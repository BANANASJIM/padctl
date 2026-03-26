const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const io = @import("device_io.zig");
const ioctl = @import("ioctl_constants.zig");

pub const DeviceIO = io.DeviceIO;

pub const MAX_EVDEV_GRABS = 8;

fn BoundedArray(comptime T: type, comptime cap: usize) type {
    return struct {
        buffer: [cap]T = undefined,
        len: usize = 0,

        pub fn append(self: *@This(), val: T) error{Overflow}!void {
            if (self.len >= cap) return error.Overflow;
            self.buffer[self.len] = val;
            self.len += 1;
        }

        pub fn constSlice(self: *const @This()) []const T {
            return self.buffer[0..self.len];
        }
    };
}

pub const HidrawDevice = struct {
    fd: posix.fd_t,
    evdev_fds: BoundedArray(posix.fd_t, MAX_EVDEV_GRABS),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HidrawDevice {
        return .{
            .fd = -1,
            .evdev_fds = .{},
            .allocator = allocator,
        };
    }

    /// Scan /dev/hidraw0..hidraw63 for a device matching vid/pid and interface_id.
    /// Returns an allocated path (caller must free) or error.NotFound.
    pub fn discover(
        allocator: std.mem.Allocator,
        vid: u16,
        pid: u16,
        interface_id: u8,
    ) ![]const u8 {
        return discoverWithRoot(allocator, vid, pid, interface_id, "/dev");
    }

    pub fn discoverWithRoot(
        allocator: std.mem.Allocator,
        vid: u16,
        pid: u16,
        interface_id: u8,
        dev_root: []const u8,
    ) ![]const u8 {
        var i: u8 = 0;
        while (i < 64) : (i += 1) {
            const path = try std.fmt.allocPrint(allocator, "{s}/hidraw{d}", .{ dev_root, i });
            defer allocator.free(path);

            const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
            defer posix.close(fd);

            var info: ioctl.HidrawDevinfo = undefined;
            const rc = linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info));
            if (rc != 0) continue;

            const dev_vid: u16 = @bitCast(info.vendor);
            const dev_pid: u16 = @bitCast(info.product);
            if (dev_vid != vid or dev_pid != pid) continue;

            const iface = readInterfaceId(path) orelse continue;
            if (iface != interface_id) continue;

            return try std.fmt.allocPrint(allocator, "{s}/hidraw{d}", .{ dev_root, i });
        }
        return error.NotFound;
    }

    /// Return all `/dev/hidrawN` paths whose VID/PID match.
    /// Caller owns the returned slice and each element (allocated with allocator).
    pub fn discoverAll(allocator: std.mem.Allocator, vid: u16, pid: u16) ![][]const u8 {
        return discoverAllWithRoot(allocator, vid, pid, "/dev");
    }

    pub fn discoverAllWithRoot(
        allocator: std.mem.Allocator,
        vid: u16,
        pid: u16,
        dev_root: []const u8,
    ) ![][]const u8 {
        var paths = std.ArrayList([]const u8){};
        errdefer {
            for (paths.items) |p| allocator.free(p);
            paths.deinit(allocator);
        }

        var i: u8 = 0;
        while (i < 64) : (i += 1) {
            var path_buf: [128]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "{s}/hidraw{d}", .{ dev_root, i }) catch continue;

            const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
            defer posix.close(fd);

            var info: ioctl.HidrawDevinfo = undefined;
            if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) continue;

            const dev_vid: u16 = @bitCast(info.vendor);
            const dev_pid: u16 = @bitCast(info.product);
            if (dev_vid != vid or dev_pid != pid) continue;

            const owned = try allocator.dupe(u8, path);
            try paths.append(allocator, owned);
        }

        return paths.toOwnedSlice(allocator);
    }

    /// Open the hidraw node at path.
    pub fn open(self: *HidrawDevice, path: []const u8) !void {
        self.fd = try posix.open(path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0);
    }

    /// Traverse sysfs to find evdev nodes associated with this hidraw device
    /// and EVIOCGRAB each one.
    pub fn grabAssociatedEvdev(self: *HidrawDevice, hidraw_path: []const u8) !void {
        return self.grabAssociatedEvdevWithRoot(hidraw_path, "/sys", "/dev/input");
    }

    pub fn grabAssociatedEvdevWithRoot(
        self: *HidrawDevice,
        hidraw_path: []const u8,
        sys_root: []const u8,
        input_dev_root: []const u8,
    ) !void {
        const node_name = std.fs.path.basename(hidraw_path); // "hidrawN"
        var path_buf: [256]u8 = undefined;
        const input_dir_path = try std.fmt.bufPrint(
            &path_buf,
            "{s}/class/hidraw/{s}/device/input",
            .{ sys_root, node_name },
        );

        var input_dir = std.fs.openDirAbsolute(input_dir_path, .{ .iterate = true }) catch return;
        defer input_dir.close();

        var it = input_dir.iterate();
        while (try it.next()) |entry| {
            if (!std.mem.startsWith(u8, entry.name, "input")) continue;

            var event_path_buf: [256]u8 = undefined;
            const event_dir_path = try std.fmt.bufPrint(
                &event_path_buf,
                "{s}/class/hidraw/{s}/device/input/{s}",
                .{ sys_root, node_name, entry.name },
            );

            var event_dir = std.fs.openDirAbsolute(event_dir_path, .{ .iterate = true }) catch continue;
            defer event_dir.close();

            var eit = event_dir.iterate();
            while (try eit.next()) |ev_entry| {
                if (!std.mem.startsWith(u8, ev_entry.name, "event")) continue;

                var dev_path_buf: [128]u8 = undefined;
                const dev_path = try std.fmt.bufPrint(
                    &dev_path_buf,
                    "{s}/{s}",
                    .{ input_dev_root, ev_entry.name },
                );

                const evfd = posix.open(dev_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
                const grab_rc = linux.ioctl(evfd, ioctl.EVIOCGRAB, @intFromPtr(&@as(c_int, 1)));
                if (grab_rc != 0) {
                    posix.close(evfd);
                    continue;
                }
                self.evdev_fds.append(evfd) catch {
                    posix.close(evfd);
                };
            }
        }
    }

    pub fn deviceIO(self: *HidrawDevice) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *HidrawDevice = @ptrCast(@alignCast(ptr));
        const n = posix.read(self.fd, buf) catch |err| switch (err) {
            error.WouldBlock => return DeviceIO.ReadError.Again,
            error.ConnectionResetByPeer, error.BrokenPipe => return DeviceIO.ReadError.Disconnected,
            else => return DeviceIO.ReadError.Io,
        };
        if (n == 0) return DeviceIO.ReadError.Disconnected;
        return n;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *HidrawDevice = @ptrCast(@alignCast(ptr));
        _ = posix.write(self.fd, data) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return DeviceIO.WriteError.Disconnected,
            else => return DeviceIO.WriteError.Io,
        };
    }

    fn pollfd(ptr: *anyopaque) posix.pollfd {
        const self: *HidrawDevice = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.fd, .events = posix.POLL.IN, .revents = 0 };
    }

    fn close(ptr: *anyopaque) void {
        const self: *HidrawDevice = @ptrCast(@alignCast(ptr));
        if (self.fd == -1) return;
        for (self.evdev_fds.constSlice()) |evfd| posix.close(evfd);
        self.evdev_fds.len = 0;
        posix.close(self.fd);
        self.fd = -1;
        self.allocator.destroy(self);
    }
};

/// Read the HID physical path from sysfs uevent; caller owns the returned slice.
pub fn readPhysicalPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const phys = readPhysFromSysfs(path) orelse return allocator.dupe(u8, path);
    const stripped = stripInputSuffix(phys);
    if (stripped.len == 0) return allocator.dupe(u8, path);
    return allocator.dupe(u8, stripped);
}

/// Read the interface number from sysfs uevent HID_PHYS for a hidraw node.
pub fn readInterfaceId(path: []const u8) ?u8 {
    const basename_s = std.fs.path.basename(path);
    var path_buf: [256]u8 = undefined;
    const sysfs_path = std.fmt.bufPrint(&path_buf, "/sys/class/hidraw/{s}/device/uevent", .{basename_s}) catch return null;
    const fd = std.fs.openFileAbsolute(sysfs_path, .{}) catch return null;
    defer fd.close();
    var buf: [1024]u8 = undefined;
    const n = fd.read(&buf) catch return null;
    if (n == 0) return null;
    var lines = std.mem.splitScalar(u8, buf[0..n], '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "HID_PHYS=")) {
            return parseInterfaceId(line["HID_PHYS=".len..]);
        }
    }
    return null;
}

/// Read HID_PHYS value from sysfs uevent file for a hidraw node.
/// Returned slice points into an internal read buffer; caller must copy if needed.
fn readPhysFromSysfs(path: []const u8) ?[]const u8 {
    const basename = std.fs.path.basename(path);
    var path_buf: [256]u8 = undefined;
    const sysfs_path = std.fmt.bufPrint(&path_buf, "/sys/class/hidraw/{s}/device/uevent", .{basename}) catch return null;
    const fd = std.fs.openFileAbsolute(sysfs_path, .{}) catch return null;
    defer fd.close();
    var buf: [1024]u8 = undefined;
    const n = fd.read(&buf) catch return null;
    if (n == 0) return null;
    const content = buf[0..n];
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "HID_PHYS=")) {
            const val = line["HID_PHYS=".len..];
            if (val.len > 0) return val;
        }
    }
    return null;
}

/// Strip trailing "/inputN" suffix from a physical path for dedup.
/// e.g. "usb-0000:00:14.0-8/input1" → "usb-0000:00:14.0-8"
pub fn stripInputSuffix(phys: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, phys, '/') orelse return phys;
    const tail = phys[slash + 1 ..];
    if (std.mem.startsWith(u8, tail, "input")) {
        const num = tail["input".len..];
        if (num.len > 0) {
            _ = std.fmt.parseInt(u8, num, 10) catch return phys;
            return phys[0..slash];
        }
    }
    return phys;
}

/// Parse interface number from HIDIOCGRAWPHYS string.
/// Looks for the last "/inputN" component and extracts N.
/// Returns null if no "input" segment is found.
pub fn parseInterfaceId(phys: []const u8) ?u8 {
    // Walk backwards through '/' segments looking for "inputN"
    var remaining = phys;
    while (remaining.len > 0) {
        const slash = std.mem.lastIndexOfScalar(u8, remaining, '/');
        const segment = if (slash) |s| remaining[s + 1 ..] else remaining;
        if (std.mem.startsWith(u8, segment, "input")) {
            const num_str = segment["input".len..];
            if (num_str.len > 0) {
                return std.fmt.parseInt(u8, num_str, 10) catch null;
            }
        }
        if (slash) |s| {
            remaining = remaining[0..s];
        } else break;
    }
    return null;
}

// --- tests ---

test "parseInterfaceId basic" {
    try std.testing.expectEqual(@as(?u8, 1), parseInterfaceId("usb-0000:00:14.0-1.2/input1"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("usb-0000:00:14.0-1/input0"));
    try std.testing.expectEqual(@as(?u8, 2), parseInterfaceId("input2"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb-0000:00:14.0-1"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId(""));
}

test "parseInterfaceId Vader5 format" {
    // Typical USB phys string: "usb-xhci_hcd.0.auto-1/input1"
    try std.testing.expectEqual(@as(?u8, 1), parseInterfaceId("usb-xhci_hcd.0.auto-1/input1"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("usb-xhci_hcd.0.auto-1/input0"));
}

test "discoverAllWithRoot: nonexistent dev_root returns empty" {
    const allocator = std.testing.allocator;
    const paths: [][]const u8 = try HidrawDevice.discoverAllWithRoot(allocator, 0x1234, 0x5678, "/nonexistent_hidraw_root_xyz");
    defer {
        for (paths) |p| allocator.free(p);
        allocator.free(paths);
    }
    try std.testing.expectEqual(@as(usize, 0), paths.len);
}

test "parseInterfaceId: deep multi-segment path" {
    try std.testing.expectEqual(@as(?u8, 3), parseInterfaceId("usb-0000:00:14.0-2.4/input3"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("platform/soc/usb/input0"));
}

test "parseInterfaceId: bare 'input' without number returns null" {
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb/input"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("input"));
}

test "parseInterfaceId: finds last 'inputN' even when trailing segment is non-input" {
    // "event0" is not an input* segment; walk finds "input5" → 5
    try std.testing.expectEqual(@as(?u8, 5), parseInterfaceId("usb/input5/event0"));
    // no inputN anywhere → null
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb/event0/dev"));
}

test "grabAssociatedEvdev sysfs path parsing" {
    // Build a temp sysfs-like tree and verify grab logic finds eventK entries.
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Create: <tmp>/class/hidraw/hidraw2/device/input/input5/event3
    try tmp.dir.makePath("class/hidraw/hidraw2/device/input/input5/event3");

    var dev = HidrawDevice.init(allocator);

    // grabAssociatedEvdevWithRoot should traverse without crashing even if
    // opening /dev/input/event3 fails (no real device).
    const hidraw_path = "/dev/hidraw2";
    const sys_root = tmp_path;
    // input_dev_root points somewhere that doesn't exist → open will fail → skipped gracefully
    dev.grabAssociatedEvdevWithRoot(hidraw_path, sys_root, "/nonexistent") catch {};
    // No evdev_fds grabbed (open failed), but no crash.
    try std.testing.expectEqual(@as(usize, 0), dev.evdev_fds.len);
}
