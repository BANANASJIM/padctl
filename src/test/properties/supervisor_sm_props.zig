// supervisor_sm_props.zig — 1-switch (2-step) state machine coverage for Supervisor.
//
// Tests all valid and invalid transition pairs using attachWithInstance / detach /
// reload and MockDeviceIO.  No real hardware or filesystem access.

const std = @import("std");
const posix = std.posix;
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const EventLoop = @import("../../event_loop.zig").EventLoop;
const DeviceInstance = @import("../../device_instance.zig").DeviceInstance;
const Interpreter = @import("../../core/interpreter.zig").Interpreter;
const MockDeviceIO = @import("../mock_device_io.zig").MockDeviceIO;
const DeviceIO = @import("../../io/device_io.zig").DeviceIO;
const Supervisor = @import("../../supervisor.zig").Supervisor;
const ConfigEntry = @import("../../supervisor.zig").ConfigEntry;

const minimal_toml =
    \\[device]
    \\name = "SM"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

fn makeInstance(allocator: std.mem.Allocator, mock: *MockDeviceIO, cfg: *const device_mod.DeviceConfig) !*DeviceInstance {
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();
    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);
    const inst = try allocator.create(DeviceInstance);
    inst.* = .{
        .allocator = allocator,
        .devices = devices,
        .loop = loop,
        .interp = Interpreter.init(cfg),
        .mapper = null,
        .uinput_dev = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = cfg,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    return inst;
}

// Helpers ------------------------------------------------------------------

fn initSup(allocator: std.mem.Allocator) !Supervisor {
    return Supervisor.initForTest(allocator);
}

fn attach(sup: *Supervisor, allocator: std.mem.Allocator, mock: *MockDeviceIO, cfg: *const device_mod.DeviceConfig, devname: []const u8, phys: []const u8) !void {
    const inst = try makeInstance(allocator, mock, cfg);
    try sup.attachWithInstance(devname, phys, inst, null);
}

// reload with empty config list = remove all
fn reloadEmpty(sup: *Supervisor) !void {
    const initFn = struct {
        fn f(_: std.mem.Allocator, _: ConfigEntry) anyerror!*DeviceInstance {
            return error.Unexpected;
        }
    }.f;
    try sup.reload(&.{}, initFn);
}

// --- valid 2-step sequences -----------------------------------------------

test "SM: attach → managed count == 1" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: attach → attach-duplicate is no-op" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    // Same devname → no-op; inst_b must be freed manually.
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    defer {
        inst_b.deinit();
        allocator.destroy(inst_b);
    }
    try sup.attachWithInstance("hidraw0", "key0b", inst_b, null);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: attach → detach → suspended, count == 1" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    sup.detach("hidraw0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].suspended);
    sup.stopAll();
}

test "SM: attach → detach → suspended instance blocks re-attach with same phys_key" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "key0");
    sup.detach("hidraw0");
    try testing.expect(sup.managed.items[0].suspended);
    // Same phys_key is rejected by dedup guard (suspended instance holds it)
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    defer {
        inst_b.deinit();
        allocator.destroy(inst_b);
    }
    try sup.attachWithInstance("hidraw0", "key0", inst_b, null);
    // Still only 1 instance (the suspended one)
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: reload-while-empty is no-op" {
    const allocator = testing.allocator;
    var sup = try initSup(allocator);
    defer sup.deinit();

    try reloadEmpty(&sup);
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "SM: attach → reload-empty → attach — reload cleans devname_map" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "key0");
    try reloadEmpty(&sup);
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
    // After reload, devname_map must be cleared; re-attaching must succeed.
    try attach(&sup, allocator, &mock_b, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: attach → reload-empty removes instance" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try reloadEmpty(&sup);
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "SM: attach → stopAll → count == 0" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    sup.stopAll();
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

// --- invalid / edge transitions -------------------------------------------

test "SM: detach-unknown is no-op — no panic" {
    const allocator = testing.allocator;
    var sup = try initSup(allocator);
    defer sup.deinit();

    sup.detach("hidraw99"); // must not panic or error
}

test "SM: detach-unknown after attach does not disturb existing instance" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    sup.detach("hidraw99"); // unknown — no-op
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: stopAll on empty supervisor is no-op" {
    const allocator = testing.allocator;
    var sup = try initSup(allocator);
    defer sup.deinit();

    sup.stopAll(); // empty — must not panic
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "SM: attach two devices → detach one → count still 2, one suspended" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "key0");
    try attach(&sup, allocator, &mock_b, &parsed.value, "hidraw1", "key1");
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);

    sup.detach("hidraw0");
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);
    // One is suspended, the other is still active
    var suspended_count: usize = 0;
    for (sup.managed.items) |*m| {
        if (m.suspended) suspended_count += 1;
    }
    try testing.expectEqual(@as(usize, 1), suspended_count);
    sup.stopAll();
}

// --- regression: issue #93 — ADD before REMOVE drained ------------------

test "regression-93: ADD before REMOVE completes must not silent-drop" {
    // Scenario (Harbdrain, 2026-04-22): controller unplugged and re-plugged
    // so fast that the udev ADD for the new hidraw arrives while the prior
    // managed instance is still marked alive (REMOVE uevent not yet drained,
    // or a USB re-enumeration that skipped REMOVE entirely).
    //
    // Prior behavior: attachWithInstance's dedup guard (phys_key match)
    // silently returns, leaving the managed entry stuck on dead hidraw fds
    // and producing no input until `padctl reload`.
    //
    // Expected behavior: when the dedup guard matches on phys_key, probe
    // the backing fd; if dead, force-detach the stale entry and proceed
    // with a fresh attach so the new devname/fds bind.

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    // Step 1 — attach the original instance (thread spawns; starts polling).
    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "phys0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(!sup.managed.items[0].suspended);

    // Step 2 — simulate the backing device going away WITHOUT a REMOVE
    // uevent reaching `detach()` yet. Closing pipe_w surfaces POLLHUP on
    // pipe_r, which is what a real hidraw fd shows after USB removal.
    // The fix's fd probe in attachWithInstance polls with 0 timeout on the
    // managed slot's DeviceIO and is independent of the device thread's
    // lifecycle, so no sleep is needed here. stopAll()/deinit() at teardown
    // will still cleanly join the live thread.
    //
    // Use the atomic helper so the close can't race with the background
    // thread's own drain-path auto-close in MockDeviceIO.read, which would
    // otherwise produce a double-close panic under ReleaseSafe
    // (posix.close treats EBADF as unreachable).
    mock_a.closeWriteEnd();

    // Step 3 — udev ADD for the "new" hidraw node arrives BEFORE the
    // REMOVE for hidraw0 was processed. Kernel assigned a new devname
    // ("hidraw1") because the old node was marked removed but user-space
    // hasn't caught up. phys_key is the same stable USB topology path.
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    // On failure paths (pre-fix), attachWithInstance silently returns and
    // the caller is expected to clean up the un-adopted instance.
    var adopted = false;
    defer if (!adopted) {
        inst_b.deinit();
        allocator.destroy(inst_b);
    };

    try sup.attachWithInstance("hidraw1", "phys0", inst_b, null);

    // Ownership transferred to sup only when the attach actually bound the
    // new devname. If the dedup guard silent-dropped (pre-fix), devname_map
    // would still map "hidraw0" → "phys0" and never gain "hidraw1".
    adopted = sup.devname_map.contains("hidraw1");

    // --- assertions ---
    // New devname must be bound to the supervisor.
    try testing.expect(sup.devname_map.contains("hidraw1"));
    // Stale devname must have been evicted.
    try testing.expect(!sup.devname_map.contains("hidraw0"));
    // Exactly one managed instance remains — the fresh one.
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(!sup.managed.items[0].suspended);

    sup.stopAll();
}

test "regression-93: orphan managed entry (devname==null) with matching phys_key does not dup-attach" {
    // Edge case carve-out for the #93 race-guard fix.
    //
    // Scenario: a ManagedInstance exists with phys_key="phys0" but its
    // devname is null — this models the hotplug allocation-failure edge
    // (supervisor.zig:1289-1304) where `spawnInstance` succeeded but the
    // subsequent devname/map allocations failed and the entry was left
    // orphaned, never registered in devname_map.
    //
    // Without the carve-out, the #93 fix's dead-fd fall-through would
    // spawn a SECOND ManagedInstance under the same phys_key, breaking
    // the dedup invariant. The fix preserves the original silent-return
    // behavior when devname is null (there is no devname to force-detach
    // by anyway — detachFull looks up via devname_map).

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    // Step 1 — create a normal managed entry via attach() so the
    // bookkeeping is valid, then synthesise the orphan state by removing
    // its devname_map binding and freeing/nulling its devname slot.
    try attach(&sup, allocator, &mock_a, &parsed.value, "hidraw0", "phys0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    {
        // Evict the devname_map binding (simulates the put() that never
        // happened in the allocation-failure edge).
        if (sup.devname_map.fetchRemove("hidraw0")) |e| {
            sup.allocator.free(e.key);
            sup.allocator.free(e.value);
        }
        // Free and null m.devname to mirror the orphan's missing devname.
        const m = &sup.managed.items[0];
        if (m.devname) |dn| sup.allocator.free(dn);
        m.devname = null;
    }
    try testing.expect(!sup.devname_map.contains("hidraw0"));
    try testing.expect(sup.managed.items[0].devname == null);

    // Step 2 — kill the backing fd so managedInstanceAlive() returns
    // false, forcing the race-guard path to evaluate the devname branch.
    // Atomic helper prevents double-close with the background thread's
    // drain-path auto-close in MockDeviceIO.read.
    mock_a.closeWriteEnd();

    // Step 3 — attempt a new attach with the same phys_key. Without the
    // carve-out, this would fall through and dup-attach; with it, the
    // orphan branch returns early and inst_b must be cleaned up by the
    // caller.
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    var adopted = false;
    defer if (!adopted) {
        inst_b.deinit();
        allocator.destroy(inst_b);
    };

    try sup.attachWithInstance("hidraw1", "phys0", inst_b, null);
    adopted = sup.devname_map.contains("hidraw1");

    // --- assertions ---
    // Dedup invariant preserved — still only one ManagedInstance.
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    // The new devname must NOT have been bound (early-return).
    try testing.expect(!sup.devname_map.contains("hidraw1"));
    // The orphan is still in place (we couldn't force-detach it without
    // a devname).
    try testing.expect(sup.managed.items[0].devname == null);
    try testing.expect(std.mem.eql(u8, sup.managed.items[0].phys_key, "phys0"));

    sup.stopAll();
}

// --- regression: issue #131-A — zombie uinput after permanent disconnect ---

test "issue-131-A: suspend grace window expires → managed instance torn down if no ADD within grace_sec" {
    // Scenario: PR #114 introduced `detach()` → `suspended = true` to survive
    // wireless sleep/wake without losing the virtual gamepad. But if the
    // physical device is gone permanently (battery dead, cable unplugged)
    // the managed entry lingers forever → zombie uinput node.
    //
    // Fix: `suspend_grace_sec` schedules a deadline at detach time; when
    // `gcExpiredGrace(now_ns)` runs past the deadline the managed entry is
    // fully torn down (equivalent to pre-#114 `detachFull`).

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    // Configure a 5-second grace window.
    sup.suspend_grace_sec = 5;

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    const t0: u64 = 1_000 * std.time.ns_per_s;
    sup.test_now_override_ns = t0;
    sup.detach("hidraw0");

    // Still suspended + tracked before deadline.
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].suspended);
    try testing.expect(sup.managed.items[0].grace_deadline_ns != null);

    // GC at t0+3s (before deadline) → still present.
    sup.gcExpiredGrace(t0 + 3 * std.time.ns_per_s);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    // GC at t0+6s (past deadline) → torn down.
    sup.gcExpiredGrace(t0 + 6 * std.time.ns_per_s);
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "issue-131-A: suspend grace window → ADD within grace_sec re-attaches cleanly" {
    // If a matching ADD arrives within the grace window the suspended
    // instance is reused — its uinput stays alive, grace_deadline_ns is
    // cleared, and `suspended = false` is restored by the rebind path.

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    sup.suspend_grace_sec = 5;

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    const t0: u64 = 1_000 * std.time.ns_per_s;
    sup.test_now_override_ns = t0;
    sup.detach("hidraw0");
    try testing.expect(sup.managed.items[0].suspended);
    try testing.expect(sup.managed.items[0].grace_deadline_ns != null);

    // Simulate rebind: in production the netlink ADD path walks
    // `attachWithRoot` which clears grace_deadline_ns and restores
    // `suspended = false`. The test exercises only the grace-window
    // bookkeeping: call `clearGraceDeadline(&m)` to mirror what the
    // rebind path does, then verify gcExpiredGrace leaves the entry
    // intact even past the original deadline.
    sup.clearGraceDeadline(&sup.managed.items[0]);
    try testing.expect(sup.managed.items[0].grace_deadline_ns == null);

    sup.gcExpiredGrace(t0 + 60 * std.time.ns_per_s);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "issue-131-A: suspend_grace_sec=0 disables grace window (legacy pre-#114 behavior)" {
    // When `suspend_grace_sec == 0`, detach() tears down immediately —
    // equivalent to `detachFull` — restoring the pre-#114 semantics for
    // users who prefer strict removal over sleep/wake preservation.

    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    sup.suspend_grace_sec = 0;

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.detach("hidraw0");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}
