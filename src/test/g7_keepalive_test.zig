const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const device = @import("../config/device.zig");
const Keepalive = @import("../core/keepalive.zig").Keepalive;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const state = @import("../core/state.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const uinput = @import("../io/uinput.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const path = "devices/gamesir/g7-pro-amazon-wired.toml";
const ms = std.time.ns_per_ms;

fn btn(id: state.ButtonId) u64 {
    return @as(u64, 1) << @intFromEnum(id);
}

// Independently encoded author-reported telemetry header and neutral state.
// Bytes9/10 deliberately contain post-remap A; raw/pre-remap byte55 does not.
fn neutralPacket() [64]u8 {
    var raw = [_]u8{0} ** 64;
    raw[0] = 0x10;
    raw[1] = 0x91;
    raw[2] = 0x37;
    raw[3] = 0x3c;
    raw[4] = 0xe0;
    @memcpy(raw[5..9], &[_]u8{ 128, 128, 128, 128 });
    raw[9] = 0x20;
    raw[55] = 8;
    return raw;
}

fn expectPacket(actual: []const u8, seq: u8) !void {
    var expected = [_]u8{0} ** 64;
    @memcpy(expected[0..6], &[_]u8{ 0x0f, 0x00, seq, 0x02, 0xf2, 0x00 });
    try testing.expectEqualSlices(u8, &expected, actual);
}

test "G7 keepalive: exact packets and source startup cadence use completion time" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    var ka = try Keepalive.init(parsed.value.device.keepalive.?, 0);
    var mock = try MockDeviceIO.init(testing.allocator, &.{});
    defer mock.deinit();
    const times = [_]i128{ 0, 50, 100, 150, 600 };
    for (times, 1..) |time, seq| {
        try testing.expect(ka.due(time * ms));
        try expectPacket(ka.packet(), @intCast(seq));
        try mock.deviceIO().write(ka.packet());
        ka.submitted();
        try testing.expect(!ka.due((time + 10000) * ms)); // one in flight
        try ka.completed(time * ms, true);
        try testing.expect(!ka.due(ka.deadline_ns - 1));
    }
    try testing.expectEqual(@as(usize, 5 * 64), mock.write_log.items.len);
    // Long write/stalled input processing never queues historical deadlines.
    try testing.expect(ka.due(10000 * ms));
    ka.submitted();
    try ka.completed(11000 * ms, true);
    try testing.expectEqual(@as(i128, 11450 * ms), ka.deadline_ns);
    try testing.expect(!ka.due(11000 * ms));
}

test "G7 keepalive: wrap, bounded failure, pause and physical reset" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    var cfg = parsed.value.device.keepalive.?;
    cfg.sequence_start = 255;
    var ka = try Keepalive.init(cfg, 0);
    try expectPacket(ka.packet(), 255);
    ka.submitted();
    try ka.completed(0, true);
    try expectPacket(ka.packet(), 1);
    ka.submitted();
    try ka.completed(50 * ms, false);
    try testing.expectEqual(@as(i128, 500 * ms), ka.deadline_ns);
    ka.submitted();
    try ka.completed(500 * ms, false);
    ka.submitted();
    try testing.expectError(error.KeepaliveWriteFailed, ka.completed(950 * ms, false));
    ka.pause(1000 * ms);
    try testing.expect(!ka.due(100000 * ms));
    const next_seq = ka.sequence;
    ka.restart(1000 * ms);
    try testing.expectEqual(next_seq, ka.sequence); // mapping restart retains sequence
    try testing.expect(!ka.due(1000 * ms));
    ka = try Keepalive.init(parsed.value.device.keepalive.?, 2000 * ms);
    try expectPacket(ka.packet(), 1); // newly claimed/rebound physical device
    try testing.expect(ka.due(2000 * ms));
}

test "G7 keepalive: parser rejects unsafe maintenance" {
    var parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    const original = parsed.value.device.keepalive.?;
    const bad = [_]device.KeepaliveConfig{
        .{ .interface = 0, .packet = "0f00", .report_size = 64, .period_ms = 450, .sequence_offset = 1, .sequence_start = 0, .sequence_skip_zero = true },
        .{ .interface = 9, .packet = "0f00", .report_size = 64, .period_ms = 450, .sequence_offset = 1 },
        .{ .interface = 0, .packet = "0f00", .report_size = 65, .period_ms = 450, .sequence_offset = 1 },
        .{ .interface = 0, .packet = "0f00", .report_size = 64, .period_ms = 0, .sequence_offset = 1 },
        .{ .interface = 0, .packet = "0f00", .report_size = 64, .period_ms = 450, .sequence_offset = 2 },
        .{ .interface = 0, .packet = "0f0", .report_size = 64, .period_ms = 450, .sequence_offset = 1 },
        .{ .interface = 0, .packet = "0fgg", .report_size = 64, .period_ms = 450, .sequence_offset = 1 },
        .{ .interface = 0, .packet = "0f00", .report_size = 1, .period_ms = 450, .sequence_offset = 0 },
        .{ .interface = 0, .packet = "0f00", .report_size = 64, .period_ms = 450, .sequence_offset = 1, .startup_count = 33 },
    };
    for (bad) |cfg| {
        parsed.value.device.keepalive = cfg;
        try testing.expectError(error.InvalidConfig, device.validate(&parsed.value));
    }
    parsed.value.device.keepalive = original;
    try device.validate(&parsed.value);
}

test "G7 keepalive: telemetry suffix matching rejects non-input markers" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    var raw = neutralPacket();
    const interp = Interpreter.init(&parsed.value);
    for (0..256) |header| {
        // Existing exact match at byte3 intentionally leaves bytes0..2 unchecked.
        raw[0] = @intCast(header);
        raw[1] = @intCast(255 - header);
        raw[2] = @intCast(header);
        try testing.expect((try interp.processReport(0, &raw)) != null);
    }
    for ([_]usize{ 3, 4 }) |off| {
        var wrong = raw;
        wrong[off] ^= 1;
        try testing.expect((try interp.processReport(0, &wrong)) == null);
    }
    raw[4] = 0x05; // register response marker, not telemetry marker e0
    try testing.expect((try interp.processReport(0, &raw)) == null);
    raw = neutralPacket();
    try testing.expect((try interp.processReport(1, &raw)) == null);
    try testing.expect((try interp.processReport(0, raw[0..63])) == null);
}

test "G7 keepalive: production writer emits source sequence 1 through 255 then 1" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    var ka = try Keepalive.init(parsed.value.device.keepalive.?, 0);
    var mock = try MockDeviceIO.init(testing.allocator, &.{});
    defer mock.deinit();
    var writer: @import("../core/rumble_writer.zig").RumbleWriter = .{};
    // Rejected admission must not consume the first wire sequence.
    try testing.expectError(error.NotRunning, writer.publishKeepalive(mock.deviceIO(), ka.packet()));
    try expectPacket(ka.packet(), 1);
    try writer.start();
    defer writer.stop();
    for (0..257) |i| {
        try testing.expect(ka.due(ka.deadline_ns));
        try writer.publishKeepalive(mock.deviceIO(), ka.packet());
        ka.submitted();
        try readable(writer.completionFd());
        const completion = writer.takeCompletion().?;
        try testing.expectEqual(.keepalive, completion.kind);
        try testing.expectEqual(.written, completion.result);
        try ka.completed(ka.deadline_ns, true);
        // Independent oracle follows source control.py's 1..255 counter.
        try expectPacket(mock.write_log.items[i * 64 ..][0..64], @intCast(i % 255 + 1));
    }
    try testing.expectEqual(@as(usize, 257 * 64), mock.write_log.items.len);
    // Legacy generic default remains modulo256, including a zero byte.
    var legacy: device.KeepaliveConfig = .{
        .interface = 0,
        .packet = "0f000002f200",
        .report_size = 64,
        .period_ms = 450,
        .sequence_offset = 2,
        .sequence_start = 255,
    }; // omission proves the generic default, not an explicit false override
    ka = try Keepalive.init(legacy, 0);
    try expectPacket(ka.packet(), 255);
    ka.submitted();
    try ka.completed(0, true);
    try expectPacket(ka.packet(), 0);
    legacy.sequence_skip_zero = true;
    legacy.sequence_start = 0;
    try testing.expectError(error.InvalidConfig, Keepalive.init(legacy, 0));
}

test "G7 keepalive: pre-remap buttons, four extras, hats and processed axes" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    try testing.expectEqual(@as(i64, 0x3537), parsed.value.device.vid);
    try testing.expectEqual(@as(i64, 0x10ba), parsed.value.device.pid);
    const interp = Interpreter.init(&parsed.value);
    var raw = neutralPacket();
    const center = (try interp.processReport(0, &raw)).?;
    try testing.expectEqual(@as(?i16, 128), center.ax);
    try testing.expectEqual(@as(?i16, 128), center.ay);
    try testing.expectEqual(@as(?u64, 0), center.buttons); // ignores post-remap A
    const buttons = [_]state.ButtonId{ .X, .A, .B, .Y, .LB, .RB, .Select, .Start, .LS, .RS, .Home, .Capture, .M1, .M2, .M3, .M4 };
    const positions = [_][2]u8{ .{ 55, 0x10 }, .{ 55, 0x20 }, .{ 55, 0x40 }, .{ 55, 0x80 }, .{ 56, 1 }, .{ 56, 2 }, .{ 56, 0x10 }, .{ 56, 0x20 }, .{ 56, 0x40 }, .{ 56, 0x80 }, .{ 57, 1 }, .{ 57, 2 }, .{ 57, 8 }, .{ 57, 0x10 }, .{ 58, 1 }, .{ 58, 2 } };
    for (buttons, positions) |id, pos| {
        raw = neutralPacket();
        raw[pos[0]] |= pos[1];
        raw[60] = 0xff; // analog RT must never turn into extra buttons
        const delta = (try interp.processReport(0, &raw)).?;
        try testing.expectEqual(@as(?u64, btn(id)), delta.buttons);
    }
    const hats = [_]u64{ btn(.DPadUp), btn(.DPadUp) | btn(.DPadRight), btn(.DPadRight), btn(.DPadRight) | btn(.DPadDown), btn(.DPadDown), btn(.DPadDown) | btn(.DPadLeft), btn(.DPadLeft), btn(.DPadLeft) | btn(.DPadUp), 0 };
    for (hats, 0..) |expected, hat| {
        raw = neutralPacket();
        raw[55] = @intCast(hat);
        try testing.expectEqual(@as(?u64, expected), (try interp.processReport(0, &raw)).?.buttons);
    }
    raw[55] = 15;
    try testing.expectEqual(@as(?u64, 0), (try interp.processReport(0, &raw)).?.buttons);
    raw = neutralPacket();
    @memcpy(raw[5..9], &[_]u8{ 0, 255, 1, 254 });
    raw[12] = 23;
    raw[13] = 231;
    const edges = (try interp.processReport(0, &raw)).?;
    try testing.expectEqual(@as(?i16, -32768), edges.ax);
    try testing.expectEqual(@as(?i16, 32767), edges.ay);
    try testing.expectEqual(@as(?i16, -32511), edges.rx);
    try testing.expectEqual(@as(?i16, 32510), edges.ry);
    try testing.expectEqual(@as(?u8, 23), edges.lt);
    try testing.expectEqual(@as(?u8, 231), edges.rt);
}

// Drains its single notification on the first read, but keeps 130 reports
// buffered. The transport worker can be deliberately blocked at write().
const BacklogDevice = struct {
    wake: [2]posix.fd_t,
    started: [2]posix.fd_t,
    release: [2]posix.fd_t,
    drained: [2]posix.fd_t,
    reads: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    writes: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    remaining: usize = 130,
    block_write: bool = true,
    fail_write: bool = false,
    written: [64]u8 = .{0} ** 64,

    fn init() !BacklogDevice {
        const wake = try posix.pipe2(.{ .NONBLOCK = true });
        errdefer {
            posix.close(wake[0]);
            posix.close(wake[1]);
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
        const drained = try posix.pipe2(.{ .NONBLOCK = true });
        return .{ .wake = wake, .started = started, .release = release, .drained = drained };
    }
    fn deinit(self: *BacklogDevice) void {
        for ([_][2]posix.fd_t{ self.wake, self.started, self.release, self.drained }) |pair| {
            posix.close(pair[0]);
            posix.close(pair[1]);
        }
    }
    fn io(self: *BacklogDevice) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable = DeviceIO.VTable{ .read = read, .write = write, .feature_report = feature, .pollfd = pollfd, .close = close };
    fn read(ptr: *anyopaque, bytes: []u8) DeviceIO.ReadError!usize {
        const self: *BacklogDevice = @ptrCast(@alignCast(ptr));
        var notification: [64]u8 = undefined;
        _ = posix.read(self.wake[0], &notification) catch {};
        if (self.remaining == 0) return error.Again;
        const packet = neutralPacket();
        @memcpy(bytes[0..64], &packet);
        self.remaining -= 1;
        _ = self.reads.fetchAdd(1, .release);
        if (self.remaining == 0) _ = posix.write(self.drained[1], "d") catch {};
        return 64;
    }
    fn write(ptr: *anyopaque, bytes: []const u8) DeviceIO.WriteError!void {
        const self: *BacklogDevice = @ptrCast(@alignCast(ptr));
        @memcpy(&self.written, bytes);
        _ = self.writes.fetchAdd(1, .release);
        _ = posix.write(self.started[1], "s") catch {};
        if (self.block_write) {
            var ack: [1]u8 = undefined;
            _ = posix.read(self.release[0], &ack) catch return error.Io;
        }
        if (self.fail_write) return error.Io;
    }
    fn feature(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        return error.Io;
    }
    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *BacklogDevice = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.wake[0], .events = posix.POLL.IN, .revents = 0 };
    }
    fn close(_: *anyopaque) void {}
};

const Output = struct {
    count: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    fn io(self: *Output) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable = uinput.OutputDevice.VTable{ .emit = emit, .poll_ff = ff, .close = close };
    fn emit(ptr: *anyopaque, _: state.GamepadState) uinput.EmitError!void {
        const self: *Output = @ptrCast(@alignCast(ptr));
        _ = self.count.fetchAdd(1, .release);
    }
    fn ff(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        return null;
    }
    fn close(_: *anyopaque) void {}
};
fn readable(fd: posix.fd_t) !void {
    var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    try testing.expectEqual(@as(usize, 1), try posix.poll(&fds, 1000));
    try testing.expect(fds[0].revents & posix.POLL.IN != 0);
}
const Run = struct {
    loop: *EventLoop,
    context: @import("../event_loop.zig").EventLoopContext,
    result: ?anyerror = null,
    fn run(self: *Run) void {
        self.loop.run(self.context) catch |err| {
            self.result = err;
        };
    }
};

test "G7 keepalive: single-wake backlog crosses input budget while physical writer blocks" {
    const parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var mock = try BacklogDevice.init();
    defer mock.deinit();
    var output = Output{};
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    var devices = [_]DeviceIO{mock.io()};
    try loop.addDevice(devices[0]);
    var run = Run{ .loop = &loop, .context = .{ .devices = &devices, .interpreter = &interp, .output = output.io(), .device_config = &parsed.value, .allocator = testing.allocator } };
    _ = try posix.write(mock.wake[1], "w");
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    var joined = false;
    defer {
        loop.stop();
        _ = posix.write(mock.release[1], "r") catch {};
        if (!joined) thread.join();
    }
    try readable(mock.started[0]);
    try readable(mock.drained[0]);
    try testing.expectEqual(@as(usize, 130), mock.reads.load(.acquire));
    // Stop notification plus release is joined before physical fds are closed.
    loop.stop();
    _ = try posix.write(mock.release[1], "r");
    thread.join();
    joined = true;
    try testing.expectEqual(@as(?anyerror, null), run.result);
    try testing.expectEqual(@as(usize, 130), output.count.load(.acquire));
    try testing.expectEqual(@as(usize, 1), mock.writes.load(.acquire));
    try expectPacket(&mock.written, 1);
}

test "G7 keepalive: idle loop wakes and three transport errors stop the virtual session" {
    var parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    parsed.value.device.keepalive.?.period_ms = 10;
    const interp = Interpreter.init(&parsed.value);
    var mock = try BacklogDevice.init();
    defer mock.deinit();
    mock.remaining = 0;
    mock.block_write = false;
    mock.fail_write = true;
    var output = Output{};
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    var devices = [_]DeviceIO{mock.io()};
    try loop.addDevice(devices[0]);
    try testing.expectError(error.KeepaliveWriteFailed, loop.run(.{ .devices = &devices, .interpreter = &interp, .output = output.io(), .device_config = &parsed.value, .allocator = testing.allocator }));
    try testing.expect(loop.disconnected);
    try testing.expectEqual(@as(usize, 3), mock.writes.load(.acquire));
    try testing.expect(!loop.rumble_writer.isRunning());
}

test "G7 keepalive: failed init cleans worker and rebind reset is transactional" {
    var parsed = try device.parseFile(testing.allocator, path);
    defer parsed.deinit();
    parsed.value.device.keepalive.?.report_size = 0; // runtime caller bypassed parse validation
    const interp = Interpreter.init(&parsed.value);
    var mock = try BacklogDevice.init();
    defer mock.deinit();
    var output = Output{};
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    var devices = [_]DeviceIO{mock.io()};
    try loop.addDevice(devices[0]);
    try testing.expectError(error.InvalidConfig, loop.run(.{ .devices = &devices, .interpreter = &interp, .output = output.io(), .device_config = &parsed.value, .allocator = testing.allocator }));
    try testing.expect(!loop.rumble_writer.isRunning());
    try testing.expectEqual(@as(posix.fd_t, -1), loop.pollfds[loop.rumble_writer_slot.?].fd);
    parsed.value.device.keepalive.?.report_size = 64;
    loop.keepalive = try Keepalive.init(parsed.value.device.keepalive.?, 0);
    loop.keepalive.?.sequence = 88;
    try testing.expectError(error.DeviceCountMismatch, loop.rebindDevices(&.{}));
    try testing.expectEqual(@as(u8, 88), loop.keepalive.?.sequence);
    try loop.rebindDevices(&devices);
    try testing.expect(loop.keepalive == null);
}

// A valid legacy HID PID passthrough setup, before adding maintenance. Its
// FfbForwarder uses a direct physical fd writer, unlike queued rumble output.
const pid_base =
    \\[device]
    \\name = "PID maintenance contract"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 1
;
const pid_output =
    \\[output.imu]
    \\backend = "uhid"
    \\[output.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
;
const pid_profile =
    \\[output.profiles.passthrough.imu]
    \\backend = "uhid"
    \\[output.profiles.passthrough.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
;
const pid_maintenance =
    \\[device.keepalive]
    \\interface = 0
    \\packet = "00"
    \\report_size = 1
    \\period_ms = 50
    \\sequence_offset = 0
;

test "G7 keepalive: reject second physical PID writer in root and profiles, preserve legacy and queued rumble" {
    const root = try device.parseString(testing.allocator, pid_base ++ "\n" ++ pid_output);
    defer root.deinit();
    try device.validate(&root.value);
    const profile = try device.parseString(testing.allocator, pid_base ++ "\n" ++ pid_profile);
    defer profile.deinit();
    try device.validate(&profile.value);
    try testing.expectError(error.InvalidConfig, device.parseString(testing.allocator, pid_base ++ "\n" ++ pid_output ++ "\n" ++ pid_maintenance));
    try testing.expectError(error.InvalidConfig, device.parseString(testing.allocator, pid_base ++ "\n" ++ pid_profile ++ "\n" ++ pid_maintenance));
    const queued = try device.parseString(testing.allocator, pid_base ++ "\n" ++ pid_maintenance ++ "\n" ++
        \\[output.force_feedback]
        \\backend = "uinput"
        \\kind = "rumble"
    );
    defer queued.deinit();
    try device.validate(&queued.value);
}
