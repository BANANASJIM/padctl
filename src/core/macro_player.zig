const std = @import("std");
const macro_mod = @import("macro.zig");
const remap = @import("remap.zig");
const timer_queue_mod = @import("timer_queue.zig");

const Macro = macro_mod.Macro;
const MacroStep = macro_mod.MacroStep;
const aux_event_mod = @import("aux_event.zig");
const AuxEventList = aux_event_mod.AuxEventList;
const AuxEvent = aux_event_mod.AuxEvent;
const TimerQueue = timer_queue_mod.TimerQueue;

pub const MacroPlayer = struct {
    macro: *const Macro,
    step_index: usize,
    waiting_for_release: bool,
    /// Token used when a delay deadline is armed in the TimerQueue.
    timer_token: u32,

    pub fn init(m: *const Macro, token: u32) MacroPlayer {
        return .{
            .macro = m,
            .step_index = 0,
            .waiting_for_release = false,
            .timer_token = token,
        };
    }

    /// Execute synchronous steps until delay / pause_for_release / end.
    /// Returns true when the macro is finished (caller should remove it).
    pub fn step(self: *MacroPlayer, aux: *AuxEventList, queue: *TimerQueue) !bool {
        if (self.waiting_for_release) return false;

        while (self.step_index < self.macro.steps.len) {
            const s = self.macro.steps[self.step_index];
            self.step_index += 1;
            switch (s) {
                .tap => |name| {
                    const code = resolveKeyCode(name) orelse continue;
                    aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {};
                    aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
                },
                .down => |name| {
                    const code = resolveKeyCode(name) orelse continue;
                    aux.append(.{ .key = .{ .code = code, .pressed = true } }) catch {};
                },
                .up => |name| {
                    const code = resolveKeyCode(name) orelse continue;
                    aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
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

    /// Emit up-events for any currently held keys (used on layer switch / cancel).
    pub fn emitPendingReleases(self: *const MacroPlayer, aux: *AuxEventList) void {
        // Walk steps up to step_index, track net held state per name.
        // Simple approach: scan for down/tap before step_index, emit up for downs without a subsequent up.
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
                    // Remove from held list
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
                .tap => {
                    // tap is self-contained press+release; no residual hold
                },
                .delay, .pause_for_release => {},
            }
        }

        for (held[0..held_len]) |h| {
            const name = h orelse continue;
            const code = resolveKeyCode(name) orelse continue;
            aux.append(.{ .key = .{ .code = code, .pressed = false } }) catch {};
        }
    }
};

fn resolveKeyCode(name: []const u8) ?u16 {
    const target = remap.resolveTarget(name) catch return null;
    return switch (target) {
        .key => |code| code,
        else => null,
    };
}

// --- tests ---

const testing = std.testing;
const mapping = @import("../config/mapping.zig");

fn makePlayer(m: *const Macro) MacroPlayer {
    return MacroPlayer.init(m, 1);
}

fn dummyQueue(allocator: std.mem.Allocator) TimerQueue {
    return TimerQueue.init(allocator, -1);
}

test "macro_player: tap step press then release emitted" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{.{ .tap = "KEY_B" }};
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var aux = AuxEventList{};
    var q = dummyQueue(allocator);
    defer q.deinit();

    const done = try player.step(&aux, &q);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), aux.len);
    switch (aux.get(0)) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }
    switch (aux.get(1)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: down + up steps held then released" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "KEY_LEFTSHIFT" }, .{ .up = "KEY_LEFTSHIFT" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var aux = AuxEventList{};
    var q = dummyQueue(allocator);
    defer q.deinit();

    const done = try player.step(&aux, &q);
    try testing.expect(done);
    try testing.expectEqual(@as(usize, 2), aux.len);
    switch (aux.get(0)) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }
    switch (aux.get(1)) {
        .key => |k| try testing.expect(!k.pressed),
        else => return error.WrongType,
    }
}

test "macro_player: delay arms timer queue returns not-done" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .tap = "KEY_A" }, .{ .delay = 50 }, .{ .tap = "KEY_B" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var aux = AuxEventList{};
    var q = dummyQueue(allocator);
    defer q.deinit();

    // First resume: executes tap A, hits delay, stops
    const done1 = try player.step(&aux, &q);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 2), aux.len); // only tap A (press+release)
    try testing.expectEqual(@as(usize, 1), q.heap.count());

    // Second resume (after timer): executes tap B, finishes
    var aux2 = AuxEventList{};
    const done2 = try player.step(&aux2, &q);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 2), aux2.len);
}

test "macro_player: pause_for_release halts until notifyTriggerReleased" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .pause_for_release, .{ .tap = "KEY_A" } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var aux = AuxEventList{};
    var q = dummyQueue(allocator);
    defer q.deinit();

    const done1 = try player.step(&aux, &q);
    try testing.expect(!done1);
    try testing.expectEqual(@as(usize, 0), aux.len);

    // notify release -> resume continues
    player.notifyTriggerReleased();
    var aux2 = AuxEventList{};
    const done2 = try player.step(&aux2, &q);
    try testing.expect(done2);
    try testing.expectEqual(@as(usize, 2), aux2.len);
}

test "macro_player: emitPendingReleases down without up emits release" {
    const allocator = testing.allocator;
    const steps = [_]MacroStep{ .{ .down = "KEY_LEFTSHIFT" }, .{ .delay = 100 } };
    const m = Macro{ .name = "t", .steps = &steps };
    var player = makePlayer(&m);
    var aux = AuxEventList{};
    var q = dummyQueue(allocator);
    defer q.deinit();

    _ = try player.step(&aux, &q); // executes down, hits delay

    var aux2 = AuxEventList{};
    player.emitPendingReleases(&aux2);
    try testing.expectEqual(@as(usize, 1), aux2.len);
    switch (aux2.get(0)) {
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
    var pa = MacroPlayer.init(&ma, 1);
    var pb = MacroPlayer.init(&mb, 2);
    var q = dummyQueue(allocator);
    defer q.deinit();

    var auxa = AuxEventList{};
    var auxb = AuxEventList{};

    const done_a = try pa.step(&auxa, &q);
    const done_b = try pb.step(&auxb, &q);

    try testing.expect(done_a);
    try testing.expect(done_b);
    try testing.expectEqual(@as(usize, 4), auxa.len); // tap A + tap B
    try testing.expectEqual(@as(usize, 2), auxb.len); // tap C
}
