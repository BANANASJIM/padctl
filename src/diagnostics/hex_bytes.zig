const std = @import("std");

pub const HexBytes = struct {
    bytes: []const u8,

    pub fn format(self: HexBytes, writer: anytype) !void {
        for (self.bytes, 0..) |b, i| {
            if (i > 0) try writer.writeByte(' ');
            try writer.print("{x:0>2}", .{b});
        }
    }
};

pub fn hex(bytes: []const u8) HexBytes {
    return .{ .bytes = bytes };
}

test "hex_bytes: formats spaced lowercase hex" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("5a a5 0f", try std.fmt.bufPrint(&buf, "{f}", .{hex(&.{ 0x5a, 0xa5, 0x0f })}));
    try std.testing.expectEqualStrings("", try std.fmt.bufPrint(&buf, "{f}", .{hex(&.{})}));
}
