const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");

pub fn run(socket_path: []const u8, writer: anytype, err_writer: anytype) u8 {
    const fd = socket_client.connectToSocket(socket_path) catch {
        socket_client.reportConnectFailure(err_writer, socket_path);
        return 1;
    };
    defer posix.close(fd);

    var buf: [4096]u8 = undefined;
    const resp = socket_client.sendCommand(fd, "DEVICES\n", &buf) catch {
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
    listen_fd: posix.fd_t,
    response: []const u8,

    // Bind + listen on the caller's thread so the socket file exists before the
    // client connects, eliminating the connect/bind race. The accept loop runs
    // on the spawned thread.
    fn bind(socket_path: []const u8) !posix.fd_t {
        const listen_fd = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
        errdefer posix.close(listen_fd);

        var addr: std.os.linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
        @memset(&addr.path, 0);
        @memcpy(addr.path[0..socket_path.len], socket_path);
        try posix.bind(listen_fd, @ptrCast(&addr), @sizeOf(std.os.linux.sockaddr.un));
        try posix.listen(listen_fd, 1);
        return listen_fd;
    }

    fn run(ctx: *@This()) void {
        defer posix.close(ctx.listen_fd);
        const client_fd = posix.accept(ctx.listen_fd, null, null, 0) catch return;
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
    const sock_path = try std.fmt.bufPrint(&sock_path_buf, "{s}/devices.sock", .{tmp_path});

    var server = TestServer{
        .listen_fd = try TestServer.bind(sock_path),
        .response = "ERR device unavailable\n",
    };
    const thread = try std.Thread.spawn(.{}, TestServer.run, .{&server});
    defer thread.join();

    const rc = run(sock_path, std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}

test "run: connection failure returns 1" {
    const rc = run("/tmp/padctl-nonexistent-test.sock", std.io.null_writer, std.io.null_writer);
    try testing.expectEqual(@as(u8, 1), rc);
}
