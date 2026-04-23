const std = @import("std");
const macro_mod = @import("macro.zig");
const remap = @import("remap.zig");
const timer_queue_mod = @import("timer_queue.zig");
const state_mod = @import("state.zig");

const Macro = macro_mod.Macro;
const MacroStep = macro_mod.MacroStep;
const aux_event_mod = @import("aux_event.zig");
const AuxEventList = aux_event_mod.AuxEventList;
const AuxEvent = aux_event_mod.AuxEvent;
const TimerQueue = timer_queue_mod.TimerQueue;
const RemapTargetResolved = remap.RemapTargetResolved;
const ButtonId = state_mod.ButtonId;

pub const MacroPlayer = struct {
    macro: *const Macro,
    step_index: usize,
    waiting_for_release: bool,
    timer_token: u32,
    trigger_src_idx: u6,
    held_gamepad_buttons: u64,

    pub fn init(m: *const Macro, token: u32, src_idx: u6) MacroPlayer {
        return .{
            .macro = m,
            .step_index = 0,
            .waiting_for_release = false,
            .timer_token = token,
            .trigger_src_idx = src_idx,
            .held_gamepad_buttons = 0,
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
    ) !bool {
        if (self.waiting_for_release) return false;

        while (self.step_index < self.macro.steps.len) {
            const s = self.macro.steps[self.step_index];
            self.step_index += 1;
            switch (s) {
                .tap => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    emitTap(target, aux, injected_buttons, pending_tap_release);
                },
                .down => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    emitDown(target, aux, injected_buttons, &self.held_gamepad_buttons);
                },
                .up => |name| {
                    const target = resolveTargetSafe(name) orelse continue;
                    emitUp(target, aux, injected_buttons, &self.held_gamepad_buttons);
                },
                .delay => |ms| {
                    const deadline = std.time.nanoTimestamp() + @as(i128, ms) * std.time.ns_per_ms;
                    try queue.arm(deadline, self.timer_token);
                    return false;
                },
                .pause_for_release => {
                    self.waiting_for_release = true;
                    return false;
                },
            }
        }
        return true;
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

fn emitTap(
    target: RemapTargetResolved,
    aux: *AuxEventList,
    injected_buttons: *u64,
    pending_tap_release: *u64,
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
            const mask = buttonMask(dst);
            injected_buttons.* |= mask;
            pending_tap_release.* |= mask;
        },
        .disabled, .macro => {},
    }
}

fn emitDown(
    target: RemapTargetResolved,
    aux: *AuxEventList,
    injected_buttons: *u64,
    held_gamepad: *u64,
) void {
    switch (target) {
        .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {},
        .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = true } }) catch {},
        .gamepad_button => |dst| {
            const mask = buttonMask(dst);
            injected_buttons.* |= mask;
            held_gamepad.* |= mask;
        },
        .disabled, .macro => {},
    }
}

fn emitUp(
    target: RemapTargetResolved,
    aux: *AuxEventList,
    injected_buttons: *u64,
    held_gamepad: *u64,
) void {
    switch (target) {
        .key => |code| aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {},
        .mouse_button => |code| aux.append(.{ .mouse_button = .{ .code = code, .pressed = false } }) catch {},
        .gamepad_button => |dst| {
            const mask = buttonMask(dst);
            injected_buttons.* &= ~mask;
            held_gamepad.* &= ~mask;
        },
        .disabled, .macro => {},
    }
}

fn buttonMask(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
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
        return p.step(&self.aux, &self.queue, &self.injected, &self.tap_release);
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
    const done2 = try ctx.step(&player);
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
