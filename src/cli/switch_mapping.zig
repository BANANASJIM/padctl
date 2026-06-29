const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");
const error_hint = @import("error_hint.zig");
const mapping_discovery = @import("../config/mapping_discovery.zig");

pub const Outcome = enum { ok, no_devices, failed };

pub fn classify(resp: []const u8) Outcome {
    if (std.mem.startsWith(u8, resp, "OK")) return .ok;
    if (error_hint.errorCode(resp)) |code| {
        if (std.mem.eql(u8, code, "no-devices")) return .no_devices;
    }
    return .failed;
}

pub fn run(allocator: std.mem.Allocator, name: []const u8, device_id: ?[]const u8, socket_path: []const u8, writer: anytype, err_writer: anytype) Outcome {
    const fd = socket_client.connectToSocket(socket_path) catch {
        socket_client.reportConnectFailure(err_writer, socket_path);
        return .failed;
    };
    defer posix.close(fd);

    // Resolve mapping path client-side so the user's ~/.config/padctl/mappings/
    // takes priority over /etc/padctl/mappings/. Send the full path to the daemon
    // which accepts both names and absolute paths.
    const resolved = mapping_discovery.findMapping(allocator, name) catch null;
    defer if (resolved) |p| allocator.free(p);
    const switch_name = resolved orelse name;

    var cmd_buf: [512]u8 = undefined;
    const cmd = socket_client.formatSwitch(&cmd_buf, switch_name, device_id);
    if (cmd.len == 0) {
        err_writer.writeAll("error: command too long\n") catch {};
        return .failed;
    }

    var resp_buf: [1024]u8 = undefined;
    const resp = socket_client.sendCommand(fd, cmd, &resp_buf) catch {
        err_writer.writeAll("error: no response from daemon\n") catch {};
        return .failed;
    };

    const outcome = classify(resp);
    switch (outcome) {
        .ok => {
            writer.writeAll(resp) catch {};
            if (resp.len == 0 or resp[resp.len - 1] != '\n') writer.writeAll("\n") catch {};
        },
        .no_devices => {},
        .failed => error_hint.report(err_writer, resp, name),
    }
    return outcome;
}

// --- tests ---

const testing = std.testing;

test "run: connection failure returns failed" {
    const rc = run(testing.allocator, "fps", null, "/tmp/padctl-nonexistent-test.sock", std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(Outcome.failed, rc);
}

test "classify: ok, no_devices, failed" {
    try testing.expectEqual(Outcome.ok, classify("OK fps\n"));
    try testing.expectEqual(Outcome.ok, classify("OK\n"));
    try testing.expectEqual(Outcome.no_devices, classify("ERR no-devices\n"));
    try testing.expectEqual(Outcome.failed, classify("ERR mapping-not-found\n"));
}
