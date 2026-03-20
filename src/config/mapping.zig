const std = @import("std");
const toml = @import("toml");

// Raw mapping config as parsed from TOML.
// Remap values are raw strings; resolution happens in remap.zig.
pub const MappingConfig = struct {
    name: ?[]const u8 = null,
    remap: ?toml.HashMap([]const u8) = null,
};

pub const ParseResult = toml.Parsed(MappingConfig);

pub fn parseString(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var parser = toml.Parser(MappingConfig).init(allocator);
    defer parser.deinit();
    return parser.parseString(content);
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);
    return parseString(allocator, content);
}

// --- tests ---

const test_toml =
    \\name = "test"
    \\
    \\[remap]
    \\M1 = "KEY_F13"
    \\M2 = "disabled"
    \\A = "B"
;

test "MappingConfig parses name and remap" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("test", cfg.name.?);
    try std.testing.expect(cfg.remap != null);
    try std.testing.expectEqualStrings("KEY_F13", cfg.remap.?.map.get("M1").?);
    try std.testing.expectEqualStrings("disabled", cfg.remap.?.map.get("M2").?);
    try std.testing.expectEqualStrings("B", cfg.remap.?.map.get("A").?);
}

test "MappingConfig: empty config" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try std.testing.expect(result.value.name == null);
    try std.testing.expect(result.value.remap == null);
}
