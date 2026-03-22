const std = @import("std");
const mem = std.mem;
const state = @import("../core/state.zig");
const device_config = @import("../config/device.zig");

pub const GamepadState = state.GamepadState;
pub const ButtonId = state.ButtonId;
pub const DeviceConfig = device_config.DeviceConfig;

// Box: 70 visible chars total (including │ borders)
const W = 70;

// 3-column layout widths (visible chars including leading border)
const CL = 20; // left: │ + 19
const CM = 15; // mid:  │ + 14
// right: W - CL - CM = 35 (│ + 33 inner + closing │)
const CR_START = CL + CM; // col 35: where right section │ sits

const CSI = "\x1b[";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const GREEN = "\x1b[32m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";

pub const RenderConfig = struct {
    has_gyro: bool = false,
    has_touchpad: bool = false,
    has_c: bool = false,
    has_z: bool = false,
    has_lm: bool = false,
    has_rm: bool = false,
    has_o: bool = false,

    pub fn hasExtButtons(self: RenderConfig) bool {
        return self.has_c or self.has_z or self.has_lm or self.has_rm or self.has_o;
    }

    pub fn deriveFromConfig(cfg: *const DeviceConfig) RenderConfig {
        var rc = RenderConfig{};
        for (cfg.report) |report| {
            if (report.fields) |fields| {
                var it = fields.map.iterator();
                while (it.next()) |entry| {
                    const name = entry.key_ptr.*;
                    if (mem.eql(u8, name, "gyro_x")) rc.has_gyro = true;
                    if (mem.eql(u8, name, "touch0_x")) rc.has_touchpad = true;
                }
            }
            if (report.button_group) |bg| {
                var it = bg.map.map.iterator();
                while (it.next()) |entry| {
                    const btn_name = entry.key_ptr.*;
                    if (mem.eql(u8, btn_name, "C")) rc.has_c = true;
                    if (mem.eql(u8, btn_name, "Z")) rc.has_z = true;
                    if (mem.eql(u8, btn_name, "LM")) rc.has_lm = true;
                    if (mem.eql(u8, btn_name, "RM")) rc.has_rm = true;
                    if (mem.eql(u8, btn_name, "O")) rc.has_o = true;
                }
            }
        }
        return rc;
    }
};

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

fn btnLabel(writer: anytype, gs: *const GamepadState, btn: ButtonId, label: []const u8) !usize {
    const bit: u6 = @intCast(@intFromEnum(btn));
    const pressed = gs.buttons & (@as(u64, 1) << bit) != 0;
    if (pressed) {
        try writer.print(GREEN ++ "[{s}]" ++ RESET, .{label});
    } else {
        try writer.print(DIM ++ "[{s}]" ++ RESET, .{label});
    }
    return label.len + 2;
}

fn pad(writer: anytype, from: usize, to: usize) !void {
    var i: usize = from;
    while (i < to) : (i += 1) try writer.writeAll(" ");
}

fn closeRow(writer: anytype, col: usize) !void {
    try pad(writer, col, W - 1);
    try writer.writeAll("│\r\n");
}

fn sectionHeader(writer: anytype, title: []const u8) !void {
    try writer.writeAll(BOLD ++ CYAN ++ "├─ " ++ RESET ++ BOLD ++ CYAN);
    try writer.writeAll(title);
    try writer.writeAll(" ");
    const used = 4 + title.len;
    var i: usize = used;
    while (i < W - 1) : (i += 1) try writer.writeAll("─");
    try writer.writeAll("┤" ++ RESET ++ "\r\n");
}

pub fn renderFrame(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
    config: RenderConfig,
) !void {
    try clearScreen(writer);

    // ┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐
    // 1 + 19 + 1 + 14 + 1 + 33 + 1 = 70
    try writer.writeAll(BOLD ++ CYAN ++
        "┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐\r\n" ++
        RESET);

    // Row 1: LX / LT bar / A B X Y
    {
        try writer.writeAll("│ LX:");
        try writer.print("{:>6}", .{gs.ax});
        try pad(writer, 11, CL); // 11 visible, pad to 20
        try writer.writeAll("│ LT ");
        try bar(writer, gs.lt, 9); // 9-wide bar
        try pad(writer, CL + 14, CL + CM); // CL+14=34, pad to 35 if needed
        try writer.writeAll("│ ");
        var col: usize = CR_START + 2; // 37
        col += try btnLabel(writer, gs, .A, "A");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .B, "B");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .X, "X");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Y, "Y");
        try closeRow(writer, col);
    }

    // Row 2: LY / RT bar / LB RB START SEL
    {
        try writer.writeAll("│ LY:");
        try writer.print("{:>6}", .{gs.ay});
        try pad(writer, 11, CL);
        try writer.writeAll("│ RT ");
        try bar(writer, gs.rt, 9);
        try pad(writer, CL + 14, CL + CM);
        try writer.writeAll("│ ");
        var col: usize = CR_START + 2;
        col += try btnLabel(writer, gs, .LB, "LB");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .RB, "RB");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Start, "START");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Select, "SEL");
        try closeRow(writer, col);
    }

    // Row 3: RX / LT:RT values / L3 R3 HOME
    {
        try writer.writeAll("│ RX:");
        try writer.print("{:>6}", .{gs.rx});
        try pad(writer, 11, CL);
        // Mid: │LT:xxx RT:xxx  = 1+3+3+4+3 = 14, pad to 15
        try writer.writeAll("│LT:");
        try writer.print("{:>3}", .{gs.lt});
        try writer.writeAll(" RT:");
        try writer.print("{:>3}", .{gs.rt});
        try pad(writer, CL + 14, CL + CM);
        try writer.writeAll("│ ");
        var col: usize = CR_START + 2;
        col += try btnLabel(writer, gs, .LS, "L3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .RS, "R3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Home, "HOME");
        try closeRow(writer, col);
    }

    // Row 4: RY / dpad header / M1-M4
    {
        try writer.writeAll("│ RY:");
        try writer.print("{:>6}", .{gs.ry});
        try pad(writer, 11, CL);
        // ├─ DPad ──────┤ = 15 visible, then 2 spaces into right col
        try writer.writeAll("├─ DPad ──────┤  ");
        var col: usize = CR_START + 2;
        col += try btnLabel(writer, gs, .M1, "M1");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M2, "M2");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M3, "M3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M4, "M4");
        try closeRow(writer, col);
    }

    // DPad up
    {
        try writer.writeAll("│");
        try pad(writer, 1, CL);
        try writer.writeAll("│      ");
        const up_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadUp)))) != 0;
        if (up_p) try writer.writeAll(GREEN ++ "↑" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try pad(writer, CL + 8, CR_START);
        try writer.writeAll("│");
        // right section: ext buttons or empty
        if (config.hasExtButtons()) {
            try writer.writeAll(" ");
            var col: usize = CR_START + 2;
            if (config.has_c) {
                col += try btnLabel(writer, gs, .C, "C");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_z) {
                col += try btnLabel(writer, gs, .Z, "Z");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_lm) {
                col += try btnLabel(writer, gs, .LM, "LM");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_rm) {
                col += try btnLabel(writer, gs, .RM, "RM");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_o) {
                col += try btnLabel(writer, gs, .O, "O");
            }
            try closeRow(writer, col);
        } else {
            try closeRow(writer, CR_START + 1);
        }
    }

    // DPad left · right
    {
        try writer.writeAll("│");
        try pad(writer, 1, CL);
        try writer.writeAll("│    ");
        const left_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadLeft)))) != 0;
        const right_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadRight)))) != 0;
        if (left_p) try writer.writeAll(GREEN ++ "←" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try writer.writeAll(" · ");
        if (right_p) try writer.writeAll(GREEN ++ "→" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try pad(writer, CL + 10, CR_START);
        try writer.writeAll("│");
        try closeRow(writer, CR_START + 1);
    }

    // DPad down
    {
        try writer.writeAll("│");
        try pad(writer, 1, CL);
        try writer.writeAll("│      ");
        const down_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadDown)))) != 0;
        if (down_p) try writer.writeAll(GREEN ++ "↓" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
        try pad(writer, CL + 8, CR_START);
        try writer.writeAll("│");
        try closeRow(writer, CR_START + 1);
    }

    // Gyro (conditional)
    if (config.has_gyro) {
        try sectionHeader(writer, "Gyro");
        // │ GX  + 32-bar + "  " + 6-digit + "  AX:" + 6-digit = 5+32+2+6+5+6 = 56
        inline for (.{
            .{ "GX", "AX", &gs.gyro_x, &gs.accel_x },
            .{ "GY", "AY", &gs.gyro_y, &gs.accel_y },
            .{ "GZ", "AZ", &gs.gyro_z, &gs.accel_z },
        }) |row| {
            try writer.writeAll("│ " ++ row[0] ++ " ");
            try signedBar(writer, row[2].*, 32);
            try writer.print("  {:>6}  " ++ row[1] ++ ":{:>6}", .{ row[2].*, row[3].* });
            try closeRow(writer, 56);
        }
    }

    // Touchpad (conditional)
    if (config.has_touchpad) {
        try sectionHeader(writer, "Touchpad");
        // │ T0 ON   X:  xxxx  Y:  xxxx = 5+3+2+2+6+4+6 = 28
        inline for (.{
            .{ "T0", &gs.touch0_active, &gs.touch0_x, &gs.touch0_y },
            .{ "T1", &gs.touch1_active, &gs.touch1_x, &gs.touch1_y },
        }) |row| {
            try writer.writeAll("│ " ++ row[0] ++ " ");
            if (row[1].*) {
                try writer.writeAll(GREEN ++ "ON " ++ RESET);
            } else {
                try writer.writeAll(DIM ++ "OFF" ++ RESET);
            }
            try writer.print("  X:{:>6}  Y:{:>6}", .{ row[2].*, row[3].* });
            try closeRow(writer, 28);
        }
    }

    // Raw hex
    try sectionHeader(writer, "Raw Hex");
    try writer.writeAll("│ ");
    const show = @min(raw.len, 16);
    for (raw[0..show]) |b| {
        try writer.print("{x:0>2} ", .{b});
    }
    try closeRow(writer, 2 + show * 3);

    if (raw.len > 16) {
        try writer.writeAll("│ ");
        const show2 = @min(raw.len - 16, 16);
        for (raw[16 .. 16 + show2]) |b| {
            try writer.print("{x:0>2} ", .{b});
        }
        try closeRow(writer, 2 + show2 * 3);
    }

    // Footer
    try writer.writeAll(BOLD ++ CYAN ++ "└" ++ RESET);
    if (rumble_on) {
        try writer.writeAll(YELLOW ++ " [Q]uit  [R]umble ON  " ++ RESET);
    } else {
        try writer.writeAll(" [Q]uit  [R]umble OFF ");
    }
    try writer.writeAll(BOLD ++ CYAN);
    var fi: usize = 23; // └(1) + text(22) = 23 visible
    while (fi < W - 1) : (fi += 1) try writer.writeAll("─");
    try writer.writeAll("┘" ++ RESET ++ "\r\n");
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
        .buttons = (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.A)))) |
            (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.LB)))),
        .gyro_x = 100,
        .gyro_y = -200,
        .gyro_z = 300,
        .accel_x = -100,
        .accel_y = 200,
        .accel_z = -300,
    };
}

const default_config = RenderConfig{ .has_gyro = true };

test "renderFrame: contains axis values" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{ 0x5a, 0xa5, 0xef, 0x01, 0x02 };
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "1234") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-567") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-4321") != null);
    try testing.expect(std.mem.indexOf(u8, out, "999") != null);
}

test "renderFrame: contains trigger values" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "128") != null);
    try testing.expect(std.mem.indexOf(u8, out, "64") != null);
}

test "renderFrame: contains gyro values" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "100") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-200") != null);
    try testing.expect(std.mem.indexOf(u8, out, "300") != null);
}

test "renderFrame: no gyro section when disabled" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{});
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Gyro") == null);
    try testing.expect(std.mem.indexOf(u8, out, "GX") == null);
}

test "renderFrame: touchpad section when enabled" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = GamepadState{};
    gs.touch0_x = 500;
    gs.touch0_active = true;
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{ .has_touchpad = true });
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Touchpad") != null);
    try testing.expect(std.mem.indexOf(u8, out, "500") != null);
}

test "renderFrame: contains raw hex bytes" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    try renderFrame(fbs.writer(), &gs, &raw, false, .{});
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "de") != null);
    try testing.expect(std.mem.indexOf(u8, out, "ad") != null);
    try testing.expect(std.mem.indexOf(u8, out, "be") != null);
    try testing.expect(std.mem.indexOf(u8, out, "ef") != null);
}

test "renderFrame: rumble_on shows rumble indicator" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, true, .{});
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "ON") != null);
}

test "renderFrame: contains ANSI escape sequences" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{});
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[") != null);
}

test "renderFrame: pressed button highlighted differently" {
    var buf_pressed: [8192]u8 = undefined;
    var buf_released: [8192]u8 = undefined;
    var fbs1 = std.io.fixedBufferStream(&buf_pressed);
    var fbs2 = std.io.fixedBufferStream(&buf_released);

    var gs_pressed = GamepadState{};
    gs_pressed.buttons = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.A)));
    var gs_released = GamepadState{};
    gs_released.buttons = 0;

    const raw = [_]u8{};
    try renderFrame(fbs1.writer(), &gs_pressed, &raw, false, .{});
    try renderFrame(fbs2.writer(), &gs_released, &raw, false, .{});

    try testing.expect(!std.mem.eql(u8, fbs1.getWritten(), fbs2.getWritten()));
}

test "renderFrame: extended buttons shown when configured" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = GamepadState{};
    gs.buttons = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.C)));
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{ .has_c = true, .has_z = true });
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "[C]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[Z]") != null);
}
