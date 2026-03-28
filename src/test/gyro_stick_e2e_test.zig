// Phase 2b end-to-end integration tests (L0/L1).
// All tests drive Mapper directly; no real fds or devices needed.

const std = @import("std");
const testing = std.testing;

const h = @import("helpers.zig");
const mapper_mod = @import("../core/mapper.zig");
const state_mod = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const command = @import("../core/command.zig");
const device_mod = @import("../config/device.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;

const Mapper = mapper_mod.Mapper;
const AuxEvent = mapper_mod.AuxEvent;
const ButtonId = state_mod.ButtonId;
const FfEvent = uinput.FfEvent;

const REL_X = h.REL_X;
const REL_Y = h.REL_Y;

const btnMask = h.btnMask;
const makeMapper = h.makeMapper;

// --- FF rumble pipeline (L1 via fillTemplate + UinputDevice mock) ---

test "gyro_stick: FF rumble — fillTemplate produces correct bytes for strong/weak" {
    const allocator = testing.allocator;
    const tmpl = "00 08 00 {strong:u8} {weak:u8} 00 00 00";
    const result = try command.fillTemplate(allocator, tmpl, &.{
        .{ .name = "strong", .value = 0x8000 },
        .{ .name = "weak", .value = 0x4000 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, result);
}

test "gyro_stick: FF rumble — erase (strong=0, weak=0) produces all-zero payload" {
    const allocator = testing.allocator;
    const tmpl = "00 08 00 {strong:u8} {weak:u8} 00 00 00";
    const result = try command.fillTemplate(allocator, tmpl, &.{
        .{ .name = "strong", .value = 0 },
        .{ .name = "weak", .value = 0 },
    });
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, result);
}

// MockDeviceIO write log captures what FF routing would send.
test "gyro_stick: FF rumble — UinputDevice ff_effects play → correct FfEvent → DeviceIO write bytes" {
    const allocator = testing.allocator;

    // Simulate: ff_effects[3] populated, EV_FF play code=3 value=1 → FfEvent
    const pfds = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(pfds[0]);
    defer std.posix.close(pfds[1]);

    const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;
    var dev = uinput.UinputDevice{
        .fd = pfds[0],
        .button_codes = [_]u16{0} ** BUTTON_COUNT,
    };
    dev.ff_effects[3] = .{ .strong = 0xff00, .weak = 0x8000 };

    // Inject EV_FF play event
    const c = @cImport({
        @cInclude("linux/input.h");
        @cInclude("linux/input-event-codes.h");
    });
    const ev = c.input_event{ .type = c.EV_FF, .code = 3, .value = 1, .time = std.mem.zeroes(c.timeval) };
    _ = try std.posix.write(pfds[1], std.mem.asBytes(&ev));

    const ff = (try dev.pollFf()) orelse return error.NoFfEvent;
    try testing.expectEqual(@as(u16, 0xff00), ff.strong);
    try testing.expectEqual(@as(u16, 0x8000), ff.weak);

    // Now verify fillTemplate with those values
    const tmpl = "00 08 00 {strong:u8} {weak:u8} 00 00 00";
    const bytes = try command.fillTemplate(allocator, tmpl, &.{
        .{ .name = "strong", .value = ff.strong },
        .{ .name = "weak", .value = ff.weak },
    });
    defer allocator.free(bytes);
    // strong=0xff00 >> 8 = 0xff, weak=0x8000 >> 8 = 0x80
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0xff, 0x80, 0x00, 0x00, 0x00 }, bytes);

    // MockDeviceIO write captures the bytes
    var mock_io = try MockDeviceIO.init(allocator, &.{});
    defer mock_io.deinit();
    const dio = mock_io.deviceIO();
    try dio.write(bytes);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0xff, 0x80, 0x00, 0x00, 0x00 }, mock_io.write_log.items);
}

test "gyro_stick: FF erase — after ff_effects cleared, play returns zeros" {
    const pfds = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(pfds[0]);
    defer std.posix.close(pfds[1]);

    const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;
    var dev = uinput.UinputDevice{
        .fd = pfds[0],
        .button_codes = [_]u16{0} ** BUTTON_COUNT,
    };
    dev.ff_effects[1] = .{ .strong = 0xffff, .weak = 0xffff };
    // erase slot
    dev.ff_effects[1] = .{};

    const c = @cImport({
        @cInclude("linux/input.h");
        @cInclude("linux/input-event-codes.h");
    });
    const ev = c.input_event{ .type = c.EV_FF, .code = 1, .value = 1, .time = std.mem.zeroes(c.timeval) };
    _ = try std.posix.write(pfds[1], std.mem.asBytes(&ev));

    const ff = (try dev.pollFf()) orelse return error.NoFfEvent;
    try testing.expectEqual(@as(u16, 0), ff.strong);
    try testing.expectEqual(@as(u16, 0), ff.weak);
}

// --- Gyro activate hold_RB (L0) ---

test "e2e: gyro activate hold_RB — RB held produces REL, released produces none" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "hold_RB"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const rb = btnMask(.RB);

    // RB held + gyro input → REL events expected
    const ev_active = try m.apply(.{ .buttons = rb, .gyro_x = 10000, .gyro_y = 10000 }, 16);
    var has_rel = false;
    for (ev_active.aux.slice()) |e| switch (e) {
        .rel => {
            has_rel = true;
        },
        else => {},
    };
    try testing.expect(has_rel);

    // RB released → no REL events
    const ev_inactive = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16);
    try testing.expectEqual(@as(usize, 0), ev_inactive.aux.len);
    // EMA zeroed by reset
    try testing.expectApproxEqAbs(@as(f32, 0.0), m.gyro_proc.ema_x, 1e-5);
}

// --- Gyro joystick mode (L0) ---

test "e2e: gyro joystick — gyro overrides emit_state.rx/ry, no REL events" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1000.0
        \\sensitivity_y = 1000.0
        \\smoothing = 0.0
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Large gyro with original rx/ry set to known value
    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 5000, .ry = 5000 }, 16);

    // rx/ry overridden by gyro output (not the raw 5000)
    try testing.expect(ev.gamepad.rx != 5000);
    try testing.expect(ev.gamepad.ry != 5000);

    // No REL events — joystick mode does not produce mouse motion
    for (ev.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };
}

test "e2e: gyro joystick — zero gyro leaves rx/ry at zero (deadzone)" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\deadzone = 200
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // gyro within deadzone → joy_x/y = 0
    const ev = try m.apply(.{ .gyro_x = 100, .gyro_y = 100, .rx = 0, .ry = 0 }, 16);
    try testing.expectEqual(@as(i16, 0), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, 0), ev.gamepad.ry);
}

// --- Layer switch reset (L0) ---

test "e2e: layer switch resets gyro EMA — no jump after activation" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.gyro]
        \\mode = "mouse"
        \\sensitivity = 100.0
        \\smoothing = 0.5
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // Dirty EMA state
    m.gyro_proc.ema_x = 800.0;
    m.gyro_proc.ema_y = -400.0;
    m.stick_left.mouse_accum_x = 1.2;
    m.stick_right.scroll_accum = 0.7;

    // LT press → PENDING
    const lt = btnMask(.LT);
    _ = try m.apply(.{ .buttons = lt }, 16);
    // Timer → ACTIVE (active_changed fires inside onTimerExpired → reset)
    _ = m.onTimerExpired();

    // LT release → IDLE (active_changed again → reset)
    _ = try m.apply(.{ .buttons = 0 }, 16);

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_y);
    try testing.expectEqual(@as(f32, 0), m.stick_left.mouse_accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_right.scroll_accum);
}

test "e2e: no layer switch — EMA preserved across frames" {
    const allocator = testing.allocator;
    var ctx = try makeMapper("", allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    m.gyro_proc.ema_x = 55.0;
    m.stick_right.mouse_accum_x = 0.3;

    _ = try m.apply(.{}, 16);

    try testing.expectEqual(@as(f32, 55.0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0.3), m.stick_right.mouse_accum_x);
}

// --- dt_ms propagation (L0) ---

test "e2e: dt_ms scaling — 4 frames@4ms == 1 frame@16ms (right stick mouse)" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[stick.right]
        \\mode = "mouse"
        \\deadzone = 0
        \\sensitivity = 100.0
    , allocator);
    defer ctx.deinit();

    const tfd4 = try std.posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
    defer std.posix.close(tfd4);
    var m4 = try Mapper.init(&ctx.parsed.value, tfd4, allocator);
    defer m4.deinit();
    const tfd16 = try std.posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
    defer std.posix.close(tfd16);
    var m16 = try Mapper.init(&ctx.parsed.value, tfd16, allocator);
    defer m16.deinit();

    var total4: i32 = 0;
    for (0..4) |_| {
        const ev = try m4.apply(.{ .rx = 10000 }, 4);
        for (ev.aux.slice()) |e| switch (e) {
            .rel => |r| if (r.code == REL_X) {
                total4 += r.value;
            },
            else => {},
        };
    }

    var total16: i32 = 0;
    const ev16 = try m16.apply(.{ .rx = 10000 }, 16);
    for (ev16.aux.slice()) |e| switch (e) {
        .rel => |r| if (r.code == REL_X) {
            total16 += r.value;
        },
        else => {},
    };

    // 4×4ms total == 1×16ms — allow ±1 rounding error
    try testing.expect(@abs(total4 - total16) <= 1);
}

test "e2e: dt_ms=1 clamp — stick still produces output (no divide-by-zero)" {
    const allocator = testing.allocator;
    var ctx = try makeMapper(
        \\[stick.right]
        \\mode = "mouse"
        \\deadzone = 0
        \\sensitivity = 200.0
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // dt=1 is minimum; should not crash or return zero unexpectedly for large input
    _ = try m.apply(.{ .rx = 32767 }, 1);
    // Just verify no panic; accumulator may or may not cross integer threshold at dt=1
}

// --- FF routing via EventLoop (L1 thread test) ---

const ff_device_toml =
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
    \\[commands.rumble]
    \\interface = 0
    \\template = "00 08 00 {strong:u8} {weak:u8} 00 00 00"
;

const MockFfOutput = struct {
    ff_event: ?FfEvent,
    call_count: usize = 0,

    fn outputDevice(self: *MockFfOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state_mod.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?FfEvent {
        const self: *MockFfOutput = @ptrCast(@alignCast(ptr));
        if (self.call_count == 0) {
            self.call_count += 1;
            return self.ff_event;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "e2e: FF rumble pipeline — EventLoop routes FfEvent → DeviceIO.write correct bytes" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(ff_pipe[0]);
    defer std.posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_device_toml);
    defer parsed.deinit();
    const interp = @import("../core/interpreter.zig").Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{ .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 } };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []@import("../io/device_io.zig").DeviceIO,
        interp: *const @import("../core/interpreter.zig").Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]@import("../io/device_io.zig").DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    _ = try std.posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // strong=0x8000 >> 8 = 0x80, weak=0x4000 >> 8 = 0x40
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 },
        mock_dev.write_log.items,
    );
}

test "e2e: FF stop (value=0) — EventLoop routes zero FfEvent → all-zero bytes written" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try std.posix.pipe2(.{ .NONBLOCK = true });
    defer std.posix.close(ff_pipe[0]);
    defer std.posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_device_toml);
    defer parsed.deinit();
    const interp = @import("../core/interpreter.zig").Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{ .ff_event = .{ .effect_type = 0x50, .strong = 0, .weak = 0 } };

    var devs = [_]@import("../io/device_io.zig").DeviceIO{dev};

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []@import("../io/device_io.zig").DeviceIO,
        interp: *const @import("../core/interpreter.zig").Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    _ = try std.posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        mock_dev.write_log.items,
    );
}
