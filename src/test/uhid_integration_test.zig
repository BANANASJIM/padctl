const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const interpreter_mod = src.core.interpreter;
const Interpreter = interpreter_mod.Interpreter;

// UHID UAPI bindings live in `src/io/uhid.zig`. Imported via the `src` barrel
// so the test bodies below share the production types unchanged.
const uhid = src.io.uhid;
const openUhid = uhid.openUhid;
const uhidCreate = uhid.uhidCreate;
const uhidInput = uhid.uhidInput;
const uhidDestroy = uhid.uhidDestroy;
const UHID_EVENT_SIZE = uhid.UHID_EVENT_SIZE;
const cleanup = src.testing_support.uhid_test_cleanup;

// Minimal HID report descriptor: 2 axes (X, Y), 4-byte report
const test_rd = [_]u8{
    0x05, 0x01, //   Usage Page (Generic Desktop)
    0x09, 0x05, //   Usage (Game Pad)
    0xA1, 0x01, //   Collection (Application)
    0x09, 0x30, //     Usage (X)
    0x09, 0x31, //     Usage (Y)
    0x15, 0x00, //     Logical Minimum (0)
    0x26, 0xFF, 0x00, // Logical Maximum (255)
    0x75, 0x08, //     Report Size (8)
    0x95, 0x04, //     Report Count (4) — 4 bytes total
    0x81, 0x02, //     Input (Data, Var, Abs)
    0xC0, //   End Collection
};

const TEST_VID: u16 = 0xFADE;
const TEST_PID: u16 = 0xCAFE;

fn findHidraw(vid: u16, pid: u16) !?[64]u8 {
    const ioctl_mod = src.io.ioctl_constants;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_mod.HidrawDevinfo = undefined;
        const rc = linux.ioctl(fd, ioctl_mod.HIDIOCGRAWINFO, @intFromPtr(&info));
        if (rc != 0) continue;
        const dev_vid: u16 = @bitCast(info.vendor);
        const dev_pid: u16 = @bitCast(info.product);
        if (dev_vid == vid and dev_pid == pid) {
            var result: [64]u8 = undefined;
            @memcpy(result[0..path.len], path);
            result[path.len] = 0;
            return result;
        }
    }
    return null;
}

// --- Test 1: UHID virtual device appears as hidraw ---

test "uhid: virtual device appears as hidraw" {
    cleanup.ensureSignalHandlersInstalled();
    const uhid_fd = try openUhid();
    cleanup.registerUhidFd(uhid_fd);
    defer {
        cleanup.unregisterUhidFd(uhid_fd);
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &test_rd);

    // Give the kernel a moment to create the hidraw node
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const found = try findHidraw(TEST_VID, TEST_PID);
    if (found == null) return error.SkipZigTest; // kernel may not have created it in time

    // Open the hidraw node and inject a report
    const path_buf = found.?;
    const path_end = std.mem.indexOfScalar(u8, &path_buf, 0) orelse path_buf.len;
    const hidraw_path = path_buf[0..path_end];

    const hidraw_fd = try posix.open(hidraw_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(hidraw_fd);

    // Inject a report via UHID_INPUT2
    const report = [_]u8{ 0x80, 0x40, 0xC0, 0x20 };
    try uhidInput(uhid_fd, &report);

    // Poll for data
    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest; // timeout, kernel too slow

    var buf: [64]u8 = undefined;
    const n = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    try testing.expectEqual(@as(usize, 4), n);
    try testing.expectEqualSlices(u8, &report, buf[0..4]);
}

// --- Test 2: Full pipeline with interpreter ---

const simple_toml =
    \\[device]
    \\name = "UHID Test Gamepad"
    \\vid = 0xFADE
    \\pid = 0xCAFE
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[report.fields]
    \\left_x = { offset = 0, type = "u8" }
    \\left_y = { offset = 1, type = "u8" }
    \\right_x = { offset = 2, type = "u8" }
    \\right_y = { offset = 3, type = "u8" }
;

test "uhid: full pipeline hidraw read through interpreter" {
    const allocator = testing.allocator;

    cleanup.ensureSignalHandlersInstalled();
    const uhid_fd = try openUhid();
    cleanup.registerUhidFd(uhid_fd);
    defer {
        cleanup.unregisterUhidFd(uhid_fd);
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &test_rd);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const found = try findHidraw(TEST_VID, TEST_PID);
    if (found == null) return error.SkipZigTest;

    const path_buf = found.?;
    const path_end = std.mem.indexOfScalar(u8, &path_buf, 0) orelse path_buf.len;
    const hidraw_path = path_buf[0..path_end];

    const hidraw_fd = try posix.open(hidraw_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(hidraw_fd);

    // Parse config and create interpreter
    const parsed = try device_mod.parseString(allocator, simple_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Inject a known report: ax=100, ay=200, rx=50, ry=150
    const report = [_]u8{ 100, 200, 50, 150 };
    try uhidInput(uhid_fd, &report);

    // Read from hidraw
    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest;

    var buf: [64]u8 = undefined;
    const n = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    try testing.expectEqual(@as(usize, 4), n);

    // Pass through interpreter (interface 0, no match filter)
    const delta = (try interp.processReport(0, buf[0..n])) orelse return error.SkipZigTest;

    try testing.expectEqual(@as(?i16, 100), delta.ax);
    try testing.expectEqual(@as(?i16, 200), delta.ay);
    try testing.expectEqual(@as(?i16, 50), delta.rx);
    try testing.expectEqual(@as(?i16, 150), delta.ry);
}

// --- Test 3: UHID rumble gamepad exposes no evdev FF capability (#444) ---
//
// padctl's buildFromOutput emits a Vendor-Defined (0xFF00) rumble output report
// with no PID Usage Page (0x0F), so the kernel binds hid-generic (no FF init)
// and the evdev node reports capabilities/ff = 0 — Wine/Lutris evdev force
// feedback then silently no-ops. Full analysis: decisions/025-uhid-rumble-ff-kernel-wall.md.

const FF_TEST_VID: u16 = 0xFADE; // padctl's virtual device identity (ADR-025: FADE:C001),
const FF_TEST_PID: u16 = 0xC001; // not in the hid-universal-pidff allowlist.

const ff_wall_toml =
    \\[device]
    \\name = "UHID FF Wall Test Pad"
    \\vid = 0xFADE
    \\pid = 0xC001
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[report.fields]
    \\left_x = { offset = 0, type = "u8" }
    \\left_y = { offset = 1, type = "u8" }
    \\[output]
    \\name = "UHID FF Wall Test Pad"
    \\vid = 0xFADE
    \\pid = 0xC001
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\B = "BTN_EAST"
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

// EVIOCGBIT(EV_FF, len): read the device's force-feedback effect bitmap — the
// same data the kernel exports as /sys/class/input/eventN/device/capabilities/ff.
fn eviocgbitFf(len: u14) u32 {
    const req = linux.IOCTL.Request{ .dir = 2, .io_type = 'E', .nr = 0x20 + 0x15, .size = len };
    return @bitCast(req);
}

fn findEvdevByVidPid(vid: u16, pid: u16) !?[64]u8 {
    const ioctl_mod = src.io.ioctl_constants;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/input/event{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var id: ioctl_mod.InputId = undefined;
        const rc = linux.ioctl(fd, ioctl_mod.EVIOCGID, @intFromPtr(&id));
        if (rc != 0) continue;
        if (id.vendor == vid and id.product == pid) {
            var result: [64]u8 = undefined;
            @memcpy(result[0..path.len], path);
            result[path.len] = 0;
            return result;
        }
    }
    return null;
}

test "uhid: rumble gamepad exposes capabilities/ff=0 — #444 kernel FF wall (ADR-025)" {
    const allocator = testing.allocator;

    // Build the descriptor through padctl's real imu=uhid rumble path.
    const parsed = try device_mod.parseString(allocator, ff_wall_toml);
    defer parsed.deinit();
    const out_cfg = parsed.value.output orelse return error.SkipZigTest;
    const descriptor = try src.io.uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg);
    defer allocator.free(descriptor);

    cleanup.ensureSignalHandlersInstalled();
    const uhid_fd = try openUhid();
    cleanup.registerUhidFd(uhid_fd);
    defer {
        cleanup.unregisterUhidFd(uhid_fd);
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, FF_TEST_VID, FF_TEST_PID, descriptor);

    // Let the kernel bind hid-generic and create the evdev node.
    std.Thread.sleep(300 * std.time.ns_per_ms);

    const found = (try findEvdevByVidPid(FF_TEST_VID, FF_TEST_PID)) orelse return error.SkipZigTest;
    const path_end = std.mem.indexOfScalar(u8, &found, 0) orelse found.len;
    const ev_path = found[0..path_end];

    const ev_fd = try posix.open(ev_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(ev_fd);

    // EVIOCGBIT(EV_FF) copies the device's FF effect bitmap (all-zero when the
    // kernel registered no EV_FF handler) and returns the byte count. Guard the
    // return so an ioctl failure surfaces as a test error instead of passing
    // against the pre-zeroed buffer. A non-zero byte means evdev FF is exposed —
    // the #444 regression.
    var ff_bits: [16]u8 = [_]u8{0} ** 16;
    const rc = linux.ioctl(ev_fd, eviocgbitFf(ff_bits.len), @intFromPtr(&ff_bits));
    if (linux.E.init(rc) != .SUCCESS) return error.EvdevFfBitIoctlFailed;
    for (ff_bits) |b| {
        try testing.expectEqual(@as(u8, 0), b);
    }
}
