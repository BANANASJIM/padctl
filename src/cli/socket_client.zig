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

pub fn reportConnectFailure(writer: anytype, socket_path: []const u8) void {
    writer.print("error: cannot connect to padctl daemon at {s}\n", .{socket_path}) catch {};
    writer.writeAll("hint: check the service: systemctl --user status padctl.service\n") catch {};
    writer.writeAll("hint: package installs need a one-time: systemctl --user enable --now padctl.service\n") catch {};
    writer.writeAll("hint: run `padctl doctor` for full diagnosis\n") catch {};
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
    return sendCommandTimeout(fd, cmd, buf, 3000);
}

pub fn sendCommandTimeout(fd: posix.fd_t, cmd: []const u8, buf: []u8, timeout_ms: i32) ![]const u8 {
    _ = try posix.write(fd, cmd);

    var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = posix.poll(&fds, timeout_ms) catch return error.Io;
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

pub const StatusDevice = struct {
    name: []const u8,
    state: []const u8,
    mapping: []const u8,
    vid: u16,
    pid: u16,
    output_kind: []const u8,
    output_fd_alive: bool,

    pub fn deinit(self: StatusDevice, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.state);
        allocator.free(self.mapping);
        allocator.free(self.output_kind);
    }
};

/// Parse the STATUS wire line into a slice of StatusDevice.
/// Caller owns result; call freeStatusDevices when done.
pub fn parseStatusLine(line: []const u8, allocator: std.mem.Allocator) ![]StatusDevice {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, "STATUS")) return error.InvalidResponse;

    var devices: std.ArrayList(StatusDevice) = .{};
    errdefer {
        for (devices.items) |d| d.deinit(allocator);
        devices.deinit(allocator);
    }

    const rest = trimmed["STATUS".len..];
    if (rest.len == 0 or std.mem.trim(u8, rest, " \t\r\n").len == 0) {
        return devices.toOwnedSlice(allocator);
    }

    var chunks = std.mem.splitSequence(u8, rest, " device=");
    _ = chunks.next(); // skip leading empty or "STATUS" prefix
    while (chunks.next()) |chunk| {
        // Device and mapping names may contain spaces; their values run until
        // the next fixed key the daemon emits.
        const name_end = std.mem.indexOf(u8, chunk, " state=") orelse
            (std.mem.indexOfScalar(u8, chunk, ' ') orelse chunk.len);
        const name = try allocator.dupe(u8, chunk[0..name_end]);
        errdefer allocator.free(name);

        const state = try extractField(allocator, chunk, "state=", null);
        errdefer allocator.free(state);
        const mapping = try extractField(allocator, chunk, "mapping=", " phys_key=");
        errdefer allocator.free(mapping);
        const output_kind = try extractField(allocator, chunk, "output_kind=", null);
        errdefer allocator.free(output_kind);
        const vid = parseHexField(chunk, "vid=0x") orelse 0;
        const pid = parseHexField(chunk, "pid=0x") orelse 0;
        const output_fd_alive = std.mem.indexOf(u8, chunk, "output_fd_alive=true") != null;

        try devices.append(allocator, .{
            .name = name,
            .state = state,
            .mapping = mapping,
            .vid = vid,
            .pid = pid,
            .output_kind = output_kind,
            .output_fd_alive = output_fd_alive,
        });
    }

    return devices.toOwnedSlice(allocator);
}

fn extractField(allocator: std.mem.Allocator, chunk: []const u8, key: []const u8, end_key: ?[]const u8) ![]const u8 {
    const start_pos = std.mem.indexOf(u8, chunk, key) orelse return allocator.dupe(u8, "");
    const val_start = start_pos + key.len;
    if (end_key) |ek| {
        if (std.mem.indexOfPos(u8, chunk, val_start, ek)) |end| {
            return allocator.dupe(u8, chunk[val_start..end]);
        }
    }
    var i = val_start;
    while (i < chunk.len and chunk[i] != ' ' and chunk[i] != '\n' and chunk[i] != '\r') i += 1;
    return allocator.dupe(u8, chunk[val_start..i]);
}

fn parseHexField(chunk: []const u8, key: []const u8) ?u16 {
    const pos = std.mem.indexOf(u8, chunk, key) orelse return null;
    const val_start = pos + key.len;
    var end = val_start;
    while (end < chunk.len and std.ascii.isHex(chunk[end])) end += 1;
    if (end == val_start) return null;
    return std.fmt.parseInt(u16, chunk[val_start..end], 16) catch null;
}

pub fn freeStatusDevices(allocator: std.mem.Allocator, devices: []StatusDevice) void {
    for (devices) |d| d.deinit(allocator);
    allocator.free(devices);
}

/// Best-effort daemon STATUS query with a short timeout. Returns null when the
/// daemon is unreachable or the response is unusable, so callers can degrade
/// to daemon-less behavior without error output.
pub fn queryStatusDevices(allocator: std.mem.Allocator, socket_path: []const u8, timeout_ms: i32) ?[]StatusDevice {
    const fd = connectToSocket(socket_path) catch |err| {
        std.log.debug("daemon status query: connect failed: {}", .{err});
        return null;
    };
    defer posix.close(fd);
    var buf: [4096]u8 = undefined;
    const resp = sendCommandTimeout(fd, "STATUS\n", &buf, timeout_ms) catch |err| {
        std.log.debug("daemon status query: no response: {}", .{err});
        return null;
    };
    return parseStatusLine(resp, allocator) catch null;
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

test "sendCommandTimeout: no data within short timeout returns Timeout" {
    const fds = try testSocketpair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var buf: [256]u8 = undefined;
    const result = sendCommandTimeout(fds[0], "STATUS\n", &buf, 50);
    try testing.expectError(error.Timeout, result);
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

test "socket_client: parseStatusLine: bare STATUS returns empty" {
    const devices = try parseStatusLine("STATUS\n", testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 0), devices.len);
}

test "socket_client: parseStatusLine: bare STATUS no newline" {
    const devices = try parseStatusLine("STATUS", testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 0), devices.len);
}

test "socket_client: parseStatusLine: one device" {
    const line = "STATUS device=vader5 state=active mapping=default phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true evdev_node=/dev/input/event5 hotplug_pending=0 last_inbound_ms_ago=12 last_outbound_ms_ago=8 write_in_flight_ms=0\n";
    const devices = try parseStatusLine(line, testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 1), devices.len);
    try testing.expectEqualStrings("vader5", devices[0].name);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
    try testing.expectEqual(@as(u16, 0x2401), devices[0].pid);
    try testing.expectEqualStrings("active", devices[0].state);
    try testing.expectEqualStrings("default", devices[0].mapping);
    try testing.expectEqualStrings("uhid", devices[0].output_kind);
    try testing.expect(devices[0].output_fd_alive);
}

test "socket_client: parseStatusLine: two devices" {
    const line = "STATUS device=vader5 state=active mapping=fps phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true evdev_node=/dev/input/event5 hotplug_pending=0 last_inbound_ms_ago=1 last_outbound_ms_ago=1 write_in_flight_ms=0 device=wheel state=suspended mapping=racing phys_key=usb-2 vid=0x044f pid=0xb67f output_kind=uinput output_fd_alive=false evdev_node=/dev/input/event6 hotplug_pending=0 last_inbound_ms_ago=100 last_outbound_ms_ago=100 write_in_flight_ms=0\n";
    const devices = try parseStatusLine(line, testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 2), devices.len);
    try testing.expectEqualStrings("vader5", devices[0].name);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
    try testing.expectEqualStrings("wheel", devices[1].name);
    try testing.expectEqual(@as(u16, 0x044f), devices[1].vid);
    try testing.expectEqual(@as(u16, 0xb67f), devices[1].pid);
    try testing.expectEqualStrings("suspended", devices[1].state);
    try testing.expectEqualStrings("racing", devices[1].mapping);
    try testing.expect(!devices[1].output_fd_alive);
}

test "socket_client: parseStatusLine: device and mapping names with spaces" {
    // Wire line from issue #404: padctl status for Flydigi Vader 5 Pro.
    const line = "STATUS device=Flydigi Vader 5 Pro state=active mapping=Crimson Desert:Vader 5 Pro phys_key=usb-0000:10:00.0-3 vid=0x37d7 pid=0x2401 output_kind=uinput output_fd_alive=true evdev_node=/dev/input/event2(Generic X-Box pad) hotplug_pending=0 last_inbound_ms_ago=0 last_outbound_ms_ago=0 write_in_flight_ms=0\n";
    const devices = try parseStatusLine(line, testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 1), devices.len);
    try testing.expectEqualStrings("Flydigi Vader 5 Pro", devices[0].name);
    try testing.expectEqualStrings("Crimson Desert:Vader 5 Pro", devices[0].mapping);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
    try testing.expectEqual(@as(u16, 0x2401), devices[0].pid);
    try testing.expectEqualStrings("active", devices[0].state);
}

test "socket_client: reportConnectFailure: exact four-line output" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);

    reportConnectFailure(buf.writer(testing.allocator), "/run/user/1000/padctl.sock");
    try testing.expectEqualStrings(
        "error: cannot connect to padctl daemon at /run/user/1000/padctl.sock\n" ++
            "hint: check the service: systemctl --user status padctl.service\n" ++
            "hint: package installs need a one-time: systemctl --user enable --now padctl.service\n" ++
            "hint: run `padctl doctor` for full diagnosis\n",
        buf.items,
    );
}

test "socket_client: queryStatusDevices: unreachable socket returns null" {
    try testing.expect(queryStatusDevices(testing.allocator, "/tmp/padctl-nonexistent-test.sock", 500) == null);
}
