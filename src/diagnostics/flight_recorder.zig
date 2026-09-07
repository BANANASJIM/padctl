const std = @import("std");
const builtin = @import("builtin");
const padctl_log = @import("../log.zig");

/// Lines held in the ring before the oldest is overwritten.
pub const RING_LINES: usize = 1024;
/// Bytes stored per line (`conventions/logging.md` §5).
pub const LINE_MAX: usize = 256;
/// Minimum spacing between two automatic flushes.
pub const MIN_FLUSH_INTERVAL_NS: i128 = 30 * std.time.ns_per_s;

pub const Reason = enum {
    rumble_stuck,
    rumble_write_dropped,
    disconnect,
    signal,
    export_request,
    shutdown,

    pub fn text(self: Reason) []const u8 {
        return switch (self) {
            .rumble_stuck => "rumble-stuck",
            .rumble_write_dropped => "rumble-write-dropped",
            .disconnect => "disconnect",
            .signal => "signal",
            .export_request => "export",
            .shutdown => "shutdown",
        };
    }

    /// Automatic triggers fire from fault paths that can repeat quickly, so
    /// they are rate limited. Operator-initiated flushes never are.
    fn automatic(self: Reason) bool {
        return switch (self) {
            .rumble_stuck, .rumble_write_dropped, .disconnect => true,
            .signal, .export_request, .shutdown => false,
        };
    }
};

pub const LastFlush = struct {
    reason: Reason,
    ms_ago: u64,
};

/// Serializes the ring across device threads, the rumble writer worker and
/// the supervisor thread. Lock order is `mutex` then the log file mutex;
/// never the reverse, so `flush` may log a warning while holding it.
var mutex: std.Thread.Mutex = .{};
var ring: [RING_LINES][LINE_MAX]u8 = undefined;
var lens: [RING_LINES]u16 = .{0} ** RING_LINES;
var head: usize = 0;
var count: usize = 0;
var last_flush_ns: ?i128 = null;
var last_flush_reason: Reason = .shutdown;
var unwritable_warns: usize = 0;
var clock_override: ?i128 = null;

fn nowNs() i128 {
    if (builtin.is_test) {
        if (clock_override) |v| return v;
    }
    return padctl_log.monotonicNs();
}

/// Store one formatted log line. The trailing newline is dropped and the
/// content truncated to `LINE_MAX`; `flush` re-adds the separator.
pub fn record(line: []const u8) void {
    const trimmed = std.mem.trimRight(u8, line, "\r\n");
    if (trimmed.len == 0) return;
    const n = @min(trimmed.len, LINE_MAX);

    mutex.lock();
    defer mutex.unlock();

    @memcpy(ring[head][0..n], trimmed[0..n]);
    lens[head] = @intCast(n);
    head = (head + 1) % RING_LINES;
    if (count < RING_LINES) count += 1;
}

/// Number of lines currently buffered.
pub fn buffered() usize {
    mutex.lock();
    defer mutex.unlock();
    return count;
}

/// Reason and age of the most recent flush that reached the log file.
pub fn lastFlush() ?LastFlush {
    mutex.lock();
    defer mutex.unlock();
    const at = last_flush_ns orelse return null;
    const delta = nowNs() - at;
    const ms: i128 = if (delta <= 0) 0 else @divFloor(delta, std.time.ns_per_ms);
    return .{
        .reason = last_flush_reason,
        .ms_ago = @intCast(@min(ms, std.math.maxInt(u64))),
    };
}

/// Append the buffered lines to the padctl log file, framed by
/// `FLIGHT_RECORDER begin`/`end`, then clear the ring. Returns the number of
/// lines written — zero when the ring is empty, the automatic trigger was
/// rate limited, or the log file could not be written.
pub fn flush(reason: Reason) usize {
    mutex.lock();
    defer mutex.unlock();

    if (count == 0) return 0;
    const now = nowNs();
    if (reason.automatic()) {
        if (last_flush_ns) |prev| {
            if (now - prev < MIN_FLUSH_INTERVAL_NS) return 0;
        }
    }

    var out: [4096]u8 = undefined;
    var used: usize = 0;

    var header_buf: [96]u8 = undefined;
    const header = std.fmt.bufPrint(
        &header_buf,
        "FLIGHT_RECORDER begin reason={s} lines={d}\n",
        .{ reason.text(), count },
    ) catch return warnUnwritable();
    if (!append(&out, &used, header)) return warnUnwritable();

    const oldest = if (count < RING_LINES) 0 else head;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const idx = (oldest + i) % RING_LINES;
        if (!append(&out, &used, ring[idx][0..lens[idx]])) return warnUnwritable();
        if (!append(&out, &used, "\n")) return warnUnwritable();
    }
    if (!append(&out, &used, "FLIGHT_RECORDER end\n")) return warnUnwritable();
    if (used > 0 and !padctl_log.appendToLogFile(out[0..used])) return warnUnwritable();

    const written = count;
    head = 0;
    count = 0;
    last_flush_ns = now;
    last_flush_reason = reason;
    return written;
}

/// Buffer `data`, spilling to the log file whenever the staging buffer fills
/// so a full ring costs tens of writes rather than one per line.
fn append(out: *[4096]u8, used: *usize, data: []const u8) bool {
    var rest = data;
    while (rest.len > 0) {
        if (used.* == out.len) {
            if (!padctl_log.appendToLogFile(out[0..used.*])) return false;
            used.* = 0;
        }
        const n = @min(out.len - used.*, rest.len);
        @memcpy(out[used.* .. used.* + n], rest[0..n]);
        used.* += n;
        rest = rest[n..];
    }
    return true;
}

/// Report an unwritable log file once per process and keep the ring intact so
/// a later flush (e.g. after `padctl dump enable`) can still persist it.
fn warnUnwritable() usize {
    if (unwritable_warns == 0) {
        std.log.warn("flight recorder: log file unwritable, flush dropped ({d} lines buffered)", .{count});
        unwritable_warns += 1;
    }
    return 0;
}

/// Number of unwritable-log-file warnings emitted since process start.
pub fn unwritableWarnCount() usize {
    mutex.lock();
    defer mutex.unlock();
    return unwritable_warns;
}

/// Test hook: drop the ring, the rate-limit state and the clock override.
pub fn resetForTest() void {
    if (!builtin.is_test) return;
    mutex.lock();
    defer mutex.unlock();
    head = 0;
    count = 0;
    last_flush_ns = null;
    unwritable_warns = 0;
    clock_override = null;
}

/// Test hook: freeze the clock used for rate limiting and flush ages.
pub fn setClockForTest(ns: ?i128) void {
    if (!builtin.is_test) return;
    clock_override = ns;
}

// --- tests ---

const testing = std.testing;

/// Redirect the log writer into `tmp` and reset recorder state. The returned
/// path stays valid for the lifetime of `buf`.
fn attachTestLog(tmp: *std.testing.TmpDir, buf: []u8) ![]const u8 {
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = try tmp.dir.realpath(".", &dir_buf);
    const path = try std.fmt.bufPrint(buf, "{s}/padctl.log", .{dir});
    padctl_log.setLogPathForTest(path);
    resetForTest();
    return path;
}

fn detachTestLog() void {
    padctl_log.setLogPathForTest("");
    resetForTest();
}

fn readTestLog(tmp: *std.testing.TmpDir) ![]u8 {
    return tmp.dir.readFileAlloc(testing.allocator, "padctl.log", 4 * 1024 * 1024);
}

test "flight_recorder: flush frames buffered lines in record order" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    record("first\n");
    record("second\n");
    record("third\n");
    try testing.expectEqual(@as(usize, 3), buffered());
    try testing.expectEqual(@as(usize, 3), flush(.signal));

    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    try testing.expectEqualStrings(
        "FLIGHT_RECORDER begin reason=signal lines=3\nfirst\nsecond\nthird\nFLIGHT_RECORDER end\n",
        content,
    );
}

test "flight_recorder: ring overwrites the oldest line at capacity" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    var i: usize = 0;
    while (i < RING_LINES + 3) : (i += 1) {
        var line_buf: [32]u8 = undefined;
        record(try std.fmt.bufPrint(&line_buf, "line-{d}", .{i}));
    }
    try testing.expectEqual(RING_LINES, buffered());
    try testing.expectEqual(RING_LINES, flush(.signal));

    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    // The three oldest lines were overwritten; the newest survived.
    try testing.expect(std.mem.indexOf(u8, content, "\nline-0\n") == null);
    try testing.expect(std.mem.indexOf(u8, content, "\nline-2\n") == null);
    try testing.expect(std.mem.indexOf(u8, content, "\nline-3\n") != null);
    var it = std.mem.splitScalar(u8, content, '\n');
    _ = it.next(); // header
    try testing.expectEqualStrings("line-3", it.next().?);
    const tail = std.mem.indexOf(u8, content, "line-1026\nFLIGHT_RECORDER end\n");
    try testing.expect(tail != null);
}

test "flight_recorder: flush clears the ring" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    record("only");
    try testing.expectEqual(@as(usize, 1), flush(.signal));
    try testing.expectEqual(@as(usize, 0), buffered());
    try testing.expectEqual(@as(usize, 0), flush(.signal));

    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, content, "FLIGHT_RECORDER begin"));
}

test "flight_recorder: record truncates a line at LINE_MAX" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    var long: [LINE_MAX + 100]u8 = undefined;
    @memset(&long, 'x');
    record(&long);
    _ = flush(.signal);

    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    var it = std.mem.splitScalar(u8, content, '\n');
    _ = it.next(); // header
    try testing.expectEqual(LINE_MAX, it.next().?.len);
}

test "flight_recorder: empty ring writes nothing" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    try testing.expectEqual(@as(usize, 0), flush(.shutdown));
    try testing.expectError(error.FileNotFound, readTestLog(&tmp));
}

test "flight_recorder: automatic flush is rate limited, explicit flush is not" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    setClockForTest(0);
    record("a");
    try testing.expectEqual(@as(usize, 1), flush(.disconnect));

    setClockForTest(MIN_FLUSH_INTERVAL_NS - 1);
    record("b");
    try testing.expectEqual(@as(usize, 0), flush(.rumble_stuck));
    try testing.expectEqual(@as(usize, 1), buffered());

    // Explicit triggers ignore the window.
    try testing.expectEqual(@as(usize, 1), flush(.export_request));

    // Past the window an automatic trigger fires again.
    setClockForTest(2 * MIN_FLUSH_INTERVAL_NS);
    record("c");
    try testing.expectEqual(@as(usize, 1), flush(.rumble_write_dropped));
}

test "flight_recorder: lastFlush reports reason and age" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();

    try testing.expectEqual(@as(?LastFlush, null), lastFlush());
    setClockForTest(0);
    record("a");
    _ = flush(.rumble_stuck);
    setClockForTest(2 * std.time.ns_per_s);
    const last = lastFlush().?;
    try testing.expectEqual(Reason.rumble_stuck, last.reason);
    try testing.expectEqual(@as(u64, 2000), last.ms_ago);
}

test "flight_recorder: unwritable log file warns once and keeps the ring" {
    detachTestLog();
    defer detachTestLog();
    padctl_log.setLogPathForTest("/proc/padctl-flight-recorder-does-not-exist/padctl.log");

    record("a");
    record("b");
    try testing.expectEqual(@as(usize, 0), flush(.signal));
    try testing.expectEqual(@as(usize, 2), buffered());
    try testing.expectEqual(@as(usize, 1), unwritableWarnCount());

    try testing.expectEqual(@as(usize, 0), flush(.signal));
    try testing.expectEqual(@as(usize, 2), buffered());
    try testing.expectEqual(@as(usize, 1), unwritableWarnCount());
}

test "flight_recorder: logFn routes debug lines to the ring while dump is off" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();
    padctl_log.setEnabled(false);

    padctl_log.logFn(.debug, .default, "ring-only-line", .{});
    try testing.expectEqual(@as(usize, 1), buffered());
    try testing.expectError(error.FileNotFound, readTestLog(&tmp));

    _ = flush(.signal);
    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "ring-only-line") != null);
}

test "flight_recorder: logFn routes debug lines to the file while dump is on" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();
    padctl_log.setEnabled(true);
    defer padctl_log.setEnabled(false);

    padctl_log.logFn(.debug, .default, "file-line", .{});
    try testing.expectEqual(@as(usize, 0), buffered());

    const content = try readTestLog(&tmp);
    defer testing.allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "file-line") != null);
}

test "flight_recorder: logFn leaves info lines out of the ring" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = try attachTestLog(&tmp, &path_buf);
    defer detachTestLog();
    padctl_log.setEnabled(false);

    padctl_log.logFn(.info, .default, "info-line", .{});
    try testing.expectEqual(@as(usize, 0), buffered());
}
