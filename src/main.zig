const std = @import("std");

pub const core = struct {
    pub const state = @import("core/state.zig");
    pub const interpreter = @import("core/interpreter.zig");
};

pub const io = struct {
    pub const device_io = @import("io/device_io.zig");
    pub const hidraw = @import("io/hidraw.zig");
    pub const usbraw = @import("io/usbraw.zig");
    pub const uinput = @import("io/uinput.zig");
};

pub const config = struct {
    pub const device = @import("config/device.zig");
    pub const toml = @import("config/toml.zig");
    pub const input_codes = @import("config/input_codes.zig");
};

pub fn main() !void {
    std.log.info("padctl starting...", .{});
}

test {
    std.testing.refAllDecls(@This());
}
