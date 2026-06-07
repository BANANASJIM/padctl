const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("../../io/ioctl_constants.zig");
const mapping_mod = @import("../../config/mapping.zig");
const paths = @import("../../config/paths.zig");
const scan_mod = @import("../scan.zig");

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

fn readVidPid(allocator: std.mem.Allocator, config_path: []const u8) !struct { vid: u16, pid: u16 } {
    const content = try std.fs.cwd().readFileAlloc(allocator, config_path, 256 * 1024);
    defer allocator.free(content);
    const vid = scan_mod.extractHexField(content, "vid") orelse return error.MissingVid;
    const pid = scan_mod.extractHexField(content, "pid") orelse return error.MissingPid;
    return .{ .vid = vid, .pid = pid };
}

fn openHidrawByVidPid(vid: u16, pid: u16) !posix.fd_t {
    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) {
            posix.close(fd);
            continue;
        }
        if (@as(u16, @bitCast(info.vendor)) == vid and @as(u16, @bitCast(info.product)) == pid)
            return fd;
        posix.close(fd);
    }
    return error.NoMatchingDevice;
}

fn openFirstHidraw() !posix.fd_t {
    var i: u8 = 0;
    while (i < MAX_HIDRAW) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        return fd;
    }
    return error.NoHidrawDevice;
}

pub fn run(allocator: std.mem.Allocator, config_path: ?[]const u8, mapping_path: ?[]const u8, writer: anytype) !void {
    // Load mapping
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

    const fd = blk: {
        if (config_path) |cp| {
            const vp = readVidPid(allocator, cp) catch |e| {
                std.log.err("failed to read VID/PID from '{s}': {}", .{ cp, e });
                return e;
            };
            break :blk openHidrawByVidPid(vp.vid, vp.pid) catch |e| {
                std.log.err("no hidraw device matching {x:0>4}:{x:0>4}: {}", .{ vp.vid, vp.pid, e });
                return e;
            };
        }
        break :blk openFirstHidraw() catch |e| {
            std.log.warn("no hidraw device available: {}", .{e});
            return e;
        };
    };
    defer posix.close(fd);

    // Print device name
    var name_buf: [NAME_BUF_LEN]u8 = std.mem.zeroes([NAME_BUF_LEN]u8);
    _ = linux.ioctl(fd, HIDIOCGRAWNAME, @intFromPtr(&name_buf));
    const dev_name = std.mem.sliceTo(&name_buf, 0);

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    try w.print("Testing device: {s}\n", .{dev_name});
    if (mapping) |m| {
        if (m.value.name) |n| try w.print("Mapping: {s}\n", .{n});
    } else {
        try w.writeAll("Mapping: (none — showing raw bytes)\n");
    }
    try w.writeAll("Press Ctrl-C to exit.\n\n");
    writer.writeAll(out.items) catch {};
    out.clearRetainingCapacity();

    // Read loop
    var report_buf: [64]u8 = undefined;
    while (true) {
        const n = posix.read(fd, &report_buf) catch break;
        if (n == 0) break;

        out.clearRetainingCapacity();
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

// "openFirstHidraw returns error when no device" test removed: openFirstHidraw
// scans /dev/hidraw0..63 and on dev machines an orphaned UHID device causes
// hid_hw_open D-state even with O_NONBLOCK. The function is exercised via run().

const testing = std.testing;

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

test "readVidPid: parses vid/pid from device toml" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "dev.toml", .data = "vid = 0x045e\npid = 0x028e\n" });

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp.dir.realpath("dev.toml", &path_buf);
    const vp = try readVidPid(testing.allocator, path);
    try testing.expectEqual(@as(u16, 0x045e), vp.vid);
    try testing.expectEqual(@as(u16, 0x028e), vp.pid);
}
