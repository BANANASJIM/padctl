const std = @import("std");

pub const GyroTarget = enum { right_stick, left_stick };
pub const GyroResponse = enum { rate, tilt };
pub const GyroAxis = enum { none, pitch, yaw, roll };

pub const GyroConfig = struct {
    mode: []const u8 = "off", // "off" | "mouse" | "joystick"
    target: GyroTarget = .right_stick,
    response: GyroResponse = .rate,
    axis_x: GyroAxis = .yaw,
    axis_y: GyroAxis = .pitch,
    degrees_full: f32 = 35.0,
    sensitivity_x: f32 = 1.5,
    sensitivity_y: f32 = 1.5,
    deadzone: i16 = 0,
    smoothing: f32 = 0.3,
    curve: f32 = 1.0,
    max_val: f32 = 32767.0,
    invert_x: bool = false,
    invert_y: bool = false,
    blend_stick: bool = false,
    minimum_output: f32 = 0.0,
};

pub const GyroOutput = struct {
    rel_x: i32,
    rel_y: i32,
    joy_x: ?i16, // joystick mode: right_x override (null if mouse mode)
    joy_y: ?i16,
};

pub const GyroProcessor = struct {
    ema_x: f32 = 0,
    ema_y: f32 = 0,
    accum_x: f32 = 0,
    accum_y: f32 = 0,

    pub fn process(self: *GyroProcessor, cfg: *const GyroConfig, gx: i16, gy: i16, gz: i16) GyroOutput {
        return self.processMotion(cfg, gx, gy, gz, 0, 0, 0);
    }

    pub fn processMotion(
        self: *GyroProcessor,
        cfg: *const GyroConfig,
        gx: i16,
        gy: i16,
        gz: i16,
        accel_x: i16,
        accel_y: i16,
        accel_z: i16,
    ) GyroOutput {
        if (!std.mem.eql(u8, cfg.mode, "mouse") and !std.mem.eql(u8, cfg.mode, "joystick")) {
            return .{ .rel_x = 0, .rel_y = 0, .joy_x = null, .joy_y = null };
        }

        if (std.mem.eql(u8, cfg.mode, "joystick") and cfg.response == .tilt) {
            return self.processTilt(cfg, accel_x, accel_y, accel_z);
        }

        const raw_x = selectRateAxis(cfg.axis_x, gx, gy, gz);
        const raw_y = selectRateAxis(cfg.axis_y, gx, gy, gz);

        // [1] deadzone
        const fsrc_x: f32 = if (raw_x) |v|
            if (@abs(@as(i32, v)) < cfg.deadzone) 0.0 else @floatFromInt(v)
        else
            0.0;
        const fsrc_y: f32 = if (raw_y) |v|
            if (@abs(@as(i32, v)) < cfg.deadzone) 0.0 else @floatFromInt(v)
        else
            0.0;

        // [2] EMA smoothing (ema_x tracks source->X, ema_y tracks source->Y)
        self.ema_x = self.ema_x * cfg.smoothing + fsrc_x * (1.0 - cfg.smoothing);
        self.ema_y = self.ema_y * cfg.smoothing + fsrc_y * (1.0 - cfg.smoothing);

        // [3] normalized curve (vader5): normalize [deadzone,max_val]→[0,1], apply pow, sensitivity scale
        const scaled_x = applyCurve(self.ema_x, cfg) * cfg.sensitivity_x;
        const scaled_y = applyCurve(self.ema_y, cfg) * cfg.sensitivity_y;

        // [5] invert
        const final_x = if (cfg.invert_x) -scaled_x else scaled_x;
        const final_y = if (cfg.invert_y) -scaled_y else scaled_y;

        if (std.mem.eql(u8, cfg.mode, "joystick")) {
            const mo = std.math.clamp(cfg.minimum_output, 0.0, 1.0);
            var out_x = final_x;
            var out_y = final_y;
            if (mo > 0.0) {
                const m = @sqrt(out_x * out_x + out_y * out_y);
                if (m > 0.0 and m < mo) {
                    const scale = mo / m;
                    out_x *= scale;
                    out_y *= scale;
                }
            }
            const jx: ?i16 = if (raw_x != null) @intFromFloat(std.math.clamp(out_x * 20000.0, -32767.0, 32767.0)) else null;
            const jy: ?i16 = if (raw_y != null) @intFromFloat(std.math.clamp(out_y * 20000.0, -32767.0, 32767.0)) else null;
            return .{ .rel_x = 0, .rel_y = 0, .joy_x = jx, .joy_y = jy };
        }

        // [6] sub-pixel accumulation
        self.accum_x += final_x;
        self.accum_y += final_y;
        const dx: i32 = @intFromFloat(@trunc(self.accum_x));
        const dy: i32 = @intFromFloat(@trunc(self.accum_y));
        self.accum_x -= @floatFromInt(dx);
        self.accum_y -= @floatFromInt(dy);

        return .{ .rel_x = dx, .rel_y = dy, .joy_x = null, .joy_y = null };
    }

    fn processTilt(self: *GyroProcessor, cfg: *const GyroConfig, accel_x: i16, accel_y: i16, accel_z: i16) GyroOutput {
        const angle_x = selectTiltAxis(cfg.axis_x, accel_x, accel_y, accel_z);
        const angle_y = selectTiltAxis(cfg.axis_y, accel_x, accel_y, accel_z);

        if (angle_x) |a| self.ema_x = self.ema_x * cfg.smoothing + a * (1.0 - cfg.smoothing);
        if (angle_y) |a| self.ema_y = self.ema_y * cfg.smoothing + a * (1.0 - cfg.smoothing);

        const jx: ?i16 = if (angle_x != null)
            angleToStick(self.ema_x, cfg.degrees_full, cfg.curve, cfg.sensitivity_x, cfg.deadzone, cfg.invert_x)
        else
            null;
        const jy: ?i16 = if (angle_y != null)
            angleToStick(self.ema_y, cfg.degrees_full, cfg.curve, cfg.sensitivity_y, cfg.deadzone, cfg.invert_y)
        else
            null;
        return .{ .rel_x = 0, .rel_y = 0, .joy_x = jx, .joy_y = jy };
    }

    pub fn reset(self: *GyroProcessor) void {
        self.ema_x = 0;
        self.ema_y = 0;
        self.accum_x = 0;
        self.accum_y = 0;
    }
};

fn selectRateAxis(axis: GyroAxis, gx: i16, gy: i16, gz: i16) ?i16 {
    return switch (axis) {
        .none => null,
        .pitch => gx,
        .yaw => gy,
        .roll => gz,
    };
}

fn selectTiltAxis(axis: GyroAxis, ax: i16, ay: i16, az: i16) ?f32 {
    if (axis == .none) return null;
    const fx: f32 = @floatFromInt(ax);
    const fy: f32 = @floatFromInt(ay);
    const fz: f32 = @floatFromInt(az);
    if (fx == 0.0 and fy == 0.0 and fz == 0.0) return null;

    const radians_to_degrees: f32 = 180.0 / std.math.pi;
    return switch (axis) {
        .none => null,
        .pitch => std.math.atan2(fy, @sqrt(fx * fx + fz * fz)) * radians_to_degrees,
        .roll => std.math.atan2(-fx, @sqrt(fy * fy + fz * fz)) * radians_to_degrees,
        .yaw => 0.0,
    };
}

fn angleToStick(angle_degrees: f32, degrees_full: f32, curve: f32, sensitivity: f32, deadzone: i16, invert: bool) i16 {
    const full = @max(degrees_full, 0.001);
    var normalized = std.math.clamp(angle_degrees / full, -1.0, 1.0);
    normalized = std.math.copysign(std.math.pow(f32, @abs(normalized), curve), normalized);

    var value = std.math.clamp(normalized * sensitivity * 32767.0, -32767.0, 32767.0);
    if (@abs(value) < @as(f32, @floatFromInt(deadzone))) value = 0.0;
    if (invert) value = -value;
    return @intFromFloat(value);
}

fn applyCurve(ema: f32, cfg: *const GyroConfig) f32 {
    const dz: f32 = @floatFromInt(cfg.deadzone);
    const abs_val = @abs(ema);
    if (abs_val < dz) return 0.0;
    const range = cfg.max_val - dz;
    if (range <= 0) return 0.0;
    const normalized = (abs_val - dz) / range;
    const curved = std.math.pow(f32, normalized, cfg.curve);
    return std.math.copysign(curved, ema);
}

// --- tests ---

const testing = std.testing;

test "gyro: mode=off: zero output" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{};
    const out = g.process(&cfg, 1000, 2000, 500);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    try testing.expect(out.joy_x == null);
    try testing.expect(out.joy_y == null);
}

test "gyro: joystick tilt response maps roll degrees to stick position" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .tilt,
        .axis_x = .roll,
        .axis_y = .none,
        .degrees_full = 35.0,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
    };

    // Forward/back pitch must not drive roll.
    const pitch_only = g.processMotion(&cfg, 0, 0, 0, 0, 5735, 8192);
    try testing.expectEqual(@as(i16, 0), pitch_only.joy_x.?);

    // Roll is left/right tilt, reported through accel_x. atan2(5735, 8192) is approximately 35 degrees.
    const out = g.processMotion(&cfg, 0, 0, 0, -5735, 0, 8192);
    try testing.expect(out.joy_x != null);
    try testing.expect(out.joy_y == null);
    try testing.expect(out.joy_x.? > 32000);
}

test "gyro: joystick tilt response supports invert and negative roll" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .tilt,
        .axis_x = .roll,
        .axis_y = .none,
        .degrees_full = 35.0,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .invert_x = true,
    };

    const out = g.processMotion(&cfg, 0, 0, 0, 5735, 0, 8192);
    try testing.expect(out.joy_x != null);
    try testing.expect(out.joy_x.? > 32000);
}

test "gyro: joystick tilt response maps pitch degrees independently of roll" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .tilt,
        .axis_x = .pitch,
        .axis_y = .none,
        .degrees_full = 35.0,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
    };

    // Pitch is forward/back tilt, reported through accel_y; accel_x-only roll must not drive it.
    const roll_only = g.processMotion(&cfg, 0, 0, 0, -5735, 0, 8192);
    try testing.expectEqual(@as(i16, 0), roll_only.joy_x.?);

    const pitch = g.processMotion(&cfg, 0, 0, 0, 0, 5735, 8192);
    try testing.expect(pitch.joy_x != null);
    try testing.expect(pitch.joy_y == null);
    try testing.expect(pitch.joy_x.? > 32000);
}

test "gyro: joystick tilt response ignores missing accelerometer vector" {
    var g = GyroProcessor{ .ema_x = 12.0, .ema_y = -8.0 };
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .tilt,
        .axis_x = .roll,
        .axis_y = .pitch,
        .smoothing = 0.0,
    };

    const out = g.processMotion(&cfg, 0, 0, 0, 0, 0, 0);
    try testing.expect(out.joy_x == null);
    try testing.expect(out.joy_y == null);
    try testing.expectEqual(@as(f32, 12.0), g.ema_x);
    try testing.expectEqual(@as(f32, -8.0), g.ema_y);
}

test "gyro: joystick rate response can route roll gyro to X axis" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .none,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
    };

    const out = g.process(&cfg, 0, 0, 10000);
    try testing.expect(out.joy_x != null);
    try testing.expect(out.joy_x.? > 0);
    try testing.expect(out.joy_y == null);
}

test "gyro: deadzone: input within deadzone returns zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 100, .smoothing = 0.0 };
    const out = g.process(&cfg, 50, 80, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "gyro: deadzone: input outside deadzone returns nonzero (large value)" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 100, .smoothing = 0.0, .sensitivity_x = 10.0, .sensitivity_y = 10.0 };
    // normalized: (30000-100)/32667 ≈ 0.915, * 10 * range ≈ 9 pixels/frame
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expect(out.rel_x != 0 or g.accum_x != 0);
}

test "gyro: smoothing=0: no EMA delay (direct pass-through)" {
    var g = GyroProcessor{};
    // sensitivity=1.0, max input=32767 → output ≈ 1.0 unit/frame at full deflection
    // Use large input: normalized ≈ 1.0, sensitivity=32767 → scaled = 32767*32767/32767 = 32767
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0 };
    const out = g.process(&cfg, 32767, 32767, 0);
    try testing.expect(out.rel_x > 0);
    try testing.expect(out.rel_y > 0);
}

test "gyro: sub-pixel accumulation: small values accumulate to integer delta" {
    var g = GyroProcessor{};
    // normalized: raw=16384 (half max), normalized=0.5, curve=1 → curved=0.5
    // applyCurve = 0.5 * 32767 = 16383.5; scaled = 16383.5 * sensitivity / 32767
    // Choose sensitivity=2.0 → scaled ≈ 1.0/frame → after 1 frame dx=1
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 2.0, .sensitivity_y = 2.0 };
    var total_x: i32 = 0;
    for (0..4) |_| {
        const out = g.process(&cfg, 16384, 16384, 0);
        total_x += out.rel_x;
    }
    try testing.expect(total_x > 0);
    try testing.expect(g.accum_x >= 0.0 and g.accum_x < 1.0);
}

test "gyro: invert_x/invert_y: negates output" {
    var g1 = GyroProcessor{};
    var g2 = GyroProcessor{};
    // Use full-scale input with high sensitivity to get non-zero integer output
    const cfg_normal = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0 };
    const cfg_invert = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0, .invert_x = true, .invert_y = true };
    const out_normal = g1.process(&cfg_normal, 32767, 32767, 0);
    const out_invert = g2.process(&cfg_invert, 32767, 32767, 0);
    try testing.expectEqual(-out_normal.rel_x, out_invert.rel_x);
    try testing.expectEqual(-out_normal.rel_y, out_invert.rel_y);
}

test "gyro: curve=1.0 linear vs curve=2.0 exponential" {
    // Normalized curve: at half-scale input, curve=2 gives 0.25, curve=1 gives 0.5.
    // Verify curve=2 produces less total motion than curve=1 at half-scale.
    var g1 = GyroProcessor{};
    var g2 = GyroProcessor{};
    const sens = 32767.0;
    const cfg_linear = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = sens, .sensitivity_y = sens };
    const cfg_exp = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 2.0, .sensitivity_x = sens, .sensitivity_y = sens };
    const out_linear = g1.process(&cfg_linear, 16384, 16384, 0);
    const out_exp = g2.process(&cfg_exp, 16384, 16384, 0);
    // Total motion = emitted pixels + residual accumulator
    const total_linear = @as(f32, @floatFromInt(out_linear.rel_x)) + g1.accum_x;
    const total_exp = @as(f32, @floatFromInt(out_exp.rel_x)) + g2.accum_x;
    try testing.expect(total_linear > total_exp);
}

test "gyro: EMA smoothing: consecutive frames converge" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.5, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    // Feed constant input; EMA should converge towards steady state
    var prev_ema: f32 = 0;
    for (0..20) |_| {
        _ = g.process(&cfg, 100, 100, 0);
        // EMA must be monotonically increasing towards asymptote
        try testing.expect(g.ema_x >= prev_ema);
        prev_ema = g.ema_x;
    }
    // After many frames, ema should be close to input (100)
    try testing.expect(g.ema_x > 90.0);
}

// --- extreme parameter value tests ---

test "gyro: sensitivity=0 produces zero output" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .sensitivity_x = 0.0, .sensitivity_y = 0.0, .smoothing = 0.0 };
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    // No NaN/Inf in accumulators
    try testing.expect(!std.math.isNan(g.accum_x));
    try testing.expect(!std.math.isInf(g.accum_x));
}

test "gyro: deadzone=32767 absorbs all input, output is zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 32767, .smoothing = 0.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    const out = g.process(&cfg, 32766, 32766, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "gyro: curve=0 pow(x,0)=1 for nonzero input, no NaN" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .curve = 0.0, .smoothing = 0.0, .sensitivity_x = 1.0, .sensitivity_y = 1.0 };
    _ = g.process(&cfg, 100, 100, 0);
    try testing.expect(!std.math.isNan(g.accum_x));
    try testing.expect(!std.math.isInf(g.accum_x));
}

test "gyro: sensitivity=0 and deadzone=32767 combination yields zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .sensitivity_x = 0.0, .sensitivity_y = 0.0, .deadzone = 32767, .smoothing = 0.0 };
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

// --- gyro curve normalization tests ---

test "gyro: full deflection sensitivity=1 yields ~1 unit/frame" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = 1.0, .sensitivity_y = 1.0 };
    _ = g.process(&cfg, 32767, 32767, 0);
    // normalized=1.0, curved=1.0, sensitivity=1.0 → scaled=1.0 → dx=1, accum=0
    try testing.expect(g.accum_x >= 0.0 and g.accum_x < 1.0);
}

test "gyro: curve normalization: half-deflection curve=1 gives 0.5x full-deflection output" {
    var g_half = GyroProcessor{};
    var g_full = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = 100.0, .sensitivity_y = 100.0 };
    const out_half = g_half.process(&cfg, 16384, 16384, 0);
    const out_full = g_full.process(&cfg, 32767, 32767, 0);
    const total_half = @as(f32, @floatFromInt(out_half.rel_x)) + g_half.accum_x;
    const total_full = @as(f32, @floatFromInt(out_full.rel_x)) + g_full.accum_x;
    // half-deflection normalized ≈ 0.5, full ≈ 1.0; ratio should be ~0.5
    const ratio = total_half / total_full;
    try testing.expect(ratio > 0.45 and ratio < 0.55);
}

test "gyro: custom max_val clips normalization ceiling" {
    var g = GyroProcessor{};
    // max_val=1000: input of 1000 should normalize to 1.0
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = 1.0, .sensitivity_y = 1.0, .max_val = 1000.0 };
    _ = g.process(&cfg, 1000, 1000, 0);
    try testing.expect(g.accum_x >= 0.0 and g.accum_x < 1.0);
}

// --- axis orientation tests: pitch(gx)→REL_Y, yaw(gy)→REL_X ---

test "gyro: pitch-only input (gx nonzero, gy=0) produces only rel_y" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0 };
    // gx=32767 (pitch/up-down), gy=0 (no yaw)
    const out = g.process(&cfg, 32767, 0, 0);
    // rel_x must be zero (no yaw input), rel_y must be non-zero (pitch drives vertical)
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expect(out.rel_y != 0 or g.accum_y != 0);
}

test "gyro: yaw-only input (gy nonzero, gx=0) produces only rel_x" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0 };
    // gx=0 (no pitch), gy=32767 (yaw/left-right)
    const out = g.process(&cfg, 0, 32767, 0);
    // rel_y must be zero (no pitch input), rel_x must be non-zero (yaw drives horizontal)
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    try testing.expect(out.rel_x != 0 or g.accum_x != 0);
}

// --- minimum_output tests ---

// gz=2622 with sensitivity=1, deadzone=0, max_val=32767 produces:
//   applyCurve = 2622/32767 ≈ 0.08002; final_x ≈ 0.08002
// snap to minimum_output=0.15 → joy_x = round(0.15*20000) = 3000
test "gyro: minimum_output: snap magnitude from 0.08 to 0.15 (joystick)" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .none,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .deadzone = 0,
        .minimum_output = 0.15,
    };
    const out = g.process(&cfg, 0, 0, 2622);
    try testing.expect(out.joy_x != null);
    try testing.expect(out.joy_y == null);
    // snap brings magnitude from ~0.08 to 0.15; joy_x = round(0.15 * 20000) = 3000
    try testing.expect(@abs(@as(i32, out.joy_x.?) - 3000) <= 5);
}

// gz=16384, sensitivity=1 → final_x ≈ 0.5; 0.5 > minimum_output=0.15 → unchanged
test "gyro: minimum_output: no snap when above threshold" {
    var g = GyroProcessor{};
    const cfg_with = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .none,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .deadzone = 0,
        .minimum_output = 0.15,
    };
    var g2 = GyroProcessor{};
    const cfg_without = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .none,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .deadzone = 0,
        .minimum_output = 0.0,
    };
    const out_with = g.process(&cfg_with, 0, 0, 16384);
    const out_without = g2.process(&cfg_without, 0, 0, 16384);
    try testing.expectEqual(out_without.joy_x, out_with.joy_x);
}

// deadzone=500 absorbs gz=100 (< deadzone) → zero output; minimum_output must not resurrect it
test "gyro: minimum_output: deadzone wins over minimum_output" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .none,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .deadzone = 500,
        .minimum_output = 0.15,
    };
    const out = g.process(&cfg, 0, 0, 100);
    try testing.expect(out.joy_x != null);
    try testing.expectEqual(@as(i16, 0), out.joy_x.?);
}

// minimum_output=0.0 (default): output byte-identical to pre-feature behavior
test "gyro: minimum_output: default 0.0 is no-op for existing configs" {
    const inputs = [_]i16{ 500, 2000, 8000, 16384, 32767 };
    for (inputs) |gz| {
        var g1 = GyroProcessor{};
        var g2 = GyroProcessor{};
        const cfg_default = GyroConfig{
            .mode = "joystick",
            .response = .rate,
            .axis_x = .roll,
            .axis_y = .none,
            .smoothing = 0.0,
            .sensitivity_x = 1.0,
            .deadzone = 0,
            .minimum_output = 0.0,
        };
        const cfg_explicit = GyroConfig{
            .mode = "joystick",
            .response = .rate,
            .axis_x = .roll,
            .axis_y = .none,
            .smoothing = 0.0,
            .sensitivity_x = 1.0,
            .deadzone = 0,
        };
        const out1 = g1.process(&cfg_default, 0, 0, gz);
        const out2 = g2.process(&cfg_explicit, 0, 0, gz);
        try testing.expectEqual(out1.joy_x, out2.joy_x);
    }
}

// mouse mode: minimum_output has no effect on REL output
test "gyro: minimum_output: mouse mode ignores minimum_output" {
    var g1 = GyroProcessor{};
    var g2 = GyroProcessor{};
    const cfg_mo = GyroConfig{
        .mode = "mouse",
        .smoothing = 0.0,
        .sensitivity_x = 5.0,
        .sensitivity_y = 5.0,
        .deadzone = 0,
        .minimum_output = 0.5,
    };
    const cfg_base = GyroConfig{
        .mode = "mouse",
        .smoothing = 0.0,
        .sensitivity_x = 5.0,
        .sensitivity_y = 5.0,
        .deadzone = 0,
        .minimum_output = 0.0,
    };
    _ = g1.process(&cfg_mo, 500, 500, 0);
    _ = g2.process(&cfg_base, 500, 500, 0);
    // Accumulators must be identical — minimum_output had no effect
    try testing.expectEqual(g2.accum_x, g1.accum_x);
    try testing.expectEqual(g2.accum_y, g1.accum_y);
}

// direction-preserving: 2D input, both axes driven equally; ratio out_x/out_y = in_x/in_y
test "gyro: minimum_output: direction preserved in 2D snap" {
    var g = GyroProcessor{};
    // axis_x=roll(gz), axis_y=pitch(gx); both = 2622 → final_x = final_y ≈ 0.08
    // magnitude ≈ 0.08 * sqrt(2) ≈ 0.1131 < minimum_output=0.15 → snap
    // After snap: out_x = out_y (ratio preserved), magnitude = 0.15
    const cfg = GyroConfig{
        .mode = "joystick",
        .response = .rate,
        .axis_x = .roll,
        .axis_y = .pitch,
        .smoothing = 0.0,
        .sensitivity_x = 1.0,
        .sensitivity_y = 1.0,
        .deadzone = 0,
        .minimum_output = 0.15,
    };
    const out = g.process(&cfg, 2622, 0, 2622);
    try testing.expect(out.joy_x != null);
    try testing.expect(out.joy_y != null);
    const fx: f32 = @floatFromInt(out.joy_x.?);
    const fy: f32 = @floatFromInt(out.joy_y.?);
    const mag = @sqrt(fx * fx + fy * fy);
    // Expected magnitude: 0.15 * 20000 = 3000
    try testing.expect(@abs(mag - 3000.0) < 10.0);
    // Direction: equal components (45° angle), ratio should be ≈ 1.0
    try testing.expect(@abs(fx - fy) <= 2);
}
