const std = @import("std");
const posix = std.posix;
const socket_client = @import("socket_client.zig");
const udev = @import("install/udev.zig");
const scan = @import("scan.zig");
const paths = @import("../config/paths.zig");

pub const StatusDevice = socket_client.StatusDevice;
pub const parseStatusLine = socket_client.parseStatusLine;
pub const freeStatusDevices = socket_client.freeStatusDevices;

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

pub fn run(allocator: std.mem.Allocator, socket_path: []const u8, writer: anytype, _: anytype) u8 {
    runInner(allocator, socket_path, writer) catch |err| {
        writer.print("doctor: fatal error: {}\n", .{err}) catch {};
        return 1;
    };
    return 0;
}

fn runInner(allocator: std.mem.Allocator, socket_path: []const u8, writer: anytype) !void {
    try writer.writeAll("[service]\n");

    const exec_start = queryServiceExecStart(allocator);
    defer if (exec_start) |es| allocator.free(es);

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
            try printServiceHints(allocator, writer);
            try printDriverBlock(writer);
            try writer.writeByte('\n');
            try printSupportedDevices(allocator, status_devices, exec_start, writer);
            return;
        },
        else => {
            try writer.print("daemon: DOWN (connect error: {})\n", .{err});
            try printServiceHints(allocator, writer);
            try printDriverBlock(writer);
            try writer.writeByte('\n');
            try printSupportedDevices(allocator, status_devices, exec_start, writer);
            return;
        },
    };
    defer posix.close(connect_fd);

    var resp_buf: [4096]u8 = undefined;
    const resp = socket_client.sendCommand(connect_fd, "STATUS\n", &resp_buf) catch {
        try writer.writeAll("daemon: UP (no status response)\n");
        try printDriverBlock(writer);
        try writer.writeByte('\n');
        try printSupportedDevices(allocator, status_devices, exec_start, writer);
        return;
    };

    status_devices = parseStatusLine(resp, allocator) catch &.{};
    try writer.print("daemon: up, {d} managed device(s)\n", .{status_devices.len});
    for (status_devices) |d| {
        try writer.print("  device={s} state={s} vid=0x{x:0>4} pid=0x{x:0>4} output_kind={s} output_fd_alive={}\n", .{
            d.name, d.state, d.vid, d.pid, d.output_kind, d.output_fd_alive,
        });
    }

    try printDriverBlock(writer);
    try writer.writeByte('\n');
    try printSupportedDevices(allocator, status_devices, exec_start, writer);
}

pub const ServiceState = struct {
    load_state: []const u8 = "",
    active_state: []const u8 = "",
    sub_state: []const u8 = "",
    exec_main_status: []const u8 = "",
};

/// Parse `systemctl show <unit> -p LoadState,ActiveState,SubState,ExecMainStatus`
/// key=value output. Returned slices alias `output`.
pub fn parseServiceShow(output: []const u8) ServiceState {
    var st: ServiceState = .{};
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (std.mem.startsWith(u8, line, "LoadState=")) {
            st.load_state = line["LoadState=".len..];
        } else if (std.mem.startsWith(u8, line, "ActiveState=")) {
            st.active_state = line["ActiveState=".len..];
        } else if (std.mem.startsWith(u8, line, "SubState=")) {
            st.sub_state = line["SubState=".len..];
        } else if (std.mem.startsWith(u8, line, "ExecMainStatus=")) {
            st.exec_main_status = line["ExecMainStatus=".len..];
        }
    }
    return st;
}

/// Print the service line plus a next-step hint tailored to the unit state.
pub fn printServiceDiagnosis(writer: anytype, st: ServiceState, user_scope: bool) !void {
    const scope: []const u8 = if (user_scope) "user" else "system";
    if (std.mem.eql(u8, st.load_state, "not-found")) {
        try writer.writeAll("service: padctl.service not installed\n");
        try writer.writeAll("hint: run: sudo padctl install\n");
    } else if (std.mem.eql(u8, st.active_state, "failed")) {
        try writer.print("service: {s} scope failed (sub={s} exec_status={s})\n", .{ scope, st.sub_state, st.exec_main_status });
        if (user_scope) {
            try writer.writeAll("hint: inspect: journalctl --user -u padctl.service -n 80 — see the troubleshooting guide\n");
        } else {
            try writer.writeAll("hint: inspect: journalctl -u padctl.service -n 80 — see the troubleshooting guide\n");
        }
    } else if (std.mem.eql(u8, st.active_state, "inactive")) {
        try writer.print("service: {s} scope inactive\n", .{scope});
        if (user_scope) {
            try writer.writeAll("hint: start it: systemctl --user enable --now padctl.service\n");
        } else {
            try writer.writeAll("hint: start it: sudo systemctl enable --now padctl.service\n");
        }
    } else {
        try writer.print("service: {s} scope {s}/{s}\n", .{ scope, st.active_state, st.sub_state });
    }
}

const ScopedServiceState = struct {
    raw: []u8,
    state: ServiceState,
    user_scope: bool,
};

fn runSystemctlShow(allocator: std.mem.Allocator, user_scope: bool) ?[]u8 {
    const argv_user = [_][]const u8{ "systemctl", "--user", "show", "padctl.service", "-p", "LoadState,ActiveState,SubState,ExecMainStatus" };
    const argv_system = [_][]const u8{ "systemctl", "show", "padctl.service", "-p", "LoadState,ActiveState,SubState,ExecMainStatus" };
    const argv: []const []const u8 = if (user_scope) &argv_user else &argv_system;
    const result = std.process.Child.run(.{ .allocator = allocator, .argv = argv }) catch return null;
    defer allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }
    return result.stdout;
}

/// Query padctl.service state in user scope first, falling back to system
/// scope when the user unit does not exist. Null when systemctl is unusable.
fn queryServiceState(allocator: std.mem.Allocator) ?ScopedServiceState {
    const user_raw = runSystemctlShow(allocator, true) orelse {
        const sys_raw = runSystemctlShow(allocator, false) orelse return null;
        return .{ .raw = sys_raw, .state = parseServiceShow(sys_raw), .user_scope = false };
    };
    const user_state = parseServiceShow(user_raw);
    if (!std.mem.eql(u8, user_state.load_state, "not-found")) {
        return .{ .raw = user_raw, .state = user_state, .user_scope = true };
    }
    if (runSystemctlShow(allocator, false)) |sys_raw| {
        const sys_state = parseServiceShow(sys_raw);
        if (!std.mem.eql(u8, sys_state.load_state, "not-found")) {
            allocator.free(user_raw);
            return .{ .raw = sys_raw, .state = sys_state, .user_scope = false };
        }
        allocator.free(sys_raw);
    }
    return .{ .raw = user_raw, .state = user_state, .user_scope = true };
}

fn printServiceHints(allocator: std.mem.Allocator, writer: anytype) !void {
    const q = queryServiceState(allocator) orelse return;
    defer allocator.free(q.raw);
    try printServiceDiagnosis(writer, q.state, q.user_scope);
}

// Mirrors the daemon_socket_guard glob in the generated driver-block rules.
fn daemonSocketPresent() bool {
    if (std.fs.accessAbsolute("/run/padctl/padctl.sock", .{})) |_| return true else |_| {}
    var dir = std.fs.openDirAbsolute("/run/user", .{ .iterate = true }) catch return false;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = std.fmt.bufPrint(&buf, "/run/user/{s}/padctl.sock", .{entry.name}) catch continue;
        if (std.fs.accessAbsolute(path, .{})) |_| return true else |_| {}
    }
    return false;
}

fn printDriverBlock(writer: anytype) !void {
    if (daemonSocketPresent()) {
        try writer.writeAll("driver-block: armed (daemon socket present)\n");
    } else {
        try writer.writeAll("driver-block: idle (no daemon socket — kernel drivers keep devices)\n");
    }
}

/// Extract the `--config-dir <path>` argument from a unit ExecStart line.
/// Returns null when the daemon runs with its default config dir (no flag).
pub fn configDirFromExecStart(exec_start: []const u8) ?[]const u8 {
    const flag = "--config-dir";
    const pos = std.mem.indexOf(u8, exec_start, flag) orelse return null;
    var rest = exec_start[pos + flag.len ..];
    rest = std.mem.trimLeft(u8, rest, " \t=");
    if (rest.len == 0) return null;
    var end: usize = 0;
    while (end < rest.len and rest[end] != ' ' and rest[end] != '\t' and rest[end] != '\n' and rest[end] != '\r') end += 1;
    if (end == 0) return null;
    return rest[0..end];
}

/// Resolve the directories doctor scans for supported-device TOMLs, in priority
/// order. The daemon's live `--config-dir` (parsed from its ExecStart, when the
/// install used a non-/usr prefix) is the source of truth, followed by the
/// common install prefixes and the user/system config dirs. `exec_start` is the
/// raw `systemctl show -p ExecStart` value (or null when unavailable).
/// Caller owns the returned slice and each element.
pub fn resolveDoctorDeviceDirs(allocator: std.mem.Allocator, exec_start: ?[]const u8) ![][]const u8 {
    var dirs: std.ArrayList([]const u8) = .{};
    errdefer {
        for (dirs.items) |d| allocator.free(d);
        dirs.deinit(allocator);
    }

    const append = struct {
        fn add(a: std.mem.Allocator, list: *std.ArrayList([]const u8), dir: []const u8) !void {
            for (list.items) |existing| {
                if (std.mem.eql(u8, existing, dir)) return;
            }
            const owned = try a.dupe(u8, dir);
            errdefer a.free(owned);
            try list.append(a, owned);
        }
    }.add;

    if (exec_start) |es| {
        if (configDirFromExecStart(es)) |cfg| try append(allocator, &dirs, cfg);
    }
    try append(allocator, &dirs, "/usr/local/share/padctl/devices");
    try append(allocator, &dirs, "/usr/share/padctl/devices");

    const config_dirs = paths.resolveDeviceConfigDirs(allocator) catch null;
    defer if (config_dirs) |cd| paths.freeConfigDirs(allocator, cd);
    if (config_dirs) |cd| {
        for (cd) |d| try append(allocator, &dirs, d);
    }

    return dirs.toOwnedSlice(allocator);
}

/// Query the live padctl.service ExecStart so doctor scans the same device dir
/// the daemon was launched with. Best-effort: returns null on any failure.
fn queryServiceExecStart(allocator: std.mem.Allocator) ?[]u8 {
    const argv = [_][]const u8{ "systemctl", "--user", "show", "-p", "ExecStart", "--value", "padctl.service" };
    const result = std.process.Child.run(.{ .allocator = allocator, .argv = &argv }) catch return null;
    defer allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }
    return result.stdout;
}

/// Pick the first directory in `dirs` that exists. A non-existent scan dir makes
/// scan.scan abort the whole scan with FileNotFound, blanking every hidraw node.
fn firstExistingDir(dirs: []const []const u8) []const u8 {
    for (dirs) |d| {
        std.fs.accessAbsolute(d, .{}) catch continue;
        return d;
    }
    return dirs[0];
}

fn printSupportedDevices(allocator: std.mem.Allocator, status_devices: []const StatusDevice, exec_start: ?[]const u8, writer: anytype) !void {
    try writer.writeAll("[supported devices]\n");

    const dirs = resolveDoctorDeviceDirs(allocator, exec_start) catch {
        try writer.writeAll("note: could not resolve device config directories\n");
        return;
    };
    defer paths.freeConfigDirs(allocator, dirs);

    var entries = udev.collectDeviceEntries(allocator, dirs) catch {
        try writer.writeAll("note: could not load device list\n");
        return;
    };
    defer udev.freeDeviceEntries(allocator, &entries);

    try writer.writeAll("scanned:");
    for (dirs) |d| try writer.print(" {s}", .{d});
    try writer.print("\nfound {d} device(s)\n", .{entries.items.len});
    if (entries.items.len == 0) {
        try writer.writeAll("hint: no device TOMLs found in the scanned directories above; on ostree/immutable distros padctl installs under /usr/local — verify the daemon's --config-dir matches\n");
        return;
    }

    const scan_dir = firstExistingDir(dirs);
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

test "doctor: parseServiceShow: canned systemctl show output" {
    const st = parseServiceShow(
        "LoadState=loaded\nActiveState=failed\nSubState=failed\nExecMainStatus=218\n",
    );
    try testing.expectEqualStrings("loaded", st.load_state);
    try testing.expectEqualStrings("failed", st.active_state);
    try testing.expectEqualStrings("failed", st.sub_state);
    try testing.expectEqualStrings("218", st.exec_main_status);
}

test "doctor: parseServiceShow: missing keys yield empty fields" {
    const st = parseServiceShow("LoadState=not-found\n");
    try testing.expectEqualStrings("not-found", st.load_state);
    try testing.expectEqualStrings("", st.active_state);
    try testing.expectEqualStrings("", st.sub_state);
    try testing.expectEqualStrings("", st.exec_main_status);
}

test "doctor: printServiceDiagnosis: not-found suggests install" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    const st = parseServiceShow("LoadState=not-found\nActiveState=inactive\nSubState=dead\nExecMainStatus=0\n");
    try printServiceDiagnosis(buf.writer(testing.allocator), st, true);
    try testing.expectEqualStrings(
        "service: padctl.service not installed\nhint: run: sudo padctl install\n",
        buf.items,
    );
}

test "doctor: printServiceDiagnosis: failed prints substate and journal pointer" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    const st = parseServiceShow("LoadState=loaded\nActiveState=failed\nSubState=failed\nExecMainStatus=218\n");
    try printServiceDiagnosis(buf.writer(testing.allocator), st, true);
    try testing.expectEqualStrings(
        "service: user scope failed (sub=failed exec_status=218)\n" ++
            "hint: inspect: journalctl --user -u padctl.service -n 80 — see the troubleshooting guide\n",
        buf.items,
    );
}

test "doctor: printServiceDiagnosis: inactive suggests enable --now" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    const st = parseServiceShow("LoadState=loaded\nActiveState=inactive\nSubState=dead\nExecMainStatus=0\n");
    try printServiceDiagnosis(buf.writer(testing.allocator), st, true);
    try testing.expectEqualStrings(
        "service: user scope inactive\nhint: start it: systemctl --user enable --now padctl.service\n",
        buf.items,
    );
}

test "doctor: printServiceDiagnosis: system scope uses sudo systemctl" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    const st = parseServiceShow("LoadState=loaded\nActiveState=inactive\nSubState=dead\nExecMainStatus=0\n");
    try printServiceDiagnosis(buf.writer(testing.allocator), st, false);
    try testing.expectEqualStrings(
        "service: system scope inactive\nhint: start it: sudo systemctl enable --now padctl.service\n",
        buf.items,
    );
}

test "doctor: printServiceDiagnosis: active state prints status without hint" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    const st = parseServiceShow("LoadState=loaded\nActiveState=activating\nSubState=auto-restart\nExecMainStatus=1\n");
    try printServiceDiagnosis(buf.writer(testing.allocator), st, true);
    try testing.expectEqualStrings("service: user scope activating/auto-restart\n", buf.items);
}

test "doctor: configDirFromExecStart: extracts --config-dir arg" {
    try testing.expectEqualStrings(
        "/usr/local/share/padctl/devices",
        configDirFromExecStart("/usr/local/bin/padctl --config-dir /usr/local/share/padctl/devices").?,
    );
}

test "doctor: configDirFromExecStart: null when flag absent" {
    try testing.expect(configDirFromExecStart("/usr/bin/padctl") == null);
}

test "doctor: resolveDoctorDeviceDirs: ExecStart config-dir is primary candidate" {
    const allocator = testing.allocator;
    const dirs = try resolveDoctorDeviceDirs(
        allocator,
        "/usr/local/bin/padctl --config-dir /usr/local/share/padctl/devices",
    );
    defer paths.freeConfigDirs(allocator, dirs);
    try testing.expectEqualStrings("/usr/local/share/padctl/devices", dirs[0]);
    // The hardcoded /usr/share must not be the only/primary search dir.
    try testing.expect(!std.mem.eql(u8, dirs[0], "/usr/share/padctl/devices"));
}

test "doctor: resolveDoctorDeviceDirs: ostree devices found outside /usr/share" {
    // Regression for #355: device TOMLs live ONLY under /usr/local (ostree
    // prefix). The old code scanned a hardcoded /usr/share and found nothing,
    // blanking the [supported devices] section. resolveDoctorDeviceDirs must
    // surface the ExecStart --config-dir so collectDeviceEntries finds them.
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("usr/local/share/padctl/devices");
    {
        var f = try tmp.dir.createFile("usr/local/share/padctl/devices/foo.toml", .{});
        defer f.close();
        try f.writeAll("[device]\nname = \"foo\"\nvid = 0x1234\npid = 0x5678\n");
    }

    const cfg_dir = try std.fmt.allocPrint(allocator, "{s}/usr/local/share/padctl/devices", .{tmp_path});
    defer allocator.free(cfg_dir);
    const exec_start = try std.fmt.allocPrint(allocator, "{s}/usr/local/bin/padctl --config-dir {s}", .{ tmp_path, cfg_dir });
    defer allocator.free(exec_start);

    const dirs = try resolveDoctorDeviceDirs(allocator, exec_start);
    defer paths.freeConfigDirs(allocator, dirs);
    try testing.expectEqualStrings(cfg_dir, dirs[0]);

    var entries = try udev.collectDeviceEntries(allocator, dirs);
    defer udev.freeDeviceEntries(allocator, &entries);
    try testing.expectEqual(@as(usize, 1), entries.items.len);
    try testing.expectEqual(@as(u16, 0x1234), entries.items[0].vid);
    try testing.expectEqual(@as(u16, 0x5678), entries.items[0].pid);

    // Falsifiability anchor: a parallel-prefix dir WITHOUT the fixture TOML
    // (mirroring the old hardcoded /usr/share) yields zero entries, i.e. the
    // section would have been blank under the old behavior.
    var tmp2 = testing.tmpDir(.{});
    defer tmp2.cleanup();
    const tmp2_path = try tmp2.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp2_path);
    try tmp2.dir.makePath("share/padctl/devices");
    const empty_dir = try std.fmt.allocPrint(allocator, "{s}/share/padctl/devices", .{tmp2_path});
    defer allocator.free(empty_dir);

    var old = try udev.collectDeviceEntries(allocator, &.{empty_dir});
    defer udev.freeDeviceEntries(allocator, &old);
    try testing.expectEqual(@as(usize, 0), old.items.len);
}

test "doctor: printSupportedDevices prints scanned paths and count when zero" {
    const allocator = testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);

    try printSupportedDevices(allocator, &.{}, null, buf.writer(allocator));
    const out = buf.items;

    // Must not be a blank section: header + observability lines are present.
    try testing.expect(std.mem.indexOf(u8, out, "[supported devices]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "scanned:") != null);
    try testing.expect(std.mem.indexOf(u8, out, "device(s)") != null);
}

test "doctor: printSupportedDevices finds device via ExecStart config-dir" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("devices");
    {
        var f = try tmp.dir.createFile("devices/foo.toml", .{});
        defer f.close();
        try f.writeAll("[device]\nname = \"foo\"\nvid = 0x1234\npid = 0x5678\n");
    }

    const dev_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(dev_dir);
    const exec_start = try std.fmt.allocPrint(allocator, "{s}/bin/padctl --config-dir {s}", .{ tmp_path, dev_dir });
    defer allocator.free(exec_start);

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    try printSupportedDevices(allocator, &.{}, exec_start, buf.writer(allocator));
    const out = buf.items;

    try testing.expect(std.mem.indexOf(u8, out, "found 1 device(s)") != null);
    try testing.expect(std.mem.indexOf(u8, out, dev_dir) != null);
    try testing.expect(std.mem.indexOf(u8, out, "0x1234:0x5678") != null);
}

test "doctor: firstExistingDir: skips leading non-existent dir" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.makePath("exists");
    const exists = try std.fmt.allocPrint(allocator, "{s}/exists", .{tmp_path});
    defer allocator.free(exists);

    const got = firstExistingDir(&.{ "/nonexistent/padctl/zzz", exists, "/another/missing" });
    try testing.expectEqualStrings(exists, got);
}

test "doctor: firstExistingDir: falls back to dirs[0] when none exist" {
    const got = firstExistingDir(&.{ "/nonexistent/a", "/nonexistent/b" });
    try testing.expectEqualStrings("/nonexistent/a", got);
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
