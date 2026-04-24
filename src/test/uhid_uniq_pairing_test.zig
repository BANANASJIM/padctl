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
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/input/event{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);

        var id: [4]u16 = std.mem.zeroes([4]u16); // bustype, vendor, product, version
        const rc_id = linux.ioctl(fd, 0x80084502, @intFromPtr(&id)); // EVIOCGID
        if (rc_id != 0) continue;
        if (id[1] != vid or id[2] != pid) continue;

        var uniq_buf: [64]u8 = std.mem.zeroes([64]u8);
        const rc = linux.ioctl(fd, ioctl_constants.EVIOCGUNIQ(uniq_buf.len), @intFromPtr(&uniq_buf));
        if (rc < 0) continue;
        const nul = std.mem.indexOfScalar(u8, &uniq_buf, 0) orelse uniq_buf.len;
        if (!std.mem.eql(u8, uniq_buf[0..nul], expect_uniq)) continue;

        var result: [64]u8 = std.mem.zeroes([64]u8);
        @memcpy(result[0..path.len], path);
        return result;
    }
    return null;
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

// A minimal Generic-Desktop Gamepad descriptor for the main-pad fd — the IMU
// fd now uses the production `UhidDescriptorBuilder.buildForImu` so this AC
// test evaluates the exact descriptor padctl ships (previously it hard-coded
// a copy, which let R-C B1's Sensor-page bug escape CI).
const MAIN_DESCRIPTOR = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x05, // Usage (Game Pad)
    0xA1, 0x01, // Collection (Application)
    0x09, 0x30, // Usage (X)
    0x15, 0x00, 0x26, 0xFF, 0x00, // Logical Min/Max 0..255
    0x75, 0x08, 0x95, 0x01, // Report Size/Count 8/1
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
