const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");
const udev = @import("install/udev.zig");
const scan = @import("scan.zig");
const paths = @import("../config/paths.zig");

pub const StatusDevice = struct {
    name: []const u8,
    state: []const u8,
    vid: u16,
    pid: u16,
    output_kind: []const u8,
    output_fd_alive: bool,

    pub fn deinit(self: StatusDevice, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.state);
        allocator.free(self.output_kind);
    }
};

pub const UsbInterface = struct {
    iface: []const u8,
    driver: ?[]const u8,

    pub fn deinit(self: UsbInterface, allocator: std.mem.Allocator) void {
        allocator.free(self.iface);
        if (self.driver) |d| allocator.free(d);
    }
};

pub const UsbPresence = struct {
    present: bool,
    bus_id: []const u8,
    interfaces: []UsbInterface,

    pub fn deinit(self: UsbPresence, allocator: std.mem.Allocator) void {
        allocator.free(self.bus_id);
        for (self.interfaces) |iface| iface.deinit(allocator);
        allocator.free(self.interfaces);
    }
};

/// Walk <sys_root>/sys/bus/usb/devices/ read-only, find a device matching vid:pid,
/// and enumerate its interface children with their bound drivers (if any).
/// sys_root is "" in production; tests inject a tmpDir path.
pub fn probeUsbPresence(allocator: std.mem.Allocator, vid: u16, pid: u16, sys_root: []const u8) !UsbPresence {
    const devices_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices", .{sys_root});
    defer allocator.free(devices_path);

    var devices_dir = std.fs.openDirAbsolute(devices_path, .{ .iterate = true }) catch {
        return UsbPresence{ .present = false, .bus_id = try allocator.dupe(u8, ""), .interfaces = &.{} };
    };
    defer devices_dir.close();

    var it = devices_dir.iterate();
    while (it.next() catch null) |de| {
        if (de.kind != .sym_link and de.kind != .directory) continue;
        if (de.name.len == 0 or de.name[0] < '0' or de.name[0] > '9') continue;
        if (std.mem.indexOfScalar(u8, de.name, ':') != null) continue;

        const vendor_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices/{s}/idVendor", .{ sys_root, de.name });
        defer allocator.free(vendor_path);
        const product_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices/{s}/idProduct", .{ sys_root, de.name });
        defer allocator.free(product_path);

        const dv = udev.readSysHex(vendor_path) catch continue;
        const dp = udev.readSysHex(product_path) catch continue;
        if (dv != vid or dp != pid) continue;

        const bus_id = try allocator.dupe(u8, de.name);
        errdefer allocator.free(bus_id);

        const dev_dir_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices/{s}", .{ sys_root, de.name });
        defer allocator.free(dev_dir_path);

        var dev_dir = std.fs.openDirAbsolute(dev_dir_path, .{ .iterate = true }) catch {
            return UsbPresence{ .present = true, .bus_id = bus_id, .interfaces = &.{} };
        };
        defer dev_dir.close();

        var ifaces: std.ArrayList(UsbInterface) = .{};
        errdefer {
            for (ifaces.items) |iface| iface.deinit(allocator);
            ifaces.deinit(allocator);
        }

        var dev_it = dev_dir.iterate();
        while (dev_it.next() catch null) |child| {
            if (child.kind != .directory and child.kind != .sym_link) continue;
            if (!std.mem.startsWith(u8, child.name, de.name)) continue;
            if (child.name.len <= de.name.len or child.name[de.name.len] != ':') continue;

            const iface_name = try allocator.dupe(u8, child.name);
            errdefer allocator.free(iface_name);

            const driver_link = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices/{s}/{s}/driver", .{ sys_root, de.name, child.name });
            defer allocator.free(driver_link);

            const driver: ?[]const u8 = blk: {
                var link_buf: [std.fs.max_path_bytes]u8 = undefined;
                const target = std.fs.readLinkAbsolute(driver_link, &link_buf) catch break :blk null;
                break :blk try allocator.dupe(u8, std.fs.path.basename(target));
            };
            errdefer if (driver) |d| allocator.free(d);

            try ifaces.append(allocator, .{ .iface = iface_name, .driver = driver });
        }

        return UsbPresence{
            .present = true,
            .bus_id = bus_id,
            .interfaces = try ifaces.toOwnedSlice(allocator),
        };
    }

    return UsbPresence{ .present = false, .bus_id = try allocator.dupe(u8, ""), .interfaces = &.{} };
}

/// Parse the STATUS wire line into a slice of StatusDevice.
/// Caller owns result; call freeStatusDevices when done.
pub fn parseStatusLine(line: []const u8, allocator: std.mem.Allocator) ![]StatusDevice {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, "STATUS")) return error.InvalidResponse;

    var devices: std.ArrayList(StatusDevice) = .{};
    errdefer {
        for (devices.items) |d| d.deinit(allocator);
        devices.deinit(allocator);
    }

    const rest = trimmed["STATUS".len..];
    if (rest.len == 0 or std.mem.trim(u8, rest, " \t\r\n").len == 0) {
        return devices.toOwnedSlice(allocator);
    }

    var chunks = std.mem.splitSequence(u8, rest, " device=");
    _ = chunks.next(); // skip leading empty or "STATUS" prefix
    while (chunks.next()) |chunk| {
        const name_end = std.mem.indexOfScalar(u8, chunk, ' ') orelse chunk.len;
        const name = try allocator.dupe(u8, chunk[0..name_end]);
        errdefer allocator.free(name);

        const state = try extractField(allocator, chunk, "state=");
        errdefer allocator.free(state);
        const output_kind = try extractField(allocator, chunk, "output_kind=");
        errdefer allocator.free(output_kind);
        const vid = parseHexField(chunk, "vid=0x") orelse 0;
        const pid = parseHexField(chunk, "pid=0x") orelse 0;
        const output_fd_alive = std.mem.indexOf(u8, chunk, "output_fd_alive=true") != null;

        try devices.append(allocator, .{
            .name = name,
            .state = state,
            .vid = vid,
            .pid = pid,
            .output_kind = output_kind,
            .output_fd_alive = output_fd_alive,
        });
    }

    return devices.toOwnedSlice(allocator);
}

fn extractField(allocator: std.mem.Allocator, chunk: []const u8, key: []const u8) ![]const u8 {
    const start_pos = std.mem.indexOf(u8, chunk, key) orelse return allocator.dupe(u8, "");
    const val_start = start_pos + key.len;
    const val_end = blk: {
        var i = val_start;
        while (i < chunk.len and chunk[i] != ' ' and chunk[i] != '\n' and chunk[i] != '\r') i += 1;
        break :blk i;
    };
    return allocator.dupe(u8, chunk[val_start..val_end]);
}

fn parseHexField(chunk: []const u8, key: []const u8) ?u16 {
    const pos = std.mem.indexOf(u8, chunk, key) orelse return null;
    const val_start = pos + key.len;
    var end = val_start;
    while (end < chunk.len and std.ascii.isHex(chunk[end])) end += 1;
    if (end == val_start) return null;
    return std.fmt.parseInt(u16, chunk[val_start..end], 16) catch null;
}

pub fn freeStatusDevices(allocator: std.mem.Allocator, devices: []StatusDevice) void {
    for (devices) |d| d.deinit(allocator);
    allocator.free(devices);
}

pub fn run(allocator: std.mem.Allocator, socket_path: []const u8, writer: anytype, _: anytype) u8 {
    runInner(allocator, socket_path, writer) catch |err| {
        writer.print("doctor: fatal error: {}\n", .{err}) catch {};
        return 1;
    };
    return 0;
}

fn runInner(allocator: std.mem.Allocator, socket_path: []const u8, writer: anytype) !void {
    try writer.writeAll("[service]\n");

    var sock_buf: [std.fs.max_path_bytes]u8 = undefined;
    const resolved = socket_client.resolveSocketPath(&sock_buf);
    try writer.print("socket: {s}\n", .{resolved});

    const scope = if (std.mem.indexOf(u8, resolved, "/run/user/") != null)
        "user scope"
    else if (std.mem.indexOf(u8, resolved, "/run/padctl/") != null)
        "system scope"
    else
        "unknown scope";
    try writer.print("scope: {s}\n", .{scope});

    var status_devices: []StatusDevice = &.{};
    defer freeStatusDevices(allocator, status_devices);

    const connect_fd = socket_client.connectToSocket(socket_path) catch |err| switch (err) {
        error.FileNotFound, error.ConnectionRefused => {
            try writer.writeAll("daemon: DOWN (no socket / not running)\n");
            try printSentinel(writer);
            try writer.writeByte('\n');
            try printSupportedDevices(allocator, status_devices, writer);
            return;
        },
        else => {
            try writer.print("daemon: DOWN (connect error: {})\n", .{err});
            try printSentinel(writer);
            try writer.writeByte('\n');
            try printSupportedDevices(allocator, status_devices, writer);
            return;
        },
    };
    defer posix.close(connect_fd);

    var resp_buf: [4096]u8 = undefined;
    const resp = socket_client.sendCommand(connect_fd, "STATUS\n", &resp_buf) catch {
        try writer.writeAll("daemon: UP (no status response)\n");
        try printSentinel(writer);
        try writer.writeByte('\n');
        try printSupportedDevices(allocator, status_devices, writer);
        return;
    };

    status_devices = parseStatusLine(resp, allocator) catch &.{};
    try writer.print("daemon: up, {d} managed device(s)\n", .{status_devices.len});
    for (status_devices) |d| {
        try writer.print("  device={s} state={s} vid=0x{x:0>4} pid=0x{x:0>4} output_kind={s} output_fd_alive={}\n", .{
            d.name, d.state, d.vid, d.pid, d.output_kind, d.output_fd_alive,
        });
    }

    try printSentinel(writer);
    try writer.writeByte('\n');
    try printSupportedDevices(allocator, status_devices, writer);
}

fn printSentinel(writer: anytype) !void {
    std.fs.accessAbsolute(udev.runtime_sentinel_path, .{}) catch {
        try writer.print("sentinel: ABSENT ({s}) — driver-block rules fail-safe disabled\n", .{udev.runtime_sentinel_path});
        return;
    };
    try writer.print("sentinel: present ({s})\n", .{udev.runtime_sentinel_path});
}

fn printSupportedDevices(allocator: std.mem.Allocator, status_devices: []const StatusDevice, writer: anytype) !void {
    try writer.writeAll("[supported devices]\n");

    var entries = udev.collectDeviceEntriesForUninstall(allocator, "/usr/share/padctl/devices") catch {
        try writer.writeAll("note: could not load device list from /usr/share/padctl/devices\n");
        return;
    };
    defer udev.freeDeviceEntries(allocator, &entries);

    const config_dirs = paths.resolveDeviceConfigDirs(allocator) catch null;
    defer if (config_dirs) |dirs| paths.freeConfigDirs(allocator, dirs);
    const scan_dir = if (config_dirs) |dirs| dirs[0] else "/usr/share/padctl/devices";

    const scan_entries = scan.scan(allocator, scan_dir) catch null;
    defer if (scan_entries) |se| scan.freeEntries(allocator, se);

    for (entries.items) |entry| {
        try writer.print("{s} (0x{x:0>4}:0x{x:0>4})\n", .{ entry.name, entry.vid, entry.pid });

        const presence = probeUsbPresence(allocator, entry.vid, entry.pid, "") catch null;
        defer if (presence) |p| p.deinit(allocator);

        if (presence) |p| {
            if (p.present) {
                try writer.print("  usb: present ({s})\n", .{p.bus_id});
                for (p.interfaces) |iface| {
                    if (iface.driver) |d| {
                        try writer.print("    iface {s} -> {s}\n", .{ iface.iface, d });
                    } else {
                        try writer.print("    iface {s} -> (none)\n", .{iface.iface});
                    }
                }
            } else {
                try writer.writeAll("  usb: not present\n");
            }
        } else {
            try writer.writeAll("  usb: (sysfs unavailable)\n");
        }

        const hidraw_path: ?[]const u8 = blk: {
            if (scan_entries) |se| {
                for (se) |se_entry| {
                    if (se_entry.vid == entry.vid and se_entry.pid == entry.pid) {
                        break :blk se_entry.path;
                    }
                }
            }
            break :blk null;
        };
        if (hidraw_path) |p| {
            try writer.print("  hidraw: {s}\n", .{p});
        } else {
            try writer.writeAll("  hidraw: none\n");
        }

        const claimed = blk: {
            for (status_devices) |sd| {
                if (sd.vid == entry.vid and sd.pid == entry.pid) break :blk true;
            }
            break :blk false;
        };
        try writer.print("  padctl: {s}\n", .{if (claimed) "CLAIMED" else "not claimed"});

        if (presence) |p| {
            if (!p.present) {
                try writer.writeAll("  verdict: device not detected on USB\n");
            } else if (claimed) {
                try writer.writeAll("  verdict: OK — managed by padctl\n");
            } else {
                var any_driver: ?[]const u8 = null;
                for (p.interfaces) |iface| {
                    if (iface.driver != null) {
                        any_driver = iface.driver;
                        break;
                    }
                }
                if (any_driver != null and hidraw_path == null) {
                    try writer.print("  verdict: device present but shadowed by '{s}' and no hidraw node\n", .{any_driver.?});
                } else if (hidraw_path == null) {
                    try writer.writeAll("  verdict: USB present but no hidraw node — check udev rules or group membership\n");
                } else {
                    try writer.writeAll("  verdict: hidraw present but not claimed — daemon down or device not in active mapping\n");
                }
            }
        }

        try writer.writeByte('\n');
    }
}

// --- tests ---

const testing = std.testing;

test "doctor: parseStatusLine: bare STATUS returns empty" {
    const devices = try parseStatusLine("STATUS\n", testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 0), devices.len);
}

test "doctor: parseStatusLine: bare STATUS no newline" {
    const devices = try parseStatusLine("STATUS", testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 0), devices.len);
}

test "doctor: parseStatusLine: one device" {
    const line = "STATUS device=vader5 state=active mapping=default phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true evdev_node=/dev/input/event5 hotplug_pending=0 last_inbound_ms_ago=12 last_outbound_ms_ago=8 write_in_flight_ms=0\n";
    const devices = try parseStatusLine(line, testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 1), devices.len);
    try testing.expectEqualStrings("vader5", devices[0].name);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
    try testing.expectEqual(@as(u16, 0x2401), devices[0].pid);
    try testing.expectEqualStrings("active", devices[0].state);
    try testing.expectEqualStrings("uhid", devices[0].output_kind);
    try testing.expect(devices[0].output_fd_alive);
}

test "doctor: parseStatusLine: two devices" {
    const line = "STATUS device=vader5 state=active mapping=fps vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true evdev_node=/dev/input/event5 hotplug_pending=0 last_inbound_ms_ago=1 last_outbound_ms_ago=1 write_in_flight_ms=0 device=wheel state=suspended mapping=racing vid=0x044f pid=0xb67f output_kind=uinput output_fd_alive=false evdev_node=/dev/input/event6 hotplug_pending=0 last_inbound_ms_ago=100 last_outbound_ms_ago=100 write_in_flight_ms=0\n";
    const devices = try parseStatusLine(line, testing.allocator);
    defer freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 2), devices.len);
    try testing.expectEqualStrings("vader5", devices[0].name);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
    try testing.expectEqualStrings("wheel", devices[1].name);
    try testing.expectEqual(@as(u16, 0x044f), devices[1].vid);
    try testing.expectEqual(@as(u16, 0xb67f), devices[1].pid);
    try testing.expectEqualStrings("suspended", devices[1].state);
    try testing.expect(!devices[1].output_fd_alive);
}

test "doctor: probeUsbPresence: device present with driver" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("sys/bus/usb/devices/1-2");
    try tmp.dir.makePath("sys/bus/usb/devices/1-2/1-2:1.0");

    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idVendor", .{});
        defer f.close();
        try f.writeAll("37d7\n");
    }
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idProduct", .{});
        defer f.close();
        try f.writeAll("2401\n");
    }

    const driver_link = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/devices/1-2/1-2:1.0/driver", .{tmp_path});
    defer allocator.free(driver_link);
    try std.posix.symlink("../../../../drivers/xpad", driver_link);

    const result = try probeUsbPresence(allocator, 0x37d7, 0x2401, tmp_path);
    defer result.deinit(allocator);

    try testing.expect(result.present);
    try testing.expectEqualStrings("1-2", result.bus_id);
    try testing.expectEqual(@as(usize, 1), result.interfaces.len);
    try testing.expectEqualStrings("1-2:1.0", result.interfaces[0].iface);
    try testing.expectEqualStrings("xpad", result.interfaces[0].driver.?);
}

test "doctor: probeUsbPresence: driverless interface" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("sys/bus/usb/devices/1-2/1-2:1.0");
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idVendor", .{});
        defer f.close();
        try f.writeAll("37d7\n");
    }
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idProduct", .{});
        defer f.close();
        try f.writeAll("2401\n");
    }

    const result = try probeUsbPresence(allocator, 0x37d7, 0x2401, tmp_path);
    defer result.deinit(allocator);

    try testing.expect(result.present);
    try testing.expectEqual(@as(usize, 1), result.interfaces.len);
    try testing.expect(result.interfaces[0].driver == null);
}

test "doctor: probeUsbPresence: not present (different vid)" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("sys/bus/usb/devices/1-2");
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idVendor", .{});
        defer f.close();
        try f.writeAll("0000\n");
    }
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-2/idProduct", .{});
        defer f.close();
        try f.writeAll("0000\n");
    }

    const result = try probeUsbPresence(allocator, 0x37d7, 0x2401, tmp_path);
    defer result.deinit(allocator);

    try testing.expect(!result.present);
}
