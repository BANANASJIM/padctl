const std = @import("std");

pub const config = @import("config/toml.zig");

pub fn main() !void {
    std.log.info("padctl starting...", .{});
}

test {
    std.testing.refAllDecls(@This());
}
