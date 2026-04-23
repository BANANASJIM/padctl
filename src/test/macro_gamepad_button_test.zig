// Regression tests for issue #99: macro steps must emit gamepad_button and
// mouse_button targets in addition to keyboard keys.
//
// Before the fix, src/core/macro_player.zig:resolveKeyCode dropped any
// RemapTargetResolved variant other than .key. `{ down = "LT" }` / `{ tap = "A" }`
// inside a [[macro]] produced no output.
//
// These tests verify:
//   1. `{ tap = "LT" }` sets the LT bit then clears it next frame.
//   2. `{ down = "A" }` / `{ up = "A" }` set and clear the A bit.
//   3. `{ down = "RT" }` followed by layer switch (cancel) clears RT via
//      emitPendingReleases — no leak.
//   4. `{ tap = "mouse_left" }` emits a mouse_button aux event.
//   5. Unknown target names are silently skipped (existing behavior).

const std = @import("std");
const testing = std.testing;

const state_mod = @import("../core/state.zig");
const macro_mod = @import("../core/macro.zig");
const macro_player_mod = @import("../core/macro_player.zig");
const timer_queue_mod = @import("../core/timer_queue.zig");
const aux_event_mod = @import("../core/aux_event.zig");
const h = @import("helpers.zig");

const ButtonId = state_mod.ButtonId;
const MacroStep = macro_mod.MacroStep;
const Macro = macro_mod.Macro;
const MacroPlayer = macro_player_mod.MacroPlayer;
const TimerQueue = timer_queue_mod.TimerQueue;
const AuxEventList = aux_event_mod.AuxEventList;

fn btnBit(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

test "macro #99: tap LT sets LT bit and schedules release next frame" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "LT" }};
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    const done = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 0), aux.len);
    try testing.expectEqual(btnBit(.LT), injected & btnBit(.LT));
    try testing.expectEqual(btnBit(.LT), tap_release & btnBit(.LT));

    // Next frame: caller clears tap_release bits from injected (mapper cadence).
    injected &= ~tap_release;
    try testing.expectEqual(@as(u64, 0), injected & btnBit(.LT));
}

test "macro #99: down A then up A toggles A bit" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "A" }, .{ .up = "A" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    const done = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(done);
    // down + up in one step call → net-zero; tap_release should stay clean.
    try testing.expectEqual(@as(u64, 0), injected & btnBit(.A));
    try testing.expectEqual(@as(u64, 0), tap_release);
}

test "macro #99: down A with delay holds A bit between frames" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "A" }, .{ .delay = 10 }, .{ .up = "A" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    const done1 = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(!done1);
    try testing.expectEqual(btnBit(.A), injected & btnBit(.A));

    aux = .{};
    const done2 = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(done2);
    try testing.expectEqual(@as(u64, 0), injected & btnBit(.A));
}

test "macro #99: down RT then cancel clears RT via emitPendingReleases" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "RT" }, .{ .delay = 100 } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    _ = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expectEqual(btnBit(.RT), injected & btnBit(.RT));

    // Simulate layer switch / macro cancel.
    var aux2 = AuxEventList{};
    player.emitPendingReleases(&aux2, &injected);
    try testing.expectEqual(@as(u64, 0), injected & btnBit(.RT));
    // No key aux events — gamepad release is state-only.
    try testing.expectEqual(@as(usize, 0), aux2.len);
}

test "macro #99: tap mouse_left emits mouse_button aux events" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "mouse_left" }};
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    const done = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), aux.len);
    switch (aux.get(0)) {
        .mouse_button => |mb| {
            try testing.expectEqual(@as(u16, 0x110), mb.code);
            try testing.expect(mb.pressed);
        },
        else => return error.WrongType,
    }
    switch (aux.get(1)) {
        .mouse_button => |mb| try testing.expect(!mb.pressed),
        else => return error.WrongType,
    }
    try testing.expectEqual(@as(u64, 0), injected);
}

test "macro #99: unknown target name silently skipped" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{
        .{ .down = "NOT_A_REAL_THING" },
        .{ .tap = "KEY_A" },
    };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = MacroPlayer.init(&m, 1, 0);

    var aux = AuxEventList{};
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;

    const done = try player.step(&aux, &q, &injected, &tap_release);
    try testing.expect(done);
    // Unknown target produced nothing; KEY_A tap produced press+release.
    try testing.expectEqual(@as(usize, 2), aux.len);
    try testing.expectEqual(@as(u64, 0), injected);
}

// Integration-level test: full mapper path with a macro that emits a gamepad
// button. Verifies the mapper correctly merges macro-injected bits into the
// output GamepadState and clears tap bits on the next frame.
test "macro #99 integration: macro:boost triggers LT via tap on output state" {
    const allocator = testing.allocator;

    var ctx = try h.makeMapper(
        \\[remap]
        \\M1 = "macro:boost"
        \\
        \\[[macro]]
        \\name = "boost"
        \\steps = [
        \\  { tap = "LT" },
        \\]
    , allocator);
    defer ctx.deinit();

    const m1_idx = @intFromEnum(ButtonId.M1);
    const lt_bit = btnBit(.LT);

    const events1 = try ctx.mapper.apply(.{ .buttons = @as(u64, 1) << @as(u6, @intCast(m1_idx)) }, 16, 0);
    try testing.expectEqual(lt_bit, events1.gamepad.buttons & lt_bit);

    const events2 = try ctx.mapper.apply(.{ .buttons = @as(u64, 1) << @as(u6, @intCast(m1_idx)) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), events2.gamepad.buttons & lt_bit);
}
