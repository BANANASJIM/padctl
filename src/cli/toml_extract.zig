const std = @import("std");

pub const DeviceInfo = struct {
    vid: u16,
    pid: u16,
    block_kernel_drivers: []const []const u8,
};

pub fn freeDeviceInfo(allocator: std.mem.Allocator, info: DeviceInfo) void {
    for (info.block_kernel_drivers) |d| allocator.free(d);
    if (info.block_kernel_drivers.len > 0) allocator.free(info.block_kernel_drivers);
}

fn isFieldKey(line: []const u8, key: []const u8) bool {
    if (!std.mem.startsWith(u8, line, key)) return false;
    if (line.len == key.len) return true;
    const next = line[key.len];
    return next == '=' or next == ' ' or next == '\t';
}

fn parseHexOrDec(comptime T: type, s: []const u8) !T {
    const t = std.mem.trim(u8, s, " \t\r");
    if (std.mem.startsWith(u8, t, "0x") or std.mem.startsWith(u8, t, "0X"))
        return std.fmt.parseInt(T, t[2..], 16);
    return std.fmt.parseInt(T, t, 10);
}

fn parseStringArray(allocator: std.mem.Allocator, value: []const u8) ![]const []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len < 2 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']') return &.{};
    const inner = trimmed[1 .. trimmed.len - 1];
    if (std.mem.trim(u8, inner, " \t").len == 0) return &.{};

    var count: usize = 0;
    var it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |_| count += 1;

    const result = try allocator.alloc([]const u8, count);
    var idx: usize = 0;
    it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |elem| {
        const clean = std.mem.trim(u8, elem, " \t\"'");
        if (!isValidIdentifier(clean)) {
            for (result[0..idx]) |prev| allocator.free(prev);
            allocator.free(result);
            return &.{};
        }
        result[idx] = try allocator.dupe(u8, clean);
        idx += 1;
    }
    return result;
}

fn isValidIdentifier(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
    }
    return true;
}

/// Parse VID, PID, and block_kernel_drivers from raw TOML text.
/// Only fields inside the [device] section are considered.
/// Returns null if no [device] section with both vid and pid exists.
pub fn extractDeviceVidPid(allocator: std.mem.Allocator, content: []const u8) !?DeviceInfo {
    var vid: ?u16 = null;
    var pid: ?u16 = null;
    var block_drivers: []const []const u8 = &.{};
    var in_device_section = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0 and trimmed[0] == '[') {
            in_device_section = std.mem.startsWith(u8, trimmed, "[device]");
            continue;
        }
        if (!in_device_section) continue;

        if (isFieldKey(trimmed, "vid")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t#");
                vid = parseHexOrDec(u16, val) catch continue;
            }
        } else if (isFieldKey(trimmed, "pid")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t#");
                pid = parseHexOrDec(u16, val) catch continue;
            }
        } else if (isFieldKey(trimmed, "block_kernel_drivers")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                // First occurrence wins — ignore duplicates to avoid leak
                if (block_drivers.len == 0) {
                    block_drivers = parseStringArray(allocator, trimmed[eq + 1 ..]) catch &.{};
                }
            }
        }
    }

    if (vid == null or pid == null) {
        freeDeviceInfo(allocator, .{ .vid = 0, .pid = 0, .block_kernel_drivers = block_drivers });
        return null;
    }
    return DeviceInfo{ .vid = vid.?, .pid = pid.?, .block_kernel_drivers = block_drivers };
}

// --- tests ---

test "extractDeviceVidPid: basic [device] section" {
    const toml =
        "[device]\n" ++
        "vid = 0x1234\n" ++
        "pid = 0x5678\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    defer if (result) |r| freeDeviceInfo(std.testing.allocator, r);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 0x1234), result.?.vid);
    try std.testing.expectEqual(@as(u16, 0x5678), result.?.pid);
}

test "extractDeviceVidPid: ignores [output] vid/pid when [output] precedes [device]" {
    const toml =
        "[output]\n" ++
        "vid = 0x045E\n" ++
        "pid = 0x028E\n" ++
        "[device]\n" ++
        "vid = 0x1234\n" ++
        "pid = 0x5678\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    defer if (result) |r| freeDeviceInfo(std.testing.allocator, r);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 0x1234), result.?.vid);
    try std.testing.expectEqual(@as(u16, 0x5678), result.?.pid);
}

test "extractDeviceVidPid: handles [device] before any other section" {
    const toml =
        "[device]\n" ++
        "vid = 0xABCD\n" ++
        "pid = 0xEF01\n" ++
        "[output]\n" ++
        "vid = 0x0001\n" ++
        "pid = 0x0002\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    defer if (result) |r| freeDeviceInfo(std.testing.allocator, r);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u16, 0xABCD), result.?.vid);
    try std.testing.expectEqual(@as(u16, 0xEF01), result.?.pid);
}

test "extractDeviceVidPid: duplicate block_kernel_drivers does not leak" {
    const toml =
        "[device]\n" ++
        "vid = 0x1234\n" ++
        "pid = 0x5678\n" ++
        "block_kernel_drivers = [\"xpad\"]\n" ++
        "block_kernel_drivers = [\"xboxdrv\"]\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    defer if (result) |r| freeDeviceInfo(std.testing.allocator, r);
    try std.testing.expect(result != null);
    // First occurrence wins
    try std.testing.expectEqual(@as(usize, 1), result.?.block_kernel_drivers.len);
    try std.testing.expectEqualStrings("xpad", result.?.block_kernel_drivers[0]);
}

test "extractDeviceVidPid: no [device] section returns null" {
    const toml =
        "[output]\n" ++
        "vid = 0x045E\n" ++
        "pid = 0x028E\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    try std.testing.expect(result == null);
}

test "extractDeviceVidPid: missing pid returns null" {
    const toml =
        "[device]\n" ++
        "vid = 0x1234\n";
    const result = try extractDeviceVidPid(std.testing.allocator, toml);
    try std.testing.expect(result == null);
}
