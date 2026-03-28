const std = @import("std");
const state = @import("state.zig");
const mapping = @import("../config/mapping.zig");

const c = @cImport({
    @cInclude("linux/input-event-codes.h");
});

const aux_event_mod = @import("aux_event.zig");
const AuxEvent = aux_event_mod.AuxEvent;
const AuxEventList = aux_event_mod.AuxEventList;
const ButtonId = state.ButtonId;
const DpadConfig = mapping.DpadConfig;

// Arrow key codes
const KEY_UP: u16 = c.KEY_UP;
const KEY_DOWN: u16 = c.KEY_DOWN;
const KEY_LEFT: u16 = c.KEY_LEFT;
const KEY_RIGHT: u16 = c.KEY_RIGHT;

/// Process DPad input.
///
/// gamepad mode: no-op; dpad values pass through unchanged.
///
/// arrows mode: edge-detect dpad_x/y vs prev values; inject KEY_UP/DOWN/LEFT/RIGHT
/// press/release into aux. When suppress_gamepad=true, suppresses DPad output:
///   - "buttons" type: sets DPadUp/Down/Left/Right bits in suppressed_buttons
///   - "hat" type: sets *suppress_dpad_hat = true (caller zeroes dpad_x/y in emit_state)
pub fn processDpad(
    dpad_x: i8,
    dpad_y: i8,
    prev_dpad_x: i8,
    prev_dpad_y: i8,
    cfg: *const DpadConfig,
    aux: *AuxEventList,
    suppressed_buttons: *u64,
    suppress_dpad_hat: *bool,
) void {
    if (!std.mem.eql(u8, cfg.mode, "arrows")) return;

    const up = dpad_y < 0;
    const down = dpad_y > 0;
    const left = dpad_x < 0;
    const right = dpad_x > 0;
    const prev_up = prev_dpad_y < 0;
    const prev_down = prev_dpad_y > 0;
    const prev_left = prev_dpad_x < 0;
    const prev_right = prev_dpad_x > 0;

    if (up != prev_up) aux.append(.{ .key = .{ .code = KEY_UP, .pressed = up } }) catch {};
    if (down != prev_down) aux.append(.{ .key = .{ .code = KEY_DOWN, .pressed = down } }) catch {};
    if (left != prev_left) aux.append(.{ .key = .{ .code = KEY_LEFT, .pressed = left } }) catch {};
    if (right != prev_right) aux.append(.{ .key = .{ .code = KEY_RIGHT, .pressed = right } }) catch {};

    if (cfg.suppress_gamepad orelse false) {
        // Suppress DPad buttons (buttons-type dpad)
        const up_idx: u6 = @intCast(@intFromEnum(ButtonId.DPadUp));
        const down_idx: u6 = @intCast(@intFromEnum(ButtonId.DPadDown));
        const left_idx: u6 = @intCast(@intFromEnum(ButtonId.DPadLeft));
        const right_idx: u6 = @intCast(@intFromEnum(ButtonId.DPadRight));
        suppressed_buttons.* |= (@as(u64, 1) << up_idx) | (@as(u64, 1) << down_idx) |
            (@as(u64, 1) << left_idx) | (@as(u64, 1) << right_idx);
        // Suppress hat-type dpad axes (caller zeroes dpad_x/y in emit_state)
        suppress_dpad_hat.* = true;
    }
}

// --- tests ---

const testing = std.testing;

fn makeCfg(mode: []const u8, suppress_gamepad: ?bool) DpadConfig {
    return .{ .mode = mode, .suppress_gamepad = suppress_gamepad };
}

test "dpad: gamepad mode: no aux events emitted" {
    const cfg = makeCfg("gamepad", null);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(0, -1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(usize, 0), aux.len);
    try testing.expectEqual(@as(u64, 0), suppressed);
    try testing.expect(!suppress_hat);
}

test "dpad: arrows mode: dpad_y < 0 -> KEY_UP press" {
    const cfg = makeCfg("arrows", null);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(0, -1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(usize, 1), aux.len);
    const ev = aux.get(0);
    try testing.expectEqual(KEY_UP, ev.key.code);
    try testing.expect(ev.key.pressed);
}

test "dpad: arrows mode: dpad from up to none -> KEY_UP release" {
    const cfg = makeCfg("arrows", null);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(0, 0, 0, -1, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(usize, 1), aux.len);
    const ev = aux.get(0);
    try testing.expectEqual(KEY_UP, ev.key.code);
    try testing.expect(!ev.key.pressed);
}

test "dpad: arrows mode: diagonal up+right -> two key presses" {
    const cfg = makeCfg("arrows", null);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(1, -1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(usize, 2), aux.len);
    // Both KEY_UP and KEY_RIGHT pressed
    var got_up = false;
    var got_right = false;
    for (aux.slice()) |ev| {
        if (ev.key.code == KEY_UP and ev.key.pressed) got_up = true;
        if (ev.key.code == KEY_RIGHT and ev.key.pressed) got_right = true;
    }
    try testing.expect(got_up);
    try testing.expect(got_right);
}

test "dpad: suppress_gamepad: DPad button bits suppressed" {
    const cfg = makeCfg("arrows", true);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(0, -1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
    const up_bit: u64 = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadUp)));
    try testing.expect((suppressed & up_bit) != 0);
    try testing.expect(suppress_hat);
}

test "dpad: suppress_gamepad=false: no button suppression" {
    const cfg = makeCfg("arrows", false);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    processDpad(0, -1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(u64, 0), suppressed);
    try testing.expect(!suppress_hat);
}

test "dpad: edge detection: same state produces no events" {
    const cfg = makeCfg("arrows", null);
    var aux = AuxEventList{};
    var suppressed: u64 = 0;
    var suppress_hat: bool = false;
    // Already in up state, still in up state — no change
    processDpad(0, -1, 0, -1, &cfg, &aux, &suppressed, &suppress_hat);
    try testing.expectEqual(@as(usize, 0), aux.len);
}

test "dpad: arrows mode: all four directions" {
    const cfg = makeCfg("arrows", null);

    // down
    {
        var aux = AuxEventList{};
        var suppressed: u64 = 0;
        var suppress_hat: bool = false;
        processDpad(0, 1, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
        try testing.expectEqual(@as(usize, 1), aux.len);
        try testing.expectEqual(KEY_DOWN, aux.get(0).key.code);
        try testing.expect(aux.get(0).key.pressed);
    }
    // left
    {
        var aux = AuxEventList{};
        var suppressed: u64 = 0;
        var suppress_hat: bool = false;
        processDpad(-1, 0, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
        try testing.expectEqual(@as(usize, 1), aux.len);
        try testing.expectEqual(KEY_LEFT, aux.get(0).key.code);
        try testing.expect(aux.get(0).key.pressed);
    }
    // right
    {
        var aux = AuxEventList{};
        var suppressed: u64 = 0;
        var suppress_hat: bool = false;
        processDpad(1, 0, 0, 0, &cfg, &aux, &suppressed, &suppress_hat);
        try testing.expectEqual(@as(usize, 1), aux.len);
        try testing.expectEqual(KEY_RIGHT, aux.get(0).key.code);
        try testing.expect(aux.get(0).key.pressed);
    }
}
