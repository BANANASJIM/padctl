const std = @import("std");
const testing = std.testing;
const device = @import("../config/device.zig");
const interp = @import("../core/interpreter.zig");
const Interpreter = interp.Interpreter;

const boundary_i16 = [_]i16{ 0, 1, -1, std.math.maxInt(i16), std.math.minInt(i16), 16384 };

fn makeToml(comptime transform: []const u8) []const u8 {
    return "[device]\nname = \"T\"\nvid = 1\npid = 2\n" ++
        "[[device.interface]]\nid = 0\nclass = \"hid\"\n" ++
        "[[report]]\nname = \"r\"\ninterface = 0\nsize = 4\n" ++
        "[report.match]\noffset = 0\nexpect = [0x01]\n" ++
        "[report.fields]\nleft_x = { offset = 2, type = \"i16le\", transform = \"" ++ transform ++ "\" }\n";
}

fn saturateCast(val: i64) i16 {
    if (val > std.math.maxInt(i16)) return std.math.maxInt(i16);
    if (val < std.math.minInt(i16)) return std.math.minInt(i16);
    return @intCast(val);
}

fn runOne(interp: *const Interpreter, val: i16) !i16 {
    var raw = [_]u8{0} ** 4;
    raw[0] = 0x01;
    std.mem.writeInt(i16, raw[2..4], val, .little);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    return delta.ax orelse error.NoMatch;
}

test "boundary: negate" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("negate"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        const expected: i16 = saturateCast(-@as(i64, v));
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: abs" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("abs"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        const v64: i64 = v;
        const abs64: i64 = @intCast(@abs(v64));
        const expected: i16 = saturateCast(abs64);
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: scale(-32768, 32767)" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("scale(-32768, 32767)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const t_max: i64 = 32767; // i16le type_max
    inline for (boundary_i16) |v| {
        const v128: i128 = v;
        const scaled: i64 = @intCast(@divTrunc(v128 * (32767 - (-32768)), t_max) + (-32768));
        const expected: i16 = saturateCast(scaled);
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: scale(0, 0) produces 0" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("scale(0, 0)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        // scale(0,0): v * (0-0) / type_max + 0 = 0
        try testing.expectEqual(@as(i16, 0), try runOne(&interp, v));
    }
}

test "boundary: clamp(-16384, 16384)" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("clamp(-16384, 16384)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        const expected: i16 = saturateCast(std.math.clamp(@as(i64, v), -16384, 16384));
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: deadzone(1000)" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("deadzone(1000)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const dz_vals = [_]i16{ 0, 999, 1000, 1001, -999, -1000, -1001, std.math.maxInt(i16), std.math.minInt(i16) };
    inline for (dz_vals) |v| {
        const expected: i16 = if (@abs(@as(i64, v)) < 1000) 0 else v;
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: chain negate, abs" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("negate, abs"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        // negate then abs: abs(-v) in i64
        const negated: i64 = -@as(i64, v);
        const abs_val: i64 = @intCast(@abs(negated));
        const expected: i16 = saturateCast(abs_val);
        try testing.expectEqual(expected, try runOne(&interp, v));
    }
}

test "boundary: chain abs, clamp(0, 16384)" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("abs, clamp(0, 16384)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    inline for (boundary_i16) |v| {
        const result = try runOne(&interp, v);
        try testing.expect(result >= 0 and result <= 16384);
    }
}

test "boundary: chain deadzone(1000), scale(-32768, 32767)" {
    const allocator = testing.allocator;
    const parsed = try device.parseString(allocator, makeToml("deadzone(1000), scale(-32768, 32767)"));
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // dead inputs (|v| < 1000) should produce the scaled value of 0
    const t_max: i64 = 32767;
    const scaled_zero: i16 = saturateCast(@as(i64, @intCast(@divTrunc(@as(i128, 0) * (32767 - (-32768)), t_max) + (-32768))));
    const dead_vals = [_]i16{ 0, 999, -999 };
    inline for (dead_vals) |v| {
        try testing.expectEqual(scaled_zero, try runOne(&interp, v));
    }
}

// issue #215 / ADR-017: production negate/abs MUST match the Lean oracle's
// single-point saturation at the type-min boundary `val == -(t_max+1) -> t_max`.
// Asserted directly via runTransformChain (DRT-independent). Reverting the
// single-point guard in interpreter.zig makes this test FAIL.
test "issue215: negate/abs single-point saturation matches Lean oracle" {
    // i8: t_max = 127, type-min = -(127+1) = -128.
    {
        var neg = interp.compileTransformChain("negate", .i8);
        try testing.expectEqual(@as(i64, 127), interp.runTransformChain(-128, &neg));
        var abs_ = interp.compileTransformChain("abs", .i8);
        try testing.expectEqual(@as(i64, 127), interp.runTransformChain(-128, &abs_));
        // Non-minInt out-of-range input must NOT saturate (oracle: raw -val/natAbs).
        try testing.expectEqual(@as(i64, 256), interp.runTransformChain(-256, &neg));
        try testing.expectEqual(@as(i64, 256), interp.runTransformChain(-256, &abs_));
        // In-range still raw.
        try testing.expectEqual(@as(i64, 127), interp.runTransformChain(-127, &neg));
    }
    // Wider type i32le: t_max = 2147483647, type-min = -2147483648.
    {
        var neg = interp.compileTransformChain("negate", .i32le);
        try testing.expectEqual(@as(i64, 2147483647), interp.runTransformChain(-2147483648, &neg));
        var abs_ = interp.compileTransformChain("abs", .i32le);
        try testing.expectEqual(@as(i64, 2147483647), interp.runTransformChain(-2147483648, &abs_));
    }
}
