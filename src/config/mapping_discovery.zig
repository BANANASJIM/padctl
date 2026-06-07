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
    return discoverMappingsFromDirs(allocator, dirs);
}

/// Scan the given dirs in priority order (first wins), deduplicate by name.
/// dirs and sources are positional: dirs[i] is tagged with sources[i].
pub fn discoverMappingsFromDirs(allocator: std.mem.Allocator, dirs: []const []const u8) ![]MappingProfile {
    const all_sources = [_]Source{ .user, .system, .package };

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

    for (dirs, 0..) |dir_path, i| {
        const source = if (i < all_sources.len) all_sources[i] else .package;
        var dir = if (std.fs.path.isAbsolute(dir_path))
            std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch continue
        else
            std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file and entry.kind != .sym_link) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;

            const name = entry.name[0 .. entry.name.len - ".toml".len];
            if (seen.contains(name)) continue;

            const owned_name = try allocator.dupe(u8, name);
            errdefer allocator.free(owned_name);

            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            errdefer allocator.free(full_path);

            // Register in seen before list.append so only one cleanup path
            // owns these pointers at a time (avoids double-free on OOM).
            try seen.put(owned_name, {});
            try list.append(allocator, .{ .name = owned_name, .path = full_path, .source = source });
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(base);

    const user_dir = try std.fmt.allocPrint(allocator, "{s}/user", .{base});
    defer allocator.free(user_dir);
    const sys_dir = try std.fmt.allocPrint(allocator, "{s}/system", .{base});
    defer allocator.free(sys_dir);
    const pkg_dir = try std.fmt.allocPrint(allocator, "{s}/package", .{base});
    defer allocator.free(pkg_dir);

    try tmp.dir.makeDir("user");
    try tmp.dir.makeDir("system");
    try tmp.dir.makeDir("package");

    for ([_][]const u8{ "user/fps.toml", "system/racing.toml", "package/fps.toml" }) |p| {
        const f = try tmp.dir.createFile(p, .{});
        f.close();
    }

    const dirs = [_][]const u8{ user_dir, sys_dir, pkg_dir };
    const profiles = try discoverMappingsFromDirs(allocator, &dirs);
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

fn discoverAndFree(allocator: std.mem.Allocator, dirs: []const []const u8) !void {
    const profiles = try discoverMappingsFromDirs(allocator, dirs);
    freeProfiles(allocator, profiles);
}

test "discoverMappingsFromDirs: no leak or double-free under allocation failure" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(base);

    for ([_][]const u8{ "a.toml", "b.toml", "c.toml" }) |p| {
        const f = try tmp.dir.createFile(p, .{});
        f.close();
    }

    const dirs = [_][]const u8{base};
    // Injects OOM at each allocation point in turn; a double-free or leak
    // on the seen.put/list.append path fails this check.
    try std.testing.checkAllAllocationFailures(allocator, discoverAndFree, .{&dirs});
}

test "findMapping: returns null for nonexistent" {
    const allocator = std.testing.allocator;
    const result = try findMapping(allocator, "nonexistent_profile_xyz_12345");
    try std.testing.expectEqual(@as(?[]u8, null), result);
}
