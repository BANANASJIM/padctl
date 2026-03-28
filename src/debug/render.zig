const std = @import("std");
const mem = std.mem;
const state = @import("../core/state.zig");
const device_config = @import("../config/device.zig");

pub const GamepadState = state.GamepadState;
pub const ButtonId = state.ButtonId;
pub const DeviceConfig = device_config.DeviceConfig;

pub const KeyEvent = struct {
    button: ButtonId,
    pressed: bool,
    timestamp_ms: i64,
};

pub const Stats = struct {
    packets_total: u64 = 0,
    packets_per_sec: u32 = 0,
    last_sec_packets: u32 = 0,
    last_sec_time: i64 = 0,
    key_press_count: u64 = 0,
    last_events: [8]KeyEvent = undefined,
    event_write_pos: u8 = 0, // next write slot (0..7, wraps)
    event_total: u64 = 0,
    start_time: i64 = 0,

    pub fn init(now: i64) Stats {
        return .{ .last_sec_time = now, .start_time = now };
    }

    pub fn recordPacket(self: *Stats, now: i64) void {
        self.packets_total += 1;
        self.last_sec_packets += 1;
        const elapsed = now - self.last_sec_time;
        if (elapsed >= 1000) {
            self.packets_per_sec = @intCast(@as(u64, self.last_sec_packets) * 1000 / @as(u64, @intCast(elapsed)));
            self.last_sec_packets = 1; // current packet starts the new window
            self.last_sec_time = now;
        }
    }

    pub fn recordButtonChange(self: *Stats, button: ButtonId, pressed: bool, now: i64) void {
        if (pressed) self.key_press_count += 1;
        self.last_events[self.event_write_pos] = .{ .button = button, .pressed = pressed, .timestamp_ms = now };
        self.event_write_pos = (self.event_write_pos + 1) % 8;
        self.event_total += 1;
    }

    pub fn eventCount(self: *const Stats) u8 {
        return @intCast(@min(self.event_total, 8));
    }

    pub fn eventAt(self: *const Stats, i: u8) ?KeyEvent {
        const count = self.eventCount();
        if (i >= count) return null;
        // Most recent is at (write_pos - 1) % 8, i=0 means newest
        const slot = (self.event_write_pos -% 1 -% i) % 8;
        return self.last_events[slot];
    }
};

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
    return shortenEventCode(label);
}

pub fn shortenEventCode(label: []const u8) []const u8 {
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
        .{ "BTN_MIDDLE", "MM" },
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
        .{ "KEY_F1", "F1" },
        .{ "KEY_F2", "F2" },
        .{ "KEY_F3", "F3" },
        .{ "KEY_F4", "F4" },
        .{ "KEY_F5", "F5" },
        .{ "KEY_F6", "F6" },
        .{ "KEY_F7", "F7" },
        .{ "KEY_F8", "F8" },
        .{ "KEY_F9", "F9" },
        .{ "KEY_F10", "F10" },
        .{ "KEY_F11", "F11" },
        .{ "KEY_F12", "F12" },
        .{ "KEY_F13", "F13" },
        .{ "KEY_F14", "F14" },
    };
    inline for (map) |entry| {
        if (mem.eql(u8, label, entry[0])) return entry[1];
    }
    // BTN_TRIGGER_HAPPY10+ → "H10" etc.
    if (label.len > "BTN_TRIGGER_HAPPY".len and mem.eql(u8, label[0.."BTN_TRIGGER_HAPPY".len], "BTN_TRIGGER_HAPPY")) {
        const happy_table = comptime blk: {
            @setEvalBranchQuota(10000);
            var tbl: [41][]const u8 = undefined;
            for (0..41) |i| {
                tbl[i] = std.fmt.comptimePrint("H{d}", .{i});
            }
            break :blk tbl;
        };
        const num_str = label["BTN_TRIGGER_HAPPY".len..];
        const n = std.fmt.parseInt(u8, num_str, 10) catch return label[0..@min(label.len, 4)];
        if (n < happy_table.len) return happy_table[n];
    }
    // KEY_X → "X" (strip KEY_ prefix, max 4 chars)
    if (label.len > 4 and mem.eql(u8, label[0..4], "KEY_"))
        return label[4..@min(label.len, 8)];
    // BTN_ prefix: strip and take first 4 chars
    if (label.len > 4 and mem.eql(u8, label[0..4], "BTN_"))
        return label[4..@min(label.len, 8)];
    // Truncate anything else to 4 chars
    return label[0..@min(label.len, 4)];
}

pub const OutputCategory = enum { gamepad, keyboard, mouse };

pub fn categorizeEventCode(code: []const u8) OutputCategory {
    // Mouse buttons
    if (mem.eql(u8, code, "BTN_LEFT") or
        mem.eql(u8, code, "BTN_RIGHT") or
        mem.eql(u8, code, "BTN_MIDDLE") or
        mem.eql(u8, code, "mouse_left") or
        mem.eql(u8, code, "mouse_right") or
        mem.eql(u8, code, "mouse_middle") or
        mem.eql(u8, code, "BTN_SIDE") or
        mem.eql(u8, code, "BTN_EXTRA") or
        mem.eql(u8, code, "BTN_FORWARD") or
        mem.eql(u8, code, "BTN_BACK") or
        mem.eql(u8, code, "BTN_TASK") or
        mem.eql(u8, code, "mouse_side") or
        mem.eql(u8, code, "mouse_extra") or
        mem.eql(u8, code, "mouse_forward") or
        mem.eql(u8, code, "mouse_back")) return .mouse;
    // Keyboard
    if (code.len > 4 and mem.eql(u8, code[0..4], "KEY_")) return .keyboard;
    // Everything else is gamepad
    return .gamepad;
}

pub const MappedButton = struct {
    short_label: [8]u8 = .{0} ** 8,
    label_len: u8 = 0,
    btn_id: ButtonId,
    category: OutputCategory,

    pub fn getLabel(self: *const MappedButton) []const u8 {
        return self.short_label[0..self.label_len];
    }
};

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
    mapped_buttons: ?[]const MappedButton = null,
    stats: ?*const Stats = null,

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

    if (view_mode == .mapped) {
        try renderMappedMode(writer, gs, raw, rumble_on, config);
    } else {
        try renderRawMode(writer, gs, raw, rumble_on, config);
    }
}

fn renderRawMode(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
    config: RenderConfig,
) !void {
    try writer.writeAll(BOLD ++ CYAN ++
        "┌─ Sticks ──────────┬─ Triggers ───┬─ Buttons ───────────────────────┐\r\n" ++
        RESET);

    // Row 1: LX / LT bar / A B X Y
    {
        try writer.writeAll("│ LX:");
        try writer.print("{:>6}", .{gs.ax});
        try pad(writer, 11, CL);
        try writer.writeAll("│ LT ");
        try bar(writer, gs.lt, 9);
        try pad(writer, CL + 14, CL + CM);
        try writer.writeAll("│ ");
        var col: usize = CR_START + 2;
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
        try writer.writeAll("├─ DPad ───────┤ ");
        var col: usize = CR_START + 1;
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

    try renderTail(writer, gs, raw, rumble_on, config, .raw);
}

const RIGHT_INNER = W - CR_START - 2; // 33 usable chars in right column

fn renderMappedMode(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
    config: RenderConfig,
) !void {
    // Build right-column lines from mapped_buttons grouped by category
    // Each line: content for the right column (up to RIGHT_INNER visible chars)
    const max_right_lines = 16;
    var right_lines: [max_right_lines]RightLine = undefined;
    var right_count: usize = 0;

    if (config.mapped_buttons) |buttons| {
        // Count per category
        var gp_count: usize = 0;
        var kb_count: usize = 0;
        var ms_count: usize = 0;
        for (buttons) |mb| {
            switch (mb.category) {
                .gamepad => gp_count += 1,
                .keyboard => kb_count += 1,
                .mouse => ms_count += 1,
            }
        }

        // Gamepad section
        if (gp_count > 0) {
            if (right_count < max_right_lines) {
                right_lines[right_count] = .{ .kind = .header, .text = "Gamepad" };
                right_count += 1;
            }
            right_count = addButtonLines(&right_lines, right_count, max_right_lines, buttons, .gamepad);
        }

        // Keyboard section
        if (kb_count > 0) {
            if (right_count < max_right_lines) {
                right_lines[right_count] = .{ .kind = .header, .text = "Keyboard" };
                right_count += 1;
            }
            right_count = addButtonLines(&right_lines, right_count, max_right_lines, buttons, .keyboard);
        }

        // Mouse section
        if (ms_count > 0) {
            if (right_count < max_right_lines) {
                right_lines[right_count] = .{ .kind = .header, .text = "Mouse" };
                right_count += 1;
            }
            right_count = addButtonLines(&right_lines, right_count, max_right_lines, buttons, .mouse);
        }
    }

    // Header
    if (config.output_info) |info| {
        const prefix = "┌─ Output: ";
        const max_name = W - 4 - 11;
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
            "┌─ Sticks ──────────┬─ Triggers ───┬─ Mapped Outputs ────────────────┐\r\n" ++
            RESET);
    }

    // 7 main rows: LX, LY, RX, RY+dpad_header, dpad_up, dpad_lr, dpad_down
    // Each row has left+mid content, then right column from right_lines

    // Row 0: LX / LT bar
    try renderLeftMid(writer, gs, 0);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 0);

    // Row 1: LY / RT bar
    try renderLeftMid(writer, gs, 1);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 1);

    // Row 2: RX / LT:RT values
    try renderLeftMid(writer, gs, 2);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 2);

    // Row 3: RY / dpad header
    try renderLeftMid(writer, gs, 3);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 3);

    // Row 4: dpad up
    try renderLeftMid(writer, gs, 4);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 4);

    // Row 5: dpad left · right
    try renderLeftMid(writer, gs, 5);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 5);

    // Row 6: dpad down
    try renderLeftMid(writer, gs, 6);
    try renderRightCol(writer, gs, config, right_lines[0..right_count], 6);

    // Extra rows if right_count > 7
    var extra_row: usize = 7;
    while (extra_row < right_count) : (extra_row += 1) {
        // Empty left + mid
        try writer.writeAll("│");
        try pad(writer, 1, CL);
        try writer.writeAll("│");
        try pad(writer, CL + 1, CR_START);
        try renderRightCol(writer, gs, config, right_lines[0..right_count], extra_row);
    }

    try renderTail(writer, gs, raw, rumble_on, config, .mapped);
}

const RightLine = struct {
    kind: enum { header, buttons },
    text: []const u8 = "",
    // For buttons kind: indices into per-category list
    start: usize = 0,
    end: usize = 0,
    cat: OutputCategory = .gamepad,
};

fn addButtonLines(
    lines: []RightLine,
    count: usize,
    max: usize,
    buttons: []const MappedButton,
    cat: OutputCategory,
) usize {
    var c = count;

    // Collect indices of buttons in this category
    var indices: [64]usize = undefined;
    var n_indices: usize = 0;
    for (buttons, 0..) |mb, i| {
        if (mb.category == cat) {
            if (n_indices < indices.len) {
                indices[n_indices] = i;
                n_indices += 1;
            }
        }
    }

    var row_width: usize = 1; // leading space
    var btn_idx: usize = 0;
    var first_in_row: usize = 0;
    var items_in_row: usize = 0;

    while (btn_idx < n_indices) : (btn_idx += 1) {
        const mb = buttons[indices[btn_idx]];
        const needed = mb.label_len + 2 + 1; // [label] + space
        if (items_in_row > 0 and row_width + needed > RIGHT_INNER) {
            // Emit current row
            if (c < max) {
                lines[c] = .{ .kind = .buttons, .start = first_in_row, .end = btn_idx, .cat = cat };
                c += 1;
            }
            first_in_row = btn_idx;
            row_width = 1;
            items_in_row = 0;
        }
        row_width += needed;
        items_in_row += 1;
    }
    // Emit last row
    if (items_in_row > 0 and c < max) {
        lines[c] = .{ .kind = .buttons, .start = first_in_row, .end = n_indices, .cat = cat };
        c += 1;
    }

    return c;
}

fn renderLeftMid(writer: anytype, gs: *const GamepadState, row: usize) !void {
    switch (row) {
        0 => {
            try writer.writeAll("│ LX:");
            try writer.print("{:>6}", .{gs.ax});
            try pad(writer, 11, CL);
            try writer.writeAll("│ LT ");
            try bar(writer, gs.lt, 9);
            try pad(writer, CL + 14, CL + CM);
        },
        1 => {
            try writer.writeAll("│ LY:");
            try writer.print("{:>6}", .{gs.ay});
            try pad(writer, 11, CL);
            try writer.writeAll("│ RT ");
            try bar(writer, gs.rt, 9);
            try pad(writer, CL + 14, CL + CM);
        },
        2 => {
            try writer.writeAll("│ RX:");
            try writer.print("{:>6}", .{gs.rx});
            try pad(writer, 11, CL);
            try writer.writeAll("│LT:");
            try writer.print("{:>3}", .{gs.lt});
            try writer.writeAll(" RT:");
            try writer.print("{:>3}", .{gs.rt});
            try pad(writer, CL + 14, CL + CM);
        },
        3 => {
            try writer.writeAll("│ RY:");
            try writer.print("{:>6}", .{gs.ry});
            try pad(writer, 11, CL);
            try writer.writeAll("├─ DPad ───────");
        },
        4 => {
            try writer.writeAll("│");
            try pad(writer, 1, CL);
            try writer.writeAll("│      ");
            const up_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadUp)))) != 0;
            if (up_p) try writer.writeAll(GREEN ++ "↑" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
            try pad(writer, CL + 8, CR_START);
        },
        5 => {
            try writer.writeAll("│");
            try pad(writer, 1, CL);
            try writer.writeAll("│    ");
            const left_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadLeft)))) != 0;
            const right_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadRight)))) != 0;
            if (left_p) try writer.writeAll(GREEN ++ "←" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
            try writer.writeAll(" · ");
            if (right_p) try writer.writeAll(GREEN ++ "→" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
            try pad(writer, CL + 10, CR_START);
        },
        6 => {
            try writer.writeAll("│");
            try pad(writer, 1, CL);
            try writer.writeAll("│      ");
            const down_p = gs.buttons & (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadDown)))) != 0;
            if (down_p) try writer.writeAll(GREEN ++ "↓" ++ RESET) else try writer.writeAll(DIM ++ "·" ++ RESET);
            try pad(writer, CL + 8, CR_START);
        },
        else => {
            try writer.writeAll("│");
            try pad(writer, 1, CL);
            try writer.writeAll("│");
            try pad(writer, CL + 1, CR_START);
        },
    }
}

fn renderRightCol(
    writer: anytype,
    gs: *const GamepadState,
    config: RenderConfig,
    right_lines: []const RightLine,
    row: usize,
) !void {
    // Row 3 special: dpad header uses ┤ instead of │
    if (row == 3) {
        try writer.writeAll("┤ ");
    } else {
        try writer.writeAll("│ ");
    }

    if (row < right_lines.len) {
        const line = right_lines[row];
        switch (line.kind) {
            .header => {
                try writer.writeAll(BOLD ++ CYAN);
                try writer.writeAll(line.text);
                try writer.writeAll(RESET);
                try closeRow(writer, CR_START + 2 + line.text.len);
            },
            .buttons => {
                const buttons = config.mapped_buttons orelse {
                    try closeRow(writer, CR_START + 2);
                    return;
                };
                var indices: [64]usize = undefined;
                var n: usize = 0;
                for (buttons, 0..) |mb, i| {
                    if (mb.category == line.cat) {
                        if (n < indices.len) {
                            indices[n] = i;
                            n += 1;
                        }
                    }
                }

                var col: usize = CR_START + 2;
                const end = @min(line.end, n);
                for (indices[line.start..end]) |idx| {
                    const mb = buttons[idx];
                    col += try btnLabel(writer, gs, mb.btn_id, mb.getLabel());
                    try writer.writeAll(" ");
                    col += 1;
                }
                try closeRow(writer, col);
            },
        }
    } else {
        try closeRow(writer, CR_START + 2);
    }
}

fn renderTail(
    writer: anytype,
    gs: *const GamepadState,
    raw: []const u8,
    rumble_on: bool,
    config: RenderConfig,
    view_mode: ViewMode,
) !void {
    // Gyro (conditional)
    if (config.has_gyro) {
        try sectionHeader(writer, "Gyro");
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

    // Stats (optional)
    if (config.stats) |st| {
        try renderStats(writer, st);
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
    const stats_hint: []const u8 = if (config.stats != null) " [S] " else " ";
    try writer.writeAll(stats_hint);
    var fi: usize = 37 + stats_hint.len;
    if (view_mode == .mapped) {
        if (config.output_info) |info| {
            if (info.mapping_file.len > 0) {
                const max_len = W - 2 - fi;
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

fn renderStats(writer: anytype, st: *const Stats) !void {
    try sectionHeader(writer, "Stats");

    // Line 1: packets, keys, uptime
    const now = std.time.milliTimestamp();
    const uptime_s: u64 = @intCast(@max(0, @divTrunc(now - st.start_time, 1000)));
    const mins = uptime_s / 60;
    const secs = uptime_s % 60;

    try writer.writeAll("│ ");
    try writer.print("Packets: {d} ({d}/s)  Keys: {d}  Uptime: {d}m {d:0>2}s", .{
        st.packets_total, st.packets_per_sec, st.key_press_count, mins, secs,
    });
    const line1_est = 2 + 9 + digitCount(st.packets_total) + 2 + digitCount(st.packets_per_sec) + 11 + digitCount(st.key_press_count) + 10 + digitCount(mins) + 2 + 2 + 1;
    try closeRow(writer, line1_est);

    // Line 2: key history (most recent first)
    try writer.writeAll("│ History: ");
    var col: usize = 11;
    const show_count = st.eventCount();
    if (show_count == 0) {
        try writer.writeAll("(none)");
        col += 6;
    } else {
        var i: u8 = 0;
        while (i < show_count) : (i += 1) {
            if (st.eventAt(i)) |ev| {
                const arrow: []const u8 = if (ev.pressed) "+" else "-";
                const name = @tagName(ev.button);
                const age_ms: u64 = @intCast(@max(0, now - ev.timestamp_ms));
                const age_s = @as(f64, @floatFromInt(age_ms)) / 1000.0;
                if (col + name.len + 10 > W - 2) break;
                try writer.print("[{s}{s} {d:.1}s] ", .{ name, arrow, age_s });
                col += name.len + 1 + 1 + digitCountF(age_s) + 4;
            }
        }
    }
    try closeRow(writer, col);
}

fn digitCount(v: anytype) usize {
    if (v == 0) return 1;
    var n: usize = 0;
    var x: u64 = if (@typeInfo(@TypeOf(v)) == .int) @intCast(if (v < 0) @as(u64, @intCast(-v)) else @as(u64, @intCast(v))) else v;
    while (x > 0) : (x /= 10) n += 1;
    return n;
}

fn digitCountF(v: f64) usize {
    const int_part: u64 = @intFromFloat(@floor(v));
    return digitCount(int_part) + 2; // "N.N"
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

test "render: renderFrame: contains axis values" {
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

test "render: renderFrame: contains trigger values" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, default_config, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "128") != null);
    try testing.expect(std.mem.indexOf(u8, out, "64") != null);
}

test "render: renderFrame: contains gyro values" {
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

test "render: renderFrame: no gyro section when disabled" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Gyro") == null);
    try testing.expect(std.mem.indexOf(u8, out, "GX") == null);
}

test "render: renderFrame: touchpad section when enabled" {
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

test "render: renderFrame: contains raw hex bytes" {
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

test "render: renderFrame: rumble_on shows rumble indicator" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, true, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "ON") != null);
}

test "render: renderFrame: contains ANSI escape sequences" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};
    try renderFrame(fbs.writer(), &gs, &raw, false, .{}, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[") != null);
}

test "render: renderFrame: pressed button highlighted differently" {
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

test "render: renderFrame: extended buttons shown when configured" {
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

test "render: renderFrame: mapped mode shows grouped outputs" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = makeTestState();
    const raw = [_]u8{ 0x01, 0x02 };

    var mb1 = MappedButton{ .btn_id = .A, .category = .gamepad, .label_len = 1 };
    mb1.short_label[0] = 'S';
    var mb2 = MappedButton{ .btn_id = .M1, .category = .keyboard, .label_len = 3 };
    @memcpy(mb2.short_label[0..3], "F13");
    const mapped = [_]MappedButton{ mb1, mb2 };

    var cfg = RenderConfig{
        .output_info = .{ .name = "Test Pad" },
        .mapped_buttons = &mapped,
    };
    _ = &cfg;

    try renderFrame(fbs.writer(), &gs, &raw, false, cfg, .mapped);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Gamepad") != null);
    try testing.expect(std.mem.indexOf(u8, out, "Keyboard") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[S]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[F13]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "Test Pad") != null);
}

test "render: shortenEventCode: known codes" {
    try testing.expectEqualStrings("S", shortenEventCode("BTN_SOUTH"));
    try testing.expectEqualStrings("HM", shortenEventCode("BTN_MODE"));
    try testing.expectEqualStrings("H1", shortenEventCode("BTN_TRIGGER_HAPPY1"));
    try testing.expectEqualStrings("F13", shortenEventCode("KEY_F13"));
    try testing.expectEqualStrings("SPC", shortenEventCode("KEY_SPACE"));
    try testing.expectEqualStrings("ML", shortenEventCode("BTN_LEFT"));
    try testing.expectEqualStrings("MM", shortenEventCode("BTN_MIDDLE"));
}

test "render: categorizeEventCode: categories" {
    try testing.expectEqual(OutputCategory.gamepad, categorizeEventCode("BTN_SOUTH"));
    try testing.expectEqual(OutputCategory.keyboard, categorizeEventCode("KEY_F13"));
    try testing.expectEqual(OutputCategory.mouse, categorizeEventCode("BTN_LEFT"));
    try testing.expectEqual(OutputCategory.mouse, categorizeEventCode("mouse_left"));
    try testing.expectEqual(OutputCategory.gamepad, categorizeEventCode("BTN_TRIGGER_HAPPY1"));
}

test "render: Stats: packet counting and per-second rate" {
    var st = Stats.init(1000);
    st.recordPacket(1000);
    st.recordPacket(1100);
    st.recordPacket(1200);
    try testing.expectEqual(@as(u64, 3), st.packets_total);
    try testing.expectEqual(@as(u32, 0), st.packets_per_sec); // no second elapsed yet

    // Simulate 1 second boundary
    st.recordPacket(2000);
    try testing.expectEqual(@as(u64, 4), st.packets_total);
    try testing.expect(st.packets_per_sec > 0);
}

test "render: Stats: button change tracking and ring buffer" {
    var st = Stats.init(0);
    st.recordButtonChange(.A, true, 100);
    try testing.expectEqual(@as(u64, 1), st.key_press_count);
    try testing.expectEqual(@as(u64, 1), st.event_total);

    // Release does not increment key_press_count
    st.recordButtonChange(.A, false, 200);
    try testing.expectEqual(@as(u64, 1), st.key_press_count);
    try testing.expectEqual(@as(u64, 2), st.event_total);

    // Most recent event first
    const ev0 = st.eventAt(0).?;
    try testing.expectEqual(ButtonId.A, ev0.button);
    try testing.expectEqual(false, ev0.pressed);

    const ev1 = st.eventAt(1).?;
    try testing.expectEqual(true, ev1.pressed);
}

test "render: Stats: ring buffer wraps at 8" {
    var st = Stats.init(0);
    // Fill 10 events, ring buffer holds last 8
    for (0..10) |i| {
        st.recordButtonChange(.B, true, @intCast(i * 100));
    }
    try testing.expectEqual(@as(u64, 10), st.key_press_count);
    try testing.expectEqual(@as(u64, 10), st.event_total);

    // eventAt(0) = most recent (i=9, timestamp=900)
    const newest = st.eventAt(0).?;
    try testing.expectEqual(@as(i64, 900), newest.timestamp_ms);

    // eventAt(7) = oldest kept (i=2, timestamp=200)
    const oldest = st.eventAt(7).?;
    try testing.expectEqual(@as(i64, 200), oldest.timestamp_ms);

    // eventAt(8) = out of range
    try testing.expectEqual(@as(?KeyEvent, null), st.eventAt(8));
}

test "render: renderStats: produces Stats section with data" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    const raw = [_]u8{};

    var st = Stats.init(std.time.milliTimestamp() - 5000);
    st.packets_total = 300;
    st.packets_per_sec = 60;
    st.recordButtonChange(.A, true, std.time.milliTimestamp() - 100);
    st.key_press_count = 12;

    const cfg = RenderConfig{ .stats = &st };
    try renderFrame(fbs.writer(), &gs, &raw, false, cfg, .raw);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "Stats") != null);
    try testing.expect(std.mem.indexOf(u8, out, "300") != null);
    try testing.expect(std.mem.indexOf(u8, out, "60/s") != null);
    try testing.expect(std.mem.indexOf(u8, out, "12") != null);
    try testing.expect(std.mem.indexOf(u8, out, "History") != null);
}
