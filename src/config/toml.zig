const std = @import("std");
const toml = @import("toml");
const device = @import("device.zig");

// Re-export all types from device.zig for backward compat.
pub const InterfaceConfig = device.InterfaceConfig;
pub const InitConfig = device.InitConfig;
pub const DeviceInfo = device.DeviceInfo;
pub const MatchConfig = device.MatchConfig;
pub const FieldConfig = device.FieldConfig;
pub const ButtonGroupSource = device.ButtonGroupSource;
pub const ButtonGroupConfig = device.ButtonGroupConfig;
pub const ChecksumExpect = device.ChecksumExpect;
pub const ChecksumConfig = device.ChecksumConfig;
pub const ReportConfig = device.ReportConfig;
pub const CommandConfig = device.CommandConfig;
pub const AxisConfig = device.AxisConfig;
pub const DpadOutputConfig = device.DpadOutputConfig;
pub const FfConfig = device.FfConfig;
pub const AuxConfig = device.AuxConfig;
pub const OutputConfig = device.OutputConfig;
pub const DeviceConfig = device.DeviceConfig;

pub const ParseResult = device.ParseResult;
pub const parseString = device.parseString;
pub const parseFile = device.parseFile;

const input_codes = @import("input_codes.zig");

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

test "parseString: valid config" {
    const allocator = std.testing.allocator;

    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const cfg = result.value;

    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
    try std.testing.expectEqualStrings("standard", cfg.report[1].name);

    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x2401), cfg.device.pid);
    try std.testing.expect(cfg.device.init != null);
    try std.testing.expectEqual(@as(usize, 2), cfg.device.init.?.response_prefix.len);
    try std.testing.expectEqual(@as(i64, 0x5a), cfg.device.init.?.response_prefix[0]);
    try std.testing.expectEqual(@as(i64, 0xa5), cfg.device.init.?.response_prefix[1]);

    try std.testing.expect(cfg.report[0].match != null);
    try std.testing.expect(cfg.report[0].fields != null);
    try std.testing.expect(cfg.report[0].checksum != null);
    try std.testing.expect(cfg.report[1].checksum == null);

    try std.testing.expect(cfg.commands != null);
    try std.testing.expect(cfg.commands.?.map.contains("rumble"));
    try std.testing.expect(cfg.commands.?.map.contains("led"));
}

test "OutputConfig: parsed fields" {
    const allocator = std.testing.allocator;

    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqualStrings("Test Output", out.name.?);
    try std.testing.expectEqual(@as(?i64, 0x3820), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0001), out.pid);

    try std.testing.expect(out.axes != null);
    const axis = out.axes.?.map.get("left_x").?;
    try std.testing.expectEqualStrings("ABS_X", axis.code);
    try std.testing.expectEqual(@as(i64, -32768), axis.min);
    try std.testing.expectEqual(@as(i64, 32767), axis.max);
    try std.testing.expectEqual(@as(?i64, 16), axis.fuzz);
    try std.testing.expectEqual(@as(?i64, 128), axis.flat);

    try std.testing.expect(out.buttons != null);
    const btn = out.buttons.?.map.get("A").?;
    try std.testing.expectEqualStrings("BTN_SOUTH", btn);

    try std.testing.expect(out.dpad != null);
    try std.testing.expectEqualStrings("hat", out.dpad.?.type);

    try std.testing.expect(out.force_feedback != null);
    try std.testing.expectEqualStrings("rumble", out.force_feedback.?.type);
    try std.testing.expectEqual(@as(?i64, 16), out.force_feedback.?.max_effects);
}

test "OutputConfig: code resolution after parse" {
    const allocator = std.testing.allocator;

    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const out = result.value.output.?;
    const axis = out.axes.?.map.get("left_x").?;
    const code = try input_codes.resolveAbsCode(axis.code);
    try std.testing.expectEqual(@as(u16, 0x00), code);

    const btn_name = out.buttons.?.map.get("A").?;
    const btn_code = try input_codes.resolveBtnCode(btn_name);
    try std.testing.expectEqual(@as(u16, 0x130), btn_code);
}

test "parseFile: missing file returns error" {
    const result = parseFile(std.testing.allocator, "/nonexistent/path/config.toml");
    try std.testing.expectError(error.FileNotFound, result);
}

test "parseString: malformed TOML returns error" {
    const result = parseString(std.testing.allocator, "this is not [valid toml = [[[");
    try std.testing.expect(result == error.UnexpectedToken or std.meta.isError(result));
}
