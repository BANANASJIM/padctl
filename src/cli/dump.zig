const std = @import("std");
const paths = @import("../config/paths.zig");
const user_config_mod = @import("../config/user_config.zig");
const socket_client = @import("socket_client.zig");

pub const WriteError = error{
    MalformedConfig,
    NoSpaceLeft,
    OutOfMemory,
    AccessDenied,
    FileNotFound,
    Unexpected,
    InputOutput,
    SystemResources,
    IsDir,
    InvalidArgument,
};

/// Write `[diagnostics] dump = <value>` to `{dir_path}/config.toml`.
/// Preserves ALL existing fields (version, devices, other diagnostics fields).
/// Only the `dump` field within `[diagnostics]` is changed.
///
/// Returns error.MalformedConfig if the existing file contains invalid TOML
/// (the file is left untouched — the caller should warn and proceed with IPC).
pub fn writeDiagnosticsConfig(allocator: std.mem.Allocator, dir_path: []const u8, dump: bool) WriteError!void {
    std.fs.makeDirAbsolute(dir_path) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        error.AccessDenied => return error.AccessDenied,
        else => return error.Unexpected,
    };

    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{dir_path});
    defer allocator.free(config_path);

    // Read existing config to preserve all fields.
    var existing_version: ?i64 = null;
    var existing_diag: user_config_mod.DiagnosticsConfig = .{};
    var existing_devices: ?[]const user_config_mod.DeviceEntry = null;
    var existing_pr: ?user_config_mod.ParseResult = null;
    defer if (existing_pr) |*pr| pr.deinit();

    if (user_config_mod.loadFromDir(allocator, dir_path)) |maybe| {
        if (maybe) |pr| {
            existing_pr = pr;
            existing_version = pr.value.version;
            existing_diag = pr.value.diagnostics;
            existing_devices = pr.value.device;
        }
        // null = file not found → fresh config, proceed.
    } else |err| switch (err) {
        error.MalformedConfig => return error.MalformedConfig,
    }

    // Update only the dump field; preserve everything else.
    existing_diag.dump = dump;

    // Build the config content in memory, then write atomically.
    var content_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&content_buf);
    const w = fbs.writer();

    w.print("version = {d}\n\n", .{existing_version orelse user_config_mod.CURRENT_VERSION}) catch return error.NoSpaceLeft;
    w.print("[diagnostics]\ndump = {}\nmax_log_size_mb = {d}\n", .{ existing_diag.dump, existing_diag.max_log_size_mb }) catch return error.NoSpaceLeft;

    if (existing_devices) |devices| {
        for (devices) |dev| {
            w.writeAll("\n[[device]]\n") catch return error.NoSpaceLeft;
            w.print("name = \"{s}\"\n", .{dev.name}) catch return error.NoSpaceLeft;
            if (dev.default_mapping) |m| {
                w.print("default_mapping = \"{s}\"\n", .{m}) catch return error.NoSpaceLeft;
            }
        }
    }

    var f = std.fs.createFileAbsolute(config_path, .{ .truncate = true }) catch return error.AccessDenied;
    defer f.close();
    f.writeAll(fbs.getWritten()) catch return error.InputOutput;
}

/// Run `padctl dump status`: query daemon for live state, read log file stats.
pub fn runStatus(
    allocator: std.mem.Allocator,
    socket_path: []const u8,
    stdout: anytype,
    stderr: anytype,
) void {
    // Query daemon for live dump state.
    var daemon_state: []const u8 = "unknown (daemon not running)";
    if (socket_client.connectToSocket(socket_path)) |sock_fd| {
        defer std.posix.close(sock_fd);
        var resp_buf: [64]u8 = undefined;
        if (socket_client.sendCommand(sock_fd, "DUMP STATUS\n", &resp_buf)) |resp| {
            // Parse "OK dump=on\n" or "OK dump=off\n"
            const trimmed = std.mem.trimRight(u8, resp, "\r\n");
            if (std.mem.indexOf(u8, trimmed, "dump=on") != null) {
                daemon_state = "enabled";
            } else if (std.mem.indexOf(u8, trimmed, "dump=off") != null) {
                daemon_state = "disabled";
            }
        } else |_| {}
    } else |_| {
        // Daemon not running — fall back to config.
        const user_cfg_mod2 = user_config_mod;
        if (user_cfg_mod2.load(allocator)) |pr| {
            var ucpr = pr;
            defer ucpr.deinit();
            daemon_state = if (ucpr.value.diagnostics.dump) "enabled (from config)" else "disabled (from config)";
        }
    }

    stdout.print("Dump: {s}\n", .{daemon_state}) catch {};

    // Log file stats. Check both user state dir and systemd /var/log/padctl,
    // pick whichever has the newest last_timestamp (the active one).
    const sys_log_dir = "/var/log/padctl";
    const user_log_dir: ?[]u8 = paths.stateDir(allocator) catch null;
    defer if (user_log_dir) |d| allocator.free(d);

    const effective_dir: []const u8 = pickActiveLogDir(sys_log_dir, user_log_dir);

    stdout.print("Log path: {s}/padctl.log\n", .{effective_dir}) catch {};

    if (getLogStats(effective_dir)) |stats| {
        var size_buf: [32]u8 = undefined;
        const size_str = formatSize(&size_buf, stats.total_size);
        stdout.print("Log size: {s} ({d} file{s})\n", .{
            size_str,
            stats.file_count,
            if (stats.file_count != 1) "s" else "",
        }) catch {};
        if (stats.firstTimestamp()) |first| {
            stdout.print("First entry: {s}\n", .{first}) catch {};
        }
        if (stats.lastTimestamp()) |last| {
            stdout.print("Last entry:  {s}\n", .{last}) catch {};
        }
    } else {
        stdout.print("Log size: no logs\n", .{}) catch {};
    }

    _ = stderr;
}

/// Delete log files in the given directory. Returns the number of files deleted.
pub fn deleteLogFiles(log_dir: []const u8) u32 {
    var deleted: u32 = 0;
    const names = [_][]const u8{ "padctl.log", "padctl.log.1" };
    for (names) |name| {
        var path_buf: [280]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ log_dir, name }) catch continue;
        std.fs.deleteFileAbsolute(path) catch continue;
        deleted += 1;
    }
    return deleted;
}

/// Aggregate LogStats across two directories.
fn mergeStats(a: ?LogStats, b: ?LogStats) ?LogStats {
    if (a == null and b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    var merged = a.?;
    const bs = b.?;
    merged.total_size += bs.total_size;
    merged.file_count += bs.file_count;

    // Pick the earliest first_timestamp and latest last_timestamp.
    if (bs.has_first_ts) {
        if (merged.has_first_ts) {
            if (std.mem.order(u8, bs.first_ts_buf[0..TS_LEN], merged.first_ts_buf[0..TS_LEN]) == .lt) {
                @memcpy(merged.first_ts_buf[0..TS_LEN], bs.first_ts_buf[0..TS_LEN]);
            }
        } else {
            @memcpy(merged.first_ts_buf[0..TS_LEN], bs.first_ts_buf[0..TS_LEN]);
            merged.has_first_ts = true;
        }
    }
    if (bs.has_last_ts) {
        if (merged.has_last_ts) {
            if (std.mem.order(u8, bs.last_ts_buf[0..TS_LEN], merged.last_ts_buf[0..TS_LEN]) == .gt) {
                @memcpy(merged.last_ts_buf[0..TS_LEN], bs.last_ts_buf[0..TS_LEN]);
            }
        } else {
            @memcpy(merged.last_ts_buf[0..TS_LEN], bs.last_ts_buf[0..TS_LEN]);
            merged.has_last_ts = true;
        }
    }
    return merged;
}

/// Run `padctl dump clear`: show stats across ALL log locations, prompt, delete all.
pub fn runClear(
    allocator: std.mem.Allocator,
    stdout: anytype,
    stderr: anytype,
) void {
    const sys_log_dir = "/var/log/padctl";
    const user_log_dir: ?[]u8 = paths.stateDir(allocator) catch null;
    defer if (user_log_dir) |d| allocator.free(d);

    // Aggregate stats from both locations.
    const sys_stats = getLogStats(sys_log_dir);
    const user_stats = if (user_log_dir) |ud| getLogStats(ud) else null;
    const stats = mergeStats(sys_stats, user_stats) orelse {
        stdout.print("No logs to clear.\n", .{}) catch {};
        return;
    };

    // Show stats.
    var size_buf: [32]u8 = undefined;
    const size_str = formatSize(&size_buf, stats.total_size);
    stdout.print("{d} log file{s}, {s}", .{
        stats.file_count,
        if (stats.file_count != 1) "s" else "",
        size_str,
    }) catch {};
    if (stats.firstTimestamp()) |first| {
        if (stats.lastTimestamp()) |last| {
            stdout.print(", spanning {s} to {s}", .{ first, last }) catch {};
        } else {
            stdout.print(", from {s}", .{first}) catch {};
        }
    }
    stdout.print("\n", .{}) catch {};

    // Check for TTY.
    const stdin_fd = std.posix.STDIN_FILENO;
    if (!std.posix.isatty(stdin_fd)) {
        stderr.print("error: refusing to delete logs without interactive confirmation (stdin is not a TTY)\n", .{}) catch {};
        std.process.exit(1);
    }

    // Prompt.
    stdout.print("Delete all logs? [y/N] ", .{}) catch {};
    var input_buf: [16]u8 = undefined;
    const n = std.posix.read(stdin_fd, &input_buf) catch {
        stdout.print("\nAborted.\n", .{}) catch {};
        return;
    };
    if (n == 0) {
        stdout.print("\nAborted.\n", .{}) catch {};
        return;
    }
    const answer = std.mem.trimRight(u8, input_buf[0..n], "\r\n \t");
    if (answer.len == 1 and (answer[0] == 'y' or answer[0] == 'Y')) {
        // Delete from BOTH locations.
        var deleted: u32 = 0;
        deleted += deleteLogFiles(sys_log_dir);
        if (user_log_dir) |ud| {
            deleted += deleteLogFiles(ud);
        }
        stdout.print("Deleted {d} file{s}.\n", .{ deleted, if (deleted != 1) "s" else "" }) catch {};
    } else {
        stdout.print("Aborted.\n", .{}) catch {};
    }
}

/// Pick whichever log directory has the newest last_timestamp.
/// Falls back to sys_dir if both are empty or only sys exists.
fn pickActiveLogDir(sys_dir: []const u8, user_dir: ?[]const u8) []const u8 {
    const sys_stats = getLogStats(sys_dir);
    const user_stats = if (user_dir) |ud| getLogStats(ud) else null;

    if (sys_stats != null and user_stats != null) {
        const sys_ts = sys_stats.?.lastTimestamp() orelse "";
        const user_ts = user_stats.?.lastTimestamp() orelse "";
        // ISO 8601 timestamps sort lexicographically.
        if (std.mem.order(u8, user_ts, sys_ts) == .gt) return user_dir.?;
        return sys_dir;
    }
    if (user_stats != null) return user_dir.?;
    return sys_dir;
}

fn formatSize(buf: *[32]u8, bytes: u64) []const u8 {
    if (bytes < 1024) {
        return std.fmt.bufPrint(buf, "{d} B", .{bytes}) catch "?";
    } else if (bytes < 1024 * 1024) {
        return std.fmt.bufPrint(buf, "{d:.1} KB", .{@as(f64, @floatFromInt(bytes)) / 1024.0}) catch "?";
    } else {
        return std.fmt.bufPrint(buf, "{d:.1} MB", .{@as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0)}) catch "?";
    }
}

/// Run `padctl dump export`: filter logs by period, output to stdout or file.
pub fn runExport(
    allocator: std.mem.Allocator,
    period_str: []const u8,
    output_path: ?[]const u8,
    stdout: anytype,
    stderr: anytype,
) void {
    const period_secs = parsePeriod(period_str) orelse {
        stderr.print("error: invalid period '{s}' — use Nm, Nh, or Nd (e.g., 10m, 1h, 1d)\n", .{period_str}) catch {};
        std.process.exit(1);
    };

    // Compute cutoff timestamp.
    const now_secs = @as(u64, @intCast(std.time.timestamp()));
    const cutoff_secs = if (now_secs > period_secs) now_secs - period_secs else 0;
    var cutoff_buf: [23]u8 = undefined;
    const cutoff = formatTimestamp(&cutoff_buf, cutoff_secs);

    // Find the active log directory.
    const sys_log_dir = "/var/log/padctl";
    const user_log_dir: ?[]u8 = paths.stateDir(allocator) catch null;
    defer if (user_log_dir) |d| allocator.free(d);
    const log_dir = pickActiveLogDir(sys_log_dir, user_log_dir);

    // Open output: file or stdout. Supports both relative and absolute paths.
    if (output_path) |op| {
        var f = (if (op.len > 0 and op[0] == '/')
            std.fs.createFileAbsolute(op, .{ .truncate = true })
        else
            std.fs.cwd().createFile(op, .{ .truncate = true })) catch |err| {
            stderr.print("error: cannot create '{s}': {}\n", .{ op, err }) catch {};
            std.process.exit(1);
        };
        defer f.close();
        exportToFd(log_dir, cutoff, f.handle);
    } else {
        exportToWriter(log_dir, cutoff, stdout);
    }
}

fn exportToFd(log_dir: []const u8, cutoff: []const u8, fd: std.posix.fd_t) void {
    const FdWriter = struct {
        fd: std.posix.fd_t,
        pub fn writeAll(self: @This(), data: []const u8) !void {
            var written: usize = 0;
            while (written < data.len) {
                written += std.posix.write(self.fd, data[written..]) catch return error.BrokenPipe;
            }
        }
    };
    const w = FdWriter{ .fd = fd };
    exportToWriter(log_dir, cutoff, w);
}

fn exportToWriter(log_dir: []const u8, cutoff: []const u8, writer: anytype) void {
    // Read rotated file first (older), then current file.
    var bak_buf: [280]u8 = undefined;
    const bak_path = std.fmt.bufPrint(&bak_buf, "{s}/padctl.log.1", .{log_dir}) catch return;
    filterLogFile(bak_path, cutoff, writer) catch {};

    var cur_buf: [280]u8 = undefined;
    const cur_path = std.fmt.bufPrint(&cur_buf, "{s}/padctl.log", .{log_dir}) catch return;
    filterLogFile(cur_path, cutoff, writer) catch {};
}

fn formatTimestamp(buf: *[23]u8, epoch_secs: u64) []const u8 {
    const es = std.time.epoch.EpochSeconds{ .secs = epoch_secs };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    const result = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.000", .{
        yd.year,
        @as(u32, @intFromEnum(md.month)) + 1,
        @as(u32, md.day_index) + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch return "0000-00-00T00:00:00.000";
    return result;
}

/// Parse a relative period string like "10m", "1h", "1d" into seconds.
/// Returns null for invalid input.
pub fn parsePeriod(s: []const u8) ?u64 {
    if (s.len < 2) return null;
    const unit = s[s.len - 1];
    const multiplier: u64 = switch (unit) {
        'm' => 60,
        'h' => 3600,
        'd' => 86400,
        else => return null,
    };
    const num_str = s[0 .. s.len - 1];
    const n = std.fmt.parseInt(u64, num_str, 10) catch return null;
    if (n == 0) return null;
    return std.math.mul(u64, n, multiplier) catch return null;
}

/// Check whether a log line's timestamp is at or after the cutoff.
/// Lines without a parseable timestamp are included conservatively.
/// Both `line` and `cutoff` use the format "YYYY-MM-DDTHH:MM:SS.mmm".
pub fn linePassesFilter(line: []const u8, cutoff: []const u8) bool {
    const ts = extractTimestamp(line) orelse return true; // no timestamp → include
    // ISO 8601 timestamps sort lexicographically.
    return std.mem.order(u8, ts, cutoff) != .lt;
}

/// Read a log file line-by-line, writing lines that pass the timestamp filter
/// to the given writer. The cutoff is an ISO 8601 timestamp string.
pub fn filterLogFile(path: []const u8, cutoff: []const u8, writer: anytype) !void {
    const f = std.fs.openFileAbsolute(path, .{}) catch return;
    defer f.close();

    var buf: [4096]u8 = undefined;
    var carry: [4096]u8 = undefined;
    var carry_len: usize = 0;

    while (true) {
        const n = f.readAll(buf[carry_len..]) catch break;
        if (carry_len > 0) {
            // Prepend leftover from previous read.
            @memcpy(buf[0..carry_len], carry[0..carry_len]);
        }
        const total = carry_len + n;
        if (total == 0) break;
        carry_len = 0;

        var data = buf[0..total];
        while (std.mem.indexOfScalar(u8, data, '\n')) |nl| {
            const line = data[0..nl];
            if (linePassesFilter(line, cutoff)) {
                try writer.writeAll(line);
                try writer.writeAll("\n");
            }
            data = data[nl + 1 ..];
        }
        // Leftover (no newline) — carry to next iteration.
        if (data.len > 0 and n > 0) {
            @memcpy(carry[0..data.len], data);
            carry_len = data.len;
        } else if (data.len > 0) {
            // EOF with no trailing newline — process the leftover.
            if (linePassesFilter(data, cutoff)) {
                try writer.writeAll(data);
                try writer.writeAll("\n");
            }
        }
    }

    // Final leftover after EOF.
    if (carry_len > 0) {
        const leftover = carry[0..carry_len];
        if (linePassesFilter(leftover, cutoff)) {
            try writer.writeAll(leftover);
            try writer.writeAll("\n");
        }
    }
}

pub const LogStats = struct {
    total_size: u64,
    file_count: u32,
    has_first_ts: bool = false,
    has_last_ts: bool = false,
    first_ts_buf: [TS_LEN]u8 = undefined,
    last_ts_buf: [TS_LEN]u8 = undefined,

    pub fn firstTimestamp(self: *const LogStats) ?[]const u8 {
        return if (self.has_first_ts) self.first_ts_buf[0..TS_LEN] else null;
    }

    pub fn lastTimestamp(self: *const LogStats) ?[]const u8 {
        return if (self.has_last_ts) self.last_ts_buf[0..TS_LEN] else null;
    }
};

const TS_LEN = 23; // "YYYY-MM-DDTHH:MM:SS.mmm"

/// Scan log files in `log_dir` and return stats. Returns null if the
/// directory doesn't exist or contains no log files. Reads only the
/// first and last lines of each file for timestamps (not the full content).
pub fn getLogStats(log_dir: []const u8) ?LogStats {
    var stats = LogStats{ .total_size = 0, .file_count = 0 };

    // Check rotated file first (older data → first timestamp).
    var bak_path_buf: [280]u8 = undefined;
    const bak_path = std.fmt.bufPrint(&bak_path_buf, "{s}/padctl.log.1", .{log_dir}) catch return null;
    if (scanFile(bak_path)) |info| {
        stats.total_size += info.size;
        stats.file_count += 1;
        if (info.has_first_ts) {
            @memcpy(stats.first_ts_buf[0..TS_LEN], info.first_ts_buf[0..TS_LEN]);
            stats.has_first_ts = true;
        }
        if (info.has_last_ts) {
            @memcpy(stats.last_ts_buf[0..TS_LEN], info.last_ts_buf[0..TS_LEN]);
            stats.has_last_ts = true;
        }
    }

    // Check current file (newer data → last timestamp).
    var cur_path_buf: [280]u8 = undefined;
    const cur_path = std.fmt.bufPrint(&cur_path_buf, "{s}/padctl.log", .{log_dir}) catch return null;
    if (scanFile(cur_path)) |info| {
        stats.total_size += info.size;
        stats.file_count += 1;
        if (info.has_first_ts and !stats.has_first_ts) {
            @memcpy(stats.first_ts_buf[0..TS_LEN], info.first_ts_buf[0..TS_LEN]);
            stats.has_first_ts = true;
        }
        if (info.has_last_ts) {
            @memcpy(stats.last_ts_buf[0..TS_LEN], info.last_ts_buf[0..TS_LEN]);
            stats.has_last_ts = true;
        }
    }

    if (stats.file_count == 0) return null;
    return stats;
}

const FileInfo = struct {
    size: u64,
    has_first_ts: bool = false,
    has_last_ts: bool = false,
    first_ts_buf: [TS_LEN]u8 = undefined,
    last_ts_buf: [TS_LEN]u8 = undefined,
};

/// Extract file size and first/last timestamp from a log file.
/// Reads the first 256 bytes for the first timestamp and the last 1024 bytes
/// for the last timestamp (large enough for HID frame hex dump lines).
/// Returns null if the file doesn't exist.
fn scanFile(path: []const u8) ?FileInfo {
    const f = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer f.close();
    const stat = f.stat() catch return null;

    var info = FileInfo{ .size = stat.size };
    if (stat.size == 0) return info;

    // Read first 256 bytes for first timestamp.
    var head_buf: [256]u8 = undefined;
    const head_n = f.readAll(&head_buf) catch 0;
    if (head_n > 0) {
        if (extractTimestamp(head_buf[0..head_n])) |ts| {
            @memcpy(info.first_ts_buf[0..TS_LEN], ts);
            info.has_first_ts = true;
        }
    }

    // Read last 1024 bytes for last timestamp. Rumble HID frame dump lines
    // can exceed 256 bytes, so we need a larger tail window to find the
    // timestamp at the start of the final line.
    const tail_size: u64 = 1024;
    if (stat.size > tail_size) {
        f.seekTo(stat.size - tail_size) catch {};
    } else {
        f.seekTo(0) catch {};
    }
    var tail_buf: [1024]u8 = undefined;
    const tail_n = f.readAll(&tail_buf) catch 0;
    if (tail_n > 0) {
        if (extractLastTimestamp(tail_buf[0..tail_n])) |ts| {
            @memcpy(info.last_ts_buf[0..TS_LEN], ts);
            info.has_last_ts = true;
        }
    }

    return info;
}

/// Extract the first `[YYYY-MM-DDTHH:MM:SS.mmm]` timestamp from a buffer.
fn extractTimestamp(buf: []const u8) ?[]const u8 {
    const start = std.mem.indexOfScalar(u8, buf, '[') orelse return null;
    if (start + 1 + TS_LEN > buf.len) return null;
    const ts = buf[start + 1 .. start + 1 + TS_LEN];
    // Quick sanity check: must have 'T' at position 10 and '.' at position 19.
    if (ts.len == TS_LEN and ts[10] == 'T' and ts[19] == '.') return ts;
    return null;
}

/// Extract the last `[YYYY-MM-DDTHH:MM:SS.mmm]` timestamp from a buffer
/// by scanning backwards.
fn extractLastTimestamp(buf: []const u8) ?[]const u8 {
    var last: ?[]const u8 = null;
    var i: usize = 0;
    while (i < buf.len) {
        if (buf[i] == '[' and i + 1 + TS_LEN <= buf.len) {
            const ts = buf[i + 1 .. i + 1 + TS_LEN];
            if (ts.len == TS_LEN and ts[10] == 'T' and ts[19] == '.') {
                last = ts;
            }
        }
        i += 1;
    }
    return last;
}

// --- tests ---

const testing = std.testing;

test "dump: writeDiagnosticsConfig creates fresh config" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    try writeDiagnosticsConfig(allocator, dir_path, true);

    var result = (try user_config_mod.loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try testing.expectEqual(true, result.value.diagnostics.dump);
    try testing.expectEqual(@as(i64, 100), result.value.diagnostics.max_log_size_mb);
    try testing.expectEqual(@as(?i64, 1), result.value.version);
}

test "dump: writeDiagnosticsConfig preserves existing device entries" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll(
            \\version = 1
            \\
            \\[[device]]
            \\name = "Vader 5 Pro"
            \\default_mapping = "fps"
        );
    }

    try writeDiagnosticsConfig(allocator, dir_path, true);

    var result = (try user_config_mod.loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try testing.expectEqual(true, result.value.diagnostics.dump);
    const mapping = user_config_mod.findDefaultMapping(&result, "Vader 5 Pro");
    try testing.expect(mapping != null);
    try testing.expectEqualStrings("fps", mapping.?);
}

test "dump: writeDiagnosticsConfig preserves max_log_size_mb" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll(
            \\version = 1
            \\
            \\[diagnostics]
            \\dump = false
            \\max_log_size_mb = 50
        );
    }

    // Toggle dump on — max_log_size_mb must survive.
    try writeDiagnosticsConfig(allocator, dir_path, true);

    var result = (try user_config_mod.loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try testing.expectEqual(true, result.value.diagnostics.dump);
    try testing.expectEqual(@as(i64, 50), result.value.diagnostics.max_log_size_mb);
}

test "dump: writeDiagnosticsConfig toggles off" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    try writeDiagnosticsConfig(allocator, dir_path, true);
    try writeDiagnosticsConfig(allocator, dir_path, false);

    var result = (try user_config_mod.loadFromDir(allocator, dir_path)).?;
    defer result.deinit();
    try testing.expectEqual(false, result.value.diagnostics.dump);
}

test "dump: writeDiagnosticsConfig aborts on malformed config" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("config.toml", .{});
        defer f.close();
        try f.writeAll("this is {{{{ not TOML !!!!");
    }

    // Must return MalformedConfig, NOT silently overwrite.
    try testing.expectError(error.MalformedConfig, writeDiagnosticsConfig(allocator, dir_path, true));

    // Verify the original file is untouched.
    const content = try tmp.dir.readFileAlloc(allocator, "config.toml", 4096);
    defer allocator.free(content);
    try testing.expectEqualStrings("this is {{{{ not TOML !!!!", content);
}

// --- LogStats tests ---

test "dump: getLogStats returns null for nonexistent directory" {
    const stats = getLogStats("/tmp/padctl_nonexistent_test_dir_12345");
    try testing.expectEqual(@as(?LogStats, null), stats);
}

test "dump: getLogStats reports size and timestamps for a single file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        defer f.close();
        try f.writeAll(
            \\[2026-04-13T14:00:00.000] [MONO:1] info: first line
            \\[2026-04-13T14:05:00.000] [MONO:2] info: middle
            \\[2026-04-13T14:10:00.000] [MONO:3] info: last line
            \\
        );
    }

    const stats = getLogStats(dir_path).?;
    try testing.expect(stats.total_size > 0);
    try testing.expectEqual(@as(u32, 1), stats.file_count);
    try testing.expectEqualStrings("2026-04-13T14:00:00.000", stats.firstTimestamp().?);
    try testing.expectEqualStrings("2026-04-13T14:10:00.000", stats.lastTimestamp().?);
}

test "dump: getLogStats merges current and rotated file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log.1", .{});
        defer f.close();
        try f.writeAll("[2026-04-12T10:00:00.000] [MONO:1] info: old\n");
    }
    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        defer f.close();
        try f.writeAll("[2026-04-13T20:00:00.000] [MONO:2] info: new\n");
    }

    const stats = getLogStats(dir_path).?;
    try testing.expectEqual(@as(u32, 2), stats.file_count);
    try testing.expectEqualStrings("2026-04-12T10:00:00.000", stats.firstTimestamp().?);
    try testing.expectEqualStrings("2026-04-13T20:00:00.000", stats.lastTimestamp().?);
}

test "dump: getLogStats finds timestamp on long final line" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        defer f.close();
        try f.writeAll("[2026-04-13T14:00:00.000] [MONO:1] info: first line\n");
        // Simulate a long HID frame dump line (~400 chars after timestamp).
        try f.writeAll("[2026-04-13T14:30:00.000] [MONO:2] debug(rumble): [Vader 5 Pro] HID_WRITE: cmd=rumble strong=65535 weak=65535 iface=0 len=32 frame=[");
        // Pad with hex data to make the line >400 bytes total.
        var i: usize = 0;
        while (i < 120) : (i += 1) {
            try f.writeAll("ff ");
        }
        try f.writeAll("]\n");
    }

    const stats = getLogStats(dir_path).?;
    try testing.expect(stats.total_size > 400);
    try testing.expectEqualStrings("2026-04-13T14:00:00.000", stats.firstTimestamp().?);
    // The last timestamp must be found even though it's >256 bytes from EOF.
    try testing.expectEqualStrings("2026-04-13T14:30:00.000", stats.lastTimestamp().?);
}

test "dump: getLogStats handles empty log file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        f.close();
    }

    const stats = getLogStats(dir_path).?;
    try testing.expectEqual(@as(u64, 0), stats.total_size);
    try testing.expectEqual(@as(u32, 1), stats.file_count);
    try testing.expectEqual(@as(?[]const u8, null), stats.firstTimestamp());
    try testing.expectEqual(@as(?[]const u8, null), stats.lastTimestamp());
}

// --- Period parsing tests ---

test "dump: parsePeriod valid durations" {
    try testing.expectEqual(@as(u64, 600), parsePeriod("10m").?);
    try testing.expectEqual(@as(u64, 3600), parsePeriod("1h").?);
    try testing.expectEqual(@as(u64, 86400), parsePeriod("1d").?);
    try testing.expectEqual(@as(u64, 86400 * 30), parsePeriod("30d").?);
}

test "dump: parsePeriod rejects invalid" {
    try testing.expectEqual(@as(?u64, null), parsePeriod("0m"));
    try testing.expectEqual(@as(?u64, null), parsePeriod("abc"));
    try testing.expectEqual(@as(?u64, null), parsePeriod(""));
    try testing.expectEqual(@as(?u64, null), parsePeriod("10"));
    try testing.expectEqual(@as(?u64, null), parsePeriod("m"));
    try testing.expectEqual(@as(?u64, null), parsePeriod("-1h"));
    // Overflow: huge number of days must return null, not crash.
    try testing.expectEqual(@as(?u64, null), parsePeriod("999999999999999999d"));
}

// --- Timestamp filtering tests ---

test "dump: linePassesFilter includes lines at or after cutoff" {
    try testing.expect(linePassesFilter("[2026-04-13T14:05:00.000] info: hello", "2026-04-13T14:00:00.000"));
    try testing.expect(linePassesFilter("[2026-04-13T14:00:00.000] info: exact", "2026-04-13T14:00:00.000"));
}

test "dump: linePassesFilter excludes lines before cutoff" {
    try testing.expect(!linePassesFilter("[2026-04-13T13:59:59.999] info: old", "2026-04-13T14:00:00.000"));
}

test "dump: linePassesFilter includes lines without timestamps" {
    try testing.expect(linePassesFilter("no timestamp here", "2026-04-13T14:00:00.000"));
    try testing.expect(linePassesFilter("", "2026-04-13T14:00:00.000"));
}

// --- Export filtering test ---

test "dump: filterLogFile filters by period" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        defer f.close();
        try f.writeAll(
            \\[2026-04-13T10:00:00.000] [MONO:1] info: old line
            \\[2026-04-13T14:00:00.000] [MONO:2] info: recent line
            \\[2026-04-13T14:30:00.000] [MONO:3] info: newest line
            \\
        );
    }

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const log_path = try std.fmt.allocPrint(allocator, "{s}/padctl.log", .{dir_path});
    defer allocator.free(log_path);

    var output_buf: [4096]u8 = undefined;
    var output = std.io.fixedBufferStream(&output_buf);

    // Cutoff at 14:00 — should include the last two lines.
    try filterLogFile(log_path, "2026-04-13T14:00:00.000", output.writer());
    const result = output.getWritten();
    try testing.expect(std.mem.indexOf(u8, result, "old line") == null);
    try testing.expect(std.mem.indexOf(u8, result, "recent line") != null);
    try testing.expect(std.mem.indexOf(u8, result, "newest line") != null);
}

// --- Clear tests ---

test "dump: deleteLogFiles removes both files" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        f.close();
    }
    {
        var f = try tmp.dir.createFile("padctl.log.1", .{});
        f.close();
    }

    const deleted = deleteLogFiles(dir_path);
    try testing.expectEqual(@as(u32, 2), deleted);
    // Verify files are gone.
    try testing.expectEqual(@as(?LogStats, null), getLogStats(dir_path));
}

test "dump: deleteLogFiles with only current file" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    {
        var f = try tmp.dir.createFile("padctl.log", .{});
        f.close();
    }

    const deleted = deleteLogFiles(dir_path);
    try testing.expectEqual(@as(u32, 1), deleted);
}

test "dump: deleteLogFiles with no files" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const deleted = deleteLogFiles(dir_path);
    try testing.expectEqual(@as(u32, 0), deleted);
}
