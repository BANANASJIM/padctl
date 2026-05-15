// transition_coverage_props.zig — aggregate coverage assertion for all 23 TransitionId classes.
//
// Falsifiability contract: this test FAILS (listing missing class names) if:
//   (a) classify() loses a branch (e.g. the gyro_deactivated arm is deleted), or
//   (b) a new TransitionId value is added to the enum without a corresponding
//       classify() branch and targeted scenario here.
//
// Mutation that triggers failure: delete the `tracker.mark(.gyro_deactivated)` line
// in transition_id.zig → test prints "missing classes (1): gyro_deactivated" and fails.
//
// This file is intentionally separate from generative_mapper_props.zig to avoid
// merge conflicts with PR #242 (branch fix/test-f1-f4-generative-drt), which is
// concurrently rewriting that file.

const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const mapper_oracle = @import("../gen/mapper_oracle.zig");
const transition_id = @import("../gen/transition_id.zig");
const config_gen = @import("../gen/config_gen.zig");
const sequence_gen = @import("../gen/sequence_gen.zig");
const mapping = @import("../../config/mapping.zig");
const state_mod = @import("../../core/state.zig");

const TransitionId = transition_id.TransitionId;
const CoverageTracker = transition_id.CoverageTracker;
const OracleState = mapper_oracle.OracleState;
const GamepadStateDelta = state_mod.GamepadStateDelta;

const field_count = @typeInfo(TransitionId).@"enum".fields.len;

// drive applies one frame through the oracle + classify, updating tracker.
fn drive(
    tracker: *CoverageTracker,
    oracle: *OracleState,
    delta: GamepadStateDelta,
    cfg: *const mapping.MappingConfig,
    dt_ms: u64,
) void {
    const prev = oracle.*;
    _ = mapper_oracle.apply(oracle, delta, cfg, dt_ms);
    transition_id.classify(tracker, &prev, oracle, delta, cfg);
}

// assertNoMissing prints each uncovered class name and fails.
fn assertNoMissing(tracker: *const CoverageTracker) !void {
    var buf: [field_count]TransitionId = undefined;
    const missing = tracker.missing(&buf);
    if (missing.len > 0) {
        std.debug.print("\nmissing classes ({d}):\n", .{missing.len});
        for (missing) |id| std.debug.print("  {s}\n", .{@tagName(id)});
    }
    try testing.expectEqual(@as(usize, 0), missing.len);
}

test "transition_coverage: all 23 TransitionId classes reached" {
    const allocator = testing.allocator;
    var tracker = CoverageTracker{};

    // --- Scenario 1: hold-layer FSM (idle→pending→active→idle) + remap targets ---
    {
        const toml_str =
            \\[remap]
            \\A = "KEY_F1"
            \\B = "mouse_left"
            \\C = "Z"
            \\M1 = "macro:m1"
            \\
            \\[[macro]]
            \\name = "m1"
            \\[[macro.steps]]
            \\tap = "A"
            \\
            \\[[layer]]
            \\name = "aim"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 50
            \\
            \\[layer.remap]
            \\X = "KEY_F2"
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);
        const a = helpers.btnMask(.A);
        const b = helpers.btnMask(.B);
        const c = helpers.btnMask(.C);
        const m1 = helpers.btnMask(.M1);

        // idle → pending
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0);
        // pending → active (dt > timeout)
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 60);
        // active: remap_layer_override (layer active + layer has remap)
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0);
        // active → idle
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // remap_suppress_button + remap_inject_key
        drive(&tracker, &oracle, .{ .buttons = a }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // remap_inject_mouse
        drive(&tracker, &oracle, .{ .buttons = b }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // remap_inject_gamepad
        drive(&tracker, &oracle, .{ .buttons = c }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // macro_triggered
        drive(&tracker, &oracle, .{ .buttons = m1 }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // simultaneous_multi_button
        drive(&tracker, &oracle, .{ .buttons = a | b }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);
    }

    // --- Scenario 2: toggle-layer (toggle_on / toggle_off) ---
    {
        const toml_str =
            \\[[layer]]
            \\name = "fn"
            \\trigger = "Select"
            \\activation = "toggle"
            \\
            \\[layer.remap]
            \\A = "KEY_F1"
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const sel = helpers.btnMask(.Select);

        drive(&tracker, &oracle, .{ .buttons = sel }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0); // toggle_on
        drive(&tracker, &oracle, .{ .buttons = sel }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0); // toggle_off
    }

    // --- Scenario 3: hold tap (pending → idle_tap) ---
    {
        const toml_str =
            \\[[layer]]
            \\name = "aim"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 300
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);

        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0); // idle → pending
        // release before timeout → pending → idle_tap
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 10);
    }

    // --- Scenario 4: mutual exclusion blocked ---
    {
        const toml_str =
            \\[[layer]]
            \\name = "aim"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 50
            \\
            \\[[layer]]
            \\name = "aim2"
            \\trigger = "RT"
            \\activation = "hold"
            \\hold_timeout = 50
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);
        const rt = helpers.btnMask(.RT);

        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0); // idle → pending
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 60); // pending → active
        // press RT while LT-layer active → mutual_exclusion_blocked
        drive(&tracker, &oracle, .{ .buttons = lt | rt }, cfg, 0);
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);
    }

    // --- Scenario 5: dpad arrows + gamepad passthrough ---
    {
        const toml_str =
            \\[dpad]
            \\mode = "arrows"
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        drive(&tracker, &oracle, .{ .dpad_x = -1 }, &parsed.value, 0); // dpad_arrows_emit

        const toml_str2 =
            \\[dpad]
            \\mode = "gamepad"
        ;
        const parsed2 = try mapping.parseString(allocator, toml_str2);
        defer parsed2.deinit();
        var oracle2 = OracleState{};
        drive(&tracker, &oracle2, .{ .dpad_x = 1 }, &parsed2.value, 0); // dpad_gamepad_passthrough
    }

    // --- Scenario 6: gyro activated / deactivated ---
    {
        const toml_str =
            \\[gyro]
            \\mode = "mouse"
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        drive(&tracker, &oracle, .{ .gyro_x = 100 }, cfg, 0); // gyro_activated
        drive(&tracker, &oracle, .{}, cfg, 0); // gyro_deactivated
    }

    // --- Scenario 7: all_buttons_pressed + button_held_across_layer_switch ---
    {
        // all_buttons_pressed: fill every ButtonId bit
        const button_count = @typeInfo(state_mod.ButtonId).@"enum".fields.len;
        var all_mask: u64 = 0;
        for (0..button_count) |i| all_mask |= @as(u64, 1) << @as(u6, @intCast(i));

        const toml_str = "";
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        drive(&tracker, &oracle, .{ .buttons = all_mask }, &parsed.value, 0);
    }
    {
        // button_held_across_layer_switch: A already pressed before LT layer becomes active.
        // Frame sequence: press A, then press LT (→pending), then hold LT past timeout (→active).
        // On the pending→active frame: prev_buttons has A set, A is in non_trigger mask → fires.
        const toml_str =
            \\[[layer]]
            \\name = "aim"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 50
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);
        const a = helpers.btnMask(.A);

        // A held first (prev_buttons will have A on next frame)
        drive(&tracker, &oracle, .{ .buttons = a }, cfg, 0);
        // LT pressed while A held → idle → pending
        drive(&tracker, &oracle, .{ .buttons = lt | a }, cfg, 0);
        // Still holding LT+A past timeout → pending → active; classify fires button_held_across_layer_switch
        drive(&tracker, &oracle, .{ .buttons = lt | a }, cfg, 60);
    }

    // --- Scenario 8: rapid_layer_toggle + macro_cancelled_by_layer ---
    {
        // rapid_layer_toggle: quick hold press + release
        const toml_str =
            \\[remap]
            \\M1 = "macro:m1"
            \\
            \\[[macro]]
            \\name = "m1"
            \\[[macro.steps]]
            \\tap = "A"
            \\
            \\[[layer]]
            \\name = "rapid"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 50
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);

        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0); // idle → pending
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 60); // pending → active
        // rapid release: active → idle (rapid_layer_toggle)
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 0);

        // macro_cancelled_by_layer: need layer with macro: target in remap
        // Re-use config with macro remap — press LT again to get pending→active while macro target present
        var oracle2 = OracleState{};
        drive(&tracker, &oracle2, .{ .buttons = lt }, cfg, 0);
        drive(&tracker, &oracle2, .{ .buttons = lt }, cfg, 60); // → active
        // classify sees hold_phase change to active with macro: in remap → macro_cancelled_by_layer
    }

    // --- Scenario 9: tap_event_emitted ---
    // tap_event_emitted fires when pending_tap_release transitions from null → Some.
    // The oracle FSM sets pending_tap_release when a hold-layer trigger is released
    // while still in .pending phase (quick tap before hold_timeout elapses).
    {
        const toml_str =
            \\[[layer]]
            \\name = "aim"
            \\trigger = "LT"
            \\activation = "hold"
            \\hold_timeout = 300
        ;
        const parsed = try mapping.parseString(allocator, toml_str);
        defer parsed.deinit();
        var oracle = OracleState{};
        const cfg = &parsed.value;

        const lt = helpers.btnMask(.LT);
        drive(&tracker, &oracle, .{ .buttons = lt }, cfg, 0); // pending
        drive(&tracker, &oracle, .{ .buttons = 0 }, cfg, 10); // tap release → pending_tap_release set
    }

    // --- Generative sweep to catch any remaining gaps ---
    {
        var prng = std.Random.DefaultPrng.init(0xB4_C0VERAGE);
        const rng = prng.random();

        for (0..300) |_| {
            var map_buf: [4096]u8 = undefined;
            const map_toml = config_gen.randomMappingConfig(rng, &map_buf);
            if (map_toml.len == 0) continue;

            const parsed = mapping.parseString(allocator, map_toml) catch continue;
            defer parsed.deinit();
            mapping.validate(&parsed.value) catch continue;

            var oracle = OracleState{};
            var frames_buf: [150]sequence_gen.Frame = undefined;
            sequence_gen.randomSequence(rng, &frames_buf, parsed.value);

            for (frames_buf) |frame| {
                drive(&tracker, &oracle, frame.delta, &parsed.value, frame.dt_ms);
            }
        }
    }

    try assertNoMissing(&tracker);
}
