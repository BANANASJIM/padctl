const std = @import("std");
const testing = std.testing;

const interpreter = @import("../../core/interpreter.zig");
const CompiledTransform = interpreter.CompiledTransform;
const CompiledTransformChain = interpreter.CompiledTransformChain;
const runTransformChain = interpreter.runTransformChain;

fn makeChain(op: interpreter.TransformOp, a: i64, b: i64) CompiledTransformChain {
    var chain = CompiledTransformChain{ .type_tag = .i16le };
    chain.items[0] = .{ .op = op, .a = a, .b = b };
    chain.len = 1;
    return chain;
}

// P1: scale monotonicity — if a <= b and x1 <= x2 then scale(x1) <= scale(x2)
test "property: scale monotonicity" {
    var prng = std.Random.DefaultPrng.init(0xA0A0);
    const rng = prng.random();

    for (0..10000) |_| {
        var a: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        var b: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        if (a > b) std.mem.swap(i64, &a, &b);

        const x1: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        const x2: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        const lo = @min(x1, x2);
        const hi = @max(x1, x2);

        const chain = makeChain(.scale, a, b);
        const r_lo = runTransformChain(lo, &chain);
        const r_hi = runTransformChain(hi, &chain);
        try testing.expect(r_lo <= r_hi);
    }
}

// P2: negate is self-inverse — negate(negate(x)) == x for all x != minInt(i64)
test "property: negate self-inverse" {
    var prng = std.Random.DefaultPrng.init(0xB1B1);
    const rng = prng.random();

    var chain = CompiledTransformChain{ .type_tag = .i16le };
    chain.items[0] = .{ .op = .negate };
    chain.items[1] = .{ .op = .negate };
    chain.len = 2;

    for (0..10000) |_| {
        const x: i64 = rng.int(i64);
        if (x == std.math.minInt(i64)) continue;
        try testing.expectEqual(x, runTransformChain(x, &chain));
    }
}

// P3: clamp idempotency — clamp(a,b)(clamp(a,b)(x)) == clamp(a,b)(x)
test "property: clamp idempotency" {
    var prng = std.Random.DefaultPrng.init(0xC2C2);
    const rng = prng.random();

    for (0..10000) |_| {
        var a: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        var b: i64 = rng.intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16));
        if (a > b) std.mem.swap(i64, &a, &b);

        const x: i64 = rng.int(i64);
        const chain = makeChain(.clamp, a, b);
        const once = runTransformChain(x, &chain);
        const twice = runTransformChain(once, &chain);
        try testing.expectEqual(once, twice);
    }
}
