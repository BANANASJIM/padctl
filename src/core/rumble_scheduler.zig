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
    /// Per-slot deadline, indexed by FF effect id (0..MAX_EFFECTS-1).
    /// 0 = not playing.
    /// INFINITE = playing with `replay.length == 0` (never auto-stops on its own).
    /// positive, < INFINITE = absolute monotonic deadline in nanoseconds.
    slots: [MAX_EFFECTS]i128 = @splat(0),

    /// Sentinel deadline for effects with infinite duration.
    pub const INFINITE: i128 = std.math.maxInt(i128);

    pub const ExpiryResult = struct {
        /// When true, the event loop must emit a stop frame to the HID device
        /// because no effect remains playing.
        emit_stop_frame: bool,
        /// Next instant at which the host timerfd should wake, or null to
        /// disarm the timerfd entirely.
        next_deadline_ns: ?i128,
    };

    /// Record that `effect_id` started playing with the given length.
    /// `length_ms == 0` means infinite (never auto-stops on its own).
    /// Out-of-range effect ids are ignored defensively.
    /// Returns the new earliest finite deadline, or null if none is pending.
    pub fn onPlay(self: *RumbleScheduler, effect_id: u8, length_ms: u16, now_ns: i128) ?i128 {
        if (effect_id >= MAX_EFFECTS) return self.nextDeadline();
        self.slots[effect_id] = if (length_ms == 0)
            INFINITE
        else
            now_ns + @as(i128, length_ms) * std.time.ns_per_ms;
        return self.nextDeadline();
    }

    /// Record that `effect_id` was explicitly stopped by the client
    /// (EV_FF value=0). Out-of-range ids are ignored defensively.
    ///
    /// Returns an `ExpiryResult`:
    /// - `emit_stop_frame` is true ONLY when no effect remains playing
    ///   (finite or infinite). The caller must not emit a zero frame to
    ///   HID when another effect is still active, otherwise the long
    ///   effect's motor would be cut off mid-playback.
    /// - `next_deadline_ns` is the next pending finite deadline, or null.
    pub fn onStop(self: *RumbleScheduler, effect_id: u8) ExpiryResult {
        if (effect_id < MAX_EFFECTS) {
            self.slots[effect_id] = 0;
        }
        return .{
            .emit_stop_frame = !self.anyPlaying(),
            .next_deadline_ns = self.nextDeadline(),
        };
    }

    /// Called when the host timerfd fires. Clears every finite slot whose
    /// deadline has elapsed, then reports whether a stop frame should be
    /// emitted (no slots remain playing at all) and where the timerfd
    /// should be armed next.
    pub fn onTimerExpired(self: *RumbleScheduler, now_ns: i128) ExpiryResult {
        for (&self.slots) |*s| {
            if (s.* > 0 and s.* != INFINITE and s.* <= now_ns) {
                s.* = 0;
            }
        }
        return .{
            .emit_stop_frame = !self.anyPlaying(),
            .next_deadline_ns = self.nextDeadline(),
        };
    }

    /// True when any slot has a non-zero deadline (finite OR infinite).
    /// Used by `onStop` and `onTimerExpired` to decide whether the event
    /// loop must emit a zero rumble frame to HID.
    fn anyPlaying(self: *const RumbleScheduler) bool {
        for (self.slots) |s| {
            if (s != 0) return true;
        }
        return false;
    }

    /// Returns the raw slot array for diagnostic logging. The caller can
    /// format it without pulling I/O into the scheduler.
    pub fn dumpSlots(self: *const RumbleScheduler) [MAX_EFFECTS]i128 {
        return self.slots;
    }

    /// Returns the earliest finite pending deadline, or null if nothing is
    /// pending. An "infinite" slot does not contribute a deadline because
    /// it never fires from the timer.
    pub fn nextDeadline(self: *const RumbleScheduler) ?i128 {
        var min: i128 = INFINITE;
        var found = false;
        for (self.slots) |s| {
            if (s > 0 and s != INFINITE and s < min) {
                min = s;
                found = true;
            }
        }
        return if (found) min else null;
    }
};

// --- tests ---

const testing = std.testing;

test "rumble_scheduler: empty scheduler has no pending deadline" {
    var sched: RumbleScheduler = .{};
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());
}

test "rumble_scheduler: onPlay records finite deadline at now + length_ms" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 1_000_000_000;
    const length_ms: u16 = 500;
    const expected: i128 = now + @as(i128, length_ms) * std.time.ns_per_ms;

    const next = sched.onPlay(0, length_ms, now);
    try testing.expectEqual(@as(?i128, expected), next);
    try testing.expectEqual(@as(?i128, expected), sched.nextDeadline());
}

test "rumble_scheduler: onTimerExpired at deadline clears slot and emits stop" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 1_000_000_000;
    const length_ms: u16 = 500;
    const deadline = now + @as(i128, length_ms) * std.time.ns_per_ms;

    _ = sched.onPlay(0, length_ms, now);

    const result = sched.onTimerExpired(deadline);
    try testing.expect(result.emit_stop_frame);
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
    const next_after_play = sched.onPlay(3, 0, now);
    try testing.expectEqual(@as(?i128, null), next_after_play);
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());

    // If the timerfd fires later for some reason (e.g., another effect
    // expired and left this one), we must not emit a stop frame.
    const result = sched.onTimerExpired(now + 10 * std.time.ns_per_s);
    try testing.expect(!result.emit_stop_frame);
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
}

test "rumble_scheduler: long-then-short overlap does not prematurely emit stop" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;
    const t300 = 300 * std.time.ns_per_ms;
    const t1000 = 1000 * std.time.ns_per_ms;

    // A plays for 1000ms starting at t=0
    _ = sched.onPlay(0, 1000, t0);
    // B plays for 200ms starting at t=100 → deadline t=300
    const next_after_b = sched.onPlay(1, 200, t100);
    try testing.expectEqual(@as(?i128, t300), next_after_b);

    // Timer fires at t=300 → B expires, A still playing, no stop frame
    const first = sched.onTimerExpired(t300);
    try testing.expect(!first.emit_stop_frame);
    try testing.expectEqual(@as(?i128, t1000), first.next_deadline_ns);

    // Timer fires at t=1000 → A expires, nothing remaining, stop frame emitted
    const second = sched.onTimerExpired(t1000);
    try testing.expect(second.emit_stop_frame);
    try testing.expectEqual(@as(?i128, null), second.next_deadline_ns);
}

test "rumble_scheduler: same-id reuse replaces the deadline (latest play wins)" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;

    // Initial play: 500ms → deadline t=500
    _ = sched.onPlay(0, 500, t0);
    try testing.expectEqual(@as(?i128, 500 * std.time.ns_per_ms), sched.nextDeadline());

    // Reuse the same effect id 100ms later with a 300ms duration →
    // new deadline is t=100+300=400, replacing the old one.
    const next_after_reuse = sched.onPlay(0, 300, t100);
    const expected = t100 + 300 * std.time.ns_per_ms;
    try testing.expectEqual(@as(?i128, expected), next_after_reuse);
    try testing.expectEqual(@as(?i128, expected), sched.nextDeadline());
}

test "rumble_scheduler: onStop of only playing effect emits stop frame" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;

    _ = sched.onPlay(0, 500, now);
    try testing.expect(sched.nextDeadline() != null);

    const result = sched.onStop(0);
    // The only playing effect stopped → event loop must emit a stop frame
    // and the timerfd must be disarmed.
    try testing.expect(result.emit_stop_frame);
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
    try testing.expectEqual(@as(?i128, null), sched.nextDeadline());
}

test "rumble_scheduler: onStop of one effect while another still plays must NOT emit stop" {
    var sched: RumbleScheduler = .{};
    const t0: i128 = 0;
    const t100 = 100 * std.time.ns_per_ms;
    const a_deadline = 1000 * std.time.ns_per_ms;

    // Long effect A is playing.
    _ = sched.onPlay(0, 1000, t0);
    // Overlapping short effect B starts.
    _ = sched.onPlay(1, 500, t100);

    // Client explicitly stops B. A is still supposed to be playing, so the
    // event loop must NOT cut the motor — emit_stop_frame must be false.
    // The timerfd must be rearmed for A's remaining deadline.
    const result = sched.onStop(1);
    try testing.expect(!result.emit_stop_frame);
    try testing.expectEqual(@as(?i128, a_deadline), result.next_deadline_ns);
}

test "rumble_scheduler: onStop of infinite-duration effect while another plays must NOT emit stop" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;
    const b_deadline = 500 * std.time.ns_per_ms;

    _ = sched.onPlay(0, 0, now); // infinite
    _ = sched.onPlay(1, 500, now); // finite

    // Stop the finite one; the infinite effect is still live → no stop frame.
    const result = sched.onStop(1);
    try testing.expect(!result.emit_stop_frame);
    // nextDeadline returns null (infinite is not a finite deadline).
    try testing.expectEqual(@as(?i128, null), result.next_deadline_ns);
    _ = b_deadline;
}

test "rumble_scheduler: out-of-range effect_id does not corrupt other slots" {
    var sched: RumbleScheduler = .{};
    const now: i128 = 0;
    const t500 = 500 * std.time.ns_per_ms;

    // Valid effect on slot 0
    _ = sched.onPlay(0, 500, now);

    // Out-of-range ids (>= MAX_EFFECTS=16) must be ignored and must not
    // affect the nextDeadline of the valid slot.
    _ = sched.onPlay(16, 100, now);
    _ = sched.onPlay(255, 100, now);
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
    _ = sched.onPlay(0, 200, t0);
    // B plays for 1000ms starting at t=100 → deadline t=1100
    // Next wake still t=200 because that's the earliest.
    const next_after_b = sched.onPlay(1, 1000, t100);
    try testing.expectEqual(@as(?i128, t200), next_after_b);

    // Timer fires at t=200 → A expires, B still playing, no stop, rearm at t=1100
    const first = sched.onTimerExpired(t200);
    try testing.expect(!first.emit_stop_frame);
    try testing.expectEqual(@as(?i128, t1100), first.next_deadline_ns);

    // Timer fires at t=1100 → B expires, stop frame emitted
    const second = sched.onTimerExpired(t1100);
    try testing.expect(second.emit_stop_frame);
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
    _ = s1.onPlay(0, 500, t0);
    _ = s1.onPlay(1, 0, t0);
    _ = s1.onStop(0);
    const slots1 = s1.dumpSlots();

    // Run with dump on.
    padctl_log.setEnabled(true);
    var s2: RumbleScheduler = .{};
    _ = s2.onPlay(0, 500, t0);
    _ = s2.onPlay(1, 0, t0);
    _ = s2.onStop(0);
    const slots2 = s2.dumpSlots();

    // Slot arrays must be identical.
    for (slots1, slots2) |a, b| {
        try testing.expectEqual(a, b);
    }
}
