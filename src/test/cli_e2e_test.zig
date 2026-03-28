// CLI E2E tests: install paths, XDG resolution, scan output/matching, config subcommands.
// Split from phase6_e2e_test.zig (non-validate sections).

const std = @import("std");
const testing = std.testing;

const paths_mod = @import("../config/paths.zig");
const scan_mod = @import("../cli/scan.zig");
const device_mod = @import("../config/device.zig");
const config_edit = @import("../cli/config/edit.zig");
const config_test_mod = @import("../cli/config/test.zig");
const helpers = @import("helpers.zig");
const collectTomlPaths = helpers.collectTomlPaths;

// --- 1. Install: directory structure paths ---

test "install paths: bin under prefix" {
    const allocator = testing.allocator;
    const bin = try std.fmt.allocPrint(allocator, "{s}{s}/bin", .{ "/staging", "/usr" });
    defer allocator.free(bin);
    try testing.expectEqualStrings("/staging/usr/bin", bin);
}

test "install paths: share/padctl/devices under prefix" {
    const allocator = testing.allocator;
    const share = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl/devices", .{ "", "/usr" });
    defer allocator.free(share);
    try testing.expectEqualStrings("/usr/share/padctl/devices", share);
}

test "install paths: lib/udev/rules.d under prefix" {
    const allocator = testing.allocator;
    const udev = try std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d", .{ "", "/usr" });
    defer allocator.free(udev);
    try testing.expectEqualStrings("/usr/lib/udev/rules.d", udev);
}

test "install paths: lib/systemd/system under prefix" {
    const allocator = testing.allocator;
    const svc = try std.fmt.allocPrint(allocator, "{s}{s}/lib/systemd/system", .{ "", "/usr" });
    defer allocator.free(svc);
    try testing.expectEqualStrings("/usr/lib/systemd/system", svc);
}

test "install paths: destdir prepended to all paths" {
    const allocator = testing.allocator;
    const destdir = "/tmp/staging";
    const bin = try std.fmt.allocPrint(allocator, "{s}/usr/bin", .{destdir});
    defer allocator.free(bin);
    try testing.expect(std.mem.startsWith(u8, bin, destdir));
}

// --- 2. XDG path resolution ---

test "XDG: resolveDeviceConfigDirs returns 3 entries" {
    const allocator = testing.allocator;
    const dirs = try paths_mod.resolveDeviceConfigDirs(allocator);
    defer paths_mod.freeConfigDirs(allocator, dirs);
    try testing.expectEqual(@as(usize, 3), dirs.len);
}

test "XDG: device config dirs end with /devices" {
    const allocator = testing.allocator;
    const dirs = try paths_mod.resolveDeviceConfigDirs(allocator);
    defer paths_mod.freeConfigDirs(allocator, dirs);
    for (dirs) |d| try testing.expect(std.mem.endsWith(u8, d, "/devices"));
}

test "XDG: system and builtin dirs are fixed" {
    const allocator = testing.allocator;
    const dirs = try paths_mod.resolveDeviceConfigDirs(allocator);
    defer paths_mod.freeConfigDirs(allocator, dirs);
    try testing.expectEqualStrings("/etc/padctl/devices", dirs[1]);
    try testing.expectEqualStrings("/usr/share/padctl/devices", dirs[2]);
}

test "XDG: userConfigDir contains padctl" {
    const allocator = testing.allocator;
    const dir = try paths_mod.userConfigDir(allocator);
    defer allocator.free(dir);
    try testing.expect(std.mem.indexOf(u8, dir, "padctl") != null);
}

test "XDG: findConfig returns null when dirs do not contain file" {
    const allocator = testing.allocator;
    const dirs = [_][]const u8{ "/tmp/padctl_xdg_miss_a", "/tmp/padctl_xdg_miss_b" };
    const result = try paths_mod.findConfig(allocator, "nope.toml", &dirs);
    try testing.expectEqual(@as(?[]u8, null), result);
}

test "XDG: findConfig finds file in first matching dir" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const file_path = try std.fmt.allocPrint(allocator, "{s}/probe.toml", .{tmp_path});
    defer allocator.free(file_path);
    {
        const f = try std.fs.createFileAbsolute(file_path, .{});
        f.close();
    }
    const dirs = [_][]const u8{tmp_path};
    const result = try paths_mod.findConfig(allocator, "probe.toml", &dirs);
    defer if (result) |p| allocator.free(p);
    try testing.expect(result != null);
    try testing.expectEqualStrings(file_path, result.?);
}

// --- 3. Scan: output format ---

test "scan output: VID:PID column fits 9 chars" {
    var buf: [9]u8 = undefined;
    const vidpid = try std.fmt.bufPrint(&buf, "{x:0>4}:{x:0>4}", .{ @as(u16, 0x37d7), @as(u16, 0x2401) });
    try testing.expectEqual(@as(usize, 9), vidpid.len);
    try testing.expectEqualStrings("37d7:2401", vidpid);
}

test "scan output: summary line format" {
    const allocator = testing.allocator;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    try out.writer().print("{d} device(s) found, {d} matched, {d} unmatched.\n", .{ 3, 2, 1 });
    try testing.expect(std.mem.indexOf(u8, out.items, "3 device(s) found") != null);
    try testing.expect(std.mem.indexOf(u8, out.items, "2 matched") != null);
    try testing.expect(std.mem.indexOf(u8, out.items, "1 unmatched") != null);
}

test "scan output: unmatched capture hint format" {
    const allocator = testing.allocator;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    const vid: u16 = 0x37d7;
    const pid: u16 = 0x2401;
    try out.writer().print("  padctl-capture --vid 0x{x:0>4} --pid 0x{x:0>4}\n", .{ vid, pid });
    try testing.expect(std.mem.indexOf(u8, out.items, "padctl-capture") != null);
    try testing.expect(std.mem.indexOf(u8, out.items, "0x37d7") != null);
    try testing.expect(std.mem.indexOf(u8, out.items, "0x2401") != null);
}

// --- 4. Scan: matching logic ---

test "scan matching: freeEntries on empty slice is no-op" {
    scan_mod.freeEntries(testing.allocator, &.{});
}

test "scan matching: vader5.toml present in devices/" {
    const allocator = testing.allocator;
    // Verify the real file exists and parses — used by scan's config match path.
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    try testing.expectEqual(@as(i64, 0x37d7), parsed.value.device.vid);
    try testing.expectEqual(@as(i64, 0x2401), parsed.value.device.pid);
}

test "scan matching: all device files parse for vid/pid lookup" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer paths.deinit(allocator);
    try testing.expect(paths.items.len >= 13);

    for (paths.items) |p| {
        const parsed = try device_mod.parseFile(allocator, p);
        defer parsed.deinit();
        try testing.expect(parsed.value.device.vid > 0);
        try testing.expect(parsed.value.device.pid > 0);
    }
}

// --- 5. Config subcommands ---

// MED-3: `padctl config edit` — no mapping files present returns NoMappingFound.
test "config edit: no mapping found error" {
    const result = config_edit.run(testing.allocator, null);
    try testing.expectError(error.NoMappingFound, result);
}

// MED-3: `padctl config test` — no hidraw device returns NoHidrawDevice.
test "config test: no hidraw device error" {
    const result = config_test_mod.run(testing.allocator, null, null, std.io.null_writer);
    try testing.expectError(error.NoHidrawDevice, result);
}
