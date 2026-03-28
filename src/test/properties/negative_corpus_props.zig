// Negative test corpus for vader5 extended report (IF1, 32-byte, magic 5a a5 ef).
// Each case targets a specific malformed/boundary input and asserts processReport behaviour.
const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");

const Interpreter = interpreter_mod.Interpreter;
const ButtonId = interpreter_mod.ButtonId;

// Inline TOML matching devices/flydigi/vader5.toml extended report.
const vader5_toml =
    \\[device]
    \\name = "Vader 5 Negative Corpus"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
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
    \\left_x  = { offset = 3,  type = "i16le" }
    \\left_y  = { offset = 5,  type = "i16le", transform = "negate" }
    \\right_x = { offset = 7,  type = "i16le" }
    \\right_y = { offset = 9,  type = "i16le", transform = "negate" }
    \\lt      = { offset = 15, type = "u8" }
    \\rt      = { offset = 16, type = "u8" }
    \\gyro_x  = { offset = 17, type = "i16le" }
    \\gyro_y  = { offset = 19, type = "i16le" }
    \\gyro_z  = { offset = 21, type = "i16le" }
    \\accel_x = { offset = 23, type = "i16le" }
    \\accel_y = { offset = 25, type = "i16le" }
    \\accel_z = { offset = 27, type = "i16le" }
    \\
    \\[report.button_group]
    \\source = { offset = 11, size = 4 }
    \\map = { DPadUp = 0, DPadRight = 1, DPadDown = 2, DPadLeft = 3, A = 4, B = 5, Select = 6, X = 7, Y = 8, Start = 9, LB = 10, RB = 11, LS = 14, RS = 15, C = 16, Z = 17, M1 = 18, M2 = 19, M3 = 20, M4 = 21, LM = 22, RM = 23, O = 24, Home = 27 }
;

fn validReport() [32]u8 {
    var r = [_]u8{0} ** 32;
    r[0] = 0x5a;
    r[1] = 0xa5;
    r[2] = 0xef;
    return r;
}

fn interp(allocator: std.mem.Allocator) !struct { parsed: device_mod.ParseResult, i: Interpreter } {
    const parsed = try device_mod.parseString(allocator, vader5_toml);
    return .{ .parsed = parsed, .i = Interpreter.init(&parsed.value) };
}

// 1. All-zero report: magic bytes won't match → null
test "negative: all-zero report returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    const raw = [_]u8{0} ** 32;
    const result = try ctx.i.processReport(1, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 2. All-0xFF report: magic bytes won't match → null
test "negative: all-0xFF report returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    const raw = [_]u8{0xff} ** 32;
    const result = try ctx.i.processReport(1, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 3. Oversized report (64 bytes): extra bytes ignored, valid match succeeds
test "negative: oversized report (64 bytes) still matches and extracts" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], 1234, .little);
    const result = try ctx.i.processReport(1, &raw);
    const delta = result orelse return error.TestUnexpectedNull;
    try testing.expectEqual(@as(?i16, 1234), delta.ax);
}

// 4. 1-byte report: too short to match magic → null
test "negative: 1-byte report returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    const raw = [_]u8{0x5a};
    const result = try ctx.i.processReport(1, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 5. Empty report: 0 bytes → null
test "negative: empty report returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    const raw = [_]u8{};
    const result = try ctx.i.processReport(1, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 6. Match byte off by one (+1): magic[2] = 0xf0 instead of 0xef → null
test "negative: match byte off-by-one returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = validReport();
    raw[2] = 0xf0;
    const result = try ctx.i.processReport(1, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 7. Truncated mid-field: report is 17 bytes (enough for match, short of last fields)
//    size = 17 < config.size 32 → null (raw.len < report.size check in processReport)
test "negative: truncated mid-field (17 bytes) returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw_buf = validReport();
    const raw = raw_buf[0..17];
    const result = try ctx.i.processReport(1, raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 8. Wrong report ID (IF0 instead of IF1): interface mismatch → null
test "negative: wrong interface id returns null" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    const raw = validReport();
    const result = try ctx.i.processReport(0, &raw);
    try testing.expectEqual(@as(?@TypeOf(result.?), null), result);
}

// 9. Max axis values: 0x7FFF for all i16le fields → correctly extracted
test "negative: max axis values extracted correctly" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = validReport();
    // left_x = 0x7FFF, left_y = 0x7FFF (negate → -32767), right_x, right_y same
    std.mem.writeInt(i16, raw[3..5], std.math.maxInt(i16), .little);
    std.mem.writeInt(i16, raw[5..7], std.math.maxInt(i16), .little);
    std.mem.writeInt(i16, raw[7..9], std.math.maxInt(i16), .little);
    std.mem.writeInt(i16, raw[9..11], std.math.maxInt(i16), .little);
    const result = try ctx.i.processReport(1, &raw);
    const delta = result orelse return error.TestUnexpectedNull;
    try testing.expectEqual(@as(?i16, 32767), delta.ax);
    try testing.expectEqual(@as(?i16, -32767), delta.ay); // negated
    try testing.expectEqual(@as(?i16, 32767), delta.rx);
    try testing.expectEqual(@as(?i16, -32767), delta.ry); // negated
}

// 10. Min axis values: 0x8000 for all i16le fields → negate saturates to maxInt(i16)
test "negative: min axis values (0x8000) extracted and saturated" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = validReport();
    std.mem.writeInt(i16, raw[3..5], std.math.minInt(i16), .little);
    std.mem.writeInt(i16, raw[5..7], std.math.minInt(i16), .little);
    std.mem.writeInt(i16, raw[7..9], std.math.minInt(i16), .little);
    std.mem.writeInt(i16, raw[9..11], std.math.minInt(i16), .little);
    const result = try ctx.i.processReport(1, &raw);
    const delta = result orelse return error.TestUnexpectedNull;
    try testing.expectEqual(@as(?i16, -32768), delta.ax);
    // negate of minInt(i64) → maxInt(i64) → saturateCast to maxInt(i16)
    try testing.expectEqual(@as(?i16, 32767), delta.ay);
    try testing.expectEqual(@as(?i16, -32768), delta.rx);
    try testing.expectEqual(@as(?i16, 32767), delta.ry);
}

// 11. Button overflow: all button bits set → all buttons pressed, no panic
test "negative: all button bits set — no panic, buttons field populated" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = validReport();
    // button_group source: offset=11, size=4 → set all 32 bits
    raw[11] = 0xff;
    raw[12] = 0xff;
    raw[13] = 0xff;
    raw[14] = 0xff;
    const result = try ctx.i.processReport(1, &raw);
    const delta = result orelse return error.TestUnexpectedNull;
    const btns = delta.buttons orelse return error.TestUnexpectedNull;
    // Every mapped button should be pressed
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    const home_bit: u6 = @intCast(@intFromEnum(ButtonId.Home));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
    try testing.expect(btns & (@as(u64, 1) << home_bit) != 0);
}

// 12. Checksum correct but data garbage: config has no checksum, so any payload with
//     valid magic processes without error (demonstrates checksum-free path stability).
test "negative: garbage payload with valid magic processes without error" {
    const allocator = testing.allocator;
    var ctx = try interp(allocator);
    defer ctx.parsed.deinit();
    var raw = [_]u8{0xAB} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    // processReport must not panic or return an error; result may be anything
    const result = try ctx.i.processReport(1, &raw);
    try testing.expect(result != null);
}
