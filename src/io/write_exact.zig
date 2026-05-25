const std = @import("std");
const posix = std.posix;

pub const WriteExactError = posix.WriteError || error{ShortWrite};

pub fn writeExact(fd: posix.fd_t, bytes: []const u8) WriteExactError!void {
    const n = try posix.write(fd, bytes);
    if (n != bytes.len) return error.ShortWrite;
}

pub fn writeExactWith(
    ctx: anytype,
    comptime writeFn: fn (@TypeOf(ctx), []const u8) WriteExactError!usize,
    bytes: []const u8,
) WriteExactError!void {
    const n = try writeFn(ctx, bytes);
    if (n != bytes.len) return error.ShortWrite;
}

const testing = std.testing;

const TestWriter = struct {
    result: union(enum) {
        bytes: usize,
        err: WriteExactError,
    },

    fn write(self: *TestWriter, bytes: []const u8) WriteExactError!usize {
        return switch (self.result) {
            .bytes => |n| @min(n, bytes.len),
            .err => |err| err,
        };
    }
};

test "writeExactWith succeeds on full write" {
    var writer = TestWriter{ .result = .{ .bytes = 3 } };
    try writeExactWith(&writer, TestWriter.write, "abc");
}

test "writeExactWith rejects short write" {
    var writer = TestWriter{ .result = .{ .bytes = 2 } };
    try testing.expectError(error.ShortWrite, writeExactWith(&writer, TestWriter.write, "abc"));
}

test "writeExactWith rejects zero write" {
    var writer = TestWriter{ .result = .{ .bytes = 0 } };
    try testing.expectError(error.ShortWrite, writeExactWith(&writer, TestWriter.write, "abc"));
}

test "writeExactWith propagates write errors" {
    var writer = TestWriter{ .result = .{ .err = error.WouldBlock } };
    try testing.expectError(error.WouldBlock, writeExactWith(&writer, TestWriter.write, "abc"));
}
