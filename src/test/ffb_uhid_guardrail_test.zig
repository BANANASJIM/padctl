const std = @import("std");
const testing = std.testing;
const device_cfg = @import("../config/device.zig");
const ffbUnavailableOverUhid = @import("../device_instance.zig").ffbUnavailableOverUhid;

test "ffbUnavailableOverUhid: use_uhid=true + rumble backend => true" {
    const ffb = device_cfg.ForceFeedbackConfig{ .backend = "uinput", .kind = "rumble" };
    try testing.expect(ffbUnavailableOverUhid(true, ffb));
}

test "ffbUnavailableOverUhid: use_uhid=true + backend=uhid kind=pid => false" {
    const ffb = device_cfg.ForceFeedbackConfig{ .backend = "uhid", .kind = "pid" };
    try testing.expect(!ffbUnavailableOverUhid(true, ffb));
}

test "ffbUnavailableOverUhid: use_uhid=false + rumble => false" {
    const ffb = device_cfg.ForceFeedbackConfig{ .backend = "uinput", .kind = "rumble" };
    try testing.expect(!ffbUnavailableOverUhid(false, ffb));
}

test "ffbUnavailableOverUhid: use_uhid=true + ffb=null => false" {
    try testing.expect(!ffbUnavailableOverUhid(true, null));
}

test "ffbUnavailableOverUhid: use_uhid=true + backend=uhid kind=rumble => true" {
    const ffb = device_cfg.ForceFeedbackConfig{ .backend = "uhid", .kind = "rumble" };
    try testing.expect(ffbUnavailableOverUhid(true, ffb));
}
