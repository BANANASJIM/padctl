const std = @import("std");
const toml = @import("toml");
pub const MacroStep = @import("../core/macro.zig").MacroStep;
pub const Macro = @import("../core/macro.zig").Macro;

pub const GyroConfig = struct {
    mode: []const u8 = "off",
    activate: ?[]const u8 = null,
    sensitivity: ?f64 = null,
    sensitivity_x: ?f64 = null,
    sensitivity_y: ?f64 = null,
    deadzone: ?i64 = null,
    smoothing: ?f64 = null,
    curve: ?f64 = null,
    max_val: ?f64 = null,
    invert_x: ?bool = null,
    invert_y: ?bool = null,
};

pub const StickConfig = struct {
    mode: []const u8 = "gamepad",
    deadzone: ?i64 = null,
    sensitivity: ?f64 = null,
    suppress_gamepad: ?bool = null,
};

pub const StickPairConfig = struct {
    left: ?StickConfig = null,
    right: ?StickConfig = null,
};

pub const DpadConfig = struct {
    mode: []const u8 = "gamepad",
    suppress_gamepad: ?bool = null,
};

pub const AdaptiveTriggerParamConfig = struct {
    position: ?i64 = null,
    strength: ?i64 = null,
    start: ?i64 = null,
    end: ?i64 = null,
    amplitude: ?i64 = null,
    frequency: ?i64 = null,
};

pub const AdaptiveTriggerConfig = struct {
    mode: []const u8 = "off",
    command_prefix: []const u8 = "adaptive_trigger_",
    left: ?AdaptiveTriggerParamConfig = null,
    right: ?AdaptiveTriggerParamConfig = null,
};

pub const LayerConfig = struct {
    name: []const u8,
    trigger: []const u8,
    activation: []const u8 = "hold",
    tap: ?[]const u8 = null,
    hold_timeout: ?i64 = null,
    remap: ?toml.HashMap([]const u8) = null,
    gyro: ?GyroConfig = null,
    stick_left: ?StickConfig = null,
    stick_right: ?StickConfig = null,
    dpad: ?DpadConfig = null,
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
};

pub const MappingConfig = struct {
    name: ?[]const u8 = null,
    remap: ?toml.HashMap([]const u8) = null,
    gyro: ?GyroConfig = null,
    stick: ?StickPairConfig = null,
    dpad: ?DpadConfig = null,
    layer: ?[]const LayerConfig = null,
    macro: ?[]const Macro = null,
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
};

pub const ParseResult = toml.Parsed(MappingConfig);

pub fn parseString(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var parser = toml.Parser(MappingConfig).init(allocator);
    defer parser.deinit();
    return parser.parseString(content);
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);
    return parseString(allocator, content);
}

fn macroExists(cfg: *const MappingConfig, name: []const u8) bool {
    const macros = cfg.macro orelse return false;
    for (macros) |*m| {
        if (std.mem.eql(u8, m.name, name)) return true;
    }
    return false;
}

fn checkRemapMacros(cfg: *const MappingConfig, map: *const toml.HashMap([]const u8)) !void {
    var it = map.map.iterator();
    while (it.next()) |entry| {
        const val = entry.value_ptr.*;
        if (std.mem.startsWith(u8, val, "macro:")) {
            const macro_name = val["macro:".len..];
            if (!macroExists(cfg, macro_name)) return error.UnknownMacro;
        }
    }
}

const valid_at_modes = [_][]const u8{ "off", "feedback", "weapon", "vibration" };

fn validateAdaptiveTrigger(at: *const AdaptiveTriggerConfig) !void {
    for (valid_at_modes) |v| {
        if (std.mem.eql(u8, at.mode, v)) return;
    }
    return error.InvalidConfig;
}

pub fn validate(cfg: *const MappingConfig) !void {
    if (cfg.remap) |*m| try checkRemapMacros(cfg, m);
    if (cfg.adaptive_trigger) |*at| try validateAdaptiveTrigger(at);

    const layers = cfg.layer orelse return;

    var seen_buf: [64][]const u8 = undefined;
    var seen_len: usize = 0;

    for (layers) |*layer| {
        if (!std.mem.eql(u8, layer.activation, "hold") and
            !std.mem.eql(u8, layer.activation, "toggle"))
            return error.InvalidConfig;

        if (layer.hold_timeout) |t| {
            if (t < 1 or t > 5000) return error.InvalidConfig;
        }

        for (seen_buf[0..seen_len]) |name| {
            if (std.mem.eql(u8, name, layer.name)) return error.InvalidConfig;
        }
        if (seen_len >= seen_buf.len) return error.InvalidConfig;
        seen_buf[seen_len] = layer.name;
        seen_len += 1;

        if (layer.remap) |*m| try checkRemapMacros(cfg, m);
        if (layer.adaptive_trigger) |*at| try validateAdaptiveTrigger(at);
    }
}

// --- tests ---

const test_toml_basic =
    \\name = "test"
    \\
    \\[remap]
    \\M1 = "KEY_F13"
    \\M2 = "disabled"
    \\A = "B"
;

test "mapping: MappingConfig parses name and remap" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_basic);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("test", cfg.name.?);
    try std.testing.expect(cfg.remap != null);
    try std.testing.expectEqualStrings("KEY_F13", cfg.remap.?.map.get("M1").?);
    try std.testing.expectEqualStrings("disabled", cfg.remap.?.map.get("M2").?);
    try std.testing.expectEqualStrings("B", cfg.remap.?.map.get("A").?);
}

test "mapping: MappingConfig: empty config" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try std.testing.expect(result.value.name == null);
    try std.testing.expect(result.value.remap == null);
    try std.testing.expect(result.value.layer == null);
}

const test_toml_full =
    \\name = "default"
    \\
    \\[remap]
    \\M1 = "KEY_F13"
    \\C = "BTN_TRIGGER_HAPPY1"
    \\
    \\[gyro]
    \\mode = "mouse"
    \\activate = "hold_RB"
    \\sensitivity = 15.0
    \\deadzone = 50
    \\smoothing = 0.3
    \\curve = 1.0
    \\invert_x = false
    \\invert_y = false
    \\
    \\[stick.left]
    \\mode = "gamepad"
    \\deadzone = 128
    \\sensitivity = 1.0
    \\suppress_gamepad = false
    \\
    \\[stick.right]
    \\mode = "gamepad"
    \\deadzone = 128
    \\sensitivity = 1.0
    \\suppress_gamepad = false
    \\
    \\[dpad]
    \\mode = "gamepad"
    \\suppress_gamepad = false
    \\
    \\[[layer]]
    \\name = "aim"
    \\trigger = "LM"
    \\activation = "hold"
    \\tap = "mouse_side"
    \\hold_timeout = 200
    \\
    \\[layer.remap]
    \\RB = "mouse_left"
    \\
    \\[layer.gyro]
    \\mode = "mouse"
    \\sensitivity = 2.0
    \\
    \\[layer.stick_left]
    \\mode = "scroll"
    \\
    \\[layer.stick_right]
    \\mode = "mouse"
    \\sensitivity = 1.0
    \\suppress_gamepad = true
    \\
    \\[layer.dpad]
    \\mode = "arrows"
    \\suppress_gamepad = true
    \\
    \\[[layer]]
    \\name = "fn"
    \\trigger = "Select"
    \\activation = "toggle"
    \\
    \\[layer.remap]
    \\A = "KEY_F1"
    \\B = "KEY_F2"
;

test "mapping: MappingConfig: full config with layers, gyro, stick, dpad" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_full);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("default", cfg.name.?);

    // gyro
    try std.testing.expect(cfg.gyro != null);
    try std.testing.expectEqualStrings("mouse", cfg.gyro.?.mode);
    try std.testing.expectEqualStrings("hold_RB", cfg.gyro.?.activate.?);
    try std.testing.expectEqual(@as(?f64, 15.0), cfg.gyro.?.sensitivity);
    try std.testing.expectEqual(@as(?i64, 50), cfg.gyro.?.deadzone);

    // stick
    try std.testing.expect(cfg.stick != null);
    try std.testing.expect(cfg.stick.?.left != null);
    try std.testing.expectEqualStrings("gamepad", cfg.stick.?.left.?.mode);
    try std.testing.expectEqual(@as(?i64, 128), cfg.stick.?.left.?.deadzone);

    // dpad
    try std.testing.expect(cfg.dpad != null);
    try std.testing.expectEqualStrings("gamepad", cfg.dpad.?.mode);

    // layers ordered
    try std.testing.expect(cfg.layer != null);
    try std.testing.expectEqual(@as(usize, 2), cfg.layer.?.len);
    try std.testing.expectEqualStrings("aim", cfg.layer.?[0].name);
    try std.testing.expectEqualStrings("fn", cfg.layer.?[1].name);

    // layer[0] fields
    const aim = cfg.layer.?[0];
    try std.testing.expectEqualStrings("hold", aim.activation);
    try std.testing.expectEqualStrings("mouse_side", aim.tap.?);
    try std.testing.expectEqual(@as(?i64, 200), aim.hold_timeout);
    try std.testing.expect(aim.remap != null);
    try std.testing.expectEqualStrings("mouse_left", aim.remap.?.map.get("RB").?);

    // layer[0] gyro override
    try std.testing.expect(aim.gyro != null);
    try std.testing.expectEqualStrings("mouse", aim.gyro.?.mode);
    try std.testing.expectEqual(@as(?f64, 2.0), aim.gyro.?.sensitivity);

    // layer[0] stick overrides
    try std.testing.expect(aim.stick_left != null);
    try std.testing.expectEqualStrings("scroll", aim.stick_left.?.mode);
    try std.testing.expect(aim.stick_right != null);
    try std.testing.expectEqualStrings("mouse", aim.stick_right.?.mode);
    try std.testing.expectEqual(@as(?bool, true), aim.stick_right.?.suppress_gamepad);

    // layer[0] dpad override
    try std.testing.expect(aim.dpad != null);
    try std.testing.expectEqualStrings("arrows", aim.dpad.?.mode);

    // layer[1] fields
    const fn_layer = cfg.layer.?[1];
    try std.testing.expectEqualStrings("toggle", fn_layer.activation);
    try std.testing.expect(fn_layer.remap != null);
    try std.testing.expectEqualStrings("KEY_F1", fn_layer.remap.?.map.get("A").?);

    try validate(&cfg);
}

test "mapping: validate: missing [mapping] section returns default empty MappingConfig" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try validate(&result.value);
}

test "mapping: validate: [[layer]] preserved in declaration order" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "first"
        \\trigger = "A"
        \\
        \\[[layer]]
        \\name = "second"
        \\trigger = "B"
        \\
        \\[[layer]]
        \\name = "third"
        \\trigger = "X"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const layers = result.value.layer.?;
    try std.testing.expectEqual(@as(usize, 3), layers.len);
    try std.testing.expectEqualStrings("first", layers[0].name);
    try std.testing.expectEqualStrings("second", layers[1].name);
    try std.testing.expectEqualStrings("third", layers[2].name);
    try validate(&result.value);
}

test "mapping: validate: invalid activation value returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "bad"
        \\trigger = "A"
        \\activation = "press"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: validate: duplicate layer name returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "aim"
        \\trigger = "A"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "B"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: validate: hold_timeout out of range returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "bad"
        \\trigger = "A"
        \\hold_timeout = 9999
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

const test_toml_macro =
    \\[[macro]]
    \\name = "dodge_roll"
    \\steps = [
    \\    { tap = "B" },
    \\    { delay = 50 },
    \\    { tap = "LEFT" },
    \\]
    \\
    \\[[macro]]
    \\name = "shift_hold"
    \\steps = [
    \\    { down = "KEY_LEFTSHIFT" },
    \\    "pause_for_release",
    \\    { up = "KEY_LEFTSHIFT" },
    \\]
    \\
    \\[[macro]]
    \\name = "noop"
    \\steps = []
    \\
    \\[remap]
    \\M1 = "macro:dodge_roll"
;

test "mapping: [[macro]] multi-entry parse: all step primitives correct" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_macro);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expect(cfg.macro != null);
    const macros = cfg.macro.?;
    try std.testing.expectEqual(@as(usize, 3), macros.len);

    const dodge = macros[0];
    try std.testing.expectEqualStrings("dodge_roll", dodge.name);
    try std.testing.expectEqual(@as(usize, 3), dodge.steps.len);
    try std.testing.expectEqualStrings("B", dodge.steps[0].tap);
    try std.testing.expectEqual(@as(u32, 50), dodge.steps[1].delay);
    try std.testing.expectEqualStrings("LEFT", dodge.steps[2].tap);

    const shift = macros[1];
    try std.testing.expectEqualStrings("shift_hold", shift.name);
    try std.testing.expectEqual(@as(usize, 3), shift.steps.len);
    try std.testing.expectEqualStrings("KEY_LEFTSHIFT", shift.steps[0].down);
    _ = shift.steps[1].pause_for_release;
    try std.testing.expectEqualStrings("KEY_LEFTSHIFT", shift.steps[2].up);

    const noop = macros[2];
    try std.testing.expectEqualStrings("noop", noop.name);
    try std.testing.expectEqual(@as(usize, 0), noop.steps.len);

    try std.testing.expectEqualStrings("macro:dodge_roll", cfg.remap.?.map.get("M1").?);
    try validate(&cfg);
}

test "mapping: validate: macro:name remap target references unknown macro returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[remap]
        \\M1 = "macro:nonexistent"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.UnknownMacro, validate(&result.value));
}

test "mapping: validate: macro:name in layer remap references unknown macro returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\
        \\[layer.remap]
        \\M1 = "macro:ghost"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.UnknownMacro, validate(&result.value));
}

test "mapping: adaptive_trigger: valid mode parses and validates" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[adaptive_trigger]
        \\mode = "feedback"
        \\
        \\[adaptive_trigger.left]
        \\position = 70
        \\strength = 200
        \\
        \\[adaptive_trigger.right]
        \\position = 40
        \\strength = 180
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const cfg = result.value;
    try std.testing.expect(cfg.adaptive_trigger != null);
    const at = cfg.adaptive_trigger.?;
    try std.testing.expectEqualStrings("feedback", at.mode);
    try std.testing.expectEqual(@as(?i64, 70), at.left.?.position);
    try std.testing.expectEqual(@as(?i64, 200), at.left.?.strength);
    try std.testing.expectEqual(@as(?i64, 40), at.right.?.position);
    try validate(&cfg);
}

test "mapping: adaptive_trigger: invalid mode returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[adaptive_trigger]
        \\mode = "bogus"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: adaptive_trigger: invalid mode in layer returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fps"
        \\trigger = "LT"
        \\
        \\[layer.adaptive_trigger]
        \\mode = "unknown"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: adaptive_trigger: per-layer valid mode validates" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "racing"
        \\trigger = "RB"
        \\
        \\[layer.adaptive_trigger]
        \\mode = "weapon"
        \\
        \\[layer.adaptive_trigger.left]
        \\start = 30
        \\end = 120
        \\strength = 200
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try validate(&result.value);
    const at = result.value.layer.?[0].adaptive_trigger.?;
    try std.testing.expectEqualStrings("weapon", at.mode);
    try std.testing.expectEqual(@as(?i64, 30), at.left.?.start);
}

test "mapping: fuzz parseString: no panic on arbitrary input" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) !void {
            const result = parseString(std.testing.allocator, input);
            if (result) |r| r.deinit() else |_| {}
        }
    }.run, .{});
}
