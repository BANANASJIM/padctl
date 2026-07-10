//! Privileged real-kernel contract for the native DualSense Edge USB route.
//!
//! This file is intentionally absent from the ordinary test namespace. Use
//! `zig build check-edge-uhid` to compile it without touching `/dev/uhid`, and
//! `zig build test-edge-uhid` for the explicit privileged run.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const posix = std.posix;
const testing = std.testing;

extern "c" fn pthread_kill(thread: std.c.pthread_t, signal: c_int) c_int;

const src = @import("src");
const device_config = src.config.device;
const DeviceInstance = src.device_instance.DeviceInstance;
const DeviceIO = src.io.device_io.DeviceIO;
const edge_codec = src.io.dualsense_edge_usb;
const edge_identity = src.io.edge_identity;
const ioctl = src.io.ioctl_constants;
const uhid = src.io.uhid;
const MockDeviceIO = src.testing_support.mock_device_io.MockDeviceIO;
const cleanup = src.testing_support.uhid_test_cleanup;

const TEST_PHYS = "padctl-t8-edge-real-kernel";
const DISCOVERY_TIMEOUT_MS: i64 = 3000;
const IO_TIMEOUT_MS: i32 = 1500;

const NATIVE_TOML =
    \\[device]
    \\name = "T8 native Edge physical source"
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

fn forced() bool {
    const value = posix.getenv("PADCTL_TEST_REQUIRE_UHID") orelse return false;
    return std.mem.eql(u8, value, "1");
}

fn monotonicNs() i128 {
    const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

fn openRequiredUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{
        .ACCMODE = .RDWR,
        .NONBLOCK = true,
        .CLOEXEC = true,
    }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => if (forced())
            error.RequiredUhidUnavailable
        else
            error.SkipZigTest,
        else => err,
    };
}

fn readSmallAbsolute(path: []const u8, out: []u8) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    const n = try file.readAll(out);
    return out[0..n];
}

fn ueventMatches(uevent: []const u8, expected_uniq: []const u8) bool {
    var has_id = false;
    var has_uniq = false;
    var lines = std.mem.splitScalar(u8, uevent, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "HID_ID=0003:0000054C:00000DF2")) has_id = true;
        if (std.mem.startsWith(u8, line, "HID_UNIQ=")) {
            has_uniq = std.mem.eql(u8, line["HID_UNIQ=".len..], expected_uniq);
        }
    }
    return has_id and has_uniq;
}

const HidrawMatch = struct {
    name: [64]u8,
    name_len: usize,
    path: [64]u8,
    path_len: usize,

    fn nameSlice(self: *const HidrawMatch) []const u8 {
        return self.name[0..self.name_len];
    }

    fn pathSlice(self: *const HidrawMatch) []const u8 {
        return self.path[0..self.path_len];
    }
};

const ScanResult = struct {
    count: usize = 0,
    first: ?HidrawMatch = null,
};

fn scanMatchingHidraw(expected_uniq: []const u8) !ScanResult {
    var dir = std.fs.openDirAbsolute("/sys/class/hidraw", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.AccessDenied => return error.HidrawSysfsUnavailable,
        else => return err,
    };
    defer dir.close();

    var result = ScanResult{};
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "hidraw")) continue;

        var uevent_path_buf: [256]u8 = undefined;
        const uevent_path = std.fmt.bufPrint(
            &uevent_path_buf,
            "/sys/class/hidraw/{s}/device/uevent",
            .{entry.name},
        ) catch continue;
        var uevent_buf: [2048]u8 = undefined;
        const uevent = readSmallAbsolute(uevent_path, &uevent_buf) catch continue;
        if (!ueventMatches(uevent, expected_uniq)) continue;

        result.count += 1;
        if (result.first == null) {
            var found = HidrawMatch{
                .name = undefined,
                .name_len = entry.name.len,
                .path = undefined,
                .path_len = 0,
            };
            if (entry.name.len > found.name.len) return error.HidrawNameTooLong;
            @memcpy(found.name[0..entry.name.len], entry.name);
            const path = std.fmt.bufPrint(&found.path, "/dev/{s}", .{entry.name}) catch
                return error.HidrawPathTooLong;
            found.path_len = path.len;
            result.first = found;
        }
    }
    return result;
}

fn waitForSingleHidraw(expected_uniq: []const u8) !HidrawMatch {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        const scan = try scanMatchingHidraw(expected_uniq);
        if (scan.count > 1) return error.MultipleNativeEdgeHidrawNodes;
        if (scan.first) |found| return found;
        if (monotonicNs() >= deadline) {
            return if (forced()) error.NativeEdgeHidrawDiscoveryTimeout else error.SkipZigTest;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn waitForHidrawGone(expected_uniq: []const u8) !void {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        const scan = try scanMatchingHidraw(expected_uniq);
        if (scan.count == 0) return;
        if (monotonicNs() >= deadline) return error.NativeEdgeHidrawDestroyTimeout;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn inputProductMatches(uevent: []const u8) bool {
    var lines = std.mem.splitScalar(u8, uevent, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "PRODUCT=")) continue;
        var fields = std.mem.splitScalar(u8, line["PRODUCT=".len..], '/');
        const bus = std.fmt.parseInt(u16, fields.next() orelse return false, 16) catch return false;
        const vid = std.fmt.parseInt(u16, fields.next() orelse return false, 16) catch return false;
        const pid = std.fmt.parseInt(u16, fields.next() orelse return false, 16) catch return false;
        return bus == uhid.BUS_USB and vid == 0x054c and pid == 0x0df2;
    }
    return false;
}

/// Count only sysfs nodes whose PRODUCT and uniq both match this test-owned
/// UHID device. Never open unrelated `/dev/input/event*` host devices.
fn scanMatchingEvdev(expected_uniq: []const u8) !usize {
    var dir = std.fs.openDirAbsolute("/sys/class/input", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.AccessDenied => return error.InputSysfsUnavailable,
        else => return err,
    };
    defer dir.close();

    var count: usize = 0;
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;

        var path_buf: [256]u8 = undefined;
        const uevent_path = std.fmt.bufPrint(
            &path_buf,
            "/sys/class/input/{s}/device/uevent",
            .{entry.name},
        ) catch continue;
        var uevent_buf: [2048]u8 = undefined;
        const uevent = readSmallAbsolute(uevent_path, &uevent_buf) catch continue;
        if (!inputProductMatches(uevent)) continue;

        const uniq_path = std.fmt.bufPrint(
            &path_buf,
            "/sys/class/input/{s}/device/uniq",
            .{entry.name},
        ) catch continue;
        var uniq_buf: [128]u8 = undefined;
        const uniq_raw = readSmallAbsolute(uniq_path, &uniq_buf) catch continue;
        const uniq = std.mem.trimRight(u8, uniq_raw, "\r\n");
        if (std.mem.eql(u8, uniq, expected_uniq)) count += 1;
    }
    return count;
}

fn waitForEvdevPresent(expected_uniq: []const u8) !void {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        if (try scanMatchingEvdev(expected_uniq) >= 1) return;
        if (monotonicNs() >= deadline) {
            return if (forced()) error.NativeEdgeEvdevDiscoveryTimeout else error.SkipZigTest;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn waitForEvdevGone(expected_uniq: []const u8) !void {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        if (try scanMatchingEvdev(expected_uniq) == 0) return;
        if (monotonicNs() >= deadline) return error.NativeEdgeEvdevDestroyTimeout;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn expectDriverAndDescriptor(found: *const HidrawMatch) !void {
    var path_buf: [256]u8 = undefined;
    const driver_path = try std.fmt.bufPrint(
        &path_buf,
        "/sys/class/hidraw/{s}/device/driver",
        .{found.nameSlice()},
    );
    var driver_real_buf: [std.fs.max_path_bytes]u8 = undefined;
    const driver_real = try std.fs.realpath(driver_path, &driver_real_buf);
    try testing.expectEqualStrings("playstation", std.fs.path.basename(driver_real));

    const module_path = try std.fmt.bufPrint(
        &path_buf,
        "/sys/class/hidraw/{s}/device/driver/module",
        .{found.nameSlice()},
    );
    var module_real_buf: [std.fs.max_path_bytes]u8 = undefined;
    if (std.fs.realpath(module_path, &module_real_buf)) |module_real| {
        try testing.expectEqualStrings("hid_playstation", std.fs.path.basename(module_real));
    } else |err| switch (err) {
        // Built-in hid-playstation has no owning module symlink. The driver
        // basename above remains the authoritative binding contract.
        error.FileNotFound => {},
        else => return err,
    }

    const descriptor_path = try std.fmt.bufPrint(
        &path_buf,
        "/sys/class/hidraw/{s}/device/report_descriptor",
        .{found.nameSlice()},
    );
    var descriptor_buf: [uhid.HID_MAX_DESCRIPTOR_SIZE]u8 = undefined;
    const descriptor = try readSmallAbsolute(descriptor_path, &descriptor_buf);
    try testing.expectEqualSlices(u8, edge_codec.descriptor(), descriptor);
}

fn expectRawIdentity(fd: posix.fd_t, expected_uniq: []const u8) !void {
    var info: ioctl.HidrawDevinfo = undefined;
    const info_rc = linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info));
    if (linux.E.init(info_rc) != .SUCCESS) return error.HidrawInfoFailed;
    try testing.expectEqual(@as(u32, uhid.BUS_USB), info.bustype);
    try testing.expectEqual(@as(u16, 0x054c), @as(u16, @bitCast(info.vendor)));
    try testing.expectEqual(@as(u16, 0x0df2), @as(u16, @bitCast(info.product)));

    var uniq_buf: [128]u8 = [_]u8{0} ** 128;
    const uniq_rc = linux.ioctl(fd, ioctl.HIDIOCGRAWUNIQ(uniq_buf.len), @intFromPtr(&uniq_buf));
    if (linux.E.init(uniq_rc) != .SUCCESS) return error.HidrawUniqFailed;
    try testing.expectEqualStrings(expected_uniq, std.mem.sliceTo(&uniq_buf, 0));
}

fn interruptHandler(_: i32) callconv(.c) void {}

const IoctlWorker = struct {
    fd: posix.fd_t,
    request: u32,
    data: *anyopaque,
    done_fd: posix.fd_t,
    result: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn run(self: *IoctlWorker) void {
        const rc = linux.ioctl(self.fd, self.request, @intFromPtr(self.data));
        self.result.store(rc, .release);
        var one: u64 = 1;
        _ = posix.write(self.done_fd, std.mem.asBytes(&one)) catch {};
    }
};

fn terminateThroughRegisteredCleanup() noreturn {
    _ = linux.kill(linux.getpid(), posix.SIG.TERM);
    unreachable;
}

fn cancelAndJoin(thread: std.Thread, pfd: *[1]posix.pollfd) void {
    // Interrupt the exact pthread running the ioctl, then require its
    // completion event before joining. A second timeout cannot safely return
    // while the worker still borrows stack state, so escalate through the
    // registered UHID SIGTERM cleanup instead of waiting unboundedly.
    if (pthread_kill(thread.getHandle(), posix.SIG.USR1) != 0) {
        terminateThroughRegisteredCleanup();
    }
    pfd[0].revents = 0;
    const completed = posix.poll(pfd, 500) catch terminateThroughRegisteredCleanup();
    if (completed != 1 or pfd[0].revents & posix.POLL.IN == 0) {
        terminateThroughRegisteredCleanup();
    }
    thread.join();
}

fn ioctlWithDeadline(fd: posix.fd_t, request: u32, data: *anyopaque) !usize {
    const done_fd = try posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
    defer posix.close(done_fd);
    var worker = IoctlWorker{ .fd = fd, .request = request, .data = data, .done_fd = done_fd };
    const thread = try std.Thread.spawn(.{}, IoctlWorker.run, .{&worker});

    var pfd = [_]posix.pollfd{.{ .fd = done_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = posix.poll(&pfd, IO_TIMEOUT_MS) catch |err| {
        cancelAndJoin(thread, &pfd);
        return err;
    };
    if (ready == 0) {
        cancelAndJoin(thread, &pfd);
        return error.HidrawIoctlTimeout;
    }
    if (ready != 1 or pfd[0].revents & posix.POLL.IN == 0) {
        cancelAndJoin(thread, &pfd);
        return error.HidrawIoctlWakeFailed;
    }
    thread.join();
    return worker.result.load(.acquire);
}

fn auditedFeature(
    report_id: u8,
    identity: edge_identity.EdgeIdentity,
    out: *[64]u8,
) ![]const u8 {
    const fixture: []const u8 = switch (report_id) {
        0x05 => @embedFile("fixtures/dualsense_edge_usb/feature_05.bin"),
        0x09 => @embedFile("fixtures/dualsense_edge_usb/feature_09.bin"),
        0x20 => @embedFile("fixtures/dualsense_edge_usb/feature_20.bin"),
        else => return error.UnsupportedAuditedFeature,
    };
    @memcpy(out[0..fixture.len], fixture);
    if (report_id == 0x09) @memcpy(out[1..7], &identity.pairing_mac);
    return out[0..fixture.len];
}

fn expectFeatureGet(
    fd: posix.fd_t,
    runtime: anytype,
    report_id: u8,
    identity: edge_identity.EdgeIdentity,
) !void {
    var expected_buf: [64]u8 = undefined;
    const expected = try auditedFeature(report_id, identity, &expected_buf);
    var actual: [64]u8 = [_]u8{0} ** 64;
    actual[0] = report_id;
    const before = runtime.controlSnapshot();
    const rc = try ioctlWithDeadline(fd, ioctl.HIDIOCGFEATURE(@intCast(expected.len)), &actual);
    if (linux.E.init(rc) != .SUCCESS) return error.HidrawGetFeatureFailed;
    try testing.expectEqual(expected.len, rc);
    try testing.expectEqualSlices(u8, expected, actual[0..expected.len]);
    const after = runtime.controlSnapshot();
    try testing.expect(after.get_report >= before.get_report + 1);
}

fn expectFeatureSetRejected(
    fd: posix.fd_t,
    runtime: anytype,
    identity: edge_identity.EdgeIdentity,
) !void {
    var feature_buf: [64]u8 = undefined;
    const feature = try auditedFeature(0x20, identity, &feature_buf);
    const before = runtime.controlSnapshot();
    const rc = try ioctlWithDeadline(fd, ioctl.HIDIOCSFEATURE(@intCast(feature.len)), feature_buf[0..feature.len].ptr);
    try testing.expectEqual(linux.E.IO, linux.E.init(rc));
    const after = runtime.controlSnapshot();
    try testing.expect(after.set_report >= before.set_report + 1);
}

fn readExactInput(fd: posix.fd_t, expected: *const [64]u8) !void {
    var pfd = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, IO_TIMEOUT_MS);
    if (ready == 0) return error.NativeEdgeInputTimeout;
    try testing.expectEqual(@as(usize, 1), ready);
    try testing.expect(pfd[0].revents & posix.POLL.IN != 0);
    var actual: [128]u8 = undefined;
    const n = try posix.read(fd, &actual);
    try testing.expectEqual(@as(usize, 64), n);
    try testing.expectEqualSlices(u8, expected, actual[0..n]);
}

test "native DualSense Edge production route satisfies real UHID and hid-playstation contract" {
    if (builtin.os.tag != .linux) {
        return if (forced()) error.RequiredLinuxHost else error.SkipZigTest;
    }

    cleanup.ensureSignalHandlersInstalled();
    var previous_usr1: posix.Sigaction = undefined;
    posix.sigaction(posix.SIG.USR1, &.{
        .handler = .{ .handler = interruptHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    }, &previous_usr1);
    defer posix.sigaction(posix.SIG.USR1, &previous_usr1, null);

    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();
    const stable = try edge_identity.deriveStableIdentity(TEST_PHYS);

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = physical.deviceIO();
    var devices_transferred = false;

    const uhid_fd = try openRequiredUhid();
    cleanup.registerUhidFd(uhid_fd);
    var registered = true;
    var test_owns_uhid_fd = true;
    var primary_fd_consumed = false;
    var instance: ?DeviceInstance = null;
    var hidraw_fd: ?posix.fd_t = null;
    defer {
        if (hidraw_fd) |fd| posix.close(fd);
        if (instance) |*live| live.deinit();
        if (!devices_transferred) allocator.free(devices);
        if (registered) cleanup.unregisterUhidFd(uhid_fd);
        if (test_owns_uhid_fd) {
            uhid.uhidDestroy(uhid_fd);
            posix.close(uhid_fd);
        }
    }

    var counter: u16 = 0x88a8;
    const created = DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        TEST_PHYS,
        &counter,
        .{
            .test_primary_uhid_fd = uhid_fd,
            .test_primary_uhid_fd_consumed = &primary_fd_consumed,
            .test_devices_override = devices,
        },
    ) catch |err| {
        // openUhidDevice closes a consumed override on every error. If route
        // selection failed earlier, the test retains and closes it in defer.
        if (primary_fd_consumed) test_owns_uhid_fd = false;
        return err;
    };
    test_owns_uhid_fd = false;
    instance = created;
    devices_transferred = true;
    try testing.expect(primary_fd_consumed);
    try testing.expectEqual(@as(u16, 0x88a8), counter);
    try testing.expect(instance.?.owner == .uhid);
    try testing.expect(instance.?.imu_dev == null);
    try testing.expect(instance.?.edge_runtime != null);

    const found = try waitForSingleHidraw(&stable.uniq);
    try waitForEvdevPresent(&stable.uniq);
    try expectDriverAndDescriptor(&found);
    hidraw_fd = posix.open(found.pathSlice(), .{
        .ACCMODE = .RDWR,
        .NONBLOCK = true,
        .CLOEXEC = true,
    }, 0) catch |err| switch (err) {
        error.AccessDenied => return error.NativeEdgeHidrawAccessDenied,
        else => return err,
    };
    try expectRawIdentity(hidraw_fd.?, &stable.uniq);

    const runtime = instance.?.edge_runtime.?;
    const initial_control = runtime.controlSnapshot();

    // Intentionally interleave kernel GET/SET control traffic with a native
    // input report. Runtime counters prove every ioctl crossed the production
    // UHID pump handlers, while hidraw observes the exact 64-byte wire image.
    try expectFeatureGet(hidraw_fd.?, runtime, 0x05, stable.edge);

    const gamepad = edge_codec.GamepadState{
        .ax = -32768,
        .ay = 32767,
        .rx = 0x1234,
        .ry = -0x2345,
        .lt = 0x3c,
        .rt = 0xa5,
        .dpad_x = 1,
        .dpad_y = -1,
        .gyro_x = 0x1234,
        .gyro_y = -0x1234,
        .accel_z = 0x4567,
        .buttons = (@as(u64, 1) << @intFromEnum(edge_codec.ButtonId.A)) |
            (@as(u64, 1) << @intFromEnum(edge_codec.ButtonId.C)) |
            (@as(u64, 1) << @intFromEnum(edge_codec.ButtonId.M4)),
        .battery_level = 7,
    };
    // Independent 64-byte wire oracle for the state above. These assignments
    // intentionally do not call the production axis/touch/input encoder.
    var expected_input = [_]u8{0} ** 64;
    expected_input[0] = 0x01;
    expected_input[1] = 0x00;
    expected_input[2] = 0x00;
    expected_input[3] = 0x92;
    expected_input[4] = 0xa3;
    expected_input[5] = 0x3c;
    expected_input[6] = 0xa5;
    expected_input[8] = 0x21;
    expected_input[10] = 0x82;
    expected_input[16] = 0x34;
    expected_input[17] = 0x12;
    expected_input[18] = 0xcc;
    expected_input[19] = 0xed;
    expected_input[26] = 0x67;
    expected_input[27] = 0x45;
    expected_input[33] = 0x00;
    expected_input[34] = 0xe0;
    expected_input[35] = 0xc1;
    expected_input[36] = 0x21;
    expected_input[37] = 0x80;
    expected_input[53] = 0x07;
    try instance.?.primary_output.?.emit(gamepad);
    try readExactInput(hidraw_fd.?, &expected_input);

    try expectFeatureGet(hidraw_fd.?, runtime, 0x09, stable.edge);
    try expectFeatureSetRejected(hidraw_fd.?, runtime, stable.edge);
    try expectFeatureGet(hidraw_fd.?, runtime, 0x20, stable.edge);

    const final_control = runtime.controlSnapshot();
    try testing.expect(final_control.get_report >= initial_control.get_report + 3);
    try testing.expect(final_control.set_report >= initial_control.set_report + 1);

    posix.close(hidraw_fd.?);
    hidraw_fd = null;
    instance.?.deinit();
    instance = null;
    cleanup.unregisterUhidFd(uhid_fd);
    registered = false;
    try waitForHidrawGone(&stable.uniq);
    try waitForEvdevGone(&stable.uniq);
}
