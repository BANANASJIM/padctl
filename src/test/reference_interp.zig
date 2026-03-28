// reference_interp.zig — intentionally naive oracle for DRT.
//
// This reimplements field extraction and transform chain independently of the
// production interpreter.  Bugs in production code will not be present here
// because the implementations share no code paths.
//
// CONSCIOUS COMPROMISE: CompiledField/CompiledReport/CompiledButtonGroup are
// imported from production.  This means DRT catches runtime extraction bugs
// (wrong read logic, wrong transform math) but NOT config compilation bugs
// (e.g., wrong offset or type_tag assigned during compileReport).  A bug that
// produces a wrong CompiledField would go undetected here because both oracle
// and production operate on the same compiled representation.
// See drt_props.zig for the corresponding note.

const std = @import("std");
const interp_mod = @import("../core/interpreter.zig");

pub const FieldType = interp_mod.FieldType;
pub const FieldTag = interp_mod.FieldTag;
pub const TransformOp = interp_mod.TransformOp;
pub const CompiledField = interp_mod.CompiledField;
pub const CompiledReport = interp_mod.CompiledReport;
pub const CompiledButtonGroup = interp_mod.CompiledButtonGroup;

// Simple raw field read using std.mem.readInt — no shared logic with production.
pub fn readField(raw: []const u8, off: usize, t: FieldType) i64 {
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

// Bit extraction: assemble bytes little-endian, shift, mask.
pub fn readBits(raw: []const u8, byte_offset: u16, start_bit: u3, bit_count: u6) u32 {
    const needed: u8 = (@as(u8, start_bit) + @as(u8, bit_count) + 7) / 8;
    var val: u32 = 0;
    for (0..needed) |i| val |= @as(u32, raw[byte_offset + i]) << @intCast(i * 8);
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

// Apply a single transform naively.
fn applyTransform(val: i64, op: TransformOp, a: i64, b: i64, t_max: i64) i64 {
    return switch (op) {
        .negate => if (val == std.math.minInt(i64)) std.math.maxInt(i64) else -val,
        .abs => blk: {
            const clamped = if (val == std.math.minInt(i64)) std.math.maxInt(i64) else val;
            break :blk @intCast(@abs(clamped));
        },
        .scale => blk: {
            if (t_max == 0) break :blk val;
            const v: i128 = val;
            break :blk @intCast(@divTrunc(v * (b - a), t_max) + a);
        },
        .clamp => std.math.clamp(val, a, b),
        .deadzone => blk: {
            const t: u64 = if (a < 0) 0 else @intCast(a);
            break :blk if (@abs(val) < t) 0 else val;
        },
    };
}

// type_max for a FieldType — mirrors production's typeMaxByTag.
fn typeMax(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 4294967295,
        .i32le, .i32be => 2147483647,
    };
}

pub fn runChain(initial: i64, cf: *const CompiledField) i64 {
    if (!cf.has_transform) return initial;
    var val = initial;
    const t_max = typeMax(cf.transforms.type_tag);
    for (cf.transforms.items[0..cf.transforms.len]) |tr| {
        val = applyTransform(val, tr.op, tr.a, tr.b, t_max);
    }
    return val;
}

// Per-field result — only the axes/scalars that a CompiledField can produce.
// We use i64 throughout; the caller compares against the production delta after
// the same saturation the production code applies.
pub const FieldResult = struct {
    tag: FieldTag,
    val: i64,
};

// Extract all fields from raw using the compiled report and return results.
pub fn extractFields(cr: *const CompiledReport, raw: []const u8, out: []FieldResult) usize {
    var n: usize = 0;
    for (cr.fields[0..cr.field_count]) |*cf| {
        var raw_val: i64 = switch (cf.mode) {
            .standard => readField(raw, cf.offset, cf.type_tag),
            .bits => blk: {
                const u = readBits(raw, cf.byte_offset, cf.start_bit, cf.bit_count);
                break :blk if (cf.is_signed)
                    @as(i64, signExtend(u, cf.bit_count))
                else
                    @as(i64, u);
            },
        };
        raw_val = runChain(raw_val, cf);
        if (n < out.len) {
            out[n] = .{ .tag = cf.tag, .val = raw_val };
            n += 1;
        }
    }
    return n;
}

// Read uint from raw bytes little-endian (mirrors production readUintBytes).
pub fn readUintBytes(raw: []const u8, off: usize, size: usize) u64 {
    var val: u64 = 0;
    for (0..size) |i| val |= @as(u64, raw[off + i]) << @intCast(i * 8);
    return val;
}
