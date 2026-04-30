const std = @import("std");
const posix = std.posix;
const paths = @import("../../config/paths.zig");
const scan_mod = @import("../scan.zig");
const mapping = @import("../../config/mapping.zig");

const presets = [_][]const u8{ "xbox-360", "xbox-elite2", "dualsense", "switch-pro" };
const templates = [_][]const u8{ "default", "fps", "racing", "fighting" };

fn ensureMappingsDir(abs_path: []const u8) !void {
    try std.fs.cwd().makePath(abs_path);
}

fn print(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    buf.writer(allocator).print(fmt, args) catch {};
    _ = posix.write(posix.STDOUT_FILENO, buf.items) catch 0;
    buf.clearRetainingCapacity();
}

fn readLine(buf: []u8) ![]u8 {
    var len: usize = 0;
    while (len < buf.len) {
        var c: [1]u8 = undefined;
        const n = posix.read(posix.STDIN_FILENO, &c) catch return error.ReadError;
        if (n == 0) return error.EndOfInput;
        if (c[0] == '\n') break;
        buf[len] = c[0];
        len += 1;
    }
    // Trim in-place: shift trimmed slice to start of buf
    const trimmed = std.mem.trim(u8, buf[0..len], " \r\t");
    const tlen = trimmed.len;
    if (tlen > 0 and trimmed.ptr != buf.ptr) {
        std.mem.copyForwards(u8, buf[0..tlen], trimmed);
    }
    return buf[0..tlen];
}

fn chooseFromList(
    allocator: std.mem.Allocator,
    pbuf: *std.ArrayList(u8),
    label: []const u8,
    items: []const []const u8,
    input_buf: []u8,
) !usize {
    print(allocator, pbuf, "{s}:\n", .{label});
    for (items, 0..) |item, i| {
        print(allocator, pbuf, "  {d}) {s}\n", .{ i + 1, item });
    }
    while (true) {
        print(allocator, pbuf, "Choice [1-{d}]: ", .{items.len});
        const raw = try readLine(input_buf);
        const n = std.fmt.parseInt(usize, raw, 10) catch continue;
        if (n >= 1 and n <= items.len) return n - 1;
    }
}

fn templateContent(idx: usize) []const u8 {
    return switch (idx) {
        0 =>
        \\# Preset: default — pass-through, no remapping
        \\
        ,
        1 =>
        \\# Preset: fps — hold RB to activate gyro mouse
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "RB"
        \\activation = "hold"
        \\
        \\[layer.stick_right]
        \\mode = "mouse"
        \\sensitivity = 1.5
        \\
        ,
        2 =>
        \\# Preset: racing — triggers as accelerate/brake
        \\
        ,
        3 =>
        \\# Preset: fighting — d-pad as arrows
        \\
        \\[dpad]
        \\mode = "arrows"
        \\
        ,
        else =>
        \\
        ,
    };
}

fn formatGuidance(allocator: std.mem.Allocator, safe_name: []const u8, device_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\
        \\Next steps:
        \\  padctl switch {s}              activate this mapping now
        \\  Or add to ~/.config/padctl/config.toml:
        \\    [[device]]
        \\    name = "{s}"
        \\    default_mapping = "{s}"
        \\
    , .{ safe_name, device_name, safe_name });
}

pub fn run(allocator: std.mem.Allocator, device_arg: ?[]const u8, preset_arg: ?[]const u8) !void {
    var pbuf: std.ArrayList(u8) = .{};
    defer pbuf.deinit(allocator);

    var input_buf: [256]u8 = undefined;

    // Determine device name
    var device_name: []const u8 = undefined;
    var device_name_owned = false;
    if (device_arg) |d| {
        device_name = d;
    } else {
        var scan_dir_owned = false;
        const scan_dir: []const u8 = blk: {
            const dev_dirs = paths.resolveDeviceConfigDirs(allocator) catch break :blk "/usr/share/padctl/devices";
            defer paths.freeConfigDirs(allocator, dev_dirs);
            const duped = allocator.dupe(u8, dev_dirs[2]) catch break :blk "/usr/share/padctl/devices";
            scan_dir_owned = true;
            break :blk duped;
        };
        defer if (scan_dir_owned) allocator.free(@constCast(scan_dir));

        const entries: []scan_mod.ScanEntry = scan_mod.scan(allocator, scan_dir) catch blk2: {
            break :blk2 try allocator.alloc(scan_mod.ScanEntry, 0);
        };
        defer scan_mod.freeEntries(allocator, entries);

        if (entries.len == 0) {
            print(allocator, &pbuf, "No HID devices found. Enter device name manually: ", .{});
            const raw = try readLine(&input_buf);
            device_name = try allocator.dupe(u8, raw);
            device_name_owned = true;
        } else {
            var dev_names = try allocator.alloc([]const u8, entries.len);
            defer allocator.free(dev_names);
            for (entries, 0..) |e, i| dev_names[i] = e.name;

            const idx = try chooseFromList(allocator, &pbuf, "Connected devices", dev_names, &input_buf);
            device_name = try allocator.dupe(u8, entries[idx].name);
            device_name_owned = true;
        }
    }
    defer if (device_name_owned) allocator.free(device_name);

    // Sanitize device name for filename
    var safe_buf = try allocator.alloc(u8, device_name.len);
    defer allocator.free(safe_buf);
    for (device_name, 0..) |c, i| {
        safe_buf[i] = if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_') std.ascii.toLower(c) else '-';
    }
    var safe = std.mem.trim(u8, safe_buf, "-");
    if (safe.len == 0) safe = "device";

    // Determine preset
    var preset_idx: usize = 0;
    if (preset_arg) |p| {
        var found = false;
        for (presets, 0..) |name, i| {
            if (std.mem.eql(u8, name, p)) {
                preset_idx = i;
                found = true;
                break;
            }
        }
        if (!found) {
            _ = posix.write(posix.STDERR_FILENO, "error: unknown preset\n") catch 0;
            return error.UnknownPreset;
        }
    } else {
        preset_idx = try chooseFromList(allocator, &pbuf, "Output preset", &presets, &input_buf);
    }

    // Determine template
    const tmpl_idx = try chooseFromList(allocator, &pbuf, "Mapping template", &templates, &input_buf);

    // Resolve output path
    const user_dir = try paths.userConfigDir(allocator);
    defer allocator.free(user_dir);

    const mappings_dir = try std.fmt.allocPrint(allocator, "{s}/mappings", .{user_dir});
    defer allocator.free(mappings_dir);

    ensureMappingsDir(mappings_dir) catch |e| {
        std.log.err("config init: failed to create {s}: {}", .{ mappings_dir, e });
        return e;
    };

    const out_path = try std.fmt.allocPrint(allocator, "{s}/{s}.toml", .{ mappings_dir, safe });
    defer allocator.free(out_path);

    // Build content
    var content_buf: std.ArrayList(u8) = .{};
    defer content_buf.deinit(allocator);
    const cw = content_buf.writer(allocator);
    try cw.print("# Generated by padctl config init\n", .{});
    try cw.print("# Device: {s}\n", .{device_name});
    try cw.print("# Preset: {s}\n\n", .{presets[preset_idx]});
    try cw.writeAll(templateContent(tmpl_idx));

    const file = try std.fs.createFileAbsolute(out_path, .{});
    defer file.close();
    try file.writeAll(content_buf.items);

    print(allocator, &pbuf, "\nCreated: {s}\n", .{out_path});

    // Validate as mapping config (parse + semantic checks).
    if (mapping.parseFile(allocator, out_path)) |res| {
        defer res.deinit();
        if (mapping.validate(&res.value)) {
            print(allocator, &pbuf, "Validation: OK\n", .{});
        } else |err| {
            print(allocator, &pbuf, "Validation warning: {}\n", .{err});
        }
    } else |err| {
        print(allocator, &pbuf, "Validation warning: {}\n", .{err});
    }

    const guidance = try formatGuidance(allocator, safe, device_name);
    defer allocator.free(guidance);
    _ = posix.write(posix.STDOUT_FILENO, guidance) catch 0;
}

// --- tests ---

test "init: mapping template content is non-empty" {
    for (0..templates.len) |i| {
        const c = templateContent(i);
        try std.testing.expect(c.len > 0);
    }
}

test "init: safe name sanitization" {
    const device = "Flydigi Vader 5 Pro";
    const allocator = std.testing.allocator;
    var safe_buf = try allocator.alloc(u8, device.len);
    defer allocator.free(safe_buf);
    for (device, 0..) |c, i| {
        safe_buf[i] = if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_') std.ascii.toLower(c) else '-';
    }
    const safe = std.mem.trim(u8, safe_buf, "-");
    try std.testing.expect(safe.len > 0);
    try std.testing.expectEqual(@as(?usize, null), std.mem.indexOf(u8, safe, " "));
}

test "init: ensureMappingsDir creates missing parent dirs" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var tmp_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_abs = try tmp.dir.realpath(".", &tmp_path_buf);

    const mappings = try std.fmt.allocPrint(allocator, "{s}/deep/nested/absent/mappings", .{tmp_abs});
    defer allocator.free(mappings);

    try ensureMappingsDir(mappings);

    try std.fs.accessAbsolute(mappings, .{});
}

test "init: formatGuidance contains expected substrings" {
    const allocator = std.testing.allocator;
    const guidance = try formatGuidance(allocator, "vader-5-pro", "Vader 5 Pro");
    defer allocator.free(guidance);

    try std.testing.expect(std.mem.indexOf(u8, guidance, "padctl switch vader-5-pro") != null);
    try std.testing.expect(std.mem.indexOf(u8, guidance, "name = \"Vader 5 Pro\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, guidance, "default_mapping = \"vader-5-pro\"") != null);
}

// Build the same TOML that run() emits, given a preset and template index.
fn buildGeneratedToml(
    allocator: std.mem.Allocator,
    device_name: []const u8,
    preset: []const u8,
    tmpl_idx: usize,
) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.print("# Generated by padctl config init\n", .{});
    try w.print("# Device: {s}\n", .{device_name});
    try w.print("# Preset: {s}\n\n", .{preset});
    try w.writeAll(templateContent(tmpl_idx));
    return buf.toOwnedSlice(allocator);
}

test "init: every (preset, template) combination round-trips through mapping.validate (issue #53)" {
    const allocator = std.testing.allocator;
    const mapping_mod = @import("../../config/mapping.zig");

    for (presets) |preset| {
        for (0..templates.len) |tmpl_idx| {
            const content = try buildGeneratedToml(allocator, "Test Device", preset, tmpl_idx);
            defer allocator.free(content);

            const parsed = mapping_mod.parseString(allocator, content) catch |err| {
                std.debug.print("preset={s} template={s} parse failed: {}\n", .{ preset, templates[tmpl_idx], err });
                return err;
            };
            defer parsed.deinit();
            mapping_mod.validate(&parsed.value) catch |err| {
                std.debug.print("preset={s} template={s} validate failed: {}\n", .{ preset, templates[tmpl_idx], err });
                return err;
            };
        }
    }
}

test "init: every (preset, template) round-trips through tools.validate.validateFile (issue #53)" {
    const allocator = std.testing.allocator;
    const validate_mod = @import("../../tools/validate.zig");

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_abs = try tmp.dir.realpath(".", &buf);

    for (presets) |preset| {
        for (0..templates.len) |tmpl_idx| {
            const content = try buildGeneratedToml(allocator, "Test Device", preset, tmpl_idx);
            defer allocator.free(content);

            const filename = try std.fmt.allocPrint(allocator, "{s}-{d}.toml", .{ preset, tmpl_idx });
            defer allocator.free(filename);
            try tmp.dir.writeFile(.{ .sub_path = filename, .data = content });

            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_abs, filename });
            defer allocator.free(path);

            const errors = try validate_mod.validateFile(path, allocator);
            defer validate_mod.freeErrors(errors, allocator);
            if (errors.len > 0) {
                for (errors) |e| std.debug.print("preset={s} template={s}: {s}\n", .{ preset, templates[tmpl_idx], e.message });
            }
            try std.testing.expectEqual(@as(usize, 0), errors.len);
        }
    }
}
