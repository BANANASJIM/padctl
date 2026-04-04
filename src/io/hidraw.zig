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
        var phys_buf: [1024]u8 = undefined;
        const phys = readPhysFromSysfs(hidraw_path, &phys_buf, sys_root) orelse return;
        const usb_prefix = stripInputSuffix(phys);
        if (usb_prefix.len == 0 or std.mem.eql(u8, usb_prefix, phys)) return;

        var path_buf: [256]u8 = undefined;
        const input_class_dir = try std.fmt.bufPrint(
            &path_buf,
            "{s}/class/input",
            .{sys_root},
        );

        var input_dir = std.fs.openDirAbsolute(input_class_dir, .{ .iterate = true }) catch return;
        defer input_dir.close();

        var it = input_dir.iterate();
        while (try it.next()) |entry| {
            if (!std.mem.startsWith(u8, entry.name, "event")) continue;

            var ev_phys_path_buf: [320]u8 = undefined;
            const ev_phys_path = std.fmt.bufPrint(
                &ev_phys_path_buf,
                "{s}/class/input/{s}/device/phys",
                .{ sys_root, entry.name },
            ) catch continue;

            var ev_phys_buf: [256]u8 = undefined;
            const ev_phys = readSysfsFile(ev_phys_path, &ev_phys_buf) orelse continue;

            if (!physMatchesPrefix(ev_phys, usb_prefix)) continue;

            var dev_path_buf: [128]u8 = undefined;
            const dev_path = std.fmt.bufPrint(
                &dev_path_buf,
                "{s}/{s}",
                .{ input_dev_root, entry.name },
            ) catch continue;

            const evfd = posix.open(dev_path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch |err| {
                std.log.warn("evdev grab: open {s} failed: {}", .{ dev_path, err });
                continue;
            };
            const grab_rc = linux.ioctl(evfd, ioctl.EVIOCGRAB, 1);
            const grab_errno = posix.errno(grab_rc);
            if (grab_errno != .SUCCESS) {
                std.log.warn("evdev grab: EVIOCGRAB {s} failed: {s}", .{ dev_path, @tagName(grab_errno) });
                posix.close(evfd);
                continue;
            }
            self.evdev_fds.append(evfd) catch {
                posix.close(evfd);
            };
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
    var buf: [1024]u8 = undefined;
    const phys = readPhysFromSysfs(path, &buf, "/sys") orelse return allocator.dupe(u8, path);
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
    return readInterfaceIdFromSysfs(basename_s);
}

fn readInterfaceIdFromSysfs(basename_s: []const u8) ?u8 {
    var pb: [256]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "/sys/class/hidraw/{s}/device/..", .{basename_s}) catch return null;
    var dir = std.fs.openDirAbsolute(p, .{}) catch return null;
    defer dir.close();
    const f = dir.openFile("bInterfaceNumber", .{}) catch return null;
    defer f.close();
    var b: [8]u8 = undefined;
    const n = f.read(&b) catch return null;
    const trimmed = std.mem.trim(u8, b[0..n], " \t\n\r");
    return std.fmt.parseInt(u8, trimmed, 16) catch null;
}

/// Returns true if ev_phys starts with prefix and the next character is a separator or end.
fn physMatchesPrefix(ev_phys: []const u8, prefix: []const u8) bool {
    if (!std.mem.startsWith(u8, ev_phys, prefix)) return false;
    if (ev_phys.len == prefix.len) return true;
    const next = ev_phys[prefix.len];
    return next == '/' or next == ':' or next == '.' or next == '-';
}

/// Read a sysfs file and return its contents (trimmed of trailing whitespace).
/// Returned slice points into buf; caller must copy if needed.
fn readSysfsFile(path: []const u8, buf: []u8) ?[]const u8 {
    const fd = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer fd.close();
    const n = fd.read(buf) catch return null;
    if (n == 0) return null;
    return std.mem.trimRight(u8, buf[0..n], " \t\n\r");
}

/// Read HID_PHYS value from sysfs uevent file for a hidraw node.
/// Returned slice points into an internal read buffer; caller must copy if needed.
fn readPhysFromSysfs(path: []const u8, buf: *[1024]u8, sys_root: []const u8) ?[]const u8 {
    const basename = std.fs.path.basename(path);
    var path_buf: [256]u8 = undefined;
    const sysfs_path = std.fmt.bufPrint(&path_buf, "{s}/class/hidraw/{s}/device/uevent", .{ sys_root, basename }) catch return null;
    const fd = std.fs.openFileAbsolute(sysfs_path, .{}) catch return null;
    defer fd.close();
    const n = fd.read(buf) catch return null;
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

test "hidraw: parseInterfaceId basic" {
    try std.testing.expectEqual(@as(?u8, 1), parseInterfaceId("usb-0000:00:14.0-1.2/input1"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("usb-0000:00:14.0-1/input0"));
    try std.testing.expectEqual(@as(?u8, 2), parseInterfaceId("input2"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb-0000:00:14.0-1"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId(""));
}

test "hidraw: parseInterfaceId Vader5 format" {
    // Typical USB phys string: "usb-xhci_hcd.0.auto-1/input1"
    try std.testing.expectEqual(@as(?u8, 1), parseInterfaceId("usb-xhci_hcd.0.auto-1/input1"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("usb-xhci_hcd.0.auto-1/input0"));
}

test "hidraw: discoverAllWithRoot: nonexistent dev_root returns empty" {
    const allocator = std.testing.allocator;
    const paths: [][]const u8 = try HidrawDevice.discoverAllWithRoot(allocator, 0x1234, 0x5678, "/nonexistent_hidraw_root_xyz");
    defer {
        for (paths) |p| allocator.free(p);
        allocator.free(paths);
    }
    try std.testing.expectEqual(@as(usize, 0), paths.len);
}

test "hidraw: parseInterfaceId: deep multi-segment path" {
    try std.testing.expectEqual(@as(?u8, 3), parseInterfaceId("usb-0000:00:14.0-2.4/input3"));
    try std.testing.expectEqual(@as(?u8, 0), parseInterfaceId("platform/soc/usb/input0"));
}

test "hidraw: parseInterfaceId: bare 'input' without number returns null" {
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb/input"));
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("input"));
}

test "hidraw: parseInterfaceId: finds last 'inputN' even when trailing segment is non-input" {
    // "event0" is not an input* segment; walk finds "input5" → 5
    try std.testing.expectEqual(@as(?u8, 5), parseInterfaceId("usb/input5/event0"));
    // no inputN anywhere → null
    try std.testing.expectEqual(@as(?u8, null), parseInterfaceId("usb/event0/dev"));
}

test "hidraw: grabAssociatedEvdev: no crash when phys missing or no matching events" {
    // grabAssociatedEvdevWithRoot returns early when hidraw uevent has no HID_PHYS.
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Minimal sysfs tree without a uevent file → readPhysFromSysfs returns null → early return.
    try tmp.dir.makePath("class/hidraw/hidraw2/device");
    try tmp.dir.makePath("class/input");

    var dev = HidrawDevice.init(allocator);
    dev.grabAssociatedEvdevWithRoot("/dev/hidraw2", tmp_path, "/nonexistent") catch {};
    try std.testing.expectEqual(@as(usize, 0), dev.evdev_fds.len);
}

test "hidraw: physMatchesPrefix: exact, suffix, and boundary" {
    // Exact match
    try std.testing.expect(physMatchesPrefix("usb-0000:00:14.0-4", "usb-0000:00:14.0-4"));
    // Valid separator chars after prefix
    try std.testing.expect(physMatchesPrefix("usb-0000:00:14.0-4/input0", "usb-0000:00:14.0-4"));
    try std.testing.expect(physMatchesPrefix("usb-0000:00:14.0-4:something", "usb-0000:00:14.0-4"));
    try std.testing.expect(physMatchesPrefix("usb-0000:00:14.0-4.1", "usb-0000:00:14.0-4"));
    try std.testing.expect(physMatchesPrefix("usb-0000:00:14.0-4-extra", "usb-0000:00:14.0-4"));
    // Port -40 must NOT match prefix -4
    try std.testing.expect(!physMatchesPrefix("usb-0000:00:14.0-40/input0", "usb-0000:00:14.0-4"));
    // Different device
    try std.testing.expect(!physMatchesPrefix("usb-0000:00:14.0-7/input0", "usb-0000:00:14.0-4"));
    // Empty
    try std.testing.expect(!physMatchesPrefix("", "usb-0000:00:14.0-4"));
}

test "hidraw: grabAssociatedEvdev: matches event by phys prefix" {
    // Build a temp sysfs-like tree with a matching and a non-matching event device.
    // Create real event device files so the traversal path can be validated.
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // hidraw uevent with HID_PHYS pointing to usb-0000:00:14.0-4/input1
    try tmp.dir.makePath("class/hidraw/hidraw3/device");
    const uevent_content = "HID_ID=0003:00001234:00005678\nHID_PHYS=usb-0000:00:14.0-4/input1\n";
    try tmp.dir.writeFile(.{
        .sub_path = "class/hidraw/hidraw3/device/uevent",
        .data = uevent_content,
    });

    // Matching event: phys starts with "usb-0000:00:14.0-4" followed by /
    try tmp.dir.makePath("class/input/event7/device");
    try tmp.dir.writeFile(.{
        .sub_path = "class/input/event7/device/phys",
        .data = "usb-0000:00:14.0-4/input0\n",
    });

    // Non-matching event: different USB port
    try tmp.dir.makePath("class/input/event9/device");
    try tmp.dir.writeFile(.{
        .sub_path = "class/input/event9/device/phys",
        .data = "usb-0000:00:14.0-7/input0\n",
    });

    // Port -40 must NOT match prefix -4 (boundary check)
    try tmp.dir.makePath("class/input/event11/device");
    try tmp.dir.writeFile(.{
        .sub_path = "class/input/event11/device/phys",
        .data = "usb-0000:00:14.0-40/input0\n",
    });

    // Create real event files in a temp input dir so open can succeed.
    try tmp.dir.makePath("input");
    try tmp.dir.writeFile(.{ .sub_path = "input/event7", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "input/event9", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "input/event11", .data = "" });

    const input_dev_root = try std.fmt.allocPrint(allocator, "{s}/input", .{tmp_path});
    defer allocator.free(input_dev_root);

    var dev = HidrawDevice.init(allocator);
    // Only event7 matches the phys prefix; event9 and event11 are excluded.
    dev.grabAssociatedEvdevWithRoot("/dev/hidraw3", tmp_path, input_dev_root) catch {};
    // On regular files with O_RDWR, EVIOCGRAB returns 0 (harmless no-op),
    // so exactly the 1 matching event (event7) is grabbed.
    try std.testing.expectEqual(@as(usize, 1), dev.evdev_fds.len);
    for (dev.evdev_fds.constSlice()) |fd| posix.close(fd);
    dev.evdev_fds.len = 0;
}
