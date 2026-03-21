const std = @import("std");
const DeviceIO = @import("io/device_io.zig").DeviceIO;
const device_mod = @import("config/device.zig");

/// Parse a hex string like "5aa5 0102 03" into bytes (skipping spaces).
pub fn parseHexBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    var out = std.ArrayList(u8){};
    defer out.deinit(allocator);

    var i: usize = 0;
    while (i < hex.len) {
        if (hex[i] == ' ') {
            i += 1;
            continue;
        }
        if (i + 1 >= hex.len) return error.InvalidHex;
        const hi = std.fmt.charToDigit(hex[i], 16) catch return error.InvalidHex;
        const lo = std.fmt.charToDigit(hex[i + 1], 16) catch return error.InvalidHex;
        try out.append(allocator, (hi << 4) | lo);
        i += 2;
    }
    return out.toOwnedSlice(allocator);
}

fn sendAndWaitPrefix(device: DeviceIO, bytes: []const u8, prefix: []const u8, retries: u8) !void {
    try device.write(bytes);
    var read_buf: [64]u8 = undefined;
    var attempt: u8 = 0;
    while (attempt < retries) : (attempt += 1) {
        const n = device.read(&read_buf) catch |err| switch (err) {
            error.Again => {
                std.Thread.sleep(5 * std.time.ns_per_ms);
                continue;
            },
            else => return err,
        };
        if (std.mem.startsWith(u8, read_buf[0..n], prefix)) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.InitFailed;
}

/// Run device init handshake for a single DeviceIO.
/// For each command hex string: write bytes, then retry up to 10 times (5ms apart)
/// waiting for a response whose prefix matches response_prefix.
pub fn runInitSequence(
    allocator: std.mem.Allocator,
    device: DeviceIO,
    init_config: device_mod.InitConfig,
) !void {
    const prefix: []const u8 = blk: {
        const raw = init_config.response_prefix;
        var buf = try allocator.alloc(u8, raw.len);
        for (raw, 0..) |b, j| buf[j] = @intCast(b);
        break :blk buf;
    };
    defer allocator.free(prefix);

    for (init_config.commands) |cmd| {
        const bytes = try parseHexBytes(allocator, cmd);
        defer allocator.free(bytes);
        try sendAndWaitPrefix(device, bytes, prefix, 10);
    }

    if (init_config.enable) |enable_cmd| {
        const bytes = try parseHexBytes(allocator, enable_cmd);
        defer allocator.free(bytes);
        try sendAndWaitPrefix(device, bytes, prefix, 10);
    }
}

// --- tests ---

test "parseHexBytes basic" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "5aa5 0102 03");
    defer allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 }, bytes);
}

test "parseHexBytes no spaces" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "deadbeef");
    defer allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }, bytes);
}

test "parseHexBytes empty" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "");
    defer allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "parseHexBytes invalid char returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidHex, parseHexBytes(allocator, "5xaa"));
}

test "parseHexBytes odd length returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidHex, parseHexBytes(allocator, "5a0"));
}

const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;

test "runInitSequence: sends command and matches response_prefix" {
    const allocator = std.testing.allocator;

    // response: 0x5a, 0xa5, 0x00 — prefix matches [0x5a, 0xa5]
    const resp = [_]u8{ 0x5a, 0xa5, 0x00 };
    var mock = try MockDeviceIO.init(allocator, &.{&resp});
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"5aa5 0101"},
        .response_prefix = &[_]i64{ 0x5a, 0xa5 },
    };

    try runInitSequence(allocator, dev, init_cfg);

    // Verify the command bytes were written
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x5a, 0xa5, 0x01, 0x01 }, mock.write_log.items);
}

test "runInitSequence: exhausted retries returns InitFailed" {
    const allocator = std.testing.allocator;

    // No frames — every read returns Again → InitFailed after 10 retries
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"0101"},
        .response_prefix = &[_]i64{0x5a},
    };

    try std.testing.expectError(error.InitFailed, runInitSequence(allocator, dev, init_cfg));
}

test "runInitSequence: enable command sent after commands" {
    const allocator = std.testing.allocator;

    // Two reads: one for the main command, one for enable
    const resp = [_]u8{ 0x5a, 0xa5 };
    var mock = try MockDeviceIO.init(allocator, &.{ &resp, &resp });
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"0101"},
        .response_prefix = &[_]i64{ 0x5a, 0xa5 },
        .enable = "0202",
    };

    try runInitSequence(allocator, dev, init_cfg);
    // cmd bytes + enable bytes both written
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x01, 0x02, 0x02 }, mock.write_log.items);
}

test "runInitSequence: wrong prefix after retries returns InitFailed" {
    const allocator = std.testing.allocator;

    // Response has wrong prefix
    const resp = [_]u8{ 0xff, 0x00 };
    // Provide 10 identical wrong responses so every retry gets one
    var mock = try MockDeviceIO.init(allocator, &.{
        &resp, &resp, &resp, &resp, &resp,
        &resp, &resp, &resp, &resp, &resp,
    });
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"0101"},
        .response_prefix = &[_]i64{ 0x5a, 0xa5 },
    };

    try std.testing.expectError(error.InitFailed, runInitSequence(allocator, dev, init_cfg));
}
