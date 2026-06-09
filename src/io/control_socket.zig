const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const MAX_CLIENTS = 4;
pub const BUF_SIZE = 256;

/// Suffix joined to the socket's parent directory to advertise the bound path.
pub const ADVERTISED_FILE_NAME = "socket.advertised";

const unix_path_len = @typeInfo(@TypeOf(@as(linux.sockaddr.un, undefined).path)).array.len;

/// Returns true if a live daemon is bound to `path` (connect(AF_UNIX) succeeds).
/// Used both by `ControlSocket.init` (refuse to start when another instance owns
/// the socket) and by the install/uninstall flow (refuse to unlink under a
/// running daemon — issue #216).
pub fn probeAlive(path: []const u8) bool {
    if (path.len == 0 or path.len >= unix_path_len) return false;
    const probe_fd = posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch return false;
    defer posix.close(probe_fd);
    var addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
    @memset(&addr.path, 0);
    @memcpy(addr.path[0..path.len], path);
    posix.connect(probe_fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.un)) catch return false;
    return true;
}

pub const ControlSocket = struct {
    listen_fd: posix.fd_t,
    client_fds: [MAX_CLIENTS]posix.fd_t,
    client_count: usize,
    path: []const u8,
    advertised_path: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub const InitError = posix.SocketError || posix.BindError || posix.ListenError || std.fs.Dir.MakeError || std.mem.Allocator.Error || error{ AlreadyRunning, ChmodFailed, PathTooLong };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) InitError!ControlSocket {
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        const dir = std.fs.path.dirname(path) orelse "/run";
        // systemd RuntimeDirectory= creates this when service is active;
        // defensive for daemon started outside systemd (dev/test/foreground).
        std.fs.makeDirAbsolute(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        if (probeAlive(path)) return error.AlreadyRunning;

        // Unlink stale socket
        std.fs.deleteFileAbsolute(path) catch {};

        const fd = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK, 0);
        errdefer posix.close(fd);

        var addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
        @memset(&addr.path, 0);
        if (path_z.len > addr.path.len - 1) return error.PathTooLong;
        @memcpy(addr.path[0..path_z.len], path_z[0..path_z.len]);

        try posix.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.un));
        errdefer std.fs.deleteFileAbsolute(path) catch {};

        const rc = linux.chmod(path_z.ptr, 0o660);
        if (linux.E.init(rc) != .SUCCESS) return error.ChmodFailed;

        try posix.listen(fd, 4);

        const path_owned = try allocator.dupe(u8, path);
        errdefer allocator.free(path_owned);

        const advertised_path = writeAdvertisedFile(allocator, path) catch |err| blk: {
            std.log.warn("control socket: advertised file write failed: {}", .{err});
            break :blk null;
        };

        return .{
            .listen_fd = fd,
            .client_fds = .{ -1, -1, -1, -1 },
            .client_count = 0,
            .path = path_owned,
            .advertised_path = advertised_path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ControlSocket) void {
        for (&self.client_fds) |*cfd| {
            if (cfd.* >= 0) {
                posix.close(cfd.*);
                cfd.* = -1;
            }
        }
        self.client_count = 0;
        posix.close(self.listen_fd);
        if (self.advertised_path) |ap| {
            std.fs.deleteFileAbsolute(ap) catch {};
            self.allocator.free(ap);
            self.advertised_path = null;
        }
        std.fs.deleteFileAbsolute(self.path) catch {};
        self.allocator.free(self.path);
    }

    pub fn pollfd(self: *const ControlSocket) posix.pollfd {
        return .{ .fd = self.listen_fd, .events = posix.POLL.IN, .revents = 0 };
    }

    pub fn clientPollfds(self: *const ControlSocket, out: []posix.pollfd) usize {
        var n: usize = 0;
        for (self.client_fds) |cfd| {
            if (cfd >= 0) {
                out[n] = .{ .fd = cfd, .events = posix.POLL.IN, .revents = 0 };
                n += 1;
            }
        }
        return n;
    }

    pub fn acceptClient(self: *ControlSocket) void {
        const cfd = posix.accept(self.listen_fd, null, null, posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK) catch return;
        if (self.client_count >= MAX_CLIENTS) {
            _ = posix.write(cfd, "ERR too-many-clients\n") catch {};
            posix.close(cfd);
            return;
        }
        for (&self.client_fds) |*slot| {
            if (slot.* < 0) {
                slot.* = cfd;
                self.client_count += 1;
                return;
            }
        }
        posix.close(cfd);
    }

    pub fn removeClient(self: *ControlSocket, fd: posix.fd_t) void {
        for (&self.client_fds) |*slot| {
            if (slot.* == fd) {
                posix.close(fd);
                slot.* = -1;
                self.client_count -= 1;
                return;
            }
        }
    }

    /// Reads one command into the caller-provided `buf`. The returned Command's
    /// `.name`/`.device_id` slice into `buf`, so `buf` must outlive every use of
    /// the Command (see the Command docstring).
    pub fn readCommand(self: *ControlSocket, fd: posix.fd_t, buf: []u8) ?Command {
        const n = posix.read(fd, buf) catch {
            self.removeClient(fd);
            return null;
        };
        if (n == 0) {
            self.removeClient(fd);
            return null;
        }
        return parseCommand(buf[0..n]);
    }

    pub fn sendResponse(_: *ControlSocket, fd: posix.fd_t, msg: []const u8) void {
        _ = posix.write(fd, msg) catch {};
    }
};

pub const CommandTag = enum {
    switch_mapping,
    switch_device,
    chord_switch,
    status,
    list,
    devices,
    dump_on,
    dump_off,
    dump_status,
    unknown,
};

/// Command fields (.name, .device_id) are slices into the caller-owned buffer
/// passed to readCommand/parseCommand. Valid only while that buffer is alive.
pub const Command = struct {
    tag: CommandTag,
    name: []const u8 = "",
    device_id: []const u8 = "",
    /// Chord index for CHORD_SWITCH command (1..255). 0 = unset.
    chord_index: u8 = 0,
};

pub fn parseCommand(raw: []const u8) Command {
    const line = std.mem.trimRight(u8, raw, "\r\n");
    if (line.len == 0) return .{ .tag = .unknown };

    var it = std.mem.tokenizeScalar(u8, line, ' ');
    const verb = it.next() orelse return .{ .tag = .unknown };

    if (std.ascii.eqlIgnoreCase(verb, "SWITCH")) {
        const name = it.next() orelse return .{ .tag = .unknown };
        if (containsPathTraversal(name)) return .{ .tag = .unknown };
        // Check for --device flag
        if (it.next()) |flag| {
            if (std.mem.eql(u8, flag, "--device")) {
                const dev_id = it.next() orelse return .{ .tag = .unknown };
                if (containsPathTraversal(dev_id)) return .{ .tag = .unknown };
                return .{ .tag = .switch_device, .name = name, .device_id = dev_id };
            }
        }
        return .{ .tag = .switch_mapping, .name = name };
    } else if (std.ascii.eqlIgnoreCase(verb, "CHORD_SWITCH")) {
        const idx_str = it.next() orelse return .{ .tag = .unknown };
        const idx = std.fmt.parseInt(u8, idx_str, 10) catch return .{ .tag = .unknown };
        if (idx == 0) return .{ .tag = .unknown };
        return .{ .tag = .chord_switch, .chord_index = idx };
    } else if (std.ascii.eqlIgnoreCase(verb, "STATUS")) {
        return .{ .tag = .status };
    } else if (std.ascii.eqlIgnoreCase(verb, "LIST")) {
        return .{ .tag = .list };
    } else if (std.ascii.eqlIgnoreCase(verb, "DEVICES")) {
        return .{ .tag = .devices };
    } else if (std.ascii.eqlIgnoreCase(verb, "DUMP")) {
        const mode = it.next() orelse return .{ .tag = .unknown };
        if (std.ascii.eqlIgnoreCase(mode, "ON")) return .{ .tag = .dump_on };
        if (std.ascii.eqlIgnoreCase(mode, "OFF")) return .{ .tag = .dump_off };
        if (std.ascii.eqlIgnoreCase(mode, "STATUS")) return .{ .tag = .dump_status };
        return .{ .tag = .unknown };
    }
    return .{ .tag = .unknown };
}

/// Returns the absolute advertised-file path for a given socket path
/// (`<dirname>/socket.advertised`). Caller owns the returned memory.
pub fn advertisedFilePath(allocator: std.mem.Allocator, socket_path: []const u8) ![]u8 {
    const dir = std.fs.path.dirname(socket_path) orelse "/";
    return std.fs.path.join(allocator, &.{ dir, ADVERTISED_FILE_NAME });
}

fn writeAdvertisedFile(allocator: std.mem.Allocator, socket_path: []const u8) ![]u8 {
    const ap = try advertisedFilePath(allocator, socket_path);
    errdefer allocator.free(ap);

    var file = try std.fs.createFileAbsolute(ap, .{ .truncate = true, .mode = 0o644 });
    defer file.close();
    try file.writeAll(socket_path);
    return ap;
}

fn containsPathTraversal(s: []const u8) bool {
    // Always block ".." and backslashes
    if (std.mem.indexOf(u8, s, "..") != null) return true;
    if (std.mem.indexOfScalar(u8, s, '\\') != null) return true;
    // Absolute paths (client-resolved) are allowed — they start with /
    // Bare names must not contain slashes
    if (s.len > 0 and s[0] == '/') return false;
    return std.mem.indexOfScalar(u8, s, '/') != null;
}

// --- tests ---

const testing = std.testing;

test "control_socket: parseCommand: SWITCH global" {
    const cmd = parseCommand("SWITCH fps\n");
    try testing.expectEqual(CommandTag.switch_mapping, cmd.tag);
    try testing.expectEqualStrings("fps", cmd.name);
}

test "control_socket: parseCommand: SWITCH per-device" {
    const cmd = parseCommand("SWITCH racing --device hidraw0\n");
    try testing.expectEqual(CommandTag.switch_device, cmd.tag);
    try testing.expectEqualStrings("racing", cmd.name);
    try testing.expectEqualStrings("hidraw0", cmd.device_id);
}

test "control_socket: parseCommand: STATUS" {
    const cmd = parseCommand("STATUS\n");
    try testing.expectEqual(CommandTag.status, cmd.tag);
}

test "control_socket: parseCommand: LIST" {
    const cmd = parseCommand("LIST\n");
    try testing.expectEqual(CommandTag.list, cmd.tag);
}

test "control_socket: parseCommand: DEVICES" {
    const cmd = parseCommand("DEVICES\n");
    try testing.expectEqual(CommandTag.devices, cmd.tag);
}

test "control_socket: parseCommand: CHORD_SWITCH valid index" {
    const cmd = parseCommand("CHORD_SWITCH 3\n");
    try testing.expectEqual(CommandTag.chord_switch, cmd.tag);
    try testing.expectEqual(@as(u8, 3), cmd.chord_index);
}

test "control_socket: parseCommand: CHORD_SWITCH zero index rejected" {
    const cmd = parseCommand("CHORD_SWITCH 0\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: CHORD_SWITCH non-numeric rejected" {
    const cmd = parseCommand("CHORD_SWITCH foo\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: CHORD_SWITCH missing arg rejected" {
    const cmd = parseCommand("CHORD_SWITCH\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: unknown" {
    const cmd = parseCommand("FOOBAR\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: empty" {
    const cmd = parseCommand("\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: case insensitive" {
    const cmd = parseCommand("switch FPS\n");
    try testing.expectEqual(CommandTag.switch_mapping, cmd.tag);
    try testing.expectEqualStrings("FPS", cmd.name);
}

test "control_socket: parseCommand: DUMP ON" {
    const cmd = parseCommand("DUMP ON\n");
    try testing.expectEqual(CommandTag.dump_on, cmd.tag);
}

test "control_socket: parseCommand: DUMP OFF" {
    const cmd = parseCommand("DUMP OFF\n");
    try testing.expectEqual(CommandTag.dump_off, cmd.tag);
}

test "control_socket: parseCommand: DUMP case insensitive" {
    const on = parseCommand("dump on\n");
    try testing.expectEqual(CommandTag.dump_on, on.tag);
    const off = parseCommand("Dump Off\n");
    try testing.expectEqual(CommandTag.dump_off, off.tag);
}

test "control_socket: parseCommand: DUMP STATUS" {
    const cmd = parseCommand("DUMP STATUS\n");
    try testing.expectEqual(CommandTag.dump_status, cmd.tag);
}

test "control_socket: parseCommand: DUMP without arg is unknown" {
    const cmd = parseCommand("DUMP\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: DUMP invalid arg is unknown" {
    const cmd = parseCommand("DUMP MAYBE\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: SWITCH missing name" {
    const cmd = parseCommand("SWITCH\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: SWITCH --device missing id" {
    const cmd = parseCommand("SWITCH fps --device\n");
    try testing.expectEqual(CommandTag.unknown, cmd.tag);
}

test "control_socket: parseCommand: path traversal rejected" {
    try testing.expectEqual(CommandTag.unknown, parseCommand("SWITCH ../etc/passwd\n").tag);
    try testing.expectEqual(CommandTag.unknown, parseCommand("SWITCH foo/bar\n").tag);
    try testing.expectEqual(CommandTag.unknown, parseCommand("SWITCH a\\b\n").tag);
    try testing.expectEqual(CommandTag.unknown, parseCommand("SWITCH ok --device ../x\n").tag);
    // Absolute paths with traversal still rejected
    try testing.expectEqual(CommandTag.unknown, parseCommand("SWITCH /etc/../shadow\n").tag);
}

test "control_socket: parseCommand: absolute path accepted" {
    const cmd = parseCommand("SWITCH /home/user/.config/padctl/mappings/vader5.toml\n");
    try testing.expectEqual(CommandTag.switch_mapping, cmd.tag);
    try testing.expectEqualStrings("/home/user/.config/padctl/mappings/vader5.toml", cmd.name);
}

fn testSocketpair() ![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    if (std.c.socketpair(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0, &fds) != 0)
        return posix.unexpectedErrno(posix.errno(0));
    return fds;
}

test "control_socket: ControlSocket: socketpair read/write" {
    const fds = try testSocketpair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    // Write a command from client side
    _ = try posix.write(fds[1], "SWITCH fps\n");

    // Read from server side
    var buf: [BUF_SIZE]u8 = undefined;
    const n = try posix.read(fds[0], &buf);
    const cmd = parseCommand(buf[0..n]);
    try testing.expectEqual(CommandTag.switch_mapping, cmd.tag);
    try testing.expectEqualStrings("fps", cmd.name);
}

// Recursive helper that fills a large stack array with 0xAA so that, under the
// OLD readCommand (which returned slices into its own buffer), the dead frame
// would be overwritten and the asserts below would see garbage. Marked noinline
// so the compiler cannot elide the stack writes.
noinline fn clobberStack(depth: usize) usize {
    var scratch: [BUF_SIZE * 2]u8 = undefined;
    @memset(&scratch, 0xAA);
    if (depth == 0) return scratch[0];
    return scratch[depth % scratch.len] +% clobberStack(depth - 1);
}

// Falsifiability: revert readCommand to the internal-buffer form
// (`var buf: [BUF_SIZE]u8 = undefined; ... parseCommand(buf[0..n])`) and drop the
// `buf` parameter — cmd.name/cmd.device_id then slice into readCommand's dead
// frame, which clobberStack overwrites with 0xAA, and these expectEqualStrings
// FAIL. With the fix the bytes live in the caller's `buf` and survive.
test "control_socket: readCommand: name survives stack clobber via caller buffer" {
    const fds = try testSocketpair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    _ = try posix.write(fds[1], "SWITCH racing --device hidraw0\n");

    var cs: ControlSocket = undefined;
    var buf: [BUF_SIZE]u8 = undefined;
    const cmd = cs.readCommand(fds[0], &buf) orelse return error.NoCommand;

    // Clobber any stack the old internal buffer would have lived in.
    _ = clobberStack(64);

    try testing.expectEqual(CommandTag.switch_device, cmd.tag);
    try testing.expectEqualStrings("racing", cmd.name);
    try testing.expectEqualStrings("hidraw0", cmd.device_id);
}

test "control_socket: ControlSocket: init creates socket at exact full path" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    // Use a short name to stay well within the 107-char Unix socket path limit
    const socket_path = try std.fs.path.join(allocator, &.{ root, "t.sock" });
    defer allocator.free(socket_path);

    var cs = ControlSocket.init(allocator, socket_path) catch |err| {
        // Skip on environments where socket binding is restricted (sandboxes, containers)
        if (err == error.AccessDenied) return;
        return err;
    };
    defer cs.deinit();

    // The socket file must exist at the EXACT full path (not truncated).
    try std.fs.accessAbsolute(socket_path, .{});
}

test "control_socket: ControlSocket: init returns AlreadyRunning when daemon is live" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "live.sock" });
    defer allocator.free(socket_path);

    var cs = ControlSocket.init(allocator, socket_path) catch |err| {
        if (err == error.AccessDenied) return;
        return err;
    };
    defer cs.deinit();

    try testing.expectError(error.AlreadyRunning, ControlSocket.init(allocator, socket_path));
}

test "control_socket: ControlSocket: init succeeds after previous daemon exits" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "stale.sock" });
    defer allocator.free(socket_path);

    {
        var cs = ControlSocket.init(allocator, socket_path) catch |err| {
            if (err == error.AccessDenied) return;
            return err;
        };
        cs.deinit();
    }

    // After daemon exits, next init must succeed (stale socket cleaned up)
    var cs2 = ControlSocket.init(allocator, socket_path) catch |err| {
        if (err == error.AccessDenied) return;
        return err;
    };
    cs2.deinit();
}

test "control_socket: ControlSocket: init rejects overly long unix socket path" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("run");
    const run_dir = try tmp.dir.realpathAlloc(allocator, "run");
    defer allocator.free(run_dir);

    const addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
    const leaf = try allocator.alloc(u8, addr.path.len);
    defer allocator.free(leaf);
    @memset(leaf, 'a');

    const socket_path = try std.fs.path.join(allocator, &.{ run_dir, leaf });
    defer allocator.free(socket_path);

    try testing.expectError(error.PathTooLong, ControlSocket.init(allocator, socket_path));
}

// Falsifiability: delete the writeAdvertisedFile call in ControlSocket.init,
// and this test must FAIL — the advertised file will not exist and
// accessAbsolute returns error.FileNotFound.
test "control_socket: ControlSocket: init writes advertised file with socket path" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "adv.sock" });
    defer allocator.free(socket_path);

    var cs = ControlSocket.init(allocator, socket_path) catch |err| {
        if (err == error.AccessDenied) return;
        return err;
    };
    defer cs.deinit();

    const expected_ap = try advertisedFilePath(allocator, socket_path);
    defer allocator.free(expected_ap);
    try std.fs.accessAbsolute(expected_ap, .{});

    var file = try std.fs.openFileAbsolute(expected_ap, .{});
    defer file.close();
    var buf: [256]u8 = undefined;
    const n = try file.readAll(&buf);
    try testing.expectEqualStrings(socket_path, buf[0..n]);
}

// Falsifiability: restore the chmod argument to 0o666 in ControlSocket.init and
// this test FAILS — the world-write bit (0o002) is set on the bound socket,
// which is the local-privilege-escalation surface this hardening removes.
test "control_socket: ControlSocket: init binds socket without world-write" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "perm.sock" });
    defer allocator.free(socket_path);

    var cs = ControlSocket.init(allocator, socket_path) catch |err| {
        if (err == error.AccessDenied) return;
        return err;
    };
    defer cs.deinit();

    const st = try posix.fstatat(posix.AT.FDCWD, socket_path, 0);
    try testing.expectEqual(@as(u32, 0), st.mode & 0o002);
}

// Falsifiability: drop the deleteFileAbsolute(self.advertised_path) branch in
// deinit, and this test must FAIL — accessAbsolute will succeed.
test "control_socket: ControlSocket: deinit removes advertised file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "advd.sock" });
    defer allocator.free(socket_path);

    var cs = ControlSocket.init(allocator, socket_path) catch |err| {
        if (err == error.AccessDenied) return;
        return err;
    };

    const expected_ap = try advertisedFilePath(allocator, socket_path);
    defer allocator.free(expected_ap);
    try std.fs.accessAbsolute(expected_ap, .{});

    cs.deinit();
    try testing.expectError(error.FileNotFound, std.fs.accessAbsolute(expected_ap, .{}));
}
