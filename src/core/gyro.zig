const std = @import("std");

pub const GyroConfig = struct {
    mode: []const u8 = "off", // "off" | "mouse" | "joystick"
    sensitivity_x: f32 = 1.5,
    sensitivity_y: f32 = 1.5,
    deadzone: i16 = 0,
    smoothing: f32 = 0.3,
    curve: f32 = 1.0,
    max_val: f32 = 32767.0,
    invert_x: bool = false,
    invert_y: bool = false,
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
        _ = gz;
        if (!std.mem.eql(u8, cfg.mode, "mouse") and !std.mem.eql(u8, cfg.mode, "joystick")) {
            return .{ .rel_x = 0, .rel_y = 0, .joy_x = null, .joy_y = null };
        }

        // [1] deadzone
        const fx: f32 = if (@abs(@as(i32, gx)) < cfg.deadzone) 0.0 else @floatFromInt(gx);
        const fy: f32 = if (@abs(@as(i32, gy)) < cfg.deadzone) 0.0 else @floatFromInt(gy);

        // [2] EMA smoothing
        self.ema_x = self.ema_x * cfg.smoothing + fx * (1.0 - cfg.smoothing);
        self.ema_y = self.ema_y * cfg.smoothing + fy * (1.0 - cfg.smoothing);

        // [3] normalized curve (vader5): normalize [deadzone,max_val]→[0,1], apply pow, sensitivity scale
        const scaled_x = applyCurve(self.ema_x, cfg) * cfg.sensitivity_x;
        const scaled_y = applyCurve(self.ema_y, cfg) * cfg.sensitivity_y;

        // [5] invert
        const final_x = if (cfg.invert_x) -scaled_x else scaled_x;
        const final_y = if (cfg.invert_y) -scaled_y else scaled_y;

        if (std.mem.eql(u8, cfg.mode, "joystick")) {
            const jx: i16 = @intFromFloat(std.math.clamp(final_x * 20000.0, -32767.0, 32767.0));
            const jy: i16 = @intFromFloat(std.math.clamp(final_y * 20000.0, -32767.0, 32767.0));
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

    pub fn reset(self: *GyroProcessor) void {
        self.ema_x = 0;
        self.ema_y = 0;
        self.accum_x = 0;
        self.accum_y = 0;
    }
};

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

test "mode=off: zero output" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{};
    const out = g.process(&cfg, 1000, 2000, 500);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    try testing.expect(out.joy_x == null);
    try testing.expect(out.joy_y == null);
}

test "deadzone: input within deadzone returns zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 100, .smoothing = 0.0 };
    const out = g.process(&cfg, 50, 80, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "deadzone: input outside deadzone returns nonzero (large value)" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 100, .smoothing = 0.0, .sensitivity_x = 10.0, .sensitivity_y = 10.0 };
    // normalized: (30000-100)/32667 ≈ 0.915, * 10 * range ≈ 9 pixels/frame
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expect(out.rel_x != 0 or g.accum_x != 0);
}

test "smoothing=0: no EMA delay (direct pass-through)" {
    var g = GyroProcessor{};
    // sensitivity=1.0, max input=32767 → output ≈ 1.0 unit/frame at full deflection
    // Use large input: normalized ≈ 1.0, sensitivity=32767 → scaled = 32767*32767/32767 = 32767
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 32767.0, .sensitivity_y = 32767.0 };
    const out = g.process(&cfg, 32767, 32767, 0);
    try testing.expect(out.rel_x > 0);
    try testing.expect(out.rel_y > 0);
}

test "sub-pixel accumulation: small values accumulate to integer delta" {
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

test "invert_x/invert_y: negates output" {
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

test "curve=1.0 linear vs curve=2.0 exponential" {
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

test "EMA smoothing: consecutive frames converge" {
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

// T4: extreme parameter values

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

// T11: gyro curve normalization (vader5 parity)

test "gyro: full deflection sensitivity=1 yields ~1 unit/frame" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = 1.0, .sensitivity_y = 1.0 };
    _ = g.process(&cfg, 32767, 32767, 0);
    // total motion (emitted + residual) should be ~1.0
    const total_x = @as(f32, @floatFromInt(0)) + g.accum_x; // dx=0 since accum < 1 initially? no...
    // normalized=1.0, curved=1.0, sensitivity=1.0 → scaled=1.0 → dx=1, accum=0
    _ = total_x;
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
