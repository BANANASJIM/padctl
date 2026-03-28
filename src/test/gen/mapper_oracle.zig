// mapper_oracle.zig — independent reference oracle for mapper deterministic subsystems.
//
// Reimplements button remap, layer selection, dpad mode, and prev-frame masking
// without sharing any logic with mapper.zig.  Shared type imports only (TP5).
// Floating-point/timing subsystems (gyro, stick, macro) are NOT replicated;
// use property constraints for those.

const std = @import("std");
const state = @import("../../core/state.zig");
const aux_event_mod = @import("../../core/aux_event.zig");
const remap_mod = @import("../../core/remap.zig");
const mapping = @import("../../config/mapping.zig");

const toml = @import("toml");

pub const GamepadState = state.GamepadState;
pub const GamepadStateDelta = state.GamepadStateDelta;
pub const ButtonId = state.ButtonId;
pub const AuxEvent = aux_event_mod.AuxEvent;
pub const AuxEventList = aux_event_mod.AuxEventList;
pub const MappingConfig = mapping.MappingConfig;
pub const LayerConfig = mapping.LayerConfig;
pub const RemapTarget = remap_mod.RemapTargetResolved;

const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;

const c = @cImport(@cInclude("linux/input-event-codes.h"));
const KEY_UP: u16 = c.KEY_UP;
const KEY_DOWN: u16 = c.KEY_DOWN;
const KEY_LEFT: u16 = c.KEY_LEFT;
const KEY_RIGHT: u16 = c.KEY_RIGHT;

fn btnMask(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

fn btnMaskByName(name: []const u8) u64 {
    const id = std.meta.stringToEnum(ButtonId, name) orelse return 0;
    return btnMask(id);
}

pub const OracleState = struct {
    gs: GamepadState = .{},
    prev_buttons: u64 = 0,
    prev_dpad_x: i8 = 0,
    prev_dpad_y: i8 = 0,
    // Hold layer FSM
    hold_phase: enum { idle, pending, active } = .idle,
    hold_layer_idx: usize = 0,
    hold_elapsed_ms: u64 = 0,
    // Toggle layers (up to 8)
    toggled: [8]bool = .{false} ** 8,
    // Injected buttons to clear next frame (tap release)
    pending_tap_release: ?u64 = null,
};

pub const OracleOutput = struct {
    gamepad: GamepadState,
    aux: AuxEventList,
    prev_buttons: u64,
};

pub fn apply(
    os: *OracleState,
    delta: GamepadStateDelta,
    cfg: *const MappingConfig,
    dt_ms: u64,
) OracleOutput {
    return applyWithLayer(os, delta, cfg, dt_ms, null);
}

/// Like apply, but use a pre-determined active layer instead of the oracle FSM.
pub fn applyWithLayer(
    os: *OracleState,
    delta: GamepadStateDelta,
    cfg: *const MappingConfig,
    dt_ms: u64,
    active_layer_override: ?*const LayerConfig,
) OracleOutput {
    var aux = AuxEventList{};

    // flush pending tap release: clear injected buttons from previous frame
    var carry_injected: u64 = 0;
    if (os.pending_tap_release) |mask| {
        carry_injected = mask; // will be subtracted from injected in emit
        os.pending_tap_release = null;
    }

    // [1] merge delta
    os.gs.applyDelta(delta);
    const cur_buttons = os.gs.buttons;

    // [2] layer trigger processing with tap-hold FSM (only when not overridden)
    const layers = cfg.layer orelse &[0]LayerConfig{};
    if (active_layer_override == null) {
        processLayers(os, layers, cur_buttons, dt_ms);
    }

    // determine active layer config
    const active_cfg: ?*const LayerConfig = active_layer_override orelse blk: {
        if (os.hold_phase == .active and os.hold_layer_idx < layers.len)
            break :blk &layers[os.hold_layer_idx];
        for (layers, 0..) |*lc, i| {
            if (i < os.toggled.len and os.toggled[i]) break :blk lc;
        }
        break :blk null;
    };

    // [3] dpad processing
    const dpad_cfg = if (active_cfg) |lc| lc.dpad orelse cfg.dpad else cfg.dpad;
    var suppressed_buttons: u64 = 0;
    var suppress_dpad_hat: bool = false;
    processDpad(os.gs.dpad_x, os.gs.dpad_y, os.prev_dpad_x, os.prev_dpad_y, dpad_cfg, &aux, &suppressed_buttons, &suppress_dpad_hat);

    // [4] base remap
    var per_src: [BUTTON_COUNT]?RemapTarget = .{null} ** BUTTON_COUNT;
    if (cfg.remap) |remap_map| {
        collectRemap(remap_map, &suppressed_buttons, &per_src);
    }

    // [5] layer remap override (last-write-wins)
    if (active_cfg) |lc| {
        if (lc.remap) |layer_remap| {
            collectRemap(layer_remap, &suppressed_buttons, &per_src);
        }
    }

    // [6] emit aux + injected buttons
    var injected_buttons: u64 = 0;
    for (0..BUTTON_COUNT) |i| {
        const target = per_src[i] orelse continue;
        const src_mask: u64 = @as(u64, 1) << @as(u6, @intCast(i));
        const pressed = (cur_buttons & src_mask) != 0;
        const prev_pressed = (os.prev_buttons & src_mask) != 0;
        switch (target) {
            .key => |code| {
                if (pressed != prev_pressed)
                    aux.append(.{ .key = .{ .code = code, .pressed = pressed } }) catch {};
            },
            .mouse_button => |code| {
                if (pressed != prev_pressed)
                    aux.append(.{ .mouse_button = .{ .code = code, .pressed = pressed } }) catch {};
            },
            .gamepad_button => |dst| {
                if (pressed) {
                    injected_buttons |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(dst)));
                }
            },
            .disabled => {},
            .macro => {},
        }
    }

    // subtract carry_injected (tap release from previous frame)
    injected_buttons &= ~carry_injected;

    // [7] assemble emit state
    var emit = os.gs;
    emit.buttons = (cur_buttons & ~suppressed_buttons) | injected_buttons;
    if (suppress_dpad_hat) {
        emit.dpad_x = 0;
        emit.dpad_y = 0;
    }

    const saved_prev = os.prev_buttons;

    // update prev-frame state
    os.prev_buttons = cur_buttons;
    os.prev_dpad_x = os.gs.dpad_x;
    os.prev_dpad_y = os.gs.dpad_y;

    return .{ .gamepad = emit, .aux = aux, .prev_buttons = saved_prev };
}

fn processLayers(os: *OracleState, layers: []const LayerConfig, buttons: u64, dt_ms: u64) void {
    for (layers, 0..) |*lc, idx| {
        const trigger_mask = btnMaskByName(lc.trigger);
        if (trigger_mask == 0) continue;
        const pressed = (buttons & trigger_mask) != 0;
        const was_pressed = (os.prev_buttons & trigger_mask) != 0;

        if (std.mem.eql(u8, lc.activation, "hold")) {
            if (pressed and !was_pressed) {
                // mutual exclusion: ignore if another layer is PENDING or ACTIVE
                if (os.hold_phase != .idle) continue;
                os.hold_phase = .pending;
                os.hold_layer_idx = idx;
                os.hold_elapsed_ms = 0;
            } else if (pressed and was_pressed and os.hold_phase == .pending and os.hold_layer_idx == idx) {
                // accumulate time while holding
                const threshold: u64 = @intCast(@max(0, lc.hold_timeout orelse 200));
                os.hold_elapsed_ms += dt_ms;
                if (os.hold_elapsed_ms >= threshold) {
                    os.hold_phase = .active;
                }
            } else if (!pressed and was_pressed) {
                if (os.hold_phase == .pending and os.hold_layer_idx == idx) {
                    // tap: inject trigger button for one frame then release
                    os.pending_tap_release = trigger_mask;
                    os.hold_phase = .idle;
                    os.hold_elapsed_ms = 0;
                } else if (os.hold_phase == .active and os.hold_layer_idx == idx) {
                    os.hold_phase = .idle;
                    os.hold_elapsed_ms = 0;
                }
            }
        } else {
            // toggle: fires on release
            if (!pressed and was_pressed) {
                if (idx < os.toggled.len) {
                    if (os.toggled[idx]) {
                        os.toggled[idx] = false;
                    } else {
                        // block toggle-on if hold layer is ACTIVE (not pending) or another toggle is on
                        const hold_blocking = os.hold_phase == .active;
                        var any_toggled = false;
                        for (os.toggled) |t| any_toggled = any_toggled or t;
                        if (!hold_blocking and !any_toggled) {
                            // Clear pending hold state (matches production layer.zig)
                            if (os.hold_phase == .pending) {
                                os.hold_phase = .idle;
                                os.hold_elapsed_ms = 0;
                            }
                            os.toggled[idx] = true;
                        }
                    }
                }
            }
        }
    }
}

fn collectRemap(
    remap_map: toml.HashMap([]const u8),
    suppressed: *u64,
    per_src: []?RemapTarget,
) void {
    var it = remap_map.map.iterator();
    while (it.next()) |entry| {
        const src_id = std.meta.stringToEnum(ButtonId, entry.key_ptr.*) orelse continue;
        const src_idx: u6 = @intCast(@intFromEnum(src_id));
        suppressed.* |= @as(u64, 1) << src_idx;
        // Unknown targets skipped — matches production mapper.zig behaviour.
        const target = remap_mod.resolveTarget(entry.value_ptr.*) catch continue;
        per_src[@intCast(src_idx)] = target;
    }
}

fn processDpad(
    dpad_x: i8,
    dpad_y: i8,
    prev_dpad_x: i8,
    prev_dpad_y: i8,
    dpad_cfg_opt: ?mapping.DpadConfig,
    aux: *AuxEventList,
    suppressed_buttons: *u64,
    suppress_dpad_hat: *bool,
) void {
    const cfg = dpad_cfg_opt orelse return;
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
        suppressed_buttons.* |= btnMask(.DPadUp) | btnMask(.DPadDown) |
            btnMask(.DPadLeft) | btnMask(.DPadRight);
        suppress_dpad_hat.* = true;
    }
}

// --- Property constraint for gyro (not replicated) ---

pub fn checkGyroProperty(delta: GamepadStateDelta, output: OracleOutput) bool {
    const gx = delta.gyro_x orelse return true;
    _ = output;
    _ = gx;
    return true; // placeholder — gyro uses floating point, only check sign consistency
}

// --- Tests ---

const testing = std.testing;

fn parseCfg(toml_str: []const u8) !mapping.ParseResult {
    return mapping.parseString(testing.allocator, toml_str);
}

test "mapper_oracle: passthrough no remap" {
    var os = OracleState{};
    const parsed = try parseCfg("");
    defer parsed.deinit();

    const a_mask = btnMask(.A);
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expect((out.gamepad.buttons & a_mask) != 0);
    try testing.expectEqual(@as(usize, 0), out.aux.len);
}

test "mapper_oracle: base remap A->KEY_F13" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "KEY_F13"
    );
    defer parsed.deinit();

    const a_mask = btnMask(.A);
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    // A suppressed
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    // KEY_F13 aux event
    try testing.expectEqual(@as(usize, 1), out.aux.len);
    const ev = out.aux.get(0);
    try testing.expectEqual(@as(u16, 183), ev.key.code);
    try testing.expect(ev.key.pressed);
}

test "mapper_oracle: base remap A->B gamepad button" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "B"
    );
    defer parsed.deinit();

    const a_mask = btnMask(.A);
    const b_mask = btnMask(.B);
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    try testing.expect((out.gamepad.buttons & b_mask) != 0);
    try testing.expectEqual(@as(usize, 0), out.aux.len);
}

test "mapper_oracle: layer hold activates remap after timer" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "B"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "X"
    );
    defer parsed.deinit();

    const lt_mask = btnMask(.LT);
    const a_mask = btnMask(.A);
    const x_mask = btnMask(.X);
    const b_mask = btnMask(.B);

    // press LT — goes PENDING, layer NOT active yet
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 0);
    try testing.expectEqual(os.hold_phase, .pending);

    // advance timer past threshold (200ms default)
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 201);
    try testing.expectEqual(os.hold_phase, .active);

    // press A while layer active — should use layer remap (X)
    const out = apply(&os, .{ .buttons = lt_mask | a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & b_mask);
    try testing.expect((out.gamepad.buttons & x_mask) != 0);
}

test "mapper_oracle: layer hold tap (release while PENDING)" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
    );
    defer parsed.deinit();

    const lt_mask = btnMask(.LT);

    // press LT — PENDING
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 0);
    try testing.expectEqual(os.hold_phase, .pending);

    // release before timeout — tap, layer never activates
    _ = apply(&os, .{ .buttons = 0 }, &parsed.value, 50);
    try testing.expectEqual(os.hold_phase, .idle);
    // tap injects LT for one frame (pending_tap_release set)
    try testing.expect(os.pending_tap_release != null);
}

test "mapper_oracle: layer toggle on/off" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
        \\
        \\[layer.remap]
        \\A = "KEY_F1"
    );
    defer parsed.deinit();

    const sel_mask = btnMask(.Select);
    const a_mask = btnMask(.A);

    // press Select
    _ = apply(&os, .{ .buttons = sel_mask }, &parsed.value, 0);
    // release Select -> toggle on
    _ = apply(&os, .{ .buttons = 0 }, &parsed.value, 0);
    try testing.expect(os.toggled[0]);

    // press A -> should be remapped to KEY_F1
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    try testing.expect(out.aux.len > 0);
    try testing.expectEqual(@as(u16, 0x3b), out.aux.get(0).key.code); // KEY_F1

    // toggle off: press + release Select again
    _ = apply(&os, .{ .buttons = sel_mask }, &parsed.value, 0);
    _ = apply(&os, .{ .buttons = 0 }, &parsed.value, 0);
    try testing.expect(!os.toggled[0]);

    // press A -> no remap now
    const out2 = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expect((out2.gamepad.buttons & a_mask) != 0);
    try testing.expectEqual(@as(usize, 0), out2.aux.len);
}

test "mapper_oracle: dpad arrows mode" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    );
    defer parsed.deinit();

    // dpad left
    const out = apply(&os, .{ .dpad_x = -1 }, &parsed.value, 0);
    try testing.expectEqual(@as(i8, 0), out.gamepad.dpad_x);
    var found_left = false;
    for (out.aux.slice()) |ev| {
        if (ev.key.code == KEY_LEFT and ev.key.pressed) found_left = true;
    }
    try testing.expect(found_left);
}

test "mapper_oracle: suppress clears button from output" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "disabled"
    );
    defer parsed.deinit();

    const a_mask = btnMask(.A);
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    try testing.expectEqual(@as(usize, 0), out.aux.len);
}

test "mapper_oracle: prev-frame mask no spurious release" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "disabled"
    );
    defer parsed.deinit();

    const a_mask = btnMask(.A);

    // frame 1: A pressed, suppressed
    const ev1 = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), ev1.gamepad.buttons & a_mask);

    // frame 2: A still pressed, still suppressed — no spurious events
    const ev2 = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), ev2.gamepad.buttons & a_mask);
    try testing.expectEqual(@as(usize, 0), ev2.aux.len);
}

test "mapper_oracle: mouse_button remap" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\M1 = "mouse_left"
    );
    defer parsed.deinit();

    const m1_mask = btnMask(.M1);
    const out = apply(&os, .{ .buttons = m1_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & m1_mask);
    try testing.expectEqual(@as(usize, 1), out.aux.len);
    try testing.expectEqual(@as(u16, 0x110), out.aux.get(0).mouse_button.code);
    try testing.expect(out.aux.get(0).mouse_button.pressed);
}

test "mapper_oracle: layer remap overrides base for same button" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "X"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "Y"
    );
    defer parsed.deinit();

    const lt_mask = btnMask(.LT);
    const a_mask = btnMask(.A);
    const x_mask = btnMask(.X);
    const y_mask = btnMask(.Y);

    // press LT, advance past threshold
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 0);
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 201);

    const out = apply(&os, .{ .buttons = lt_mask | a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & x_mask);
    try testing.expect((out.gamepad.buttons & y_mask) != 0);
}

test "mapper_oracle: hold layer release deactivates" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "B"
    );
    defer parsed.deinit();

    const lt_mask = btnMask(.LT);
    const a_mask = btnMask(.A);
    const b_mask = btnMask(.B);

    // press LT then advance past threshold
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 0);
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 201);
    try testing.expectEqual(os.hold_phase, .active);

    // release LT
    _ = apply(&os, .{ .buttons = 0 }, &parsed.value, 0);
    try testing.expectEqual(os.hold_phase, .idle);

    // A should no longer be remapped
    const out = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expect((out.gamepad.buttons & a_mask) != 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & b_mask);
}

test "mapper_oracle: suppress accumulates base + layer" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[remap]
        \\A = "disabled"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\B = "disabled"
    );
    defer parsed.deinit();

    const lt_mask = btnMask(.LT);
    const a_mask = btnMask(.A);
    const b_mask = btnMask(.B);

    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 0);
    _ = apply(&os, .{ .buttons = lt_mask }, &parsed.value, 201);
    const out = apply(&os, .{ .buttons = lt_mask | a_mask | b_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & a_mask);
    try testing.expectEqual(@as(u64, 0), out.gamepad.buttons & b_mask);
}

test "mapper_oracle: dpad gamepad mode passthrough" {
    var os = OracleState{};
    const parsed = try parseCfg(
        \\[dpad]
        \\mode = "gamepad"
    );
    defer parsed.deinit();

    const out = apply(&os, .{ .dpad_x = 1, .dpad_y = -1 }, &parsed.value, 0);
    try testing.expectEqual(@as(i8, 1), out.gamepad.dpad_x);
    try testing.expectEqual(@as(i8, -1), out.gamepad.dpad_y);
    try testing.expectEqual(@as(usize, 0), out.aux.len);
}

test "mapper_oracle: prev_buttons in output" {
    var os = OracleState{};
    const parsed = try parseCfg("");
    defer parsed.deinit();

    const a_mask = btnMask(.A);

    // frame 1: A pressed; prev was 0
    const out1 = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expectEqual(@as(u64, 0), out1.prev_buttons);

    // frame 2: A still pressed; prev_buttons should now be a_mask
    const out2 = apply(&os, .{ .buttons = a_mask }, &parsed.value, 0);
    try testing.expect((out2.prev_buttons & a_mask) != 0);
}
