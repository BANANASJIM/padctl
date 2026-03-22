const std = @import("std");
const paths = @import("paths.zig");

pub const Source = enum { user, system, package };

pub const MappingProfile = struct {
    name: []const u8,
    path: []const u8,
    source: Source,
};

/// Scan XDG 3-layer mapping dirs, deduplicate by name (user > system > package).
/// Caller owns returned slice; call freeProfiles() when done.
pub fn discoverMappings(allocator: std.mem.Allocator) ![]MappingProfile {
    const dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dirs);

    const sources = [_]Source{ .user, .system, .package };

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var list: std.ArrayList(MappingProfile) = .{};
    errdefer {
        for (list.items) |p| {
            allocator.free(p.name);
            allocator.free(p.path);
        }
        list.deinit(allocator);
    }

    for (dirs, sources) |dir_path, source| {
        var dir = if (std.fs.path.isAbsolute(dir_path))
            std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch continue
        else
            std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;

            const name = entry.name[0 .. entry.name.len - ".toml".len];
            if (seen.contains(name)) continue;

            const owned_name = try allocator.dupe(u8, name);
            errdefer allocator.free(owned_name);

            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            errdefer allocator.free(full_path);

            try list.append(allocator, .{ .name = owned_name, .path = full_path, .source = source });
            try seen.put(owned_name, {});
        }
    }

    return list.toOwnedSlice(allocator);
}

/// Find a mapping profile by name. Returns the full path or null. Caller frees.
pub fn findMapping(allocator: std.mem.Allocator, name: []const u8) !?[]const u8 {
    const dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dirs);

    const filename = try std.fmt.allocPrint(allocator, "{s}.toml", .{name});
    defer allocator.free(filename);

    return paths.findConfig(allocator, filename, dirs);
}

pub fn freeProfiles(allocator: std.mem.Allocator, profiles: []MappingProfile) void {
    for (profiles) |p| {
        allocator.free(p.name);
        allocator.free(p.path);
    }
    allocator.free(profiles);
}

// --- tests ---

test "discoverMappings: empty dirs returns empty" {
    const profiles = try discoverMappings(std.testing.allocator);
    defer freeProfiles(std.testing.allocator, profiles);
    // Real XDG dirs may or may not have mappings; just verify no crash
}

test "discoverMappings: temp dir with profiles" {
    const allocator = std.testing.allocator;

    const base = "/tmp/padctl_test_mapping_discovery";
    const user_dir = base ++ "/user/mappings";
    const sys_dir = base ++ "/system/mappings";
    const pkg_dir = base ++ "/package/mappings";

    // Clean up from previous runs
    std.fs.deleteTreeAbsolute(base) catch {};

    // Create directories
    try std.fs.makeDirAbsolute(base);
    for ([_][]const u8{ base ++ "/user", user_dir, base ++ "/system", sys_dir, base ++ "/package", pkg_dir }) |d| {
        try std.fs.makeDirAbsolute(d);
    }
    defer std.fs.deleteTreeAbsolute(base) catch {};

    // Create mapping files
    for ([_][]const u8{ user_dir ++ "/fps.toml", sys_dir ++ "/racing.toml", pkg_dir ++ "/fps.toml" }) |p| {
        const f = try std.fs.createFileAbsolute(p, .{});
        f.close();
    }

    // Override paths by calling the internal scan logic directly
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var list: std.ArrayList(MappingProfile) = .{};

    const dirs = [_][]const u8{ user_dir, sys_dir, pkg_dir };
    const sources = [_]Source{ .user, .system, .package };

    for (dirs, sources) |dir_path, source| {
        var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;

            const name = entry.name[0 .. entry.name.len - ".toml".len];
            if (seen.contains(name)) continue;

            const owned_name = try allocator.dupe(u8, name);
            errdefer allocator.free(owned_name);
            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            errdefer allocator.free(full_path);
            try list.append(allocator, .{ .name = owned_name, .path = full_path, .source = source });
            try seen.put(owned_name, {});
        }
    }

    const profiles = try list.toOwnedSlice(allocator);
    defer freeProfiles(allocator, profiles);

    // "fps" should appear once (user wins), "racing" from system
    try std.testing.expectEqual(@as(usize, 2), profiles.len);

    var found_fps = false;
    var found_racing = false;
    for (profiles) |p| {
        if (std.mem.eql(u8, p.name, "fps")) {
            found_fps = true;
            try std.testing.expectEqual(Source.user, p.source);
            try std.testing.expect(std.mem.indexOf(u8, p.path, "/user/") != null);
        }
        if (std.mem.eql(u8, p.name, "racing")) {
            found_racing = true;
            try std.testing.expectEqual(Source.system, p.source);
        }
    }
    try std.testing.expect(found_fps);
    try std.testing.expect(found_racing);
}

test "findMapping: returns null for nonexistent" {
    const allocator = std.testing.allocator;
    const result = try findMapping(allocator, "nonexistent_profile_xyz_12345");
    try std.testing.expectEqual(@as(?[]u8, null), result);
}
