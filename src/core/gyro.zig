const std = @import("std");

pub const GyroConfig = struct {
    mode: []const u8 = "off", // "off" | "mouse" | "joystick"
    sensitivity_x: f32 = 1.5,
    sensitivity_y: f32 = 1.5,
    deadzone: i16 = 0,
    smoothing: f32 = 0.3,
    curve: f32 = 1.0,
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

        // [3] exponential curve
        const abs_x = @abs(self.ema_x);
        const abs_y = @abs(self.ema_y);
        const curved_x = std.math.copysign(std.math.pow(f32, abs_x, cfg.curve), self.ema_x);
        const curved_y = std.math.copysign(std.math.pow(f32, abs_y, cfg.curve), self.ema_y);

        // [4] sensitivity scale (GYRO_SCALE = 0.001)
        const scaled_x = curved_x * cfg.sensitivity_x * 0.001;
        const scaled_y = curved_y * cfg.sensitivity_y * 0.001;

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
    // 30000 raw, scaled * 0.001 * 10 = 0.3 per axis, needs several frames to accumulate
    _ = g.process(&cfg, 30000, 30000, 0);
    _ = g.process(&cfg, 30000, 30000, 0);
    _ = g.process(&cfg, 30000, 30000, 0);
    const out = g.process(&cfg, 30000, 30000, 0);
    // After 4 frames at smoothing=0, scaled = 30000 * 0.001 * 10 = 300 per frame — well over 1
    try testing.expect(out.rel_x != 0 or g.accum_x != 0);
}

test "smoothing=0: no EMA delay (direct pass-through)" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    // With smoothing=0: ema = val directly; scaled = val * 1000 * 0.001 = val
    // 10 raw → scaled = 10.0 → dx = 10 on first frame
    const out = g.process(&cfg, 10, 10, 0);
    try testing.expectEqual(@as(i32, 10), out.rel_x);
    try testing.expectEqual(@as(i32, 10), out.rel_y);
}

test "sub-pixel accumulation: small values accumulate to integer delta" {
    var g = GyroProcessor{};
    // sensitivity such that each frame contributes 0.25 pixels
    // raw=100, sensitivity=2.5, scale=0.001 → 100 * 2.5 * 0.001 = 0.25
    const cfg = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 2.5, .sensitivity_y = 2.5 };
    var total_x: i32 = 0;
    for (0..4) |_| {
        const out = g.process(&cfg, 100, 100, 0);
        total_x += out.rel_x;
    }
    // After 4 frames: 4 * 0.25 = 1.0 → total delta = 1
    try testing.expectEqual(@as(i32, 1), total_x);
    try testing.expectApproxEqAbs(@as(f32, 0.0), g.accum_x, 1e-5);
}

test "invert_x/invert_y: negates output" {
    var g1 = GyroProcessor{};
    var g2 = GyroProcessor{};
    const cfg_normal = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    const cfg_invert = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0, .invert_x = true, .invert_y = true };
    const out_normal = g1.process(&cfg_normal, 10, 10, 0);
    const out_invert = g2.process(&cfg_invert, 10, 10, 0);
    try testing.expectEqual(-out_normal.rel_x, out_invert.rel_x);
    try testing.expectEqual(-out_normal.rel_y, out_invert.rel_y);
}

test "curve=1.0 linear vs curve=2.0 exponential" {
    var g1 = GyroProcessor{};
    var g2 = GyroProcessor{};
    const cfg_linear = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 1.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    const cfg_exp = GyroConfig{ .mode = "mouse", .smoothing = 0.0, .curve = 2.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    // With raw=100: linear = 100^1.0 = 100; exp = 100^2.0 = 10000
    // scaled_linear = 100 * 1000 * 0.001 = 100
    // scaled_exp    = 10000 * 1000 * 0.001 = 10000
    const out_linear = g1.process(&cfg_linear, 100, 100, 0);
    const out_exp = g2.process(&cfg_exp, 100, 100, 0);
    try testing.expect(@abs(out_exp.rel_x) > @abs(out_linear.rel_x) * 50);
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

test "T4: sensitivity=0 produces zero output" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .sensitivity_x = 0.0, .sensitivity_y = 0.0, .smoothing = 0.0 };
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    // No NaN/Inf in accumulators
    try testing.expect(!std.math.isNan(g.accum_x));
    try testing.expect(!std.math.isInf(g.accum_x));
}

test "T4: deadzone=32767 absorbs all input, output is zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .deadzone = 32767, .smoothing = 0.0, .sensitivity_x = 1000.0, .sensitivity_y = 1000.0 };
    const out = g.process(&cfg, 32766, 32766, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "T4: curve=0 pow(x,0)=1 for nonzero input, no NaN" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .curve = 0.0, .smoothing = 0.0, .sensitivity_x = 1.0, .sensitivity_y = 1.0 };
    _ = g.process(&cfg, 100, 100, 0);
    try testing.expect(!std.math.isNan(g.accum_x));
    try testing.expect(!std.math.isInf(g.accum_x));
}

test "T4: sensitivity=0 and deadzone=32767 combination yields zero" {
    var g = GyroProcessor{};
    const cfg = GyroConfig{ .mode = "mouse", .sensitivity_x = 0.0, .sensitivity_y = 0.0, .deadzone = 32767, .smoothing = 0.0 };
    const out = g.process(&cfg, 30000, 30000, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}
