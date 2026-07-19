// Mapper end-to-end integration tests (L1 — mock timer/vtable, always CI).
//
// All tests drive the Mapper directly; no EventLoop thread is needed.
// Timer events are injected by calling m.layer.onTriggerPress() / m.layer.onTimerExpired() (LayerState)
// or m.onLayerTimerExpired() (Mapper) instead of using a real timerfd.

const std = @import("std");
const testing = std.testing;

const h = @import("helpers.zig");
const mapper_mod = @import("../core/mapper.zig");
const layer_mod = @import("../core/layer.zig");
const state_mod = @import("../core/state.zig");

const Mapper = mapper_mod.Mapper;
const AuxEvent = mapper_mod.AuxEvent;
const AuxEventList = mapper_mod.AuxEventList;
const ButtonId = state_mod.ButtonId;
const GamepadState = state_mod.GamepadState;
const GamepadStateDelta = state_mod.GamepadStateDelta;

const REL_X = h.REL_X;
const REL_Y = h.REL_Y;
const BTN_LEFT = h.BTN_LEFT;
const BTN_FORWARD: u16 = 0x115;
const KEY_UP = h.KEY_UP;
const KEY_DOWN = h.KEY_DOWN;
const KEY_LEFT = h.KEY_LEFT;
const KEY_RIGHT = h.KEY_RIGHT;
const KEY_F1 = h.KEY_F1;
const KEY_F13 = h.KEY_F13;

const btnMask = h.btnMask;
const makeMapper = h.makeMapper;

// --- 1. Layer hold switch ---

test "e2e: layer hold — PENDING → ACTIVE, layer remap activates" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    // Frame 1: LT press → PENDING
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // Mock timer expired → ACTIVE
    _ = m.layer.onTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Frame 2: A press while layer active → mouse_left aux event
    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));

    var found_mouse_left = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .mouse_button => |mb| {
                if (mb.code == BTN_LEFT and mb.pressed) found_mouse_left = true;
            },
            else => {},
        }
    }
    try testing.expect(found_mouse_left);

    // Frame 3: LT release → layer IDLE, A restores
    _ = m.layer.onTriggerRelease(null, 500_000_000);
    try testing.expect(m.layer.tap_hold == null);
    const ev2 = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expect((ev2.gamepad.buttons & btnMask(.A)) != 0);
    try testing.expectEqual(@as(usize, 0), ev2.aux.len);
}

// --- 2. Layer tap ---

test "e2e: layer tap — quick release emits tap event" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    // Frame 1: LT press → PENDING
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);

    // Frame 2: LT release before timer → tap event
    const tap_target = mapper_mod.resolveTarget("mouse_left") catch unreachable;
    const res = m.layer.onTriggerRelease(tap_target, 100_000_000);
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event != null);
    try testing.expect(m.layer.tap_hold == null);

    // The tap target is mouse_left → BTN_LEFT
    switch (res.tap_event.?) {
        .mouse_button => |code| try testing.expectEqual(BTN_LEFT, code),
        else => return error.WrongTapEventType,
    }
}

fn auxListMouseCount(list: *const AuxEventList, code: u16, pressed: bool) usize {
    var count: usize = 0;
    for (list.slice()) |e| {
        switch (e) {
            .mouse_button => |b| {
                if (b.code == code and b.pressed == pressed) count += 1;
            },
            else => {},
        }
    }
    return count;
}

fn auxMouseCount(ev: anytype, code: u16, pressed: bool) usize {
    return auxListMouseCount(&ev.aux, code, pressed);
}

test "e2e: layer tap mouse delays aux release" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "mouse_left"
        \\hold_timeout = 200
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = 1_000_000_000;
    const ev_press = try m.apply(.{ .buttons = btnMask(.LT) }, 16, t0);
    try testing.expectEqual(@as(usize, 0), ev_press.aux.len);

    const ev_release = try m.apply(.{ .buttons = 0 }, 16, t0 + 50 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxMouseCount(ev_release, BTN_LEFT, true));
    try testing.expectEqual(@as(usize, 0), auxMouseCount(ev_release, BTN_LEFT, false));

    const aux_release = m.onMacroTimerExpired(t0 + 90 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxListMouseCount(&aux_release, BTN_LEFT, false));
    try testing.expectEqual(@as(usize, 0), auxListMouseCount(&aux_release, BTN_LEFT, true));
}

test "e2e: layer tap — no tap after timeout (ACTIVE release)" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired(); // ACTIVE

    const res = m.layer.onTriggerRelease(null, 500_000_000);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(res.layer_deactivated);
    try testing.expect(m.layer.tap_hold == null);
}

// --- 3. Suppress/inject verification ---

test "e2e: suppress/inject — no layer: A→KEY_F13, mouse_side unaffected" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    // A suppressed in gamepad
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    // KEY_F13 in aux
    try testing.expectEqual(@as(usize, 1), ev.aux.len);
    switch (ev.aux.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_F13, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "e2e: suppress/inject — layer ACTIVE: A→mouse_left overrides base A→KEY_F13" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    // Activate layer
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));

    var found_mouse_left = false;
    var found_key_f13 = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .mouse_button => |mb| if (mb.code == BTN_LEFT) {
                found_mouse_left = true;
            },
            .key => |k| if (k.code == KEY_F13) {
                found_key_f13 = true;
            },
            else => {},
        }
    }
    try testing.expect(found_mouse_left);
    try testing.expect(!found_key_f13);
}

// --- 4. Gyro → mouse ---

test "e2e: gyro mouse mode — non-zero gyro produces REL_X/REL_Y aux events" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "mouse"
        \\smoothing = 0.0
        \\sensitivity = 32767.0
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Full-deflection gyro: with smoothing=0 and sensitivity=32767, normalized*sensitivity ~= 32767 → integer pixels emitted on first frame.
    const ev = try m.apply(.{ .gyro_x = 32767, .gyro_y = 32767 }, 16, 0);

    var found_rel_x = false;
    var found_rel_y = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .rel => |r| {
                if (r.code == REL_X) found_rel_x = true;
                if (r.code == REL_Y) found_rel_y = true;
            },
            else => {},
        }
    }
    try testing.expect(found_rel_x);
    try testing.expect(found_rel_y);
}

test "e2e: gyro off mode — no REL events" {
    const allocator = testing.allocator;
    // Default gyro mode is "off"
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev.aux.slice()) |e| {
        switch (e) {
            .rel => return error.UnexpectedRelEvent,
            else => {},
        }
    }
}

// --- 5. Dual uinput device routing ---

test "e2e: dual uinput routing — gamepad_button remap stays on main device, no aux" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "B"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    // A suppressed, B injected in gamepad (main device)
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    try testing.expect((ev.gamepad.buttons & btnMask(.B)) != 0);
    // No aux events
    try testing.expectEqual(@as(usize, 0), ev.aux.len);
}

test "e2e: dual uinput routing — key remap goes to aux, not main device" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    try testing.expectEqual(@as(usize, 1), ev.aux.len);
    switch (ev.aux.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_F1, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "e2e: dual uinput routing — mouse_button remap goes to aux" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\RB = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.RB) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.RB));
    try testing.expectEqual(@as(usize, 1), ev.aux.len);
    switch (ev.aux.get(0)) {
        .mouse_button => |mb| {
            try testing.expectEqual(BTN_LEFT, mb.code);
            try testing.expect(mb.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "e2e: dual uinput routing — same frame: gamepad remap + key remap both route correctly" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "B"
        \\RB = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const buttons = btnMask(.A) | btnMask(.RB);
    const ev = try m.apply(.{ .buttons = buttons }, 16, 0);

    // A→B on main device
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    try testing.expect((ev.gamepad.buttons & btnMask(.B)) != 0);

    // RB→KEY_F1 on aux
    var found_f1 = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_F1 and k.pressed) {
                found_f1 = true;
            },
            else => {},
        }
    }
    try testing.expect(found_f1);
}

// --- 6. DPad arrows ---

test "e2e: dpad arrows — dpad_y=-1 (first press) → KEY_UP press" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[dpad]
        \\mode = "arrows"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // prev dpad_y = 0 (default), current = -1
    const ev = try m.apply(.{ .dpad_y = -1 }, 16, 0);
    var found_key_up_press = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_UP and k.pressed) {
                found_key_up_press = true;
            },
            else => {},
        }
    }
    try testing.expect(found_key_up_press);
}

test "e2e: dpad arrows — dpad_y returns to 0 → KEY_UP release" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[dpad]
        \\mode = "arrows"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Set prev to dpad_y = -1 by applying that state first
    _ = try m.apply(.{ .dpad_y = -1 }, 16, 0);

    // Now dpad_y returns to 0 → KEY_UP release
    const ev = try m.apply(.{ .dpad_y = 0 }, 16, 0);
    var found_key_up_release = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_UP and !k.pressed) {
                found_key_up_release = true;
            },
            else => {},
        }
    }
    try testing.expect(found_key_up_release);
}

test "e2e: dpad gamepad mode — dpad passes through unchanged, no aux KEY events" {
    const allocator = testing.allocator;
    // Default mode is "gamepad". emit_state.synthesizeDpadAxes() derives dpad axes
    // from button state, so drive the test via the DPadUp button bit.
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.DPadUp) }, 16, 0);
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => return error.UnexpectedKeyEvent,
            else => {},
        }
    }
    try testing.expectEqual(@as(i8, -1), ev.gamepad.dpad_y);
}

test "e2e: dpad arrows suppress_gamepad — dpad_x/y zeroed in emit_state" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .dpad_y = -1 }, 16, 0);
    try testing.expectEqual(@as(i8, 0), ev.gamepad.dpad_y);
    try testing.expectEqual(@as(i8, 0), ev.gamepad.dpad_x);
}

// --- 7. prev-frame suppress correctness ---

test "e2e: prev-frame mask — layer activates mid-stream, no spurious release for held button" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\B = "disabled"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    // Frame N-1: B pressed, no layer → B passes through
    const ev1 = try m.apply(.{ .buttons = btnMask(.B) }, 16, 0);
    try testing.expect((ev1.gamepad.buttons & btnMask(.B)) != 0);

    // Layer activates (simulate timer)
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    // Frame N: B still held + layer ACTIVE → B suppressed in both current and masked_prev
    const ev2 = try m.apply(.{ .buttons = btnMask(.B) }, 16, 0);
    // B suppressed in emit output
    try testing.expectEqual(@as(u64, 0), ev2.gamepad.buttons & btnMask(.B));
    // B also suppressed in masked_prev (no spurious release diff)
    try testing.expectEqual(@as(u64, 0), ev2.prev.buttons & btnMask(.B));
}

// --- 8. Toggle layer cycle ---

test "e2e: toggle layer — Select release toggles fn layer on/off, A remap applies" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
        \\
        \\[layer.remap]
        \\A = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    const sel = btnMask(.Select);

    // Toggle on: Select press then release
    _ = m.layer.processLayerTriggers(configs, sel, 0, 0); // press
    _ = m.layer.processLayerTriggers(configs, 0, sel, 0); // release → toggle on
    try testing.expect(m.layer.toggled.contains("fn"));

    // A press → KEY_F1 in aux
    const ev1 = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    var found_f1 = false;
    for (ev1.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_F1) {
                found_f1 = true;
            },
            else => {},
        }
    }
    try testing.expect(found_f1);
    try testing.expectEqual(@as(u64, 0), ev1.gamepad.buttons & btnMask(.A));

    // Toggle off: Select press then release again
    _ = m.layer.processLayerTriggers(configs, sel, 0, 0);
    _ = m.layer.processLayerTriggers(configs, 0, sel, 0); // release → toggle off
    try testing.expect(!m.layer.toggled.contains("fn"));

    // A press now → A passes through on main device
    const ev2 = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expect((ev2.gamepad.buttons & btnMask(.A)) != 0);
    var no_f1 = true;
    for (ev2.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_F1) {
                no_f1 = false;
            },
            else => {},
        }
    }
    try testing.expect(no_f1);
}

// --- 9. Layer-only remap fall-through to base ---

test "e2e: layer remap fall-through — button not in layer remap uses base remap" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\X = "KEY_F13"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\RB = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    // X pressed — not in layer remap, should fall through to base (KEY_F13)
    const ev = try m.apply(.{ .buttons = btnMask(.X) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.X));
    var found_f13 = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_F13) {
                found_f13 = true;
            },
            else => {},
        }
    }
    try testing.expect(found_f13);
}

// --- 8. mouse_forward / mouse_back remap ---

test "e2e: remap to mouse_forward produces BTN_FORWARD aux event" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\M1 = "mouse_forward"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.M1) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.M1));

    var found_forward = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .mouse_button => |mb| if (mb.code == BTN_FORWARD and mb.pressed) {
                found_forward = true;
            },
            else => {},
        }
    }
    try testing.expect(found_forward);
}

// --- 9. dpad layer mode switch ---

test "e2e: layer active — dpad mode switches to arrows" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[dpad]
        \\mode = "gamepad"
        \\
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
    var m = &ctx.mapper;
    const configs = ctx.parsed.value.layer.?;

    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    // dpad_y = -1 → KEY_UP (arrows mode active via layer)
    const ev_up = try m.apply(.{ .dpad_y = -1 }, 16, 0);
    var found_key_up = false;
    for (ev_up.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_UP and k.pressed) {
                found_key_up = true;
            },
            else => {},
        }
    }
    try testing.expect(found_key_up);

    // dpad_y = 1 → KEY_DOWN
    const ev_down = try m.apply(.{ .dpad_y = 1 }, 16, 0);
    var found_key_down = false;
    for (ev_down.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_DOWN and k.pressed) {
                found_key_down = true;
            },
            else => {},
        }
    }
    try testing.expect(found_key_down);
}

// --- 10. chord switch detector wired into Mapper ---

const chord_detector_mod = @import("../core/chord_detector.zig");

fn chordCfg() chord_detector_mod.Config {
    var sels: [chord_detector_mod.MAX_SELECTORS]u64 = [_]u64{0} ** chord_detector_mod.MAX_SELECTORS;
    sels[0] = btnMask(.A);
    sels[1] = btnMask(.B);
    sels[2] = btnMask(.X);
    sels[3] = btnMask(.Y);
    return .{
        .modifier_mask = btnMask(.LM) | btnMask(.RM),
        .selectors = sels,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    };
}

test "e2e: chord match — modifier+selector after debounce fires chord_index" {
    const allocator = testing.allocator;
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    m.setChordDetector(chordCfg());

    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = btnMask(.LM) | btnMask(.RM) }, 16, t0);
    const ev = try m.apply(.{ .buttons = btnMask(.LM) | btnMask(.RM) | btnMask(.A) }, 16, t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, 1), ev.chord_switch_request);
    // Selector A must be suppressed in emit state.
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
}

test "e2e: no chord detector — feature inert, selector passes through" {
    const allocator = testing.allocator;
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    // Deliberately do not call setChordDetector.

    const ev = try m.apply(.{ .buttons = btnMask(.LM) | btnMask(.RM) | btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(?u8, null), ev.chord_switch_request);
    try testing.expect((ev.gamepad.buttons & btnMask(.A)) != 0);
}

test "e2e: partial modifier — only LM held, selector fires as normal input" {
    const allocator = testing.allocator;
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;
    m.setChordDetector(chordCfg());

    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = btnMask(.LM) }, 16, t0);
    const ev = try m.apply(.{ .buttons = btnMask(.LM) | btnMask(.A) }, 16, t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), ev.chord_switch_request);
    try testing.expect((ev.gamepad.buttons & btnMask(.A)) != 0);
}

// --- gesture: per-button tap/hold/double-press ---

fn keyCode(name: []const u8) u16 {
    return (mapper_mod.resolveTarget(name) catch unreachable).key;
}

fn auxHasKey(ev: anytype, code: u16, pressed: bool) bool {
    return auxListHasKey(&ev.aux, code, pressed);
}

fn auxListKeyCount(list: *const AuxEventList, code: u16, pressed: bool) usize {
    var count: usize = 0;
    for (list.slice()) |e| {
        switch (e) {
            .key => |k| {
                if (k.code == code and k.pressed == pressed) count += 1;
            },
            else => {},
        }
    }
    return count;
}

fn auxKeyCount(ev: anytype, code: u16, pressed: bool) usize {
    return auxListKeyCount(&ev.aux, code, pressed);
}

fn auxListHasKey(list: *const AuxEventList, code: u16, pressed: bool) bool {
    return auxListKeyCount(list, code, pressed) != 0;
}

fn auxHasAnyKey(ev: anytype, code: u16) bool {
    return auxHasKey(ev, code, true) or auxHasKey(ev, code, false);
}

fn auxListHasAnyKey(list: *const AuxEventList, code: u16) bool {
    return auxListHasKey(list, code, true) or auxListHasKey(list, code, false);
}

test "e2e gesture: tap-only key delays aux release" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_X" }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = 1_000_000_000;
    const ev_press = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    try testing.expectEqual(@as(usize, 0), ev_press.aux.len); // nothing on press
    // source button suppressed (gesture engine is the sole emitter)
    try testing.expectEqual(@as(u64, 0), ev_press.gamepad.buttons & btnMask(.A));

    const ev_rel = try m.apply(.{ .buttons = 0 }, 16, t0 + 30 * std.time.ns_per_ms);
    try testing.expect(auxHasKey(ev_rel, keyCode("KEY_X"), true));
    try testing.expect(!auxHasKey(ev_rel, keyCode("KEY_X"), false));

    const aux_release = m.onMacroTimerExpired(t0 + 70 * std.time.ns_per_ms);
    try testing.expect(auxListHasKey(&aux_release, keyCode("KEY_X"), false));
    try testing.expect(!auxListHasKey(&aux_release, keyCode("KEY_X"), true));
}

test "e2e gesture: repeated same key tap refreshes delayed aux release" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_J" }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const key_j = keyCode("KEY_J");
    const t0: i128 = 1_000_000_000;

    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    const first_release = try m.apply(.{ .buttons = 0 }, 16, t0 + 10 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxKeyCount(first_release, key_j, true));
    try testing.expectEqual(@as(usize, 0), auxKeyCount(first_release, key_j, false));

    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0 + 20 * std.time.ns_per_ms);
    const second_release = try m.apply(.{ .buttons = 0 }, 16, t0 + 25 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxKeyCount(second_release, key_j, false));
    try testing.expectEqual(@as(usize, 1), auxKeyCount(second_release, key_j, true));

    const old_release_deadline = m.onMacroTimerExpired(t0 + 45 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 0), old_release_deadline.len);

    const final_release = m.onMacroTimerExpired(t0 + 60 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxListKeyCount(&final_release, key_j, false));
    try testing.expectEqual(@as(usize, 0), auxListKeyCount(&final_release, key_j, true));
}

test "e2e gesture: hold key fires at deadline and releases on button up" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_X", hold = "KEY_Y", hold_ms = 300 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    // hold deadline armed on the shared macro timer queue; drive expiry while held
    const aux_exp = m.onMacroTimerExpired(t0 + 300 * std.time.ns_per_ms);
    var saw_hold_press = false;
    for (aux_exp.slice()) |e| switch (e) {
        .key => |k| if (k.code == keyCode("KEY_Y") and k.pressed) {
            saw_hold_press = true;
        },
        else => {},
    };
    try testing.expect(saw_hold_press);

    // release button -> hold key release
    const ev_rel = try m.apply(.{ .buttons = 0 }, 16, t0 + 500 * std.time.ns_per_ms);
    try testing.expect(auxHasKey(ev_rel, keyCode("KEY_Y"), false));
    // tap must NOT fire when hold consumed the gesture
    try testing.expect(!auxHasKey(ev_rel, keyCode("KEY_X"), true));
}

test "e2e gesture regression: tap+hold KEY_J release is delayed to timer tick" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_J", hold = "KEY_K", hold_ms = 300 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const key_j = keyCode("KEY_J");
    const key_k = keyCode("KEY_K");
    const t0: i128 = 1_000_000_000;

    const ev_press = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    try testing.expectEqual(@as(usize, 0), ev_press.aux.len);
    try testing.expectEqual(@as(u64, 0), ev_press.gamepad.buttons & btnMask(.A));

    const ev_release = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxKeyCount(ev_release, key_j, true));
    try testing.expectEqual(@as(usize, 0), auxKeyCount(ev_release, key_j, false));
    try testing.expect(!auxHasAnyKey(ev_release, key_k));

    const early_timer = m.onMacroTimerExpired(t0 + 60 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 0), early_timer.len);

    const aux_release = m.onMacroTimerExpired(t0 + 80 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxListKeyCount(&aux_release, key_j, false));
    try testing.expectEqual(@as(usize, 0), auxListKeyCount(&aux_release, key_j, true));
    try testing.expect(!auxListHasAnyKey(&aux_release, key_k));
}

test "e2e gesture: releaseHeldAux releases held key before reset" {
    const allocator = testing.allocator;
    var old_ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_X", hold = "KEY_Y", hold_ms = 300 }
    , allocator);
    defer old_ctx.deinit();
    var old = &old_ctx.mapper;

    const t0: i128 = 1_000_000_000;
    _ = try old.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    _ = old.onMacroTimerExpired(t0 + 300 * std.time.ns_per_ms);

    const release = old.releaseHeldAux();
    const wrapper = mapper_mod.OutputEvents{ .gamepad = .{}, .prev = .{}, .aux = release };
    try testing.expect(auxHasKey(wrapper, keyCode("KEY_Y"), false));
}

test "e2e gesture: double fires on second press inside window" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_X", double = "KEY_Z", double_ms = 250 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    const ev_r1 = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);
    // tap deferred while the double window is open
    try testing.expect(!auxHasKey(ev_r1, keyCode("KEY_X"), true));

    const ev_p2 = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0 + 100 * std.time.ns_per_ms);
    try testing.expect(auxHasKey(ev_p2, keyCode("KEY_Z"), true));
    try testing.expect(!auxHasKey(ev_p2, keyCode("KEY_Z"), false));

    const aux_release = m.onMacroTimerExpired(t0 + 140 * std.time.ns_per_ms);
    try testing.expect(auxListHasKey(&aux_release, keyCode("KEY_Z"), false));
    try testing.expect(!auxListHasKey(&aux_release, keyCode("KEY_Z"), true));
}

test "e2e gesture: double-window timeout collapses to single tap" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_X", double = "KEY_Z", double_ms = 250 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    _ = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);
    // double window expires with no second press -> single tap
    const aux_exp = m.onMacroTimerExpired(t0 + 300 * std.time.ns_per_ms);
    var saw_tap_press = false;
    for (aux_exp.slice()) |e| switch (e) {
        .key => |k| if (k.code == keyCode("KEY_X") and k.pressed) {
            saw_tap_press = true;
        },
        else => {},
    };
    try testing.expect(saw_tap_press);
    try testing.expect(!auxListHasKey(&aux_exp, keyCode("KEY_X"), false));

    const aux_release = m.onMacroTimerExpired(t0 + 340 * std.time.ns_per_ms);
    try testing.expect(auxListHasKey(&aux_release, keyCode("KEY_X"), false));
    try testing.expect(!auxListHasKey(&aux_release, keyCode("KEY_X"), true));
}

test "e2e gesture regression: tap+double KEY_J timeout release is delayed to timer tick" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "KEY_J", double = "KEY_K", double_ms = 250 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const key_j = keyCode("KEY_J");
    const key_k = keyCode("KEY_K");
    const t0: i128 = 1_000_000_000;

    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    const ev_release = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 0), auxKeyCount(ev_release, key_j, true));
    try testing.expectEqual(@as(usize, 0), auxKeyCount(ev_release, key_j, false));
    try testing.expect(!auxHasAnyKey(ev_release, key_k));

    const aux_timeout = m.onMacroTimerExpired(t0 + 300 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxListKeyCount(&aux_timeout, key_j, true));
    try testing.expectEqual(@as(usize, 0), auxListKeyCount(&aux_timeout, key_j, false));
    try testing.expect(!auxListHasAnyKey(&aux_timeout, key_k));

    const aux_release = m.onMacroTimerExpired(t0 + 340 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), auxListKeyCount(&aux_release, key_j, false));
    try testing.expectEqual(@as(usize, 0), auxListKeyCount(&aux_release, key_j, true));
    try testing.expect(!auxListHasAnyKey(&aux_release, key_k));
}

test "e2e gesture issue 492: timer-origin tap is independent of physical report cadence" {
    const allocator = testing.allocator;

    for ([_]u32{ 2, 4, 8, 16 }) |cadence_ms| {
        for ([_]bool{ false, true }) |with_followup| {
            var ctx = try makeMapper(
                \\[remap]
                \\A = { tap = "B", double = "Y", double_ms = 250 }
            , allocator);
            defer ctx.deinit();
            var m = &ctx.mapper;

            const t0: i128 = 1_000_000_000;
            _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
            _ = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);

            // The double window timeout resolves the single tap. The virtual
            // press must be emitted by this timer wakeup, even with no later
            // physical input report.
            const press_ns = t0 + 300 * std.time.ns_per_ms;
            const press = m.onMacroTimerExpiredEvents(press_ns);
            try testing.expect(press.gamepad != null);
            try testing.expectEqual(btnMask(.B), press.gamepad.?.buttons & btnMask(.B));

            if (with_followup) {
                var elapsed_ms = cadence_ms;
                while (elapsed_ms < 119) : (elapsed_ms += cadence_ms) {
                    const followup = try m.apply(
                        .{ .buttons = 0 },
                        cadence_ms,
                        press_ns + @as(i128, elapsed_ms) * std.time.ns_per_ms,
                    );
                    try testing.expectEqual(btnMask(.B), followup.gamepad.buttons & btnMask(.B));
                }
                const at_119 = try m.apply(.{ .buttons = 0 }, 1, press_ns + 119 * std.time.ns_per_ms);
                try testing.expectEqual(btnMask(.B), at_119.gamepad.buttons & btnMask(.B));
            }

            const before_release = m.onMacroTimerExpiredEvents(press_ns + 119 * std.time.ns_per_ms);
            try testing.expect(before_release.gamepad == null);
            const release = m.onMacroTimerExpiredEvents(press_ns + 120 * std.time.ns_per_ms);
            try testing.expect(release.gamepad != null);
            try testing.expectEqual(@as(u64, 0), release.gamepad.?.buttons & btnMask(.B));
        }
    }
}

const TimedGamepadFrame = struct {
    at_ms: u32,
    gamepad: GamepadState,
};

fn periodicSamplerObservesMapperPulse(
    frames: []const TimedGamepadFrame,
    mask: u64,
    period_ms: u32,
    phase_ms: u32,
) bool {
    std.debug.assert(frames.len > 0);
    var sample_ms = phase_ms;
    const end_ms = frames[frames.len - 1].at_ms;
    while (sample_ms <= end_ms) : (sample_ms += period_ms) {
        var last = frames[0].gamepad;
        for (frames[1..]) |frame| {
            if (frame.at_ms > sample_ms) break;
            last = frame.gamepad;
        }
        if ((last.buttons & mask) != 0) return true;
    }
    return false;
}

test "e2e gesture issue 492: edge-origin gamepad tap remains pressed for 120ms" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\LS = { tap = "LS", hold = "KEY_Z", hold_ms = 1000 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ls = btnMask(.LS);
    const t0: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = ls }, 16, t0);
    const press_ns = t0 + 333 * std.time.ns_per_ms;
    const tap = try m.apply(.{ .buttons = 0 }, 16, press_ns);
    try testing.expectEqual(ls, tap.gamepad.buttons & ls);
    const followup = try m.apply(.{ .buttons = 0 }, 1, press_ns + std.time.ns_per_ms);
    try testing.expectEqual(ls, followup.gamepad.buttons & ls);

    // The old 30 ms auxiliary-tap lifetime expires here. A gamepad tap needs a
    // dedicated lifetime long enough to cross slower consumer polling phases.
    const before_release = m.onMacroTimerExpiredEvents(press_ns + 119 * std.time.ns_per_ms);
    try testing.expect(before_release.gamepad == null);

    const release = m.onMacroTimerExpiredEvents(press_ns + 120 * std.time.ns_per_ms);
    try testing.expect(release.gamepad != null);
    try testing.expectEqual(@as(u64, 0), release.gamepad.?.buttons & ls);

    const frames = [_]TimedGamepadFrame{
        .{ .at_ms = 0, .gamepad = .{} },
        .{ .at_ms = 333, .gamepad = tap.gamepad },
        .{ .at_ms = 334, .gamepad = followup.gamepad },
        .{ .at_ms = 453, .gamepad = release.gamepad.? },
    };

    // Sample the last real Mapper output frame at each consumer tick. A 120 ms
    // state lifetime crosses every phase, including the 100 ms boundary.
    for ([_]u32{ 8, 16, 33, 50, 100 }) |period_ms| {
        for (0..period_ms) |phase_ms| {
            try testing.expect(periodicSamplerObservesMapperPulse(
                &frames,
                ls,
                period_ms,
                @intCast(phase_ms),
            ));
        }
    }
}

test "e2e gesture issue 492: rapid repeated stick-click taps keep distinct edges" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\LS = { tap = "LS", hold = "KEY_Z" }
        \\RS = { tap = "RS", hold = "KEY_Z" }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    for ([_]ButtonId{ .LS, .RS }, 0..) |button, iteration| {
        const t0: i128 = 1_000_000_000 + @as(i128, @intCast(iteration)) * 200 * std.time.ns_per_ms;
        const mask = btnMask(button);

        // First physical click resolves to a virtual stick-click press.
        _ = try m.apply(.{ .buttons = mask }, 16, t0);
        const first_tap = try m.apply(.{ .buttons = 0 }, 16, t0 + 10 * std.time.ns_per_ms);
        try testing.expectEqual(mask, first_tap.gamepad.buttons & mask);

        // A second physical click starts before the first tap's minimum pulse
        // has elapsed. It must end the first virtual click so consumers observe
        // a release edge before the second virtual press; otherwise both
        // physical clicks collapse into one long virtual press.
        const second_press = try m.apply(.{ .buttons = mask }, 16, t0 + 20 * std.time.ns_per_ms);
        try testing.expectEqual(@as(u64, 0), second_press.gamepad.buttons & mask);

        const second_tap = try m.apply(.{ .buttons = 0 }, 16, t0 + 25 * std.time.ns_per_ms);
        try testing.expectEqual(mask, second_tap.gamepad.buttons & mask);

        // The cancelled first deadline must not release the second tap early.
        const stale_release = m.onMacroTimerExpiredEvents(t0 + 131 * std.time.ns_per_ms);
        try testing.expect(stale_release.gamepad == null);

        const final_release = m.onMacroTimerExpiredEvents(t0 + 145 * std.time.ns_per_ms);
        try testing.expect(final_release.gamepad != null);
        try testing.expectEqual(@as(u64, 0), final_release.gamepad.?.buttons & mask);
    }
}

test "e2e gesture issue 492: rising edge cancels old tap after layer changes target kind" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "B", hold = "KEY_Z", hold_ms = 1000 }
        \\
        \\[[layer]]
        \\name = "fn"
        \\trigger = "LB"
        \\activation = "toggle"
        \\
        \\[layer.remap]
        \\A = "X"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = std.time.ns_per_s;
    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    const old_tap = try m.apply(.{ .buttons = 0 }, 16, t0 + 10 * std.time.ns_per_ms);
    try testing.expectEqual(btnMask(.B), old_tap.gamepad.buttons & btnMask(.B));

    _ = try m.apply(.{ .buttons = btnMask(.LB) }, 16, t0 + 20 * std.time.ns_per_ms);
    const layer_on = try m.apply(.{ .buttons = 0 }, 16, t0 + 30 * std.time.ns_per_ms);
    try testing.expectEqual(btnMask(.B), layer_on.gamepad.buttons & btnMask(.B));

    // A is now a plain gamepad remap. Its rising edge must still terminate the
    // old gesture-owned B pulse before emitting X.
    const remapped_press = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0 + 40 * std.time.ns_per_ms);
    try testing.expectEqual(@as(u64, 0), remapped_press.gamepad.buttons & btnMask(.B));
    try testing.expectEqual(btnMask(.X), remapped_press.gamepad.buttons & btnMask(.X));

    const stale_release = m.onMacroTimerExpiredEvents(t0 + 130 * std.time.ns_per_ms);
    try testing.expect(stale_release.gamepad == null);
}

test "e2e gesture issue 492: different sources sharing a target retain independent releases" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\LS = { tap = "A", hold = "KEY_Z" }
        \\RS = { tap = "A", hold = "KEY_Z" }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = std.time.ns_per_s;
    _ = try m.apply(.{ .buttons = btnMask(.LS) }, 16, t0);
    const first = try m.apply(.{ .buttons = 0 }, 16, t0 + 10 * std.time.ns_per_ms);
    try testing.expectEqual(btnMask(.A), first.gamepad.buttons & btnMask(.A));

    _ = try m.apply(.{ .buttons = btnMask(.RS) }, 16, t0 + 20 * std.time.ns_per_ms);
    const second = try m.apply(.{ .buttons = 0 }, 16, t0 + 30 * std.time.ns_per_ms);
    try testing.expectEqual(btnMask(.A), second.gamepad.buttons & btnMask(.A));

    // LS expires first, but RS still owns the same virtual A target.
    const first_release = m.onMacroTimerExpiredEvents(t0 + 130 * std.time.ns_per_ms);
    try testing.expect(first_release.gamepad != null);
    try testing.expectEqual(btnMask(.A), first_release.gamepad.?.buttons & btnMask(.A));

    const final_release = m.onMacroTimerExpiredEvents(t0 + 150 * std.time.ns_per_ms);
    try testing.expect(final_release.gamepad != null);
    try testing.expectEqual(@as(u64, 0), final_release.gamepad.?.buttons & btnMask(.A));
}

test "e2e gesture issue 492: timer-origin LT and RT taps include analog floors" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "LT", double = "X", double_ms = 250 }
        \\B = { tap = "RT", double = "Y", double_ms = 250 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    for ([_]struct { src: ButtonId, dst: ButtonId, use_lt: bool }{
        .{ .src = .A, .dst = .LT, .use_lt = true },
        .{ .src = .B, .dst = .RT, .use_lt = false },
    }, 0..) |case, index| {
        const t0 = std.time.ns_per_s + @as(i128, @intCast(index)) * std.time.ns_per_s;
        _ = try m.apply(.{ .buttons = btnMask(case.src) }, 16, t0);
        _ = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);

        const press = m.onMacroTimerExpiredEvents(t0 + 300 * std.time.ns_per_ms);
        try testing.expect(press.gamepad != null);
        try testing.expectEqual(btnMask(case.dst), press.gamepad.?.buttons & btnMask(case.dst));
        if (case.use_lt) {
            try testing.expectEqual(@as(u8, 255), press.gamepad.?.lt);
        } else {
            try testing.expectEqual(@as(u8, 255), press.gamepad.?.rt);
        }

        const release = m.onMacroTimerExpiredEvents(t0 + 420 * std.time.ns_per_ms);
        try testing.expect(release.gamepad != null);
        try testing.expectEqual(@as(u64, 0), release.gamepad.?.buttons & btnMask(case.dst));
        if (case.use_lt) {
            try testing.expectEqual(@as(u8, 0), release.gamepad.?.lt);
        } else {
            try testing.expectEqual(@as(u8, 0), release.gamepad.?.rt);
        }
    }
}

test "e2e gesture issue 492: edge-origin LT and RT taps keep bit and analog floor for 120ms" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "LT", hold = "KEY_Z", hold_ms = 1000 }
        \\B = { tap = "RT", hold = "KEY_Z", hold_ms = 1000 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    for ([_]struct { src: ButtonId, dst: ButtonId, use_lt: bool }{
        .{ .src = .A, .dst = .LT, .use_lt = true },
        .{ .src = .B, .dst = .RT, .use_lt = false },
    }, 0..) |case, index| {
        const t0 = std.time.ns_per_s + @as(i128, @intCast(index)) * std.time.ns_per_s;
        _ = try m.apply(.{ .buttons = btnMask(case.src) }, 16, t0);
        const press_ns = t0 + 10 * std.time.ns_per_ms;
        const press = try m.apply(.{ .buttons = 0 }, 16, press_ns);
        try testing.expectEqual(btnMask(case.dst), press.gamepad.buttons & btnMask(case.dst));
        if (case.use_lt) {
            try testing.expectEqual(@as(u8, 255), press.gamepad.lt);
        } else {
            try testing.expectEqual(@as(u8, 255), press.gamepad.rt);
        }

        const early = try m.apply(.{ .buttons = 0 }, 1, press_ns + std.time.ns_per_ms);
        const at_119 = try m.apply(.{ .buttons = 0 }, 118, press_ns + 119 * std.time.ns_per_ms);
        for ([_]GamepadState{ early.gamepad, at_119.gamepad }) |frame| {
            try testing.expectEqual(btnMask(case.dst), frame.buttons & btnMask(case.dst));
            if (case.use_lt) {
                try testing.expectEqual(@as(u8, 255), frame.lt);
            } else {
                try testing.expectEqual(@as(u8, 255), frame.rt);
            }
        }

        const release = m.onMacroTimerExpiredEvents(press_ns + 120 * std.time.ns_per_ms);
        try testing.expect(release.gamepad != null);
        try testing.expectEqual(@as(u64, 0), release.gamepad.?.buttons & btnMask(case.dst));
        if (case.use_lt) {
            try testing.expectEqual(@as(u8, 0), release.gamepad.?.lt);
        } else {
            try testing.expectEqual(@as(u8, 0), release.gamepad.?.rt);
        }
    }
}

test "e2e gesture issue 492: timer-origin gamepad hold emits without a followup report" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "X", hold = "RB", hold_ms = 100 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = std.time.ns_per_s;
    _ = try m.apply(.{ .buttons = btnMask(.A) }, 16, t0);
    const hold = m.onMacroTimerExpiredEvents(t0 + 100 * std.time.ns_per_ms);
    try testing.expect(hold.gamepad != null);
    try testing.expectEqual(btnMask(.RB), hold.gamepad.?.buttons & btnMask(.RB));
    try testing.expectEqual(@as(u64, 0), hold.gamepad.?.buttons & btnMask(.A));

    const release = try m.apply(.{ .buttons = 0 }, 16, t0 + 200 * std.time.ns_per_ms);
    try testing.expectEqual(@as(u64, 0), release.gamepad.buttons & btnMask(.RB));
}

test "e2e gesture issue 492: timer tap frames preserve last gyro joystick axes" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\
        \\[remap]
        \\A = { tap = "B", double = "Y", double_ms = 250 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const t0: i128 = std.time.ns_per_s;
    const physical_rx: i16 = 1234;
    const physical_ry: i16 = -2345;
    _ = try m.apply(.{
        .buttons = btnMask(.A),
        .gyro_x = 10000,
        .gyro_y = -12000,
        .rx = physical_rx,
        .ry = physical_ry,
    }, 16, t0);
    const last_apply = try m.apply(.{ .buttons = 0 }, 16, t0 + 40 * std.time.ns_per_ms);
    try testing.expect(last_apply.gamepad.rx != physical_rx);
    try testing.expect(last_apply.gamepad.ry != physical_ry);

    const tap_press = m.onMacroTimerExpiredEvents(t0 + 300 * std.time.ns_per_ms);
    try testing.expect(tap_press.gamepad != null);
    try testing.expectEqual(btnMask(.B), tap_press.gamepad.?.buttons & btnMask(.B));
    try testing.expectEqual(last_apply.gamepad.rx, tap_press.gamepad.?.rx);
    try testing.expectEqual(last_apply.gamepad.ry, tap_press.gamepad.?.ry);

    const tap_release = m.onMacroTimerExpiredEvents(t0 + 420 * std.time.ns_per_ms);
    try testing.expect(tap_release.gamepad != null);
    try testing.expectEqual(last_apply.gamepad.rx, tap_release.gamepad.?.rx);
    try testing.expectEqual(last_apply.gamepad.ry, tap_release.gamepad.?.ry);
}

test "e2e gesture issue 492: LS and RS duration sweep classifies every sub-threshold press as tap" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\LS = { tap = "LS", hold = "KEY_Z", hold_ms = 300 }
        \\RS = { tap = "RS", hold = "KEY_Z", hold_ms = 300 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var now_ns: i128 = std.time.ns_per_s;
    for ([_]ButtonId{ .LS, .RS }) |button| {
        const mask = btnMask(button);
        var duration_ms: u32 = 1;
        while (duration_ms < 300) : (duration_ms += 1) {
            const press = try m.apply(.{ .buttons = mask }, 16, now_ns);
            try testing.expectEqual(@as(u64, 0), press.gamepad.buttons & mask);

            const release_ns = now_ns + @as(i128, duration_ms) * std.time.ns_per_ms;
            const release = try m.apply(.{ .buttons = 0 }, 16, release_ns);
            try testing.expectEqual(mask, release.gamepad.buttons & mask);
            try testing.expect(!auxHasAnyKey(release, keyCode("KEY_Z")));

            const before_timer = m.onMacroTimerExpiredEvents(release_ns + 119 * std.time.ns_per_ms);
            try testing.expect(before_timer.gamepad == null);

            const timer = m.onMacroTimerExpiredEvents(release_ns + 120 * std.time.ns_per_ms);
            try testing.expect(timer.gamepad != null);
            try testing.expectEqual(@as(u64, 0), timer.gamepad.?.buttons & mask);
            try testing.expect(!auxListHasAnyKey(&timer.aux, keyCode("KEY_Z")));

            now_ns = release_ns + 130 * std.time.ns_per_ms;
        }
    }
}

test "e2e gesture issue 492: LS and RS at hold deadline select KEY_Z and never tap" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\LS = { tap = "LS", hold = "KEY_Z", hold_ms = 300 }
        \\RS = { tap = "RS", hold = "KEY_Z", hold_ms = 300 }
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    var now_ns: i128 = std.time.ns_per_s;
    for ([_]ButtonId{ .LS, .RS }) |button| {
        const mask = btnMask(button);
        _ = try m.apply(.{ .buttons = mask }, 16, now_ns);

        const hold = m.onMacroTimerExpiredEvents(now_ns + 300 * std.time.ns_per_ms);
        try testing.expect(hold.gamepad == null);
        try testing.expect(auxListHasKey(&hold.aux, keyCode("KEY_Z"), true));

        const release = try m.apply(.{ .buttons = 0 }, 16, now_ns + 301 * std.time.ns_per_ms);
        try testing.expectEqual(@as(u64, 0), release.gamepad.buttons & mask);
        try testing.expect(auxHasKey(release, keyCode("KEY_Z"), false));
        try testing.expect(!auxHasKey(release, keyCode("KEY_Z"), true));

        now_ns += 500 * std.time.ns_per_ms;
    }
}

test "e2e gesture back-compat: plain string remap A=KEY_F13 unchanged (immediate edge)" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(usize, 1), ev.aux.len);
    switch (ev.aux.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_F13, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "e2e gesture back-compat: chord array remap A=[KEY_LEFTMETA,KEY_1] unchanged" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = ["KEY_LEFTMETA", "KEY_1"]
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // chord source button is suppressed via precompute; chord output is driven
    // by the chord pipeline, not the gesture engine — behaviour unchanged.
    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    try testing.expectEqual(@as(usize, 0), ev.aux.len);
}

// --- F-2: a resolved timer-origin gamepad tap survives a same-frame layer
// transition. Once emitted, its release token owns the lifetime independently
// of the gesture engine state reset caused by the layer transition.

test "gesture F-2: resolved single-tap gamepad bit survives same-frame layer toggle" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[remap]
        \\A = { tap = "B", double = "X", double_ms = 250 }
        \\
        \\[[layer]]
        \\name = "fn"
        \\trigger = "LB"
        \\activation = "toggle"
        \\
        \\[layer.remap]
        \\Y = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const lb_mask = btnMask(.LB);
    const b_bit = btnMask(.B);
    const ns_per_ms: i128 = std.time.ns_per_ms;
    const t0: i128 = 1_000_000_000;

    // Frame 1: A press (gesture wait_decide); LB press arms toggle.
    _ = try m.apply(.{ .buttons = btnMask(.A) | lb_mask }, 16, t0);

    // Frame 2: A release opens the double window; LB still held.
    _ = try m.apply(.{ .buttons = lb_mask }, 16, t0 + 40 * ns_per_ms);

    // Double window expires with no second press -> single tap "B" emitted.
    const tap = m.onMacroTimerExpiredEvents(t0 + 300 * ns_per_ms);
    try testing.expect(tap.gamepad != null);
    try testing.expectEqual(b_bit, tap.gamepad.?.buttons & b_bit);

    // Frame 3: LB released -> toggle flips -> layer active_changed. The resolved
    // tap must remain active for the rest of its timer-owned lifetime.
    const ev = try m.apply(.{ .buttons = 0 }, 16, t0 + 301 * ns_per_ms);
    try testing.expectEqual(b_bit, ev.gamepad.buttons & b_bit);

    const release = m.onMacroTimerExpiredEvents(t0 + 420 * ns_per_ms);
    try testing.expect(release.gamepad != null);
    try testing.expectEqual(@as(u64, 0), release.gamepad.?.buttons & b_bit);
}
