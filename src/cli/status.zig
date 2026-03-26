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

    return if (std.mem.startsWith(u8, resp, "ERR")) 1 else 0;
}

// --- tests ---

const testing = std.testing;

const TestServer = struct {
    socket_path: []const u8,
    response: []const u8,

    fn run(ctx: *@This()) void {
        const listen_fd = posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch return;
        defer posix.close(listen_fd);

        var addr: std.os.linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
        @memset(&addr.path, 0);
        @memcpy(addr.path[0..ctx.socket_path.len], ctx.socket_path);
        posix.bind(listen_fd, @ptrCast(&addr), @sizeOf(std.os.linux.sockaddr.un)) catch return;
        posix.listen(listen_fd, 1) catch return;

        const client_fd = posix.accept(listen_fd, null, null, 0) catch return;
        defer posix.close(client_fd);
        _ = posix.write(client_fd, ctx.response) catch {};
    }
};

test "run: ERR response returns 1" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    var sock_path_buf: [256]u8 = undefined;
    const sock_path = try std.fmt.bufPrint(&sock_path_buf, "{s}/status.sock", .{tmp_path});

    var server = TestServer{
        .socket_path = sock_path,
        .response = "ERR daemon unavailable\n",
    };
    const thread = try std.Thread.spawn(.{}, TestServer.run, .{&server});
    defer thread.join();

    std.Thread.sleep(10 * std.time.ns_per_ms);

    const rc = run(sock_path, std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}

test "run: connection failure returns 1" {
    const rc = run("/tmp/padctl-nonexistent-test.sock", std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}
