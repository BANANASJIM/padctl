// Parse-time AST rewrite: implicit `delay` steps between adjacent emitting
// macro steps. Driven by `macro_step_delay` (global) and `[[macro]].step_delay`
// (per-macro override). See `docs/src/mapping-config.md` — "Implicit step delays".

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
fn expectDelay(step: MacroStep, want: u32) !void {
    try testing.expectEqual(want, step.delay);
}
fn expectPause(step: MacroStep) !void {
    _ = step.pause_for_release;
}

test "macro_step_delay: case A — step_delay = 0 produces identity transform" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\step_delay = 0
        \\steps = [
        \\    { tap = "B" },
        \\    { tap = "A" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 2), m.steps.len);
    try expectTap(m.steps[0], "B");
    try expectTap(m.steps[1], "A");
}

test "macro_step_delay: case B — step_delay = 50 inserts between emitting steps" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\step_delay = 50
        \\steps = [
        \\    { down = "RB" },
        \\    { down = "X" },
        \\    { up = "X" },
        \\    { up = "RB" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 7), m.steps.len);
    try expectDown(m.steps[0], "RB");
    try expectDelay(m.steps[1], 50);
    try expectDown(m.steps[2], "X");
    try expectDelay(m.steps[3], 50);
    try expectUp(m.steps[4], "X");
    try expectDelay(m.steps[5], 50);
    try expectUp(m.steps[6], "RB");
}

test "macro_step_delay: case C — explicit delay suppresses adjacent auto-insertion" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\step_delay = 50
        \\steps = [
        \\    { tap = "B" },
        \\    { delay = 200 },
        \\    { tap = "A" },
        \\    { tap = "C" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    // tap B, explicit delay 200, tap A, auto delay 50, tap C → 5 entries
    try testing.expectEqual(@as(usize, 5), m.steps.len);
    try expectTap(m.steps[0], "B");
    try expectDelay(m.steps[1], 200);
    try expectTap(m.steps[2], "A");
    try expectDelay(m.steps[3], 50);
    try expectTap(m.steps[4], "C");
}

test "macro_step_delay: case D — pause_for_release blocks adjacent auto-insertion" {
    const allocator = testing.allocator;
    const src =
        \\[[macro]]
        \\name = "m"
        \\step_delay = 50
        \\steps = [
        \\    { down = "X" },
        \\    "pause_for_release",
        \\    { up = "X" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 3), m.steps.len);
    try expectDown(m.steps[0], "X");
    try expectPause(m.steps[1]);
    try expectUp(m.steps[2], "X");
}

test "macro_step_delay: case E — global default applies when per-macro unset" {
    const allocator = testing.allocator;
    const src =
        \\macro_step_delay = 30
        \\
        \\[[macro]]
        \\name = "m"
        \\steps = [
        \\    { tap = "B" },
        \\    { tap = "A" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    try testing.expectEqual(@as(?u32, 30), result.value.macro_step_delay);
    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 3), m.steps.len);
    try expectTap(m.steps[0], "B");
    try expectDelay(m.steps[1], 30);
    try expectTap(m.steps[2], "A");
}

test "macro_step_delay: case F — per-macro step_delay = 0 wins over global" {
    const allocator = testing.allocator;
    const src =
        \\macro_step_delay = 30
        \\
        \\[[macro]]
        \\name = "m"
        \\step_delay = 0
        \\steps = [
        \\    { tap = "B" },
        \\    { tap = "A" },
        \\]
    ;
    const result = try mapping.parseString(allocator, src);
    defer result.deinit();

    const m = result.value.macro.?[0];
    try testing.expectEqual(@as(usize, 2), m.steps.len);
    try expectTap(m.steps[0], "B");
    try expectTap(m.steps[1], "A");
}

test "macro_step_delay: case G — neither field set is byte-identical to pre-fix" {
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

    try testing.expectEqual(@as(?u32, null), result.value.macro_step_delay);

    const dodge = result.value.macro.?[0];
    try testing.expectEqual(@as(?u32, null), dodge.step_delay);
    try testing.expectEqual(@as(usize, 3), dodge.steps.len);
    try expectTap(dodge.steps[0], "B");
    try expectDelay(dodge.steps[1], 50);
    try expectTap(dodge.steps[2], "LEFT");

    const shift = result.value.macro.?[1];
    try testing.expectEqual(@as(?u32, null), shift.step_delay);
    try testing.expectEqual(@as(usize, 3), shift.steps.len);
    try expectDown(shift.steps[0], "KEY_LEFTSHIFT");
    try expectPause(shift.steps[1]);
    try expectUp(shift.steps[2], "KEY_LEFTSHIFT");
}
