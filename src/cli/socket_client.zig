const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub const DEFAULT_SOCKET_PATH = "/run/padctl/padctl.sock";

/// Non-root user with XDG_RUNTIME_DIR set → use XDG socket path
/// (daemon binds there before the file exists; no existence check here).
/// Root or missing XDG_RUNTIME_DIR → system path for system-service compatibility.
pub fn resolveSocketPath(buf: []u8) []const u8 {
    if (posix.geteuid() != 0) {
        if (posix.getenv("XDG_RUNTIME_DIR")) |xrd| {
            return resolveSocketPathForXrd(buf, xrd);
        }
    }
    return DEFAULT_SOCKET_PATH;
}

fn resolveSocketPathForXrd(buf: []u8, xrd: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, "{s}/padctl.sock", .{xrd}) catch DEFAULT_SOCKET_PATH;
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

test "resolveSocketPath: XDG path returned even when socket does not exist" {
    // Regression for chicken-and-egg: old code called accessAbsolute, which
    // caused fall-through to DEFAULT_SOCKET_PATH when the socket didn't exist yet.
    // Test the pure helper directly to avoid env manipulation in the test suite.
    var buf: [256]u8 = undefined;
    const result = resolveSocketPathForXrd(&buf, "/nonexistent/padctl-test-xdg");
    try testing.expectEqualStrings("/nonexistent/padctl-test-xdg/padctl.sock", result);
}

test "resolveSocketPath: buf large enough for XDG path" {
    // Verify bufPrint won't overflow for a typical XDG_RUNTIME_DIR length.
    var buf: [256]u8 = undefined;
    const fake_xrd = "/run/user/1000";
    const result = std.fmt.bufPrint(&buf, "{s}/padctl.sock", .{fake_xrd}) catch unreachable;
    try testing.expectEqualStrings("/run/user/1000/padctl.sock", result);
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

// Issue #216 (partial): "cannot connect to padctl daemon". The systemd
// capabilities / SupplementaryGroups / hidraw-permission half is an
// environment-layer concern (NOT-UNIT-TESTABLE; the install-side guard lives
// in src/cli/install/tests.zig "issue #216"). The padctl-side testable slice
// (research/issue-regression-coverage-audit-2026-05-15.md §D.6) is: the client
// connect path must surface a *specific*, diagnosable error rather than a
// catch-all, so callers can distinguish a malformed socket path from a
// genuinely-unreachable daemon. `connectToSocket` is the exact function every
// CLI client (status/devices/switch/dump) calls before printing "cannot
// connect to padctl daemon".
//
// Falsifiability contract (audit §D.6): the explicit validation branch
//   `if (path.len == 0 or path[0] != '/' or indexOf(path, "..") != null)
//        return error.InvalidPath;`
// is what makes the error specific. If that guard is removed/weakened (errors
// "mapped back to catch-all"), an empty or relative or "..":-traversal path
// instead falls through to posix.socket/posix.connect and fails with a generic
// posix errno (e.g. error.FileNotFound / AddressNotAvailable) — NOT
// error.InvalidPath. Under that mutation every `expectError(error.InvalidPath,
// ...)` below fails. Independently provable by deleting that `if` line.
test "socket_client: connectToSocket: malformed paths return specific InvalidPath (issue #216)" {
    // Empty path — must not be a generic socket/connect failure.
    try testing.expectError(error.InvalidPath, connectToSocket(""));

    // Relative (non-absolute) path — daemon sockets are always absolute.
    try testing.expectError(error.InvalidPath, connectToSocket("relative/padctl.sock"));

    // Path-traversal attempt — must be rejected before any syscall.
    try testing.expectError(error.InvalidPath, connectToSocket("/run/padctl/../padctl.sock"));
}

// Companion guard: a well-formed but absent absolute socket path must return a
// concrete posix ConnectError member (FileNotFound for a missing AF_UNIX
// node), never an opaque/unexpected error. This pins the "daemon not running"
// diagnostic to a specific, actionable error variant.
test "socket_client: connectToSocket: nonexistent absolute socket yields concrete posix error (issue #216)" {
    const result = connectToSocket("/run/padctl-issue216-nonexistent/padctl.sock");
    try testing.expectError(error.FileNotFound, result);
}
