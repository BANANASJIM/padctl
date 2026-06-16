const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("../../io/ioctl_constants.zig");
const hidraw = @import("../../io/hidraw.zig");
const device_mod = @import("../../config/device.zig");
const mapping_mod = @import("../../config/mapping.zig");
const paths = @import("../../config/paths.zig");
const scan_mod = @import("../scan.zig");
const perm_hint = @import("../perm_hint.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const state_mod = @import("../../core/state.zig");

const NAME_BUF_LEN = 128;
const MAX_HIDRAW = 64;

// HIDIOCGRAWNAME(128)
const HIDIOCGRAWNAME: u32 = blk: {
    const req = linux.IOCTL.Request{
        .dir = 2,
        .io_type = 'H',
        .nr = 0x04,
        .size = NAME_BUF_LEN,
    };
    break :blk @as(u32, @bitCast(req));
};

const OpenedDevice = struct {
    fd: posix.fd_t,
    iface: ?u8,
};

fn openHidrawByVidPid(vid: u16, pid: u16, denied: *bool) !OpenedDevice {
    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch |err| {
            if (err == error.AccessDenied) denied.* = true;
            continue;
        };

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) {
            posix.close(fd);
            continue;
        }
        if (@as(u16, @bitCast(info.vendor)) == vid and @as(u16, @bitCast(info.product)) == pid)
            return .{ .fd = fd, .iface = hidraw.readInterfaceId(path) };
        posix.close(fd);
    }
    return error.NoMatchingDevice;
}

/// Open the first hidraw node whose VID/PID matches a device config in `dirs`
/// (same resolution the daemon uses); fall back to the first hidraw node.
/// On a config match, `out_config` receives the owned config path.
fn openAutoResolved(
    allocator: std.mem.Allocator,
    dirs: []const []const u8,
    out_config: *?[]const u8,
    denied: *bool,
) !OpenedDevice {
    var fallback: ?OpenedDevice = null;
    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch |err| {
            if (err == error.AccessDenied) denied.* = true;
            continue;
        };

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) {
            posix.close(fd);
            continue;
        }
        const vid: u16 = @bitCast(info.vendor);
        const pid: u16 = @bitCast(info.product);
        const iface = hidraw.readInterfaceId(path);
        for (dirs) |dir| {
            const matched = scan_mod.findConfig(allocator, dir, vid, pid, iface) catch continue;
            if (fallback) |f| posix.close(f.fd);
            out_config.* = matched;
            return .{ .fd = fd, .iface = iface };
        }
        if (fallback == null) {
            fallback = .{ .fd = fd, .iface = iface };
        } else {
            posix.close(fd);
        }
    }
    return fallback orelse error.NoHidrawDevice;
}

/// Pick the report interface id to decode with, or null when this device
/// cannot be decoded from a hidraw node (vendor/suppress class interface).
fn decodeInterface(cfg: *const device_mod.DeviceConfig, iface: ?u8) ?u8 {
    if (iface) |id| {
        for (cfg.device.interface) |ic| {
            if (ic.id == id)
                return if (std.mem.eql(u8, ic.class, "hid")) id else null;
        }
        return null;
    }
    var only_hid: ?u8 = null;
    for (cfg.device.interface) |ic| {
        if (std.mem.eql(u8, ic.class, "hid")) {
            if (only_hid != null) return null;
            only_hid = std.math.cast(u8, ic.id) orelse return null;
        }
    }
    return only_hid;
}

const Decoder = struct {
    interp: *const interpreter_mod.Interpreter,
    interface_id: u8,
    state: state_mod.GamepadState = .{},

    fn feed(self: *Decoder, w: anytype, raw: []const u8) !void {
        const delta = (self.interp.processReport(self.interface_id, raw) catch return) orelse {
            try formatReport(w, raw, null);
            return;
        };
        const prev = self.state;
        self.state.applyDelta(delta);
        try formatEvents(w, prev, self.state);
    }
};

fn formatEvents(w: anytype, prev: state_mod.GamepadState, curr: state_mod.GamepadState) !void {
    const changed = prev.buttons ^ curr.buttons;
    inline for (@typeInfo(state_mod.ButtonId).@"enum".fields) |f| {
        const bit = @as(u64, 1) << f.value;
        if (changed & bit != 0)
            try w.print("{s} {s}\n", .{ f.name, if (curr.buttons & bit != 0) "down" else "up" });
    }
    const axes = .{
        .{ "LX", "ax" },
        .{ "LY", "ay" },
        .{ "RX", "rx" },
        .{ "RY", "ry" },
        .{ "LT", "lt" },
        .{ "RT", "rt" },
        .{ "DPadX", "dpad_x" },
        .{ "DPadY", "dpad_y" },
    };
    inline for (axes) |a| {
        if (@field(prev, a[1]) != @field(curr, a[1]))
            try w.print("{s}={d}\n", .{ a[0], @field(curr, a[1]) });
    }
}

/// `mapping_arg` is a bare profile name (resolved through the XDG mapping dirs,
/// matching `padctl switch`) unless it contains a '/', in which case it is used
/// as a literal path. Caller frees the result when non-null.
fn resolveMappingPath(allocator: std.mem.Allocator, mapping_arg: []const u8) !?[]const u8 {
    if (std.mem.indexOfScalar(u8, mapping_arg, '/') != null)
        return try allocator.dupe(u8, mapping_arg);
    const dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dirs);
    return resolveMappingNameInDirs(allocator, mapping_arg, dirs);
}

/// Resolve a bare profile name to `<dir>/<name>.toml` across `dirs` in priority
/// order, the same lookup `padctl switch` uses. Caller frees when non-null.
fn resolveMappingNameInDirs(allocator: std.mem.Allocator, name: []const u8, dirs: []const []const u8) !?[]const u8 {
    const filename = try std.fmt.allocPrint(allocator, "{s}.toml", .{name});
    defer allocator.free(filename);
    return paths.findConfig(allocator, filename, dirs);
}

/// Report why no hidraw node could be opened. When every candidate node was
/// permission-denied, the user is not missing a device — they lack `input`
/// group access, so route to the shared remedy instead of "no device found".
fn reportNoDevice(writer: anytype, denied: bool) void {
    if (denied) {
        writer.writeAll("error: a hidraw node was permission-denied.\n") catch {};
        perm_hint.writeInputGroupHint(writer);
    } else {
        writer.writeAll("error: no hidraw device found.\n") catch {};
        writer.writeAll("hint: connect a supported controller, then run `padctl scan`.\n") catch {};
    }
}

pub fn run(
    allocator: std.mem.Allocator,
    config_path: ?[]const u8,
    mapping_arg: ?[]const u8,
    raw_mode: bool,
    writer: anytype,
) !void {
    const mapping_path: ?[]const u8 = if (mapping_arg) |ma|
        resolveMappingPath(allocator, ma) catch null
    else
        null;
    defer if (mapping_path) |p| allocator.free(p);
    if (mapping_arg != null and mapping_path == null)
        std.log.warn("mapping '{s}' not found", .{mapping_arg.?});

    const mapping: ?mapping_mod.ParseResult = blk: {
        const mpath = if (mapping_path) |mp| mp else {
            break :blk null;
        };
        break :blk mapping_mod.parseFile(allocator, mpath) catch |e| {
            std.log.err("failed to load mapping '{s}': {}", .{ mpath, e });
            break :blk null;
        };
    };
    defer if (mapping) |m| m.deinit();

    var auto_path: ?[]const u8 = null;
    defer if (auto_path) |p| allocator.free(p);

    var parsed_device: ?device_mod.ParseResult = null;
    defer if (parsed_device) |p| p.deinit();

    var opened: OpenedDevice = undefined;
    if (config_path) |cp| {
        const parsed = device_mod.parseFile(allocator, cp) catch |e| {
            std.log.err("failed to load device config '{s}': {}", .{ cp, e });
            return e;
        };
        parsed_device = parsed;
        const vid = std.math.cast(u16, parsed.value.device.vid) orelse return error.MalformedConfig;
        const pid = std.math.cast(u16, parsed.value.device.pid) orelse return error.MalformedConfig;
        var denied = false;
        opened = openHidrawByVidPid(vid, pid, &denied) catch |e| {
            writer.print("error: no hidraw device matching {x:0>4}:{x:0>4}.\n", .{ vid, pid }) catch {};
            if (denied) perm_hint.writeInputGroupHint(writer);
            return e;
        };
    } else {
        var dirs: [][]const u8 = &.{};
        var dirs_owned = false;
        defer if (dirs_owned) paths.freeConfigDirs(allocator, dirs);
        if (paths.resolveDeviceConfigDirs(allocator)) |d| {
            dirs = d;
            dirs_owned = true;
        } else |e| {
            std.log.warn("failed to resolve device config dirs: {}", .{e});
        }
        var denied = false;
        opened = openAutoResolved(allocator, dirs, &auto_path, &denied) catch |e| {
            reportNoDevice(writer, denied);
            return e;
        };
        if (auto_path) |p| {
            parsed_device = device_mod.parseFile(allocator, p) catch |e| blk: {
                std.log.warn("failed to load device config '{s}': {}", .{ p, e });
                break :blk null;
            };
        }
    }
    defer posix.close(opened.fd);

    const decode_iface: ?u8 = if (!raw_mode and parsed_device != null)
        decodeInterface(&parsed_device.?.value, opened.iface)
    else
        null;

    // Print device name
    var name_buf: [NAME_BUF_LEN]u8 = std.mem.zeroes([NAME_BUF_LEN]u8);
    _ = linux.ioctl(opened.fd, HIDIOCGRAWNAME, @intFromPtr(&name_buf));
    const dev_name = std.mem.sliceTo(&name_buf, 0);

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    try w.print("Testing device: {s}\n", .{dev_name});
    const active_config: ?[]const u8 = config_path orelse auto_path;
    if (decode_iface != null) {
        try w.print("Device config: {s}\n", .{active_config.?});
    } else if (raw_mode) {
        try w.writeAll("Device config: (raw mode)\n");
    } else if (active_config) |cp| {
        const why = if (parsed_device == null) "failed to load" else "no hid-class interface";
        try w.print("Device config: {s} ({s} — showing raw bytes)\n", .{ cp, why });
    } else {
        try w.writeAll("Device config: (none — showing raw bytes)\n");
    }
    if (mapping) |m| {
        if (m.value.name) |n| try w.print("Mapping: {s}\n", .{n});
    }
    try w.writeAll("Press Ctrl-C to exit.\n\n");
    writer.writeAll(out.items) catch {};
    out.clearRetainingCapacity();

    var interp: interpreter_mod.Interpreter = undefined;
    var decoder = Decoder{ .interp = &interp, .interface_id = 0 };
    if (decode_iface) |id| {
        interp = interpreter_mod.Interpreter.init(&parsed_device.?.value);
        decoder.interface_id = id;
    }

    // Read loop
    var report_buf: [64]u8 = undefined;
    while (true) {
        const n = posix.read(opened.fd, &report_buf) catch break;
        if (n == 0) break;

        out.clearRetainingCapacity();
        if (decode_iface != null)
            try decoder.feed(w, report_buf[0..n])
        else
            try formatReport(w, report_buf[0..n], if (mapping) |m| m.value.remap else null);
        writer.writeAll(out.items) catch {};
    }
}

fn formatReport(w: anytype, report: []const u8, remap: ?mapping_mod.RemapMap) !void {
    try w.print("report[{d}B]:", .{report.len});
    for (report) |byte| {
        try w.print(" {x:0>2}", .{byte});
    }

    if (remap) |r| {
        var it = r.map.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| try w.print("  {s} -> {s}", .{ entry.key_ptr.*, s }),
                .chord_names => |names| {
                    try w.print("  {s} -> chord[", .{entry.key_ptr.*});
                    for (names, 0..) |name, i| {
                        if (i > 0) try w.writeAll(", ");
                        try w.print("{s}", .{name});
                    }
                    try w.writeAll("]");
                },
                .gesture => try w.print("  {s} -> <gesture>", .{entry.key_ptr.*}),
            }
        }
    }

    try w.writeByte('\n');
}

// --- tests ---

const testing = std.testing;

test "reportNoDevice: all-denied routes to the input-group hint" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    reportNoDevice(buf.writer(testing.allocator), true);
    try testing.expect(std.mem.indexOf(u8, buf.items, "permission-denied") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "usermod -aG input $USER") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "no hidraw device found") == null);
}

test "reportNoDevice: genuinely absent device does not show the group hint" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    reportNoDevice(buf.writer(testing.allocator), false);
    try testing.expect(std.mem.indexOf(u8, buf.items, "no hidraw device found") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "padctl scan") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "usermod") == null);
}

test "resolveMappingPath: slash arg is used as a literal path" {
    const allocator = testing.allocator;
    const got = try resolveMappingPath(allocator, "/etc/padctl/mappings/fps.toml");
    defer if (got) |p| allocator.free(p);
    try testing.expect(got != null);
    try testing.expectEqualStrings("/etc/padctl/mappings/fps.toml", got.?);
}

test "resolveMappingPath: bare name resolves through mapping dirs" {
    const allocator = testing.allocator;
    const got = try resolveMappingPath(allocator, "nonexistent_profile_xyz_12345");
    defer if (got) |p| allocator.free(p);
    try testing.expectEqual(@as(?[]const u8, null), got);
}

test "resolveMappingNameInDirs: bare name resolves to the on-disk profile" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "fps.toml", .data = "name = \"fps\"\n" });
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const dirs = [_][]const u8{dir};
    const got = try resolveMappingNameInDirs(allocator, "fps", &dirs);
    defer if (got) |p| allocator.free(p);
    try testing.expect(got != null);
    try testing.expect(std.mem.endsWith(u8, got.?, "/fps.toml"));
}

test "resolveMappingNameInDirs: missing name returns null" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const dirs = [_][]const u8{dir};
    const got = try resolveMappingNameInDirs(allocator, "absent", &dirs);
    defer if (got) |p| allocator.free(p);
    try testing.expectEqual(@as(?[]const u8, null), got);
}

test "formatReport: hex dump without mapping" {
    var out: std.ArrayList(u8) = .{};
    defer out.deinit(testing.allocator);
    try formatReport(out.writer(testing.allocator), &[_]u8{ 0x01, 0xab, 0x00 }, null);
    try testing.expectEqualStrings("report[3B]: 01 ab 00\n", out.items);
}

test "formatReport: appends remap hint" {
    var map = std.StringHashMap(mapping_mod.RemapValue).init(testing.allocator);
    defer map.deinit();
    try map.put("BTN_SOUTH", .{ .string = "KEY_A" });

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(testing.allocator);
    try formatReport(out.writer(testing.allocator), &[_]u8{0xff}, .{ .map = map });
    try testing.expectEqualStrings("report[1B]: ff  BTN_SOUTH -> KEY_A\n", out.items);
}

fn vader5Report() [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    return raw;
}

test "decode: button edge events with named buttons" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = interpreter_mod.Interpreter.init(&parsed.value);
    var dec = Decoder{ .interp = &interp, .interface_id = 1 };

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    // M1 = button_group bit 18 → byte 11 + 2, bit 2
    var raw = vader5Report();
    raw[13] = 0x04;
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("M1 down\n", out.items);

    out.clearRetainingCapacity();
    try dec.feed(w, &raw); // unchanged report → no events
    try testing.expectEqualStrings("", out.items);

    out.clearRetainingCapacity();
    raw[13] = 0;
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("M1 up\n", out.items);
}

test "decode: multiple buttons in enum order" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = interpreter_mod.Interpreter.init(&parsed.value);
    var dec = Decoder{ .interp = &interp, .interface_id = 1 };

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    // A = bit 4, B = bit 5 (byte 11)
    var raw = vader5Report();
    raw[11] = 0x30;
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("A down\nB down\n", out.items);
}

test "decode: axes printed on change with value" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = interpreter_mod.Interpreter.init(&parsed.value);
    var dec = Decoder{ .interp = &interp, .interface_id = 1 };

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    var raw = vader5Report();
    std.mem.writeInt(i16, raw[3..5], 1000, .little); // left_x
    std.mem.writeInt(i16, raw[5..7], -500, .little); // left_y, negate transform → 500
    raw[15] = 143; // lt
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("LX=1000\nLY=500\nLT=143\n", out.items);

    out.clearRetainingCapacity();
    raw[15] = 0;
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("LT=0\n", out.items);
}

test "decode: buttons and axes in one report" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = interpreter_mod.Interpreter.init(&parsed.value);
    var dec = Decoder{ .interp = &interp, .interface_id = 1 };

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    var raw = vader5Report();
    raw[11] = 0x10; // A
    raw[16] = 200; // rt
    try dec.feed(w, &raw);
    try testing.expectEqualStrings("A down\nRT=200\n", out.items);
}

test "decode: unmatched report falls back to raw hex" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = interpreter_mod.Interpreter.init(&parsed.value);
    var dec = Decoder{ .interp = &interp, .interface_id = 1 };

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    try dec.feed(out.writer(allocator), &[_]u8{ 0x01, 0x02 });
    try testing.expectEqualStrings("report[2B]: 01 02\n", out.items);
}

test "decodeInterface: hid-class interface is decodable" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualshock4.toml");
    defer parsed.deinit();
    try testing.expectEqual(@as(?u8, 0), decodeInterface(&parsed.value, 0));
    try testing.expectEqual(@as(?u8, 0), decodeInterface(&parsed.value, null)); // single hid iface
    try testing.expectEqual(@as(?u8, null), decodeInterface(&parsed.value, 7)); // undeclared iface
}

test "decodeInterface: vendor-class interface falls back to raw" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    try testing.expectEqual(@as(?u8, null), decodeInterface(&parsed.value, 1));
    try testing.expectEqual(@as(?u8, null), decodeInterface(&parsed.value, null));
}
