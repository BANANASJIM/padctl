const std = @import("std");
const device = @import("../config/device.zig");

pub fn generateDevicePage(
    cfg: *const device.DeviceConfig,
    vendor: []const u8,
    writer: anytype,
) !void {
    const dev = &cfg.device;

    try writer.print("# {s}\n\n", .{dev.name});
    try writer.print("**VID:PID** `0x{x:0>4}:0x{x:0>4}`\n\n", .{ @as(u64, @intCast(dev.vid)), @as(u64, @intCast(dev.pid)) });
    try writer.print("**Vendor** {s}\n\n", .{vendor});

    // Interfaces table
    if (dev.interface.len > 0) {
        try writer.writeAll("## Interfaces\n\n");
        try writer.writeAll("| ID | Class | EP IN | EP OUT |\n");
        try writer.writeAll("|----|-------|-------|--------|\n");
        for (dev.interface) |iface| {
            try writer.print("| {d} | {s} | {s} | {s} |\n", .{
                iface.id,
                iface.class,
                if (iface.ep_in) |ep| blk: {
                    var buf: [8]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{ep});
                    break :blk s;
                } else "—",
                if (iface.ep_out) |ep| blk: {
                    var buf: [8]u8 = undefined;
                    const s = try std.fmt.bufPrint(&buf, "{d}", .{ep});
                    break :blk s;
                } else "—",
            });
        }
        try writer.writeByte('\n');
    }

    // Reports
    for (cfg.report) |report| {
        try writer.print("## Report: `{s}` ({d} bytes, interface {d})\n\n", .{
            report.name, report.size, report.interface,
        });

        if (report.match) |m| {
            try writer.print("Match: byte[{d}] = ", .{m.offset});
            for (m.expect, 0..) |b, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("`0x{x:0>2}`", .{@as(u64, @intCast(b))});
            }
            try writer.writeAll("\n\n");
        }

        if (report.fields) |fields| {
            try writer.writeAll("### Fields\n\n");
            try writer.writeAll("| Name | Offset | Type | Transform |\n");
            try writer.writeAll("|------|--------|------|-----------|\n");
            var it = fields.map.iterator();
            while (it.next()) |entry| {
                const f = entry.value_ptr.*;
                try writer.print("| `{s}` | {d} | `{s}` | {s} |\n", .{
                    entry.key_ptr.*,
                    f.offset,
                    f.type,
                    f.transform orelse "—",
                });
            }
            try writer.writeByte('\n');
        }

        if (report.button_group) |bg| {
            try writer.writeAll("### Button Map\n\n");
            try writer.print("Source: offset {d}, size {d} byte(s)\n\n", .{
                bg.source.offset, bg.source.size,
            });
            try writer.writeAll("| Button | Bit Index |\n");
            try writer.writeAll("|--------|-----------|\n");
            var it = bg.map.map.iterator();
            while (it.next()) |entry| {
                try writer.print("| `{s}` | {d} |\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeByte('\n');
        }
    }

    // Commands
    if (cfg.commands) |cmds| {
        try writer.writeAll("## Commands\n\n");
        try writer.writeAll("| Name | Interface | Template |\n");
        try writer.writeAll("|------|-----------|----------|\n");
        var it = cmds.map.iterator();
        while (it.next()) |entry| {
            const c = entry.value_ptr.*;
            const tpl = entry.value_ptr.*.template;
            const short = if (tpl.len > 60) tpl[0..60] else tpl;
            _ = c;
            try writer.print("| `{s}` | {d} | `{s}...` |\n", .{
                entry.key_ptr.*,
                entry.value_ptr.*.interface,
                short,
            });
        }
        try writer.writeByte('\n');
    }

    // Output
    if (cfg.output) |out| {
        try writer.writeAll("## Output Capabilities\n\n");
        try writer.print("uinput device name: **{s}**", .{out.name});
        if (out.vid) |v| try writer.print(" | VID `0x{x:0>4}`", .{@as(u64, @intCast(v))});
        if (out.pid) |p| try writer.print(" | PID `0x{x:0>4}`", .{@as(u64, @intCast(p))});
        try writer.writeAll("\n\n");

        if (out.axes) |axes| {
            try writer.writeAll("### Axes\n\n");
            try writer.writeAll("| Field | Code | Min | Max | Fuzz | Flat |\n");
            try writer.writeAll("|-------|------|-----|-----|------|------|\n");
            var it = axes.map.iterator();
            while (it.next()) |entry| {
                const a = entry.value_ptr.*;
                try writer.print("| `{s}` | `{s}` | {d} | {d} | {d} | {d} |\n", .{
                    entry.key_ptr.*,
                    a.code,
                    a.min,
                    a.max,
                    a.fuzz orelse 0,
                    a.flat orelse 0,
                });
            }
            try writer.writeByte('\n');
        }

        if (out.buttons) |buttons| {
            try writer.writeAll("### Buttons\n\n");
            try writer.writeAll("| Button | Event Code |\n");
            try writer.writeAll("|--------|------------|\n");
            var it = buttons.map.iterator();
            while (it.next()) |entry| {
                try writer.print("| `{s}` | `{s}` |\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeByte('\n');
        }

        if (out.force_feedback) |ff| {
            try writer.print("**Force feedback**: type=`{s}`", .{ff.type});
            if (ff.max_effects) |me| try writer.print(", max_effects={d}", .{me});
            try writer.writeAll("\n\n");
        }
    }
}

fn outputFilename(
    allocator: std.mem.Allocator,
    toml_path: []const u8,
    dev_name: []const u8,
) ![]u8 {
    // derive vendor from directory: devices/<vendor>/model.toml -> vendor
    var vendor: []const u8 = "unknown";
    const basename = std.fs.path.basename(toml_path);
    const parent = std.fs.path.dirname(toml_path) orelse ".";
    const grandparent_base = std.fs.path.basename(parent);
    // if parent dir is not "devices" itself, use it as vendor
    if (!std.mem.eql(u8, grandparent_base, "devices") and
        !std.mem.eql(u8, grandparent_base, "."))
    {
        vendor = grandparent_base;
    }

    // strip .toml from basename
    const stem = if (std.mem.endsWith(u8, basename, ".toml"))
        basename[0 .. basename.len - 5]
    else
        basename;

    // slugify device name: lowercase, spaces -> hyphens, keep alphanum and hyphen
    var slug = try allocator.alloc(u8, dev_name.len);
    defer allocator.free(slug);
    var slug_len: usize = 0;
    for (dev_name) |c| {
        if (std.ascii.isAlphanumeric(c)) {
            slug[slug_len] = std.ascii.toLower(c);
            slug_len += 1;
        } else if (c == ' ' or c == '-' or c == '_') {
            if (slug_len > 0 and slug[slug_len - 1] != '-') {
                slug[slug_len] = '-';
                slug_len += 1;
            }
        }
    }
    _ = stem;

    return std.fmt.allocPrint(allocator, "{s}-{s}.md", .{ vendor, slug[0..slug_len] });
}

pub fn runDocGen(
    allocator: std.mem.Allocator,
    paths: []const []const u8,
    out_dir: []const u8,
) !void {
    for (paths) |path| {
        const parsed = device.parseFile(allocator, path) catch |err| {
            std.log.err("failed to parse '{s}': {}", .{ path, err });
            return error.ParseFailed;
        };
        defer parsed.deinit();

        const cfg = &parsed.value;

        // derive vendor from path
        const parent = std.fs.path.dirname(path) orelse ".";
        const vendor = std.fs.path.basename(parent);

        const fname = try outputFilename(allocator, path, cfg.device.name);
        defer allocator.free(fname);

        const out_path = try std.fs.path.join(allocator, &.{ out_dir, fname });
        defer allocator.free(out_path);

        // ensure output dir exists
        std.fs.cwd().makePath(out_dir) catch {};

        var buf: std.ArrayList(u8) = .{};
        defer buf.deinit(allocator);
        try generateDevicePage(cfg, vendor, buf.writer(allocator));

        const file = try std.fs.cwd().createFile(out_path, .{});
        defer file.close();
        try file.writeAll(buf.items);

        _ = std.posix.write(std.posix.STDOUT_FILENO, "wrote ") catch 0;
        _ = std.posix.write(std.posix.STDOUT_FILENO, out_path) catch 0;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch 0;
    }
}

// --- tests ---

const test_toml =
    \\[device]
    \\name = "Sony DualSense"
    \\vid = 0x054c
    \\pid = 0x0ce6
    \\[[device.interface]]
    \\id = 3
    \\class = "hid"
    \\[[report]]
    \\name = "usb"
    \\interface = 3
    \\size = 64
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x  = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
    \\left_y  = { offset = 2, type = "u8", transform = "scale(-32768, 32767), negate" }
    \\gyro_x  = { offset = 16, type = "i16le" }
    \\[report.button_group]
    \\source = { offset = 8, size = 3 }
    \\map = { X = 4, A = 5, B = 6, Y = 7 }
    \\[commands.rumble]
    \\interface = 3
    \\template = "02 01 00 {weak:u8} {strong:u8} 00"
    \\[commands.led]
    \\interface = 3
    \\template = "02 00 04 00 00 00 {r:u8} {g:u8} {b:u8}"
    \\[output]
    \\name = "Sony DualSense"
    \\vid = 0x054c
    \\pid = 0x0ce6
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = -32768, max = 32767 }
    \\left_y = { code = "ABS_Y", min = -32768, max = 32767 }
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\B = "BTN_EAST"
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

test "generateDevicePage contains VID:PID" {
    const allocator = std.testing.allocator;
    const parsed = try device.parseString(allocator, test_toml);
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);

    try generateDevicePage(&parsed.value, "sony", buf.writer(allocator));

    const out = buf.items;
    try std.testing.expect(std.mem.indexOf(u8, out, "0x054c:0x0ce6") != null);
}

test "generateDevicePage field table row count" {
    const allocator = std.testing.allocator;
    const parsed = try device.parseString(allocator, test_toml);
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);

    try generateDevicePage(&parsed.value, "sony", buf.writer(allocator));

    const out = buf.items;
    // 3 fields declared: left_x, left_y, gyro_x
    const fields = parsed.value.report[0].fields orelse return error.NoFields;
    const field_count = fields.map.count();
    try std.testing.expectEqual(@as(usize, 3), field_count);

    // count field table data rows (start with "| `" = field name column)
    // header row starts with "| Name", separator with "|----"
    var row_count: usize = 0;
    var in_fields = false;
    var it = std.mem.splitScalar(u8, out, '\n');
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, "### Fields") != null) {
            in_fields = true;
            continue;
        }
        if (in_fields and std.mem.startsWith(u8, line, "### ")) {
            in_fields = false;
        }
        if (in_fields and std.mem.startsWith(u8, line, "| `")) {
            row_count += 1;
        }
    }
    try std.testing.expectEqual(field_count, row_count);
}

test "generateDevicePage button section row count" {
    const allocator = std.testing.allocator;
    const parsed = try device.parseString(allocator, test_toml);
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);

    try generateDevicePage(&parsed.value, "sony", buf.writer(allocator));

    const out = buf.items;
    const bg = parsed.value.report[0].button_group orelse return error.NoBg;
    const btn_count = bg.map.map.count();
    try std.testing.expectEqual(@as(usize, 4), btn_count);

    // count button map rows: lines of form "| `<name>` | <num> |"
    var row_count: usize = 0;
    var in_btn_section = false;
    var it = std.mem.splitScalar(u8, out, '\n');
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, "Button Map") != null) {
            in_btn_section = true;
            continue;
        }
        if (in_btn_section and std.mem.startsWith(u8, line, "## ")) {
            in_btn_section = false;
        }
        if (in_btn_section and std.mem.startsWith(u8, line, "| `") and
            !std.mem.startsWith(u8, line, "| Button"))
        {
            row_count += 1;
        }
    }
    try std.testing.expectEqual(btn_count, row_count);
}

test "generateDevicePage no WASM section when absent" {
    const allocator = std.testing.allocator;
    const parsed = try device.parseString(allocator, test_toml);
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);

    try generateDevicePage(&parsed.value, "sony", buf.writer(allocator));

    const out = buf.items;
    try std.testing.expect(std.mem.indexOf(u8, out, "WASM") == null);
}

test "outputFilename derives vendor-slug" {
    const allocator = std.testing.allocator;
    const fname = try outputFilename(allocator, "devices/sony/dualsense.toml", "Sony DualSense");
    defer allocator.free(fname);
    try std.testing.expectEqualStrings("sony-sony-dualsense.md", fname);
}
