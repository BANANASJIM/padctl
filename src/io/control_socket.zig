const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const MAX_CLIENTS = 4;
const BUF_SIZE = 256;

pub const ControlSocket = struct {
    listen_fd: posix.fd_t,
    client_fds: [MAX_CLIENTS]posix.fd_t,
    client_count: usize,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub const InitError = posix.SocketError || posix.BindError || posix.ListenError || std.fs.Dir.MakeError || std.mem.Allocator.Error || error{ ChmodFailed, PathTooLong };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) InitError!ControlSocket {
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        const dir = std.fs.path.dirname(path) orelse "/run";
        std.fs.makeDirAbsolute(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

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

        const rc = linux.chmod(path_z.ptr, 0o666);
        if (linux.E.init(rc) != .SUCCESS) return error.ChmodFailed;

        try posix.listen(fd, 4);

        const path_owned = try allocator.dupe(u8, path);

        return .{
            .listen_fd = fd,
            .client_fds = .{ -1, -1, -1, -1 },
            .client_count = 0,
            .path = path_owned,
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

    pub fn readCommand(self: *ControlSocket, fd: posix.fd_t) ?Command {
        var buf: [BUF_SIZE]u8 = undefined;
        const n = posix.read(fd, &buf) catch {
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
    status,
    list,
    devices,
    unknown,
};

/// Command fields (.name, .device_id) are slices into the caller's buffer.
/// Only valid for the duration of the current call frame.
pub const Command = struct {
    tag: CommandTag,
    name: []const u8 = "",
    device_id: []const u8 = "",
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
    } else if (std.ascii.eqlIgnoreCase(verb, "STATUS")) {
        return .{ .tag = .status };
    } else if (std.ascii.eqlIgnoreCase(verb, "LIST")) {
        return .{ .tag = .list };
    } else if (std.ascii.eqlIgnoreCase(verb, "DEVICES")) {
        return .{ .tag = .devices };
    }
    return .{ .tag = .unknown };
}

fn containsPathTraversal(s: []const u8) bool {
    return std.mem.indexOfScalar(u8, s, '/') != null or
        std.mem.indexOfScalar(u8, s, '\\') != null or
        std.mem.indexOf(u8, s, "..") != null;
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

test "control_socket: ControlSocket: init creates socket at exact full path" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const socket_path = try std.fs.path.join(allocator, &.{ root, "padctl.sock" });
    defer allocator.free(socket_path);

    var cs = try ControlSocket.init(allocator, socket_path);
    defer cs.deinit();

    // The socket file must exist at the EXACT full path (not truncated).
    try std.fs.accessAbsolute(socket_path, .{});
}

test "control_socket: ControlSocket: init rejects overly long unix socket path" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
    const leaf = try allocator.alloc(u8, addr.path.len);
    defer allocator.free(leaf);
    @memset(leaf, 'a');

    const socket_path = try std.fs.path.join(allocator, &.{ root, leaf });
    defer allocator.free(socket_path);

    try testing.expectError(error.PathTooLong, ControlSocket.init(allocator, socket_path));
}
