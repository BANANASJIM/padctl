const std = @import("std");
const remap_mod = @import("remap.zig");

const RemapTargetResolved = remap_mod.RemapTargetResolved;
const ResolvedGesture = remap_mod.ResolvedGesture;

pub const GESTURE_SLOTS = 16;

pub const GestureLeg = enum { hold, double };

pub const EmitAction = enum { press, release, tap };

pub const Emit = struct {
    target: RemapTargetResolved,
    action: EmitAction,
};

pub const Arm = struct {
    leg: GestureLeg,
    deadline_ns: i128,
};

// Result of one engine step. The mapper performs the emits via applyTarget and
// owns the shared timer_queue: it allocates a token for `arm`, records it back
// into the slot via setArmToken, and drains expiry by token.
pub const Outcome = struct {
    emits: [3]Emit = undefined,
    emit_len: usize = 0,
    arm: ?Arm = null,
    cancel_hold: bool = false,
    cancel_double: bool = false,

    fn push(self: *Outcome, target: RemapTargetResolved, action: EmitAction) void {
        if (self.emit_len >= self.emits.len) return;
        self.emits[self.emit_len] = .{ .target = target, .action = action };
        self.emit_len += 1;
    }

    pub fn slice(self: *const Outcome) []const Emit {
        return self.emits[0..self.emit_len];
    }
};

const Phase = enum { idle, wait_decide, hold_active };

const Slot = struct {
    src_idx: u6,
    gesture: *const ResolvedGesture,
    phase: Phase = .idle,
    press_ns: i128 = 0,
    release_ns: i128 = 0,
    hold_token: ?u32 = null,
    double_token: ?u32 = null,
    first_release_seen: bool = false,
};

pub const GestureEngine = struct {
    slots: [GESTURE_SLOTS]?Slot = [_]?Slot{null} ** GESTURE_SLOTS,

    pub fn reset(self: *GestureEngine) void {
        self.slots = [_]?Slot{null} ** GESTURE_SLOTS;
    }

    fn findSlot(self: *GestureEngine, src_idx: u6) ?*Slot {
        for (&self.slots) |*maybe| {
            if (maybe.*) |*s| {
                if (s.src_idx == src_idx) return s;
            }
        }
        return null;
    }

    fn acquireSlot(self: *GestureEngine, src_idx: u6, gesture: *const ResolvedGesture) ?*Slot {
        if (self.findSlot(src_idx)) |s| return s;
        for (&self.slots) |*maybe| {
            if (maybe.* == null) {
                maybe.* = .{ .src_idx = src_idx, .gesture = gesture };
                return &maybe.*.?;
            }
        }
        return null;
    }

    fn releaseSlot(self: *GestureEngine, src_idx: u6) void {
        for (&self.slots) |*maybe| {
            if (maybe.*) |*s| {
                if (s.src_idx == src_idx) {
                    maybe.* = null;
                    return;
                }
            }
        }
    }

    // Called by the mapper after it allocates a timer token for `out.arm`.
    pub fn setArmToken(self: *GestureEngine, src_idx: u6, leg: GestureLeg, token: u32) void {
        const s = self.findSlot(src_idx) orelse return;
        switch (leg) {
            .hold => s.hold_token = token,
            .double => s.double_token = token,
        }
    }

    pub fn onButtonEdge(self: *GestureEngine, src_idx: u6, gesture: *const ResolvedGesture, pressed: bool, now_ns: i128) Outcome {
        var out = Outcome{};
        if (pressed) {
            const s = self.acquireSlot(src_idx, gesture) orelse return out;
            switch (s.phase) {
                .idle => {
                    s.press_ns = now_ns;
                    s.first_release_seen = false;
                    s.phase = .wait_decide;
                    if (gesture.hold != null) {
                        out.arm = .{ .leg = .hold, .deadline_ns = now_ns + gesture.hold_ns };
                    }
                },
                .wait_decide => {
                    // Second press inside the double window confirms double.
                    if (gesture.has_double and s.first_release_seen) {
                        if (gesture.double) |d| out.push(d, .tap);
                        if (s.double_token != null) {
                            out.cancel_double = true;
                            s.double_token = null;
                        }
                        s.phase = .idle;
                        self.releaseSlot(src_idx);
                    }
                },
                .hold_active => {},
            }
            return out;
        }

        // release edge
        const s = self.findSlot(src_idx) orelse return out;
        switch (s.phase) {
            .idle => {},
            .wait_decide => {
                if (!gesture.has_double) {
                    if (gesture.tap) |t| out.push(t, .tap);
                    if (s.hold_token != null) {
                        out.cancel_hold = true;
                        s.hold_token = null;
                    }
                    s.phase = .idle;
                    self.releaseSlot(src_idx);
                } else if (!s.first_release_seen) {
                    s.first_release_seen = true;
                    s.release_ns = now_ns;
                    if (s.hold_token != null) {
                        out.cancel_hold = true;
                        s.hold_token = null;
                    }
                    out.arm = .{ .leg = .double, .deadline_ns = now_ns + gesture.double_ns };
                }
            },
            .hold_active => {
                if (gesture.hold) |hh| out.push(hh, .release);
                s.phase = .idle;
                self.releaseSlot(src_idx);
            },
        }
        return out;
    }

    // `leg` is the timer's leg; resolved by the mapper from the expired token.
    pub fn onTimerExpired(self: *GestureEngine, src_idx: u6, leg: GestureLeg, held: bool, _: i128) Outcome {
        var out = Outcome{};
        const s = self.findSlot(src_idx) orelse return out;
        switch (leg) {
            .hold => {
                s.hold_token = null;
                if (s.phase == .wait_decide and held) {
                    if (s.gesture.hold) |hh| out.push(hh, .press);
                    if (s.double_token != null) {
                        out.cancel_double = true;
                        s.double_token = null;
                    }
                    s.phase = .hold_active;
                }
            },
            .double => {
                s.double_token = null;
                if (s.phase == .wait_decide and s.first_release_seen) {
                    if (s.gesture.tap) |t| out.push(t, .tap);
                    s.phase = .idle;
                    self.releaseSlot(src_idx);
                }
            },
        }
        return out;
    }
};

// --- tests ---

const testing = std.testing;
const input_codes = @import("../config/input_codes.zig");

fn key(name: []const u8) RemapTargetResolved {
    return .{ .key = input_codes.resolveKeyCode(name) catch unreachable };
}

const ns_ms: i128 = std.time.ns_per_ms;

test "gesture: tap-only emits tap on release" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = null,
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};

    const o_press = e.onButtonEdge(0, &g, true, 0);
    try testing.expectEqual(@as(usize, 0), o_press.emit_len);
    try testing.expect(o_press.arm == null); // no hold leg -> no deadline armed

    const o_rel = e.onButtonEdge(0, &g, false, 50 * ns_ms);
    try testing.expectEqual(@as(usize, 1), o_rel.emit_len);
    try testing.expectEqual(EmitAction.tap, o_rel.slice()[0].action);
    try testing.expectEqual(key("KEY_X").key, o_rel.slice()[0].target.key);
}

test "gesture: hold fires at deadline while still held, then release on button up" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = key("KEY_Y"),
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};

    const o_press = e.onButtonEdge(0, &g, true, 0);
    try testing.expect(o_press.arm != null);
    try testing.expectEqual(GestureLeg.hold, o_press.arm.?.leg);
    try testing.expectEqual(@as(i128, 300 * ns_ms), o_press.arm.?.deadline_ns);
    e.setArmToken(0, .hold, 7);

    const o_exp = e.onTimerExpired(0, .hold, true, 300 * ns_ms);
    try testing.expectEqual(@as(usize, 1), o_exp.emit_len);
    try testing.expectEqual(EmitAction.press, o_exp.slice()[0].action);
    try testing.expectEqual(key("KEY_Y").key, o_exp.slice()[0].target.key);

    const o_rel = e.onButtonEdge(0, &g, false, 500 * ns_ms);
    try testing.expectEqual(@as(usize, 1), o_rel.emit_len);
    try testing.expectEqual(EmitAction.release, o_rel.slice()[0].action);
    try testing.expectEqual(key("KEY_Y").key, o_rel.slice()[0].target.key);
}

test "gesture: hold deadline ignored when button already released" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = key("KEY_Y"),
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(0, &g, true, 0);
    e.setArmToken(0, .hold, 7);
    // released before hold deadline -> tap, slot freed
    const o_rel = e.onButtonEdge(0, &g, false, 50 * ns_ms);
    try testing.expect(o_rel.cancel_hold);
    try testing.expectEqual(EmitAction.tap, o_rel.slice()[0].action);
    // stale hold expiry must not emit
    const o_exp = e.onTimerExpired(0, .hold, false, 300 * ns_ms);
    try testing.expectEqual(@as(usize, 0), o_exp.emit_len);
}

test "gesture: double fires on second press inside window" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = null,
        .double = key("KEY_Z"),
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = true,
    };
    var e = GestureEngine{};

    _ = e.onButtonEdge(0, &g, true, 0);
    const o_r1 = e.onButtonEdge(0, &g, false, 40 * ns_ms);
    try testing.expectEqual(@as(usize, 0), o_r1.emit_len); // tap deferred (has_double)
    try testing.expect(o_r1.arm != null);
    try testing.expectEqual(GestureLeg.double, o_r1.arm.?.leg);
    e.setArmToken(0, .double, 9);

    const o_p2 = e.onButtonEdge(0, &g, true, 100 * ns_ms);
    try testing.expectEqual(@as(usize, 1), o_p2.emit_len);
    try testing.expectEqual(key("KEY_Z").key, o_p2.slice()[0].target.key);
    try testing.expect(o_p2.cancel_double);
}

test "gesture: double window timeout collapses to single tap" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = null,
        .double = key("KEY_Z"),
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = true,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(0, &g, true, 0);
    _ = e.onButtonEdge(0, &g, false, 40 * ns_ms);
    e.setArmToken(0, .double, 9);

    const o_exp = e.onTimerExpired(0, .double, false, 290 * ns_ms);
    try testing.expectEqual(@as(usize, 1), o_exp.emit_len);
    try testing.expectEqual(EmitAction.tap, o_exp.slice()[0].action);
    try testing.expectEqual(key("KEY_X").key, o_exp.slice()[0].target.key);
}

test "gesture: hold fires while held, no double pending to cancel" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = key("KEY_Y"),
        .double = key("KEY_Z"),
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = true,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(0, &g, true, 0);
    e.setArmToken(0, .hold, 1);
    const o_exp = e.onTimerExpired(0, .hold, true, 300 * ns_ms);
    try testing.expectEqual(EmitAction.press, o_exp.slice()[0].action);
    try testing.expectEqual(key("KEY_Y").key, o_exp.slice()[0].target.key);
    // No release happened, so no double deadline was ever armed: nothing to cancel.
    try testing.expect(!o_exp.cancel_double);
}

test "gesture: tap+hold (no double) emits tap immediately on release, no double armed" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = key("KEY_Y"),
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(0, &g, true, 0);
    e.setArmToken(0, .hold, 1);
    const o_rel = e.onButtonEdge(0, &g, false, 30 * ns_ms);
    try testing.expectEqual(EmitAction.tap, o_rel.slice()[0].action);
    try testing.expectEqual(key("KEY_X").key, o_rel.slice()[0].target.key);
    try testing.expect(o_rel.arm == null); // no double_token armed
    try testing.expect(o_rel.cancel_hold);
}

test "gesture: multi-slot concurrency — two sources independent" {
    var ga = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = null,
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var gb = ResolvedGesture{
        .tap = key("KEY_Z"),
        .hold = key("KEY_Y"),
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(3, &ga, true, 0);
    _ = e.onButtonEdge(5, &gb, true, 0);
    e.setArmToken(5, .hold, 2);

    const o_b = e.onTimerExpired(5, .hold, true, 300 * ns_ms);
    try testing.expectEqual(key("KEY_Y").key, o_b.slice()[0].target.key);

    const o_a = e.onButtonEdge(3, &ga, false, 10 * ns_ms);
    try testing.expectEqual(key("KEY_X").key, o_a.slice()[0].target.key);
    try testing.expectEqual(EmitAction.tap, o_a.slice()[0].action);
}

test "gesture: reset clears all slots" {
    var g = ResolvedGesture{
        .tap = key("KEY_X"),
        .hold = key("KEY_Y"),
        .double = null,
        .hold_ns = 300 * ns_ms,
        .double_ns = 250 * ns_ms,
        .has_double = false,
    };
    var e = GestureEngine{};
    _ = e.onButtonEdge(0, &g, true, 0);
    try testing.expect(e.findSlot(0) != null);
    e.reset();
    try testing.expect(e.findSlot(0) == null);
}
