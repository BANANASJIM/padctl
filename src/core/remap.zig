const std = @import("std");
const state = @import("state.zig");
const input_codes = @import("../config/input_codes.zig");
const aux_event_mod = @import("aux_event.zig");

const ButtonId = state.ButtonId;
const AuxEventList = aux_event_mod.AuxEventList;

pub const RemapTargetResolved = union(enum) {
    key: u16,
    mouse_button: u16,
    gamepad_button: ButtonId,
    disabled: void,
    macro: []const u8,
    // Chord output: 2..=4 evdev key codes (issue #206). Codes are owned by the
    // Mapper allocator (allocated in precomputeRemap, freed in Mapper.deinit).
    // Dispatch implementation lands in PR B-2.
    chord: []const u16,
};

pub const TargetAction = enum { press, release, tap };

/// Dispatch a resolved remap target into aux events and injected-button state.
/// `.disabled` and `.macro` are no-ops — callers that need macro-queue side
/// effects must handle them before calling this.
/// `pending_tap_release` is required when action == .tap and target is .gamepad_button.
/// `held_gamepad` is optional; MacroPlayer uses it to track bits for emitPendingReleases.
pub fn applyTarget(
    target: RemapTargetResolved,
    action: TargetAction,
    aux: *AuxEventList,
    injected_buttons: *u64,
    pending_tap_release: ?*u64,
    held_gamepad: ?*u64,
) void {
    switch (target) {
        .key => |code| switch (action) {
            .press => aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {},
            .release => aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {},
            .tap => {
                aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {};
                aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
            },
        },
        .mouse_button => |code| switch (action) {
            .press => aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch {},
            .release => aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {},
            .tap => {
                aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch {};
                aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {};
            },
        },
        .gamepad_button => |dst| {
            const mask = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(dst)));
            switch (action) {
                .press => {
                    injected_buttons.* |= mask;
                    if (held_gamepad) |h| h.* |= mask;
                },
                .release => {
                    injected_buttons.* &= ~mask;
                    if (held_gamepad) |h| h.* &= ~mask;
                },
                .tap => {
                    injected_buttons.* |= mask;
                    if (pending_tap_release) |ptr| ptr.* |= mask;
                },
            }
        },
        // chord dispatch lands in PR B-2 (issue #206)
        .disabled, .macro, .chord => {},
    }
}

pub const CHORD_MIN_KEYS: usize = 2;
pub const CHORD_MAX_KEYS: usize = 4;

/// Resolve an array remap target like `["KEY_LEFTMETA", "KEY_1"]` into a
/// `.chord` variant. Caller owns the returned `chord` slice.
pub fn resolveChordTarget(allocator: std.mem.Allocator, names: []const []const u8) !RemapTargetResolved {
    if (names.len < CHORD_MIN_KEYS) return error.ChordTooShort;
    if (names.len > CHORD_MAX_KEYS) return error.ChordTooLong;

    const codes = try allocator.alloc(u16, names.len);
    errdefer allocator.free(codes);

    for (names, 0..) |name, i| {
        const code = try input_codes.resolveKeyCode(name);
        for (codes[0..i]) |prior| {
            if (prior == code) return error.DuplicateChordKey;
        }
        codes[i] = code;
    }
    return .{ .chord = codes };
}

pub fn resolveTarget(raw: []const u8) !RemapTargetResolved {
    if (std.mem.eql(u8, raw, "disabled")) return .disabled;

    if (std.mem.startsWith(u8, raw, "macro:")) {
        return .{ .macro = raw["macro:".len..] };
    }

    // mouse_* shorthand
    if (std.mem.startsWith(u8, raw, "mouse_")) {
        const code = try input_codes.resolveMouseCode(raw);
        return .{ .mouse_button = code };
    }

    // KEY_* keyboard code
    if (std.mem.startsWith(u8, raw, "KEY_")) {
        const code = try input_codes.resolveKeyCode(raw);
        return .{ .key = code };
    }

    // BTN_* maps to mouse_button (gamepad BTN_* names are handled by ButtonId)
    if (std.mem.startsWith(u8, raw, "BTN_")) {
        const code = input_codes.resolveBtnCode(raw) catch return error.UnknownRemapTarget;
        return .{ .mouse_button = code };
    }

    // Gamepad button name
    if (std.meta.stringToEnum(ButtonId, raw)) |btn| {
        return .{ .gamepad_button = btn };
    }

    return error.UnknownRemapTarget;
}

// --- tests ---

test "remap: resolveTarget: macro:dodge_roll -> RemapTargetResolved.macro" {
    const target = try resolveTarget("macro:dodge_roll");
    try std.testing.expectEqualStrings("dodge_roll", target.macro);
}

test "remap: resolveTarget: KEY_F13 -> key 183" {
    const target = try resolveTarget("KEY_F13");
    try std.testing.expectEqual(@as(u16, 183), target.key);
}

test "remap: resolveTarget: BTN_LEFT -> mouse_button 0x110" {
    const target = try resolveTarget("BTN_LEFT");
    try std.testing.expectEqual(@as(u16, 0x110), target.mouse_button);
}

test "remap: resolveTarget: mouse_left -> mouse_button 0x110" {
    const target = try resolveTarget("mouse_left");
    try std.testing.expectEqual(@as(u16, 0x110), target.mouse_button);
}

test "remap: resolveTarget: A -> gamepad_button .A" {
    const target = try resolveTarget("A");
    try std.testing.expectEqual(ButtonId.A, target.gamepad_button);
}

test "remap: resolveTarget: B -> gamepad_button .B" {
    const target = try resolveTarget("B");
    try std.testing.expectEqual(ButtonId.B, target.gamepad_button);
}

test "remap: resolveTarget: disabled -> .disabled" {
    const target = try resolveTarget("disabled");
    try std.testing.expectEqual(RemapTargetResolved.disabled, target);
}

test "remap: resolveTarget: unknown string -> error.UnknownRemapTarget" {
    try std.testing.expectError(error.UnknownRemapTarget, resolveTarget("unknown_garbage"));
}

test "remap: resolveChordTarget: 2-key chord resolves" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{ "KEY_LEFTMETA", "KEY_1" };
    const target = try resolveChordTarget(allocator, &names);
    defer allocator.free(target.chord);
    try std.testing.expectEqual(@as(usize, 2), target.chord.len);
    try std.testing.expectEqual(try input_codes.resolveKeyCode("KEY_LEFTMETA"), target.chord[0]);
    try std.testing.expectEqual(try input_codes.resolveKeyCode("KEY_1"), target.chord[1]);
}

test "remap: resolveChordTarget: 3-key chord preserves declaration order" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{ "KEY_LEFTCTRL", "KEY_LEFTSHIFT", "KEY_S" };
    const target = try resolveChordTarget(allocator, &names);
    defer allocator.free(target.chord);
    try std.testing.expectEqual(@as(usize, 3), target.chord.len);
    try std.testing.expectEqual(try input_codes.resolveKeyCode("KEY_LEFTCTRL"), target.chord[0]);
    try std.testing.expectEqual(try input_codes.resolveKeyCode("KEY_LEFTSHIFT"), target.chord[1]);
    try std.testing.expectEqual(try input_codes.resolveKeyCode("KEY_S"), target.chord[2]);
}

test "remap: resolveChordTarget: 1-key array -> ChordTooShort" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{"KEY_A"};
    try std.testing.expectError(error.ChordTooShort, resolveChordTarget(allocator, &names));
}

test "remap: resolveChordTarget: 5-key array -> ChordTooLong" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{ "KEY_A", "KEY_B", "KEY_C", "KEY_D", "KEY_E" };
    try std.testing.expectError(error.ChordTooLong, resolveChordTarget(allocator, &names));
}

test "remap: resolveChordTarget: duplicate keys -> DuplicateChordKey" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{ "KEY_A", "KEY_A" };
    try std.testing.expectError(error.DuplicateChordKey, resolveChordTarget(allocator, &names));
}

test "remap: resolveChordTarget: unknown key code propagates resolveKeyCode error" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{ "KEY_NOT_REAL", "KEY_1" };
    try std.testing.expectError(error.UnknownKeyCode, resolveChordTarget(allocator, &names));
}
