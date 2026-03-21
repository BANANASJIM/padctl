const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("../io/ioctl_constants.zig");

const DEFAULT_CONFIG_DIR = "/usr/share/padctl/devices";
const MAX_HIDRAW = 64;
const NAME_BUF_LEN = 128;
const PHYS_BUF_LEN = 256;

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
};

/// Enumerate /dev/hidrawN, deduplicate by physical path, match against *.toml.
/// Caller owns result; call freeEntries() when done.
pub fn scan(allocator: std.mem.Allocator, config_dir: []const u8) ![]ScanEntry {
    var entries: std.ArrayList(ScanEntry) = .{};
    errdefer {
        for (entries.items) |e| freeEntry(allocator, e);
        entries.deinit(allocator);
    }

    var phys_seen = std.StringHashMap(void).init(allocator);
    defer {
        var it = phys_seen.keyIterator();
        while (it.next()) |k| allocator.free(k.*);
        phys_seen.deinit();
    }

    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;

        const fd = posix.open(path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) continue;

        var phys_buf: [PHYS_BUF_LEN]u8 = std.mem.zeroes([PHYS_BUF_LEN]u8);
        _ = linux.ioctl(fd, ioctl.HIDIOCGRAWPHYS, @intFromPtr(&phys_buf));
        const phys_raw = std.mem.sliceTo(&phys_buf, 0);

        if (phys_raw.len > 0) {
            const gop = try phys_seen.getOrPut(try allocator.dupe(u8, phys_raw));
            if (gop.found_existing) {
                allocator.free(gop.key_ptr.*);
                continue;
            }
        }

        var name_buf: [NAME_BUF_LEN]u8 = std.mem.zeroes([NAME_BUF_LEN]u8);
        _ = linux.ioctl(fd, HIDIOCGRAWNAME, @intFromPtr(&name_buf));
        const name_raw = std.mem.sliceTo(&name_buf, 0);

        const vid: u16 = @bitCast(info.vendor);
        const pid: u16 = @bitCast(info.product);
        const config_path = findConfig(allocator, config_dir, vid, pid) catch null;

        try entries.append(allocator, .{
            .path = try allocator.dupe(u8, path),
            .vid = vid,
            .pid = pid,
            .name = try allocator.dupe(u8, name_raw),
            .phys = try allocator.dupe(u8, phys_raw),
            .config_path = config_path,
        });
    }

    return entries.toOwnedSlice(allocator);
}

fn findConfig(allocator: std.mem.Allocator, config_dir: []const u8, vid: u16, pid: u16) ![]const u8 {
    var dir = if (std.fs.path.isAbsolute(config_dir))
        try std.fs.openDirAbsolute(config_dir, .{ .iterate = true })
    else
        try std.fs.cwd().openDir(config_dir, .{ .iterate = true });
    defer dir.close();
    return findConfigInDir(allocator, dir, config_dir, vid, pid);
}

fn findConfigInDir(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    dir_path: []const u8,
    vid: u16,
    pid: u16,
) ![]const u8 {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                var sub = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
                defer sub.close();
                const sub_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
                defer allocator.free(sub_path);
                if (findConfigInDir(allocator, sub, sub_path, vid, pid)) |p| return p else |_| {}
            },
            .file => {
                if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
                const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
                errdefer allocator.free(full_path);
                if (tomlMatchesVidPid(allocator, full_path, vid, pid) catch false) return full_path;
                allocator.free(full_path);
            },
            else => {},
        }
    }
    return error.NotFound;
}

fn tomlMatchesVidPid(allocator: std.mem.Allocator, path: []const u8, vid: u16, pid: u16) !bool {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 256 * 1024);
    defer allocator.free(content);
    const file_vid = extractHexField(content, "vid") orelse return false;
    const file_pid = extractHexField(content, "pid") orelse return false;
    return file_vid == vid and file_pid == pid;
}

/// Extract the first occurrence of `key = 0x<hex>` or `key = <dec>` from TOML text.
fn extractHexField(content: []const u8, key: []const u8) ?u16 {
    var pos: usize = 0;
    while (pos < content.len) {
        const idx = std.mem.indexOfPos(u8, content, pos, key) orelse break;
        pos = idx + key.len;

        var p = pos;
        while (p < content.len and content[p] == ' ') p += 1;
        if (p >= content.len or content[p] != '=') continue;
        p += 1;
        while (p < content.len and content[p] == ' ') p += 1;

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

pub fn run(allocator: std.mem.Allocator, config_dir: []const u8) !void {
    const entries = try scan(allocator, config_dir);
    defer freeEntries(allocator, entries);

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    if (entries.len == 0) {
        try w.writeAll("No HID devices found.\n");
        _ = posix.write(posix.STDOUT_FILENO, out.items) catch 0;
        return;
    }

    const path_w = 18;
    const vidpid_w = 9;
    const name_w = 32;
    const pad_total = path_w + vidpid_w + name_w;
    var pad: [pad_total]u8 = undefined;

    try w.print("{s} {s} {s} {s}\n", .{
        padRight(pad[0..path_w], "DEVICE", path_w),
        padRight(pad[path_w .. path_w + vidpid_w], "VID:PID", vidpid_w),
        padRight(pad[path_w + vidpid_w .. pad_total], "NAME", name_w),
        "CONFIG",
    });
    try w.writeByteNTimes('-', path_w + 1 + vidpid_w + 1 + name_w + 1 + 24);
    try w.writeByte('\n');

    var unmatched: usize = 0;
    for (entries) |e| {
        var vidpid_buf: [9]u8 = undefined;
        const vidpid = std.fmt.bufPrint(&vidpid_buf, "{x:0>4}:{x:0>4}", .{ e.vid, e.pid }) catch unreachable;

        var row_pad: [pad_total]u8 = undefined;
        try w.print("{s} {s} {s} {s}\n", .{
            padRight(row_pad[0..path_w], e.path, path_w),
            padRight(row_pad[path_w .. path_w + vidpid_w], vidpid, vidpid_w),
            padRight(row_pad[path_w + vidpid_w .. pad_total], e.name, name_w),
            e.config_path orelse "",
        });

        if (e.config_path == null) unmatched += 1;
    }

    try w.writeByte('\n');
    try w.print("{d} device(s) found, {d} matched, {d} unmatched.\n", .{
        entries.len,
        entries.len - unmatched,
        unmatched,
    });

    if (unmatched > 0) {
        try w.writeByte('\n');
        try w.writeAll("To capture an unmatched device:\n");
        for (entries) |e| {
            if (e.config_path == null) {
                try w.print("  padctl-capture --vid 0x{x:0>4} --pid 0x{x:0>4}\n", .{ e.vid, e.pid });
            }
        }
    }

    _ = posix.write(posix.STDOUT_FILENO, out.items) catch 0;
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

test "findConfig: matches VID/PID in real devices dir" {
    const allocator = std.testing.allocator;
    // vader5.toml: vid=0x37d7 pid=0x2401
    const path = findConfig(allocator, "devices", 0x37d7, 0x2401) catch null;
    defer if (path) |p| allocator.free(p);
    try std.testing.expect(path != null);
    try std.testing.expect(std.mem.endsWith(u8, path.?, ".toml"));
}

test "findConfig: no match returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.NotFound, findConfig(allocator, "devices", 0xffff, 0xffff));
}

test "freeEntries: empty slice is a no-op" {
    const empty: []ScanEntry = &.{};
    freeEntries(std.testing.allocator, empty);
}
