const std = @import("std");
const Config = @import("../config/device.zig").KeepaliveConfig;

/// One in-flight session-maintenance packet, driven by CLOCK_MONOTONIC.
/// The EventLoop admits packets to the shared physical writer; this state
/// machine never performs I/O, sleeps or queues missed ticks.
pub const Keepalive = struct {
    bytes: [64]u8 = .{0} ** 64,
    len: usize,
    sequence_offset: usize,
    sequence: u8,
    sequence_skip_zero: bool,
    period_ns: i128,
    startup_interval_ns: i128,
    short_intervals_left: u8,
    deadline_ns: i128,
    in_flight: bool = false,
    active: bool = true,
    failures: u8 = 0,

    pub fn init(cfg: Config, now_ns: i128) !Keepalive {
        if (cfg.report_size < 1 or cfg.report_size > 64 or cfg.sequence_offset < 0 or cfg.sequence_offset >= cfg.report_size or
            cfg.sequence_start < 0 or cfg.sequence_start > 255 or (cfg.sequence_skip_zero and cfg.sequence_start == 0) or cfg.period_ms < 10 or cfg.period_ms > 60000 or
            cfg.startup_count < 0 or cfg.startup_count > 32 or cfg.startup_interval_ms < 10 or cfg.startup_interval_ms > 60000) return error.InvalidConfig;
        var result = Keepalive{
            .len = @intCast(cfg.report_size),
            .sequence_offset = @intCast(cfg.sequence_offset),
            .sequence = @intCast(cfg.sequence_start),
            .sequence_skip_zero = cfg.sequence_skip_zero,
            .period_ns = cfg.period_ms * std.time.ns_per_ms,
            .startup_interval_ns = cfg.startup_interval_ms * std.time.ns_per_ms,
            .short_intervals_left = @intCast(cfg.startup_count),
            .deadline_ns = now_ns,
        };
        var nibble: ?u8 = null;
        var offset: usize = 0;
        for (cfg.packet) |ch| {
            if (ch == ' ') continue;
            const value = std.fmt.charToDigit(ch, 16) catch return error.InvalidConfig;
            if (nibble) |hi| {
                if (offset >= result.len) return error.InvalidConfig;
                result.bytes[offset] = hi * 16 + value;
                offset += 1;
                nibble = null;
            } else nibble = value;
        }
        if (nibble != null or offset == 0 or result.sequence_offset >= offset) return error.InvalidConfig;
        return result;
    }

    pub fn due(self: *const Keepalive, now_ns: i128) bool {
        return self.active and !self.in_flight and now_ns >= self.deadline_ns;
    }

    pub fn packet(self: *Keepalive) []const u8 {
        self.bytes[self.sequence_offset] = self.sequence;
        return self.bytes[0..self.len];
    }

    /// Call only after the writer accepted this packet. No mailbox overwrite
    /// or failed admission consumes a sequence number.
    pub fn submitted(self: *Keepalive) void {
        std.debug.assert(!self.in_flight);
        self.in_flight = true;
        self.sequence +%= 1;
        if (self.sequence_skip_zero and self.sequence == 0) self.sequence = 1;
    }

    pub fn completed(self: *Keepalive, now_ns: i128, success: bool) !void {
        std.debug.assert(self.in_flight);
        self.in_flight = false;
        if (!success) {
            self.failures += 1;
            if (self.failures >= 3) return error.KeepaliveWriteFailed;
            self.deadline_ns = now_ns + self.period_ns;
            return;
        }
        self.failures = 0;
        // startup_count=3: packets at 0/50/100ms, first regular packet at
        // 150ms, then every 450ms for the GameSir reference. Timing is based
        // on write completion so a stall cannot produce a catch-up burst.
        const interval = if (self.short_intervals_left > 0) self.startup_interval_ns else self.period_ns;
        self.short_intervals_left -|= 1;
        self.deadline_ns = now_ns + interval;
    }

    /// Pause after the shared writer has joined. Mapping-loop restarts retain
    /// sequence/cadence; physical rebind drops this object and primes anew.
    pub fn pause(self: *Keepalive, now_ns: i128) void {
        self.active = false;
        self.in_flight = false;
        self.deadline_ns = now_ns + self.period_ns;
    }
    pub fn restart(self: *Keepalive, now_ns: i128) void {
        self.active = true;
        self.deadline_ns = now_ns + self.period_ns;
    }
};
