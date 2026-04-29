// FF routing / rumble-throttle / stop-scheduler integration tests extracted
// from src/event_loop.zig (arch-review finding #5).

const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const state = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const device_mod = @import("../config/device.zig");
const padctl_log = @import("../log.zig");
const rumble_scheduler_mod = @import("../core/rumble_scheduler.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;

// intentionally minimal; not a vader5 fixture
const minimal_toml =
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
    \\size = 3
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i16le" }
;

// synthetic fixture: simple rumble command, no checksum
const ff_toml =
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

// synthetic fixture: custom_ff command key overrides rumble routing
const custom_ff_toml =
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
    \\[output.force_feedback]
    \\type = "custom_ff"
    \\max_effects = 16
    \\[commands.rumble]
    \\interface = 0
    \\template = "ff ff ff ff"
    \\[commands.custom_ff]
    \\interface = 0
    \\template = "aa {strong:u8} {weak:u8} bb"
;

// synthetic fixture: auto_stop = false opt-out
const ff_toml_no_autostop =
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
    \\[output]
    \\name = "T"
    \\vid = 1
    \\pid = 2
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = -32768, max = 32767 }
    \\[output.force_feedback]
    \\type = "rumble"
    \\auto_stop = false
;

const MockFfOutput = struct {
    allocator: std.mem.Allocator,
    ff_event: ?uinput.FfEvent,
    call_count: usize = 0,

    fn outputDevice(self: *MockFfOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *MockFfOutput = @ptrCast(@alignCast(ptr));
        if (self.call_count == 0) {
            self.call_count += 1;
            return self.ff_event;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "event_loop: FF event routed to DeviceIO.write via fillTemplate" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    // FF wake pipe: write side signals readiness
    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    // Signal uinput FF fd ready, then stop
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // strong=0x8000 >> 8 = 0x80, weak=0x4000 >> 8 = 0x40
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, mock_dev.write_log.items);
}

test "event_loop: no commands.rumble — silent skip" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    // Config has no [commands] section
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // No write should have occurred
    try testing.expectEqual(@as(usize, 0), mock_dev.write_log.items.len);
}

test "event_loop: config-driven FF command key — output.force_feedback.type overrides default rumble" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, custom_ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // custom_ff template: "aa {strong:u8} {weak:u8} bb"
    // strong=0x8000 >> 8 = 0x80, weak=0x4000 >> 8 = 0x40
    // Must NOT match "ff ff ff ff" (the rumble template)
    try testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0x80, 0x40, 0xbb }, mock_dev.write_log.items);
}

// Regression test: stop frame must bypass throttle even within 10ms of a play frame.
const MockFfOutputSeq = struct {
    allocator: std.mem.Allocator,
    events: []const ?uinput.FfEvent,
    call_count: usize = 0,

    fn outputDevice(self: *MockFfOutputSeq) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *MockFfOutputSeq = @ptrCast(@alignCast(ptr));
        if (self.call_count < self.events.len) {
            const ev = self.events[self.call_count];
            self.call_count += 1;
            return ev;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

/// Drain-aware variant of MockFfOutputSeq. Each `mockPollFf` call reads one
/// byte from the test's ff_pipe before returning the next event. That forces
/// a strict 1:1 correspondence between pipe writes and event consumption so
/// real-time delays between pipe writes are respected — which matters when a
/// test wants its second play frame to land AFTER the 10ms play-frame
/// throttle window closes.
const MockFfOutputDrain = struct {
    events: []const ?uinput.FfEvent,
    call_count: usize = 0,
    pipe_read: posix.fd_t,

    fn outputDevice(self: *MockFfOutputDrain) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *MockFfOutputDrain = @ptrCast(@alignCast(ptr));
        var buf: [1]u8 = undefined;
        _ = posix.read(self.pipe_read, &buf) catch return null;
        if (self.call_count < self.events.len) {
            const ev = self.events[self.call_count];
            self.call_count += 1;
            return ev;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "event_loop: stop frame forwarded even within 10ms throttle window" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    // Use a real pipe; each byte written wakes one poll iteration.
    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // play then stop — both within a single burst; stop must not be throttled.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 }, // play
        .{ .effect_type = 0x50, .strong = 0, .weak = 0 }, // stop
        null,
    };
    var ff_out = MockFfOutputSeq{ .allocator = allocator, .events = &seq };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputSeq,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    // First wakeup → play event
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(2 * std.time.ns_per_ms); // stay well inside 10ms throttle window
    // Second wakeup → stop event (must bypass throttle)
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Template: "00 08 00 {strong:u8} {weak:u8} 00 00 00" → 8-byte frame
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 2 * frame_size), mock_dev.write_log.items.len);
    // Entry 0: play frame
    const play_frame = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
    // Entry 1: stop frame
    const stop_frame = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, stop_frame);
}

test "event_loop: explicit stop of one of two overlapping effects does not cut the long effect" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Sequence:
    //   1) play A (slot 0, 300ms duration, magnitude 0x8000/0x4000)
    //   2) play B (slot 1, 100ms duration, magnitude 0x4000/0x2000)
    //   3) explicit stop B (slot 1)
    //
    // Use the drain-aware mock so each pipe write advances the mock by
    // exactly one event and the test's wall-clock sleeps actually gate
    // the 10ms play-frame throttle.
    //
    // Expected: three HID frames — play A, play B, then ONE stop frame
    // when A's 300ms auto-stop deadline fires. No stop frame from the
    // explicit stop of B, because A was still live.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 300 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0x4000, .weak = 0x2000, .duration_ms = 100 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0] };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputDrain,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 500 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    // play A — scheduler arms at t+300ms
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(15 * std.time.ns_per_ms); // clear the 10ms play throttle
    // play B — scheduler still has A pending; next earliest deadline is
    // min(300, 15+100) = 115ms.
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(15 * std.time.ns_per_ms);
    // explicit stop B — A is still active; scheduler must NOT emit a stop.
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    // Wait for A's 300ms auto-stop deadline to fire.
    std.Thread.sleep(350 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Expect exactly 3 frames: play A, play B, auto-stop.
    // The explicit stop of B must NOT have produced a zero frame while A
    // was still playing.
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 3 * frame_size), mock_dev.write_log.items.len);
    const play_a = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_a);
    const play_b = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, play_b);
    const final_stop = mock_dev.write_log.items[2 * frame_size .. 3 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, final_stop);
}

test "event_loop: auto_stop=false never emits a scheduler-driven stop frame" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml_no_autostop);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Single play with a short duration. Because the device opted out,
    // the scheduler must NOT arm the timerfd and NOT emit an auto-stop
    // frame — only the play frame from the pollFf path should land.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 25 },
        null,
    };
    var ff_out = MockFfOutputSeq{ .allocator = allocator, .events = &seq };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputSeq,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    // Wait well past the 25ms duration to prove no auto-stop fires.
    std.Thread.sleep(80 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Only the play frame; NO stop frame because auto_stop = false.
    const frame_size = 8;
    try testing.expectEqual(@as(usize, frame_size), mock_dev.write_log.items.len);
    const play_frame = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
}

test "event_loop: explicit stop before duration_ms disarms auto-stop (no double stop)" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Play with a long (200ms) duration, followed by an explicit stop a few
    // ms later. The scheduler must cancel the 200ms auto-stop deadline so
    // that only one stop frame (the explicit one) hits HID — not a second
    // redundant stop from the timer firing later.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 200 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputSeq{ .allocator = allocator, .events = &seq };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputSeq,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 300 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    // First wake: play event → scheduler arms at t+200ms.
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(5 * std.time.ns_per_ms);
    // Second wake: explicit stop → scheduler disarms.
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    // Wait well past the original 200ms to prove the timer never fires.
    std.Thread.sleep(260 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Exactly 2 frames: play + stop. No third stop from the (disarmed) timer.
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 2 * frame_size), mock_dev.write_log.items.len);
    const play_frame = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
    const stop_frame = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, stop_frame);
}

test "event_loop: rumble auto-stop emits stop frame after duration_ms elapses" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Single play event with a short finite duration (25ms).
    // The client deliberately does NOT send an explicit stop — matching
    // what Steam/SDL does when relying on the kernel's ff-memless auto-stop
    // for real controllers. padctl must emit its own stop frame.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 25 },
        null,
    };
    var ff_out = MockFfOutputSeq{ .allocator = allocator, .events = &seq };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputSeq,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
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

    // Wake the loop so pollFf delivers the play event. The scheduler should
    // then arm rumble_stop_fd at t+25ms. No more FF events are sent.
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    // Wait long enough for the 25ms deadline to fire plus scheduling slack.
    std.Thread.sleep(80 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Template: "00 08 00 {strong:u8} {weak:u8} 00 00 00" → 8-byte frame
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 2 * frame_size), mock_dev.write_log.items.len);
    const play_frame = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
    const stop_frame = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, stop_frame);
}

test "event_loop: play after stop within throttle window is forwarded" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // stop at T=0, then play at T≈5ms (well within 10ms throttle window)
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .strong = 0, .weak = 0 }, // stop
        .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 }, // play
        null,
    };
    var ff_out = MockFfOutputSeq{ .allocator = allocator, .events = &seq };

    const RunCtx2 = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputSeq,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx2{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };
    const T2 = struct {
        fn run(c: *RunCtx2) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T2.run, .{&ctx});

    // First wakeup → stop
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(5 * std.time.ns_per_ms); // inside 10ms throttle window
    // Second wakeup → play (must NOT be throttled because stop doesn't advance last_rumble_ns)
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Both frames must be written: stop then play
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 2 * frame_size), mock_dev.write_log.items.len);
    const stop_frame = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, stop_frame);
    const play_frame = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
}

test "event_loop: FF scheduler state identical with dump on vs off" {
    // Run the same FF PLAY event through two separate event loops — one
    // with dump enabled, one disabled — and verify the scheduler state
    // and HID write output are identical.
    // padctl_log is now a module-level import; no local re-binding needed.
    const allocator = testing.allocator;

    const RunResult = struct {
        scheduler_slots: [rumble_scheduler_mod.MAX_EFFECTS]i128,
        write_log: []u8,
    };

    const runOnce = struct {
        fn go(alloc: std.mem.Allocator, dump_on: bool) !RunResult {
            padctl_log.setEnabled(dump_on);
            defer padctl_log.setEnabled(false);

            var loop = try EventLoop.initManaged();
            defer loop.deinit();

            var mock_dev = try MockDeviceIO.init(alloc, &.{});
            defer mock_dev.deinit();
            const dev = mock_dev.deviceIO();
            try loop.addDevice(dev);

            const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
            defer posix.close(ff_pipe[0]);
            defer posix.close(ff_pipe[1]);
            try loop.addUinputFf(ff_pipe[0]);

            const parsed = try device_mod.parseString(alloc, ff_toml);
            defer parsed.deinit();
            const interp = Interpreter.init(&parsed.value);

            var ff_out = MockFfOutput{
                .allocator = alloc,
                .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000, .duration_ms = 300 },
            };

            var devs = [_]DeviceIO{dev};

            // Use a pointer to stack-local context to avoid anonymous struct type issues.
            const Ctx2 = struct { l: *EventLoop, d: []DeviceIO, i: *const Interpreter, f: *MockFfOutput, c: *const device_mod.DeviceConfig, a: std.mem.Allocator };
            var run_ctx = Ctx2{ .l = &loop, .d = &devs, .i = &interp, .f = &ff_out, .c = &parsed.value, .a = alloc };
            const thread = try std.Thread.spawn(.{}, struct {
                fn run(ctx: *Ctx2) !void {
                    try ctx.l.run(.{
                        .devices = ctx.d,
                        .interpreter = ctx.i,
                        .output = ctx.f.outputDevice(),
                        .allocator = ctx.a,
                        .device_config = ctx.c,
                        .poll_timeout_ms = 100,
                    });
                }
            }.run, .{&run_ctx});

            _ = try posix.write(ff_pipe[1], &[_]u8{1});
            std.Thread.sleep(20 * std.time.ns_per_ms);
            loop.stop();
            thread.join();

            const log_copy = try alloc.dupe(u8, mock_dev.write_log.items);
            return RunResult{
                .scheduler_slots = loop.rumble_scheduler.dumpSlots(),
                .write_log = log_copy,
            };
        }
    }.go;

    const r_off = try runOnce(allocator, false);
    defer allocator.free(r_off.write_log);
    const r_on = try runOnce(allocator, true);
    defer allocator.free(r_on.write_log);

    // Both runs must have actually produced work. Without these checks the
    // test would pass vacuously if the FF event never reached the scheduler
    // (pipe write race, poll timeout) — both runs would have empty slots
    // and empty write logs and `expectEqualSlices` on two empty slices
    // would succeed.
    try testing.expect(r_off.write_log.len > 0);
    try testing.expect(r_on.write_log.len > 0);
    var active_off: usize = 0;
    var active_on: usize = 0;
    for (r_off.scheduler_slots) |s| {
        if (s != 0) active_off += 1;
    }
    for (r_on.scheduler_slots) |s| {
        if (s != 0) active_on += 1;
    }
    try testing.expect(active_off >= 1);
    try testing.expect(active_on >= 1);

    // Scheduler slot activity pattern must be identical (which slots are
    // active/inactive). Exact timestamps differ between runs because they
    // use the real monotonic clock, so we compare structural shape.
    for (r_off.scheduler_slots, r_on.scheduler_slots) |a, b| {
        const a_active = a != 0;
        const b_active = b != 0;
        try testing.expectEqual(a_active, b_active);
        // Both infinite or both finite.
        const a_inf = a == rumble_scheduler_mod.RumbleScheduler.INFINITE;
        const b_inf = b == rumble_scheduler_mod.RumbleScheduler.INFINITE;
        try testing.expectEqual(a_inf, b_inf);
    }
    // HID writes must be identical (same bytes sent to device).
    try testing.expectEqualSlices(u8, r_off.write_log, r_on.write_log);
}
