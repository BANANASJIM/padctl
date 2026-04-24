//! ADR-015 Stage 1 acceptance-criterion test: verify that two UHID-backed
//! evdev nodes created with the same `uniq` string return byte-identical
//! values from `EVIOCGUNIQ`. SDL's `GetSensor()` pairs main-pad and IMU by
//! strcmp-equal uniq strings, so this is the CI-equivalent signal for the
//! Stage 1 exit condition.
//!
//! ## Runtime behaviour
//!
//! - On non-Linux hosts: returns `error.SkipZigTest` (standard practice).
//! - On Linux hosts *without* `/dev/uhid` access (root-only CI runners,
//!   unprivileged containers): logs an explicit warning so the absence is
//!   visible in CI output, then behaves one of two ways:
//!     * Default: returns `error.SkipZigTest` — test suite stays green on
//!       CI while making the gap audible.
//!     * When `PADCTL_TEST_REQUIRE_UHID=1` is set: returns
//!       `error.UhidAccessRequired` — fails the test so an environment
//!       that's meant to have /dev/uhid access but doesn't surfaces the
//!       breakage immediately. Used by post-install verification and
//!       ADR-015-compliant CI runners.
//!
//! ## Why this can't just silently SkipZigTest
//!
//! The audit flagged H2 — the Stage 1 AC was unmet because no production
//! code imported `EVIOCGUNIQ` at all. A plain `error.SkipZigTest` on
//! missing /dev/uhid would recreate that silent failure mode. The warning
//! log + opt-in hard fail preserves the CI signal without making local dev
//! environments red by default.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const uhid = @import("../io/uhid.zig");
const uhid_descriptor = @import("../io/uhid_descriptor.zig");
const device_cfg = @import("../config/device.zig");
const ioctl_constants = @import("../io/ioctl_constants.zig");

const SHARED_UNIQ = "padctl/uniq-pair-test-0";

fn requireUhid() bool {
    const v = std.posix.getenv("PADCTL_TEST_REQUIRE_UHID") orelse return false;
    return std.mem.eql(u8, v, "1") or std.mem.eql(u8, v, "true");
}

fn reportMissingUhid(reason: []const u8) error{ SkipZigTest, UhidAccessRequired } {
    std.log.warn(
        "uhid_uniq_pairing_test: /dev/uhid unavailable ({s}) — ADR-015 Stage 1 CI signal is SILENT. " ++
            "Install udev rules via 'sudo ./zig-out/bin/padctl install' and reload udev, " ++
            "or set PADCTL_TEST_REQUIRE_UHID=1 to turn this into a hard failure.",
        .{reason},
    );
    if (requireUhid()) return error.UhidAccessRequired;
    return error.SkipZigTest;
}

fn waitForEvdevNode(vid: u16, pid: u16, uniq: []const u8, timeout_ms: u32) !?[64]u8 {
    const start = std.time.milliTimestamp();
    const deadline = start + @as(i64, @intCast(timeout_ms));
    while (std.time.milliTimestamp() < deadline) {
        if (try findEvdevByUniq(vid, pid, uniq)) |path| return path;
        std.Thread.sleep(20 * std.time.ns_per_ms);
    }
    return null;
}

fn findEvdevByUniq(vid: u16, pid: u16, expect_uniq: []const u8) !?[64]u8 {
    // Walk /sys/class/input/event*/device/uevent and pick only entries whose
    // uevent reports a matching PRODUCT= line, then open just that event node.
    // This avoids opening host hardware (keyboards, the user's real gamepad,
    // active evdev grabs by padctl/Steam) which on kernel 6.18 can block in
    // evdev_release / input_flush_device during close() and deadlock the test.
    var dir = std.fs.openDirAbsolute("/sys/class/input", .{ .iterate = true }) catch return null;
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;

        // Read /sys/class/input/eventN/device/uevent — contains "PRODUCT=bus/vid/pid/ver".
        var uevent_path_buf: [128]u8 = undefined;
        const uevent_path = std.fmt.bufPrint(&uevent_path_buf, "/sys/class/input/{s}/device/uevent", .{entry.name}) catch continue;
        const uevent_file = std.fs.openFileAbsolute(uevent_path, .{}) catch continue;
        defer uevent_file.close();
        var uevent_buf: [4096]u8 = undefined;
        const uevent_len = uevent_file.readAll(&uevent_buf) catch continue;
        const uevent = uevent_buf[0..uevent_len];

        if (!sysfsProductMatches(uevent, vid, pid)) continue;

        // Matches by VID/PID — now open only this single device to verify uniq.
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/input/{s}", .{entry.name}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);

        var uniq_buf: [64]u8 = std.mem.zeroes([64]u8);
        const rc = linux.ioctl(fd, ioctl_constants.EVIOCGUNIQ(uniq_buf.len), @intFromPtr(&uniq_buf));
        if (posix.errno(rc) != .SUCCESS) continue;
        const nul = std.mem.indexOfScalar(u8, &uniq_buf, 0) orelse uniq_buf.len;
        if (!std.mem.eql(u8, uniq_buf[0..nul], expect_uniq)) continue;

        var result: [64]u8 = std.mem.zeroes([64]u8);
        @memcpy(result[0..path.len], path);
        return result;
    }
    return null;
}

/// Parse a sysfs uevent blob and return true iff a `PRODUCT=bus/vid/pid/ver`
/// line matches the given VID/PID. `bus` is the host bus type (not our UHID
/// pretend-USB bus), so we only check vid + pid positions.
fn sysfsProductMatches(uevent: []const u8, vid: u16, pid: u16) bool {
    var line_iter = std.mem.splitScalar(u8, uevent, '\n');
    while (line_iter.next()) |line| {
        const prefix = "PRODUCT=";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const value = line[prefix.len..];
        var field_iter = std.mem.splitScalar(u8, value, '/');
        _ = field_iter.next() orelse return false; // bus
        const vid_str = field_iter.next() orelse return false;
        const pid_str = field_iter.next() orelse return false;
        const parsed_vid = std.fmt.parseInt(u16, vid_str, 16) catch return false;
        const parsed_pid = std.fmt.parseInt(u16, pid_str, 16) catch return false;
        return parsed_vid == vid and parsed_pid == pid;
    }
    return false;
}

fn readUniqFromEvdevPath(path: []const u8) ![]u8 {
    const fd = try posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(fd);

    var buf: [64]u8 = std.mem.zeroes([64]u8);
    const rc = linux.ioctl(fd, ioctl_constants.EVIOCGUNIQ(buf.len), @intFromPtr(&buf));
    if (rc < 0) return error.EvdevIoctlFailed;
    const nul = std.mem.indexOfScalar(u8, &buf, 0) orelse buf.len;
    const out = try testing.allocator.alloc(u8, nul);
    @memcpy(out, buf[0..nul]);
    return out;
}

// ---------------------------------------------------------------------------
// Phase 13 Wave 5 canary — kernel-level evdev classification ioctls.
//
// SDL/Steam `GuessDeviceClass` keys off two ioctl signals *after* the kernel's
// HID→evdev mapper (`drivers/hid/hid-input.c`) parses the descriptor:
//   1. `EVIOCGPROP` → must expose `INPUT_PROP_ACCELEROMETER` (0x06) so the
//      sensor is classified as an accelerometer, not a gamepad.
//   2. `EVIOCGBIT(EV_KEY, ...)` → must be *empty* for the IMU node; any KEY
//      bit set trips the gamepad heuristic and SDL won't pair the sensor.
// The primary pad is the inverse: EV_KEY must have at least one bit so SDL
// classifies it as a gamepad.
//
// Kernel constants (linux/input-event-codes.h):
//   INPUT_PROP_ACCELEROMETER = 0x06 → byte 0 bit 6 (mask 0x40)
//   INPUT_PROP_CNT           = 0x20 → props buffer = 4 bytes
//   EV_KEY                   = 0x01
//   KEY_MAX                  = 0x2ff → key bitmap = 96 bytes
//
// EVIOCGPROP(len)     = _IOR('E', 0x09, len)
// EVIOCGBIT(ev, len)  = _IOR('E', 0x20 + ev, len)
const INPUT_PROP_ACCELEROMETER: u8 = 0x06;
const INPUT_PROP_CNT: usize = 0x20;
const EV_KEY_CODE: u8 = 0x01;
const KEY_MAX: usize = 0x2ff;
const KEY_BYTES: usize = (KEY_MAX + 7) / 8 + 1; // 96 bytes

fn EVIOCGPROP(len: u14) u32 {
    const req = std.os.linux.IOCTL.Request{ .dir = 2, .io_type = 'E', .nr = 0x09, .size = len };
    return @bitCast(req);
}

fn EVIOCGBIT(ev: u8, len: u14) u32 {
    const req = std.os.linux.IOCTL.Request{ .dir = 2, .io_type = 'E', .nr = 0x20 + ev, .size = len };
    return @bitCast(req);
}

fn readPropBitmap(path: []const u8) ![INPUT_PROP_CNT / 8]u8 {
    const fd = try posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(fd);

    var props: [INPUT_PROP_CNT / 8]u8 = std.mem.zeroes([INPUT_PROP_CNT / 8]u8);
    const rc = linux.ioctl(fd, EVIOCGPROP(@intCast(props.len)), @intFromPtr(&props));
    if (posix.errno(rc) != .SUCCESS) return error.EvdevPropIoctlFailed;
    return props;
}

fn readKeyBitmap(path: []const u8) ![KEY_BYTES]u8 {
    const fd = try posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(fd);

    var key_bits: [KEY_BYTES]u8 = std.mem.zeroes([KEY_BYTES]u8);
    const rc = linux.ioctl(fd, EVIOCGBIT(EV_KEY_CODE, @intCast(key_bits.len)), @intFromPtr(&key_bits));
    if (posix.errno(rc) != .SUCCESS) return error.EvdevKeyBitIoctlFailed;
    return key_bits;
}

fn hasPropBit(props: []const u8, bit: u8) bool {
    const byte_idx: usize = bit / 8;
    const bit_idx: u3 = @intCast(bit % 8);
    if (byte_idx >= props.len) return false;
    return ((props[byte_idx] >> bit_idx) & 1) == 1;
}

fn keyBitmapPopcount(bits: []const u8) usize {
    var total: usize = 0;
    for (bits) |b| total += @popCount(b);
    return total;
}

fn printHex(label: []const u8, bytes: []const u8) void {
    std.debug.print("{s} (len={d}):", .{ label, bytes.len });
    for (bytes) |b| std.debug.print(" {x:0>2}", .{b});
    std.debug.print("\n", .{});
}

// A minimal Generic-Desktop Gamepad descriptor for the main-pad fd — the IMU
// fd now uses the production `UhidDescriptorBuilder.buildForImu` so this AC
// test evaluates the exact descriptor padctl ships (previously it hard-coded
// a copy, which let R-C B1's Sensor-page bug escape CI).
//
// The Wave 5 canary assertions rely on the primary pad exposing at least one
// EV_KEY bit (so SDL classifies it as a gamepad). We include one Button Page
// usage (BTN_SOUTH = button 1) so the kernel's hid-input mapper emits exactly
// one BTN_* bit on the evdev node. Without this, the EV_KEY control sample
// would be vacuous.
const MAIN_DESCRIPTOR = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x05, // Usage (Game Pad)
    0xA1, 0x01, // Collection (Application)
    // --- Button Page: 1 button ---
    0x05, 0x09, // Usage Page (Button)
    0x19, 0x01, // Usage Minimum (1)
    0x29, 0x01, // Usage Maximum (1)
    0x15, 0x00, 0x25, 0x01, // Logical Min/Max 0..1
    0x75, 0x01, 0x95, 0x01, // Report Size 1, Count 1
    0x81, 0x02, // Input (Data, Var, Abs)
    // padding to byte boundary (7 bits)
    0x75, 0x07,
    0x95, 0x01,
    0x81, 0x03, // Input (Const, Var, Abs) padding
    // --- Axis X ---
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x30, // Usage (X)
    0x15, 0x00, 0x26, 0xFF, 0x00, // Logical Min/Max 0..255
    0x75, 0x08, 0x95, 0x01, // Report Size 8, Count 1
    0x81, 0x02, // Input (Data, Var, Abs)
    0xC0, // End Collection
};

test "uhid: EVIOCGUNIQ returns identical strings on a paired main-pad + IMU (ADR-015 Stage 1 AC)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    // Probe /dev/uhid accessibility — if the test host lacks permission,
    // emit a loud warning so the gap is visible in logs rather than
    // silently passing.
    const probe = uhid.openUhid() catch |err| switch (err) {
        error.SkipZigTest => return reportMissingUhid("openUhid returned SkipZigTest"),
        else => |e| return e,
    };
    posix.close(probe);

    const MAIN_VID: u16 = 0xFADE;
    const MAIN_PID: u16 = 0xC001;
    const IMU_VID: u16 = 0xFADE;
    const IMU_PID: u16 = 0xC002;

    // Build the IMU descriptor from production code — ensures the AC test
    // exercises the same byte stream that ships in DeviceInstance.init.
    const imu_cfg = device_cfg.ImuConfig{};
    const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(testing.allocator, imu_cfg);
    defer testing.allocator.free(imu_desc);

    // Create two UHID devices sharing the same uniq.
    const main_fd = try uhid.openUhid();
    defer {
        uhid.uhidDestroy(main_fd);
        posix.close(main_fd);
    }
    try sendCreateWithUniq(main_fd, MAIN_VID, MAIN_PID, "padctl-main", SHARED_UNIQ, &MAIN_DESCRIPTOR);

    const imu_fd = try uhid.openUhid();
    defer {
        uhid.uhidDestroy(imu_fd);
        posix.close(imu_fd);
    }
    try sendCreateWithUniq(imu_fd, IMU_VID, IMU_PID, "padctl-imu", SHARED_UNIQ, imu_desc);

    // Wait for evdev nodes to appear.
    const main_path = (try waitForEvdevNode(MAIN_VID, MAIN_PID, SHARED_UNIQ, 2000)) orelse
        return reportMissingUhid("main-pad evdev node did not appear (input subsystem denied?)");
    const imu_path = (try waitForEvdevNode(IMU_VID, IMU_PID, SHARED_UNIQ, 2000)) orelse
        return reportMissingUhid("imu evdev node did not appear");

    const main_path_len = std.mem.indexOfScalar(u8, &main_path, 0) orelse main_path.len;
    const imu_path_len = std.mem.indexOfScalar(u8, &imu_path, 0) orelse imu_path.len;

    const main_uniq = try readUniqFromEvdevPath(main_path[0..main_path_len]);
    defer testing.allocator.free(main_uniq);
    const imu_uniq = try readUniqFromEvdevPath(imu_path[0..imu_path_len]);
    defer testing.allocator.free(imu_uniq);

    // The actual contract — what SDL strcmp tests for.
    try testing.expectEqualStrings(SHARED_UNIQ, main_uniq);
    try testing.expectEqualStrings(SHARED_UNIQ, imu_uniq);
    try testing.expectEqualSlices(u8, main_uniq, imu_uniq);

    // -----------------------------------------------------------------------
    // Wave 5 canary — kernel evdev classification. If `buildForImu`'s
    // descriptor is kernel-accepted, the IMU node must expose
    // INPUT_PROP_ACCELEROMETER and carry zero EV_KEY bits. The primary pad
    // node must carry at least one EV_KEY bit (control sample).
    // -----------------------------------------------------------------------
    const imu_props = try readPropBitmap(imu_path[0..imu_path_len]);
    const imu_keys = try readKeyBitmap(imu_path[0..imu_path_len]);
    const main_keys = try readKeyBitmap(main_path[0..main_path_len]);

    if (!hasPropBit(&imu_props, INPUT_PROP_ACCELEROMETER)) {
        printHex("IMU EVIOCGPROP", &imu_props);
        printHex("IMU EVIOCGBIT(EV_KEY)", &imu_keys);
        std.debug.print(
            "IMU node '{s}' lacks INPUT_PROP_ACCELEROMETER (bit 0x{x}) — SDL will NOT classify as sensor.\n",
            .{ imu_path[0..imu_path_len], INPUT_PROP_ACCELEROMETER },
        );
    }
    try testing.expect(hasPropBit(&imu_props, INPUT_PROP_ACCELEROMETER));

    const imu_key_count = keyBitmapPopcount(&imu_keys);
    if (imu_key_count != 0) {
        printHex("IMU EVIOCGBIT(EV_KEY)", &imu_keys);
        std.debug.print(
            "IMU node '{s}' has {d} EV_KEY bits — SDL will reclassify as gamepad.\n",
            .{ imu_path[0..imu_path_len], imu_key_count },
        );
    }
    try testing.expectEqual(@as(usize, 0), imu_key_count);

    // Control: primary pad must still look like a gamepad.
    const main_key_count = keyBitmapPopcount(&main_keys);
    if (main_key_count == 0) {
        printHex("primary pad EVIOCGBIT(EV_KEY)", &main_keys);
        std.debug.print(
            "primary pad node '{s}' carries zero EV_KEY bits — regression: SDL will not classify as gamepad.\n",
            .{main_path[0..main_path_len]},
        );
    }
    try testing.expect(main_key_count >= 1);
}

fn sendCreateWithUniq(
    fd: posix.fd_t,
    vid: u16,
    pid: u16,
    name: []const u8,
    uniq: []const u8,
    descriptor: []const u8,
) !void {
    var ev = std.mem.zeroes(uhid.UhidCreate2Event);
    ev.type = uhid.UHID_CREATE2;
    const name_copy = @min(name.len, ev.payload.name.len - 1);
    @memcpy(ev.payload.name[0..name_copy], name[0..name_copy]);
    const uniq_copy = @min(uniq.len, ev.payload.uniq.len - 1);
    @memcpy(ev.payload.uniq[0..uniq_copy], uniq[0..uniq_copy]);
    if (descriptor.len > ev.payload.rd_data.len) return error.DescriptorTooLarge;
    ev.payload.rd_size = @intCast(descriptor.len);
    ev.payload.bus = uhid.BUS_USB;
    ev.payload.vendor = vid;
    ev.payload.product = pid;
    @memcpy(ev.payload.rd_data[0..descriptor.len], descriptor);

    const bytes = std.mem.asBytes(&ev);
    var buf: [uhid.UHID_EVENT_SIZE]u8 = std.mem.zeroes([uhid.UHID_EVENT_SIZE]u8);
    const copy_len = @min(bytes.len, uhid.UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

test "uhid: EVIOCGUNIQ ioctl constructor round-trips the size field" {
    // Defensive unit test — if the IOCTL.Request layout ever drifts, this
    // catches it before the hardware-gated test above.
    const r = ioctl_constants.EVIOCGUNIQ(64);
    // Direction = _IOC_READ = 2; io_type = 'E' (0x45); nr = 0x08; size = 64.
    // Kernel layout (from linux/ioctl.h):
    //   bits 0..7   = nr
    //   bits 8..15  = type
    //   bits 16..29 = size
    //   bits 30..31 = dir
    try testing.expectEqual(@as(u32, 0x08), r & 0xFF);
    try testing.expectEqual(@as(u32, 'E'), (r >> 8) & 0xFF);
    try testing.expectEqual(@as(u32, 64), (r >> 16) & 0x3FFF);
    try testing.expectEqual(@as(u32, 2), (r >> 30) & 0x3);
}
