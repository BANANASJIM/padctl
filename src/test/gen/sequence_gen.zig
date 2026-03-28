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

pub fn randomSequence(rng: std.Random, frames: []Frame) void {
    // Compose random scenario templates into the frame buffer
    var pos: usize = 0;
    while (pos < frames.len) {
        const scenario = rng.intRangeAtMost(u8, 0, 9);
        const remaining = frames.len - pos;
        const written = switch (scenario) {
            0 => genIdle(frames[pos..], rng, remaining),
            1 => genButtonTap(frames[pos..], rng, remaining),
            2 => genButtonHold(frames[pos..], rng, remaining),
            3 => genSimultaneousPress(frames[pos..], rng, remaining),
            4 => genLayerHold(frames[pos..], rng, remaining),
            5 => genLayerToggle(frames[pos..], rng, remaining),
            6 => genAxisSweep(frames[pos..], rng, remaining),
            7 => genRapidToggle(frames[pos..], rng, remaining),
            8 => genAllButtons(frames[pos..], rng, remaining),
            9 => genStress(frames[pos..], rng, remaining),
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

fn genButtonTap(frames: []Frame, rng: std.Random, max: usize) usize {
    const hold_len = rng.intRangeAtMost(usize, 2, 5);
    const needed = 2 + hold_len; // press + hold + release
    if (max < needed) return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    frames[0] = .{ .delta = .{ .buttons = btn }, .dt_ms = 16 };
    for (frames[1 .. 1 + hold_len]) |*f| {
        f.* = .{ .delta = .{}, .dt_ms = 16 };
    }
    frames[1 + hold_len] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 };
    return needed;
}

fn genButtonHold(frames: []Frame, rng: std.Random, max: usize) usize {
    const hold_len = rng.intRangeAtMost(usize, 10, 20);
    const needed = 2 + hold_len;
    if (max < needed) return genIdle(frames, rng, max);
    const btn = randomButton(rng);
    frames[0] = .{ .delta = .{ .buttons = btn }, .dt_ms = 16 };
    for (frames[1 .. 1 + hold_len]) |*f| {
        f.* = .{ .delta = .{}, .dt_ms = 16 };
    }
    frames[1 + hold_len] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 };
    return needed;
}

fn genSimultaneousPress(frames: []Frame, rng: std.Random, max: usize) usize {
    if (max < 3) return genIdle(frames, rng, max);
    const n_btns = rng.intRangeAtMost(u8, 2, 3);
    var mask: u64 = 0;
    for (0..n_btns) |_| mask |= randomButton(rng);
    frames[0] = .{ .delta = .{ .buttons = mask }, .dt_ms = 16 };
    frames[1] = .{ .delta = .{}, .dt_ms = 16 };
    frames[2] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 };
    return 3;
}

fn genLayerHold(frames: []Frame, rng: std.Random, max: usize) usize {
    if (max < 6) return genIdle(frames, rng, max);
    const trigger = btnMask(.LT);
    const btn = randomButton(rng);
    frames[0] = .{ .delta = .{ .buttons = trigger }, .dt_ms = 16 }; // press trigger
    frames[1] = .{ .delta = .{}, .dt_ms = 16 };
    frames[2] = .{ .delta = .{ .buttons = trigger | btn }, .dt_ms = 16 }; // press button while layer held
    frames[3] = .{ .delta = .{}, .dt_ms = 16 };
    frames[4] = .{ .delta = .{ .buttons = trigger }, .dt_ms = 16 }; // release button
    frames[5] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 }; // release trigger
    return 6;
}

fn genLayerToggle(frames: []Frame, rng: std.Random, max: usize) usize {
    if (max < 4) return genIdle(frames, rng, max);
    const trigger = btnMask(.Select);
    frames[0] = .{ .delta = .{ .buttons = trigger }, .dt_ms = 16 }; // press
    frames[1] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 }; // release -> toggle on
    frames[2] = .{ .delta = .{ .buttons = trigger }, .dt_ms = 16 }; // press
    frames[3] = .{ .delta = .{ .buttons = 0 }, .dt_ms = 16 }; // release -> toggle off
    return 4;
}

fn genAxisSweep(frames: []Frame, rng: std.Random, max: usize) usize {
    const n = @min(20, max);
    if (n == 0) return 0;
    _ = rng;
    const step: i32 = @divTrunc(65535, @as(i32, @intCast(n)));
    for (frames[0..n], 0..) |*f, i| {
        const val: i16 = @intCast(@as(i32, -32768) + step * @as(i32, @intCast(i)));
        f.* = .{ .delta = .{ .ax = val }, .dt_ms = 16 };
    }
    return n;
}

fn genRapidToggle(frames: []Frame, rng: std.Random, max: usize) usize {
    const n = @min(10, max);
    _ = rng;
    const trigger = btnMask(.Select);
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
    // Set all 32 ButtonId bits
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
    randomSequence(rng, &frames);
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
