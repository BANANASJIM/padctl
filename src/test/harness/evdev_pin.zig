//! EvdevPin — Layer 2 sink-side harness for input continuity diagnostics.
//!
//! Walks /sys/class/input/event* matching uinput/UHID name (and optional uniq),
//! opens /dev/input/eventN non-blocking, then exposes `pollEvents` and
//! `isAlive`. Together with `UhidSimulator` (upstream) the pair owns both
//! ends of the data flow that Steam-like consumers see.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

pub const PinError = error{
    SkipZigTest,
    EvdevNodeNotFound,
} || posix.OpenError || posix.PollError || posix.ReadError;

pub const InputEvent = extern struct {
    sec: isize,
    usec: isize,
    type: u16,
    code: u16,
    value: i32,
};

pub const OpenOptions = struct {
    name: []const u8,
    uniq: ?[]const u8 = null,
    deadline_ms: u32 = 500,
};

pub const EvdevPin = struct {
    fd: posix.fd_t,
    event_index: u16,

    pub fn open(opts: OpenOptions) PinError!EvdevPin {
        if (builtin.os.tag != .linux) return error.SkipZigTest;

        const sys_root = std.fs.openDirAbsolute("/sys/class/input", .{ .iterate = true }) catch
            return error.SkipZigTest;
        defer @constCast(&sys_root).close();

        const start = std.time.milliTimestamp();
        const deadline = start + @as(i64, @intCast(opts.deadline_ms));
        while (std.time.milliTimestamp() <= deadline) {
            if (try scanOnce(opts)) |found| return found;
            std.Thread.sleep(20 * std.time.ns_per_ms);
        }
        return error.EvdevNodeNotFound;
    }

    pub fn pollEvents(self: *EvdevPin, allocator: std.mem.Allocator, deadline_ms: u32) ![]InputEvent {
        var list: std.ArrayList(InputEvent) = .{};
        defer list.deinit(allocator);
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(deadline_ms));
        while (true) {
            const remaining = deadline - std.time.milliTimestamp();
            const wait_ms: i32 = if (remaining > 0) @intCast(@min(remaining, 50)) else 0;
            var pfd = [1]posix.pollfd{.{ .fd = self.fd, .events = posix.POLL.IN, .revents = 0 }};
            const ready = posix.poll(&pfd, wait_ms) catch break;
            if (ready == 0) break;
            if ((pfd[0].revents & (posix.POLL.HUP | posix.POLL.ERR | posix.POLL.NVAL)) != 0) break;
            var ev: InputEvent = undefined;
            const n = posix.read(self.fd, std.mem.asBytes(&ev)) catch break;
            if (n != @sizeOf(InputEvent)) break;
            try list.append(allocator, ev);
            if (std.time.milliTimestamp() >= deadline) break;
        }
        return list.toOwnedSlice(allocator);
    }

    pub fn isAlive(self: *EvdevPin) bool {
        var pfd = [1]posix.pollfd{.{ .fd = self.fd, .events = posix.POLL.IN, .revents = 0 }};
        const ready = posix.poll(&pfd, 0) catch return false;
        _ = ready;
        return (pfd[0].revents & (posix.POLL.HUP | posix.POLL.ERR | posix.POLL.NVAL)) == 0;
    }

    pub fn close(self: *EvdevPin) void {
        if (self.fd < 0) return;
        posix.close(self.fd);
        self.fd = -1;
    }
};

fn scanOnce(opts: OpenOptions) !?EvdevPin {
    var dir = std.fs.openDirAbsolute("/sys/class/input", .{ .iterate = true }) catch return null;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;
        if (!readAttrMatches(dir, entry.name, "device/name", opts.name)) continue;
        if (opts.uniq) |u| {
            if (!readAttrMatches(dir, entry.name, "device/uniq", u)) continue;
        }
        const idx = std.fmt.parseInt(u16, entry.name[5..], 10) catch continue;
        var path_buf: [48]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/input/{s}", .{entry.name}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch |err| switch (err) {
            error.AccessDenied, error.PermissionDenied => return error.SkipZigTest,
            error.FileNotFound => continue,
            else => return err,
        };
        return EvdevPin{ .fd = fd, .event_index = idx };
    }
    return null;
}

fn readAttrMatches(dir: std.fs.Dir, event_name: []const u8, attr: []const u8, expect: []const u8) bool {
    var path_buf: [80]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ event_name, attr }) catch return false;
    var f = dir.openFile(path, .{}) catch return false;
    defer f.close();
    var buf: [128]u8 = undefined;
    const n = f.read(&buf) catch return false;
    const trimmed = std.mem.trimRight(u8, buf[0..n], "\n\r ");
    return std.mem.eql(u8, trimmed, expect);
}
