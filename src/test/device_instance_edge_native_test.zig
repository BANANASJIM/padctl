//! Layer 1 routing coverage for the native DualSense Edge personality.
//! A Unix SEQPACKET pair stands in for `/dev/uhid`, preserving kernel event
//! boundaries while allowing exact CREATE2/control/input assertions.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const posix = std.posix;
const testing = std.testing;

const device_config = @import("../config/device.zig");
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const edge_codec = @import("../io/dualsense_edge_usb.zig");
const edge_identity = @import("../io/edge_identity.zig");
const uhid = @import("../io/uhid.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;

const NATIVE_TOML =
    \\[device]
    \\name = "Protocol-name-independent physical pad"
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

fn sendGet(fd: posix.fd_t, request_id: u32, report_number: u8) !void {
    var event = [_]u8{0} ** 10;
    std.mem.writeInt(u32, event[0..4], uhid.UHID_GET_REPORT, .little);
    std.mem.writeInt(u32, event[4..8], request_id, .little);
    event[8] = report_number;
    event[9] = @intFromEnum(uhid.ReportType.feature);
    try testing.expectEqual(event.len, try posix.write(fd, &event));
}

fn sendStop(fd: posix.fd_t) !void {
    var event: [4]u8 = undefined;
    std.mem.writeInt(u32, &event, uhid.UHID_STOP, .little);
    try testing.expectEqual(event.len, try posix.write(fd, &event));
}

fn sendSet(fd: posix.fd_t, request_id: u32, report_number: u8) !void {
    var event = [_]u8{0} ** 12;
    std.mem.writeInt(u32, event[0..4], uhid.UHID_SET_REPORT, .little);
    std.mem.writeInt(u32, event[4..8], request_id, .little);
    event[8] = report_number;
    event[9] = @intFromEnum(uhid.ReportType.feature);
    std.mem.writeInt(u16, event[10..12], 0, .little);
    try testing.expectEqual(event.len, try posix.write(fd, &event));
}

fn expectFeatureReply(
    fd: posix.fd_t,
    scratch: *[uhid.UHID_EVENT_SIZE]u8,
    request_id: u32,
    report_number: u8,
    identity: edge_identity.EdgeIdentity,
) !void {
    try sendGet(fd, request_id, report_number);
    const reply = try readEvent(fd, scratch);
    try testing.expectEqual(uhid.UHID_GET_REPORT_REPLY, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(request_id, std.mem.readInt(u32, reply[4..8], .little));
    try testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, reply[8..10], .little));
    const size: usize = std.mem.readInt(u16, reply[10..12], .little);
    var expected_buf: [uhid.UHID_DATA_MAX]u8 = undefined;
    const expected = try edge_codec.featureReport(report_number, identity, &expected_buf);
    try testing.expectEqual(expected.len, size);
    try testing.expectEqualSlices(u8, expected, reply[12 .. 12 + size]);
}

const DestroyResponder = struct {
    fd: posix.fd_t,
    saw_destroy: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *DestroyResponder) void {
        var scratch: [uhid.UHID_EVENT_SIZE]u8 = undefined;
        const bytes = readEvent(self.fd, &scratch) catch {
            self.failed.store(true, .release);
            return;
        };
        if (std.mem.readInt(u32, bytes[0..4], .little) != uhid.UHID_DESTROY) {
            self.failed.store(true, .release);
            return;
        }
        self.saw_destroy.store(true, .release);
        sendStop(self.fd) catch self.failed.store(true, .release);
    }
};

const CreateDestroyResponder = struct {
    fd: posix.fd_t,
    saw_create: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    saw_destroy: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    sent_stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *CreateDestroyResponder) void {
        var scratch: [uhid.UHID_EVENT_SIZE]u8 = undefined;
        const create = readEvent(self.fd, &scratch) catch {
            self.failed.store(true, .release);
            return;
        };
        if (std.mem.readInt(u32, create[0..4], .little) != uhid.UHID_CREATE2) {
            self.failed.store(true, .release);
            return;
        }
        self.saw_create.store(true, .release);

        const destroy = readEvent(self.fd, &scratch) catch {
            self.failed.store(true, .release);
            return;
        };
        if (std.mem.readInt(u32, destroy[0..4], .little) != uhid.UHID_DESTROY) {
            self.failed.store(true, .release);
            return;
        }
        self.saw_destroy.store(true, .release);
        sendStop(self.fd) catch {
            self.failed.store(true, .release);
            return;
        };
        self.sent_stop.store(true, .release);
    }
};

test "DeviceInstance native Edge routes by final discriminators with stable identity and one UHID" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = physical.deviceIO();

    const pair = try socketPair();
    defer posix.close(pair[1]);
    var counter: u16 = 0x2468;
    var primary_fd_consumed = false;
    var instance = try DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        "phys-abc",
        &counter,
        .{
            .test_primary_uhid_fd = pair[0],
            .test_primary_uhid_fd_consumed = &primary_fd_consumed,
            .test_devices_override = devices,
        },
    );
    var live = true;
    defer if (live) {
        sendStop(pair[1]) catch {};
        instance.deinit();
    };

    try testing.expectEqual(@as(u16, 0x2468), counter);
    try testing.expect(primary_fd_consumed);
    try testing.expect(instance.owner == .uhid);
    try testing.expect(instance.owner.uhid.hasNativePump());
    try testing.expect(instance.owner.uhid.control_handler.get_report != null);
    try testing.expect(instance.owner.uhid.native_output_handler.decode != null);
    try testing.expect(instance.edge_runtime != null);
    try testing.expect(instance.primary_output != null);
    try testing.expect(instance.imu_dev == null);
    try testing.expect(instance.imu_output == null);

    var scratch: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const create_bytes = try readEvent(pair[1], &scratch);
    try testing.expectEqual(@as(usize, uhid.UHID_EVENT_SIZE), create_bytes.len);
    var create: uhid.UhidCreate2Event = undefined;
    @memcpy(std.mem.asBytes(&create), create_bytes[0..@sizeOf(uhid.UhidCreate2Event)]);
    try testing.expectEqual(uhid.UHID_CREATE2, create.type);
    try testing.expectEqual(@as(u32, 0x054c), create.payload.vendor);
    try testing.expectEqual(@as(u32, 0x0df2), create.payload.product);
    try testing.expectEqual(@as(u16, 389), create.payload.rd_size);
    try testing.expectEqualSlices(u8, edge_codec.descriptor(), create.payload.rd_data[0..create.payload.rd_size]);
    try testing.expectEqualStrings("padctl/edge-5694565d7152", std.mem.sliceTo(&create.payload.uniq, 0));

    const stable = try edge_identity.deriveStableIdentity("phys-abc");
    try expectFeatureReply(pair[1], &scratch, 0x05050505, 0x05, stable.edge);
    try expectFeatureReply(pair[1], &scratch, 0x09090909, 0x09, stable.edge);
    try expectFeatureReply(pair[1], &scratch, 0x20202020, 0x20, stable.edge);

    try sendSet(pair[1], 0x5e7e5e7e, 0x20);
    const set_reply = try readEvent(pair[1], &scratch);
    try testing.expectEqual(uhid.UHID_SET_REPORT_REPLY, std.mem.readInt(u32, set_reply[0..4], .little));
    try testing.expectEqual(@as(u32, 0x5e7e5e7e), std.mem.readInt(u32, set_reply[4..8], .little));
    try testing.expect(std.mem.readInt(u16, set_reply[8..10], .little) != 0);
    try testing.expectEqual(
        @import("../io/dualsense_edge_runtime.zig").EdgeRuntime.ControlSnapshot{
            .get_report = 3,
            .set_report = 1,
        },
        instance.edge_runtime.?.controlSnapshot(),
    );

    const gamepad = edge_codec.GamepadState{
        .ax = -32768,
        .ay = 32767,
        .gyro_x = 0x1234,
        .gyro_y = -0x1234,
        .accel_z = 0x4567,
    };
    try instance.primary_output.?.emit(gamepad);
    const input_bytes = try readEvent(pair[1], &scratch);
    try testing.expectEqual(uhid.UHID_INPUT2, std.mem.readInt(u32, input_bytes[0..4], .little));
    try testing.expectEqual(@as(u16, edge_codec.INPUT_REPORT_SIZE), std.mem.readInt(u16, input_bytes[4..6], .little));
    var expected_encoder = edge_codec.InputEncoder.init(.{
        .left_button = .C,
        .right_button = .Z,
        .left_x = 480,
        .right_x = 1440,
        .y = 540,
        .click = true,
    });
    const expected_input = expected_encoder.encode(gamepad);
    try testing.expectEqualSlices(u8, &expected_input, input_bytes[6 .. 6 + edge_codec.INPUT_REPORT_SIZE]);

    // Model the kernel teardown ordering: userspace writes DESTROY first;
    // only then does the peer deliver STOP to the still-owning pump.
    var responder = DestroyResponder{ .fd = pair[1] };
    const responder_thread = try std.Thread.spawn(.{}, DestroyResponder.run, .{&responder});
    instance.deinit();
    live = false;
    responder_thread.join();
    try testing.expect(responder.saw_destroy.load(.acquire));
    try testing.expect(!responder.failed.load(.acquire));
}

test "DeviceInstance native Edge rejects missing or absolute phys fallback without consuming counter" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();

    for ([_]?[]const u8{ null, "/sys/devices/unstable-fallback" }) |phys_key| {
        var physical = try MockDeviceIO.init(allocator, &.{});
        defer physical.deinit();
        const devices = try allocator.alloc(DeviceIO, 1);
        defer allocator.free(devices);
        devices[0] = physical.deviceIO();

        const pair = try socketPair();
        defer posix.close(pair[0]);
        defer posix.close(pair[1]);
        var counter: u16 = 0xbeef;
        var primary_fd_consumed = false;
        try testing.expectError(error.UnstablePhysicalIdentity, DeviceInstance.init(
            allocator,
            &parsed.value,
            null,
            phys_key,
            &counter,
            .{
                .test_primary_uhid_fd = pair[0],
                .test_primary_uhid_fd_consumed = &primary_fd_consumed,
                .test_devices_override = devices,
            },
        ));
        try testing.expectEqual(@as(u16, 0xbeef), counter);
        try testing.expect(!primary_fd_consumed);
    }
}

test "DeviceInstance native Edge frees runtime when CREATE2 fails after pump start" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = physical.deviceIO();

    // The read end is a valid fd, so initWithFd starts the pump. CREATE2 then
    // fails because the same fd is not writable, exercising both UhidDevice
    // and EdgeRuntime errdefers under std.testing.allocator leak detection.
    const pipe = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
    defer posix.close(pipe[1]);
    var counter: u16 = 77;
    var primary_fd_consumed = false;
    try testing.expectError(error.UhidCreateFailed, DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        "phys-create-failure",
        &counter,
        .{
            .test_primary_uhid_fd = pipe[0],
            .test_primary_uhid_fd_consumed = &primary_fd_consumed,
            .test_devices_override = devices,
        },
    ));
    try testing.expectEqual(@as(u16, 77), counter);
    try testing.expect(primary_fd_consumed);
}

test "DeviceInstance native Edge rejects generic source mode at parse and route boundaries" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const with_generic_mode = try std.mem.replaceOwned(
        u8,
        allocator,
        NATIVE_TOML,
        "name = \"Protocol-name-independent physical pad\"",
        "name = \"Protocol-name-independent physical pad\"\nmode = \"generic\"",
    );
    defer allocator.free(with_generic_mode);
    const generic_native_toml = try std.mem.concat(allocator, u8, &.{
        with_generic_mode,
        "\n[output.mapping]\nleft_x = { event = \"ABS_X\", range = [0, 255] }\n",
    });
    defer allocator.free(generic_native_toml);
    try testing.expectError(error.InvalidConfig, device_config.parseString(allocator, generic_native_toml));

    // Defense in depth: a caller could mutate or construct DeviceConfig after
    // validation. The runtime boundary must still reject before GenericUinput.
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();
    parsed.value.device.mode = "generic";

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = physical.deviceIO();
    const pair = try socketPair();
    defer posix.close(pair[0]);
    defer posix.close(pair[1]);
    var counter: u16 = 91;
    try testing.expectError(error.InvalidConfig, DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        "phys-generic-conflict",
        &counter,
        .{
            .test_primary_uhid_fd = pair[0],
            .test_devices_override = devices,
        },
    ));
    try testing.expectEqual(@as(u16, 91), counter);
}

test "DeviceInstance native Edge rolls back post-route failure through DESTROY then STOP" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = physical.deviceIO();

    const pair = try socketPair();
    defer posix.close(pair[1]);
    var responder = CreateDestroyResponder{ .fd = pair[1] };
    const responder_thread = try std.Thread.spawn(.{}, CreateDestroyResponder.run, .{&responder});

    var counter: u16 = 123;
    var primary_fd_consumed = false;
    const result = DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        "phys-post-route-failure",
        &counter,
        .{
            .test_primary_uhid_fd = pair[0],
            .test_primary_uhid_fd_consumed = &primary_fd_consumed,
            .test_devices_override = devices,
            .test_fail_after_output_route = true,
        },
    );
    responder_thread.join();
    try testing.expectError(error.TestPostOutputRouteFailure, result);
    try testing.expectEqual(@as(u16, 123), counter);
    try testing.expect(primary_fd_consumed);
    try testing.expect(responder.saw_create.load(.acquire));
    try testing.expect(responder.saw_destroy.load(.acquire));
    try testing.expect(responder.sent_stop.load(.acquire));
    try testing.expect(!responder.failed.load(.acquire));
}
