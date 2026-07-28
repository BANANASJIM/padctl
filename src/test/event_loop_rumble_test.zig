// FF routing / rumble-throttle / stop-scheduler integration tests extracted
// from src/event_loop.zig (arch-review finding #5).

const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const event_loop_mod = @import("../event_loop.zig");
const EventLoop = event_loop_mod.EventLoop;
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

const ff_report_toml =
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
/// byte from the test's ff_pipe before returning the next event. Tests can pass
/// `ack_write` to learn when the loop has taken the event from the output fd.
const MockFfOutputDrain = struct {
    events: []const ?uinput.FfEvent,
    call_count: usize = 0,
    pipe_read: posix.fd_t,
    ack_write: ?posix.fd_t = null,

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
            if (ev != null) {
                if (self.ack_write) |fd| _ = posix.write(fd, &[_]u8{1}) catch {};
            }
            return ev;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

fn waitForAck(ack_read: posix.fd_t) !void {
    var pfd = [1]posix.pollfd{.{ .fd = ack_read, .events = posix.POLL.IN, .revents = 0 }};
    const n = posix.poll(&pfd, 2000) catch return error.AckTimeout;
    if (n == 0) return error.AckTimeout;
    var buf: [1]u8 = undefined;
    _ = posix.read(ack_read, &buf) catch {};
}

fn sendFfAndWait(ff_write: posix.fd_t, ack_read: posix.fd_t) !void {
    _ = try posix.write(ff_write, &[_]u8{1});
    try waitForAck(ack_read);
}

fn waitForNoAck(ack_read: posix.fd_t, timeout_ms: u64) !void {
    var pfd = [1]posix.pollfd{.{ .fd = ack_read, .events = posix.POLL.IN, .revents = 0 }};
    const n = posix.poll(&pfd, @intCast(timeout_ms)) catch return error.UnexpectedAck;
    if (n != 0) return error.UnexpectedAck;
}

fn runThrottledPlayScenario(allocator: std.mem.Allocator, wait_ns: u64) ![]u8 {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const write_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack[0]);
    defer posix.close(write_ack[1]);
    mock_dev.setWriteAck(write_ack[1]);
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const logical_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(logical_ack[0]);
    defer posix.close(logical_ack[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 50 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 300 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = logical_ack[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    if (wait_ns < 300 * std.time.ns_per_ms) {
        try waitForNoAck(write_ack[0], @intCast(wait_ns / std.time.ns_per_ms));
    } else {
        try waitForAck(write_ack[0]);
    }
    loop.stop();
    thread.join();

    return allocator.dupe(u8, mock_dev.write_log.items);
}

const PriorityProbeOutput = struct {
    ff_pipe_read: posix.fd_t,
    mock_device: *MockDeviceIO,
    ff_before_device_read: bool = false,

    fn outputDevice(self: *PriorityProbeOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *PriorityProbeOutput = @ptrCast(@alignCast(ptr));
        var buf: [1]u8 = undefined;
        _ = posix.read(self.ff_pipe_read, &buf) catch return null;
        if (self.mock_device.frame_idx == 0) {
            self.ff_before_device_read = true;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

const TracingDeviceIO = struct {
    frames: []const []const u8,
    frame_idx: usize = 0,
    allocator: std.mem.Allocator,
    trace: std.ArrayList(u8),
    write_log: std.ArrayList(u8),
    pipe_r: posix.fd_t,
    pipe_w: posix.fd_t,

    fn init(allocator: std.mem.Allocator, frames: []const []const u8) !TracingDeviceIO {
        var fds: [2]posix.fd_t = undefined;
        const rc = std.os.linux.socketpair(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.SEQPACKET | std.os.linux.SOCK.NONBLOCK,
            0,
            &fds,
        );
        if (rc != 0) return error.SocketPairFailed;
        return .{
            .frames = frames,
            .allocator = allocator,
            .trace = .{},
            .write_log = .{},
            .pipe_r = fds[0],
            .pipe_w = fds[1],
        };
    }

    fn deinit(self: *TracingDeviceIO) void {
        self.trace.deinit(self.allocator);
        self.write_log.deinit(self.allocator);
        posix.close(self.pipe_r);
        self.closeWriteEnd();
    }

    fn signal(self: *TracingDeviceIO) !void {
        _ = try posix.write(self.pipe_w, &[_]u8{1});
    }

    fn closeWriteEnd(self: *TracingDeviceIO) void {
        const fd = @atomicRmw(posix.fd_t, &self.pipe_w, .Xchg, -1, .acq_rel);
        if (fd >= 0) posix.close(fd);
    }

    fn deviceIO(self: *TracingDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *TracingDeviceIO = @ptrCast(@alignCast(ptr));
        if (self.frame_idx >= self.frames.len) {
            self.closeWriteEnd();
            return DeviceIO.ReadError.Again;
        }
        const frame = self.frames[self.frame_idx];
        self.frame_idx += 1;
        const n = @min(buf.len, frame.len);
        @memcpy(buf[0..n], frame[0..n]);
        self.trace.append(self.allocator, 'R') catch return DeviceIO.ReadError.Io;
        return n;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *TracingDeviceIO = @ptrCast(@alignCast(ptr));
        self.trace.append(self.allocator, 'W') catch return DeviceIO.WriteError.Io;
        self.write_log.appendSlice(self.allocator, data) catch return DeviceIO.WriteError.Io;
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *TracingDeviceIO = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.pipe_r, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

const NoopOutput = struct {
    fn outputDevice(self: *NoopOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = emit,
        .poll_ff = pollFf,
        .close = close,
    };

    fn emit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}
    fn pollFf(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        return null;
    }
    fn close(_: *anyopaque) void {}
};

const FailingWriteDeviceIO = struct {
    allocator: std.mem.Allocator,
    write_log: std.ArrayList(u8),
    write_times: std.ArrayList(i128),
    attempt_times: std.ArrayList(i128),
    pipe_r: posix.fd_t,
    pipe_w: posix.fd_t,
    write_attempts: usize = 0,
    first_fail_index: usize,
    fail_write_count: usize,
    fail_error: DeviceIO.WriteError,
    write_ack: ?posix.fd_t = null,
    attempt_ack: ?posix.fd_t = null,
    write_release: ?posix.fd_t = null,
    gated_attempts: usize = 0,

    fn init(allocator: std.mem.Allocator, fail_write_index: usize) !FailingWriteDeviceIO {
        return initRange(allocator, fail_write_index, 1, DeviceIO.WriteError.Io);
    }

    fn initNoFail(allocator: std.mem.Allocator) !FailingWriteDeviceIO {
        return initRange(allocator, 1, 0, DeviceIO.WriteError.Io);
    }

    fn initRange(allocator: std.mem.Allocator, first_fail_index: usize, fail_write_count: usize, fail_error: DeviceIO.WriteError) !FailingWriteDeviceIO {
        const fds = try posix.pipe2(.{ .NONBLOCK = true });
        return .{
            .allocator = allocator,
            .write_log = .{},
            .write_times = .{},
            .attempt_times = .{},
            .pipe_r = fds[0],
            .pipe_w = fds[1],
            .first_fail_index = first_fail_index,
            .fail_write_count = fail_write_count,
            .fail_error = fail_error,
        };
    }

    fn setWriteAck(self: *FailingWriteDeviceIO, fd: posix.fd_t) void {
        self.write_ack = fd;
    }

    fn setWriteGate(self: *FailingWriteDeviceIO, attempt_ack: posix.fd_t, write_release: posix.fd_t, gated_attempts: usize) void {
        self.attempt_ack = attempt_ack;
        self.write_release = write_release;
        self.gated_attempts = gated_attempts;
    }

    fn deinit(self: *FailingWriteDeviceIO) void {
        self.write_log.deinit(self.allocator);
        self.write_times.deinit(self.allocator);
        self.attempt_times.deinit(self.allocator);
        posix.close(self.pipe_r);
        posix.close(self.pipe_w);
    }

    fn deviceIO(self: *FailingWriteDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(_: *anyopaque, _: []u8) DeviceIO.ReadError!usize {
        return DeviceIO.ReadError.Again;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *FailingWriteDeviceIO = @ptrCast(@alignCast(ptr));
        self.write_attempts += 1;
        self.attempt_times.append(self.allocator, event_loop_mod.monotonicNs()) catch return DeviceIO.WriteError.Io;
        if (self.attempt_ack) |fd| _ = posix.write(fd, &[_]u8{1}) catch {};
        if (self.write_attempts <= self.gated_attempts) {
            var release: [1]u8 = undefined;
            _ = posix.read(self.write_release.?, &release) catch return DeviceIO.WriteError.Io;
        }
        if (self.fail_write_count > 0) {
            const fail_end = self.first_fail_index + self.fail_write_count;
            if (self.write_attempts >= self.first_fail_index and self.write_attempts < fail_end) return self.fail_error;
        }
        self.write_log.appendSlice(self.allocator, data) catch return DeviceIO.WriteError.Io;
        self.write_times.append(self.allocator, event_loop_mod.monotonicNs()) catch return DeviceIO.WriteError.Io;
        if (self.write_ack) |fd| _ = posix.write(fd, &[_]u8{1}) catch {};
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *FailingWriteDeviceIO = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.pipe_r, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

const AsyncRumbleHarness = struct {
    allocator: std.mem.Allocator,
    loop: EventLoop,
    write_dev: FailingWriteDeviceIO,
    ff_pipe: [2]posix.fd_t,
    logical_ack: [2]posix.fd_t,
    attempt_ack: [2]posix.fd_t,
    write_ack: [2]posix.fd_t,
    release: [2]posix.fd_t,
    run_done: [2]posix.fd_t,
    parsed: device_mod.ParseResult,
    interpreter: Interpreter = undefined,
    output: MockFfOutputDrain = undefined,
    devices: [1]DeviceIO = undefined,
    thread: ?std.Thread = null,

    fn init(allocator: std.mem.Allocator, first_fail: usize, fail_count: usize) !AsyncRumbleHarness {
        var loop = try EventLoop.initManaged();
        errdefer loop.deinit();
        var write_dev = try FailingWriteDeviceIO.initRange(allocator, first_fail, fail_count, DeviceIO.WriteError.Io);
        errdefer write_dev.deinit();

        const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer closePipe(ff_pipe);
        const logical_ack = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer closePipe(logical_ack);
        const attempt_ack = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer closePipe(attempt_ack);
        const write_ack = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer closePipe(write_ack);
        const release = try posix.pipe2(.{});
        errdefer closePipe(release);
        const run_done = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer closePipe(run_done);
        var parsed = try device_mod.parseString(allocator, ff_toml);
        errdefer parsed.deinit();

        return .{
            .allocator = allocator,
            .loop = loop,
            .write_dev = write_dev,
            .ff_pipe = ff_pipe,
            .logical_ack = logical_ack,
            .attempt_ack = attempt_ack,
            .write_ack = write_ack,
            .release = release,
            .run_done = run_done,
            .parsed = parsed,
        };
    }

    fn start(self: *AsyncRumbleHarness, events: []const ?uinput.FfEvent) !void {
        self.interpreter = Interpreter.init(&self.parsed.value);
        self.output = .{
            .events = events,
            .pipe_read = self.ff_pipe[0],
            .ack_write = self.logical_ack[1],
        };
        self.devices = .{self.write_dev.deviceIO()};
        try self.loop.addDevice(self.devices[0]);
        try self.loop.addUinputFf(self.ff_pipe[0]);
        self.write_dev.setWriteAck(self.write_ack[1]);
        self.write_dev.setWriteGate(self.attempt_ack[1], self.release[0], 1);
        self.thread = try std.Thread.spawn(.{}, run, .{self});
    }

    fn run(self: *AsyncRumbleHarness) void {
        defer _ = posix.write(self.run_done[1], &[_]u8{1}) catch {};
        self.loop.run(.{
            .devices = &self.devices,
            .interpreter = &self.interpreter,
            .output = self.output.outputDevice(),
            .allocator = self.allocator,
            .device_config = &self.parsed.value,
            .poll_timeout_ms = 100,
        }) catch @panic("event loop failed");
    }

    fn send(self: *AsyncRumbleHarness) !void {
        try sendFfAndWait(self.ff_pipe[1], self.logical_ack[0]);
    }

    fn releaseWrite(self: *AsyncRumbleHarness) !void {
        _ = try posix.write(self.release[1], &[_]u8{1});
    }

    fn waitForWriterShutdown(self: *AsyncRumbleHarness) !void {
        const deadline = event_loop_mod.monotonicNs() + 500 * std.time.ns_per_ms;
        while (!self.loop.rumble_writer.shutting_down.load(.acquire)) {
            if (event_loop_mod.monotonicNs() >= deadline) return error.ShutdownTimeout;
            std.Thread.sleep(std.time.ns_per_ms);
        }
    }

    fn join(self: *AsyncRumbleHarness) void {
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    fn finish(self: *AsyncRumbleHarness) void {
        self.loop.stop();
        self.join();
    }

    fn deinit(self: *AsyncRumbleHarness) void {
        _ = posix.write(self.release[1], &[_]u8{1}) catch {};
        self.finish();
        self.parsed.deinit();
        closePipe(self.run_done);
        closePipe(self.release);
        closePipe(self.write_ack);
        closePipe(self.attempt_ack);
        closePipe(self.logical_ack);
        closePipe(self.ff_pipe);
        self.write_dev.deinit();
        self.loop.deinit();
    }

    fn closePipe(pipe: [2]posix.fd_t) void {
        posix.close(pipe[0]);
        posix.close(pipe[1]);
    }
};

test "event_loop: device input is handled before uinput FF when both are ready" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const frame = [_]u8{ 0x01, 0x00, 0x00 };
    var mock_dev = try MockDeviceIO.init(allocator, &.{&frame});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var output = PriorityProbeOutput{
        .ff_pipe_read = ff_pipe[0],
        .mock_device = &mock_dev,
    };

    var devs = [_]DeviceIO{dev};

    // Make both fds readable before entering the loop. The design slot order
    // puts device fds before optional output fds, so this must process the
    // input frame before looking at the uinput FF wake.
    try mock_dev.signal();
    _ = try posix.write(ff_pipe[1], &[_]u8{1});

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        output: *PriorityProbeOutput,
        cfg: *const device_mod.DeviceConfig,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .output = &output,
        .cfg = &parsed.value,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{
                .devices = c.devs,
                .interpreter = c.interp,
                .output = c.output.outputDevice(),
                .device_config = c.cfg,
                .poll_timeout_ms = 100,
            });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 1), mock_dev.frame_idx);
    try testing.expect(!output.ff_before_device_read);
}

const GatedRumbleDeviceIO = struct {
    input_r: posix.fd_t,
    input_w: posix.fd_t,
    write_started_r: posix.fd_t,
    write_started_w: posix.fd_t,
    write_release_r: posix.fd_t,
    write_release_w: posix.fd_t,
    write_done_r: posix.fd_t,
    write_done_w: posix.fd_t,
    input_reads: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn init() !GatedRumbleDeviceIO {
        var input: [2]posix.fd_t = undefined;
        const rc = std.os.linux.socketpair(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.SEQPACKET | std.os.linux.SOCK.NONBLOCK,
            0,
            &input,
        );
        if (rc != 0) return error.SocketPairFailed;
        errdefer {
            posix.close(input[0]);
            posix.close(input[1]);
        }

        const started = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer {
            posix.close(started[0]);
            posix.close(started[1]);
        }
        const release = try posix.pipe2(.{});
        errdefer {
            posix.close(release[0]);
            posix.close(release[1]);
        }
        const done = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer {
            posix.close(done[0]);
            posix.close(done[1]);
        }

        return .{
            .input_r = input[0],
            .input_w = input[1],
            .write_started_r = started[0],
            .write_started_w = started[1],
            .write_release_r = release[0],
            .write_release_w = release[1],
            .write_done_r = done[0],
            .write_done_w = done[1],
        };
    }

    fn deinit(self: *GatedRumbleDeviceIO) void {
        posix.close(self.input_r);
        posix.close(self.input_w);
        posix.close(self.write_started_r);
        posix.close(self.write_started_w);
        posix.close(self.write_release_r);
        posix.close(self.write_release_w);
        posix.close(self.write_done_r);
        posix.close(self.write_done_w);
    }

    fn deviceIO(self: *GatedRumbleDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn signalInput(self: *GatedRumbleDeviceIO, frame: []const u8) !void {
        _ = try posix.write(self.input_w, frame);
    }

    fn releaseWrite(self: *GatedRumbleDeviceIO) void {
        _ = posix.write(self.write_release_w, &[_]u8{1}) catch {};
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *GatedRumbleDeviceIO = @ptrCast(@alignCast(ptr));
        const n = posix.read(self.input_r, buf) catch |err| switch (err) {
            error.WouldBlock => return DeviceIO.ReadError.Again,
            else => return DeviceIO.ReadError.Io,
        };
        if (n == 0) return DeviceIO.ReadError.Disconnected;
        _ = self.input_reads.fetchAdd(1, .acq_rel);
        return n;
    }

    fn write(ptr: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        const self: *GatedRumbleDeviceIO = @ptrCast(@alignCast(ptr));
        _ = posix.write(self.write_started_w, &[_]u8{1}) catch return DeviceIO.WriteError.Io;
        var release: [1]u8 = undefined;
        _ = posix.read(self.write_release_r, &release) catch return DeviceIO.WriteError.Io;
        _ = posix.write(self.write_done_w, &[_]u8{1}) catch return DeviceIO.WriteError.Io;
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *GatedRumbleDeviceIO = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.input_r, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

const InputEmissionProbe = struct {
    notify_w: posix.fd_t,
    ff_event: ?uinput.FfEvent,
    ff_poll_count: usize = 0,

    fn outputDevice(self: *InputEmissionProbe) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = emit,
        .poll_ff = pollFf,
        .close = close,
    };

    fn emit(ptr: *anyopaque, _: state.GamepadState) uinput.EmitError!void {
        const self: *InputEmissionProbe = @ptrCast(@alignCast(ptr));
        _ = posix.write(self.notify_w, &[_]u8{1}) catch return uinput.EmitError.WriteFailed;
    }

    fn pollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *InputEmissionProbe = @ptrCast(@alignCast(ptr));
        if (self.ff_poll_count == 0) {
            self.ff_poll_count += 1;
            return self.ff_event;
        }
        return null;
    }

    fn close(_: *anyopaque) void {}
};

fn expectReadable(fd: posix.fd_t, timeout_ms: i32) !void {
    var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&fds, timeout_ms);
    try testing.expectEqual(@as(usize, 1), ready);
    try testing.expect(fds[0].revents & posix.POLL.IN != 0);
}

test "issue 503: blocked rumble write does not starve physical input emission" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var gated = try GatedRumbleDeviceIO.init();
    defer gated.deinit();
    const dev = gated.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const emit_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(emit_pipe[0]);
    defer posix.close(emit_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_report_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var output = InputEmissionProbe{
        .notify_w = emit_pipe[1],
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };
    var devs = [_]DeviceIO{dev};

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        output: *InputEmissionProbe,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .output = &output,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{
                .devices = c.devs,
                .interpreter = c.interp,
                .output = c.output.outputDevice(),
                .allocator = c.alloc,
                .device_config = c.cfg,
                .poll_timeout_ms = 100,
            });
        }
    };

    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    var joined = false;
    defer {
        gated.releaseWrite();
        loop.stop();
        if (!joined) thread.join();
    }

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    try expectReadable(gated.write_started_r, 500);

    // The transport worker is now deterministically blocked. Input arriving
    // afterward must still cross the interpreter and virtual-output boundary.
    try gated.signalInput(&[_]u8{ 0x01, 0x34, 0x12 });
    try expectReadable(emit_pipe[0], 500);
    try testing.expectEqual(@as(usize, 1), gated.input_reads.load(.acquire));

    gated.releaseWrite();
    try expectReadable(gated.write_done_r, 500);
    loop.stop();
    thread.join();
    joined = true;
}

test "issue 503: newer stop supersedes an older failed play retry" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 1);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    try waitForNoAck(harness.attempt_ack[0], 40);
    harness.finish();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, harness.write_dev.write_log.items);
}

test "issue 503: command cadence bounds physical writes while keeping latest play" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x6000, .weak = 0x3000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    harness.parsed.value.commands.?.map.getPtr("rumble").?.min_interval_ms = 100;
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForNoAck(harness.attempt_ack[0], 50);
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    harness.finish();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expect(harness.write_dev.attempt_times.items[1] - harness.write_dev.write_times.items[0] >= 90 * std.time.ns_per_ms);
    try testing.expectEqualSlices(u8, &[_]u8{
        0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00,
        0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00,
    }, harness.write_dev.write_log.items);
}

test "issue 503: repeated physical stop is suppressed after hardware is zero" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForNoAck(harness.attempt_ack[0], 50);
    harness.finish();

    try testing.expectEqual(@as(usize, 1), harness.write_dev.write_attempts);
    try testing.expectEqualSlices(u8, &[_]u8{
        0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, harness.write_dev.write_log.items);
}

test "issue 503: logically different frames with identical payload are suppressed" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x40ff, .weak = 0x20ff, .duration_ms = 500 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForNoAck(harness.attempt_ack[0], 50);
    harness.finish();

    try testing.expectEqual(@as(usize, 1), harness.write_dev.write_attempts);
    try testing.expectEqualSlices(u8, &[_]u8{
        0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00,
    }, harness.write_dev.write_log.items);
}

test "issue 503: weaker no-frame play does not suppress aggregate retry" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 0 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0x2000, .weak = 0x1000, .duration_ms = 0 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 1);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    harness.finish();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, harness.write_dev.write_log.items);
}

test "issue 503: fresh frame does not inherit unrelated pending retry count" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 0 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 1);
    defer harness.deinit();
    harness.loop.pending_rumble_frame = .{ .strong = 0x1000, .weak = 0x0800 };
    harness.loop.pending_rumble_deadline_ns = event_loop_mod.monotonicNs() + std.time.ns_per_s;
    harness.loop.pending_rumble_retry_count = 3;
    harness.loop.pending_rumble_generation = 77;
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.releaseWrite();
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    harness.finish();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, harness.write_dev.write_log.items);
}

test "issue 503: play cadence starts at slow write completion" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try waitForNoAck(harness.attempt_ack[0], 15);
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForNoAck(harness.attempt_ack[0], 5);
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    harness.finish();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expect(harness.write_dev.attempt_times.items[1] - harness.write_dev.write_times.items[0] >= 8 * std.time.ns_per_ms);
}

test "issue 503: shutdown keeps completion cadence for queued play" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    harness.loop.stop();
    try harness.waitForWriterShutdown();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    try waitForAck(harness.run_done[0]);
    harness.join();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expect(harness.write_dev.attempt_times.items[1] - harness.write_dev.write_times.items[0] >= 8 * std.time.ns_per_ms);
}

test "issue 503: shutdown sends accepted stop without cadence delay" {
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(testing.allocator, 1, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    harness.loop.stop();
    try harness.waitForWriterShutdown();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    try waitForAck(harness.run_done[0]);
    harness.join();

    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expect(harness.write_dev.attempt_times.items[1] - harness.write_dev.write_times.items[0] < 8 * std.time.ns_per_ms);
    try testing.expectEqualSlices(u8, &[_]u8{
        0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00,
        0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, harness.write_dev.write_log.items);
}

test "issue 503: rumble writer startup failure clears running state" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var output = NoopOutput{};
    var devs = [_]DeviceIO{dev};

    try testing.expectError(error.TestRumbleWriterStartFailed, loop.run(.{
        .devices = &devs,
        .interpreter = &interp,
        .output = output.outputDevice(),
        .allocator = allocator,
        .device_config = &parsed.value,
        .test_fail_rumble_writer_start = true,
    }));
    try testing.expect(!loop.running);
    try testing.expect(!loop.rumble_writer.isRunning());
}

test "issue 503: EventLoop restart reuses a disabled rumble writer poll slot" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    var devices = [_]DeviceIO{write_dev.deviceIO()};
    try loop.addDevice(devices[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interpreter = Interpreter.init(&parsed.value);
    var output = NoopOutput{};
    const ctx = event_loop_mod.EventLoopContext{
        .devices = &devices,
        .interpreter = &interpreter,
        .output = output.outputDevice(),
        .allocator = allocator,
        .device_config = &parsed.value,
    };

    loop.stop();
    try loop.run(ctx);
    const slot = loop.rumble_writer_slot.?;
    const fd_count = loop.fd_count;
    try testing.expectEqual(@as(posix.fd_t, -1), loop.pollfds[slot].fd);
    try testing.expectEqual(@as(i16, 0), loop.pollfds[slot].events);
    try testing.expectEqual(@as(i16, 0), loop.pollfds[slot].revents);

    loop.stop();
    try loop.run(ctx);
    try testing.expectEqual(slot, loop.rumble_writer_slot.?);
    try testing.expectEqual(fd_count, loop.fd_count);
    try testing.expectEqual(@as(posix.fd_t, -1), loop.pollfds[slot].fd);
}

test "event_loop: device input is handled before rumble auto-stop write when both are ready" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const frame = [_]u8{ 0x01, 0x00, 0x00 };
    var trace_dev = try TracingDeviceIO.init(allocator, &.{&frame});
    defer trace_dev.deinit();
    const dev = trace_dev.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, ff_report_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const now_ns = event_loop_mod.monotonicNs();
    _ = loop.rumble_scheduler.onPlay(0, 0x8000, 0x4000, 1, now_ns - 2 * std.time.ns_per_ms);
    event_loop_mod.armTimer(loop.rumble_stop_fd, 1);
    std.Thread.sleep(3 * std.time.ns_per_ms);
    try trace_dev.signal();

    var output = NoopOutput{};
    var devs = [_]DeviceIO{dev};

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        output: *NoopOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .output = &output,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{
                .devices = c.devs,
                .interpreter = c.interp,
                .output = c.output.outputDevice(),
                .allocator = c.alloc,
                .device_config = c.cfg,
                .poll_timeout_ms = 100,
            });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqualSlices(u8, "RW", trace_dev.trace.items);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, trace_dev.write_log.items);
}

test "event_loop: stop frame forwarded even within 10ms throttle window" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const write_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack[0]);
    defer posix.close(write_ack[1]);
    mock_dev.setWriteAck(write_ack[1]);
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    // Use a real pipe; each byte written wakes one poll iteration.
    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const logical_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(logical_ack[0]);
    defer posix.close(logical_ack[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // play then stop — both within a single burst; stop must not be throttled.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 }, // play
        .{ .effect_type = 0x50, .strong = 0, .weak = 0 }, // stop
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = logical_ack[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
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

test "event_loop: stopping a short overlapping effect restores the remaining long effect" {
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
    //   1) play A (slot 0, 300ms duration, magnitude 0x4000/0x2000)
    //   2) play B (slot 1, 100ms duration, magnitude 0x8000/0x4000)
    //   3) explicit stop B (slot 1)
    //
    // Use the drain-aware mock so each pipe write advances the mock by
    // exactly one event and the test's wall-clock sleeps actually gate
    // the 10ms play-frame throttle.
    //
    // Expected: four HID frames — play A, play B, restore A when B stops,
    // then stop when A's 300ms auto-stop deadline fires. The hardware only
    // has one rumble command state, so suppressing output while A remains
    // active leaves B's stronger command stuck on the controller.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 300 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0x8000, .weak = 0x4000, .duration_ms = 100 },
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

    // Expect exactly 4 frames: play A, play B, restore A, auto-stop.
    const frame_size = 8;
    try testing.expectEqual(@as(usize, 4 * frame_size), mock_dev.write_log.items.len);
    const play_a = mock_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, play_a);
    const play_b = mock_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_b);
    const restore_a = mock_dev.write_log.items[2 * frame_size .. 3 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, restore_a);
    const final_stop = mock_dev.write_log.items[3 * frame_size .. 4 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, final_stop);
}

test "event_loop: non-zero restore frame refreshes rumble throttle clock" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    write_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x4000, .weak = 0x2000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0, .weak = 0, .duration_ms = 0 },
        .{ .effect_type = 0x50, .effect_id = 2, .strong = 0x7000, .weak = 0x3000, .duration_ms = 500 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    std.Thread.sleep(15 * std.time.ns_per_ms);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try waitForAck(write_ack_pipe[0]);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 4 * frame_size), write_dev.write_log.items.len);
    try testing.expectEqual(@as(usize, 4), write_dev.write_times.items.len);
    try testing.expect(write_dev.write_times.items[3] - write_dev.write_times.items[2] >= 8 * std.time.ns_per_ms);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, write_dev.write_log.items[0..frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, write_dev.write_log.items[frame_size .. 2 * frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, write_dev.write_log.items[2 * frame_size .. 3 * frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x70, 0x30, 0x00, 0x00, 0x00 }, write_dev.write_log.items[3 * frame_size .. 4 * frame_size]);
}

test "event_loop: throttled non-zero play is flushed after throttle deadline" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);
    loop.last_rumble_ns = event_loop_mod.monotonicNs() + 50 * std.time.ns_per_ms;

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    write_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x2000, .weak = 0x1000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x6000, .weak = 0x3000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 200 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, frame_size), write_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, write_dev.write_log.items[0..frame_size]);
}

test "event_loop: stop cancels pending throttled rumble frame" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);
    loop.last_rumble_ns = event_loop_mod.monotonicNs() + 50 * std.time.ns_per_ms;

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    write_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x2000, .weak = 0x1000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 200 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 100);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, frame_size), write_dev.write_log.items.len);
    try testing.expectEqual(@as(?rumble_scheduler_mod.RumbleScheduler.Frame, null), loop.pending_rumble_frame);
    try testing.expectEqual(@as(?i128, null), loop.pending_rumble_deadline_ns);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, write_dev.write_log.items[0..frame_size]);
}

test "event_loop: failed stop frame is retried from pending rumble queue" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var fail_dev = try FailingWriteDeviceIO.initRange(allocator, 2, 2, DeviceIO.WriteError.Io);
    defer fail_dev.deinit();
    const dev = fail_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    fail_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 200 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 4), fail_dev.write_attempts);
    try testing.expectEqual(@as(usize, 4), fail_dev.attempt_times.items.len);
    try testing.expect(fail_dev.attempt_times.items[2] - fail_dev.attempt_times.items[1] >= @as(i128, 8 * std.time.ns_per_ms));
    try testing.expect(fail_dev.attempt_times.items[3] - fail_dev.attempt_times.items[2] >= @as(i128, 8 * std.time.ns_per_ms));
    try testing.expectEqual(@as(usize, 2 * frame_size), fail_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, fail_dev.write_log.items[0..frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, fail_dev.write_log.items[frame_size .. 2 * frame_size]);
}

test "event_loop: disconnected rumble write exits without retry queue" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var fail_dev = try FailingWriteDeviceIO.initRange(allocator, 2, 1, DeviceIO.WriteError.Disconnected);
    defer fail_dev.deinit();
    const dev = fail_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    fail_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 200 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 30);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 2), fail_dev.write_attempts);
    try testing.expect(loop.disconnected);
    try testing.expectEqual(@as(?rumble_scheduler_mod.RumbleScheduler.Frame, null), loop.pending_rumble_frame);
    try testing.expectEqual(@as(?i128, null), loop.pending_rumble_deadline_ns);
    try testing.expectEqual(@as(usize, frame_size), fail_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, fail_dev.write_log.items[0..frame_size]);
}

test "event_loop: repeated rumble write failures stop retrying without disconnecting input loop" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var fail_dev = try FailingWriteDeviceIO.initRange(allocator, 2, 4, DeviceIO.WriteError.Io);
    defer fail_dev.deinit();
    const dev = fail_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    fail_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 500 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 200 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 100);
    try testing.expect(@atomicLoad(bool, &loop.running, .acquire));
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 5), fail_dev.write_attempts);
    try testing.expect(!loop.disconnected);
    try testing.expectEqual(@as(?rumble_scheduler_mod.RumbleScheduler.Frame, null), loop.pending_rumble_frame);
    try testing.expectEqual(@as(?i128, null), loop.pending_rumble_deadline_ns);
    try testing.expectEqual(@as(usize, frame_size), fail_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, fail_dev.write_log.items[0..frame_size]);
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

test "event_loop: auto_stop=false throttled play still flushes pending rumble frame" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);
    loop.last_rumble_ns = event_loop_mod.monotonicNs() + 50 * std.time.ns_per_ms;

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);
    const write_ack_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack_pipe[0]);
    defer posix.close(write_ack_pipe[1]);
    write_dev.setWriteAck(write_ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml_no_autostop);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x2000, .weak = 0x1000, .duration_ms = 25 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 25 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = ack_pipe[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    const frame_size = 8;
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForNoAck(write_ack_pipe[0], 5);
    try sendFfAndWait(ff_pipe[1], ack_pipe[0]);
    try waitForAck(write_ack_pipe[0]);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, frame_size), write_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, write_dev.write_log.items[0..frame_size]);
}

test "event_loop: explicit stop before duration_ms disarms auto-stop (no double stop)" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const write_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack[0]);
    defer posix.close(write_ack[1]);
    mock_dev.setWriteAck(write_ack[1]);
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const logical_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(logical_ack[0]);
    defer posix.close(logical_ack[1]);

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
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = logical_ack[1] };

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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 300 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try waitForNoAck(write_ack[0], 230);
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

    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .strong = 0, .weak = 0 },
        .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
        null,
    };
    var harness = try AsyncRumbleHarness.init(allocator, 0, 0);
    defer harness.deinit();
    try harness.start(&seq);

    try harness.send();
    try waitForAck(harness.attempt_ack[0]);
    try harness.send();
    try harness.releaseWrite();
    try waitForAck(harness.write_ack[0]);
    try waitForAck(harness.attempt_ack[0]);
    try waitForAck(harness.write_ack[0]);
    harness.finish();

    const frame_size = 8;
    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_attempts);
    try testing.expectEqual(@as(usize, 2), harness.write_dev.attempt_times.items.len);
    try testing.expectEqual(@as(usize, 2), harness.write_dev.write_times.items.len);
    try testing.expect(harness.write_dev.attempt_times.items[1] - harness.write_dev.write_times.items[0] >= 8 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 2 * frame_size), harness.write_dev.write_log.items.len);
    const stop_frame = harness.write_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, stop_frame);
    const play_frame = harness.write_dev.write_log.items[frame_size .. 2 * frame_size];
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

test "event_loop: replay after stop is forwarded and arms auto-stop deadline" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var write_dev = try FailingWriteDeviceIO.initNoFail(allocator);
    defer write_dev.deinit();
    const dev = write_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);
    const logical_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(logical_ack[0]);
    defer posix.close(logical_ack[1]);
    const write_ack = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(write_ack[0]);
    defer posix.close(write_ack[1]);
    write_dev.setWriteAck(write_ack[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // play, explicit stop, then a replay of effect 0.
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 100 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 },
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 100 },
        null,
    };
    var ff_out = MockFfOutputDrain{ .events = &seq, .pipe_read = ff_pipe[0], .ack_write = logical_ack[1] };

    const RunCtx3 = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutputDrain,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx3{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };
    const T3 = struct {
        fn run(c: *RunCtx3) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T3.run, .{&ctx});

    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try sendFfAndWait(ff_pipe[1], logical_ack[0]);
    try waitForAck(write_ack[0]);
    try waitForAck(write_ack[0]); // replay's 100ms auto-stop
    loop.stop();
    thread.join();

    const frame_size = 8;
    try testing.expectEqual(@as(usize, 4 * frame_size), write_dev.write_log.items.len);
    const play_frame = write_dev.write_log.items[0..frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, play_frame);
    const explicit_stop = write_dev.write_log.items[frame_size .. 2 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, explicit_stop);
    const replay_frame = write_dev.write_log.items[2 * frame_size .. 3 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, replay_frame);
    const auto_stop = write_dev.write_log.items[3 * frame_size .. 4 * frame_size];
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, auto_stop);
}

test "event_loop: throttled play still rearms auto-stop deadline" {
    // Regression test for #65 (stuck rumble): scheduler state must update even
    // when a PLAY frame is suppressed by the 10ms hardware-write throttle.
    //
    // Sequence:
    //   T0  FF_PLAY effect 0, 50ms duration   -> emitted, first deadline armed
    //   T1  FF_PLAY effect 0, 300ms duration  -> throttled, then flushed after
    //                                            10ms; scheduler deadline must extend
    //
    // If the second onPlay were gated by "frame forwarded", the first 50ms
    // deadline would fire and emit a premature stop. If the throttled frame were
    // dropped, the device would keep the first strength until final stop.
    const allocator = testing.allocator;
    const frame_size = 8;

    const early_log = try runThrottledPlayScenario(allocator, 120 * std.time.ns_per_ms);
    defer allocator.free(early_log);
    try testing.expectEqual(@as(usize, 2 * frame_size), early_log.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, early_log[0..frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, early_log[frame_size .. 2 * frame_size]);

    const late_log = try runThrottledPlayScenario(allocator, 420 * std.time.ns_per_ms);
    defer allocator.free(late_log);
    try testing.expectEqual(@as(usize, 3 * frame_size), late_log.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 }, late_log[0..frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, late_log[frame_size .. 2 * frame_size]);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, late_log[2 * frame_size .. 3 * frame_size]);
}
