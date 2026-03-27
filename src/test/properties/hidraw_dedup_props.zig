const std = @import("std");
const testing = std.testing;

const hidraw = @import("../../io/hidraw.zig");
const stripInputSuffix = hidraw.stripInputSuffix;

// P5: stripInputSuffix properties
test "property: stripInputSuffix — same USB path with different inputN yields same result" {
    const base = "usb-0000:00:14.0-1/input";
    const result3 = stripInputSuffix(base ++ "3");
    const result7 = stripInputSuffix(base ++ "7");
    const result0 = stripInputSuffix(base ++ "0");

    try testing.expectEqualStrings(result3, result7);
    try testing.expectEqualStrings(result3, result0);
    try testing.expectEqualStrings("usb-0000:00:14.0-1", result3);
}

test "property: stripInputSuffix — paths without /inputN are unchanged" {
    const cases = [_][]const u8{
        "usb-0000:00:14.0-1",
        "usb-0000:00:14.0-1/something",
        "usb-0000:00:14.0-1/input",
        "usb-0000:00:14.0-1/inputXYZ",
    };

    for (cases) |path| {
        try testing.expectEqualStrings(path, stripInputSuffix(path));
    }
}

test "property: stripInputSuffix — empty string is unchanged" {
    try testing.expectEqualStrings("", stripInputSuffix(""));
}

test "property: stripInputSuffix — all single-digit suffixes yield same base" {
    const base = "usb-hub/input";
    var prev: ?[]const u8 = null;
    for (0..10) |i| {
        var buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&buf, "{s}{d}", .{ base, i }) catch unreachable;
        const result = stripInputSuffix(path);
        if (prev) |p| {
            try testing.expectEqualStrings(p, result);
        }
        prev = result;
    }
}
