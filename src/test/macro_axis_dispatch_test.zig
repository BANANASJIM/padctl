// Regression for issue #99: macros must drive the LT/RT *analog* axis, not
// only the LT/RT button bit. PR #152 set the bit in injected_buttons (which
// emits BTN_TL2/BTN_TR2 digital), but downstream consumers reading the analog
// axis (ABS_Z / ABS_RZ — what SDL, Steam Input, and most games read) saw the
// axis stuck at the raw input value. These tests assert the axis saturates
// while a macro is holding LT/RT and follows the raw value otherwise.

const std = @import("std");
const testing = std.testing;

const state_mod = @import("../core/state.zig");
const h = @import("helpers.zig");

const ButtonId = state_mod.ButtonId;

fn btnBit(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

test "macro #99: tap LT saturates lt axis for one frame then releases" {
    const allocator = testing.allocator;

    var ctx = try h.makeMapper(
        \\[remap]
        \\M1 = "macro:full_brake"
        \\
        \\[[macro]]
        \\name = "full_brake"
        \\steps = [
        \\  { tap = "LT" },
        \\]
    , allocator);
    defer ctx.deinit();

    const m1_bit = btnBit(.M1);

    const frame1 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 0);
    try testing.expectEqual(@as(u8, 255), frame1.gamepad.lt);

    const frame2 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 16 * std.time.ns_per_ms);
    try testing.expectEqual(@as(u8, 0), frame2.gamepad.lt);
}

test "macro #99: down LT holds lt at max across frames until up" {
    const allocator = testing.allocator;

    var ctx = try h.makeMapper(
        \\[remap]
        \\M1 = "macro:hold_lt"
        \\
        \\[[macro]]
        \\name = "hold_lt"
        \\steps = [
        \\  { down = "LT" },
        \\  { delay = 20 },
        \\  { up = "LT" },
        \\]
    , allocator);
    defer ctx.deinit();

    const m1_bit = btnBit(.M1);
    const ns_per_ms: i128 = std.time.ns_per_ms;

    const frame1 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 0);
    try testing.expectEqual(@as(u8, 255), frame1.gamepad.lt);

    const frame2 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 10 * ns_per_ms);
    try testing.expectEqual(@as(u8, 255), frame2.gamepad.lt);

    const frame3 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 25 * ns_per_ms);
    try testing.expectEqual(@as(u8, 0), frame3.gamepad.lt);
}

test "macro #99: down RT drives rt axis without touching lt" {
    const allocator = testing.allocator;

    var ctx = try h.makeMapper(
        \\[remap]
        \\M1 = "macro:rt_only"
        \\
        \\[[macro]]
        \\name = "rt_only"
        \\steps = [
        \\  { down = "RT" },
        \\  { delay = 20 },
        \\  { up = "RT" },
        \\]
    , allocator);
    defer ctx.deinit();

    const m1_bit = btnBit(.M1);

    const frame1 = try ctx.mapper.apply(.{ .buttons = m1_bit }, 16, 0);
    try testing.expectEqual(@as(u8, 255), frame1.gamepad.rt);
    try testing.expectEqual(@as(u8, 0), frame1.gamepad.lt);
}

test "macro #99: macro axis floor cannot lower physical input" {
    const allocator = testing.allocator;

    var ctx = try h.makeMapper(
        \\[remap]
        \\M1 = "macro:full_brake"
        \\
        \\[[macro]]
        \\name = "full_brake"
        \\steps = [
        \\  { down = "LT" },
        \\  { delay = 50 },
        \\  { up = "LT" },
        \\]
    , allocator);
    defer ctx.deinit();

    const m1_bit = btnBit(.M1);

    // User physically holding LT at 200; macro requests max (255) — max wins.
    const frame1 = try ctx.mapper.apply(.{ .buttons = m1_bit, .lt = 200 }, 16, 0);
    try testing.expectEqual(@as(u8, 255), frame1.gamepad.lt);
}

test "macro #99: emitPendingReleases clears held axis on cancel" {
    const allocator = testing.allocator;

    const macro_mod = @import("../core/macro.zig");
    const macro_player_mod = @import("../core/macro_player.zig");
    const timer_queue_mod = @import("../core/timer_queue.zig");
    const aux_event_mod = @import("../core/aux_event.zig");

    const steps = [_]macro_mod.MacroStep{
        .{ .down = "LT" },
        .{ .delay = 1000 },
        .{ .up = "LT" },
    };
    const m = macro_mod.Macro{ .name = "hold_lt", .steps = &steps };
    var player = macro_player_mod.MacroPlayer.init(&m, 1, 0);

    var aux = aux_event_mod.AuxEventList{};
    var q = timer_queue_mod.TimerQueue.init(allocator, -1);
    defer q.deinit();
    var injected: u64 = 0;
    var tap_release: u64 = 0;
    var axes = macro_player_mod.AxisInjection{};

    _ = try player.step(&aux, &q, &injected, &tap_release, &axes, 0);
    try testing.expectEqual(@as(u8, 255), axes.lt);
    try testing.expectEqual(@as(u8, 255), player.held_axis_lt);

    // Cancel via emitPendingReleases — clears held floor.
    var aux2 = aux_event_mod.AuxEventList{};
    player.emitPendingReleases(&aux2, &injected);
    try testing.expectEqual(@as(u8, 0), player.held_axis_lt);
    try testing.expectEqual(@as(u8, 0), player.held_axis_rt);
}
