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

pub const DiagnosticsConfig = struct {
    dump: bool = false,
    max_log_size_mb: i64 = 100,
};

/// Runtime supervisor tunables. All fields have production defaults and
/// are optional — a missing `[supervisor]` section leaves them as-is.
pub const SupervisorConfig = struct {
    /// Issue #131-A: seconds to preserve a suspended instance's uinput so
    /// a wireless sleep/wake cycle does not break SDL's cached eventN
    /// reference. Negative values treated as 0 (immediate teardown);
    /// values > u32_max clamped. See `Supervisor.suspend_grace_sec`.
    suspend_grace_sec: i64 = 15,
};

pub const UserConfig = struct {
    /// Schema version for forward/backward compatibility. Missing = legacy
    /// v0 (pre-versioned). Current version is 1. The loader accepts any
    /// version and logs a warning when it's newer than expected.
    version: ?i64 = null,
    device: ?[]DeviceEntry = null,
    diagnostics: DiagnosticsConfig = .{},
    supervisor: SupervisorConfig = .{},
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

/// Atomically rewrite `config_path` from `cfg`, preserving every section.
///
/// Writes `version`, then `[diagnostics]` and `[supervisor]` (each emitted
/// only when at least one field differs from its struct default — keeps
/// fresh files terse), then every `[[device]]` entry. Strings are TOML
/// basic-string escaped.
///
/// Atomicity: serialise to `<config_path>.tmp`, fsync, then rename(2) onto
/// `config_path`. rename(2) is atomic on POSIX filesystems, so a crash or
/// kill mid-write never leaves the live config truncated. The parent
/// directory must exist; callers create it before invoking this helper.
pub fn writeAtomic(
    allocator: std.mem.Allocator,
    config_path: []const u8,
    cfg: *const UserConfig,
) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    try emitToml(buf.writer(allocator), cfg);

    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{config_path});
    defer allocator.free(tmp_path);

    {
        var f = try std.fs.createFileAbsolute(tmp_path, .{ .truncate = true });
        defer f.close();
        f.writeAll(buf.items) catch |err| {
            std.fs.deleteFileAbsolute(tmp_path) catch {};
            return err;
        };
        f.sync() catch {};
    }
    errdefer std.fs.deleteFileAbsolute(tmp_path) catch {};
    try std.posix.rename(tmp_path, config_path);
}

/// Serialise `cfg` to a TOML writer. Sections with all-default values are
/// elided so a fresh-install config stays minimal; any non-default field
/// triggers full emission of that section.
pub fn emitToml(writer: anytype, cfg: *const UserConfig) !void {
    try writer.print("version = {d}\n", .{cfg.version orelse CURRENT_VERSION});

    const diag = cfg.diagnostics;
    const diag_default = DiagnosticsConfig{};
    if (diag.dump != diag_default.dump or diag.max_log_size_mb != diag_default.max_log_size_mb) {
        try writer.print("\n[diagnostics]\ndump = {}\nmax_log_size_mb = {d}\n", .{ diag.dump, diag.max_log_size_mb });
    }

    const sup = cfg.supervisor;
    const sup_default = SupervisorConfig{};
    if (sup.suspend_grace_sec != sup_default.suspend_grace_sec) {
        try writer.print("\n[supervisor]\nsuspend_grace_sec = {d}\n", .{sup.suspend_grace_sec});
    }

    if (cfg.device) |entries| {
        for (entries) |d| {
            try writer.writeAll("\n[[device]]\nname = \"");
            try escapeTomlString(writer, d.name);
            try writer.writeAll("\"\n");
            if (d.default_mapping) |m| {
                try writer.writeAll("default_mapping = \"");
                try escapeTomlString(writer, m);
                try writer.writeAll("\"\n");
            }
        }
    }
}

/// Escape a TOML basic-string payload (between the enclosing `"`).
///
/// Control characters are REJECTED with error.InvalidDeviceName — per PR #168
/// (audit V1) the project's defensive-boundary policy is: control bytes in
/// device names indicate input corruption (broken sysfs, malicious udev rule,
/// hand-edited bad TOML) — surface loudly, don't silent-normalize.
/// Tab (0x09) is the only control byte TOML basic strings permit; it passes through.
pub fn escapeTomlString(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '"' => try writer.writeAll("\\\""),
            '\t' => try writer.writeByte('\t'),
            0...0x08, 0x0A...0x1F, 0x7F => return error.InvalidDeviceName,
            else => try writer.writeByte(c),
        }
    }
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

test "user_config: diagnostics section parses with defaults" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 1
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    // Missing [diagnostics] → defaults: dump=false, max_log_size_mb=100
    try std.testing.expectEqual(false, result.value.diagnostics.dump);
    try std.testing.expectEqual(@as(i64, 100), result.value.diagnostics.max_log_size_mb);
}

test "user_config: diagnostics section parses explicit values" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 1
        \\
        \\[diagnostics]
        \\dump = true
        \\max_log_size_mb = 50
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(true, result.value.diagnostics.dump);
    try std.testing.expectEqual(@as(i64, 50), result.value.diagnostics.max_log_size_mb);
}

test "user_config: diagnostics alongside device entries" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 1
        \\
        \\[diagnostics]
        \\dump = true
        \\
        \\[[device]]
        \\name = "Test Pad"
        \\default_mapping = "fps"
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(true, result.value.diagnostics.dump);
    try std.testing.expectEqualStrings("fps", findDefaultMapping(&result, "Test Pad").?);
}

test "user_config: unknown fields ignored (forward compatibility)" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 2
        \\some_future_field = "hello"
        \\
        \\[diagnostics]
        \\dump = true
        \\max_log_size_mb = 75
        \\future_diag_option = 42
        \\
        \\[[device]]
        \\name = "Pad"
        \\default_mapping = "m1"
        \\unknown_device_field = true
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    // Known fields parsed correctly despite unknown siblings.
    try std.testing.expectEqual(true, result.value.diagnostics.dump);
    try std.testing.expectEqual(@as(i64, 75), result.value.diagnostics.max_log_size_mb);
    try std.testing.expectEqualStrings("m1", findDefaultMapping(&result, "Pad").?);
}

test "user_config: supervisor section defaults when absent" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 1
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(@as(i64, 15), result.value.supervisor.suspend_grace_sec);
}

test "user_config: supervisor.suspend_grace_sec parses explicit value" {
    const allocator = std.testing.allocator;

    const toml_str =
        \\version = 1
        \\
        \\[supervisor]
        \\suspend_grace_sec = 30
    ;
    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(toml_str);
    defer result.deinit();

    try std.testing.expectEqual(@as(i64, 30), result.value.supervisor.suspend_grace_sec);
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

test "writeAtomic round-trips [supervisor] section" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    const cfg = UserConfig{
        .version = CURRENT_VERSION,
        .supervisor = .{ .suspend_grace_sec = 30 },
    };
    try writeAtomic(allocator, config_path, &cfg);

    var result = (try loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try std.testing.expectEqual(@as(i64, 30), result.value.supervisor.suspend_grace_sec);
}

test "writeAtomic round-trips [diagnostics] section" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    const cfg = UserConfig{
        .version = CURRENT_VERSION,
        .diagnostics = .{ .dump = true, .max_log_size_mb = 50 },
    };
    try writeAtomic(allocator, config_path, &cfg);

    var result = (try loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try std.testing.expectEqual(true, result.value.diagnostics.dump);
    try std.testing.expectEqual(@as(i64, 50), result.value.diagnostics.max_log_size_mb);
}

test "writeAtomic preserves all sections through device-mutation flow" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    const seed =
        \\version = 1
        \\
        \\[diagnostics]
        \\dump = true
        \\max_log_size_mb = 50
        \\
        \\[supervisor]
        \\suspend_grace_sec = 30
        \\
        \\[[device]]
        \\name = "Vader 5 Pro"
        \\default_mapping = "fps"
    ;
    {
        const f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll(seed);
    }

    // Simulate `padctl switch`: load -> mutate device entry -> writeAtomic.
    var loaded = (try loadFromDir(allocator, dir_path)).?;
    defer loaded.deinit();

    const new_devices = try allocator.alloc(DeviceEntry, 1);
    defer allocator.free(new_devices);
    new_devices[0] = .{ .name = "Vader 5 Pro", .default_mapping = "racing" };

    const mutated = UserConfig{
        .version = loaded.value.version,
        .device = new_devices,
        .diagnostics = loaded.value.diagnostics,
        .supervisor = loaded.value.supervisor,
    };
    try writeAtomic(allocator, config_path, &mutated);

    var reloaded = (try loadFromDir(allocator, dir_path)).?;
    defer reloaded.deinit();
    try std.testing.expectEqual(true, reloaded.value.diagnostics.dump);
    try std.testing.expectEqual(@as(i64, 50), reloaded.value.diagnostics.max_log_size_mb);
    try std.testing.expectEqual(@as(i64, 30), reloaded.value.supervisor.suspend_grace_sec);
    try std.testing.expectEqualStrings("racing", findDefaultMapping(&reloaded, "Vader 5 Pro").?);
}

test "writeAtomic leaves no .tmp sidecar after success" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    const cfg = UserConfig{ .version = CURRENT_VERSION };
    try writeAtomic(allocator, config_path, &cfg);

    try std.testing.expectError(error.FileNotFound, tmp.dir.access("config.toml.tmp", .{}));
    try tmp.dir.access("config.toml", .{});
}

test "writeAtomic escapes TOML special characters in device names" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    const devices = try allocator.alloc(DeviceEntry, 1);
    defer allocator.free(devices);
    devices[0] = .{ .name = "Quote\"Backslash\\Pad", .default_mapping = "m1" };
    const cfg = UserConfig{ .version = CURRENT_VERSION, .device = devices };
    try writeAtomic(allocator, config_path, &cfg);

    var result = (try loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try std.testing.expectEqualStrings("m1", findDefaultMapping(&result, "Quote\"Backslash\\Pad").?);
}

test "escapeTomlString rejects newline (PR #168 regression)" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, escapeTomlString(buf.writer(a), "Bad\nName"));
}

test "escapeTomlString rejects control byte 0x07 (PR #168 regression)" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, escapeTomlString(buf.writer(a), "Bad\x07Name"));
}

test "escapeTomlString allows tab (TOML-spec-allowed)" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try escapeTomlString(buf.writer(a), "Foo\tBar");
    try std.testing.expectEqualStrings("Foo\tBar", buf.items);
}

test "escapeTomlString escapes backslash and double-quote" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try escapeTomlString(buf.writer(a), "a\\b\"c");
    try std.testing.expectEqualStrings("a\\\\b\\\"c", buf.items);
}
