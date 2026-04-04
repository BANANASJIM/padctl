const std = @import("std");
const device = @import("../config/device.zig");

pub const Param = struct {
    name: []const u8,
    value: u16,
};

/// Fill a command template, replacing hex literals and {name:type} placeholders.
///
/// Token format (space-separated):
///   "00"           hex literal → 1 byte
///   "{name}"       lookup name in params, u8 output (value >> 8)
///   "{name:u8}"    same as above
///   "{name:u16le}" 2 bytes, little-endian
///   "{name:u16be}" 2 bytes, big-endian
pub fn fillTemplate(
    allocator: std.mem.Allocator,
    template: []const u8,
    params: []const Param,
) ![]u8 {
    var out = std.ArrayList(u8){};
    errdefer out.deinit(allocator);

    var it = std.mem.tokenizeScalar(u8, template, ' ');
    while (it.next()) |token| {
        if (token.len > 2 and token[0] == '{' and token[token.len - 1] == '}') {
            const inner = token[1 .. token.len - 1];
            const colon = std.mem.indexOfScalar(u8, inner, ':');
            const name = if (colon) |c| inner[0..c] else inner;
            const type_str = if (colon) |c| inner[c + 1 ..] else "u8";

            const pval = findParam(params, name) orelse return error.UnknownParam;

            if (std.mem.eql(u8, type_str, "u8")) {
                try out.append(allocator, @intCast(pval >> 8));
            } else if (std.mem.eql(u8, type_str, "u16le")) {
                try out.append(allocator, @intCast(pval & 0xff));
                try out.append(allocator, @intCast(pval >> 8));
            } else if (std.mem.eql(u8, type_str, "u16be")) {
                try out.append(allocator, @intCast(pval >> 8));
                try out.append(allocator, @intCast(pval & 0xff));
            } else {
                return error.UnsupportedParamType;
            }
        } else {
            const byte = std.fmt.parseInt(u8, token, 16) catch return error.InvalidHexByte;
            try out.append(allocator, byte);
        }
    }

    return out.toOwnedSlice(allocator);
}

/// Compute and insert a checksum into a filled command buffer.
pub fn applyChecksum(buf: []u8, cs: *const device.CommandChecksumConfig) void {
    if (cs.range.len != 2) return;
    if (cs.range[0] < 0 or cs.range[1] < 0 or cs.offset < 0) return;
    const start: usize = @intCast(cs.range[0]);
    const end: usize = @intCast(cs.range[1]);
    const off: usize = @intCast(cs.offset);
    if (start > end or end > buf.len or off >= buf.len) return;

    if (std.mem.eql(u8, cs.algo, "sum8")) {
        var sum: u8 = if (cs.seed) |s| @intCast(s & 0xff) else 0;
        for (buf[start..end]) |b| sum +%= b;
        buf[off] = sum;
    } else if (std.mem.eql(u8, cs.algo, "xor")) {
        var xv: u8 = if (cs.seed) |s| @intCast(s & 0xff) else 0;
        for (buf[start..end]) |b| xv ^= b;
        buf[off] = xv;
    }
}

fn findParam(params: []const Param, name: []const u8) ?u16 {
    for (params) |p| {
        if (std.mem.eql(u8, p.name, name)) return p.value;
    }
    return null;
}

// --- tests ---

const testing = std.testing;

test "command: fillTemplate: hex literals + u8 placeholders" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "00 08 00 {strong:u8} {weak:u8} 00 00 00", &.{
        .{ .name = "strong", .value = 0x8000 },
        .{ .name = "weak", .value = 0x4000 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, result);
}

test "command: fillTemplate: u16le" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "{weak:u16le}", &.{
        .{ .name = "weak", .value = 0x1234 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x34, 0x12 }, result);
}

test "command: fillTemplate: u16be" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "{strong:u16be}", &.{
        .{ .name = "strong", .value = 0x8000 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x80, 0x00 }, result);
}

test "command: fillTemplate: no type defaults to u8" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "{strong}", &.{
        .{ .name = "strong", .value = 0x8000 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{0x80}, result);
}

test "command: fillTemplate: pure hex template" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "de ad be ef", &.{});
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }, result);
}

test "command: fillTemplate: empty template" {
    const allocator = testing.allocator;
    const result = try fillTemplate(allocator, "", &.{});
    defer allocator.free(result);
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "command: fillTemplate: unknown param name returns error" {
    const allocator = testing.allocator;
    try testing.expectError(error.UnknownParam, fillTemplate(allocator, "{ghost:u8}", &.{
        .{ .name = "strong", .value = 0 },
    }));
}

test "command: fillTemplate: unsupported type returns error" {
    const allocator = testing.allocator;
    try testing.expectError(error.UnsupportedParamType, fillTemplate(allocator, "{x:u32}", &.{
        .{ .name = "x", .value = 0 },
    }));
}

test "command: fillTemplate: hex byte out of range returns error" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidHexByte, fillTemplate(allocator, "1ff", &.{}));
}
