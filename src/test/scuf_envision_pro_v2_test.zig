// Author-reported wire fixtures, independent of the production TOML layout.
// These checks prove decoding behavior, not hardware or factory-map validation.
const std = @import("std");
const testing = std.testing;
const device = @import("../config/device.zig");
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const state = @import("../core/state.zig");
const helpers = @import("helpers.zig");
const uinput = @import("../io/uinput.zig");
const c = @cImport({
    @cInclude("linux/input-event-codes.h");
});
const config_path = "devices/scuf/envision-pro-v2.toml";

fn button(id: state.ButtonId) u64 {
    return @as(u64, 1) << @intFromEnum(id);
}

// Report 06: sticks in bytes 1..8, two adjacent 10-bit triggers followed
// immediately by the hat nibble. Never derive packet positions from TOML.
fn packet(lt: u16, rt: u16, hat: u8) [16]u8 {
    var raw = [_]u8{0} ** 16;
    raw[0] = 0x06;
    raw[9] = @truncate(lt);
    raw[10] = @as(u8, @intCast(lt >> 8)) | @as(u8, @truncate(rt << 2));
    raw[11] = @as(u8, @intCast(rt >> 6)) | (hat << 4);
    return raw;
}

// Positive integer scale uses truncation: 10-bit full scale is 1023.
fn scaled(raw: u16) u8 {
    return @intCast(@as(u32, raw) * 255 / 1023);
}

test "SCUF: full trigger travel is monotonic and independent of adjacent fields" {
    const parsed = try device.parseFile(testing.allocator, config_path);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    const held_values = [_]u16{ 0, 255, 256, 512, 1023 };
    for (held_values) |held| {
        for (0..16) |hat| {
            var previous: u8 = 0;
            for (0..1024) |travel| {
                const value: u16 = @intCast(travel);
                const left = packet(value, held, @intCast(hat));
                const right = packet(held, value, @intCast(hat));
                const dl = (try interp.processReport(3, &left)) orelse return error.NoMatch;
                const dr = (try interp.processReport(3, &right)) orelse return error.NoMatch;
                try testing.expectEqual(@as(?u8, scaled(value)), dl.lt);
                try testing.expectEqual(@as(?u8, scaled(held)), dl.rt);
                try testing.expectEqual(@as(?u8, scaled(held)), dr.lt);
                try testing.expectEqual(@as(?u8, scaled(value)), dr.rt);
                try testing.expectEqual(dl.buttons, dr.buttons);
                try testing.expect(dl.lt.? >= previous);
                previous = dl.lt.?;
            }
            try testing.expectEqual(@as(u8, 255), previous);
        }
    }
}

test "SCUF: original trigger declarations fail the full-range oracle" {
    var parsed = try device.parseFile(testing.allocator, config_path);
    defer parsed.deinit();
    // Recreate only the contributor's original trigger declarations in memory.
    // The TOML stays unchanged; the same production compiler/decoder runs both.
    const fields = &parsed.value.report[0].fields.?;
    fields.map.getPtr("lt").?.* = .{ .offset = 9, .type = "u8" };
    fields.map.getPtr("rt").?.transform = null;
    const old = Interpreter.init(&parsed.value);
    const before = packet(255, 255, 8);
    const after = packet(256, 256, 8);
    const db = (try old.processReport(3, &before)).?;
    const da = (try old.processReport(3, &after)).?;
    try testing.expectEqual(@as(?u8, 255), db.lt);
    try testing.expectEqual(@as(?u8, 0), da.lt); // old low-byte wraparound
    try testing.expectEqual(@as(?u8, 255), da.rt); // old early saturation
    for ([_]u16{ 255, 256, 512 }) |value| {
        const raw = packet(value, value, 8);
        const delta = (try old.processReport(3, &raw)).?;
        try testing.expect(delta.lt.? != scaled(value));
        try testing.expect(delta.rt.? != scaled(value));
    }
    const full = packet(1023, 1023, 8);
    const df = (try old.processReport(3, &full)).?;
    try testing.expectEqual(@as(?u8, 255), df.lt);
    try testing.expectEqual(@as(?u8, 255), df.rt);
}

test "SCUF: hats reach interpreted buttons and passthrough output axes" {
    const parsed = try device.parseFile(testing.allocator, config_path);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    var mapping = try helpers.makeMapper("", testing.allocator);
    defer mapping.deinit();
    const up = button(.DPadUp);
    const down = button(.DPadDown);
    const left = button(.DPadLeft);
    const right = button(.DPadRight);
    const masks = [_]u64{ up, up | right, right, down | right, down, down | left, left, up | left };
    const xs = [_]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
    const ys = [_]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };
    try testing.expect(uinput.dpadIsHat(&parsed.value.output.?));
    for (0..16) |hat| {
        var raw = packet(255, 512, @intCast(hat));
        raw[12] = 1; // A held while the hat changes
        const delta = (try interp.processReport(3, &raw)).?;
        const mask = (if (hat < 8) masks[hat] else 0) | button(.A);
        try testing.expectEqual(@as(?u64, mask), delta.buttons);
        const events = try mapping.mapper.apply(delta, 1, @intCast(hat + 1));
        try testing.expectEqual(mask, events.gamepad.buttons);
        try testing.expectEqual(if (hat < 8) xs[hat] else @as(i8, 0), events.gamepad.dpad_x);
        try testing.expectEqual(if (hat < 8) ys[hat] else @as(i8, 0), events.gamepad.dpad_y);
        try testing.expectEqual(scaled(255), events.gamepad.lt);
        try testing.expectEqual(scaled(512), events.gamepad.rt);
    }
}

test "SCUF: individual reported button bits and releases survive passthrough" {
    const parsed = try device.parseFile(testing.allocator, config_path);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    // Actual Linux event-code resolution also records which decoded inputs
    // deliberately have no default output; personal mappings may still use them.
    const codes = try uinput.resolveButtonCodes(&parsed.value.output.?);
    const output_ids = [_]state.ButtonId{ .X, .Y, .M1, .M2, .M3, .M4, .LM, .RM, .C, .Z, .O };
    const expected_codes = [_]u16{ c.BTN_NORTH, c.BTN_WEST, c.BTN_TRIGGER_HAPPY8, c.BTN_TRIGGER_HAPPY7, c.BTN_TRIGGER_HAPPY6, c.BTN_TRIGGER_HAPPY5, c.BTN_TRIGGER_HAPPY11, c.BTN_TRIGGER_HAPPY12, 0, 0, 0 };
    for (output_ids, expected_codes) |id, expected| try testing.expectEqual(expected, codes[@intFromEnum(id)]);
    var mapping = try helpers.makeMapper("", testing.allocator);
    defer mapping.deinit();
    const ids = [_]state.ButtonId{ .A, .B, .X, .Y, .LB, .RB, .Select, .Start, .LS, .RS, .Home, .C, .Z, .O, .M1, .M2, .M3, .M4, .LM, .RM };
    const wire_bits = [_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 19, 20, 21, 22, 23, 24 };
    for (ids, wire_bits) |id, bit| {
        var raw = packet(0, 0, 8);
        raw[12 + bit / 8] = @as(u8, 1) << @as(u3, @intCast(bit % 8));
        const delta = (try interp.processReport(3, &raw)).?;
        try testing.expectEqual(@as(?u64, button(id)), delta.buttons);
        const events = try mapping.mapper.apply(delta, 1, 0);
        try testing.expectEqual(button(id), events.gamepad.buttons);
        const released = packet(0, 0, 8);
        const release_delta = (try interp.processReport(3, &released)).?;
        try testing.expectEqual(@as(?u64, 0), release_delta.buttons);
        const release_events = try mapping.mapper.apply(release_delta, 1, 1);
        try testing.expectEqual(@as(u64, 0), release_events.gamepad.buttons);
    }
}

test "SCUF: signed sticks and report framing preserve the production contract" {
    const parsed = try device.parseFile(testing.allocator, config_path);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    try testing.expectEqual(@as(i64, 0x1b1c), parsed.value.device.vid);
    try testing.expectEqual(@as(i64, 0x3a08), parsed.value.device.pid);
    // Signed little-endian endpoints and opposite signs, not config-derived.
    var raw = [_]u8{ 0x06, 0x00, 0x80, 0xff, 0x7f, 0xff, 0xff, 0x01, 0x00, 0, 0, 0x80, 0, 0, 0, 0 };
    const delta = (try interp.processReport(3, &raw)).?;
    try testing.expectEqual(@as(?i16, -32768), delta.ax);
    try testing.expectEqual(@as(?i16, 32767), delta.ay);
    try testing.expectEqual(@as(?i16, -1), delta.rx);
    try testing.expectEqual(@as(?i16, 1), delta.ry);
    // Both endpoints on every stick field, with no inferred Y inversion.
    for ([_][2]u8{ .{ 0x00, 0x80 }, .{ 0xff, 0x7f } }, [_]i16{ -32768, 32767 }) |bytes, expected| {
        var endpoints = packet(0, 0, 8);
        for ([_]usize{ 1, 3, 5, 7 }) |offset| @memcpy(endpoints[offset..][0..2], &bytes);
        const de = (try interp.processReport(3, &endpoints)).?;
        try testing.expectEqual(@as(?i16, expected), de.ax);
        try testing.expectEqual(@as(?i16, expected), de.ay);
        try testing.expectEqual(@as(?i16, expected), de.rx);
        try testing.expectEqual(@as(?i16, expected), de.ry);
    }
    const center = packet(0, 0, 8);
    const dc = (try interp.processReport(3, &center)).?;
    try testing.expectEqual(@as(?i16, 0), dc.ax);
    try testing.expectEqual(@as(?i16, 0), dc.ay);
    try testing.expectEqual(@as(?i16, 0), dc.rx);
    try testing.expectEqual(@as(?i16, 0), dc.ry);
    try testing.expectEqual(@as(?state.GamepadStateDelta, null), try interp.processReport(2, &raw));
    try testing.expectEqual(@as(?state.GamepadStateDelta, null), try interp.processReport(3, raw[0..15]));
    raw[0] = 0x05;
    try testing.expectEqual(@as(?state.GamepadStateDelta, null), try interp.processReport(3, &raw));
    var longer = [_]u8{0} ** 17;
    @memcpy(longer[0..16], &center);
    try testing.expect((try interp.processReport(3, &longer)) != null); // size is a minimum
}
