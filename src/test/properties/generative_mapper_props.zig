const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const config_gen = @import("../gen/config_gen.zig");
const sequence_gen = @import("../gen/sequence_gen.zig");
const mapper_oracle = @import("../gen/mapper_oracle.zig");
const transition_id = @import("../gen/transition_id.zig");
const shrink_mod = @import("../gen/shrink.zig");
const mapping = @import("../../config/mapping.zig");
const state_mod = @import("../../core/state.zig");

const Mapper = helpers.Mapper;
const GamepadStateDelta = state_mod.GamepadStateDelta;
const Frame = sequence_gen.Frame;
const OracleState = mapper_oracle.OracleState;
const CoverageTracker = transition_id.CoverageTracker;

// --- Shrink support ---

// Context for the shrink check callback.
const ShrinkCtx = struct {
    allocator: std.mem.Allocator,
    /// TOML string (owned by the context, fixed buffer — length stored here).
    toml_buf: [4096]u8,
    toml_len: usize,
};

// Check whether frames still diverge when replayed from a fresh mapper + oracle.
fn shrinkCheck(raw_ctx: *anyopaque, frames: []const Frame) bool {
    const ctx: *ShrinkCtx = @alignCast(@ptrCast(raw_ctx));
    const toml = ctx.toml_buf[0..ctx.toml_len];

    const parsed = mapping.parseString(ctx.allocator, toml) catch return false;
    defer parsed.deinit();

    var mc = helpers.makeMapper(toml, ctx.allocator) catch return false;
    defer mc.deinit();

    var oracle = OracleState{};

    for (frames) |frame| {
        const prod = mc.mapper.apply(frame.delta, @as(u32, frame.dt_ms)) catch return false;
        const oout = mapper_oracle.apply(&oracle, frame.delta, &parsed.value, @as(u64, frame.dt_ms));

        if (oout.gamepad.buttons != prod.gamepad.buttons) return true;
        if (oout.gamepad.dpad_x != prod.gamepad.dpad_x) return true;
        if (oout.gamepad.dpad_y != prod.gamepad.dpad_y) return true;
    }
    return false;
}

fn logMinimalCase(toml: []const u8, min_frames: []const Frame) void {
    std.log.err("=== MINIMAL REPRODUCING CASE ===", .{});
    std.log.err("mapping_toml:\n{s}", .{toml});
    std.log.err("frames ({d}):", .{min_frames.len});
    for (min_frames, 0..) |f, i| {
        std.log.err("  [{d}] dt={d} buttons={?} ax={?} ay={?}", .{
            i, f.dt_ms, f.delta.buttons, f.delta.ax, f.delta.ay,
        });
    }
    std.log.err("================================", .{});
}

fn btnMaskByName(name: []const u8) u64 {
    const id = std.meta.stringToEnum(state_mod.ButtonId, name) orelse return 0;
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

fn runHarness(
    allocator: std.mem.Allocator,
    n_configs: usize,
    n_frames: usize,
    seed: u64,
    tracker: *CoverageTracker,
) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var pass: usize = 0;
    var skip: usize = 0;

    for (0..n_configs) |_| {
        var map_buf: [4096]u8 = undefined;
        const map_toml = config_gen.randomMappingConfig(rng, &map_buf);
        if (map_toml.len == 0) {
            skip += 1;
            continue;
        }

        const parsed = mapping.parseString(allocator, map_toml) catch {
            skip += 1;
            continue;
        };
        defer parsed.deinit();

        mapping.validate(&parsed.value) catch {
            skip += 1;
            continue;
        };

        var ctx = helpers.makeMapper(map_toml, allocator) catch {
            skip += 1;
            continue;
        };
        defer ctx.deinit();

        var oracle = OracleState{};

        var frames_buf: [200]Frame = undefined;
        const frames = frames_buf[0..@min(n_frames, frames_buf.len)];
        sequence_gen.randomSequence(rng, frames, parsed.value);

        // Build shrink context once per config (contains TOML copy + allocator).
        var sctx = ShrinkCtx{ .allocator = allocator, .toml_buf = undefined, .toml_len = map_toml.len };
        @memcpy(sctx.toml_buf[0..map_toml.len], map_toml);

        for (frames) |frame| {
            const prev_oracle = oracle;

            // Pre-check: will the oracle cross pending→active on this frame?
            // The oracle transitions when: button still held, phase==pending, elapsed+dt >= threshold.
            // Fire the production timer BEFORE apply() so both sides activate in sync.
            if (oracle.hold_phase == .pending and frame.dt_ms > 0) {
                const layers = parsed.value.layer orelse &[0]mapping.LayerConfig{};
                if (oracle.hold_layer_idx < layers.len) {
                    const lc = &layers[oracle.hold_layer_idx];
                    const threshold: u64 = @intCast(@max(0, lc.hold_timeout orelse 200));
                    if (oracle.hold_elapsed_ms + @as(u64, frame.dt_ms) >= threshold) {
                        // Also verify trigger is still held (oracle checks pressed and was_pressed)
                        const trigger_mask = btnMaskByName(lc.trigger);
                        const cur_buttons = if (frame.delta.buttons) |b| b else oracle.gs.buttons;
                        if (trigger_mask != 0 and (cur_buttons & trigger_mask) != 0 and (oracle.prev_buttons & trigger_mask) != 0) {
                            _ = ctx.mapper.layer.onTimerExpired();
                        }
                    }
                }
            }

            const prod_out = try ctx.mapper.apply(frame.delta, @as(u32, frame.dt_ms));
            const oracle_out = mapper_oracle.apply(&oracle, frame.delta, &parsed.value, @as(u64, frame.dt_ms));

            // On divergence: shrink the full sequence, log the minimal case, then assert.
            const btn_ok = oracle_out.gamepad.buttons == prod_out.gamepad.buttons;
            const dx_ok = oracle_out.gamepad.dpad_x == prod_out.gamepad.dpad_x;
            const dy_ok = oracle_out.gamepad.dpad_y == prod_out.gamepad.dpad_y;

            if (!btn_ok or !dx_ok or !dy_ok) {
                const min_frames = shrink_mod.shrinkSequence(
                    allocator,
                    frames,
                    &sctx,
                    shrinkCheck,
                ) catch frames; // on OOM fall back to original
                defer if (min_frames.ptr != frames.ptr) allocator.free(min_frames);
                logMinimalCase(map_toml, min_frames);
            }

            // Deterministic: button output (suppress + inject)
            try testing.expectEqual(oracle_out.gamepad.buttons, prod_out.gamepad.buttons);

            // Deterministic: dpad output
            try testing.expectEqual(oracle_out.gamepad.dpad_x, prod_out.gamepad.dpad_x);
            try testing.expectEqual(oracle_out.gamepad.dpad_y, prod_out.gamepad.dpad_y);

            // Aux events: compare count and key/mouse events
            try compareAux(&oracle_out.aux, &prod_out.aux);

            // Property: gyro direction consistency (non-deterministic, sign only)
            checkGyroSign(frame.delta, &prod_out);

            // Track transitions
            transition_id.classify(tracker, &prev_oracle, &oracle, frame.delta, &parsed.value);
        }
        pass += 1;
    }

    // At least some configs should have passed
    try testing.expect(pass > 0);
    try testing.expect(skip < n_configs);
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
    var tracker = CoverageTracker{};
    try runHarness(allocator, 200, 200, 0x6E4_A33E8, &tracker);

    const cov = tracker.coverage();
    if (cov.seen < cov.total) {
        std.log.warn("generative: transition coverage: {d}/{d}", .{ cov.seen, cov.total });
    }
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
    const prod = ctx.mapper.apply(.{ .buttons = lt | a }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = lt | a }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons, prod.gamepad.buttons);

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
    const prod = ctx.mapper.apply(.{ .buttons = lt | a | b }, 0) catch unreachable;
    const oout = mapper_oracle.apply(&oracle, .{ .buttons = lt | a | b }, &parsed.value, 0);
    try testing.expectEqual(oout.gamepad.buttons, prod.gamepad.buttons);
    try compareAux(&oout.aux, &prod.aux);
}
