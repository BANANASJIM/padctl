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

const init_poll_interval_ns = 10 * std.time.ns_per_ms;
const init_drain_limit = 64;

fn drainPendingReports(device: DeviceIO) !usize {
    var read_buf: [64]u8 = undefined;
    var drained: usize = 0;
    while (drained < init_drain_limit) {
        _ = device.read(&read_buf) catch |err| switch (err) {
            error.Again => return drained,
            else => return err,
        };
        drained += 1;
    }
    return drained;
}

fn responseMatches(
    response: []const u8,
    response_prefix: []const u8,
    command_prefix: []const u8,
) bool {
    return std.mem.startsWith(u8, response, response_prefix) and
        std.mem.startsWith(u8, response, command_prefix);
}

fn sendAndWaitPrefix(
    device: DeviceIO,
    bytes: []const u8,
    prefix: []const u8,
    command_prefix_len: usize,
    retries: u16,
    report_size: usize,
) !void {
    if (command_prefix_len > bytes.len or
        command_prefix_len > device_mod.MAX_INIT_COMMAND_SIZE)
        return error.InvalidConfig;

    // Reduce the chance that a queued response is mistaken for this command's
    // ACK. This is deliberately bounded and is not a transport-level barrier:
    // a concurrent producer can still enqueue a frame between drain and write.
    const pre_drain_count = if (command_prefix_len > 0)
        try drainPendingReports(device)
    else
        0;

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
    if (prefix.len == 0 and command_prefix_len == 0) {
        std.Thread.sleep(20 * std.time.ns_per_ms);
        return;
    }

    if (retries == 0) return error.InitFailed;

    const command_prefix = bytes[0..command_prefix_len];
    const logged_command_prefix = command_prefix[0..@min(command_prefix.len, 8)];
    var read_buf: [64]u8 = undefined;
    var timer = try std.time.Timer.start();
    const timeout_ns = @as(u64, retries) * init_poll_interval_ns;
    var ignored_count: usize = 0;
    while (timer.read() < timeout_ns) {
        const n = device.read(&read_buf) catch |err| switch (err) {
            error.Again => {
                const elapsed_ns = timer.read();
                if (elapsed_ns >= timeout_ns) break;
                std.Thread.sleep(@min(init_poll_interval_ns, timeout_ns - elapsed_ns));
                continue;
            },
            else => return err,
        };
        if (responseMatches(read_buf[0..n], prefix, command_prefix)) {
            if (command_prefix_len > 0) {
                std.log.debug(
                    "init: strict ACK command_prefix={x} command_prefix_len={d} response_prefix={x} pre_drain={d} ignored={d}",
                    .{ logged_command_prefix, command_prefix.len, prefix, pre_drain_count, ignored_count },
                );
            }
            return;
        }
        ignored_count += 1;
        if (ignored_count % init_drain_limit == 0) std.Thread.yield() catch {};
    }
    if (command_prefix_len > 0) {
        std.log.debug(
            "init: strict ACK timeout command_prefix={x} command_prefix_len={d} response_prefix={x} pre_drain={d} ignored={d}",
            .{ logged_command_prefix, command_prefix.len, prefix, pre_drain_count, ignored_count },
        );
    }
    return error.InitFailed;
}

/// Run device init handshake for a single DeviceIO.
/// For each command hex string: write bytes, then wait for all configured
/// response criteria (static prefix and optional command-prefix correlation).
/// If feature_report is set, send it via HIDIOCSFEATURE after all commands.
pub fn runInitSequence(
    allocator: std.mem.Allocator,
    device: DeviceIO,
    init_config: device_mod.InitConfig,
) !void {
    const prefix: []const u8 = blk: {
        const raw = init_config.response_prefix orelse break :blk &[_]u8{};
        if (raw.len > device_mod.MAX_INIT_COMMAND_SIZE) return error.InvalidConfig;
        for (raw) |b| if (b < 0 or b > 255) return error.InvalidConfig;
        const buf = try allocator.alloc(u8, raw.len);
        for (raw, 0..) |b, j| buf[j] = @intCast(b);
        break :blk buf;
    };
    defer if (init_config.response_prefix != null) allocator.free(prefix);

    const report_size: usize = if (init_config.report_size) |rs| @intCast(rs) else 0;
    const command_prefix_len: usize = if (init_config.response_command_prefix_len) |len| blk: {
        if (len <= 0 or len > device_mod.MAX_INIT_COMMAND_SIZE)
            return error.InvalidConfig;
        break :blk @intCast(len);
    } else 0;
    const require_response = init_config.require_response;
    const has_command = if (init_config.commands) |commands| commands.len > 0 else false;
    const has_response_step = has_command or init_config.enable != null;
    if (require_response and
        (!has_response_step or (prefix.len == 0 and command_prefix_len == 0)))
    {
        return error.InvalidConfig;
    }

    var total: usize = 0;

    if (init_config.commands) |cmds| {
        for (cmds) |cmd| {
            const bytes = try parseHexBytes(allocator, cmd);
            defer allocator.free(bytes);
            sendAndWaitPrefix(device, bytes, prefix, command_prefix_len, 50, report_size) catch |err| {
                if (err == error.InitFailed) {
                    if (require_response) return err;
                    std.log.debug("init command got no ack, continuing", .{});
                } else return err;
            };
        }
        total += cmds.len;
    }

    if (init_config.enable) |enable_cmd| {
        const bytes = try parseHexBytes(allocator, enable_cmd);
        defer allocator.free(bytes);
        sendAndWaitPrefix(device, bytes, prefix, command_prefix_len, 50, report_size) catch |err| {
            if (err == error.InitFailed) {
                if (require_response) return err;
                std.log.debug("enable command got no ack, continuing", .{});
            } else return err;
        };
        total += 1;
    }

    if (init_config.feature_report) |fr| {
        var buf: [64]u8 = .{0} ** 64;
        const n = @min(fr.len, buf.len);
        for (fr[0..n], 0..) |b, i| buf[i] = @intCast(b);
        device.featureReport(buf[0..n]) catch |err| {
            std.log.warn("feature_report ioctl failed: {}", .{err});
            return err;
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

/// Test-only DeviceIO that exposes one queue before the first write and either
/// a single response queue or one queue per write afterwards. This models
/// asynchronous traffic closely enough to distinguish stale reports from
/// responses produced by a particular command.
const WriteTriggeredDeviceIO = struct {
    allocator: std.mem.Allocator,
    before_write: []const []const u8,
    after_write: []const []const u8,
    response_stages: ?[]const []const []const u8 = null,
    before_idx: usize = 0,
    response_idx: usize = 0,
    total_response_reads: usize = 0,
    write_count: usize = 0,
    write_log: std.ArrayList(u8) = .{},

    fn init(
        allocator: std.mem.Allocator,
        before_write: []const []const u8,
        after_write: []const []const u8,
    ) WriteTriggeredDeviceIO {
        return .{
            .allocator = allocator,
            .before_write = before_write,
            .after_write = after_write,
        };
    }

    fn initStaged(
        allocator: std.mem.Allocator,
        before_write: []const []const u8,
        response_stages: []const []const []const u8,
    ) WriteTriggeredDeviceIO {
        return .{
            .allocator = allocator,
            .before_write = before_write,
            .after_write = &.{},
            .response_stages = response_stages,
        };
    }

    fn deinit(self: *WriteTriggeredDeviceIO) void {
        self.write_log.deinit(self.allocator);
    }

    fn deviceIO(self: *WriteTriggeredDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *WriteTriggeredDeviceIO = @ptrCast(@alignCast(ptr));
        const frame = if (self.write_count == 0) blk: {
            if (self.before_idx >= self.before_write.len) return error.Again;
            defer self.before_idx += 1;
            break :blk self.before_write[self.before_idx];
        } else blk: {
            const responses = if (self.response_stages) |stages| stage: {
                const stage_idx = self.write_count - 1;
                if (stage_idx >= stages.len) return error.Again;
                break :stage stages[stage_idx];
            } else self.after_write;
            if (self.response_idx >= responses.len) return error.Again;
            defer {
                self.response_idx += 1;
                self.total_response_reads += 1;
            }
            break :blk responses[self.response_idx];
        };
        const n = @min(buf.len, frame.len);
        @memcpy(buf[0..n], frame[0..n]);
        return n;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *WriteTriggeredDeviceIO = @ptrCast(@alignCast(ptr));
        self.write_log.appendSlice(self.allocator, data) catch return error.Io;
        self.write_count += 1;
        self.response_idx = 0;
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn pollfd(_: *anyopaque) std.posix.pollfd {
        return .{ .fd = -1, .events = 0, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

test "init: Vader input report does not acknowledge init command" {
    const allocator = std.testing.allocator;

    // Vader 5 extended input reports share the broad 5a a5 prefix with
    // command acknowledgements, but 0xef is input data rather than the
    // response to command 0x01.
    const input_report = [_]u8{ 0x5a, 0xa5, 0xef, 0x00 };
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{}, &.{&input_report});
    defer mock.deinit();

    try std.testing.expectError(
        error.InitFailed,
        sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 3, 1, 0),
    );
}

test "init: strict response rejects a late ACK for another opcode" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const late_serial_ack = [_]u8{ 0x5a, 0xa5, 0xa1, 0x01 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{}, &.{&late_serial_ack});
    defer mock.deinit();

    try std.testing.expectError(
        error.InitFailed,
        sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 3, 1, 0),
    );
}

test "init: strict response drains an ACK queued before write" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const stale_ack = [_]u8{ 0x5a, 0xa5, 0x01, 0x01 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{&stale_ack}, &.{});
    defer mock.deinit();

    try std.testing.expectError(
        error.InitFailed,
        sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 3, 1, 0),
    );
    try std.testing.expectEqual(@as(usize, 1), mock.before_idx);
    try std.testing.expectEqual(@as(usize, 1), mock.write_count);
}

test "init: strict response accepts matching ACK produced after write" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const ack = [_]u8{ 0x5a, 0xa5, 0x01, 0x01 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{}, &.{&ack});
    defer mock.deinit();

    try sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 3, 1, 0);
    try std.testing.expectEqualSlices(u8, &command, mock.write_log.items);
}

test "init: command correlation works without a static response prefix" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const ack = [_]u8{ 0x5a, 0xa5, 0x01, 0x01 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{}, &.{&ack});
    defer mock.deinit();

    try sendAndWaitPrefix(mock.deviceIO(), &command, &.{}, 3, 1, 0);
}

test "init: strict response skips input reports until matching ACK" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const input_report = [_]u8{ 0x5a, 0xa5, 0xef, 0x00 };
    const ack = [_]u8{ 0x5a, 0xa5, 0x01, 0x01 };
    var mock = WriteTriggeredDeviceIO.init(allocator, &.{}, &.{
        &input_report, &input_report, &input_report, &input_report, &input_report,
        &input_report, &input_report, &input_report, &input_report, &input_report,
        &input_report, &input_report, &input_report, &input_report, &input_report,
        &input_report, &input_report, &input_report, &input_report, &input_report,
        &input_report, &input_report, &input_report, &input_report, &ack,
    });
    defer mock.deinit();

    try sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 3, 1, 0);
    try std.testing.expectEqual(@as(usize, 25), mock.total_response_reads);
}

test "init: unconfigured command correlation preserves prefix-only matching" {
    const allocator = std.testing.allocator;
    const command = [_]u8{ 0x5a, 0xa5, 0x01, 0x02, 0x03 };
    const input_report = [_]u8{ 0x5a, 0xa5, 0xef, 0x00 };
    var mock = try MockDeviceIO.init(allocator, &.{&input_report});
    defer mock.deinit();

    try sendAndWaitPrefix(mock.deviceIO(), &command, &.{ 0x5a, 0xa5 }, 0, 1, 0);
}

test "init: strict Vader handshake correlates all commands and enable ACKs" {
    const allocator = std.testing.allocator;
    const input_report = [_]u8{ 0x5a, 0xa5, 0xef, 0x00 };
    const ident_ack = [_]u8{ 0x5a, 0xa5, 0x01, 0x01 };
    const serial_ack = [_]u8{ 0x5a, 0xa5, 0xa1, 0x01 };
    const config_read_ack = [_]u8{ 0x5a, 0xa5, 0x02, 0x01 };
    const config_data_ack = [_]u8{ 0x5a, 0xa5, 0x04, 0x01 };
    const enable_ack = [_]u8{ 0x5a, 0xa5, 0x11, 0x01 };
    const ident_responses = [_][]const u8{ &input_report, &ident_ack };
    const serial_responses = [_][]const u8{ &input_report, &serial_ack };
    const config_read_responses = [_][]const u8{ &input_report, &config_read_ack };
    const config_data_responses = [_][]const u8{ &input_report, &config_data_ack };
    const enable_responses = [_][]const u8{ &input_report, &enable_ack };
    const response_stages = [_][]const []const u8{
        &ident_responses,
        &serial_responses,
        &config_read_responses,
        &config_data_responses,
        &enable_responses,
    };
    var mock = WriteTriggeredDeviceIO.initStaged(allocator, &.{}, &response_stages);
    defer mock.deinit();

    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const init_cfg = parsed.value.device.init orelse return error.MissingInit;

    try runInitSequence(allocator, mock.deviceIO(), init_cfg);
    try std.testing.expectEqual(@as(usize, 5), mock.write_count);
    try std.testing.expectEqual(@as(usize, 10), mock.total_response_reads);
    try std.testing.expectEqual(@as(usize, 5 * 32), mock.write_log.items.len);

    const expected_commands = [_][]const u8{
        &.{ 0x5a, 0xa5, 0x01, 0x02, 0x03 },
        &.{ 0x5a, 0xa5, 0xa1, 0x02, 0xa3 },
        &.{ 0x5a, 0xa5, 0x02, 0x02, 0x04 },
        &.{ 0x5a, 0xa5, 0x04, 0x02, 0x06 },
        &.{ 0x5a, 0xa5, 0x11, 0x07, 0xff, 0x01, 0xff, 0xff, 0xff, 0x15, 0x00 },
    };
    for (expected_commands, 0..) |expected, i| {
        const report = mock.write_log.items[i * 32 ..][0..32];
        try std.testing.expectEqualSlices(u8, expected, report[0..expected.len]);
        for (report[expected.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

const FailFeatureReportDeviceIO = struct {
    pub fn deviceIO(self: *FailFeatureReportDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(_: *anyopaque, _: []u8) DeviceIO.ReadError!usize {
        return DeviceIO.ReadError.Again;
    }

    fn write(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        return DeviceIO.WriteError.Io;
    }

    fn pollfd(_: *anyopaque) std.posix.pollfd {
        return .{ .fd = -1, .events = 0, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

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

test "init: runInitSequence: require_response fails on missing ack" {
    const allocator = std.testing.allocator;

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"5a01"},
        .response_prefix = &[_]i64{0x5a},
        .response_command_prefix_len = 1,
        .require_response = true,
    };

    try std.testing.expectError(error.InitFailed, runInitSequence(allocator, dev, init_cfg));
}

test "init: runInitSequence rejects an out-of-range response prefix" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const init_cfg = device_mod.InitConfig{
        .commands = &.{"01"},
        .response_prefix = &.{ 0x5a, 256 },
    };

    try std.testing.expectError(
        error.InvalidConfig,
        runInitSequence(allocator, mock.deviceIO(), init_cfg),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.write_log.items.len);
}

test "init: runInitSequence rejects required response without match criteria" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const init_cfg = device_mod.InitConfig{
        .commands = &.{"01"},
        .require_response = true,
    };

    try std.testing.expectError(
        error.InvalidConfig,
        runInitSequence(allocator, mock.deviceIO(), init_cfg),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.write_log.items.len);
}

test "init: runInitSequence rejects required response without a response step" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const init_cfg = device_mod.InitConfig{
        .response_prefix = &.{0x5a},
        .require_response = true,
        .feature_report = &.{1},
    };

    try std.testing.expectError(
        error.InvalidConfig,
        runInitSequence(allocator, mock.deviceIO(), init_cfg),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.feature_report_log.items.len);
}

test "init: runInitSequence rejects response prefix larger than read buffer" {
    const allocator = std.testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const prefix_values: [device_mod.MAX_INIT_COMMAND_SIZE + 1]i64 = @splat(0x5a);
    const init_cfg = device_mod.InitConfig{
        .commands = &.{"01"},
        .response_prefix = &prefix_values,
    };

    try std.testing.expectError(
        error.InvalidConfig,
        runInitSequence(allocator, mock.deviceIO(), init_cfg),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.write_log.items.len);
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

test "init: runInitSequence: feature_report sent via featureReport path (no commands)" {
    const allocator = std.testing.allocator;

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    // Steam Deck lizard-mode unlock: 0x81 + 63 zero bytes
    const init_cfg = device_mod.InitConfig{
        .feature_report = &[_]i64{ 0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    try runInitSequence(allocator, dev, init_cfg);

    // Nothing written via output report path
    try std.testing.expectEqual(@as(usize, 0), mock.write_log.items.len);
    // 64 bytes sent via featureReport path; first byte is report ID 0x81
    try std.testing.expectEqual(@as(usize, 64), mock.feature_report_log.items.len);
    try std.testing.expectEqual(@as(u8, 0x81), mock.feature_report_log.items[0]);
    // remaining 63 bytes must be zero
    for (mock.feature_report_log.items[1..]) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }
}

test "init: runInitSequence: feature_report after commands" {
    const allocator = std.testing.allocator;

    const resp = [_]u8{ 0x5a, 0xa5 };
    var mock = try MockDeviceIO.init(allocator, &.{&resp});
    defer mock.deinit();
    const dev = mock.deviceIO();

    const init_cfg = device_mod.InitConfig{
        .commands = &[_][]const u8{"aa"},
        .response_prefix = &[_]i64{ 0x5a, 0xa5 },
        .feature_report = &[_]i64{ 0x81, 0, 0 },
    };

    try runInitSequence(allocator, dev, init_cfg);

    try std.testing.expectEqualSlices(u8, &[_]u8{0xaa}, mock.write_log.items);
    try std.testing.expectEqual(@as(usize, 3), mock.feature_report_log.items.len);
    try std.testing.expectEqual(@as(u8, 0x81), mock.feature_report_log.items[0]);
}

test "init: runInitSequence: feature_report write errors propagate" {
    const allocator = std.testing.allocator;

    var failing = FailFeatureReportDeviceIO{};
    const init_cfg = device_mod.InitConfig{
        .feature_report = &[_]i64{ 0x81, 0, 0 },
    };

    try std.testing.expectError(DeviceIO.WriteError.Io, runInitSequence(allocator, failing.deviceIO(), init_cfg));
}
