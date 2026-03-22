const std = @import("std");
const testing = std.testing;
const render = @import("../debug/render.zig");
const hidraw = @import("../io/hidraw.zig");

// -- Test 1: renderFrame with empty raw slice --

test "renderFrame: empty raw slice does not panic" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = render.GamepadState{};
    try render.renderFrame(fbs.writer(), &gs, &.{}, false);
    try render.renderFrame(fbs.writer(), &gs, &[_]u8{0x42}, true);
}

// -- Test 2: stripInputSuffix strips /inputN --

test "stripInputSuffix: strips trailing /inputN" {
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8/input1"));
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8/input2"));
}

test "stripInputSuffix: no suffix unchanged" {
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8"));
}

test "stripInputSuffix: bare input without number unchanged" {
    try testing.expectEqualStrings("usb/input", hidraw.stripInputSuffix("usb/input"));
}

test "stripInputSuffix: non-input suffix unchanged" {
    try testing.expectEqualStrings("usb/event0/dev", hidraw.stripInputSuffix("usb/event0/dev"));
}

test "stripInputSuffix: same base path deduplicates" {
    const a = hidraw.stripInputSuffix("usb-0000:00:14.0-8/input1");
    const b = hidraw.stripInputSuffix("usb-0000:00:14.0-8/input2");
    try testing.expectEqualStrings(a, b);
}

// -- Test 3: directory walker finds .toml in subdirectories --

test "walker: finds toml files in subdirectories" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create nested structure: top.toml, sub/nested.toml, sub/deep/deep.toml
    try tmp.dir.writeFile(.{ .sub_path = "top.toml", .data = "" });
    try tmp.dir.makePath("sub/deep");
    try tmp.dir.writeFile(.{ .sub_path = "sub/nested.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/deep/deep.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/ignore.txt", .data = "" });

    // Use Walker to traverse and collect .toml files
    var walker = try tmp.dir.walk(testing.allocator);
    defer walker.deinit();

    var toml_count: usize = 0;
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.basename, ".toml")) {
            toml_count += 1;
        }
    }

    // iterate() would find only top.toml (1); walk() finds all 3
    try testing.expectEqual(@as(usize, 3), toml_count);
}
