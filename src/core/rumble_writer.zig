const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const DeviceIO = @import("../io/device_io.zig").DeviceIO;

// Physical reports are bounded by the same 512-byte ceiling enforced for
// configured input reports. Keeping the mailbox inline avoids allocator use
// across the EventLoop and writer threads.
pub const MAX_FRAME_BYTES: usize = 512;

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
};

const Request = struct {
    device: DeviceIO,
    frame: Frame,
    retry_count: u8,
    len: usize,
    bytes: [MAX_FRAME_BYTES]u8,
};

/// One physical writer with a capacity-one, latest-wins request mailbox.
///
/// EventLoop remains the sole producer. A slow DeviceIO.write occupies only
/// this worker; newer logical rumble states replace the one queued request
/// instead of growing an unbounded backlog. Completions are acknowledged
/// before another write starts so transport failures cannot be overwritten.
pub const RumbleWriter = struct {
    mutex: Mutex = .{},
    pending: ?Request = null,
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
    ) error{ NotRunning, FrameTooLarge }!void {
        if (self.thread == null) return error.NotRunning;
        if (bytes.len > MAX_FRAME_BYTES) return error.FrameTooLarge;

        var request = Request{
            .device = device,
            .frame = frame,
            .retry_count = retry_count,
            .len = bytes.len,
            .bytes = undefined,
        };
        @memcpy(request.bytes[0..bytes.len], bytes);

        self.mutex.lock();
        const needs_wake = self.pending == null;
        self.pending = request;
        self.mutex.unlock();

        if (needs_wake) signal(self.request_w);
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
        while (true) {
            var request_poll = [_]posix.pollfd{
                .{ .fd = self.request_r, .events = posix.POLL.IN, .revents = 0 },
                .{ .fd = self.shutdown_r, .events = posix.POLL.IN, .revents = 0 },
            };
            _ = posix.poll(&request_poll, -1) catch return;
            if (request_poll[1].revents & posix.POLL.IN != 0 or self.shutting_down.load(.acquire)) {
                self.writeLatestPendingOnShutdown();
                return;
            }
            if (request_poll[0].revents & posix.POLL.IN == 0) continue;
            drain(self.request_r);

            const request = self.takeRequest() orelse continue;
            const result = writeRequest(request);

            // Teardown owns no transport result and must never wait for an
            // EventLoop acknowledgement that can no longer arrive. Preserve
            // only the latest queued state so a final STOP is not discarded.
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
        const request = self.takeRequest() orelse return;
        _ = writeRequest(request);
    }

    fn takeRequest(self: *RumbleWriter) ?Request {
        self.mutex.lock();
        defer self.mutex.unlock();
        const request = self.pending;
        self.pending = null;
        return request;
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
