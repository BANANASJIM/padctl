const std = @import("std");
const toml = @import("toml");
const state = @import("../core/state.zig");
const presets = @import("presets.zig");
const input_codes = @import("input_codes.zig");

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
    interface: ?i64 = null,
    report_size: ?i64 = null,
};

pub const DeviceInfo = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    interface: []const InterfaceConfig,
    init: ?InitConfig = null,
    mode: ?[]const u8 = null,
    block_kernel_drivers: ?[]const []const u8 = null,
};

pub const MatchConfig = struct {
    offset: i64,
    expect: []const i64,
};

pub const FieldConfig = struct {
    offset: ?i64 = null,
    type: ?[]const u8 = null,
    bits: ?[]const i64 = null,
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

pub const CommandChecksumConfig = struct {
    algo: []const u8,
    range: []const i64,
    offset: i64,
    seed: ?i64 = null,
};

pub const CommandConfig = struct {
    interface: i64,
    template: []const u8,
    checksum: ?CommandChecksumConfig = null,
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

pub const TouchpadConfig = struct {
    name: ?[]const u8 = null,
    x_min: i64 = 0,
    x_max: i64 = 0,
    y_min: i64 = 0,
    y_max: i64 = 0,
    max_slots: ?i64 = null,
};

pub const MappingEntry = struct {
    event: []const u8,
    range: ?[]const i64 = null,
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
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
    touchpad: ?TouchpadConfig = null,
    mapping: ?toml.HashMap(MappingEntry) = null,
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

const valid_transforms = [_][]const u8{ "negate", "abs", "scale", "clamp", "deadzone" };

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

const max_transforms = state.MAX_TRANSFORMS;

fn isValidTransformChain(chain: []const u8) bool {
    var pos: usize = 0;
    var depth: usize = 0;
    var seg_start: usize = 0;
    var count: usize = 0;
    while (pos < chain.len) : (pos += 1) {
        switch (chain[pos]) {
            '(' => depth += 1,
            ')' => if (depth > 0) {
                depth -= 1;
            },
            ',' => if (depth == 0) {
                if (!isValidTransform(chain[seg_start..pos])) return false;
                count += 1;
                if (count > max_transforms) return false;
                seg_start = pos + 1;
            },
            else => {},
        }
    }
    count += 1;
    if (count > max_transforms) return false;
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

                if (field.bits) |bits| {
                    // bits mode: mutual exclusivity
                    if (field.offset != null) return error.InvalidConfig;
                    if (field.transform != null) return error.InvalidConfig;
                    if (bits.len != 3) return error.InvalidConfig;
                    if (bits[1] < 0 or bits[1] > 7) return error.InvalidConfig;
                    if (bits[2] < 1 or bits[2] > 32) return error.InvalidConfig;
                    if (bits[0] < 0) return error.InvalidConfig;
                    // bounds check: byte_offset + ceil((start_bit + bit_count) / 8) <= report.size
                    const span = @divTrunc(bits[1] + bits[2] + 7, 8);
                    if (span > 4) return error.InvalidConfig;
                    if (bits[0] + span > report.size) return error.OffsetOutOfBounds;
                    // type must be null, "unsigned", or "signed"
                    if (field.type) |t| {
                        if (!std.mem.eql(u8, t, "unsigned") and !std.mem.eql(u8, t, "signed"))
                            return error.InvalidConfig;
                    }
                } else {
                    // standard mode: both offset and type required
                    const offset = field.offset orelse return error.InvalidConfig;
                    const type_str = field.type orelse return error.InvalidConfig;
                    const sz = fieldTypeSize(type_str) orelse return error.InvalidConfig;
                    if (offset < 0 or offset + sz > report.size) return error.OffsetOutOfBounds;
                }

                if (field.transform) |tr| {
                    if (!isValidTransformChain(tr)) return error.InvalidConfig;
                }
            }
        }

        if (report.button_group) |bg| {
            if (bg.source.offset + bg.source.size > report.size) return error.OffsetOutOfBounds;
            const bg_source_size = bg.source.size;
            const is_generic = if (cfg.device.mode) |m| std.mem.eql(u8, m, "generic") else false;
            var it = bg.map.map.iterator();
            while (it.next()) |entry| {
                if (!is_generic) {
                    const btn_name = entry.key_ptr.*;
                    _ = std.meta.stringToEnum(ButtonId, btn_name) orelse return error.InvalidConfig;
                }
                const bit_val = entry.value_ptr.*;
                if (bit_val < 0 or bit_val >= bg_source_size * 8) return error.InvalidConfig;
            }
        }

        if (report.match) |m| {
            if (m.offset < 0) return error.InvalidConfig;
            for (m.expect) |byte| {
                if (byte < 0 or byte > 255) return error.InvalidConfig;
            }
            if (m.offset + @as(i64, @intCast(m.expect.len)) > report.size) return error.InvalidConfig;
        }

        if (report.checksum) |cs| {
            if (cs.range.len != 2) return error.InvalidConfig;
            if (cs.range[0] < 0 or cs.range[1] > report.size) return error.InvalidConfig;
            if (cs.range[0] >= cs.range[1]) return error.InvalidConfig;
            if (cs.expect.offset < 0) return error.InvalidConfig;
            const expect_end = cs.expect.offset + if (std.mem.eql(u8, cs.algo, "crc32")) @as(i64, 4) else 1;
            if (expect_end > report.size) return error.InvalidConfig;
        }
    }

    // Generic mode validation
    if (cfg.device.mode) |m| {
        if (std.mem.eql(u8, m, "generic")) {
            const out = cfg.output orelse return error.InvalidConfig;
            const mapping = out.mapping orelse return error.InvalidConfig;
            var it = mapping.map.iterator();
            while (it.next()) |entry| {
                const me = entry.value_ptr.*;
                _ = input_codes.resolveEventCode(me.event) catch return error.InvalidConfig;
                // ABS events require range
                if (std.mem.startsWith(u8, me.event, "ABS_")) {
                    const range = me.range orelse return error.InvalidConfig;
                    if (range.len != 2) return error.InvalidConfig;
                }
            }
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
    \\range = [0, 27]
    \\expect = { offset = 28, type = "u32le" }
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

test "device: load flydigi/vader5.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x2401), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 1), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
}

test "device: valid config parses and validates" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
}

test "device: offset out of bounds returns error" {
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

test "device: duplicate field name returns error" {
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

test "device: invalid transform returns error" {
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

test "device: transform chain exceeding max count returns error" {
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
        \\x = { offset = 0, type = "u8", transform = "abs, abs, abs, abs, abs, abs, abs, abs, abs" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: transform chain at max count is accepted" {
    const allocator = std.testing.allocator;
    const ok =
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
        \\x = { offset = 0, type = "u8", transform = "abs, abs, abs, abs, abs, abs, abs, abs" }
    ;
    const parsed = try parseString(allocator, ok);
    defer parsed.deinit();
}

test "device: unknown button name returns error" {
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

test "device: load devices/sony/dualsense.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Sony DualSense", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x054c), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x0ce6), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("usb", cfg.report[0].name);
    try std.testing.expectEqualStrings("bt", cfg.report[1].name);
}

test "device: dualsense.toml report field count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const fields = cfg.report[0].fields orelse return error.NoFields;
    // left_x, left_y, right_x, right_y, lt, rt,
    // gyro_x, gyro_y, gyro_z, accel_x, accel_y, accel_z,
    // sensor_timestamp, touch0_contact, touch1_contact, battery_level = 16
    try std.testing.expectEqual(@as(usize, 16), fields.map.count());
}

test "device: dualsense.toml commands count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const cmds = cfg.commands orelse return error.NoCommands;
    // rumble + led + 4 adaptive trigger = 6
    try std.testing.expectEqual(@as(usize, 6), cmds.map.count());
}

test "device: dualsense.toml output axes and buttons count" {
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

test "device: emulate preset resolves vid/pid/name and axes/buttons" {
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

test "device: emulate preset: explicit vid overrides preset" {
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

test "device: emulate preset: unknown preset returns error" {
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

test "device: VID=0 is a valid config value" {
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

test "device: empty device name parses and validates without error" {
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

// T4: bits DSL config validation tests

test "device: bits field parses and validates" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12] }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const fields = result.value.report[0].fields orelse return error.NoFields;
    var it = fields.map.iterator();
    const entry = it.next() orelse return error.Empty;
    const fc = entry.value_ptr.*;
    try std.testing.expect(fc.bits != null);
    try std.testing.expect(fc.offset == null);
}

test "device: bits field with signed type" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 4, 12], type = "signed" }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
}

test "device: bits field with invalid type returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], type = "i16le" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits out of bounds returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
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
        \\left_x = { bits = [3, 0, 12] }
    ;
    try std.testing.expectError(error.OffsetOutOfBounds, parseString(allocator, toml_str));
}

test "device: bits with offset present returns error (mutual exclusivity)" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], offset = 2 }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: missing both offset and bits returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { type = "u8" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits with transform returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], transform = "negate" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits span > 4 bytes returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 64
        \\[report.fields]
        \\left_x = { bits = [0, 1, 32] }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: lookup transform is rejected" {
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
        \\x = { offset = 0, type = "u8", transform = "lookup" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: generic mode: valid config parses" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[report.button_group]
        \\source = { offset = 4, size = 1 }
        \\map = { gear_up = 0 }
        \\[output]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\[output.mapping]
        \\wheel = { event = "ABS_WHEEL", range = [-32768, 32767] }
        \\gear_up = { event = "BTN_GEAR_UP" }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("generic", result.value.device.mode.?);
}

test "device: generic mode: missing output.mapping returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[output]
        \\name = "Wheel"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: generic mode: unknown event code returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[output]
        \\name = "Wheel"
        \\[output.mapping]
        \\wheel = { event = "INVALID_CODE", range = [-100, 100] }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: generic mode: ABS event missing range returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[output]
        \\name = "Wheel"
        \\[output.mapping]
        \\wheel = { event = "ABS_WHEEL" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: fuzz parseString: no panic on arbitrary input" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) !void {
            const result = parseString(std.testing.allocator, input);
            if (result) |r| r.deinit() else |_| {}
        }
    }.run, .{});
}
