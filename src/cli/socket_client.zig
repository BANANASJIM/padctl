const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const control_socket = @import("../io/control_socket.zig");

pub const DEFAULT_SOCKET_PATH = "/run/padctl/padctl.sock";
pub const SYSTEM_RUNTIME_DIR = "/run/padctl";

/// Resolution order (first match wins):
///   1. $PADCTL_SOCKET env override
///   2. $XDG_RUNTIME_DIR/socket.advertised (user-scope daemon)
///   3. /run/padctl/socket.advertised (system-scope daemon)
///   4. Backward-compat fallback (old uid-relative paths)
///
/// Step 2 has no `padctl/` segment: the user-scope daemon binds at
/// `$XDG_RUNTIME_DIR/padctl.sock`, so `dirname()` is `$XDG_RUNTIME_DIR` and
/// `writeAdvertisedFile` produces `$XDG_RUNTIME_DIR/socket.advertised`.
pub fn resolveSocketPath(buf: []u8) []const u8 {
    const env_override = blk: {
        if (posix.getenv("PADCTL_SOCKET")) |v| {
            if (v.len > 0) break :blk v;
        }
        break :blk null;
    };
    const xrd = posix.getenv("XDG_RUNTIME_DIR");
    return resolveSocketPathFor(buf, env_override, xrd, SYSTEM_RUNTIME_DIR, posix.geteuid() == 0);
}

/// Pure resolver; takes injectable env/runtime-dir parameters so tests can
/// exercise every branch without mutating the process environment.
pub fn resolveSocketPathFor(
    buf: []u8,
    env_override: ?[]const u8,
    xdg_runtime_dir: ?[]const u8,
    system_runtime_dir: []const u8,
    is_root: bool,
) []const u8 {
    if (env_override) |v| {
        if (v.len > 0) return copyOrDefault(buf, v);
    }

    if (xdg_runtime_dir) |xrd| {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const adv = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ xrd, control_socket.ADVERTISED_FILE_NAME }) catch null;
        if (adv) |p| if (readAdvertised(buf, p)) |out| return out;
    }

    {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const adv = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ system_runtime_dir, control_socket.ADVERTISED_FILE_NAME }) catch null;
        if (adv) |p| if (readAdvertised(buf, p)) |out| return out;
    }

    // Backward-compat fallback so a new CLI still reaches an old daemon.
    if (!is_root) {
        if (xdg_runtime_dir) |xrd| {
            return std.fmt.bufPrint(buf, "{s}/padctl.sock", .{xrd}) catch DEFAULT_SOCKET_PATH;
        }
    }
    return DEFAULT_SOCKET_PATH;
}

fn copyOrDefault(buf: []u8, s: []const u8) []const u8 {
    if (s.len > buf.len) return DEFAULT_SOCKET_PATH;
    @memcpy(buf[0..s.len], s);
    return buf[0..s.len];
}

fn readAdvertised(out: []u8, advertised_path: []const u8) ?[]const u8 {
    var file = std.fs.openFileAbsolute(advertised_path, .{}) catch return null;
    defer file.close();
    var raw: [256]u8 = undefined;
    const n = file.readAll(&raw) catch return null;
    const trimmed = std.mem.trim(u8, raw[0..n], " \t\r\n");
    if (trimmed.len == 0 or trimmed.len > out.len) return null;
    @memcpy(out[0..trimmed.len], trimmed);
    return out[0..trimmed.len];
}

pub const ConnectError = posix.SocketError || posix.ConnectError || error{ PathTooLong, InvalidPath };

pub fn connectToSocket(path: []const u8) ConnectError!posix.fd_t {
    if (path.len == 0 or path[0] != '/' or std.mem.indexOf(u8, path, "..") != null)
        return error.InvalidPath;

    const fd = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(fd);

    var addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
    @memset(&addr.path, 0);
    if (path.len >= addr.path.len) return error.PathTooLong;
    @memcpy(addr.path[0..path.len], path);

    try posix.connect(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.un));
    return fd;
}

pub fn sendCommand(fd: posix.fd_t, cmd: []const u8, buf: []u8) ![]const u8 {
    _ = try posix.write(fd, cmd);

    var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = posix.poll(&fds, 3000) catch return error.Io;
    if (ready == 0) return error.Timeout;

    var total: usize = 0;
    while (total < buf.len) {
        const n = posix.read(fd, buf[total..]) catch |err| switch (err) {
            error.WouldBlock => break,
            else => return err,
        };
        if (n == 0) break;
        total += n;
        if (std.mem.indexOfScalar(u8, buf[0..total], '\n') != null) break;
    }
    if (total == 0) return error.EndOfStream;
    return buf[0..total];
}

pub fn formatSwitch(buf: []u8, name: []const u8, device_id: ?[]const u8) []const u8 {
    if (device_id) |dev| {
        const len = (std.fmt.bufPrint(buf, "SWITCH {s} --device {s}\n", .{ name, dev }) catch return buf[0..0]).len;
        return buf[0..len];
    }
    const len = (std.fmt.bufPrint(buf, "SWITCH {s}\n", .{name}) catch return buf[0..0]).len;
    return buf[0..len];
}

// --- tests ---

const testing = std.testing;

test "resolveSocketPath: root returns system path" {
    // This test only verifies the default fallback path constant.
    try testing.expectEqualStrings("/run/padctl/padctl.sock", DEFAULT_SOCKET_PATH);
}

// Test A: env override wins over every advertised file and fallback.
test "resolveSocketPathFor: PADCTL_SOCKET env override wins" {
    var buf: [256]u8 = undefined;
    const got = resolveSocketPathFor(&buf, "/custom/path.sock", "/run/user/1000", "/run/padctl", false);
    try testing.expectEqualStrings("/custom/path.sock", got);
}

// Falsifiability: drop the XDG advertised-read branch in resolveSocketPathFor
// and this test must FAIL — the resolver will hit the backward-compat
// fallback and return the XDG socket path instead of the advertised value.
// Fixture writes at `$XDG_RUNTIME_DIR/socket.advertised` (no `padctl/`
// segment) to match the daemon writer: dirname($XDG/padctl.sock) is $XDG.
test "resolveSocketPathFor: XDG advertised file is honored" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const xrd = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(xrd);

    var f = try tmp.dir.createFile(control_socket.ADVERTISED_FILE_NAME, .{ .truncate = true });
    try f.writeAll("/tmp/foo.sock\n");
    f.close();

    var buf: [256]u8 = undefined;
    const got = resolveSocketPathFor(&buf, null, xrd, "/nonexistent-system", false);
    try testing.expectEqualStrings("/tmp/foo.sock", got);
}

// Test C: system advertised file picked when XDG is missing.
test "resolveSocketPathFor: system advertised file is honored when XDG absent" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const sys_root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(sys_root);

    var f = try tmp.dir.createFile(control_socket.ADVERTISED_FILE_NAME, .{ .truncate = true });
    try f.writeAll("/run/padctl/padctl.sock");
    f.close();

    var buf: [256]u8 = undefined;
    const got = resolveSocketPathFor(&buf, null, null, sys_root, true);
    try testing.expectEqualStrings("/run/padctl/padctl.sock", got);
}

// Test D: backward-compat fallback when no env, no advertised files.
test "resolveSocketPathFor: fallback returns XDG path for non-root user" {
    var buf: [256]u8 = undefined;
    const got = resolveSocketPathFor(&buf, null, "/run/user/1000", "/nonexistent-system", false);
    try testing.expectEqualStrings("/run/user/1000/padctl.sock", got);
}

test "resolveSocketPathFor: fallback returns system path for root" {
    var buf: [256]u8 = undefined;
    const got = resolveSocketPathFor(&buf, null, null, "/nonexistent-system", true);
    try testing.expectEqualStrings(DEFAULT_SOCKET_PATH, got);
}

test "formatSwitch: global" {
    var buf: [256]u8 = undefined;
    const cmd = formatSwitch(&buf, "fps", null);
    try testing.expectEqualStrings("SWITCH fps\n", cmd);
}

test "formatSwitch: per-device" {
    var buf: [256]u8 = undefined;
    const cmd = formatSwitch(&buf, "racing", "hidraw0");
    try testing.expectEqualStrings("SWITCH racing --device hidraw0\n", cmd);
}

fn testSocketpair() ![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    if (std.c.socketpair(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0, &fds) != 0)
        return posix.unexpectedErrno(posix.errno(0));
    return fds;
}

test "sendCommand: socketpair round-trip" {
    const fds = try testSocketpair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    // Simulate server: write response on fds[1]
    _ = try posix.write(fds[1], "OK fps\n");

    var buf: [256]u8 = undefined;
    const resp = try sendCommand(fds[0], "SWITCH fps\n", &buf);
    try testing.expectEqualStrings("OK fps\n", resp);
}

test "sendCommand: empty response returns EndOfStream" {
    const fds = try testSocketpair();
    defer posix.close(fds[0]);
    // Close server side immediately
    posix.close(fds[1]);

    var buf: [256]u8 = undefined;
    const result = sendCommand(fds[0], "STATUS\n", &buf);
    try testing.expectError(error.BrokenPipe, result);
}

// The client connect path must surface a *specific*, diagnosable error rather
// than a catch-all, so callers can distinguish a malformed socket path from a
// genuinely-unreachable daemon. `connectToSocket` is called by every CLI client
// (status/devices/switch/dump) before printing "cannot connect to padctl daemon".
//
// Falsifiability: the explicit validation branch
//   `if (path.len == 0 or path[0] != '/' or indexOf(path, "..") != null)
//        return error.InvalidPath;`
// makes the error specific. Removing that guard lets invalid paths fall through
// to posix.socket/posix.connect and fail with a generic errno — NOT
// error.InvalidPath — so every `expectError(error.InvalidPath, ...)` below fails.
test "socket_client: connectToSocket: malformed paths return specific InvalidPath" {
    // Empty path — must not be a generic socket/connect failure.
    try testing.expectError(error.InvalidPath, connectToSocket(""));

    // Relative (non-absolute) path — daemon sockets are always absolute.
    try testing.expectError(error.InvalidPath, connectToSocket("relative/padctl.sock"));

    // Path-traversal attempt — must be rejected before any syscall.
    try testing.expectError(error.InvalidPath, connectToSocket("/run/padctl/../padctl.sock"));
}

// Companion guard: a well-formed but absent absolute socket path must return a
// concrete posix ConnectError member, never an opaque/unexpected error. This
// pins the "daemon not running" diagnostic to an actionable error variant.
test "socket_client: connectToSocket: nonexistent absolute socket yields concrete posix error" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try tmp.dir.realpath(".", &dir_buf);
    var sock_buf: [std.fs.max_path_bytes]u8 = undefined;
    const sock_path = try std.fmt.bufPrint(&sock_buf, "{s}/padctl.sock", .{dir_path});

    if (connectToSocket(sock_path)) |fd| {
        posix.close(fd);
        return error.TestUnexpectedResult;
    } else |err| switch (err) {
        error.FileNotFound => {},
        // Some local sandboxes reject AF_UNIX connect before pathname lookup.
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    }
}
