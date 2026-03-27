const std = @import("std");
const state = @import("state.zig");
const device = @import("../config/device.zig");

pub const GamepadStateDelta = state.GamepadStateDelta;
pub const ButtonId = state.ButtonId;
pub const DeviceConfig = device.DeviceConfig;
pub const ReportConfig = device.ReportConfig;

pub const ProcessError = error{ ChecksumMismatch, MalformedConfig };

// --- compile-time type catalogue ---

pub const FieldType = enum { u8, i8, u16le, i16le, u16be, i16be, u32le, i32le, u32be, i32be };

pub fn parseFieldType(s: []const u8) ?FieldType {
    return std.meta.stringToEnum(FieldType, s);
}

fn typeMaxByTag(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 4294967295,
        .i32le, .i32be => 2147483647,
    };
}

pub fn readFieldByTag(raw: []const u8, off: usize, t: FieldType) i64 {
    return switch (t) {
        .u8 => raw[off],
        .i8 => @as(i8, @bitCast(raw[off])),
        .u16le => std.mem.readInt(u16, raw[off..][0..2], .little),
        .i16le => std.mem.readInt(i16, raw[off..][0..2], .little),
        .u16be => std.mem.readInt(u16, raw[off..][0..2], .big),
        .i16be => std.mem.readInt(i16, raw[off..][0..2], .big),
        .u32le => std.mem.readInt(u32, raw[off..][0..4], .little),
        .i32le => std.mem.readInt(i32, raw[off..][0..4], .little),
        .u32be => std.mem.readInt(u32, raw[off..][0..4], .big),
        .i32be => std.mem.readInt(i32, raw[off..][0..4], .big),
    };
}

// --- bits DSL: sub-byte / cross-byte field extraction ---

pub fn extractBits(raw: []const u8, byte_offset: u16, start_bit: u3, bit_count: u6) u32 {
    const needed: u8 = (@as(u8, start_bit) + @as(u8, bit_count) + 7) / 8;
    var val: u32 = 0;
    for (0..needed) |i| {
        val |= @as(u32, raw[byte_offset + i]) << @intCast(i * 8);
    }
    val >>= start_bit;
    if (bit_count == 0) return 0;
    if (bit_count >= 32) return val;
    const shift: u5 = @intCast(bit_count);
    return val & ((@as(u32, 1) << shift) - 1);
}

pub fn signExtend(val: u32, bit_count: u6) i32 {
    if (bit_count == 0 or bit_count >= 32) return @bitCast(val);
    const shift: u5 = @intCast(32 - @as(u8, bit_count));
    return @as(i32, @bitCast(val << shift)) >> shift;
}

// --- compile-time field name catalogue ---

pub const FieldTag = enum {
    ax,
    ay,
    rx,
    ry,
    lt,
    rt,
    gyro_x,
    gyro_y,
    gyro_z,
    accel_x,
    accel_y,
    accel_z,
    touch0_x,
    touch0_y,
    touch1_x,
    touch1_y,
    touch0_active,
    touch1_active,
    battery_level,
    dpad,
    unknown,
};

pub fn parseFieldTag(name: []const u8) FieldTag {
    if (std.mem.eql(u8, name, "left_x") or std.mem.eql(u8, name, "ax")) return .ax;
    if (std.mem.eql(u8, name, "left_y") or std.mem.eql(u8, name, "ay")) return .ay;
    if (std.mem.eql(u8, name, "right_x") or std.mem.eql(u8, name, "rx")) return .rx;
    if (std.mem.eql(u8, name, "right_y") or std.mem.eql(u8, name, "ry")) return .ry;
    if (std.mem.eql(u8, name, "lt")) return .lt;
    if (std.mem.eql(u8, name, "rt")) return .rt;
    if (std.mem.eql(u8, name, "gyro_x")) return .gyro_x;
    if (std.mem.eql(u8, name, "gyro_y")) return .gyro_y;
    if (std.mem.eql(u8, name, "gyro_z")) return .gyro_z;
    if (std.mem.eql(u8, name, "accel_x")) return .accel_x;
    if (std.mem.eql(u8, name, "accel_y")) return .accel_y;
    if (std.mem.eql(u8, name, "accel_z")) return .accel_z;
    if (std.mem.eql(u8, name, "touch0_x")) return .touch0_x;
    if (std.mem.eql(u8, name, "touch0_y")) return .touch0_y;
    if (std.mem.eql(u8, name, "touch1_x")) return .touch1_x;
    if (std.mem.eql(u8, name, "touch1_y")) return .touch1_y;
    if (std.mem.eql(u8, name, "touch0_active")) return .touch0_active;
    if (std.mem.eql(u8, name, "touch1_active")) return .touch1_active;
    if (std.mem.eql(u8, name, "battery_level")) return .battery_level;
    if (std.mem.eql(u8, name, "dpad")) return .dpad;
    return .unknown;
}

fn saturateCast(comptime T: type, val: i64) T {
    if (val > std.math.maxInt(T)) return std.math.maxInt(T);
    if (val < std.math.minInt(T)) return std.math.minInt(T);
    return @intCast(val);
}

fn applyFieldTag(delta: *GamepadStateDelta, tag: FieldTag, val: i64) void {
    switch (tag) {
        .ax => delta.ax = saturateCast(i16, val),
        .ay => delta.ay = saturateCast(i16, val),
        .rx => delta.rx = saturateCast(i16, val),
        .ry => delta.ry = saturateCast(i16, val),
        .lt => delta.lt = @intCast(val & 0xff),
        .rt => delta.rt = @intCast(val & 0xff),
        .gyro_x => delta.gyro_x = saturateCast(i16, val),
        .gyro_y => delta.gyro_y = saturateCast(i16, val),
        .gyro_z => delta.gyro_z = saturateCast(i16, val),
        .accel_x => delta.accel_x = saturateCast(i16, val),
        .accel_y => delta.accel_y = saturateCast(i16, val),
        .accel_z => delta.accel_z = saturateCast(i16, val),
        .touch0_x => delta.touch0_x = saturateCast(i16, val),
        .touch0_y => delta.touch0_y = saturateCast(i16, val),
        .touch1_x => delta.touch1_x = saturateCast(i16, val),
        .touch1_y => delta.touch1_y = saturateCast(i16, val),
        .touch0_active => delta.touch0_active = val != 0,
        .touch1_active => delta.touch1_active = val != 0,
        .battery_level => delta.battery_level = @intCast(val & 0xff),
        .dpad => {
            // HID hat switch: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, 8+=neutral
            const HAT_X = [8]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
            const HAT_Y = [8]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };
            if (val >= 0 and val < 8) {
                const idx: usize = @intCast(val);
                delta.dpad_x = HAT_X[idx];
                delta.dpad_y = HAT_Y[idx];
            } else {
                delta.dpad_x = 0;
                delta.dpad_y = 0;
            }
        },
        .unknown => {},
    }
}

// --- pre-compiled transform chain ---

pub const TransformOp = enum { negate, abs, scale, clamp, deadzone };

pub const CompiledTransform = struct {
    op: TransformOp,
    a: i64 = 0,
    b: i64 = 0,
};

pub const MAX_TRANSFORMS = state.MAX_TRANSFORMS;

pub const CompiledTransformChain = struct {
    items: [MAX_TRANSFORMS]CompiledTransform = undefined,
    len: u8 = 0,
    type_tag: FieldType,
};

pub fn compileTransformChain(chain: []const u8, type_tag: FieldType) CompiledTransformChain {
    var result = CompiledTransformChain{ .type_tag = type_tag };
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
                if (result.len < MAX_TRANSFORMS) {
                    result.items[result.len] = compileTransformSeg(std.mem.trim(u8, chain[seg_start..pos], " \t"));
                    result.len += 1;
                } else {
                    std.log.warn("transform chain exceeds max {d}, ignoring segment", .{MAX_TRANSFORMS});
                }
                seg_start = pos + 1;
            },
            else => {},
        }
    }
    if (result.len < MAX_TRANSFORMS) {
        result.items[result.len] = compileTransformSeg(std.mem.trim(u8, chain[seg_start..], " \t"));
        result.len += 1;
    } else {
        std.log.warn("transform chain exceeds max {d}, ignoring segment", .{MAX_TRANSFORMS});
    }
    return result;
}

fn compileTransformSeg(seg: []const u8) CompiledTransform {
    if (std.mem.eql(u8, seg, "negate")) return .{ .op = .negate };
    if (std.mem.eql(u8, seg, "abs")) return .{ .op = .abs };
    if (std.mem.startsWith(u8, seg, "scale(")) {
        const args = parseArgs2(seg);
        return .{ .op = .scale, .a = args.a, .b = args.b };
    }
    if (std.mem.startsWith(u8, seg, "clamp(")) {
        const args = parseArgs2(seg);
        return .{ .op = .clamp, .a = args.a, .b = args.b };
    }
    if (std.mem.startsWith(u8, seg, "deadzone(")) {
        return .{ .op = .deadzone, .a = parseArgs1(seg) };
    }
    std.log.warn("unrecognized transform segment '{s}', treating as deadzone(0)", .{seg});
    return .{ .op = .deadzone, .a = 0 };
}

pub fn runTransformChain(initial: i64, chain: *const CompiledTransformChain) i64 {
    var val = initial;
    const t_max = typeMaxByTag(chain.type_tag);
    for (chain.items[0..chain.len]) |tr| {
        val = switch (tr.op) {
            .negate => if (val == std.math.minInt(i64)) std.math.maxInt(i64) else -val,
            .abs => blk: {
                const clamped = if (val == std.math.minInt(i64)) std.math.maxInt(i64) else val;
                break :blk @intCast(@abs(clamped));
            },
            .scale => blk: {
                if (t_max == 0) break :blk val;
                const v: i128 = val;
                break :blk @intCast(@divTrunc(v * (tr.b - tr.a), t_max) + tr.a);
            },
            .clamp => std.math.clamp(val, tr.a, tr.b),
            .deadzone => blk: {
                const t: u64 = if (tr.a < 0) 0 else @intCast(tr.a);
                break :blk if (@abs(val) < t) 0 else val;
            },
        };
    }
    return val;
}

// --- pre-compiled checksum algo ---

pub const ChecksumAlgo = enum { sum8, xor, crc32 };

pub const CompiledChecksum = struct {
    algo: ChecksumAlgo,
    range_start: usize,
    range_end: usize,
    expect_off: usize,
    seed: ?i64,
};

// --- pre-compiled report ---

const MAX_FIELDS = 32;
const MAX_BUTTONS = 32;
const MAX_REPORTS = 8;

pub const CompiledField = struct {
    tag: FieldTag,
    mode: enum { standard, bits },
    // standard mode
    type_tag: FieldType,
    offset: usize,
    // bits mode
    byte_offset: u16,
    start_bit: u3,
    bit_count: u6,
    is_signed: bool,
    // common
    transforms: CompiledTransformChain,
    has_transform: bool,
};

pub const CompiledButtonEntry = struct {
    btn_id: ButtonId,
    bit_idx: u5,
};

pub const CompiledButtonGroup = struct {
    src_off: usize,
    src_size: usize,
    entries: [MAX_BUTTONS]CompiledButtonEntry,
    count: u8,
};

pub const CompiledReport = struct {
    src: *const ReportConfig,
    checksum: ?CompiledChecksum,
    fields: [MAX_FIELDS]CompiledField,
    field_count: u8,
    button_group: ?CompiledButtonGroup,
};

fn compileReport(report: *const ReportConfig) CompiledReport {
    var cr = CompiledReport{
        .src = report,
        .checksum = null,
        .fields = undefined,
        .field_count = 0,
        .button_group = null,
    };

    if (report.checksum) |cs| {
        if (std.meta.stringToEnum(ChecksumAlgo, cs.algo)) |algo| {
            cr.checksum = .{
                .algo = algo,
                .range_start = @intCast(cs.range[0]),
                .range_end = @intCast(cs.range[1]),
                .expect_off = @intCast(cs.expect.offset),
                .seed = cs.seed,
            };
        }
    }

    if (report.fields) |fields| {
        var it = fields.map.iterator();
        while (it.next()) |entry| {
            if (cr.field_count >= MAX_FIELDS) break;
            const name = entry.key_ptr.*;
            const fc = entry.value_ptr.*;

            if (fc.bits) |bits| {
                // bits mode
                if (bits.len != 3) continue;
                const is_signed = if (fc.type) |t| std.mem.eql(u8, t, "signed") else false;
                var cf = CompiledField{
                    .tag = parseFieldTag(name),
                    .mode = .bits,
                    .type_tag = .u8,
                    .offset = 0,
                    .byte_offset = @intCast(bits[0]),
                    .start_bit = @intCast(bits[1]),
                    .bit_count = @intCast(bits[2]),
                    .is_signed = is_signed,
                    .transforms = undefined,
                    .has_transform = false,
                };
                if (fc.transform) |tr| {
                    cf.transforms = compileTransformChain(tr, .u8);
                    cf.has_transform = true;
                }
                cr.fields[cr.field_count] = cf;
                cr.field_count += 1;
            } else {
                // standard mode
                const type_str = fc.type orelse continue;
                const type_tag = parseFieldType(type_str) orelse continue;
                const offset = fc.offset orelse continue;
                var cf = CompiledField{
                    .tag = parseFieldTag(name),
                    .mode = .standard,
                    .type_tag = type_tag,
                    .offset = @intCast(offset),
                    .byte_offset = 0,
                    .start_bit = 0,
                    .bit_count = 0,
                    .is_signed = false,
                    .transforms = undefined,
                    .has_transform = false,
                };
                if (fc.transform) |tr| {
                    cf.transforms = compileTransformChain(tr, type_tag);
                    cf.has_transform = true;
                }
                cr.fields[cr.field_count] = cf;
                cr.field_count += 1;
            }
        }
    }

    if (report.button_group) |bg| {
        var cbg = CompiledButtonGroup{
            .src_off = @intCast(bg.source.offset),
            .src_size = @intCast(bg.source.size),
            .entries = undefined,
            .count = 0,
        };
        var it = bg.map.map.iterator();
        while (it.next()) |entry| {
            if (cbg.count >= MAX_BUTTONS) break;
            const btn_name = entry.key_ptr.*;
            const bit_idx = entry.value_ptr.*;
            if (std.meta.stringToEnum(ButtonId, btn_name)) |btn_id| {
                cbg.entries[cbg.count] = .{
                    .btn_id = btn_id,
                    .bit_idx = @intCast(bit_idx),
                };
                cbg.count += 1;
            }
        }
        cr.button_group = cbg;
    }

    return cr;
}

// --- Interpreter ---

pub const Interpreter = struct {
    compiled: [MAX_REPORTS]CompiledReport,
    report_count: u8,

    pub fn init(config: *const DeviceConfig) Interpreter {
        var self = Interpreter{ .compiled = undefined, .report_count = 0 };
        for (config.report) |*report| {
            if (self.report_count >= MAX_REPORTS) break;
            self.compiled[self.report_count] = compileReport(report);
            self.report_count += 1;
        }
        return self;
    }

    pub fn processReport(
        self: *const Interpreter,
        interface_id: u8,
        raw: []const u8,
    ) ProcessError!?GamepadStateDelta {
        const cr = self.matchReport(interface_id, raw) orelse return null;
        if (raw.len < @as(usize, @intCast(cr.src.size))) return null;
        try verifyChecksumCompiled(cr, raw);
        var delta = GamepadStateDelta{};
        extractAndFillCompiled(cr, raw, &delta);
        return delta;
    }

    pub fn matchReport(self: *const Interpreter, interface_id: u8, raw: []const u8) ?*const CompiledReport {
        for (self.compiled[0..self.report_count]) |*cr| {
            if (cr.src.interface != @as(i64, interface_id)) continue;
            if (cr.src.match) |m| {
                if (!checkMatch(m, raw)) continue;
            }
            return cr;
        }
        return null;
    }
};

fn checkMatch(m: device.MatchConfig, raw: []const u8) bool {
    const off: usize = @intCast(m.offset);
    if (raw.len < off + m.expect.len) return false;
    for (m.expect, 0..) |byte, i| {
        if (raw[off + i] != @as(u8, @intCast(byte))) return false;
    }
    return true;
}

pub fn verifyChecksumCompiled(cr: *const CompiledReport, raw: []const u8) ProcessError!void {
    const cs = cr.checksum orelse return;
    const data = raw[cs.range_start..cs.range_end];
    switch (cs.algo) {
        .sum8 => {
            var sum: u8 = 0;
            for (data) |b| sum +%= b;
            if (sum != raw[cs.expect_off]) return ProcessError.ChecksumMismatch;
        },
        .xor => {
            var xv: u8 = 0;
            for (data) |b| xv ^= b;
            if (xv != raw[cs.expect_off]) return ProcessError.ChecksumMismatch;
        },
        .crc32 => {
            var crc = std.hash.crc.Crc32IsoHdlc.init();
            if (cs.seed) |seed| {
                const seed_byte: u8 = @intCast(seed & 0xff);
                crc.update(&[_]u8{seed_byte});
            }
            crc.update(data);
            const computed = crc.final();
            const stored = std.mem.readInt(u32, raw[cs.expect_off..][0..4], .little);
            if (computed != stored) return ProcessError.ChecksumMismatch;
        },
    }
}

fn extractAndFillCompiled(cr: *const CompiledReport, raw: []const u8, delta: *GamepadStateDelta) void {
    for (cr.fields[0..cr.field_count]) |*cf| {
        var val: i64 = switch (cf.mode) {
            .standard => readFieldByTag(raw, cf.offset, cf.type_tag),
            .bits => blk: {
                const raw_val = extractBits(raw, cf.byte_offset, cf.start_bit, cf.bit_count);
                break :blk if (cf.is_signed)
                    @as(i64, signExtend(raw_val, cf.bit_count))
                else
                    @as(i64, raw_val);
            },
        };
        if (cf.has_transform) val = runTransformChain(val, &cf.transforms);
        applyFieldTag(delta, cf.tag, val);
    }

    if (cr.button_group) |*cbg| {
        const src_val = readUintBytes(raw, cbg.src_off, cbg.src_size);
        var bits: u64 = delta.buttons orelse 0;
        for (cbg.entries[0..cbg.count]) |entry| {
            const pressed = (src_val >> @intCast(entry.bit_idx)) & 1 == 1;
            const btn_bit: u6 = @intCast(@intFromEnum(entry.btn_id));
            if (pressed) {
                bits |= @as(u64, 1) << btn_bit;
            } else {
                bits &= ~(@as(u64, 1) << btn_bit);
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
    \\source = { offset = 11, size = 4 }
    \\map = { DPadUp = 0, DPadRight = 1, DPadDown = 2, DPadLeft = 3, A = 4, B = 5, Select = 6, X = 7, Y = 8, Start = 9, LB = 10, RB = 11, LS = 14, RS = 15, C = 16, Z = 17, M1 = 18, M2 = 19, M3 = 20, M4 = 21, LM = 22, RM = 23, O = 24, Home = 27 }
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
    // button_group: A=bit4, B=bit5 → byte[11]=0x30
    raw[11] = 0x30;
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
    // A=bit4, B=bit5 both pressed
    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_bit: u6 = @intCast(@intFromEnum(ButtonId.B));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
    try testing.expect(btns & (@as(u64, 1) << b_bit) != 0);
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

test "checksum xor mismatch returns error" {
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
    // xor = 0xAA ^ 0x01 ^ 0x02 ^ 0x03 = 0xAA; put wrong value 0x00
    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x00, 0x00 };
    try testing.expectError(ProcessError.ChecksumMismatch, interp.processReport(0, &raw));
}

test "checksum range out of bounds returns null" {
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
        \\size = 20
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "sum8"
        \\range = [0, 20]
        \\expect = { offset = 18, type = "u8" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // Report smaller than declared size — should return null (size check), not panic
    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03 };
    const result = try interp.processReport(0, &raw);
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
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

fn makeDualSenseSample() [64]u8 {
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01; // Report ID
    raw[1] = 0x00; // left_x = 0 → scale → -32768
    raw[2] = 0xFF; // left_y = 255 → scale → 32767 → negate → -32767
    raw[3] = 0xFF; // right_x = 255 → scale → 32767
    raw[4] = 0x00; // right_y = 0 → scale → -32768 → negate → 32768 → saturates to 32767
    raw[5] = 0xC0; // lt = 192
    raw[6] = 0x80; // rt = 128
    // byte 8: bit4=Square(X), bit5=Cross(A)
    raw[8] = 0x30;
    // gyro at offset 16-21
    std.mem.writeInt(i16, raw[16..18], 512, .little); // gyro_x
    std.mem.writeInt(i16, raw[18..20], -512, .little); // gyro_y
    std.mem.writeInt(i16, raw[20..22], 256, .little); // gyro_z
    // accel at offset 22-27
    std.mem.writeInt(i16, raw[22..24], 8192, .little); // accel_x (~1g)
    std.mem.writeInt(i16, raw[24..26], 0, .little); // accel_y
    std.mem.writeInt(i16, raw[26..28], -8192, .little); // accel_z
    return raw;
}

test "DualSense USB report: axes, triggers, IMU, buttons" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = makeDualSenseSample();
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;

    // left_x=0x00 → scale(-32768,32767) on u8: 0*65535/255 - 32768 = -32768
    try testing.expectEqual(@as(?i16, -32768), delta.ax);
    // left_y=0xFF → scale → 32767, negate → -32767
    try testing.expectEqual(@as(?i16, -32767), delta.ay);
    // right_x=0xFF → scale → 32767
    try testing.expectEqual(@as(?i16, 32767), delta.rx);
    // triggers
    try testing.expectEqual(@as(?u8, 0xC0), delta.lt);
    try testing.expectEqual(@as(?u8, 0x80), delta.rt);
    // IMU
    try testing.expectEqual(@as(?i16, 512), delta.gyro_x);
    try testing.expectEqual(@as(?i16, -512), delta.gyro_y);
    try testing.expectEqual(@as(?i16, 256), delta.gyro_z);
    try testing.expectEqual(@as(?i16, 8192), delta.accel_x);
    try testing.expectEqual(@as(?i16, 0), delta.accel_y);
    try testing.expectEqual(@as(?i16, -8192), delta.accel_z);
    // buttons: byte8 = 0x30 → bit4=Square(X), bit5=Cross(A)
    const btns = delta.buttons orelse return error.NoBtns;
    const x_bit: u6 = @intCast(@intFromEnum(ButtonId.X));
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    try testing.expect(btns & (@as(u64, 1) << x_bit) != 0); // Square pressed
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0); // Cross pressed
    try testing.expect(btns & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.B)))) == 0); // Circle not pressed
}

test "DualSense right_y=0x00 saturates to 32767" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01;
    raw[4] = 0x00; // right_y=0 → scale(-32768,32767) → -32768 → negate → 32768 → saturates to 32767
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 32767), delta.ry);
}

test "DualSense joystick boundary values" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // 0x80 center: scale(128, u8_max=255) = 128*65535/255 - 32768 ≈ 128*257 - 32768 = 32896 - 32768 = 128
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01;
    raw[1] = 0x80; // left_x = 0x80
    const d1 = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 128), d1.ax);

    // 0xFF max: scale(255, u8_max=255) = 255*65535/255 - 32768 = 65535 - 32768 = 32767
    raw[1] = 0xFF;
    const d2 = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, 32767), d2.ax);

    // 0x00 min: scale(0, u8_max=255) = 0 - 32768 = -32768
    raw[1] = 0x00;
    const d3 = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?i16, -32768), d3.ax);
}

test "DualSense L1+R1 simultaneously pressed" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01;
    // byte 9: L1=bit0, R1=bit1 → 0x03
    raw[9] = 0x03;
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    const btns = delta.buttons orelse return error.NoBtns;
    const lb_bit: u6 = @intCast(@intFromEnum(ButtonId.LB));
    const rb_bit: u6 = @intCast(@intFromEnum(ButtonId.RB));
    try testing.expect(btns & (@as(u64, 1) << lb_bit) != 0);
    try testing.expect(btns & (@as(u64, 1) << rb_bit) != 0);
}

test "DualSense all buttons released" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01;
    // bytes 8-10 = 0x00 → no buttons pressed
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    const btns = delta.buttons orelse 0;
    try testing.expectEqual(@as(u32, 0), btns);
}

test "DualSense battery_level: bits DSL extracts 4-bit nibble" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01;
    // byte 53: bits[3:0]=level(8), bits[7:4]=charging(1) → 0x18
    raw[53] = 0x18;
    raw[33] = 0x05;
    raw[37] = 0x80;
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?u8, 8), delta.battery_level);
}

test "battery_level FieldTag: parseFieldTag and applyFieldTag" {
    try testing.expectEqual(FieldTag.battery_level, parseFieldTag("battery_level"));
    try testing.expectEqual(FieldTag.unknown, parseFieldTag("battery_raw"));

    var delta = GamepadStateDelta{};
    applyFieldTag(&delta, .battery_level, 10);
    try testing.expectEqual(@as(?u8, 10), delta.battery_level);

    // large value is masked to u8 range
    var delta2 = GamepadStateDelta{};
    applyFieldTag(&delta2, .battery_level, 0x1ff);
    try testing.expectEqual(@as(?u8, 0xff), delta2.battery_level);
}

fn makeDualSenseBtSample() [78]u8 {
    var raw = [_]u8{0} ** 78;
    raw[0] = 0x31; // Report ID
    raw[2] = 0x00; // left_x = 0 → scale → -32768
    raw[3] = 0xFF; // left_y = 255 → scale → 32767 → negate → -32767
    raw[4] = 0xFF; // right_x = 255 → scale → 32767
    raw[5] = 0x00; // right_y = 0 → scale → wraps to -32768
    raw[6] = 0xC0; // lt = 192
    raw[7] = 0x80; // rt = 128
    // byte 9: bit4=Square(X), bit5=Cross(A)
    raw[9] = 0x30;
    // gyro at BT offset 17-22
    std.mem.writeInt(i16, raw[17..19], 512, .little);
    std.mem.writeInt(i16, raw[19..21], -512, .little);
    std.mem.writeInt(i16, raw[21..23], 256, .little);
    // accel at BT offset 23-28
    std.mem.writeInt(i16, raw[23..25], 8192, .little);
    std.mem.writeInt(i16, raw[25..27], 0, .little);
    std.mem.writeInt(i16, raw[27..29], -8192, .little);
    // CRC32(seed=0xa1, raw[0..74]) = 0x02662fd2
    raw[74] = 0xd2;
    raw[75] = 0x2f;
    raw[76] = 0x66;
    raw[77] = 0x02;
    return raw;
}

test "DualSense BT report: axes, triggers, IMU, buttons, CRC32" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = makeDualSenseBtSample();
    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;

    try testing.expectEqual(@as(?i16, -32768), delta.ax);
    try testing.expectEqual(@as(?i16, -32767), delta.ay);
    try testing.expectEqual(@as(?i16, 32767), delta.rx);
    try testing.expectEqual(@as(?u8, 0xC0), delta.lt);
    try testing.expectEqual(@as(?u8, 0x80), delta.rt);
    try testing.expectEqual(@as(?i16, 512), delta.gyro_x);
    try testing.expectEqual(@as(?i16, -512), delta.gyro_y);
    try testing.expectEqual(@as(?i16, 256), delta.gyro_z);
    try testing.expectEqual(@as(?i16, 8192), delta.accel_x);
    try testing.expectEqual(@as(?i16, 0), delta.accel_y);
    try testing.expectEqual(@as(?i16, -8192), delta.accel_z);

    const btns = delta.buttons orelse return error.NoBtns;
    const x_bit: u6 = @intCast(@intFromEnum(ButtonId.X));
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    try testing.expect(btns & (@as(u64, 1) << x_bit) != 0);
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
}

test "DualSense BT report: CRC32 mismatch returns error" {
    const allocator = testing.allocator;
    const parsed = try @import("../config/device.zig").parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = makeDualSenseBtSample();
    // Corrupt CRC
    raw[74] = 0x00;
    try testing.expectError(ProcessError.ChecksumMismatch, interp.processReport(3, &raw));
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
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_bit: u6 = @intCast(@intFromEnum(ButtonId.B));
    const x_bit: u6 = @intCast(@intFromEnum(ButtonId.X));
    const y_bit: u6 = @intCast(@intFromEnum(ButtonId.Y));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0); // A pressed
    try testing.expect(btns & (@as(u64, 1) << b_bit) == 0); // B not pressed
    try testing.expect(btns & (@as(u64, 1) << x_bit) != 0); // X pressed
    try testing.expect(btns & (@as(u64, 1) << y_bit) == 0); // Y not pressed
}

const crc32_base_toml =
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
    \\size = 9
    \\[report.match]
    \\offset = 0
    \\expect = [0xAA]
    \\[report.checksum]
    \\algo = "crc32"
    \\range = [0, 4]
    \\expect = { offset = 4, type = "u32le" }
;

test "checksum crc32 correct passes" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, crc32_base_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // CRC32-IsoHdlc([0xAA,0x01,0x02,0x03]) = 0xa96f7f72
    var raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x72, 0x7f, 0x6f, 0xa9, 0x00 };
    _ = try interp.processReport(0, &raw);
}

test "checksum crc32 mismatch returns error" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, crc32_base_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // Store wrong crc
    var raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 };
    try testing.expectError(ProcessError.ChecksumMismatch, interp.processReport(0, &raw));
}

test "checksum crc32 with seed" {
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
        \\size = 9
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.checksum]
        \\algo = "crc32"
        \\range = [1, 4]
        \\seed = 66
        \\expect = { offset = 4, type = "u32le" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // seed=66=0x42 → CRC32(seed_byte=0x42, data=[0x01,0x02,0x03]) = 0xbaa416a5
    var raw = [_]u8{ 0x01, 0x01, 0x02, 0x03, 0xa5, 0x16, 0xa4, 0xba, 0x00 };
    _ = try interp.processReport(0, &raw);
}

// T3: boundary reports

test "T3: empty report (0 bytes) returns null without panic" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const result = try interp.processReport(1, &[_]u8{});
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
}

test "T3: oversized report parsed without bounds error" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // 128 bytes, magic correct — should match and parse normally
    var raw = [_]u8{0} ** 128;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], 100, .little);
    const result = try interp.processReport(1, &raw);
    try testing.expect(result != null);
}

test "T3: all-0xFF report does not panic" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0xFF} ** 32;
    // magic won't match (0xFF != 0x5a), so result is null — no crash
    const result = try interp.processReport(1, &raw);
    try testing.expectEqual(@as(?GamepadStateDelta, null), result);
}

test "fuzz processReport: no panic on arbitrary input" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    try testing.fuzz(interp, struct {
        fn run(ctx: Interpreter, input: []const u8) !void {
            for (0..4) |iface| {
                _ = ctx.processReport(@intCast(iface), input) catch {};
            }
        }
    }.run, .{});
}

test "T3: field at last valid offset (offset = size - 1) reads correctly" {
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
        \\lt = { offset = 3, type = "u8" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const raw = [_]u8{ 0x01, 0x00, 0x00, 0xAB };
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?u8, 0xAB), delta.lt);
}

// T4: extractBits unit tests

test "T4: extractBits single byte, low nibble" {
    const raw = [_]u8{0xAB}; // 0b10101011
    // byte_offset=0, start_bit=0, bit_count=4 → low nibble = 0xB = 11
    try testing.expectEqual(@as(u32, 0x0B), extractBits(&raw, 0, 0, 4));
}

test "T4: extractBits single byte, high nibble" {
    const raw = [_]u8{0xAB}; // 0b10101011
    // byte_offset=0, start_bit=4, bit_count=4 → high nibble = 0xA = 10
    try testing.expectEqual(@as(u32, 0x0A), extractBits(&raw, 0, 4, 4));
}

test "T4: extractBits single bit" {
    const raw = [_]u8{ 0x00, 0x08 }; // byte1 = 0b00001000
    // byte_offset=1, start_bit=3, bit_count=1 → bit3 = 1
    try testing.expectEqual(@as(u32, 1), extractBits(&raw, 1, 3, 1));
    // byte_offset=1, start_bit=2, bit_count=1 → bit2 = 0
    try testing.expectEqual(@as(u32, 0), extractBits(&raw, 1, 2, 1));
}

test "T4: extractBits cross-byte 12-bit (DualSense touchpad X)" {
    // touch0_x: bits = [34, 0, 12]
    // Simulate: byte[0]=0x34, byte[1]=0x12 → LE u16 = 0x1234
    // start_bit=0, bit_count=12 → 0x1234 & 0xFFF = 0x234
    const raw = [_]u8{ 0x34, 0x12 };
    try testing.expectEqual(@as(u32, 0x234), extractBits(&raw, 0, 0, 12));
}

test "T4: extractBits cross-byte 12-bit with start_bit=4 (DualSense touchpad Y)" {
    // touch0_y: bits = [35, 4, 12]
    // byte[0]=0xAB, byte[1]=0xCD → LE = 0xCDAB
    // shift right by 4 → 0x0CDA, mask 12 bits → 0xCDA
    const raw = [_]u8{ 0xAB, 0xCD };
    try testing.expectEqual(@as(u32, 0xCDA), extractBits(&raw, 0, 4, 12));
}

test "T4: extractBits full 32-bit" {
    var raw: [4]u8 = undefined;
    std.mem.writeInt(u32, &raw, 0xDEADBEEF, .little);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), extractBits(&raw, 0, 0, 32));
}

test "T4: extractBits full 8-bit" {
    const raw = [_]u8{0xFF};
    try testing.expectEqual(@as(u32, 0xFF), extractBits(&raw, 0, 0, 8));
}

test "T4: extractBits with byte_offset" {
    const raw = [_]u8{ 0x00, 0x00, 0xAB, 0xCD };
    // byte_offset=2, start_bit=0, bit_count=16 → LE u16 from bytes[2..4] = 0xCDAB
    try testing.expectEqual(@as(u32, 0xCDAB), extractBits(&raw, 2, 0, 16));
}

test "T4: signExtend positive value" {
    // 12-bit value 0x7FF (2047), sign bit (bit11) = 0 → positive
    try testing.expectEqual(@as(i32, 2047), signExtend(0x7FF, 12));
}

test "T4: signExtend negative value" {
    // 12-bit value 0x800 (bit11 = 1) → sign extend to -2048
    try testing.expectEqual(@as(i32, -2048), signExtend(0x800, 12));
}

test "T4: signExtend 1-bit" {
    try testing.expectEqual(@as(i32, 0), signExtend(0, 1));
    try testing.expectEqual(@as(i32, -1), signExtend(1, 1));
}

// T4: interpreter round-trip with bits DSL

const bits_toml =
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
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\lt = { bits = [1, 0, 8] }
    \\left_x = { bits = [2, 0, 12], type = "signed" }
;

test "T4: bits field round-trip through interpreter" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, bits_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 8;
    raw[0] = 0x01; // match
    raw[1] = 200; // lt = 200 (unsigned 8-bit)
    // left_x: 12-bit signed = -100 → two's complement 12-bit: 0xF9C
    // byte[2] = 0x9C, byte[3] low nibble = 0x0F
    std.mem.writeInt(u16, raw[2..4], @as(u16, @bitCast(@as(i16, -100))), .little);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?u8, 200), delta.lt);
    try testing.expectEqual(@as(?i16, -100), delta.ax);
}

test "T4: bits field unsigned default" {
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
        \\lt = { bits = [1, 0, 8] }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    raw[1] = 0xFF; // 255 unsigned
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?u8, 255), delta.lt);
}

test "extractBits: start_bit=7 single bit" {
    try testing.expectEqual(@as(u32, 1), extractBits(&[_]u8{0x80}, 0, 7, 1));
    try testing.expectEqual(@as(u32, 0), extractBits(&[_]u8{0x7F}, 0, 7, 1));
}

test "T4: touch0_active bits round-trip" {
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
        \\size = 8
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\touch0_active = { bits = [4, 3, 1] }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // bit 3 set → touch0_active = true
    var raw = [_]u8{0} ** 8;
    raw[0] = 0x01;
    raw[4] = 0x08;
    const d1 = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?bool, true), d1.touch0_active);

    // bit 3 clear → touch0_active = false
    raw[4] = 0x00;
    const d2 = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    try testing.expectEqual(@as(?bool, false), d2.touch0_active);
}

test "FieldTag.dpad: hat switch values 0-7 decode correctly" {
    // HID hat: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
    const HAT_X = [8]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
    const HAT_Y = [8]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };
    for (0..8) |i| {
        var delta = GamepadStateDelta{};
        applyFieldTag(&delta, .dpad, @intCast(i));
        try std.testing.expectEqual(HAT_X[i], delta.dpad_x.?);
        try std.testing.expectEqual(HAT_Y[i], delta.dpad_y.?);
    }
}

test "FieldTag.dpad: value 8 (released) and >8 treated as neutral" {
    var delta = GamepadStateDelta{};
    applyFieldTag(&delta, .dpad, 8);
    try std.testing.expectEqual(@as(i8, 0), delta.dpad_x.?);
    try std.testing.expectEqual(@as(i8, 0), delta.dpad_y.?);

    var delta2 = GamepadStateDelta{};
    applyFieldTag(&delta2, .dpad, 15);
    try std.testing.expectEqual(@as(i8, 0), delta2.dpad_x.?);
    try std.testing.expectEqual(@as(i8, 0), delta2.dpad_y.?);
}
