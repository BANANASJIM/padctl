const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const interpreter_mod = @import("../core/interpreter.zig");
const state_mod = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const helpers = @import("helpers.zig");

const c = @cImport({
    @cInclude("linux/input.h");
    @cInclude("linux/input-event-codes.h");
});

const Interpreter = interpreter_mod.Interpreter;
const GamepadState = state_mod.GamepadState;
const GamepadStateDelta = state_mod.GamepadStateDelta;
const ButtonId = state_mod.ButtonId;

fn btn(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

fn dpadMask() u64 {
    return btn(.DPadUp) | btn(.DPadDown) | btn(.DPadLeft) | btn(.DPadRight);
}

/// HID hat switch: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, >=8 neutral.
fn expectedDpadBits(hat: u8) u64 {
    return switch (hat) {
        0 => btn(.DPadUp),
        1 => btn(.DPadUp) | btn(.DPadRight),
        2 => btn(.DPadRight),
        3 => btn(.DPadDown) | btn(.DPadRight),
        4 => btn(.DPadDown),
        5 => btn(.DPadDown) | btn(.DPadLeft),
        6 => btn(.DPadLeft),
        7 => btn(.DPadUp) | btn(.DPadLeft),
        else => 0,
    };
}

fn expectedDx(hat: u8) i8 {
    const bits = expectedDpadBits(hat);
    const right: i8 = if (bits & btn(.DPadRight) != 0) 1 else 0;
    const left: i8 = if (bits & btn(.DPadLeft) != 0) 1 else 0;
    return right - left;
}

fn expectedDy(hat: u8) i8 {
    const bits = expectedDpadBits(hat);
    const down: i8 = if (bits & btn(.DPadDown) != 0) 1 else 0;
    const up: i8 = if (bits & btn(.DPadUp) != 0) 1 else 0;
    return down - up;
}

// The two declaration forms a device can use for its dpad: a HID hat enum
// field, or four button_group bits. Every behavioural test below runs against
// both so the engine cannot treat them differently.
const Form = enum { hat, bits };

/// The `[output.dpad] type` a test declares: `hat` emits ABS_HAT0X/Y, `buttons`
/// emits BTN_DPAD_* key events.
const OutputForm = enum { hat, buttons };

const hat_device_toml =
    \\[device]
    \\name = "Hat Pad"
    \\vid = 0x1234
    \\pid = 0x5678
    \\
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 4
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\
    \\[report.fields]
    \\dpad = { offset = 1, type = "u8" }
    \\
    \\[report.button_group]
    \\source = { offset = 2, size = 1 }
    \\map = { A = 0, LT = 1 }
    \\
;

const bits_device_toml =
    \\[device]
    \\name = "Bits Pad"
    \\vid = 0x1234
    \\pid = 0x5679
    \\
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 4
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\
    \\[report.button_group]
    \\source = { offset = 1, size = 1 }
    \\map = { DPadUp = 0, DPadDown = 1, DPadLeft = 2, DPadRight = 3, A = 4, LT = 5 }
    \\
;

const output_hat_toml =
    \\[output]
    \\name = "Virtual Pad"
    \\vid = 0x045e
    \\pid = 0x028e
    \\
    \\[output.dpad]
    \\type = "hat"
    \\
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\
;

const output_buttons_toml =
    \\[output]
    \\name = "Virtual Pad"
    \\vid = 0x045e
    \\pid = 0x028e
    \\
    \\[output.dpad]
    \\type = "buttons"
    \\
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\DPadUp = "BTN_DPAD_UP"
    \\DPadDown = "BTN_DPAD_DOWN"
    \\DPadLeft = "BTN_DPAD_LEFT"
    \\DPadRight = "BTN_DPAD_RIGHT"
    \\
;

fn outputToml(out_form: OutputForm) []const u8 {
    return switch (out_form) {
        .hat => output_hat_toml,
        .buttons => output_buttons_toml,
    };
}

fn deviceToml(allocator: std.mem.Allocator, form: Form, output: []const u8) ![]u8 {
    const base = switch (form) {
        .hat => hat_device_toml,
        .bits => bits_device_toml,
    };
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output });
}

/// Encode one input report carrying `hat` plus the optional A / LT buttons, in
/// whichever form the device declares.
fn buildReport(form: Form, hat: u8, a: bool, lt: bool) [4]u8 {
    var raw = [_]u8{ 0x01, 0, 0, 0 };
    switch (form) {
        .hat => {
            raw[1] = hat;
            if (a) raw[2] |= 1 << 0;
            if (lt) raw[2] |= 1 << 1;
        },
        .bits => {
            const bits = expectedDpadBits(hat);
            if (bits & btn(.DPadUp) != 0) raw[1] |= 1 << 0;
            if (bits & btn(.DPadDown) != 0) raw[1] |= 1 << 1;
            if (bits & btn(.DPadLeft) != 0) raw[1] |= 1 << 2;
            if (bits & btn(.DPadRight) != 0) raw[1] |= 1 << 3;
            if (a) raw[1] |= 1 << 4;
            if (lt) raw[1] |= 1 << 5;
        },
    }
    return raw;
}

const KeyEvent = struct { code: u16, pressed: bool };

fn collectKeys(aux: anytype, out: *std.ArrayList(KeyEvent), allocator: std.mem.Allocator) !void {
    for (aux.slice()) |e| switch (e) {
        .key => |k| try out.append(allocator, .{ .code = k.code, .pressed = k.pressed }),
        else => {},
    };
}

// --- interpreter: hat enum decodes into DPad* button bits ---

test "dpad hat: interpreter decodes every hat value into DPad button bits" {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, .hat, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    for (0..16) |i| {
        const hat: u8 = @intCast(i);
        const raw = buildReport(.hat, hat, false, false);
        const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
        const buttons = delta.buttons orelse return error.NoButtons;
        try testing.expectEqual(expectedDpadBits(hat), buttons & dpadMask());
    }
}

test "dpad hat: a report carrying only a hat field still yields button bits" {
    const allocator = testing.allocator;
    const toml =
        \\[device]
        \\name = "Hat Only"
        \\vid = 0x1234
        \\pid = 0x5680
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "input"
        \\interface = 0
        \\size = 4
        \\
        \\[report.fields]
        \\dpad = { offset = 1, type = "u8" }
    ;
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var raw = [_]u8{ 0, 6, 0, 0 };
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const buttons = delta.buttons orelse return error.NoButtons;
    try testing.expectEqual(btn(.DPadLeft), buttons & dpadMask());
}

test "dpad hat: bits-mode hat field decodes identically to offset mode" {
    const allocator = testing.allocator;
    const toml =
        \\[device]
        \\name = "Hat Nibble"
        \\vid = 0x1234
        \\pid = 0x5681
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "input"
        \\interface = 0
        \\size = 4
        \\
        \\[report.fields]
        \\dpad = { bits = [1, 4, 4] }
    ;
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    for (0..16) |i| {
        const hat: u8 = @intCast(i);
        var raw = [_]u8{ 0, hat << 4, 0, 0 };
        const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
        const buttons = delta.buttons orelse return error.NoButtons;
        try testing.expectEqual(expectedDpadBits(hat), buttons & dpadMask());
    }
}

/// Push one emitted state through the real uinput backend over a pipe, with
/// `[output]` resolved the way `UinputDevice.create` resolves it for a live
/// node. Every call starts from a fresh device, so the events describe the
/// whole non-neutral state rather than a diff against an earlier frame.
fn emitOnce(out_cfg: *const device_mod.OutputConfig, s: GamepadState, out: []c.input_event) !usize {
    const pfds = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(pfds[0]);
    defer std.posix.close(pfds[1]);

    var dev = uinput.UinputDevice{
        .fd = pfds[1],
        .button_codes = try uinput.resolveButtonCodes(out_cfg),
        .has_dpad_hat = uinput.dpadIsHat(out_cfg),
    };
    try dev.emit(s);

    const bytes = std.posix.read(pfds[0], std.mem.sliceAsBytes(out)) catch return 0;
    return bytes / @sizeOf(c.input_event);
}

fn eventValue(evs: []const c.input_event, ev_type: u16, code: u16) ?i32 {
    for (evs) |e| {
        if (e.type == ev_type and e.code == code) return e.value;
    }
    return null;
}

/// The wire events must carry the d-pad in the form `[output.dpad]` declares:
/// ABS_HAT0X/Y for `type = "hat"`, BTN_DPAD_* key presses for `type = "buttons"`,
/// and nothing of the other form. `out_form` is what the test declared, so the
/// expectation never moves with the code that resolves the declaration.
fn expectDpadOutput(out_form: OutputForm, hat: u8, evs: []const c.input_event) !void {
    const hat_form = out_form == .hat;
    const bits = expectedDpadBits(hat);

    const want_x: ?i32 = if (hat_form and expectedDx(hat) != 0) expectedDx(hat) else null;
    const want_y: ?i32 = if (hat_form and expectedDy(hat) != 0) expectedDy(hat) else null;
    try testing.expectEqual(want_x, eventValue(evs, c.EV_ABS, c.ABS_HAT0X));
    try testing.expectEqual(want_y, eventValue(evs, c.EV_ABS, c.ABS_HAT0Y));

    const dpad_keys = [_]struct { id: ButtonId, code: u16 }{
        .{ .id = .DPadUp, .code = c.BTN_DPAD_UP },
        .{ .id = .DPadDown, .code = c.BTN_DPAD_DOWN },
        .{ .id = .DPadLeft, .code = c.BTN_DPAD_LEFT },
        .{ .id = .DPadRight, .code = c.BTN_DPAD_RIGHT },
    };
    for (dpad_keys) |k| {
        const want: ?i32 = if (!hat_form and bits & btn(k.id) != 0) 1 else null;
        try testing.expectEqual(want, eventValue(evs, c.EV_KEY, k.code));
    }
}

// --- mapper path and no-mapper path, for both output.dpad types ---

fn runMapperPath(form: Form, out_form: OutputForm, mapping_toml: []const u8) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, outputToml(out_form));
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try helpers.makeMapper(mapping_toml, allocator);
    defer ctx.deinit();

    const out_cfg = parsed.value.output orelse return error.NoOutput;

    for (0..16) |i| {
        const hat: u8 = @intCast(i);
        const raw = buildReport(form, hat, false, false);
        const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
        const ev = try ctx.mapper.apply(delta, 16, 0);
        try testing.expectEqual(expectedDx(hat), ev.gamepad.dpad_x);
        try testing.expectEqual(expectedDy(hat), ev.gamepad.dpad_y);
        try testing.expectEqual(expectedDpadBits(hat), ev.gamepad.buttons & dpadMask());

        var evs: [16]c.input_event = undefined;
        const n = try emitOnce(&out_cfg, ev.gamepad, &evs);
        try expectDpadOutput(out_form, hat, evs[0..n]);
    }
}

fn runNoMapperPath(form: Form, out_form: OutputForm) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, outputToml(out_form));
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const out_cfg = parsed.value.output orelse return error.NoOutput;

    // Mirrors the mapper-less branch of the event loop: accumulate the delta,
    // then derive the hat axes before emitting.
    var gs = GamepadState{};
    for (0..16) |i| {
        const hat: u8 = @intCast(i);
        const raw = buildReport(form, hat, false, false);
        const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
        gs.applyDelta(delta);
        gs.synthesizeDpadAxes();
        try testing.expectEqual(expectedDx(hat), gs.dpad_x);
        try testing.expectEqual(expectedDy(hat), gs.dpad_y);
        try testing.expectEqual(expectedDpadBits(hat), gs.buttons & dpadMask());

        var evs: [16]c.input_event = undefined;
        const n = try emitOnce(&out_cfg, gs, &evs);
        try expectDpadOutput(out_form, hat, evs[0..n]);
    }
}

test "dpad hat: mapper path, output.dpad.type = hat" {
    try runMapperPath(.hat, .hat, "");
}

test "dpad hat: mapper path, output.dpad.type = buttons" {
    try runMapperPath(.hat, .buttons, "");
}

test "dpad hat: no-mapper path, output.dpad.type = hat" {
    try runNoMapperPath(.hat, .hat);
}

test "dpad hat: no-mapper path, output.dpad.type = buttons" {
    try runNoMapperPath(.hat, .buttons);
}

test "dpad bits: mapper path and no-mapper path, both output types" {
    try runMapperPath(.bits, .hat, "");
    try runMapperPath(.bits, .buttons, "");
    try runNoMapperPath(.bits, .hat);
    try runNoMapperPath(.bits, .buttons);
}

// --- remap / layer / arrows / suppress_gamepad parity across input forms ---

fn runRemap(form: Form) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try helpers.makeMapper(
        \\[remap]
        \\DPadUp = "A"
    , allocator);
    defer ctx.deinit();

    const raw = buildReport(form, 0, false, false);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const ev = try ctx.mapper.apply(delta, 16, 0);

    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btn(.DPadUp));
    try testing.expect(ev.gamepad.buttons & btn(.A) != 0);
    try testing.expectEqual(@as(i8, 0), ev.gamepad.dpad_y);
}

test "dpad: remap of DPadUp applies to hat input" {
    try runRemap(.hat);
}

test "dpad: remap of DPadUp applies to button-bit input" {
    try runRemap(.bits);
}

fn runArrows(form: Form, mapping_toml: []const u8) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try helpers.makeMapper(mapping_toml, allocator);
    defer ctx.deinit();

    var keys: std.ArrayList(KeyEvent) = .{};
    defer keys.deinit(allocator);

    // hat 0 (up) → KEY_UP press
    const up_raw = buildReport(form, 0, false, false);
    const up_delta = (try interp.processReport(0, &up_raw)) orelse return error.NoMatch;
    const up_ev = try ctx.mapper.apply(up_delta, 16, 0);
    try collectKeys(up_ev.aux, &keys, allocator);
    try testing.expectEqual(@as(usize, 1), keys.items.len);
    try testing.expectEqual(helpers.KEY_UP, keys.items[0].code);
    try testing.expect(keys.items[0].pressed);

    // hat 8 (neutral) → KEY_UP release
    keys.clearRetainingCapacity();
    const rel_raw = buildReport(form, 8, false, false);
    const rel_delta = (try interp.processReport(0, &rel_raw)) orelse return error.NoMatch;
    const rel_ev = try ctx.mapper.apply(rel_delta, 16, 0);
    try collectKeys(rel_ev.aux, &keys, allocator);
    try testing.expectEqual(@as(usize, 1), keys.items.len);
    try testing.expectEqual(helpers.KEY_UP, keys.items[0].code);
    try testing.expect(!keys.items[0].pressed);

    // hat 1 (up-right) → two presses
    keys.clearRetainingCapacity();
    const diag_raw = buildReport(form, 1, false, false);
    const diag_delta = (try interp.processReport(0, &diag_raw)) orelse return error.NoMatch;
    const diag_ev = try ctx.mapper.apply(diag_delta, 16, 0);
    try collectKeys(diag_ev.aux, &keys, allocator);
    try testing.expectEqual(@as(usize, 2), keys.items.len);
    var got_up = false;
    var got_right = false;
    for (keys.items) |k| {
        if (k.code == helpers.KEY_UP and k.pressed) got_up = true;
        if (k.code == helpers.KEY_RIGHT and k.pressed) got_right = true;
    }
    try testing.expect(got_up);
    try testing.expect(got_right);
}

const arrows_mapping =
    \\[dpad]
    \\mode = "arrows"
;

const arrows_suppress_mapping =
    \\[dpad]
    \\mode = "arrows"
    \\suppress_gamepad = true
;

test "dpad: arrows mode emits KEY events for hat input" {
    try runArrows(.hat, arrows_mapping);
}

test "dpad: arrows mode emits KEY events for button-bit input" {
    try runArrows(.bits, arrows_mapping);
}

test "dpad: arrows mode with suppress_gamepad emits KEY events for hat input" {
    try runArrows(.hat, arrows_suppress_mapping);
}

test "dpad: arrows mode with suppress_gamepad emits KEY events for button-bit input" {
    try runArrows(.bits, arrows_suppress_mapping);
}

fn runSuppress(form: Form) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try helpers.makeMapper(arrows_suppress_mapping, allocator);
    defer ctx.deinit();

    const raw = buildReport(form, 0, false, false);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const ev = try ctx.mapper.apply(delta, 16, 0);

    try testing.expectEqual(@as(i8, 0), ev.gamepad.dpad_x);
    try testing.expectEqual(@as(i8, 0), ev.gamepad.dpad_y);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & dpadMask());
}

test "dpad: suppress_gamepad removes both hat axes and DPad bits for hat input" {
    try runSuppress(.hat);
}

test "dpad: suppress_gamepad removes both hat axes and DPad bits for button-bit input" {
    try runSuppress(.bits);
}

fn runLayerArrows(form: Form) !void {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, form, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try helpers.makeMapper(
        \\[[layer]]
        \\name = "nav"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    , allocator);
    defer ctx.deinit();

    // Hold LT past the hold timeout so the layer activates.
    const hold_raw = buildReport(form, 8, false, true);
    const hold_delta = (try interp.processReport(0, &hold_raw)) orelse return error.NoMatch;
    _ = try ctx.mapper.apply(hold_delta, 16, 0);
    _ = ctx.mapper.onLayerTimerExpired();

    const raw = buildReport(form, 4, false, true);
    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const ev = try ctx.mapper.apply(delta, 16, 0);

    var keys: std.ArrayList(KeyEvent) = .{};
    defer keys.deinit(allocator);
    try collectKeys(ev.aux, &keys, allocator);

    var got_down = false;
    for (keys.items) |k| {
        if (k.code == helpers.KEY_DOWN and k.pressed) got_down = true;
    }
    try testing.expect(got_down);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & dpadMask());
}

test "dpad: layer dpad override applies to hat input" {
    try runLayerArrows(.hat);
}

test "dpad: layer dpad override applies to button-bit input" {
    try runLayerArrows(.bits);
}

test "dpad: hat input and button-bit input produce identical mapper output" {
    const allocator = testing.allocator;
    const mappings = [_][]const u8{ "", arrows_mapping, arrows_suppress_mapping };

    for (mappings) |mapping_toml| {
        const hat_toml = try deviceToml(allocator, .hat, output_hat_toml);
        defer allocator.free(hat_toml);
        const hat_parsed = try device_mod.parseString(allocator, hat_toml);
        defer hat_parsed.deinit();
        const hat_interp = Interpreter.init(&hat_parsed.value);

        const bits_toml = try deviceToml(allocator, .bits, output_hat_toml);
        defer allocator.free(bits_toml);
        const bits_parsed = try device_mod.parseString(allocator, bits_toml);
        defer bits_parsed.deinit();
        const bits_interp = Interpreter.init(&bits_parsed.value);

        var hat_ctx = try helpers.makeMapper(mapping_toml, allocator);
        defer hat_ctx.deinit();
        var bits_ctx = try helpers.makeMapper(mapping_toml, allocator);
        defer bits_ctx.deinit();

        var hat_keys: std.ArrayList(KeyEvent) = .{};
        defer hat_keys.deinit(allocator);
        var bits_keys: std.ArrayList(KeyEvent) = .{};
        defer bits_keys.deinit(allocator);

        for (0..16) |i| {
            const hat: u8 = @intCast(i);
            const hat_raw = buildReport(.hat, hat, false, false);
            const bits_raw = buildReport(.bits, hat, false, false);
            const hat_delta = (try hat_interp.processReport(0, &hat_raw)) orelse return error.NoMatch;
            const bits_delta = (try bits_interp.processReport(0, &bits_raw)) orelse return error.NoMatch;

            const hat_ev = try hat_ctx.mapper.apply(hat_delta, 16, 0);
            const bits_ev = try bits_ctx.mapper.apply(bits_delta, 16, 0);

            try testing.expectEqual(hat_ev.gamepad.dpad_x, bits_ev.gamepad.dpad_x);
            try testing.expectEqual(hat_ev.gamepad.dpad_y, bits_ev.gamepad.dpad_y);
            try testing.expectEqual(
                hat_ev.gamepad.buttons & dpadMask(),
                bits_ev.gamepad.buttons & dpadMask(),
            );

            hat_keys.clearRetainingCapacity();
            bits_keys.clearRetainingCapacity();
            try collectKeys(hat_ev.aux, &hat_keys, allocator);
            try collectKeys(bits_ev.aux, &bits_keys, allocator);
            try testing.expectEqual(hat_keys.items.len, bits_keys.items.len);
            for (hat_keys.items, bits_keys.items) |a, b| {
                try testing.expectEqual(a.code, b.code);
                try testing.expectEqual(a.pressed, b.pressed);
            }
        }
    }
}

// --- validate: a dpad hat field and DPad* button bits cannot coexist ---

test "dpad validate: hat field plus DPad button_group in one report is rejected" {
    const allocator = testing.allocator;
    const toml =
        \\[device]
        \\name = "Double"
        \\vid = 1
        \\pid = 2
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "input"
        \\interface = 0
        \\size = 4
        \\
        \\[report.fields]
        \\dpad = { offset = 1, type = "u8" }
        \\
        \\[report.button_group]
        \\source = { offset = 2, size = 1 }
        \\map = { DPadUp = 0, A = 1 }
    ;
    try testing.expectError(error.InvalidConfig, device_mod.parseString(allocator, toml));
}

test "dpad validate: hat field and DPad button_group in different reports is rejected" {
    const allocator = testing.allocator;
    const toml =
        \\[device]
        \\name = "Double Split"
        \\vid = 1
        \\pid = 2
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "hat"
        \\interface = 0
        \\size = 4
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\
        \\[report.fields]
        \\dpad = { offset = 1, type = "u8" }
        \\
        \\[[report]]
        \\name = "buttons"
        \\interface = 0
        \\size = 4
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x02]
        \\
        \\[report.button_group]
        \\source = { offset = 1, size = 1 }
        \\map = { DPadRight = 0 }
    ;
    try testing.expectError(error.InvalidConfig, device_mod.parseString(allocator, toml));
}

test "dpad validate: hat field alone is accepted" {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, .hat, output_hat_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
}

test "dpad validate: DPad button_group alone is accepted" {
    const allocator = testing.allocator;
    const toml = try deviceToml(allocator, .bits, output_buttons_toml);
    defer allocator.free(toml);
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
}
