// Phase 2c end-to-end integration tests (T7: L0/L1).
// Covers: multi-device parallel, macro playback, pause_for_release, hot-reload, layer macro cleanup.

const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const h = @import("helpers.zig");
const mapping = @import("../config/mapping.zig");
const mapper_mod = @import("../core/mapper.zig");
const state_mod = @import("../core/state.zig");
const macro_mod = @import("../core/macro.zig");
const macro_player_mod = @import("../core/macro_player.zig");
const timer_queue_mod = @import("../core/timer_queue.zig");
const device_mod = @import("../config/device.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const uinput = @import("../io/uinput.zig");

const Mapper = mapper_mod.Mapper;
const AuxEventList = mapper_mod.AuxEventList;
const ButtonId = state_mod.ButtonId;
const MacroStep = macro_mod.MacroStep;
const Macro = macro_mod.Macro;
const MacroPlayer = macro_player_mod.MacroPlayer;
const TimerQueue = timer_queue_mod.TimerQueue;

const KEY_B = h.KEY_B;
const KEY_LEFT = h.KEY_LEFT;
const KEY_LEFTSHIFT = h.KEY_LEFTSHIFT;

const btnMask = h.btnMask;
const makeMapper = h.makeMapper;

const minimal_device_toml =
    \\[device]
    \\name = "T"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

/// Minimal DeviceInstance wired to a MockDeviceIO, null output.
fn testInstance(
    allocator: std.mem.Allocator,
    mock: *MockDeviceIO,
    cfg: *const device_mod.DeviceConfig,
) !DeviceInstance {
    const devices = try allocator.alloc(@import("../io/device_io.zig").DeviceIO, 1);
    errdefer allocator.free(devices);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    return DeviceInstance{
        .allocator = allocator,
        .devices = devices,
        .loop = loop,
        .interp = @import("../core/interpreter.zig").Interpreter.init(cfg),
        .mapper = null,
        .uinput_dev = null,
        .aux_dev = null,
        .device_cfg = cfg,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
}

// --- T7.1-2: Multi-device parallel (L1) ---

test "macro: multi-device — stop(A) does not affect B" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    var inst_a = try testInstance(allocator, &mock_a, &parsed.value);
    defer {
        inst_a.loop.deinit();
        allocator.free(inst_a.devices);
    }
    var inst_b = try testInstance(allocator, &mock_b, &parsed.value);
    defer {
        inst_b.loop.deinit();
        allocator.free(inst_b.devices);
    }

    const RunFn = struct {
        fn run(i: *DeviceInstance) !void {
            try i.run();
        }
    };

    const ta = try std.Thread.spawn(.{}, RunFn.run, .{&inst_a});
    const tb = try std.Thread.spawn(.{}, RunFn.run, .{&inst_b});

    try h.waitRunning(&inst_a.loop);
    try h.waitRunning(&inst_b.loop);

    // Stop A; B should keep running.
    inst_a.stop();
    ta.join();

    try testing.expect(inst_a.stopped);
    try testing.expect(!inst_b.stopped);

    inst_b.stop();
    tb.join();
    try testing.expect(inst_b.stopped);
}

test "macro: multi-device — independent write sinks" {
    // Two instances share no output — writes to mock_a are not visible in mock_b.
    const allocator = testing.allocator;

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    try mock_a.deviceIO().write(&[_]u8{ 0xAA, 0xBB });

    try testing.expectEqualSlices(u8, &[_]u8{ 0xAA, 0xBB }, mock_a.write_log.items);
    try testing.expectEqual(@as(usize, 0), mock_b.write_log.items.len);
}

// --- T7.3-5: Macro playback (L0) ---

test "macro: macro playback — tap B, delay 50, tap LEFT sequence" {
    const allocator = testing.allocator;

    const steps = [_]MacroStep{
        .{ .tap = "KEY_B" },
        .{ .delay = 50 },
        .{ .tap = "KEY_LEFT" },
    };
    const m = Macro{ .name = "dodge_roll", .steps = &steps };
    var player = MacroPlayer.init(&m, 1);
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    // First step: tap B (press+release), then hits delay → not done.
    var aux1 = AuxEventList{};
    const done1 = try player.step(&aux1, &q);
    try testing.expect(!done1);
    // Two events: KEY_B press + release.
    try testing.expectEqual(@as(usize, 2), aux1.len);
    switch (aux1.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_B, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongType,
    }
    switch (aux1.get(1)) {
        .key => |k| {
            try testing.expectEqual(KEY_B, k.code);
            try testing.expect(!k.pressed);
        },
        else => return error.WrongType,
    }
    // Delay armed in queue.
    try testing.expectEqual(@as(usize, 1), q.heap.count());

    // Second step (after timer expiry): tap LEFT → done.
    var aux2 = AuxEventList{};
    const done2 = try player.step(&aux2, &q);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 2), aux2.len);
    switch (aux2.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_LEFT, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongType,
    }
    switch (aux2.get(1)) {
        .key => |k| {
            try testing.expectEqual(KEY_LEFT, k.code);
            try testing.expect(!k.pressed);
        },
        else => return error.WrongType,
    }
}

test "macro: pause_for_release — down LSHIFT, pause, no output until released" {
    const allocator = testing.allocator;

    const steps = [_]MacroStep{
        .{ .down = "KEY_LEFTSHIFT" },
        .pause_for_release,
        .{ .up = "KEY_LEFTSHIFT" },
    };
    const m = Macro{ .name = "shift_hold", .steps = &steps };
    var player = MacroPlayer.init(&m, 1);
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    // First step: down LSHIFT → press emitted, then pause_for_release → halts.
    var aux1 = AuxEventList{};
    const done1 = try player.step(&aux1, &q);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 1), aux1.len);
    switch (aux1.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_LEFTSHIFT, k.code);
            try testing.expect(k.pressed);
        },
        else => return error.WrongType,
    }
    try testing.expect(player.waiting_for_release);

    // Trigger held — no further output.
    var aux2 = AuxEventList{};
    const done2 = try player.step(&aux2, &q);
    try testing.expect(!done2);
    try testing.expectEqual(@as(usize, 0), aux2.len);

    // Release trigger → resume → up LSHIFT → done.
    player.notifyTriggerReleased();
    var aux3 = AuxEventList{};
    const done3 = try player.step(&aux3, &q);
    try testing.expect(done3);
    try testing.expectEqual(@as(usize, 1), aux3.len);
    switch (aux3.get(0)) {
        .key => |k| {
            try testing.expectEqual(KEY_LEFTSHIFT, k.code);
            try testing.expect(!k.pressed);
        },
        else => return error.WrongType,
    }
}

// --- T7.6: Layer switch clears active macros (L0) ---

test "macro: layer switch while macro active — held keys released, macros cleared" {
    const allocator = testing.allocator;

    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[[macro]]
        \\name = "shift_hold"
        \\steps = [
        \\  { down = "KEY_LEFTSHIFT" },
        \\  { delay = 5000 },
        \\  { up = "KEY_LEFTSHIFT" },
        \\]
        \\
        \\[remap]
        \\M1 = "macro:shift_hold"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Press M1 to start macro — down LSHIFT emitted, delay armed.
    const m1_mask = btnMask(.M1);
    _ = try m.apply(.{ .buttons = m1_mask }, 16);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

    // Now activate layer (LT hold) — active_changed fires → macros cleared, releases emitted.
    const configs = ctx.parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const ev = try m.apply(.{ .buttons = m1_mask }, 16);

    // active_macros must be empty after layer switch.
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);

    // At least one release event for KEY_LEFTSHIFT should be in aux.
    var found_shift_release = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_LEFTSHIFT and !k.pressed) {
                found_shift_release = true;
            },
            else => {},
        }
    }
    try testing.expect(found_shift_release);
}

// --- T7.7: Hot-reload — mapping replaced, new mapping effective (L0) ---

test "macro: hot-reload — updateMapping swaps config; next apply uses new mapping" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    // Initial mapping: M1 = "macro:dodge_roll".
    const initial_toml =
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = [{ tap = "KEY_B" }]
        \\
        \\[remap]
        \\M1 = "macro:dodge_roll"
    ;
    const parsed_initial = try mapping.parseString(allocator, initial_toml);
    defer parsed_initial.deinit();

    // New mapping: M1 = "KEY_A" (no macro).
    const new_toml =
        \\[remap]
        \\M1 = "KEY_A"
    ;
    var parsed_new = try mapping.parseString(allocator, new_toml);
    defer parsed_new.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const devices = try allocator.alloc(@import("../io/device_io.zig").DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    var inst = DeviceInstance{
        .allocator = allocator,
        .devices = devices,
        .loop = loop,
        .interp = @import("../core/interpreter.zig").Interpreter.init(&parsed_dev.value),
        .mapper = try Mapper.init(&parsed_initial.value, loop.timer_fd, allocator),
        .uinput_dev = null,
        .aux_dev = null,
        .device_cfg = &parsed_dev.value,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    defer {
        inst.mapper.?.deinit();
        inst.loop.deinit();
        allocator.free(inst.devices);
    }

    const RunFn = struct {
        fn run(i: *DeviceInstance) !void {
            try i.run();
        }
    };
    const thread = try std.Thread.spawn(.{}, RunFn.run, .{&inst});

    try h.waitRunning(&inst.loop);

    // Hot-swap: replace mapping with new_toml config.
    inst.updateMapping(&parsed_new.value);
    // poll until pending_mapping is consumed (applied on the next loop iteration)
    var w: usize = 0;
    while (w < 1000) : (w += 1) {
        if (@atomicLoad(?*mapping.MappingConfig, &inst.pending_mapping, .acquire) == null) break;
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }

    inst.stop();
    thread.join();

    // After hot-reload, inst.mapper.config must point to the new mapping.
    try testing.expectEqual(&parsed_new.value, inst.mapper.?.config);
    // pending_mapping consumed.
    try testing.expectEqual(@as(?*mapping.MappingConfig, null), inst.pending_mapping);

    // Verify new mapping: M1 press produces KEY_A, not macro.
    var m = &inst.mapper.?;
    const m1_mask = btnMask(.M1);
    const ev = try m.apply(.{ .buttons = m1_mask }, 16);

    // With new mapping M1 = "KEY_A", active_macros must be empty.
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);
    // M1 suppressed in gamepad output.
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & m1_mask);
    // KEY_A in aux.
    const KEY_A: u16 = 30;
    var found_key_a = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == KEY_A and k.pressed) {
                found_key_a = true;
            },
            else => {},
        }
    }
    try testing.expect(found_key_a);
}

// --- L0: macro trigger via Mapper.apply (regression guard) ---

test "macro: mapper macro trigger — M1=macro:dodge_roll press starts player" {
    const allocator = testing.allocator;

    var ctx = try makeMapper(
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = [{ tap = "KEY_B" }, { tap = "KEY_LEFT" }]
        \\
        \\[remap]
        \\M1 = "macro:dodge_roll"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Rising edge: M1 press → macro player added.
    const m1_mask = btnMask(.M1);
    const ev = try m.apply(.{ .buttons = m1_mask }, 16);
    _ = ev;

    // Macro player started and immediately ran synchronous steps (tap B + tap LEFT = 4 events).
    // Player is done (removed) since both taps are synchronous.
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);
}

test "macro: mapper macro trigger — no second player on held button (no re-trigger)" {
    const allocator = testing.allocator;

    var ctx = try makeMapper(
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = [{ tap = "KEY_B" }]
        \\
        \\[remap]
        \\M1 = "macro:dodge_roll"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const m1_mask = btnMask(.M1);
    // Frame 1: rising edge → macro starts and finishes.
    _ = try m.apply(.{ .buttons = m1_mask }, 16);
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);

    // Frame 2: still held → no new player (no rising edge).
    _ = try m.apply(.{ .buttons = m1_mask }, 16);
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);
}
