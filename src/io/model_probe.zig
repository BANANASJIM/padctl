const std = @import("std");
const DeviceIO = @import("device_io.zig").DeviceIO;
const config_device = @import("../config/device.zig");
const ProbeConfig = config_device.ProbeConfig;

const poll_interval_ns = 2 * std.time.ns_per_ms;
pub const reply_window_ms = 100;
pub const attempts = 4;
/// An input frame can match the reply pattern by chance, rarely twice with
/// the same ID.
const confirmations = 2;

pub const Result = union(enum) {
    id: u8,
    no_reply: NoReply,
};

pub const NoReply = struct {
    writes_failed: bool = false,
    frames: usize = 0,
    last_buf: [16]u8 = undefined,
    last_shown: usize = 0,
    last_len: usize = 0,

    pub fn last(self: *const NoReply) []const u8 {
        return self.last_buf[0..self.last_shown];
    }

    fn record(self: *NoReply, frame: []const u8) void {
        self.frames += 1;
        self.last_len = frame.len;
        self.last_shown = @min(frame.len, self.last_buf.len);
        @memcpy(self.last_buf[0..self.last_shown], frame[0..self.last_shown]);
    }
};

pub fn parseReply(probe: *const ProbeConfig, frame: []const u8) ?u8 {
    if (probe.reply_size) |n| if (frame.len != @as(usize, @intCast(n))) return null;
    if (probe.reply_exclude) |ex| if (matches(ex, frame)) return null;
    const off: usize = @intCast(probe.reply.offset);
    if (frame.len < off + probe.reply.expect.len) return null;
    for (probe.reply.expect, 0..) |b, i| {
        if (frame[off + i] != @as(u8, @intCast(b))) return null;
    }
    const id_off: usize = @intCast(probe.id_offset);
    if (frame.len <= id_off) return null;
    return frame[id_off];
}

fn matches(m: config_device.MatchConfig, frame: []const u8) bool {
    const off: usize = @intCast(m.offset);
    if (frame.len < off + m.expect.len) return false;
    for (m.expect, 0..) |b, i| {
        if (frame[off + i] != @as(u8, @intCast(b))) return false;
    }
    return true;
}

pub fn encodeCommand(probe: *const ProbeConfig, buf: *[64]u8) ?[]const u8 {
    var n: usize = 0;
    var i: usize = 0;
    const hex = probe.command;
    while (i < hex.len) {
        if (hex[i] == ' ') {
            i += 1;
            continue;
        }
        if (i + 1 >= hex.len or n >= buf.len) return null;
        const hi = std.fmt.charToDigit(hex[i], 16) catch return null;
        const lo = std.fmt.charToDigit(hex[i + 1], 16) catch return null;
        buf[n] = (hi << 4) | lo;
        n += 1;
        i += 2;
    }
    return buf[0..n];
}

/// Kept across the retries of one plug: a slow pad may answer once per run.
pub const Tally = struct {
    ids: [8]u8 = undefined,
    counts: [8]u8 = undefined,
    n: usize = 0,

    pub fn add(self: *Tally, id: u8) ?u8 {
        const k = for (self.ids[0..self.n], 0..) |s, i| {
            if (s == id) break i;
        } else blk: {
            if (self.n == self.ids.len) return null;
            self.ids[self.n] = id;
            self.counts[self.n] = 0;
            self.n += 1;
            break :blk self.n - 1;
        };
        self.counts[k] +|= 1;
        return if (self.counts[k] >= confirmations) id else null;
    }

    pub fn lone(self: *const Tally) ?u8 {
        return if (self.n == 1) self.ids[0] else null;
    }
};

pub fn run(device: DeviceIO, probe: *const ProbeConfig, tally: *Tally) Result {
    return runWithWindow(device, probe, reply_window_ms, tally);
}

fn runWithWindow(device: DeviceIO, probe: *const ProbeConfig, window_ms: u64, tally: *Tally) Result {
    var none = NoReply{};
    var cmd_buf: [64]u8 = undefined;
    const cmd = encodeCommand(probe, &cmd_buf) orelse return .{ .no_reply = none };
    var read_buf: [64]u8 = undefined;
    var writes_ok: usize = 0;
    for (0..attempts) |_| {
        // Writes occasionally fail on these receivers (SDL ignores it too).
        device.write(cmd) catch continue;
        writes_ok += 1;
        var timer = std.time.Timer.start() catch return .{ .no_reply = none };
        while (timer.read() < window_ms * std.time.ns_per_ms) {
            const n = device.read(&read_buf) catch |err| switch (err) {
                error.Again => {
                    std.Thread.sleep(poll_interval_ns);
                    continue;
                },
                else => return .{ .no_reply = none },
            };
            const id = parseReply(probe, read_buf[0..n]) orelse {
                none.record(read_buf[0..n]);
                continue;
            };
            if (tally.add(id)) |confirmed| return .{ .id = confirmed };
            break; // next send
        }
    }
    none.writes_failed = writes_ok == 0;
    return .{ .no_reply = none };
}

// --- tests ---

const testing = std.testing;

/// Replays `frames` once something has been written; Again otherwise.
const ReplyMock = struct {
    frames: []const []const u8,
    idx: usize = 0,
    writes: usize = 0,
    fail_writes: usize = 0,

    fn init(_: std.mem.Allocator, _: []const []const u8, frames: []const []const u8) ReplyMock {
        return .{ .frames = frames };
    }
    fn deinit(_: *ReplyMock) void {}
    fn deviceIO(self: *ReplyMock) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable = DeviceIO.VTable{ .read = read, .write = write, .feature_report = featureReport, .pollfd = pollfd, .close = close };
    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *ReplyMock = @ptrCast(@alignCast(ptr));
        if (self.writes == 0 or self.idx >= self.frames.len) return error.Again;
        const f = self.frames[self.idx];
        self.idx += 1;
        const n = @min(buf.len, f.len);
        @memcpy(buf[0..n], f[0..n]);
        return n;
    }
    fn write(ptr: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        const self: *ReplyMock = @ptrCast(@alignCast(ptr));
        if (self.fail_writes > 0) {
            self.fail_writes -= 1;
            return error.Io;
        }
        self.writes += 1;
    }
    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {}
    fn pollfd(_: *anyopaque) std.posix.pollfd {
        return .{ .fd = -1, .events = 0, .revents = 0 };
    }
    fn close(_: *anyopaque) void {}
};

const flydigi_probe = ProbeConfig{
    .interface = 2,
    .command = "05 ec 00 00 00 00 00 00 00 00 00 00",
    .reply = .{ .offset = 15, .expect = &.{0xec} },
    .id_offset = 3,
    .ids = &.{84},
};

fn flydigiReply(id: u8) [32]u8 {
    var r = [_]u8{0} ** 32;
    r[0] = 0x04;
    r[3] = id;
    r[15] = 0xec;
    return r;
}

test "model_probe: parseReply reads the ID only from the reply frame" {
    const reply = flydigiReply(84);
    try testing.expectEqual(@as(?u8, 84), parseReply(&flydigi_probe, &reply));
    var input = flydigiReply(84);
    input[15] = 0x00;
    try testing.expectEqual(@as(?u8, null), parseReply(&flydigi_probe, &input));
    try testing.expectEqual(@as(?u8, null), parseReply(&flydigi_probe, reply[0..10]));
}

test "model_probe: encodeCommand decodes spaced hex" {
    var buf: [64]u8 = undefined;
    const cmd = encodeCommand(&flydigi_probe, &buf).?;
    try testing.expectEqual(@as(usize, 12), cmd.len);
    try testing.expectEqual(@as(u8, 0x05), cmd[0]);
    try testing.expectEqual(@as(u8, 0xec), cmd[1]);
}

test "model_probe: run returns the ID from the reply after other frames" {
    const input = [_]u8{ 0x04, 0xfe, 0x66, 0x00 };
    const reply = flydigiReply(28);
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{ &input, &reply, &input, &reply });
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 20, &tally);
    try testing.expectEqual(@as(u8, 28), r.id);
}

test "model_probe: an input frame that looks like a reply is outvoted" {
    // Byte 15 of a Flydigi input report is accelerometer data; one frame
    // matching 0xec by chance must not decide the model.
    var fake = flydigiReply(0x66);
    fake[0] = 0x04;
    const reply = flydigiReply(28);
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{ &fake, &reply, &reply });
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 20, &tally);
    try testing.expectEqual(@as(u8, 28), r.id);
}

test "model_probe: reply_size rejects frames of another length" {
    var sized = flydigi_probe;
    sized.reply_size = 32;
    const reply = flydigiReply(84);
    try testing.expectEqual(@as(?u8, 84), parseReply(&sized, &reply));
    try testing.expectEqual(@as(?u8, null), parseReply(&sized, reply[0..20]));
}

test "model_probe: confirmation carries over between runs" {
    const reply = flydigiReply(84);
    var tally = Tally{};
    var first = ReplyMock.init(testing.allocator, &.{}, &.{&reply});
    try testing.expect(runWithWindow(first.deviceIO(), &flydigi_probe, 5, &tally) == .no_reply);
    try testing.expectEqual(@as(?u8, 84), tally.lone());
    var second = ReplyMock.init(testing.allocator, &.{}, &.{&reply});
    try testing.expectEqual(@as(u8, 84), runWithWindow(second.deviceIO(), &flydigi_probe, 5, &tally).id);
}

test "model_probe: a lone match is not trusted" {
    const reply = flydigiReply(84);
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{&reply});
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 5, &tally);
    try testing.expect(r == .no_reply);
}

test "model_probe: reply_exclude drops input frames that fit the reply pattern" {
    var excl = flydigi_probe;
    excl.reply_exclude = .{ .offset = 1, .expect = &.{0xfe} };
    var input = flydigiReply(0x80);
    input[1] = 0xfe; // 04 fe ... input report, byte 15 happens to be 0xec
    try testing.expectEqual(@as(?u8, null), parseReply(&excl, &input));
    try testing.expectEqual(@as(?u8, 84), parseReply(&excl, &flydigiReply(84)));

    // A resting pad can repeat the same input frame; it must not confirm itself.
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{ &input, &input, &input, &input });
    defer mock.deinit();
    var tally = Tally{};
    try testing.expect(runWithWindow(mock.deviceIO(), &excl, 5, &tally) == .no_reply);
}

test "model_probe: all writes failing is reported" {
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{});
    mock.fail_writes = attempts;
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 5, &tally);
    try testing.expect(r.no_reply.writes_failed);
}

test "model_probe: a failed write is retried" {
    const reply = flydigiReply(84);
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{ &reply, &reply });
    mock.fail_writes = 1;
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 20, &tally);
    try testing.expectEqual(@as(u8, 84), r.id);
}

test "model_probe: run reports what arrived when no reply comes" {
    const input = [_]u8{ 0x04, 0xfe, 0x66, 0x00 };
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{&input});
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 5, &tally);
    try testing.expect(r.no_reply.frames >= 1);
    try testing.expectEqualSlices(u8, &input, r.no_reply.last());
}

test "model_probe: run on a silent device records no frames" {
    var mock = ReplyMock.init(testing.allocator, &.{}, &.{});
    defer mock.deinit();
    var tally = Tally{};
    const r = runWithWindow(mock.deviceIO(), &flydigi_probe, 5, &tally);
    try testing.expectEqual(@as(usize, 0), r.no_reply.frames);
}
