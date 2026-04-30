const std = @import("std");
const posix = std.posix;
const OutputReport = @import("uhid.zig").OutputReport;

/// Writes UHID_OUTPUT bytes byte-faithfully to the physical wheel hidraw fd.
///
/// Borrowed fd: Supervisor owns the hidraw fd lifetime; FfbForwarder is a
/// non-owning borrower. Never call posix.close on physical_fd here.
pub const FfbForwarder = struct {
    physical_fd: posix.fd_t,
    state: enum { active, disabled } = .active,
    writes_total: u64 = 0,
    drops_eagain: u64 = 0,

    pub fn init(physical_fd: posix.fd_t) FfbForwarder {
        return .{ .physical_fd = physical_fd };
    }

    /// Write report.data to the physical hidraw fd, byte-for-byte unchanged.
    /// Errors are classified and logged; none escape to the caller.
    pub fn forward(self: *FfbForwarder, report: OutputReport) void {
        if (self.state == .disabled) return;
        _ = posix.write(self.physical_fd, report.data) catch |err| switch (err) {
            error.WouldBlock => {
                self.drops_eagain += 1;
                std.log.debug("ffb forwarder: EAGAIN (drop #{d})", .{self.drops_eagain});
                return;
            },
            error.AccessDenied, error.PermissionDenied => {
                std.log.warn("ffb forwarder: hidraw write EACCES, disabling (udev rule may be missing)", .{});
                self.state = .disabled;
                return;
            },
            error.NoDevice => {
                // Device unplugged; supervisor unbind handles cleanup.
                std.log.warn("ffb forwarder: hidraw ENODEV, disabling", .{});
                self.state = .disabled;
                return;
            },
            else => {
                std.log.warn("ffb forwarder: hidraw write error {}, disabling", .{err});
                self.state = .disabled;
                return;
            },
        };
        self.writes_total += 1;
    }

    pub fn deinit(_: *FfbForwarder) void {}
};

/// Static trampoline registered via UhidDevice.setOutputCallback.
pub fn forwarderCallback(ctx: *anyopaque, report: OutputReport) void {
    const self: *FfbForwarder = @ptrCast(@alignCast(ctx));
    self.forward(report);
}

// --- Tests -----------------------------------------------------------------

const testing = std.testing;

test "FfbForwarder: forwards report bytes byte-faithfully" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var fwd = FfbForwarder.init(fds[1]);
    const payload = [_]u8{ 0x01, 0x02, 0x03 };
    fwd.forward(.{ .report_id = 0x01, .data = &payload });

    var buf: [16]u8 = undefined;
    const n = try posix.read(fds[0], &buf);
    try testing.expectEqual(@as(usize, 3), n);
    try testing.expectEqualSlices(u8, &payload, buf[0..n]);
}

test "FfbForwarder: counts writes_total" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var fwd = FfbForwarder.init(fds[1]);
    const payload = [_]u8{0xAA};
    fwd.forward(.{ .report_id = 0xAA, .data = &payload });
    fwd.forward(.{ .report_id = 0xAA, .data = &payload });
    fwd.forward(.{ .report_id = 0xAA, .data = &payload });
    try testing.expectEqual(@as(u64, 3), fwd.writes_total);

    // Drain pipe
    var buf: [64]u8 = undefined;
    _ = posix.read(fds[0], &buf) catch {};
    _ = posix.read(fds[0], &buf) catch {};
    _ = posix.read(fds[0], &buf) catch {};
}

test "FfbForwarder: EAGAIN increments drops_eagain" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    // Non-blocking pipe: fill it to capacity then attempt another write.
    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    // Fill the pipe buffer (Linux default is 64 KiB; write until EAGAIN).
    const chunk = [_]u8{0xFF} ** 4096;
    var filled: usize = 0;
    while (filled < 128 * 1024) {
        const n = posix.write(fds[1], &chunk) catch break;
        filled += n;
    }

    var fwd = FfbForwarder.init(fds[1]);
    const payload = [_]u8{0x01};
    fwd.forward(.{ .report_id = 0x01, .data = &payload });

    try testing.expectEqual(@as(u64, 1), fwd.drops_eagain);
    try testing.expectEqual(@as(u64, 0), fwd.writes_total);
}

test "FfbForwarder: closed fd transitions to state=disabled" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);

    var fwd = FfbForwarder.init(fds[1]);
    // Close the write end before forwarding.
    posix.close(fds[1]);

    const payload = [_]u8{0x01};
    fwd.forward(.{ .report_id = 0x01, .data = &payload });

    // EBADF or ENODEV both must result in disabled state.
    try testing.expectEqual(.disabled, fwd.state);
}

test "FfbForwarder: disabled state short-circuits without writing" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var fwd = FfbForwarder.init(fds[1]);
    fwd.state = .disabled;

    const payload = [_]u8{0x01};
    fwd.forward(.{ .report_id = 0x01, .data = &payload });
    try testing.expectEqual(@as(u64, 0), fwd.writes_total);
    try testing.expectEqual(@as(u64, 0), fwd.drops_eagain);
}
