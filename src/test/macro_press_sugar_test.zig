// Parse-time expansion of `{ press = "BTN" }` macro steps.
// Each press desugars to `{ down = "BTN" }` at its position, with `{ up = "BTN" }`
// steps appended after the last step in reverse encounter order (LIFO unwind).

const std = @import("std");
const testing = std.testing;
const mapping = @import("../config/mapping.zig");
const macro_mod = @import("../core/macro.zig");

const MacroStep = macro_mod.MacroStep;

fn expectTap(step: MacroStep, want: []const u8) !void {
    try testing.expectEqualStrings(want, step.tap);
}
fn expectDown(step: MacroStep, want: []const u8) !void {
    try testing.expectEqualStrings(want, step.down);
}
fn expectUp(step: MacroStep, want: []const u8) !void {
    try testing.expectEqualStrings(want, step.up);
}
fn expectPause(step: MacroStep) !void {
    _ = step.pause_for_release;
}

// A — identity: no press steps → expansion is a no-op.
test "macro_press: case A — no press steps is identity" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { down = "RB" },
        \\    { up = "RB" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 2), m.steps.len);
    try expectDown(m.steps[0], "RB");
    try expectUp(m.steps[1], "RB");
}

// B — single press: expands to down at site + up appended at end.
test "macro_press: case B — single press expands to down + up" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { press = "RB" },
        \\    "pause_for_release",
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 3), m.steps.len);
    try expectDown(m.steps[0], "RB");
    try expectPause(m.steps[1]);
    try expectUp(m.steps[2], "RB");
}

// C — multiple press LIFO unwind: ups appear in reverse encounter order.
test "macro_press: case C — multiple press unwinds in LIFO order" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { press = "RB" },
        \\    { press = "X" },
        \\    "pause_for_release",
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 5), m.steps.len);
    try expectDown(m.steps[0], "RB");
    try expectDown(m.steps[1], "X");
    try expectPause(m.steps[2]);
    // LIFO: X before RB
    try expectUp(m.steps[3], "X");
    try expectUp(m.steps[4], "RB");
}

// D — press with extra steps: non-press steps survive untouched.
test "macro_press: case D — press with extra tap step survives intact" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { press = "RB" },
        \\    { tap = "Y" },
        \\    "pause_for_release",
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 4), m.steps.len);
    try expectDown(m.steps[0], "RB");
    try expectTap(m.steps[1], "Y");
    try expectPause(m.steps[2]);
    try expectUp(m.steps[3], "RB");
}

// E — conflict error: press + explicit up of the same button is rejected.
test "macro_press: case E — press conflicts with explicit up on same button" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { press = "RB" },
        \\    { up = "RB" },
        \\]
    ;
    try testing.expectError(error.PressConflict, mapping.parseString(allocator, src));
}

test "macro_press: case G — press conflicts with explicit down on same button" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { press = "RB" },
        \\    { down = "RB" },
        \\]
    ;
    try testing.expectError(error.PressConflict, mapping.parseString(allocator, src));
}

// F — backward compat: existing macros without press are byte-identical.
test "macro_press: case F — macro without press is byte-identical pre/post" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = [
        \\    { tap = "B" },
        \\    { delay = 50 },
        \\    { tap = "LEFT" },
        \\]
        \\
        \\[[macro]]
        \\name = "shift_hold"
        \\steps = [
        \\    { down = "KEY_LEFTSHIFT" },
        \\    "pause_for_release",
        \\    { up = "KEY_LEFTSHIFT" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const dodge = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 3), dodge.steps.len);
    try expectTap(dodge.steps[0], "B");
    try testing.expectEqual(@as(u32, 50), dodge.steps[1].delay);
    try expectTap(dodge.steps[2], "LEFT");

    const shift = result.value.macro.?[1];
    try testing.expectEqual(@as(usize, 3), shift.steps.len);
    try expectDown(shift.steps[0], "KEY_LEFTSHIFT");
    try expectPause(shift.steps[1]);
    try expectUp(shift.steps[2], "KEY_LEFTSHIFT");
}
