// Metamorphic relation tests for the interpreter pipeline.
//
// Each test encodes a metamorphic relation: a property that must hold
// between two related inputs, rather than comparing against a fixed oracle.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const state_mod = @import("../../core/state.zig");

const Interpreter = interpreter_mod.Interpreter;
const runTransformChain = interpreter_mod.runTransformChain;
const compileTransformChain = interpreter_mod.compileTransformChain;
const CompiledTransformChain = interpreter_mod.CompiledTransformChain;

// MR1: deadzone(0) is identity — already covered in transform_props for runTransformChain,
// here we check it at processReport level using a real config.
//
// Build two interpreters from the same config: one with deadzone(0) in transform,
// one bare. For any input value v they must produce the same output.
test "metamorphic: deadzone(0) is identity on axis value" {
    // Inline config: left_x with deadzone(0) vs plain left_x
    const toml_dz =
        \\[device]
        \\name = "DZ Test"
        \\vid = 0x0001
        \\pid = 0x0001
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.fields]
        \\left_x = { offset = 0, type = "i16le", transform = "deadzone(0)" }
    ;
    const toml_plain =
        \\[device]
        \\name = "Plain Test"
        \\vid = 0x0001
        \\pid = 0x0001
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.fields]
        \\left_x = { offset = 0, type = "i16le" }
    ;

    const allocator = testing.allocator;
    const p1 = try device_mod.parseString(allocator, toml_dz);
    defer p1.deinit();
    const p2 = try device_mod.parseString(allocator, toml_plain);
    defer p2.deinit();

    const interp1 = Interpreter.init(&p1.value);
    const interp2 = Interpreter.init(&p2.value);

    var prng = std.Random.DefaultPrng.init(0x1234);
    const rng = prng.random();
    for (0..1000) |_| {
        var raw = [_]u8{0} ** 4;
        const v: i16 = rng.int(i16);
        std.mem.writeInt(i16, raw[0..2], v, .little);

        const d1 = (try interp1.processReport(1, &raw)) orelse continue;
        const d2 = (try interp2.processReport(1, &raw)) orelse continue;
        try testing.expectEqual(d1.ax, d2.ax);
    }
}

// MR2: config reload idempotency — parsing same TOML twice yields interpreters
// that produce identical output for the same raw bytes.
test "metamorphic: config reload idempotency" {
    const toml =
        \\[device]
        \\name = "Idempotency Test"
        \\vid = 0x0002
        \\pid = 0x0002
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 8
        \\[report.fields]
        \\left_x  = { offset = 0, type = "i16le" }
        \\left_y  = { offset = 2, type = "i16le", transform = "negate" }
        \\lt      = { offset = 4, type = "u8" }
        \\rt      = { offset = 5, type = "u8" }
    ;

    const allocator = testing.allocator;
    const p1 = try device_mod.parseString(allocator, toml);
    defer p1.deinit();
    const p2 = try device_mod.parseString(allocator, toml);
    defer p2.deinit();

    const ia = Interpreter.init(&p1.value);
    const ib = Interpreter.init(&p2.value);

    var prng = std.Random.DefaultPrng.init(0xABCD);
    const rng = prng.random();
    for (0..500) |_| {
        var raw = [_]u8{0} ** 8;
        rng.bytes(&raw);

        const d1 = try ia.processReport(1, &raw);
        const d2 = try ib.processReport(1, &raw);

        if (d1 == null and d2 == null) continue;
        const r1 = d1 orelse return error.MismatchNullity;
        const r2 = d2 orelse return error.MismatchNullity;
        try testing.expectEqual(r1.ax, r2.ax);
        try testing.expectEqual(r1.ay, r2.ay);
        try testing.expectEqual(r1.lt, r2.lt);
        try testing.expectEqual(r1.rt, r2.rt);
    }
}

// MR3: match byte sensitivity — corrupting a match byte makes processReport return null.
test "metamorphic: match byte corruption → null" {
    const toml =
        \\[device]
        \\name = "Match Test"
        \\vid = 0x0003
        \\pid = 0x0003
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 8
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA, 0xBB]
        \\[report.fields]
        \\left_x = { offset = 2, type = "i16le" }
    ;

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Valid packet
    var valid = [_]u8{0} ** 8;
    valid[0] = 0xAA;
    valid[1] = 0xBB;
    const ok = try interp.processReport(1, &valid);
    try testing.expect(ok != null);

    // Corrupt first match byte
    var bad1 = valid;
    bad1[0] ^= 0xFF;
    const r1 = try interp.processReport(1, &bad1);
    try testing.expect(r1 == null);

    // Corrupt second match byte
    var bad2 = valid;
    bad2[1] ^= 0xFF;
    const r2 = try interp.processReport(1, &bad2);
    try testing.expect(r2 == null);
}

// MR4: button bit flip — toggling a button's source bit flips its state in delta.buttons.
test "metamorphic: button bit flip toggles button state" {
    const toml =
        \\[device]
        \\name = "Button Test"
        \\vid = 0x0004
        \\pid = 0x0004
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.button_group]
        \\source = { offset = 0, size = 2 }
        \\map = { A = 0, B = 1, X = 2, Y = 3 }
    ;

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const ButtonId = state_mod.ButtonId;

    const buttons = [_]ButtonId{ .A, .B, .X, .Y };
    const bit_indices = [_]u3{ 0, 1, 2, 3 };

    for (buttons, bit_indices) |btn, src_bit| {
        // Bit = 0
        var raw_off = [_]u8{0} ** 4;
        const d0 = (try interp.processReport(1, &raw_off)) orelse return error.NoMatch;

        // Bit = 1
        var raw_on = raw_off;
        raw_on[0] |= @as(u8, 1) << src_bit;
        const d1 = (try interp.processReport(1, &raw_on)) orelse return error.NoMatch;

        const btn_bit: u6 = @intCast(@intFromEnum(btn));
        const mask: u64 = @as(u64, 1) << btn_bit;

        const state0: u64 = d0.buttons orelse 0;
        const state1: u64 = d1.buttons orelse 0;

        // state1 should have the bit set, state0 should not
        try testing.expect((state1 & mask) != 0);
        try testing.expect((state0 & mask) == 0);
    }
}

// MR5: scale linearity — doubling input approximately doubles output (within 1 lsb tolerance).
// Uses runTransformChain directly since processReport saturation makes exact checks tricky.
// scale(0, 100) on u8 (t_max=255): scaled(v) = v * 100 / 255, non-trivial rational mapping.
test "metamorphic: scale linearity — doubling input roughly doubles output" {
    var prng = std.Random.DefaultPrng.init(0x5CA1E);
    const rng = prng.random();

    // scale(0, 100) on u8 type_tag (t_max = 255): identity is avoided, exercises real linearity.
    var chain = compileTransformChain("scale(0, 100)", .u8);

    for (0..1000) |_| {
        // Pick v in [1, 127] so 2v fits in u8 range
        const v: i64 = rng.intRangeAtMost(u8, 1, 127);
        const out_v = runTransformChain(v, &chain);
        const out_2v = runTransformChain(v * 2, &chain);

        // out_2v should be within 1 of 2 * out_v (integer division rounding)
        const diff = @abs(out_2v - out_v * 2);
        try testing.expect(diff <= 1);
    }
}

// MR6: negate double application — negate(negate(x)) == x, tested at pipeline level.
// negate is already tested in transform_props; here we confirm it round-trips through
// processReport as well (two reports: one with "negate", one with "negate, negate").
test "metamorphic: double-negate round-trips at processReport level" {
    const toml_once =
        \\[device]
        \\name = "Negate Once"
        \\vid = 0x0005
        \\pid = 0x0005
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.fields]
        \\left_x = { offset = 0, type = "i16le", transform = "negate" }
    ;
    const toml_twice =
        \\[device]
        \\name = "Negate Twice"
        \\vid = 0x0005
        \\pid = 0x0005
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.fields]
        \\left_x = { offset = 0, type = "i16le", transform = "negate, negate" }
    ;
    const toml_plain =
        \\[device]
        \\name = "No Transform"
        \\vid = 0x0005
        \\pid = 0x0005
        \\[[device.interface]]
        \\id = 1
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 1
        \\size = 4
        \\[report.fields]
        \\left_x = { offset = 0, type = "i16le" }
    ;

    const allocator = testing.allocator;
    const p_twice = try device_mod.parseString(allocator, toml_twice);
    defer p_twice.deinit();
    const p_plain = try device_mod.parseString(allocator, toml_plain);
    defer p_plain.deinit();
    _ = toml_once;

    const i_twice = Interpreter.init(&p_twice.value);
    const i_plain = Interpreter.init(&p_plain.value);

    var prng = std.Random.DefaultPrng.init(0xDEAD);
    const rng = prng.random();
    for (0..500) |_| {
        var raw = [_]u8{0} ** 4;
        const v: i16 = rng.int(i16);
        // minInt(i16) round-trips correctly: negate(-32768)=32768, negate(32768)=-32768,
        // saturateCast(i16,-32768)=-32768. The saturation-to-maxInt guard only fires for
        // minInt(i64), which an i16 value never reaches.
        std.mem.writeInt(i16, raw[0..2], v, .little);

        const d_twice = (try i_twice.processReport(1, &raw)) orelse continue;
        const d_plain = (try i_plain.processReport(1, &raw)) orelse continue;
        try testing.expectEqual(d_plain.ax, d_twice.ax);
    }
}
