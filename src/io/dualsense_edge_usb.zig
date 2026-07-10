//! Pure Sony DualSense Edge USB wire codec.
//!
//! Descriptor and feature payloads are audited fixtures from the immutable hhd
//! source recorded beside the fixtures.  This module performs no UHID I/O and
//! derives no runtime identity.

const std = @import("std");
const state = @import("../core/state.zig");
const uhid = @import("uhid.zig");
const edge_identity = @import("edge_identity.zig");

pub const INPUT_REPORT_SIZE: usize = 64;
pub const INPUT_REPORT_ID: u8 = 0x01;
pub const OUTPUT_REPORT_ID: u8 = 0x02;

const DESCRIPTOR = @embedFile("../test/fixtures/dualsense_edge_usb/descriptor.bin");
const FEATURE_05 = @embedFile("../test/fixtures/dualsense_edge_usb/feature_05.bin");
const FEATURE_09 = @embedFile("../test/fixtures/dualsense_edge_usb/feature_09.bin");
const FEATURE_20 = @embedFile("../test/fixtures/dualsense_edge_usb/feature_20.bin");

comptime {
    if (DESCRIPTOR.len != 389) @compileError("DualSense Edge USB descriptor must be 389 bytes");
    if (FEATURE_05.len != 41) @compileError("DualSense Edge feature 0x05 must be 41 bytes");
    if (FEATURE_09.len != 20) @compileError("DualSense Edge feature 0x09 must be 20 bytes");
    if (FEATURE_20.len != 64) @compileError("DualSense Edge feature 0x20 must be 64 bytes");
}

pub const EdgeIdentity = edge_identity.EdgeIdentity;
pub const ButtonId = state.ButtonId;
pub const GamepadState = state.GamepadState;
pub const RumbleCommand = uhid.RumbleCommand;

pub const FeatureError = error{
    UnsupportedFeatureReport,
    BufferTooSmall,
};

pub const DecodeError = error{
    InvalidReportLength,
    InvalidReportId,
    InvalidReportType,
    InvalidRumbleFlags,
};

/// Resolved, typed form of `[output.touch_synthesis]`. String-to-ButtonId
/// resolution and coordinate validation stay in the configuration layer.
pub const TouchSynthesis = struct {
    left_button: ButtonId,
    right_button: ButtonId,
    left_x: u16,
    right_x: u16,
    y: u16,
    click: bool,
};

pub fn descriptor() []const u8 {
    return DESCRIPTOR;
}

/// Copy a complete feature report, including its report ID, into `out`.
/// Pairing bytes 1..6 are the caller-supplied stable Edge identity.
pub fn featureReport(
    report_id: u8,
    identity: EdgeIdentity,
    out: []u8,
) FeatureError![]const u8 {
    const fixture: []const u8 = switch (report_id) {
        0x05 => FEATURE_05,
        0x09 => FEATURE_09,
        0x20 => FEATURE_20,
        else => return error.UnsupportedFeatureReport,
    };
    if (out.len < fixture.len) return error.BufferTooSmall;
    @memcpy(out[0..fixture.len], fixture);
    if (report_id == 0x09) @memcpy(out[1..7], &identity.pairing_mac);
    return out[0..fixture.len];
}

pub fn encodeX(value: i16) u8 {
    const numerator: i32 = @as(i32, value) + 32768;
    const scaled = @divFloor(numerator, 256);
    return @intCast(std.math.clamp(scaled, 0, 255));
}

pub fn encodeY(value: i16) u8 {
    const numerator: i32 = 32768 - @as(i32, value);
    const scaled = @divFloor(numerator, 256);
    return @intCast(std.math.clamp(scaled, 0, 255));
}

const ContactState = struct {
    active_id: ?u7 = null,
};

pub const InputEncoder = struct {
    touch: TouchSynthesis,
    next_contact_id: u7 = 0,
    left: ContactState = .{},
    right: ContactState = .{},

    pub fn init(touch: TouchSynthesis) InputEncoder {
        return .{ .touch = touch };
    }

    pub fn encode(self: *InputEncoder, input: GamepadState) [INPUT_REPORT_SIZE]u8 {
        var report = [_]u8{0} ** INPUT_REPORT_SIZE;
        report[0] = INPUT_REPORT_ID;
        report[1] = encodeX(input.ax);
        report[2] = encodeY(input.ay);
        report[3] = encodeX(input.rx);
        report[4] = encodeY(input.ry);
        report[5] = input.lt;
        report[6] = input.rt;

        report[8] = encodeHat(input.dpad_x, input.dpad_y);
        setIfPressed(&report[8], input, .X, 0x10);
        setIfPressed(&report[8], input, .A, 0x20);
        setIfPressed(&report[8], input, .B, 0x40);
        setIfPressed(&report[8], input, .Y, 0x80);

        setIfPressed(&report[9], input, .LB, 0x01);
        setIfPressed(&report[9], input, .RB, 0x02);
        setIfPressed(&report[9], input, .LT, 0x04);
        setIfPressed(&report[9], input, .RT, 0x08);
        setIfPressed(&report[9], input, .Select, 0x10);
        setIfPressed(&report[9], input, .Start, 0x20);
        setIfPressed(&report[9], input, .LS, 0x40);
        setIfPressed(&report[9], input, .RS, 0x80);

        setIfPressed(&report[10], input, .Home, 0x01);
        setIfPressed(&report[10], input, .TouchPad, 0x02);
        setIfPressed(&report[10], input, .Mic, 0x04);
        setIfPressed(&report[10], input, .M1, 0x10); // Fn1
        setIfPressed(&report[10], input, .M2, 0x20); // Fn2
        setIfPressed(&report[10], input, .M3, 0x40); // left paddle
        setIfPressed(&report[10], input, .M4, 0x80); // right paddle

        std.mem.writeInt(i16, report[16..18], input.gyro_x, .little);
        std.mem.writeInt(i16, report[18..20], input.gyro_y, .little);
        std.mem.writeInt(i16, report[20..22], input.gyro_z, .little);
        std.mem.writeInt(i16, report[22..24], input.accel_x, .little);
        std.mem.writeInt(i16, report[24..26], input.accel_y, .little);
        std.mem.writeInt(i16, report[26..28], input.accel_z, .little);

        const left_down = isPressed(input, self.touch.left_button);
        const right_down = isPressed(input, self.touch.right_button);

        if (left_down and self.left.active_id == null)
            self.left.active_id = self.allocateContactId(self.right.active_id);
        if (right_down and self.right.active_id == null)
            self.right.active_id = self.allocateContactId(self.left.active_id);

        encodeContact(
            report[33..37],
            self.left.active_id,
            left_down,
            self.touch.left_x,
            self.touch.y,
        );
        encodeContact(
            report[37..41],
            self.right.active_id,
            right_down,
            self.touch.right_x,
            self.touch.y,
        );

        if (self.touch.click and (left_down or right_down)) report[10] |= 0x02;

        if (!left_down) self.left.active_id = null;
        if (!right_down) self.right.active_id = null;

        // The native status nibble represents 0..10 rather than a percentage.
        report[53] = @min(input.battery_level, 10);
        return report;
    }

    fn allocateContactId(self: *InputEncoder, other_active: ?u7) u7 {
        var candidate = self.next_contact_id;
        while (other_active != null and candidate == other_active.?) {
            candidate = incrementContactId(candidate);
        }
        self.next_contact_id = incrementContactId(candidate);
        return candidate;
    }
};

fn incrementContactId(value: u7) u7 {
    return @truncate(@as(u8, value) +% 1);
}

fn isPressed(input: GamepadState, id: ButtonId) bool {
    const shift: u6 = @intCast(@intFromEnum(id));
    return input.buttons & (@as(u64, 1) << shift) != 0;
}

fn setIfPressed(byte: *u8, input: GamepadState, id: ButtonId, mask: u8) void {
    if (isPressed(input, id)) byte.* |= mask;
}

fn encodeHat(x: i8, y: i8) u8 {
    const sx = std.math.sign(x);
    const sy = std.math.sign(y);
    if (sx == 0 and sy < 0) return 0;
    if (sx > 0 and sy < 0) return 1;
    if (sx > 0 and sy == 0) return 2;
    if (sx > 0 and sy > 0) return 3;
    if (sx == 0 and sy > 0) return 4;
    if (sx < 0 and sy > 0) return 5;
    if (sx < 0 and sy == 0) return 6;
    if (sx < 0 and sy < 0) return 7;
    return 8;
}

fn encodeContact(
    slot: []u8,
    active_id: ?u7,
    down: bool,
    x: u16,
    y: u16,
) void {
    if (active_id) |id| {
        slot[0] = @as(u8, id) | if (down) @as(u8, 0) else @as(u8, 0x80);
        slot[1] = @truncate(x);
        slot[2] = @truncate((x >> 8) | ((y & 0x0F) << 4));
        slot[3] = @truncate(y >> 4);
    } else {
        slot[0] = 0x80;
        slot[1] = 0;
        slot[2] = 0;
        slot[3] = 0;
    }
}

/// Decode DualSense Edge's v2 compatible-vibration form. The Linux/Edge form
/// requires valid_flag0 bit 1 and valid_flag2 bit 2. SDL's RumbleStart path
/// also emits a 48-byte zero-motor handshake before all v2 flag groups are
/// populated; accept that stop/handshake narrowly while still rejecting the
/// old v1 compatibility bit and requiring full v2 flags for nonzero motors or
/// the Linux 63-byte short form.
pub fn decodeCompatibleRumble(report: []const u8) DecodeError!RumbleCommand {
    if (report.len != 48 and report.len != 63) return error.InvalidReportLength;
    if (report[0] != OUTPUT_REPORT_ID) return error.InvalidReportId;

    // Bit 0 is the old DualSense v1 compatibility flag. Edge v2 must not
    // silently reinterpret it as the new mode.
    if (report[1] & 0x01 != 0) return error.InvalidRumbleFlags;

    const zero_motor_48 = report.len == 48 and report[3] == 0 and report[4] == 0;
    if (zero_motor_48) return .{ .weak = 0, .strong = 0 };

    const v2_active = report[1] & 0x02 != 0 and report[39] & 0x04 != 0;
    if (!v2_active) {
        return error.InvalidRumbleFlags;
    }

    return .{
        .weak = @as(u16, report[3]) * 257,
        .strong = @as(u16, report[4]) * 257,
    };
}

/// Typed UHID boundary for the native pump. Keeping report-type validation
/// here prevents a feature/input payload with compatible-looking bytes from
/// being routed to the physical rumble command path.
pub fn decodeOutputReport(report: uhid.OutputReport) DecodeError!RumbleCommand {
    if (report.report_type != .output) return error.InvalidReportType;
    if (report.report_id != OUTPUT_REPORT_ID) return error.InvalidReportId;
    return decodeCompatibleRumble(report.data);
}
