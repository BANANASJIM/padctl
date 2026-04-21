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

/// Returns the directory for padctl log/state files.
///
/// Priority (see `resolveStateDir` for the pure logic):
/// 1. $STATE_DIRECTORY — set by systemd when the unit declares
///    StateDirectory=padctl. Maps to $XDG_STATE_HOME/padctl on the user
///    service and /var/lib/padctl on a system service. systemd pre-creates
///    the dir and auto-whitelists it through any active sandbox directives.
/// 2. $XDG_STATE_HOME/padctl — non-systemd invocations (e.g. the CLI
///    running in the user's shell) with XDG set.
/// 3. ~/.local/state/padctl — non-systemd invocations with HOME set.
/// 4. /var/log/padctl — last-resort fallback when neither XDG nor HOME
///    is available (shouldn't happen in practice).
///
/// Caller frees.
pub fn stateDir(allocator: Allocator) ![]u8 {
    return resolveStateDir(
        allocator,
        std.posix.getenv("STATE_DIRECTORY"),
        std.posix.getenv("XDG_STATE_HOME"),
        std.posix.getenv("HOME"),
    );
}

/// Pure helper: resolve the state directory from explicit env values.
/// Extracted so tests don't have to manipulate process environment.
pub fn resolveStateDir(
    allocator: Allocator,
    state_dir_env: ?[]const u8,
    xdg_state_home_env: ?[]const u8,
    home_env: ?[]const u8,
) ![]u8 {
    if (state_dir_env) |s| return allocator.dupe(u8, s);
    if (xdg_state_home_env) |xdg| {
        return std.fmt.allocPrint(allocator, "{s}/padctl", .{xdg});
    }
    const home = home_env orelse {
        return allocator.dupe(u8, "/var/log/padctl");
    };
    return std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home});
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

test "resolveStateDir: STATE_DIRECTORY wins over all others" {
    const allocator = std.testing.allocator;
    const result = try resolveStateDir(
        allocator,
        "/var/lib/padctl",
        "/some/xdg",
        "/home/user",
    );
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/var/lib/padctl", result);
}

test "resolveStateDir: falls back to XDG_STATE_HOME/padctl when STATE_DIRECTORY unset" {
    const allocator = std.testing.allocator;
    const result = try resolveStateDir(
        allocator,
        null,
        "/home/elly/.local/state",
        "/home/elly",
    );
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/home/elly/.local/state/padctl", result);
}

test "resolveStateDir: falls back to HOME/.local/state/padctl when XDG unset" {
    const allocator = std.testing.allocator;
    const result = try resolveStateDir(allocator, null, null, "/home/shakespear");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/home/shakespear/.local/state/padctl", result);
}

test "resolveStateDir: last-resort /var/log/padctl when nothing is set" {
    const allocator = std.testing.allocator;
    const result = try resolveStateDir(allocator, null, null, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/var/log/padctl", result);
}

test "resolveStateDir: empty STATE_DIRECTORY still wins (systemd sets it empty if no directive)" {
    // Defensive — even if systemd somehow exports an empty STATE_DIRECTORY,
    // we should return it as-is rather than silently treating it as unset.
    // Caller is expected to check for empty strings before using the path.
    const allocator = std.testing.allocator;
    const result = try resolveStateDir(allocator, "", "/home/elly/.local/state", "/home/elly");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}
