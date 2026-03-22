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

fn shortenLabel(label: []const u8) []const u8 {
    const map = .{
        .{ "BTN_SOUTH", "S" },
        .{ "BTN_EAST", "E" },
        .{ "BTN_NORTH", "N" },
        .{ "BTN_WEST", "W" },
        .{ "BTN_TL", "TL" },
        .{ "BTN_TR", "TR" },
        .{ "BTN_START", "STA" },
        .{ "BTN_SELECT", "SEL" },
        .{ "BTN_THUMBL", "L3" },
        .{ "BTN_THUMBR", "R3" },
        .{ "BTN_MODE", "HM" },
        .{ "BTN_LEFT", "ML" },
        .{ "BTN_RIGHT", "MR" },
        .{ "BTN_TRIGGER_HAPPY1", "H1" },
        .{ "BTN_TRIGGER_HAPPY2", "H2" },
        .{ "BTN_TRIGGER_HAPPY3", "H3" },
        .{ "BTN_TRIGGER_HAPPY4", "H4" },
        .{ "BTN_TRIGGER_HAPPY5", "H5" },
        .{ "BTN_TRIGGER_HAPPY6", "H6" },
        .{ "BTN_TRIGGER_HAPPY7", "H7" },
        .{ "BTN_TRIGGER_HAPPY8", "H8" },
        .{ "BTN_TRIGGER_HAPPY9", "H9" },
        .{ "KEY_SPACE", "SPC" },
        .{ "KEY_ENTER", "ENT" },
        .{ "KEY_ESC", "ESC" },
        .{ "KEY_TAB", "TAB" },
        .{ "KEY_F13", "F13" },
        .{ "KEY_F14", "F14" },
    };
    inline for (map) |entry| {
        if (mem.eql(u8, label, entry[0])) return entry[1];
    }
    // KEY_X → "X" (strip KEY_ prefix, max 4 chars)
    if (label.len > 4 and mem.eql(u8, label[0..4], "KEY_"))
        return label[4..@min(label.len, 8)];
    // Truncate anything else to 4 chars
    return label[0..@min(label.len, 4)];
}

pub const OutputInfo = struct {
    name: []const u8 = "Unknown",
    mapping_file: []const u8 = "",
};

pub const button_id_count = std.meta.fields(ButtonId).len;

pub const RenderConfig = struct {
    has_gyro: bool = false,
    has_touchpad: bool = false,
    has_c: bool = false,
    has_z: bool = false,
    has_lm: bool = false,
    has_rm: bool = false,
    has_o: bool = false,
    output_info: ?OutputInfo = null,
    button_labels: [button_id_count]?[]const u8 = .{null} ** button_id_count,

    pub fn hasExtButtons(self: RenderConfig) bool {
        return self.has_c or self.has_z or self.has_lm or self.has_rm or self.has_o;
    }

    pub fn btnDisplayLabel(self: *const RenderConfig, btn: ButtonId, default: []const u8) []const u8 {
        return shortenLabel(self.button_labels[@intFromEnum(btn)] orelse default);
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

pub const ViewMode = enum { raw, mapped };

pub fn renderFrame(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
    config: RenderConfig,
    view_mode: ViewMode,
) !void {
    try clearScreen(writer);
    const ml = view_mode == .mapped;

    // Header: show output device name in mapped mode
    if (view_mode == .mapped) {
        if (config.output_info) |info| {
            // ┌─ Output: <name> ──...──┐  (W=70)
            const prefix = "┌─ Output: ";
            const max_name = W - 4 - 11; // 4 = "─┐" + margins, 11 = prefix visible len
            const name_len = @min(info.name.len, max_name);
            try writer.writeAll(BOLD ++ CYAN ++ prefix);
            try writer.writeAll(info.name[0..name_len]);
            try writer.writeAll(" ");
            const used = 11 + name_len + 1;
            var hi: usize = used;
            while (hi < W - 1) : (hi += 1) try writer.writeAll("─");
            try writer.writeAll("┐\r\n" ++ RESET);
        } else {
            try writer.writeAll(BOLD ++ CYAN ++
                "┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐\r\n" ++
                RESET);
        }
    } else {
        // ┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐
        // 1 + 19 + 1 + 14 + 1 + 33 + 1 = 70
        try writer.writeAll(BOLD ++ CYAN ++
            "┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐\r\n" ++
            RESET);
    }

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
        col += try btnLabel(writer, gs, .A, if (ml) config.btnDisplayLabel(.A, "A") else "A");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .B, if (ml) config.btnDisplayLabel(.B, "B") else "B");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .X, if (ml) config.btnDisplayLabel(.X, "X") else "X");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Y, if (ml) config.btnDisplayLabel(.Y, "Y") else "Y");
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
        col += try btnLabel(writer, gs, .LB, if (ml) config.btnDisplayLabel(.LB, "LB") else "LB");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .RB, if (ml) config.btnDisplayLabel(.RB, "RB") else "RB");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Start, if (ml) config.btnDisplayLabel(.Start, "START") else "START");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Select, if (ml) config.btnDisplayLabel(.Select, "SEL") else "SEL");
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
        col += try btnLabel(writer, gs, .LS, if (ml) config.btnDisplayLabel(.LS, "L3") else "L3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .RS, if (ml) config.btnDisplayLabel(.RS, "R3") else "R3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .Home, if (ml) config.btnDisplayLabel(.Home, "HOME") else "HOME");
        try closeRow(writer, col);
    }

    // Row 4: RY / dpad header / M1-M4
    {
        try writer.writeAll("│ RY:");
        try writer.print("{:>6}", .{gs.ry});
        try pad(writer, 11, CL);
        // ├─ DPad ───────┤ = CM+1 visible (┤ at CR_START), then 1 space
        try writer.writeAll("├─ DPad ───────┤ ");
        var col: usize = CR_START + 1;
        col += try btnLabel(writer, gs, .M1, if (ml) config.btnDisplayLabel(.M1, "M1") else "M1");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M2, if (ml) config.btnDisplayLabel(.M2, "M2") else "M2");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M3, if (ml) config.btnDisplayLabel(.M3, "M3") else "M3");
        try writer.writeAll(" ");
        col += 1;
        col += try btnLabel(writer, gs, .M4, if (ml) config.btnDisplayLabel(.M4, "M4") else "M4");
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
                col += try btnLabel(writer, gs, .C, if (ml) config.btnDisplayLabel(.C, "C") else "C");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_z) {
                col += try btnLabel(writer, gs, .Z, if (ml) config.btnDisplayLabel(.Z, "Z") else "Z");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_lm) {
                col += try btnLabel(writer, gs, .LM, if (ml) config.btnDisplayLabel(.LM, "LM") else "LM");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_rm) {
                col += try btnLabel(writer, gs, .RM, if (ml) config.btnDisplayLabel(.RM, "RM") else "RM");
                try writer.writeAll(" ");
                col += 1;
            }
            if (config.has_o) {
                col += try btnLabel(writer, gs, .O, if (ml) config.btnDisplayLabel(.O, "O") else "O");
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
    const show: usize = @min(raw.len, 16);
    for (raw[0..show]) |b| {
        try writer.print("{x:0>2} ", .{b});
    }
    try closeRow(writer, 2 + show * 3);

    if (raw.len > 16) {
        try writer.writeAll("│ ");
        const show2: usize = @min(raw.len - 16, 16);
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
    switch (view_mode) {
        .raw => try writer.writeAll(" [M]ode: RAW "),
        .mapped => try writer.writeAll(YELLOW ++ " [M]ode: MAPPED " ++ RESET),
    }
    var fi: usize = 37; // └(1) + rumble(22) + mode(14) = 37 visible
    // Show mapping file in mapped mode
    if (view_mode == .mapped) {
        if (config.output_info) |info| {
            if (info.mapping_file.len > 0) {
                const max_len = W - 2 - fi; // leave room for ┘
                if (max_len > 4) {
                    const show_len = @min(info.mapping_file.len, max_len - 1);
                    try writer.writeAll(DIM);
                    try writer.writeAll(info.mapping_file[0..show_len]);
                    try writer.writeAll(RESET);
                    fi += show_len;
                }
            }
        }
    }
    try writer.writeAll(BOLD ++ CYAN);
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
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config, .raw);
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
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "128") != null);
    try testing.expect(std.mem.indexOf(u8, out, "64") != null);
}

test "renderFrame: contains gyro values" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config, .raw);
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
    try renderFrame(fbs.writer(), &gs, &raw, false, .{}, .raw);
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
    try renderFrame(fbs.writer(), &gs, &raw, false, .{ .has_touchpad = true }, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Touchpad") != null);
    try testing.expect(std.mem.indexOf(u8, out, "500") != null);
}

test "renderFrame: contains raw hex bytes" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    try renderFrame(fbs.writer(), &gs, &raw, false, .{}, .raw);
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
    try renderFrame(fbs.writer(), &gs, &raw, true, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "ON") != null);
}

test "renderFrame: contains ANSI escape sequences" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{}, .raw);
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
    try renderFrame(fbs1.writer(), &gs_pressed, &raw, false, .{}, .raw);
    try renderFrame(fbs2.writer(), &gs_released, &raw, false, .{}, .raw);

    try testing.expect(!std.mem.eql(u8, fbs1.getWritten(), fbs2.getWritten()));
}

test "renderFrame: extended buttons shown when configured" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = GamepadState{};
    gs.buttons = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.C)));
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{ .has_c = true, .has_z = true }, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "[C]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[Z]") != null);
}
