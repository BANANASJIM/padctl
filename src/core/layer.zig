const std = @import("std");
const mapping = @import("../config/mapping.zig");
const remap = @import("remap.zig");

pub const LayerConfig = mapping.LayerConfig;
pub const RemapTarget = remap.RemapTargetResolved;

pub const LayerAction = struct {
    arm_timer_ms: ?u64 = null,
    disarm_timer: bool = false,
    tap_event: ?RemapTarget = null,
    active_changed: bool = false,
};

pub const TapHoldPhase = enum { pending, active };

pub const TapHoldState = struct {
    layer_name: []const u8,
    layer_activated: bool = false,
    phase: TapHoldPhase = .pending,
    press_ns: i128 = 0,
    hold_timeout_ns: i128 = 0,
};

pub const TapHoldResult = struct {
    arm_timer_ms: ?u64 = null,
    disarm_timer: bool = false,
    tap_event: ?RemapTarget = null,
    layer_activated: bool = false,
    layer_deactivated: bool = false,
};

pub const LayerState = struct {
    tap_hold: ?TapHoldState = null,
    toggled: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) LayerState {
        return .{ .toggled = std.StringHashMap(void).init(allocator) };
    }

    pub fn deinit(self: *LayerState) void {
        self.toggled.deinit();
    }

    /// Returns the active LayerConfig by priority:
    /// 1. Hold ACTIVE (tap_hold != null and layer_activated == true)
    /// 2. First toggled layer in declaration order (ADR-004)
    /// 3. null (base layer)
    pub fn getActive(
        self: *const LayerState,
        configs: []const LayerConfig,
    ) ?*const LayerConfig {
        if (self.tap_hold) |*th| {
            if (th.layer_activated) {
                for (configs) |*cfg| {
                    if (std.mem.eql(u8, cfg.name, th.layer_name)) return cfg;
                }
            }
        }
        for (configs) |*cfg| {
            if (self.toggled.contains(cfg.name)) return cfg;
        }
        return null;
    }

    /// Per-frame dispatch: converts button edges into layer activation/deactivation.
    /// Implements ADR-004 mutual exclusion: while any layer is ACTIVE or PENDING,
    /// new Hold presses are silently ignored; new Toggle-on is blocked until getActive() == null.
    pub fn processLayerTriggers(
        self: *LayerState,
        configs: []const LayerConfig,
        buttons: u64,
        prev_buttons: u64,
        now_ns: i128,
    ) LayerAction {
        var action = LayerAction{};

        for (configs) |*cfg| {
            const trigger_id = std.meta.stringToEnum(@import("state.zig").ButtonId, cfg.trigger) orelse continue;
            const mask = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(trigger_id)));
            const pressed = (buttons & mask) != 0;
            const was_pressed = (prev_buttons & mask) != 0;

            if (std.mem.eql(u8, cfg.activation, "hold")) {
                if (pressed and !was_pressed) {
                    // Mutual exclusion: if another layer is already PENDING or ACTIVE, ignore.
                    if (self.tap_hold) |th| {
                        if (!std.mem.eql(u8, th.layer_name, cfg.name)) continue;
                    }
                    const timeout: u64 = @intCast(cfg.hold_timeout orelse 200);
                    const res = self.onTriggerPress(cfg.name, timeout, now_ns);
                    if (res.arm_timer_ms) |ms| {
                        action.arm_timer_ms = ms;
                        action.active_changed = true;
                    }
                } else if (!pressed and was_pressed) {
                    // Only process release for the layer that owns tap_hold.
                    const th = self.tap_hold orelse continue;
                    if (!std.mem.eql(u8, th.layer_name, cfg.name)) continue;
                    const tap_target: ?RemapTarget = if (cfg.tap) |t|
                        remap.resolveTarget(t) catch null
                    else
                        null;
                    const res = self.onTriggerRelease(tap_target, now_ns);
                    if (res.disarm_timer) action.disarm_timer = true;
                    if (res.tap_event) |ev| action.tap_event = ev;
                    if (res.layer_activated or res.layer_deactivated) action.active_changed = true;
                }
            } else { // toggle
                if (!pressed and was_pressed) {
                    if (self.toggled.contains(cfg.name)) {
                        _ = self.toggled.remove(cfg.name);
                        action.active_changed = true;
                    } else if (self.getActive(configs) == null) {
                        // Clear any stale PENDING tap_hold state.
                        if (self.tap_hold != null) {
                            self.tap_hold = null;
                            action.disarm_timer = true;
                        }
                        self.toggled.put(cfg.name, {}) catch {};
                        action.active_changed = true;
                    }
                }
            }
        }

        return action;
    }

    pub fn onTriggerPress(self: *LayerState, layer_name: []const u8, hold_timeout_ms: u64, now_ns: i128) TapHoldResult {
        if (self.tap_hold) |th| {
            if (std.mem.eql(u8, th.layer_name, layer_name)) return .{};
        }
        self.tap_hold = .{
            .layer_name = layer_name,
            .phase = .pending,
            .press_ns = now_ns,
            .hold_timeout_ns = @as(i128, hold_timeout_ms) * 1_000_000,
        };
        return .{ .arm_timer_ms = hold_timeout_ms };
    }

    pub fn onTriggerRelease(self: *LayerState, tap_target: ?RemapTarget, now_ns: i128) TapHoldResult {
        const th = self.tap_hold orelse return .{};
        defer self.tap_hold = null;
        return switch (th.phase) {
            .pending => .{
                .disarm_timer = true,
                .tap_event = tap_target,
            },
            .active => if (th.hold_timeout_ns > 0 and (now_ns - th.press_ns) < th.hold_timeout_ns) .{
                .tap_event = tap_target,
                .layer_deactivated = true,
            } else .{
                .layer_deactivated = true,
            },
        };
    }

    pub fn onTimerExpired(self: *LayerState) TapHoldResult {
        const th = &(self.tap_hold orelse return .{}); // IDLE: stale, no-op
        if (th.phase != .pending) return .{};
        th.phase = .active;
        th.layer_activated = true;
        return .{ .layer_activated = true };
    }
};

// --- tests ---

const testing = std.testing;

const aim_cfg = LayerConfig{ .name = "aim", .trigger = "LT" };
const fn_cfg = LayerConfig{ .name = "fn", .trigger = "Select" };

test "layer: getActive: no active layer returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    try testing.expect(ls.getActive(&configs) == null);
}

test "layer: getActive: hold ACTIVE returns matching layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "layer: getActive: hold PENDING (not activated) does not activate layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = false, .phase = .pending };

    const configs = [_]LayerConfig{aim_cfg};
    try testing.expect(ls.getActive(&configs) == null);
}

test "layer: getActive: toggle on returns matching layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("fn", active.?.name);
}

test "layer: getActive: hold ACTIVE takes priority over toggled" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "layer: getActive: multiple toggled layers — declaration order wins (ADR-004)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("aim", {});
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "layer: getActive: multiple toggled layers — fn declared first wins when aim is absent" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("fn", active.?.name);
}

test "layer: getActive: configs length boundary — toggled name not in configs returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("unknown", {});

    const configs = [_]LayerConfig{aim_cfg};
    try testing.expect(ls.getActive(&configs) == null);
}

test "layer: getActive: empty configs always returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };
    try ls.toggled.put("fn", {});

    try testing.expect(ls.getActive(&.{}) == null);
}

// --- T4: tap-hold state machine tests ---

test "layer: tap-hold: press → PENDING, arm_timer_ms set" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTriggerPress("aim", 200, 0);
    try testing.expectEqual(@as(?u64, 200), res.arm_timer_ms);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(ls.tap_hold != null);
    try testing.expectEqual(TapHoldPhase.pending, ls.tap_hold.?.phase);
}

test "layer: tap-hold: PENDING + timer expired → ACTIVE, layer_activated = true" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200, 0);

    const res = ls.onTimerExpired();
    try testing.expect(res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(res.arm_timer_ms == null);
    try testing.expect(!res.disarm_timer);
    try testing.expect(ls.tap_hold != null);
    try testing.expectEqual(TapHoldPhase.active, ls.tap_hold.?.phase);
    try testing.expect(ls.tap_hold.?.layer_activated);
}

test "layer: tap-hold: PENDING + release → IDLE, tap_event has value" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200, 0);

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 }, 100_000_000);
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event != null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(ls.tap_hold == null);
}

test "layer: tap-hold: PENDING + release with no tap target → IDLE, no tap_event" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200, 0);

    const res = ls.onTriggerRelease(null, 100_000_000);
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(ls.tap_hold == null);
}

test "layer: tap-hold: ACTIVE + release (past timeout) → IDLE, no tap" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200, 0);
    _ = ls.onTimerExpired();

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 }, 500_000_000);
    try testing.expect(res.layer_deactivated);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(ls.tap_hold == null);
}

test "layer: tap-hold: ACTIVE + release within timeout (race) → tap emitted (#79)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const press_time: i128 = 1_000_000_000;
    _ = ls.onTriggerPress("aim", 200, press_time);
    _ = ls.onTimerExpired();

    const release_time: i128 = press_time + 150_000_000;
    const res2 = ls.onTriggerRelease(RemapTarget{ .key = 183 }, release_time);
    try testing.expect(res2.layer_deactivated);
    try testing.expect(res2.tap_event != null);
    try testing.expect(ls.tap_hold == null);
}

test "layer: tap-hold: IDLE + release → no-op" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 }, 0);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
}

test "layer: tap-hold: IDLE + timer expired → no-op (stale timer)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTimerExpired();
    try testing.expect(!res.layer_activated);
    try testing.expect(res.arm_timer_ms == null);
}

test "layer: tap-hold: ACTIVE re-press same trigger → ignored" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200, 0);
    _ = ls.onTimerExpired();

    const res = ls.onTriggerPress("aim", 200, 0);
    try testing.expect(res.arm_timer_ms == null);
    try testing.expectEqual(TapHoldPhase.active, ls.tap_hold.?.phase);
}

// --- T5: processLayerTriggers tests ---

const hold_aim = LayerConfig{ .name = "aim", .trigger = "LT", .activation = "hold" };
const hold_fn = LayerConfig{ .name = "fn", .trigger = "RB", .activation = "hold" };
const toggle_sel = LayerConfig{ .name = "sel", .trigger = "Select", .activation = "toggle" };

fn ltMask() u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(@import("state.zig").ButtonId.LT)));
}
fn rbMask() u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(@import("state.zig").ButtonId.RB)));
}
fn selMask() u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(@import("state.zig").ButtonId.Select)));
}

test "layer: processLayerTriggers: Hold press → PENDING, arm timer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{hold_aim};
    const lt = ltMask();

    const action = ls.processLayerTriggers(&configs, lt, 0, 0);
    try testing.expect(action.arm_timer_ms != null);
    try testing.expectEqual(@as(?u64, 200), action.arm_timer_ms);
    try testing.expect(action.active_changed);
    try testing.expect(ls.tap_hold != null);
    try testing.expectEqual(TapHoldPhase.pending, ls.tap_hold.?.phase);
}

test "layer: processLayerTriggers: Hold PENDING + timer → ACTIVE, getActive returns layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{hold_aim};
    const lt = ltMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    _ = ls.onTimerExpired();

    try testing.expect(ls.getActive(&configs) != null);
    try testing.expectEqualStrings("aim", ls.getActive(&configs).?.name);
}

test "layer: processLayerTriggers: Hold ACTIVE + release → IDLE" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{hold_aim};
    const lt = ltMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    _ = ls.onTimerExpired();

    const action = ls.processLayerTriggers(&configs, 0, lt, 0);
    try testing.expect(action.active_changed);
    try testing.expect(ls.tap_hold == null);
    try testing.expect(ls.getActive(&configs) == null);
}

test "layer: processLayerTriggers: Hold PENDING release → tap event + disarm" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const tap_cfg = LayerConfig{ .name = "aim", .trigger = "LT", .activation = "hold", .tap = "KEY_F13" };
    const configs = [_]LayerConfig{tap_cfg};
    const lt = ltMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    const action = ls.processLayerTriggers(&configs, 0, lt, 0);

    try testing.expect(action.disarm_timer);
    try testing.expect(action.tap_event != null);
    try testing.expect(ls.tap_hold == null);
}

test "layer: processLayerTriggers: ADR-004 mutual exclusion — second Hold press ignored while PENDING" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{ hold_aim, hold_fn };
    const lt = ltMask();
    const rb = rbMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    try testing.expectEqualStrings("aim", ls.tap_hold.?.layer_name);

    // RB pressed while LT PENDING — must be ignored
    const action = ls.processLayerTriggers(&configs, lt | rb, lt, 0);
    try testing.expect(action.arm_timer_ms == null);
    try testing.expectEqualStrings("aim", ls.tap_hold.?.layer_name);
}

test "layer: processLayerTriggers: ADR-004 mutual exclusion — second Hold press ignored while ACTIVE" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{ hold_aim, hold_fn };
    const lt = ltMask();
    const rb = rbMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    _ = ls.onTimerExpired();

    const action = ls.processLayerTriggers(&configs, lt | rb, lt, 0);
    try testing.expect(action.arm_timer_ms == null);
    try testing.expectEqualStrings("aim", ls.tap_hold.?.layer_name);
}

test "layer: processLayerTriggers: Toggle release → layer on" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{toggle_sel};
    const sel = selMask();

    const action = ls.processLayerTriggers(&configs, 0, sel, 0);
    try testing.expect(action.active_changed);
    try testing.expect(ls.toggled.contains("sel"));
    try testing.expect(ls.getActive(&configs) != null);
}

test "layer: processLayerTriggers: Toggle second release → layer off" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{toggle_sel};
    const sel = selMask();

    _ = ls.processLayerTriggers(&configs, 0, sel, 0);
    const action = ls.processLayerTriggers(&configs, 0, sel, 0);
    try testing.expect(action.active_changed);
    try testing.expect(!ls.toggled.contains("sel"));
    try testing.expect(ls.getActive(&configs) == null);
}

test "layer: processLayerTriggers: Toggle on blocked while Hold ACTIVE" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{ hold_aim, toggle_sel };
    const lt = ltMask();
    const sel = selMask();

    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    _ = ls.onTimerExpired();

    // Toggle release while Hold ACTIVE — must be blocked
    _ = ls.processLayerTriggers(&configs, lt, lt | sel, 0);
    try testing.expect(!ls.toggled.contains("sel"));
    try testing.expectEqualStrings("aim", ls.getActive(&configs).?.name);
}

test "layer: processLayerTriggers: Toggle + Hold coexist, Hold takes priority in getActive" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const configs = [_]LayerConfig{ hold_aim, toggle_sel };
    const lt = ltMask();
    const sel = selMask();

    // Toggle on first (no active layer yet)
    _ = ls.processLayerTriggers(&configs, 0, sel, 0);
    try testing.expect(ls.toggled.contains("sel"));

    // Hold press + activate
    _ = ls.processLayerTriggers(&configs, lt, 0, 0);
    _ = ls.onTimerExpired();

    // Hold must take priority
    try testing.expectEqualStrings("aim", ls.getActive(&configs).?.name);
}

test "layer: processLayerTriggers: multiple Toggles on — declaration order wins (ADR-004)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    const tog_a = LayerConfig{ .name = "a", .trigger = "LB", .activation = "toggle" };
    const tog_b = LayerConfig{ .name = "b", .trigger = "RB", .activation = "toggle" };
    const configs = [_]LayerConfig{ tog_a, tog_b };
    const lb = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(@import("state.zig").ButtonId.LB)));
    const rb = rbMask();

    // Toggle "a" on
    _ = ls.processLayerTriggers(&configs, 0, lb, 0);
    try testing.expect(ls.toggled.contains("a"));

    // "a" is active now; "b" toggle-on should be blocked
    _ = ls.processLayerTriggers(&configs, 0, rb, 0);
    try testing.expect(!ls.toggled.contains("b"));
    try testing.expectEqualStrings("a", ls.getActive(&configs).?.name);
}
