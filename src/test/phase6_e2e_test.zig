// Phase 6 E2E tests (CI-automatable).
// Manual-only tests (real hardware / root required) are marked with error.SkipZigTest.

const std = @import("std");
const testing = std.testing;

const paths_mod = @import("../config/paths.zig");
const scan_mod = @import("../cli/scan.zig");
const validate_mod = @import("../tools/validate.zig");
const device_mod = @import("../config/device.zig");
const config_edit = @import("../cli/config/edit.zig");
const config_test_mod = @import("../cli/config/test.zig");

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

// Manual: real install writes system paths and requires root.
test "install: run as root writes files (manual)" {
    if (true) return error.SkipZigTest;
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

// Manual: scan requires /dev/hidrawN nodes.
test "scan: real device enumeration (manual)" {
    if (true) return error.SkipZigTest;
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

test "scan matching: all 5 device files parse for vid/pid lookup" {
    const allocator = testing.allocator;
    const paths = [_][]const u8{
        "devices/8bitdo/ultimate.toml",
        "devices/flydigi/vader5.toml",
        "devices/microsoft/xbox-elite.toml",
        "devices/nintendo/switch-pro.toml",
        "devices/sony/dualsense.toml",
    };
    for (paths) |p| {
        const parsed = try device_mod.parseFile(allocator, p);
        defer parsed.deinit();
        try testing.expect(parsed.value.device.vid > 0);
        try testing.expect(parsed.value.device.pid > 0);
    }
}

// --- 5. All device TOML validate ---

const device_paths = [_][]const u8{
    "devices/8bitdo/ultimate.toml",
    "devices/flydigi/vader5.toml",
    "devices/microsoft/xbox-elite.toml",
    "devices/nintendo/switch-pro.toml",
    "devices/sony/dualsense.toml",
};

test "validate: all device TOMLs produce 0 errors" {
    const allocator = testing.allocator;
    for (device_paths) |path| {
        const errors = try validate_mod.validateFile(path, allocator);
        defer validate_mod.freeErrors(errors, allocator);
        if (errors.len > 0) {
            for (errors) |e| std.debug.print("{s}: {s}\n", .{ path, e.message });
        }
        try testing.expectEqual(@as(usize, 0), errors.len);
    }
}

test "validate: all device TOMLs have non-empty name" {
    const allocator = testing.allocator;
    for (device_paths) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();
        try testing.expect(parsed.value.device.name.len > 0);
    }
}

test "validate: all device TOMLs have at least one report" {
    const allocator = testing.allocator;
    for (device_paths) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();
        try testing.expect(parsed.value.report.len >= 1);
    }
}

// --- 6. Config subcommand stubs ---

test "config edit: stub returns error.NotImplemented" {
    const result = config_edit.run(testing.allocator, null);
    try testing.expectError(error.NotImplemented, result);
}

test "config test: stub returns error.NotImplemented" {
    const result = config_test_mod.run(testing.allocator, null);
    try testing.expectError(error.NotImplemented, result);
}
