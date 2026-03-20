const std = @import("std");
const state = @import("state.zig");
const device = @import("../config/device.zig");

pub const GamepadStateDelta = state.GamepadStateDelta;
pub const ButtonId = state.ButtonId;
pub const DeviceConfig = device.DeviceConfig;
pub const ReportConfig = device.ReportConfig;

pub const ProcessError = error{ ChecksumMismatch, MalformedConfig };

pub const Interpreter = struct {
    config: *const DeviceConfig,

    pub fn init(config: *const DeviceConfig) Interpreter {
        return .{ .config = config };
    }

    pub fn processReport(
        self: *const Interpreter,
        interface_id: u8,
        raw: []const u8,
    ) ProcessError!?GamepadStateDelta {
        const report = matchReport(self.config, interface_id, raw) orelse return null;
        if (raw.len < @as(usize, @intCast(report.size))) return null;
        try verifyChecksum(report, raw);
        var delta = GamepadStateDelta{};
        try extractAndFill(report, raw, &delta);
        return delta;
    }
};

fn matchReport(cfg: *const DeviceConfig, interface_id: u8, raw: []const u8) ?*const ReportConfig {
    for (cfg.report) |*report| {
        if (report.interface != @as(i64, interface_id)) continue;
        if (report.match) |m| {
            if (!checkMatch(m, raw)) continue;
        }
        return report;
    }
    return null;
}

fn checkMatch(m: device.MatchConfig, raw: []const u8) bool {
    const off: usize = @intCast(m.offset);
    if (raw.len < off + m.expect.len) return false;
    for (m.expect, 0..) |byte, i| {
        if (raw[off + i] != @as(u8, @intCast(byte))) return false;
    }
    return true;
}

fn verifyChecksum(report: *const ReportConfig, raw: []const u8) ProcessError!void {
    const cs = report.checksum orelse return;
    const range_start: usize = @intCast(cs.range[0]);
    const range_end: usize = @intCast(cs.range[1]);
    const data = raw[range_start..range_end];
    const expect_off: usize = @intCast(cs.expect.offset);

    if (std.mem.eql(u8, cs.algo, "sum8")) {
        var sum: u8 = 0;
        for (data) |b| sum +%= b;
        if (sum != raw[expect_off]) return ProcessError.ChecksumMismatch;
    } else if (std.mem.eql(u8, cs.algo, "xor")) {
        var xv: u8 = 0;
        for (data) |b| xv ^= b;
        if (xv != raw[expect_off]) return ProcessError.ChecksumMismatch;
    } else if (std.mem.eql(u8, cs.algo, "crc32")) {
        var crc = std.hash.crc.Crc32IsoHdlc.init();
        if (cs.seed) |seed| {
            const seed_byte: u8 = @intCast(seed & 0xff);
            crc.update(&[_]u8{seed_byte});
        }
        crc.update(data);
        const computed = crc.final();
        const stored = std.mem.readInt(u32, raw[expect_off..][0..4], .little);
        if (computed != stored) return ProcessError.ChecksumMismatch;
    }
}

fn extractAndFill(report: *const ReportConfig, raw: []const u8, delta: *GamepadStateDelta) ProcessError!void {
    if (report.fields) |fields| {
        var it = fields.map.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const field = entry.value_ptr.*;
            const off: usize = @intCast(field.offset);
            var val: i64 = readField(raw, off, field.type);
            if (field.transform) |tr| val = applyTransformChain(val, tr, field.type);
            fillDeltaField(delta, name, val);
        }
    }

    if (report.button_group) |bg| {
        const src_off: usize = @intCast(bg.source.offset);
        const src_size: usize = @intCast(bg.source.size);
        const src_val = readUintBytes(raw, src_off, src_size);
        var bits: u32 = delta.buttons orelse 0;
        var btn_it = bg.map.map.iterator();
        while (btn_it.next()) |entry| {
            const btn_name = entry.key_ptr.*;
            const bit_idx: usize = @intCast(entry.value_ptr.*);
            const pressed = (src_val >> @intCast(bit_idx)) & 1 == 1;
            if (std.meta.stringToEnum(ButtonId, btn_name)) |btn_id| {
                const btn_bit: u5 = @intCast(@intFromEnum(btn_id));
                if (pressed) {
                    bits |= @as(u32, 1) << btn_bit;
                } else {
                    bits &= ~(@as(u32, 1) << btn_bit);
                }
            }
        }
        delta.buttons = bits;
    }
}

fn readUintBytes(raw: []const u8, off: usize, size: usize) u64 {
    var val: u64 = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        val |= @as(u64, raw[off + i]) << @intCast(i * 8);
    }
    return val;
}

fn readField(raw: []const u8, off: usize, type_str: []const u8) i64 {
    if (std.mem.eql(u8, type_str, "u8")) return raw[off];
    if (std.mem.eql(u8, type_str, "i8")) return @as(i8, @bitCast(raw[off]));
    if (std.mem.eql(u8, type_str, "u16le")) return std.mem.readInt(u16, raw[off..][0..2], .little);
    if (std.mem.eql(u8, type_str, "i16le")) return std.mem.readInt(i16, raw[off..][0..2], .little);
    if (std.mem.eql(u8, type_str, "u16be")) return std.mem.readInt(u16, raw[off..][0..2], .big);
    if (std.mem.eql(u8, type_str, "i16be")) return std.mem.readInt(i16, raw[off..][0..2], .big);
    if (std.mem.eql(u8, type_str, "u32le")) return std.mem.readInt(u32, raw[off..][0..4], .little);
    if (std.mem.eql(u8, type_str, "i32le")) return std.mem.readInt(i32, raw[off..][0..4], .little);
    return 0;
}

fn typeMax(type_str: []const u8) i64 {
    if (std.mem.eql(u8, type_str, "u8")) return 255;
    if (std.mem.eql(u8, type_str, "i8")) return 127;
    if (std.mem.eql(u8, type_str, "u16le") or std.mem.eql(u8, type_str, "u16be")) return 65535;
    if (std.mem.eql(u8, type_str, "i16le") or std.mem.eql(u8, type_str, "i16be")) return 32767;
    if (std.mem.eql(u8, type_str, "u32le") or std.mem.eql(u8, type_str, "u32be")) return 4294967295;
    if (std.mem.eql(u8, type_str, "i32le") or std.mem.eql(u8, type_str, "i32be")) return 2147483647;
    return 1;
}

fn applyTransformChain(initial: i64, chain: []const u8, type_str: []const u8) i64 {
    var val = initial;
    var pos: usize = 0;
    var depth: usize = 0;
    var seg_start: usize = 0;
    while (pos < chain.len) : (pos += 1) {
        switch (chain[pos]) {
            '(' => depth += 1,
            ')' => if (depth > 0) { depth -= 1; },
            ',' => if (depth == 0) {
                val = applyTransform(val, std.mem.trim(u8, chain[seg_start..pos], " \t"), type_str);
                seg_start = pos + 1;
            },
            else => {},
        }
    }
    return applyTransform(val, std.mem.trim(u8, chain[seg_start..], " \t"), type_str);
}

fn applyTransform(val: i64, seg: []const u8, type_str: []const u8) i64 {
    if (std.mem.eql(u8, seg, "negate")) return -val;
    if (std.mem.eql(u8, seg, "abs")) return @intCast(@abs(val));
    if (std.mem.startsWith(u8, seg, "scale(")) return applyScale(val, seg, type_str);
    if (std.mem.startsWith(u8, seg, "clamp(")) return applyClamp(val, seg);
    if (std.mem.startsWith(u8, seg, "deadzone(")) return applyDeadzone(val, seg);
    return val;
}

fn parseArgs2(seg: []const u8) struct { a: i64, b: i64 } {
    const inner_start = std.mem.indexOfScalar(u8, seg, '(') orelse return .{ .a = 0, .b = 0 };
    const inner_end = std.mem.lastIndexOfScalar(u8, seg, ')') orelse return .{ .a = 0, .b = 0 };
    const args_str = seg[inner_start + 1 .. inner_end];
    var it = std.mem.splitScalar(u8, args_str, ',');
    const a_str = std.mem.trim(u8, it.next() orelse "0", " \t");
    const b_str = std.mem.trim(u8, it.next() orelse "0", " \t");
    const a = std.fmt.parseInt(i64, a_str, 10) catch 0;
    const b = std.fmt.parseInt(i64, b_str, 10) catch 0;
    return .{ .a = a, .b = b };
}

fn parseArgs1(seg: []const u8) i64 {
    const inner_start = std.mem.indexOfScalar(u8, seg, '(') orelse return 0;
    const inner_end = std.mem.lastIndexOfScalar(u8, seg, ')') orelse return 0;
    const arg_str = std.mem.trim(u8, seg[inner_start + 1 .. inner_end], " \t");
    return std.fmt.parseInt(i64, arg_str, 10) catch 0;
}

fn applyScale(val: i64, seg: []const u8, type_str: []const u8) i64 {
    const args = parseArgs2(seg);
    const out_min = args.a;
    const out_max = args.b;
    const t_max = typeMax(type_str);
    if (t_max == 0) return val;
    // val * (out_max - out_min) / type_max + out_min
    return @divTrunc(val * (out_max - out_min), t_max) + out_min;
}

fn applyClamp(val: i64, seg: []const u8) i64 {
    const args = parseArgs2(seg);
    return std.math.clamp(val, args.a, args.b);
}

fn applyDeadzone(val: i64, seg: []const u8) i64 {
    const threshold = parseArgs1(seg);
    return if (@abs(val) < threshold) 0 else val;
}

fn fillDeltaField(delta: *GamepadStateDelta, name: []const u8, val: i64) void {
    if (std.mem.eql(u8, name, "left_x") or std.mem.eql(u8, name, "ax")) {
        delta.ax = @truncate(val);
    } else if (std.mem.eql(u8, name, "left_y") or std.mem.eql(u8, name, "ay")) {
        delta.ay = @truncate(val);
    } else if (std.mem.eql(u8, name, "right_x") or std.mem.eql(u8, name, "rx")) {
        delta.rx = @truncate(val);
    } else if (std.mem.eql(u8, name, "right_y") or std.mem.eql(u8, name, "ry")) {
        delta.ry = @truncate(val);
    } else if (std.mem.eql(u8, name, "lt")) {
        delta.lt = @intCast(val & 0xff);
    } else if (std.mem.eql(u8, name, "rt")) {
        delta.rt = @intCast(val & 0xff);
    } else if (std.mem.eql(u8, name, "gyro_x")) {
        delta.gyro_x = @truncate(val);
    } else if (std.mem.eql(u8, name, "gyro_y")) {
        delta.gyro_y = @truncate(val);
    } else if (std.mem.eql(u8, name, "gyro_z")) {
        delta.gyro_z = @truncate(val);
    } else if (std.mem.eql(u8, name, "accel_x")) {
        delta.accel_x = @truncate(val);
    } else if (std.mem.eql(u8, name, "accel_y")) {
        delta.accel_y = @truncate(val);
    } else if (std.mem.eql(u8, name, "accel_z")) {
        delta.accel_z = @truncate(val);
    }
    // unknown fields silently ignored
}

// --- tests ---

const testing = std.testing;

// Vader 5 IF1 extended report: 32 bytes
// [0..2] = magic 0x5a 0xa5 0xef
// [3..4] = left_x i16le
// [5..6] = left_y i16le (negated by transform)
// [7..8] = right_x i16le
// [9..10] = right_y i16le (negated)
// [11..12] = button_group source (2 bytes)
// [13..14] = ext button_group source (2 bytes)
// [15] = lt u8
// [16] = rt u8
// [17..18] = gyro_x i16le
// [19..20] = gyro_y i16le
// [21..22] = gyro_z i16le
// [23..24] = accel_x i16le
// [25..26] = accel_y i16le
// [27..28] = accel_z i16le
// [29..31] = padding

const vader5_toml =
    \\[device]
    \\name = "Test Vader 5"
    \\vid = 0x37d7
    \\pid = 0x2401
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
    \\left_x  = { offset = 3, type = "i16le" }
    \\left_y  = { offset = 5, type = "i16le", transform = "negate" }
    \\right_x = { offset = 7, type = "i16le" }
    \\right_y = { offset = 9, type = "i16le", transform = "negate" }
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
    \\source = { offset = 11, size = 2 }
    \\map = { A = 0, B = 1, X = 3, Y = 4, LB = 6, RB = 7, Select = 10, Start = 11, LS = 12, RS = 13, DPadDown = 14, DPadLeft = 15 }
;

const vader5_if0_toml =
    \\[device]
    \\name = "Test Vader 5"
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
    \\right_x = { offset = 7, type = "i16le" }
;

fn makeIf1Sample() [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    // left_x = 1000
    std.mem.writeInt(i16, raw[3..5], 1000, .little);
    // left_y = -500 → after negate → 500
    std.mem.writeInt(i16, raw[5..7], -500, .little);
    // right_x = 200
    std.mem.writeInt(i16, raw[7..9], 200, .little);
    // right_y = -300 → after negate → 300
    std.mem.writeInt(i16, raw[9..11], -300, .little);
    // button_group: A=bit0, B=bit1 → byte[11]=0x03, byte[12]=0x00
    raw[11] = 0x03;
    raw[12] = 0x00;
    raw[15] = 128; // lt
    raw[16] = 64; // rt
    std.mem.writeInt(i16, raw[17..19], 100, .little); // gyro_x
    std.mem.writeInt(i16, raw[19..21], 200, .little); // gyro_y
    std.mem.writeInt(i16, raw[21..23], 300, .little); // gyro_z
    std.mem.writeInt(i16, raw[23..25], -100, .little); // accel_x
    std.mem.writeInt(i16, raw[25..27], -200, .little); // accel_y
    std.mem.writeInt(i16, raw[27..29], -300, .little); // accel_z
    return raw;
}

test "IF1 sample: axes, buttons, IMU" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = makeIf1Sample();
    const delta = (try interp.processReport(1, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 1000), delta.ax);
    try testing.expectEqual(@as(?i16, 500), delta.ay); // negated
    try testing.expectEqual(@as(?i16, 200), delta.rx);
    try testing.expectEqual(@as(?i16, 300), delta.ry); // negated
    try testing.expectEqual(@as(?u8, 128), delta.lt);
    try testing.expectEqual(@as(?u8, 64), delta.rt);
    try testing.expectEqual(@as(?i16, 100), delta.gyro_x);
    try testing.expectEqual(@as(?i16, 200), delta.gyro_y);
    try testing.expectEqual(@as(?i16, 300), delta.gyro_z);
    try testing.expectEqual(@as(?i16, -100), delta.accel_x);
    try testing.expectEqual(@as(?i16, -200), delta.accel_y);
    try testing.expectEqual(@as(?i16, -300), delta.accel_z);
    // A=bit0, B=bit1 both pressed
    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_bit: u5 = @intCast(@intFromEnum(ButtonId.B));
    try testing.expect(btns & (@as(u32, 1) << a_bit) != 0);
    try testing.expect(btns & (@as(u32, 1) << b_bit) != 0);
}

test "match miss: wrong magic returns null" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = makeIf1Sample();
    raw[0] = 0x00; // break magic
    const result = try interp.processReport(1, &raw);
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
}

test "short raw returns null" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = [_]u8{ 0x5a, 0xa5, 0xef, 0x01 }; // only 4 bytes, report.size=32
    const result = try interp.processReport(1, &raw);
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
}

test "wrong interface_id returns null" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = makeIf1Sample();
    const result = try interp.processReport(0, &raw); // IF0, no match
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
}

test "different interface_id matches different report" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_if0_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // IF1 sample
    const if1_raw = makeIf1Sample();
    const d1 = (try interp.processReport(1, &if1_raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 1000), d1.ax);

    // IF0 sample: 20 bytes, byte[0]=0x00
    var if0_raw = [_]u8{0} ** 20;
    if0_raw[0] = 0x00;
    std.mem.writeInt(i16, if0_raw[7..9], 500, .little); // right_x
    const d2 = (try interp.processReport(0, &if0_raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 500), d2.rx);
    try testing.expectEqual(@as(?i16, null), d2.ax); // not in IF0 report
}

test "checksum sum8 mismatch returns error" {
    const allocator = testing.allocator;
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
        \\size = 6
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "sum8"
        \\range = [0, 4]
        \\expect = { offset = 4, type = "u8" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // sum of bytes[0..4] = 0xAA + 0x01 + 0x02 + 0x03 = 0xB0; put wrong value 0x00
    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x00, 0x00 };
    try testing.expectError(ProcessError.ChecksumMismatch, interp.processReport(0, &raw));
}

test "checksum sum8 correct passes" {
    const allocator = testing.allocator;
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
        \\size = 6
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "sum8"
        \\range = [0, 4]
        \\expect = { offset = 4, type = "u8" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // sum = 0xAA + 0x01 + 0x02 + 0x03 = 0xB0
    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0xB0, 0x00 };
    _ = try interp.processReport(0, &raw);
}

test "checksum xor" {
    const allocator = testing.allocator;
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
        \\size = 6
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "xor"
        \\range = [0, 4]
        \\expect = { offset = 4, type = "u8" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // xor = 0xAA ^ 0x01 ^ 0x02 ^ 0x03 = 0xAA
    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0xAA, 0x00 };
    _ = try interp.processReport(0, &raw);
}

test "transform negate" {
    const allocator = testing.allocator;
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
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\left_x = { offset = 2, type = "i16le", transform = "negate" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    std.mem.writeInt(i16, raw[2..4], 300, .little);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, -300), delta.ax);
}

test "transform scale" {
    const allocator = testing.allocator;
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
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\left_x = { offset = 2, type = "i16le", transform = "scale(-32768, 32767)" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    // val = 32767 (max i16le), scale(-32768, 32767) of i16le type_max=32767 → 32767
    std.mem.writeInt(i16, raw[2..4], 32767, .little);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 32767), delta.ax);
}

test "transform clamp" {
    const allocator = testing.allocator;
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
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\lt = { offset = 2, type = "u8", transform = "clamp(0, 200)" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    raw[2] = 255; // exceeds 200
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?u8, 200), delta.lt);
}

test "transform chain scale+negate" {
    const allocator = testing.allocator;
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
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\left_x = { offset = 2, type = "i16le", transform = "scale(-32768, 32767), negate" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    std.mem.writeInt(i16, raw[2..4], 32767, .little);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    // scale(32767) = 32767, negate → -32767
    try testing.expectEqual(@as(?i16, -32767), delta.ax);
}

test "button_group batch extraction" {
    const allocator = testing.allocator;
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
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.button_group]
        \\source = { offset = 1, size = 2 }
        \\map = { A = 0, B = 1, X = 3, Y = 4 }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // bits: A=0, X=3 set → byte 1 = 0b00001001 = 0x09
    const raw = [_]u8{ 0x01, 0x09, 0x00, 0x00 };
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_bit: u5 = @intCast(@intFromEnum(ButtonId.B));
    const x_bit: u5 = @intCast(@intFromEnum(ButtonId.X));
    const y_bit: u5 = @intCast(@intFromEnum(ButtonId.Y));
    try testing.expect(btns & (@as(u32, 1) << a_bit) != 0); // A pressed
    try testing.expect(btns & (@as(u32, 1) << b_bit) == 0); // B not pressed
    try testing.expect(btns & (@as(u32, 1) << x_bit) != 0); // X pressed
    try testing.expect(btns & (@as(u32, 1) << y_bit) == 0); // Y not pressed
}
