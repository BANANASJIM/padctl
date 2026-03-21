const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const interpreter = @import("../core/interpreter.zig");
const state = @import("../core/state.zig");
const ButtonId = state.ButtonId;

const devices_dir = "devices/";

fn collectTomlPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit();
    }

    var dir = std.fs.cwd().openDir(devices_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return paths,
        else => return err,
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".toml")) continue;
        const full = try std.fmt.allocPrint(allocator, "{s}{s}", .{ devices_dir, entry.path });
        try paths.append(full);
    }

    return paths;
}

fn freeTomlPaths(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8)) void {
    for (paths.items) |p| allocator.free(p);
    paths.deinit();
}

// Metadata/raw fields that intentionally map to .unknown
const field_ignore_list = [_][]const u8{
    "battery_raw",
    "paddle_raw",
    "left_x_raw",
    "left_y_raw",
    "right_x_raw",
    "right_y_raw",
    "sensor_timestamp",
    "touch0_contact",
    "touch1_contact",
};

fn isIgnoredField(name: []const u8) bool {
    for (field_ignore_list) |ignored| {
        if (std.mem.eql(u8, name, ignored)) return true;
    }
    return false;
}

test "auto: all device configs parse and validate" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);

    if (paths.items.len == 0) return; // devices/ not found

    try testing.expect(paths.items.len >= 12);

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch |err| {
            std.debug.print("FAIL parse: {s}: {}\n", .{ path, err });
            return err;
        };
        defer parsed.deinit();

        const cfg = &parsed.value;
        try testing.expect(cfg.device.name.len > 0);
        try testing.expect(cfg.report.len >= 1);

        for (cfg.report) |report| {
            try testing.expect(report.size > 0);
        }
    }
}

test "auto: all field names map to known FieldTag" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);

    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        // Skip generic-mode devices — field names are arbitrary
        if (parsed.value.device.mode) |m| {
            if (std.mem.eql(u8, m, "generic")) continue;
        }

        for (parsed.value.report) |report| {
            if (report.fields) |fields| {
                var it = fields.map.iterator();
                while (it.next()) |entry| {
                    const name = entry.key_ptr.*;
                    if (isIgnoredField(name)) continue;
                    const tag = interpreter.parseFieldTag(name);
                    if (tag == .unknown) {
                        std.debug.print("FAIL FieldTag: {s} field '{s}' -> .unknown\n", .{ path, name });
                        return error.TestUnexpectedResult;
                    }
                }
            }
        }
    }
}

test "auto: all button_group keys are valid ButtonId" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);

    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        // Skip generic-mode devices — button names are arbitrary
        if (parsed.value.device.mode) |m| {
            if (std.mem.eql(u8, m, "generic")) continue;
        }

        for (parsed.value.report) |report| {
            if (report.button_group) |bg| {
                var it = bg.map.map.iterator();
                while (it.next()) |entry| {
                    const name = entry.key_ptr.*;
                    if (std.meta.stringToEnum(ButtonId, name) == null) {
                        std.debug.print("FAIL ButtonId: {s} button '{s}' invalid\n", .{ path, name });
                        return error.TestUnexpectedResult;
                    }
                }
            }
        }
    }
}
