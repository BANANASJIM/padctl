const std = @import("std");
const posix = std.posix;

pub const WriteExactError = posix.WriteError || error{ShortWrite};

pub fn writeExact(fd: posix.fd_t, bytes: []const u8) WriteExactError!void {
    const n = try posix.write(fd, bytes);
    if (n != bytes.len) return error.ShortWrite;
}
