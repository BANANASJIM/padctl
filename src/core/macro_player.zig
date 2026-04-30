const std = @import("std");
const macro_mod = @import("macro.zig");
const remap = @import("remap.zig");
const timer_queue_mod = @import("timer_queue.zig");

const Macro = macro_mod.Macro;
const MacroStep = macro_mod.MacroStep;
const aux_event_mod = @import("aux_event.zig");
const AuxEventList = aux_event_mod.AuxEventList;
const TimerQueue = timer_queue_mod.TimerQueue;
const RemapTargetResolved = remap.RemapTargetResolved;

pub const MacroPlayer = struct {
    macro: *const Macro,
    step_index: usize,
    waiting_for_release: bool,
    timer_token: u32,
    trigger_src_idx: u6,
    held_gamepad_buttons: u64,
    // issue #72: deadline at which the next step becomes eligible. While now_ns
    // is below this, step() must yield the frame so per-poll Mapper.apply calls
    // do not race past delay= boundaries.
    next_step_eligible_at_ns: i128,
    // issue #119: repeat-macro trigger-held flag, refreshed by Mapper each frame
    // before invoking step(). step() consults this when reaching end-of-steps to
    // decide whether to schedule a restart. A falling edge stops further repeats.
    trigger_held: bool,
    // issue #119: when non-null, the macro has finished its current iteration and
    // is waiting for now_ns to reach this deadline before restarting from
    // step_index = 0. Same gating mechanism as next_step_eligible_at_ns.
    awaiting_restart_at_ns: ?i128,

    pub fn init(m: *const Macro, token: u32, src_idx: u6) MacroPlayer {
        return .{
            .macro = m,
            .step_index = 0,
            .waiting_for_release = false,
            .timer_token = token,
            .trigger_src_idx = src_idx,
            .held_gamepad_buttons = 0,
            .next_step_eligible_at_ns = 0,
            .trigger_held = true,
            .awaiting_restart_at_ns = null,
        };
    }

    /// Execute synchronous steps until delay / pause_for_release / end.
    /// Returns true when the macro is finished (caller should remove it).
    ///
    /// injected_buttons: mapper-owned bitmask for synthesized gamepad bits; tap/down/up
    ///   of a .gamepad_button target set or clear bits here.
    /// pending_tap_release: tap bits ORed by this frame; mapper clears them next frame
    ///   (same cadence as the remap tap path — see mapper.emitTapEvent).
    pub fn step(
        self: *MacroPlayer,
        aux: *AuxEventList,
        queue: *TimerQueue,
        injected_buttons: *u64,
        pending_tap_release: *u64,
        now_ns: i128,
    ) !bool {
        if (self.waiting_for_release) return false;
        // issue #72: prevent same-frame double-emit — only the macro timerfd
        // expiry advances state past a delay boundary.
        if (now_ns < self.next_step_eligible_at_ns) return false;

        // issue #119: gate restart on trigger_held — released triggers stop
        // further iterations even after the restart timer fires.
        if (self.awaiting_restart_at_ns) |deadline| {
            if (now_ns < deadline) return false;
            self.awaiting_restart_at_ns = null;
            if (!self.trigger_held) return true;
            self.step_index = 0;
        }

        while (self.step_index < self.macro.steps.len) {
            const s = self.macro.steps[self.step_index];
            self.step_index += 1;
            switch (s) {
                .tap => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    remap.applyTarget(target, .tap, aux, injected_buttons, pending_tap_release, null);
                },
                .down => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    remap.applyTarget(target, .press, aux, injected_buttons, null, &self.held_gamepad_buttons);
                },
                .up => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    remap.applyTarget(target, .release, aux, injected_buttons, null, &self.held_gamepad_buttons);
                },
                .delay => |ms| {
                    const deadline = now_ns + @as(i128, ms) * std.time.ns_per_ms;
                    try queue.arm(deadline, self.timer_token, now_ns);
                    self.next_step_eligible_at_ns = deadline;
                    return false;
                },
                .pause_for_release => {
                    self.waiting_for_release = true;
                    return false;
                },
            }
        }

        // issue #119: end of steps. Schedule restart if repeat_delay_ms set and
        // trigger still held; otherwise legacy single-shot completion.
        if (self.macro.repeat_delay_ms) |delay_ms| {
            if (self.trigger_held) {
                const deadline = now_ns + @as(i128, delay_ms) * std.time.ns_per_ms;
                try queue.arm(deadline, self.timer_token, now_ns);
                self.awaiting_restart_at_ns = deadline;
                return false;
            }
        }
        return true;
    }

    // issue #119: refreshed each Mapper.apply frame for repeat-mode macros so
    // step() can decide at end-of-steps whether to schedule another iteration.
    pub fn setTriggerHeld(self: *MacroPlayer, held: bool) void {
        self.trigger_held = held;
    }

    pub fn notifyTriggerReleased(self: *MacroPlayer) void {
        self.waiting_for_release = false;
    }

    /// Emit releases for any keys/buttons still held by this player.
    /// Called on layer switch / macro cancel. Drops key-up aux events AND clears
    /// held gamepad bits from injected_buttons.
    pub fn emitPendingReleases(self: *MacroPlayer, aux: *AuxEventList, injected_buttons: *u64) void {
        // Walk steps up to step_index, track net held state per name (keys / mouse buttons).
        // Gamepad bits are tracked live in self.held_gamepad_buttons and cleared below.
        var held: [32]?[]const u8 = [_]?[]const u8{null} ** 32;
        var held_len: usize = 0;

        for (self.macro.steps[0..self.step_index]) |s| {
            switch (s) {
                .down => |name| {
                    if (held_len < held.len) {
                        held[held_len] = name;
                        held_len += 1;
                    }
                },
                .up => |name| {
                    for (held[0..held_len], 0..) |h, i| {
                        if (h) |hn| {
                            if (std.mem.eql(u8, hn, name)) {
                                held[i] = held[held_len - 1];
                                held_len -= 1;
                                break;
                            }
                        }
                    }
                },
                .tap => {},
                .delay, .pause_for_release => {},
            }
        }

        for (held[0..held_len]) |h| {
            const name = h orelse continue;
            const target = resolveTargetSafe(name) orelse continue;
            switch (target) {
                .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {},
                .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {},
                .gamepad_button => {},
                .disabled, .macro => {},
            }
        }

        injected_buttons.* &= ~self.held_gamepad_buttons;
        self.held_gamepad_buttons = 0;
    }
};

fn resolveTargetSafe(name: []const u8) ?RemapTargetResolved {
    return remap.resolveTarget(name) catch null;
}

// --- tests ---

const testing = std.testing;

fn makePlayer(m: *const Macro) MacroPlayer {
    return MacroPlayer.init(m, 1, 0);
}

fn dummyQueue(allocator: std.mem.Allocator) TimerQueue {
    return TimerQueue.init(allocator, -1);
}

const StepCtx = struct {
    aux: AuxEventList = .{},
    queue: TimerQueue,
    injected: u64 = 0,
    tap_release: u64 = 0,

    fn init(allocator: std.mem.Allocator) StepCtx {
        return .{ .queue = dummyQueue(allocator) };
    }

    fn deinit(self: *StepCtx) void {
        self.queue.deinit();
    }

    fn step(self: *StepCtx, p: *MacroPlayer) !bool {
        return p.step(&self.aux, &self.queue, &self.injected, &self.tap_release, 0);
    }
};

test "macro_player: tap step press then release emitted" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "KEY_B" }};
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done = try ctx.step(&player);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
    switch (ctx.aux.get(0)) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }
    switch (ctx.aux.get(1)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: down + up steps held then released" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "KEY_LEFTSHIFT" }, .{ .up = "KEY_LEFTSHIFT" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done = try ctx.step(&player);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
    switch (ctx.aux.get(0)) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }
    switch (ctx.aux.get(1)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: delay arms timer queue returns not-done" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .tap = "KEY_A" }, .{ .delay = 50 }, .{ .tap = "KEY_B" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done1 = try ctx.step(&player);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
    try testing.expectEqual(@as(usize, 1), ctx.queue.heap.count());

    ctx.aux = .{};
    // issue #72: must advance now_ns past the delay deadline before step resumes.
    const after_delay: i128 = 50 * std.time.ns_per_ms + 1;
    const done2 = try player.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, after_delay);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
}

test "macro_player: pause_for_release halts until notifyTriggerReleased" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .pause_for_release, .{ .tap = "KEY_A" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done1 = try ctx.step(&player);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 0), ctx.aux.len);

    player.notifyTriggerReleased();
    ctx.aux = .{};
    const done2 = try ctx.step(&player);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
}

test "macro_player: emitPendingReleases down without up emits release" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "KEY_LEFTSHIFT" }, .{ .delay = 100 } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    _ = try ctx.step(&player);

    var aux2 = AuxEventList{};
    player.emitPendingReleases(&aux2, &ctx.injected);
    try testing.expectEqual(@as(usize, 1), aux2.len);
    switch (aux2.get(0)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: shift_hold — down pause_for_release up" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "KEY_LEFTSHIFT" }, .pause_for_release, .{ .up = "KEY_LEFTSHIFT" } };
    const m = Macro{ .name = "shift_hold", .steps = &steps };
    var player = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done1 = try ctx.step(&player);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 1), ctx.aux.len);
    switch (ctx.aux.get(0)) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }

    player.notifyTriggerReleased();
    ctx.aux = .{};
    const done2 = try ctx.step(&player);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 1), ctx.aux.len);
    switch (ctx.aux.get(0)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: two players advance step_index independently" {
    const allocator = testing.allocator;
    const steps_a = [_]MacroStep{ .{ .tap = "KEY_A" }, .{ .tap = "KEY_B" } };
    const steps_b = [_]MacroStep{.{ .tap = "KEY_C" }};
    const ma = Macro{ .name = "a", .steps = &steps_a };
    const mb = Macro{ .name = "b", .steps = &steps_b };
    var pa = MacroPlayer.init(&ma, 1, 0);
    var pb = MacroPlayer.init(&mb, 2, 1);
    var ctx_a = StepCtx.init(allocator);
    defer ctx_a.deinit();
    var ctx_b = StepCtx.init(allocator);
    defer ctx_b.deinit();

    const done_a = try ctx_a.step(&pa);
    const done_b = try ctx_b.step(&pb);

    try testing.expect(done_a);
    try testing.expect(done_b);
    try testing.expectEqual(@as(usize, 4), ctx_a.aux.len);
    try testing.expectEqual(@as(usize, 2), ctx_b.aux.len);
}

// --- issue #119: repeat_delay_ms ---

test "macro_player: repeat_delay_ms — held trigger reschedules; release stops" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "KEY_A" }};
    const m = Macro{ .name = "spam", .steps = &steps, .repeat_delay_ms = 50 };
    var p = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const ns_per_ms: i128 = std.time.ns_per_ms;
    const t0: i128 = 0;

    // First iteration: tap fires (press+release events), player not done, restart armed.
    const done0 = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, t0);
    try testing.expect(!done0);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
    try testing.expectEqual(@as(usize, 1), ctx.queue.heap.count());
    try testing.expect(p.awaiting_restart_at_ns != null);

    // Mid-restart-window: must not advance.
    ctx.aux = .{};
    const done_mid = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, t0 + 20 * ns_per_ms);
    try testing.expect(!done_mid);
    try testing.expectEqual(@as(usize, 0), ctx.aux.len);

    // Restart deadline reached, trigger still held: second iteration fires.
    ctx.aux = .{};
    p.setTriggerHeld(true);
    const done1 = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, t0 + 50 * ns_per_ms);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len); // press + release of KEY_A again

    // Release trigger; reach next restart deadline → player completes (returns true).
    ctx.aux = .{};
    p.setTriggerHeld(false);
    const done2 = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, t0 + 100 * ns_per_ms + 1);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 0), ctx.aux.len); // no further taps after release
}

test "macro_player: repeat_delay_ms — release mid-iteration completes current pass then stops" {
    const allocator = testing.allocator;
    // XYX combo: two taps separated by a delay.
    const steps = [_]MacroStep{
        .{ .tap = "KEY_A" },
        .{ .delay = 10 },
        .{ .tap = "KEY_B" },
    };
    const m = Macro{ .name = "combo", .steps = &steps, .repeat_delay_ms = 100 };
    var p = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const ns_per_ms: i128 = std.time.ns_per_ms;

    // Frame 0: trigger held, first tap fires, then delay arms.
    const done0 = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, 0);
    try testing.expect(!done0);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len); // KEY_A press+release

    // User releases trigger BEFORE delay expiry. The current iteration must
    // still finish naturally (KEY_B tap), but no restart should be scheduled.
    p.setTriggerHeld(false);

    // Delay expires: second tap fires AND end-of-steps reached. trigger_held=false
    // means the macro completes (returns true) — no restart armed.
    ctx.aux = .{};
    const done1 = try p.step(&ctx.aux, &ctx.queue, &ctx.injected, &ctx.tap_release, 10 * ns_per_ms + 1);
    try testing.expect(done1);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len); // KEY_B press+release
    try testing.expect(p.awaiting_restart_at_ns == null);
}

test "macro_player: repeat_delay_ms absent — legacy single-shot completion" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "KEY_A" }};
    const m = Macro{ .name = "once", .steps = &steps };
    var p = makePlayer(&m);
    var ctx = StepCtx.init(allocator);
    defer ctx.deinit();

    const done = try ctx.step(&p);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), ctx.aux.len);
    try testing.expect(p.awaiting_restart_at_ns == null);
}
