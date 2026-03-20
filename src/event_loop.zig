const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const DeviceIO = @import("io/device_io.zig").DeviceIO;
const Interpreter = @import("core/interpreter.zig").Interpreter;
const OutputDevice = @import("io/uinput.zig").OutputDevice;
const state = @import("core/state.zig");

// Per-interface 1 fd + signalfd + uinput FF fd + udev monitor fd + timerfd slot
pub const MAX_FDS = 8;

const signalfd_siginfo_size = 128;

pub const EventLoop = struct {
    pollfds: [MAX_FDS]posix.pollfd,
    fd_count: usize,
    signal_fd: posix.fd_t,
    // device fd index: pollfds[device_base .. device_base + device_count] are device fds
    device_base: usize,
    running: bool,
    gamepad_state: state.GamepadState,

    pub fn init() !EventLoop {
        var mask = posix.sigemptyset();
        posix.sigaddset(&mask, linux.SIG.TERM);
        posix.sigaddset(&mask, linux.SIG.INT);
        posix.sigprocmask(linux.SIG.BLOCK, &mask, null);

        const sig_fd = try posix.signalfd(-1, &mask, 0);

        var loop = EventLoop{
            .pollfds = undefined,
            .fd_count = 0,
            .signal_fd = sig_fd,
            .device_base = 0,
            .running = false,
            .gamepad_state = .{},
        };

        // signalfd occupies slot 0
        loop.pollfds[0] = .{ .fd = sig_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.fd_count = 1;
        loop.device_base = 1;

        return loop;
    }

    pub fn addDevice(self: *EventLoop, device: DeviceIO) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = device.pollfd();
        self.fd_count += 1;
    }

    pub fn run(
        self: *EventLoop,
        devices: []DeviceIO,
        interpreter: *const Interpreter,
        output: OutputDevice,
    ) !void {
        self.running = true;
        var buf: [64]u8 = undefined;

        while (self.running) {
            _ = posix.ppoll(self.pollfds[0..self.fd_count], null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };

            // Check signalfd
            if (self.pollfds[0].revents & posix.POLL.IN != 0) {
                var siginfo: [signalfd_siginfo_size]u8 = undefined;
                _ = posix.read(self.signal_fd, &siginfo) catch {};
                self.running = false;
                break;
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
                        applyDelta(&self.gamepad_state, delta);
                        try output.emit(self.gamepad_state);
                    }
                }
            }
        }
    }

    pub fn stop(self: *EventLoop) void {
        self.running = false;
    }

    pub fn deinit(self: *EventLoop) void {
        posix.close(self.signal_fd);
    }
};

fn applyDelta(s: *state.GamepadState, delta: state.GamepadStateDelta) void {
    if (delta.ax) |v| s.ax = v;
    if (delta.ay) |v| s.ay = v;
    if (delta.rx) |v| s.rx = v;
    if (delta.ry) |v| s.ry = v;
    if (delta.lt) |v| s.lt = v;
    if (delta.rt) |v| s.rt = v;
    if (delta.dpad_x) |v| s.dpad_x = v;
    if (delta.dpad_y) |v| s.dpad_y = v;
    if (delta.buttons) |v| s.buttons = v;
    if (delta.gyro_x) |v| s.gyro_x = v;
    if (delta.gyro_y) |v| s.gyro_y = v;
    if (delta.gyro_z) |v| s.gyro_z = v;
    if (delta.accel_x) |v| s.accel_x = v;
    if (delta.accel_y) |v| s.accel_y = v;
    if (delta.accel_z) |v| s.accel_z = v;
}

// --- tests ---

const testing = std.testing;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const uinput = @import("io/uinput.zig");

test "EventLoop.init creates signalfd" {
    var loop = try EventLoop.init();
    defer loop.deinit();
    try testing.expect(loop.signal_fd >= 0);
    try testing.expectEqual(@as(usize, 1), loop.fd_count);
}

test "EventLoop.stop sets running = false" {
    var loop = try EventLoop.init();
    defer loop.deinit();
    loop.running = true;
    loop.stop();
    try testing.expect(!loop.running);
}

test "EventLoop.addDevice registers fd" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    try loop.addDevice(dev);
    try testing.expectEqual(@as(usize, 2), loop.fd_count);
    try testing.expectEqual(mock.pipe_r, loop.pollfds[1].fd);
}

test "EventLoop.addDevice rejects overflow" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    // Fill up to MAX_FDS - 1 more slots (already have 1 for signalfd)
    var mocks: [MAX_FDS - 1]MockDeviceIO = undefined;
    for (0..MAX_FDS - 1) |i| {
        mocks[i] = try MockDeviceIO.init(allocator, &.{});
    }
    defer for (0..MAX_FDS - 1) |i| mocks[i].deinit();

    for (0..MAX_FDS - 1) |i| {
        const dev = mocks[i].deviceIO();
        try loop.addDevice(dev);
    }
    // Now fd_count == MAX_FDS, next add should fail
    var extra = try MockDeviceIO.init(allocator, &.{});
    defer extra.deinit();
    const extra_dev = extra.deviceIO();
    try testing.expectError(error.TooManyFds, loop.addDevice(extra_dev));
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

    // Signal pipe to make device fd ready, then stop after one iteration
    try mock.signal();

    // Run the loop in a thread, stop after first dispatch
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
            try c.loop.run(c.devices, c.interp, c.output);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    // Give the loop a moment to process, then stop it
    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // left_x = 500 should be in gamepad state
    try testing.expectEqual(@as(i16, 500), loop.gamepad_state.ax);
    try testing.expectEqual(@as(usize, 1), out.emitted.items.len);
    try testing.expectEqual(@as(i16, 500), out.emitted.items[0].ax);
}

test "EventLoop timerfd slot: nfds grows without crash" {
    const allocator = testing.allocator;
    var loop = try EventLoop.init();
    defer loop.deinit();

    // Add one device
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    const before = loop.fd_count; // should be 2

    // Simulate timerfd activation: add a dummy pollfd (Phase 2 pattern)
    const timer_placeholder = posix.pollfd{ .fd = mock.pipe_r, .events = posix.POLL.IN, .revents = 0 };
    loop.pollfds[loop.fd_count] = timer_placeholder;
    loop.fd_count += 1;

    try testing.expectEqual(before + 1, loop.fd_count);
    // Just verifying the slot math — ppoll not actually called here
}
