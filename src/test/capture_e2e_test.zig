// Capture E2E tests: analyse, TOML skeleton generation, debug render.
// Split from phase3_e2e_test.zig (T1-T3).

const std = @import("std");
const testing = std.testing;

const analyse_mod = @import("analyse");
const toml_gen_mod = @import("toml_gen");
const render_mod = @import("../debug/render.zig");
const state_mod = @import("../core/state.zig");

const Frame = analyse_mod.Frame;
const AnalysisResult = analyse_mod.AnalysisResult;
const DeviceInfo = toml_gen_mod.DeviceInfo;
const GamepadState = state_mod.GamepadState;
const ButtonId = state_mod.ButtonId;

// --- T1: capture analyse ---

test "capture: 32-byte frames — magic prefix detected" {
    const allocator = testing.allocator;

    // 100 frames; bytes 0-2 always 0x5a 0xa5 0xef; rest vary
    var datas: [100][32]u8 = undefined;
    var frames: [100]Frame = undefined;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (&datas, 0..) |*d, i| {
        rng.bytes(d);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    try testing.expectEqual(@as(u16, 32), result.report_size);

    var found_magic: [3]bool = .{ false, false, false };
    for (result.magic) |m| {
        if (m.offset == 0 and m.value == 0x5a) found_magic[0] = true;
        if (m.offset == 1 and m.value == 0xa5) found_magic[1] = true;
        if (m.offset == 2 and m.value == 0xef) found_magic[2] = true;
    }
    try testing.expect(found_magic[0]);
    try testing.expect(found_magic[1]);
    try testing.expect(found_magic[2]);
}

test "capture: i16le axis at offset 3-4, range -32468..32102" {
    const allocator = testing.allocator;

    const axis_vals = [_]i16{ -32468, 0, 16000, 32102, -10000 };
    var datas: [5][32]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        const u: u16 = @bitCast(axis_vals[i]);
        d[3] = @intCast(u & 0xff);
        d[4] = @intCast(u >> 8);
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 3 and a.axis_type == .i16le) {
            found = true;
            try testing.expect(a.min_val <= -10000);
            try testing.expect(a.max_val >= 16000);
        }
    }
    try testing.expect(found);
}

test "capture: u8 axis at offset 8, range 0..255" {
    const allocator = testing.allocator;

    const u8_vals = [_]u8{ 0, 64, 128, 200, 255 };
    var datas: [5][32]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        d[8] = u8_vals[i];
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 8 and a.axis_type == .u8_axis) {
            found = true;
            try testing.expectEqual(@as(i32, 0), a.min_val);
            try testing.expectEqual(@as(i32, 255), a.max_val);
        }
    }
    try testing.expect(found);
}

test "capture: button detection — bit 3 of byte 11, 6 toggles, high confidence" {
    const allocator = testing.allocator;

    var datas: [7][32]u8 = undefined;
    var frames: [7]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        if (i % 2 == 1) d[11] = 0x08;
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.buttons) |b| {
        if (b.byte_offset == 11 and b.bit == 3 and b.high_confidence) {
            found = true;
        }
    }
    try testing.expect(found);
}

// --- T2: TOML skeleton generation ---

test "capture: emitToml — contains [device], [[report]], [report.fields]" {
    const allocator = testing.allocator;

    // Build a minimal AnalysisResult
    var magic = [_]analyse_mod.MagicByte{.{ .offset = 0, .value = 0x5a }};
    var buttons = [_]analyse_mod.ButtonCandidate{
        .{ .byte_offset = 11, .bit = 3, .toggle_count = 6, .high_confidence = true },
        .{ .byte_offset = 11, .bit = 5, .toggle_count = 6, .high_confidence = true },
    };
    var axes = [_]analyse_mod.AxisCandidate{
        .{ .offset = 3, .axis_type = .i16le, .min_val = -32468, .max_val = 32102 },
        .{ .offset = 8, .axis_type = .u8_axis, .min_val = 0, .max_val = 255 },
    };
    const result = AnalysisResult{
        .report_size = 32,
        .magic = &magic,
        .buttons = &buttons,
        .axes = &axes,
    };

    const info = DeviceInfo{ .name = "Test Device", .vid = 0x37d7, .pid = 0x2401, .interface_id = 0 };

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try toml_gen_mod.emitToml(result, info, allocator, buf.writer());

    const out = buf.items;
    try testing.expect(std.mem.indexOf(u8, out, "[device]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[[report]]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.fields]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.button_group]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "i16le") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"u8\"") != null);
}

// --- T3: debug render ---

test "capture: renderFrame — ANSI sequences present" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    try render_mod.renderFrame(fbs.writer(), &gs, &[_]u8{}, false, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[") != null);
}

test "capture: renderFrame — correct axis values rendered" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = GamepadState{};
    gs.ax = -1234;
    gs.ry = 5678;
    gs.gyro_x = 2345;
    try render_mod.renderFrame(fbs.writer(), &gs, &[_]u8{}, false, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "-1234") != null);
    try testing.expect(std.mem.indexOf(u8, out, "5678") != null);
    try testing.expect(std.mem.indexOf(u8, out, "2345") != null);
}

test "capture: renderFrame — pressed button differs from released" {
    var buf_on: [8192]u8 = undefined;
    var buf_off: [8192]u8 = undefined;
    var fbs_on = std.io.fixedBufferStream(&buf_on);
    var fbs_off = std.io.fixedBufferStream(&buf_off);

    var gs_on = GamepadState{};
    gs_on.buttons = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.A)));
    var gs_off = GamepadState{};

    try render_mod.renderFrame(fbs_on.writer(), &gs_on, &[_]u8{}, false, .{}, .raw);
    try render_mod.renderFrame(fbs_off.writer(), &gs_off, &[_]u8{}, false, .{}, .raw);

    try testing.expect(!std.mem.eql(u8, fbs_on.getWritten(), fbs_off.getWritten()));
}
