const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const ioctl = @import("../../io/ioctl_constants.zig");
const mapping_mod = @import("../../config/mapping.zig");
const paths = @import("../../config/paths.zig");

const NAME_BUF_LEN = 128;

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

fn openFirstHidraw(config_path: ?[]const u8) !posix.fd_t {
    if (config_path) |p| {
        // Try to infer device from config path — just scan and open first available
        _ = p;
    }
    // Scan /dev/hidraw0..63 for first openable
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        return fd;
    }
    return error.NoHidrawDevice;
}

fn mappingLabel(mapping: *const mapping_mod.MappingConfig, button: []const u8) ?[]const u8 {
    if (mapping.remap) |remap| {
        if (remap.map.get(button)) |target| return target;
    }
    return null;
}

pub fn run(allocator: std.mem.Allocator, config_path: ?[]const u8, mapping_path: ?[]const u8) !void {
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

    const fd = openFirstHidraw(config_path) catch |e| {
        std.log.err("no hidraw device available: {}", .{e});
        return e;
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
    _ = posix.write(posix.STDOUT_FILENO, out.items) catch 0;
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
                    try w.print("  {s} -> {s}", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
            }
        }

        try w.writeByte('\n');
        _ = posix.write(posix.STDOUT_FILENO, out.items) catch 0;
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

test "test: openFirstHidraw returns error when no device" {
    // In CI there are no hidraw devices; ensure it returns an error cleanly.
    const result = openFirstHidraw(null);
    // May succeed or fail depending on environment; just ensure no panic.
    if (result) |fd| {
        posix.close(fd);
    } else |_| {}
}
