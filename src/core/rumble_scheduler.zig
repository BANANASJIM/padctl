const std = @import("std");

/// Maximum number of FF effect slots padctl tracks. Matches the kernel's
/// UINPUT_NUM_EFFECTS constraint used when registering rumble on uinput.
pub const MAX_EFFECTS = 16;

/// Per-effect FF rumble auto-stop state machine.
///
/// Pure logic. No file descriptors, no clock, no syscalls. The caller passes
/// `now_ns` on every mutation and consults the return values (or `nextDeadline`)
/// to learn when the host timerfd should wake next.
///
/// Background: the Linux kernel's ff-memless.c auto-stops effects when their
/// `replay.length` elapses, but uinput uses plain `input_ff_create()` — not the
/// memless helper — so effects uploaded to padctl's virtual gamepad are never
/// auto-stopped by the kernel. This module fills that gap in userspace.
pub const RumbleScheduler = struct {
    pub const Slot = struct {
        /// 0 = not playing.
        /// INFINITE = playing with `replay.length == 0`.
        /// positive, < INFINITE = absolute monotonic deadline in nanoseconds.
        deadline_ns: i128 = 0,
        strong: u16 = 0,
        weak: u16 = 0,
    };

    pub const Frame = struct {
        strong: u16,
        weak: u16,
    };

    /// Per-effect state, indexed by FF effect id (0..MAX_EFFECTS-1).
    slots: [MAX_EFFECTS]Slot = @splat(.{}),

    /// Sentinel deadline for effects with infinite duration.
    pub const INFINITE: i128 = std.math.maxInt(i128);

    pub const ExpiryResult = struct {
        /// Frame to emit to the HID device when the aggregate active rumble
        /// changed. `null` means the hardware command state is already correct.
        frame: ?Frame,
        /// True when any effect remains active after the mutation.
        active_after: bool,
        /// Next instant at which the host timerfd should wake, or null to
        /// disarm the timerfd entirely.
        next_deadline_ns: ?i128,
    };

    /// Record that `effect_id` started playing with the given length.
    /// `length_ms == 0` means infinite (never auto-stops on its own).
    /// Out-of-range effect ids are ignored defensively.
    pub fn onPlay(self: *RumbleScheduler, effect_id: u8, strong: u16, weak: u16, length_ms: u16, now_ns: i128) ExpiryResult {
        const before = self.aggregateFrame();
        if (effect_id < MAX_EFFECTS) {
            self.slots[effect_id] = .{
                .deadline_ns = if (length_ms == 0)
                    INFINITE
                else
                    now_ns + @as(i128, length_ms) * std.time.ns_per_ms,
                .strong = strong,
                .weak = weak,
            };
        }
        const after = self.aggregateFrame();
        return .{
            .frame = changedFrame(before, after),
            .active_after = self.anyPlaying(),
            .next_deadline_ns = self.nextDeadline(),
        };
    }

    /// Record that `effect_id` was explicitly stopped by the client
    /// (EV_FF value=0). Out-of-range ids are ignored defensively.
    ///
    /// Returns an `ExpiryResult`:
    /// - `frame` is the new aggregate hardware rumble state when it changed.
    ///   This may be a zero stop frame or a non-zero restore frame for another
    ///   effect that is still active.
    /// - `next_deadline_ns` is the next pending finite deadline, or null.
    pub fn onStop(self: *RumbleScheduler, effect_id: u8) ExpiryResult {
        const before = self.aggregateFrame();
        if (effect_id < MAX_EFFECTS) {
            self.slots[effect_id] = .{};
        }
        const after = self.aggregateFrame();
        return .{
            .frame = changedFrame(before, after),
            .active_after = self.anyPlaying(),
            .next_deadline_ns = self.nextDeadline(),
        };
    }

    /// Called when the host timerfd fires. Clears every finite slot whose
    /// deadline has elapsed, then reports whether a stop frame should be
    /// emitted (no slots remain playing at all) and where the timerfd
    /// should be armed next.
    pub fn onTimerExpired(self: *RumbleScheduler, now_ns: i128) ExpiryResult {
        const before = self.aggregateFrame();
        for (&self.slots) |*s| {
            if (s.deadline_ns > 0 and s.deadline_ns != INFINITE and s.deadline_ns <= now_ns) {
                s.* = .{};
            }
        }
        const after = self.aggregateFrame();
        return .{
            .frame = changedFrame(before, after),
            .active_after = self.anyPlaying(),
            .next_deadline_ns = self.nextDeadline(),
        };
    }

    fn anyPlaying(self: *const RumbleScheduler) bool {
        for (self.slots) |s| {
            if (s.deadline_ns != 0) return true;
        }
        return false;
    }

    /// Aggregate all active effects into the single rumble command the
    /// physical controller can actually hold. This intentionally uses
    /// per-motor max: it preserves an active stronger effect, restores weaker
    /// effects after stronger overlaps stop, and avoids synthetic overdrive.
    fn aggregateFrame(self: *const RumbleScheduler) Frame {
        var out = Frame{ .strong = 0, .weak = 0 };
        for (self.slots) |s| {
            if (s.deadline_ns == 0) continue;
            out.strong = @max(out.strong, s.strong);
            out.weak = @max(out.weak, s.weak);
        }
        return out;
    }

    fn changedFrame(before: Frame, after: Frame) ?Frame {
        if (before.strong == after.strong and before.weak == after.weak) return null;
        return after;
    }

    /// Returns the raw slot array for diagnostic logging. The caller can
    /// format it without pulling I/O into the scheduler.
    pub fn dumpSlots(self: *const RumbleScheduler) [MAX_EFFECTS]i128 {
        var out: [MAX_EFFECTS]i128 = undefined;
        for (self.slots, 0..) |s, i| out[i] = s.deadline_ns;
        return out;
    }

    /// Returns the earliest finite pending deadline, or null if nothing is
    /// pending. An "infinite" slot does not contribute a deadline because
    /// it never fires from the timer.
    pub fn nextDeadline(self: *const RumbleScheduler) ?i128 {
        var min: i128 = INFINITE;
        var found = false;
        for (self.slots) |s| {
            if (s.deadline_ns > 0 and s.deadline_ns != INFINITE and s.deadline_ns < min) {
                min = s.deadline_ns;
                found = true;
            }
        }
        return if (found) min else null;
    }
};

// --- tests ---

const testing = std.testing;

fn expectFrame(actual: ?RumbleScheduler.Frame, strong: u16, weak: u16) !void {
    const frame = actual orelse return error.ExpectedFrame;
    try testing.expectEqual(strong, frame.strong);
    try testing.expectEqual(weak, frame.weak);
}

fn expectNoFrame(actual: ?RumbleScheduler.Frame) !void {
    try testing.expectEqual(@as(?RumbleScheduler.Frame, null), actual);
}

test "rumble_scheduler: empty scheduler has no pending deadline" {
    var sched: RumbleScheduler = .{};
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());
}

test "rumble_scheduler: onPlay records finite deadline at now + length_ms" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 1_000_000_000;
    const length_ms: u16 = 500;
    const expected: i128 = now + @as(i128, length_ms) * std.time.ns_per_ms;

    const result = sched.onPlay(0, 0x8000, 0x4000, length_ms, now);
    try expectFrame(result.frame, 0x8000, 0x4000);
    try testing.expectEqual(@as(?i128, expected), result.next_deadline_ns);
    try testing.expectEqual(@as(?i128, expected), sched.nextDeadline());
}

test "rumble_scheduler: onTimerExpired at deadline clears slot and emits stop" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 1_000_000_000;
    const length_ms: u16 = 500;
    const deadline = now + @as(i128, length_ms) * std.time.ns_per_ms;

    _ = sched.onPlay(0, 0x8000, 0x4000, length_ms, now);

    const result = sched.onTimerExpired(deadline);
    try expectFrame(result.frame, 0, 0);
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
    // Slot is cleared
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());
}

test "rumble_scheduler: infinite duration never contributes a deadline but stays playing" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 5_000_000_000;

    // length_ms == 0 means the kernel recorded an infinite-duration effect.
    // The scheduler should disarm the timerfd (nothing to auto-stop) but
    // still consider the slot "playing" so a spurious timer fire does not
    // emit a stop frame.
    const next_after_play = sched.onPlay(3, 0x1000, 0x2000, 0, now);
    try expectFrame(next_after_play.frame, 0x1000, 0x2000);
    try testing.expectEqual(@as(?i128, null), next_after_play.next_deadline_ns);
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());

    // If the timerfd fires later for some reason (e.g., another effect
    // expired and left this one), we must not emit a stop frame.
    const result = sched.onTimerExpired(now + 10 * std.time.ns_per_s);
    try expectNoFrame(result.frame);
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
}

test "rumble_scheduler: long-then-short overlap does not prematurely emit stop" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;
    const t300 = 300 * std.time.ns_per_ms;
    const t1000 = 1000 * std.time.ns_per_ms;

    // A plays for 1000ms starting at t=0
    _ = sched.onPlay(0, 0x1000, 0x0800, 1000, t0);
    // B plays for 200ms starting at t=100 → deadline t=300
    const next_after_b = sched.onPlay(1, 0x8000, 0x4000, 200, t100);
    try expectFrame(next_after_b.frame, 0x8000, 0x4000);
    try testing.expectEqual(@as(?i128, t300), next_after_b.next_deadline_ns);

    // Timer fires at t=300 → B expires, A still playing, restore A.
    const first = sched.onTimerExpired(t300);
    try expectFrame(first.frame, 0x1000, 0x0800);
    try testing.expectEqual(@as(?i128, t1000), first.next_deadline_ns);

    // Timer fires at t=1000 → A expires, nothing remaining, stop frame emitted
    const second = sched.onTimerExpired(t1000);
    try expectFrame(second.frame, 0, 0);
    try testing.expectEqual(@as(?i128, null), second.next_deadline_ns);
}

test "rumble_scheduler: same-id reuse replaces the deadline (latest play wins)" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;

    // Initial play: 500ms → deadline t=500
    _ = sched.onPlay(0, 0x1000, 0x0800, 500, t0);
    try testing.expectEqual(@as(?i128, 500 * std.time.ns_per_ms), sched.nextDeadline());

    // Reuse the same effect id 100ms later with a 300ms duration →
    // new deadline is t=100+300=400, replacing the old one.
    const next_after_reuse = sched.onPlay(0, 0x2000, 0x1000, 300, t100);
    const expected = t100 + 300 * std.time.ns_per_ms;
    try expectFrame(next_after_reuse.frame, 0x2000, 0x1000);
    try testing.expectEqual(@as(?i128, expected), next_after_reuse.next_deadline_ns);
    try testing.expectEqual(@as(?i128, expected), sched.nextDeadline());
}

test "rumble_scheduler: onStop of only playing effect emits stop frame" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;

    _ = sched.onPlay(0, 0x8000, 0x4000, 500, now);
    try testing.expect(sched.nextDeadline() != null);

    const result = sched.onStop(0);
    // The only playing effect stopped → event loop must emit a stop frame
    // and the timerfd must be disarmed.
    try expectFrame(result.frame, 0, 0);
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());
}

test "rumble_scheduler: onStop of one effect while another still plays restores aggregate" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;
    const a_deadline = 1000 * std.time.ns_per_ms;

    // Long effect A is playing.
    _ = sched.onPlay(0, 0x1000, 0x0800, 1000, t0);
    // Overlapping short effect B starts.
    _ = sched.onPlay(1, 0x8000, 0x4000, 500, t100);

    // Client explicitly stops B. A is still supposed to be playing, so the
    // event loop must restore A's lower magnitude instead of leaving B stuck.
    const result = sched.onStop(1);
    try expectFrame(result.frame, 0x1000, 0x0800);
    try testing.expectEqual(@as(?i128, a_deadline), result.next_deadline_ns);
}

test "rumble_scheduler: onStop of finite effect while infinite effect remains restores aggregate" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;
    const b_deadline = 500 * std.time.ns_per_ms;

    _ = sched.onPlay(0, 0x1000, 0x0800, 0, now); // infinite
    _ = sched.onPlay(1, 0x8000, 0x4000, 500, now); // finite

    // Stop the finite one; the infinite effect is still live.
    const result = sched.onStop(1);
    try expectFrame(result.frame, 0x1000, 0x0800);
    // nextDeadline returns null (infinite is not a finite deadline).
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
    _ = b_deadline;
}

test "rumble_scheduler: out-of-range effect_id does not corrupt other slots" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;
    const t500 = 500 * std.time.ns_per_ms;

    // Valid effect on slot 0
    _ = sched.onPlay(0, 0x8000, 0x4000, 500, now);

    // Out-of-range ids (>= MAX_EFFECTS=16) must be ignored and must not
    // affect the nextDeadline of the valid slot.
    _ = sched.onPlay(16, 0xffff, 0xffff, 100, now);
    _ = sched.onPlay(255, 0xffff, 0xffff, 100, now);
    _ = sched.onStop(16);
    _ = sched.onStop(200);

    try testing.expectEqual(@as(?i128, t500), sched.nextDeadline());
}

test "rumble_scheduler: short-then-long overlap rearms for the longer deadline" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;
    const t200 = 200 * std.time.ns_per_ms;
    const t1100 = 1100 * std.time.ns_per_ms;

    // A plays for 200ms starting at t=0 → deadline t=200
    _ = sched.onPlay(0, 0x8000, 0x4000, 200, t0);
    // B plays for 1000ms starting at t=100 → deadline t=1100
    // Next wake still t=200 because that's the earliest.
    const next_after_b = sched.onPlay(1, 0x1000, 0x0800, 1000, t100);
    try expectNoFrame(next_after_b.frame);
    try testing.expectEqual(@as(?i128, t200), next_after_b.next_deadline_ns);

    // Timer fires at t=200 → A expires, B still playing, restore B.
    const first = sched.onTimerExpired(t200);
    try expectFrame(first.frame, 0x1000, 0x0800);
    try testing.expectEqual(@as(?i128, t1100), first.next_deadline_ns);

    // Timer fires at t=1100 → B expires, stop frame emitted
    const second = sched.onTimerExpired(t1100);
    try expectFrame(second.frame, 0, 0);
    try testing.expectEqual(@as(?i128, null), second.next_deadline_ns);
}

test "rumble_scheduler: state identical regardless of dump_enabled" {
    // The scheduler is pure logic — logging is external.
    // Verify that the same sequence of operations produces identical
    // slot state whether dump is on or off.
    const padctl_log = @import("../log.zig");
    // defer the restore before toggling so an early `try` failure can't
    // leak dump_enabled=true to subsequent tests sharing the process.
    defer padctl_log.setEnabled(false);
    const t0: i128 = 1_000_000_000;

    // Run with dump off.
    padctl_log.setEnabled(false);
    var s1: RumbleScheduler = .{};
    _ = s1.onPlay(0, 0x8000, 0x4000, 500, t0);
    _ = s1.onPlay(1, 0x1000, 0x0800, 0, t0);
    _ = s1.onStop(0);
    const slots1 = s1.dumpSlots();

    // Run with dump on.
    padctl_log.setEnabled(true);
    var s2: RumbleScheduler = .{};
    _ = s2.onPlay(0, 0x8000, 0x4000, 500, t0);
    _ = s2.onPlay(1, 0x1000, 0x0800, 0, t0);
    _ = s2.onStop(0);
    const slots2 = s2.dumpSlots();

    // Slot arrays must be identical.
    for (slots1, slots2) |a, b| {
        try testing.expectEqual(a, b);
    }
}
