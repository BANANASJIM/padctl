const std = @import("std");
const toml = @import("toml");
const mapping = @import("../config/mapping.zig");
const state = @import("state.zig");
const layer = @import("layer.zig");
const gyro = @import("gyro.zig");
const stick = @import("stick.zig");
const macro_player_mod = @import("macro_player.zig");
const timer_queue_mod = @import("timer_queue.zig");
const aux_event_mod = @import("aux_event.zig");

pub const RemapTargetResolved = @import("remap.zig").RemapTargetResolved;
pub const resolveTarget = @import("remap.zig").resolveTarget;
pub const AuxEvent = aux_event_mod.AuxEvent;
pub const AuxEventList = aux_event_mod.AuxEventList;
pub const TimerRequest = @import("timer_request.zig").TimerRequest;

const MacroPlayer = macro_player_mod.MacroPlayer;
const TimerQueue = timer_queue_mod.TimerQueue;

const GamepadState = state.GamepadState;
const GamepadStateDelta = state.GamepadStateDelta;
const ButtonId = state.ButtonId;
const LayerState = layer.LayerState;
const MappingConfig = mapping.MappingConfig;
const LayerConfig = mapping.LayerConfig;

pub const OutputEvents = struct {
    gamepad: GamepadState,
    prev: GamepadState,
    aux: AuxEventList,
    timer_request: ?TimerRequest = null,
};

pub const Mapper = struct {
    config: *const MappingConfig,
    layer: LayerState,
    state: GamepadState,
    prev: GamepadState,
    gyro_proc: gyro.GyroProcessor,
    stick_left: stick.StickProcessor,
    stick_right: stick.StickProcessor,
    suppressed_buttons: u32,
    injected_buttons: u32,
    pending_tap_release: ?u32,
    timer_fd: std.posix.fd_t,
    allocator: std.mem.Allocator,
    active_macros: std.ArrayList(MacroPlayer),
    timer_queue: TimerQueue,
    next_token: u32,

    pub fn init(config: *const MappingConfig, timer_fd: std.posix.fd_t, allocator: std.mem.Allocator) !Mapper {
        return .{
            .config = config,
            .layer = LayerState.init(allocator),
            .state = .{},
            .prev = .{},
            .gyro_proc = .{},
            .stick_left = .{},
            .stick_right = .{},
            .suppressed_buttons = 0,
            .injected_buttons = 0,
            .pending_tap_release = null,
            .timer_fd = timer_fd,
            .allocator = allocator,
            .active_macros = .{},
            .timer_queue = TimerQueue.init(allocator, timer_fd),
            .next_token = 1,
        };
    }

    pub fn deinit(self: *Mapper) void {
        self.layer.deinit();
        self.active_macros.deinit(self.allocator);
        self.timer_queue.deinit();
    }

    pub fn apply(self: *Mapper, delta: GamepadStateDelta, dt_ms: u32) !OutputEvents {
        // flush pending tap release from previous frame
        var aux = AuxEventList{};
        if (self.pending_tap_release) |mask| {
            self.injected_buttons &= ~mask;
            self.pending_tap_release = null;
            // inject release into emit state at end of this frame
        }

        // [1] merge delta into current state
        self.state.applyDelta(delta);

        // [2] layer trigger processing
        const configs = self.config.layer orelse &.{};
        const action = self.layer.processLayerTriggers(configs, self.state.buttons, self.prev.buttons);
        var timer_request: ?TimerRequest = null;
        if (action.arm_timer_ms) |ms| {
            timer_request = .{ .arm = @intCast(ms) };
        } else if (action.disarm_timer) {
            timer_request = .{ .disarm = {} };
        }
        if (action.active_changed) {
            self.gyro_proc.reset();
            self.stick_left.reset();
            self.stick_right.reset();
            // Cancel in-flight macros; emit releases for any held keys.
            for (self.active_macros.items) |*p| p.emitPendingReleases(&aux);
            self.active_macros.clearRetainingCapacity();
        }

        // reset accumulators
        self.suppressed_buttons = 0;
        self.injected_buttons = 0;

        // per-source inject map: null = not mapped, Some = last-write target
        const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;
        var per_src_inject: [BUTTON_COUNT]?RemapTargetResolved = [_]?RemapTargetResolved{null} ** BUTTON_COUNT;

        // [3] mode processing
        var suppress_dpad_hat: bool = false;
        var suppress_right_stick_gyro: bool = false;
        var gyro_joy_x: ?i16 = null;
        var gyro_joy_y: ?i16 = null;
        {
            const gcfg = self.effectiveGyroConfig();
            const activate_spec = blk: {
                if (self.layer.getActive(self.config.layer orelse &.{})) |active| {
                    if (active.gyro) |g| break :blk g.activate;
                }
                break :blk if (self.config.gyro) |g| g.activate else null;
            };
            if (checkGyroActivate(activate_spec, self.state.buttons)) {
                const gout = self.gyro_proc.process(&gcfg, self.state.gyro_x, self.state.gyro_y, self.state.gyro_z);
                if (std.mem.eql(u8, gcfg.mode, "mouse")) {
                    if (gout.rel_x != 0) aux.append(.{ .rel = .{ .code = 0, .value = gout.rel_x } }) catch {};
                    if (gout.rel_y != 0) aux.append(.{ .rel = .{ .code = 1, .value = gout.rel_y } }) catch {};
                } else if (std.mem.eql(u8, gcfg.mode, "joystick")) {
                    if (gout.joy_x) |jx| {
                        gyro_joy_x = jx;
                        suppress_right_stick_gyro = true;
                    }
                    if (gout.joy_y) |jy| {
                        gyro_joy_y = jy;
                        suppress_right_stick_gyro = true;
                    }
                }
            } else {
                self.gyro_proc.reset();
            }

            const left_cfg = self.effectiveStickConfig(.left);
            const left_out = self.stick_left.process(&left_cfg, self.state.ax, self.state.ay, dt_ms);
            if (std.mem.eql(u8, left_cfg.mode, "mouse")) {
                if (left_out.rel_x != 0) aux.append(.{ .rel = .{ .code = 0, .value = left_out.rel_x } }) catch {};
                if (left_out.rel_y != 0) aux.append(.{ .rel = .{ .code = 1, .value = left_out.rel_y } }) catch {};
            } else if (std.mem.eql(u8, left_cfg.mode, "scroll")) {
                if (left_out.wheel != 0) aux.append(.{ .rel = .{ .code = 8, .value = left_out.wheel } }) catch {};
            }

            const right_cfg = self.effectiveStickConfig(.right);
            const right_out = self.stick_right.process(&right_cfg, self.state.rx, self.state.ry, dt_ms);
            if (std.mem.eql(u8, right_cfg.mode, "mouse")) {
                if (right_out.rel_x != 0) aux.append(.{ .rel = .{ .code = 0, .value = right_out.rel_x } }) catch {};
                if (right_out.rel_y != 0) aux.append(.{ .rel = .{ .code = 1, .value = right_out.rel_y } }) catch {};
            } else if (std.mem.eql(u8, right_cfg.mode, "scroll")) {
                if (right_out.wheel != 0) aux.append(.{ .rel = .{ .code = 8, .value = right_out.wheel } }) catch {};
            }

            const dpad_cfg = self.effectiveDpadConfig();
            @import("dpad.zig").processDpad(
                self.state.dpad_x,
                self.state.dpad_y,
                self.prev.dpad_x,
                self.prev.dpad_y,
                &dpad_cfg,
                &aux,
                &self.suppressed_buttons,
                &suppress_dpad_hat,
            );
        }

        // [4] base remap: collect suppress mask + per-source inject targets
        if (self.config.remap) |remap_map| {
            collectRemapMap(remap_map, &self.suppressed_buttons, &per_src_inject);
        }

        // [5] layer remap: OR-accumulate suppress, last-write-wins for inject
        if (self.layer.getActive(configs)) |active| {
            if (active.remap) |layer_remap| {
                collectRemapMap(layer_remap, &self.suppressed_buttons, &per_src_inject);
            }
        }

        // [6] build aux + injected_buttons from per_src_inject
        for (0..BUTTON_COUNT) |i| {
            const target = per_src_inject[i] orelse continue;
            const src_mask: u32 = @as(u32, 1) << @as(u5, @intCast(i));
            const pressed = (self.state.buttons & src_mask) != 0;
            const prev_pressed = (self.prev.buttons & src_mask) != 0;
            switch (target) {
                .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = pressed } }) catch {},
                .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = pressed } }) catch {},
                .gamepad_button => |dst| {
                    if (pressed) {
                        const dst_idx: u5 = @intCast(@intFromEnum(dst));
                        self.injected_buttons |= @as(u32, 1) << dst_idx;
                    }
                },
                .disabled => {},
                .macro => |name| {
                    // Trigger macro on rising edge only.
                    if (pressed and !prev_pressed) {
                        if (self.findMacro(name)) |m| {
                            const token = self.next_token;
                            self.next_token +%= 1;
                            const player = MacroPlayer.init(m, token);
                            self.active_macros.append(self.allocator, player) catch {};
                        }
                    }
                },
            }
        }

        // emit tap event if any
        if (action.tap_event) |tap| {
            emitTapEvent(tap, &aux, &self.injected_buttons, &self.pending_tap_release);
        }

        // [8] resume all active macro players; remove finished ones
        var i: usize = 0;
        while (i < self.active_macros.items.len) {
            const done = self.active_macros.items[i].step(&aux, &self.timer_queue) catch false;
            if (done) {
                _ = self.active_macros.swapRemove(i);
            } else {
                i += 1;
            }
        }

        // assemble emit state
        var emit_state = self.state;
        emit_state.buttons = (self.state.buttons & ~self.suppressed_buttons) | self.injected_buttons;
        if (suppress_dpad_hat) {
            emit_state.dpad_x = 0;
            emit_state.dpad_y = 0;
        }

        // gyro joystick mode: override right stick axes, suppress originals
        if (suppress_right_stick_gyro) {
            if (gyro_joy_x) |jx| emit_state.rx = jx;
            if (gyro_joy_y) |jy| emit_state.ry = jy;
        }

        // suppress stick axes when mode != gamepad
        const left_cfg = self.effectiveStickConfig(.left);
        const right_cfg = self.effectiveStickConfig(.right);
        if (left_cfg.suppress_gamepad or !std.mem.eql(u8, left_cfg.mode, "gamepad")) {
            emit_state.ax = 0;
            emit_state.ay = 0;
        }
        if (!suppress_right_stick_gyro and (right_cfg.suppress_gamepad or !std.mem.eql(u8, right_cfg.mode, "gamepad"))) {
            emit_state.rx = 0;
            emit_state.ry = 0;
        }

        // [7] prev-frame masking: same masks applied to prev before diff
        var masked_prev = self.prev;
        masked_prev.buttons = (self.prev.buttons & ~self.suppressed_buttons) | self.injected_buttons;
        if (suppress_dpad_hat) {
            masked_prev.dpad_x = 0;
            masked_prev.dpad_y = 0;
        }

        self.prev = self.state;

        return .{ .gamepad = emit_state, .prev = masked_prev, .aux = aux, .timer_request = timer_request };
    }

    pub fn onTimerExpired(self: *Mapper) AuxEventList {
        _ = self.layer.onTimerExpired();

        var aux = AuxEventList{};
        var buf: [16]timer_queue_mod.Deadline = undefined;
        const expired = self.timer_queue.drainExpired(std.time.nanoTimestamp(), &buf);
        for (expired) |d| {
            var idx: usize = 0;
            while (idx < self.active_macros.items.len) {
                if (self.active_macros.items[idx].timer_token == d.token) {
                    const done = self.active_macros.items[idx].step(&aux, &self.timer_queue) catch false;
                    if (done) {
                        _ = self.active_macros.swapRemove(idx);
                    } else {
                        idx += 1;
                    }
                    break;
                }
                idx += 1;
            }
        }
        return aux;
    }

    fn findMacro(self: *const Mapper, name: []const u8) ?*const mapping.Macro {
        const macros = self.config.macro orelse return null;
        for (macros) |*m| {
            if (std.mem.eql(u8, m.name, name)) return m;
        }
        return null;
    }

    fn effectiveGyroConfig(self: *const Mapper) gyro.GyroConfig {
        const configs = self.config.layer orelse &.{};
        if (self.layer.getActive(configs)) |active| {
            if (active.gyro) |g| return resolveGyroConfig2(&g);
        }
        return resolveGyroConfig(self.config);
    }

    fn effectiveDpadConfig(self: *const Mapper) mapping.DpadConfig {
        const configs = self.config.layer orelse &.{};
        if (self.layer.getActive(configs)) |active| {
            if (active.dpad) |d| return d;
        }
        return self.config.dpad orelse mapping.DpadConfig{};
    }

    const StickSide = enum { left, right };

    fn effectiveStickConfig(self: *const Mapper, side: StickSide) stick.StickConfig {
        const configs = self.config.layer orelse &.{};
        if (self.layer.getActive(configs)) |active| {
            const layer_sc = switch (side) {
                .left => active.stick_left,
                .right => active.stick_right,
            };
            if (layer_sc) |sc| return resolveStickConfig(&sc);
        }
        const base_pair = self.config.stick orelse return stick.StickConfig{};
        const base_sc = switch (side) {
            .left => base_pair.left,
            .right => base_pair.right,
        };
        return if (base_sc) |sc| resolveStickConfig(&sc) else stick.StickConfig{};
    }
};

fn resolveGyroConfig(config: *const MappingConfig) gyro.GyroConfig {
    const mc = config.gyro orelse return .{};
    return resolveGyroConfig2(&mc);
}

fn resolveGyroConfig2(mc: *const mapping.GyroConfig) gyro.GyroConfig {
    return .{
        .mode = mc.mode,
        .sensitivity_x = if (mc.sensitivity_x) |v| @floatCast(v) else if (mc.sensitivity) |v| @floatCast(v) else 1.5,
        .sensitivity_y = if (mc.sensitivity_y) |v| @floatCast(v) else if (mc.sensitivity) |v| @floatCast(v) else 1.5,
        .deadzone = if (mc.deadzone) |v| @intCast(v) else 0,
        .smoothing = if (mc.smoothing) |v| @floatCast(v) else 0.3,
        .curve = if (mc.curve) |v| @floatCast(v) else 1.0,
        .invert_x = mc.invert_x orelse false,
        .invert_y = mc.invert_y orelse false,
    };
}

fn resolveStickConfig(mc: *const mapping.StickConfig) stick.StickConfig {
    return .{
        .mode = mc.mode,
        .deadzone = if (mc.deadzone) |v| @intCast(v) else 128,
        .sensitivity = if (mc.sensitivity) |v| @floatCast(v) else 1.0,
        .suppress_gamepad = mc.suppress_gamepad orelse false,
    };
}

fn collectRemapMap(
    remap_map: toml.HashMap([]const u8),
    suppressed: *u32,
    per_src_inject: []?RemapTargetResolved,
) void {
    var it = remap_map.map.iterator();
    while (it.next()) |entry| {
        const src_id = std.meta.stringToEnum(ButtonId, entry.key_ptr.*) orelse continue;
        const src_idx: u5 = @intCast(@intFromEnum(src_id));
        suppressed.* |= @as(u32, 1) << src_idx;
        const target = resolveTarget(entry.value_ptr.*) catch continue;
        per_src_inject[@intCast(src_idx)] = target;
    }
}

fn emitTapEvent(
    target: RemapTargetResolved,
    aux: *AuxEventList,
    injected_buttons: *u32,
    pending_tap_release: *?u32,
) void {
    switch (target) {
        .key => |code| {
            aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {};
            aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
        },
        .mouse_button => |code| {
            aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch {};
            aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {};
        },
        .gamepad_button => |dst| {
            const dst_idx: u5 = @intCast(@intFromEnum(dst));
            const mask: u32 = @as(u32, 1) << dst_idx;
            injected_buttons.* |= mask;
            pending_tap_release.* = mask;
        },
        .disabled, .macro => {},
    }
}

fn buttonBit(name: []const u8) u32 {
    const id = std.meta.stringToEnum(ButtonId, name) orelse return 0;
    return @as(u32, 1) << @as(u5, @intCast(@intFromEnum(id)));
}

fn checkGyroActivate(activate: ?[]const u8, buttons: u32) bool {
    const spec = activate orelse return true;
    if (std.mem.startsWith(u8, spec, "hold_")) {
        const btn_name = spec["hold_".len..];
        return buttons & buttonBit(btn_name) != 0;
    }
    return true; // "always" or unrecognized
}

// --- tests ---

const testing = std.testing;

fn makeMapping(toml_str: []const u8, allocator: std.mem.Allocator) !mapping.ParseResult {
    return mapping.parseString(allocator, toml_str);
}

fn makeMapper(cfg: *const MappingConfig, allocator: std.mem.Allocator) !Mapper {
    // Use -1 as a dummy fd for tests (timer operations are no-ops on invalid fd)
    return Mapper.init(cfg, std.posix.STDIN_FILENO, allocator);
}

test "no layer no remap: apply passes through unchanged" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << a_idx)) != 0);
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "base remap disabled: source button suppressed" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);
    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << a_idx));
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "base remap key: source -> KEY_F13 aux event" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\M1 = "KEY_F13"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const m1_idx: u5 = @intCast(@intFromEnum(ButtonId.M1));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << m1_idx }, 16);

    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << m1_idx));
    try testing.expectEqual(@as(usize, 1), events.aux.len);
    switch (events.aux.get(0)) {
        .key => |k| {
            try testing.expectEqual(@as(u16, 183), k.code); // KEY_F13
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "base remap gamepad_button: A -> B" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);

    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << a_idx));
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << b_idx)) != 0);
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "layer remap overrides base: base A->B, layer A->C" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "X"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Activate hold layer by simulating PENDING → ACTIVE manually
    const configs = parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    const x_idx: u5 = @intCast(@intFromEnum(ButtonId.X));

    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);

    // A suppressed
    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << a_idx));
    // B not injected (overridden by layer)
    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << b_idx));
    // X injected (layer remap wins)
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << x_idx)) != 0);
}

test "suppress accumulates: base suppress A + layer suppress B" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "disabled"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\B = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const configs = parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    const both = (@as(u32, 1) << a_idx) | (@as(u32, 1) << b_idx);
    const events = try m.apply(.{ .buttons = both }, 16);

    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << a_idx));
    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << b_idx));
}

test "inject last-write wins: layer inject overrides base inject for same button" {
    const allocator = testing.allocator;
    // base: A->X, layer: A->Y — layer's inject for A's target wins
    const parsed = try makeMapping(
        \\[remap]
        \\A = "X"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "Y"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const configs = parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const x_idx: u5 = @intCast(@intFromEnum(ButtonId.X));
    const y_idx: u5 = @intCast(@intFromEnum(ButtonId.Y));

    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);

    try testing.expectEqual(@as(u32, 0), events.gamepad.buttons & (@as(u32, 1) << x_idx));
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << y_idx)) != 0);
}

test "prev frame masking: suppress produces correct diff" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u32 = @as(u32, 1) << a_idx;

    // Frame N-1: A pressed, remap disabled
    const ev1 = try m.apply(.{ .buttons = a_mask }, 16);
    // A is suppressed in output, prev is now raw a_mask
    try testing.expectEqual(@as(u32, 0), ev1.gamepad.buttons & a_mask);

    // Frame N: A still pressed — should produce no change (both masked_prev and gamepad have A=0)
    const ev2 = try m.apply(.{ .buttons = a_mask }, 16);
    try testing.expectEqual(@as(u32, 0), ev2.gamepad.buttons & a_mask);
    // masked_prev should also have A=0 (same suppress applied)
    try testing.expectEqual(@as(u32, 0), ev2.prev.buttons & a_mask);
}

test "onTimerExpired: PENDING -> ACTIVE activates layer" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\A = "B"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const configs = parsed.value.layer.?;
    // Press LT — goes PENDING
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // Timer fires — goes ACTIVE
    _ = m.onTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Now layer remap should be active
    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx }, 16);
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << b_idx)) != 0);
}

test "layer gyro override: active layer gyro config used" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "off"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.gyro]
        \\mode = "mouse"
        \\sensitivity = 100.0
        \\smoothing = 0.0
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const configs = parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    // With layer active, gyro should be in mouse mode
    const gcfg = m.effectiveGyroConfig();
    try testing.expectEqualStrings("mouse", gcfg.mode);
}

test "layer dpad override: active layer dpad config used" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[dpad]
        \\mode = "gamepad"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const configs = parsed.value.layer.?;
    _ = m.layer.onTriggerPress(configs[0].name, 200);
    _ = m.layer.onTimerExpired();

    const dcfg = m.effectiveDpadConfig();
    try testing.expectEqualStrings("arrows", dcfg.mode);
    try testing.expectEqual(@as(?bool, true), dcfg.suppress_gamepad);
}

test "gamepad_button tap: injected this frame, released next frame" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "A"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u5 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u32 = @as(u32, 1) << lt_idx;
    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u32 = @as(u32, 1) << a_idx;

    // Press LT -> PENDING
    _ = try m.apply(.{ .buttons = lt_mask }, 16);
    // Release LT -> tap fires (PENDING->IDLE with tap)
    const ev_tap = try m.apply(.{ .buttons = 0 }, 16);
    // A should be injected this frame
    try testing.expect((ev_tap.gamepad.buttons & a_mask) != 0);
    try testing.expect(m.pending_tap_release != null);

    // Next frame: pending_tap_release should clear A
    const ev_release = try m.apply(.{}, 16);
    try testing.expectEqual(@as(u32, 0), ev_release.gamepad.buttons & a_mask);
    try testing.expect(m.pending_tap_release == null);
}

test "dt_ms propagation: stick mouse output scales with dt" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[stick.right]
        \\mode = "mouse"
        \\deadzone = 0
        \\sensitivity = 100.0
    , allocator);
    defer parsed.deinit();

    // m4: 4 frames at dt=4ms (total elapsed = 16ms)
    // m16: 1 frame at dt=16ms (total elapsed = 16ms)
    // Both should produce the same total REL displacement.
    var m4 = try makeMapper(&parsed.value, allocator);
    defer m4.deinit();
    var m16 = try makeMapper(&parsed.value, allocator);
    defer m16.deinit();

    var total4: i32 = 0;
    for (0..4) |_| {
        const ev = try m4.apply(.{ .rx = 10000 }, 4);
        for (ev.aux.slice()) |e| switch (e) {
            .rel => |r| if (r.code == 0) {
                total4 += r.value;
            },
            else => {},
        };
    }

    var total16: i32 = 0;
    const ev16 = try m16.apply(.{ .rx = 10000 }, 16);
    for (ev16.aux.slice()) |e| switch (e) {
        .rel => |r| if (r.code == 0) {
            total16 += r.value;
        },
        else => {},
    };

    // 4 frames × dt=4 ≡ 1 frame × dt=16 in total motion budget
    const diff = @abs(total4 - total16);
    try testing.expect(diff <= 2);
}

test "dpad prev mask: suppress_dpad_hat applied to masked_prev" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[dpad]
        \\mode = "arrows"
        \\suppress_gamepad = true
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Frame 1: dpad up
    const ev1 = try m.apply(.{ .dpad_x = 0, .dpad_y = -1 }, 16);
    try testing.expectEqual(@as(i8, 0), ev1.gamepad.dpad_y);

    // Frame 2: same dpad — masked_prev should also have dpad_y = 0
    const ev2 = try m.apply(.{ .dpad_x = 0, .dpad_y = -1 }, 16);
    try testing.expectEqual(@as(i8, 0), ev2.prev.dpad_y);
}

test "checkGyroActivate: null always true" {
    try testing.expect(checkGyroActivate(null, 0));
    try testing.expect(checkGyroActivate(null, 0xFFFFFFFF));
}

test "checkGyroActivate: always always true" {
    try testing.expect(checkGyroActivate("always", 0));
}

test "checkGyroActivate: hold_RB pressed" {
    const rb_idx: u5 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u32 = @as(u32, 1) << rb_idx;
    try testing.expect(checkGyroActivate("hold_RB", rb_mask));
}

test "checkGyroActivate: hold_RB not pressed" {
    try testing.expect(!checkGyroActivate("hold_RB", 0));
}

test "checkGyroActivate: unknown button name returns false" {
    try testing.expect(!checkGyroActivate("hold_UNKNOWN", 0xFFFFFFFF));
}

test "gyro activate: inactive frame no REL events and processor reset" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "hold_RB"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Seed EMA with large gyro input while RB is held
    const rb_idx: u5 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u32 = @as(u32, 1) << rb_idx;
    _ = try m.apply(.{ .buttons = rb_mask, .gyro_x = 10000, .gyro_y = 10000 }, 16);

    // Release RB — gyro should be deactivated, processor reset, no REL events
    const ev = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16);
    try testing.expectEqual(@as(usize, 0), ev.aux.len);
    // After reset, EMA should be zero
    try testing.expectApproxEqAbs(@as(f32, 0.0), m.gyro_proc.ema_x, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), m.gyro_proc.ema_y, 1e-5);
}

test "gyro activate: active when RB held, inactive when released" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "hold_RB"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const rb_idx: u5 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u32 = @as(u32, 1) << rb_idx;

    // RB held, large gyro — should produce REL events
    const ev_active = try m.apply(.{ .buttons = rb_mask, .gyro_x = 10000, .gyro_y = 10000 }, 16);
    try testing.expect(ev_active.aux.len > 0);

    // RB released — no REL events
    const ev_inactive = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16);
    try testing.expectEqual(@as(usize, 0), ev_inactive.aux.len);
}

test "gyro joystick mode: overrides emit_state.rx/ry, suppresses original axes" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1000.0
        \\sensitivity_y = 1000.0
        \\smoothing = 0.0
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Feed large gyro input so joy_x/joy_y are non-zero
    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 5000, .ry = 5000 }, 16);

    // rx/ry must be gyro-derived (not the raw 5000)
    try testing.expect(ev.gamepad.rx != 5000);
    try testing.expect(ev.gamepad.ry != 5000);
    // No aux REL events from gyro (joystick mode emits no mouse events)
    for (ev.aux.slice()) |e| {
        switch (e) {
            .rel => return error.UnexpectedRelEvent,
            else => {},
        }
    }
}

test "gyro joystick mode: null joy_x does not touch rx" {
    const allocator = testing.allocator;
    // mode=off → process() returns joy_x=null, joy_y=null
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "off"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const ev = try m.apply(.{ .rx = 1234, .ry = -1234 }, 16);
    // mode=off: no override, axes pass through unchanged
    try testing.expectEqual(@as(i16, 1234), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, -1234), ev.gamepad.ry);
}

test "gyro mouse mode: joy_x/y do not affect emit_state axes" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity_x = 1000.0
        \\sensitivity_y = 1000.0
        \\smoothing = 0.0
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 999, .ry = 888 }, 16);
    // mouse mode: rx/ry must be untouched (suppress_right_stick_gyro stays false)
    try testing.expectEqual(@as(i16, 999), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, 888), ev.gamepad.ry);
}

test "T7: layer switch resets gyro EMA and accumulators" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.gyro]
        \\mode = "mouse"
        \\sensitivity = 100.0
        \\smoothing = 0.5
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Accumulate EMA state via gyro input frames (base layer, mode=off → no output but EMA still runs if mode matched)
    // Directly set dirty processor state to simulate residual EMA
    m.gyro_proc.ema_x = 500.0;
    m.gyro_proc.ema_y = -300.0;
    m.gyro_proc.accum_x = 0.7;
    m.gyro_proc.accum_y = -0.4;

    // Trigger layer activation: LT press → PENDING
    const lt_idx: u5 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u32 = @as(u32, 1) << lt_idx;
    _ = try m.apply(.{ .buttons = lt_mask }, 16);

    // Timer fires → ACTIVE (active_changed = true inside onTimerExpired, but processLayerTriggers
    // sets active_changed on press too — here we drive it through the full path)
    _ = m.onTimerExpired();
    // Manually trigger a frame that will see active_changed via release
    // Instead: drive through processLayerTriggers which sets active_changed on ACTIVE→IDLE release
    // For simplicity: re-dirty the processor and then release LT to deactivate
    m.gyro_proc.ema_x = 500.0;
    m.gyro_proc.accum_x = 0.7;
    m.stick_left.mouse_accum_x = 1.5;
    m.stick_right.scroll_accum = 0.9;

    // LT release → layer deactivates → active_changed = true → reset fires
    _ = try m.apply(.{ .buttons = 0 }, 16);

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0), m.gyro_proc.accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_left.mouse_accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_right.scroll_accum);
}

test "T7: no layer switch — processor state preserved" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    m.gyro_proc.ema_x = 42.0;
    m.stick_left.mouse_accum_x = 0.6;

    _ = try m.apply(.{}, 16);

    // No layer change: state must not be reset
    try testing.expectEqual(@as(f32, 42.0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0.6), m.stick_left.mouse_accum_x);
}

test "T7: toggle layer switch resets processors" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const sel_idx: u5 = @intCast(@intFromEnum(ButtonId.Select));
    const sel_mask: u32 = @as(u32, 1) << sel_idx;

    // Frame 1: Select pressed (rising edge only, toggle fires on release)
    _ = try m.apply(.{ .buttons = sel_mask }, 16);

    // Dirty processor state to simulate residual accumulation
    m.gyro_proc.ema_y = -200.0;
    m.stick_right.mouse_accum_y = 0.8;

    // Frame 2: Select released → toggle fires → active_changed = true → reset
    _ = try m.apply(.{ .buttons = 0 }, 16);

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_y);
    try testing.expectEqual(@as(f32, 0), m.stick_right.mouse_accum_y);
}
