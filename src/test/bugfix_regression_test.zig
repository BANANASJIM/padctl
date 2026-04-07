const std = @import("std");
const testing = std.testing;
const render = @import("../debug/render.zig");
const hidraw = @import("../io/hidraw.zig");
const Supervisor = @import("../supervisor.zig").Supervisor;

// -- Test 1: renderFrame with empty raw slice --

test "renderFrame: empty raw slice does not panic" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = render.GamepadState{};
    try render.renderFrame(fbs.writer(), &gs, &.{}, false, .{}, .raw);
    try render.renderFrame(fbs.writer(), &gs, &[_]u8{0x42}, true, .{}, .raw);
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

// -- Test 3 (issue #64): isTransientOpenError classifies errors correctly --
// Regression: previously only error.AccessDenied was retried; EPERM/ENODEV/ENOENT
// caused a silent drop (bare `return`), losing the hotplug attach forever.

test "isTransientOpenError: transient errors are retried" {
    try testing.expect(Supervisor.isTransientOpenError(error.AccessDenied));
    try testing.expect(Supervisor.isTransientOpenError(error.PermissionDenied));
    try testing.expect(Supervisor.isTransientOpenError(error.DeviceBusy));
    try testing.expect(Supervisor.isTransientOpenError(error.FileNotFound));
    try testing.expect(Supervisor.isTransientOpenError(error.NoDevice));
}

test "isTransientOpenError: fatal errors are not retried" {
    try testing.expect(!Supervisor.isTransientOpenError(error.OutOfMemory));
    try testing.expect(!Supervisor.isTransientOpenError(error.SystemResources));
    try testing.expect(!Supervisor.isTransientOpenError(error.Unexpected));
}

// -- Test 4 (issue #64): attachWithRoot maps any transient open error to HotplugTransient --
// Regression: previously EPERM/ENODEV/ENOENT were normalized to error.AccessDenied,
// making it impossible for callers to distinguish the retry sentinel from a real EACCES.

test "attachWithRoot: missing device returns HotplugTransient, not AccessDenied" {
    var sup = try Supervisor.initForTest(testing.allocator);
    defer sup.deinit();

    // Use a nonexistent path under a real-looking dev root.
    // open() will fail with FileNotFound — a transient error — which must surface as HotplugTransient.
    const result = sup.attachWithRoot("hidraw99", "/dev/nonexistent_root_for_test");
    try testing.expectError(error.HotplugTransient, result);
}

// -- Test 5: directory walker finds .toml in subdirectories --

test "walker: finds toml files in subdirectories" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create nested structure: top.toml, sub/nested.toml, sub/deep/deep.toml
    try tmp.dir.writeFile(.{ .sub_path = "top.toml", .data = "" });
    try tmp.dir.makePath("sub/deep");
    try tmp.dir.writeFile(.{ .sub_path = "sub/nested.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/deep/deep.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/ignore.txt", .data = "" });

    // Reopen with iterate permission for walker
    var iter_dir = try tmp.dir.openDir(".", .{ .iterate = true });
    defer iter_dir.close();
    var walker = try iter_dir.walk(testing.allocator);
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
