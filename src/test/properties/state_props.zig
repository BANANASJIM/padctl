const std = @import("std");
const testing = std.testing;

const state = @import("../../core/state.zig");
const GamepadState = state.GamepadState;
const ButtonId = state.ButtonId;

fn btnMask(id: ButtonId) u64 {
    return @as(u64, 1) << @intFromEnum(id);
}

// P6: synthesizeDpadAxes is idempotent
test "property: synthesizeDpadAxes idempotency — double apply yields same result" {
    var rng = std.Random.DefaultPrng.init(0xABCD_1234);
    const random = rng.random();

    for (0..1000) |_| {
        var gs = GamepadState{ .buttons = random.int(u64) };
        gs.synthesizeDpadAxes();
        const dx1 = gs.dpad_x;
        const dy1 = gs.dpad_y;

        gs.synthesizeDpadAxes();
        try testing.expectEqual(dx1, gs.dpad_x);
        try testing.expectEqual(dy1, gs.dpad_y);
    }
}

// P6: all 9 dpad button combinations produce correct dpad_x/dpad_y
test "property: synthesizeDpadAxes — all 9 button combos yield correct axes" {
    const DpadCombo = struct { up: bool, down: bool, left: bool, right: bool, dx: i8, dy: i8 };
    const combos = [_]DpadCombo{
        .{ .up = false, .down = false, .left = false, .right = false, .dx = 0, .dy = 0 },
        .{ .up = true, .down = false, .left = false, .right = false, .dx = 0, .dy = -1 },
        .{ .up = false, .down = true, .left = false, .right = false, .dx = 0, .dy = 1 },
        .{ .up = false, .down = false, .left = true, .right = false, .dx = -1, .dy = 0 },
        .{ .up = false, .down = false, .left = false, .right = true, .dx = 1, .dy = 0 },
        .{ .up = true, .down = false, .left = true, .right = false, .dx = -1, .dy = -1 },
        .{ .up = true, .down = false, .left = false, .right = true, .dx = 1, .dy = -1 },
        .{ .up = false, .down = true, .left = true, .right = false, .dx = -1, .dy = 1 },
        .{ .up = false, .down = true, .left = false, .right = true, .dx = 1, .dy = 1 },
    };

    for (combos) |c| {
        var gs = GamepadState{};
        if (c.up) gs.buttons |= btnMask(.DPadUp);
        if (c.down) gs.buttons |= btnMask(.DPadDown);
        if (c.left) gs.buttons |= btnMask(.DPadLeft);
        if (c.right) gs.buttons |= btnMask(.DPadRight);

        gs.synthesizeDpadAxes();
        try testing.expectEqual(c.dx, gs.dpad_x);
        try testing.expectEqual(c.dy, gs.dpad_y);
    }
}

// Opposing directions cancel out
test "property: synthesizeDpadAxes — opposing directions cancel" {
    // Up + Down → dy=0
    var gs = GamepadState{};
    gs.buttons = btnMask(.DPadUp) | btnMask(.DPadDown);
    gs.synthesizeDpadAxes();
    try testing.expectEqual(@as(i8, 0), gs.dpad_y);

    // Left + Right → dx=0
    gs = GamepadState{};
    gs.buttons = btnMask(.DPadLeft) | btnMask(.DPadRight);
    gs.synthesizeDpadAxes();
    try testing.expectEqual(@as(i8, 0), gs.dpad_x);
}
