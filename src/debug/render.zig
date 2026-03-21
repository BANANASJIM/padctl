const std = @import("std");
const state = @import("../core/state.zig");

pub const GamepadState = state.GamepadState;
pub const ButtonId = state.ButtonId;

// ANSI helpers
const CSI = "\x1b[";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";

fn moveTo(writer: anytype, row: u8, col: u8) !void {
    try writer.print(CSI ++ "{d};{d}H", .{ row, col });
}

fn clearScreen(writer: anytype) !void {
    try writer.writeAll(CSI ++ "2J" ++ CSI ++ "H");
}

fn bar(writer: anytype, value: u8, width: u8) !void {
    const filled: u8 = @intCast(@as(u16, value) * width / 255);
    try writer.writeAll(GREEN);
    var i: u8 = 0;
    while (i < width) : (i += 1) {
        try writer.writeAll(if (i < filled) "█" else "░");
    }
    try writer.writeAll(RESET);
}

fn signedBar(writer: anytype, value: i16, width: u8) !void {
    // center = width/2, positive goes right, negative goes left
    const half: u8 = width / 2;
    const norm: i32 = @divTrunc(@as(i32, value) * half, 32767);
    const pos: i32 = @as(i32, half) + norm;
    var i: u8 = 0;
    while (i < width) : (i += 1) {
        const fi: i32 = i;
        const in_bar = if (norm >= 0) (fi >= half and fi < pos) else (fi >= pos and fi < half);
        if (i == half) {
            try writer.writeAll("|");
        } else if (in_bar) {
            try writer.writeAll(GREEN ++ "█" ++ RESET);
        } else {
            try writer.writeAll("░");
        }
    }
}

fn btnLabel(writer: anytype, gs: *const GamepadState, btn: ButtonId, label: []const u8) !void {
    const bit: u5 = @intCast(@intFromEnum(btn));
    const pressed = gs.buttons & (@as(u32, 1) << bit) != 0;
    if (pressed) {
        try writer.print(GREEN ++ "[{s}]" ++ RESET, .{label});
    } else {
        try writer.print(DIM ++ "[{s}]" ++ RESET, .{label});
    }
}

/// Render a full TUI frame. Pure function: takes writer + GamepadState + raw report bytes.
/// Assumes 80×24 terminal. Uses ANSI escape sequences only.
pub fn renderFrame(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
) !void {
    try clearScreen(writer);
    try writer.writeAll(BOLD ++ CYAN);
    try writer.writeAll("┌─ Sticks ──────────┬─ Triggers ──┬─ Buttons ──────────────────────┐\r\n");
    try writer.writeAll(RESET);

    // Row 2: LX / LT bar / buttons row 1
    try writer.writeAll("│ LX:");
    try writer.print("{:>6} ", .{gs.ax});
    try writer.writeAll("        │ LT ");
    try bar(writer, gs.lt, 8);
    try writer.writeAll(" │ ");
    try btnLabel(writer, gs, .A, "A");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .B, "B");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .X, "X");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .Y, "Y");
    try writer.writeAll("           │\r\n");

    // Row 3: LY / RT bar / buttons row 2
    try writer.writeAll("│ LY:");
    try writer.print("{:>6} ", .{gs.ay});
    try writer.writeAll("        │ RT ");
    try bar(writer, gs.rt, 8);
    try writer.writeAll(" │ ");
    try btnLabel(writer, gs, .LB, "LB");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .RB, "RB");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .Start, "START");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .Select, "SEL");
    try writer.writeAll("   │\r\n");

    // Row 4: RX / LT value / buttons row 3
    try writer.writeAll("│ RX:");
    try writer.print("{:>6} ", .{gs.rx});
    try writer.writeAll("        │ LT:");
    try writer.print("{:>4} RT:{:>4}│ ", .{ gs.lt, gs.rt });
    try btnLabel(writer, gs, .LS, "L3");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .RS, "R3");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .Home, "HOME");
    try writer.writeAll("              │\r\n");

    // Row 5: RY / dpad / buttons row 4
    try writer.writeAll("│ RY:");
    try writer.print("{:>6} ", .{gs.ry});
    try writer.writeAll("        ├─ DPad ──────┤ ");
    try btnLabel(writer, gs, .M1, "M1");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .M2, "M2");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .M3, "M3");
    try writer.writeAll(" ");
    try btnLabel(writer, gs, .M4, "M4");
    try writer.writeAll("           │\r\n");

    // Row 6: dpad up
    {
        const up_pressed = gs.buttons & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.DPadUp)))) != 0;
        try writer.writeAll("│                   │     ");
        if (up_pressed) try writer.writeAll(GREEN ++ "↑" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try writer.writeAll("       │                               │\r\n");
    }

    // Row 7: dpad left/right
    {
        const left_p = gs.buttons & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.DPadLeft)))) != 0;
        const right_p = gs.buttons & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.DPadRight)))) != 0;
        try writer.writeAll("│                   │   ");
        if (left_p) try writer.writeAll(GREEN ++ "←" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try writer.writeAll(" · ");
        if (right_p) try writer.writeAll(GREEN ++ "→" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try writer.writeAll("     │                               │\r\n");
    }

    // Row 8: dpad down
    {
        const down_p = gs.buttons & (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.DPadDown)))) != 0;
        try writer.writeAll("│                   │     ");
        if (down_p) try writer.writeAll(GREEN ++ "↓" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try writer.writeAll("       │                               │\r\n");
    }

    try writer.writeAll(BOLD ++ CYAN);
    try writer.writeAll("├─ Gyro ────────────────────────────────────────────────────────────┤\r\n");
    try writer.writeAll(RESET);

    // Gyro X
    try writer.writeAll("│ GX ");
    try signedBar(writer, gs.gyro_x, 32);
    try writer.print("  {:>6}  AX:{:>6} │\r\n", .{ gs.gyro_x, gs.accel_x });

    // Gyro Y
    try writer.writeAll("│ GY ");
    try signedBar(writer, gs.gyro_y, 32);
    try writer.print("  {:>6}  AY:{:>6} │\r\n", .{ gs.gyro_y, gs.accel_y });

    // Gyro Z
    try writer.writeAll("│ GZ ");
    try signedBar(writer, gs.gyro_z, 32);
    try writer.print("  {:>6}  AZ:{:>6} │\r\n", .{ gs.gyro_z, gs.accel_z });

    try writer.writeAll(BOLD ++ CYAN);
    try writer.writeAll("├─ Raw Hex ─────────────────────────────────────────────────────────┤\r\n");
    try writer.writeAll(RESET);

    // Hex dump up to 32 bytes, two rows of 16
    try writer.writeAll("│ ");
    const show = @min(raw.len, 16);
    for (raw[0..show]) |b| {
        try writer.print("{x:0>2} ", .{b});
    }
    if (show < 16) {
        var pad: usize = 0;
        while (pad < 16 - show) : (pad += 1) try writer.writeAll("   ");
    }
    try writer.writeAll("│\r\n│ ");
    const show2_start: usize = 16;
    const show2 = if (raw.len > show2_start) @min(raw.len - show2_start, 16) else 0;
    for (raw[show2_start .. show2_start + show2]) |b| {
        try writer.print("{x:0>2} ", .{b});
    }
    if (show2 < 16) {
        var pad: usize = 0;
        while (pad < 16 - show2) : (pad += 1) try writer.writeAll("   ");
    }
    try writer.writeAll("│\r\n");

    try writer.writeAll(BOLD ++ CYAN);
    try writer.writeAll("└");
    try writer.writeAll(RESET);
    if (rumble_on) {
        try writer.writeAll(YELLOW ++ " [Q]uit  [R]umble ON  " ++ RESET);
    } else {
        try writer.writeAll(" [Q]uit  [R]umble OFF ");
    }
    try writer.writeAll(BOLD ++ CYAN ++ "────────────────────────────────────────────┘" ++ RESET);
    try writer.writeAll("\r\n");
    _ = moveTo; // suppress unused warning; used in non-clearScreen rendering path if needed
}

// --- tests ---

const testing = std.testing;

fn makeTestState() GamepadState {
    return GamepadState{
        .ax = 1234,
        .ay = -567,
        .rx = -4321,
        .ry = 999,
        .lt = 128,
        .rt = 64,
        .buttons = (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.A)))) |
            (@as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.LB)))),
        .gyro_x = 100,
        .gyro_y = -200,
        .gyro_z = 300,
        .accel_x = -100,
        .accel_y = 200,
        .accel_z = -300,
    };
}

test "renderFrame: contains axis values" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{ 0x5a, 0xa5, 0xef, 0x01, 0x02 };
    try renderFrame(fbs.writer(), &gs, &raw, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "1234") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-567") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-4321") != null);
    try testing.expect(std.mem.indexOf(u8, out, "999") != null);
}

test "renderFrame: contains trigger values" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "128") != null);
    try testing.expect(std.mem.indexOf(u8, out, "64") != null);
}

test "renderFrame: contains gyro values" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "100") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-200") != null);
    try testing.expect(std.mem.indexOf(u8, out, "300") != null);
}

test "renderFrame: contains raw hex bytes" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    try renderFrame(fbs.writer(), &gs, &raw, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "de") != null);
    try testing.expect(std.mem.indexOf(u8, out, "ad") != null);
    try testing.expect(std.mem.indexOf(u8, out, "be") != null);
    try testing.expect(std.mem.indexOf(u8, out, "ef") != null);
}

test "renderFrame: rumble_on shows rumble indicator" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, true);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "ON") != null);
}

test "renderFrame: contains ANSI escape sequences" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false);
    const out = fbs.getWritten();
    // Must contain ESC[ (CSI)
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[") != null);
}

test "renderFrame: pressed button highlighted differently" {
    var buf_pressed: [4096]u8 = undefined;
    var buf_released: [4096]u8 = undefined;
    var fbs1 = std.io.fixedBufferStream(&buf_pressed);
    var fbs2 = std.io.fixedBufferStream(&buf_released);

    var gs_pressed = GamepadState{};
    gs_pressed.buttons = @as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.A)));
    var gs_released = GamepadState{};
    gs_released.buttons = 0;

    const raw = [_]u8{};
    try renderFrame(fbs1.writer(), &gs_pressed, &raw, false);
    try renderFrame(fbs2.writer(), &gs_released, &raw, false);

    // The two outputs must differ (pressed state changes rendering)
    try testing.expect(!std.mem.eql(u8, fbs1.getWritten(), fbs2.getWritten()));
}
