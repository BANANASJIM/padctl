const std = @import("std");
const posix = std.posix;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;

/// Mock DeviceIO for Layer 1 tests.
/// - read(): returns pre-recorded frames in order; returns Again when exhausted.
/// - write(): appends data to write_log.
/// - pollfd(): returns pipe_r; write 1 byte to pipe_w to trigger readiness.
/// - close(): no-op.
pub const MockDeviceIO = struct {
    frames: []const []const u8,
    frame_idx: usize,
    allocator: std.mem.Allocator,
    write_log: std.ArrayList(u8),
    pipe_r: posix.fd_t,
    pipe_w: posix.fd_t,
    disconnected: bool,

    pub fn init(allocator: std.mem.Allocator, frames: []const []const u8) !MockDeviceIO {
        var fds: [2]posix.fd_t = undefined;
        // socketpair(AF_UNIX, SOCK_SEQPACKET, 0) for message-boundary semantics
        const rc = std.os.linux.socketpair(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.SEQPACKET | std.os.linux.SOCK.NONBLOCK,
            0,
            &fds,
        );
        if (rc != 0) return error.SocketPairFailed;
        return .{
            .frames = frames,
            .frame_idx = 0,
            .allocator = allocator,
            .write_log = .{},
            .pipe_r = fds[0],
            .pipe_w = fds[1],
            .disconnected = false,
        };
    }

    pub fn deinit(self: *MockDeviceIO) void {
        self.write_log.deinit(self.allocator);
        posix.close(self.pipe_r);
        posix.close(self.pipe_w);
    }

    /// Signal the pipe_r side as readable (triggers ppoll).
    pub fn signal(self: *MockDeviceIO) !void {
        _ = try posix.write(self.pipe_w, &[_]u8{1});
    }

    /// Cause the next read to return Disconnected.
    pub fn injectDisconnect(self: *MockDeviceIO) !void {
        self.disconnected = true;
        _ = try posix.write(self.pipe_w, &[_]u8{1});
    }

    pub fn deviceIO(self: *MockDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *MockDeviceIO = @ptrCast(@alignCast(ptr));
        if (self.disconnected) return DeviceIO.ReadError.Disconnected;
        if (self.frame_idx >= self.frames.len) return DeviceIO.ReadError.Again;
        const frame = self.frames[self.frame_idx];
        self.frame_idx += 1;
        const n = @min(buf.len, frame.len);
        @memcpy(buf[0..n], frame[0..n]);
        return n;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *MockDeviceIO = @ptrCast(@alignCast(ptr));
        self.write_log.appendSlice(self.allocator, data) catch return DeviceIO.WriteError.Io;
    }

    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *MockDeviceIO = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.pipe_r, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

// --- tests ---

test "MockDeviceIO read returns frames in order then Again" {
    const allocator = std.testing.allocator;
    const frame1 = &[_]u8{ 0x5a, 0xa5, 0xef };
    const frame2 = &[_]u8{ 0x01, 0x02 };
    var mock = try MockDeviceIO.init(allocator, &.{ frame1, frame2 });
    defer mock.deinit();

    const io = mock.deviceIO();
    var buf: [64]u8 = undefined;

    const n1 = try io.read(&buf);
    try std.testing.expectEqual(@as(usize, 3), n1);
    try std.testing.expectEqualSlices(u8, frame1, buf[0..3]);

    const n2 = try io.read(&buf);
    try std.testing.expectEqual(@as(usize, 2), n2);
    try std.testing.expectEqualSlices(u8, frame2, buf[0..2]);

    try std.testing.expectError(DeviceIO.ReadError.Again, io.read(&buf));
}

test "MockDeviceIO write logs data" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    try io.write(&[_]u8{ 0x01, 0x02, 0x03 });
    try io.write(&[_]u8{0x04});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x02, 0x03, 0x04 }, mock.write_log.items);
}

test "MockDeviceIO pollfd returns pipe_r" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    const pfd = io.pollfd();
    try std.testing.expectEqual(mock.pipe_r, pfd.fd);
    try std.testing.expectEqual(posix.POLL.IN, pfd.events);
}

test "MockDeviceIO signal makes pipe_r readable" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    try mock.signal();

    var pfd = [1]posix.pollfd{.{ .fd = mock.pipe_r, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try std.testing.expectEqual(@as(usize, 1), ready);
}

test "MockDeviceIO injectDisconnect returns Disconnected" {
    const allocator = std.testing.allocator;
    const frame = &[_]u8{0x01};
    var mock = try MockDeviceIO.init(allocator, &.{frame});
    defer mock.deinit();

    try mock.injectDisconnect();

    const io = mock.deviceIO();
    var buf: [64]u8 = undefined;
    try std.testing.expectError(DeviceIO.ReadError.Disconnected, io.read(&buf));
    // Stays disconnected on subsequent reads
    try std.testing.expectError(DeviceIO.ReadError.Disconnected, io.read(&buf));
}
