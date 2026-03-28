const std = @import("std");
const state = @import("../../core/state.zig");
const mapping = @import("../../config/mapping.zig");

const GamepadStateDelta = state.GamepadStateDelta;
const ButtonId = state.ButtonId;

pub const Frame = struct {
    delta: GamepadStateDelta,
    dt_ms: u16,
};

fn btnMask(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

pub fn randomSequence(rng: std.Random, frames: []Frame, cfg: ?mapping.MappingConfig) void {
    var pos: usize = 0;
    var acc: u64 = 0;
    while (pos < frames.len) {
        const scenario = rng.intRangeAtMost(u8, 0, 15);
        const remaining = frames.len - pos;
        const written = switch (scenario) {
            0 => genIdle(frames[pos..], rng, remaining),
            1 => genButtonTap(frames[pos..], rng, remaining, &acc),
            2 => genButtonHold(frames[pos..], rng, remaining, &acc),
            3 => genSimultaneousPress(frames[pos..], rng, remaining, &acc),
            4 => genLayerHold(frames[pos..], rng, remaining, cfg, &acc),
            5 => genLayerToggle(frames[pos..], rng, remaining, cfg, &acc),
            6 => genAxisSweep(frames[pos..], rng, remaining),
            7 => genRapidToggle(frames[pos..], rng, remaining, cfg),
            8 => genAllButtons(frames[pos..], rng, remaining),
            9 => genStress(frames[pos..], rng, remaining),
            10 => genButtonHeldAcrossLayerSwitch(frames[pos..], rng, remaining, cfg, &acc),
            11 => genBoundaryValues(frames[pos..], rng, remaining),
            12 => genTouchTransition(frames[pos..], rng, remaining),
            13 => genDpadDirectionChange(frames[pos..], rng, remaining, &acc),
            14 => genTriggerBoundary(frames[pos..], rng, remaining),
            15 => genDualLayer(frames[pos..], rng, remaining, cfg, &acc),
            else => unreachable,
        };
        pos += written;
    }
}

pub fn stressSequence(rng: std.Random, frames: []Frame) void {
    for (frames) |*f| {
        f.delta = state.generateRandomDelta(rng);
        f.dt_ms = rng.intRangeAtMost(u16, 1, 100);
    }
}

// --- Scenario generators ---

fn genIdle(frames: []Frame, _: std.Random, max: usize) usize {
    const n = @min(5, max);
    for (frames[0..n]) |*f| {
        f.* = .{ .delta = .{}, .dt_ms = 16 };
    }
    return n;
}

fn genButtonTap(frames: []Frame, rng: std.Random, max: usize, acc: *u64) usize {
    const hold_len = rng.intRangeAtMost(usize, 2, 5);
    const needed = 2 + hold_len; // press + hold + release
    if (max < needed) return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    acc.* |= btn;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    for (frames[1 .. 1 + hold_len]) |*f| {
        f.* = .{ .delta = .{}, .dt_ms = 16 };
    }
    acc.* &= ~btn;
    frames[1 + hold_len] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    return needed;
}

fn genButtonHold(frames: []Frame, rng: std.Random, max: usize, acc: *u64) usize {
    const hold_len = rng.intRangeAtMost(usize, 10, 20);
    const needed = 2 + hold_len;
    if (max < needed) return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    acc.* |= btn;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    for (frames[1 .. 1 + hold_len]) |*f| {
        f.* = .{ .delta = .{}, .dt_ms = 16 };
    }
    acc.* &= ~btn;
    frames[1 + hold_len] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    return needed;
}

fn genSimultaneousPress(frames: []Frame, rng: std.Random, max: usize, acc: *u64) usize {
    if (max < 3) return genIdle(frames, rng, max);
    const n_btns = rng.intRangeAtMost(u8, 2, 3);
    var mask: u64 = 0;
    for (0..n_btns) |_| mask |= randomButton(rng);
    acc.* |= mask;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    frames[1] = .{ .delta = .{}, .dt_ms = 16 };
    acc.* &= ~mask;
    frames[2] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    return 3;
}

// Returns the trigger mask for the first hold-activation layer in cfg, or null.
fn holdLayerTrigger(cfg: ?mapping.MappingConfig) ?u64 {
    const layers = (cfg orelse return null).layer orelse return null;
    for (layers) |*l| {
        if (std.mem.eql(u8, l.activation, "hold")) {
            return triggerNameToMask(l.trigger);
        }
    }
    return null;
}

// Returns the trigger mask for the first toggle-activation layer in cfg, or null.
fn toggleLayerTrigger(cfg: ?mapping.MappingConfig) ?u64 {
    const layers = (cfg orelse return null).layer orelse return null;
    for (layers) |*l| {
        if (std.mem.eql(u8, l.activation, "toggle")) {
            return triggerNameToMask(l.trigger);
        }
    }
    return null;
}

fn triggerNameToMask(name: []const u8) u64 {
    const fields = @typeInfo(ButtonId).@"enum".fields;
    inline for (fields) |f| {
        if (std.mem.eql(u8, f.name, name)) {
            return @as(u64, 1) << @as(u6, @intCast(f.value));
        }
    }
    return 0;
}

fn genLayerHold(frames: []Frame, rng: std.Random, max: usize, cfg: ?mapping.MappingConfig, acc: *u64) usize {
    if (max < 6) return genIdle(frames, rng, max);
    const trigger = holdLayerTrigger(cfg) orelse return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    acc.* |= trigger;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // press trigger
    frames[1] = .{ .delta = .{}, .dt_ms = 16 };
    acc.* |= btn;
    frames[2] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // press button while layer held
    frames[3] = .{ .delta = .{}, .dt_ms = 16 };
    acc.* &= ~btn;
    frames[4] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release button
    acc.* &= ~trigger;
    frames[5] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release trigger
    return 6;
}

fn genLayerToggle(frames: []Frame, rng: std.Random, max: usize, cfg: ?mapping.MappingConfig, acc: *u64) usize {
    if (max < 4) return genIdle(frames, rng, max);
    const trigger = toggleLayerTrigger(cfg) orelse return genIdle(frames, rng, max);
    acc.* |= trigger;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // press -> toggle on
    acc.* &= ~trigger;
    frames[1] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release
    acc.* |= trigger;
    frames[2] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // press -> toggle off
    acc.* &= ~trigger;
    frames[3] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release
    return 4;
}

fn genAxisSweep(frames: []Frame, rng: std.Random, max: usize) usize {
    const n = @min(20, max);
    if (n == 0) return 0;
    // Gap 12: sweep randomly chosen axis including gyro
    const axis_choice = rng.intRangeAtMost(u8, 0, 8);
    const step: i32 = @divTrunc(65535, @as(i32, @intCast(n)));
    for (frames[0..n], 0..) |*f, i| {
        const val: i16 = @intCast(@as(i32, -32768) + step * @as(i32, @intCast(i)));
        var d = GamepadStateDelta{};
        switch (axis_choice) {
            0 => d.ax = val,
            1 => d.ay = val,
            2 => d.rx = val,
            3 => d.ry = val,
            4 => d.lt = @intCast(@as(u16, @bitCast(val)) >> 8),
            5 => d.rt = @intCast(@as(u16, @bitCast(val)) >> 8),
            6 => d.gyro_x = val,
            7 => d.gyro_y = val,
            8 => d.gyro_z = val,
            else => unreachable,
        }
        f.* = .{ .delta = d, .dt_ms = 16 };
    }
    return n;
}

fn genRapidToggle(frames: []Frame, rng: std.Random, max: usize, cfg: ?mapping.MappingConfig) usize {
    const n = @min(10, max);
    _ = rng;
    const trigger = toggleLayerTrigger(cfg) orelse btnMask(.Select);
    for (frames[0..n], 0..) |*f, i| {
        f.* = .{
            .delta = .{ .buttons = if (i % 2 == 0) trigger else 0 },
            .dt_ms = 8,
        };
    }
    return n;
}

fn genAllButtons(frames: []Frame, rng: std.Random, max: usize) usize {
    if (max < 2) return genIdle(frames, rng, max);
    // Set all 33 ButtonId bits
    const field_count = @typeInfo(ButtonId).@"enum".fields.len;
    var all: u64 = 0;
    for (0..field_count) |i| all |= @as(u64, 1) << @as(u6, @intCast(i));
    frames[0] = .{ .delta = .{ .buttons = all }, .dt_ms = 16 };
    frames[1] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 };
    return 2;
}

fn genStress(frames: []Frame, rng: std.Random, max: usize) usize {
    const n = @min(10, max);
    for (frames[0..n]) |*f| {
        f.delta = state.generateRandomDelta(rng);
        f.dt_ms = rng.intRangeAtMost(u16, 1, 100);
    }
    return n;
}

// Gap 13: press A -> activate layer -> release A
fn genButtonHeldAcrossLayerSwitch(frames: []Frame, rng: std.Random, max: usize, cfg: ?mapping.MappingConfig, acc: *u64) usize {
    if (max < 4) return genIdle(frames, rng, max);
    const trigger = holdLayerTrigger(cfg) orelse return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    acc.* |= btn;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // press button
    acc.* |= trigger;
    frames[1] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // activate layer while button held
    frames[2] = .{ .delta = .{}, .dt_ms = 16 };
    acc.* &= ~(btn | trigger);
    frames[3] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release both
    return 4;
}

// Gap 13: boundary values for axes
fn genBoundaryValues(frames: []Frame, rng: std.Random, max: usize) usize {
    const vals = [_]i16{ 0, 1, -1, 32767, -32768 };
    const n = @min(vals.len, max);
    if (n == 0) return 0;
    _ = rng;
    for (frames[0..n], 0..) |*f, i| {
        f.* = .{ .delta = .{ .ax = vals[i], .ay = vals[i], .rx = vals[i], .ry = vals[i] }, .dt_ms = 16 };
    }
    return n;
}

// Gap 13: touch active -> inactive transitions
fn genTouchTransition(frames: []Frame, rng: std.Random, max: usize) usize {
    if (max < 4) return genIdle(frames, rng, max);
    frames[0] = .{ .delta = .{ .touch0_active = true, .touch0_x = 100, .touch0_y = 200 }, .dt_ms = 16 };
    frames[1] = .{ .delta = .{ .touch0_x = 150, .touch0_y = 250 }, .dt_ms = 16 };
    frames[2] = .{ .delta = .{ .touch0_active = false }, .dt_ms = 16 };
    frames[3] = .{ .delta = .{}, .dt_ms = 16 };
    return 4;
}

// Gap 13: dpad direction change without neutral
fn genDpadDirectionChange(frames: []Frame, rng: std.Random, max: usize, acc: *u64) usize {
    if (max < 3) return genIdle(frames, rng, max);
    const up = btnMask(.DPadUp);
    const right = btnMask(.DPadRight);
    acc.* |= up;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // Up
    acc.* = (acc.* & ~up) | right;
    frames[1] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // Right (no neutral)
    acc.* &= ~right;
    frames[2] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 }; // release
    return 3;
}

// Gap 13: trigger boundary values
fn genTriggerBoundary(frames: []Frame, rng: std.Random, max: usize) usize {
    const vals = [_]u8{ 0, 1, 254, 255 };
    const n = @min(vals.len, max);
    if (n == 0) return 0;
    _ = rng;
    for (frames[0..n], 0..) |*f, i| {
        f.* = .{ .delta = .{ .lt = vals[i], .rt = vals[i] }, .dt_ms = 16 };
    }
    return n;
}

// Gap 13: toggle layer on, then hold another layer
fn genDualLayer(frames: []Frame, rng: std.Random, max: usize, cfg: ?mapping.MappingConfig, acc: *u64) usize {
    if (max < 6) return genIdle(frames, rng, max);
    const toggle_t = toggleLayerTrigger(cfg) orelse return genIdle(frames, rng, max);
    const hold_t = holdLayerTrigger(cfg) orelse return genIdle(frames, rng, max);
    if (toggle_t == hold_t) return genIdle(frames, rng, max);
    // Toggle on
    acc.* |= toggle_t;
    frames[0] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    acc.* &= ~toggle_t;
    frames[1] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    // Hold layer
    acc.* |= hold_t;
    frames[2] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    frames[3] = .{ .delta = .{}, .dt_ms = 16 };
    acc.* &= ~hold_t;
    frames[4] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 16 };
    // Toggle off
    acc.* |= toggle_t;
    frames[5] = .{ .delta = .{ .buttons = acc.* }, .dt_ms = 8 };
    acc.* &= ~toggle_t;
    return 6;
}

fn randomButton(rng: std.Random) u64 {
    const field_count = @typeInfo(ButtonId).@"enum".fields.len;
    const idx = rng.intRangeAtMost(usize, 0, field_count - 1);
    return @as(u64, 1) << @as(u6, @intCast(idx));
}

// --- Tests ---

test "sequence_gen: generated sequence has correct length" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    var frames: [200]Frame = undefined;
    randomSequence(rng, &frames, null);
    // All frames should be initialized (dt_ms > 0 for non-idle or == 16 for idle)
    for (frames) |f| {
        try std.testing.expect(f.dt_ms > 0);
    }
}

test "sequence_gen: stress sequence covers all button bits" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    var frames: [1000]Frame = undefined;
    stressSequence(rng, &frames);

    const field_count = @typeInfo(ButtonId).@"enum".fields.len;
    var seen: u64 = 0;
    for (frames) |f| {
        if (f.delta.buttons) |b| seen |= b;
    }
    // With 1000 random u64 values, every bit among 0..field_count should appear
    for (0..field_count) |i| {
        try std.testing.expect((seen & (@as(u64, 1) << @as(u6, @intCast(i)))) != 0);
    }
}
