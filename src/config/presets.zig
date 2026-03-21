const std = @import("std");
const toml = @import("toml");
const device = @import("device.zig");

const AxisEntry = struct { name: []const u8, cfg: device.AxisConfig };
const ButtonEntry = struct { name: []const u8, code: []const u8 };

const Preset = struct {
    vid: i64,
    pid: i64,
    name: []const u8,
    axes: []const AxisEntry,
    buttons: []const ButtonEntry,
};

const xbox360_axes = [_]AxisEntry{
    .{ .name = "left_x",  .cfg = .{ .code = "ABS_X",  .min = -32768, .max = 32767, .fuzz = 16, .flat = 128 } },
    .{ .name = "left_y",  .cfg = .{ .code = "ABS_Y",  .min = -32768, .max = 32767, .fuzz = 16, .flat = 128 } },
    .{ .name = "right_x", .cfg = .{ .code = "ABS_RX", .min = -32768, .max = 32767, .fuzz = 16, .flat = 128 } },
    .{ .name = "right_y", .cfg = .{ .code = "ABS_RY", .min = -32768, .max = 32767, .fuzz = 16, .flat = 128 } },
    .{ .name = "lt",      .cfg = .{ .code = "ABS_Z",  .min = 0,      .max = 255,   .fuzz = 0,  .flat = 0   } },
    .{ .name = "rt",      .cfg = .{ .code = "ABS_RZ", .min = 0,      .max = 255,   .fuzz = 0,  .flat = 0   } },
};

const xbox360_buttons = [_]ButtonEntry{
    .{ .name = "A",      .code = "BTN_SOUTH" },
    .{ .name = "B",      .code = "BTN_EAST"  },
    .{ .name = "X",      .code = "BTN_WEST"  },
    .{ .name = "Y",      .code = "BTN_NORTH" },
    .{ .name = "LB",     .code = "BTN_TL"    },
    .{ .name = "RB",     .code = "BTN_TR"    },
    .{ .name = "Select", .code = "BTN_SELECT" },
    .{ .name = "Start",  .code = "BTN_START" },
    .{ .name = "Home",   .code = "BTN_MODE"  },
    .{ .name = "LS",     .code = "BTN_THUMBL" },
    .{ .name = "RS",     .code = "BTN_THUMBR" },
};

const dualsense_axes = [_]AxisEntry{
    .{ .name = "left_x",  .cfg = .{ .code = "ABS_X",  .min = 0, .max = 255, .fuzz = 0, .flat = 8 } },
    .{ .name = "left_y",  .cfg = .{ .code = "ABS_Y",  .min = 0, .max = 255, .fuzz = 0, .flat = 8 } },
    .{ .name = "right_x", .cfg = .{ .code = "ABS_RX", .min = 0, .max = 255, .fuzz = 0, .flat = 8 } },
    .{ .name = "right_y", .cfg = .{ .code = "ABS_RY", .min = 0, .max = 255, .fuzz = 0, .flat = 8 } },
    .{ .name = "lt",      .cfg = .{ .code = "ABS_Z",  .min = 0, .max = 255, .fuzz = 0, .flat = 0 } },
    .{ .name = "rt",      .cfg = .{ .code = "ABS_RZ", .min = 0, .max = 255, .fuzz = 0, .flat = 0 } },
};

const dualsense_buttons = [_]ButtonEntry{
    .{ .name = "A",        .code = "BTN_SOUTH"  },
    .{ .name = "B",        .code = "BTN_EAST"   },
    .{ .name = "X",        .code = "BTN_WEST"   },
    .{ .name = "Y",        .code = "BTN_NORTH"  },
    .{ .name = "LB",       .code = "BTN_TL"     },
    .{ .name = "RB",       .code = "BTN_TR"     },
    .{ .name = "Select",   .code = "BTN_SELECT" },
    .{ .name = "Start",    .code = "BTN_START"  },
    .{ .name = "Home",     .code = "BTN_MODE"   },
    .{ .name = "LS",       .code = "BTN_THUMBL" },
    .{ .name = "RS",       .code = "BTN_THUMBR" },
    .{ .name = "TouchPad", .code = "BTN_TOUCH"  },
    .{ .name = "Mic",      .code = "BTN_MISC"   },
};

const switch_pro_axes = [_]AxisEntry{
    .{ .name = "left_x",  .cfg = .{ .code = "ABS_X",  .min = -32768, .max = 32767, .fuzz = 0, .flat = 200 } },
    .{ .name = "left_y",  .cfg = .{ .code = "ABS_Y",  .min = -32768, .max = 32767, .fuzz = 0, .flat = 200 } },
    .{ .name = "right_x", .cfg = .{ .code = "ABS_RX", .min = -32768, .max = 32767, .fuzz = 0, .flat = 200 } },
    .{ .name = "right_y", .cfg = .{ .code = "ABS_RY", .min = -32768, .max = 32767, .fuzz = 0, .flat = 200 } },
};

const switch_pro_buttons = [_]ButtonEntry{
    .{ .name = "A",      .code = "BTN_EAST"   },
    .{ .name = "B",      .code = "BTN_SOUTH"  },
    .{ .name = "X",      .code = "BTN_NORTH"  },
    .{ .name = "Y",      .code = "BTN_WEST"   },
    .{ .name = "LB",     .code = "BTN_TL"     },
    .{ .name = "RB",     .code = "BTN_TR"     },
    .{ .name = "ZL",     .code = "BTN_TL2"    },
    .{ .name = "ZR",     .code = "BTN_TR2"    },
    .{ .name = "Minus",  .code = "BTN_SELECT" },
    .{ .name = "Plus",   .code = "BTN_START"  },
    .{ .name = "Home",   .code = "BTN_MODE"   },
    .{ .name = "Capture",.code = "BTN_MISC"   },
    .{ .name = "LS",     .code = "BTN_THUMBL" },
    .{ .name = "RS",     .code = "BTN_THUMBR" },
};

const presets = [_]struct { name: []const u8, preset: Preset }{
    .{ .name = "xbox-360", .preset = .{
        .vid  = 0x045e,
        .pid  = 0x028e,
        .name = "Xbox 360 Controller",
        .axes    = &xbox360_axes,
        .buttons = &xbox360_buttons,
    }},
    .{ .name = "xbox-elite2", .preset = .{
        .vid  = 0x045e,
        .pid  = 0x0b00,
        .name = "Xbox Elite Series 2",
        .axes    = &xbox360_axes,
        .buttons = &xbox360_buttons,
    }},
    .{ .name = "dualsense", .preset = .{
        .vid  = 0x054c,
        .pid  = 0x0ce6,
        .name = "Sony DualSense",
        .axes    = &dualsense_axes,
        .buttons = &dualsense_buttons,
    }},
    .{ .name = "switch-pro", .preset = .{
        .vid  = 0x057e,
        .pid  = 0x2009,
        .name = "Nintendo Switch Pro Controller",
        .axes    = &switch_pro_axes,
        .buttons = &switch_pro_buttons,
    }},
};

fn lookupPreset(name: []const u8) ?Preset {
    for (presets) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.preset;
    }
    return null;
}

fn buildAxesMap(allocator: std.mem.Allocator, axes: []const AxisEntry) !toml.HashMap(device.AxisConfig) {
    var map = std.StringHashMap(device.AxisConfig).init(allocator);
    errdefer map.deinit();
    for (axes) |entry| {
        const key = try allocator.dupe(u8, entry.name);
        try map.put(key, entry.cfg);
    }
    return .{ .map = map };
}

fn buildButtonsMap(allocator: std.mem.Allocator, buttons: []const ButtonEntry) !toml.HashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer map.deinit();
    for (buttons) |entry| {
        const key  = try allocator.dupe(u8, entry.name);
        const code = try allocator.dupe(u8, entry.code);
        try map.put(key, code);
    }
    return .{ .map = map };
}

/// Apply preset defaults to `out`, leaving any already-set fields unchanged.
/// Returns error.UnknownPreset if the preset name is not recognised.
pub fn applyPreset(allocator: std.mem.Allocator, out: *device.OutputConfig, preset_name: []const u8) !void {
    const p = lookupPreset(preset_name) orelse return error.UnknownPreset;
    if (out.vid  == null) out.vid  = p.vid;
    if (out.pid  == null) out.pid  = p.pid;
    if (out.name == null) out.name = p.name;
    if (out.axes    == null) out.axes    = try buildAxesMap(allocator, p.axes);
    if (out.buttons == null) out.buttons = try buildButtonsMap(allocator, p.buttons);
}

// --- tests ---

test "applyPreset: xbox-360 fills vid/pid/name" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{};
    try applyPreset(arena.allocator(), &out, "xbox-360");
    try std.testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x028e), out.pid);
    try std.testing.expectEqualStrings("Xbox 360 Controller", out.name.?);
    try std.testing.expect(out.axes != null);
    try std.testing.expect(out.buttons != null);
}

test "applyPreset: explicit fields are not overridden" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{ .vid = 0x1234 };
    try applyPreset(arena.allocator(), &out, "xbox-360");
    try std.testing.expectEqual(@as(?i64, 0x1234), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x028e), out.pid);
}

test "applyPreset: dualsense preset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{};
    try applyPreset(arena.allocator(), &out, "dualsense");
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0ce6), out.pid);
}

test "applyPreset: switch-pro preset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{};
    try applyPreset(arena.allocator(), &out, "switch-pro");
    try std.testing.expectEqual(@as(?i64, 0x057e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x2009), out.pid);
}

test "applyPreset: xbox-elite2 preset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{};
    try applyPreset(arena.allocator(), &out, "xbox-elite2");
    try std.testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0b00), out.pid);
}

test "applyPreset: unknown preset returns error" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var out = device.OutputConfig{};
    try std.testing.expectError(error.UnknownPreset, applyPreset(arena.allocator(), &out, "unknown-device"));
}
