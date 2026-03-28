const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const state_mod = @import("../../core/state.zig");
const layer_mod = @import("../../core/layer.zig");
const mapping = @import("../../config/mapping.zig");

const Mapper = helpers.Mapper;
const ButtonId = state_mod.ButtonId;
const GamepadStateDelta = state_mod.GamepadStateDelta;
const LayerState = layer_mod.LayerState;
const LayerConfig = mapping.LayerConfig;

const makeMapper = helpers.makeMapper;
const btnMask = helpers.btnMask;

// P1: random button state -> mapper never crashes
test "property: random input deltas never crash mapper" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
        \\B = "mouse_left"
        \\X = "Y"
        \\
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "disabled"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var prng = std.Random.DefaultPrng.init(0xCAFE_BABE);
    const rng = prng.random();

    for (0..1000) |_| {
        const delta = state_mod.generateRandomDelta(rng);
        const ev = try m.apply(delta, 16);
        // Invariant: aux key/mouse codes must be non-zero (no code 0 in Linux input).
        for (ev.aux.slice()) |aux| {
            switch (aux) {
                .key => |k| try testing.expect(k.code > 0),
                .mouse_button => |mb| try testing.expect(mb.code > 0),
                .rel => {},
            }
        }
        _ = ev.gamepad.buttons;
    }
}

// P2: all buttons pressed simultaneously
test "property: all 64 button bits set — no panic or overflow" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
        \\B = "mouse_left"
        \\X = "Y"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = 0xFFFFFFFFFFFFFFFF }, 16);
    // mapper must return without panic; buttons field is valid
    _ = ev.gamepad.buttons;

    // release all
    _ = try m.apply(.{ .buttons = 0 }, 16);
}

// P3: rapid layer toggle — 1000 cycles
test "property: rapid hold layer toggle — state stays consistent" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "KEY_F13"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();

    for (0..1000) |_| {
        if (rng.boolean()) {
            _ = m.layer.processLayerTriggers(configs, btnMask(.LT), 0);
            if (rng.boolean()) _ = m.layer.onTimerExpired();
        } else {
            _ = m.layer.processLayerTriggers(configs, 0, btnMask(.LT));
        }

        // layer state must never reference out-of-bounds config
        if (m.layer.getActive(configs)) |active| {
            try testing.expectEqualStrings("aim", active.name);
        }
    }
}

// P3b: rapid toggle activation
test "property: rapid toggle layer — state stays consistent" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    var prng = std.Random.DefaultPrng.init(99);
    const rng = prng.random();

    for (0..1000) |_| {
        const sel = btnMask(.Select);
        if (rng.boolean()) {
            // press
            _ = m.layer.processLayerTriggers(configs, sel, 0);
        } else {
            // release (toggle fires on release)
            _ = m.layer.processLayerTriggers(configs, 0, sel);
        }

        if (m.layer.getActive(configs)) |active| {
            try testing.expectEqualStrings("fn", active.name);
        }
    }
}

// P4: random remap config doesn't crash
test "property: random button remap pairs — no crash" {
    const allocator = testing.allocator;
    const button_names = [_][]const u8{ "A", "B", "X", "Y", "LB", "RB", "Start", "Select" };
    const targets = [_][]const u8{ "A", "B", "X", "Y", "KEY_F1", "mouse_left", "disabled" };

    var prng = std.Random.DefaultPrng.init(0xBEEF);
    const rng = prng.random();

    for (0..100) |_| {
        const src = button_names[rng.intRangeAtMost(usize, 0, button_names.len - 1)];
        const dst = targets[rng.intRangeAtMost(usize, 0, targets.len - 1)];

        var buf: [256]u8 = undefined;
        const toml_str = try std.fmt.bufPrint(&buf, "[remap]\n{s} = \"{s}\"\n", .{ src, dst });

        var ctx = try makeMapper(toml_str, allocator);
        defer ctx.deinit();
        var m = &ctx.mapper;

        const delta = state_mod.generateRandomDelta(rng);
        const ev = try m.apply(delta, 16);
        for (ev.aux.slice()) |aux| {
            switch (aux) {
                .key => |k| try testing.expect(k.code > 0),
                .mouse_button => |mb| try testing.expect(mb.code > 0),
                .rel => {},
            }
        }
        _ = ev.gamepad.buttons;
    }
}

// P5: axis values at extremes
test "property: extreme axis values — no overflow after processing" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const extreme_deltas = [_]GamepadStateDelta{
        .{ .ax = std.math.minInt(i16), .ay = std.math.minInt(i16), .lt = 0, .rt = 0 },
        .{ .ax = std.math.maxInt(i16), .ay = std.math.maxInt(i16), .lt = 255, .rt = 255 },
        .{ .rx = std.math.minInt(i16), .ry = std.math.maxInt(i16) },
        .{ .gyro_x = std.math.minInt(i16), .gyro_y = std.math.maxInt(i16), .gyro_z = std.math.minInt(i16) },
        .{ .accel_x = std.math.maxInt(i16), .accel_y = std.math.minInt(i16), .accel_z = std.math.maxInt(i16) },
        .{ .touch0_x = std.math.minInt(i16), .touch0_y = std.math.maxInt(i16), .touch0_active = true },
        .{ .dpad_x = std.math.minInt(i8), .dpad_y = std.math.maxInt(i8) },
    };

    for (extreme_deltas) |delta| {
        _ = try m.apply(delta, 16);
    }

    // also fuzz with random extreme-biased values
    var prng = std.Random.DefaultPrng.init(0xF00D);
    const rng = prng.random();
    for (0..1000) |_| {
        var delta = GamepadStateDelta{};
        // bias toward extremes
        if (rng.boolean()) {
            delta.ax = if (rng.boolean()) std.math.minInt(i16) else std.math.maxInt(i16);
        }
        if (rng.boolean()) {
            delta.ay = if (rng.boolean()) std.math.minInt(i16) else std.math.maxInt(i16);
        }
        if (rng.boolean()) {
            delta.lt = if (rng.boolean()) @as(u8, 0) else @as(u8, 255);
        }
        if (rng.boolean()) {
            delta.rt = if (rng.boolean()) @as(u8, 0) else @as(u8, 255);
        }
        if (rng.boolean()) {
            delta.gyro_x = if (rng.boolean()) std.math.minInt(i16) else std.math.maxInt(i16);
        }
        if (rng.boolean()) {
            delta.buttons = rng.int(u64);
        }
        _ = try m.apply(delta, 16);
    }
}

// P6: empty/null config paths — passthrough works
test "property: empty config — passthrough no crash" {
    const allocator = testing.allocator;
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var prng = std.Random.DefaultPrng.init(0x1234);
    const rng = prng.random();

    for (0..1000) |_| {
        const delta = state_mod.generateRandomDelta(rng);
        const ev = try m.apply(delta, 16);
        // No remaps → gamepad output equals input (passthrough).
        if (delta.buttons) |b| try testing.expectEqual(b, ev.gamepad.buttons);
        if (delta.ax) |v| try testing.expectEqual(v, ev.gamepad.ax);
        if (delta.ay) |v| try testing.expectEqual(v, ev.gamepad.ay);
        if (delta.lt) |v| try testing.expectEqual(v, ev.gamepad.lt);
        if (delta.rt) |v| try testing.expectEqual(v, ev.gamepad.rt);
        try testing.expectEqual(@as(usize, 0), ev.aux.len);
    }
}

test "property: empty layer array — no crash" {
    const allocator = testing.allocator;
    // config with remap but no layers
    var ctx = try makeMapper(
        \\[remap]
        \\A = "B"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var prng = std.Random.DefaultPrng.init(0x5678);
    const rng = prng.random();

    for (0..1000) |_| {
        const delta = state_mod.generateRandomDelta(rng);
        const ev = try m.apply(delta, 16);
        for (ev.aux.slice()) |aux| {
            switch (aux) {
                .key => |k| try testing.expect(k.code > 0),
                .mouse_button => |mb| try testing.expect(mb.code > 0),
                .rel => {},
            }
        }
        _ = ev.gamepad.buttons;
    }
}

// P7: duplicate mappings — two inputs mapped to same output
test "property: duplicate remap targets — last write wins, no crash" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "Y"
        \\B = "Y"
        \\X = "KEY_F1"
        \\LB = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // press both A and B → both map to Y
    const ev1 = try m.apply(.{ .buttons = btnMask(.A) | btnMask(.B) }, 16);
    // Y should be injected (at least one source is pressed)
    try testing.expect((ev1.gamepad.buttons & btnMask(.Y)) != 0);
    // A and B should be suppressed
    try testing.expectEqual(@as(u64, 0), ev1.gamepad.buttons & btnMask(.A));
    try testing.expectEqual(@as(u64, 0), ev1.gamepad.buttons & btnMask(.B));

    // fuzz with random button combos
    var prng = std.Random.DefaultPrng.init(0xAAAA);
    const rng = prng.random();
    for (0..1000) |_| {
        _ = try m.apply(.{ .buttons = rng.int(u64) }, 16);
    }
}

// P7a: apply idempotency — same delta twice produces no new button-press aux events
test "property: apply same delta twice — no duplicate button press events" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
        \\B = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var prng = std.Random.DefaultPrng.init(0xD0D0);
    const rng = prng.random();

    for (0..1000) |_| {
        const delta = GamepadStateDelta{ .buttons = rng.int(u64) };
        const ev1 = try m.apply(delta, 16);
        const ev2 = try m.apply(delta, 16);

        // second apply with identical state should produce no key/mouse press events
        for (ev2.aux.slice()) |aux| {
            switch (aux) {
                .key => |k| try testing.expect(!k.pressed),
                .mouse_button => |mb| try testing.expect(!mb.pressed),
                .rel => {},
            }
        }
        _ = ev1;
    }
}

// P7b: layer + base both mapping to same target
test "property: layer and base remap to same target — no crash" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F1"
        \\
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\B = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    // activate layer
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    // both A and B pressed — both map to KEY_F1
    _ = try m.apply(.{ .buttons = btnMask(.A) | btnMask(.B) }, 16);

    // fuzz
    var prng = std.Random.DefaultPrng.init(0xBBBB);
    const rng = prng.random();
    for (0..1000) |_| {
        const delta = state_mod.generateRandomDelta(rng);
        _ = try m.apply(delta, 16);
    }
}
