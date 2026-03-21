const std = @import("std");
const state = @import("state.zig");
const mapping = @import("../config/mapping.zig");
const input_codes = @import("../config/input_codes.zig");

const ButtonId = state.ButtonId;
const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;

pub const RemapTargetResolved = union(enum) {
    key: u16,
    mouse_button: u16,
    gamepad_button: ButtonId,
    disabled: void,
    macro: []const u8,
};

pub const RemapRule = struct {
    source: ButtonId,
    target: RemapTargetResolved,
};

pub const AuxEvent = @import("../io/uinput.zig").AuxEvent;
pub const AuxEventList = @import("mapper.zig").AuxEventList;

pub const Remap = struct {
    rules: []const RemapRule,
    allocator: std.mem.Allocator,

    pub fn init(cfg: *const mapping.MappingConfig, allocator: std.mem.Allocator) !Remap {
        const remap_map = cfg.remap orelse return Remap{ .rules = &.{}, .allocator = allocator };

        var list = std.ArrayList(RemapRule){};
        errdefer list.deinit(allocator);

        var it = remap_map.map.iterator();
        while (it.next()) |entry| {
            const src_id = std.meta.stringToEnum(ButtonId, entry.key_ptr.*) orelse
                return error.UnknownButton;
            const target = try resolveTarget(entry.value_ptr.*);
            try list.append(allocator, .{ .source = src_id, .target = target });
        }

        return Remap{ .rules = try list.toOwnedSlice(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Remap) void {
        self.allocator.free(self.rules);
    }

    // Collect all key/mouse_button codes needed for AuxDevice capability inference.
    pub fn collectAuxCodes(self: *const Remap, out: *std.ArrayList(u16)) !void {
        for (self.rules) |rule| {
            switch (rule.target) {
                .key, .mouse_button => |code| try out.append(code),
                else => {},
            }
        }
    }

    pub fn apply(self: *const Remap, gs: *state.GamepadState, aux: *AuxEventList) void {
        for (self.rules) |rule| {
            const idx: u5 = @intCast(@intFromEnum(rule.source));
            const mask: u32 = @as(u32, 1) << idx;
            const pressed = (gs.buttons & mask) != 0;

            // Suppress source regardless of state
            gs.buttons &= ~mask;

            switch (rule.target) {
                .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = pressed } }) catch {},
                .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = pressed } }) catch {},
                .gamepad_button => |dst| {
                    if (pressed) {
                        const dst_idx: u5 = @intCast(@intFromEnum(dst));
                        gs.buttons |= @as(u32, 1) << dst_idx;
                    }
                    // released: target bit stays cleared (suppressed above, not re-set)
                },
                .disabled => {},
                .macro => {},  // handled by MacroPlayer (T4)
            }
        }
    }
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

const testing = std.testing;

fn makeMapping(toml_str: []const u8, allocator: std.mem.Allocator) !mapping.ParseResult {
    return mapping.parseString(allocator, toml_str);
}

test "remap disabled: source button suppressed" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\M2 = "disabled"
    , allocator);
    defer parsed.deinit();

    var remap = try Remap.init(&parsed.value, allocator);
    defer remap.deinit();

    var gs = state.GamepadState{};
    // Set M2 bit
    const m2_idx: u5 = @intCast(@intFromEnum(ButtonId.M2));
    gs.buttons |= @as(u32, 1) << m2_idx;

    var aux = AuxEventList{};
    remap.apply(&gs, &aux);

    try testing.expectEqual(@as(u32, 0), gs.buttons & (@as(u32, 1) << m2_idx));
    try testing.expectEqual(@as(usize, 0), aux.len);
}

test "remap key: source -> KEY_F13 aux event" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\M1 = "KEY_F13"
    , allocator);
    defer parsed.deinit();

    var remap = try Remap.init(&parsed.value, allocator);
    defer remap.deinit();

    var gs = state.GamepadState{};
    const m1_idx: u5 = @intCast(@intFromEnum(ButtonId.M1));
    gs.buttons |= @as(u32, 1) << m1_idx;

    var aux = AuxEventList{};
    remap.apply(&gs, &aux);

    // Source suppressed
    try testing.expectEqual(@as(u32, 0), gs.buttons & (@as(u32, 1) << m1_idx));
    // Aux event generated
    try testing.expectEqual(@as(usize, 1), aux.len);
    const ev = aux.get(0);
    switch (ev) {
        .key => |k| {
            // KEY_F13 = 0xd3 = 211
            try testing.expectEqual(@as(u16, 183), k.code); // KEY_F13 Linux value
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "remap gamepad_button: A -> B" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
    , allocator);
    defer parsed.deinit();

    var remap = try Remap.init(&parsed.value, allocator);
    defer remap.deinit();

    var gs = state.GamepadState{};
    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    gs.buttons |= @as(u32, 1) << a_idx;

    var aux = AuxEventList{};
    remap.apply(&gs, &aux);

    // A suppressed
    try testing.expectEqual(@as(u32, 0), gs.buttons & (@as(u32, 1) << a_idx));
    // B injected
    try testing.expect((gs.buttons & (@as(u32, 1) << b_idx)) != 0);
    try testing.expectEqual(@as(usize, 0), aux.len);
}

test "no remap: state unchanged" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var remap = try Remap.init(&parsed.value, allocator);
    defer remap.deinit();

    var gs = state.GamepadState{};
    gs.buttons = 0b1010;

    var aux = AuxEventList{};
    remap.apply(&gs, &aux);

    try testing.expectEqual(@as(u32, 0b1010), gs.buttons);
    try testing.expectEqual(@as(usize, 0), aux.len);
}

test "resolveTarget: macro:dodge_roll -> RemapTargetResolved.macro" {
    const target = try resolveTarget("macro:dodge_roll");
    try testing.expectEqualStrings("dodge_roll", target.macro);
}

test "remap macro:name: source suppressed, no aux event" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = []
        \\
        \\[remap]
        \\M1 = "macro:dodge_roll"
    , allocator);
    defer parsed.deinit();

    var remap_inst = try Remap.init(&parsed.value, allocator);
    defer remap_inst.deinit();

    try testing.expectEqual(@as(usize, 1), remap_inst.rules.len);
    try testing.expectEqualStrings("dodge_roll", remap_inst.rules[0].target.macro);

    var gs = state.GamepadState{};
    const m1_idx: u5 = @intCast(@intFromEnum(ButtonId.M1));
    gs.buttons |= @as(u32, 1) << m1_idx;

    var aux = AuxEventList{};
    remap_inst.apply(&gs, &aux);

    try testing.expectEqual(@as(u32, 0), gs.buttons & (@as(u32, 1) << m1_idx));
    try testing.expectEqual(@as(usize, 0), aux.len);
}
