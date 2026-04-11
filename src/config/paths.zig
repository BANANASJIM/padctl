const std = @import("std");
const Allocator = std.mem.Allocator;

/// Returns $XDG_CONFIG_HOME/padctl, or ~/.config/padctl. Caller frees.
pub fn userConfigDir(allocator: Allocator) ![]u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        return std.fmt.allocPrint(allocator, "{s}/padctl", .{xdg});
    }
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return std.fmt.allocPrint(allocator, "{s}/.config/padctl", .{home});
}

pub fn systemConfigDir() []const u8 {
    return "/etc/padctl";
}

pub fn dataDir() []const u8 {
    return "/usr/share/padctl";
}

/// Returns search dirs for devices/ in priority order: user > system > builtin.
/// Caller frees the slice and each element.
pub fn resolveDeviceConfigDirs(allocator: Allocator) ![][]const u8 {
    return resolveSubdirDirs(allocator, "devices");
}

/// Returns search dirs for mappings/ in priority order.
/// Caller frees the slice and each element.
pub fn resolveMappingConfigDirs(allocator: Allocator) ![][]const u8 {
    return resolveSubdirDirs(allocator, "mappings");
}

fn resolveSubdirDirs(allocator: Allocator, subdir: []const u8) ![][]const u8 {
    const user_dir = userConfigDir(allocator) catch |err| switch (err) {
        error.NoHomeDir => {
            var dirs = try allocator.alloc([]u8, 2);
            errdefer allocator.free(dirs);
            dirs[0] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ systemConfigDir(), subdir });
            errdefer allocator.free(dirs[0]);
            dirs[1] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dataDir(), subdir });
            return @ptrCast(dirs);
        },
        else => return err,
    };
    defer allocator.free(user_dir);

    var dirs = try allocator.alloc([]u8, 3);
    errdefer allocator.free(dirs);

    dirs[0] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ user_dir, subdir });
    errdefer allocator.free(dirs[0]);

    dirs[1] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ systemConfigDir(), subdir });
    errdefer allocator.free(dirs[1]);

    dirs[2] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dataDir(), subdir });

    return @ptrCast(dirs);
}

pub fn freeConfigDirs(allocator: Allocator, dirs: [][]const u8) void {
    for (dirs) |d| allocator.free(d);
    allocator.free(dirs);
}

/// Find the first file named `name` that exists in any of `dirs`. Caller frees result.
pub fn findConfig(allocator: Allocator, name: []const u8, dirs: []const []const u8) !?[]u8 {
    for (dirs) |dir| {
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, name });
        errdefer allocator.free(path);
        std.fs.accessAbsolute(path, .{}) catch {
            allocator.free(path);
            continue;
        };
        return path;
    }
    return null;
}

// --- tests ---

test "userConfigDir: falls back to HOME/.config/padctl" {
    const allocator = std.testing.allocator;
    const home = std.posix.getenv("HOME") orelse return error.SkipZigTest;
    const dir = try userConfigDir(allocator);
    defer allocator.free(dir);
    const expected = try std.fmt.allocPrint(allocator, "{s}/.config/padctl", .{home});
    defer allocator.free(expected);
    try std.testing.expectEqualStrings(expected, dir);
}

test "userConfigDir: no SUDO_USER branch" {
    // Verify SUDO_USER is not consulted: the function must use $HOME directly.
    const allocator = std.testing.allocator;
    const home = std.posix.getenv("HOME") orelse return error.SkipZigTest;
    const dir = try userConfigDir(allocator);
    defer allocator.free(dir);
    try std.testing.expect(std.mem.startsWith(u8, dir, home));
    try std.testing.expect(std.mem.endsWith(u8, dir, "/.config/padctl") or
        std.posix.getenv("XDG_CONFIG_HOME") != null);
}

test "resolveDeviceConfigDirs: returns three entries" {
    const allocator = std.testing.allocator;
    const dirs = try resolveDeviceConfigDirs(allocator);
    defer freeConfigDirs(allocator, dirs);
    try std.testing.expectEqual(@as(usize, 3), dirs.len);
    try std.testing.expect(std.mem.endsWith(u8, dirs[0], "/devices"));
    try std.testing.expect(std.mem.endsWith(u8, dirs[1], "/devices"));
    try std.testing.expect(std.mem.endsWith(u8, dirs[2], "/devices"));
}

test "resolveMappingConfigDirs: returns three entries" {
    const allocator = std.testing.allocator;
    const dirs = try resolveMappingConfigDirs(allocator);
    defer freeConfigDirs(allocator, dirs);
    try std.testing.expectEqual(@as(usize, 3), dirs.len);
    try std.testing.expect(std.mem.endsWith(u8, dirs[0], "/mappings"));
}

test "resolveDeviceConfigDirs: priority order" {
    const allocator = std.testing.allocator;
    const dirs = try resolveDeviceConfigDirs(allocator);
    defer freeConfigDirs(allocator, dirs);
    // user dir must contain .config/padctl or $XDG_CONFIG_HOME
    try std.testing.expect(
        std.mem.indexOf(u8, dirs[0], ".config/padctl") != null or
            std.posix.getenv("XDG_CONFIG_HOME") != null,
    );
    try std.testing.expectEqualStrings("/etc/padctl/devices", dirs[1]);
    try std.testing.expectEqualStrings("/usr/share/padctl/devices", dirs[2]);
}

test "findConfig: returns null when no dir contains the file" {
    const allocator = std.testing.allocator;
    const dirs = [_][]const u8{ "/tmp/nonexistent_padctl_xdg_a", "/tmp/nonexistent_padctl_xdg_b" };
    const result = try findConfig(allocator, "some.toml", &dirs);
    try std.testing.expectEqual(@as(?[]u8, null), result);
}

test "findConfig: returns path when file exists" {
    const allocator = std.testing.allocator;

    const tmp_dir = "/tmp/padctl_xdg_test_findconfig";
    std.fs.makeDirAbsolute(tmp_dir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    defer std.fs.deleteTreeAbsolute(tmp_dir) catch {};

    const file_path = tmp_dir ++ "/test.toml";
    const f = try std.fs.createFileAbsolute(file_path, .{});
    f.close();

    const dirs = [_][]const u8{tmp_dir};
    const result = try findConfig(allocator, "test.toml", &dirs);
    defer if (result) |p| allocator.free(p);

    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings(file_path, result.?);
}
