//! Phase 13 Wave 6 T6 — Layer 1 e2e integration tests.
//!
//! Covers the full FFB passthrough chain:
//!   UHID_OUTPUT injection → FfbForwarder → physical hidraw write.
//!
//! All tests use pipe2 fixtures — no /dev/uhid, no /dev/hidraw, zero privilege.
//!
//! Note on pipe direction:
//!   - For UHID_CREATE2 capture (T2 VID/PID clone): UhidDevice gets write-end;
//!     test reads from read-end. Matches supervisor_uhid_routing_test.zig.
//!   - For UHID_OUTPUT injection (round-trip): UhidDevice.initWithFd gets
//!     read-end; test writes synthetic events to write-end. Matches
//!     uhid_output_dispatch_test.zig.
//!   Both directions are needed; they use separate pipe pairs.
//!   DeviceInstance.init tests (VID/PID, EAGAIN, disabled) use the CREATE2
//!   capture direction since they test the init + forwarder callback path.

const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const device_instance = @import("../device_instance.zig");
const DeviceInstance = device_instance.DeviceInstance;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const uhid = @import("../io/uhid.zig");
const UhidDevice = uhid.UhidDevice;
const UHID_EVENT_SIZE = uhid.UHID_EVENT_SIZE;
const UHID_OUTPUT = uhid.UHID_OUTPUT;
const UHID_CREATE2 = uhid.UHID_CREATE2;
const UhidCreate2Event = uhid.UhidCreate2Event;
const ffb_mod = @import("../io/ffb_forwarder.zig");
const FfbForwarder = ffb_mod.FfbForwarder;
const uhid_descriptor = @import("../io/uhid_descriptor.zig");

const DUMMY_DESCRIPTOR = [_]u8{ 0x05, 0x01, 0xC0 };

const TOML_MOZA_CLONE =
    \\[device]
    \\name = "Moza R5 Wheel"
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
    \\name = "Moza R5"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\[output.imu]
    \\backend = "uhid"
    \\name = "Moza R5 IMU"
    \\[output.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
    \\clone_vid_pid = true
;

const TOML_NO_CLONE =
    \\[device]
    \\name = "Moza R5 No Clone"
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
    \\name = "Moza R5 No Clone"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\[output.imu]
    \\backend = "uhid"
    \\name = "Moza R5 No Clone IMU"
    \\[output.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
    \\clone_vid_pid = false
;

const TOML_PID_FIXTURE =
    \\[device]
    \\name = "PID Test"
    \\vid = 0x11FF
    \\pid = 0x1211
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 2
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[output]
    \\name = "PID Out"
    \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
    \\[output.imu]
    \\backend = "uhid"
    \\[output.force_feedback]
    \\backend = "uhid"
    \\kind = "pid"
;

// Write a synthetic UHID_OUTPUT event into a pipe write-end.
// payload[0] is the report ID; payload[1..] is the body.
fn writeUhidOutputEvent(fd: posix.fd_t, payload: []const u8) !void {
    var ev: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, ev[0..4], UHID_OUTPUT, .little);
    // uhid_output_req: data[4096] at offset 4, size u16 at offset 4100
    const sz = @min(payload.len, uhid.UHID_DATA_MAX);
    @memcpy(ev[4..][0..sz], payload[0..sz]);
    std.mem.writeInt(u16, ev[4 + 4096 ..][0..2], @intCast(sz), .little);
    _ = try posix.write(fd, &ev);
}

// Read and decode a UHID_CREATE2 event from a pipe read-end.
fn readCreate2(fd: posix.fd_t, scratch: []u8) !UhidCreate2Event {
    const n = try posix.read(fd, scratch);
    try testing.expect(n >= @sizeOf(UhidCreate2Event));
    var ev: UhidCreate2Event = undefined;
    @memcpy(std.mem.asBytes(&ev), scratch[0..@sizeOf(UhidCreate2Event)]);
    try testing.expectEqual(UHID_CREATE2, ev.type);
    return ev;
}

// Drain all pending UHID_OUTPUT events from uhid_dev, forwarding each via fwd.
fn drainAndForward(
    uhid_dev: *UhidDevice,
    fwd: *FfbForwarder,
    buf: []u8,
) !u32 {
    var count: u32 = 0;
    while (true) {
        const report = try uhid_dev.pollOutputReport(buf);
        const r = report orelse break;
        fwd.forward(r);
        count += 1;
    }
    return count;
}

// TP30: Full chain round-trip — UHID_OUTPUT → FfbForwarder → physical hidraw.
// Uses UhidDevice.initWithFd directly with the pipe read-end (same as T3
// dispatch tests) so the test can both inject events and assert hidraw writes.
// FfbForwarder and UhidDevice are wired manually without running the event loop.
test "wave6_pidff: end-to-end UHID_OUTPUT → hidraw forward (Set Effect / Effect Op / Device Control)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    // uhid_fds: read-end → UhidDevice; write-end → test injects UHID_OUTPUT.
    const uhid_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(uhid_fds[0]);
    defer posix.close(uhid_fds[1]);

    // hidraw_fds: write-end → FfbForwarder; read-end → test asserts bytes.
    const hidraw_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(hidraw_fds[0]);
    defer posix.close(hidraw_fds[1]);

    const cfg = uhid.Config{
        .vid = 0x11FF,
        .pid = 0x1211,
        .name = "Moza R5 Test",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(allocator, uhid_fds[0], cfg);
    defer {
        dev.fd = -1; // pipe read-end managed by uhid_fds defer above
        allocator.destroy(dev);
    }

    var fwd = FfbForwarder.init(hidraw_fds[1]);
    dev.setOutputCallback(ffb_mod.forwarderCallback, &fwd);
    defer dev.clearOutputCallback();

    var uhid_buf: [UHID_EVENT_SIZE]u8 = undefined;
    var read_buf: [256]u8 = undefined;

    // --- Set Effect Report (report_id=1) ---
    const set_effect = [_]u8{ 0x01, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x3F, 0x00, 0x00, 0x00, 0x00 };
    try writeUhidOutputEvent(uhid_fds[1], &set_effect);
    _ = try drainAndForward(dev, &fwd, &uhid_buf);

    const n1 = try posix.read(hidraw_fds[0], &read_buf);
    try testing.expectEqual(set_effect.len, n1);
    try testing.expectEqualSlices(u8, &set_effect, read_buf[0..n1]);

    // --- Effect Operation Report (report_id=10) ---
    const effect_op = [_]u8{ 0x0A, 0x01, 0x01 };
    try writeUhidOutputEvent(uhid_fds[1], &effect_op);
    _ = try drainAndForward(dev, &fwd, &uhid_buf);

    const n2 = try posix.read(hidraw_fds[0], &read_buf);
    try testing.expectEqual(effect_op.len, n2);
    try testing.expectEqualSlices(u8, &effect_op, read_buf[0..n2]);

    // --- Device Control Report (report_id=11) ---
    const device_ctrl = [_]u8{0x0B};
    try writeUhidOutputEvent(uhid_fds[1], &device_ctrl);
    _ = try drainAndForward(dev, &fwd, &uhid_buf);

    const n3 = try posix.read(hidraw_fds[0], &read_buf);
    try testing.expectEqual(device_ctrl.len, n3);
    try testing.expectEqualSlices(u8, &device_ctrl, read_buf[0..n3]);

    try testing.expectEqual(@as(u64, 3), fwd.writes_total);
    try testing.expectEqual(@as(u64, 0), fwd.drops_eagain);
}

// TP31: buildForPid emits all 8 PID Usages required by kernel
// pidff_find_reports (drivers/hid/usbhid/hid-pidff.c). Kernel matches by
// HID Usage on PID Usage Page 0x0F, NOT by Report ID.
test "wave6_pidff: PID descriptor exposes all 8 kernel-required Usages" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, TOML_PID_FIXTURE);
    defer parsed.deinit();

    const out = parsed.value.output.?;
    const ffb_cfg = out.force_feedback.?;
    const desc = try uhid_descriptor.UhidDescriptorBuilder.buildForPid(allocator, out, ffb_cfg);
    defer allocator.free(desc);

    try uhid_descriptor.validateMandatoryReports(desc);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);

    // Negative: a hand-crafted partial descriptor missing the Set Effect
    // (0x21) Usage must fail validation. This is the failure mode kernel
    // pidff_find_reports rejects with -ENODEV.
    var partial_buf: [256]u8 = undefined;
    var partial_len: usize = 0;
    partial_buf[partial_len] = 0x05;
    partial_buf[partial_len + 1] = 0x0F;
    partial_len += 2;
    const usages_present = [_]u8{ 0x77, 0x7d, 0x7f, 0x89, 0x90, 0x96, 0xab };
    for (usages_present) |u| {
        partial_buf[partial_len] = 0x09;
        partial_buf[partial_len + 1] = u;
        partial_len += 2;
        partial_buf[partial_len] = 0xA1;
        partial_buf[partial_len + 1] = 0x02;
        partial_len += 2;
        partial_buf[partial_len] = 0xC0;
        partial_len += 1;
    }
    try testing.expectError(
        error.MissingMandatoryPidUsage,
        uhid_descriptor.validateMandatoryReports(partial_buf[0..partial_len]),
    );
}

// TP34 (from test-plan): clone_vid_pid=true passes real VID/PID to UHID_CREATE2.
test "wave6_pidff: VID/PID clone passes through to UHID_CREATE2" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    // primary_fds[1] → DeviceInstance (write-end for UHID_CREATE2); fds[0] read by test.
    // Owned by DeviceInstance; do NOT defer-close fds[1].
    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const hidraw_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(hidraw_fds[0]);
    defer posix.close(hidraw_fds[1]);

    const parsed = try device_mod.parseString(allocator, TOML_MOZA_CLONE);
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
            .test_physical_hidraw_fd = hidraw_fds[1],
        },
    );
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    // clone_vid_pid=true → wheel's real VID/PID instead of daemon identity.
    try testing.expectEqual(@as(u32, 0x11FF), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0x1211), primary_ev.payload.product);
}

// TP32: EAGAIN on physical hidraw increments drops_eagain without panicking.
test "wave6_pidff: physical hidraw EAGAIN → drops_eagain incremented" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const uhid_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(uhid_fds[0]);
    defer posix.close(uhid_fds[1]);

    const hidraw_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(hidraw_fds[0]);
    defer posix.close(hidraw_fds[1]);

    const cfg = uhid.Config{
        .vid = 0x11FF,
        .pid = 0x1211,
        .name = "Moza R5 EAGAIN",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(allocator, uhid_fds[0], cfg);
    defer {
        dev.fd = -1;
        allocator.destroy(dev);
    }

    var fwd = FfbForwarder.init(hidraw_fds[1]);
    dev.setOutputCallback(ffb_mod.forwarderCallback, &fwd);
    defer dev.clearOutputCallback();

    // Fill the hidraw pipe buffer to capacity (Linux default 64 KiB).
    const chunk = [_]u8{0xFF} ** 4096;
    var filled: usize = 0;
    while (filled < 128 * 1024) {
        const n = posix.write(hidraw_fds[1], &chunk) catch break;
        filled += n;
    }

    try writeUhidOutputEvent(uhid_fds[1], &[_]u8{ 0x01, 0xAA });
    var uhid_buf: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try drainAndForward(dev, &fwd, &uhid_buf);

    try testing.expect(fwd.drops_eagain >= 1);
    // EAGAIN does NOT disable the forwarder.
    try testing.expectEqual(.active, fwd.state);
}

// TP33: Closing the physical hidraw write-end transitions forwarder to disabled.
test "wave6_pidff: physical hidraw close → forwarder disabled" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const uhid_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(uhid_fds[0]);
    defer posix.close(uhid_fds[1]);

    const hidraw_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(hidraw_fds[0]);
    // hidraw_fds[1] is closed mid-test; do NOT defer a second close.

    const cfg = uhid.Config{
        .vid = 0x11FF,
        .pid = 0x1211,
        .name = "Moza R5 Disabled",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(allocator, uhid_fds[0], cfg);
    defer {
        dev.fd = -1;
        allocator.destroy(dev);
    }

    var fwd = FfbForwarder.init(hidraw_fds[1]);
    dev.setOutputCallback(ffb_mod.forwarderCallback, &fwd);
    defer dev.clearOutputCallback();

    var uhid_buf: [UHID_EVENT_SIZE]u8 = undefined;
    var read_buf: [64]u8 = undefined;

    // Successful round-trip first.
    try writeUhidOutputEvent(uhid_fds[1], &[_]u8{ 0x01, 0x42 });
    _ = try drainAndForward(dev, &fwd, &uhid_buf);
    _ = posix.read(hidraw_fds[0], &read_buf) catch |err| switch (err) {
        error.WouldBlock => {},
        else => return err,
    };
    try testing.expectEqual(@as(u64, 1), fwd.writes_total);

    // Close physical hidraw write-end; next forward must set state=.disabled.
    posix.close(hidraw_fds[1]);

    try writeUhidOutputEvent(uhid_fds[1], &[_]u8{ 0x01, 0x43 });
    _ = try drainAndForward(dev, &fwd, &uhid_buf);

    try testing.expectEqual(.disabled, fwd.state);
}

// TP35: No [output.force_feedback] block → ffb_forwarder must remain null after init.
// Gating condition for the FFB path: ensures non-PID devices never get a forwarder wired,
// preventing arbitrary UHID_OUTPUT bytes from leaking into the wrong hidraw fd.
test "wave6_pidff: no force_feedback block → no FfbForwarder wired (TP35)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const TOML_NO_FFB =
        \\[device]
        \\name = "Generic Gamepad"
        \\vid = 0x054C
        \\pid = 0x0CE6
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
        \\name = "Generic Gamepad Out"
        \\axes = { left_x = { code = "ABS_X", min = -128, max = 127 } }
        \\[output.imu]
        \\backend = "uhid"
        \\name = "Generic Gamepad IMU"
    ;

    const parsed = try device_mod.parseString(allocator, TOML_NO_FFB);
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

    try testing.expectEqual(null, inst.ffb_forwarder);
}

// TP34 (second part): clone_vid_pid=false uses daemon identity 0xFADE:0xC001.
test "wave6_pidff: clone_vid_pid=false uses daemon identity (0xFADE:0xC001)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const allocator = testing.allocator;

    const primary_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(primary_fds[0]);

    const imu_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(imu_fds[0]);

    const hidraw_fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(hidraw_fds[0]);
    defer posix.close(hidraw_fds[1]);

    const parsed = try device_mod.parseString(allocator, TOML_NO_CLONE);
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
            .test_physical_hidraw_fd = hidraw_fds[1],
        },
    );
    defer inst.deinit();

    const scratch = try allocator.alloc(u8, UHID_EVENT_SIZE);
    defer allocator.free(scratch);

    const primary_ev = try readCreate2(primary_fds[0], scratch);
    // clone_vid_pid=false → daemon identity, not wheel VID/PID.
    try testing.expectEqual(@as(u32, 0xFADE), primary_ev.payload.vendor);
    try testing.expectEqual(@as(u32, 0xC001), primary_ev.payload.product);
}
