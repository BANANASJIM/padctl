const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const DeviceIO = @import("io/device_io.zig").DeviceIO;
const Interpreter = @import("core/interpreter.zig").Interpreter;
const OutputDevice = @import("io/uinput.zig").OutputDevice;
const state = @import("core/state.zig");
const mapper_mod = @import("core/mapper.zig");
const DeviceConfig = @import("config/device.zig").DeviceConfig;
const fillTemplate = @import("core/command.zig").fillTemplate;
const Param = @import("core/command.zig").Param;

// signalfd(0) + stop_pipe(1) + per-interface fds + uinput FF fd + timerfd slot
pub const MAX_FDS = 10;

const signalfd_siginfo_size = 128;

pub const TimerCallback = struct {
    ptr: *anyopaque,
    on_expired: *const fn (*anyopaque) void,

    pub fn call(self: TimerCallback) void {
        self.on_expired(self.ptr);
    }
};

/// Arm a timerfd for a one-shot timeout (it_interval = 0).
pub fn armTimer(fd: posix.fd_t, timeout_ms: u32) !void {
    const spec = linux.itimerspec{
        .it_value = .{
            .sec = @intCast(timeout_ms / 1000),
            .nsec = @intCast((timeout_ms % 1000) * 1_000_000),
        },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

/// Disarm a timerfd by setting all fields to zero.
pub fn disarmTimer(fd: posix.fd_t) void {
    const spec = linux.itimerspec{
        .it_value = .{ .sec = 0, .nsec = 0 },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

pub const EventLoop = struct {
    pollfds: [MAX_FDS]posix.pollfd,
    fd_count: usize,
    signal_fd: posix.fd_t,
    stop_r: posix.fd_t,
    stop_w: posix.fd_t,
    // device fds start at slot 2 (after signalfd + stop_pipe)
    device_base: usize,
    timer_fd: posix.fd_t,
    uinput_ff_slot: ?usize,
    running: bool,
    gamepad_state: state.GamepadState,

    pub fn init() !EventLoop {
        var mask = posix.sigemptyset();
        posix.sigaddset(&mask, linux.SIG.TERM);
        posix.sigaddset(&mask, linux.SIG.INT);
        posix.sigprocmask(linux.SIG.BLOCK, &mask, null);

        const sig_fd = try posix.signalfd(-1, &mask, 0);
        errdefer posix.close(sig_fd);

        const pfds = try posix.pipe2(.{ .NONBLOCK = true });
        const stop_r = pfds[0];
        const stop_w = pfds[1];
        errdefer {
            posix.close(stop_r);
            posix.close(stop_w);
        }

        const timer_fd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
        errdefer posix.close(timer_fd);

        var loop = EventLoop{
            .pollfds = undefined,
            .fd_count = 0,
            .signal_fd = sig_fd,
            .stop_r = stop_r,
            .stop_w = stop_w,
            .device_base = 0,
            .timer_fd = timer_fd,
            .uinput_ff_slot = null,
            .running = false,
            .gamepad_state = .{},
        };

        // slot 0 = signalfd, slot 1 = stop pipe, slot 2 = timerfd
        loop.pollfds[0] = .{ .fd = sig_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[1] = .{ .fd = stop_r, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[2] = .{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.fd_count = 3;
        loop.device_base = 3;

        return loop;
    }

    pub fn addDevice(self: *EventLoop, device: DeviceIO) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = device.pollfd();
        self.fd_count += 1;
    }

    pub fn addUinputFf(self: *EventLoop, fd: posix.fd_t) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = .{ .fd = fd, .events = posix.POLL.IN, .revents = 0 };
        self.uinput_ff_slot = slot;
        self.fd_count += 1;
    }

    pub fn run(
        self: *EventLoop,
        devices: []DeviceIO,
        interpreter: *const Interpreter,
        output: OutputDevice,
        mapper: ?*mapper_mod.Mapper,
        aux_output: ?@import("io/uinput.zig").AuxOutputDevice,
        allocator: ?std.mem.Allocator,
        device_config: ?*const DeviceConfig,
    ) !void {
        self.running = true;
        var buf: [64]u8 = undefined;

        while (self.running) {
            _ = posix.ppoll(self.pollfds[0..self.fd_count], null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };

            // Check signalfd (slot 0)
            if (self.pollfds[0].revents & posix.POLL.IN != 0) {
                var siginfo: [signalfd_siginfo_size]u8 = undefined;
                _ = posix.read(self.signal_fd, &siginfo) catch {};
                break;
            }

            // Check stop pipe (slot 1)
            if (self.pollfds[1].revents & posix.POLL.IN != 0) break;

            // Check timerfd (slot 2)
            if (self.pollfds[2].revents & posix.POLL.IN != 0) {
                var expiry: [8]u8 = undefined;
                _ = posix.read(self.timer_fd, &expiry) catch {};
                if (mapper) |m| m.onTimerExpired();
            }

            // Check uinput FF fd
            if (self.uinput_ff_slot) |slot| {
                if (self.pollfds[slot].revents & posix.POLL.IN != 0) {
                    if (output.pollFf() catch null) |ff| {
                        if (allocator) |alloc| {
                            if (device_config) |dcfg| {
                                if (dcfg.commands) |cmds| {
                                    if (cmds.map.get("rumble")) |cmd| {
                                        const iface_idx: usize = @intCast(cmd.interface);
                                        if (iface_idx < devices.len) {
                                            const params = [_]Param{
                                                .{ .name = "strong", .value = ff.strong },
                                                .{ .name = "weak", .value = ff.weak },
                                            };
                                            if (fillTemplate(alloc, cmd.template, &params)) |bytes| {
                                                defer alloc.free(bytes);
                                                devices[iface_idx].write(bytes) catch {};
                                            } else |_| {}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Check device fds
            for (devices, 0..) |dev, i| {
                const slot = self.device_base + i;
                if (slot >= self.fd_count) break;
                if (self.pollfds[slot].revents & posix.POLL.IN == 0) continue;

                // Drain all available frames from this device
                while (true) {
                    const n = dev.read(&buf) catch |err| switch (err) {
                        error.Again => break,
                        error.Disconnected => {
                            self.running = false;
                            break;
                        },
                        error.Io => break,
                    };
                    if (n == 0) break;

                    const interface_id: u8 = @intCast(i);
                    if (interpreter.processReport(interface_id, buf[0..n]) catch null) |delta| {
                        if (mapper) |m| {
                            const events = try m.apply(delta);
                            self.gamepad_state.applyDelta(delta);
                            try output.emit(events.gamepad);
                            if (aux_output) |ao| {
                                if (events.aux.len > 0) try ao.emitAux(events.aux.slice());
                            }
                        } else {
                            self.gamepad_state.applyDelta(delta);
                            try output.emit(self.gamepad_state);
                        }
                    }
                }
            }
        }
        self.running = false;
    }

    /// Interrupt a blocking ppoll in run() from another thread.
    pub fn stop(self: *EventLoop) void {
        _ = posix.write(self.stop_w, &[_]u8{1}) catch {};
    }

    pub fn deinit(self: *EventLoop) void {
        posix.close(self.signal_fd);
        posix.close(self.stop_r);
        posix.close(self.stop_w);
        posix.close(self.timer_fd);
    }
};

// --- tests ---

const testing = std.testing;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const uinput = @import("io/uinput.zig");

test "EventLoop.addUinputFf registers fd and increments fd_count" {
    var loop = try EventLoop.init();
    defer loop.deinit();

    const pfds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(pfds[0]);
    defer posix.close(pfds[1]);

    try loop.addUinputFf(pfds[0]);
    try testing.expectEqual(@as(usize, 4), loop.fd_count);
    try testing.expectEqual(@as(?usize, 3), loop.uinput_ff_slot);
    try testing.expectEqual(pfds[0], loop.pollfds[3].fd);
}

test "EventLoop.init creates signalfd and timerfd" {
    var loop = try EventLoop.init();
    defer loop.deinit();
    try testing.expect(loop.signal_fd >= 0);
    try testing.expect(loop.timer_fd >= 0);
    // slot 0 = signalfd, slot 1 = stop_pipe, slot 2 = timerfd
    try testing.expectEqual(@as(usize, 3), loop.fd_count);
}

test "EventLoop.stop wakes ppoll" {
    var loop = try EventLoop.init();
    defer loop.deinit();
    loop.stop();
    var pfd = [1]posix.pollfd{.{ .fd = loop.stop_r, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 1), ready);
}

test "EventLoop.addDevice registers fd" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    try loop.addDevice(dev);
    // fd_count goes from 3 → 4, device is at slot 3
    try testing.expectEqual(@as(usize, 4), loop.fd_count);
    try testing.expectEqual(mock.pipe_r, loop.pollfds[3].fd);
}

test "EventLoop.addDevice rejects overflow" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    // Fill remaining slots (already have 3: signalfd + stop_pipe + timerfd)
    var mocks: [MAX_FDS - 3]MockDeviceIO = undefined;
    for (0..MAX_FDS - 3) |i| {
        mocks[i] = try MockDeviceIO.init(allocator, &.{});
    }
    defer for (0..MAX_FDS - 3) |i| mocks[i].deinit();

    for (0..MAX_FDS - 3) |i| {
        const dev = mocks[i].deviceIO();
        try loop.addDevice(dev);
    }
    var extra = try MockDeviceIO.init(allocator, &.{});
    defer extra.deinit();
    const extra_dev = extra.deviceIO();
    try testing.expectError(error.TooManyFds, loop.addDevice(extra_dev));
}

test "armTimer / disarmTimer: arm then disarm does not leave fd readable" {
    var loop = try EventLoop.init();
    defer loop.deinit();

    try armTimer(loop.timer_fd, 5000); // 5 seconds — will not fire during test
    disarmTimer(loop.timer_fd);

    // After disarm, timerfd should not be readable
    var pfd = [1]posix.pollfd{.{ .fd = loop.timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 0), ready);
}

test "armTimer: fires after timeout" {
    var loop = try EventLoop.init();
    defer loop.deinit();

    try armTimer(loop.timer_fd, 20); // 20ms

    var pfd = [1]posix.pollfd{.{ .fd = loop.timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    // Wait up to 200ms for the timer to fire
    const ready = try posix.poll(&pfd, 200);
    try testing.expectEqual(@as(usize, 1), ready);

    // Consume 8 bytes — must not block
    var expiry: [8]u8 = undefined;
    const n = try posix.read(loop.timer_fd, &expiry);
    try testing.expectEqual(@as(usize, 8), n);
}

test "EventLoop timerfd: mapper.onTimerExpired invoked on timer expiry" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    // Arm for 20ms, then run the loop
    try armTimer(loop.timer_fd, 20);

    const mapping_mod = @import("config/mapping.zig");
    const mapper_empty = try mapping_mod.parseString(allocator,
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
    );
    defer mapper_empty.deinit();

    var m = try mapper_mod.Mapper.init(&mapper_empty.value, loop.timer_fd, allocator);
    defer m.deinit();

    // Put layer in PENDING so timer expiry advances it to ACTIVE
    _ = m.layer.onTriggerPress("aim", 200);

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const MockOut = struct {
        fn outputDevice() uinput.OutputDevice {
            return .{ .ptr = undefined, .vtable = &vtable };
        }
        const vtable = uinput.OutputDevice.VTable{
            .emit = mockEmit,
            .poll_ff = mockPollFf,
            .close = mockClose,
        };
        fn mockEmit(_: *anyopaque, _: state.GamepadState) anyerror!void {}
        fn mockPollFf(_: *anyopaque) anyerror!?uinput.FfEvent { return null; }
        fn mockClose(_: *anyopaque) void {}
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        mapper: *mapper_mod.Mapper,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{ .loop = &loop, .devs = &devs, .interp = &interp, .mapper = &m };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.devs, c.interp, MockOut.outputDevice(), c.mapper, null, null, null);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(150 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Timer expiry should have advanced aim layer from PENDING to ACTIVE
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(m.layer.tap_hold.?.layer_activated);
}

// MockOutput for event loop integration test
const MockOutput = struct {
    allocator: std.mem.Allocator,
    emitted: std.ArrayList(state.GamepadState),

    fn init(allocator: std.mem.Allocator) MockOutput {
        return .{ .allocator = allocator, .emitted = .{} };
    }

    fn deinit(self: *MockOutput) void {
        self.emitted.deinit(self.allocator);
    }

    fn outputDevice(self: *MockOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(ptr: *anyopaque, s: state.GamepadState) anyerror!void {
        const self: *MockOutput = @ptrCast(@alignCast(ptr));
        try self.emitted.append(self.allocator, s);
    }

    fn mockPollFf(_: *anyopaque) anyerror!?uinput.FfEvent {
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

// Minimal DeviceConfig + Interpreter for event loop tests
const device_mod = @import("config/device.zig");

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

test "EventLoop mini: device frame dispatched to interpreter and output" {
    const allocator = testing.allocator;

    var loop = try EventLoop.init();
    defer loop.deinit();

    // frame: match byte 0x01, left_x = 500 (i16le)
    var frame: [3]u8 = undefined;
    frame[0] = 0x01;
    std.mem.writeInt(i16, frame[1..3], 500, .little);

    var mock = try MockDeviceIO.init(allocator, &.{&frame});
    defer mock.deinit();
    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var out = MockOutput.init(allocator);
    defer out.deinit();
    const output = out.outputDevice();

    try mock.signal();

    const RunCtx = struct {
        loop: *EventLoop,
        devices: []DeviceIO,
        interp: *const Interpreter,
        output: uinput.OutputDevice,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .devices = &devs,
        .interp = &interp,
        .output = output,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.devices, c.interp, c.output, null, null, null, null);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(i16, 500), loop.gamepad_state.ax);
    try testing.expectEqual(@as(usize, 1), out.emitted.items.len);
    try testing.expectEqual(@as(i16, 500), out.emitted.items[0].ax);
}

// T4: FF routing tests

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

    fn mockEmit(_: *anyopaque, _: state.GamepadState) anyerror!void {}

    fn mockPollFf(ptr: *anyopaque) anyerror!?uinput.FfEvent {
        const self: *MockFfOutput = @ptrCast(@alignCast(ptr));
        if (self.call_count == 0) {
            self.call_count += 1;
            return self.ff_event;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "T4: FF event routed to DeviceIO.write via fillTemplate" {
    const allocator = testing.allocator;

    var loop = try EventLoop.init();
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
            try c.loop.run(c.devs, c.interp, c.ff_out.outputDevice(), null, null, c.alloc, c.cfg);
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

test "T4: no commands.rumble — silent skip" {
    const allocator = testing.allocator;

    var loop = try EventLoop.init();
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
            try c.loop.run(c.devs, c.interp, c.ff_out.outputDevice(), null, null, c.alloc, c.cfg);
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
