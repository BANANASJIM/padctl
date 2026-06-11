//! Integration test for the shadow input-node watchdog (issue #406).
//!
//! Creates a uinput device that mimics a kernel-driver shadow node (BUS_USB
//! plus the managed pad's physical VID/PID, no uniq), runs the sweep, and
//! asserts the node is exclusively grabbed — a second EVIOCGRAB fails with
//! EBUSY — and released again by releaseAll(). Skips when /dev/uinput or the
//! created node is unavailable, same gating as the other uinput tests.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const shadow_grab = @import("../io/shadow_grab.zig");
const ioctl = @import("../io/ioctl_constants.zig");

const BUS_USB: u16 = 0x03;
const BUS_VIRTUAL: u16 = 0x06;
const EV_KEY: usize = 0x01;
const BTN_SOUTH: usize = 0x130;

const UinputSetup = extern struct {
    id: ioctl.InputId,
    name: [80]u8,
    ff_effects_max: u32,
};

fn expectIoctlOk(rc: usize) !void {
    if (linux.E.init(rc) != .SUCCESS) return error.IoctlFailed;
}

fn createPad(bustype: u16, vid: u16, pid: u16) !posix.fd_t {
    const fd = posix.open("/dev/uinput", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
    errdefer posix.close(fd);
    try expectIoctlOk(linux.ioctl(fd, ioctl.UI_SET_EVBIT, EV_KEY));
    try expectIoctlOk(linux.ioctl(fd, ioctl.UI_SET_KEYBIT, BTN_SOUTH));
    var setup = std.mem.zeroes(UinputSetup);
    setup.id.bustype = bustype;
    setup.id.vendor = vid;
    setup.id.product = pid;
    const name = "padctl-shadow-watchdog-test";
    @memcpy(setup.name[0..name.len], name);
    try expectIoctlOk(linux.ioctl(fd, ioctl.UI_DEV_SETUP, @intFromPtr(&setup)));
    try expectIoctlOk(linux.ioctl(fd, ioctl.UI_DEV_CREATE, 0));
    return fd;
}

fn destroyPad(fd: posix.fd_t) void {
    _ = linux.ioctl(fd, ioctl.UI_DEV_DESTROY, 0);
    posix.close(fd);
}

fn findEventNode(vid: u16, pid: u16, name_buf: *[24]u8) ?[]const u8 {
    var attempt: usize = 0;
    while (attempt < 20) : (attempt += 1) {
        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            var path_buf: [40]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "/dev/input/event{d}", .{i}) catch continue;
            const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
            defer posix.close(fd);
            var id: ioctl.InputId = undefined;
            if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCGID, @intFromPtr(&id))) != .SUCCESS) continue;
            if (id.vendor != vid or id.product != pid) continue;
            return std.fmt.bufPrint(name_buf, "event{d}", .{i}) catch null;
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    return null;
}

test "shadow_grab: sweep grabs a USB-bus shadow node exclusively and releases it" {
    const vid: u16 = 0xFAD7;
    const pid: u16 = 0x24FE;
    const ufd = try createPad(BUS_USB, vid, pid);
    defer destroyPad(ufd);

    var name_buf: [24]u8 = undefined;
    const node = findEventNode(vid, pid, &name_buf) orelse return error.SkipZigTest;

    var list = shadow_grab.GrabList{};
    defer list.releaseAll();

    // Foreign physical VID/PID: the sweep must not touch the node.
    shadow_grab.sweepDir(&list, "/dev/input", .{ .phys_vendor = 0xF0F0, .phys_product = 0x0F0F });
    try testing.expect(!list.contains(node));
    list.releaseAll();

    const params: shadow_grab.Params = .{ .phys_vendor = vid, .phys_product = pid };
    shadow_grab.sweepDir(&list, "/dev/input", params);
    try testing.expect(list.contains(node));

    // Re-sweep is idempotent: already-grabbed nodes are skipped.
    const len_after = list.len;
    shadow_grab.sweepDir(&list, "/dev/input", params);
    try testing.expectEqual(len_after, list.len);

    // EVIOCGRAB exclusivity is observable: a second grab fails with EBUSY.
    var path_buf: [40]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/dev/input/{s}", .{node});
    const probe = try posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(probe);
    try testing.expectEqual(linux.E.BUSY, linux.E.init(linux.ioctl(probe, ioctl.EVIOCGRAB, 1)));

    // releaseAll drops the grab: the probe fd can now take it.
    list.releaseAll();
    try testing.expectEqual(linux.E.SUCCESS, linux.E.init(linux.ioctl(probe, ioctl.EVIOCGRAB, 1)));
    _ = linux.ioctl(probe, ioctl.EVIOCGRAB, 0);
}

test "shadow_grab: sweep prunes a grab whose device is gone (ENODEV)" {
    const vid: u16 = 0xFAD7;
    const pid: u16 = 0x24FC;
    const ufd = try createPad(BUS_USB, vid, pid);
    var destroyed = false;
    defer if (!destroyed) destroyPad(ufd);

    var name_buf: [24]u8 = undefined;
    const node = findEventNode(vid, pid, &name_buf) orelse return error.SkipZigTest;

    var list = shadow_grab.GrabList{};
    defer list.releaseAll();
    const params: shadow_grab.Params = .{ .phys_vendor = vid, .phys_product = pid };
    shadow_grab.sweepDir(&list, "/dev/input", params);
    try testing.expect(list.contains(node));

    destroyPad(ufd);
    destroyed = true;

    shadow_grab.sweepDir(&list, "/dev/input", params);
    try testing.expect(!list.contains(node));
}

test "shadow_grab: sweep skips virtual-bus nodes (padctl's own uinput outputs)" {
    const vid: u16 = 0xFAD7;
    const pid: u16 = 0x24FD;
    const ufd = try createPad(BUS_VIRTUAL, vid, pid);
    defer destroyPad(ufd);

    var name_buf: [24]u8 = undefined;
    const node = findEventNode(vid, pid, &name_buf) orelse return error.SkipZigTest;

    var list = shadow_grab.GrabList{};
    defer list.releaseAll();
    shadow_grab.sweepDir(&list, "/dev/input", .{ .phys_vendor = vid, .phys_product = pid });
    try testing.expect(!list.contains(node));
}
