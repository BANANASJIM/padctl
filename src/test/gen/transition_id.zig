const std = @import("std");
const state = @import("../../core/state.zig");
const mapping = @import("../../config/mapping.zig");

const ButtonId = state.ButtonId;
const GamepadStateDelta = state.GamepadStateDelta;
const OracleState = @import("mapper_oracle.zig").OracleState;

pub const TransitionId = enum {
    // Layer
    layer_idle_to_pending,
    layer_pending_to_active,
    layer_pending_to_idle_tap,
    layer_active_to_idle,
    layer_toggle_on,
    layer_toggle_off,
    layer_mutual_exclusion_blocked,

    // Remap
    remap_suppress_button,
    remap_inject_key,
    remap_inject_mouse,
    remap_inject_gamepad,
    remap_layer_override,

    // Macro
    macro_triggered,
    macro_cancelled_by_layer,

    // Gyro
    gyro_activated,
    gyro_deactivated,

    // Dpad
    dpad_arrows_emit,
    dpad_gamepad_passthrough,

    // Tap
    tap_event_emitted,

    // Cross-subsystem
    button_held_across_layer_switch,

    // Stress
    simultaneous_multi_button,
    all_buttons_pressed,
    rapid_layer_toggle,
};

const field_count = @typeInfo(TransitionId).@"enum".fields.len;

pub const CoverageTracker = struct {
    seen: [field_count]bool = [_]bool{false} ** field_count,

    pub fn mark(self: *CoverageTracker, id: TransitionId) void {
        self.seen[@intFromEnum(id)] = true;
    }

    pub fn coverage(self: *const CoverageTracker) struct { seen: usize, total: usize } {
        var count: usize = 0;
        for (self.seen) |s| {
            if (s) count += 1;
        }
        return .{ .seen = count, .total = field_count };
    }

    pub fn missing(self: *const CoverageTracker, buf: []TransitionId) []const TransitionId {
        var n: usize = 0;
        for (self.seen, 0..) |s, i| {
            if (!s and n < buf.len) {
                buf[n] = @enumFromInt(i);
                n += 1;
            }
        }
        return buf[0..n];
    }
};

fn btnMask(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

fn btnMaskByName(name: []const u8) u64 {
    const id = std.meta.stringToEnum(ButtonId, name) orelse return 0;
    return btnMask(id);
}

pub fn classify(
    tracker: *CoverageTracker,
    prev_os: *const OracleState,
    cur_os: *const OracleState,
    delta: GamepadStateDelta,
    cfg: *const mapping.MappingConfig,
) void {
    const buttons = delta.buttons orelse cur_os.gs.buttons;
    const prev_buttons = prev_os.prev_buttons;

    // Layer hold FSM transitions
    if (prev_os.hold_phase != cur_os.hold_phase) {
        switch (cur_os.hold_phase) {
            .pending => tracker.mark(.layer_idle_to_pending),
            .active => tracker.mark(.layer_pending_to_active),
            .idle => {
                if (prev_os.hold_phase == .pending)
                    tracker.mark(.layer_pending_to_idle_tap)
                else
                    tracker.mark(.layer_active_to_idle);
            },
        }
    }

    // Toggle transitions
    for (prev_os.toggled, cur_os.toggled) |prev_t, cur_t| {
        if (!prev_t and cur_t) tracker.mark(.layer_toggle_on);
        if (prev_t and !cur_t) tracker.mark(.layer_toggle_off);
    }

    // Tap event
    if (cur_os.pending_tap_release != null and prev_os.pending_tap_release == null)
        tracker.mark(.tap_event_emitted);

    // Remap classification: only fire when a remapped source button is actually pressed
    if (cfg.remap) |remap_map| {
        var has_pressed_remap = false;
        var it = remap_map.map.iterator();
        while (it.next()) |entry| {
            const src_mask = btnMaskByName(entry.key_ptr.*);
            if (src_mask != 0 and (buttons & src_mask) != 0) {
                has_pressed_remap = true;
                break;
            }
        }
        if (has_pressed_remap) {
            tracker.mark(.remap_suppress_button);
            classifyRemapTargets(tracker, cfg);
        }
    }

    // Layer remap override
    const layers = cfg.layer orelse &[0]mapping.LayerConfig{};
    if (cur_os.hold_phase == .active or hasActiveToggle(cur_os)) {
        for (layers) |*lc| {
            if (lc.remap != null) {
                tracker.mark(.remap_layer_override);
                break;
            }
        }
    }

    // Dpad
    if (cfg.dpad) |dpad| {
        if (std.mem.eql(u8, dpad.mode, "arrows"))
            tracker.mark(.dpad_arrows_emit)
        else
            tracker.mark(.dpad_gamepad_passthrough);
    }

    // Gyro
    if (cfg.gyro) |g| {
        if (std.mem.eql(u8, g.mode, "mouse") or std.mem.eql(u8, g.mode, "joystick")) {
            if (delta.gyro_x != null or delta.gyro_y != null)
                tracker.mark(.gyro_activated)
            else
                tracker.mark(.gyro_deactivated);
        }
    }

    // Stress patterns
    const pressed_count = @popCount(buttons);
    if (pressed_count >= 2) tracker.mark(.simultaneous_multi_button);

    const all_count = @typeInfo(ButtonId).@"enum".fields.len;
    var all_mask: u64 = 0;
    for (0..all_count) |i| all_mask |= @as(u64, 1) << @as(u6, @intCast(i));
    if (buttons & all_mask == all_mask) tracker.mark(.all_buttons_pressed);

    // Mutual exclusion: hold layer is pending/active and another trigger is newly pressed
    if (cur_os.hold_phase != .idle) {
        for (layers, 0..) |*lc, idx| {
            if (idx == cur_os.hold_layer_idx) continue;
            if (std.mem.eql(u8, lc.activation, "hold")) {
                const tmask = btnMaskByName(lc.trigger);
                if (tmask != 0 and (buttons & tmask) != 0 and (prev_buttons & tmask) == 0)
                    tracker.mark(.layer_mutual_exclusion_blocked);
            }
        }
    }

    // Macro cancelled by layer switch
    if (prev_os.hold_phase != cur_os.hold_phase and cur_os.hold_phase == .active) {
        if (cfg.remap) |remap_map| {
            var it = remap_map.map.iterator();
            while (it.next()) |entry| {
                if (std.mem.startsWith(u8, entry.value_ptr.*, "macro:"))
                    tracker.mark(.macro_cancelled_by_layer);
            }
        }
    }

    // Button held across layer switch
    if (prev_os.hold_phase != cur_os.hold_phase) {
        const non_trigger = buttons & ~layerTriggerMask(cfg);
        if (non_trigger != 0 and (non_trigger & prev_buttons) != 0)
            tracker.mark(.button_held_across_layer_switch);
    }

    // Rapid layer toggle: consecutive toggle transitions (on->off or off->on within same pass)
    if (prev_os.hold_phase != cur_os.hold_phase and cur_os.hold_phase == .idle and prev_os.hold_phase != .idle) {
        // Quick release after hold = potential rapid toggle
        tracker.mark(.rapid_layer_toggle);
    }
}

fn hasActiveToggle(os: *const OracleState) bool {
    for (os.toggled) |t| {
        if (t) return true;
    }
    return false;
}

fn layerTriggerMask(cfg: *const mapping.MappingConfig) u64 {
    const layers = cfg.layer orelse return 0;
    var mask: u64 = 0;
    for (layers) |*lc| mask |= btnMaskByName(lc.trigger);
    return mask;
}

fn classifyRemapTargets(tracker: *CoverageTracker, cfg: *const mapping.MappingConfig) void {
    const remap = cfg.remap orelse return;
    var it = remap.map.iterator();
    while (it.next()) |entry| {
        const val = entry.value_ptr.*;
        if (std.mem.startsWith(u8, val, "KEY_"))
            tracker.mark(.remap_inject_key)
        else if (std.mem.startsWith(u8, val, "mouse_"))
            tracker.mark(.remap_inject_mouse)
        else if (std.mem.eql(u8, val, "disabled")) {} // suppress only
        else if (std.mem.startsWith(u8, val, "macro:"))
            tracker.mark(.macro_triggered)
        else
            tracker.mark(.remap_inject_gamepad);
    }
}

// --- Tests ---

test "transition_id: coverage tracker starts empty" {
    var tracker = CoverageTracker{};
    const cov = tracker.coverage();
    try std.testing.expectEqual(@as(usize, 0), cov.seen);
    try std.testing.expectEqual(field_count, cov.total);
}

test "transition_id: mark and coverage" {
    var tracker = CoverageTracker{};
    tracker.mark(.layer_idle_to_pending);
    tracker.mark(.remap_suppress_button);
    const cov = tracker.coverage();
    try std.testing.expectEqual(@as(usize, 2), cov.seen);
}

test "transition_id: missing returns unmarked" {
    var tracker = CoverageTracker{};
    tracker.mark(.layer_idle_to_pending);
    var buf: [field_count]TransitionId = undefined;
    const m = tracker.missing(&buf);
    try std.testing.expectEqual(field_count - 1, m.len);
}
