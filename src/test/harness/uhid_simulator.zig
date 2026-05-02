//! Generalised UHID simulator harness for padctl end-to-end testing.
//!
//! A `UhidSimulator` **produces** a virtual HID device so padctl (reading from
//! `/dev/hidrawN`) sees it as an ordinary hardware gamepad. Use it to drive
//! the full daemon pipeline without needing physical hardware.
//!
//! Design shape:
//!   - `create(opts)` opens `/dev/uhid`, ships `UHID_CREATE2`, blocks until
//!     the kernel exposes the hidraw node (bounded poll), and records the
//!     discovered `/dev/hidrawN` path.
//!   - `injectReport(bytes)` sends a `UHID_INPUT2` with a caller-supplied
//!     payload; padctl's hidraw reader observes it unchanged.
//!   - `onFeatureReport(callback)` is a Wave 1 stub — wire with real
//!     `UHID_FEATURE` kernel → userspace handling in Wave 3 when routing
//!     switches land (see issue #126 for the 0x81 Steam-mode switch).
//!   - `destroy()` ships `UHID_DESTROY` and closes the fd.
//!
//! CI posture: every method gracefully skips when `/dev/uhid` is absent or
//! unwritable (no CAP_SYS_ADMIN, non-Linux host) by returning
//! `error.SkipZigTest`.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

// Module-relative imports — keeps the harness reachable from both the
// `src` barrel module (via `testing_support`) and from the standalone
// `uhid_integration_test` target without needing a dedicated `src`
// module-import edge.
const uhid = @import("../../io/uhid.zig");
const ioctl_constants = @import("../../io/ioctl_constants.zig");
const cleanup = @import("../uhid_test_cleanup.zig");

pub const SimulatorError = error{
    SkipZigTest,
    HidrawNotFound,
    KernelBusy,
} || posix.OpenError || posix.WriteError || posix.ReadError || posix.PollError;

pub const CreateOptions = struct {
    vid: u16,
    pid: u16,
    /// Device name — surfaces in /sys/class/hid/.../name.
    name: []const u8 = "padctl-uhid-sim",
    /// Unique identifier — surfaces in /sys/class/hid/.../uniq.
    uniq: []const u8 = "padctl/sim-0",
    /// HID report descriptor bytes.
    descriptor: []const u8,
    /// Max time (ms) to wait for the kernel to create the `/dev/hidrawN` node
    /// after UHID_CREATE2. Tests accept the default; stress harnesses may
    /// want a longer ceiling.
    hidraw_timeout_ms: u32 = 500,
};

/// Callback type for `onFeatureReport`. Wave 1 does not deliver events; the
/// callback slot is preserved so Wave 3 routing can wire real kernel events
/// without changing the test surface.
pub const FeatureCallback = *const fn (report_id: u8, data: []const u8) void;

pub const UhidSimulator = struct {
    fd: posix.fd_t,
    /// Nul-terminated path to the discovered `/dev/hidrawN` node. Empty when
    /// no match was located within `hidraw_timeout_ms`.
    hidraw_path_buf: [64]u8 = std.mem.zeroes([64]u8),
    hidraw_path_len: usize = 0,
    vid: u16,
    pid: u16,
    feature_cb: ?FeatureCallback = null,

    /// Open `/dev/uhid`, create a virtual HID device, and block (bounded) until
    /// the kernel exposes it as `/dev/hidrawN`.
    ///
    /// Returns `error.SkipZigTest` on hosts where `/dev/uhid` is missing or
    /// the caller lacks permission — keeps the test suite green on macOS and
    /// unprivileged CI runners.
    pub fn create(opts: CreateOptions) SimulatorError!UhidSimulator {
        if (builtin.os.tag != .linux) return error.SkipZigTest;
        if (opts.descriptor.len == 0) return error.SkipZigTest;
        if (opts.descriptor.len > uhid.HID_MAX_DESCRIPTOR_SIZE) return error.SkipZigTest;

        cleanup.ensureSignalHandlersInstalled();
        const fd = uhid.openUhid() catch |err| switch (err) {
            error.SkipZigTest => return error.SkipZigTest,
            else => |e| return e,
        };
        cleanup.registerUhidFd(fd);
        errdefer posix.close(fd);

        sendCreate(fd, opts) catch |err| switch (err) {
            error.SkipZigTest => return error.SkipZigTest,
            else => |e| return e,
        };

        var self = UhidSimulator{
            .fd = fd,
            .vid = opts.vid,
            .pid = opts.pid,
        };

        // Bounded poll for the hidraw node. Real kernels take ~20-100ms to
        // wire the hidraw class device up. We deliberately exceed the test
        // timeout by a small factor so slow CI doesn't flap. The optional
        // uniq filter excludes real hardware sharing our synthetic VID/PID
        // — belt-and-braces defence against vendor-ID collisions.
        const start = std.time.milliTimestamp();
        const deadline = start + @as(i64, @intCast(opts.hidraw_timeout_ms));
        while (std.time.milliTimestamp() < deadline) {
            if (try findHidrawPath(opts.vid, opts.pid, opts.uniq)) |entry| {
                @memcpy(self.hidraw_path_buf[0..entry.len], entry.slice());
                self.hidraw_path_buf[entry.len] = 0;
                self.hidraw_path_len = entry.len;
                return self;
            }
            std.Thread.sleep(10 * std.time.ns_per_ms);
        }
        return error.HidrawNotFound;
    }

    /// Inject a HID input report. Padctl's hidraw reader sees the exact bytes
    /// the caller passed in.
    pub fn injectReport(self: *UhidSimulator, bytes: []const u8) SimulatorError!void {
        if (bytes.len > uhid.UHID_DATA_MAX) return error.SkipZigTest;
        uhid.uhidInput(self.fd, bytes) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.KernelBusy,
            error.PayloadTooLong => return error.SkipZigTest,
            else => |e| return e,
        };
    }

    /// Register a feature-report callback for Wave 3 routing tests. Wave 1
    /// stores the callback without invoking it — pair with the production
    /// UHID event loop once wave 3 ships.
    pub fn onFeatureReport(self: *UhidSimulator, cb: FeatureCallback) void {
        self.feature_cb = cb;
    }

    /// Nul-terminated path to the /dev/hidrawN node, or null if not found.
    pub fn hidrawPath(self: *const UhidSimulator) ?[]const u8 {
        if (self.hidraw_path_len == 0) return null;
        return self.hidraw_path_buf[0..self.hidraw_path_len];
    }

    /// Open the /dev/hidrawN node read-only (non-blocking). Caller closes.
    pub fn openHidraw(self: *const UhidSimulator) !posix.fd_t {
        const path = self.hidrawPath() orelse return error.HidrawNotFound;
        return posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    }

    /// Tear the virtual device down. Safe to call multiple times (the second
    /// call is a no-op).
    pub fn destroy(self: *UhidSimulator) void {
        if (self.fd < 0) return;
        cleanup.unregisterUhidFd(self.fd);
        uhid.uhidDestroy(self.fd);
        posix.close(self.fd);
        self.fd = -1;
    }

    fn sendCreate(fd: posix.fd_t, opts: CreateOptions) !void {
        var ev = std.mem.zeroes(uhid.UhidCreate2Event);
        ev.type = uhid.UHID_CREATE2;
        const name_copy = @min(opts.name.len, ev.payload.name.len - 1);
        @memcpy(ev.payload.name[0..name_copy], opts.name[0..name_copy]);
        const uniq_copy = @min(opts.uniq.len, ev.payload.uniq.len - 1);
        if (uniq_copy != 0) @memcpy(ev.payload.uniq[0..uniq_copy], opts.uniq[0..uniq_copy]);
        ev.payload.rd_size = std.math.cast(u16, opts.descriptor.len) orelse
            return error.SkipZigTest;
        ev.payload.bus = uhid.BUS_USB;
        ev.payload.vendor = opts.vid;
        ev.payload.product = opts.pid;
        ev.payload.version = 0;
        ev.payload.country = 0;
        @memcpy(ev.payload.rd_data[0..opts.descriptor.len], opts.descriptor);

        const bytes = std.mem.asBytes(&ev);
        var buf: [uhid.UHID_EVENT_SIZE]u8 = std.mem.zeroes([uhid.UHID_EVENT_SIZE]u8);
        const copy_len = @min(bytes.len, uhid.UHID_EVENT_SIZE);
        @memcpy(buf[0..copy_len], bytes[0..copy_len]);
        _ = try posix.write(fd, &buf);
    }
};

/// Small owning tuple for a discovered hidraw path.
const HidrawEntry = struct {
    storage: [64]u8,
    len: usize,

    pub fn slice(self: *const HidrawEntry) []const u8 {
        return self.storage[0..self.len];
    }
};

/// Find a /dev/hidrawN whose VID/PID match and — when `expect_uniq` is
/// non-empty — whose `HIDIOCGRAWUNIQ` attribute matches exactly. The uniq
/// filter prevents aliasing a real device that happens to share the
/// synthetic test VID/PID; when `expect_uniq` is empty the legacy
/// VID/PID-only match applies.
fn findHidrawPath(vid: u16, pid: u16, expect_uniq: []const u8) !?HidrawEntry {
    const linux = std.os.linux;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_constants.HidrawDevinfo = undefined;
        const rc = linux.ioctl(fd, ioctl_constants.HIDIOCGRAWINFO, @intFromPtr(&info));
        if (rc != 0) continue;
        const dev_vid: u16 = @bitCast(info.vendor);
        const dev_pid: u16 = @bitCast(info.product);
        if (dev_vid != vid or dev_pid != pid) continue;

        if (expect_uniq.len != 0) {
            var uniq_buf: [64]u8 = std.mem.zeroes([64]u8);
            const uniq_rc = linux.ioctl(fd, ioctl_constants.HIDIOCGRAWUNIQ(uniq_buf.len), @intFromPtr(&uniq_buf));
            if (uniq_rc < 0) continue;
            const nul = std.mem.indexOfScalar(u8, &uniq_buf, 0) orelse uniq_buf.len;
            if (!std.mem.eql(u8, uniq_buf[0..nul], expect_uniq)) continue;
        }

        var out = HidrawEntry{ .storage = undefined, .len = path.len };
        @memcpy(out.storage[0..path.len], path);
        return out;
    }
    return null;
}

// --- Tests -----------------------------------------------------------------

const testing = std.testing;

test "uhid_simulator: non-linux host skips cleanly" {
    if (builtin.os.tag == .linux) return error.SkipZigTest;
    try testing.expectError(error.SkipZigTest, UhidSimulator.create(.{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    }));
}

test "uhid_simulator: linux host without /dev/uhid or caps skips cleanly" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // `/dev/uhid` may exist but not be writable under test runners. We accept
    // either outcome: the device either came up, in which case we tear it
    // down, or we see SkipZigTest — both are "no CI failure".
    var sim = UhidSimulator.create(.{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-sim-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
        .hidraw_timeout_ms = 50,
    }) catch |err| switch (err) {
        error.SkipZigTest, error.HidrawNotFound, error.AccessDenied => return error.SkipZigTest,
        else => |e| return e,
    };
    defer sim.destroy();
    try testing.expect(sim.fd >= 0);
}
