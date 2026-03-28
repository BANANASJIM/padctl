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
    .{ .name = "BTN_GEAR_DOWN", .code = c.BTN_GEAR_DOWN },
    .{ .name = "BTN_GEAR_UP", .code = c.BTN_GEAR_UP },
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
    // Touch/stylus
    .{ .name = "BTN_TOOL_PEN", .code = c.BTN_TOOL_PEN },
    .{ .name = "BTN_TOOL_RUBBER", .code = c.BTN_TOOL_RUBBER },
    .{ .name = "BTN_TOOL_BRUSH", .code = c.BTN_TOOL_BRUSH },
    .{ .name = "BTN_TOOL_PENCIL", .code = c.BTN_TOOL_PENCIL },
    .{ .name = "BTN_TOOL_AIRBRUSH", .code = c.BTN_TOOL_AIRBRUSH },
    .{ .name = "BTN_TOOL_FINGER", .code = c.BTN_TOOL_FINGER },
    .{ .name = "BTN_TOOL_MOUSE", .code = c.BTN_TOOL_MOUSE },
    .{ .name = "BTN_TOOL_LENS", .code = c.BTN_TOOL_LENS },
    .{ .name = "BTN_TOOL_QUINTTAP", .code = c.BTN_TOOL_QUINTTAP },
    .{ .name = "BTN_TOUCH", .code = c.BTN_TOUCH },
    .{ .name = "BTN_TOOL_DOUBLETAP", .code = c.BTN_TOOL_DOUBLETAP },
    .{ .name = "BTN_TOOL_TRIPLETAP", .code = c.BTN_TOOL_TRIPLETAP },
    .{ .name = "BTN_TOOL_QUADTAP", .code = c.BTN_TOOL_QUADTAP },
};

const key_table = [_]CodeEntry{
    .{ .name = "KEY_ESC", .code = c.KEY_ESC },
    .{ .name = "KEY_1", .code = c.KEY_1 },
    .{ .name = "KEY_2", .code = c.KEY_2 },
    .{ .name = "KEY_3", .code = c.KEY_3 },
    .{ .name = "KEY_4", .code = c.KEY_4 },
    .{ .name = "KEY_5", .code = c.KEY_5 },
    .{ .name = "KEY_6", .code = c.KEY_6 },
    .{ .name = "KEY_7", .code = c.KEY_7 },
    .{ .name = "KEY_8", .code = c.KEY_8 },
    .{ .name = "KEY_9", .code = c.KEY_9 },
    .{ .name = "KEY_0", .code = c.KEY_0 },
    .{ .name = "KEY_MINUS", .code = c.KEY_MINUS },
    .{ .name = "KEY_EQUAL", .code = c.KEY_EQUAL },
    .{ .name = "KEY_BACKSPACE", .code = c.KEY_BACKSPACE },
    .{ .name = "KEY_TAB", .code = c.KEY_TAB },
    .{ .name = "KEY_Q", .code = c.KEY_Q },
    .{ .name = "KEY_W", .code = c.KEY_W },
    .{ .name = "KEY_E", .code = c.KEY_E },
    .{ .name = "KEY_R", .code = c.KEY_R },
    .{ .name = "KEY_T", .code = c.KEY_T },
    .{ .name = "KEY_Y", .code = c.KEY_Y },
    .{ .name = "KEY_U", .code = c.KEY_U },
    .{ .name = "KEY_I", .code = c.KEY_I },
    .{ .name = "KEY_O", .code = c.KEY_O },
    .{ .name = "KEY_P", .code = c.KEY_P },
    .{ .name = "KEY_A", .code = c.KEY_A },
    .{ .name = "KEY_S", .code = c.KEY_S },
    .{ .name = "KEY_D", .code = c.KEY_D },
    .{ .name = "KEY_F", .code = c.KEY_F },
    .{ .name = "KEY_G", .code = c.KEY_G },
    .{ .name = "KEY_H", .code = c.KEY_H },
    .{ .name = "KEY_J", .code = c.KEY_J },
    .{ .name = "KEY_K", .code = c.KEY_K },
    .{ .name = "KEY_L", .code = c.KEY_L },
    .{ .name = "KEY_Z", .code = c.KEY_Z },
    .{ .name = "KEY_X", .code = c.KEY_X },
    .{ .name = "KEY_C", .code = c.KEY_C },
    .{ .name = "KEY_V", .code = c.KEY_V },
    .{ .name = "KEY_B", .code = c.KEY_B },
    .{ .name = "KEY_N", .code = c.KEY_N },
    .{ .name = "KEY_M", .code = c.KEY_M },
    .{ .name = "KEY_ENTER", .code = c.KEY_ENTER },
    .{ .name = "KEY_LEFTCTRL", .code = c.KEY_LEFTCTRL },
    .{ .name = "KEY_RIGHTCTRL", .code = c.KEY_RIGHTCTRL },
    .{ .name = "KEY_LEFTSHIFT", .code = c.KEY_LEFTSHIFT },
    .{ .name = "KEY_RIGHTSHIFT", .code = c.KEY_RIGHTSHIFT },
    .{ .name = "KEY_LEFTALT", .code = c.KEY_LEFTALT },
    .{ .name = "KEY_RIGHTALT", .code = c.KEY_RIGHTALT },
    .{ .name = "KEY_LEFTMETA", .code = c.KEY_LEFTMETA },
    .{ .name = "KEY_RIGHTMETA", .code = c.KEY_RIGHTMETA },
    .{ .name = "KEY_SPACE", .code = c.KEY_SPACE },
    .{ .name = "KEY_CAPSLOCK", .code = c.KEY_CAPSLOCK },
    .{ .name = "KEY_F1", .code = c.KEY_F1 },
    .{ .name = "KEY_F2", .code = c.KEY_F2 },
    .{ .name = "KEY_F3", .code = c.KEY_F3 },
    .{ .name = "KEY_F4", .code = c.KEY_F4 },
    .{ .name = "KEY_F5", .code = c.KEY_F5 },
    .{ .name = "KEY_F6", .code = c.KEY_F6 },
    .{ .name = "KEY_F7", .code = c.KEY_F7 },
    .{ .name = "KEY_F8", .code = c.KEY_F8 },
    .{ .name = "KEY_F9", .code = c.KEY_F9 },
    .{ .name = "KEY_F10", .code = c.KEY_F10 },
    .{ .name = "KEY_F11", .code = c.KEY_F11 },
    .{ .name = "KEY_F12", .code = c.KEY_F12 },
    .{ .name = "KEY_F13", .code = c.KEY_F13 },
    .{ .name = "KEY_F14", .code = c.KEY_F14 },
    .{ .name = "KEY_F15", .code = c.KEY_F15 },
    .{ .name = "KEY_F16", .code = c.KEY_F16 },
    .{ .name = "KEY_F17", .code = c.KEY_F17 },
    .{ .name = "KEY_F18", .code = c.KEY_F18 },
    .{ .name = "KEY_F19", .code = c.KEY_F19 },
    .{ .name = "KEY_F20", .code = c.KEY_F20 },
    .{ .name = "KEY_F21", .code = c.KEY_F21 },
    .{ .name = "KEY_F22", .code = c.KEY_F22 },
    .{ .name = "KEY_F23", .code = c.KEY_F23 },
    .{ .name = "KEY_F24", .code = c.KEY_F24 },
    .{ .name = "KEY_UP", .code = c.KEY_UP },
    .{ .name = "KEY_DOWN", .code = c.KEY_DOWN },
    .{ .name = "KEY_LEFT", .code = c.KEY_LEFT },
    .{ .name = "KEY_RIGHT", .code = c.KEY_RIGHT },
    .{ .name = "KEY_HOME", .code = c.KEY_HOME },
    .{ .name = "KEY_END", .code = c.KEY_END },
    .{ .name = "KEY_PAGEUP", .code = c.KEY_PAGEUP },
    .{ .name = "KEY_PAGEDOWN", .code = c.KEY_PAGEDOWN },
    .{ .name = "KEY_INSERT", .code = c.KEY_INSERT },
    .{ .name = "KEY_DELETE", .code = c.KEY_DELETE },
    .{ .name = "KEY_PRINT", .code = c.KEY_PRINT },
    .{ .name = "KEY_SCROLLLOCK", .code = c.KEY_SCROLLLOCK },
    .{ .name = "KEY_PAUSE", .code = c.KEY_PAUSE },
    .{ .name = "KEY_NUMLOCK", .code = c.KEY_NUMLOCK },
    .{ .name = "KEY_MUTE", .code = c.KEY_MUTE },
    .{ .name = "KEY_VOLUMEDOWN", .code = c.KEY_VOLUMEDOWN },
    .{ .name = "KEY_VOLUMEUP", .code = c.KEY_VOLUMEUP },
    .{ .name = "KEY_MEDIA_PLAY_PAUSE", .code = c.KEY_PLAYPAUSE },
    .{ .name = "KEY_PLAYPAUSE", .code = c.KEY_PLAYPAUSE },
    .{ .name = "KEY_NEXTSONG", .code = c.KEY_NEXTSONG },
    .{ .name = "KEY_PREVIOUSSONG", .code = c.KEY_PREVIOUSSONG },
};

// Mouse button shortcuts (vader5 compat)
const mouse_table = [_]CodeEntry{
    .{ .name = "mouse_left", .code = c.BTN_LEFT },
    .{ .name = "mouse_right", .code = c.BTN_RIGHT },
    .{ .name = "mouse_middle", .code = c.BTN_MIDDLE },
    .{ .name = "mouse_side", .code = c.BTN_SIDE },
    .{ .name = "mouse_extra", .code = c.BTN_EXTRA },
    .{ .name = "mouse_forward", .code = c.BTN_FORWARD },
    .{ .name = "mouse_back", .code = c.BTN_BACK },
};

pub fn resolveKeyCode(name: []const u8) error{UnknownKeyCode}!u16 {
    for (key_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.code;
    }
    return error.UnknownKeyCode;
}

pub fn resolveMouseCode(name: []const u8) error{UnknownMouseCode}!u16 {
    for (mouse_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.code;
    }
    return error.UnknownMouseCode;
}

pub const ResolvedEvent = struct {
    event_type: u16,
    event_code: u16,
};

pub fn resolveEventCode(name: []const u8) error{UnknownEventCode}!ResolvedEvent {
    if (std.mem.startsWith(u8, name, "ABS_")) {
        return .{ .event_type = c.EV_ABS, .event_code = resolveAbsCode(name) catch return error.UnknownEventCode };
    }
    if (std.mem.startsWith(u8, name, "BTN_") or std.mem.startsWith(u8, name, "KEY_")) {
        const code = resolveBtnCode(name) catch resolveKeyCode(name) catch return error.UnknownEventCode;
        return .{ .event_type = c.EV_KEY, .event_code = code };
    }
    return error.UnknownEventCode;
}

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

test "input_codes: resolveAbsCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x00), try resolveAbsCode("ABS_X"));
    try std.testing.expectEqual(@as(u16, 0x01), try resolveAbsCode("ABS_Y"));
    try std.testing.expectEqual(@as(u16, 0x03), try resolveAbsCode("ABS_RX"));
    try std.testing.expectEqual(@as(u16, 0x10), try resolveAbsCode("ABS_HAT0X"));
    try std.testing.expectEqual(@as(u16, 0x11), try resolveAbsCode("ABS_HAT0Y"));
}

test "input_codes: resolveAbsCode: unknown returns error" {
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode("INVALID"));
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode(""));
    try std.testing.expectError(error.UnknownAbsCode, resolveAbsCode("BTN_SOUTH"));
}

test "input_codes: resolveBtnCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x130), try resolveBtnCode("BTN_SOUTH"));
    try std.testing.expectEqual(@as(u16, 0x131), try resolveBtnCode("BTN_EAST"));
    try std.testing.expectEqual(@as(u16, 0x133), try resolveBtnCode("BTN_NORTH"));
    try std.testing.expectEqual(@as(u16, 0x134), try resolveBtnCode("BTN_WEST"));
    try std.testing.expectEqual(@as(u16, 0x13a), try resolveBtnCode("BTN_SELECT"));
    try std.testing.expectEqual(@as(u16, 0x13b), try resolveBtnCode("BTN_START"));
    try std.testing.expectEqual(@as(u16, 0x2c2), try resolveBtnCode("BTN_TRIGGER_HAPPY3"));
}

test "input_codes: resolveBtnCode: unknown returns error" {
    try std.testing.expectError(error.UnknownBtnCode, resolveBtnCode("INVALID"));
    try std.testing.expectError(error.UnknownBtnCode, resolveBtnCode("ABS_X"));
}

test "input_codes: resolveKeyCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x1e), try resolveKeyCode("KEY_A"));
    try std.testing.expectEqual(@as(u16, 0x3b), try resolveKeyCode("KEY_F1"));
    try std.testing.expectEqual(@as(u16, 0x58), try resolveKeyCode("KEY_F12"));
    try std.testing.expectEqual(@as(u16, 0x1c), try resolveKeyCode("KEY_ENTER"));
    try std.testing.expectEqual(@as(u16, 0x39), try resolveKeyCode("KEY_SPACE"));
    try std.testing.expectEqual(@as(u16, 0x01), try resolveKeyCode("KEY_ESC"));
    try std.testing.expectEqual(@as(u16, 0x67), try resolveKeyCode("KEY_UP"));
    try std.testing.expectEqual(@as(u16, 0x6c), try resolveKeyCode("KEY_DOWN"));
}

test "input_codes: resolveKeyCode: unknown returns error" {
    try std.testing.expectError(error.UnknownKeyCode, resolveKeyCode("INVALID"));
    try std.testing.expectError(error.UnknownKeyCode, resolveKeyCode(""));
    try std.testing.expectError(error.UnknownKeyCode, resolveKeyCode("BTN_SOUTH"));
    try std.testing.expectError(error.UnknownKeyCode, resolveKeyCode("ABS_X"));
}

test "input_codes: resolveMouseCode: known codes" {
    try std.testing.expectEqual(@as(u16, 0x110), try resolveMouseCode("mouse_left"));
    try std.testing.expectEqual(@as(u16, 0x111), try resolveMouseCode("mouse_right"));
    try std.testing.expectEqual(@as(u16, 0x112), try resolveMouseCode("mouse_middle"));
    try std.testing.expectEqual(@as(u16, 0x113), try resolveMouseCode("mouse_side"));
    try std.testing.expectEqual(@as(u16, 0x114), try resolveMouseCode("mouse_extra"));
    try std.testing.expectEqual(@as(u16, 0x115), try resolveMouseCode("mouse_forward"));
    try std.testing.expectEqual(@as(u16, 0x116), try resolveMouseCode("mouse_back"));
}

test "input_codes: resolveMouseCode: unknown returns error" {
    try std.testing.expectError(error.UnknownMouseCode, resolveMouseCode("INVALID"));
    try std.testing.expectError(error.UnknownMouseCode, resolveMouseCode(""));
    try std.testing.expectError(error.UnknownMouseCode, resolveMouseCode("BTN_LEFT"));
    try std.testing.expectError(error.UnknownMouseCode, resolveMouseCode("MOUSE_LEFT"));
}

test "input_codes: resolveEventCode: ABS_WHEEL returns EV_ABS" {
    const r = try resolveEventCode("ABS_WHEEL");
    try std.testing.expectEqual(@as(u16, c.EV_ABS), r.event_type);
    try std.testing.expectEqual(@as(u16, c.ABS_WHEEL), r.event_code);
}

test "input_codes: resolveEventCode: BTN_GEAR_UP returns EV_KEY" {
    const r = try resolveEventCode("BTN_GEAR_UP");
    try std.testing.expectEqual(@as(u16, c.EV_KEY), r.event_type);
    try std.testing.expectEqual(@as(u16, c.BTN_GEAR_UP), r.event_code);
}

test "input_codes: resolveEventCode: KEY_A returns EV_KEY" {
    const r = try resolveEventCode("KEY_A");
    try std.testing.expectEqual(@as(u16, c.EV_KEY), r.event_type);
    try std.testing.expectEqual(@as(u16, c.KEY_A), r.event_code);
}

test "input_codes: resolveEventCode: INVALID returns error" {
    try std.testing.expectError(error.UnknownEventCode, resolveEventCode("INVALID"));
}
