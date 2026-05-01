const std = @import("std");
const mapping = @import("../config/mapping.zig");

const toml_text = @embedFile("../../examples/mappings/chord-output.toml");

test "chord_output_e2e: examples/mappings/chord-output.toml parses (SSOT)" {
    const allocator = std.testing.allocator;
    const result = try mapping.parseString(allocator, toml_text);
    defer result.deinit();

    const remap = result.value.remap orelse return error.MissingRemap;

    // M1 single-key form
    const m1 = remap.map.get("M1") orelse return error.MissingM1;
    try std.testing.expect(m1 == .string);
    try std.testing.expectEqualStrings("KEY_F13", m1.string);

    // A: 2-key chord
    const a = remap.map.get("A") orelse return error.MissingA;
    try std.testing.expect(a == .chord_names);
    try std.testing.expectEqual(@as(usize, 2), a.chord_names.len);
    try std.testing.expectEqualStrings("KEY_LEFTMETA", a.chord_names[0]);
    try std.testing.expectEqualStrings("KEY_1", a.chord_names[1]);

    // B: 2-key chord
    const b = remap.map.get("B") orelse return error.MissingB;
    try std.testing.expect(b == .chord_names);
    try std.testing.expectEqual(@as(usize, 2), b.chord_names.len);

    // X: 3-key chord
    const x = remap.map.get("X") orelse return error.MissingX;
    try std.testing.expect(x == .chord_names);
    try std.testing.expectEqual(@as(usize, 3), x.chord_names.len);

    // Y: 4-key chord (max length)
    const y = remap.map.get("Y") orelse return error.MissingY;
    try std.testing.expect(y == .chord_names);
    try std.testing.expectEqual(@as(usize, 4), y.chord_names.len);

    // Canonical example must pass full validation
    try mapping.validate(&result.value);
}
