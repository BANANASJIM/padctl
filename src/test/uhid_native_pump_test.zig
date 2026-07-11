//! T1 regression coverage for mixed UHID kernel traffic.
//!
//! This uses a nonblocking Unix `SOCK_SEQPACKET` pair to preserve the event
//! boundaries supplied by `/dev/uhid` while also allowing the test to inspect
//! synchronous userspace replies on the peer endpoint.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const posix = std.posix;
const testing = std.testing;

const uhid = @import("../io/uhid.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const device_config = @import("../config/device.zig");
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const MockOutput = @import("mock_output.zig").MockOutput;

const DUMMY_DESCRIPTOR = [_]u8{ 0x05, 0x01, 0xC0 };

fn socketPair() ![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    const rc = linux.socketpair(
        linux.AF.UNIX,
        linux.SOCK.SEQPACKET | linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC,
        0,
        &fds,
    );
    if (linux.E.init(rc) != .SUCCESS) return error.SocketPairFailed;
    return fds;
}

fn sendEvent(fd: posix.fd_t, event: []const u8) !void {
    const n = try posix.write(fd, event);
    try testing.expectEqual(event.len, n);
}

fn fullEvent(event_type: u32) [uhid.UHID_EVENT_SIZE]u8 {
    var event = std.mem.zeroes([uhid.UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, event[0..4], event_type, .little);
    return event;
}

const HandlerCtx = struct {
    get_calls: usize = 0,
    set_calls: usize = 0,
};

fn getFeature(
    context: *anyopaque,
    request: uhid.GetReportRequest,
    reply_data: []u8,
) uhid.GetReportResult {
    const ctx: *HandlerCtx = @ptrCast(@alignCast(context));
    ctx.get_calls += 1;
    if (request.report_type != .feature or
        (request.report_number != 0x09 and request.report_number != 0x20))
    {
        return .{ .err = uhid.UHID_PROTOCOL_ERROR };
    }
    reply_data[0] = request.report_number;
    reply_data[1] = if (request.report_number == 0x09) 0xA9 else 0xB0;
    return .{ .size = 2 };
}

fn setFeature(context: *anyopaque, request: uhid.SetReportRequest) u16 {
    const ctx: *HandlerCtx = @ptrCast(@alignCast(context));
    ctx.set_calls += 1;
    if (request.report_type != .feature or request.report_number != 0x20) {
        return uhid.UHID_PROTOCOL_ERROR;
    }
    if (!std.mem.eql(u8, request.data, &[_]u8{ 0xDE, 0xAD })) {
        return uhid.UHID_PROTOCOL_ERROR;
    }
    return 0;
}

const NativeStubCtx = struct {
    calls: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
};

fn decodeNormalizedStub(context: *anyopaque, report: uhid.OutputReport) ?uhid.RumbleCommand {
    const ctx: *NativeStubCtx = @ptrCast(@alignCast(context));
    _ = ctx.calls.fetchAdd(1, .release);
    if (report.data.len != 2 or report.data[0] != 0xF0) return null;
    const marker = report.data[1];
    return .{
        .strong = @as(u16, marker) * 0x0101,
        .weak = @as(u16, 0xFF - marker) * 0x0101,
    };
}

fn sendStubOutput(fd: posix.fd_t, marker: u8) !void {
    var output = fullEvent(uhid.UHID_OUTPUT);
    output[4] = 0xF0;
    output[5] = marker;
    std.mem.writeInt(u16, output[4100..4102], 2, .little);
    output[4102] = 1;
    try sendEvent(fd, output[0..4103]);
}

fn waitForCalls(ctx: *const NativeStubCtx, expected: usize) !void {
    var attempts: usize = 0;
    while (ctx.calls.load(.acquire) < expected and attempts < 200) : (attempts += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(expected, ctx.calls.load(.acquire));
}

fn waitForPublishes(dev: *uhid.UhidDevice, expected: u64) !void {
    var attempts: usize = 0;
    while (dev.rumbleMailboxSnapshot().publish_count < expected and attempts < 200) : (attempts += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(expected, dev.rumbleMailboxSnapshot().publish_count);
}

fn waitReadable(fd: posix.fd_t, timeout_ms: i32) !void {
    var pfd = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, timeout_ms);
    try testing.expectEqual(@as(usize, 1), ready);
    try testing.expect(pfd[0].revents & (posix.POLL.IN | posix.POLL.HUP) != 0);
}

fn waitPumpExited(dev: *const uhid.UhidDevice) !void {
    var attempts: usize = 0;
    while (!dev.pumpExited() and attempts < 500) : (attempts += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    try testing.expect(dev.pumpExited());
}

const PhysicalWriteMock = struct {
    poll_r: posix.fd_t,
    poll_w: posix.fd_t,
    bytes: [32]u8 = undefined,
    write_len: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn init() !PhysicalWriteMock {
        const fds = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        return .{ .poll_r = fds[0], .poll_w = fds[1] };
    }

    fn deinit(self: *PhysicalWriteMock) void {
        posix.close(self.poll_r);
        posix.close(self.poll_w);
    }

    fn deviceIO(self: *PhysicalWriteMock) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn read(_: *anyopaque, _: []u8) DeviceIO.ReadError!usize {
        return DeviceIO.ReadError.Again;
    }

    fn write(context: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *PhysicalWriteMock = @ptrCast(@alignCast(context));
        if (data.len > self.bytes.len) return DeviceIO.WriteError.Io;
        @memcpy(self.bytes[0..data.len], data);
        self.write_len.store(data.len, .release);
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn pollfd(context: *anyopaque) posix.pollfd {
        const self: *PhysicalWriteMock = @ptrCast(@alignCast(context));
        return .{ .fd = self.poll_r, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };
};

test "uhid_native_t4: pump mailbox burst keeps only normalized latest command" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);

    var stub = NativeStubCtx{};
    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t4-mailbox",
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{ .output_handler = .{
            .ctx = &stub,
            .decode = decodeNormalizedStub,
        } },
    });
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var forbidden_reader_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectError(error.NativePumpOwnsReader, dev.pollOutputReport(&forbidden_reader_buf));

    try sendStubOutput(fds[1], 0x11);
    try sendStubOutput(fds[1], 0x22);
    try sendStubOutput(fds[1], 0x33);
    try waitForPublishes(dev, 3);

    const latest = uhid.RumbleCommand{
        .strong = 0x3333,
        .weak = 0xCCCC,
    };
    try testing.expectEqual(
        uhid.RumbleMailbox.Snapshot{ .publish_count = 3, .pending = latest },
        dev.rumbleMailboxSnapshot(),
    );
    try testing.expectEqual(latest, dev.takeRumbleCommand().?);
    try testing.expectEqual(
        uhid.RumbleMailbox.Snapshot{ .publish_count = 3, .pending = null },
        dev.rumbleMailboxSnapshot(),
    );
    try testing.expectEqual(@as(?uhid.RumbleCommand, null), dev.takeRumbleCommand());

    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);
    dev.close();
}

test "uhid_native_t4: saturated nonblocking wake coalesces without losing publication" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);

    var stub = NativeStubCtx{};
    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t4-eagain",
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{ .output_handler = .{
            .ctx = &stub,
            .decode = decodeNormalizedStub,
        } },
    });
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var saturated: u64 = std.math.maxInt(u64) - 1;
    try testing.expectEqual(@as(usize, 8), try posix.write(dev.rumbleWakeFd(), std.mem.asBytes(&saturated)));
    try sendStubOutput(fds[1], 0x7B);
    try waitForPublishes(dev, 1);
    try testing.expectEqual(uhid.RumbleCommand{
        .strong = 0x7B7B,
        .weak = 0x8484,
    }, dev.takeRumbleCommand().?);
    dev.drainRumbleWake();

    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);
    dev.close();
}

const PumpControlCtx = struct {
    get_calls: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    set_calls: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
};

fn pumpGetFeature(context: *anyopaque, request: uhid.GetReportRequest, reply_data: []u8) uhid.GetReportResult {
    const ctx: *PumpControlCtx = @ptrCast(@alignCast(context));
    _ = ctx.get_calls.fetchAdd(1, .release);
    if (request.report_type != .feature or
        (request.report_number != 0x09 and request.report_number != 0x20))
    {
        return .{ .err = uhid.UHID_PROTOCOL_ERROR };
    }
    reply_data[0] = request.report_number;
    return .{ .size = 1 };
}

fn pumpSetFeature(context: *anyopaque, request: uhid.SetReportRequest) u16 {
    const ctx: *PumpControlCtx = @ptrCast(@alignCast(context));
    _ = ctx.set_calls.fetchAdd(1, .release);
    if (request.report_number != 0x30 or !std.mem.eql(u8, request.data, &[_]u8{0xCC})) {
        return uhid.UHID_PROTOCOL_ERROR;
    }
    return 0;
}

test "uhid_native_t4: sole-reader pump preserves mixed control order and output" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);

    var output_ctx = NativeStubCtx{};
    var control_ctx = PumpControlCtx{};
    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t4-mixed",
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{
            .control_handler = .{
                .ctx = &control_ctx,
                .get_report = pumpGetFeature,
                .set_report = pumpSetFeature,
            },
            .output_handler = .{
                .ctx = &output_ctx,
                .decode = decodeNormalizedStub,
            },
        },
    });
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var start = fullEvent(uhid.UHID_START);
    std.mem.writeInt(u64, start[4..12], 7, .little);
    try sendEvent(fds[1], start[0..12]);
    var open = fullEvent(uhid.UHID_OPEN);
    try sendEvent(fds[1], open[0..4]);

    var get_09 = fullEvent(uhid.UHID_GET_REPORT);
    std.mem.writeInt(u32, get_09[4..8], 0x01020304, .little);
    get_09[8] = 0x09;
    get_09[9] = 0;
    try sendEvent(fds[1], get_09[0..10]);
    try sendStubOutput(fds[1], 0x44);

    var get_20 = fullEvent(uhid.UHID_GET_REPORT);
    std.mem.writeInt(u32, get_20[4..8], 0x11121314, .little);
    get_20[8] = 0x20;
    get_20[9] = 0;
    try sendEvent(fds[1], get_20[0..10]);

    var set = fullEvent(uhid.UHID_SET_REPORT);
    std.mem.writeInt(u32, set[4..8], 0x21222324, .little);
    set[8] = 0x30;
    set[9] = 0;
    std.mem.writeInt(u16, set[10..12], 1, .little);
    set[12] = 0xCC;
    try sendEvent(fds[1], set[0..13]);
    try sendStubOutput(fds[1], 0x55);
    var close = fullEvent(uhid.UHID_CLOSE);
    try sendEvent(fds[1], close[0..4]);
    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);

    try waitForCalls(&output_ctx, 2);
    try waitPumpExited(dev);
    try testing.expectEqual(@as(usize, 2), control_ctx.get_calls.load(.acquire));
    try testing.expectEqual(@as(usize, 1), control_ctx.set_calls.load(.acquire));
    try testing.expectEqual(uhid.RumbleCommand{ .strong = 0x5555, .weak = 0xAAAA }, dev.takeRumbleCommand().?);

    var reply: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try waitReadable(fds[1], 500);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &reply));
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x01020304), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u8, 0x09), reply[12]);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &reply));
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x11121314), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u8, 0x20), reply[12]);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &reply));
    try testing.expectEqual(uhid.UHID_SET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x21222324), std.mem.readInt(u32, reply[4..8], .little));

    dev.close();
}

const CloseCtx = struct {
    dev: *uhid.UhidDevice,

    fn run(ctx: *@This()) void {
        ctx.dev.close();
    }
};

fn makeLifecycleDevice(fds: [2]posix.fd_t, name: []const u8) !*uhid.UhidDevice {
    return uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = name,
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{},
    });
}

test "uhid_native_t4: close writes DESTROY then drains STOP before join and is idempotent" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);
    const dev = try makeLifecycleDevice(fds, "padctl-t4-stop");
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var close_ctx = CloseCtx{ .dev = dev };
    const closer = try std.Thread.spawn(.{}, CloseCtx.run, .{&close_ctx});
    var joined = false;
    defer if (!joined) {
        var stop = fullEvent(uhid.UHID_STOP);
        sendEvent(fds[1], stop[0..4]) catch {};
        closer.join();
    };

    try waitReadable(fds[1], 500);
    var destroy: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &destroy));
    try testing.expectEqual(uhid.UHID_DESTROY, std.mem.readInt(u32, destroy[0..4], .little));

    // The peer is still writable after DESTROY: fd close is forbidden until
    // the pump consumes STOP and the owner joins it.
    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);
    closer.join();
    joined = true;

    try testing.expect(!dev.drainTimedOut());
    try testing.expect(dev.pumpExited());
    try testing.expectEqual(@as(posix.fd_t, -1), dev.fd);
    dev.close();
    try testing.expectEqual(@as(posix.fd_t, -1), dev.fd);
}

test "uhid_native_t4: close drain exits on peer POLLHUP" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    var peer_open = true;
    defer if (peer_open) posix.close(fds[1]);
    const dev = try makeLifecycleDevice(fds, "padctl-t4-hup");
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var close_ctx = CloseCtx{ .dev = dev };
    const closer = try std.Thread.spawn(.{}, CloseCtx.run, .{&close_ctx});
    var joined = false;
    defer if (!joined) closer.join();

    try waitReadable(fds[1], 500);
    var destroy: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &destroy));
    try testing.expectEqual(uhid.UHID_DESTROY, std.mem.readInt(u32, destroy[0..4], .little));
    posix.close(fds[1]);
    peer_open = false;
    closer.join();
    joined = true;

    try testing.expect(dev.pumpExited());
    try testing.expect(!dev.drainTimedOut());
    try testing.expectEqual(@as(posix.fd_t, -1), dev.fd);
}

const NonStopFloodCtx = struct {
    fd: posix.fd_t,
    stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    sent: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn run(ctx: *@This()) void {
        var mask = posix.sigemptyset();
        posix.sigaddset(&mask, linux.SIG.PIPE);
        posix.sigprocmask(linux.SIG.BLOCK, &mask, null);
        var open = fullEvent(uhid.UHID_OPEN);
        while (!ctx.stop.load(.acquire)) {
            const n = posix.write(ctx.fd, open[0..4]) catch {
                std.Thread.sleep(std.time.ns_per_ms);
                continue;
            };
            if (n == 4) _ = ctx.sent.fetchAdd(1, .release);
        }
    }
};

test "uhid_native_t4: continuous non-STOP traffic cannot starve bounded close drain" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);
    const dev = try makeLifecycleDevice(fds, "padctl-t4-timeout");
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var flood = NonStopFloodCtx{ .fd = fds[1] };
    const flood_thread = try std.Thread.spawn(.{}, NonStopFloodCtx.run, .{&flood});
    var flood_joined = false;
    defer if (!flood_joined) {
        flood.stop.store(true, .release);
        flood_thread.join();
    };
    var ready_attempts: usize = 0;
    while (flood.sent.load(.acquire) < 128 and ready_attempts < 500) : (ready_attempts += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    try testing.expect(flood.sent.load(.acquire) >= 128);

    const before = try posix.clock_gettime(.MONOTONIC);
    dev.close();
    const after = try posix.clock_gettime(.MONOTONIC);
    flood.stop.store(true, .release);
    flood_thread.join();
    flood_joined = true;
    const elapsed_ns = (@as(i128, after.sec) - before.sec) * std.time.ns_per_s +
        (@as(i128, after.nsec) - before.nsec);

    try testing.expect(dev.drainTimedOut());
    try testing.expect(dev.pumpExited());
    try testing.expect(elapsed_ns >= 450 * std.time.ns_per_ms);
    try testing.expect(elapsed_ns <= 1000 * std.time.ns_per_ms);
    try testing.expect(flood.sent.load(.acquire) > 128);
}

test "uhid_native_t4: failed CREATE2 after pump start joins thread and releases owned resources" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    // Bind the device to a pipe read-end: pump reads are valid, while the
    // owner-side CREATE2 write fails deterministically without SIGPIPE.
    const fds = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
    defer posix.close(fds[1]);
    const cfg = uhid.Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t4-create-failure",
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{},
    };
    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], cfg);
    defer testing.allocator.destroy(dev);
    defer dev.close();

    try testing.expect(dev.hasNativePump());
    const owned_uhid_fd = dev.fd;
    const owned_mailbox_wake_fd = dev.rumbleWakeFd();
    try testing.expectError(error.UhidCreateFailed, dev.sendCreateOwned(cfg));

    try testing.expect(dev.pumpExited());
    try testing.expect(!dev.hasNativePump());
    try testing.expect(dev.nativeWakeResourcesClosed());

    var wake_poll = [_]posix.pollfd{.{ .fd = owned_mailbox_wake_fd, .events = posix.POLL.IN, .revents = 0 }};
    _ = try posix.poll(&wake_poll, 0);
    try testing.expect(wake_poll[0].revents & posix.POLL.NVAL != 0);

    // sendCreateOwned leaves the UHID fd with its UhidDevice owner. Closing
    // that owner is the final startup-error cleanup step and is idempotent.
    dev.close();
    var uhid_poll = [_]posix.pollfd{.{ .fd = owned_uhid_fd, .events = posix.POLL.IN, .revents = 0 }};
    _ = try posix.poll(&uhid_poll, 0);
    try testing.expect(uhid_poll[0].revents & posix.POLL.NVAL != 0);
    dev.close();
}

test "uhid_native_t4: pump never writes physical device and EventLoop drains mailbox" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const config_toml =
        \\[device]
        \\name = "T4 physical handoff"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "input"
        \\interface = 0
        \\size = 1
        \\[report.match]
        \\offset = 0
        \\expect = [1]
        \\[report.fields]
        \\left_x = { offset = 0, type = "u8" }
        \\[commands.rumble]
        \\interface = 0
        \\template = "a5 {strong:u16le} {weak:u16le}"
    ;
    const parsed = try device_config.parseString(testing.allocator, config_toml);
    defer parsed.deinit();
    const interpreter = Interpreter.init(&parsed.value);

    var physical = try PhysicalWriteMock.init();
    defer physical.deinit();
    var physical_devices = [_]DeviceIO{physical.deviceIO()};

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(physical_devices[0]);

    const fds = try socketPair();
    defer posix.close(fds[1]);
    var stub = NativeStubCtx{};
    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t4-event-loop",
        .descriptor = &DUMMY_DESCRIPTOR,
        .native_pump = .{ .output_handler = .{
            .ctx = &stub,
            .decode = decodeNormalizedStub,
        } },
    });
    defer testing.allocator.destroy(dev);
    defer dev.close();
    try loop.addNativeUhidRumble(dev);

    try sendStubOutput(fds[1], 0x66);
    try waitForPublishes(dev, 1);
    // The pump has decoded and published, but has no DeviceIO and therefore
    // cannot perform the physical command write itself.
    try testing.expectEqual(@as(usize, 0), physical.write_len.load(.acquire));

    var output = MockOutput.init(testing.allocator);
    defer output.deinit();
    const RunCtx = struct {
        event_loop: *EventLoop,
        devices: []DeviceIO,
        interpreter: *const Interpreter,
        output: *MockOutput,
        config: *const device_config.DeviceConfig,

        fn run(ctx: *@This()) !void {
            try ctx.event_loop.run(.{
                .devices = ctx.devices,
                .interpreter = ctx.interpreter,
                .output = ctx.output.outputDevice(),
                .allocator = testing.allocator,
                .device_config = ctx.config,
                .poll_timeout_ms = 20,
                .device_tag = "t4",
            });
        }
    };
    var run_ctx = RunCtx{
        .event_loop = &loop,
        .devices = &physical_devices,
        .interpreter = &interpreter,
        .output = &output,
        .config = &parsed.value,
    };
    const event_thread = try std.Thread.spawn(.{}, RunCtx.run, .{&run_ctx});
    var attempts: usize = 0;
    while (physical.write_len.load(.acquire) == 0 and attempts < 500) : (attempts += 1) {
        std.Thread.sleep(std.time.ns_per_ms);
    }
    loop.stop();
    event_thread.join();

    const write_len = physical.write_len.load(.acquire);
    try testing.expectEqual(@as(usize, 5), write_len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xA5, 0x66, 0x66, 0x99, 0x99 }, physical.bytes[0..write_len]);

    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);
    dev.close();
}

test "uhid_native_t1: mixed stream requires request-id replies and preserves output" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t1-baseline",
        .descriptor = &DUMMY_DESCRIPTOR,
    });
    defer testing.allocator.destroy(dev);

    var handler_ctx = HandlerCtx{};
    dev.setControlHandler(.{
        .ctx = &handler_ctx,
        .get_report = getFeature,
        .set_report = setFeature,
    });

    var start = fullEvent(uhid.UHID_START);
    std.mem.writeInt(u64, start[4..12], 0x07, .little);
    try sendEvent(fds[1], start[0..12]);

    var open = fullEvent(uhid.UHID_OPEN);
    try sendEvent(fds[1], open[0..4]);

    var get = fullEvent(uhid.UHID_GET_REPORT);
    std.mem.writeInt(u32, get[4..8], 0x11223344, .little);
    get[8] = 0x09;
    get[9] = 0; // UHID_FEATURE_REPORT
    try sendEvent(fds[1], get[0..10]);

    var output = fullEvent(uhid.UHID_OUTPUT);
    output[4] = 0x02;
    output[5] = 0xA5;
    std.mem.writeInt(u16, output[4100..4102], 2, .little);
    output[4102] = 1; // UHID_OUTPUT_REPORT
    try sendEvent(fds[1], output[0..4103]);

    var get_second = fullEvent(uhid.UHID_GET_REPORT);
    std.mem.writeInt(u32, get_second[4..8], 0x22334455, .little);
    get_second[8] = 0x20;
    get_second[9] = 0;
    try sendEvent(fds[1], get_second[0..10]);

    var set = fullEvent(uhid.UHID_SET_REPORT);
    std.mem.writeInt(u32, set[4..8], 0x55667788, .little);
    set[8] = 0x20;
    set[9] = 0; // UHID_FEATURE_REPORT
    std.mem.writeInt(u16, set[10..12], 2, .little);
    set[12] = 0xDE;
    set[13] = 0xAD;
    try sendEvent(fds[1], set[0..14]);

    var output_second = fullEvent(uhid.UHID_OUTPUT);
    output_second[4] = 0x02;
    output_second[5] = 0x5A;
    std.mem.writeInt(u16, output_second[4100..4102], 2, .little);
    output_second[4102] = 1;
    try sendEvent(fds[1], output_second[0..4103]);

    var close = fullEvent(uhid.UHID_CLOSE);
    try sendEvent(fds[1], close[0..4]);

    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);

    var read_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const report = (try dev.pollOutputReport(&read_buf)).?;
    try testing.expectEqualSlices(u8, &[_]u8{ 0x02, 0xA5 }, report.data);
    try testing.expectEqual(uhid.ReportType.output, report.report_type);
    const second_report = (try dev.pollOutputReport(&read_buf)).?;
    try testing.expectEqualSlices(u8, &[_]u8{ 0x02, 0x5A }, second_report.data);
    try testing.expectEqual(@as(?uhid.OutputReport, null), try dev.pollOutputReport(&read_buf));
    try testing.expectEqual(@as(usize, 2), handler_ctx.get_calls);
    try testing.expectEqual(@as(usize, 1), handler_ctx.set_calls);

    var reply: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const reply_n = try posix.read(fds[1], &reply);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, reply_n);
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x11223344), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[8..10], .little));
    try testing.expectEqual(@as(u16, 2), std.mem.readInt(u16, reply[10..12], .little));
    try testing.expectEqualSlices(u8, &[_]u8{ 0x09, 0xA9 }, reply[12..14]);

    const second_get_reply_n = try posix.read(fds[1], &reply);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, second_get_reply_n);
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x22334455), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[8..10], .little));
    try testing.expectEqualSlices(u8, &[_]u8{ 0x20, 0xB0 }, reply[12..14]);

    const set_reply_n = try posix.read(fds[1], &reply);
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, set_reply_n);
    try testing.expectEqual(uhid.UHID_SET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x55667788), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[8..10], .little));
}

test "uhid_native_t1: unsupported SET_REPORT replies with same id and nonzero error" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t1-unsupported-set",
        .descriptor = &DUMMY_DESCRIPTOR,
    });
    defer testing.allocator.destroy(dev);

    var set = fullEvent(uhid.UHID_SET_REPORT);
    std.mem.writeInt(u32, set[4..8], 0xC3D4E5F6, .little);
    set[8] = 0xEE;
    set[9] = 0;
    std.mem.writeInt(u16, set[10..12], 1, .little);
    set[12] = 0xAA;
    try sendEvent(fds[1], set[0..13]);

    var event_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(@as(?uhid.OutputReport, null), try dev.pollOutputReport(&event_buf));

    var reply: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &reply));
    try testing.expectEqual(uhid.UHID_SET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0xC3D4E5F6), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expect(std.mem.readInt(u16, reply[8..10], .little) != 0);
}

test "uhid_native_t1: unsupported GET_REPORT replies with same id and nonzero error" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t1-unsupported",
        .descriptor = &DUMMY_DESCRIPTOR,
    });
    defer testing.allocator.destroy(dev);

    var get = fullEvent(uhid.UHID_GET_REPORT);
    std.mem.writeInt(u32, get[4..8], 0xA1B2C3D4, .little);
    get[8] = 0xEE;
    get[9] = 0;
    try sendEvent(fds[1], get[0..10]);

    var event_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(@as(?uhid.OutputReport, null), try dev.pollOutputReport(&event_buf));

    var reply: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    try testing.expectEqual(uhid.UHID_EVENT_SIZE, try posix.read(fds[1], &reply));
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0xA1B2C3D4), std.mem.readInt(u32, reply[4..8], .little));
    try testing.expect(std.mem.readInt(u16, reply[8..10], .little) != 0);
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[10..12], .little));
}

test "uhid_native_t1: readEvent zero-extends a four-byte STOP" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t1-zero-extend",
        .descriptor = &DUMMY_DESCRIPTOR,
    });
    defer testing.allocator.destroy(dev);

    var stop = fullEvent(uhid.UHID_STOP);
    try sendEvent(fds[1], stop[0..4]);

    var event_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    @memset(&event_buf, 0xA5);
    const event = (try dev.readEvent(&event_buf)).?;
    try testing.expect(event == .stop);
    for (event_buf[4..]) |byte| try testing.expectEqual(@as(u8, 0), byte);
}

test "uhid_native_t1: decoder rejects truncated and oversized SET_REPORT and OUTPUT" {
    var set = fullEvent(uhid.UHID_SET_REPORT);
    std.mem.writeInt(u16, set[10..12], 2, .little);
    set[12] = 0xAA;
    try testing.expectError(error.IncompleteUhidEvent, uhid.decodeEvent(&set, 13));
    std.mem.writeInt(u16, set[10..12], uhid.UHID_DATA_MAX + 1, .little);
    try testing.expectError(error.OversizedUhidDeclaration, uhid.decodeEvent(&set, 12));

    var output = fullEvent(uhid.UHID_OUTPUT);
    output[4] = 0x02;
    std.mem.writeInt(u16, output[4100..4102], 1, .little);
    try testing.expectError(error.IncompleteUhidEvent, uhid.decodeEvent(&output, 4102));
    std.mem.writeInt(u16, output[4100..4102], uhid.UHID_DATA_MAX + 1, .little);
    try testing.expectError(error.OversizedUhidDeclaration, uhid.decodeEvent(&output, 4103));
}
