const std = @import("std");
const testing = std.testing;

const Fixture = struct {
    bytes: []const u8,
    expected_len: usize,
    expected_sha256: []const u8,
};

fn expectFixture(fixture: Fixture) !void {
    try testing.expectEqual(fixture.expected_len, fixture.bytes.len);

    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(fixture.bytes, &digest, .{});
    const actual_sha256 = std.fmt.bytesToHex(digest, .lower);
    try testing.expectEqualStrings(fixture.expected_sha256, &actual_sha256);
}

test "DualSense Edge USB fixtures pin audited lengths and SHA-256" {
    const fixtures = [_]Fixture{
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/descriptor.bin"),
            .expected_len = 389,
            .expected_sha256 = "962368681aeeecaf4c384c37458fa98a7e58de2905aafad8ee0b81986ee50891",
        },
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/feature_05.bin"),
            .expected_len = 41,
            .expected_sha256 = "4528e5d961dd54633c9b61c780802037eb88817e0d10042531c92726f96b540c",
        },
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/feature_09.bin"),
            .expected_len = 20,
            .expected_sha256 = "5ce718554d3fb7937651d134162ab4d25539dc53dacfeb0a78e503325bfe44fb",
        },
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/feature_20.bin"),
            .expected_len = 64,
            .expected_sha256 = "214ac66af99f5b87928c273493602c6e57ba2ab7f62c09c19228ee4060ecaa0e",
        },
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin"),
            .expected_len = 48,
            .expected_sha256 = "d25aab53105bf555a982900df2351efcd0ca9f9857f467ab5cd96a984bf8beb7",
        },
        .{
            .bytes = @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin"),
            .expected_len = 63,
            .expected_sha256 = "ba4e3b6f590e90c70c610a9a30e67976c0f6779287447c87e9d06baf24ae399a",
        },
    };

    for (fixtures) |fixture| try expectFixture(fixture);
}

fn expectSyntheticOutput(bytes: []const u8) !void {
    for (bytes, 0..) |byte, index| {
        const expected: u8 = switch (index) {
            0 => 0x02,
            1 => 0x02,
            3 => 0x3c,
            4 => 0xa5,
            39 => 0x04,
            else => 0,
        };
        try testing.expectEqual(expected, byte);
    }
}

test "DualSense Edge compatible-rumble fixtures are synthetic short forms" {
    try expectSyntheticOutput(@embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin"));
    try expectSyntheticOutput(@embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin"));
}
