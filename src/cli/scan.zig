const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("../io/ioctl_constants.zig");
const hidraw = @import("../io/hidraw.zig");
const readPhysicalPath = hidraw.readPhysicalPath;
const readInterfaceId = hidraw.readInterfaceId;

const DEFAULT_CONFIG_DIR = "/usr/share/padctl/devices";
const MAX_HIDRAW = 64;
const NAME_BUF_LEN = 128;

// HIDIOCGRAWNAME(128): dir=READ('H', 0x04, 128)
const HIDIOCGRAWNAME: u32 = blk: {
    const req = linux.IOCTL.Request{
        .dir = 2,
        .io_type = 'H',
        .nr = 0x04,
        .size = NAME_BUF_LEN,
    };
    break :blk @as(u32, @bitCast(req));
};

pub const ScanEntry = struct {
    path: []const u8,
    vid: u16,
    pid: u16,
    name: []const u8,
    phys: []const u8,
    config_path: ?[]const u8,
    interface_id: ?u8 = null,
};

/// Enumerate /dev/hidrawN, match against *.toml with interface filtering.
/// Caller owns result; call freeEntries() when done.
pub fn scan(allocator: std.mem.Allocator, config_dir: []const u8) ![]ScanEntry {
    var entries: std.ArrayList(ScanEntry) = .{};
    errdefer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;

        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => {
                std.log.warn("scan: open {s} failed: {}", .{ path, err });
                continue;
            },
        };
        defer posix.close(fd);

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) {
            std.log.warn("scan: HIDIOCGRAWINFO failed for {s}", .{path});
            continue;
        }

        const phys_owned = readPhysicalPath(allocator, path) catch |err| blk: {
            std.log.warn("scan: readPhysicalPath {s} failed: {}", .{ path, err });
            break :blk try allocator.dupe(u8, "");
        };

        var name_buf: [NAME_BUF_LEN]u8 = std.mem.zeroes([NAME_BUF_LEN]u8);
        const name_rc = linux.ioctl(fd, HIDIOCGRAWNAME, @intFromPtr(&name_buf));
        if (std.posix.errno(name_rc) != .SUCCESS) {
            std.log.warn("scan: HIDIOCGRAWNAME failed for {s}: {}", .{ path, std.posix.errno(name_rc) });
        }
        const name_raw = std.mem.sliceTo(&name_buf, 0);

        const vid: u16 = @bitCast(info.vendor);
        const pid: u16 = @bitCast(info.product);
        const iface_id = readInterfaceId(path);
        const matched_config: ?[]const u8 = if (findConfig(allocator, config_dir, vid, pid, iface_id)) |m| m else |err| switch (err) {
            error.NotFound => null,
            else => return err,
        };

        try entries.append(allocator, .{
            .path = try allocator.dupe(u8, path),
            .vid = vid,
            .pid = pid,
            .name = try allocator.dupe(u8, name_raw),
            .phys = phys_owned,
            .config_path = matched_config,
            .interface_id = iface_id,
        });
    }

    // Suppress unmatched sibling interfaces of matched physical devices.
    // If any hidraw node for a physical device matched a config, hide the
    // unmatched siblings sharing the same physical path.
    for (entries.items) |e| {
        if (e.config_path != null and e.phys.len > 0) {
            for (entries.items) |*other| {
                if (other.config_path == null and std.mem.eql(u8, other.phys, e.phys)) {
                    other.config_path = ""; // sentinel: suppress but don't show
                }
            }
        }
    }

    // Remove suppressed entries (sentinel config_path == "")
    var keep: usize = 0;
    for (entries.items) |e| {
        if (e.config_path) |cp| {
            if (cp.len == 0) {
                // Sentinel — free owned fields but not config_path (it's a literal)
                allocator.free(e.path);
                allocator.free(e.name);
                allocator.free(e.phys);
                continue;
            }
        }
        entries.items[keep] = e;
        keep += 1;
    }
    entries.shrinkRetainingCapacity(keep);

    return entries.toOwnedSlice(allocator);
}

fn findConfig(allocator: std.mem.Allocator, config_dir: []const u8, vid: u16, pid: u16, iface_id: ?u8) ![]const u8 {
    var dir = if (std.fs.path.isAbsolute(config_dir))
        try std.fs.openDirAbsolute(config_dir, .{ .iterate = true })
    else
        try std.fs.cwd().openDir(config_dir, .{ .iterate = true });
    defer dir.close();
    return findConfigInDir(allocator, dir, config_dir, vid, pid, iface_id);
}

fn findConfigInDir(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    dir_path: []const u8,
    vid: u16,
    pid: u16,
    iface_id: ?u8,
) ![]const u8 {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                var sub = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
                defer sub.close();
                const sub_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
                defer allocator.free(sub_path);
                if (findConfigInDir(allocator, sub, sub_path, vid, pid, iface_id)) |m| return m else |_| {}
            },
            .file => {
                if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
                const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
                errdefer allocator.free(full_path);
                const match_result = tomlMatchesVidPid(allocator, full_path, vid, pid, iface_id) catch |err| blk: {
                    std.log.warn("scan: failed to read/parse '{s}': {}", .{ full_path, err });
                    break :blk null;
                };
                if (match_result) |iface_match| {
                    // Config declares an interface constraint
                    if (iface_match) |matches| {
                        if (matches) return full_path;
                        allocator.free(full_path);
                        continue; // wrong interface, keep searching
                    }
                    // Config has no interface constraint: matches any interface
                    return full_path;
                }
                allocator.free(full_path);
            },
            else => {},
        }
    }
    return error.NotFound;
}

/// Returns null if VID/PID don't match. Otherwise returns ?bool:
/// inner null = config has no interface constraint (matches any),
/// true = config has interface constraint and iface_id matches,
/// false = config has interface constraint but iface_id doesn't match.
fn tomlMatchesVidPid(allocator: std.mem.Allocator, path: []const u8, vid: u16, pid: u16, iface_id: ?u8) !??bool {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 256 * 1024);
    defer allocator.free(content);
    const file_vid = extractHexField(content, "vid") orelse return null;
    const file_pid = extractHexField(content, "pid") orelse return null;
    if (file_vid != vid or file_pid != pid) return null;
    return matchInterfaceId(content, iface_id);
}

/// Check whether TOML content has a [[device.interface]] section whose id matches target.
/// Returns null if no [[device.interface]] sections exist (no constraint),
/// true if any section's id matches target, false otherwise.
fn configHasInterfaceId(content: []const u8, target: u8) ?bool {
    const marker = "[[device.interface]]";
    var found_any = false;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, marker)) |idx| {
        found_any = true;
        const after = content[idx + marker.len ..];
        var lines = std.mem.splitScalar(u8, after, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trimLeft(u8, line, " \t");
            if (trimmed.len == 0) continue;
            if (trimmed[0] == '[') break; // next section
            if (trimmed[0] == '#') continue;
            if (!std.mem.startsWith(u8, trimmed, "id")) continue;
            const rest = std.mem.trimLeft(u8, trimmed["id".len..], " \t");
            if (rest.len == 0 or rest[0] != '=') continue;
            const val_str = std.mem.trimLeft(u8, rest[1..], " \t");
            var end: usize = 0;
            while (end < val_str.len and std.ascii.isDigit(val_str[end])) end += 1;
            if (end == 0) continue;
            const parsed = std.fmt.parseInt(u8, val_str[0..end], 10) catch continue;
            if (parsed == target) return true;
            break; // found id for this section, move to next
        }
        pos = idx + marker.len;
    }
    if (!found_any) return null;
    return false;
}

/// Match device interface id against config's [[device.interface]] sections.
/// Returns null if config has no interface constraint (matches any device),
/// true if config has constraint and iface_id matches,
/// false if config has constraint but iface_id doesn't match or is unknown.
fn matchInterfaceId(content: []const u8, iface_id: ?u8) ?bool {
    const marker = "[[device.interface]]";
    if (std.mem.indexOf(u8, content, marker) == null) return null; // no constraint
    if (iface_id) |actual| {
        return configHasInterfaceId(content, actual) orelse false;
    } else {
        std.log.warn("scan: sysfs interface id unavailable, skipping interface-constrained config", .{});
        return false;
    }
}

/// Extract the first occurrence of `key = 0x<hex>` or `key = <dec>` from TOML text.
pub fn extractHexField(content: []const u8, key: []const u8) ?u16 {
    var pos: usize = 0;
    while (pos < content.len) {
        const idx = std.mem.indexOfPos(u8, content, pos, key) orelse break;
        pos = idx + key.len;

        // Skip matches inside comments or mid-line (key must be at line start)
        const line_start = if (std.mem.lastIndexOf(u8, content[0..idx], "\n")) |nl| nl + 1 else 0;
        const prefix = std.mem.trimLeft(u8, content[line_start..idx], " \t");
        if (prefix.len > 0) continue;

        var p = pos;
        while (p < content.len and (content[p] == ' ' or content[p] == '\t')) p += 1;
        if (p >= content.len or content[p] != '=') continue;
        p += 1;
        while (p < content.len and (content[p] == ' ' or content[p] == '\t')) p += 1;

        if (p + 2 <= content.len and content[p] == '0' and (content[p + 1] == 'x' or content[p + 1] == 'X')) {
            const start = p + 2;
            var end = start;
            while (end < content.len and std.ascii.isHex(content[end])) end += 1;
            if (end > start) return std.fmt.parseInt(u16, content[start..end], 16) catch null;
        } else if (p < content.len and std.ascii.isDigit(content[p])) {
            var end = p;
            while (end < content.len and std.ascii.isDigit(content[end])) end += 1;
            return std.fmt.parseInt(u16, content[p..end], 10) catch null;
        }
    }
    return null;
}

pub fn freeEntry(allocator: std.mem.Allocator, e: ScanEntry) void {
    allocator.free(e.path);
    allocator.free(e.name);
    allocator.free(e.phys);
    if (e.config_path) |p| allocator.free(p);
}

pub fn freeEntries(allocator: std.mem.Allocator, entries: []ScanEntry) void {
    for (entries) |e| freeEntry(allocator, e);
    allocator.free(entries);
}

fn padRight(buf: []u8, s: []const u8, width: usize) []const u8 {
    const len = @min(s.len, width);
    @memcpy(buf[0..len], s[0..len]);
    @memset(buf[len..width], ' ');
    return buf[0..width];
}

pub fn run(allocator: std.mem.Allocator, config_dirs: []const []const u8, writer: anytype) !void {
    var all_entries: std.ArrayList(ScanEntry) = .{};
    defer {
        for (all_entries.items) |e| freeEntry(allocator, e);
        all_entries.deinit(allocator);
    }

    for (config_dirs) |dir| {
        const entries = scan(allocator, dir) catch |err| {
            std.log.warn("scan: failed to scan config dir '{s}': {}", .{ dir, err });
            continue;
        };
        defer allocator.free(entries);
        for (entries) |e| {
            // Merge: if same path already seen, skip; otherwise check if we can upgrade config_path
            var found = false;
            for (all_entries.items) |*existing| {
                if (std.mem.eql(u8, existing.path, e.path)) {
                    found = true;
                    if (existing.config_path == null and e.config_path != null) {
                        existing.config_path = e.config_path;
                        // Free the duplicate non-config fields
                        allocator.free(e.path);
                        allocator.free(e.name);
                        allocator.free(e.phys);
                    } else {
                        freeEntry(allocator, e);
                    }
                    break;
                }
            }
            if (!found) all_entries.append(allocator, e) catch |err| {
                freeEntry(allocator, e);
                return err;
            };
        }
    }

    const entries = all_entries.items;

    if (entries.len == 0) {
        try writer.writeAll("No HID devices found.\n");
        return;
    }

    const path_w = 18;
    const vidpid_w = 9;
    const name_w = 32;
    const pad_total = path_w + vidpid_w + name_w;
    var pad: [pad_total]u8 = undefined;

    try writer.print("{s} {s} {s} {s}\n", .{
        padRight(pad[0..path_w], "DEVICE", path_w),
        padRight(pad[path_w .. path_w + vidpid_w], "VID:PID", vidpid_w),
        padRight(pad[path_w + vidpid_w .. pad_total], "NAME", name_w),
        "CONFIG",
    });
    try writer.writeByteNTimes('-', path_w + 1 + vidpid_w + 1 + name_w + 1 + 24);
    try writer.writeByte('\n');

    var unmatched: usize = 0;
    for (entries) |e| {
        var vidpid_buf: [9]u8 = undefined;
        const vidpid = std.fmt.bufPrint(&vidpid_buf, "{x:0>4}:{x:0>4}", .{ e.vid, e.pid }) catch unreachable;

        var row_pad: [pad_total]u8 = undefined;
        try writer.print("{s} {s} {s} {s}\n", .{
            padRight(row_pad[0..path_w], e.path, path_w),
            padRight(row_pad[path_w .. path_w + vidpid_w], vidpid, vidpid_w),
            padRight(row_pad[path_w + vidpid_w .. pad_total], e.name, name_w),
            e.config_path orelse "",
        });

        if (e.config_path == null) unmatched += 1;
    }

    try writer.writeByte('\n');
    try writer.print("{d} device(s) found, {d} matched, {d} unmatched.\n", .{
        entries.len,
        entries.len - unmatched,
        unmatched,
    });

    if (unmatched > 0) {
        try writer.writeByte('\n');
        try writer.writeAll("To capture an unmatched device:\n");
        for (entries) |e| {
            if (e.config_path == null) {
                try writer.print("  padctl-capture --vid 0x{x:0>4} --pid 0x{x:0>4}\n", .{ e.vid, e.pid });
            }
        }
    }
}

// --- tests ---

test "extractHexField: hex value" {
    const toml_str = "vid = 0x37d7\npid = 0x2401\n";
    try std.testing.expectEqual(@as(?u16, 0x37d7), extractHexField(toml_str, "vid"));
    try std.testing.expectEqual(@as(?u16, 0x2401), extractHexField(toml_str, "pid"));
}

test "extractHexField: decimal value" {
    const toml_str = "vid = 1000\npid = 512\n";
    try std.testing.expectEqual(@as(?u16, 1000), extractHexField(toml_str, "vid"));
    try std.testing.expectEqual(@as(?u16, 512), extractHexField(toml_str, "pid"));
}

test "extractHexField: missing key" {
    try std.testing.expectEqual(@as(?u16, null), extractHexField("name = \"foo\"\n", "vid"));
}

test "extractHexField: quoted value not parsed" {
    try std.testing.expectEqual(@as(?u16, null), extractHexField("vid = \"0x1234\"\n", "vid"));
}

test "extractHexField: uppercase hex" {
    try std.testing.expectEqual(@as(?u16, 0x1a86), extractHexField("vid = 0x1A86\n", "vid"));
}

test "extractHexField: ignores commented-out lines" {
    try std.testing.expectEqual(@as(?u16, null), extractHexField("# vid = 0x1234\n", "vid"));
    try std.testing.expectEqual(@as(?u16, 0x5678), extractHexField("# vid = 0x1234\nvid = 0x5678\n", "vid"));
}

test "findConfig: matches VID/PID with correct interface" {
    const allocator = std.testing.allocator;
    // vader5.toml: vid=0x37d7 pid=0x2401, interface=1
    const path = findConfig(allocator, "devices", 0x37d7, 0x2401, 1) catch null;
    defer if (path) |p| allocator.free(p);
    try std.testing.expect(path != null);
    try std.testing.expect(std.mem.endsWith(u8, path.?, ".toml"));
}

test "findConfig: no match returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.NotFound, findConfig(allocator, "devices", 0xffff, 0xffff, null));
}

test "findConfig: vader4-pro matches with correct interface" {
    const allocator = std.testing.allocator;
    // vader4-pro-04b4-2412.toml: vid=0x04b4 pid=0x2412, interface=2
    const path = findConfig(allocator, "devices", 0x04b4, 0x2412, 2) catch null;
    defer if (path) |p| allocator.free(p);
    try std.testing.expect(path != null);
}

test "findConfig: vader4-pro rejects wrong interface" {
    const allocator = std.testing.allocator;
    // vader4-pro config requires interface 2; interface 0 should not match
    try std.testing.expectError(error.NotFound, findConfig(allocator, "devices", 0x04b4, 0x2412, 0));
}

test "configHasInterfaceId: single section match" {
    const toml = "[[device.interface]]\nid = 2\nclass = \"hid\"\n";
    try std.testing.expectEqual(@as(?bool, true), configHasInterfaceId(toml, 2));
    try std.testing.expectEqual(@as(?bool, false), configHasInterfaceId(toml, 1));
}

test "configHasInterfaceId: no section returns null" {
    const toml = "[device]\nname = \"foo\"\nvid = 0x1234\n";
    try std.testing.expectEqual(@as(?bool, null), configHasInterfaceId(toml, 0));
}

test "configHasInterfaceId: multiple sections" {
    const toml = "[[device.interface]]\nid = 0\nclass = \"vendor\"\n\n[[device.interface]]\nid = 2\nclass = \"hid\"\n";
    try std.testing.expectEqual(@as(?bool, true), configHasInterfaceId(toml, 2));
    try std.testing.expectEqual(@as(?bool, true), configHasInterfaceId(toml, 0));
    try std.testing.expectEqual(@as(?bool, false), configHasInterfaceId(toml, 1));
}

test "matchInterfaceId: no constraint returns null" {
    const toml = "[device]\nname = \"foo\"\n";
    try std.testing.expectEqual(@as(?bool, null), matchInterfaceId(toml, 1));
    try std.testing.expectEqual(@as(?bool, null), matchInterfaceId(toml, null));
}

test "matchInterfaceId: with constraint and known iface" {
    const toml = "[[device.interface]]\nid = 2\n";
    try std.testing.expectEqual(@as(?bool, true), matchInterfaceId(toml, 2));
    try std.testing.expectEqual(@as(?bool, false), matchInterfaceId(toml, 0));
}

test "matchInterfaceId: with constraint and null iface returns false" {
    const toml = "[[device.interface]]\nid = 2\n";
    try std.testing.expectEqual(@as(?bool, false), matchInterfaceId(toml, null));
}

test "freeEntries: empty slice is a no-op" {
    const empty: []ScanEntry = &.{};
    freeEntries(std.testing.allocator, empty);
}
