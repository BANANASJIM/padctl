// Regression test for issue #330: a macro launched from inside a layer that
// reaches pause_for_release must drain its up= cleanup steps when the layer
// trigger is released, even if the macro launch key is still held.
//
// Before the fix, handleLayerActiveChanged unconditionally cancelled all
// in-flight macros on every layer state change. Macros in waiting_for_release
// state never ran their up= steps; emitPendingReleases ran instead.
//
// The fix: on layer *deactivation only*, macros that are waiting_for_release
// get notifyTriggerReleased() + one step() pass to drain their cleanup steps.
// Macros not in waiting_for_release state are still cancelled (unchanged).

const std = @import("std");
const testing = std.testing;

const h = @import("helpers.zig");
const state_mod = @import("../core/state.zig");

const ButtonId = state_mod.ButtonId;
const btnMask = h.btnMask;
const makeMapper = h.makeMapper;

// Linux key codes used in assertions.
const KEY_LEFTSHIFT: u16 = 42;
const KEY_A: u16 = 30;

// The test encodes v1ld's exact scenario (issue #330), adapted to use keyboard
// keys for observability. Gamepad buttons (like the reporter's RB and X) do not
// produce aux events, so order-based falsifiability requires key targets.
//
// Macro structure mirrors the reporter's:
//   { down = "KEY_LEFTSHIFT" }   analogous to "down RB"
//   { down = "KEY_A" }           analogous to "down X"
//   "pause_for_release"
//   { up = "KEY_A" }             analogous to "up X"
//   { up = "KEY_LEFTSHIFT" }     analogous to "up RB"
//
// Falsifiability: emitPendingReleases (no-drain path) walks steps in press
// order and emits KEY_LEFTSHIFT up before KEY_A up. The drain path runs the
// actual up= steps (step 3 = up KEY_A, step 4 = up KEY_LEFTSHIFT), so KEY_A up
// comes first. The test asserts KEY_A up precedes KEY_LEFTSHIFT up.
test "macro #330: drain pause_for_release on layer deactivation — up= steps run in unwind order" {
    const allocator = testing.allocator;

    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "combo"
        \\trigger = "M1"
        \\activation = "hold"
        \\hold_timeout = 50
        \\
        \\[layer.remap]
        \\X = "macro:rb-x-combo"
        \\
        \\[[macro]]
        \\name = "rb-x-combo"
        \\steps = [
        \\  { down = "KEY_LEFTSHIFT" },
        \\  { down = "KEY_A" },
        \\  "pause_for_release",
        \\  { up = "KEY_A" },
        \\  { up = "KEY_LEFTSHIFT" },
        \\]
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const m1_mask = btnMask(.M1);
    const x_mask = btnMask(.X);

    // Frame 1: M1 pressed — layer enters PENDING.
    _ = try m.apply(.{ .buttons = m1_mask }, 16, 0);

    // Advance hold timer so layer becomes ACTIVE.
    _ = m.layer.onTimerExpired();

    // Frame 2: X pressed while layer active — macro starts.
    // step() runs: down KEY_LEFTSHIFT, down KEY_A, pause_for_release → waiting.
    const ev2 = try m.apply(.{ .buttons = m1_mask | x_mask }, 16, 1);

    // Confirm macro started and reached pause_for_release.
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);
    try testing.expect(m.active_macros.items[0].waiting_for_release);

    // Confirm both key presses were emitted on Frame 2.
    var found_lshift_press = false;
    var found_a_press = false;
    for (ev2.aux.slice()) |e| {
        switch (e) {
            .key => |k| {
                if (k.code == KEY_LEFTSHIFT and k.pressed) found_lshift_press = true;
                if (k.code == KEY_A and k.pressed) found_a_press = true;
            },
            else => {},
        }
    }
    try testing.expect(found_lshift_press);
    try testing.expect(found_a_press);

    // Frame 3: M1 released (X still held) — layer deactivates.
    // The drain fix: notifyTriggerReleased() + step() runs up KEY_A then up KEY_LEFTSHIFT.
    const ev3 = try m.apply(.{ .buttons = x_mask }, 16, 2);

    // After deactivation the macro must be drained and removed.
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);

    // Collect key release events from the deactivation frame in order.
    var releases: [8]u16 = undefined;
    var release_count: usize = 0;
    for (ev3.aux.slice()) |e| {
        switch (e) {
            .key => |k| {
                if (!k.pressed and release_count < releases.len) {
                    releases[release_count] = k.code;
                    release_count += 1;
                }
            },
            else => {},
        }
    }

    // Both keys must be released on the deactivation frame.
    var a_pos: ?usize = null;
    var lshift_pos: ?usize = null;
    for (releases[0..release_count], 0..) |code, idx| {
        if (code == KEY_A) a_pos = idx;
        if (code == KEY_LEFTSHIFT) lshift_pos = idx;
    }

    try testing.expect(a_pos != null); // KEY_A release must appear
    try testing.expect(lshift_pos != null); // KEY_LEFTSHIFT release must appear

    // Drain order: up KEY_A (step 3) before up KEY_LEFTSHIFT (step 4).
    // Without the drain fix, emitPendingReleases emits in press order:
    // KEY_LEFTSHIFT first (index 0 in held), KEY_A second — this assertion fails.
    try testing.expect(a_pos.? < lshift_pos.?);
}

// Guard: layer deactivation must still cancel macros in delay state (no drain
// for macros not at pause_for_release). Ensures the fix is scoped correctly.
test "macro #330: layer deactivation cancels delay-state macros — no drain for non-waiting" {
    const allocator = testing.allocator;

    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "combo"
        \\trigger = "M1"
        \\activation = "hold"
        \\hold_timeout = 50
        \\
        \\[layer.remap]
        \\X = "macro:long-delay"
        \\
        \\[[macro]]
        \\name = "long-delay"
        \\steps = [
        \\  { down = "KEY_LEFTSHIFT" },
        \\  { delay = 60000 },
        \\  { up = "KEY_LEFTSHIFT" },
        \\]
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const m1_mask = btnMask(.M1);
    const x_mask = btnMask(.X);

    // Frame 1: M1 pressed → PENDING.
    _ = try m.apply(.{ .buttons = m1_mask }, 16, 0);
    _ = m.layer.onTimerExpired();

    // Frame 2: X pressed → macro starts, runs down KEY_LEFTSHIFT, hits delay.
    _ = try m.apply(.{ .buttons = m1_mask | x_mask }, 16, 1);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);
    // Macro is stalled at delay, not at pause_for_release.
    try testing.expect(!m.active_macros.items[0].waiting_for_release);

    // Frame 3: M1 released → layer deactivates → macro in delay is cancelled.
    const ev3 = try m.apply(.{ .buttons = x_mask }, 16, 2);

    // Macro must be cancelled (not drained), active_macros empty.
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);

    // emitPendingReleases emits KEY_LEFTSHIFT up on cancel.
    var found_lshift_release = false;
    for (ev3.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_LEFTSHIFT and !k.pressed) {
                found_lshift_release = true;
            },
            else => {},
        }
    }
    try testing.expect(found_lshift_release);
}
