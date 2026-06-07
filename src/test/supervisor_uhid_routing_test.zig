//! Layer 1 routing tests for UHID device creation and uniq pairing.
//!
//! Drives `DeviceInstance.openUhidDevice` (the routing helper that wraps
//! `UhidDevice.init` and the test-fd seam) against a pair of `posix.pipe2`
//! write-ends. The pipe captures the bytes the helper would have written to
//! `/dev/uhid`: one `UHID_CREATE2` event on construction, one `UHID_DESTROY`
//! on close. Asserting directly on the wire bytes verifies byte-identical
//! uniq pairing without ever touching a real kernel fd — the whole test runs
//! with zero privileges on CI.
//!
//! `UhidSimulator` is NOT used here: it is an input-side harness that
//! produces a virtual HID node for padctl to consume, not a write-capture
//! interceptor for `UHID_CREATE2` events.
//!
//! The final test in this file drives `DeviceInstance.init` end-to-end via
//! the `InitOptions.test_devices_override` + `test_*_uhid_fd` seams so the
//! routing switch inside `init` is exercised directly — the prior tests
//! would stay green even if that switch degenerated to always-uinput.
//! Additional coverage at the `/dev/uhid` kernel level lives in the Layer 2
//! integration tests (`supervisor_uhid_grace_integration_test.zig`,
//! privilege-gated on `PADCTL_TEST_REQUIRE_UHID`).

const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const device_instance = src.device_instance;
const DeviceInstance = device_instance.DeviceInstance;
const DeviceIO = src.io.device_io.DeviceIO;
const MockDeviceIO = src.testing_support.mock_device_io.MockDeviceIO;
const uhid = src.io.uhid;
const uhid_descriptor = src.io.uhid_descriptor;
const uniq_mod = src.io.uniq;

const TEST_DESCRIPTOR = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x05, // Usage (Game Pad)
    0xA1, 0x01, // Collection (Application)
    0x05, 0x09, // Usage Page (Button)
    0x19, 0x01,
    0x29, 0x02,
    0x15, 0x00,
    0x25, 0x01,
    0x75, 0x01,
    0x95, 0x02,
    0x81, 0x02,
    0x75, 0x06,
    0x95, 0x01,
    0x81, 0x03,
    0xC0,
};

const TEST_TOML_ILLEGAL =
    \\[device]
    \\name = "Illegal Combo"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\buttons = { a = "BTN_SOUTH" }
    \\[output.imu]
    \\backend = "uinput"
;

fn readCreate2(fd: posix.fd_t, scratch: []u8) !uhid.UhidCreate2Event {
    const n = try posix.read(fd, scratch);
    try testing.expect(n >= @sizeOf(uhid.UhidCreate2Event));
    var ev: uhid.UhidCreate2Event = undefined;
    @memcpy(std.mem.asBytes(&ev), scratch[0..@sizeOf(uhid.UhidCreate2Event)]);
    try testing.expectEqual(uhid.UHID_CREATE2, ev.type);
    return ev;
}

fn uniqSlice(ev: *const uhid.UhidCreate2Event) []const u8 {
    return std.mem.sliceTo(&ev.payload.uniq, 0);
}

fn readDestroy(fd: posix.fd_t, scratch: []u8) !void {
    const n = try posix.read(fd, scratch);
    try testing.expect(n >= @sizeOf(u32));
    const ev_type = std.mem.readInt(u32, scratch[0..4], .little);
    try testing.expectEqual(uhid.UHID_DESTROY, ev_type);
}

fn containsBytes(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

test "routing: primary + IMU cards share byte-identical uniq" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);
    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const uniq_z = try uniq_mod.buildUniq(allocator, "Routing Test Pad", "sim-phys-0001", 0);
    defer allocator.free(uniq_z);
    const uniq_s = std.mem.sliceTo(uniq_z, 0);

    const primary_cfg = uhid.Config{
        .name = "Routing Test Pad",
        .uniq = uniq_s,
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = &TEST_DESCRIPTOR,
    };
    const primary = try device_instance.openUhidDeviceForTest(allocator, primary_cfg, primary_fds[1]);
    defer {
        primary.close();
        allocator.destroy(primary);
    }

    const imu_cfg_data = device_mod.ImuConfig{};
    const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg_data);
    defer allocator.free(imu_desc);
    const imu_cfg = uhid.Config{
        .name = "Routing Test IMU",
        .uniq = uniq_s,
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = imu_desc,
        .imu = imu_cfg_data,
    };
    const imu = try device_instance.openUhidDeviceForTest(allocator, imu_cfg, imu_fds[1]);
    defer {
        imu.close();
        allocator.destroy(imu);
    }

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    const imu_ev = try readCreate2(imu_fds[0], scratch);

    try testing.expectEqualStrings(uniqSlice(&primary_ev), uniqSlice(&imu_ev));
    try testing.expect(std.mem.startsWith(u8, uniqSlice(&primary_ev), "padctl/"));
    try testing.expect(std.mem.startsWith(u8, uniqSlice(&primary_ev), "padctl/routing-test-pad-"));
}

test "routing: primary descriptor contains EV_KEY, IMU descriptor does not" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);
    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const uniq_z = try uniq_mod.buildUniq(allocator, "Routing Test Pad", "sim-phys-0002", 0);
    defer allocator.free(uniq_z);
    const uniq_s = std.mem.sliceTo(uniq_z, 0);

    const primary_cfg = uhid.Config{
        .name = "Routing Test Pad",
        .uniq = uniq_s,
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = &TEST_DESCRIPTOR,
    };
    const primary = try device_instance.openUhidDeviceForTest(allocator, primary_cfg, primary_fds[1]);
    defer {
        primary.close();
        allocator.destroy(primary);
    }

    const imu_cfg_data = device_mod.ImuConfig{};
    const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg_data);
    defer allocator.free(imu_desc);
    const imu_cfg = uhid.Config{
        .name = "Routing Test IMU",
        .uniq = uniq_s,
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = imu_desc,
        .imu = imu_cfg_data,
    };
    const imu = try device_instance.openUhidDeviceForTest(allocator, imu_cfg, imu_fds[1]);
    defer {
        imu.close();
        allocator.destroy(imu);
    }

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    const imu_ev = try readCreate2(imu_fds[0], scratch);

    const primary_rd = primary_ev.payload.rd_data[0..primary_ev.payload.rd_size];
    const imu_rd = imu_ev.payload.rd_data[0..imu_ev.payload.rd_size];

    try testing.expect(containsBytes(primary_rd, &.{ 0x05, 0x09 }));
    try testing.expect(!containsBytes(imu_rd, &.{ 0x05, 0x09 }));
}

test "routing: close emits UHID_DESTROY per card" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const uniq_z = try uniq_mod.buildUniq(allocator, "Destroy Pad", "sim-phys-0003", 0);
    defer allocator.free(uniq_z);

    const cfg = uhid.Config{
        .name = "Destroy Pad",
        .uniq = std.mem.sliceTo(uniq_z, 0),
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = &TEST_DESCRIPTOR,
    };
    const dev = try device_instance.openUhidDeviceForTest(allocator, cfg, primary_fds[1]);
    defer allocator.destroy(dev);

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    _ = try readCreate2(primary_fds[0], scratch);

    dev.close();
    try readDestroy(primary_fds[0], scratch);
}

test "routing: parseString rejects backend=uinput + [output.imu]" {
    const allocator = testing.allocator;
    const result = device_mod.parseString(allocator, TEST_TOML_ILLEGAL);
    try testing.expectError(error.InvalidConfig, result);
}

const TEST_TOML_UHID_LEGAL =
    \\[device]
    \\name = "Routing E2E Pad"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\name = "Routing E2E Pad"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\buttons = { a = "BTN_SOUTH" }
    \\[output.imu]
    \\backend = "uhid"
    \\name = "Routing E2E IMU"
;

// Exercises the `use_uhid` switch inside `DeviceInstance.init` directly —
// the earlier tests go through `openUhidDeviceForTest`, which bypasses the
// switch and would stay green even if the routing decision regressed to
// always-uinput. Reverse-verification: temporarily forcing `use_uhid = false`
// in `device_instance.zig` flips `owner` to `.uinput`, which fails the
// `.uhid` assertions below.
test "DeviceInstance.init: backend=uhid TOML routes via InitOptions test seam" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);
    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_UHID_LEGAL);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var counter: u16 = 1;
    var inst = try DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        null,
        &counter,
        .{
            .test_primary_uhid_fd = primary_fds[1],
            .test_imu_uhid_fd = imu_fds[1],
            .test_devices_override = devices,
        },
    );
    defer inst.deinit();

    switch (inst.owner) {
        .uhid => {},
        else => {
            std.debug.print("owner was {s}, expected .uhid\n", .{@tagName(inst.owner)});
            try testing.expect(false);
        },
    }
    try testing.expect(inst.primary_output != null);
    try testing.expect(inst.imu_dev != null);
    try testing.expect(inst.imu_output != null);

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    const imu_ev = try readCreate2(imu_fds[0], scratch);
    try testing.expectEqualStrings(uniqSlice(&primary_ev), uniqSlice(&imu_ev));
    try testing.expect(std.mem.startsWith(u8, uniqSlice(&primary_ev), "padctl/"));
    // clone_vid_pid absent → primary card must use daemon identity, not device VID/PID.
    try testing.expectEqual(@as(u32, 0xFADE), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0xC001), primary_ev.payload.product);
}

// clone_vid_pid routing tests.

const TEST_TOML_NO_CLONE =
    \\[device]
    \\name = "Clone Test Pad"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\name = "Clone Test Pad"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\[output.imu]
    \\backend = "uhid"
    \\name = "Clone Test IMU"
;

// clone_vid_pid absent → primary UHID card uses daemon identity 0xFADE:0xC001
test "clone_vid_pid=false (default) → primary UHID vid=0xFADE pid=0xC001" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);
    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_NO_CLONE);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var counter: u16 = 1;
    var inst = try DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        null,
        &counter,
        .{
            .test_primary_uhid_fd = primary_fds[1],
            .test_imu_uhid_fd = imu_fds[1],
            .test_devices_override = devices,
        },
    );
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    try testing.expectEqual(@as(u32, 0xFADE), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0xC001), primary_ev.payload.product);
}

const TEST_TOML_CLONE =
    \\[device]
    \\name = "Clone Test Wheel"
    \\vid = 0x11FF
    \\pid = 0x1211
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\name = "Clone Test Wheel"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\[output.imu]
    \\backend = "uhid"
    \\name = "Clone Test IMU"
    \\[output.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
    \\clone_vid_pid = true
;

// clone_vid_pid=true → primary UHID card uses wheel's real VID/PID
test "clone_vid_pid=true → primary UHID vid=device.vid pid=device.pid" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);
    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_CLONE);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var counter: u16 = 1;
    var inst = try DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        null,
        &counter,
        .{
            .test_primary_uhid_fd = primary_fds[1],
            .test_imu_uhid_fd = imu_fds[1],
            .test_devices_override = devices,
        },
    );
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    try testing.expectEqual(@as(u32, 0x11FF), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0x1211), primary_ev.payload.product);
}

// --- [output] backend=uhid + present_output_id routing (Vader 5 paddles) ----

// Vader-representative: main pad on UHID, masquerade identity presented, no IMU
// card, rumble FFB (sidecar skipped in the test seam). M1-M4 -> the four
// BTN_TRIGGER_HAPPY paddle codes that buildFromOutput emits as Button usages.
const TEST_TOML_OUTPUT_UHID =
    \\[device]
    \\name = "Paddle Pad"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\name = "Xbox Elite Series 2"
    \\vid = 0x045e
    \\pid = 0x0b00
    \\backend = "uhid"
    \\present_output_id = true
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\buttons = { A = "BTN_SOUTH", M1 = "BTN_TRIGGER_HAPPY1", M2 = "BTN_TRIGGER_HAPPY3", M3 = "BTN_TRIGGER_HAPPY2", M4 = "BTN_TRIGGER_HAPPY4" }
    \\[output.force_feedback]
    \\type = "rumble"
;

fn initOutputUhid(
    allocator: std.mem.Allocator,
    parsed: anytype,
    mock: *MockDeviceIO,
    primary_fd: posix.fd_t,
) !DeviceInstance {
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();
    var counter: u16 = 1;
    return DeviceInstance.init(allocator, &parsed.value, null, null, &counter, .{
        .test_primary_uhid_fd = primary_fd,
        .test_devices_override = devices,
        .test_skip_ff_sidecar = true,
    });
}

test "output backend=uhid routes main pad to UHID (Vader paddles)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_OUTPUT_UHID);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var inst = try initOutputUhid(allocator, parsed, &mock, primary_fds[1]);
    defer inst.deinit();

    // Reverse-verification: dropping backend="uhid" from the TOML flips owner
    // to .uinput, failing this assertion.
    switch (inst.owner) {
        .uhid => {},
        else => {
            std.debug.print("owner was {s}, expected .uhid\n", .{@tagName(inst.owner)});
            try testing.expect(false);
        },
    }
    // No [output.imu] -> no IMU companion card.
    try testing.expect(inst.imu_dev == null);

    // Regression: the primary UHID fd MUST be registered with the event loop
    // for ALL UHID main pads, not only PID-FFB devices. This Vader config has
    // plain rumble FFB (not PID); before the fix the fd was registered only
    // inside the PID block, so /dev/uhid was never drained and the kernel HID
    // probe stalled (zero input events). uhid_output_slot != null proves the
    // unconditional registration.
    try testing.expect(inst.loop.uhid_output_slot != null);
}

test "present_output_id=true presents [output] vid/pid not daemon FADE:C001" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_OUTPUT_UHID);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var inst = try initOutputUhid(allocator, parsed, &mock, primary_fds[1]);
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    // Masquerade identity, NOT the 0xFADE:0xC001 default and NOT device id.
    try testing.expectEqual(@as(u32, 0x045e), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0x0b00), primary_ev.payload.product);
    try testing.expect(primary_ev.payload.vendor != 0xFADE);
    try testing.expect(primary_ev.payload.product != 0xC001);
}

test "UHID primary descriptor declares the four paddle Button usages" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const parsed = try device_mod.parseString(allocator, TEST_TOML_OUTPUT_UHID);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var inst = try initOutputUhid(allocator, parsed, &mock, primary_fds[1]);
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, uhid.UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    const rd = primary_ev.payload.rd_data[0..primary_ev.payload.rd_size];

    // buildFromOutput maps BTN_TRIGGER_HAPPY1-4 to HID Button usages 17-20.
    // Each appears as a Usage short item `0x09 <usage>`. Reverse-verification:
    // removing the M1-M4 button mappings from the TOML drops these usages and
    // fails the assertions.
    const paddle_usages = [_][2]u8{
        .{ 0x09, 17 }, // BTN_TRIGGER_HAPPY1 (M1)
        .{ 0x09, 18 }, // BTN_TRIGGER_HAPPY2 (M3)
        .{ 0x09, 19 }, // BTN_TRIGGER_HAPPY3 (M2)
        .{ 0x09, 20 }, // BTN_TRIGGER_HAPPY4 (M4)
    };
    for (paddle_usages) |pu| {
        try testing.expect(containsBytes(rd, &pu));
    }
}
