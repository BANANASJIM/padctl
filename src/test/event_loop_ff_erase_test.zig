// UI_FF_ERASE stop-emission tests.
//
// A host can stop rumble by erasing the FF effect (EVIOCRMFF) instead of
// writing EV_FF value=0. The Linux ff-memless helper stops a playing effect
// on erase; uinput does not use that helper, so padctl must emulate it. An
// infinite-duration effect that is only ever erased must still produce a stop
// frame and free its scheduler slot, otherwise the motor stays on forever and
// every later stop is suppressed because a slot is permanently "playing".

const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const state = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const device_mod = @import("../config/device.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;

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

// Drain-aware FF mock: each mockPollFf reads one byte from the test pipe
// before returning the next event. After consuming a real event it writes one
// byte to ack_write so the test body can wait for each event to be processed
// before sending the next, providing deterministic ordering without sleeps.
const MockFfOutputDrain = struct {
    events: []const ?uinput.FfEvent,
    call_count: usize = 0,
    pipe_read: posix.fd_t,
    ack_write: posix.fd_t,

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
                // Signal the test body: this real event has been consumed.
                _ = posix.write(self.ack_write, &[_]u8{1}) catch {};
            }
            return ev;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "uinput: eraseStopEvent surfaces a zero rumble FfEvent for the erased slot" {
    const ev = uinput.UinputDevice.eraseStopEvent(3) orelse
        return error.EraseProducedNoStop;
    try testing.expectEqual(@as(u8, 3), ev.effect_id);
    try testing.expectEqual(@as(u16, 0x50), ev.effect_type); // FF_RUMBLE
    try testing.expectEqual(@as(u16, 0), ev.strong);
    try testing.expectEqual(@as(u16, 0), ev.weak);
    try testing.expectEqual(@as(u16, 0), ev.duration_ms);
}

test "uinput: eraseStopEvent ignores out-of-range effect ids" {
    try testing.expectEqual(@as(?uinput.FfEvent, null), uinput.UinputDevice.eraseStopEvent(16));
    try testing.expectEqual(@as(?uinput.FfEvent, null), uinput.UinputDevice.eraseStopEvent(255));
}

test "event_loop: erasing an infinite effect emits a stop frame and frees the slot" {
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

    // Ack pipe: blocking read side; event loop writes one byte per consumed event.
    const ack_pipe = try posix.pipe2(.{});
    defer posix.close(ack_pipe[0]);
    defer posix.close(ack_pipe[1]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // 1) Play an infinite-duration effect (duration_ms=0 → never auto-stops).
    // 2) The host erases it (no EV_FF=0). erase_stop is the event a fixed
    //    pollFf surfaces for UI_FF_ERASE; current code surfaces null, so the
    //    slot leaks and the motor never stops.
    // 3) A different effect plays then is explicitly stopped. The leaked slot
    //    must not suppress this final stop frame.
    // Hand-written stop event for the erased slot — encoded independently of
    // eraseStopEvent so this integration test pins the expected wire shape
    // rather than echoing the helper it indirectly exercises. 0x50 = FF_RUMBLE.
    const erase_stop: ?uinput.FfEvent = .{ .effect_type = 0x50, .effect_id = 0, .strong = 0, .weak = 0, .duration_ms = 0 };
    const seq = [_]?uinput.FfEvent{
        .{ .effect_type = 0x50, .effect_id = 0, .strong = 0x8000, .weak = 0x4000, .duration_ms = 0 },
        erase_stop,
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0x4000, .weak = 0x2000, .duration_ms = 0 },
        .{ .effect_type = 0x50, .effect_id = 1, .strong = 0, .weak = 0, .duration_ms = 0 },
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

    // Ack-based sync: write one byte to ff_pipe[1], then block until the event
    // loop confirms it consumed the event by reading one ack byte. This removes
    // the race where loop.stop() fires before the 4th event is processed.
    // A 15ms gap before each play write still clears the 10ms throttle window.
    const waitAck = struct {
        fn call(ack_read: posix.fd_t) error{AckTimeout}!void {
            var pfd = [1]posix.pollfd{.{ .fd = ack_read, .events = posix.POLL.IN, .revents = 0 }};
            const n = posix.poll(&pfd, 2000) catch return error.AckTimeout;
            if (n == 0) return error.AckTimeout;
            var buf: [1]u8 = undefined;
            _ = posix.read(ack_read, &buf) catch {};
        }
    }.call;

    std.Thread.sleep(15 * std.time.ns_per_ms);
    _ = try posix.write(ff_pipe[1], &[_]u8{1}); // play 0
    try waitAck(ack_pipe[0]);
    std.Thread.sleep(15 * std.time.ns_per_ms);
    _ = try posix.write(ff_pipe[1], &[_]u8{1}); // erase 0 → stop
    try waitAck(ack_pipe[0]);
    std.Thread.sleep(15 * std.time.ns_per_ms);
    _ = try posix.write(ff_pipe[1], &[_]u8{1}); // play 1
    try waitAck(ack_pipe[0]);
    _ = try posix.write(ff_pipe[1], &[_]u8{1}); // explicit stop 1
    try waitAck(ack_pipe[0]);
    loop.stop();
    thread.join();

    // Template: "00 08 00 {strong:u8} {weak:u8} 00 00 00" → 8-byte frame.
    const frame_size = 8;
    const play_0 = [_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 };
    const stop = [_]u8{ 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const play_1 = [_]u8{ 0x00, 0x08, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00 };

    // Expected frames: play 0, stop (from erase), play 1, stop 1.
    try testing.expectEqual(@as(usize, 4 * frame_size), mock_dev.write_log.items.len);
    try testing.expectEqualSlices(u8, &play_0, mock_dev.write_log.items[0..frame_size]);
    try testing.expectEqualSlices(u8, &stop, mock_dev.write_log.items[frame_size .. 2 * frame_size]);
    try testing.expectEqualSlices(u8, &play_1, mock_dev.write_log.items[2 * frame_size .. 3 * frame_size]);
    try testing.expectEqualSlices(u8, &stop, mock_dev.write_log.items[3 * frame_size .. 4 * frame_size]);

    // No slot may remain "playing" after the erase + explicit stop.
    for (loop.rumble_scheduler.dumpSlots()) |s| {
        try testing.expectEqual(@as(i128, 0), s);
    }
}
