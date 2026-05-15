const std = @import("std");
const user_config_mod = @import("../../config/user_config.zig");
const config_device = @import("../../config/device.zig");
const plan_mod = @import("plan.zig");
const udev = @import("udev.zig");
const InstallPlan = plan_mod.InstallPlan;
const ensureDirAll = plan_mod.ensureDirAll;
const dirExistsAbsolute = plan_mod.dirExistsAbsolute;
const isValidIdentifier = udev.isValidIdentifier;

pub const ConflictMode = enum {
    skip,
    force,
    interactive,
};

pub const PromptResult = enum { keep, overwrite, abort };

pub const PromptFn = *const fn (
    config_path: []const u8,
    device_name: []const u8,
    existing_map: []const u8,
    proposed_map: []const u8,
) PromptResult;

pub fn stdinPrompt(
    config_path: []const u8,
    device_name: []const u8,
    existing_map: []const u8,
    proposed_map: []const u8,
) PromptResult {
    _ = std.posix.write(std.posix.STDERR_FILENO, "\nConflict: ") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, config_path) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\n  existing: \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, device_name) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\" -> \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, existing_map) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\"\n  proposed: \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, device_name) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\" -> \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, proposed_map) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\"\n  [k]eep existing / [o]verwrite with backup / [a]bort (default: k): ") catch {};

    var buf: [16]u8 = undefined;
    const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
    const choice: u8 = if (n > 0) buf[0] else 'k';
    return switch (choice) {
        'o', 'O' => .overwrite,
        'a', 'A' => .abort,
        else => .keep,
    };
}

pub fn findMappingsSourceDir(allocator: std.mem.Allocator, self_dir: []const u8, cwd_override: ?[]const u8) !?[]u8 {
    const sibling = try std.fmt.allocPrint(allocator, "{s}/mappings", .{self_dir});
    defer allocator.free(sibling);
    if (dirExistsAbsolute(sibling)) return try allocator.dupe(u8, sibling);

    var parent = self_dir;
    while (std.fs.path.dirname(parent)) |next| {
        parent = next;
        const candidate = try std.fmt.allocPrint(allocator, "{s}/mappings", .{parent});
        defer allocator.free(candidate);
        if (dirExistsAbsolute(candidate)) return try allocator.dupe(u8, candidate);
        if (std.mem.eql(u8, parent, "/")) break;
    }

    const cwd = cwd_override orelse try std.process.getCwdAlloc(allocator);
    defer if (cwd_override == null) allocator.free(cwd);
    const cwd_candidate = try std.fmt.allocPrint(allocator, "{s}/mappings", .{cwd});
    defer allocator.free(cwd_candidate);
    if (dirExistsAbsolute(cwd_candidate)) return try allocator.dupe(u8, cwd_candidate);

    return null;
}

pub fn installMapping(allocator: std.mem.Allocator, name: []const u8, destdir: []const u8, src_dir: []const u8, force: bool) !void {
    if (!isValidIdentifier(name)) return error.InvalidArgument;

    const src_flat = try std.fmt.allocPrint(allocator, "{s}/{s}.toml", .{ src_dir, name });
    defer allocator.free(src_flat);
    const src_nested = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}.toml", .{ src_dir, name, name });
    defer allocator.free(src_nested);

    const src_path: []const u8 = blk: {
        if (std.fs.accessAbsolute(src_flat, .{})) |_| {
            break :blk src_flat;
        } else |_| {}
        if (std.fs.accessAbsolute(src_nested, .{})) |_| {
            break :blk src_nested;
        } else |_| {}
        return error.FileNotFound;
    };

    const target_dir = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings", .{destdir});
    defer allocator.free(target_dir);
    try ensureDirAll(allocator, target_dir);

    const target_path = try std.fmt.allocPrint(allocator, "{s}/{s}.toml", .{ target_dir, name });
    defer allocator.free(target_path);

    if (!force) {
        if (std.fs.accessAbsolute(target_path, .{})) |_| {
            return;
        } else |_| {}
    }

    {
        var src_f = try std.fs.openFileAbsolute(src_path, .{});
        defer src_f.close();
        const data = try src_f.readToEndAlloc(allocator, 1 << 20);
        defer allocator.free(data);
        var dst_f = try std.fs.createFileAbsolute(target_path, .{ .truncate = true });
        defer dst_f.close();
        try dst_f.writeAll(data);
    }
}

/// Walk `devices_dir` looking for `*/mapping_name.toml`. If exactly one match
/// is found, parse it and return `device.name`. Returns null on zero or
/// multiple matches (logs an error for ambiguity). Caller owns result.
pub fn findDeviceNameForMapping(
    allocator: std.mem.Allocator,
    mapping_name: []const u8,
    devices_dir: []const u8,
) !?[]const u8 {
    var dir = std.fs.cwd().openDir(devices_dir, .{ .iterate = true }) catch return null;
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var match_path: ?[]u8 = null;
    defer if (match_path) |p| allocator.free(p);
    var match_count: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;

        const stem = entry.basename[0 .. entry.basename.len - 5];
        if (!std.mem.eql(u8, stem, mapping_name)) continue;

        match_count += 1;
        if (match_count == 1) {
            match_path = try allocator.dupe(u8, entry.path);
        } else {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: multiple device configs match mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, "', skipping binding\n") catch {};
            return null;
        }
    }

    if (match_count == 0 or match_path == null) return null;

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ devices_dir, match_path.? });
    const parsed = config_device.parseFile(allocator, full_path) catch return null;
    defer parsed.deinit();
    return try allocator.dupe(u8, parsed.value.device.name);
}

/// Write (or update) a device→mapping binding in `{destdir}/etc/padctl/config.toml`.
/// PR #168 audit V1: the underlying writeAtomic + escapeTomlString chain
/// hard-rejects control chars in `device_name`, surfacing as
/// error.InvalidDeviceName. Do not bypass.
pub fn writeBinding(
    allocator: std.mem.Allocator,
    destdir: []const u8,
    device_name: []const u8,
    mapping_name: []const u8,
    conflict_mode: ConflictMode,
    prompt_fn: PromptFn,
) !void {
    const etc_dir = try std.fmt.allocPrint(allocator, "{s}/etc/padctl", .{destdir});
    defer allocator.free(etc_dir);
    try ensureDirAll(allocator, etc_dir);

    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{etc_dir});
    defer allocator.free(config_path);

    var existing = user_config_mod.loadFromDir(allocator, etc_dir) catch |err| switch (err) {
        error.MalformedConfig => {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: ") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, config_path) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, " is malformed — fix or remove it before installing bindings\n") catch {};
            return error.MalformedConfig;
        },
    };
    defer if (existing) |*e| e.deinit();

    const version: i64 = if (existing) |e| e.value.version orelse user_config_mod.CURRENT_VERSION else user_config_mod.CURRENT_VERSION;
    const devices = if (existing) |e| e.value.device else null;

    if (devices) |devs| {
        for (devs) |d| {
            if (std.ascii.eqlIgnoreCase(d.name, device_name)) {
                if (d.default_mapping) |m| {
                    if (std.mem.eql(u8, m, mapping_name)) return;
                }
                const existing_map = d.default_mapping orelse "(none)";
                switch (conflict_mode) {
                    .skip => {
                        std.log.warn("binding conflict: {s} already has \"{s}\" -> \"{s}\". Use --force-binding to overwrite.", .{ config_path, device_name, existing_map });
                        return;
                    },
                    .interactive => {
                        switch (prompt_fn(config_path, device_name, existing_map, mapping_name)) {
                            .overwrite => {},
                            .abort => return error.Aborted,
                            .keep => return,
                        }
                    },
                    .force => {},
                }
                break;
            }
        }
    }

    if (existing != null and (conflict_mode == .force or conflict_mode == .interactive)) {
        backupFile(allocator, config_path) catch |err| {
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "error: cannot create backup of {s}: {}, aborting overwrite\n", .{ config_path, err }) catch "error: backup failed, aborting\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
            return err;
        };
    }

    var has_target = false;
    if (devices) |devs| {
        for (devs) |d| {
            if (std.ascii.eqlIgnoreCase(d.name, device_name)) {
                has_target = true;
                break;
            }
        }
    }
    const old_count = if (devices) |d| d.len else 0;
    const new_count = if (has_target) old_count else old_count + 1;
    var new_devices = try allocator.alloc(user_config_mod.DeviceEntry, new_count);
    defer allocator.free(new_devices);

    var idx: usize = 0;
    if (devices) |devs| {
        for (devs) |d| {
            if (std.ascii.eqlIgnoreCase(d.name, device_name)) {
                new_devices[idx] = .{ .name = device_name, .default_mapping = mapping_name };
            } else {
                new_devices[idx] = d;
            }
            idx += 1;
        }
    }
    if (!has_target) {
        new_devices[idx] = .{ .name = device_name, .default_mapping = mapping_name };
    }

    const cfg = user_config_mod.UserConfig{
        .version = version,
        .device = new_devices,
        .diagnostics = if (existing) |e| e.value.diagnostics else .{},
        .supervisor = if (existing) |e| e.value.supervisor else .{},
        .chord_switch = if (existing) |e| e.value.chord_switch else null,
    };
    try user_config_mod.writeAtomic(allocator, config_path, &cfg);
}

/// Copy `path` to `path.bak.YYYYMMDD-HHMMSS`. Returns an error if the backup
/// cannot be created — caller must abort the overwrite.
pub fn backupFile(allocator: std.mem.Allocator, file_path: []const u8) !void {
    const now = std.time.timestamp();
    const epoch_secs: std.time.epoch.EpochSeconds = .{ .secs = @intCast(now) };
    const day = epoch_secs.getEpochDay().calculateYearDay();
    const year_day = day.calculateMonthDay();
    const day_secs = epoch_secs.getDaySeconds();
    const year: u16 = day.year;
    const month: u8 = @intFromEnum(year_day.month);
    const dom: u8 = year_day.day_index + 1;
    const hours: u8 = @intCast(day_secs.getHoursIntoDay());
    const minutes: u8 = @intCast(day_secs.getMinutesIntoHour());
    const seconds: u8 = @intCast(day_secs.getSecondsIntoMinute());

    const bak_path = try std.fmt.allocPrint(allocator, "{s}.bak.{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}", .{
        file_path, year, month, dom, hours, minutes, seconds,
    });
    defer allocator.free(bak_path);

    const data = try std.fs.cwd().readFileAlloc(allocator, file_path, 256 * 1024);
    defer allocator.free(data);
    var f = try std.fs.createFileAbsolute(bak_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(data);

    std.log.info("backup: {s}", .{bak_path});
}

pub fn installMappings(
    allocator: std.mem.Allocator,
    plan: *const InstallPlan,
    self_dir: []const u8,
    installed_mappings: *std.ArrayList([]const u8),
) !bool {
    if (plan.opts.mappings.len == 0) return false;
    const mappings_src = findMappingsSourceDir(allocator, self_dir, null) catch null;
    defer if (mappings_src) |path| allocator.free(path);
    if (mappings_src == null) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: mappings directory not found near executable or current working directory\n") catch {};
        return true;
    }
    var failed = false;
    for (plan.opts.mappings) |mapping_name| {
        installMapping(allocator, mapping_name, plan.opts.destdir, mappings_src.?, plan.opts.force_mapping) catch |err| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "' not installed: {}\n", .{err}) catch "' not installed\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
            failed = true;
            continue;
        };
        installed_mappings.append(allocator, mapping_name) catch {};
    }
    return failed;
}

pub fn installBindings(
    allocator: std.mem.Allocator,
    plan: *const InstallPlan,
    self_dir: []const u8,
    installed_mappings: []const []const u8,
) !bool {
    const devices_src = udev.findDevicesSourceDir(allocator, self_dir, null) catch null;
    defer if (devices_src) |path| allocator.free(path);
    if (devices_src == null) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: devices directory not found, cannot resolve device bindings\n") catch {};
        return true;
    }
    var failed = false;
    for (installed_mappings) |mapping_name| {
        const device_name = findDeviceNameForMapping(allocator, mapping_name, devices_src.?) catch null;
        defer if (device_name) |n| allocator.free(n);
        if (device_name) |name| {
            const mode: ConflictMode = if (plan.opts.force_binding)
                .force
            else if (std.posix.isatty(std.posix.STDIN_FILENO))
                .interactive
            else
                .skip;
            writeBinding(allocator, plan.opts.destdir, name, mapping_name, mode, stdinPrompt) catch |err| {
                var errbuf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&errbuf, "error: could not write binding for \"{s}\": {}\n", .{ mapping_name, err }) catch "error: binding write failed\n";
                _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
                failed = true;
            };
        } else {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: no device config found for mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, "', binding not written\n") catch {};
            failed = true;
        }
    }
    return failed;
}
