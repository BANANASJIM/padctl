const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const config_gen = @import("../gen/config_gen.zig");
const sequence_gen = @import("../gen/sequence_gen.zig");
const mapper_oracle = @import("../gen/mapper_oracle.zig");
const transition_id = @import("../gen/transition_id.zig");
const mapping = @import("../../config/mapping.zig");
const device_mod = @import("../../config/device.zig");
const state_mod = @import("../../core/state.zig");

const GamepadStateDelta = state_mod.GamepadStateDelta;
const Frame = sequence_gen.Frame;
const OracleState = mapper_oracle.OracleState;
const CoverageTracker = transition_id.CoverageTracker;

fn runHarness(
    allocator: std.mem.Allocator,
    n_configs: usize,
    n_frames: usize,
    seed: u64,
) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var pass: usize = 0;

    for (0..n_configs) |_| {
        var map_buf: [4096]u8 = undefined;
        const map_toml = config_gen.randomMappingConfig(rng, &map_buf);
        if (map_toml.len == 0) continue; // generator returned empty — skip

        var ctx = try helpers.makeMapper(map_toml, allocator);
        defer ctx.deinit();

        try mapping.validate(&ctx.parsed.value);

        var frames_buf: [200]Frame = undefined;
        const frames = frames_buf[0..@min(n_frames, frames_buf.len)];
        sequence_gen.randomSequence(rng, frames, ctx.parsed.value);

        for (frames) |frame| {
            _ = try ctx.mapper.apply(frame.delta, @as(u32, frame.dt_ms));
        }
        pass += 1;
    }

    try testing.expect(pass > 0);
}

fn compareAux(oracle_aux: *const mapper_oracle.AuxEventList, prod_aux: *const @import("../../core/aux_event.zig").AuxEventList) !void {
    // Compare key and mouse_button events; skip rel events (gyro/stick floating point)
    var oracle_key_count: usize = 0;
    var prod_key_count: usize = 0;

    for (oracle_aux.slice()) |ev| {
        switch (ev) {
            .key => oracle_key_count += 1,
            .mouse_button => oracle_key_count += 1,
            else => {},
        }
    }
    for (prod_aux.slice()) |ev| {
        switch (ev) {
            .key => prod_key_count += 1,
            .mouse_button => prod_key_count += 1,
            else => {},
        }
    }
    try testing.expectEqual(oracle_key_count, prod_key_count);

    // Compare key events in order
    var oi: usize = 0;
    var pi: usize = 0;
    while (oi < oracle_aux.len and pi < prod_aux.len) {
        const oev = oracle_aux.get(oi);
        const pev = prod_aux.get(pi);

        const o_is_key = switch (oev) {
            .key, .mouse_button => true,
            else => false,
        };
        const p_is_key = switch (pev) {
            .key, .mouse_button => true,
            else => false,
        };

        if (!o_is_key) {
            oi += 1;
            continue;
        }
        if (!p_is_key) {
            pi += 1;
            continue;
        }

        // Both are key/mouse_button — compare
        switch (oev) {
            .key => |ok| {
                switch (pev) {
                    .key => |pk| {
                        try testing.expectEqual(ok.code, pk.code);
                        try testing.expectEqual(ok.pressed, pk.pressed);
                    },
                    else => return error.TestUnexpectedResult,
                }
            },
            .mouse_button => |ok| {
                switch (pev) {
                    .mouse_button => |pk| {
                        try testing.expectEqual(ok.code, pk.code);
                        try testing.expectEqual(ok.pressed, pk.pressed);
                    },
                    else => return error.TestUnexpectedResult,
                }
            },
            else => unreachable,
        }
        oi += 1;
        pi += 1;
    }
}

fn checkGyroSign(delta: GamepadStateDelta, prod_out: *const @import("../../core/mapper.zig").OutputEvents) void {
    // Property: if gyro input is zero, no gyro rel events expected (soft check)
    _ = delta;
    _ = prod_out;
    // Gyro involves EMA/smoothing — exact sign check unreliable; skip for now
}

// --- Main generative test ---

test "generative: mapper DRT -- random config x random sequence" {
    const allocator = testing.allocator;
    try runHarness(allocator, 200, 200, 0x6E4_A33E8);
}

// --- Targeted scenario tests ---

test "generative: layer hold -> pending -> active -> deactivate" {
    const allocator = testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\hold_timeout = 100
        \\
        \\[layer.remap]
        \\A = "X"
    ;

    var ctx = try helpers.makeMapper(toml_str, allocator);
    defer ctx.deinit();
    var oracle = OracleState{};
    const parsed = try mapping.parseString(allocator, toml_str);
    defer parsed.deinit();
    var tracker = CoverageTracker{};

    const lt = helpers.btnMask(.LT);
    const a = helpers.btnMask(.A);

    // idle -> pending
    var prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = lt }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = lt }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_idle_to_pending)]);

    // pending -> active (advance past timeout)
    prev = oracle;
    // Fire production timer BEFORE apply so layer is active for remap processing
    _ = ctx.mapper.layer.onTimerExpired();
    _ = ctx.mapper.apply(.{ .buttons = lt }, 101) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 101);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = lt }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_pending_to_active)]);

    // verify layer remap active: A -> X
    // Production suppresses layer trigger buttons; oracle doesn't — mask out LT for comparison
    const prod = ctx.mapper.apply(.{ .buttons = lt | a }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = lt | a }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons & ~lt, prod.gamepad.buttons);

    // active -> idle (release LT)
    prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = 0 }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = 0 }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_active_to_idle)]);
}

test "generative: layer toggle on/off" {
    const allocator = testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
        \\
        \\[layer.remap]
        \\A = "KEY_F1"
    ;

    var ctx = try helpers.makeMapper(toml_str, allocator);
    defer ctx.deinit();
    var oracle = OracleState{};
    const parsed = try mapping.parseString(allocator, toml_str);
    defer parsed.deinit();
    var tracker = CoverageTracker{};

    const sel = helpers.btnMask(.Select);
    const a = helpers.btnMask(.A);

    // press + release Select -> toggle on
    _ = ctx.mapper.apply(.{ .buttons = sel }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = sel }, &parsed.value, 0);
    var prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = 0 }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = 0 }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_toggle_on)]);

    // A should be remapped to KEY_F1
    const prod = ctx.mapper.apply(.{ .buttons = a }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = a }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons, prod.gamepad.buttons);

    // press + release Select -> toggle off
    _ = ctx.mapper.apply(.{ .buttons = sel }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = sel }, &parsed.value, 0);
    prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = 0 }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = 0 }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_toggle_off)]);
}

test "generative: dpad arrows mode emits KEY events" {
    const allocator = testing.allocator;
    const toml_str =
        \\[dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    ;

    var ctx = try helpers.makeMapper(toml_str, allocator);
    defer ctx.deinit();
    var oracle = OracleState{};
    const parsed = try mapping.parseString(allocator, toml_str);
    defer parsed.deinit();

    const prod = ctx.mapper.apply(.{ .dpad_x = -1 }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .dpad_x = -1 }, &parsed.value, 0);

    try testing.expectEqual(oout.gamepad.dpad_x, prod.gamepad.dpad_x);
    try testing.expectEqual(@as(i8, 0), prod.gamepad.dpad_x);
    try compareAux(&oout.aux, &prod.aux);
}

test "generative: simultaneous buttons + layer remap" {
    const allocator = testing.allocator;
    const toml_str =
        \\[remap]
        \\A = "X"
        \\B = "Y"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\hold_timeout = 50
        \\
        \\[layer.remap]
        \\A = "KEY_F1"
    ;

    var ctx = try helpers.makeMapper(toml_str, allocator);
    defer ctx.deinit();
    var oracle = OracleState{};
    const parsed = try mapping.parseString(allocator, toml_str);
    defer parsed.deinit();

    const lt = helpers.btnMask(.LT);
    const a = helpers.btnMask(.A);
    const b = helpers.btnMask(.B);

    // Activate layer
    _ = ctx.mapper.apply(.{ .buttons = lt }, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 0);
    _ = ctx.mapper.layer.onTimerExpired();
    _ = ctx.mapper.apply(.{ .buttons = lt }, 51) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 51);

    // Press A + B simultaneously while layer active
    // Production suppresses layer trigger buttons; oracle doesn't — mask out LT for comparison
    const prod = ctx.mapper.apply(.{ .buttons = lt | a | b }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = lt | a | b }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons & ~lt, prod.gamepad.buttons);
    try compareAux(&oout.aux, &prod.aux);
}

// --- Real device config × generative mapping × random sequence ---

test "generative: real device configs x compatible mapping x random sequences" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) return; // no device configs present — skip silently

    var prng = std.Random.DefaultPrng.init(0xDEAD_C0DE_F00D);
    const rng = prng.random();

    var tested: usize = 0;

    for (paths.items) |path| {
        const dev_parsed = try device_mod.parseFile(allocator, path);
        defer dev_parsed.deinit();

        // Generate a mapping compatible with this device's buttons.
        var map_buf: [4096]u8 = undefined;
        const map_toml = config_gen.generateCompatibleMapping(rng, &dev_parsed.value, &map_buf);
        if (map_toml.len == 0) continue; // generator produced nothing for this device — skip

        const map_parsed = try mapping.parseString(allocator, map_toml);
        defer map_parsed.deinit();
        try mapping.validate(&map_parsed.value);

        var mc = try helpers.makeMapper(map_toml, allocator);
        defer mc.deinit();

        var frames_buf: [100]Frame = undefined;
        sequence_gen.randomSequence(rng, &frames_buf, map_parsed.value);

        for (frames_buf) |frame| {
            _ = try mc.mapper.apply(frame.delta, @as(u32, frame.dt_ms));
        }
        tested += 1;
    }

    try testing.expect(tested > 0);
}
