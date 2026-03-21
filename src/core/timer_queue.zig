const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

pub const Deadline = struct {
    absolute_ns: i128,
    token: u32,
};

fn deadlineOrder(_: void, a: Deadline, b: Deadline) std.math.Order {
    return std.math.order(a.absolute_ns, b.absolute_ns);
}

pub const TimerQueue = struct {
    heap: std.PriorityQueue(Deadline, void, deadlineOrder),
    timer_fd: posix.fd_t,

    pub fn init(allocator: std.mem.Allocator, timer_fd: posix.fd_t) TimerQueue {
        return .{
            .heap = std.PriorityQueue(Deadline, void, deadlineOrder).init(allocator, {}),
            .timer_fd = timer_fd,
        };
    }

    pub fn deinit(self: *TimerQueue) void {
        self.heap.deinit();
    }

    pub fn arm(self: *TimerQueue, deadline_ns: i128, token: u32) !void {
        try self.heap.add(.{ .absolute_ns = deadline_ns, .token = token });
        self.rearmFd();
    }

    /// Drain all entries with absolute_ns <= now_ns. Returns slice into caller-provided buf.
    pub fn drainExpired(self: *TimerQueue, now_ns: i128, buf: []Deadline) []Deadline {
        var count: usize = 0;
        while (self.heap.peek()) |top| {
            if (top.absolute_ns > now_ns) break;
            buf[count] = self.heap.remove();
            count += 1;
            if (count >= buf.len) break;
        }
        self.rearmFd();
        return buf[0..count];
    }

    pub fn cancel(self: *TimerQueue, token: u32) void {
        // Rebuild heap minus matching token.
        var tmp = std.PriorityQueue(Deadline, void, deadlineOrder).init(
            self.heap.allocator,
            {},
        );
        defer tmp.deinit();
        // Drain all into tmp, skip the cancelled token.
        while (self.heap.removeOrNull()) |d| {
            if (d.token == token) continue;
            tmp.add(d) catch {};
        }
        // Swap back.
        while (tmp.removeOrNull()) |d| {
            self.heap.add(d) catch {};
        }
        self.rearmFd();
    }

    fn rearmFd(self: *TimerQueue) void {
        if (self.heap.peek()) |top| {
            const now = std.time.nanoTimestamp();
            const delta_ns = top.absolute_ns - now;
            const delta_clamped: u64 = if (delta_ns <= 0) 1 else @intCast(delta_ns);
            const spec = linux.itimerspec{
                .it_value = .{
                    .sec = @intCast(delta_clamped / std.time.ns_per_s),
                    .nsec = @intCast(delta_clamped % std.time.ns_per_s),
                },
                .it_interval = .{ .sec = 0, .nsec = 0 },
            };
            _ = linux.timerfd_settime(self.timer_fd, .{}, &spec, null);
        } else {
            // Disarm.
            const spec = linux.itimerspec{
                .it_value = .{ .sec = 0, .nsec = 0 },
                .it_interval = .{ .sec = 0, .nsec = 0 },
            };
            _ = linux.timerfd_settime(self.timer_fd, .{}, &spec, null);
        }
    }
};

// --- tests ---

const testing = std.testing;

test "TimerQueue: arm + drainExpired returns expired entries" {
    const allocator = testing.allocator;
    // Use a dummy fd (-1) — rearmFd is a no-op on invalid fd (EBADF silently ignored).
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    const now: i128 = 1_000_000_000;
    try q.arm(now - 1, 1);
    try q.arm(now + 100_000, 2);
    try q.arm(now - 500, 3);

    var buf: [8]Deadline = undefined;
    const expired = q.drainExpired(now, &buf);
    try testing.expectEqual(@as(usize, 2), expired.len);
    // min-heap: token 3 (now-500) before token 1 (now-1)
    try testing.expectEqual(@as(u32, 3), expired[0].token);
    try testing.expectEqual(@as(u32, 1), expired[1].token);

    // Token 2 still in queue
    try testing.expectEqual(@as(usize, 1), q.heap.count());
    try testing.expectEqual(@as(u32, 2), q.heap.peek().?.token);
}

test "TimerQueue: drainExpired empty heap returns empty slice" {
    const allocator = testing.allocator;
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    var buf: [4]Deadline = undefined;
    const expired = q.drainExpired(std.time.nanoTimestamp(), &buf);
    try testing.expectEqual(@as(usize, 0), expired.len);
}

test "TimerQueue: cancel removes matching token" {
    const allocator = testing.allocator;
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    try q.arm(1000, 10);
    try q.arm(2000, 20);
    try q.arm(3000, 30);

    q.cancel(20);
    try testing.expectEqual(@as(usize, 2), q.heap.count());

    var buf: [8]Deadline = undefined;
    const expired = q.drainExpired(9999, &buf);
    try testing.expectEqual(@as(usize, 2), expired.len);
    try testing.expectEqual(@as(u32, 10), expired[0].token);
    try testing.expectEqual(@as(u32, 30), expired[1].token);
}

test "TimerQueue: cancel nonexistent token is a no-op" {
    const allocator = testing.allocator;
    var q = TimerQueue.init(allocator, -1);
    defer q.deinit();

    try q.arm(1000, 5);
    q.cancel(99);
    try testing.expectEqual(@as(usize, 1), q.heap.count());
}

test "TimerQueue: arm + drain with real timerfd fires within deadline" {
    const allocator = testing.allocator;
    const timer_fd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
    defer posix.close(timer_fd);

    var q = TimerQueue.init(allocator, timer_fd);
    defer q.deinit();

    const deadline = std.time.nanoTimestamp() + 30 * std.time.ns_per_ms;
    try q.arm(deadline, 42);

    var pfd = [1]posix.pollfd{.{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 200);
    try testing.expectEqual(@as(usize, 1), ready);

    var expiry: [8]u8 = undefined;
    _ = try posix.read(timer_fd, &expiry);

    var buf: [4]Deadline = undefined;
    const expired = q.drainExpired(std.time.nanoTimestamp(), &buf);
    try testing.expectEqual(@as(usize, 1), expired.len);
    try testing.expectEqual(@as(u32, 42), expired[0].token);
}
