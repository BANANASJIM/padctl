const std = @import("std");
const socket_client = @import("socket_client.zig");

/// Resolve PID: explicit arg → /run/padctl.pid → pgrep -x padctl
fn resolvePid(allocator: std.mem.Allocator, explicit: ?[]const u8) !std.posix.pid_t {
    if (explicit) |s| {
        return std.fmt.parseInt(std.posix.pid_t, s, 10) catch return error.InvalidPid;
    }

    // Try /run/padctl.pid
    if (readPidFile(allocator, "/run/padctl.pid")) |pid| {
        return pid;
    } else |_| {}

    // Fall back to pgrep -x padctl
    return pgrepPadctl(allocator);
}

fn readPidFile(allocator: std.mem.Allocator, path: []const u8) !std.posix.pid_t {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 64);
    defer allocator.free(data);
    const trimmed = std.mem.trim(u8, data, &std.ascii.whitespace);
    return std.fmt.parseInt(std.posix.pid_t, trimmed, 10);
}

fn pgrepPadctl(allocator: std.mem.Allocator) !std.posix.pid_t {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pgrep", "-x", "padctl" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0) return error.ProcessNotFound;
    const trimmed = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
    // pgrep may return multiple lines; take first
    const line = std.mem.sliceTo(trimmed, '\n');
    return std.fmt.parseInt(std.posix.pid_t, line, 10) catch return error.ProcessNotFound;
}

fn isAlive(pid: std.posix.pid_t) bool {
    // kill(pid, 0) returns error only if process doesn't exist or no permission
    std.posix.kill(pid, 0) catch return false;
    return true;
}

const SocketReload = enum { ok, failed, unreachable_socket };

/// Ask the daemon to reload via the control socket. Forwards the reply to
/// `writer`/`err_writer` and reports whether it confirmed success (`ok`),
/// reported a failure (`failed`), or the socket was unreachable so the caller
/// can fall back to SIGHUP (`unreachable_socket`).
fn reloadViaSocket(socket_path: []const u8, writer: anytype, err_writer: anytype) SocketReload {
    const fd = socket_client.connectToSocket(socket_path) catch return .unreachable_socket;
    defer std.posix.close(fd);

    var resp_buf: [256]u8 = undefined;
    const resp = socket_client.sendCommand(fd, "RELOAD\n", &resp_buf) catch return .unreachable_socket;
    return printReply(resp, writer, err_writer);
}

fn printReply(resp: []const u8, writer: anytype, err_writer: anytype) SocketReload {
    if (std.mem.startsWith(u8, resp, "OK")) {
        writeLine(writer, resp);
        return .ok;
    }
    writeLine(err_writer, resp);
    return .failed;
}

fn writeLine(out: anytype, resp: []const u8) void {
    out.writeAll(resp) catch {};
    if (resp.len == 0 or resp[resp.len - 1] != '\n') out.writeAll("\n") catch {};
}

pub fn run(allocator: std.mem.Allocator, pid_arg: ?[]const u8, socket_path: []const u8, writer: anytype, err_writer: anytype) !void {
    // The socket reply confirms the reload actually happened; SIGHUP only
    // assumes it. Use the socket when reachable, fall back to the signal.
    if (pid_arg == null) switch (reloadViaSocket(socket_path, writer, err_writer)) {
        .ok => return,
        .failed => std.process.exit(1),
        .unreachable_socket => {},
    };

    const pid = resolvePid(allocator, pid_arg) catch {
        std.log.err("padctl daemon not running", .{});
        std.process.exit(1);
    };

    try std.posix.kill(pid, std.posix.SIG.HUP);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    if (!isAlive(pid)) {
        std.log.err("padctl daemon (PID: {d}) exited after SIGHUP", .{pid});
        std.process.exit(1);
    }

    writer.writeAll("Reloaded.\n") catch {};
}

// --- tests ---

const testing = std.testing;

test "readPidFile: parses valid pid" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "padctl.pid", .data = "12345\n" });
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp.dir.realpath("padctl.pid", &buf);
    const pid = try readPidFile(allocator, path);
    try testing.expectEqual(@as(std.posix.pid_t, 12345), pid);
}

test "readPidFile: missing file returns error" {
    const allocator = testing.allocator;
    const result = readPidFile(allocator, "/nonexistent/padctl.pid");
    try testing.expectError(error.FileNotFound, result);
}

test "readPidFile: non-numeric content returns ParseIntError" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "padctl.pid", .data = "notapid\n" });
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp.dir.realpath("padctl.pid", &buf);
    const result = readPidFile(allocator, path);
    try testing.expectError(error.InvalidCharacter, result);
}

test "resolvePid: explicit arg parsed directly" {
    const allocator = testing.allocator;
    const pid = try resolvePid(allocator, "9999");
    try testing.expectEqual(@as(std.posix.pid_t, 9999), pid);
}

test "isAlive: current process is alive" {
    const self = std.os.linux.getpid();
    try testing.expect(isAlive(self));
}

test "isAlive: pid 0 is not a user process (alive check via kill)" {
    // PID 1 always exists on Linux; just verify isAlive doesn't crash
    // (may return true or false depending on permissions, but must not panic)
    _ = isAlive(1);
}

test "printReply: OK goes to writer, ERR goes to err_writer" {
    var out: std.ArrayList(u8) = .{};
    defer out.deinit(testing.allocator);
    var err: std.ArrayList(u8) = .{};
    defer err.deinit(testing.allocator);

    const ok = printReply("OK reloaded 2 devices\n", out.writer(testing.allocator), err.writer(testing.allocator));
    try testing.expectEqual(SocketReload.ok, ok);
    try testing.expectEqualStrings("OK reloaded 2 devices\n", out.items);
    try testing.expectEqualStrings("", err.items);

    out.clearRetainingCapacity();
    const failed = printReply("ERR /etc/x.toml: bad", out.writer(testing.allocator), err.writer(testing.allocator));
    try testing.expectEqual(SocketReload.failed, failed);
    try testing.expectEqualStrings("", out.items);
    try testing.expectEqualStrings("ERR /etc/x.toml: bad\n", err.items);
}
