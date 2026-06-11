//! Shadow input-node watchdog (issue #406).
//!
//! When a kernel driver (e.g. xpad) binds an unclaimed interface of a managed
//! pad it creates a raw /dev/input/event* node carrying all buttons. SDL and
//! games sometimes read that node instead of padctl's virtual device, so
//! "disabled" bindings leak through. EVIOCGRAB hides a node from all other
//! readers and needs no privileges under active-seat ACLs.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("ioctl_constants.zig");
const uniq_mod = @import("uniq.zig");

pub const MAX_GRABS = @import("hidraw.zig").MAX_EVDEV_GRABS;

const BUS_VIRTUAL: u16 = 0x06;
const NAME_CAP = 24;

pub const Params = struct {
    phys_vendor: u16,
    phys_product: u16,
};

pub const GrabResult = enum { grabbed, skipped, access_denied };

const Grab = struct {
    fd: posix.fd_t,
    name_buf: [NAME_CAP]u8,
    name_len: u8,

    fn name(self: *const Grab) []const u8 {
        return self.name_buf[0..self.name_len];
    }
};

pub const GrabList = struct {
    grabs: [MAX_GRABS]Grab = undefined,
    len: usize = 0,

    pub fn contains(self: *const GrabList, node: []const u8) bool {
        for (self.grabs[0..self.len]) |*g| {
            if (std.mem.eql(u8, g.name(), node)) return true;
        }
        return false;
    }

    /// Closing a grabbed fd implicitly releases its EVIOCGRAB.
    pub fn releaseAll(self: *GrabList) void {
        for (self.grabs[0..self.len]) |*g| posix.close(g.fd);
        self.len = 0;
    }

    /// Drop the grab on `node` (the kernel reuses eventN names, so a stale
    /// entry would block grabbing a new shadow with the same name).
    pub fn evict(self: *GrabList, node: []const u8) bool {
        for (self.grabs[0..self.len], 0..) |*g, i| {
            if (!std.mem.eql(u8, g.name(), node)) continue;
            posix.close(g.fd);
            self.len -= 1;
            self.grabs[i] = self.grabs[self.len];
            return true;
        }
        return false;
    }

    /// Evict entries whose device is gone (fd answers ENODEV).
    pub fn pruneDead(self: *GrabList) void {
        var i: usize = 0;
        while (i < self.len) {
            var id: ioctl.InputId = undefined;
            if (linux.E.init(linux.ioctl(self.grabs[i].fd, ioctl.EVIOCGID, @intFromPtr(&id))) == .NODEV) {
                posix.close(self.grabs[i].fd);
                self.len -= 1;
                self.grabs[i] = self.grabs[self.len];
            } else {
                i += 1;
            }
        }
    }
};

/// Pure decision seam: grab when the node carries the managed device's
/// physical VID/PID and is not one of padctl's own outputs — virtual-bus
/// uinput or "padctl/"-uniq UHID. The [output] identity is deliberately not
/// excluded: configs often clone the physical VID/PID, and padctl's outputs
/// are already covered by the bus/uniq checks.
pub fn shouldGrab(id: ioctl.InputId, uniq: []const u8, p: Params) bool {
    if (id.bustype == BUS_VIRTUAL) return false;
    if (std.mem.startsWith(u8, uniq, uniq_mod.PREFIX)) return false;
    return id.vendor == p.phys_vendor and id.product == p.phys_product;
}

fn readUniq(fd: posix.fd_t, buf: *[uniq_mod.MAX_UNIQ_LEN]u8) []const u8 {
    @memset(buf, 0);
    const rc = linux.ioctl(fd, ioctl.EVIOCGUNIQ(buf.len), @intFromPtr(buf));
    if (posix.errno(rc) != .SUCCESS) return "";
    return std.mem.sliceTo(buf, 0);
}

fn driverName(node: []const u8, buf: []u8) ?[]const u8 {
    var path_buf: [80]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/sys/class/input/{s}/device/device/driver", .{node}) catch return null;
    const target = posix.readlink(path, buf) catch return null;
    return std.fs.path.basename(target);
}

/// `.access_denied` flags nodes whose udev permissions are not applied yet
/// so the caller can retry; any other open failure is not retryable.
fn classifyOpenError(err: posix.OpenError) GrabResult {
    return switch (err) {
        error.AccessDenied => .access_denied,
        else => .skipped,
    };
}

/// Probe one event node and grab it when it shadows the managed device.
pub fn tryGrabNode(list: *GrabList, input_dir: []const u8, node: []const u8, p: Params) GrabResult {
    if (node.len == 0 or node.len > NAME_CAP) return .skipped;
    if (list.contains(node)) return .skipped;
    if (list.len >= list.grabs.len) return .skipped;

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ input_dir, node }) catch return .skipped;
    const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch |err| return classifyOpenError(err);

    var id: ioctl.InputId = undefined;
    if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCGID, @intFromPtr(&id))) != .SUCCESS) {
        posix.close(fd);
        return .skipped;
    }
    var uniq_buf: [uniq_mod.MAX_UNIQ_LEN]u8 = undefined;
    const uniq = readUniq(fd, &uniq_buf);
    if (!shouldGrab(id, uniq, p)) {
        posix.close(fd);
        return .skipped;
    }

    const grab_errno = linux.E.init(linux.ioctl(fd, ioctl.EVIOCGRAB, 1));
    if (grab_errno != .SUCCESS) {
        // EBUSY: someone already holds the exclusive grab (typically padctl's
        // own hidraw-associated grab), so the node is hidden anyway.
        if (grab_errno == .BUSY) {
            std.log.debug("shadow grab: {s} already grabbed", .{path});
        } else {
            std.log.warn("shadow grab: EVIOCGRAB {s} failed: {s}", .{ path, @tagName(grab_errno) });
        }
        posix.close(fd);
        return .skipped;
    }

    list.grabs[list.len] = .{ .fd = fd, .name_buf = undefined, .name_len = @intCast(node.len) };
    @memcpy(list.grabs[list.len].name_buf[0..node.len], node);
    list.len += 1;

    var drv_buf: [128]u8 = undefined;
    if (driverName(node, &drv_buf)) |drv| {
        std.log.warn("shadow input node {s} ({x:0>4}:{x:0>4}) grabbed; kernel driver {s} bound to a managed device", .{ path, id.vendor, id.product, drv });
    } else {
        std.log.warn("shadow input node {s} ({x:0>4}:{x:0>4}) grabbed; kernel driver bound to a managed device", .{ path, id.vendor, id.product });
    }
    return .grabbed;
}

/// Enumerate `input_dir` and grab every shadow node of the managed device.
/// Catches shadows that predate the daemon (the netlink watch only sees new
/// nodes). Dead grabs are pruned first so reused eventN names stay grabbable.
pub fn sweepDir(list: *GrabList, input_dir: []const u8, p: Params) void {
    list.pruneDead();
    var dir = std.fs.openDirAbsolute(input_dir, .{ .iterate = true }) catch return;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch return) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;
        _ = tryGrabNode(list, input_dir, entry.name, p);
    }
}

// --- tests ---

const testing = std.testing;

fn nodeId(bustype: u16, vendor: u16, product: u16) ioctl.InputId {
    return .{ .bustype = bustype, .vendor = vendor, .product = product, .version = 0x0110 };
}

const vader5: Params = .{
    .phys_vendor = 0x37d7,
    .phys_product = 0x2401,
};

test "shadow_grab: shouldGrab takes xpad shadow node (BUS_USB, physical VID/PID)" {
    try testing.expect(shouldGrab(nodeId(0x03, 0x37d7, 0x2401), "", vader5));
}

test "shadow_grab: shouldGrab skips padctl uinput outputs (BUS_VIRTUAL)" {
    try testing.expect(!shouldGrab(nodeId(0x06, 0x045e, 0x0b00), "", vader5));
    // Even a virtual-bus node cloning the physical VID/PID is ours, not a shadow.
    try testing.expect(!shouldGrab(nodeId(0x06, 0x37d7, 0x2401), "", vader5));
}

test "shadow_grab: shouldGrab skips padctl UHID outputs by uniq prefix" {
    // clone_vid_pid UHID FFB device: BUS_USB + physical VID/PID, only the
    // uniq distinguishes it from a real xpad shadow.
    try testing.expect(!shouldGrab(nodeId(0x03, 0x37d7, 0x2401), "padctl/vader-5-pro-1a2b", vader5));
}

test "shadow_grab: shouldGrab takes shadows when [output] clones the physical identity" {
    // xbox-elite-style config: [output] vid/pid equals the physical vid/pid,
    // so a genuine xpad shadow carries the output identity too.
    const p: Params = .{ .phys_vendor = 0x045e, .phys_product = 0x0b00 };
    try testing.expect(shouldGrab(nodeId(0x03, 0x045e, 0x0b00), "", p));
}

test "shadow_grab: shouldGrab skips unrelated devices" {
    try testing.expect(!shouldGrab(nodeId(0x03, 0x046d, 0xc52b), "", vader5));
    try testing.expect(!shouldGrab(nodeId(0x05, 0x37d7, 0x2402), "", vader5));
}

test "shadow_grab: GrabList contains/releaseAll bookkeeping" {
    var list = GrabList{};
    try testing.expect(!list.contains("event3"));

    const fd = try posix.open("/dev/null", .{ .ACCMODE = .RDONLY }, 0);
    list.grabs[0] = .{ .fd = fd, .name_buf = undefined, .name_len = 6 };
    @memcpy(list.grabs[0].name_buf[0..6], "event3");
    list.len = 1;

    try testing.expect(list.contains("event3"));
    try testing.expect(!list.contains("event33"));
    list.releaseAll();
    try testing.expectEqual(@as(usize, 0), list.len);
}

test "shadow_grab: tryGrabNode rejects oversized, duplicate, and unopenable nodes" {
    var list = GrabList{};
    try testing.expectEqual(GrabResult.skipped, tryGrabNode(&list, "/dev/input", "event-name-way-too-long-to-fit", vader5));
    try testing.expectEqual(GrabResult.skipped, tryGrabNode(&list, "/nonexistent_input_dir_xyz", "event0", vader5));
    list.grabs[0] = .{ .fd = -1, .name_buf = undefined, .name_len = 6 };
    @memcpy(list.grabs[0].name_buf[0..6], "event7");
    list.len = 1;
    try testing.expectEqual(GrabResult.skipped, tryGrabNode(&list, "/nonexistent_input_dir_xyz", "event7", vader5));
    list.len = 0;
}

test "shadow_grab: classifyOpenError marks only AccessDenied retryable" {
    try testing.expectEqual(GrabResult.access_denied, classifyOpenError(error.AccessDenied));
    try testing.expectEqual(GrabResult.skipped, classifyOpenError(error.FileNotFound));
    try testing.expectEqual(GrabResult.skipped, classifyOpenError(error.DeviceBusy));
}

test "shadow_grab: evict closes the named grab and frees the name for reuse" {
    var list = GrabList{};
    inline for (.{ "event3", "event4" }, 0..) |n, i| {
        const fd = try posix.open("/dev/null", .{ .ACCMODE = .RDONLY }, 0);
        list.grabs[i] = .{ .fd = fd, .name_buf = undefined, .name_len = n.len };
        @memcpy(list.grabs[i].name_buf[0..n.len], n);
    }
    list.len = 2;

    try testing.expect(!list.evict("event9"));
    try testing.expect(list.evict("event3"));
    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expect(!list.contains("event3"));
    try testing.expect(list.contains("event4"));

    // A reused kernel name is grabbable again: contains() no longer blocks it.
    try testing.expect(!list.evict("event3"));
    list.releaseAll();
}

test "shadow_grab: pruneDead keeps live fds" {
    var list = GrabList{};
    const fd = try posix.open("/dev/null", .{ .ACCMODE = .RDONLY }, 0);
    list.grabs[0] = .{ .fd = fd, .name_buf = undefined, .name_len = 6 };
    @memcpy(list.grabs[0].name_buf[0..6], "event3");
    list.len = 1;
    list.pruneDead();
    try testing.expectEqual(@as(usize, 1), list.len);
    list.releaseAll();
}

test "shadow_grab: sweepDir on nonexistent dir is a no-op" {
    var list = GrabList{};
    sweepDir(&list, "/nonexistent_input_dir_xyz", vader5);
    try testing.expectEqual(@as(usize, 0), list.len);
}
