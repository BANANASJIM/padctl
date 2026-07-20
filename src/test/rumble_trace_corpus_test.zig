//! Characterization tests for public issue #65 rumble traces.
//!
//! These tests characterize field-derived event/write shapes and guard the
//! shipped Vader 5 encoder. They deliberately do not claim USB completion or
//! physical motor state.

const std = @import("std");
const testing = std.testing;

const command = @import("../core/command.zig");
const device = @import("../config/device.zig");

const FRAME_LEN = 32;
const MAX_EVENT_TO_WRITE_LAG_NS = std.time.ns_per_ms;

const FfEvent = struct {
    mono_ns: u64,
    id: u8,
    strong: u16,
    weak: u16,
    duration_ms: u16,
    is_stop: bool,
};

const HidWrite = struct {
    mono_ns: u64,
    strong: u16,
    weak: u16,
    declared_len: u8,
    frame: [FRAME_LEN]u8,
};

const Record = union(enum) {
    ff: FfEvent,
    hid: HidWrite,
};

const Magnitude = struct {
    strong: u16,
    weak: u16,
};

fn parseUnsignedAfter(comptime T: type, line: []const u8, marker: []const u8) !T {
    const marker_pos = std.mem.indexOf(u8, line, marker) orelse return error.MissingField;
    const start = marker_pos + marker.len;
    var end = start;
    while (end < line.len and std.ascii.isDigit(line[end])) : (end += 1) {}
    if (end == start) return error.InvalidField;
    return std.fmt.parseUnsigned(T, line[start..end], 10);
}

fn parseBoolAfter(line: []const u8, marker: []const u8) !bool {
    const marker_pos = std.mem.indexOf(u8, line, marker) orelse return error.MissingField;
    const value = line[marker_pos + marker.len ..];
    if (std.mem.startsWith(u8, value, "true")) return true;
    if (std.mem.startsWith(u8, value, "false")) return false;
    return error.InvalidField;
}

fn parseFfEvent(line: []const u8) !FfEvent {
    return .{
        .mono_ns = try parseUnsignedAfter(u64, line, "[MONO:"),
        .id = try parseUnsignedAfter(u8, line, "FF_EVENT: id="),
        .strong = try parseUnsignedAfter(u16, line, "strong="),
        .weak = try parseUnsignedAfter(u16, line, "weak="),
        .duration_ms = try parseUnsignedAfter(u16, line, "dur="),
        .is_stop = try parseBoolAfter(line, "is_stop="),
    };
}

fn parseHidWrite(line: []const u8) !HidWrite {
    const declared_len = try parseUnsignedAfter(u8, line, "len=");
    if (declared_len != FRAME_LEN) return error.UnexpectedFrameLength;

    const marker = "frame=[";
    const marker_pos = std.mem.indexOf(u8, line, marker) orelse return error.MissingFrame;
    const start = marker_pos + marker.len;
    const end_rel = std.mem.indexOfScalar(u8, line[start..], ']') orelse return error.UnterminatedFrame;
    const frame_text = line[start .. start + end_rel];

    var frame: [FRAME_LEN]u8 = undefined;
    var count: usize = 0;
    var tokens = std.mem.tokenizeScalar(u8, frame_text, ' ');
    while (tokens.next()) |token| {
        if (count >= frame.len) return error.UnexpectedFrameLength;
        frame[count] = std.fmt.parseUnsigned(u8, token, 16) catch return error.InvalidFrameByte;
        count += 1;
    }
    if (count != declared_len) return error.UnexpectedFrameLength;

    return .{
        .mono_ns = try parseUnsignedAfter(u64, line, "[MONO:"),
        .strong = try parseUnsignedAfter(u16, line, "strong="),
        .weak = try parseUnsignedAfter(u16, line, "weak="),
        .declared_len = declared_len,
        .frame = frame,
    };
}

fn parseTrace(allocator: std.mem.Allocator, text: []const u8) ![]Record {
    var records: std.ArrayList(Record) = .{};
    errdefer records.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "FF_EVENT:") != null) {
            try records.append(allocator, .{ .ff = try parseFfEvent(line) });
        } else if (std.mem.indexOf(u8, line, "HID_WRITE:") != null) {
            try records.append(allocator, .{ .hid = try parseHidWrite(line) });
        }
    }
    if (records.items.len == 0) return error.EmptyTrace;
    return records.toOwnedSlice(allocator);
}

fn validateHidFrame(hid: HidWrite) !void {
    if (hid.declared_len != FRAME_LEN) return error.UnexpectedFrameLength;
    if (!std.mem.eql(u8, hid.frame[0..4], &.{ 0x5a, 0xa5, 0x12, 0x06 })) return error.BadHeader;
    if (hid.frame[4] != @as(u8, @intCast(hid.strong >> 8))) return error.StrongMismatch;
    if (hid.frame[5] != @as(u8, @intCast(hid.weak >> 8))) return error.WeakMismatch;
    for (hid.frame[6..8]) |byte| if (byte != 0) return error.BadReservedByte;

    var checksum: u8 = 0;
    for (hid.frame[2..8]) |byte| checksum +%= byte;
    if (hid.frame[8] != checksum) return error.BadChecksum;
    for (hid.frame[9..]) |byte| if (byte != 0) return error.BadReservedByte;
}

fn validateAllFrames(records: []const Record) !void {
    for (records) |record| switch (record) {
        .ff => {},
        .hid => |hid| try validateHidFrame(hid),
    };
}

fn expectParsedMagnitudes(
    records: []const Record,
    expected_ff: []const Magnitude,
    expected_hid: []const Magnitude,
) !void {
    var ff_index: usize = 0;
    var hid_index: usize = 0;
    for (records) |record| switch (record) {
        .ff => |ff| {
            if (ff_index >= expected_ff.len) return error.UnexpectedFfEvent;
            try testing.expectEqual(expected_ff[ff_index].strong, ff.strong);
            try testing.expectEqual(expected_ff[ff_index].weak, ff.weak);
            try testing.expectEqual(@as(u16, 65535), ff.duration_ms);
            try testing.expectEqual(ff.strong == 0 and ff.weak == 0, ff.is_stop);
            ff_index += 1;
        },
        .hid => |hid| {
            if (hid_index >= expected_hid.len) return error.UnexpectedHidWrite;
            try testing.expectEqual(expected_hid[hid_index].strong, hid.strong);
            try testing.expectEqual(expected_hid[hid_index].weak, hid.weak);
            hid_index += 1;
        },
    };
    try testing.expectEqual(expected_ff.len, ff_index);
    try testing.expectEqual(expected_hid.len, hid_index);
}

fn validateTerminalStop(records: []const Record) !void {
    var last_ff: ?FfEvent = null;
    var last_hid: ?HidWrite = null;
    for (records) |record| switch (record) {
        .ff => |ff| last_ff = ff,
        .hid => |hid| last_hid = hid,
    };

    const ff = last_ff orelse return error.MissingTerminalStop;
    const hid = last_hid orelse return error.MissingTerminalStop;
    if (!ff.is_stop or ff.strong != 0 or ff.weak != 0) return error.MissingTerminalStop;
    if (hid.strong != 0 or hid.weak != 0) return error.MissingTerminalStop;
    if (hid.mono_ns < ff.mono_ns or hid.mono_ns - ff.mono_ns > MAX_EVENT_TO_WRITE_LAG_NS)
        return error.StopWriteLag;
}

fn validateOneToOne(records: []const Record) !void {
    var pending: ?FfEvent = null;
    for (records) |record| switch (record) {
        .ff => |ff| {
            if (pending != null) return error.UnpairedFfEvent;
            pending = ff;
        },
        .hid => |hid| {
            const ff = pending orelse return error.UnpairedHidWrite;
            if (ff.strong != hid.strong or ff.weak != hid.weak) return error.EventWriteMismatch;
            if (hid.mono_ns < ff.mono_ns or hid.mono_ns - ff.mono_ns > MAX_EVENT_TO_WRITE_LAG_NS)
                return error.EventWriteLag;
            pending = null;
        },
    };
    if (pending != null) return error.UnpairedFfEvent;
}

fn expectSixtyHzCadence(records: []const Record) !void {
    var previous: ?u64 = null;
    var sixty_hz_deltas: usize = 0;
    for (records) |record| switch (record) {
        .ff => {},
        .hid => |hid| {
            if (previous) |prev| {
                const delta = hid.mono_ns - prev;
                if (delta >= 15 * std.time.ns_per_ms and delta <= 18 * std.time.ns_per_ms)
                    sixty_hz_deltas += 1;
            }
            previous = hid.mono_ns;
        },
    };
    try testing.expect(sixty_hz_deltas >= 5);
}

fn validateLatestWinsThrottle(records: []const Record) !void {
    var latest_ff: ?FfEvent = null;
    var previous_ff_ns: ?u64 = null;
    var previous_nonzero_hid_ns: ?u64 = null;
    var fast_ff_deltas: usize = 0;
    var throttled_hid_deltas: usize = 0;
    var stop_inside_throttle_window = false;
    var ff_count: usize = 0;
    var hid_count: usize = 0;

    for (records) |record| switch (record) {
        .ff => |ff| {
            if (previous_ff_ns) |prev| {
                if (ff.mono_ns - prev < 3 * std.time.ns_per_ms) fast_ff_deltas += 1;
            }
            previous_ff_ns = ff.mono_ns;
            latest_ff = ff;
            ff_count += 1;
        },
        .hid => |hid| {
            const ff = latest_ff orelse return error.UnpairedHidWrite;
            if (hid.mono_ns < ff.mono_ns) return error.EventWriteLag;
            if (ff.strong != hid.strong or ff.weak != hid.weak) return error.LatestEventNotWritten;
            if (hid.strong != 0 or hid.weak != 0) {
                if (previous_nonzero_hid_ns) |prev| {
                    const delta = hid.mono_ns - prev;
                    if (delta < 10 * std.time.ns_per_ms) return error.NonzeroWriteInsideThrottleWindow;
                    if (delta >= 10 * std.time.ns_per_ms and delta <= 12 * std.time.ns_per_ms)
                        throttled_hid_deltas += 1;
                }
                previous_nonzero_hid_ns = hid.mono_ns;
            } else if (previous_nonzero_hid_ns) |prev| {
                if (hid.mono_ns - prev < 10 * std.time.ns_per_ms)
                    stop_inside_throttle_window = true;
            }
            hid_count += 1;
        },
    };

    try testing.expect(ff_count > hid_count);
    try testing.expect(fast_ff_deltas >= 16);
    try testing.expect(throttled_hid_deltas >= 2);
    try testing.expect(stop_inside_throttle_window);
}

fn expectShippedVaderEncoder(records: []const Record) !void {
    const allocator = testing.allocator;
    var parsed = try device.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();

    const commands = parsed.value.commands orelse return error.MissingCommands;
    const rumble = commands.map.get("rumble") orelse return error.MissingRumbleCommand;
    for (records) |record| switch (record) {
        .ff => {},
        .hid => |hid| {
            const encoded = try command.fillTemplate(allocator, rumble.template, &.{
                .{ .name = "strong", .value = hid.strong },
                .{ .name = "weak", .value = hid.weak },
            });
            defer allocator.free(encoded);
            if (rumble.checksum) |*checksum| command.applyChecksum(encoded, checksum);
            try testing.expectEqualSlices(u8, &hid.frame, encoded);
        },
    };
}

test "issue65 field characterization: 60 Hz events map one-to-one to valid Vader frames and terminal stop" {
    const records = try parseTrace(testing.allocator, @embedFile("fixtures/issue65_rumble/daniel_60hz_stop.log"));
    defer testing.allocator.free(records);

    const expected = [_]Magnitude{
        .{ .strong = 65535, .weak = 65535 },
        .{ .strong = 54795, .weak = 54795 },
        .{ .strong = 40236, .weak = 40236 },
        .{ .strong = 26824, .weak = 26824 },
        .{ .strong = 15496, .weak = 15496 },
        .{ .strong = 6769, .weak = 6769 },
        .{ .strong = 1413, .weak = 1413 },
        .{ .strong = 0, .weak = 0 },
    };
    try testing.expectEqual(@as(usize, 16), records.len);
    try expectParsedMagnitudes(records, &expected, &expected);
    try validateAllFrames(records);
    try validateOneToOne(records);
    try validateTerminalStop(records);
    try expectSixtyHzCadence(records);
    try expectShippedVaderEncoder(records);
}

test "issue65 field characterization: strong-only events pin encoder byte placement" {
    const records = try parseTrace(testing.allocator, @embedFile("fixtures/issue65_rumble/daniel_strong_only_stop.log"));
    defer testing.allocator.free(records);

    const expected = [_]Magnitude{
        .{ .strong = 65535, .weak = 0 },
        .{ .strong = 49194, .weak = 0 },
        .{ .strong = 13977, .weak = 0 },
        .{ .strong = 0, .weak = 0 },
    };
    try testing.expectEqual(@as(usize, 8), records.len);
    try expectParsedMagnitudes(records, &expected, &expected);
    try validateAllFrames(records);
    try validateOneToOne(records);
    try validateTerminalStop(records);
    try expectShippedVaderEncoder(records);
}

test "issue65 field characterization: dense events show latest-wins writes and stop inside throttle window" {
    const records = try parseTrace(testing.allocator, @embedFile("fixtures/issue65_rumble/dreadtusk_throttled_stop.log"));
    defer testing.allocator.free(records);

    const expected_ff = [_]Magnitude{
        .{ .strong = 1228, .weak = 1228 },
        .{ .strong = 1154, .weak = 1154 },
        .{ .strong = 1080, .weak = 1080 },
        .{ .strong = 1006, .weak = 1006 },
        .{ .strong = 932, .weak = 932 },
        .{ .strong = 858, .weak = 858 },
        .{ .strong = 785, .weak = 785 },
        .{ .strong = 712, .weak = 712 },
        .{ .strong = 639, .weak = 639 },
        .{ .strong = 565, .weak = 565 },
        .{ .strong = 492, .weak = 492 },
        .{ .strong = 420, .weak = 420 },
        .{ .strong = 347, .weak = 347 },
        .{ .strong = 274, .weak = 274 },
        .{ .strong = 202, .weak = 202 },
        .{ .strong = 130, .weak = 130 },
        .{ .strong = 58, .weak = 58 },
        .{ .strong = 0, .weak = 0 },
    };
    const expected_hid = [_]Magnitude{
        .{ .strong = 1228, .weak = 1228 },
        .{ .strong = 785, .weak = 785 },
        .{ .strong = 347, .weak = 347 },
        .{ .strong = 0, .weak = 0 },
    };
    try testing.expectEqual(@as(usize, 22), records.len);
    try expectParsedMagnitudes(records, &expected_ff, &expected_hid);
    try validateAllFrames(records);
    try validateLatestWinsThrottle(records);
    try validateTerminalStop(records);
    try expectShippedVaderEncoder(records);
}

test "issue65 trace oracle rejects a corrupted checksum" {
    const records = try parseTrace(testing.allocator, @embedFile("fixtures/issue65_rumble/daniel_60hz_stop.log"));
    defer testing.allocator.free(records);

    var corrupted: ?HidWrite = null;
    for (records) |record| switch (record) {
        .ff => {},
        .hid => |hid| {
            corrupted = hid;
            break;
        },
    };
    var hid = corrupted orelse return error.MissingFrame;
    hid.frame[8] ^= 0x01;
    try testing.expectError(error.BadChecksum, validateHidFrame(hid));
}

test "issue65 trace parser rejects a truncated declared frame" {
    const truncated =
        "[trace-derived] [MONO:1] debug(rumble): [Flydigi Vader 5 Pro] " ++
        "HID_WRITE: cmd=rumble strong=0 weak=0 iface=0 len=32 " ++
        "frame=[5a a5 12 06 00 00 00 00 18 ]\n";
    try testing.expectError(error.UnexpectedFrameLength, parseTrace(testing.allocator, truncated));
}

test "issue65 trace oracle rejects a missing terminal stop" {
    const records = try parseTrace(testing.allocator, @embedFile("fixtures/issue65_rumble/daniel_60hz_stop.log"));
    defer testing.allocator.free(records);
    const copy = try testing.allocator.dupe(Record, records);
    defer testing.allocator.free(copy);

    var index = copy.len;
    while (index > 0) {
        index -= 1;
        switch (copy[index]) {
            .ff => |ff| {
                var changed = ff;
                changed.is_stop = false;
                copy[index] = .{ .ff = changed };
                break;
            },
            .hid => {},
        }
    }
    try testing.expectError(error.MissingTerminalStop, validateTerminalStop(copy));
}
