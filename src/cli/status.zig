const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");

pub fn run(socket_path: []const u8, writer: anytype, err_writer: anytype) u8 {
    const fd = socket_client.connectToSocket(socket_path) catch {
        err_writer.writeAll("error: cannot connect to padctl daemon\n") catch {};
        return 1;
    };
    defer posix.close(fd);

    var buf: [4096]u8 = undefined;
    const resp = socket_client.sendCommand(fd, "STATUS\n", &buf) catch {
        err_writer.writeAll("error: no response from daemon\n") catch {};
        return 1;
    };

    writer.writeAll(resp) catch {};
    if (resp.len == 0 or resp[resp.len - 1] != '\n') {
        writer.writeAll("\n") catch {};
    }

    return if (std.mem.startsWith(u8, resp, "ERROR")) 1 else 0;
}

// --- tests ---

const testing = std.testing;

test "run: connection failure returns 1" {
    const rc = run("/tmp/padctl-nonexistent-test.sock", std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}
