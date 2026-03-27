const std = @import("std");

pub const MIN_TOGGLE_COUNT = 6; // 3 press + 3 release
pub const I16_THRESHOLD: i32 = 4096; // min range to qualify as i16le axis
pub const U8_AXIS_MIN_RANGE: u32 = 64; // min range to qualify as u8 axis
pub const MAGIC_MAX_OFFSET = 8; // check first N bytes for invariant magic

pub const Frame = struct {
    timestamp_us: u64,
    data: []const u8,
};

pub const MagicByte = struct {
    offset: u8,
    value: u8,
};

pub const ButtonCandidate = struct {
    byte_offset: u8,
    bit: u3,
    toggle_count: u32,
    high_confidence: bool,
};

pub const AxisType = enum { i16le, u8_axis };

pub const AxisCandidate = struct {
    offset: u8,
    axis_type: AxisType,
    min_val: i32,
    max_val: i32,
};

pub const AnalysisResult = struct {
    report_size: u16,
    magic: []MagicByte,
    buttons: []ButtonCandidate,
    axes: []AxisCandidate,

    pub fn deinit(self: AnalysisResult, allocator: std.mem.Allocator) void {
        allocator.free(self.magic);
        allocator.free(self.buttons);
        allocator.free(self.axes);
    }
};

pub fn analyse(frames: []const Frame, allocator: std.mem.Allocator) !AnalysisResult {
    if (frames.len == 0) return .{
        .report_size = 0,
        .magic = try allocator.alloc(MagicByte, 0),
        .buttons = try allocator.alloc(ButtonCandidate, 0),
        .axes = try allocator.alloc(AxisCandidate, 0),
    };

    if (frames[0].data.len > std.math.maxInt(u16)) return error.ReportTooLarge;
    const report_size: u16 = @intCast(frames[0].data.len);

    // magic bytes: bytes that never change across all frames
    var magic_list: std.ArrayList(MagicByte) = .{};
    errdefer magic_list.deinit(allocator);

    const magic_len = @min(report_size, MAGIC_MAX_OFFSET);
    for (0..magic_len) |off| {
        const v = frames[0].data[off];
        var invariant = true;
        for (frames[1..]) |f| {
            if (f.data.len <= off or f.data[off] != v) {
                invariant = false;
                break;
            }
        }
        if (invariant) try magic_list.append(allocator, .{ .offset = @intCast(off), .value = v });
    }

    // Count bit transitions between consecutive frames
    const toggle_counts = try allocator.alloc([8]u32, report_size);
    defer allocator.free(toggle_counts);
    @memset(toggle_counts, .{0} ** 8);

    for (frames[0 .. frames.len - 1], frames[1..]) |prev, cur| {
        const len = @min(@min(prev.data.len, cur.data.len), report_size);
        for (0..len) |b| {
            const diff = prev.data[b] ^ cur.data[b];
            for (0..8) |bit| {
                if ((diff >> @intCast(bit)) & 1 == 1) toggle_counts[b][bit] += 1;
            }
        }
    }

    var axis_covered = try allocator.alloc(bool, report_size);
    defer allocator.free(axis_covered);
    @memset(axis_covered, false);

    // magic bytes cannot be axes
    for (magic_list.items) |m| {
        if (m.offset < report_size) axis_covered[m.offset] = true;
    }

    var axes_list: std.ArrayList(AxisCandidate) = .{};
    errdefer axes_list.deinit(allocator);

    // i16le axis detection: adjacent byte pairs, joint range (skip pairs involving magic/covered bytes)
    var off: usize = 0;
    while (off + 1 < report_size) : (off += 1) {
        if (axis_covered[off] or axis_covered[off + 1]) continue;
        var min_val: i32 = std.math.maxInt(i32);
        var max_val: i32 = std.math.minInt(i32);
        for (frames) |f| {
            if (f.data.len < off + 2) continue;
            const lo = f.data[off];
            const hi = f.data[off + 1];
            const v: i16 = @bitCast((@as(u16, hi) << 8) | lo);
            const vi: i32 = v;
            if (vi < min_val) min_val = vi;
            if (vi > max_val) max_val = vi;
        }
        if (max_val - min_val >= I16_THRESHOLD) {
            try axes_list.append(allocator, .{
                .offset = @intCast(off),
                .axis_type = .i16le,
                .min_val = min_val,
                .max_val = max_val,
            });
            axis_covered[off] = true;
            axis_covered[off + 1] = true;
            off += 1; // skip high byte
        }
    }

    // u8 axis detection: single bytes with sufficient range, not covered by i16le
    for (0..report_size) |b| {
        if (axis_covered[b]) continue;
        var min_u: u32 = 255;
        var max_u: u32 = 0;
        for (frames) |f| {
            if (f.data.len <= b) continue;
            const v: u32 = f.data[b];
            if (v < min_u) min_u = v;
            if (v > max_u) max_u = v;
        }
        if (max_u - min_u >= U8_AXIS_MIN_RANGE) {
            try axes_list.append(allocator, .{
                .offset = @intCast(b),
                .axis_type = .u8_axis,
                .min_val = @intCast(min_u),
                .max_val = @intCast(max_u),
            });
            axis_covered[b] = true;
        }
    }

    // button candidates: toggling bits not in axis-covered bytes
    var button_list: std.ArrayList(ButtonCandidate) = .{};
    errdefer button_list.deinit(allocator);

    for (0..report_size) |b| {
        if (axis_covered[b]) continue;
        for (0..8) |bit| {
            const tc = toggle_counts[b][bit];
            if (tc == 0) continue;
            try button_list.append(allocator, .{
                .byte_offset = @intCast(b),
                .bit = @intCast(bit),
                .toggle_count = tc,
                .high_confidence = tc >= MIN_TOGGLE_COUNT,
            });
        }
    }

    return .{
        .report_size = report_size,
        .magic = try magic_list.toOwnedSlice(allocator),
        .buttons = try button_list.toOwnedSlice(allocator),
        .axes = try axes_list.toOwnedSlice(allocator),
    };
}

// --- tests ---

test "magic bytes: invariant prefix detected" {
    const allocator = std.testing.allocator;
    const f0 = [_]u8{ 0x5a, 0xa5, 0xef, 0x10, 0x20 };
    const f1 = [_]u8{ 0x5a, 0xa5, 0xef, 0x30, 0x50 };
    const f2 = [_]u8{ 0x5a, 0xa5, 0xef, 0x11, 0x22 };
    const frames = [_]Frame{
        .{ .timestamp_us = 0, .data = &f0 },
        .{ .timestamp_us = 1000, .data = &f1 },
        .{ .timestamp_us = 2000, .data = &f2 },
    };
    const result = try analyse(&frames, allocator);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(u16, 5), result.report_size);
    try std.testing.expectEqual(@as(usize, 3), result.magic.len);
    try std.testing.expectEqual(@as(u8, 0), result.magic[0].offset);
    try std.testing.expectEqual(@as(u8, 0x5a), result.magic[0].value);
    try std.testing.expectEqual(@as(u8, 1), result.magic[1].offset);
    try std.testing.expectEqual(@as(u8, 0xa5), result.magic[1].value);
    try std.testing.expectEqual(@as(u8, 2), result.magic[2].offset);
    try std.testing.expectEqual(@as(u8, 0xef), result.magic[2].value);
}

test "button detection: 6 toggles on bit 3 of byte 11 => high confidence" {
    const allocator = std.testing.allocator;
    // 12-byte frames: bit 3 of byte 11 toggles 3x press + 3x release = 6 diffs vs baseline
    var datas: [7][12]u8 = undefined;
    var frames: [7]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        if (i % 2 == 1) d[11] = 0x08; // bit 3 set on odd frames
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }
    const result = try analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.buttons) |b| {
        if (b.byte_offset == 11 and b.bit == 3 and b.high_confidence) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "i16le axis: range -32767..32767 detected" {
    const allocator = std.testing.allocator;
    const vals = [_]i16{ 0, 10000, -10000, 32767, -32767 };
    var datas: [5][4]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&frames, 0..) |*f, i| {
        @memset(&datas[i], 0);
        const u: u16 = @bitCast(vals[i]);
        datas[i][0] = @intCast(u & 0xff);
        datas[i][1] = @intCast(u >> 8);
        f.* = .{ .timestamp_us = @as(u64, i) * 1000, .data = &datas[i] };
    }
    const result = try analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 0 and a.axis_type == .i16le) {
            found = true;
            try std.testing.expect(a.min_val <= -10000);
            try std.testing.expect(a.max_val >= 10000);
        }
    }
    try std.testing.expect(found);
}

test "u8 axis: range 0..255 detected" {
    const allocator = std.testing.allocator;
    const trigger_vals = [_]u8{ 0, 64, 128, 200, 255 };
    var datas: [5][4]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&frames, 0..) |*f, i| {
        datas[i] = .{ 0x5a, 0xa5, trigger_vals[i], 0 };
        f.* = .{ .timestamp_us = @as(u64, i) * 1000, .data = &datas[i] };
    }
    const result = try analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 2 and a.axis_type == .u8_axis) {
            found = true;
            try std.testing.expectEqual(@as(i32, 0), a.min_val);
            try std.testing.expectEqual(@as(i32, 255), a.max_val);
        }
    }
    try std.testing.expect(found);
}
