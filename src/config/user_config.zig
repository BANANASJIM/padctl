const std = @import("std");
const toml = @import("toml");
const paths = @import("paths.zig");

/// Current schema version written by the installer's binding writer.
/// Bumping this requires adding migration logic in the loader.
pub const CURRENT_VERSION: i64 = 1;

pub const DeviceEntry = struct {
    name: []const u8,
    default_mapping: ?[]const u8 = null,
};

pub const UserConfig = struct {
    /// Schema version for forward/backward compatibility. Missing = legacy
    /// v0 (pre-versioned). Current version is 1. The loader accepts any
    /// version and logs a warning when it's newer than expected.
    version: ?i64 = null,
    device: ?[]DeviceEntry = null,
};

pub const ParseResult = toml.Parsed(UserConfig);

/// Load user config with system fallback.
///
/// Priority: `~/.config/padctl/config.toml` (user) → `/etc/padctl/config.toml`
/// (system). The system path is tried only when the user path is genuinely
/// unavailable (HOME not set, file missing, directory inaccessible). A
/// malformed user config returns null WITHOUT falling through — a parse
/// error in the user file is a user mistake, not a reason to silently
/// switch to the system file.
pub fn load(allocator: std.mem.Allocator) ?ParseResult {
    // Try user path first.
    const user_dir = paths.userConfigDir(allocator) catch |err| {
        // HOME not set (common under systemd) — skip straight to system.
        if (err == error.NoHomeDir) {
            return loadSystemFallback(allocator);
        }
        return null;
    };
    defer allocator.free(user_dir);

    if (loadFromDir(allocator, user_dir)) |maybe_result| {
        if (maybe_result) |result| return result;
        // result is null → file not found → fall through to system.
    } else |err| switch (err) {
        // User config exists but is malformed. Do NOT fall through to
        // the system config — a broken user file is a user mistake and
        // silent fallback would hide the parse error (already logged by
        // loadFromDir).
        error.MalformedConfig => return null,
    }

    // User file absent — try system fallback.
    return loadSystemFallback(allocator);
}

fn loadSystemFallback(allocator: std.mem.Allocator) ?ParseResult {
    const sys_dir = paths.systemConfigDir();
    const result = loadFromDir(allocator, sys_dir) catch {
        // System config malformed — already logged.
        return null;
    };
    if (result != null) {
        std.log.info("user config: loaded system config from {s}/config.toml", .{sys_dir});
    } else {
        std.log.info("user config: no config.toml found; create ~/.config/padctl/config.toml or {s}/config.toml to set per-device defaults", .{sys_dir});
    }
    return result;
}

pub const LoadDirError = error{MalformedConfig};

/// Load and parse `{dir_path}/config.toml`.
///
/// Returns:
/// - Success, non-null: file found and parsed.
/// - Success, null: file not found (or directory inaccessible) — safe to
///   fall through to a lower-priority config path.
/// - error.MalformedConfig: file exists but contains invalid TOML. The
///   caller must NOT fall through to a system config — a broken user
///   config is a user mistake and silent fallback would hide the problem.
pub fn loadFromDir(allocator: std.mem.Allocator, dir_path: []const u8) LoadDirError!?ParseResult {
    const config_path = std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path}) catch return null;
    defer allocator.free(config_path);

    const content = std.fs.cwd().readFileAlloc(allocator, config_path, 256 * 1024) catch |err| {
        if (err != error.FileNotFound)
            std.log.warn("user config: cannot read {s}: {}", .{ config_path, err });
        return null;
    };
    defer allocator.free(content);

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    const result = parser.parseString(content) catch |err| {
        std.log.warn("user config: parse error in {s}: {}", .{ config_path, err });
        return error.MalformedConfig;
    };

    // Warn when the file was written by a newer padctl than we are.
    if (result.value.version) |v| {
        if (v > CURRENT_VERSION) {
            std.log.warn("user config: {s} has version {d}, expected <= {d} — some fields may not be understood", .{ config_path, v, CURRENT_VERSION });
        }
    }

    return result;
}

pub fn findDefaultMapping(result: *const ParseResult, device_name: []const u8) ?[]const u8 {
    const entries = result.value.device orelse return null;
    for (entries) |e| {
        if (std.ascii.eqlIgnoreCase(e.name, device_name)) return e.default_mapping;
    }
    if (entries.len > 0)
        std.log.warn("user config: no entry for detected device \"{s}\" — add [[device]] name = \"{s}\" to config.toml", .{ device_name, device_name });
    return null;
}

// --- tests ---

test "load: returns null when config.toml absent" {
    const allocator = std.testing.allocator;
    // load() reads from XDG_CONFIG_HOME / HOME paths; in a clean test env with no
    // config.toml it must return null without crashing.
    const result = load(allocator);
    if (result) |*r| {
        var mr = r.*;
        mr.deinit();
    }
    // If null, that is the expected outcome for a missing config.
}

test "user_config: loadFromDir reads config.toml from a given directory" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const content =
        \\version = 1
        \\
        \\[[device]]
        \\name = "Test Device"
        \\default_mapping = "test_mapping"
    ;
    {
        const f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll(content);
    }

    var result = try loadFromDir(allocator, dir_path);
    try std.testing.expect(result != null);
    if (result) |*r| {
        defer r.deinit();
        try std.testing.expectEqual(@as(?i64, 1), r.value.version);
        const mapping = findDefaultMapping(r, "Test Device");
        try std.testing.expect(mapping != null);
        try std.testing.expectEqualStrings("test_mapping", mapping.?);
    }
}

test "user_config: loadFromDir returns null when directory has no config.toml" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const result = try loadFromDir(allocator, dir_path);
    try std.testing.expectEqual(@as(?ParseResult, null), result);
}

test "user_config: loadFromDir handles legacy file without version field" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const content =
        \\[[device]]
        \\name = "Legacy Device"
        \\default_mapping = "legacy"
    ;
    {
        const f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll(content);
    }

    var result = try loadFromDir(allocator, dir_path);
    try std.testing.expect(result != null);
    if (result) |*r| {
        defer r.deinit();
        try std.testing.expectEqual(@as(?i64, null), r.value.version);
        try std.testing.expectEqualStrings("legacy", findDefaultMapping(r, "Legacy Device").?);
    }
}

test "user_config: loadFromDir returns MalformedConfig for broken TOML" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        const f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll("this is {{{{ not valid TOML !!!!");
    }

    try std.testing.expectError(error.MalformedConfig, loadFromDir(allocator, dir_path));
}

test "findDefaultMapping: exact match" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\[[device]]
        \\name = "Flydigi Vader 5 Pro"
        \\default_mapping = "fps"
        \\
        \\[[device]]
        \\name = "Sony DualSense"
        \\default_mapping = "default"
    ;

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqualStrings("fps", findDefaultMapping(&result, "Flydigi Vader 5 Pro").?);
    try std.testing.expectEqualStrings("default", findDefaultMapping(&result, "Sony DualSense").?);
}

test "findDefaultMapping: case-insensitive match" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\[[device]]
        \\name = "Flydigi Vader 5 Pro"
        \\default_mapping = "fps"
    ;

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    // Different casing must still match.
    try std.testing.expectEqualStrings("fps", findDefaultMapping(&result, "flydigi vader 5 pro").?);
    try std.testing.expectEqualStrings("fps", findDefaultMapping(&result, "FLYDIGI VADER 5 PRO").?);
}

test "findDefaultMapping: no match returns null" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\[[device]]
        \\name = "Flydigi Vader 5 Pro"
        \\default_mapping = "fps"
    ;

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), findDefaultMapping(&result, "Unknown Device"));
}

test "findDefaultMapping: null when no devices" {
    const allocator = std.testing.allocator;

    const toml_str = "";

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), findDefaultMapping(&result, "Any Device"));
}

test "findDefaultMapping: entry without default_mapping returns null" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\[[device]]
        \\name = "Foo Pad"
    ;

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), findDefaultMapping(&result, "Foo Pad"));
}
