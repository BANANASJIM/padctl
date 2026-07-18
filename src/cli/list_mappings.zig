const std = @import("std");
const mapping_discovery = @import("../config/mapping_discovery.zig");
const MappingProfile = mapping_discovery.MappingProfile;
const Source = mapping_discovery.Source;

fn lessName(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn padRight(buf: []u8, s: []const u8, width: usize) []const u8 {
    const len = @min(s.len, width);
    @memcpy(buf[0..len], s[0..len]);
    @memset(buf[len..width], ' ');
    return buf[0..width];
}

fn sourceLabel(source: Source) []const u8 {
    return switch (source) {
        .user => "user",
        .system => "system",
        .package => "package",
    };
}

pub fn run(allocator: std.mem.Allocator, extra_dir: ?[]const u8, writer: anytype) !void {
    const profiles = try mapping_discovery.discoverMappings(allocator);
    defer mapping_discovery.freeProfiles(allocator, profiles);

    if (profiles.len == 0 and extra_dir == null) {
        try writer.writeAll("No mapping profiles found.\n");
        return;
    }

    const name_w = 24;
    const source_w = 8;
    var pad: [name_w + source_w]u8 = undefined;

    try writer.print("{s} {s} {s}\n", .{
        padRight(pad[0..name_w], "NAME", name_w),
        padRight(pad[name_w..], "SOURCE", source_w),
        "PATH",
    });
    try writer.writeByteNTimes('-', name_w + 1 + source_w + 1 + 40);
    try writer.writeByte('\n');

    for (profiles) |p| {
        var row_pad: [name_w + source_w]u8 = undefined;
        try writer.print("{s} {s} {s}\n", .{
            padRight(row_pad[0..name_w], p.name, name_w),
            padRight(row_pad[name_w..], sourceLabel(p.source), source_w),
            p.path,
        });
    }

    if (extra_dir) |dir| {
        try writer.print("\nDevice mappings ({s}):\n", .{dir});
        var d = if (std.fs.path.isAbsolute(dir))
            std.fs.openDirAbsolute(dir, .{ .iterate = true }) catch {
                try writer.writeAll("  (directory not found)\n");
                return;
            }
        else
            std.fs.cwd().openDir(dir, .{ .iterate = true }) catch {
                try writer.writeAll("  (directory not found)\n");
                return;
            };
        defer d.close();

        var found = false;
        var it = d.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
            try writer.print("  {s}\n", .{entry.name});
            found = true;
        }
        if (!found) try writer.writeAll("  (none)\n");
    }

    try writer.print("\n{d} mapping(s) found.\n", .{profiles.len});
}

fn writeNames(
    allocator: std.mem.Allocator,
    profiles: []const MappingProfile,
    extra_dir: ?[]const u8,
    writer: anytype,
) !void {
    var names: std.ArrayList([]const u8) = .{};
    defer names.deinit(allocator);
    var owned_extra_names: std.ArrayList([]u8) = .{};
    defer {
        for (owned_extra_names.items) |name| allocator.free(name);
        owned_extra_names.deinit(allocator);
    }
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    for (profiles) |profile| {
        if (seen.contains(profile.name)) continue;
        try names.append(allocator, profile.name);
        try seen.put(profile.name, {});
    }

    if (extra_dir) |dir_path| {
        var dir = if (std.fs.path.isAbsolute(dir_path))
            try std.fs.openDirAbsolute(dir_path, .{ .iterate = true })
        else
            try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
            const name = entry.name[0 .. entry.name.len - ".toml".len];
            if (seen.contains(name)) continue;
            const owned_name = try allocator.dupe(u8, name);
            owned_extra_names.append(allocator, owned_name) catch |err| {
                allocator.free(owned_name);
                return err;
            };
            try names.append(allocator, owned_name);
            try seen.put(owned_name, {});
        }
    }

    std.mem.sort([]const u8, names.items, {}, lessName);
    for (names.items) |name| {
        if (std.mem.indexOfScalar(u8, name, '\n') != null) continue;
        try writer.print("{s}\n", .{name});
    }
}

/// Stable, machine-readable mapping names for shell completion and scripts.
/// XDG profiles and optional config-directory TOML basenames are deduplicated,
/// sorted, and emitted one per line. Table output is intentionally omitted.
pub fn runNames(allocator: std.mem.Allocator, extra_dir: ?[]const u8, writer: anytype) !void {
    const profiles = try mapping_discovery.discoverMappings(allocator);
    defer mapping_discovery.freeProfiles(allocator, profiles);
    try writeNames(allocator, profiles, extra_dir, writer);
}

// --- tests ---

test "list_mappings: smoke (no panic)" {
    const allocator = std.testing.allocator;
    run(allocator, null, std.io.null_writer) catch {};
}

test "list_mappings: machine-readable names are sorted without table output" {
    const profiles = [_]MappingProfile{
        .{ .name = "racing", .path = "/tmp/racing.toml", .source = .system },
        .{ .name = "arcade", .path = "/tmp/arcade.toml", .source = .user },
    };
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try writeNames(std.testing.allocator, &profiles, null, &output.writer);
    try std.testing.expectEqualStrings("arcade\nracing\n", output.written());
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "SOURCE") == null);
}

test "list_mappings: names include sorted config-dir TOML basenames without duplicates" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "zeta.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "arcade.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "ignored.txt", .data = "" });
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const profiles = [_]MappingProfile{
        .{ .name = "racing", .path = "/tmp/racing.toml", .source = .system },
        .{ .name = "arcade", .path = "/tmp/arcade.toml", .source = .user },
    };
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try writeNames(allocator, &profiles, dir_path, &output.writer);
    try std.testing.expectEqualStrings("arcade\nracing\nzeta\n", output.written());
}
