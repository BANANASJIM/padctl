//! Real-uinput integration test for the pollFf UI_FF_ERASE wiring.
//!
//! The production stop-on-erase plumbing lives in `UinputDevice.pollFf`'s
//! UI_FF_ERASE branch (`result = eraseStopEvent(...); break;`). That branch only
//! fires when a real `/dev/uinput` device receives a UI_FF_ERASE request from
//! the kernel — which the Layer-0 `event_loop_ff_erase_test.zig` can't reach
//! because it feeds pollFf's output to the event loop via a canned FfEvent.
//!
//! This test drives the actual ioctl path: padctl creates an FF_RUMBLE uinput
//! device, a client opens the matching evdev node, EVIOCSFF-uploads an infinite
//! effect, then EVIOCRMFF-erases it WITHOUT writing EV_FF value=0. The kernel
//! turns that into UI_FF_UPLOAD / UI_FF_ERASE requests on padctl's fd; we pump
//! the real `pollFf()` and assert it surfaces a zero-magnitude stop FfEvent for
//! the erased slot — the exact emulation that stops the motor on erase.
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
//!       the only place this UI_FF_ERASE wiring runs against the real kernel.

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

fn requireUinput() bool {
    const v = std.posix.getenv("PADCTL_TEST_REQUIRE_UINPUT") orelse return false;
    return std.mem.eql(u8, v, "1") or std.mem.eql(u8, v, "true");
}

fn reportMissingUinput(reason: []const u8) error{ SkipZigTest, UinputAccessRequired } {
    std.log.warn(
        "uinput_ff_erase_integration_test: /dev/uinput unavailable ({s}) — pollFf UI_FF_ERASE wiring CI signal is SILENT. " ++
            "Run in a privileged environment with /dev/uinput, " ++
            "or set PADCTL_TEST_REQUIRE_UINPUT=1 to turn this into a hard failure.",
        .{reason},
    );
    if (requireUinput()) return error.UinputAccessRequired;
    return error.SkipZigTest;
}

const FF_VID: u16 = 0xFAD7;
const FF_PID: u16 = 0x2401;

const ff_toml =
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

fn findEventNode(vid: u16, pid: u16, name_buf: *[40]u8) ?[]const u8 {
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
            return std.fmt.bufPrint(name_buf, "/dev/input/event{d}", .{i}) catch null;
        }
        std.Thread.sleep(50 * std.time.ns_per_ms);
    }
    return null;
}

// Client side, run on its own thread: EVIOCSFF an infinite rumble effect, then
// EVIOCRMFF-erase it without writing EV_FF=0. Both ioctls block until padctl's
// pollFf services the matching kernel request, which is why this can't run
// inline with the pump loop.
const Client = struct {
    node: []const u8,
    result: anyerror!void = {},
    erased_id: i16 = -1,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *Client) void {
        self.result = self.body();
        self.done.store(true, .release);
    }

    fn body(self: *Client) !void {
        const fd = try posix.open(self.node, .{ .ACCMODE = .RDWR }, 0);
        defer posix.close(fd);

        var effect = std.mem.zeroes(c.ff_effect);
        effect.type = c.FF_RUMBLE;
        effect.id = -1; // kernel assigns the slot
        effect.replay.length = 0; // infinite — only ever stopped by erase
        effect.u.rumble.strong_magnitude = 0x8000;
        effect.u.rumble.weak_magnitude = 0x4000;
        if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCSFF, @intFromPtr(&effect))) != .SUCCESS)
            return error.UploadFailed;
        self.erased_id = effect.id;

        const id: c_int = effect.id;
        if (linux.E.init(linux.ioctl(fd, ioctl.EVIOCRMFF, @as(usize, @bitCast(@as(isize, id))))) != .SUCCESS)
            return error.EraseFailed;
    }
};

test "uinput: pollFf turns a real UI_FF_ERASE into a zero-magnitude stop frame" {
    const allocator = testing.allocator;

    const parsed = device_cfg.parseString(allocator, ff_toml) catch return error.ConfigParseFailed;
    defer parsed.deinit();
    const out_cfg = parsed.value.output orelse return error.NoOutput;

    var dev = uinput.UinputDevice.create(&out_cfg) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return reportMissingUinput("/dev/uinput open failed"),
        error.PermissionDenied => return reportMissingUinput("/dev/uinput ioctl permission denied"),
        else => return err,
    };
    defer dev.close();

    var name_buf: [40]u8 = undefined;
    const node = findEventNode(FF_VID, FF_PID, &name_buf) orelse
        return reportMissingUinput("created uinput node did not appear under /dev/input");

    var client = Client{ .node = node };
    const thread = try std.Thread.spawn(.{}, Client.run, .{&client});

    // Pump the real pollFf to drive the upload + erase handshake. The client's
    // EVIOCSFF/EVIOCRMFF block until pollFf services the matching UI_FF_UPLOAD /
    // UI_FF_ERASE request, so we keep pumping until the client thread finishes
    // (so its erase ioctl returns rather than timing out) while capturing the
    // first zero-magnitude stop the erase surfaces. Deadline-bounded so a
    // regression that drops the stop fails instead of hanging.
    var stop: ?uinput.FfEvent = null;
    const deadline = std.time.milliTimestamp() + 5000;
    while (std.time.milliTimestamp() < deadline) {
        if (try dev.pollFf()) |ev| {
            if (stop == null and ev.strong == 0 and ev.weak == 0) stop = ev;
        }
        if (client.done.load(.acquire) and stop != null) break;
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }

    thread.join();
    try client.result;

    const ev = stop orelse return error.NoStopFrameFromErase;
    try testing.expectEqual(@as(u16, c.FF_RUMBLE), ev.effect_type);
    try testing.expectEqual(@as(u16, 0), ev.strong);
    try testing.expectEqual(@as(u16, 0), ev.weak);
    try testing.expect(client.erased_id >= 0);
    try testing.expectEqual(@as(u8, @intCast(client.erased_id)), ev.effect_id);
}
