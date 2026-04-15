const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const Allocator = std.mem.Allocator;
const paths = @import("config/paths.zig");

/// File descriptor for the log file. -1 when file logging is inactive.
var log_fd: std.atomic.Value(posix.fd_t) = std.atomic.Value(posix.fd_t).init(-1);

/// Serializes concurrent file writes across device threads.
var log_mutex: std.Thread.Mutex = .{};

/// Stored log file path for reopening after deletion or lazy open.
var log_path_buf: [256]u8 = undefined;
var log_path_len: usize = 0;

/// Whether init() resolved a valid log path (even if file isn't open yet).
var initialized: bool = false;

/// When false (default), only error/warning lines reach the log file.
/// Debug/info lines are suppressed. Toggled via `padctl dump enable/disable`.
var dump_enabled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

/// Maximum log file size before rotation.
/// Default 100 MiB; overridden by `[diagnostics] max_log_size_mb` in config.
var max_log_size: u64 = 100 * 1024 * 1024;

pub const InitOptions = struct {
    dump: bool = false,
    max_log_size_mb: i64 = 100,
};

/// Enable or disable debug-level file logging at runtime.
/// When toggling on, lazily opens the log file if not already open.
pub fn setEnabled(on: bool) void {
    dump_enabled.store(on, .release);
    // If enabling dump and file not open yet, open it now.
    if (on and initialized and log_fd.load(.acquire) == -1) {
        log_mutex.lock();
        defer log_mutex.unlock();
        openLogFile();
    }
}

/// Returns true when debug-level file logging is active.
pub fn isEnabled() bool {
    return dump_enabled.load(.acquire);
}

/// Returns true when a message at the given level should be written to the
/// log file. Used by logFn; exposed for testability.
pub fn shouldWriteToFile(comptime level: std.log.Level) bool {
    const always = comptime (level == .err or level == .warn);
    return always or dump_enabled.load(.acquire);
}

/// Set the maximum log file size in megabytes (for rotation).
pub fn setMaxLogSize(mb: i64) void {
    const clamped: u64 = if (mb > 0) @intCast(mb) else 100;
    max_log_size = clamped * 1024 * 1024;
}

/// Step 1: Resolve the log directory and store the path. Call this BEFORE
/// loading config so that early warnings (e.g. malformed config.toml) can
/// persist to the log file via lazy open in logFn. No file is opened yet.
pub fn initPath(allocator: Allocator) void {
    const dir_path = paths.stateDir(allocator) catch return;
    defer allocator.free(dir_path);

    // Ensure the directory tree exists.
    std.fs.makeDirAbsolute(dir_path) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => {
            if (std.mem.lastIndexOfScalar(u8, dir_path, '/')) |sep| {
                std.fs.makeDirAbsolute(dir_path[0..sep]) catch {};
                std.fs.makeDirAbsolute(dir_path) catch return;
            } else return;
        },
    };

    // Store the resolved log path for lazy open and reopen-after-delete.
    const log_path = std.fmt.allocPrint(allocator, "{s}/padctl.log", .{dir_path}) catch return;
    defer allocator.free(log_path);
    if (log_path.len <= log_path_buf.len) {
        @memcpy(log_path_buf[0..log_path.len], log_path);
        log_path_len = log_path.len;
        initialized = true;
    }
}

/// Step 2: Apply diagnostics config and optionally open the log file.
/// Call this AFTER loading config. If dump is enabled, the file opens
/// immediately. Otherwise it stays lazy (opened on first err/warn).
pub fn applyConfig(opts: InitOptions) void {
    setMaxLogSize(opts.max_log_size_mb);
    dump_enabled.store(opts.dump, .release);

    if (opts.dump and initialized and log_fd.load(.acquire) == -1) {
        openLogFile();
        if (log_path_len > 0) {
            var confirm_buf: [256]u8 = undefined;
            const confirm = std.fmt.bufPrint(&confirm_buf, "info: file logging active (dump=on): {s}\n", .{log_path_buf[0..log_path_len]}) catch return;
            _ = posix.write(posix.STDERR_FILENO, confirm) catch {};
        }
    }
}

/// Convenience: initPath + applyConfig in one call.
pub fn init(allocator: Allocator, opts: InitOptions) void {
    initPath(allocator);
    applyConfig(opts);
}

/// Open (or rotate + open) the log file. Must be called under log_mutex
/// or during single-threaded init.
fn openLogFile() void {
    if (log_path_len == 0) return;
    const log_path = log_path_buf[0..log_path_len];

    // Rotate if the log file exceeds the size threshold.
    if (std.fs.openFileAbsolute(log_path, .{})) |f| {
        defer f.close();
        if (f.stat()) |st| {
            if (st.size > max_log_size) {
                // Build backup path from log_path by appending ".1"
                var bak_buf: [260]u8 = undefined;
                if (log_path_len + 2 <= bak_buf.len) {
                    @memcpy(bak_buf[0..log_path_len], log_path);
                    @memcpy(bak_buf[log_path_len .. log_path_len + 2], ".1");
                    const bak_path = bak_buf[0 .. log_path_len + 2];
                    std.fs.renameAbsolute(log_path, bak_path) catch {};
                }
            }
        } else |_| {}
    } else |_| {}

    const fd = posix.open(log_path, .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true }, 0o644) catch return;
    log_fd.store(fd, .release);
}

/// Close the log file.
pub fn deinit() void {
    const fd = log_fd.swap(-1, .acq_rel);
    if (fd != -1) posix.close(fd);
    initialized = false;
}

/// Check if the log file was deleted (nlink == 0 on the open fd).
/// If so, close the old fd, recreate the file, and update the global fd.
/// Must be called under log_mutex. Returns the (possibly new) fd.
fn reopenIfDeleted(fd: posix.fd_t) posix.fd_t {
    if (log_path_len == 0) return fd;
    const st = posix.fstat(fd) catch return fd;
    if (st.nlink > 0) return fd;
    posix.close(fd);
    const path = log_path_buf[0..log_path_len];
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |sep| {
        std.fs.makeDirAbsolute(path[0..sep]) catch {};
    }
    const new_fd = posix.open(path, .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true }, 0o644) catch {
        log_fd.store(-1, .release);
        return -1;
    };
    log_fd.store(new_fd, .release);
    return new_fd;
}

/// Lazily open the log file on the first persistent write (err/warn).
/// Must be called under log_mutex.
fn ensureFileOpen() posix.fd_t {
    var fd = log_fd.load(.acquire);
    if (fd != -1) return fd;
    if (!initialized) return -1;
    openLogFile();
    fd = log_fd.load(.acquire);
    return fd;
}

/// Custom log function: tees to stderr (for journal) and the log file.
/// Format: [YYYY-MM-DDTHH:MM:SS.mmm] [MONO:nnnnnnn] [level] (scope): message
pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const scope_prefix = comptime if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // Format wall-clock timestamp.
    var ts_buf: [32]u8 = undefined;
    const ts_str = wallClockTimestamp(&ts_buf);

    // Monotonic nanoseconds for scheduler correlation.
    const mono_ns = monotonicNs();

    // Format into a stack buffer large enough for any log line.
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();
    nosuspend w.print("[{s}] [MONO:{d}] " ++ level_txt ++ scope_prefix ++ format ++ "\n", .{ ts_str, mono_ns } ++ args) catch {
        @memcpy(buf[buf.len - 4 ..], "...\n");
        fbs.pos = buf.len;
    };
    const msg = fbs.getWritten();
    if (msg.len == 0) return;

    // Write to stderr (for systemd journal / terminal).
    _ = posix.write(posix.STDERR_FILENO, msg) catch {};

    // Write to log file: err/warn always persist; debug/info only when dump enabled.
    const always_write = comptime (message_level == .err or message_level == .warn);
    const write_to_file = shouldWriteToFile(message_level);
    if (write_to_file) {
        log_mutex.lock();
        defer log_mutex.unlock();

        var fd = log_fd.load(.acquire);
        if (fd == -1 and always_write) {
            // Lazy open: first err/warn creates the file even with dump off.
            fd = ensureFileOpen();
        }
        if (fd != -1) {
            fd = reopenIfDeleted(fd);
            _ = posix.write(fd, msg) catch {};
        }
    }
}

/// Format a wall-clock timestamp as "YYYY-MM-DDTHH:MM:SS.mmm".
fn wallClockTimestamp(buf: *[32]u8) []const u8 {
    var ts: linux.timespec = undefined;
    const rc = linux.clock_gettime(.REALTIME, &ts);
    if (rc != 0) return "????-??-??T??:??:??.???";

    const epoch_secs: u64 = @intCast(ts.sec);
    const millis: u64 = @intCast(@divTrunc(ts.nsec, std.time.ns_per_ms));

    const es = std.time.epoch.EpochSeconds{ .secs = epoch_secs };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    const result = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
        yd.year,
        @as(u32, @intFromEnum(md.month)) + 1,
        @as(u32, md.day_index) + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
        millis,
    }) catch return "????-??-??T??:??:??.???";
    return result;
}

/// Returns the current CLOCK_MONOTONIC time in nanoseconds.
fn monotonicNs() i128 {
    var ts: linux.timespec = undefined;
    const rc = linux.clock_gettime(.MONOTONIC, &ts);
    if (rc != 0) return 0;
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

// --- tests ---

const testing = std.testing;

test "log: dump disabled by default" {
    try testing.expect(!isEnabled());
}

test "log: setEnabled toggles state" {
    try testing.expect(!isEnabled());
    setEnabled(true);
    try testing.expect(isEnabled());
    setEnabled(false);
    try testing.expect(!isEnabled());
}

test "log: setMaxLogSize updates rotation threshold" {
    setMaxLogSize(50);
    try testing.expectEqual(@as(u64, 50 * 1024 * 1024), max_log_size);
    setMaxLogSize(100);
}

test "log: shouldWriteToFile: debug suppressed when dump off" {
    setEnabled(false);
    try testing.expect(!shouldWriteToFile(.debug));
    try testing.expect(!shouldWriteToFile(.info));
}

test "log: shouldWriteToFile: debug passes when dump on" {
    setEnabled(true);
    try testing.expect(shouldWriteToFile(.debug));
    try testing.expect(shouldWriteToFile(.info));
    setEnabled(false);
}

test "log: shouldWriteToFile: err and warn always pass regardless of dump" {
    setEnabled(false);
    try testing.expect(shouldWriteToFile(.err));
    try testing.expect(shouldWriteToFile(.warn));
    setEnabled(true);
    try testing.expect(shouldWriteToFile(.err));
    try testing.expect(shouldWriteToFile(.warn));
    setEnabled(false);
}

test "log: setEnabled is atomic under concurrent access" {
    // Spawn two threads that toggle rapidly; verify no crash.
    const Thread = std.Thread;
    const toggle_fn = struct {
        fn run(_: void) void {
            var i: usize = 0;
            while (i < 1000) : (i += 1) {
                setEnabled(i % 2 == 0);
                _ = isEnabled();
                _ = shouldWriteToFile(.debug);
            }
        }
    }.run;
    const t1 = try Thread.spawn(.{}, toggle_fn, .{{}});
    const t2 = try Thread.spawn(.{}, toggle_fn, .{{}});
    t1.join();
    t2.join();
    setEnabled(false);
    // If we got here without crash, atomicity is sufficient.
}
