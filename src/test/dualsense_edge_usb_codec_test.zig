const std = @import("std");
const testing = std.testing;

const state = @import("../core/state.zig");
const codec = @import("../io/dualsense_edge_usb.zig");
const edge_identity = @import("../io/edge_identity.zig");

const ButtonId = state.ButtonId;
const GamepadState = state.GamepadState;

fn pressed(ids: []const ButtonId) u64 {
    var bits: u64 = 0;
    for (ids) |id| bits |= @as(u64, 1) << @intFromEnum(id);
    return bits;
}

fn testTouchConfig() codec.TouchSynthesis {
    return .{
        .left_button = .C,
        .right_button = .Z,
        .left_x = 480,
        .right_x = 1440,
        .y = 540,
        .click = true,
    };
}

test "DualSense Edge USB codec: descriptor and identity-parameterized features match fixtures" {
    try testing.expectEqualSlices(
        u8,
        @embedFile("fixtures/dualsense_edge_usb/descriptor.bin"),
        codec.descriptor(),
    );

    const identity = edge_identity.EdgeIdentity{
        .pairing_mac = .{ 0x02, 0x11, 0x22, 0x33, 0x44, 0x55 },
    };
    var buf: [64]u8 = undefined;

    const feature_05 = try codec.featureReport(0x05, identity, &buf);
    try testing.expectEqualSlices(u8, @embedFile("fixtures/dualsense_edge_usb/feature_05.bin"), feature_05);

    const feature_20 = try codec.featureReport(0x20, identity, &buf);
    try testing.expectEqualSlices(u8, @embedFile("fixtures/dualsense_edge_usb/feature_20.bin"), feature_20);

    var expected_09: [20]u8 = @embedFile("fixtures/dualsense_edge_usb/feature_09.bin").*;
    @memcpy(expected_09[1..7], &identity.pairing_mac);
    const feature_09 = try codec.featureReport(0x09, identity, &buf);
    try testing.expectEqualSlices(u8, &expected_09, feature_09);

    try testing.expectError(error.UnsupportedFeatureReport, codec.featureReport(0x99, identity, &buf));
    try testing.expectError(error.BufferTooSmall, codec.featureReport(0x20, identity, buf[0..63]));
}

test "DualSense Edge USB codec: exact input bytes cover axes triggers dpad buttons and IMU" {
    var encoder = codec.InputEncoder.init(testTouchConfig());
    const input = GamepadState{
        .ax = -32768,
        .ay = 32767,
        .rx = 32767,
        .ry = -32768,
        .lt = 0x25,
        .rt = 0xD2,
        .dpad_x = 1,
        .dpad_y = -1,
        .buttons = pressed(&.{ .A, .Y, .LB, .RT, .Select, .RS, .Home, .Mic, .M1, .M2, .M3, .M4 }),
        .gyro_x = 0x1234,
        .gyro_y = -2,
        .gyro_z = -32768,
        .accel_x = 32767,
        .accel_y = 0x4567,
        .accel_z = -0x1234,
        .battery_level = 7,
    };

    const report = encoder.encode(input);
    var expected = [_]u8{0} ** codec.INPUT_REPORT_SIZE;
    expected[0] = 0x01;
    expected[1] = 0;
    expected[2] = 0;
    expected[3] = 255;
    expected[4] = 255;
    expected[5] = 0x25;
    expected[6] = 0xD2;
    expected[8] = 0xA1; // triangle + cross + north-east hat
    expected[9] = 0x99; // L1 + R2 + create + R3
    expected[10] = 0xF5; // PS + mic + Fn1/Fn2/left/right paddle
    std.mem.writeInt(i16, expected[16..18], 0x1234, .little);
    std.mem.writeInt(i16, expected[18..20], -2, .little);
    std.mem.writeInt(i16, expected[20..22], -32768, .little);
    std.mem.writeInt(i16, expected[22..24], 32767, .little);
    std.mem.writeInt(i16, expected[24..26], 0x4567, .little);
    std.mem.writeInt(i16, expected[26..28], -0x1234, .little);
    expected[33] = 0x80;
    expected[37] = 0x80;
    expected[53] = 7;
    try testing.expectEqualSlices(u8, &expected, &report);
}

test "DualSense Edge USB codec: signed stick conversion widens and floors" {
    const vectors = [_]struct {
        v: i16,
        x: u8,
        y: u8,
    }{
        .{ .v = -32768, .x = 0, .y = 255 },
        .{ .v = -32767, .x = 0, .y = 255 },
        .{ .v = -1, .x = 127, .y = 128 },
        .{ .v = 0, .x = 128, .y = 128 },
        .{ .v = 1, .x = 128, .y = 127 },
        .{ .v = 32766, .x = 255, .y = 0 },
        .{ .v = 32767, .x = 255, .y = 0 },
    };

    for (vectors) |vector| {
        try testing.expectEqual(vector.x, codec.encodeX(vector.v));
        try testing.expectEqual(vector.y, codec.encodeY(vector.v));
    }

    var encoder = codec.InputEncoder.init(testTouchConfig());
    const report = encoder.encode(.{ .ax = -1, .ay = 1, .rx = 1, .ry = -1, .lt = 1, .rt = 254 });
    try testing.expectEqualSlices(u8, &.{ 127, 127, 128, 128, 1, 254 }, report[1..7]);

    const endpoints = encoder.encode(.{ .lt = 0, .rt = 255 });
    try testing.expectEqual(@as(u8, 0), endpoints[5]);
    try testing.expectEqual(@as(u8, 255), endpoints[6]);
}

test "DualSense Edge USB codec: Edge buttons independently map to Fn and paddles" {
    const cases = [_]struct { id: ButtonId, mask: u8 }{
        .{ .id = .M1, .mask = 0x10 },
        .{ .id = .M2, .mask = 0x20 },
        .{ .id = .M3, .mask = 0x40 },
        .{ .id = .M4, .mask = 0x80 },
    };
    for (cases) |case| {
        var encoder = codec.InputEncoder.init(testTouchConfig());
        const report = encoder.encode(.{ .buttons = pressed(&.{case.id}) });
        try testing.expectEqual(case.mask, report[10]);
    }
}

test "DualSense Edge USB codec: dpad encodes all directions and neutral" {
    const cases = [_]struct { x: i8, y: i8, hat: u8 }{
        .{ .x = 0, .y = -1, .hat = 0 },
        .{ .x = 1, .y = -1, .hat = 1 },
        .{ .x = 1, .y = 0, .hat = 2 },
        .{ .x = 1, .y = 1, .hat = 3 },
        .{ .x = 0, .y = 1, .hat = 4 },
        .{ .x = -1, .y = 1, .hat = 5 },
        .{ .x = -1, .y = 0, .hat = 6 },
        .{ .x = -1, .y = -1, .hat = 7 },
        .{ .x = 0, .y = 0, .hat = 8 },
    };
    for (cases) |case| {
        var encoder = codec.InputEncoder.init(testTouchConfig());
        const report = encoder.encode(.{ .dpad_x = case.x, .dpad_y = case.y });
        try testing.expectEqual(case.hat, report[8] & 0x0F);
    }
}

fn expectTouch(slot: []const u8, contact: u8, x: u16, y: u16) !void {
    try testing.expectEqual(contact, slot[0]);
    try testing.expectEqual(@as(u8, @truncate(x)), slot[1]);
    try testing.expectEqual(@as(u8, @truncate((x >> 8) | ((y & 0x0F) << 4))), slot[2]);
    try testing.expectEqual(@as(u8, @truncate(y >> 4)), slot[3]);
}

test "DualSense Edge USB codec: C and Z contacts keep independent ids through both release orders" {
    var encoder = codec.InputEncoder.init(testTouchConfig());

    var report = encoder.encode(.{});
    try expectTouch(report[33..37], 0x80, 0, 0);
    try expectTouch(report[37..41], 0x80, 0, 0);
    try testing.expectEqual(@as(u8, 0), report[10] & 0x02);

    report = encoder.encode(.{ .buttons = pressed(&.{.C}) });
    try expectTouch(report[33..37], 0, 480, 540);
    try expectTouch(report[37..41], 0x80, 0, 0);
    try testing.expectEqual(@as(u8, 0x02), report[10] & 0x02);

    const held = encoder.encode(.{ .buttons = pressed(&.{.C}) });
    try testing.expectEqualSlices(u8, report[33..41], held[33..41]);

    report = encoder.encode(.{ .buttons = pressed(&.{ .C, .Z }) });
    try expectTouch(report[33..37], 0, 480, 540);
    try expectTouch(report[37..41], 1, 1440, 540);

    report = encoder.encode(.{ .buttons = pressed(&.{.Z}) });
    try expectTouch(report[33..37], 0x80, 480, 540);
    try expectTouch(report[37..41], 1, 1440, 540);
    try testing.expectEqual(@as(u8, 0x02), report[10] & 0x02);

    report = encoder.encode(.{});
    try expectTouch(report[33..37], 0x80, 0, 0);
    try expectTouch(report[37..41], 0x81, 1440, 540);
    try testing.expectEqual(@as(u8, 0), report[10] & 0x02);

    // Press again and release right before left to exercise the other order.
    report = encoder.encode(.{ .buttons = pressed(&.{ .C, .Z }) });
    const left_id = report[33];
    const right_id = report[37];
    report = encoder.encode(.{ .buttons = pressed(&.{.C}) });
    try testing.expectEqual(left_id, report[33]);
    try testing.expectEqual(right_id | 0x80, report[37]);
    try testing.expectEqual(@as(u8, 0x02), report[10] & 0x02);
    report = encoder.encode(.{});
    try testing.expectEqual(left_id | 0x80, report[33]);
    try testing.expectEqual(@as(u8, 0), report[10] & 0x02);
}

test "DualSense Edge USB codec: contact id rollover skips the other active contact" {
    var encoder = codec.InputEncoder.init(testTouchConfig());
    var report = encoder.encode(.{ .buttons = pressed(&.{.Z}) });
    try testing.expectEqual(@as(u8, 0), report[37]);

    var cycle: usize = 0;
    while (cycle < 127) : (cycle += 1) {
        report = encoder.encode(.{ .buttons = pressed(&.{ .C, .Z }) });
        try testing.expect(report[33] != report[37]);
        _ = encoder.encode(.{ .buttons = pressed(&.{.Z}) });
    }
    report = encoder.encode(.{ .buttons = pressed(&.{ .C, .Z }) });
    try testing.expectEqual(@as(u8, 1), report[33]);
    try testing.expectEqual(@as(u8, 0), report[37]);
}

test "DualSense Edge USB codec: touch contacts do not synthesize click when disabled" {
    var touch = testTouchConfig();
    touch.click = false;
    var encoder = codec.InputEncoder.init(touch);
    const report = encoder.encode(.{ .buttons = pressed(&.{ .C, .Z }) });
    try testing.expectEqual(@as(u8, 0), report[10] & 0x02);
    try testing.expectEqual(@as(u8, 0), report[33] & 0x80);
    try testing.expectEqual(@as(u8, 0), report[37] & 0x80);
}

test "DualSense Edge USB codec: compatible rumble decodes exact 48 and 63 byte forms" {
    const expected = codec.RumbleCommand{ .strong = 0xA5A5, .weak = 0x3C3C };
    try testing.expectEqual(expected, try codec.decodeCompatibleRumble(
        @embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin"),
    ));
    try testing.expectEqual(expected, try codec.decodeCompatibleRumble(
        @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin"),
    ));

    var endpoint = [_]u8{0} ** 63;
    endpoint[0] = 0x02;
    endpoint[1] = 0x02;
    endpoint[3] = 0;
    endpoint[4] = 255;
    endpoint[39] = 0x04;
    try testing.expectEqual(
        codec.RumbleCommand{ .strong = 65535, .weak = 0 },
        try codec.decodeCompatibleRumble(&endpoint),
    );

    var sdl_stop = [_]u8{0} ** 48;
    sdl_stop[0] = 0x02;
    try testing.expectEqual(
        codec.RumbleCommand{ .strong = 0, .weak = 0 },
        try codec.decodeCompatibleRumble(&sdl_stop),
    );

    // SDL_RumbleStart can publish the v2 selector before valid_flag2. Zero
    // motors make this a stop/handshake, and unrelated LED bytes must not
    // turn it into a malformed rumble command.
    var sdl_start = [_]u8{0} ** 48;
    sdl_start[0] = 0x02;
    sdl_start[1] = 0x02;
    sdl_start[39] = 0;
    sdl_start[44] = 0x7f;
    try testing.expectEqual(
        codec.RumbleCommand{ .strong = 0, .weak = 0 },
        try codec.decodeCompatibleRumble(&sdl_start),
    );

    var sdl_unrelated = [_]u8{0} ** 48;
    sdl_unrelated[0] = 0x02;
    sdl_unrelated[2] = 0x10;
    sdl_unrelated[45] = 0xa5;
    try testing.expectEqual(
        codec.RumbleCommand{ .strong = 0, .weak = 0 },
        try codec.decodeCompatibleRumble(&sdl_unrelated),
    );

    var linux_stop = [_]u8{0} ** 63;
    linux_stop[0] = 0x02;
    linux_stop[1] = 0x02;
    linux_stop[39] = 0x04;
    try testing.expectEqual(
        codec.RumbleCommand{ .strong = 0, .weak = 0 },
        try codec.decodeCompatibleRumble(&linux_stop),
    );
}

test "DualSense Edge USB codec: compatible rumble rejects invalid ids lengths and flags" {
    const fixture = @embedFile("fixtures/dualsense_edge_usb/output_compat_63.bin");
    try testing.expectError(error.InvalidReportLength, codec.decodeCompatibleRumble(fixture[0..47]));
    try testing.expectError(error.InvalidReportLength, codec.decodeCompatibleRumble(fixture[0..62]));

    var invalid: [63]u8 = undefined;
    @memcpy(&invalid, fixture);
    invalid[0] = 0x01;
    try testing.expectError(error.InvalidReportId, codec.decodeCompatibleRumble(&invalid));

    invalid = fixture.*;
    invalid[1] = 0x01; // old v1 compatibility flag is not Edge-compatible v2
    try testing.expectError(error.InvalidRumbleFlags, codec.decodeCompatibleRumble(&invalid));

    invalid = fixture.*;
    invalid[39] = 0;
    try testing.expectError(error.InvalidRumbleFlags, codec.decodeCompatibleRumble(&invalid));

    var invalid_48 = [_]u8{0} ** 48;
    invalid_48[0] = 0x02;
    invalid_48[3] = 1;
    try testing.expectError(error.InvalidRumbleFlags, codec.decodeCompatibleRumble(&invalid_48));

    invalid_48 = [_]u8{0} ** 48;
    invalid_48[0] = 0x02;
    invalid_48[1] = 0x01; // old v1 form is rejected even when motors are zero
    try testing.expectError(error.InvalidRumbleFlags, codec.decodeCompatibleRumble(&invalid_48));

    @memset(&invalid, 0);
    invalid[0] = 0x02;
    try testing.expectError(error.InvalidRumbleFlags, codec.decodeCompatibleRumble(&invalid));
}

test "DualSense Edge USB codec: typed output boundary rejects non-output report types" {
    const fixture = @embedFile("fixtures/dualsense_edge_usb/output_compat_48.bin");
    const expected = codec.RumbleCommand{ .strong = 0xA5A5, .weak = 0x3C3C };
    try testing.expectEqual(expected, try codec.decodeOutputReport(.{
        .report_id = 0x02,
        .report_type = .output,
        .data = fixture,
    }));
    try testing.expectError(error.InvalidReportType, codec.decodeOutputReport(.{
        .report_id = 0x02,
        .report_type = .feature,
        .data = fixture,
    }));
    try testing.expectError(error.InvalidReportId, codec.decodeOutputReport(.{
        .report_id = 0x01,
        .report_type = .output,
        .data = fixture,
    }));
}
