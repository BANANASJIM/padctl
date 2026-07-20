//! Real-uinput integration tests for the pollFf FF event wiring.
//!
//! The production stop-on-erase plumbing lives in `UinputDevice.pollFf`'s
//! UI_FF_ERASE branch (`result = eraseStopEvent(...); break;`). That branch only
//! fires when a real `/dev/uinput` device receives a UI_FF_ERASE request from
//! the kernel — which the Layer-0 `event_loop_ff_erase_test.zig` can't reach
//! because it feeds pollFf's output to the event loop via a canned FfEvent.
//!
//! These tests drive the actual ioctl path: padctl creates an FF_RUMBLE uinput
//! device and a client opens the matching evdev node. One scenario uploads an
//! effect and writes rapid EV_FF PLAY+STOP events; the other erases an effect
//! without EV_FF=0. Both kernel handshakes are pumped through real `pollFf()`.
//!
//! ## Runtime behaviour (mirrors shadow_grab_integration_test.zig)
//!
//! - On a host without `/dev/uinput` access (the plain `check-matrix` CI job,
//!   unprivileged containers): logs an explicit warning, then either
//!     * Default: returns `error.SkipZigTest` — the suite stays green while
//!       making the gap audible.
//!     * When `PADCTL_TEST_REQUIRE_UINPUT=1` is set: returns
//!       `error.UinputAccessRequired` — a hard failure, so an environment meant
//!       to have /dev/uinput but lacking it surfaces the breakage. The
//!       privileged `e2e` job sets it when /dev/uinput is accessible, which is
//!       where these FF wiring scenarios run against the real kernel.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const uinput = src.io.uinput;
const ioctl = src.io.ioctl_constants;
const device_cfg = src.config.device;

const c = @cImport({
    @cInclude("linux/input.h");
});

extern "c" fn pthread_kill(thread: std.c.pthread_t, signal: c_int) c_int;

const gate = src.testing_support.uhid_gate;

const FF_VID: u16 = 0xFAD7;
const FF_ERASE_PID: u16 = 0x2401;
const FF_PLAY_STOP_PID: u16 = 0x2402;
const FF_ERASE_NAME = "padctl-ff-erase-itest";
const FF_PLAY_STOP_NAME = "padctl-ff-play-stop-itest";
const EVIOCGNAME_256 = linux.IOCTL.IOR('E', 0x06, [256]u8);
const CLIENT_TIMEOUT_NS = 5 * std.time.ns_per_s;
const CLIENT_POLL_MS: i32 = 50;
const CANCEL_TIMEOUT_MS: i32 = 500;
const CLEANUP_DRAIN_MS: i32 = 50;
const MAX_DRAIN_POLLS: usize = 32;

const ff_erase_toml =
    \\[device]
    \\name = "ff-erase-itest"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[output]
    \\name = "padctl-ff-erase-itest"
    \\vid = 0xFAD7
    \\pid = 0x2401
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

const ff_play_stop_toml =
    \\[device]
    \\name = "ff-play-stop-itest"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[output]
    \\name = "padctl-ff-play-stop-itest"
    \\vid = 0xFAD7
    \\pid = 0x2402
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

fn findEventNode(vid: u16, pid: u16, expected_name: []const u8, path_buf_out: *[40]u8) ?[]const u8 {
    var attempt: usize = 0;
    while (attempt < 20) : (attempt += 1) {
        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            var path_buf: [40]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "/dev/input/event{d}", .{i}) catch continue;
            const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
            defer posix.close(fd);
            var id: ioctl.InputId = undefined;
            if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCGID, @intFromPtr(&id))) != .SUCCESS) continue;
            if (id.vendor != vid or id.product != pid) continue;
            var actual_name: [256]u8 = @splat(0);
            if (linux.E.init(linux.ioctl(fd, EVIOCGNAME_256, @intFromPtr(&actual_name))) != .SUCCESS) continue;
            const name_len = std.mem.indexOfScalar(u8, &actual_name, 0) orelse actual_name.len;
            if (!std.mem.eql(u8, expected_name, actual_name[0..name_len])) continue;
            return std.fmt.bufPrint(path_buf_out, "/dev/input/event{d}", .{i}) catch null;
        }
        std.Thread.sleep(50 * std.time.ns_per_ms);
    }
    return null;
}

const ClientAction = enum {
    erase,
    play_stop,
};

fn interruptHandler(_: i32) callconv(.c) void {}

fn terminateTestProcess() noreturn {
    // Returning while a worker still borrows stack state is unsafe. The build
    // target also has a hard `timeout` watchdog, but terminate immediately if
    // SIGUSR1 failed to interrupt the blocking evdev ioctl.
    _ = linux.kill(linux.getpid(), posix.SIG.TERM);
    unreachable;
}

fn cancelAndJoin(thread: std.Thread, done_fd: posix.fd_t, completed: *const std.atomic.Value(bool)) void {
    if (completed.load(.acquire)) {
        thread.join();
        return;
    }

    // Even when pthread_kill reports that the target already exited, allow the
    // same bounded completion window: the worker may be between returning from
    // its body and publishing `completed`.
    _ = pthread_kill(thread.getHandle(), posix.SIG.USR1);
    var done_poll = [_]posix.pollfd{.{ .fd = done_fd, .events = posix.POLL.IN, .revents = 0 }};
    _ = posix.poll(&done_poll, CANCEL_TIMEOUT_MS) catch terminateTestProcess();
    if (!completed.load(.acquire)) terminateTestProcess();
    thread.join();
}

fn finishAfterPumpError(
    thread: std.Thread,
    done_fd: posix.fd_t,
    completed: *const std.atomic.Value(bool),
    client_done: bool,
) void {
    if (client_done or completed.load(.acquire)) {
        thread.join();
    } else {
        cancelAndJoin(thread, done_fd, completed);
    }
}

fn writeFfEvent(fd: posix.fd_t, effect_id: i16, value: i32) !void {
    if (effect_id < 0) return error.InvalidEffectId;
    const event = c.input_event{
        .type = c.EV_FF,
        .code = @intCast(effect_id),
        .value = value,
        .time = std.mem.zeroes(c.timeval),
    };
    const bytes = std.mem.asBytes(&event);
    const written = try posix.write(fd, bytes);
    if (written != bytes.len) return error.ShortEventWrite;
}

// Client side, run on its own thread. EVIOCSFF and EVIOCRMFF block until
// padctl's pollFf services the corresponding kernel requests, so the main
// thread pumps /dev/uinput while this worker uses the evdev side.
const Client = struct {
    node: []const u8,
    action: ClientAction,
    done_fd: posix.fd_t,
    completed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    result: anyerror!void = {},
    effect_id: i16 = -1,
    fd: posix.fd_t = -1,

    fn run(self: *Client) void {
        self.result = self.body();
        self.completed.store(true, .release);
        var one: u64 = 1;
        _ = posix.write(self.done_fd, std.mem.asBytes(&one)) catch {};
    }

    fn body(self: *Client) !void {
        const fd = try posix.open(self.node, .{ .ACCMODE = .RDWR }, 0);
        // The harness closes this fd only after it verifies the explicit
        // action. Keeping it open prevents kernel close-cleanup STOPs from
        // masquerading as the PLAY/STOP or ERASE event under test.
        self.fd = fd;

        var effect = std.mem.zeroes(c.ff_effect);
        effect.type = c.FF_RUMBLE;
        effect.id = -1; // kernel assigns the slot
        effect.replay.length = if (self.action == .erase) 0 else 65535;
        effect.u.rumble.strong_magnitude = 0xf000;
        effect.u.rumble.weak_magnitude = 0x0f00;
        if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCSFF, @intFromPtr(&effect))) != .SUCCESS)
            return error.UploadFailed;
        self.effect_id = effect.id;

        switch (self.action) {
            .erase => {
                const id: c_int = effect.id;
                if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCRMFF, @as(usize, @bitCast(@as(isize, id))))) != .SUCCESS)
                    return error.EraseFailed;
            },
            .play_stop => {
                // Deliberately no sleep: this is the real-kernel counterpart
                // to the rapid same-slot PLAY+STOP FIFO regression test.
                try writeFfEvent(fd, effect.id, 1);
                try writeFfEvent(fd, effect.id, 0);
            },
        }
    }
};

const ScenarioResult = struct {
    events: [8]uinput.FfEvent = undefined,
    event_count: usize = 0,
    target_event_count: usize = 0,
    effect_id: i16,
};

fn drainQueuedEvents(dev: *uinput.UinputDevice, result: *ScenarioResult, initial_timeout_ms: i32) !void {
    var timeout_ms = initial_timeout_ms;
    var poll_count: usize = 0;
    while (poll_count < MAX_DRAIN_POLLS) : (poll_count += 1) {
        var pollfds = [_]posix.pollfd{.{ .fd = dev.pollFfFd(), .events = posix.POLL.IN, .revents = 0 }};
        const ready = try posix.poll(&pollfds, timeout_ms);
        timeout_ms = 0;
        if (ready == 0) return;
        if (pollfds[0].revents & (posix.POLL.ERR | posix.POLL.HUP | posix.POLL.NVAL) != 0)
            return error.PollDescriptorFailed;
        if (pollfds[0].revents & posix.POLL.IN == 0) return error.UnexpectedPollEvent;
        if (try dev.pollFf()) |event| {
            if (result.event_count >= result.events.len) return error.TooManyFfEvents;
            result.events[result.event_count] = event;
            result.event_count += 1;
        }
    }
    return error.FfQueueDidNotDrain;
}

const ClientCloser = struct {
    fd: posix.fd_t,
    done_fd: posix.fd_t,
    completed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *ClientCloser) void {
        posix.close(self.fd);
        self.completed.store(true, .release);
        var one: u64 = 1;
        _ = posix.write(self.done_fd, std.mem.asBytes(&one)) catch {};
    }
};

fn closeClientWithPump(dev: *uinput.UinputDevice, fd: posix.fd_t, result: *ScenarioResult) !void {
    // Once ownership reaches this helper, failing to start the closer would
    // leave an fd that may require a pumped UI_FF_ERASE handshake. Terminate
    // instead of returning with an unsafe synchronous-close fallback.
    const done_fd = posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK) catch terminateTestProcess();
    defer posix.close(done_fd);

    var closer = ClientCloser{ .fd = fd, .done_fd = done_fd };
    const thread = std.Thread.spawn(.{}, ClientCloser.run, .{&closer}) catch terminateTestProcess();
    var joined = false;
    defer if (!joined) cancelAndJoin(thread, done_fd, &closer.completed);

    var timer = try std.time.Timer.start();
    var close_done = false;
    while (timer.read() < CLIENT_TIMEOUT_NS) {
        var pollfds = [_]posix.pollfd{
            .{ .fd = dev.pollFfFd(), .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = done_fd, .events = posix.POLL.IN, .revents = 0 },
        };
        const ready = posix.poll(&pollfds, CLIENT_POLL_MS) catch |err| {
            cancelAndJoin(thread, done_fd, &closer.completed);
            joined = true;
            return err;
        };
        if (ready == 0) {
            close_done = closer.completed.load(.acquire);
            if (close_done) break;
            continue;
        }

        const fatal_poll_events = posix.POLL.ERR | posix.POLL.HUP | posix.POLL.NVAL;
        if (pollfds[0].revents & fatal_poll_events != 0 or
            pollfds[1].revents & fatal_poll_events != 0)
        {
            cancelAndJoin(thread, done_fd, &closer.completed);
            joined = true;
            return error.PollDescriptorFailed;
        }

        if (pollfds[0].revents & posix.POLL.IN != 0) {
            const maybe_event = dev.pollFf() catch |err| {
                cancelAndJoin(thread, done_fd, &closer.completed);
                joined = true;
                return err;
            };
            if (maybe_event) |event| {
                if (result.event_count >= result.events.len) {
                    cancelAndJoin(thread, done_fd, &closer.completed);
                    joined = true;
                    return error.TooManyFfEvents;
                }
                result.events[result.event_count] = event;
                result.event_count += 1;
            }
        }
        if (pollfds[1].revents & posix.POLL.IN != 0) {
            var completed_count: u64 = 0;
            const read_len = posix.read(done_fd, std.mem.asBytes(&completed_count)) catch |err| {
                cancelAndJoin(thread, done_fd, &closer.completed);
                joined = true;
                return err;
            };
            if (read_len != @sizeOf(u64) or completed_count == 0) {
                cancelAndJoin(thread, done_fd, &closer.completed);
                joined = true;
                return error.InvalidCompletionSignal;
            }
        }
        close_done = closer.completed.load(.acquire);
        if (close_done) break;
    }

    if (!close_done) {
        cancelAndJoin(thread, done_fd, &closer.completed);
        joined = true;
        return error.ClientCloseTimeout;
    }
    thread.join();
    joined = true;

    // Catch any cleanup event queued immediately after close published done.
    try drainQueuedEvents(dev, result, CLEANUP_DRAIN_MS);
}

fn runScenario(
    toml: []const u8,
    pid: u16,
    expected_name: []const u8,
    action: ClientAction,
    expected_events: usize,
) !ScenarioResult {
    const allocator = testing.allocator;

    const parsed = device_cfg.parseString(allocator, toml) catch return error.ConfigParseFailed;
    defer parsed.deinit();
    const out_cfg = parsed.value.output orelse return error.NoOutput;

    var dev = uinput.UinputDevice.create(&out_cfg) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return gate.reportMissingUinput("/dev/uinput open failed"),
        error.PermissionDenied => return gate.reportMissingUinput("/dev/uinput ioctl permission denied"),
        else => return err,
    };
    defer dev.close();

    var name_buf: [40]u8 = undefined;
    const node = findEventNode(FF_VID, pid, expected_name, &name_buf) orelse
        return gate.reportMissingUinput("created uinput node did not appear under /dev/input");

    var previous_usr1: posix.Sigaction = undefined;
    posix.sigaction(posix.SIG.USR1, &.{
        .handler = .{ .handler = interruptHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    }, &previous_usr1);
    defer posix.sigaction(posix.SIG.USR1, &previous_usr1, null);

    const done_fd = try posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
    defer posix.close(done_fd);
    var client = Client{ .node = node, .action = action, .done_fd = done_fd };
    var result = ScenarioResult{ .effect_id = -1 };
    const thread = try std.Thread.spawn(.{}, Client.run, .{&client});
    errdefer if (client.fd >= 0) {
        const client_fd = client.fd;
        client.fd = -1;
        var discarded = ScenarioResult{ .effect_id = -1 };
        closeClientWithPump(&dev, client_fd, &discarded) catch terminateTestProcess();
    };
    var joined = false;
    defer if (!joined) cancelAndJoin(thread, done_fd, &client.completed);

    var timer = try std.time.Timer.start();
    var client_done = false;
    while (timer.read() < CLIENT_TIMEOUT_NS) {
        var pollfds = [_]posix.pollfd{
            .{ .fd = dev.pollFfFd(), .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = done_fd, .events = posix.POLL.IN, .revents = 0 },
        };
        const ready = posix.poll(&pollfds, CLIENT_POLL_MS) catch |err| {
            finishAfterPumpError(thread, done_fd, &client.completed, client_done);
            joined = true;
            return err;
        };
        if (ready == 0) {
            client_done = client.completed.load(.acquire);
            if (client_done) break;
            continue;
        }

        const fatal_poll_events = posix.POLL.ERR | posix.POLL.HUP | posix.POLL.NVAL;
        if (pollfds[0].revents & fatal_poll_events != 0 or
            pollfds[1].revents & fatal_poll_events != 0)
        {
            finishAfterPumpError(thread, done_fd, &client.completed, client_done);
            joined = true;
            return error.PollDescriptorFailed;
        }

        if (pollfds[0].revents & posix.POLL.IN != 0) {
            const maybe_event = dev.pollFf() catch |err| {
                finishAfterPumpError(thread, done_fd, &client.completed, client_done);
                joined = true;
                return err;
            };
            if (maybe_event) |event| {
                if (result.event_count >= result.events.len) {
                    finishAfterPumpError(thread, done_fd, &client.completed, client_done);
                    joined = true;
                    return error.TooManyFfEvents;
                }
                result.events[result.event_count] = event;
                result.event_count += 1;
            }
        }
        if (pollfds[1].revents & posix.POLL.IN != 0) {
            var completed_count: u64 = 0;
            const read_len = posix.read(done_fd, std.mem.asBytes(&completed_count)) catch |err| {
                finishAfterPumpError(thread, done_fd, &client.completed, client_done);
                joined = true;
                return err;
            };
            if (read_len != @sizeOf(u64) or completed_count == 0) {
                finishAfterPumpError(thread, done_fd, &client.completed, client_done);
                joined = true;
                return error.InvalidCompletionSignal;
            }
        }
        client_done = client.completed.load(.acquire);
        if (client_done) break;
    }

    if (!client_done) {
        cancelAndJoin(thread, done_fd, &client.completed);
        joined = true;
        return error.ClientTimeout;
    }
    thread.join();
    joined = true;
    try client.result;

    // All explicit writes/ioctls have returned, but the evdev fd remains open.
    // Drain now and pin the target event count before close-generated cleanup
    // can enter the uinput queue.
    try drainQueuedEvents(&dev, &result, 0);
    if (result.event_count != expected_events) return error.UnexpectedTargetEventCount;
    result.target_event_count = result.event_count;

    if (client.fd < 0) return error.MissingClientFd;
    const client_fd = client.fd;
    client.fd = -1;

    // Closing the FF client can legitimately append STOP/ERASE cleanup events.
    // A dedicated closer owns the potentially blocking close while this thread
    // continues pumping UI_FF_ERASE. Capture cleanup separately so callers can
    // enforce that it stays zero without letting it substitute for the target.
    try closeClientWithPump(&dev, client_fd, &result);

    result.effect_id = client.effect_id;
    return result;
}

fn expectStopEvent(event: uinput.FfEvent, effect_id: u8) !void {
    try testing.expectEqual(@as(u16, c.FF_RUMBLE), event.effect_type);
    try testing.expectEqual(effect_id, event.effect_id);
    try testing.expectEqual(@as(u16, 0), event.strong);
    try testing.expectEqual(@as(u16, 0), event.weak);
    try testing.expectEqual(@as(u16, 0), event.duration_ms);
}

test "uinput: pollFf preserves real-kernel rapid PLAY then explicit STOP" {
    const result = try runScenario(ff_play_stop_toml, FF_PLAY_STOP_PID, FF_PLAY_STOP_NAME, .play_stop, 2);

    try testing.expect(result.effect_id >= 0);
    try testing.expectEqual(@as(usize, 2), result.target_event_count);
    const play = result.events[0];
    const stop = result.events[1];
    try testing.expectEqual(@as(u16, c.FF_RUMBLE), play.effect_type);
    try testing.expectEqual(@as(u8, @intCast(result.effect_id)), play.effect_id);
    try testing.expectEqual(@as(u16, 0xf000), play.strong);
    try testing.expectEqual(@as(u16, 0x0f00), play.weak);
    try testing.expectEqual(@as(u16, 65535), play.duration_ms);
    try expectStopEvent(stop, play.effect_id);

    // Closing an evdev FF client may emit additional kernel cleanup STOP/ERASE
    // notifications. They are valid only if they remain zero for this slot;
    // a late non-zero frame would re-arm rumble after the explicit STOP.
    for (result.events[result.target_event_count..result.event_count]) |event|
        try expectStopEvent(event, play.effect_id);
}

test "uinput: pollFf turns a real UI_FF_ERASE into a zero-magnitude stop frame" {
    // Linux ff-core stops the effect with EV_FF=0 before issuing UI_FF_ERASE.
    // pollFf must preserve that kernel stop and surface its own erase stop, so
    // the pre-close target phase contains exactly two zero events.
    const result = try runScenario(ff_erase_toml, FF_ERASE_PID, FF_ERASE_NAME, .erase, 2);

    try testing.expectEqual(@as(usize, 2), result.target_event_count);
    try testing.expect(result.effect_id >= 0);
    const effect_id: u8 = @intCast(result.effect_id);
    for (result.events[0..result.event_count]) |event|
        try expectStopEvent(event, effect_id);
}
