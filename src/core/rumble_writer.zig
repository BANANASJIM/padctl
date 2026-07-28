const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const DeviceIO = @import("../io/device_io.zig").DeviceIO;

// Physical reports are bounded by the same 512-byte ceiling enforced for
// configured input reports. Keeping the mailbox inline avoids allocator use
// across the EventLoop and writer threads.
pub const MAX_FRAME_BYTES: usize = 512;
pub const DEFAULT_MIN_WRITE_INTERVAL_NS: u64 = 10 * std.time.ns_per_ms;

const Mutex = if (builtin.sanitize_thread) struct {
    m: std.c.pthread_mutex_t = .{},

    fn lock(self: *@This()) void {
        const result = std.c.pthread_mutex_lock(&self.m);
        std.debug.assert(result == .SUCCESS);
    }

    fn unlock(self: *@This()) void {
        const result = std.c.pthread_mutex_unlock(&self.m);
        std.debug.assert(result == .SUCCESS);
    }
} else std.Thread.Mutex;

pub const Frame = struct {
    strong: u16,
    weak: u16,
};

pub const CompletionResult = enum {
    written,
    write_failed,
    disconnected,
};

pub const Completion = struct {
    frame: Frame,
    result: CompletionResult,
    retry_count: u8,
    generation: u64,
    completed_ns: i128,
};

const Request = struct {
    device: DeviceIO,
    frame: Frame,
    retry_count: u8,
    generation: u64,
    min_interval_ns: u64,
    len: usize,
    bytes: [MAX_FRAME_BYTES]u8,

    fn isStop(self: Request) bool {
        return self.frame.strong == 0 and self.frame.weak == 0;
    }
};

/// One physical writer with a bounded latest-state mailbox plus a STOP barrier.
///
/// EventLoop remains the sole producer. A slow DeviceIO.write occupies only
/// this worker; newer logical rumble states replace the queued PLAY request
/// instead of growing an unbounded backlog, while a queued STOP cannot be
/// overwritten by a later PLAY. Completions are acknowledged before another
/// write starts so transport failures cannot be overwritten.
pub const RumbleWriter = struct {
    mutex: Mutex = .{},
    pending: ?Request = null,
    pending_stop: ?Request = null,
    completion: ?Completion = null,
    wake_r: posix.fd_t = -1,
    wake_w: posix.fd_t = -1,
    completion_r: posix.fd_t = -1,
    completion_w: posix.fd_t = -1,
    thread: ?std.Thread = null,
    shutting_down: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn start(self: *RumbleWriter) !void {
        if (self.thread != null) return;

        const wake = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        self.wake_r = wake[0];
        self.wake_w = wake[1];
        errdefer self.closePipes();

        const completion = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        self.completion_r = completion[0];
        self.completion_w = completion[1];
        self.shutting_down.store(false, .release);
        self.thread = try std.Thread.spawn(.{}, workerMain, .{self});
    }

    pub fn stop(self: *RumbleWriter) void {
        const thread = self.thread orelse return;
        self.shutting_down.store(true, .release);
        signal(self.wake_w);
        thread.join();
        self.thread = null;

        self.mutex.lock();
        self.pending = null;
        self.pending_stop = null;
        self.completion = null;
        self.mutex.unlock();

        self.closePipes();
        self.shutting_down.store(false, .release);
    }

    pub fn isRunning(self: *const RumbleWriter) bool {
        return self.thread != null;
    }

    pub fn completionFd(self: *const RumbleWriter) posix.fd_t {
        return self.completion_r;
    }

    pub fn publish(
        self: *RumbleWriter,
        device: DeviceIO,
        bytes: []const u8,
        frame: Frame,
        retry_count: u8,
        generation: u64,
        min_interval_ns: u64,
    ) error{ NotRunning, FrameTooLarge }!void {
        if (self.thread == null) return error.NotRunning;
        if (bytes.len > MAX_FRAME_BYTES) return error.FrameTooLarge;

        var request = Request{
            .device = device,
            .frame = frame,
            .retry_count = retry_count,
            .generation = generation,
            .min_interval_ns = min_interval_ns,
            .len = bytes.len,
            .bytes = undefined,
        };
        @memcpy(request.bytes[0..bytes.len], bytes);

        self.mutex.lock();
        if (request.isStop()) {
            // A STOP is a safety barrier. It supersedes older queued PLAY
            // state, but a later PLAY cannot overwrite it before hardware has
            // seen the zero frame.
            self.pending = null;
            self.pending_stop = request;
        } else {
            self.pending = request;
        }
        self.mutex.unlock();

        // Always wake: the worker may currently be waiting for a non-STOP
        // cadence deadline, and a newly accepted STOP must bypass that wait.
        signal(self.wake_w);
    }

    pub fn takeCompletion(self: *RumbleWriter) ?Completion {
        drain(self.completion_r);
        self.mutex.lock();
        const result = self.completion;
        self.completion = null;
        self.mutex.unlock();
        if (result != null) signal(self.wake_w);
        return result;
    }

    fn workerMain(self: *RumbleWriter) void {
        var last_success: ?SuccessfulWrite = null;
        while (true) {
            const selection = self.takeReadyRequest(last_success);
            const request = switch (selection) {
                .request => |request| request,
                .wait => |wait_ns| {
                    if (!self.waitForWake(wait_ns)) {
                        self.writePendingOnShutdown(last_success);
                        return;
                    }
                    continue;
                },
                .empty => {
                    if (!self.waitForWake(null)) {
                        self.writePendingOnShutdown(last_success);
                        return;
                    }
                    continue;
                },
            };
            const result = writeRequest(request);
            const completed_ns = monotonicNs();
            if (result == .written) {
                last_success = successfulWrite(request, completed_ns);
            }

            if (self.shutting_down.load(.acquire)) {
                self.writePendingOnShutdown(last_success);
                return;
            }

            self.mutex.lock();
            std.debug.assert(self.completion == null);
            self.completion = .{
                .frame = request.frame,
                .result = result,
                .retry_count = request.retry_count,
                .generation = request.generation,
                .completed_ns = completed_ns,
            };
            self.mutex.unlock();
            signal(self.completion_w);

            if (!self.waitForCompletionAck()) {
                self.writePendingOnShutdown(last_success);
                return;
            }
        }
    }

    fn writeRequest(request: Request) CompletionResult {
        request.device.write(request.bytes[0..request.len]) catch |err| {
            return switch (err) {
                DeviceIO.WriteError.Disconnected => .disconnected,
                DeviceIO.WriteError.Io => .write_failed,
            };
        };
        return .written;
    }

    fn writePendingOnShutdown(self: *RumbleWriter, last_success: ?SuccessfulWrite) void {
        while (true) {
            switch (self.takeReadyRequest(last_success)) {
                .request => |request| {
                    self.mutex.lock();
                    self.pending = null;
                    self.pending_stop = null;
                    self.mutex.unlock();
                    _ = writeRequest(request);
                    return;
                },
                .wait => |wait_ns| std.Thread.sleep(@intCast(@min(wait_ns, std.math.maxInt(u64)))),
                .empty => return,
            }
        }
    }

    const Selection = union(enum) {
        request: Request,
        wait: i128,
        empty,
    };

    const SuccessfulWrite = struct {
        device: DeviceIO,
        completed_ns: i128,
        len: usize,
        bytes: [MAX_FRAME_BYTES]u8,
    };

    fn successfulWrite(request: Request, completed_ns: i128) SuccessfulWrite {
        var success = SuccessfulWrite{
            .device = request.device,
            .completed_ns = completed_ns,
            .len = request.len,
            .bytes = undefined,
        };
        @memcpy(success.bytes[0..request.len], request.bytes[0..request.len]);
        return success;
    }

    fn payloadsEqual(request: Request, success: SuccessfulWrite) bool {
        return request.device.ptr == success.device.ptr and
            request.device.vtable == success.device.vtable and
            request.len == success.len and
            std.mem.eql(u8, request.bytes[0..request.len], success.bytes[0..success.len]);
    }

    fn takeReadyRequest(self: *RumbleWriter, last_success: ?SuccessfulWrite) Selection {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.pending_stop) |request| {
            self.pending_stop = null;
            if (last_success) |success| {
                if (payloadsEqual(request, success)) continue;
            }
            return .{ .request = request };
        }
        while (self.pending) |request| {
            if (last_success) |success| {
                if (payloadsEqual(request, success)) {
                    self.pending = null;
                    continue;
                }
                const interval_ns: i128 = @intCast(request.min_interval_ns);
                const remaining = success.completed_ns + interval_ns - monotonicNs();
                if (remaining > 0) return .{ .wait = remaining };
            }
            self.pending = null;
            return .{ .request = request };
        }
        return .empty;
    }

    fn waitForWake(self: *RumbleWriter, wait_ns: ?i128) bool {
        const timeout_ms: i32 = if (wait_ns) |ns|
            @intCast(@min(
                @as(i128, std.math.maxInt(i32)),
                @max(1, @divFloor(ns + std.time.ns_per_ms - 1, std.time.ns_per_ms)),
            ))
        else
            -1;
        var wake_poll = [_]posix.pollfd{.{
            .fd = self.wake_r,
            .events = posix.POLL.IN,
            .revents = 0,
        }};
        _ = posix.poll(&wake_poll, timeout_ms) catch return false;
        if (wake_poll[0].revents & posix.POLL.IN != 0) drain(self.wake_r);
        return !self.shutting_down.load(.acquire);
    }

    fn waitForCompletionAck(self: *RumbleWriter) bool {
        while (self.waitForWake(null)) {
            self.mutex.lock();
            const acknowledged = self.completion == null;
            self.mutex.unlock();
            if (acknowledged) return true;
        }
        return false;
    }

    fn monotonicNs() i128 {
        const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
        return @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
    }

    fn signal(fd: posix.fd_t) void {
        _ = posix.write(fd, &[_]u8{1}) catch {};
    }

    fn drain(fd: posix.fd_t) void {
        var buf: [64]u8 = undefined;
        while (true) {
            const n = posix.read(fd, &buf) catch return;
            if (n == 0 or n < buf.len) return;
        }
    }

    fn closePipes(self: *RumbleWriter) void {
        const fds = [_]*posix.fd_t{
            &self.wake_r,
            &self.wake_w,
            &self.completion_r,
            &self.completion_w,
        };
        for (fds) |fd| {
            if (fd.* >= 0) posix.close(fd.*);
            fd.* = -1;
        }
    }
};
