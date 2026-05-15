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
const OutputEvents = @import("../../core/mapper.zig").OutputEvents;

// Trigger buttons drive the layer FSM. Production suppresses these from the
// gamepad output while the layer is held; the oracle does not. Comparing
// `prod.buttons` against `oracle.buttons & ~LAYER_TRIGGER_MASK` follows the
// same convention used by the hand-written scenario tests below (see the
// `oout.gamepad.buttons & ~lt` comparisons).
const LAYER_TRIGGER_MASK: u64 = blk: {
    @setEvalBranchQuota(100_000);
    var m: u64 = 0;
    // Mirrors config_gen.zig `layer_triggers` — the only buttons a generated
    // config can use as a layer trigger (production suppresses / tap-injects
    // these; the oracle does not, so both sides mask them symmetrically).
    // Names not present in ButtonId are silently ignored.
    const names = [_][]const u8{ "LT", "RT", "Select", "Start", "Home", "LM", "RM" };
    for (names) |n| {
        if (std.meta.stringToEnum(state_mod.ButtonId, n)) |id|
            m |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
    }
    break :blk m;
};

/// True if the generated config contains a subsystem the deterministic oracle
/// (`mapper_oracle.zig`) does not faithfully reimplement. For these configs the
/// A==B deterministic compare is intentionally skipped (F5: do NOT fake a green
/// by routing both through shared code). The float property check still runs.
///
/// - macros: oracle treats `.macro` remap targets as no-ops; production runs a
///   real macro player that emits keys/buttons. Genuine model gap, not a bug.
fn configIsFullyModeled(cfg: *const mapping.MappingConfig) bool {
    return cfg.macro == null or cfg.macro.?.len == 0;
}

/// Drive production `Mapper` and the independent `mapper_oracle` over the same
/// generated config + frame sequence and assert equivalence on the
/// deterministic subsystems (remap / layer-FSM / dpad / suppress+inject /
/// buttons). Float subsystems (gyro / stick) are checked via property
/// constraints (`checkGyroSign`), not exact equality, per design/testing.md
/// TP5 split-oracle.
///
/// Timing model: production's layer hold FSM (`layer.zig`) is driven by an
/// absolute CLOCK_MONOTONIC `now_ns` and only promotes PENDING->ACTIVE when the
/// armed timerfd fires (`onLayerTimerExpired`). The oracle promotes by
/// accumulating `dt_ms`. To make the two genuinely comparable WITHOUT sharing
/// code, we maintain a synthetic monotonic clock (sum of frame `dt_ms`) for
/// production and replay the real ppoll timerfd-expiry entry point
/// (`ctx.mapper.onLayerTimerExpired()`) at exactly the deadline the production
/// FSM armed. Production still runs its own FSM; the oracle independently
/// reimplements promotion.
fn runHarness(
    allocator: std.mem.Allocator,
    n_configs: usize,
    n_frames: usize,
    seed: u64,
) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var pass: usize = 0;
    var compared: usize = 0;

    for (0..n_configs) |_| {
        var map_buf: [4096]u8 = undefined;
        const map_toml = config_gen.randomMappingConfig(rng, &map_buf);
        if (map_toml.len == 0) continue; // generator returned empty — skip

        var ctx = try helpers.makeMapper(map_toml, allocator);
        defer ctx.deinit();

        try mapping.validate(&ctx.parsed.value);

        const oracle_parsed = try mapping.parseString(allocator, map_toml);
        defer oracle_parsed.deinit();

        var os = OracleState{};

        const do_compare = configIsFullyModeled(&ctx.parsed.value);

        var frames_buf: [200]Frame = undefined;
        const frames = frames_buf[0..@min(n_frames, frames_buf.len)];
        sequence_gen.randomSequence(rng, frames, ctx.parsed.value);

        // Synthetic monotonic clock and pending production layer-timer deadline.
        var now_ns: i128 = 1; // start > 0 so press_ns is distinguishable
        var armed_deadline_ns: ?i128 = null;

        for (frames) |frame| {
            now_ns += @as(i128, frame.dt_ms) * std.time.ns_per_ms;

            // Replay timerfd expiry: if the production layer FSM armed a hold
            // timer that is now due, fire the real expiry entry point exactly
            // as the ppoll loop would, BEFORE applying this frame. This makes
            // production's PENDING->ACTIVE follow the same logical schedule the
            // oracle derives from accumulated dt_ms — independent code paths.
            if (armed_deadline_ns) |dl| {
                if (now_ns >= dl) {
                    _ = ctx.mapper.onLayerTimerExpired();
                    armed_deadline_ns = null;
                }
            }

            const prod = try ctx.mapper.apply(frame.delta, @as(u32, frame.dt_ms), now_ns);

            // Track timer arm/disarm requests from production.
            if (prod.timer_request) |tr| switch (tr) {
                .arm => |ms| armed_deadline_ns = now_ns + @as(i128, ms) * std.time.ns_per_ms,
                .disarm => armed_deadline_ns = null,
            };

            const oout = mapper_oracle.apply(&os, frame.delta, &oracle_parsed.value, @as(u64, frame.dt_ms));

            // Float subsystem (gyro/stick): property constraints only — always.
            try checkGyroSign(frame.delta, &prod);

            // Deterministic subsystems: exact A==B equivalence — skipped only
            // for configs with a documented oracle model gap (F5-safe).
            if (do_compare) {
                try testing.expectEqual(
                    oout.gamepad.buttons & ~LAYER_TRIGGER_MASK,
                    prod.gamepad.buttons & ~LAYER_TRIGGER_MASK,
                );
                try testing.expectEqual(oout.gamepad.dpad_x, prod.gamepad.dpad_x);
                try testing.expectEqual(oout.gamepad.dpad_y, prod.gamepad.dpad_y);
                try compareAux(&oout.aux, &prod.aux);
                compared += 1;
            }
        }
        pass += 1;
    }

    // Sanity floor: the harness exercised configs (preserves old guarantee).
    try testing.expect(pass > 0);
    // Value assertion: the deterministic split-oracle compare actually ran on
    // a non-trivial number of frames (guards against the compare being
    // silently disabled by an over-broad model-gap skip).
    try testing.expect(compared > 0);
}

fn compareAux(oracle_aux: *const mapper_oracle.AuxEventList, prod_aux: *const @import("../../core/aux_event.zig").AuxEventList) !void {
    // Deterministic path: compare key + mouse_button events (code, pressed) in
    // order. `.rel` events are gyro/stick floating-point output and are checked
    // separately via the float property check (checkGyroSign), not here.
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

/// F4 float-subsystem property check (TP5: float subsystems verified by
/// property constraints, not exact equality).
///
/// Per-frame invariant that holds for ANY config / ANY frame, so it is safe to
/// call inside the random harness without false positives:
///   (a) every emitted `.rel` event carries a valid REL_* code, and
///   (b) its magnitude is bounded (no NaN/overflow/garbage leaking from the
///       gyro/stick float pipeline into integer rel output).
/// A per-frame *sign* assertion is intentionally NOT done here: EMA smoothing,
/// deadzone, the `invert_x/y` config, joystick mode, and simultaneous stick
/// output make a single-frame sign check inherently flaky. The falsifiable
/// gyro-direction property (which catches a reversed-EMA-sign mutation) is
/// asserted deterministically in the dedicated test below.
fn checkGyroSign(delta: GamepadStateDelta, prod_out: *const OutputEvents) !void {
    _ = delta;
    const REL_MAX: i32 = 1 << 20; // far above any sane per-frame mouse delta
    for (prod_out.aux.slice()) |ev| {
        switch (ev) {
            .rel => |r| {
                const valid = r.code == helpers.REL_X or r.code == helpers.REL_Y or
                    r.code == REL_WHEEL or r.code == REL_HWHEEL;
                try testing.expect(valid);
                try testing.expect(r.value > -REL_MAX and r.value < REL_MAX);
            },
            else => {},
        }
    }
}

const REL_WHEEL: u16 = 8;
const REL_HWHEEL: u16 = 6;

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
    _ = ctx.mapper.apply(.{ .buttons = lt }, 0, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = lt }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_idle_to_pending)]);

    // pending -> active (advance past timeout)
    prev = oracle;
    // Fire production timer BEFORE apply so layer is active for remap processing
    _ = ctx.mapper.layer.onTimerExpired();
    _ = ctx.mapper.apply(.{ .buttons = lt }, 101, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 101);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = lt }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_pending_to_active)]);

    // verify layer remap active: A -> X
    // Production suppresses layer trigger buttons; oracle doesn't — mask out LT for comparison
    const prod = ctx.mapper.apply(.{ .buttons = lt | a }, 0, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = lt | a }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons & ~lt, prod.gamepad.buttons);

    // active -> idle (release LT)
    prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0, 0) catch unreachable;
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
    _ = ctx.mapper.apply(.{ .buttons = sel }, 0, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = sel }, &parsed.value, 0);
    var prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = 0 }, &parsed.value, 0);
    transition_id.classify(&tracker, &prev, &oracle, .{ .buttons = 0 }, &parsed.value);
    try testing.expect(tracker.seen[@intFromEnum(transition_id.TransitionId.layer_toggle_on)]);

    // A should be remapped to KEY_F1
    const prod = ctx.mapper.apply(.{ .buttons = a }, 0, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = a }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons, prod.gamepad.buttons);

    // press + release Select -> toggle off
    _ = ctx.mapper.apply(.{ .buttons = sel }, 0, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = sel }, &parsed.value, 0);
    prev = oracle;
    _ = ctx.mapper.apply(.{ .buttons = 0 }, 0, 0) catch unreachable;
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

    const prod = ctx.mapper.apply(.{ .dpad_x = -1 }, 0, 0) catch unreachable;
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
    _ = ctx.mapper.apply(.{ .buttons = lt }, 0, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 0);
    _ = ctx.mapper.layer.onTimerExpired();
    _ = ctx.mapper.apply(.{ .buttons = lt }, 51, 0) catch unreachable;
    _ = mapper_oracle.apply(&oracle, .{ .buttons = lt }, &parsed.value, 51);

    // Press A + B simultaneously while layer active
    // Production suppresses layer trigger buttons; oracle doesn't — mask out LT for comparison
    const prod = ctx.mapper.apply(.{ .buttons = lt | a | b }, 0, 0) catch unreachable;
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

        var os = OracleState{};
        const do_compare = configIsFullyModeled(&mc.parsed.value);

        var frames_buf: [100]Frame = undefined;
        sequence_gen.randomSequence(rng, &frames_buf, map_parsed.value);

        var now_ns: i128 = 1;
        var armed_deadline_ns: ?i128 = null;

        for (frames_buf) |frame| {
            now_ns += @as(i128, frame.dt_ms) * std.time.ns_per_ms;
            if (armed_deadline_ns) |dl| {
                if (now_ns >= dl) {
                    _ = mc.mapper.onLayerTimerExpired();
                    armed_deadline_ns = null;
                }
            }

            const prod = try mc.mapper.apply(frame.delta, @as(u32, frame.dt_ms), now_ns);
            if (prod.timer_request) |tr| switch (tr) {
                .arm => |ms| armed_deadline_ns = now_ns + @as(i128, ms) * std.time.ns_per_ms,
                .disarm => armed_deadline_ns = null,
            };

            const oout = mapper_oracle.apply(&os, frame.delta, &map_parsed.value, @as(u64, frame.dt_ms));
            try checkGyroSign(frame.delta, &prod);
            if (do_compare) {
                try testing.expectEqual(
                    oout.gamepad.buttons & ~LAYER_TRIGGER_MASK,
                    prod.gamepad.buttons & ~LAYER_TRIGGER_MASK,
                );
                try testing.expectEqual(oout.gamepad.dpad_x, prod.gamepad.dpad_x);
                try testing.expectEqual(oout.gamepad.dpad_y, prod.gamepad.dpad_y);
                try compareAux(&oout.aux, &prod.aux);
            }
        }
        tested += 1;
    }

    try testing.expect(tested > 0);
}

// --- F4 falsifiable gyro-direction property (dedicated, deterministic) ---
//
// TP5 float-subsystem property: with default config (invert_x = invert_y =
// false), a sustained positive yaw (gyro_y) must produce net-positive REL_X
// motion, and sustained positive pitch (gyro_x) net-positive REL_Y. EMA
// smoothing makes any single frame unreliable, so we drive a steady strong
// input for many frames and assert the ACCUMULATED displacement sign.
//
// Falsifiability contract: mutation M = reverse the gyro EMA output sign in
// `src/core/gyro.zig` (e.g. `const final_x = if (cfg.invert_x) scaled_x else
// -scaled_x;`, or `return std.math.copysign(curved, -ema);` in applyCurve).
// Under M the accumulated REL_X/REL_Y sign flips and BOTH expectations below
// fail. The old `runHarness` (`expect(pass > 0)`) and the old empty
// `checkGyroSign` were both insensitive to M.
test "generative: gyro mouse-mode direction is sign-consistent (F4)" {
    const allocator = testing.allocator;
    const toml_str =
        \\[remap]
        \\A = "B"
        \\
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 4.0
        \\smoothing = 0.3
        \\max_val = 1000.0
    ;

    var ctx = try helpers.makeMapper(toml_str, allocator);
    defer ctx.deinit();

    var sum_rel_x: i64 = 0;
    var sum_rel_y: i64 = 0;
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        // Sustained positive yaw (gyro_y -> REL_X) and positive pitch
        // (gyro_x -> REL_Y), well above the default zero deadzone.
        const out = try ctx.mapper.apply(
            .{ .gyro_x = 8000, .gyro_y = 8000, .gyro_z = 0 },
            16,
            @as(i128, @intCast(i + 1)) * 16 * std.time.ns_per_ms,
        );
        for (out.aux.slice()) |ev| {
            switch (ev) {
                .rel => |r| {
                    if (r.code == helpers.REL_X) sum_rel_x += r.value;
                    if (r.code == helpers.REL_Y) sum_rel_y += r.value;
                },
                else => {},
            }
        }
    }

    // Sanity: motion was actually produced (guards a silently-zero pipeline).
    try testing.expect(sum_rel_x != 0);
    try testing.expect(sum_rel_y != 0);
    // The falsifiable assertion: direction matches input (no sign inversion).
    try testing.expect(sum_rel_x > 0);
    try testing.expect(sum_rel_y > 0);
}
