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

fn sendAndWaitPrefix(device: DeviceIO, bytes: []const u8, prefix: []const u8, retries: u16, report_size: usize) !void {
    // Zero-pad to report_size to match HID output report length
    var pad_buf: [64]u8 = .{0} ** 64;
    if (bytes.len > pad_buf.len)
        std.log.warn("init command {d} bytes exceeds {d}-byte buffer, truncated", .{ bytes.len, pad_buf.len });
    if (report_size > pad_buf.len)
        std.log.warn("report_size {d} exceeds {d}-byte buffer, write capped", .{ report_size, pad_buf.len });
    const send_len = @max(bytes.len, report_size);
    const copy_len = @min(bytes.len, pad_buf.len);
    @memcpy(pad_buf[0..copy_len], bytes[0..copy_len]);
    try device.write(pad_buf[0..@min(send_len, pad_buf.len)]);
    if (prefix.len == 0) {
        std.Thread.sleep(20 * std.time.ns_per_ms);
        return;
    }
    var read_buf: [64]u8 = undefined;
    var attempt: u16 = 0;
    while (attempt < retries) : (attempt += 1) {
        const n = device.read(&read_buf) catch |err| switch (err) {
            error.Again => {
                std.Thread.sleep(10 * std.time.ns_per_ms);
                continue;
            },
            else => return err,
        };
        if (std.mem.startsWith(u8, read_buf[0..n], prefix)) return;
        std.Thread.sleep(10 * std.time.ns_per_ms);
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

    const report_size: usize = if (init_config.report_size) |rs| @intCast(rs) else 0;

    for (init_config.commands) |cmd| {
        const bytes = try parseHexBytes(allocator, cmd);
        defer allocator.free(bytes);
        sendAndWaitPrefix(device, bytes, prefix, 50, report_size) catch |err| {
            if (err == error.InitFailed) {
                std.log.debug("init command got no ack, continuing", .{});
            } else return err;
        };
    }

    var total: usize = init_config.commands.len;

    if (init_config.enable) |enable_cmd| {
        const bytes = try parseHexBytes(allocator, enable_cmd);
        defer allocator.free(bytes);
        sendAndWaitPrefix(device, bytes, prefix, 50, report_size) catch |err| {
            if (err == error.InitFailed) {
                std.log.debug("enable command got no ack, continuing", .{});
            } else return err;
        };
        total += 1;
    }

    std.log.info("init: sent {d} commands", .{total});
}

// --- tests ---

test "init: parseHexBytes basic" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "5aa5 0102 03");
    defer allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 }, bytes);
}

test "init: parseHexBytes no spaces" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "deadbeef");
    defer allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }, bytes);
}

test "init: parseHexBytes empty" {
    const allocator = std.testing.allocator;
    const bytes = try parseHexBytes(allocator, "");
    defer allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "init: parseHexBytes invalid char returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidHex, parseHexBytes(allocator, "5xaa"));
}

test "init: parseHexBytes odd length returns error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidHex, parseHexBytes(allocator, "5a0"));
}

const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;

test "init: runInitSequence: sends command and matches response_prefix" {
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

test "init: runInitSequence: exhausted retries logs warning and continues" {
    const allocator = std.testing.allocator;

    // No frames — every read returns Again → warns but does not fail
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"0101"},
        .response_prefix = &[_]i64{0x5a},
    };

    try runInitSequence(allocator, dev, init_cfg);
}

test "init: runInitSequence: enable command sent after commands" {
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

test "init: runInitSequence: wrong prefix after retries logs warning and continues" {
    const allocator = std.testing.allocator;

    // Response has wrong prefix — warns but does not fail
    const resp = [_]u8{ 0xff, 0x00 };
    // Provide 50 identical wrong responses so every retry gets one
    var mock = try MockDeviceIO.init(allocator, &.{
        &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp,
        &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp,
        &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp,
        &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp,
        &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp, &resp,
    });
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"0101"},
        .response_prefix = &[_]i64{ 0x5a, 0xa5 },
    };

    try runInitSequence(allocator, dev, init_cfg);
}
