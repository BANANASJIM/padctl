const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub const UeventAction = enum { add, remove, other };

pub const Uevent = struct {
    action: UeventAction,
    devname: ?[]const u8,
    subsystem: ?[]const u8,
};

pub fn openNetlinkUevent() !posix.fd_t {
    const fd = try posix.socket(linux.AF.NETLINK, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK, linux.NETLINK.KOBJECT_UEVENT);
    errdefer posix.close(fd);
    const addr = linux.sockaddr.nl{ .pid = 0, .groups = 1 };
    try posix.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.nl));
    return fd;
}

/// Parse a null-delimited uevent message buffer.
/// Buffer format: "action@path\0KEY=val\0KEY=val\0..."
pub fn parseUevent(buf: []const u8) Uevent {
    var action: UeventAction = .other;
    var devname: ?[]const u8 = null;
    var subsystem: ?[]const u8 = null;

    var it = std.mem.splitScalar(u8, buf, 0);

    // First token: "action@path"
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
