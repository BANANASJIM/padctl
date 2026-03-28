const std = @import("std");

pub const MacroStep = union(enum) {
    tap: []const u8,
    down: []const u8,
    up: []const u8,
    delay: u32,
    pause_for_release: void,
};

pub const Macro = struct {
    name: []const u8,
    steps: []const MacroStep,
};

// --- tests ---

const testing = std.testing;

test "macro: MacroStep variants" {
    const tap: MacroStep = .{ .tap = "B" };
    const down: MacroStep = .{ .down = "A" };
    const up: MacroStep = .{ .up = "KEY_LEFTSHIFT" };
    const delay: MacroStep = .{ .delay = 50 };
    const pause: MacroStep = .pause_for_release;

    try testing.expectEqualStrings("B", tap.tap);
    try testing.expectEqualStrings("A", down.down);
    try testing.expectEqualStrings("KEY_LEFTSHIFT", up.up);
    try testing.expectEqual(@as(u32, 50), delay.delay);
    _ = pause;
}

test "macro: empty steps is valid" {
    const m = Macro{ .name = "noop", .steps = &.{} };
    try testing.expectEqualStrings("noop", m.name);
    try testing.expectEqual(@as(usize, 0), m.steps.len);
}
