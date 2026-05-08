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

fn readVidPid(config_path: []const u8) !struct { vid: u16, pid: u16 } {
    const content = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, config_path, 256 * 1024);
    defer std.heap.page_allocator.free(content);
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

fn mappingLabel(mapping: *const mapping_mod.MappingConfig, button: []const u8) ?[]const u8 {
    if (mapping.remap) |remap| {
        if (remap.map.get(button)) |target| {
            switch (target) {
                .string => |s| return s,
                // Chord arrays don't have a single human label; callers fall
                // back to the source button name.
                else => return null,
            }
        }
    }
    return null;
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
            const vp = readVidPid(cp) catch |e| {
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
        try w.print("report[{d}B]:", .{n});
        for (report_buf[0..n]) |byte| {
            try w.print(" {x:0>2}", .{byte});
        }

        if (mapping) |m| {
            // Show any known remaps as a hint
            const remap = m.value.remap;
            if (remap != null) {
                var it = remap.?.map.iterator();
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
                    }
                }
            }
        }

        try w.writeByte('\n');
        writer.writeAll(out.items) catch {};
    }
}

// --- tests ---

test "test: mappingLabel returns remap target" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[remap]
        \\A = "BTN_SOUTH"
        \\B = "BTN_EAST"
    ;
    const parsed = try mapping_mod.parseString(allocator, toml_str);
    defer parsed.deinit();
    const label = mappingLabel(&parsed.value, "A");
    try std.testing.expectEqualStrings("BTN_SOUTH", label.?);
    try std.testing.expectEqual(@as(?[]const u8, null), mappingLabel(&parsed.value, "X"));
}

test "test: mappingLabel with no remap returns null" {
    const m = mapping_mod.MappingConfig{};
    try std.testing.expectEqual(@as(?[]const u8, null), mappingLabel(&m, "A"));
}

// "openFirstHidraw returns error when no device" test removed: openFirstHidraw
// scans /dev/hidraw0..63 and on dev machines an orphaned UHID device causes
// hid_hw_open D-state even with O_NONBLOCK. The function is exercised via run().
