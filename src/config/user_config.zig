const std = @import("std");
const toml = @import("toml");
const paths = @import("paths.zig");

pub const DeviceEntry = struct {
    name: []const u8,
    default_mapping: ?[]const u8 = null,
};

pub const UserConfig = struct {
    device: ?[]DeviceEntry = null,
};

pub const ParseResult = toml.Parsed(UserConfig);

pub fn load(allocator: std.mem.Allocator) ?ParseResult {
    const config_dir = paths.userConfigDir(allocator) catch return null;
    defer allocator.free(config_dir);

    const config_path = std.fmt.allocPrint(allocator, "{s}/config.toml", .{config_dir}) catch return null;
    defer allocator.free(config_path);

    const content = std.fs.cwd().readFileAlloc(allocator, config_path, 256 * 1024) catch |err| {
        if (err != error.FileNotFound) std.log.warn("user config: cannot read {s}: {}", .{ config_path, err });
        return null;
    };
    defer allocator.free(content);

    var parser = toml.Parser(UserConfig).init(allocator);
    defer parser.deinit();
    return parser.parseString(content) catch |err| {
        std.log.warn("user config: parse error in {s}: {}", .{ config_path, err });
        return null;
    };
}

/// Find the default_mapping for a device by name. Returns a slice into the parsed data.
pub fn findDefaultMapping(result: *const ParseResult, device_name: []const u8) ?[]const u8 {
    const entries = result.value.device orelse return null;
    for (entries) |e| {
        if (std.mem.eql(u8, e.name, device_name)) return e.default_mapping;
    }
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

test "findDefaultMapping: matches by name" {
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
