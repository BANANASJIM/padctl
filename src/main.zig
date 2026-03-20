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
    pub const ioctl_constants = @import("io/ioctl_constants.zig");
};

pub const testing_support = struct {
    pub const mock_device_io = @import("test/mock_device_io.zig");
};

pub const config = struct {
    pub const device = @import("config/device.zig");
    pub const toml = @import("config/toml.zig");
    pub const input_codes = @import("config/input_codes.zig");
};

pub const event_loop = @import("event_loop.zig");

pub fn main() !void {
    std.log.info("padctl starting...", .{});
    // T9b: CLI + config loading + device init + handshake
    // T9c: full pipeline wiring (DeviceIO → Interpreter → OutputDevice)
}

test {
    std.testing.refAllDecls(@This());
}
