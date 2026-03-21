const std = @import("std");
const toml = @import("toml");
const state = @import("../core/state.zig");
const presets = @import("presets.zig");

pub const ButtonId = state.ButtonId;

pub const InterfaceConfig = struct {
    id: i64,
    class: []const u8,
    ep_in: ?i64 = null,
    ep_out: ?i64 = null,
};

pub const InitConfig = struct {
    commands: []const []const u8,
    response_prefix: []const i64,
    enable: ?[]const u8 = null,
    disable: ?[]const u8 = null,
};

pub const DeviceInfo = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    interface: []const InterfaceConfig,
    init: ?InitConfig = null,
};

pub const MatchConfig = struct {
    offset: i64,
    expect: []const i64,
};

pub const FieldConfig = struct {
    offset: i64,
    type: []const u8,
    transform: ?[]const u8 = null,
};

pub const ButtonGroupSource = struct {
    offset: i64,
    size: i64,
};

pub const ButtonGroupConfig = struct {
    source: ButtonGroupSource,
    map: toml.HashMap(i64),
};

pub const ChecksumExpect = struct {
    offset: i64,
    type: []const u8,
};

pub const ChecksumConfig = struct {
    algo: []const u8,
    range: []const i64,
    expect: ChecksumExpect,
    seed: ?i64 = null,
};

pub const ReportConfig = struct {
    name: []const u8,
    interface: i64,
    size: i64,
    match: ?MatchConfig = null,
    fields: ?toml.HashMap(FieldConfig) = null,
    button_group: ?ButtonGroupConfig = null,
    checksum: ?ChecksumConfig = null,
};

pub const CommandConfig = struct {
    interface: i64,
    template: []const u8,
};

pub const AxisConfig = struct {
    code: []const u8,
    min: i64,
    max: i64,
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
};

pub const DpadOutputConfig = struct {
    type: []const u8, // "hat" | "buttons"
};

pub const FfConfig = struct {
    type: []const u8, // "rumble"
    max_effects: ?i64 = null,
};

pub const AuxConfig = struct {
    type: ?[]const u8 = null, // "mouse" | "keyboard"
    name: ?[]const u8 = null,
    keyboard: ?bool = null,
    buttons: ?toml.HashMap([]const u8) = null,
};

pub const OutputConfig = struct {
    emulate: ?[]const u8 = null,
    name: ?[]const u8 = null,
    vid: ?i64 = null,
    pid: ?i64 = null,
    axes: ?toml.HashMap(AxisConfig) = null,
    buttons: ?toml.HashMap([]const u8) = null,
    dpad: ?DpadOutputConfig = null,
    force_feedback: ?FfConfig = null,
    aux: ?AuxConfig = null,
};

pub const WasmOverridesConfig = struct {
    process_report: ?bool = null,
};

pub const WasmConfig = struct {
    plugin: []const u8,
    overrides: ?WasmOverridesConfig = null,
};

pub const DeviceConfig = struct {
    device: DeviceInfo,
    report: []const ReportConfig,
    commands: ?toml.HashMap(CommandConfig) = null,
    output: ?OutputConfig = null,
    wasm: ?WasmConfig = null,
};

const valid_transforms = [_][]const u8{ "negate", "abs", "scale", "clamp", "deadzone", "lookup" };

fn isValidTransform(t: []const u8) bool {
    const name = std.mem.trim(u8, t, " \t");
    const paren = std.mem.indexOfScalar(u8, name, '(');
    const base = if (paren) |p| name[0..p] else name;
    const base_trimmed = std.mem.trim(u8, base, " \t");
    for (valid_transforms) |v| {
        if (std.mem.eql(u8, base_trimmed, v)) return true;
    }
    return false;
}

fn isValidTransformChain(chain: []const u8) bool {
    var pos: usize = 0;
    var depth: usize = 0;
    var seg_start: usize = 0;
    while (pos < chain.len) : (pos += 1) {
        switch (chain[pos]) {
            '(' => depth += 1,
            ')' => if (depth > 0) {
                depth -= 1;
            },
            ',' => if (depth == 0) {
                if (!isValidTransform(chain[seg_start..pos])) return false;
                seg_start = pos + 1;
            },
            else => {},
        }
    }
    return isValidTransform(chain[seg_start..]);
}

fn fieldTypeSize(type_str: []const u8) ?i64 {
    if (std.mem.eql(u8, type_str, "u8") or std.mem.eql(u8, type_str, "i8")) return 1;
    if (std.mem.eql(u8, type_str, "u16le") or std.mem.eql(u8, type_str, "i16le") or
        std.mem.eql(u8, type_str, "u16be") or std.mem.eql(u8, type_str, "i16be")) return 2;
    if (std.mem.eql(u8, type_str, "u32le") or std.mem.eql(u8, type_str, "i32le") or
        std.mem.eql(u8, type_str, "u32be") or std.mem.eql(u8, type_str, "i32be")) return 4;
    return null;
}

pub fn validate(cfg: *const DeviceConfig) !void {
    for (cfg.report) |report| {
        if (report.fields) |fields| {
            var seen_buf: [64][]const u8 = undefined;
            var seen_len: usize = 0;
            var it = fields.map.iterator();
            while (it.next()) |entry| {
                const name = entry.key_ptr.*;
                const field = entry.value_ptr.*;

                for (seen_buf[0..seen_len]) |s| {
                    if (std.mem.eql(u8, s, name)) return error.InvalidConfig;
                }
                if (seen_len < seen_buf.len) {
                    seen_buf[seen_len] = name;
                    seen_len += 1;
                }

                const sz = fieldTypeSize(field.type) orelse return error.InvalidConfig;
                if (field.offset < 0 or field.offset + sz > report.size) return error.OffsetOutOfBounds;

                if (field.transform) |tr| {
                    if (!isValidTransformChain(tr)) return error.InvalidConfig;
                }
            }
        }

        if (report.button_group) |bg| {
            var it = bg.map.map.iterator();
            while (it.next()) |entry| {
                const btn_name = entry.key_ptr.*;
                _ = std.meta.stringToEnum(ButtonId, btn_name) orelse return error.InvalidConfig;
            }
        }

        if (report.checksum) |cs| {
            if (cs.range.len != 2) return error.InvalidConfig;
            if (cs.range[0] < 0 or cs.range[1] > report.size) return error.InvalidConfig;
        }
    }
}

pub const ParseResult = toml.Parsed(DeviceConfig);

pub fn parseString(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var parser = toml.Parser(DeviceConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(content);
    if (result.value.output) |*out| {
        if (out.emulate) |preset_name| {
            presets.applyPreset(result.arena.allocator(), out, preset_name) catch |err| {
                result.deinit();
                return err;
            };
        }
    }
    validate(&result.value) catch |err| {
        result.deinit();
        return err;
    };
    return result;
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);
    return parseString(allocator, content);
}

// --- tests ---

const test_toml =
    \\[device]
    \\name = "Test Device"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\
    \\[[device.interface]]
    \\id = 0
    \\class = "vendor"
    \\
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
    \\
    \\[device.init]
    \\commands = ["5aa5 0102 03"]
    \\response_prefix = [0x5a, 0xa5]
    \\
    \\[[report]]
    \\name = "extended"
    \\interface = 1
    \\size = 32
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\
    \\[report.fields]
    \\left_x = { offset = 3, type = "i16le" }
    \\left_y = { offset = 5, type = "i16le", transform = "negate" }
    \\
    \\[report.button_group]
    \\source = { offset = 11, size = 2 }
    \\map = { A = 0, B = 1, X = 3, Y = 4 }
    \\
    \\[report.checksum]
    \\algo = "crc32"
    \\range = [0, 29]
    \\expect = { offset = 30, type = "u16le" }
    \\
    \\[[report]]
    \\name = "standard"
    \\interface = 0
    \\size = 20
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x00]
    \\
    \\[report.fields]
    \\left_x = { offset = 6, type = "i16le" }
    \\
    \\[commands.rumble]
    \\interface = 0
    \\template = "00 08 00 {strong} {weak} 00 00 00"
    \\
    \\[commands.led]
    \\interface = 1
    \\template = "5aa5 2001 {r} {g} {b} 00"
    \\
    \\[output]
    \\name = "Test Output"
    \\vid = 0x3820
    \\pid = 0x0001
    \\
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = -32768, max = 32767, fuzz = 16, flat = 128 }
    \\
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\
    \\[output.dpad]
    \\type = "hat"
    \\
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

test "load test-vader5.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "spike/test-vader5.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Test Vader 5", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
}

test "load flydigi/vader5.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x2401), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
}

test "valid config parses and validates" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
}

test "offset out of bounds returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[report.fields]
        \\x = { offset = 3, type = "i16le" }
    ;
    try std.testing.expectError(error.OffsetOutOfBounds, parseString(allocator, bad));
}

test "duplicate field name returns error" {
    const cfg = DeviceConfig{
        .device = .{
            .name = "test",
            .vid = 1,
            .pid = 2,
            .interface = &.{},
        },
        .report = &.{},
    };
    try validate(&cfg);
}

test "invalid transform returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\x = { offset = 0, type = "u8", transform = "$val * 2 + 1" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "unknown button name returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.button_group]
        \\source = { offset = 0, size = 1 }
        \\map = { INVALID_BTN = 0 }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "load devices/sony/dualsense.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Sony DualSense", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x054c), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x0ce6), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 1), cfg.report.len);
    try std.testing.expectEqualStrings("usb", cfg.report[0].name);
}

test "dualsense.toml report field count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const fields = cfg.report[0].fields orelse return error.NoFields;
    // left_x, left_y, right_x, right_y, lt, rt,
    // gyro_x, gyro_y, gyro_z, accel_x, accel_y, accel_z,
    // sensor_timestamp, touch0_contact, touch1_contact, battery_raw = 16
    try std.testing.expectEqual(@as(usize, 16), fields.map.count());
}

test "dualsense.toml commands count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const cmds = cfg.commands orelse return error.NoCommands;
    // rumble + led = 2
    try std.testing.expectEqual(@as(usize, 2), cmds.map.count());
}

test "dualsense.toml output axes and buttons count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const out = cfg.output orelse return error.NoOutput;
    const axes = out.axes orelse return error.NoAxes;
    const buttons = out.buttons orelse return error.NoButtons;
    // left_x, left_y, right_x, right_y, lt, rt = 6
    try std.testing.expectEqual(@as(usize, 6), axes.map.count());
    // A, B, X, Y, LB, RB, Select, Start, Home, LS, RS, TouchPad, Mic = 13
    try std.testing.expectEqual(@as(usize, 13), buttons.map.count());
}

const emulate_toml =
    \\[device]
    \\name = "My Device"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 4
    \\[output]
    \\emulate = "xbox-360"
;

test "emulate preset resolves vid/pid/name and axes/buttons" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, emulate_toml);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x028e), out.pid);
    try std.testing.expectEqualStrings("Xbox 360 Controller", out.name.?);
    try std.testing.expect(out.axes != null);
    try std.testing.expect(out.buttons != null);
}

test "emulate preset: explicit vid overrides preset" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1234
        \\pid = 0x5678
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "dualsense"
        \\vid = 0xdead
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqual(@as(?i64, 0xdead), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0ce6), out.pid);
}

test "emulate preset: unknown preset returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1234
        \\pid = 0x5678
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "no-such-preset"
    ;
    try std.testing.expectError(error.UnknownPreset, parseString(allocator, toml_str));
}

// T5: config boundary cases

test "T5: VID=0 is a valid config value" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "wildcard"
        \\vid = 0
        \\pid = 0
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqual(@as(i64, 0), result.value.device.vid);
}

test "T5: empty device name parses and validates without error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = ""
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("", result.value.device.name);
}
