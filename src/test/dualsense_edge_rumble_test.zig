//! T7 end-to-end handoff coverage for native DualSense Edge USB rumble.
//!
//! The test injects kernel-shaped UHID_OUTPUT packets at the DeviceInstance
//! boundary. Production code then owns every transition: EdgeRuntime invokes
//! the audited codec, the sole-reader pump publishes to its latest-wins
//! mailbox, and DeviceInstance.run/EventLoop formats `[commands.rumble]` for
//! the physical DeviceIO.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const posix = std.posix;
const testing = std.testing;

const device_config = @import("../config/device.zig");
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const uhid = @import("../io/uhid.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;

const NATIVE_RUMBLE_TOML =
    \\[device]
    \\name = "T7 physical Edge handoff"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[commands.rumble]
    \\interface = 0
    \\template = "d0 {strong:u16le} {weak:u16le} d1"
    \\[output]
    \\emulate = "dualsense-edge"
    \\backend = "uhid"
    \\protocol = "dualsense-edge-usb"
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    \\right_x = { code = "ABS_RX", min = 0, max = 255 }
    \\right_y = { code = "ABS_RY", min = 0, max = 255 }
    \\lt = { code = "ABS_Z", min = 0, max = 255 }
    \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    \\[output.force_feedback]
    \\type = "rumble"
    \\[output.touch_synthesis]
    \\left_button = "C"
    \\right_button = "Z"
    \\left_x = 480
    \\right_x = 1440
    \\y = 540
    \\click = true
;

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

fn waitReadable(fd: posix.fd_t) !void {
    var pfd = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 1000);
    try testing.expectEqual(@as(usize, 1), ready);
    try testing.expect(pfd[0].revents & (posix.POLL.IN | posix.POLL.HUP) != 0);
}

fn readEvent(fd: posix.fd_t, buf: *[uhid.UHID_EVENT_SIZE]u8) ![]const u8 {
    try waitReadable(fd);
    const n = try posix.read(fd, buf);
    try testing.expect(n >= 4);
    return buf[0..n];
}

fn sendEvent(fd: posix.fd_t, event: []const u8) !void {
    try testing.expectEqual(event.len, try posix.write(fd, event));
}

fn sendOutput(fd: posix.fd_t, report: []const u8) !void {
    try testing.expect(report.len <= uhid.UHID_DATA_MAX);
    var event = std.mem.zeroes([uhid.UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, event[0..4], uhid.UHID_OUTPUT, .little);
    @memcpy(event[4 .. 4 + report.len], report);
    std.mem.writeInt(u16, event[4100..4102], @intCast(report.len), .little);
    event[4102] = @intFromEnum(uhid.ReportType.output);
    try sendEvent(fd, event[0..4103]);
}

/// A feature GET queued after the output packets is an in-band barrier for
/// the sole-reader pump. Receiving its reply proves all earlier packets have
/// passed through the production decoder and mailbox publication point.
fn pumpBarrier(fd: posix.fd_t, scratch: *[uhid.UHID_EVENT_SIZE]u8) !void {
    const request_id: u32 = 0x74370005;
    var event = [_]u8{0} ** 10;
    std.mem.writeInt(u32, event[0..4], uhid.UHID_GET_REPORT, .little);
    std.mem.writeInt(u32, event[4..8], request_id, .little);
    event[8] = 0x05;
    event[9] = @intFromEnum(uhid.ReportType.feature);
    try sendEvent(fd, &event);

    const reply = try readEvent(fd, scratch);
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(request_id, std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[8..10], .little));
}

fn expectMailboxWake(device: *uhid.UhidDevice, expected: bool) !void {
    var pfd = [_]posix.pollfd{.{
        .fd = device.rumbleWakeFd(),
        .events = posix.POLL.IN,
        .revents = 0,
    }};
    const ready = try posix.poll(&pfd, if (expected) 1000 else 0);
    if (expected) {
        try testing.expectEqual(@as(usize, 1), ready);
        try testing.expect(pfd[0].revents & posix.POLL.IN != 0);
    } else {
        try testing.expectEqual(@as(usize, 0), ready);
    }
}

fn sendStop(fd: posix.fd_t) !void {
    var event: [4]u8 = undefined;
    std.mem.writeInt(u32, &event, uhid.UHID_STOP, .little);
    try sendEvent(fd, &event);
}

const DestroyResponder = struct {
    fd: posix.fd_t,
    saw_destroy: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *DestroyResponder) void {
        var scratch: [uhid.UHID_EVENT_SIZE]u8 = undefined;
        const event = readEvent(self.fd, &scratch) catch {
            self.failed.store(true, .release);
            return;
        };
        if (std.mem.readInt(u32, event[0..4], .little) != uhid.UHID_DESTROY) {
            self.failed.store(true, .release);
            return;
        }
        self.saw_destroy.store(true, .release);
        sendStop(self.fd) catch self.failed.store(true, .release);
    }
};

fn runHandoff(
    reports: []const []const u8,
    expect_publication: bool,
    expected_physical_write: []const u8,
) !void {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_RUMBLE_TOML);
    defer parsed.deinit();

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = physical.deviceIO();

    const pair = try socketPair();
    defer posix.close(pair[1]);
    var counter: u16 = 0x4717;
    var instance = try DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        "phys-t7-rumble",
        &counter,
        .{
            .test_primary_uhid_fd = pair[0],
            .test_devices_override = devices,
        },
    );
    var live = true;
    defer if (live) {
        // Failure-only escape hatch. The normal path below enforces the
        // kernel lifecycle order strictly: userspace DESTROY, then STOP.
        sendStop(pair[1]) catch {};
        instance.deinit();
    };

    var scratch: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const create = try readEvent(pair[1], &scratch);
    try testing.expectEqual(uhid.UHID_CREATE2, std.mem.readInt(u32, create[0..4], .little));

    // DeviceInstance performs a best-effort zero-rumble quiesce during
    // attachment. Exclude that setup write so the log below observes only
    // the UHID pump -> mailbox -> EventLoop handoff under test.
    physical.write_log.clearRetainingCapacity();

    for (reports) |report| try sendOutput(pair[1], report);
    try pumpBarrier(pair[1], &scratch);
    try expectMailboxWake(instance.owner.uhid, expect_publication);

    // The pump has consumed every report (and, for valid reports, published
    // the command), but it has no physical DeviceIO and cannot write here.
    try testing.expectEqual(@as(usize, 0), physical.write_log.items.len);

    // A deterministic physical disconnect makes the production
    // DeviceInstance.run call finite. EventLoop still drains the already-ready
    // mailbox in this iteration, after its physical-input pass, and then exits
    // because the backing pad is gone.
    try physical.injectDisconnect();
    try instance.run();
    try testing.expect(instance.loop.disconnected);
    try testing.expectEqualSlices(u8, expected_physical_write, physical.write_log.items);

    var responder = DestroyResponder{ .fd = pair[1] };
    const responder_thread = try std.Thread.spawn(.{}, DestroyResponder.run, .{&responder});
    instance.deinit();
    live = false;
    responder_thread.join();
    try testing.expect(responder.saw_destroy.load(.acquire));
    try testing.expect(!responder.failed.load(.acquire));
}

test "T7 native Edge 48-byte asymmetric rumble reaches physical command via DeviceInstance" {
    const reports = [_][]const u8{
        @embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin"),
    };
    try runHandoff(&reports, true, &[_]u8{ 0xd0, 0xa5, 0xa5, 0x3c, 0x3c, 0xd1 });
}

test "T7 native Edge 63-byte asymmetric rumble reaches physical command via DeviceInstance" {
    const reports = [_][]const u8{
        @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin"),
    };
    try runHandoff(&reports, true, &[_]u8{ 0xd0, 0xa5, 0xa5, 0x3c, 0x3c, 0xd1 });
}

test "T7 native Edge SDL zero stop reaches physical zero command" {
    var stop = [_]u8{0} ** 48;
    stop[0] = 0x02;
    const reports = [_][]const u8{&stop};
    try runHandoff(&reports, true, &[_]u8{ 0xd0, 0, 0, 0, 0, 0xd1 });
}

test "T7 native Edge burst is latest-wins before one EventLoop drain" {
    const first = @embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin");
    var latest = @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin").*;
    latest[3] = 0x17;
    latest[4] = 0xe2;
    const reports = [_][]const u8{ first, &latest };
    try runHandoff(&reports, true, &[_]u8{ 0xd0, 0xe2, 0xe2, 0x17, 0x17, 0xd1 });
}

test "T7 native Edge invalid compatible flags never write physical rumble" {
    var invalid = @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin").*;
    invalid[39] = 0;
    const reports = [_][]const u8{&invalid};
    try runHandoff(&reports, false, &.{});
}
