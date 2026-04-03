// Phase 2a end-to-end integration tests (L1 — mock timer/vtable, always CI).
//
// All tests drive the Mapper directly; no EventLoop thread is needed.
// Timer events are injected by calling m.layer.onTriggerPress() / m.layer.onTimerExpired()
// instead of using a real timerfd.

const std = @import("std");
const testing = std.testing;

const h = @import("helpers.zig");
const mapper_mod = @import("../core/mapper.zig");
const layer_mod = @import("../core/layer.zig");
const state_mod = @import("../core/state.zig");

const Mapper = mapper_mod.Mapper;
const AuxEvent = mapper_mod.AuxEvent;
const ButtonId = state_mod.ButtonId;
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
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // Mock timer expired → ACTIVE
    _ = m.layer.onTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Frame 2: A press while layer active → mouse_left aux event
    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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
    _ = m.layer.onTriggerRelease(null);
    try testing.expect(m.layer.tap_hold == null);
    const ev2 = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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
    _ = m.layer.onTriggerPress(configs[0].name, 200);

    // Frame 2: LT release before timer → tap event
    const tap_target = mapper_mod.resolveTarget("mouse_left") catch unreachable;
    const res = m.layer.onTriggerRelease(tap_target);
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event != null);
    try testing.expect(m.layer.tap_hold == null);

    // The tap target is mouse_left → BTN_LEFT
    switch (res.tap_event.?) {
        .mouse_button => |code| try testing.expectEqual(BTN_LEFT, code),
        else => return error.WrongTapEventType,
    }
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

    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired(); // ACTIVE

    const res = m.layer.onTriggerRelease(null);
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

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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
        \\sensitivity = 1000.0
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Large gyro value to ensure accumulation crosses integer threshold
    const ev = try m.apply(.{ .gyro_x = 10, .gyro_y = 10 }, 16);

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

    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000 }, 16);
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

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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

    const ev = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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

    const ev = try m.apply(.{ .buttons = btnMask(.RB) }, 16);
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
    const ev = try m.apply(.{ .buttons = buttons }, 16);

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
    const ev = try m.apply(.{ .dpad_y = -1 }, 16);
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
    _ = try m.apply(.{ .dpad_y = -1 }, 16);

    // Now dpad_y returns to 0 → KEY_UP release
    const ev = try m.apply(.{ .dpad_y = 0 }, 16);
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
    // Default mode is "gamepad"
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(.{ .dpad_y = -1 }, 16);
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

    const ev = try m.apply(.{ .dpad_y = -1 }, 16);
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
    const ev1 = try m.apply(.{ .buttons = btnMask(.B) }, 16);
    try testing.expect((ev1.gamepad.buttons & btnMask(.B)) != 0);

    // Layer activates (simulate timer)
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    // Frame N: B still held + layer ACTIVE → B suppressed in both current and masked_prev
    const ev2 = try m.apply(.{ .buttons = btnMask(.B) }, 16);
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
    _ = m.layer.processLayerTriggers(configs, sel, 0); // press
    _ = m.layer.processLayerTriggers(configs, 0, sel); // release → toggle on
    try testing.expect(m.layer.toggled.contains("fn"));

    // A press → KEY_F1 in aux
    const ev1 = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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
    _ = m.layer.processLayerTriggers(configs, sel, 0);
    _ = m.layer.processLayerTriggers(configs, 0, sel); // release → toggle off
    try testing.expect(!m.layer.toggled.contains("fn"));

    // A press now → A passes through on main device
    const ev2 = try m.apply(.{ .buttons = btnMask(.A) }, 16);
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

    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    // X pressed — not in layer remap, should fall through to base (KEY_F13)
    const ev = try m.apply(.{ .buttons = btnMask(.X) }, 16);
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

    const ev = try m.apply(.{ .buttons = btnMask(.M1) }, 16);
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

    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    // dpad_y = -1 → KEY_UP (arrows mode active via layer)
    const ev_up = try m.apply(.{ .dpad_y = -1 }, 16);
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
    const ev_down = try m.apply(.{ .dpad_y = 1 }, 16);
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
