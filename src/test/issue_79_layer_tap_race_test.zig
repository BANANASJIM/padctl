// Regression tests for issue #79 — "Tap buttons not working on layer".
//
// HYPOTHESIS UNDER TEST
// ---------------------
// `src/event_loop.zig` ppoll iteration takes `const now = monotonicNs()`
// once per wake, then the device drain loop processes every queued HID
// frame with the same `now`. When the kernel queues multiple frames
// between wakes (Vader 5 Pro at 1000Hz + scheduler jitter), a frame
// that physically arrived earlier than wake-time is timestamped with
// wake-time, not actual-frame time.
//
// Combined with the strict `<` comparison in
// `LayerState.onTriggerRelease` (src/core/layer.zig — `.active` arm:
// `(now_ns - press_ns) < hold_timeout_ns`), a release whose stale
// `now_ns` snapshot equals exactly `press_ns + hold_timeout_ns` fails
// the predicate and drops the tap, even though the user physically
// released well below the hold boundary.
//
// The three tests below exercise `LayerState` directly (Layer 0 — no
// real timerfd, no Mapper, no event_loop). They model the temporal
// shape of the hypothesis:
//
//   T1: same-wake batch (control). Press + release share one `now_ns`.
//       PENDING + release path emits tap unconditionally — no `<`
//       comparison involved. Expected: PASS on main.
//
//   T2: cross-wake with timerfd between (the bug). Press at T,
//       timerfd transitions PENDING -> ACTIVE, release at exactly
//       `T + hold_timeout`. Strict `<` evaluates `200ms < 200ms` =
//       false -> no tap. Expected: FAIL on main if hypothesis holds.
//
//   T3: sub-boundary release after timer fired (control). Press at T,
//       timerfd ACTIVE, release at `T + hold_timeout + 5ms`. The user
//       genuinely held past the boundary. No tap is correct.
//       Expected: PASS on main; locks down the upper-boundary contract.
//
// DO NOT FIX THE BUG IN THIS PATCH. Tests document the hypothesis;
// the dispatcher decides next steps from CI signal.
//
// Refs: issue #79.

const std = @import("std");
const testing = std.testing;

const layer = @import("../core/layer.zig");
const remap = @import("../core/remap.zig");

const LayerState = layer.LayerState;
const RemapTarget = remap.RemapTargetResolved;

// User config from issue #79:
//   [[layer]]
//   name = "fps"
//   trigger = "LM"
//   activation = "hold"
//   tap = "Select"
//   hold_timeout = 200
const layer_name = "fps";
const hold_timeout_ms: u64 = 200;
const hold_timeout_ns: i128 = 200_000_000;
const tap_target = RemapTarget{ .key = 183 }; // KEY_F13 stand-in; identity is irrelevant.

test "issue #79 T1: same-wake batch — PENDING release shares now_ns, tap fires" {
    // Friendly case: kernel queued press and release in the same ppoll
    // wake, both stamped with the wake's `now_ns`. PENDING + release
    // takes the unconditional `.disarm_timer + .tap_event` arm — no
    // strict-< check. Tap MUST fire.
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const wake_ns: i128 = 5_000_000_000;
    _ = ls.onTriggerPress(layer_name, hold_timeout_ms, wake_ns);

    // No timer expiry between press and release — still PENDING.
    const res = ls.onTriggerRelease(tap_target, wake_ns);

    try testing.expect(res.tap_event != null);
    try testing.expectEqual(@as(?RemapTarget, tap_target), res.tap_event);
    try testing.expect(res.disarm_timer);
    try testing.expect(!res.layer_deactivated);
}

test "issue #79 T2: cross-wake — release at press+hold_timeout after timerfd fired drops tap" {
    // Failing case under hypothesis:
    //   * Wake A samples now=T_A. Press queued frame -> press_ns=T_A.
    //     Layer timerfd armed for hold_timeout_ms.
    //   * Real release happens at ~T_A+150ms (clear tap intent).
    //   * Kernel queues release frame; ppoll returns at T_A+~200ms.
    //     Timer fd is also readable. event_loop takes one snapshot
    //     `now=T_A+200ms`, drains the timer first (or processes timer
    //     callback before release apply), so phase is .active by the
    //     time release is dispatched.
    //   * Release apply uses the stale now=T_A+200ms.
    //     `.active` arm checks `(200_000_000 - 0) < 200_000_000` -> false
    //     -> tap_event = null. Tap silently dropped.
    //
    // Hypothesis: tap_event is null on current main. This assertion
    // FAILS on main if hypothesis holds — that's the failure signal.
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const press_ns: i128 = 7_000_000_000;
    _ = ls.onTriggerPress(layer_name, hold_timeout_ms, press_ns);

    // Layer timerfd expired between wakes -> phase transitions
    // PENDING -> ACTIVE.
    _ = ls.onTimerExpired();

    // Wake B snapshot equals exactly press + hold_timeout.
    const release_ns: i128 = press_ns + hold_timeout_ns;
    const res = ls.onTriggerRelease(tap_target, release_ns);

    // Hypothesis confirmed if tap_event is null here. Expectation
    // (the user-visible correct behavior): tap fires.
    try testing.expect(res.layer_deactivated);
    try testing.expect(res.tap_event != null);
    try testing.expectEqual(@as(?RemapTarget, tap_target), res.tap_event);
}

test "issue #79 T3: sub-boundary release post-timer — held past hold_timeout, no tap" {
    // Genuine hold case: press at T, timer fires at T+200ms, release
    // at T+205ms. The user clearly held past the boundary; emitting
    // a tap here would be a false positive. Locks the upper-boundary
    // semantics any future fix must preserve.
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const press_ns: i128 = 10_000_000_000;
    _ = ls.onTriggerPress(layer_name, hold_timeout_ms, press_ns);
    _ = ls.onTimerExpired();

    const release_ns: i128 = press_ns + hold_timeout_ns + 5_000_000; // +5ms past
    const res = ls.onTriggerRelease(tap_target, release_ns);

    try testing.expect(res.layer_deactivated);
    try testing.expect(res.tap_event == null);
}
