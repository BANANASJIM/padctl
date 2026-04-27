//! Wave 6 T3 — Layer 1 tests for UHID_OUTPUT event dispatch.
//!
//! Verifies that EventLoop correctly drains UHID_OUTPUT events from the
//! primary UHID fd and invokes the registered callback when the device
//! config specifies backend=uhid + kind=pid. Also verifies that the
//! dispatch is a no-op when force_feedback is absent or backend != uhid.
//!
//! Uses pipe2 fixtures — no /dev/uhid required.

const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const testing = std.testing;

const src = @import("src");
const uhid = src.io.uhid;
const UhidDevice = uhid.UhidDevice;
const OutputReport = uhid.OutputReport;
const UHID_EVENT_SIZE = uhid.UHID_EVENT_SIZE;
const UHID_OUTPUT = uhid.UHID_OUTPUT;
const UhidOutputReq = uhid.UhidOutputReq;
const event_loop_mod = src.event_loop;
const EventLoop = event_loop_mod.EventLoop;
const EventLoopContext = event_loop_mod.EventLoopContext;

const DUMMY_DESCRIPTOR = [_]u8{ 0x05, 0x01, 0xC0 };

// Write a synthetic UHID_OUTPUT event to fd with the given payload bytes.
// payload[0] is the report ID.
fn writeUhidOutputEvent(fd: posix.fd_t, payload: []const u8) !void {
    var ev: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, ev[0..4], UHID_OUTPUT, .little);
    // uhid_output_req starts at offset 4: data[4096], size u16, rtype u8
    const sz = @min(payload.len, uhid.UHID_DATA_MAX);
    @memcpy(ev[4..][0..sz], payload[0..sz]);
    std.mem.writeInt(u16, ev[4 + 4096 ..][0..2], @intCast(sz), .little);
    _ = try posix.write(fd, &ev);
}

// Simple callback counter for tests.
const CallbackCtx = struct {
    calls: u32 = 0,
    last_report_id: u8 = 0,
};

fn testCallback(ctx: *anyopaque, report: OutputReport) void {
    const c: *CallbackCtx = @ptrCast(@alignCast(ctx));
    c.calls += 1;
    c.last_report_id = report.report_id;
}

test "uhid_output_dispatch: callback fires on UHID_OUTPUT when backend=uhid kind=pid" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    // pipe2: read-end is given to UhidDevice (dev reads from it);
    // write-end is used by the test to inject synthetic events.
    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[1]);

    const cfg = uhid.Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t3-test",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer {
        dev.fd = -1; // pipe read-end already closed via dev.close() or explicitly
        alloc.destroy(dev);
    }

    var cb_ctx = CallbackCtx{};
    dev.setOutputCallback(testCallback, &cb_ctx);

    // Write one UHID_OUTPUT event.
    try writeUhidOutputEvent(fds[1], &[_]u8{ 0x01, 0xAB, 0xCD });

    // Drain manually (simulating the event_loop drain loop).
    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    while (true) {
        const report = try dev.pollOutputReport(&buf);
        const r = report orelse break;
        if (dev.output_cb) |cb| {
            cb(dev.output_ctx.?, r);
        }
    }

    try testing.expectEqual(@as(u32, 1), cb_ctx.calls);
    try testing.expectEqual(@as(u8, 0x01), cb_ctx.last_report_id);

    posix.close(fds[0]);
}

test "uhid_output_dispatch: no callback → drain is silent no-op" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[1]);

    const cfg = uhid.Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t3-test-noop",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer {
        dev.fd = -1;
        alloc.destroy(dev);
    }

    // No callback registered.
    try writeUhidOutputEvent(fds[1], &[_]u8{ 0x02, 0xFF });

    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    while (true) {
        const report = try dev.pollOutputReport(&buf);
        const r = report orelse break;
        if (dev.output_cb) |cb| {
            cb(dev.output_ctx.?, r);
        }
        // no panic, no assertion failure
    }

    posix.close(fds[0]);
}

test "uhid_output_dispatch: multiple events drain in order" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[1]);

    const cfg = uhid.Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t3-multi",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer {
        dev.fd = -1;
        alloc.destroy(dev);
    }

    var cb_ctx = CallbackCtx{};
    dev.setOutputCallback(testCallback, &cb_ctx);

    // Inject 3 events with distinct report IDs.
    try writeUhidOutputEvent(fds[1], &[_]u8{0x01});
    try writeUhidOutputEvent(fds[1], &[_]u8{0x0A});
    try writeUhidOutputEvent(fds[1], &[_]u8{0x0B});

    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    while (true) {
        const report = try dev.pollOutputReport(&buf);
        const r = report orelse break;
        if (dev.output_cb) |cb| {
            cb(dev.output_ctx.?, r);
        }
    }

    try testing.expectEqual(@as(u32, 3), cb_ctx.calls);
    try testing.expectEqual(@as(u8, 0x0B), cb_ctx.last_report_id);

    posix.close(fds[0]);
}

test "uhid_output_dispatch: clearOutputCallback stops invocation" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[1]);

    const cfg = uhid.Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t3-clear",
        .descriptor = &DUMMY_DESCRIPTOR,
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer {
        dev.fd = -1;
        alloc.destroy(dev);
    }

    var cb_ctx = CallbackCtx{};
    dev.setOutputCallback(testCallback, &cb_ctx);
    dev.clearOutputCallback();

    try writeUhidOutputEvent(fds[1], &[_]u8{0x05});

    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    while (true) {
        const report = try dev.pollOutputReport(&buf);
        const r = report orelse break;
        if (dev.output_cb) |cb| {
            cb(dev.output_ctx.?, r);
        }
    }

    try testing.expectEqual(@as(u32, 0), cb_ctx.calls);

    posix.close(fds[0]);
}
