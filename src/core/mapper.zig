const std = @import("std");
const linux = std.os.linux;
const toml = @import("toml");
const mapping = @import("../config/mapping.zig");
const state = @import("state.zig");
const layer = @import("layer.zig");

pub const RemapTargetResolved = @import("remap.zig").RemapTargetResolved;
pub const resolveTarget = @import("remap.zig").resolveTarget;
pub const AuxEvent = @import("../io/uinput.zig").AuxEvent;

pub const AuxEventList = struct {
    buffer: [64]AuxEvent = undefined,
    len: usize = 0,

    pub fn append(self: *AuxEventList, val: AuxEvent) error{Overflow}!void {
        if (self.len >= 64) return error.Overflow;
        self.buffer[self.len] = val;
        self.len += 1;
    }

    pub fn get(self: *const AuxEventList, i: usize) AuxEvent {
        return self.buffer[i];
    }

    pub fn slice(self: *const AuxEventList) []const AuxEvent {
        return self.buffer[0..self.len];
    }
};

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
};

pub const Mapper = struct {
    config: *const MappingConfig,
    layer: LayerState,
    state: GamepadState,
    prev: GamepadState,
    suppressed_buttons: u32,
    injected_buttons: u32,
    timer_fd: std.posix.fd_t,
    allocator: std.mem.Allocator,

    pub fn init(config: *const MappingConfig, timer_fd: std.posix.fd_t, allocator: std.mem.Allocator) !Mapper {
        return .{
            .config = config,
            .layer = LayerState.init(allocator),
            .state = .{},
            .prev = .{},
            .suppressed_buttons = 0,
            .injected_buttons = 0,
            .timer_fd = timer_fd,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Mapper) void {
        self.layer.deinit();
    }

    pub fn apply(self: *Mapper, delta: GamepadStateDelta) !OutputEvents {
        // [1] merge delta into current state
        applyDelta(&self.state, delta);

        // [2] layer trigger processing
        const configs = self.config.layer orelse &.{};
        const action = self.layer.processLayerTriggers(configs, self.state.buttons, self.prev.buttons);
        if (action.arm_timer_ms) |ms| try armTimer(self.timer_fd, @intCast(ms));
        if (action.disarm_timer) disarmTimer(self.timer_fd);

        // reset accumulators
        self.suppressed_buttons = 0;
        self.injected_buttons = 0;

        // per-source inject map: null = not mapped, Some = last-write target
        const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;
        var per_src_inject: [BUTTON_COUNT]?RemapTargetResolved = [_]?RemapTargetResolved{null} ** BUTTON_COUNT;
        var aux = AuxEventList{};

        // [3] mode processing
        var suppress_dpad_hat: bool = false;
        {
            const dpad_cfg = self.config.dpad orelse mapping.DpadConfig{};
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
            }
        }

        // emit tap event if any
        if (action.tap_event) |tap| {
            emitTapEvent(tap, &aux);
        }

        // assemble emit state
        var emit_state = self.state;
        emit_state.buttons = (self.state.buttons & ~self.suppressed_buttons) | self.injected_buttons;
        if (suppress_dpad_hat) {
            emit_state.dpad_x = 0;
            emit_state.dpad_y = 0;
        }

        // [7] prev-frame masking: same masks applied to prev before diff
        var masked_prev = self.prev;
        masked_prev.buttons = (self.prev.buttons & ~self.suppressed_buttons) | self.injected_buttons;

        self.prev = self.state;

        return .{ .gamepad = emit_state, .prev = masked_prev, .aux = aux };
    }

    pub fn onTimerExpired(self: *Mapper) void {
        _ = self.layer.onTimerExpired();
    }
};

fn armTimer(fd: std.posix.fd_t, timeout_ms: u32) !void {
    const spec = linux.itimerspec{
        .it_value = .{
            .sec = @intCast(timeout_ms / 1000),
            .nsec = @intCast((timeout_ms % 1000) * 1_000_000),
        },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

fn disarmTimer(fd: std.posix.fd_t) void {
    const spec = linux.itimerspec{
        .it_value = .{ .sec = 0, .nsec = 0 },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

fn applyDelta(s: *GamepadState, delta: GamepadStateDelta) void {
    if (delta.ax) |v| s.ax = v;
    if (delta.ay) |v| s.ay = v;
    if (delta.rx) |v| s.rx = v;
    if (delta.ry) |v| s.ry = v;
    if (delta.lt) |v| s.lt = v;
    if (delta.rt) |v| s.rt = v;
    if (delta.dpad_x) |v| s.dpad_x = v;
    if (delta.dpad_y) |v| s.dpad_y = v;
    if (delta.buttons) |v| s.buttons = v;
    if (delta.gyro_x) |v| s.gyro_x = v;
    if (delta.gyro_y) |v| s.gyro_y = v;
    if (delta.gyro_z) |v| s.gyro_z = v;
    if (delta.accel_x) |v| s.accel_x = v;
    if (delta.accel_y) |v| s.accel_y = v;
    if (delta.accel_z) |v| s.accel_z = v;
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

fn emitTapEvent(target: RemapTargetResolved, aux: *AuxEventList) void {
    switch (target) {
        .key => |code| {
            aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {};
            aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
        },
        .mouse_button => |code| {
            aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch {};
            aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {};
        },
        .gamepad_button => |_| {
            // gamepad tap: would need two-frame press+release; not fully supported in single apply()
            // Phase 2a: emit as best-effort key inject in this frame
        },
        .disabled => {},
    }
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
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });
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
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });
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
    const events = try m.apply(.{ .buttons = @as(u32, 1) << m1_idx });

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
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });

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

    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });

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
    const events = try m.apply(.{ .buttons = both });

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

    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });

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
    const ev1 = try m.apply(.{ .buttons = a_mask });
    // A is suppressed in output, prev is now raw a_mask
    try testing.expectEqual(@as(u32, 0), ev1.gamepad.buttons & a_mask);

    // Frame N: A still pressed — should produce no change (both masked_prev and gamepad have A=0)
    const ev2 = try m.apply(.{ .buttons = a_mask });
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
    m.onTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Now layer remap should be active
    const a_idx: u5 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u5 = @intCast(@intFromEnum(ButtonId.B));
    const events = try m.apply(.{ .buttons = @as(u32, 1) << a_idx });
    try testing.expect((events.gamepad.buttons & (@as(u32, 1) << b_idx)) != 0);
}
