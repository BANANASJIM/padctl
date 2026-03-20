const std = @import("std");

const c = @cImport({
    @cInclude("linux/input-event-codes.h");
});

const CodeEntry = struct { name: []const u8, code: u16 };

const abs_table = [_]CodeEntry{
    .{ .name = "ABS_X", .code = c.ABS_X },
    .{ .name = "ABS_Y", .code = c.ABS_Y },
    .{ .name = "ABS_Z", .code = c.ABS_Z },
    .{ .name = "ABS_RX", .code = c.ABS_RX },
    .{ .name = "ABS_RY", .code = c.ABS_RY },
    .{ .name = "ABS_RZ", .code = c.ABS_RZ },
    .{ .name = "ABS_THROTTLE", .code = c.ABS_THROTTLE },
    .{ .name = "ABS_RUDDER", .code = c.ABS_RUDDER },
    .{ .name = "ABS_WHEEL", .code = c.ABS_WHEEL },
    .{ .name = "ABS_GAS", .code = c.ABS_GAS },
    .{ .name = "ABS_BRAKE", .code = c.ABS_BRAKE },
    .{ .name = "ABS_HAT0X", .code = c.ABS_HAT0X },
    .{ .name = "ABS_HAT0Y", .code = c.ABS_HAT0Y },
    .{ .name = "ABS_HAT1X", .code = c.ABS_HAT1X },
    .{ .name = "ABS_HAT1Y", .code = c.ABS_HAT1Y },
    .{ .name = "ABS_HAT2X", .code = c.ABS_HAT2X },
    .{ .name = "ABS_HAT2Y", .code = c.ABS_HAT2Y },
    .{ .name = "ABS_HAT3X", .code = c.ABS_HAT3X },
    .{ .name = "ABS_HAT3Y", .code = c.ABS_HAT3Y },
    .{ .name = "ABS_PRESSURE", .code = c.ABS_PRESSURE },
    .{ .name = "ABS_DISTANCE", .code = c.ABS_DISTANCE },
    .{ .name = "ABS_TILT_X", .code = c.ABS_TILT_X },
    .{ .name = "ABS_TILT_Y", .code = c.ABS_TILT_Y },
    .{ .name = "ABS_TOOL_WIDTH", .code = c.ABS_TOOL_WIDTH },
    .{ .name = "ABS_VOLUME", .code = c.ABS_VOLUME },
    .{ .name = "ABS_MISC", .code = c.ABS_MISC },
    .{ .name = "ABS_MT_SLOT", .code = c.ABS_MT_SLOT },
    .{ .name = "ABS_MT_TOUCH_MAJOR", .code = c.ABS_MT_TOUCH_MAJOR },
    .{ .name = "ABS_MT_TOUCH_MINOR", .code = c.ABS_MT_TOUCH_MINOR },
    .{ .name = "ABS_MT_WIDTH_MAJOR", .code = c.ABS_MT_WIDTH_MAJOR },
    .{ .name = "ABS_MT_WIDTH_MINOR", .code = c.ABS_MT_WIDTH_MINOR },
    .{ .name = "ABS_MT_ORIENTATION", .code = c.ABS_MT_ORIENTATION },
    .{ .name = "ABS_MT_POSITION_X", .code = c.ABS_MT_POSITION_X },
    .{ .name = "ABS_MT_POSITION_Y", .code = c.ABS_MT_POSITION_Y },
    .{ .name = "ABS_MT_TOOL_TYPE", .code = c.ABS_MT_TOOL_TYPE },
    .{ .name = "ABS_MT_BLOB_ID", .code = c.ABS_MT_BLOB_ID },
    .{ .name = "ABS_MT_TRACKING_ID", .code = c.ABS_MT_TRACKING_ID },
    .{ .name = "ABS_MT_PRESSURE", .code = c.ABS_MT_PRESSURE },
    .{ .name = "ABS_MT_DISTANCE", .code = c.ABS_MT_DISTANCE },
    .{ .name = "ABS_MT_TOOL_X", .code = c.ABS_MT_TOOL_X },
    .{ .name = "ABS_MT_TOOL_Y", .code = c.ABS_MT_TOOL_Y },
};

const btn_table = [_]CodeEntry{
    .{ .name = "BTN_MISC", .code = c.BTN_MISC },
    .{ .name = "BTN_0", .code = c.BTN_0 },
    .{ .name = "BTN_1", .code = c.BTN_1 },
    .{ .name = "BTN_2", .code = c.BTN_2 },
    .{ .name = "BTN_3", .code = c.BTN_3 },
    .{ .name = "BTN_4", .code = c.BTN_4 },
    .{ .name = "BTN_5", .code = c.BTN_5 },
    .{ .name = "BTN_6", .code = c.BTN_6 },
    .{ .name = "BTN_7", .code = c.BTN_7 },
    .{ .name = "BTN_8", .code = c.BTN_8 },
    .{ .name = "BTN_9", .code = c.BTN_9 },
    .{ .name = "BTN_MOUSE", .code = c.BTN_MOUSE },
    .{ .name = "BTN_LEFT", .code = c.BTN_LEFT },
    .{ .name = "BTN_RIGHT", .code = c.BTN_RIGHT },
    .{ .name = "BTN_MIDDLE", .code = c.BTN_MIDDLE },
    .{ .name = "BTN_SIDE", .code = c.BTN_SIDE },
    .{ .name = "BTN_EXTRA", .code = c.BTN_EXTRA },
    .{ .name = "BTN_FORWARD", .code = c.BTN_FORWARD },
    .{ .name = "BTN_BACK", .code = c.BTN_BACK },
    .{ .name = "BTN_TASK", .code = c.BTN_TASK },
    .{ .name = "BTN_JOYSTICK", .code = c.BTN_JOYSTICK },
    .{ .name = "BTN_TRIGGER", .code = c.BTN_TRIGGER },
    .{ .name = "BTN_THUMB", .code = c.BTN_THUMB },
    .{ .name = "BTN_THUMB2", .code = c.BTN_THUMB2 },
    .{ .name = "BTN_TOP", .code = c.BTN_TOP },
    .{ .name = "BTN_TOP2", .code = c.BTN_TOP2 },
    .{ .name = "BTN_PINKIE", .code = c.BTN_PINKIE },
    .{ .name = "BTN_BASE", .code = c.BTN_BASE },
    .{ .name = "BTN_BASE2", .code = c.BTN_BASE2 },
    .{ .name = "BTN_BASE3", .code = c.BTN_BASE3 },
    .{ .name = "BTN_BASE4", .code = c.BTN_BASE4 },
    .{ .name = "BTN_BASE5", .code = c.BTN_BASE5 },
    .{ .name = "BTN_BASE6", .code = c.BTN_BASE6 },
    .{ .name = "BTN_DEAD", .code = c.BTN_DEAD },
    .{ .name = "BTN_GAMEPAD", .code = c.BTN_GAMEPAD },
    .{ .name = "BTN_SOUTH", .code = c.BTN_SOUTH },
    .{ .name = "BTN_A", .code = c.BTN_SOUTH },
    .{ .name = "BTN_EAST", .code = c.BTN_EAST },
    .{ .name = "BTN_B", .code = c.BTN_EAST },
    .{ .name = "BTN_C", .code = c.BTN_C },
    .{ .name = "BTN_NORTH", .code = c.BTN_NORTH },
    .{ .name = "BTN_X", .code = c.BTN_NORTH },
    .{ .name = "BTN_WEST", .code = c.BTN_WEST },
    .{ .name = "BTN_Y", .code = c.BTN_WEST },
    .{ .name = "BTN_Z", .code = c.BTN_Z },
    .{ .name = "BTN_TL", .code = c.BTN_TL },
    .{ .name = "BTN_TR", .code = c.BTN_TR },
    .{ .name = "BTN_TL2", .code = c.BTN_TL2 },
    .{ .name = "BTN_TR2", .code = c.BTN_TR2 },
    .{ .name = "BTN_SELECT", .code = c.BTN_SELECT },
    .{ .name = "BTN_START", .code = c.BTN_START },
    .{ .name = "BTN_MODE", .code = c.BTN_MODE },
    .{ .name = "BTN_THUMBL", .code = c.BTN_THUMBL },
    .{ .name = "BTN_THUMBR", .code = c.BTN_THUMBR },
    .{ .name = "BTN_DPAD_UP", .code = c.BTN_DPAD_UP },
    .{ .name = "BTN_DPAD_DOWN", .code = c.BTN_DPAD_DOWN },
    .{ .name = "BTN_DPAD_LEFT", .code = c.BTN_DPAD_LEFT },
    .{ .name = "BTN_DPAD_RIGHT", .code = c.BTN_DPAD_RIGHT },
    .{ .name = "BTN_TRIGGER_HAPPY", .code = c.BTN_TRIGGER_HAPPY },
    .{ .name = "BTN_TRIGGER_HAPPY1", .code = c.BTN_TRIGGER_HAPPY1 },
    .{ .name = "BTN_TRIGGER_HAPPY2", .code = c.BTN_TRIGGER_HAPPY2 },
    .{ .name = "BTN_TRIGGER_HAPPY3", .code = c.BTN_TRIGGER_HAPPY3 },
    .{ .name = "BTN_TRIGGER_HAPPY4", .code = c.BTN_TRIGGER_HAPPY4 },
    .{ .name = "BTN_TRIGGER_HAPPY5", .code = c.BTN_TRIGGER_HAPPY5 },
    .{ .name = "BTN_TRIGGER_HAPPY6", .code = c.BTN_TRIGGER_HAPPY6 },
    .{ .name = "BTN_TRIGGER_HAPPY7", .code = c.BTN_TRIGGER_HAPPY7 },
    .{ .name = "BTN_TRIGGER_HAPPY8", .code = c.BTN_TRIGGER_HAPPY8 },
    .{ .name = "BTN_TRIGGER_HAPPY9", .code = c.BTN_TRIGGER_HAPPY9 },
    .{ .name = "BTN_TRIGGER_HAPPY10", .code = c.BTN_TRIGGER_HAPPY10 },
    .{ .name = "BTN_TRIGGER_HAPPY11", .code = c.BTN_TRIGGER_HAPPY11 },
    .{ .name = "BTN_TRIGGER_HAPPY12", .code = c.BTN_TRIGGER_HAPPY12 },
    .{ .name = "BTN_TRIGGER_HAPPY13", .code = c.BTN_TRIGGER_HAPPY13 },
    .{ .name = "BTN_TRIGGER_HAPPY14", .code = c.BTN_TRIGGER_HAPPY14 },
    .{ .name = "BTN_TRIGGER_HAPPY15", .code = c.BTN_TRIGGER_HAPPY15 },
    .{ .name = "BTN_TRIGGER_HAPPY16", .code = c.BTN_TRIGGER_HAPPY16 },
    .{ .name = "BTN_TRIGGER_HAPPY17", .code = c.BTN_TRIGGER_HAPPY17 },
    .{ .name = "BTN_TRIGGER_HAPPY18", .code = c.BTN_TRIGGER_HAPPY18 },
    .{ .name = "BTN_TRIGGER_HAPPY19", .code = c.BTN_TRIGGER_HAPPY19 },
    .{ .name = "BTN_TRIGGER_HAPPY20", .code = c.BTN_TRIGGER_HAPPY20 },
    .{ .name = "BTN_TRIGGER_HAPPY21", .code = c.BTN_TRIGGER_HAPPY21 },
    .{ .name = "BTN_TRIGGER_HAPPY22", .code = c.BTN_TRIGGER_HAPPY22 },
    .{ .name = "BTN_TRIGGER_HAPPY23", .code = c.BTN_TRIGGER_HAPPY23 },
    .{ .name = "BTN_TRIGGER_HAPPY24", .code = c.BTN_TRIGGER_HAPPY24 },
    .{ .name = "BTN_TRIGGER_HAPPY25", .code = c.BTN_TRIGGER_HAPPY25 },
    .{ .name = "BTN_TRIGGER_HAPPY26", .code = c.BTN_TRIGGER_HAPPY26 },
    .{ .name = "BTN_TRIGGER_HAPPY27", .code = c.BTN_TRIGGER_HAPPY27 },
    .{ .name = "BTN_TRIGGER_HAPPY28", .code = c.BTN_TRIGGER_HAPPY28 },
    .{ .name = "BTN_TRIGGER_HAPPY29", .code = c.BTN_TRIGGER_HAPPY29 },
    .{ .name = "BTN_TRIGGER_HAPPY30", .code = c.BTN_TRIGGER_HAPPY30 },
    .{ .name = "BTN_TRIGGER_HAPPY31", .code = c.BTN_TRIGGER_HAPPY31 },
    .{ .name = "BTN_TRIGGER_HAPPY32", .code = c.BTN_TRIGGER_HAPPY32 },
    .{ .name = "BTN_TRIGGER_HAPPY33", .code = c.BTN_TRIGGER_HAPPY33 },
    .{ .name = "BTN_TRIGGER_HAPPY34", .code = c.BTN_TRIGGER_HAPPY34 },
    .{ .name = "BTN_TRIGGER_HAPPY35", .code = c.BTN_TRIGGER_HAPPY35 },
    .{ .name = "BTN_TRIGGER_HAPPY36", .code = c.BTN_TRIGGER_HAPPY36 },
    .{ .name = "BTN_TRIGGER_HAPPY37", .code = c.BTN_TRIGGER_HAPPY37 },
    .{ .name = "BTN_TRIGGER_HAPPY38", .code = c.BTN_TRIGGER_HAPPY38 },
    .{ .name = "BTN_TRIGGER_HAPPY39", .code = c.BTN_TRIGGER_HAPPY39 },
    .{ .name = "BTN_TRIGGER_HAPPY40", .code = c.BTN_TRIGGER_HAPPY40 },
};

pub fn resolveAbsCode(name: []const u8) error{UnknownAbsCode}!u16 {
    for (abs_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.code;
    }
    return error.UnknownAbsCode;
}

pub fn resolveBtnCode(name: []const u8) error{UnknownBtnCode}!u16 {
    for (btn_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.code;
    }
    return error.UnknownBtnCode;
}

test "resolveAbsCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x00), try resolveAbsCode("ABS_X"));
    try std.testing.expectEqual(@as(u16, 0x01), try resolveAbsCode("ABS_Y"));
    try std.testing.expectEqual(@as(u16, 0x03), try resolveAbsCode("ABS_RX"));
    try std.testing.expectEqual(@as(u16, 0x10), try resolveAbsCode("ABS_HAT0X"));
    try std.testing.expectEqual(@as(u16, 0x11), try resolveAbsCode("ABS_HAT0Y"));
}

test "resolveAbsCode: unknown returns error" {
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode("INVALID"));
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode(""));
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode("BTN_SOUTH"));
}

test "resolveBtnCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x130), try resolveBtnCode("BTN_SOUTH"));
    try std.testing.expectEqual(@as(u16, 0x131), try resolveBtnCode("BTN_EAST"));
    try std.testing.expectEqual(@as(u16, 0x133), try resolveBtnCode("BTN_NORTH"));
    try std.testing.expectEqual(@as(u16, 0x134), try resolveBtnCode("BTN_WEST"));
    try std.testing.expectEqual(@as(u16, 0x13a), try resolveBtnCode("BTN_SELECT"));
    try std.testing.expectEqual(@as(u16, 0x13b), try resolveBtnCode("BTN_START"));
    try std.testing.expectEqual(@as(u16, 0x2c2), try resolveBtnCode("BTN_TRIGGER_HAPPY3"));
}

test "resolveBtnCode: unknown returns error" {
    try std.testing.expectError(error.UnknownBtnCode, resolveBtnCode("INVALID"));
    try std.testing.expectError(error.UnknownBtnCode, resolveBtnCode("ABS_X"));
}
