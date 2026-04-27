const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const render = @import("../debug/render.zig");
const hidraw = @import("../io/hidraw.zig");
const Supervisor = @import("../supervisor.zig").Supervisor;
const EventLoop = @import("../event_loop.zig").EventLoop;
const armTimer = @import("../event_loop.zig").armTimer;
const helpers = @import("helpers.zig");
const layer_mod = @import("../core/layer.zig");

// -- Test 1: renderFrame with empty raw slice --

test "renderFrame: empty raw slice does not panic" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = render.GamepadState{};
    try render.renderFrame(fbs.writer(), &gs, &.{}, false, .{}, .raw);
    try render.renderFrame(fbs.writer(), &gs, &[_]u8{0x42}, true, .{}, .raw);
}

// -- Test 2: stripInputSuffix strips /inputN --

test "stripInputSuffix: strips trailing /inputN" {
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8/input1"));
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8/input2"));
}

test "stripInputSuffix: no suffix unchanged" {
    try testing.expectEqualStrings("usb-0000:00:14.0-8", hidraw.stripInputSuffix("usb-0000:00:14.0-8"));
}

test "stripInputSuffix: bare input without number unchanged" {
    try testing.expectEqualStrings("usb/input", hidraw.stripInputSuffix("usb/input"));
}

test "stripInputSuffix: non-input suffix unchanged" {
    try testing.expectEqualStrings("usb/event0/dev", hidraw.stripInputSuffix("usb/event0/dev"));
}

test "stripInputSuffix: same base path deduplicates" {
    const a = hidraw.stripInputSuffix("usb-0000:00:14.0-8/input1");
    const b = hidraw.stripInputSuffix("usb-0000:00:14.0-8/input2");
    try testing.expectEqualStrings(a, b);
}

// -- Test 3 (issue #64): isTransientOpenError classifies errors correctly --
// Regression: previously only error.AccessDenied was retried; EPERM/ENODEV/ENOENT
// caused a silent drop (bare `return`), losing the hotplug attach forever.

test "isTransientOpenError: transient errors are retried" {
    try testing.expect(Supervisor.isTransientOpenError(error.AccessDenied));
    try testing.expect(Supervisor.isTransientOpenError(error.PermissionDenied));
    try testing.expect(Supervisor.isTransientOpenError(error.DeviceBusy));
    try testing.expect(Supervisor.isTransientOpenError(error.FileNotFound));
    try testing.expect(Supervisor.isTransientOpenError(error.NoDevice));
}

test "isTransientOpenError: fatal errors are not retried" {
    try testing.expect(!Supervisor.isTransientOpenError(error.OutOfMemory));
    try testing.expect(!Supervisor.isTransientOpenError(error.SystemResources));
    try testing.expect(!Supervisor.isTransientOpenError(error.Unexpected));
}

// -- Test 4 (issue #64): attachWithRoot maps any transient open error to HotplugTransient --
// Regression: previously EPERM/ENODEV/ENOENT were normalized to error.AccessDenied,
// making it impossible for callers to distinguish the retry sentinel from a real EACCES.

test "attachWithRoot: missing device returns HotplugTransient, not AccessDenied" {
    var sup = try Supervisor.initForTest(testing.allocator);
    defer sup.deinit();

    // Use a nonexistent path under a real-looking dev root.
    // open() will fail with FileNotFound — a transient error — which must surface as HotplugTransient.
    const result = sup.attachWithRoot("hidraw99", "/dev/nonexistent_root_for_test");
    try testing.expectError(error.HotplugTransient, result);
}

// -- Test 5: directory walker finds .toml in subdirectories --

test "walker: finds toml files in subdirectories" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create nested structure: top.toml, sub/nested.toml, sub/deep/deep.toml
    try tmp.dir.writeFile(.{ .sub_path = "top.toml", .data = "" });
    try tmp.dir.makePath("sub/deep");
    try tmp.dir.writeFile(.{ .sub_path = "sub/nested.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/deep/deep.toml", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "sub/ignore.txt", .data = "" });

    // Reopen with iterate permission for walker
    var iter_dir = try tmp.dir.openDir(".", .{ .iterate = true });
    defer iter_dir.close();
    var walker = try iter_dir.walk(testing.allocator);
    defer walker.deinit();

    var toml_count: usize = 0;
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.basename, ".toml")) {
            toml_count += 1;
        }
    }

    // iterate() would find only top.toml (1); walk() finds all 3
    try testing.expectEqual(@as(usize, 3), toml_count);
}

// -- Test 6 (issue #72): macro timer and layer hold timer are independent fds --
// Regression: both MacroPlayer delay and layer hold-trigger used the same timerfd.
// A layer-hold arm/disarm after apply() would silently overwrite the macro delay,
// causing { delay = N } steps to never fire and subsequent macro steps to be skipped.
// Fix: EventLoop.macro_timer_fd is a dedicated timerfd for TimerQueue; timer_fd is
// layer-hold only.  The two fds never share a timerfd_settime call path.

test "issue #72: macro_timer_fd and timer_fd are independent — layer arm does not clobber macro delay" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    // Arm the macro timer for 30ms.
    armTimer(loop.macro_timer_fd, 30);

    // Immediately overwrite the layer timer (simulating timer_request.arm from apply()).
    // Before the fix both pointed at the same fd, so this would kill the macro timer.
    armTimer(loop.timer_fd, 5000);

    // Macro timer must still fire within 200ms despite the layer arm above.
    var pfd = [1]posix.pollfd{.{ .fd = loop.macro_timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 200);
    try testing.expectEqual(@as(usize, 1), ready);
}

// -- Test 7 (PR #171 follow-up): timer expiry handlers must be split per slot --
// Regression: Mapper.onTimerExpired ran self.layer.onTimerExpired() unconditionally,
// promoting any PENDING layer to ACTIVE regardless of which timerfd fired. PR #171
// only separated the arm path; the expiry handlers still routed through one entry,
// so a macro `delay` shorter than hold_timeout collapsed the layer hold timing to
// the macro deadline.

test "macro timer expiry must NOT promote PENDING layer (PR #171 follow-up)" {
    const allocator = testing.allocator;

    var ctx = try helpers.makeMapper(
        \\[[layer]]
        \\name = "fps"
        \\trigger = "LT"
        \\activation = "hold"
        \\hold_timeout = 200
        \\
        \\[[macro]]
        \\name = "tap_b"
        \\steps = [
        \\  { delay = 50 },
        \\  { tap = "KEY_B" },
        \\]
        \\
        \\[remap]
        \\A = "macro:tap_b"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // t=0: press A → macro arms TimerQueue for t+50ms via macro_timer_fd.
    const press_a_ns: i128 = 0;
    const a_mask = helpers.btnMask(.A);
    _ = try m.apply(.{ .buttons = a_mask }, 16, press_a_ns);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);

    // t=20ms: press LT → layer goes PENDING; layer hold deadline at t=220ms.
    const press_lt_ns: i128 = 20 * std.time.ns_per_ms;
    const lt_mask = helpers.btnMask(.LT);
    _ = try m.apply(.{ .buttons = a_mask | lt_mask }, 16, press_lt_ns);
    try testing.expect(m.layer.tap_hold != null);
    try testing.expectEqual(layer_mod.TapHoldPhase.pending, m.layer.tap_hold.?.phase);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // t=50ms: macro_timer_fd fires (slot 4). Calling the macro-only handler
    // must NOT touch the layer state.
    const macro_expiry_ns: i128 = 50 * std.time.ns_per_ms;
    _ = m.onMacroTimerExpired(macro_expiry_ns);

    // Layer must still be PENDING — premature promotion is the regression.
    try testing.expect(m.layer.tap_hold != null);
    try testing.expectEqual(layer_mod.TapHoldPhase.pending, m.layer.tap_hold.?.phase);
    try testing.expect(!m.layer.tap_hold.?.layer_activated);

    // Layer timer_fd fires (slot 2). Layer-only handler promotes PENDING → ACTIVE.
    _ = m.onLayerTimerExpired();
    try testing.expectEqual(layer_mod.TapHoldPhase.active, m.layer.tap_hold.?.phase);
    try testing.expect(m.layer.tap_hold.?.layer_activated);
}

test "layer timer expiry must NOT drain macro queue (PR #171 follow-up)" {
    const allocator = testing.allocator;

    var ctx = try helpers.makeMapper(
        \\[[layer]]
        \\name = "fps"
        \\trigger = "LT"
        \\activation = "hold"
        \\hold_timeout = 100
        \\
        \\[[macro]]
        \\name = "delayed_b"
        \\steps = [
        \\  { delay = 500 },
        \\  { tap = "KEY_B" },
        \\]
        \\
        \\[remap]
        \\A = "macro:delayed_b"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    // t=0: press A → macro arms TimerQueue for t+500ms.
    const a_mask = helpers.btnMask(.A);
    _ = try m.apply(.{ .buttons = a_mask }, 16, 0);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);
    const initial_step_index = m.active_macros.items[0].step_index;

    // t=10ms: press LT → layer PENDING; hold deadline at t=110ms.
    const press_lt_ns: i128 = 10 * std.time.ns_per_ms;
    const lt_mask = helpers.btnMask(.LT);
    _ = try m.apply(.{ .buttons = a_mask | lt_mask }, 16, press_lt_ns);

    // Layer-only handler must NOT advance the macro player (whose deadline is
    // far in the future at t=510ms). The macro must still be at the same step.
    _ = m.onLayerTimerExpired();

    try testing.expect(m.layer.tap_hold != null);
    try testing.expectEqual(layer_mod.TapHoldPhase.active, m.layer.tap_hold.?.phase);
    try testing.expectEqual(@as(usize, 1), m.active_macros.items.len);
    try testing.expectEqual(initial_step_index, m.active_macros.items[0].step_index);
}
