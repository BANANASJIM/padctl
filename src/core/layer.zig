const std = @import("std");
const mapping = @import("../config/mapping.zig");
const remap = @import("remap.zig");

pub const LayerConfig = mapping.LayerConfig;
pub const RemapTarget = remap.RemapTargetResolved;

pub const TapHoldPhase = enum { pending, active };

pub const TapHoldState = struct {
    layer_name: []const u8,
    layer_activated: bool = false,
    phase: TapHoldPhase = .pending,
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

    /// IDLE → PENDING: arm timerfd
    pub fn onTriggerPress(self: *LayerState, layer_name: []const u8, hold_timeout_ms: u64) TapHoldResult {
        // already PENDING or ACTIVE for this layer: ignore re-press
        if (self.tap_hold) |th| {
            if (std.mem.eql(u8, th.layer_name, layer_name)) return .{};
        }
        self.tap_hold = .{ .layer_name = layer_name, .phase = .pending };
        return .{ .arm_timer_ms = hold_timeout_ms };
    }

    /// PENDING → IDLE + tap, or ACTIVE → IDLE
    pub fn onTriggerRelease(self: *LayerState, tap_target: ?RemapTarget) TapHoldResult {
        const th = self.tap_hold orelse return .{}; // IDLE: no-op
        defer self.tap_hold = null;
        return switch (th.phase) {
            .pending => .{
                .disarm_timer = true,
                .tap_event = tap_target,
            },
            .active => .{
                .layer_deactivated = true,
            },
        };
    }

    /// PENDING → ACTIVE; stale timer (IDLE) is ignored
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

test "getActive: no active layer returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    try testing.expect(ls.getActive(&configs) == null);
}

test "getActive: hold ACTIVE returns matching layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "getActive: hold PENDING (not activated) does not activate layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = false, .phase = .pending };

    const configs = [_]LayerConfig{aim_cfg};
    try testing.expect(ls.getActive(&configs) == null);
}

test "getActive: toggle on returns matching layer" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("fn", active.?.name);
}

test "getActive: hold ACTIVE takes priority over toggled" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "getActive: multiple toggled layers — declaration order wins (ADR-004)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("aim", {});
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("aim", active.?.name);
}

test "getActive: multiple toggled layers — fn declared first wins when aim is absent" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("fn", {});

    const configs = [_]LayerConfig{ aim_cfg, fn_cfg };
    const active = ls.getActive(&configs);
    try testing.expect(active != null);
    try testing.expectEqualStrings("fn", active.?.name);
}

test "getActive: configs length boundary — toggled name not in configs returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    try ls.toggled.put("unknown", {});

    const configs = [_]LayerConfig{aim_cfg};
    try testing.expect(ls.getActive(&configs) == null);
}

test "getActive: empty configs always returns null" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    ls.tap_hold = .{ .layer_name = "aim", .layer_activated = true, .phase = .active };
    try ls.toggled.put("fn", {});

    try testing.expect(ls.getActive(&.{}) == null);
}

// --- T4: tap-hold state machine tests ---

test "tap-hold: press → PENDING, arm_timer_ms set" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTriggerPress("aim", 200);
    try testing.expectEqual(@as(?u64, 200), res.arm_timer_ms);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(ls.tap_hold != null);
    try testing.expectEqual(TapHoldPhase.pending, ls.tap_hold.?.phase);
}

test "tap-hold: PENDING + timer expired → ACTIVE, layer_activated = true" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200);

    const res = ls.onTimerExpired();
    try testing.expect(res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(res.arm_timer_ms == null);
    try testing.expect(!res.disarm_timer);
    try testing.expect(ls.tap_hold != null);
    try testing.expectEqual(TapHoldPhase.active, ls.tap_hold.?.phase);
    try testing.expect(ls.tap_hold.?.layer_activated);
}

test "tap-hold: PENDING + release → IDLE, tap_event has value" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200);

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 });
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event != null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
    try testing.expect(ls.tap_hold == null);
}

test "tap-hold: PENDING + release with no tap target → IDLE, no tap_event" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200);

    const res = ls.onTriggerRelease(null);
    try testing.expect(res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(ls.tap_hold == null);
}

test "tap-hold: ACTIVE + release → IDLE, layer_deactivated = true" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200);
    _ = ls.onTimerExpired();

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 });
    try testing.expect(res.layer_deactivated);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(ls.tap_hold == null);
}

test "tap-hold: IDLE + release → no-op" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTriggerRelease(RemapTarget{ .key = 183 });
    try testing.expect(!res.disarm_timer);
    try testing.expect(res.tap_event == null);
    try testing.expect(!res.layer_activated);
    try testing.expect(!res.layer_deactivated);
}

test "tap-hold: IDLE + timer expired → no-op (stale timer)" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();

    const res = ls.onTimerExpired();
    try testing.expect(!res.layer_activated);
    try testing.expect(res.arm_timer_ms == null);
}

test "tap-hold: ACTIVE re-press same trigger → ignored" {
    var ls = LayerState.init(testing.allocator);
    defer ls.deinit();
    _ = ls.onTriggerPress("aim", 200);
    _ = ls.onTimerExpired();

    const res = ls.onTriggerPress("aim", 200);
    try testing.expect(res.arm_timer_ms == null);
    try testing.expectEqual(TapHoldPhase.active, ls.tap_hold.?.phase);
}
