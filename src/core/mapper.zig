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
const c = @cImport(@cInclude("linux/input-event-codes.h"));

const posix = std.posix;

const REL_X: u16 = c.REL_X;
const REL_Y: u16 = c.REL_Y;
const REL_WHEEL: u16 = c.REL_WHEEL;
const REL_HWHEEL: u16 = c.REL_HWHEEL;

const remap_mod = @import("remap.zig");
const gesture_mod = @import("gesture.zig");
const chord_detector_mod = @import("chord_detector.zig");
pub const RemapTargetResolved = remap_mod.RemapTargetResolved;
pub const resolveTarget = remap_mod.resolveTarget;
pub const AuxEvent = aux_event_mod.AuxEvent;
pub const AuxEventList = aux_event_mod.AuxEventList;
pub const TimerRequest = @import("timer_request.zig").TimerRequest;
pub const ChordDetector = chord_detector_mod.Detector;
pub const ChordDetectorConfig = chord_detector_mod.Config;

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
    chord_switch_request: ?u8 = null,
};

pub const LayerTimerEvents = struct {
    gamepad: ?GamepadState = null,
    aux: AuxEventList = .{},
};

const BUTTON_COUNT = @typeInfo(ButtonId).@"enum".fields.len;

const ResolvedRemap = struct {
    inject: [BUTTON_COUNT]?RemapTargetResolved,
    suppress: u64,
};

const AuxDownTarget = union(enum) {
    key: u16,
    mouse_button: u16,
};

const AUX_TAP_RELEASE_DELAY_NS: i128 = 30 * std.time.ns_per_ms;
const AUX_TAP_RELEASE_TOKEN_SLOTS = BUTTON_COUNT;
const GESTURE_TOKEN_SLOTS = gesture_mod.GESTURE_SLOTS * 2;

const AuxTapReleaseTokenEntry = struct {
    token: u32,
    target: AuxDownTarget,
};

const AuxTapReleaseTokenTable = struct {
    entries: [AUX_TAP_RELEASE_TOKEN_SLOTS]?AuxTapReleaseTokenEntry = [_]?AuxTapReleaseTokenEntry{null} ** AUX_TAP_RELEASE_TOKEN_SLOTS,

    fn put(self: *AuxTapReleaseTokenTable, token: u32, target: AuxDownTarget) bool {
        for (&self.entries) |*e| {
            if (e.* == null) {
                e.* = .{ .token = token, .target = target };
                return true;
            }
        }
        return false;
    }

    fn take(self: *AuxTapReleaseTokenTable, token: u32) ?AuxDownTarget {
        for (&self.entries) |*e| {
            if (e.*) |v| {
                if (v.token == token) {
                    e.* = null;
                    return v.target;
                }
            }
        }
        return null;
    }

    fn takeTarget(self: *AuxTapReleaseTokenTable, target: AuxDownTarget) ?AuxTapReleaseTokenEntry {
        for (&self.entries) |*e| {
            if (e.*) |v| {
                if (auxDownTargetEql(v.target, target)) {
                    e.* = null;
                    return v;
                }
            }
        }
        return null;
    }
};

const GestureTokenEntry = struct {
    token: u32,
    src_idx: u6,
    leg: gesture_mod.GestureLeg,
};

// Maps live timer tokens armed by the gesture engine back to (slot, leg) so
// onMacroTimerExpired can route expiry. Bounded by concurrent gesture timers.
const GestureTokenTable = struct {
    entries: [GESTURE_TOKEN_SLOTS]?GestureTokenEntry = [_]?GestureTokenEntry{null} ** GESTURE_TOKEN_SLOTS,

    fn put(self: *GestureTokenTable, token: u32, src_idx: u6, leg: gesture_mod.GestureLeg) void {
        for (&self.entries) |*e| {
            if (e.* == null) {
                e.* = .{ .token = token, .src_idx = src_idx, .leg = leg };
                return;
            }
        }
    }

    fn take(self: *GestureTokenTable, token: u32) ?GestureTokenEntry {
        for (&self.entries) |*e| {
            if (e.*) |v| {
                if (v.token == token) {
                    e.* = null;
                    return v;
                }
            }
        }
        return null;
    }

    fn clear(self: *GestureTokenTable) void {
        self.entries = [_]?GestureTokenEntry{null} ** GESTURE_TOKEN_SLOTS;
    }
};

pub const Mapper = struct {
    config: *const MappingConfig,
    layer: LayerState,
    state: GamepadState,
    prev: GamepadState,
    gyro_proc: gyro.GyroProcessor,
    stick_left: stick.StickProcessor,
    stick_right: stick.StickProcessor,
    suppressed_buttons: u64,
    injected_buttons: u64,
    // Buttons already held when this mapper was seeded; ignore their edges until release.
    seeded_buttons: u64,
    aux_down_targets: [BUTTON_COUNT]?AuxDownTarget,
    gesture_aux_down_targets: [BUTTON_COUNT]?AuxDownTarget,
    pending_tap_release: ?u64,
    aux_tap_release_tokens: AuxTapReleaseTokenTable,
    // Gamepad-button taps emitted by macro timer expiry need one apply() cycle
    // to reach output before pending_tap_release fires; staged here, promoted
    // to injected+pending_tap_release at the next apply.
    macro_timer_tap_pending: u64,
    gesture_engine: gesture_mod.GestureEngine,
    gesture_tokens: GestureTokenTable,
    // Same staging discipline as macro_timer_tap_pending: gamepad taps emitted
    // from gesture timer expiry need one apply() to reach output.
    gesture_timer_tap_pending: u64,
    // Gamepad bits held by an active gesture hold leg; re-asserted each frame
    // until the hold leg emits its release.
    gesture_held_gamepad: u64,
    timer_fd: std.posix.fd_t,
    allocator: std.mem.Allocator,
    active_macros: std.ArrayList(MacroPlayer),
    timer_queue: TimerQueue,
    next_token: u32,
    resolved_base: ResolvedRemap,
    resolved_layers: []ResolvedRemap,
    // In-controller mapping switch via chord detection. null disables the feature.
    chord_detector: ?ChordDetector = null,

    pub fn init(config: *const MappingConfig, timer_fd: std.posix.fd_t, allocator: std.mem.Allocator) !Mapper {
        const base = if (config.remap) |m| try precomputeRemap(allocator, m) else ResolvedRemap{
            .inject = [_]?RemapTargetResolved{null} ** BUTTON_COUNT,
            .suppress = 0,
        };
        errdefer freeResolvedRemap(allocator, base);

        const layers = config.layer orelse &.{};
        const resolved_layers = try allocator.alloc(ResolvedRemap, layers.len);
        errdefer allocator.free(resolved_layers);

        var initialized: usize = 0;
        errdefer for (resolved_layers[0..initialized]) |r| freeResolvedRemap(allocator, r);

        for (layers, 0..) |*lc, i| {
            resolved_layers[i] = if (lc.remap) |m| try precomputeRemap(allocator, m) else ResolvedRemap{
                .inject = [_]?RemapTargetResolved{null} ** BUTTON_COUNT,
                .suppress = 0,
            };
            initialized = i + 1;
        }

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
            .seeded_buttons = 0,
            .aux_down_targets = [_]?AuxDownTarget{null} ** BUTTON_COUNT,
            .gesture_aux_down_targets = [_]?AuxDownTarget{null} ** BUTTON_COUNT,
            .pending_tap_release = null,
            .aux_tap_release_tokens = .{},
            .macro_timer_tap_pending = 0,
            .gesture_engine = .{},
            .gesture_tokens = .{},
            .gesture_timer_tap_pending = 0,
            .gesture_held_gamepad = 0,
            .timer_fd = timer_fd,
            .allocator = allocator,
            .active_macros = .{},
            .timer_queue = TimerQueue.init(allocator, timer_fd),
            .next_token = 1,
            .resolved_base = base,
            .resolved_layers = resolved_layers,
        };
    }

    pub fn deinit(self: *Mapper) void {
        self.layer.deinit();
        self.active_macros.deinit(self.allocator);
        self.gesture_engine.reset();
        self.gesture_tokens.clear();
        self.timer_queue.deinit();
        freeResolvedRemap(self.allocator, self.resolved_base);
        for (self.resolved_layers) |r| freeResolvedRemap(self.allocator, r);
        self.allocator.free(self.resolved_layers);
    }

    pub fn setChordDetector(self: *Mapper, cfg: ChordDetectorConfig) void {
        self.chord_detector = ChordDetector.init(cfg);
    }

    pub fn seedInputState(self: *Mapper, current: GamepadState) void {
        var seeded = current;
        self.applyTriggerThreshold(&seeded);
        self.state = seeded;
        self.prev = seeded;
        self.seeded_buttons = seeded.buttons;
    }

    pub fn resetRuntimeState(self: *Mapper) void {
        self.layer.tap_hold = null;
        self.layer.toggled.clearRetainingCapacity();
        self.state = .{};
        self.prev = .{};
        self.gyro_proc.reset();
        self.stick_left.reset();
        self.stick_right.reset();
        self.suppressed_buttons = 0;
        self.injected_buttons = 0;
        self.seeded_buttons = 0;
        self.aux_down_targets = [_]?AuxDownTarget{null} ** BUTTON_COUNT;
        self.gesture_aux_down_targets = [_]?AuxDownTarget{null} ** BUTTON_COUNT;
        self.pending_tap_release = null;
        self.aux_tap_release_tokens = .{};
        self.macro_timer_tap_pending = 0;
        self.gesture_engine.reset();
        self.gesture_tokens.clear();
        self.gesture_timer_tap_pending = 0;
        self.gesture_held_gamepad = 0;
        self.active_macros.clearRetainingCapacity();
        self.timer_queue.clear();
        self.next_token = 1;
        if (self.chord_detector) |cd| {
            self.chord_detector = ChordDetector.init(cd.cfg);
        }
    }

    fn applyTriggerThreshold(self: *const Mapper, gs: *GamepadState) void {
        if (self.config.trigger_threshold) |threshold| {
            const lt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.LT));
            const rt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.RT));
            if (gs.lt > threshold) {
                gs.buttons |= lt_bit;
            } else {
                gs.buttons &= ~lt_bit;
            }
            if (gs.rt > threshold) {
                gs.buttons |= rt_bit;
            } else {
                gs.buttons &= ~rt_bit;
            }
        }
    }

    pub fn releaseHeldAux(self: *Mapper) AuxEventList {
        var aux = AuxEventList{};
        for (&self.aux_down_targets) |*target| {
            if (target.*) |down| {
                emitAuxDownRelease(down, &aux);
                target.* = null;
            }
        }

        var injected: u64 = 0;
        for (self.active_macros.items) |*player| {
            player.emitPendingReleases(&aux, &injected);
        }
        self.active_macros.clearRetainingCapacity();

        for (&self.gesture_aux_down_targets) |*target| {
            if (target.*) |down| {
                emitAuxDownRelease(down, &aux);
                target.* = null;
            }
        }
        releasePendingAuxTapReleases(self, &aux, null);
        return aux;
    }

    fn suppressSeededEdges(self: *Mapper) void {
        if (self.seeded_buttons == 0) return;

        const still_held = self.seeded_buttons & self.state.buttons;
        const released = self.seeded_buttons & ~self.state.buttons;
        var suppress_release = released;
        for (self.aux_down_targets, 0..) |target, i| {
            if (target != null) {
                suppress_release &= ~(@as(u64, 1) << @as(u6, @intCast(i)));
            }
        }
        self.prev.buttons = (self.prev.buttons | still_held) & ~suppress_release;
        self.seeded_buttons = still_held;
    }

    // `now_ns` is the ppoll-wakeup CLOCK_MONOTONIC snapshot from the caller;
    // must match the value passed to onMacroTimerExpired() in the same wakeup so
    // tap/hold boundary decisions see a single timeline.
    pub fn apply(self: *Mapper, delta: GamepadStateDelta, dt_ms: u32, now_ns: i128) !OutputEvents {
        // flush pending tap release from previous frame
        var aux = AuxEventList{};
        if (self.pending_tap_release) |mask| {
            self.injected_buttons &= ~mask;
            self.pending_tap_release = null;
            // inject release into emit state at end of this frame
        }

        self.state.applyDelta(delta);
        self.applyTriggerThreshold(&self.state);
        self.suppressSeededEdges();

        const configs = self.config.layer orelse &.{};
        const action = self.layer.processLayerTriggers(configs, self.state.buttons, self.prev.buttons, now_ns);
        var timer_request: ?TimerRequest = null;
        if (action.arm_timer_ms) |ms| {
            timer_request = .{ .arm = @intCast(ms) };
        } else if (action.disarm_timer) {
            timer_request = .{ .disarm = {} };
        }
        if (action.active_changed) {
            self.handleLayerActiveChanged(&aux, now_ns);
        }

        self.suppressed_buttons = 0;
        self.injected_buttons = 0;

        // Promote macro-timer tap bits staged at last expiry — emit press this
        // frame, schedule release for the next apply.
        if (self.macro_timer_tap_pending != 0) {
            self.injected_buttons |= self.macro_timer_tap_pending;
            const existing = self.pending_tap_release orelse 0;
            self.pending_tap_release = existing | self.macro_timer_tap_pending;
            self.macro_timer_tap_pending = 0;
        }

        // Promote gesture-timer tap bits staged at last expiry.
        if (self.gesture_timer_tap_pending != 0) {
            self.injected_buttons |= self.gesture_timer_tap_pending;
            const existing = self.pending_tap_release orelse 0;
            self.pending_tap_release = existing | self.gesture_timer_tap_pending;
            self.gesture_timer_tap_pending = 0;
        }

        // Suppress layer trigger buttons so they don't leak to uinput output.
        // Trigger buttons are consumed by the layer system regardless of
        // whether the layer is currently active.
        for (configs) |*cfg| {
            const trigger_id = std.meta.stringToEnum(ButtonId, cfg.trigger) orelse continue;
            self.suppressed_buttons |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(trigger_id)));
        }

        // Chord switch detection. Selector buttons must not leak to uinput output
        // while the modifier is held; the supervisor performs the actual mapping
        // switch in response to chord_switch_request.
        var chord_switch_request: ?u8 = null;
        if (self.chord_detector) |*cd| {
            const cd_now: u64 = @intCast(@max(now_ns, 0));
            const cr = cd.step(self.state.buttons, self.prev.buttons, cd_now);
            self.suppressed_buttons |= cr.suppress_mask;
            chord_switch_request = cr.chord_index;
        }

        // per-source inject map: null = not mapped, Some = last-write target
        var per_src_inject: [BUTTON_COUNT]?RemapTargetResolved = [_]?RemapTargetResolved{null} ** BUTTON_COUNT;

        var suppress_dpad_hat: bool = false;
        var suppress_right_stick_gyro: bool = false;
        var suppress_left_stick_gyro: bool = false;
        var gyro_joy_x: ?i16 = null;
        var gyro_joy_y: ?i16 = null;
        var gyro_blend_stick: bool = false;
        {
            const gcfg = self.effectiveGyroConfig();
            const activate_spec = blk: {
                if (self.layer.getActive(self.config.layer orelse &.{})) |active| {
                    if (active.gyro) |g| break :blk g.activate;
                }
                break :blk if (self.config.gyro) |g| g.activate else null;
            };
            if (checkGyroActivate(activate_spec, self.state.buttons)) {
                const gout = self.gyro_proc.processMotion(
                    &gcfg,
                    self.state.gyro_x,
                    self.state.gyro_y,
                    self.state.gyro_z,
                    self.state.accel_x,
                    self.state.accel_y,
                    self.state.accel_z,
                );
                if (std.mem.eql(u8, gcfg.mode, "mouse")) {
                    if (gout.rel_x != 0) aux.append(.{ .rel = .{ .code = REL_X, .value = gout.rel_x } }) catch {};
                    if (gout.rel_y != 0) aux.append(.{ .rel = .{ .code = REL_Y, .value = gout.rel_y } }) catch {};
                } else if (std.mem.eql(u8, gcfg.mode, "joystick")) {
                    gyro_blend_stick = gcfg.blend_stick;
                    if (gout.joy_x) |jx| {
                        gyro_joy_x = jx;
                        switch (gcfg.target) {
                            .right_stick => suppress_right_stick_gyro = true,
                            .left_stick => suppress_left_stick_gyro = true,
                        }
                    }
                    if (gout.joy_y) |jy| {
                        gyro_joy_y = jy;
                        switch (gcfg.target) {
                            .right_stick => suppress_right_stick_gyro = true,
                            .left_stick => suppress_left_stick_gyro = true,
                        }
                    }
                }
            } else {
                self.gyro_proc.reset();
            }

            const left_cfg = self.effectiveStickConfig(.left);
            const left_out = self.stick_left.process(&left_cfg, self.state.ax, self.state.ay, dt_ms);
            if (std.mem.eql(u8, left_cfg.mode, "mouse")) {
                if (left_out.rel_x != 0) aux.append(.{ .rel = .{ .code = REL_X, .value = left_out.rel_x } }) catch {};
                if (left_out.rel_y != 0) aux.append(.{ .rel = .{ .code = REL_Y, .value = left_out.rel_y } }) catch {};
            } else if (std.mem.eql(u8, left_cfg.mode, "scroll")) {
                if (left_out.wheel != 0) aux.append(.{ .rel = .{ .code = REL_WHEEL, .value = left_out.wheel } }) catch {};
                if (left_out.hwheel != 0) aux.append(.{ .rel = .{ .code = REL_HWHEEL, .value = left_out.hwheel } }) catch {};
            }

            const right_cfg = self.effectiveStickConfig(.right);
            const right_out = self.stick_right.process(&right_cfg, self.state.rx, self.state.ry, dt_ms);
            if (std.mem.eql(u8, right_cfg.mode, "mouse")) {
                if (right_out.rel_x != 0) aux.append(.{ .rel = .{ .code = REL_X, .value = right_out.rel_x } }) catch {};
                if (right_out.rel_y != 0) aux.append(.{ .rel = .{ .code = REL_Y, .value = right_out.rel_y } }) catch {};
            } else if (std.mem.eql(u8, right_cfg.mode, "scroll")) {
                if (right_out.wheel != 0) aux.append(.{ .rel = .{ .code = REL_WHEEL, .value = right_out.wheel } }) catch {};
                if (right_out.hwheel != 0) aux.append(.{ .rel = .{ .code = REL_HWHEEL, .value = right_out.hwheel } }) catch {};
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

        // Base remap: copy precomputed suppress mask + inject targets.
        self.suppressed_buttons |= self.resolved_base.suppress;
        for (self.resolved_base.inject, 0..) |t, i| {
            if (t) |target| per_src_inject[i] = target;
        }

        // Layer remap: OR-accumulate suppress, last-write-wins for inject.
        if (self.layer.getActiveIndex(configs)) |idx| {
            const lr = &self.resolved_layers[idx];
            self.suppressed_buttons |= lr.suppress;
            for (lr.inject, 0..) |t, i| {
                if (t) |target| per_src_inject[i] = target;
            }
        }

        for (0..BUTTON_COUNT) |i| {
            const src_mask: u64 = @as(u64, 1) << @as(u6, @intCast(i));
            const pressed = (self.state.buttons & src_mask) != 0;
            const prev_pressed = (self.prev.buttons & src_mask) != 0;
            if (!pressed and prev_pressed) {
                if (self.aux_down_targets[i]) |down| {
                    emitAuxDownRelease(down, &aux);
                    self.aux_down_targets[i] = null;
                }
            }

            const target = per_src_inject[i] orelse continue;
            switch (target) {
                .macro => |name| {
                    if (pressed and !prev_pressed) {
                        if (self.findMacro(name)) |m| {
                            const token = self.next_token;
                            self.next_token +%= 1;
                            const player = MacroPlayer.init(m, token, @intCast(i));
                            self.active_macros.append(self.allocator, player) catch |err| {
                                std.log.warn("macro queue failed: {}", .{err});
                            };
                        }
                    } else if (!pressed and prev_pressed) {
                        for (self.active_macros.items) |*p| {
                            if (p.trigger_src_idx == @as(u6, @intCast(i)) and p.waiting_for_release)
                                p.notifyTriggerReleased();
                        }
                    }
                },
                .gamepad_button => {
                    // Level-triggered: OR bit each frame while held;
                    // `injected_buttons` is reset at frame start so release is implicit.
                    if (pressed) remap_mod.applyTarget(target, .press, &aux, &self.injected_buttons, null, null);
                },
                .key, .mouse_button => {
                    if (pressed and !prev_pressed) {
                        remap_mod.applyTarget(target, .press, &aux, &self.injected_buttons, null, null);
                        self.aux_down_targets[i] = auxDownTarget(target);
                    }
                },
                .disabled => {},
                // Chord source button is suppressed via precomputeRemap; chord
                // events are emitted by the chord output pipeline, not here.
                .chord => {},
                .gesture => |node| {
                    if (pressed != prev_pressed) {
                        const out = self.gesture_engine.onButtonEdge(@intCast(i), node, pressed, now_ns);
                        self.applyGestureOutcome(@intCast(i), out, &aux, false, now_ns);
                    }
                },
            }
        }

        // Re-assert gamepad bits held by an active gesture hold leg; the engine
        // emits press once, so the bit must persist across frames until release.
        self.injected_buttons |= self.gesture_held_gamepad;

        if (action.tap_event) |tap| {
            emitTapEvent(self, tap, &aux, now_ns);
        }

        var macro_tap_release: u64 = 0;
        var macro_axes: macro_player_mod.AxisInjection = .{};
        var i: usize = 0;
        while (i < self.active_macros.items.len) {
            // Re-assert macro-held gamepad bits each frame; injected_buttons is reset
            // above, but held_gamepad_buttons (set by past `down=`) must persist
            // across the delay window and outlive same-frame step advancement.
            self.injected_buttons |= self.active_macros.items[i].held_gamepad_buttons;
            // Refresh trigger-held flag so repeat-mode macros stop scheduling
            // restarts once the source button is released.
            const src_bit: u64 = @as(u64, 1) << self.active_macros.items[i].trigger_src_idx;
            self.active_macros.items[i].setTriggerHeld((self.state.buttons & src_bit) != 0);
            const done = self.active_macros.items[i].step(
                &aux,
                &self.timer_queue,
                &self.injected_buttons,
                &macro_tap_release,
                &macro_axes,
                now_ns,
            ) catch |err| blk: {
                std.log.warn("macro step failed: {}", .{err});
                break :blk false;
            };
            if (done) {
                _ = self.active_macros.swapRemove(i);
            } else {
                i += 1;
            }
        }
        if (macro_tap_release != 0) {
            const existing = self.pending_tap_release orelse 0;
            self.pending_tap_release = existing | macro_tap_release;
        }

        // assemble emit state
        var emit_state = self.state;
        emit_state.buttons = (self.state.buttons & ~self.suppressed_buttons) | self.injected_buttons;
        // issue #99: macros driving LT/RT raise the analog axis floor; physical
        // input still wins when the user presses harder than the macro.
        if (macro_axes.lt > emit_state.lt) emit_state.lt = macro_axes.lt;
        if (macro_axes.rt > emit_state.rt) emit_state.rt = macro_axes.rt;
        emit_state.synthesizeDpadAxes();
        if (suppress_dpad_hat) {
            emit_state.dpad_x = 0;
            emit_state.dpad_y = 0;
        }

        // gyro joystick mode: override or blend stick axes, suppress originals
        if (suppress_right_stick_gyro) {
            if (gyro_joy_x) |jx| emit_state.rx = if (gyro_blend_stick)
                @as(i16, @intCast(std.math.clamp(@as(i32, emit_state.rx) + @as(i32, jx), -32767, 32767)))
            else
                jx;
            if (gyro_joy_y) |jy| emit_state.ry = if (gyro_blend_stick)
                @as(i16, @intCast(std.math.clamp(@as(i32, emit_state.ry) + @as(i32, jy), -32767, 32767)))
            else
                jy;
        }
        if (suppress_left_stick_gyro) {
            if (gyro_joy_x) |jx| emit_state.ax = if (gyro_blend_stick)
                @as(i16, @intCast(std.math.clamp(@as(i32, emit_state.ax) + @as(i32, jx), -32767, 32767)))
            else
                jx;
            if (gyro_joy_y) |jy| emit_state.ay = if (gyro_blend_stick)
                @as(i16, @intCast(std.math.clamp(@as(i32, emit_state.ay) + @as(i32, jy), -32767, 32767)))
            else
                jy;
        }

        // suppress stick axes when mode != gamepad
        const left_cfg = self.effectiveStickConfig(.left);
        const right_cfg = self.effectiveStickConfig(.right);
        if (!suppress_left_stick_gyro and (left_cfg.suppress_gamepad or !std.mem.eql(u8, left_cfg.mode, "gamepad"))) {
            emit_state.ax = 0;
            emit_state.ay = 0;
        }
        if (!suppress_right_stick_gyro and (right_cfg.suppress_gamepad or !std.mem.eql(u8, right_cfg.mode, "gamepad"))) {
            emit_state.rx = 0;
            emit_state.ry = 0;
        }

        // Apply same masks to prev before diff.
        var masked_prev = self.prev;
        masked_prev.buttons = (self.prev.buttons & ~self.suppressed_buttons) | self.injected_buttons;
        masked_prev.synthesizeDpadAxes();
        if (suppress_dpad_hat) {
            masked_prev.dpad_x = 0;
            masked_prev.dpad_y = 0;
        }

        self.prev = self.state;

        return .{
            .gamepad = emit_state,
            .prev = masked_prev,
            .aux = aux,
            .timer_request = timer_request,
            .chord_switch_request = chord_switch_request,
        };
    }

    // Layer-hold timerfd (slot 2) expiry only — macro timerfd (slot 4) is a separate fd.
    pub fn onLayerTimerExpired(self: *Mapper) AuxEventList {
        return self.onLayerTimerExpiredAt(0).aux;
    }

    pub fn onLayerTimerExpiredAt(self: *Mapper, now_ns: i128) LayerTimerEvents {
        var events = LayerTimerEvents{};
        const th_res = self.layer.onTimerExpired();
        if (th_res.sticky_toggled) {
            self.handleLayerActiveChanged(&events.aux, now_ns);
            events.gamepad = self.currentMappedGamepadFrame();
        } else if (th_res.layer_activated) {
            self.prev.dpad_x = 0;
            self.prev.dpad_y = 0;
        }
        return events;
    }

    fn handleLayerActiveChanged(self: *Mapper, aux: *AuxEventList, now_ns: i128) void {
        self.gyro_proc.reset();
        self.stick_left.reset();
        self.stick_right.reset();
        // Reset dpad prev so edge detection fires on the next frame.
        self.prev.dpad_x = 0;
        self.prev.dpad_y = 0;
        // Cancel in-flight macros; emit releases for any held keys/buttons.
        for (self.active_macros.items) |*p| p.emitPendingReleases(aux, &self.injected_buttons);
        self.active_macros.clearRetainingCapacity();
        releasePendingAuxTapReleases(self, aux, now_ns);
        // Discard tap bits staged from a cancelled macro's timer expiry.
        self.macro_timer_tap_pending = 0;
        // Cancel in-flight gestures; mirror the macro-cancel above.
        for (self.gesture_tokens.entries) |maybe| {
            if (maybe) |e| self.timer_queue.cancel(e.token, now_ns);
        }
        self.gesture_tokens.clear();
        self.gesture_engine.reset();
        self.gesture_timer_tap_pending = 0;
        self.gesture_held_gamepad = 0;
    }

    fn currentMappedGamepadFrame(self: *Mapper) GamepadState {
        const configs = self.config.layer orelse &.{};
        var suppressed: u64 = 0;
        var injected: u64 = self.gesture_held_gamepad;
        var per_src_inject: [BUTTON_COUNT]?RemapTargetResolved = [_]?RemapTargetResolved{null} ** BUTTON_COUNT;

        for (self.active_macros.items) |player| {
            injected |= player.held_gamepad_buttons;
        }

        for (configs) |*cfg| {
            const trigger_id = std.meta.stringToEnum(ButtonId, cfg.trigger) orelse continue;
            suppressed |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(trigger_id)));
        }
        suppressed |= self.currentChordSwitchSuppressMask();

        suppressed |= self.resolved_base.suppress;
        for (self.resolved_base.inject, 0..) |t, i| {
            if (t) |target| per_src_inject[i] = target;
        }
        if (self.layer.getActiveIndex(configs)) |idx| {
            const lr = &self.resolved_layers[idx];
            suppressed |= lr.suppress;
            for (lr.inject, 0..) |t, i| {
                if (t) |target| per_src_inject[i] = target;
            }
        }

        for (0..BUTTON_COUNT) |i| {
            const src_mask: u64 = @as(u64, 1) << @as(u6, @intCast(i));
            if ((self.state.buttons & src_mask) == 0) continue;
            const target = per_src_inject[i] orelse continue;
            switch (target) {
                .gamepad_button => |dst| injected |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(dst))),
                else => {},
            }
        }

        const dpad_cfg = self.effectiveDpadConfig();
        var suppress_dpad_hat = false;
        if (std.mem.eql(u8, dpad_cfg.mode, "arrows") and (dpad_cfg.suppress_gamepad orelse false)) {
            suppressed |= (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadUp)))) |
                (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadDown)))) |
                (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadLeft)))) |
                (@as(u64, 1) << @as(u6, @intCast(@intFromEnum(ButtonId.DPadRight))));
            suppress_dpad_hat = true;
        }

        var emit_state = self.state;
        emit_state.buttons = (self.state.buttons & ~suppressed) | injected;
        emit_state.synthesizeDpadAxes();
        if (suppress_dpad_hat) {
            emit_state.dpad_x = 0;
            emit_state.dpad_y = 0;
        }

        const left_cfg = self.effectiveStickConfig(.left);
        const right_cfg = self.effectiveStickConfig(.right);
        if (left_cfg.suppress_gamepad or !std.mem.eql(u8, left_cfg.mode, "gamepad")) {
            emit_state.ax = 0;
            emit_state.ay = 0;
        }
        if (right_cfg.suppress_gamepad or !std.mem.eql(u8, right_cfg.mode, "gamepad")) {
            emit_state.rx = 0;
            emit_state.ry = 0;
        }
        return emit_state;
    }

    fn currentChordSwitchSuppressMask(self: *const Mapper) u64 {
        const cd = self.chord_detector orelse return 0;
        if (cd.cfg.selector_count == 0 or cd.cfg.modifier_mask == 0) return 0;
        if ((self.state.buttons & cd.cfg.modifier_mask) != cd.cfg.modifier_mask) return 0;

        var suppress: u64 = 0;
        var i: u8 = 0;
        while (i < cd.cfg.selector_count) : (i += 1) {
            suppress |= cd.cfg.selectors[i];
        }
        return suppress;
    }

    // Translate one gesture-engine Outcome into output. `from_timer` selects
    // the gamepad-tap staging path: timer-context taps stage into
    // gesture_timer_tap_pending so a full press is visible one frame before the
    // release; apply-context taps use pending_tap_release directly.
    fn applyGestureOutcome(
        self: *Mapper,
        src_idx: u6,
        out: gesture_mod.Outcome,
        aux: *AuxEventList,
        from_timer: bool,
        now_ns: i128,
    ) void {
        if (out.cancel_hold or out.cancel_double) {
            // Tokens are matched by value at expiry; cancel both the queue
            // entry and the routing record so a stale expiry is inert.
            var ti: usize = 0;
            while (ti < self.gesture_tokens.entries.len) : (ti += 1) {
                const e = self.gesture_tokens.entries[ti] orelse continue;
                if (e.src_idx != src_idx) continue;
                if ((out.cancel_hold and e.leg == .hold) or
                    (out.cancel_double and e.leg == .double))
                {
                    self.timer_queue.cancel(e.token, now_ns);
                    self.gesture_tokens.entries[ti] = null;
                }
            }
        }
        for (out.slice()) |em| {
            switch (em.target) {
                .gamepad_button => |dst| {
                    const mask = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(dst)));
                    switch (em.action) {
                        .press => {
                            self.injected_buttons |= mask;
                            self.gesture_held_gamepad |= mask;
                        },
                        .release => {
                            self.injected_buttons &= ~mask;
                            self.gesture_held_gamepad &= ~mask;
                        },
                        .tap => if (from_timer) {
                            self.gesture_timer_tap_pending |= mask;
                        } else {
                            self.injected_buttons |= mask;
                            const existing = self.pending_tap_release orelse 0;
                            self.pending_tap_release = existing | mask;
                        },
                    }
                },
                else => {
                    const act: remap_mod.TargetAction = switch (em.action) {
                        .press => .press,
                        .release => .release,
                        .tap => .tap,
                    };
                    if (auxDownTarget(em.target)) |down| {
                        switch (em.action) {
                            .press => self.gesture_aux_down_targets[src_idx] = down,
                            .release => self.gesture_aux_down_targets[src_idx] = null,
                            .tap => {},
                        }
                    }
                    if (em.action == .tap and emitDelayedAuxTap(self, em.target, aux, now_ns)) continue;
                    remap_mod.applyTarget(em.target, act, aux, &self.injected_buttons, null, null);
                },
            }
        }
        if (out.arm) |a| {
            const token = self.next_token;
            self.next_token +%= 1;
            self.timer_queue.arm(a.deadline_ns, token, now_ns) catch return;
            self.gesture_tokens.put(token, src_idx, a.leg);
            self.gesture_engine.setArmToken(src_idx, a.leg, token);
        }
    }

    // Macro timerfd (slot 4) expiry only — must NOT call onLayerTimerExpired().
    pub fn onMacroTimerExpired(self: *Mapper, now_ns: i128) AuxEventList {
        var aux = AuxEventList{};
        var macro_tap_release: u64 = 0;
        // Axis floor on timer-driven resume is discarded; the next Mapper.apply()
        // frame re-walks active macros and recomputes from held_axis_*.
        var macro_axes: macro_player_mod.AxisInjection = .{};
        var buf: [16]timer_queue_mod.Deadline = undefined;
        const expired = self.timer_queue.drainExpired(now_ns, &buf);
        for (expired) |d| {
            if (self.aux_tap_release_tokens.take(d.token)) |target| {
                emitAuxDownRelease(target, &aux);
                continue;
            }
            if (self.gesture_tokens.take(d.token)) |ge| {
                const src_bit = @as(u64, 1) << ge.src_idx;
                const held = (self.state.buttons & src_bit) != 0;
                const out = self.gesture_engine.onTimerExpired(ge.src_idx, ge.leg, held, now_ns);
                self.applyGestureOutcome(ge.src_idx, out, &aux, true, now_ns);
                continue;
            }
            var idx: usize = 0;
            while (idx < self.active_macros.items.len) {
                if (self.active_macros.items[idx].timer_token == d.token) {
                    const done = self.active_macros.items[idx].step(
                        &aux,
                        &self.timer_queue,
                        &self.injected_buttons,
                        &macro_tap_release,
                        &macro_axes,
                        now_ns,
                    ) catch |err| blk: {
                        std.log.warn("macro step failed: {}", .{err});
                        break :blk false;
                    };
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
        if (macro_tap_release != 0) {
            // Stage tap bits for the next apply rather than promoting to
            // pending_tap_release here — apply() resets injected_buttons on
            // entry, so a same-cycle pending_tap_release would clear the bit
            // before the gamepad output is ever emitted.
            self.macro_timer_tap_pending |= macro_tap_release;
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
    const response = resolveGyroResponse(mc.response);
    return .{
        .mode = mc.mode,
        .response = response,
        .axis_x = resolveGyroAxis(mc.axis_x, if (response == .tilt) .roll else .yaw),
        .axis_y = resolveGyroAxis(mc.axis_y, .pitch),
        .degrees_full = if (mc.degrees_full) |v| @floatCast(v) else 35.0,
        .sensitivity_x = if (mc.sensitivity_x) |v| @floatCast(v) else if (mc.sensitivity) |v| @floatCast(v) else 1.5,
        .sensitivity_y = if (mc.sensitivity_y) |v| @floatCast(v) else if (mc.sensitivity) |v| @floatCast(v) else 1.5,
        .deadzone = if (mc.deadzone) |v| @intCast(v) else 0,
        .smoothing = if (mc.smoothing) |v| @floatCast(v) else 0.3,
        .curve = if (mc.curve) |v| @floatCast(v) else 1.0,
        .max_val = if (mc.max_val) |v| @floatCast(v) else 32767.0,
        .invert_x = mc.invert_x orelse false,
        .invert_y = mc.invert_y orelse false,
        .target = if (mc.target) |t| (if (std.mem.eql(u8, t, "left_stick")) .left_stick else .right_stick) else .right_stick,
        .blend_stick = mc.blend_stick orelse false,
        .minimum_output = if (mc.minimum_output) |v| @as(f32, @floatCast(std.math.clamp(v, 0.0, 1.0))) else 0.0,
    };
}

fn resolveGyroResponse(response: ?[]const u8) gyro.GyroResponse {
    const r = response orelse return .rate;
    if (std.mem.eql(u8, r, "tilt")) return .tilt;
    return .rate;
}

fn resolveGyroAxis(axis: ?[]const u8, default: gyro.GyroAxis) gyro.GyroAxis {
    const a = axis orelse return default;
    if (std.mem.eql(u8, a, "none")) return .none;
    if (std.mem.eql(u8, a, "pitch")) return .pitch;
    if (std.mem.eql(u8, a, "roll")) return .roll;
    if (std.mem.eql(u8, a, "yaw")) return .yaw;
    return default;
}

fn resolveStickConfig(mc: *const mapping.StickConfig) stick.StickConfig {
    return .{
        .mode = mc.mode,
        .deadzone = if (mc.deadzone) |v| @intCast(v) else 128,
        .sensitivity = if (mc.sensitivity) |v| @floatCast(v) else 1.0,
        .suppress_gamepad = mc.suppress_gamepad orelse false,
    };
}

fn freeResolvedRemap(allocator: std.mem.Allocator, r: ResolvedRemap) void {
    for (r.inject) |maybe_target| {
        const t = maybe_target orelse continue;
        switch (t) {
            .chord => |codes| allocator.free(codes),
            .gesture => |node| allocator.destroy(node),
            else => {},
        }
    }
}

fn auxDownTarget(target: RemapTargetResolved) ?AuxDownTarget {
    return switch (target) {
        .key => |code| .{ .key = code },
        .mouse_button => |code| .{ .mouse_button = code },
        else => null,
    };
}

fn auxDownTargetEql(a: AuxDownTarget, b: AuxDownTarget) bool {
    return switch (a) {
        .key => |a_code| switch (b) {
            .key => |b_code| a_code == b_code,
            else => false,
        },
        .mouse_button => |a_code| switch (b) {
            .mouse_button => |b_code| a_code == b_code,
            else => false,
        },
    };
}

fn emitAuxDownPress(target: AuxDownTarget, aux: *AuxEventList) bool {
    switch (target) {
        .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch return false,
        .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch return false,
    }
    return true;
}

fn emitAuxDownRelease(target: AuxDownTarget, aux: *AuxEventList) void {
    switch (target) {
        .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {},
        .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {},
    }
}

fn releasePendingAuxTapReleases(self: *Mapper, aux: *AuxEventList, now_ns: ?i128) void {
    for (&self.aux_tap_release_tokens.entries) |*entry| {
        if (entry.*) |e| {
            if (now_ns) |now| self.timer_queue.cancel(e.token, now);
            emitAuxDownRelease(e.target, aux);
            entry.* = null;
        }
    }
}

fn emitDelayedAuxTap(self: *Mapper, target: RemapTargetResolved, aux: *AuxEventList, now_ns: i128) bool {
    const down = auxDownTarget(target) orelse return false;
    if (self.aux_tap_release_tokens.takeTarget(down)) |prior| {
        self.timer_queue.cancel(prior.token, now_ns);
        emitAuxDownRelease(prior.target, aux);
    }

    const token = self.next_token;
    self.next_token +%= 1;
    if (!self.aux_tap_release_tokens.put(token, down)) {
        remap_mod.applyTarget(target, .tap, aux, &self.injected_buttons, null, null);
        return true;
    }
    if (!emitAuxDownPress(down, aux)) {
        _ = self.aux_tap_release_tokens.take(token);
        return true;
    }
    self.timer_queue.arm(now_ns + AUX_TAP_RELEASE_DELAY_NS, token, now_ns) catch |err| {
        _ = self.aux_tap_release_tokens.take(token);
        std.log.warn("aux tap release timer arm failed: {}", .{err});
        emitAuxDownRelease(down, aux);
    };
    return true;
}

fn emitTapEvent(self: *Mapper, target: RemapTargetResolved, aux: *AuxEventList, now_ns: i128) void {
    if (emitDelayedAuxTap(self, target, aux, now_ns)) return;

    var local_pending: u64 = self.pending_tap_release orelse 0;
    remap_mod.applyTarget(target, .tap, aux, &self.injected_buttons, &local_pending, null);
    if (local_pending != 0) self.pending_tap_release = local_pending;
}

fn precomputeRemap(allocator: std.mem.Allocator, remap_map: mapping.RemapMap) !ResolvedRemap {
    var result = ResolvedRemap{
        .inject = [_]?RemapTargetResolved{null} ** BUTTON_COUNT,
        .suppress = 0,
    };
    errdefer freeResolvedRemap(allocator, result);

    var it = remap_map.map.iterator();
    while (it.next()) |entry| {
        const src_id = std.meta.stringToEnum(ButtonId, entry.key_ptr.*) orelse {
            std.log.warn("unknown remap source: {s}", .{entry.key_ptr.*});
            continue;
        };
        const src_idx: u6 = @intCast(@intFromEnum(src_id));
        const target: RemapTargetResolved = switch (entry.value_ptr.*) {
            .string => |s| resolveTarget(s) catch {
                std.log.warn("unknown remap target: {s}", .{s});
                continue;
            },
            .chord_names => |names| remap_mod.resolveChordTarget(allocator, names) catch |e| switch (e) {
                error.OutOfMemory => return e,
                error.ChordTooShort, error.ChordTooLong, error.DuplicateChordKey, error.UnknownKeyCode => {
                    std.log.warn("chord remap on {s} rejected: {s}", .{ entry.key_ptr.*, @errorName(e) });
                    continue;
                },
            },
            .gesture => |spec| remap_mod.resolveGestureTarget(allocator, spec) catch |e| switch (e) {
                error.OutOfMemory => return e,
                else => {
                    std.log.warn("gesture remap on {s} rejected: {s}", .{ entry.key_ptr.*, @errorName(e) });
                    continue;
                },
            },
        };
        result.suppress |= @as(u64, 1) << src_idx;
        result.inject[@intCast(src_idx)] = target;
    }
    return result;
}

fn buttonBit(name: []const u8) u64 {
    const id = std.meta.stringToEnum(ButtonId, name) orelse return 0;
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

fn checkGyroActivate(activate: ?[]const u8, buttons: u64) bool {
    const spec = activate orelse return true;
    if (std.mem.eql(u8, spec, "always")) return true;
    if (std.mem.startsWith(u8, spec, "hold_")) {
        const btn_name = spec["hold_".len..];
        return buttons & buttonBit(btn_name) != 0;
    }
    return buttons & buttonBit(spec) != 0;
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

test "mapper: resetRuntimeState clears transient layer timer and input state" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold_toggle"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    try m.layer.toggled.put("aim", {});
    _ = m.layer.onTriggerPressWithMode("aim", 200, 1_000, .hold_toggle);
    m.state.buttons = buttonBit("A");
    m.prev.buttons = buttonBit("A");
    m.seeded_buttons = buttonBit("A");
    m.pending_tap_release = buttonBit("B");
    m.macro_timer_tap_pending = buttonBit("X");
    m.gesture_timer_tap_pending = buttonBit("Y");
    m.gesture_held_gamepad = buttonBit("RB");
    m.aux_down_targets[@intFromEnum(ButtonId.A)] = .{ .key = 30 };
    try m.timer_queue.arm(2_000, 99, 1_000);

    m.resetRuntimeState();

    try testing.expect(m.layer.tap_hold == null);
    try testing.expectEqual(@as(usize, 0), m.layer.toggled.count());
    try testing.expect(std.meta.eql(GamepadState{}, m.state));
    try testing.expect(std.meta.eql(GamepadState{}, m.prev));
    try testing.expectEqual(@as(u64, 0), m.seeded_buttons);
    try testing.expectEqual(@as(?u64, null), m.pending_tap_release);
    try testing.expectEqual(@as(u64, 0), m.macro_timer_tap_pending);
    try testing.expectEqual(@as(u64, 0), m.gesture_timer_tap_pending);
    try testing.expectEqual(@as(u64, 0), m.gesture_held_gamepad);
    try testing.expect(m.aux_down_targets[@intFromEnum(ButtonId.A)] == null);
    try testing.expectEqual(@as(usize, 0), m.timer_queue.heap.count());
}

test "mapper: no layer no remap: apply passes through unchanged" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << a_idx)) != 0);
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "mapper: base remap disabled: source button suppressed" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);
    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << a_idx));
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "mapper: base remap key: source -> KEY_F13 aux event" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\M1 = "KEY_F13"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const m1_idx: u6 = @intCast(@intFromEnum(ButtonId.M1));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << m1_idx }, 16, 0);

    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << m1_idx));
    try testing.expectEqual(@as(usize, 1), events.aux.len);
    switch (events.aux.get(0)) {
        .key => |k| {
            try testing.expectEqual(@as(u16, 183), k.code); // KEY_F13
            try testing.expect(k.pressed);
        },
        else => return error.WrongEventType,
    }
}

test "mapper: releaseHeldAux releases old trigger-threshold aux down" {
    const allocator = testing.allocator;
    const old_parsed = try makeMapping(
        \\trigger_threshold = 128
        \\
        \\[remap]
        \\LT = "KEY_F13"
    , allocator);
    defer old_parsed.deinit();

    var old = try makeMapper(&old_parsed.value, allocator);
    defer old.deinit();
    const down = try old.apply(.{ .lt = 200 }, 16, 0);
    try testing.expectEqual(@as(usize, 1), down.aux.len);
    try testing.expect(down.aux.get(0).key.pressed);

    const release = old.releaseHeldAux();
    try testing.expectEqual(@as(usize, 1), release.len);
    try testing.expectEqual(@as(u16, 183), release.get(0).key.code);
    try testing.expect(!release.get(0).key.pressed);
}

test "mapper: base remap gamepad_button: A -> B" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);

    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << a_idx));
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << b_idx)) != 0);
    try testing.expectEqual(@as(usize, 0), events.aux.len);
}

test "mapper: layer remap overrides base: base A->B, layer A->C" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));

    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);

    // A suppressed
    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << a_idx));
    // B not injected (overridden by layer)
    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << b_idx));
    // X injected (layer remap wins)
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << x_idx)) != 0);
}

test "mapper: suppress accumulates: base suppress A + layer suppress B" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const both = (@as(u64, 1) << a_idx) | (@as(u64, 1) << b_idx);
    const events = try m.apply(.{ .buttons = both }, 16, 0);

    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << a_idx));
    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << b_idx));
}

test "mapper: inject last-write wins: layer inject overrides base inject for same button" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const y_idx: u6 = @intCast(@intFromEnum(ButtonId.Y));

    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);

    try testing.expectEqual(@as(u64, 0), events.gamepad.buttons & (@as(u64, 1) << x_idx));
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << y_idx)) != 0);
}

test "mapper: prev frame masking: suppress produces correct diff" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;

    // Frame N-1: A pressed, remap disabled
    const ev1 = try m.apply(.{ .buttons = a_mask }, 16, 0);
    // A is suppressed in output, prev is now raw a_mask
    try testing.expectEqual(@as(u64, 0), ev1.gamepad.buttons & a_mask);

    // Frame N: A still pressed — should produce no change (both masked_prev and gamepad have A=0)
    const ev2 = try m.apply(.{ .buttons = a_mask }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev2.gamepad.buttons & a_mask);
    // masked_prev should also have A=0 (same suppress applied)
    try testing.expectEqual(@as(u64, 0), ev2.prev.buttons & a_mask);
}

test "mapper: onLayerTimerExpired: PENDING -> ACTIVE activates layer" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // Timer fires — goes ACTIVE
    _ = m.onLayerTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Now layer remap should be active
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << b_idx)) != 0);
}

test "mapper: hold_toggle layer short tap emits tap without toggling" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\tap = "B"
        \\hold_timeout = 200
        \\
        \\[layer.remap]
        \\A = "X"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const b_mask: u64 = @as(u64, 1) << b_idx;

    _ = try m.apply(.{ .buttons = lt_mask }, 16, 0);
    const ev_tap = try m.apply(.{ .buttons = 0 }, 16, 100_000_000);

    try testing.expect((ev_tap.gamepad.buttons & b_mask) != 0);
    try testing.expect(!m.layer.toggled.contains("race"));
    try testing.expect(m.layer.getActive(parsed.value.layer.?) == null);
}

test "mapper: hold_toggle layer hold toggles sticky on and off" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\hold_timeout = 200
        \\
        \\[layer.remap]
        \\A = "X"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const x_mask: u64 = @as(u64, 1) << x_idx;

    _ = try m.apply(.{ .buttons = lt_mask }, 16, 0);
    _ = m.onLayerTimerExpired();
    try testing.expect(m.layer.toggled.contains("race"));
    try testing.expect(m.layer.tap_hold == null);

    _ = try m.apply(.{ .buttons = 0 }, 16, 250_000_000);
    try testing.expect(m.layer.toggled.contains("race"));

    const ev_layer = try m.apply(.{ .buttons = a_mask }, 16, 260_000_000);
    try testing.expectEqual(@as(u64, 0), ev_layer.gamepad.buttons & a_mask);
    try testing.expect((ev_layer.gamepad.buttons & x_mask) != 0);

    _ = try m.apply(.{ .buttons = lt_mask }, 16, 300_000_000);
    _ = m.onLayerTimerExpired();
    try testing.expect(!m.layer.toggled.contains("race"));

    _ = try m.apply(.{ .buttons = 0 }, 16, 550_000_000);
    const ev_base = try m.apply(.{ .buttons = a_mask }, 16, 560_000_000);
    try testing.expect((ev_base.gamepad.buttons & a_mask) != 0);
    try testing.expectEqual(@as(u64, 0), ev_base.gamepad.buttons & x_mask);
}

test "mapper: hold_toggle timer transition resets processors" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;

    m.gyro_proc.ema_x = 99.0;
    m.stick_left.mouse_accum_x = 1.25;
    m.stick_right.scroll_accum = -0.5;

    _ = try m.apply(.{ .buttons = lt_mask }, 16, 0);
    _ = m.onLayerTimerExpired();

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0), m.stick_left.mouse_accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_right.scroll_accum);
}

test "mapper: hold_toggle pending preserves macros but sticky transition cancels them" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\hold_timeout = 200
        \\
        \\[remap]
        \\M1 = "macro:hold_x"
        \\
        \\[[macro]]
        \\name = "hold_x"
        \\steps = [
        \\  { down = "X" },
        \\  { delay = 100000 },
        \\  { up = "X" },
        \\]
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const m1_idx: u6 = @intCast(@intFromEnum(ButtonId.M1));
    const m1_mask: u64 = @as(u64, 1) << m1_idx;
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const x_mask: u64 = @as(u64, 1) << x_idx;

    const ev_macro = try m.apply(.{ .buttons = m1_mask }, 16, 0);
    try testing.expect((ev_macro.gamepad.buttons & x_mask) != 0);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

    const ev_pending = try m.apply(.{ .buttons = m1_mask | lt_mask }, 16, 0);
    try testing.expect((ev_pending.gamepad.buttons & x_mask) != 0);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

    _ = m.onLayerTimerExpired();
    try testing.expectEqual(@as(usize, 0), m.active_macros.items.len);
    try testing.expect(m.layer.toggled.contains("race"));
}

test "mapper: hold_toggle sticky transition emits gamepad frame after macro cancel" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\hold_timeout = 200
        \\
        \\[remap]
        \\M1 = "macro:hold_x"
        \\
        \\[[macro]]
        \\name = "hold_x"
        \\steps = [
        \\  { down = "X" },
        \\  { delay = 100000 },
        \\  { up = "X" },
        \\]
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const m1_idx: u6 = @intCast(@intFromEnum(ButtonId.M1));
    const m1_mask: u64 = @as(u64, 1) << m1_idx;
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const x_mask: u64 = @as(u64, 1) << x_idx;

    _ = try m.apply(.{ .buttons = m1_mask }, 16, 0);
    const ev_pending = try m.apply(.{ .buttons = m1_mask | lt_mask }, 16, 0);
    try testing.expect((ev_pending.gamepad.buttons & x_mask) != 0);

    const timer_events = m.onLayerTimerExpiredAt(200_000_000);
    try testing.expect(timer_events.gamepad != null);
    try testing.expectEqual(@as(u64, 0), timer_events.gamepad.?.buttons & x_mask);
    try testing.expectEqual(@as(u64, 0), timer_events.gamepad.?.buttons & m1_mask);
    try testing.expectEqual(@as(u64, 0), timer_events.gamepad.?.buttons & lt_mask);
}

test "mapper: hold_toggle timer frame recomputes held source remaps" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "X"
        \\
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\hold_timeout = 200
        \\
        \\[layer.remap]
        \\A = "Y"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;
    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const x_mask: u64 = @as(u64, 1) << x_idx;
    const y_idx: u6 = @intCast(@intFromEnum(ButtonId.Y));
    const y_mask: u64 = @as(u64, 1) << y_idx;

    const ev_base = try m.apply(.{ .buttons = a_mask }, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev_base.gamepad.buttons & a_mask);
    try testing.expect((ev_base.gamepad.buttons & x_mask) != 0);
    try testing.expectEqual(@as(u64, 0), ev_base.gamepad.buttons & y_mask);

    _ = try m.apply(.{ .buttons = a_mask | lt_mask }, 16, 10_000_000);
    const timer_on = m.onLayerTimerExpiredAt(210_000_000);
    try testing.expect(timer_on.gamepad != null);
    try testing.expectEqual(@as(u64, 0), timer_on.gamepad.?.buttons & a_mask);
    try testing.expectEqual(@as(u64, 0), timer_on.gamepad.?.buttons & lt_mask);
    try testing.expectEqual(@as(u64, 0), timer_on.gamepad.?.buttons & x_mask);
    try testing.expect((timer_on.gamepad.?.buttons & y_mask) != 0);

    _ = try m.apply(.{ .buttons = a_mask }, 16, 220_000_000);
    _ = try m.apply(.{ .buttons = a_mask | lt_mask }, 16, 300_000_000);
    const timer_off = m.onLayerTimerExpiredAt(500_000_000);
    try testing.expect(timer_off.gamepad != null);
    try testing.expectEqual(@as(u64, 0), timer_off.gamepad.?.buttons & a_mask);
    try testing.expectEqual(@as(u64, 0), timer_off.gamepad.?.buttons & lt_mask);
    try testing.expect((timer_off.gamepad.?.buttons & x_mask) != 0);
    try testing.expectEqual(@as(u64, 0), timer_off.gamepad.?.buttons & y_mask);
}

test "mapper: hold_toggle timer frame preserves chord selector suppression" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "race"
        \\trigger = "LT"
        \\activation = "hold_toggle"
        \\hold_timeout = 200
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;
    const lm_idx: u6 = @intCast(@intFromEnum(ButtonId.LM));
    const lm_mask: u64 = @as(u64, 1) << lm_idx;
    const rm_idx: u6 = @intCast(@intFromEnum(ButtonId.RM));
    const rm_mask: u64 = @as(u64, 1) << rm_idx;
    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;

    var selectors: [chord_detector_mod.MAX_SELECTORS]u64 = [_]u64{0} ** chord_detector_mod.MAX_SELECTORS;
    selectors[0] = a_mask;
    m.setChordDetector(.{
        .modifier_mask = lm_mask | rm_mask,
        .selectors = selectors,
        .selector_count = 1,
        .hold_ns = 80 * std.time.ns_per_ms,
    });

    _ = try m.apply(.{ .buttons = lm_mask | rm_mask | a_mask }, 16, 0);
    _ = try m.apply(.{ .buttons = lm_mask | rm_mask | a_mask | lt_mask }, 16, 10_000_000);
    const timer_events = m.onLayerTimerExpiredAt(210_000_000);

    try testing.expect(timer_events.gamepad != null);
    try testing.expectEqual(@as(u64, 0), timer_events.gamepad.?.buttons & a_mask);
    try testing.expectEqual(@as(u64, 0), timer_events.gamepad.?.buttons & lt_mask);
    try testing.expect((timer_events.gamepad.?.buttons & lm_mask) != 0);
    try testing.expect((timer_events.gamepad.?.buttons & rm_mask) != 0);
}

test "mapper: layer gyro override: active layer gyro config used" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    // With layer active, gyro should be in mouse mode with the configured sensitivity
    const gcfg = m.effectiveGyroConfig();
    try testing.expectEqualStrings("mouse", gcfg.mode);
    try testing.expectApproxEqAbs(@as(f32, 100.0), gcfg.sensitivity_x, 1e-4);
}

test "mapper: layer dpad override: active layer dpad config used" {
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
    _ = m.layer.onTriggerPress(configs[0].name, 200, 0);
    _ = m.layer.onTimerExpired();

    const dcfg = m.effectiveDpadConfig();
    try testing.expectEqualStrings("arrows", dcfg.mode);
    try testing.expectEqual(@as(?bool, true), dcfg.suppress_gamepad);
}

test "mapper: dpad arrows layer: key events fire after hold-timer activation" {
    // Regression: when a hold-layer activates via timer (PENDING→ACTIVE), self.prev.dpad_x/y
    // retains the pressed value. Without the prev reset, processDpad sees curr==prev and
    // emits no edge. Fix: reset prev.dpad_x/y on active_changed.
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "nav"
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

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;

    // Frame 1: LT + dpad-up pressed simultaneously → layer PENDING, dpad recorded in prev
    _ = try m.apply(.{ .buttons = lt_mask, .dpad_y = -1 }, 16, 0);

    // Timer fires: PENDING → ACTIVE
    _ = m.onLayerTimerExpired();

    // Frame 2: still holding LT + dpad-up, but now layer is ACTIVE (active_changed=true)
    // prev.dpad_y should be reset to 0 so edge triggers KEY_UP press
    const configs = parsed.value.layer.?;
    _ = configs; // suppress unused warning
    const ev = try m.apply(.{ .buttons = lt_mask, .dpad_y = -1 }, 16, 0);

    var got_key_up = false;
    for (ev.aux.slice()) |e| switch (e) {
        .key => |k| if (k.code == c.KEY_UP and k.pressed) {
            got_key_up = true;
        },
        else => {},
    };
    try testing.expect(got_key_up);
}

test "mapper: gamepad_button tap: injected this frame, released next frame" {
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

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;

    // Press LT -> PENDING
    _ = try m.apply(.{ .buttons = lt_mask }, 16, 0);
    // Release LT -> tap fires (PENDING->IDLE with tap)
    const ev_tap = try m.apply(.{ .buttons = 0 }, 16, 0);
    // A should be injected this frame
    try testing.expect((ev_tap.gamepad.buttons & a_mask) != 0);
    try testing.expect(m.pending_tap_release != null);

    // Next frame: pending_tap_release should clear A
    const ev_release = try m.apply(.{}, 16, 0);
    try testing.expectEqual(@as(u64, 0), ev_release.gamepad.buttons & a_mask);
    try testing.expect(m.pending_tap_release == null);
}

test "mapper: dt_ms propagation: stick mouse output scales with dt" {
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
        const ev = try m4.apply(.{ .rx = 10000 }, 4, 0);
        for (ev.aux.slice()) |e| switch (e) {
            .rel => |r| if (r.code == 0) {
                total4 += r.value;
            },
            else => {},
        };
    }

    var total16: i32 = 0;
    const ev16 = try m16.apply(.{ .rx = 10000 }, 16, 0);
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

test "mapper: dpad prev mask: suppress_dpad_hat applied to masked_prev" {
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
    const ev1 = try m.apply(.{ .dpad_x = 0, .dpad_y = -1 }, 16, 0);
    try testing.expectEqual(@as(i8, 0), ev1.gamepad.dpad_y);

    // Frame 2: same dpad — masked_prev should also have dpad_y = 0
    const ev2 = try m.apply(.{ .dpad_x = 0, .dpad_y = -1 }, 16, 0);
    try testing.expectEqual(@as(i8, 0), ev2.prev.dpad_y);
}

test "mapper: checkGyroActivate: null always true" {
    try testing.expect(checkGyroActivate(null, 0));
    try testing.expect(checkGyroActivate(null, 0xFFFFFFFF));
}

test "mapper: checkGyroActivate: always always true" {
    try testing.expect(checkGyroActivate("always", 0));
}

test "mapper: checkGyroActivate: hold_RB pressed" {
    const rb_idx: u6 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u64 = @as(u64, 1) << rb_idx;
    try testing.expect(checkGyroActivate("hold_RB", rb_mask));
}

test "mapper: checkGyroActivate: hold_RB not pressed" {
    try testing.expect(!checkGyroActivate("hold_RB", 0));
}

test "mapper: checkGyroActivate: unknown button name returns false" {
    try testing.expect(!checkGyroActivate("hold_UNKNOWN", 0xFFFFFFFF));
}

test "mapper: checkGyroActivate: bare LS gates correctly" {
    const ls_idx: u6 = @intCast(@intFromEnum(ButtonId.LS));
    const ls_mask: u64 = @as(u64, 1) << ls_idx;
    // LS bit set → active
    try testing.expect(checkGyroActivate("LS", ls_mask));
    // LS bit clear → inactive
    try testing.expect(!checkGyroActivate("LS", 0));
    // Other button set, LS clear → inactive
    const rb_idx: u6 = @intCast(@intFromEnum(ButtonId.RB));
    try testing.expect(!checkGyroActivate("LS", @as(u64, 1) << rb_idx));
}

test "mapper: checkGyroActivate: bare LT gates correctly" {
    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    try testing.expect(checkGyroActivate("LT", lt_mask));
    try testing.expect(!checkGyroActivate("LT", 0));
}

test "mapper: checkGyroActivate: bogus bare name returns false (not true)" {
    // Regression: before fix this returned true, making gyro always-on.
    try testing.expect(!checkGyroActivate("BOGUS_NOT_A_BUTTON", 0xFFFFFFFF));
}

test "e2e: gyro activate bare LS — no output when LS not pressed, output when pressed" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "LS"
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const ls_idx: u6 = @intCast(@intFromEnum(ButtonId.LS));
    const ls_mask: u64 = @as(u64, 1) << ls_idx;

    // LS not pressed → no gyro output
    const ev_off = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev_off.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };

    // LS pressed → gyro output
    const ev_on = try m.apply(.{ .buttons = ls_mask, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    var has_rel = false;
    for (ev_on.aux.slice()) |e| switch (e) {
        .rel => {
            has_rel = true;
        },
        else => {},
    };
    try testing.expect(has_rel);

    // LS released → gyro output stops
    const ev_off2 = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev_off2.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };
}

test "e2e: gyro activate bare LT — gated through trigger_threshold LT synthesis" {
    // End-to-end: the analog LT axis crossing trigger_threshold synthesizes the
    // LT button bit, which the bare-name activate gate then consumes.
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\trigger_threshold = 128
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "LT"
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // LT below threshold → no LT bit synthesized → gyro gated off
    const ev_off = try m.apply(.{ .lt = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev_off.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };

    // LT above threshold → LT bit synthesized → gyro fires
    const ev_on = try m.apply(.{ .lt = 200, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    var has_rel = false;
    for (ev_on.aux.slice()) |e| switch (e) {
        .rel => {
            has_rel = true;
        },
        else => {},
    };
    try testing.expect(has_rel);
}

test "e2e: gyro activate bogus name — gyro always disabled" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "BOGUS_NOT_A_BUTTON"
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Even with all bits set, unknown name resolves to 0 via buttonBit → gyro off
    const ev = try m.apply(.{ .buttons = 0xFFFFFFFFFFFFFFFF, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };
}

test "e2e: gyro activate hold_LT no trigger_threshold — LT bit never synthesized, gyro stays off" {
    // Documents the analog-trigger trap: without trigger_threshold the LT bit is
    // never set in buttons, so hold_LT (and bare LT) never fires.
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "mouse"
        \\sensitivity = 1000.0
        \\smoothing = 0.0
        \\activate = "hold_LT"
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // Simulate LT axis fully pressed (lt=255) but no trigger_threshold → bit never set
    const ev = try m.apply(.{ .lt = 255, .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    for (ev.aux.slice()) |e| switch (e) {
        .rel => return error.UnexpectedRelEvent,
        else => {},
    };
}

// --- OOM path tests ---

test "mapper: Mapper.apply toggle OOM is silently swallowed" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\activation = "toggle"
    , allocator);
    defer parsed.deinit();
    // Failing allocator: Mapper.init needs 1 alloc (resolved_layers); second alloc fails on toggled.put.
    var fa = testing.FailingAllocator.init(allocator, .{ .fail_index = 1 });
    var m = try Mapper.init(&parsed.value, std.posix.STDIN_FILENO, fa.allocator());
    defer m.deinit();
    const sel_idx: u6 = @intCast(@intFromEnum(ButtonId.Select));
    const sel_mask: u64 = @as(u64, 1) << sel_idx;
    // Rising edge then release — toggle fires, toggled.put OOMs silently.
    _ = try m.apply(.{ .buttons = sel_mask }, 16, 0);
    _ = try m.apply(.{}, 16, 0);
    // Mapper must stay usable: third frame must produce no-crash and empty aux events.
    const ev = try m.apply(.{}, 16, 0);
    try testing.expectEqual(@as(usize, 0), ev.aux.len);
}

test "mapper: TimerQueue.arm OOM returns error" {
    var fa = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var q = TimerQueue.init(fa.allocator(), -1);
    defer q.deinit();
    try testing.expectError(error.OutOfMemory, q.arm(1000, 1, 0));
}

test "mapper: active_macros append OOM is silently ignored" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[macro]]
        \\name = "boom"
        \\steps = [{ tap = "KEY_A" }]
        \\[remap]
        \\A = "macro:boom"
    , allocator);
    defer parsed.deinit();
    // Use failing allocator starting at index 2 to let Mapper.init succeed,
    // then fail on the first active_macros.append during apply.
    var fa = testing.FailingAllocator.init(allocator, .{ .fail_index = 2 });
    var m = try Mapper.init(&parsed.value, std.posix.STDIN_FILENO, fa.allocator());
    defer m.deinit();
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    // Rising edge triggers macro dispatch; append failure must not crash.
    const ev = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);
    // OOM swallowed: no aux events emitted (macro not started), A suppressed by remap.
    const a_mask: u64 = @as(u64, 1) << a_idx;
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & a_mask);
}

// --- AuxEventList overflow tests ---

test "mapper: AuxEventList 64-item fill succeeds, 65th returns Overflow" {
    var list = AuxEventList{};
    for (0..64) |_| {
        try list.append(.{ .rel = .{ .code = 0, .value = 1 } });
    }
    try testing.expectEqual(@as(usize, 64), list.len);
    try testing.expectError(error.Overflow, list.append(.{ .rel = .{ .code = 0, .value = 1 } }));
}

test "mapper: AuxEventList empty slice returns zero length" {
    const list = AuxEventList{};
    try testing.expectEqual(@as(usize, 0), list.slice().len);
}

test "mapper: gyro activate: inactive frame no REL events and processor reset" {
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
    const rb_idx: u6 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u64 = @as(u64, 1) << rb_idx;
    _ = try m.apply(.{ .buttons = rb_mask, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);

    // Release RB — gyro should be deactivated, processor reset, no REL events
    const ev = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    try testing.expectEqual(@as(usize, 0), ev.aux.len);
    // After reset, EMA should be zero
    try testing.expectApproxEqAbs(@as(f32, 0.0), m.gyro_proc.ema_x, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), m.gyro_proc.ema_y, 1e-5);
}

test "mapper: gyro activate: active when RB held, inactive when released" {
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

    const rb_idx: u6 = @intCast(@intFromEnum(ButtonId.RB));
    const rb_mask: u64 = @as(u64, 1) << rb_idx;

    // RB held, large gyro — should produce REL events
    const ev_active = try m.apply(.{ .buttons = rb_mask, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    try testing.expect(ev_active.aux.len > 0);
    // At least one REL event must be present (not just any aux event)
    var found_rel = false;
    for (ev_active.aux.slice()) |e| {
        if (e == .rel) found_rel = true;
    }
    try testing.expect(found_rel);

    // RB released — no REL events
    const ev_inactive = try m.apply(.{ .buttons = 0, .gyro_x = 10000, .gyro_y = 10000 }, 16, 0);
    try testing.expectEqual(@as(usize, 0), ev_inactive.aux.len);
}

test "mapper: gyro joystick mode: overrides emit_state.rx/ry, suppresses original axes" {
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
    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 5000, .ry = 5000 }, 16, 0);

    // rx/ry must be gyro-derived (not the raw 5000)
    try testing.expect(ev.gamepad.rx != 5000);
    try testing.expect(ev.gamepad.ry != 5000);
    // With gyro_x=+10000 (positive), joystick rx should be non-negative (same direction)
    try testing.expect(ev.gamepad.rx >= 0);
    // No aux REL events from gyro (joystick mode emits no mouse events)
    for (ev.aux.slice()) |e| {
        switch (e) {
            .rel => return error.UnexpectedRelEvent,
            else => {},
        }
    }
}

test "mapper: gyro joystick mode: null joy_x does not touch rx" {
    const allocator = testing.allocator;
    // mode=off → process() returns joy_x=null, joy_y=null
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "off"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const ev = try m.apply(.{ .rx = 1234, .ry = -1234 }, 16, 0);
    // mode=off: no override, axes pass through unchanged
    try testing.expectEqual(@as(i16, 1234), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, -1234), ev.gamepad.ry);
}

test "mapper: gyro mouse mode: joy_x/y do not affect emit_state axes" {
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

    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 999, .ry = 888 }, 16, 0);
    // mouse mode: rx/ry must be untouched (suppress_right_stick_gyro stays false)
    try testing.expectEqual(@as(i16, 999), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, 888), ev.gamepad.ry);
}

test "mapper: gyro blend_stick=false: output equals pure gyro value (zero-regression)" {
    // Falsifiable: would FAIL if the default (override) path were replaced with additive logic.
    // Non-saturating constants (sensitivity 1.0, gyro 10000) so pure-gyro and physical+gyro
    // are numerically distinct (neither clamped to 32767), mirroring the fixed blend_stick=true test.
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\blend_stick = false
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const physical_rx: i16 = 5000;
    const physical_ry: i16 = -3000;
    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = physical_rx, .ry = physical_ry }, 16, 0);

    // Derive the pure gyro_joy value from a second mapper fed ZERO physical rx/ry but the
    // same gyro input: with no physical contribution its output IS the pure gyro joystick value.
    var m_pure = try makeMapper(&parsed.value, allocator);
    defer m_pure.deinit();
    const ev_pure = try m_pure.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 0, .ry = 0 }, 16, 0);
    const gyro_joy_x = ev_pure.gamepad.rx;
    const gyro_joy_y = ev_pure.gamepad.ry;

    // Pure-gyro must be non-saturating and non-zero, else the override/additive distinction
    // would be vacuous (both would clamp to the same value).
    try testing.expect(gyro_joy_x != 0 and gyro_joy_x != 32767 and gyro_joy_x != -32767);
    try testing.expect(gyro_joy_y != 0 and gyro_joy_y != 32767 and gyro_joy_y != -32767);

    // blend_stick=false must override: output == pure gyro_joy exactly, discarding physical.
    try testing.expectEqual(gyro_joy_x, ev.gamepad.rx);
    try testing.expectEqual(gyro_joy_y, ev.gamepad.ry);

    // And it must NOT be the additive (blend) result clamp(physical + gyro_joy).
    const additive_rx = @as(i16, @intCast(std.math.clamp(
        @as(i32, physical_rx) + @as(i32, gyro_joy_x),
        -32767,
        32767,
    )));
    const additive_ry = @as(i16, @intCast(std.math.clamp(
        @as(i32, physical_ry) + @as(i32, gyro_joy_y),
        -32767,
        32767,
    )));
    try testing.expect(additive_rx != gyro_joy_x);
    try testing.expect(additive_ry != gyro_joy_y);
    try testing.expect(ev.gamepad.rx != additive_rx);
    try testing.expect(ev.gamepad.ry != additive_ry);
    // Override discards physical entirely, so output must also differ from physical.
    try testing.expect(ev.gamepad.rx != physical_rx);
    try testing.expect(ev.gamepad.ry != physical_ry);
}

test "mapper: gyro blend_stick omitted(null) == explicit false (ADR-018 absent invariant)" {
    // Pins the `mc.blend_stick orelse false` default contract: a [gyro] config with NO
    // blend_stick line (TOML omits it -> null) must behave byte-identically to explicit
    // blend_stick = false. Falsifiable: would FAIL if the default were `orelse true`
    // (omitted path would then blend physical+gyro and diverge from explicit-false override).
    const allocator = testing.allocator;
    const parsed_false = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\blend_stick = false
    , allocator);
    defer parsed_false.deinit();

    // Identical [gyro] config but with the blend_stick line entirely OMITTED -> null.
    const parsed_omitted = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
    , allocator);
    defer parsed_omitted.deinit();

    var m_false = try makeMapper(&parsed_false.value, allocator);
    defer m_false.deinit();
    var m_omitted = try makeMapper(&parsed_omitted.value, allocator);
    defer m_omitted.deinit();

    // Non-saturating gyro + non-zero physical so blend (if wrongly defaulted true) would
    // produce clamp(physical + gyro) != pure-gyro override, making the paths distinguishable.
    const physical_rx: i16 = 5000;
    const physical_ry: i16 = -3000;
    const delta: GamepadStateDelta = .{ .gyro_x = 10000, .gyro_y = 10000, .rx = physical_rx, .ry = physical_ry };

    const ev_false = try m_false.apply(delta, 16, 0);
    const ev_omitted = try m_omitted.apply(delta, 16, 0);

    // Sanity: explicit-false is the pure-gyro override (discards physical, non-saturating).
    try testing.expect(ev_false.gamepad.rx != 0 and ev_false.gamepad.rx != 32767 and ev_false.gamepad.rx != -32767);
    try testing.expect(ev_false.gamepad.rx != physical_rx and ev_false.gamepad.ry != physical_ry);

    // The null-default contract: omitted blend_stick == explicit false, byte-identical.
    try testing.expectEqual(ev_false.gamepad.rx, ev_omitted.gamepad.rx);
    try testing.expectEqual(ev_false.gamepad.ry, ev_omitted.gamepad.ry);
}

test "mapper: gyro blend_stick=true: output equals clamp(physical + gyro, -32767, 32767)" {
    // Falsifiable: would FAIL if blend_stick were not applied (pure override gives a different value).
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\blend_stick = true
    , allocator);
    defer parsed.deinit();

    // Also get the override (blend=false) result so we can assert blend != override.
    const parsed_no_blend = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1.0
        \\sensitivity_y = 1.0
        \\smoothing = 0.0
        \\blend_stick = false
    , allocator);
    defer parsed_no_blend.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();
    var m_no = try makeMapper(&parsed_no_blend.value, allocator);
    defer m_no.deinit();

    // sensitivity 1.0 * gyro 10000 -> gyro_joy ~= 6103 (non-saturated), so
    // physical +/-1000 + gyro_joy stays in range and differs from gyro_joy alone.
    const physical_rx: i16 = 1000;
    const physical_ry: i16 = -1000;
    const delta: GamepadStateDelta = .{ .gyro_x = 10000, .gyro_y = 10000, .rx = physical_rx, .ry = physical_ry };

    const ev_blend = try m.apply(delta, 16, 0);
    const ev_override = try m_no.apply(delta, 16, 0);

    // Blend output must differ from pure override (gyro value alone).
    try testing.expect(ev_blend.gamepad.rx != ev_override.gamepad.rx);
    // Blend output = clamp(physical + gyro_joy).  gyro_joy == ev_override result.
    const expected_rx = @as(i16, @intCast(std.math.clamp(
        @as(i32, physical_rx) + @as(i32, ev_override.gamepad.rx),
        -32767,
        32767,
    )));
    const expected_ry = @as(i16, @intCast(std.math.clamp(
        @as(i32, physical_ry) + @as(i32, ev_override.gamepad.ry),
        -32767,
        32767,
    )));
    try testing.expectEqual(expected_rx, ev_blend.gamepad.rx);
    try testing.expectEqual(expected_ry, ev_blend.gamepad.ry);
}

test "mapper: gyro blend_stick=true: full-deflection clamp boundary" {
    // Falsifiable: would FAIL if saturation clamp were absent (overflow or wrong value).
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[gyro]
        \\mode = "joystick"
        \\sensitivity_x = 1000.0
        \\sensitivity_y = 1000.0
        \\smoothing = 0.0
        \\blend_stick = true
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // physical = +32767 (full deflection), positive gyro → sum exceeds i16 max → must clamp to 32767.
    const ev = try m.apply(.{ .gyro_x = 10000, .gyro_y = 10000, .rx = 32767, .ry = 32767 }, 16, 0);
    try testing.expectEqual(@as(i16, 32767), ev.gamepad.rx);
    try testing.expectEqual(@as(i16, 32767), ev.gamepad.ry);
}

test "mapper: layer switch resets gyro EMA and accumulators" {
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
    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    _ = try m.apply(.{ .buttons = lt_mask }, 16, 0);

    // Timer fires → ACTIVE (active_changed = true inside onLayerTimerExpired, but processLayerTriggers
    // sets active_changed on press too — here we drive it through the full path)
    _ = m.onLayerTimerExpired();
    // Manually trigger a frame that will see active_changed via release
    // Instead: drive through processLayerTriggers which sets active_changed on ACTIVE→IDLE release
    // For simplicity: re-dirty the processor and then release LT to deactivate
    m.gyro_proc.ema_x = 500.0;
    m.gyro_proc.accum_x = 0.7;
    m.stick_left.mouse_accum_x = 1.5;
    m.stick_right.scroll_accum = 0.9;

    // LT release → layer deactivates → active_changed = true → reset fires
    _ = try m.apply(.{ .buttons = 0 }, 16, 0);

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0), m.gyro_proc.accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_left.mouse_accum_x);
    try testing.expectEqual(@as(f32, 0), m.stick_right.scroll_accum);
}

test "mapper: no layer switch — processor state preserved" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    m.gyro_proc.ema_x = 42.0;
    m.stick_left.mouse_accum_x = 0.6;

    _ = try m.apply(.{}, 16, 0);

    // No layer change: state must not be reset
    try testing.expectEqual(@as(f32, 42.0), m.gyro_proc.ema_x);
    try testing.expectEqual(@as(f32, 0.6), m.stick_left.mouse_accum_x);
}

test "mapper: toggle layer switch resets processors" {
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

    const sel_idx: u6 = @intCast(@intFromEnum(ButtonId.Select));
    const sel_mask: u64 = @as(u64, 1) << sel_idx;

    // Frame 1: Select pressed (rising edge only, toggle fires on release)
    _ = try m.apply(.{ .buttons = sel_mask }, 16, 0);

    // Dirty processor state to simulate residual accumulation
    m.gyro_proc.ema_y = -200.0;
    m.stick_right.mouse_accum_y = 0.8;

    // Frame 2: Select released → toggle fires → active_changed = true → reset
    _ = try m.apply(.{ .buttons = 0 }, 16, 0);

    try testing.expectEqual(@as(f32, 0), m.gyro_proc.ema_y);
    try testing.expectEqual(@as(f32, 0), m.stick_right.mouse_accum_y);
}

// --- REL event code and sign verification ---

test "mapper: gyro mouse REL events carry REL_X/REL_Y codes" {
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

    // Positive gyro input → REL_X and REL_Y events with matching codes and positive values.
    const ev = try m.apply(.{ .gyro_x = 20000, .gyro_y = 20000 }, 16, 0);

    var rel_x_value: ?i32 = null;
    var rel_y_value: ?i32 = null;
    for (ev.aux.slice()) |e| switch (e) {
        .rel => |r| {
            if (r.code == REL_X) rel_x_value = r.value;
            if (r.code == REL_Y) rel_y_value = r.value;
        },
        else => {},
    };

    try testing.expect(rel_x_value != null);
    try testing.expect(rel_y_value != null);
    try testing.expect(rel_x_value.? > 0);
    try testing.expect(rel_y_value.? > 0);
}

test "mapper: gyro mouse REL sign follows gyro input sign" {
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

    const ev = try m.apply(.{ .gyro_x = -20000, .gyro_y = -20000 }, 16, 0);

    var rel_x_value: ?i32 = null;
    var rel_y_value: ?i32 = null;
    for (ev.aux.slice()) |e| switch (e) {
        .rel => |r| {
            if (r.code == REL_X) rel_x_value = r.value;
            if (r.code == REL_Y) rel_y_value = r.value;
        },
        else => {},
    };

    try testing.expect(rel_x_value != null);
    try testing.expect(rel_y_value != null);
    try testing.expect(rel_x_value.? < 0);
    try testing.expect(rel_y_value.? < 0);
}

test "mapper: stick scroll REL_WHEEL and REL_HWHEEL codes verified" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[stick.right]
        \\mode = "scroll"
        \\deadzone = 0
        \\sensitivity = 100.0
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // ry < 0 = stick up → REL_WHEEL > 0 (scroll up); rx > 0 → REL_HWHEEL > 0
    var wheel_value: i32 = 0;
    var hwheel_value: i32 = 0;
    for (0..30) |_| {
        const ev = try m.apply(.{ .rx = 32000, .ry = -32000 }, 16, 0);
        for (ev.aux.slice()) |e| switch (e) {
            .rel => |r| {
                if (r.code == REL_WHEEL) wheel_value += r.value;
                if (r.code == REL_HWHEEL) hwheel_value += r.value;
            },
            else => {},
        };
    }

    try testing.expect(wheel_value > 0);
    try testing.expect(hwheel_value > 0);
}

test "mapper: stick scroll positive ry gives negative REL_WHEEL values" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[stick.right]
        \\mode = "scroll"
        \\deadzone = 0
        \\sensitivity = 100.0
    , allocator);
    defer parsed.deinit();
    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    // ry > 0 = stick down → REL_WHEEL < 0 (scroll down)
    var wheel_value: i32 = 0;
    for (0..30) |_| {
        const ev = try m.apply(.{ .rx = 0, .ry = 32000 }, 16, 0);
        for (ev.aux.slice()) |e| switch (e) {
            .rel => |r| if (r.code == REL_WHEEL) {
                wheel_value += r.value;
            },
            else => {},
        };
    }

    try testing.expect(wheel_value < 0);
}

test "mapper: invalid remap target does not suppress source button" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "INVALID_TARGET_XYZ"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const events = try m.apply(.{ .buttons = @as(u64, 1) << a_idx }, 16, 0);
    // A must still pass through — bad target must not suppress the source
    try testing.expect((events.gamepad.buttons & (@as(u64, 1) << a_idx)) != 0);
}

test "mapper: trigger_threshold: lt above threshold sets LT button" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\trigger_threshold = 128
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.LT));
    const rt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.RT));

    const events = try m.apply(.{ .lt = 200, .rt = 50 }, 16, 0);
    try testing.expect((events.gamepad.buttons & lt_bit) != 0);
    try testing.expect((events.gamepad.buttons & rt_bit) == 0);
}

test "mapper: trigger_threshold: null threshold does not synthesize buttons" {
    const allocator = testing.allocator;
    const parsed = try makeMapping("", allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.LT));

    const events = try m.apply(.{ .lt = 200 }, 16, 0);
    try testing.expect((events.gamepad.buttons & lt_bit) == 0);
}

test "mapper: trigger_threshold: boundary — equal to threshold does not trigger" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\trigger_threshold = 128
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.LT));

    // lt == threshold: should NOT trigger (strictly greater required)
    const e1 = try m.apply(.{ .lt = 128 }, 16, 0);
    try testing.expect((e1.gamepad.buttons & lt_bit) == 0);

    // lt == threshold + 1: should trigger
    const e2 = try m.apply(.{ .lt = 129 }, 16, 0);
    try testing.expect((e2.gamepad.buttons & lt_bit) != 0);
}

test "mapper: trigger_threshold: release clears button bit" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\trigger_threshold = 128
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_bit = @as(u64, 1) << @intCast(@intFromEnum(ButtonId.LT));

    const e1 = try m.apply(.{ .lt = 200 }, 16, 0);
    try testing.expect((e1.gamepad.buttons & lt_bit) != 0);

    const e2 = try m.apply(.{ .lt = 50 }, 16, 0);
    try testing.expect((e2.gamepad.buttons & lt_bit) == 0);
}

test "mapper: precomputed remap table has correct values after init" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
        \\M1 = "KEY_F13"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\
        \\[layer.remap]
        \\X = "disabled"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: usize = @intFromEnum(ButtonId.A);
    const m1_idx: usize = @intFromEnum(ButtonId.M1);
    const x_idx: usize = @intFromEnum(ButtonId.X);

    // base remap: A -> B (gamepad_button), M1 -> KEY_F13 (key)
    const a_mask: u64 = @as(u64, 1) << @as(u6, @intCast(a_idx));
    try testing.expect(m.resolved_base.suppress & a_mask != 0);
    try testing.expect(m.resolved_base.inject[a_idx] != null);
    switch (m.resolved_base.inject[a_idx].?) {
        .gamepad_button => |dst| try testing.expectEqual(ButtonId.B, dst),
        else => return error.WrongTargetType,
    }
    const m1_mask: u64 = @as(u64, 1) << @as(u6, @intCast(m1_idx));
    try testing.expect(m.resolved_base.suppress & m1_mask != 0);
    switch (m.resolved_base.inject[m1_idx].?) {
        .key => |code| try testing.expectEqual(@as(u16, 183), code), // KEY_F13
        else => return error.WrongTargetType,
    }

    // layer remap: X -> disabled
    try testing.expectEqual(@as(usize, 1), m.resolved_layers.len);
    const x_mask: u64 = @as(u64, 1) << @as(u6, @intCast(x_idx));
    try testing.expect(m.resolved_layers[0].suppress & x_mask != 0);
    switch (m.resolved_layers[0].inject[x_idx].?) {
        .disabled => {},
        else => return error.WrongTargetType,
    }
}

test "mapper: 1000 apply frames with remap produce stable output (no per-frame string work)" {
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[remap]
        \\A = "B"
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const b_idx: u6 = @intCast(@intFromEnum(ButtonId.B));
    const a_mask: u64 = @as(u64, 1) << a_idx;
    const b_mask: u64 = @as(u64, 1) << b_idx;

    // Run 1000 frames; each must produce A suppressed and B injected.
    for (0..1000) |frame| {
        const ev = try m.apply(.{ .buttons = a_mask }, 16, @intCast(frame));
        try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & a_mask);
        try testing.expect(ev.gamepad.buttons & b_mask != 0);
    }
}

test "mapper: dual-ready ppoll — apply uses caller now_ns, tap fires at press+195ms" {
    // On a single ppoll wakeup the timerfd (promote PENDING → ACTIVE) and
    // the device fd (release) can both be ready. If apply() re-read
    // CLOCK_MONOTONIC internally after the timer handler ran, the drift would
    // push a 195ms physical tap past the 200ms hold_timeout. The caller
    // snapshots `now` once and threads it through both onTimerExpired and apply.
    const allocator = testing.allocator;
    const parsed = try makeMapping(
        \\[[layer]]
        \\name = "fps"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "A"
        \\hold_timeout = 200
    , allocator);
    defer parsed.deinit();

    var m = try makeMapper(&parsed.value, allocator);
    defer m.deinit();

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;

    // Frame 1: press at t=0 → PENDING
    const press_ns: i128 = 1_000_000_000;
    _ = try m.apply(.{ .buttons = lt_mask }, 16, press_ns);

    // Timer fires at t=200ms → ACTIVE
    _ = m.onLayerTimerExpired();
    try testing.expect(m.layer.tap_hold.?.layer_activated);

    // Frame 2: release observed on the same ppoll wakeup as the timer,
    // but the caller-supplied snapshot is the physical release instant
    // (t=195ms — below hold_timeout). The race-case branch must still
    // emit the tap.
    const release_ns: i128 = press_ns + 195_000_000;
    const ev_tap = try m.apply(.{ .buttons = 0 }, 16, release_ns);
    try testing.expect((ev_tap.gamepad.buttons & a_mask) != 0);
    try testing.expect(m.pending_tap_release != null);

    // Next frame clears the injected tap release.
    const ev_clear = try m.apply(.{}, 16, release_ns + 1_000_000);
    try testing.expectEqual(@as(u64, 0), ev_clear.gamepad.buttons & a_mask);
}

test "mapper: timing boundary sweep — tap fires via .pending branch iff release_ns < hold_timeout_ns" {
    // 7 release_delta × 3 press bases = 21 cases.
    //
    // Falsifiability: the tap-fires cases (delta < 200) release the trigger
    // while the hold timer is STILL PENDING — the timer is never manually
    // expired, so onTriggerRelease takes the `.pending` branch.
    // A `macro:hold_x` runs in parallel: a spurious active_changed reset on
    // the PENDING-press frame calls emitPendingReleases +
    // active_macros.clearRetainingCapacity, dropping the held X gamepad bit
    // and the active macro. We assert both on the PENDING-press frame, so
    // re-adding the mutation is visible.
    //
    // The held-past-hold_timeout cases (delta >= 200) DO expire the timer
    // first → onTriggerRelease takes the legitimate `.active` branch → no tap.
    const allocator = testing.allocator;

    const lt_idx: u6 = @intCast(@intFromEnum(ButtonId.LT));
    const lt_mask: u64 = @as(u64, 1) << lt_idx;
    const m1_idx: u6 = @intCast(@intFromEnum(ButtonId.M1));
    const m1_mask: u64 = @as(u64, 1) << m1_idx;
    const a_idx: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_idx;
    const x_idx: u6 = @intCast(@intFromEnum(ButtonId.X));
    const x_mask: u64 = @as(u64, 1) << x_idx;

    const release_deltas_ms = [_]u64{ 1, 50, 100, 195, 199, 200, 201 };
    const press_bases: [3]i128 = .{ 0xA000_0000, 0xB000_0000, 0xC000_0000 };

    for (press_bases) |press_ns| {
        for (release_deltas_ms) |delta_ms| {
            const parsed = try makeMapping(
                \\[[layer]]
                \\name = "fps"
                \\trigger = "LT"
                \\activation = "hold"
                \\tap = "A"
                \\hold_timeout = 200
                \\
                \\[remap]
                \\M1 = "macro:hold_x"
                \\
                \\[[macro]]
                \\name = "hold_x"
                \\steps = [
                \\  { down = "X" },
                \\  { delay = 100000 },
                \\  { up = "X" },
                \\]
            , allocator);
            defer parsed.deinit();

            var m = try makeMapper(&parsed.value, allocator);
            defer m.deinit();

            // Frame A: press M1 → macro arms, X held across the long delay.
            const ev_macro = try m.apply(.{ .buttons = m1_mask }, 16, press_ns);
            try testing.expect((ev_macro.gamepad.buttons & x_mask) != 0);
            try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

            // Frame B: press LT while M1 still held → Hold PENDING entry.
            // The macro must survive (no spurious active_changed reset); with
            // the mutation re-added the reset cancels the macro and drops the X bit.
            const ev_pending = try m.apply(.{ .buttons = m1_mask | lt_mask }, 16, press_ns);
            try testing.expect((ev_pending.gamepad.buttons & x_mask) != 0);
            try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

            const release_ns: i128 = press_ns + @as(i128, delta_ms) * 1_000_000;

            if (delta_ms < 200) {
                // Race-case: release LT while the hold timer is STILL PENDING
                // (timer never expired) → `.pending` branch must emit the tap.
                const ev_tap = try m.apply(.{ .buttons = m1_mask }, 16, release_ns);
                try testing.expect((ev_tap.gamepad.buttons & a_mask) != 0);
                // Macro state must have survived the whole race window.
                try testing.expect((ev_tap.gamepad.buttons & x_mask) != 0);
                try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);
            } else {
                // Held past hold_timeout: expire the timer first → ACTIVE,
                // release takes the `.active` branch → no tap.
                _ = m.onLayerTimerExpired();
                const ev_hold = try m.apply(.{ .buttons = m1_mask }, 16, release_ns);
                try testing.expectEqual(@as(u64, 0), ev_hold.gamepad.buttons & a_mask);
            }
        }
    }
}
