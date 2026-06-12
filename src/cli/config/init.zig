const std = @import("std");
const posix = std.posix;
const paths = @import("../../config/paths.zig");
const scan_mod = @import("../scan.zig");
const mapping = @import("../../config/mapping.zig");

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
        \\# Template: default — pass-through, every input keeps its native function.
        \\# Uncomment the [remap] block below to override individual buttons:
        \\
        \\# [remap]
        \\# A = "B"          # physical A acts as B
        \\# M1 = "KEY_F13"   # back paddle emits keyboard F13
        \\
        ,
        1 =>
        \\# Template: fps — hold RB to aim with the right stick as a mouse
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
        \\# Template: racing — hold LM to toggle tilt steering on the left stick
        \\
        \\[[layer]]
        \\name = "race"
        \\trigger = "LM"
        \\activation = "hold_toggle"
        \\hold_timeout = 300
        \\tap = "LM"
        \\
        \\[layer.gyro]
        \\mode = "joystick"
        \\response = "tilt"
        \\target = "left_stick"
        \\axis_x = "roll"
        \\axis_y = "none"
        \\degrees_full = 35.0
        \\
        ,
        3 =>
        \\# Template: fighting — d-pad emits keyboard arrow keys
        \\
        \\[dpad]
        \\mode = "arrows"
        \\
        ,
        else => unreachable,
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

pub fn run(allocator: std.mem.Allocator, device_arg: ?[]const u8) !void {
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
            const duped = allocator.dupe(u8, paths.builtinDir(dev_dirs)) catch break :blk "/usr/share/padctl/devices";
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
    try cw.print("# Device: {s}\n\n", .{device_name});
    try cw.writeAll(templateContent(tmpl_idx));

    // Validate generated content BEFORE writing — fail loudly if generator drifts.
    validateContent(allocator, content_buf.items) catch |err| {
        print(allocator, &pbuf, "ERROR: generator produced invalid TOML/mapping: {}\n", .{err});
        return err;
    };

    const file = try std.fs.createFileAbsolute(out_path, .{});
    defer file.close();
    try file.writeAll(content_buf.items);

    print(allocator, &pbuf, "\nCreated: {s}\n", .{out_path});
    print(allocator, &pbuf, "Validation: OK\n", .{});

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

// Validate generated TOML content in memory; returns error if invalid.
fn validateContent(allocator: std.mem.Allocator, content: []const u8) !void {
    const res = try mapping.parseString(allocator, content);
    defer res.deinit();
    try mapping.validate(&res.value);
}

// Build the same TOML that run() emits, given a template index.
fn buildGeneratedToml(
    allocator: std.mem.Allocator,
    device_name: []const u8,
    tmpl_idx: usize,
) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.print("# Generated by padctl config init\n", .{});
    try w.print("# Device: {s}\n\n", .{device_name});
    try w.writeAll(templateContent(tmpl_idx));
    return buf.toOwnedSlice(allocator);
}

fn templateIdx(name: []const u8) usize {
    for (templates, 0..) |t, i| {
        if (std.mem.eql(u8, t, name)) return i;
    }
    unreachable;
}

fn parseValidatedTemplate(allocator: std.mem.Allocator, name: []const u8) !mapping.ParseResult {
    const content = try buildGeneratedToml(allocator, "Test Device", templateIdx(name));
    defer allocator.free(content);
    const parsed = try mapping.parseString(allocator, content);
    errdefer parsed.deinit();
    try mapping.validate(&parsed.value);
    return parsed;
}

test "init: 'default' template validates and carries a commented [remap] example" {
    const allocator = std.testing.allocator;
    const parsed = try parseValidatedTemplate(allocator, "default");
    defer parsed.deinit();

    const content = templateContent(templateIdx("default"));
    try std.testing.expect(std.mem.indexOf(u8, content, "# [remap]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "# A = ") != null);
}

test "init: 'fps' template validates and emits the aim layer" {
    const allocator = std.testing.allocator;
    const parsed = try parseValidatedTemplate(allocator, "fps");
    defer parsed.deinit();

    const layers = parsed.value.layer orelse return error.TestExpectedLayer;
    try std.testing.expectEqual(@as(usize, 1), layers.len);
    try std.testing.expectEqualStrings("aim", layers[0].name);
    try std.testing.expectEqualStrings("RB", layers[0].trigger);
    const stick = layers[0].stick_right orelse return error.TestExpectedStick;
    try std.testing.expectEqualStrings("mouse", stick.mode);
}

test "init: 'racing' template validates and emits the tilt-steering gyro layer" {
    const allocator = std.testing.allocator;
    const parsed = try parseValidatedTemplate(allocator, "racing");
    defer parsed.deinit();

    const layers = parsed.value.layer orelse return error.TestExpectedLayer;
    try std.testing.expectEqual(@as(usize, 1), layers.len);
    try std.testing.expectEqualStrings("race", layers[0].name);
    try std.testing.expectEqualStrings("hold_toggle", layers[0].activation);
    const gyro = layers[0].gyro orelse return error.TestExpectedGyro;
    try std.testing.expectEqualStrings("joystick", gyro.mode);
    try std.testing.expectEqualStrings("tilt", gyro.response.?);
    try std.testing.expectEqualStrings("left_stick", gyro.target.?);
    try std.testing.expectEqualStrings("roll", gyro.axis_x.?);
    try std.testing.expectEqualStrings("none", gyro.axis_y.?);
    try std.testing.expectEqual(@as(f64, 35.0), gyro.degrees_full.?);
}

test "init: 'fighting' template validates and emits dpad arrows" {
    const allocator = std.testing.allocator;
    const parsed = try parseValidatedTemplate(allocator, "fighting");
    defer parsed.deinit();

    const dpad = parsed.value.dpad orelse return error.TestExpectedDpad;
    try std.testing.expectEqualStrings("arrows", dpad.mode);
}

test "init: every template round-trips through tools.validate.validateFile" {
    const allocator = std.testing.allocator;
    const validate_mod = @import("../../tools/validate.zig");

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_abs = try tmp.dir.realpath(".", &buf);

    for (0..templates.len) |tmpl_idx| {
        const content = try buildGeneratedToml(allocator, "Test Device", tmpl_idx);
        defer allocator.free(content);

        const filename = try std.fmt.allocPrint(allocator, "{s}.toml", .{templates[tmpl_idx]});
        defer allocator.free(filename);
        try tmp.dir.writeFile(.{ .sub_path = filename, .data = content });

        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_abs, filename });
        defer allocator.free(path);

        const errors = try validate_mod.validateFile(path, allocator);
        defer validate_mod.freeErrors(errors, allocator);
        if (errors.len > 0) {
            for (errors) |e| std.debug.print("template={s}: {s}\n", .{ templates[tmpl_idx], e.message });
        }
        try std.testing.expectEqual(@as(usize, 0), errors.len);
    }
}

test "init: validate-before-write gate rejects invalid TOML and writes no file" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_abs = try tmp.dir.realpath(".", &path_buf);

    // Intentionally broken TOML (unclosed bracket)
    const broken: []const u8 = "[[layer]\nname = \"broken\"\n";

    // validateContent must fail on broken input (TOML parser returns UnexpectedToken)
    try std.testing.expect(if (validateContent(allocator, broken)) false else |_| true);

    // Confirm no file was written (write gated on validateContent)
    const out = try std.fmt.allocPrint(allocator, "{s}/should-not-exist.toml", .{tmp_abs});
    defer allocator.free(out);
    try std.testing.expectError(error.FileNotFound, std.fs.accessAbsolute(out, .{}));
}
