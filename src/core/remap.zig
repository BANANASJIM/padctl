const std = @import("std");
const state = @import("state.zig");
const input_codes = @import("../config/input_codes.zig");

const ButtonId = state.ButtonId;

pub const RemapTargetResolved = union(enum) {
    key: u16,
    mouse_button: u16,
    gamepad_button: ButtonId,
    disabled: void,
    macro: []const u8,
};

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

test "resolveTarget: macro:dodge_roll -> RemapTargetResolved.macro" {
    const target = try resolveTarget("macro:dodge_roll");
    try std.testing.expectEqualStrings("dodge_roll", target.macro);
}
