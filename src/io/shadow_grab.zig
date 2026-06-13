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

pub const GrabResult = enum { grabbed, already_grabbed, skipped, access_denied };

const Grab = struct {
    fd: posix.fd_t,
    name_buf: [NAME_CAP]u8,
    name_len: u8,
    // false when another reader holds the exclusive EVIOCGRAB (EBUSY): the node
    // is hidden so it counts as a handled shadow, but we own no fd to release.
    owned: bool = true,

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

    /// Append this list's STATUS wire fields: ` shadow_grabs=<n>` plus a
    /// comma-joined ` shadow_nodes=` list when any grab is held.
    pub fn appendStatusFields(self: *const GrabList, w: anytype) !void {
        try w.print(" shadow_grabs={d}", .{self.len});
        if (self.len == 0) return;
        try w.writeAll(" shadow_nodes=");
        for (self.grabs[0..self.len], 0..) |*g, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeAll(g.name());
        }
    }

    /// Record a foreign-held (EBUSY) node with no owned fd. Used by tests to
    /// populate a list without touching /dev/input.
    pub fn pushUnownedForTest(self: *GrabList, node: []const u8) void {
        if (self.len >= MAX_GRABS or node.len > NAME_CAP) return;
        var g = Grab{ .fd = -1, .name_buf = undefined, .name_len = @intCast(node.len), .owned = false };
        @memcpy(g.name_buf[0..node.len], node);
        self.grabs[self.len] = g;
        self.len += 1;
    }

    /// Closing a grabbed fd implicitly releases its EVIOCGRAB.
    pub fn releaseAll(self: *GrabList) void {
        for (self.grabs[0..self.len]) |*g| {
            if (g.owned) posix.close(g.fd);
        }
        self.len = 0;
    }

    /// Drop the grab on `node` (the kernel reuses eventN names, so a stale
    /// entry would block grabbing a new shadow with the same name).
    pub fn evict(self: *GrabList, node: []const u8) bool {
        for (self.grabs[0..self.len], 0..) |*g, i| {
            if (!std.mem.eql(u8, g.name(), node)) continue;
            if (g.owned) posix.close(g.fd);
            self.len -= 1;
            self.grabs[i] = self.grabs[self.len];
            return true;
        }
        return false;
    }

    /// Evict entries whose device is gone (owned fd answers ENODEV) and re-probe
    /// entries held by a foreign reader (owned=false). A foreign EVIOCGRAB that
    /// is later released leaves the node grabbable again with no REMOVE uevent,
    /// so an unowned entry must be re-validated rather than trusted forever:
    /// re-grab succeeds -> upgrade to an owned grab padctl now guards; still
    /// EBUSY -> keep counting it; node gone -> drop it. `/dev/input` matches the
    /// only production caller; revalidate is seam-injected for unit testing.
    pub fn pruneDead(self: *GrabList) void {
        self.pruneDeadWith(reopenGrab, "/dev/input");
    }

    fn pruneDeadWith(
        self: *GrabList,
        comptime revalidate: fn ([]const u8, []const u8) Revalidation,
        input_dir: []const u8,
    ) void {
        var i: usize = 0;
        while (i < self.len) {
            const g = &self.grabs[i];
            if (g.owned) {
                var id: ioctl.InputId = undefined;
                if (linux.E.init(linux.ioctl(g.fd, ioctl.EVIOCGID, @intFromPtr(&id))) == .NODEV) {
                    posix.close(g.fd);
                    self.dropAt(i);
                } else {
                    i += 1;
                }
                continue;
            }
            switch (revalidate(input_dir, g.name())) {
                .upgraded => |fd| {
                    g.fd = fd;
                    g.owned = true;
                    i += 1;
                },
                .still_busy => i += 1,
                .gone => self.dropAt(i),
            }
        }
    }

    fn dropAt(self: *GrabList, i: usize) void {
        self.len -= 1;
        self.grabs[i] = self.grabs[self.len];
    }
};

/// Outcome of re-probing an unowned (foreign-held) shadow entry.
const Revalidation = union(enum) {
    /// The foreign grab was released; padctl re-grabbed it and now owns this fd.
    upgraded: posix.fd_t,
    /// Another reader still holds the exclusive grab; keep the unowned entry.
    still_busy,
    /// The node is gone (open/ioctl failed); drop the entry.
    gone,
};

/// Re-open `node` read-only and re-attempt EVIOCGRAB. On success padctl owns
/// the returned fd; on EBUSY the node is still foreign-held; any open or other
/// ioctl failure means the node disappeared.
fn reopenGrab(input_dir: []const u8, node: []const u8) Revalidation {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ input_dir, node }) catch return .gone;
    const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch return .gone;
    switch (linux.E.init(linux.ioctl(fd, ioctl.EVIOCGRAB, 1))) {
        .SUCCESS => return .{ .upgraded = fd },
        .BUSY => {
            posix.close(fd);
            return .still_busy;
        },
        else => {
            posix.close(fd);
            return .gone;
        },
    }
}

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

/// EBUSY means another reader already holds the exclusive grab, so the shadow
/// is hidden either way and counts as handled; any other ioctl failure leaves
/// the node ungrabbed and uncounted.
fn classifyGrabErrno(e: linux.E) GrabResult {
    return switch (e) {
        .SUCCESS => .grabbed,
        .BUSY => .already_grabbed,
        else => .skipped,
    };
}

fn recordGrab(list: *GrabList, node: []const u8, fd: posix.fd_t, owned: bool) void {
    list.grabs[list.len] = .{ .fd = fd, .name_buf = undefined, .name_len = @intCast(node.len), .owned = owned };
    @memcpy(list.grabs[list.len].name_buf[0..node.len], node);
    list.len += 1;
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

    const result = classifyGrabErrno(linux.E.init(linux.ioctl(fd, ioctl.EVIOCGRAB, 1)));
    switch (result) {
        .grabbed => {
            recordGrab(list, node, fd, true);
            var drv_buf: [128]u8 = undefined;
            if (driverName(node, &drv_buf)) |drv| {
                std.log.warn("shadow input node {s} ({x:0>4}:{x:0>4}) grabbed; kernel driver {s} bound to a managed device", .{ path, id.vendor, id.product, drv });
            } else {
                std.log.warn("shadow input node {s} ({x:0>4}:{x:0>4}) grabbed; kernel driver bound to a managed device", .{ path, id.vendor, id.product });
            }
        },
        .already_grabbed => {
            // Hidden by another reader's grab; count it but own no fd to hold.
            std.log.debug("shadow grab: {s} already grabbed by another reader", .{path});
            posix.close(fd);
            recordGrab(list, node, -1, false);
        },
        else => {
            std.log.warn("shadow grab: EVIOCGRAB {s} failed", .{path});
            posix.close(fd);
        },
    }
    return result;
}

/// Enumerate `input_dir` and grab every shadow node of the managed device.
/// Catches shadows that predate the daemon (the netlink watch only sees new
/// nodes). Dead grabs are pruned first so reused eventN names stay grabbable.
/// `on_denied` (when non-null) is invoked with the node name for every node
/// that returns `.access_denied`, mirroring the netlink ADD retry path so a
/// pre-existing shadow whose udev ACL has not landed yet is not lost.
pub fn sweepDir(
    list: *GrabList,
    input_dir: []const u8,
    p: Params,
    ctx: anytype,
    comptime on_denied: ?fn (@TypeOf(ctx), []const u8) void,
) void {
    sweepDirWith(tryGrabNode, list, input_dir, p, ctx, on_denied);
}

/// `sweepDir` with the per-node grab function injectable so the denied-node
/// callback dispatch is testable without a real access-denied open (root, the
/// CI uid, bypasses file permissions).
fn sweepDirWith(
    comptime grab_fn: fn (*GrabList, []const u8, []const u8, Params) GrabResult,
    list: *GrabList,
    input_dir: []const u8,
    p: Params,
    ctx: anytype,
    comptime on_denied: ?fn (@TypeOf(ctx), []const u8) void,
) void {
    list.pruneDead();
    var dir = std.fs.openDirAbsolute(input_dir, .{ .iterate = true }) catch return;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch return) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;
        const r = grab_fn(list, input_dir, entry.name, p);
        if (r == .access_denied) {
            if (on_denied) |cb| cb(ctx, entry.name);
        }
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

test "shadow_grab: classifyGrabErrno counts EBUSY as a handled shadow" {
    try testing.expectEqual(GrabResult.grabbed, classifyGrabErrno(.SUCCESS));
    try testing.expectEqual(GrabResult.already_grabbed, classifyGrabErrno(.BUSY));
    // Any other ioctl failure leaves the node ungrabbed and uncounted.
    try testing.expectEqual(GrabResult.skipped, classifyGrabErrno(.NODEV));
    try testing.expectEqual(GrabResult.skipped, classifyGrabErrno(.INVAL));
}

fn revalidateStillBusy(_: []const u8, _: []const u8) Revalidation {
    return .still_busy;
}

fn revalidateGone(_: []const u8, _: []const u8) Revalidation {
    return .gone;
}

/// Upgrade fixture: opens /dev/null so the upgraded entry owns a real,
/// closeable fd (a bare sentinel would let close() bugs go undetected).
fn revalidateUpgrade(_: []const u8, _: []const u8) Revalidation {
    const fd = posix.open("/dev/null", .{ .ACCMODE = .RDONLY }, 0) catch unreachable;
    return .{ .upgraded = fd };
}

test "shadow_grab: an EBUSY-held shadow is counted but releaseAll skips its fd" {
    var list = GrabList{};
    // Simulate what tryGrabNode records on EBUSY: a counted, unowned entry
    // whose fd was already closed (-1 would crash close() if treated as owned).
    recordGrab(&list, "event8", -1, false);
    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expect(list.contains("event8"));

    // A still-foreign-held node stays counted and must not close the -1 fd.
    list.pruneDeadWith(revalidateStillBusy, "/dev/input");
    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expect(!list.grabs[0].owned);

    // releaseAll/evict must not posix.close(-1) on an unowned entry.
    try testing.expect(list.evict("event8"));
    try testing.expectEqual(@as(usize, 0), list.len);

    recordGrab(&list, "event8", -1, false);
    list.releaseAll();
    try testing.expectEqual(@as(usize, 0), list.len);
}

test "shadow_grab: pruneDead re-grabs an unowned shadow whose foreign holder released it" {
    var list = GrabList{};
    recordGrab(&list, "event8", -1, false);

    // The foreign reader released its grab: re-validation re-grabs the node, so
    // the phantom entry is upgraded to an owned grab padctl genuinely guards.
    list.pruneDeadWith(revalidateUpgrade, "/dev/input");
    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expect(list.grabs[0].owned);
    try testing.expect(list.grabs[0].fd >= 0);

    // The upgraded fd is owned, so releaseAll closes it (double-free would trap).
    list.releaseAll();
    try testing.expectEqual(@as(usize, 0), list.len);
}

test "shadow_grab: pruneDead drops an unowned shadow whose node is gone" {
    var list = GrabList{};
    recordGrab(&list, "event8", -1, false);
    recordGrab(&list, "event9", -1, false);

    list.pruneDeadWith(revalidateGone, "/dev/input");
    try testing.expectEqual(@as(usize, 0), list.len);
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
    sweepDir(&list, "/nonexistent_input_dir_xyz", vader5, {}, null);
    try testing.expectEqual(@as(usize, 0), list.len);
}

const DeniedSink = struct {
    nodes: std.ArrayList([]const u8) = .{},
    allocator: std.mem.Allocator,

    fn cb(self: *DeniedSink, node: []const u8) void {
        const owned = self.allocator.dupe(u8, node) catch return;
        self.nodes.append(self.allocator, owned) catch {};
    }
    fn deinit(self: *DeniedSink) void {
        for (self.nodes.items) |n| self.allocator.free(n);
        self.nodes.deinit(self.allocator);
    }
};

fn stubAlwaysDenied(_: *GrabList, _: []const u8, node: []const u8, _: Params) GrabResult {
    return if (std.mem.eql(u8, node, "event9")) .access_denied else .skipped;
}

test "shadow_grab: sweepDir reports access_denied nodes to the retry callback" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // The grab function is stubbed to report event9 as access_denied — the exact
    // race the netlink ADD path retries; the sweep must surface it to the
    // callback so a pre-existing shadow is not lost (uid-independent: root
    // bypasses real file permissions, so a 0000-mode file would not suffice).
    {
        var f = try tmp.dir.createFile("event9", .{});
        f.close();
    }
    {
        var f = try tmp.dir.createFile("event8", .{});
        f.close();
    }
    try tmp.dir.makePath("not-an-event"); // ignored: wrong prefix

    var sink = DeniedSink{ .allocator = allocator };
    defer sink.deinit();
    var list = GrabList{};
    sweepDirWith(stubAlwaysDenied, &list, tmp_path, vader5, &sink, DeniedSink.cb);

    try testing.expectEqual(@as(usize, 0), list.len);
    try testing.expectEqual(@as(usize, 1), sink.nodes.items.len);
    try testing.expectEqualStrings("event9", sink.nodes.items[0]);
}
