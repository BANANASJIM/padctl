const std = @import("std");

pub const StickConfig = struct {
    mode: []const u8 = "gamepad", // "gamepad" | "mouse" | "scroll"
    deadzone: i16 = 128,
    sensitivity: f32 = 1.0,
    suppress_gamepad: bool = false,
};

pub const StickOutput = struct {
    rel_x: i32 = 0,
    rel_y: i32 = 0,
    wheel: i32 = 0,
    hwheel: i32 = 0,
};

pub const StickProcessor = struct {
    mouse_accum_x: f32 = 0,
    mouse_accum_y: f32 = 0,
    scroll_accum: f32 = 0,
    hscroll_accum: f32 = 0,

    pub fn process(
        self: *StickProcessor,
        cfg: *const StickConfig,
        axis_x: i16,
        axis_y: i16,
        dt_ms: u32,
    ) StickOutput {
        if (std.mem.eql(u8, cfg.mode, "mouse")) {
            return self.processMouseMode(axis_x, axis_y, cfg, @floatFromInt(dt_ms));
        } else if (std.mem.eql(u8, cfg.mode, "scroll")) {
            return self.processScrollMode(axis_x, axis_y, cfg, @floatFromInt(dt_ms));
        }
        // gamepad: pass-through (caller uses raw axis values)
        return .{};
    }

    pub fn reset(self: *StickProcessor) void {
        self.mouse_accum_x = 0;
        self.mouse_accum_y = 0;
        self.scroll_accum = 0;
        self.hscroll_accum = 0;
    }

    fn processMouseMode(self: *StickProcessor, x: i16, y: i16, cfg: *const StickConfig, dt_ms: f32) StickOutput {
        const fx = applyDeadzone(x, cfg.deadzone);
        const fy = applyDeadzone(y, cfg.deadzone);

        const nx = fx / 32768.0;
        const ny = fy / 32768.0;

        self.mouse_accum_x += nx * cfg.sensitivity * dt_ms / 16.0;
        self.mouse_accum_y += ny * cfg.sensitivity * dt_ms / 16.0;

        const dx: i32 = @intFromFloat(@trunc(self.mouse_accum_x));
        const dy: i32 = @intFromFloat(@trunc(self.mouse_accum_y));
        self.mouse_accum_x -= @floatFromInt(dx);
        self.mouse_accum_y -= @floatFromInt(dy);

        return .{ .rel_x = dx, .rel_y = dy };
    }

    fn processScrollMode(self: *StickProcessor, x: i16, y: i16, cfg: *const StickConfig, dt_ms: f32) StickOutput {
        const fy = applyDeadzone(y, cfg.deadzone);
        self.scroll_accum += (fy / 32768.0) * cfg.sensitivity * dt_ms / 100.0;
        const wheel: i32 = @intFromFloat(@trunc(self.scroll_accum));
        self.scroll_accum -= @floatFromInt(wheel);

        const fx = applyDeadzone(x, cfg.deadzone);
        self.hscroll_accum += (fx / 32768.0) * cfg.sensitivity * dt_ms / 100.0;
        const hwheel: i32 = @intFromFloat(@trunc(self.hscroll_accum));
        self.hscroll_accum -= @floatFromInt(hwheel);

        return .{ .wheel = wheel, .hwheel = hwheel };
    }
};

fn applyDeadzone(val: i16, deadzone: i16) f32 {
    if (@abs(@as(i32, val)) < deadzone) return 0;
    return @floatFromInt(val);
}

// --- tests ---

const testing = std.testing;

test "stick: gamepad mode: process returns zero StickOutput" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "gamepad" };
    const out = sp.process(&cfg, 10000, -5000, 16);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    try testing.expectEqual(@as(i32, 0), out.wheel);
    try testing.expectEqual(@as(i32, 0), out.hwheel);
}

test "stick: mouse mode: deadzone suppresses output" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 1000, .sensitivity = 1.0 };
    // axis values within deadzone → no movement
    const out = sp.process(&cfg, 500, -500, 16);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "stick: mouse mode: outside deadzone produces nonzero output" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 100, .sensitivity = 10.0 };
    const out = sp.process(&cfg, 32000, 0, 16);
    try testing.expect(out.rel_x != 0);
}

test "stick: mouse mode: dt normalization scales proportionally" {
    var sp8 = StickProcessor{};
    var sp16 = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 100.0 };
    // dt=8ms should give roughly half the displacement of dt=16ms after enough frames
    var total8: i32 = 0;
    var total16: i32 = 0;
    for (0..4) |_| {
        const o8 = sp8.process(&cfg, 10000, 0, 8);
        const o16 = sp16.process(&cfg, 10000, 0, 16);
        total8 += o8.rel_x;
        total16 += o16.rel_x;
    }
    // After 4 frames: dt=8 total should be ~half of dt=16 total
    try testing.expect(total8 > 0);
    try testing.expect(total16 > 0);
    // Allow small rounding: 2*total8 should be close to total16
    const diff = @abs(2 * total8 - total16);
    try testing.expect(diff <= 2);
}

test "stick: mouse mode: sub-pixel accumulation precision" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 1.0 };
    // Small input that accumulates across frames
    var total: i32 = 0;
    for (0..100) |_| {
        const out = sp.process(&cfg, 1000, 0, 16);
        total += out.rel_x;
    }
    // After 100 frames the accumulator should have emitted some pixels
    try testing.expect(total > 0);
    // Residual accumulator should be in [0, 1)
    try testing.expect(sp.mouse_accum_x >= 0 and sp.mouse_accum_x < 1.0);
}

test "stick: scroll mode: accumulates to step" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "scroll", .deadzone = 0, .sensitivity = 10.0 };
    var steps: i32 = 0;
    for (0..20) |_| {
        const out = sp.process(&cfg, 0, 32767, 16);
        steps += out.wheel;
    }
    try testing.expect(steps > 0);
}

test "stick: scroll mode: small input accumulates across frames" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "scroll", .deadzone = 0, .sensitivity = 1.0 };
    // Single small-value frame should not immediately produce a step
    const out1 = sp.process(&cfg, 0, 100, 16);
    try testing.expectEqual(@as(i32, 0), out1.wheel);
    // But accumulator is non-zero
    try testing.expect(sp.scroll_accum != 0);
}

test "stick: dt=0: mouse delta is zero" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 100.0 };
    const out = sp.process(&cfg, 32000, 32000, 0);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

// T4: extreme parameter values

test "stick: sensitivity=0 produces zero mouse output" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 0.0 };
    const out = sp.process(&cfg, 32000, 32000, 16);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
    try testing.expect(!std.math.isNan(sp.mouse_accum_x));
}

test "stick: deadzone=32767 absorbs all stick input" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 32767, .sensitivity = 100.0 };
    const out = sp.process(&cfg, 32766, 32766, 16);
    try testing.expectEqual(@as(i32, 0), out.rel_x);
    try testing.expectEqual(@as(i32, 0), out.rel_y);
}

test "stick: dt_ms=1 integrates without overflow" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 1.0 };
    _ = sp.process(&cfg, 32000, 0, 1);
    try testing.expect(!std.math.isNan(sp.mouse_accum_x));
    try testing.expect(!std.math.isInf(sp.mouse_accum_x));
}

test "stick: dt_ms=100 integrates without overflow" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "mouse", .deadzone = 0, .sensitivity = 1.0 };
    _ = sp.process(&cfg, 32000, 0, 100);
    try testing.expect(!std.math.isNan(sp.mouse_accum_x));
    try testing.expect(!std.math.isInf(sp.mouse_accum_x));
}

// T10: REL_HWHEEL tests

test "stick: scroll mode X axis produces hwheel" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "scroll", .deadzone = 0, .sensitivity = 10.0 };
    var hsteps: i32 = 0;
    for (0..20) |_| {
        const out = sp.process(&cfg, 32767, 0, 16);
        hsteps += out.hwheel;
        try testing.expectEqual(@as(i32, 0), out.wheel);
    }
    try testing.expect(hsteps > 0);
}

test "stick: scroll mode Y axis produces wheel, not hwheel" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "scroll", .deadzone = 0, .sensitivity = 10.0 };
    var vsteps: i32 = 0;
    for (0..20) |_| {
        const out = sp.process(&cfg, 0, 32767, 16);
        vsteps += out.wheel;
        try testing.expectEqual(@as(i32, 0), out.hwheel);
    }
    try testing.expect(vsteps > 0);
}

test "stick: scroll mode both axes produce independent outputs" {
    var sp = StickProcessor{};
    const cfg = StickConfig{ .mode = "scroll", .deadzone = 0, .sensitivity = 10.0 };
    var total_wheel: i32 = 0;
    var total_hwheel: i32 = 0;
    for (0..20) |_| {
        const out = sp.process(&cfg, 32767, 32767, 16);
        total_wheel += out.wheel;
        total_hwheel += out.hwheel;
    }
    try testing.expect(total_wheel > 0);
    try testing.expect(total_hwheel > 0);
}

test "stick: hscroll_accum resets on reset()" {
    var sp = StickProcessor{};
    sp.hscroll_accum = 0.5;
    sp.reset();
    try testing.expectEqual(@as(f32, 0), sp.hscroll_accum);
}
