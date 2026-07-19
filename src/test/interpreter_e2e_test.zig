const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const interpreter_mod = @import("../core/interpreter.zig");
const state_mod = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const EventLoop = @import("../event_loop.zig").EventLoop;
const EventLoopContext = @import("../event_loop.zig").EventLoopContext;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const mapping_mod = @import("../config/mapping.zig");
const Mapper = @import("../core/mapper.zig").Mapper;
const padctl_log = @import("../log.zig");

const Interpreter = interpreter_mod.Interpreter;
const GamepadState = state_mod.GamepadState;
const ButtonId = state_mod.ButtonId;

// Vader 5 IF1 extended report layout (32 bytes):
//   [0..2]  magic: 5a a5 ef
//   [3..4]  left_x  i16le
//   [5..6]  left_y  i16le (negate transform → stored negated)
//   [7..8]  right_x i16le
//   [9..10] right_y i16le (negate transform)
//   [11..14] button_group source (4 bytes), bit 4 = A
//   [15]    lt u8
//   [16]    rt u8
//   [17..28] IMU fields

fn makeIf1Sample() [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], 1000, .little); // left_x
    std.mem.writeInt(i16, raw[5..7], -500, .little); // left_y → after negate → 500
    raw[11] = 0x10; // A = bit 4
    raw[15] = 128; // lt
    return raw;
}

// --- Layer 1: raw bytes → GamepadState ---

test "interpreter_e2e: Vader5 IF1 — load from file and process" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const raw = makeIf1Sample();
    const delta = (try interp.processReport(1, &raw)) orelse return error.NoMatch;

    try testing.expectEqual(@as(?i16, 1000), delta.ax);
    try testing.expectEqual(@as(?i16, 500), delta.ay);
    try testing.expectEqual(@as(?u8, 128), delta.lt);

    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
}

test "interpreter_e2e: Vader5 IF1 — checksum mismatch suppresses emit" {
    const allocator = testing.allocator;
    const toml_with_cs =
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
        \\size = 6
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "sum8"
        \\range = [0, 4]
        \\expect = { offset = 4, type = "u8" }
    ;
    const parsed = try device_mod.parseString(allocator, toml_with_cs);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x00, 0x00 }; // wrong checksum
    try testing.expectError(interpreter_mod.ProcessError.ChecksumMismatch, interp.processReport(0, &raw));
}

// --- Layer 1: complete pipeline via EventLoop ---
// Config uses interface = 0 so device at slice index 0 matches.

const pipeline_toml =
    \\[device]
    \\name = "Vader5 Pipeline Test"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[device.init]
    \\commands = []
    \\response_prefix = []
    \\[[report]]
    \\name = "extended"
    \\interface = 0
    \\size = 32
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\[report.fields]
    \\left_x  = { offset = 3,  type = "i16le" }
    \\left_y  = { offset = 5,  type = "i16le", transform = "negate" }
    \\lt      = { offset = 15, type = "u8" }
    \\[report.button_group]
    \\source = { offset = 11, size = 2 }
    \\map = { A = 0, B = 1 }
;

const GamepadStateDelta = state_mod.GamepadStateDelta;

const MockOutput = @import("mock_output.zig").MockOutput;

fn makeFrame(left_x: i16, left_y_raw: i16, buttons_byte: u8, lt: u8) [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], left_x, .little);
    std.mem.writeInt(i16, raw[5..7], left_y_raw, .little);
    raw[11] = buttons_byte;
    raw[15] = lt;
    return raw;
}

fn makeVader5ButtonFrame(buttons: u32) [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(u32, raw[11..15], buttons, .little);
    return raw;
}

const StreamingDeviceIO = struct {
    read_fd: std.posix.fd_t,
    write_fd: std.posix.fd_t,
    read_count: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn init() !StreamingDeviceIO {
        var fds: [2]std.posix.fd_t = undefined;
        const rc = std.os.linux.socketpair(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.SEQPACKET | std.os.linux.SOCK.NONBLOCK,
            0,
            &fds,
        );
        if (rc != 0) return error.SocketPairFailed;
        return .{ .read_fd = fds[0], .write_fd = fds[1] };
    }

    fn deinit(self: *StreamingDeviceIO) void {
        std.posix.close(self.read_fd);
        std.posix.close(self.write_fd);
    }

    fn send(self: *StreamingDeviceIO, frame: []const u8) !void {
        const written = try std.posix.write(self.write_fd, frame);
        if (written != frame.len) return error.ShortWrite;
    }

    fn deviceIO(self: *StreamingDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn framesRead(self: *const StreamingDeviceIO) usize {
        return self.read_count.load(.acquire);
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *StreamingDeviceIO = @ptrCast(@alignCast(ptr));
        const n = std.posix.read(self.read_fd, buf) catch |err| switch (err) {
            error.WouldBlock => return DeviceIO.ReadError.Again,
            error.ConnectionResetByPeer => return DeviceIO.ReadError.Disconnected,
            else => return DeviceIO.ReadError.Io,
        };
        if (n != 0) _ = self.read_count.fetchAdd(1, .release);
        return n;
    }

    fn write(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}
    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}
    fn pollfd(ptr: *anyopaque) std.posix.pollfd {
        const self: *StreamingDeviceIO = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.read_fd, .events = std.posix.POLL.IN, .revents = 0 };
    }
    fn close(_: *anyopaque) void {}
};

const GestureEdgeOutput = struct {
    allocator: std.mem.Allocator,
    emitted: std.ArrayList(GamepadState),
    prev: GamepadState = .{},
    rises: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    falls: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    fn init(allocator: std.mem.Allocator) GestureEdgeOutput {
        return .{ .allocator = allocator, .emitted = .{} };
    }

    fn deinit(self: *GestureEdgeOutput) void {
        self.emitted.deinit(self.allocator);
    }

    fn outputDevice(self: *GestureEdgeOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn observed(self: *const GestureEdgeOutput, mask: u64) bool {
        return self.rises.load(.acquire) & mask != 0 and
            self.falls.load(.acquire) & mask != 0;
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = emit,
        .poll_ff = pollFf,
        .close = close,
    };

    fn emit(ptr: *anyopaque, current: GamepadState) uinput.EmitError!void {
        const self: *GestureEdgeOutput = @ptrCast(@alignCast(ptr));
        const previous_buttons = self.prev.buttons;
        self.emitted.append(self.allocator, current) catch return error.WriteFailed;
        self.prev = current;
        _ = self.rises.fetchOr(~previous_buttons & current.buttons, .release);
        _ = self.falls.fetchOr(previous_buttons & ~current.buttons, .release);
    }

    fn pollFf(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        return null;
    }

    fn close(_: *anyopaque) void {}
};

fn waitForFrames(stream: *const StreamingDeviceIO, expected: usize) !void {
    for (0..1000) |_| {
        if (stream.framesRead() >= expected) return;
        std.Thread.sleep(std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn waitForGestureEdges(output: *const GestureEdgeOutput, mask: u64) !void {
    for (0..1000) |_| {
        if (output.observed(mask)) return;
        std.Thread.sleep(std.time.ns_per_ms);
    }
    return error.Timeout;
}

test "EventLoop pipeline: A press then release" {
    const allocator = testing.allocator;

    var frame1 = makeFrame(1000, -500, 0x01, 128); // A pressed
    var frame2 = makeFrame(1000, -500, 0x00, 128); // A released

    var mock = try MockDeviceIO.init(allocator, &.{ &frame1, &frame2 });
    defer mock.deinit();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var out = MockOutput.init(allocator);
    defer out.deinit();
    const output = out.outputDevice();

    try mock.signal();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *EventLoop,
        elc: EventLoopContext,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .elc = .{ .devices = &devs, .interpreter = &interp, .output = output, .poll_timeout_ms = 100 },
    };
    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.elc);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(15 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expect(out.diffs.items.len >= 2);

    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_bit;

    // First diff: buttons changed, A pressed
    const d0_btns = out.diffs.items[0].buttons orelse return error.NoDiff;
    try testing.expect(d0_btns & a_mask != 0);
    // Second diff: buttons changed, A released
    const d1_btns = out.diffs.items[1].buttons orelse return error.NoDiff;
    try testing.expect(d1_btns & a_mask == 0);
}

test "EventLoop diagnostics issue 492: Vader5 LS and RS gesture taps keep full output edges" {
    const allocator = testing.allocator;
    padctl_log.setEnabled(true);
    defer padctl_log.setEnabled(false);

    var stream = try StreamingDeviceIO.init();
    defer stream.deinit();
    const dev = stream.deviceIO();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(dev);

    const parsed_device = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed_device.deinit();
    const interp = Interpreter.init(&parsed_device.value);

    const parsed_mapping = try mapping_mod.parseString(allocator,
        \\[remap]
        \\LS = { tap = "LS", hold = "KEY_Z", hold_ms = 1000 }
        \\RS = { tap = "RS", hold = "KEY_Z", hold_ms = 1000 }
    );
    defer parsed_mapping.deinit();
    var mapper = try Mapper.init(&parsed_mapping.value, loop.macro_timer_fd, allocator);
    defer mapper.deinit();

    var out = GestureEdgeOutput.init(allocator);
    defer out.deinit();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *EventLoop,
        elc: EventLoopContext,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .elc = .{
            .devices = &devs,
            .interpreter = &interp,
            .output = out.outputDevice(),
            .mapper = &mapper,
            .device_config = &parsed_device.value,
            .mapping_config = &parsed_mapping.value,
            .poll_timeout_ms = 100,
            .device_tag = "Vader5 diagnostics test",
        },
    };
    const Runner = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.elc);
        }
    };
    const thread = try std.Thread.spawn(.{}, Runner.run, .{&ctx});
    var thread_joined = false;
    defer if (!thread_joined) {
        loop.stop();
        thread.join();
    };

    var wait_count: usize = 0;
    while (!@atomicLoad(bool, &loop.running, .acquire) and wait_count < 200) : (wait_count += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    try testing.expect(@atomicLoad(bool, &loop.running, .acquire));

    const ls_raw_bit: u32 = @as(u32, 1) << 14;
    const rs_raw_bit: u32 = @as(u32, 1) << 15;
    const idle = makeVader5ButtonFrame(0);
    const ls_down = makeVader5ButtonFrame(ls_raw_bit);
    const rs_down = makeVader5ButtonFrame(rs_raw_bit);
    const ls_mask = @as(u64, 1) << @intFromEnum(ButtonId.LS);
    const rs_mask = @as(u64, 1) << @intFromEnum(ButtonId.RS);

    try stream.send(&ls_down);
    try waitForFrames(&stream, 1);
    try stream.send(&idle);
    try waitForFrames(&stream, 2);
    try waitForGestureEdges(&out, ls_mask);
    try stream.send(&rs_down);
    try waitForFrames(&stream, 3);
    try stream.send(&idle);
    try waitForFrames(&stream, 4);
    try waitForGestureEdges(&out, rs_mask);

    loop.stop();
    thread.join();
    thread_joined = true;

    var ls_rises: usize = 0;
    var ls_falls: usize = 0;
    var rs_rises: usize = 0;
    var rs_falls: usize = 0;
    var prev_buttons: u64 = 0;
    for (out.emitted.items) |frame| {
        if (prev_buttons & ls_mask == 0 and frame.buttons & ls_mask != 0) ls_rises += 1;
        if (prev_buttons & ls_mask != 0 and frame.buttons & ls_mask == 0) ls_falls += 1;
        if (prev_buttons & rs_mask == 0 and frame.buttons & rs_mask != 0) rs_rises += 1;
        if (prev_buttons & rs_mask != 0 and frame.buttons & rs_mask == 0) rs_falls += 1;
        prev_buttons = frame.buttons;
    }

    try testing.expectEqual(@as(usize, 1), ls_rises);
    try testing.expectEqual(@as(usize, 1), ls_falls);
    try testing.expectEqual(@as(usize, 1), rs_rises);
    try testing.expectEqual(@as(usize, 1), rs_falls);
}

// --- Layer 2 (manual) ---
// 1. zig build -Doptimize=Debug
// 2. sudo ./zig-out/bin/padctl --config devices/flydigi/vader5.toml
// 3. evtest /dev/input/eventN — verify axes and buttons
// 4. jstest --normal /dev/input/jsN — verify joystick
