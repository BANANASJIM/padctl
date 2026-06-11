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
    output_vendor: ?u16 = null,
    output_product: ?u16 = null,
};

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
};

/// Pure decision seam: grab when the node carries the managed device's
/// physical VID/PID and is not one of padctl's own outputs — virtual-bus
/// uinput, "padctl/"-uniq UHID, or the configured [output] identity.
pub fn shouldGrab(id: ioctl.InputId, uniq: []const u8, p: Params) bool {
    if (id.bustype == BUS_VIRTUAL) return false;
    if (std.mem.startsWith(u8, uniq, uniq_mod.PREFIX)) return false;
    if (id.vendor != p.phys_vendor or id.product != p.phys_product) return false;
    if (p.output_vendor) |ov| {
        if (p.output_product) |op| {
            if (id.vendor == ov and id.product == op) return false;
        }
    }
    return true;
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

/// Probe one event node and grab it when it shadows the managed device.
/// Returns true when the node was grabbed into `list`.
pub fn tryGrabNode(list: *GrabList, input_dir: []const u8, node: []const u8, p: Params) bool {
    if (node.len == 0 or node.len > NAME_CAP) return false;
    if (list.contains(node)) return false;
    if (list.len >= list.grabs.len) return false;

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ input_dir, node }) catch return false;
    const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch return false;

    var id: ioctl.InputId = undefined;
    if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCGID, @intFromPtr(&id))) != .SUCCESS) {
        posix.close(fd);
        return false;
    }
    var uniq_buf: [uniq_mod.MAX_UNIQ_LEN]u8 = undefined;
    const uniq = readUniq(fd, &uniq_buf);
    if (!shouldGrab(id, uniq, p)) {
        posix.close(fd);
        return false;
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
        return false;
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
    return true;
}

/// Enumerate `input_dir` and grab every shadow node of the managed device.
/// Catches shadows that predate the daemon (the netlink watch only sees new
/// nodes).
pub fn sweepDir(list: *GrabList, input_dir: []const u8, p: Params) void {
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
    .output_vendor = 0x045e,
    .output_product = 0x0b00,
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

test "shadow_grab: shouldGrab skips the configured output identity" {
    var p = vader5;
    p.phys_vendor = 0x045e;
    p.phys_product = 0x0b00;
    try testing.expect(!shouldGrab(nodeId(0x03, 0x045e, 0x0b00), "", p));
}

test "shadow_grab: shouldGrab skips unrelated devices" {
    try testing.expect(!shouldGrab(nodeId(0x03, 0x046d, 0xc52b), "", vader5));
    try testing.expect(!shouldGrab(nodeId(0x05, 0x37d7, 0x2402), "", vader5));
}

test "shadow_grab: shouldGrab without configured output ids still takes shadows" {
    const p: Params = .{ .phys_vendor = 0x37d7, .phys_product = 0x2401 };
    try testing.expect(shouldGrab(nodeId(0x03, 0x37d7, 0x2401), "", p));
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
    try testing.expect(!tryGrabNode(&list, "/dev/input", "event-name-way-too-long-to-fit", vader5));
    try testing.expect(!tryGrabNode(&list, "/nonexistent_input_dir_xyz", "event0", vader5));
    list.grabs[0] = .{ .fd = -1, .name_buf = undefined, .name_len = 6 };
    @memcpy(list.grabs[0].name_buf[0..6], "event7");
    list.len = 1;
    try testing.expect(!tryGrabNode(&list, "/nonexistent_input_dir_xyz", "event7", vader5));
    list.len = 0;
}

test "shadow_grab: sweepDir on nonexistent dir is a no-op" {
    var list = GrabList{};
    sweepDir(&list, "/nonexistent_input_dir_xyz", vader5);
    try testing.expectEqual(@as(usize, 0), list.len);
}
