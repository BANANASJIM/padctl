// regression_corpus_props.zig — deterministic regression tests for mapper bugs
// discovered by the generative harness.
//
// Each RegressionCase encodes the minimal reproducing sequence found by shrink.zig.
// Add new cases here as bugs are confirmed.

const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const mapper_oracle = @import("../gen/mapper_oracle.zig");
const sequence_gen = @import("../gen/sequence_gen.zig");
const mapping = @import("../../config/mapping.zig");
const state_mod = @import("../../core/state.zig");

const OracleState = mapper_oracle.OracleState;
const Frame = sequence_gen.Frame;
const ButtonId = state_mod.ButtonId;

const RegressionCase = struct {
    name: []const u8,
    mapping_toml: []const u8,
    frames: []const Frame,
    /// Expected button state after each frame (parallel to frames[]).
    expected_buttons: []const u64,
};

// Note on corpus shape: the RegressionCase harness threads frames into
// `Mapper.apply(delta, dt_ms, now_ns = 0)` without a real monotonic
// clock or calls to `onTimerExpired`. That means:
//
//   * Issue #79 (tap-on-layer boundary near hold_timeout) needs a real
//     now_ns progression plus an `onTimerExpired` call between frames,
//     so it cannot be expressed as a plain frame list. It is pinned as
//     a targeted test below instead.
//   * Issue #142 (commitSwitchTarget must rebuildAuxIfChanged) and
//     Issue #131-A (zombie uinput on rebind failure) are supervisor-
//     level bugs; `Mapper.apply` cannot drive them. Targeted
//     supervisor tests already live in
//     `src/supervisor.zig` ("switch to mapping with new aux KEY_*")
//     and `src/test/properties/supervisor_sm_props.zig:451-565,628-735`.
//     Duplicating them here as oracle-comparison corpus entries would
//     not be meaningful — flagging explicitly and not force-fitting.
//
// As the harness grows to cover timing and state-machine dimensions,
// migrate the targeted-cases list below into proper RegressionCase
// entries.
const cases = [_]RegressionCase{};

test "regression: all corpus cases pass" {
    const allocator = testing.allocator;

    for (cases) |case| {
        var ctx = try helpers.makeMapper(case.mapping_toml, allocator);
        defer ctx.deinit();

        var oracle = OracleState{};

        std.debug.assert(case.frames.len == case.expected_buttons.len);

        for (case.frames, case.expected_buttons, 0..) |frame, expected, idx| {
            const prod = try ctx.mapper.apply(frame.delta, @as(u32, frame.dt_ms), 0);
            const oout = mapper_oracle.apply(&oracle, frame.delta, &ctx.parsed.value, @as(u64, frame.dt_ms));

            testing.expectEqual(expected, prod.gamepad.buttons) catch |err| {
                std.log.err("regression '{s}' frame {d}: production={d} expected={d}", .{
                    case.name, idx, prod.gamepad.buttons, expected,
                });
                return err;
            };
            testing.expectEqual(expected, oout.gamepad.buttons) catch |err| {
                std.log.err("regression '{s}' frame {d}: oracle={d} expected={d}", .{
                    case.name, idx, oout.gamepad.buttons, expected,
                });
                return err;
            };
        }
    }
}

// --- targeted regression cases (do not fit the plain-frames corpus shape) ---

test "regression targeted: issue #79 — tap-on-layer at hold_timeout-5ms emits tap" {
    // Pre-fix repro: apply() re-read CLOCK_MONOTONIC internally after the
    // timer handler ran; physical release at press+195ms drifted past the
    // 200ms hold_timeout, losing the tap. The fix threads a single
    // ppoll-wakeup snapshot through both `onTimerExpired` and `apply`.
    const allocator = testing.allocator;
    var ctx = try helpers.makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "A"
        \\hold_timeout = 200
    , allocator);
    defer ctx.deinit();

    const lt_mask: u64 = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.LT)));
    const a_mask: u64 = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.A)));

    const press_ns: i128 = 1_000_000_000;
    _ = try ctx.mapper.apply(.{ .buttons = lt_mask }, 16, press_ns);

    const timer_ns: i128 = press_ns + 200_000_000;
    _ = ctx.mapper.onTimerExpired(timer_ns);

    const release_ns: i128 = press_ns + 195_000_000;
    const ev = try ctx.mapper.apply(.{ .buttons = 0 }, 16, release_ns);
    try testing.expect((ev.gamepad.buttons & a_mask) != 0);
}
