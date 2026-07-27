const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const DeviceIO = @import("../io/device_io.zig").DeviceIO;

// Physical reports are bounded by the same 512-byte ceiling enforced for
// configured input reports. Keeping the mailbox inline avoids allocator use
// across the EventLoop and writer threads.
pub const MAX_FRAME_BYTES: usize = 512;
const MIN_WRITE_INTERVAL_NS: i128 = 10 * std.time.ns_per_ms;

const Mutex = if (builtin.sanitize_thread) struct {
    m: std.c.pthread_mutex_t = .{},

    fn lock(self: *@This()) void {
        std.debug.assert(std.c.pthread_mutex_lock(&self.m) == .SUCCESS);
    }

    fn unlock(self: *@This()) void {
        std.debug.assert(std.c.pthread_mutex_unlock(&self.m) == .SUCCESS);
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
    request_r: posix.fd_t = -1,
    request_w: posix.fd_t = -1,
    completion_r: posix.fd_t = -1,
    completion_w: posix.fd_t = -1,
    ack_r: posix.fd_t = -1,
    ack_w: posix.fd_t = -1,
    shutdown_r: posix.fd_t = -1,
    shutdown_w: posix.fd_t = -1,
    thread: ?std.Thread = null,
    shutting_down: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn start(self: *RumbleWriter) !void {
        if (self.thread != null) return;

        const request = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        errdefer {
            posix.close(request[0]);
            posix.close(request[1]);
        }
        const completion = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        errdefer {
            posix.close(completion[0]);
            posix.close(completion[1]);
        }
        const ack = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        errdefer {
            posix.close(ack[0]);
            posix.close(ack[1]);
        }
        const shutdown = try posix.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        errdefer {
            posix.close(shutdown[0]);
            posix.close(shutdown[1]);
        }

        self.request_r = request[0];
        self.request_w = request[1];
        self.completion_r = completion[0];
        self.completion_w = completion[1];
        self.ack_r = ack[0];
        self.ack_w = ack[1];
        self.shutdown_r = shutdown[0];
        self.shutdown_w = shutdown[1];
        self.shutting_down.store(false, .release);
        self.thread = std.Thread.spawn(.{}, workerMain, .{self}) catch |err| {
            self.closePipes();
            return err;
        };
    }

    pub fn stop(self: *RumbleWriter) void {
        const thread = self.thread orelse return;
        self.shutting_down.store(true, .release);
        signal(self.shutdown_w);
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
    ) error{ NotRunning, FrameTooLarge }!void {
        if (self.thread == null) return error.NotRunning;
        if (bytes.len > MAX_FRAME_BYTES) return error.FrameTooLarge;

        var request = Request{
            .device = device,
            .frame = frame,
            .retry_count = retry_count,
            .generation = generation,
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
        signal(self.request_w);
    }

    pub fn takeCompletion(self: *RumbleWriter) ?Completion {
        drain(self.completion_r);
        self.mutex.lock();
        const result = self.completion;
        self.completion = null;
        self.mutex.unlock();
        if (result != null) signal(self.ack_w);
        return result;
    }

    fn workerMain(self: *RumbleWriter) void {
        var last_success_ns: i128 = 0;
        while (true) {
            const selection = self.takeReadyRequest(last_success_ns);
            const request = switch (selection) {
                .request => |request| request,
                .wait => |wait_ns| {
                    if (!self.waitForRequest(wait_ns)) {
                        self.writeLatestPendingOnShutdown();
                        return;
                    }
                    continue;
                },
                .empty => {
                    if (!self.waitForRequest(null)) {
                        self.writeLatestPendingOnShutdown();
                        return;
                    }
                    continue;
                },
            };
            const result = writeRequest(request);
            const completed_ns = monotonicNs();
            if (result == .written) last_success_ns = completed_ns;

            if (self.shutting_down.load(.acquire)) {
                self.writeLatestPendingOnShutdown();
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

            var ack_poll = [_]posix.pollfd{
                .{ .fd = self.ack_r, .events = posix.POLL.IN, .revents = 0 },
                .{ .fd = self.shutdown_r, .events = posix.POLL.IN, .revents = 0 },
            };
            _ = posix.poll(&ack_poll, -1) catch return;
            if (ack_poll[1].revents & posix.POLL.IN != 0 or self.shutting_down.load(.acquire)) {
                self.writeLatestPendingOnShutdown();
                return;
            }
            if (ack_poll[0].revents & posix.POLL.IN != 0) drain(self.ack_r);
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

    fn writeLatestPendingOnShutdown(self: *RumbleWriter) void {
        self.mutex.lock();
        const request = self.pending_stop orelse self.pending;
        self.pending_stop = null;
        self.pending = null;
        self.mutex.unlock();
        if (request) |pending| _ = writeRequest(pending);
    }

    const Selection = union(enum) {
        request: Request,
        wait: i128,
        empty,
    };

    fn takeReadyRequest(self: *RumbleWriter, last_success_ns: i128) Selection {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pending_stop) |request| {
            self.pending_stop = null;
            return .{ .request = request };
        }
        const request = self.pending orelse return .empty;
        if (last_success_ns != 0) {
            const remaining = last_success_ns + MIN_WRITE_INTERVAL_NS - monotonicNs();
            if (remaining > 0) return .{ .wait = remaining };
        }
        self.pending = null;
        return .{ .request = request };
    }

    fn waitForRequest(self: *RumbleWriter, wait_ns: ?i128) bool {
        const timeout_ms: i32 = if (wait_ns) |ns|
            @intCast(@min(
                @as(i128, std.math.maxInt(i32)),
                @max(1, @divFloor(ns + std.time.ns_per_ms - 1, std.time.ns_per_ms)),
            ))
        else
            -1;
        var request_poll = [_]posix.pollfd{
            .{ .fd = self.request_r, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = self.shutdown_r, .events = posix.POLL.IN, .revents = 0 },
        };
        _ = posix.poll(&request_poll, timeout_ms) catch return false;
        if (request_poll[1].revents & posix.POLL.IN != 0 or self.shutting_down.load(.acquire)) return false;
        if (request_poll[0].revents & posix.POLL.IN != 0) drain(self.request_r);
        return true;
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
            &self.request_r,
            &self.request_w,
            &self.completion_r,
            &self.completion_w,
            &self.ack_r,
            &self.ack_w,
            &self.shutdown_r,
            &self.shutdown_w,
        };
        for (fds) |fd| {
            if (fd.* >= 0) posix.close(fd.*);
            fd.* = -1;
        }
    }
};
