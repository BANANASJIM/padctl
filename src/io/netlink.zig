const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub fn openNetlinkUevent() !posix.fd_t {
    const fd = try posix.socket(linux.AF.NETLINK, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK, linux.NETLINK.KOBJECT_UEVENT);
    errdefer posix.close(fd);
    const addr = linux.sockaddr.nl{ .pid = 0, .groups = 1 };
    try posix.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.nl));
    return fd;
}

pub const UeventAction = enum { add, remove, other };

pub const Uevent = struct {
    action: UeventAction,
    devname: ?[]const u8,
    subsystem: ?[]const u8,
};

/// Parse a null-delimited uevent message buffer.
/// Buffer format: "action@path\0KEY=val\0KEY=val\0..."
pub fn parseUevent(buf: []const u8) Uevent {
    var action: UeventAction = .other;
    var devname: ?[]const u8 = null;
    var subsystem: ?[]const u8 = null;

    var it = std.mem.splitScalar(u8, buf, 0);

    if (it.next()) |header| {
        if (std.mem.startsWith(u8, header, "add@")) {
            action = .add;
        } else if (std.mem.startsWith(u8, header, "remove@")) {
            action = .remove;
        }
    }

    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        if (std.mem.startsWith(u8, kv, "DEVNAME=")) {
            devname = kv["DEVNAME=".len..];
        } else if (std.mem.startsWith(u8, kv, "SUBSYSTEM=")) {
            subsystem = kv["SUBSYSTEM=".len..];
        }
    }

    return .{ .action = action, .devname = devname, .subsystem = subsystem };
}

/// Drain all pending uevent messages from fd, calling callback for each hidraw add/remove.
/// Stops when recv returns WouldBlock (EAGAIN).
pub fn drainNetlink(fd: posix.fd_t, ctx: anytype, comptime callback: fn (@TypeOf(ctx), UeventAction, []const u8) void) void {
    var buf: [2048]u8 = undefined;
    while (true) {
        const n = posix.recv(fd, &buf, 0) catch |err| switch (err) {
            error.WouldBlock => return,
            else => return,
        };
        if (n == 0) return;
        const ev = parseUevent(buf[0..n]);
        if (ev.action == .other) continue;
        const sub = ev.subsystem orelse continue;
        if (!std.mem.eql(u8, sub, "hidraw")) continue;
        const name = ev.devname orelse continue;
        callback(ctx, ev.action, name);
    }
}

// --- tests ---

const testing = std.testing;

test "parseUevent: add hidraw" {
    const msg = "add@/devices/platform/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = parseUevent(msg);
    try testing.expectEqual(UeventAction.add, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
    try testing.expectEqualStrings("hidraw", ev.subsystem.?);
}

test "parseUevent: remove hidraw" {
    const msg = "remove@/devices/platform/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = parseUevent(msg);
    try testing.expectEqual(UeventAction.remove, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
}

test "parseUevent: non-hidraw subsystem" {
    const msg = "add@/devices/usb/usb1\x00SUBSYSTEM=usb\x00DEVNAME=usb1\x00";
    const ev = parseUevent(msg);
    try testing.expectEqual(UeventAction.add, ev.action);
    try testing.expectEqualStrings("usb", ev.subsystem.?);
}

test "parseUevent: other action" {
    const msg = "change@/devices/platform/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = parseUevent(msg);
    try testing.expectEqual(UeventAction.other, ev.action);
}

test "parseUevent: missing DEVNAME" {
    const msg = "add@/devices/platform/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00";
    const ev = parseUevent(msg);
    try testing.expectEqual(UeventAction.add, ev.action);
    try testing.expect(ev.devname == null);
    try testing.expectEqualStrings("hidraw", ev.subsystem.?);
}
