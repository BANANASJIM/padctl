const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");

pub fn run(name: []const u8, device_id: ?[]const u8, socket_path: []const u8, writer: anytype, err_writer: anytype) u8 {
    const fd = socket_client.connectToSocket(socket_path) catch {
        err_writer.writeAll("error: cannot connect to padctl daemon\n") catch {};
        return 1;
    };
    defer posix.close(fd);

    var cmd_buf: [256]u8 = undefined;
    const cmd = socket_client.formatSwitch(&cmd_buf, name, device_id);
    if (cmd.len == 0) {
        err_writer.writeAll("error: command too long\n") catch {};
        return 1;
    }

    var resp_buf: [1024]u8 = undefined;
    const resp = socket_client.sendCommand(fd, cmd, &resp_buf) catch {
        err_writer.writeAll("error: no response from daemon\n") catch {};
        return 1;
    };

    writer.writeAll(resp) catch {};
    if (resp.len == 0 or resp[resp.len - 1] != '\n') {
        writer.writeAll("\n") catch {};
    }

    return if (std.mem.startsWith(u8, resp, "OK")) 0 else 1;
}

// --- tests ---

const testing = std.testing;

test "run: connection failure returns 1" {
    const rc = run("fps", null, "/tmp/padctl-nonexistent-test.sock", std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}
