const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const wedge_mod = @import("../io/wedge_atomics.zig");
const WedgeAtomics = wedge_mod.WedgeAtomics;
const HidrawDevice = @import("../io/hidraw.zig").HidrawDevice;
const FfbForwarder = @import("../io/ffb_forwarder.zig").FfbForwarder;
const OutputReport = @import("../io/uhid.zig").OutputReport;

// Test A: write enter sets write_in_flight_since_ns, exit clears it (success path).
// Falsifiability: removing the `defer w.endWrite()` in hidraw.write makes the
// post-call expectEqual fail with the begin timestamp instead of 0.
test "wedge: hidraw write clears write_in_flight_since_ns on success" {
    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var wedge = WedgeAtomics{};

    var dev = HidrawDevice{
        .fd = fds[1],
        .evdev_fds = .{},
        .allocator = testing.allocator,
        .wedge = &wedge,
    };
    const io = dev.deviceIO();

    try testing.expectEqual(@as(u64, 0), wedge.loadInFlight());
    const payload = [_]u8{ 0x01, 0x02, 0x03 };
    try io.write(&payload);
    try testing.expectEqual(@as(u64, 0), wedge.loadInFlight());
    try testing.expect(wedge.loadOutbound() != 0);

    // Drain the pipe to avoid leaking blocked bytes.
    var drain: [16]u8 = undefined;
    _ = posix.read(fds[0], &drain) catch {};
}

// Test B: error path still clears write_in_flight_since_ns.
// Falsifiability: same as Test A — defer guarantees the clear runs regardless
// of the write outcome. Without the defer, the error path leaves the field set.
test "wedge: hidraw write clears write_in_flight_since_ns on error" {
    // Closed write-end → BrokenPipe → DeviceIO.WriteError.Disconnected.
    const fds = try posix.pipe2(.{});
    posix.close(fds[0]);
    defer posix.close(fds[1]);

    var wedge = WedgeAtomics{};

    var dev = HidrawDevice{
        .fd = fds[1],
        .evdev_fds = .{},
        .allocator = testing.allocator,
        .wedge = &wedge,
    };
    const io = dev.deviceIO();

    const payload = [_]u8{0x99};
    // Either Disconnected or Io is acceptable — the point is that the call
    // returns an error and the in-flight slot must still be cleared.
    const result = io.write(&payload);
    try testing.expect(std.meta.isError(result));
    try testing.expectEqual(@as(u64, 0), wedge.loadInFlight());
}

// Test B2: FfbForwarder forward() clears write_in_flight_since_ns even when
// the forwarder hits an error path that returns without writing.
test "wedge: ffb_forwarder clears write_in_flight_since_ns after closed-fd error" {
    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);

    var wedge = WedgeAtomics{};
    var fwd = FfbForwarder.init(fds[1]);
    fwd.attachWedge(&wedge);

    posix.close(fds[1]);

    const payload = [_]u8{0x01};
    fwd.forward(.{ .report_id = 0x01, .data = &payload });
    try testing.expectEqual(@as(u64, 0), wedge.loadInFlight());
}

// Test: hidraw read bumps last_inbound_ns on success.
test "wedge: hidraw read bumps last_inbound_ns" {
    const fds = try posix.pipe2(.{});
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    var wedge = WedgeAtomics{};
    var dev = HidrawDevice{
        .fd = fds[0],
        .evdev_fds = .{},
        .allocator = testing.allocator,
        .wedge = &wedge,
    };
    const io = dev.deviceIO();

    const payload = [_]u8{ 0x10, 0x20 };
    _ = try posix.write(fds[1], &payload);

    var buf: [16]u8 = undefined;
    const n = try io.read(&buf);
    try testing.expectEqual(@as(usize, 2), n);
    try testing.expect(wedge.loadInbound() != 0);
}

// Test C + D: STATUS output contains the 3 new fields, and write_in_flight_ms
// reports a sensible non-zero when the atomic is pre-armed.
// Falsifiability for C: removing any of the three writes in handleStatus
// causes the corresponding indexOf assertion to fail.
// Falsifiability for D: dropping the `(now_ns - ifs) / ns_per_ms` formula
// in favour of a constant breaks the ±tolerance assertion.
test "wedge: STATUS surfaces last_inbound_ms_ago, last_outbound_ms_ago, write_in_flight_ms" {
    const Supervisor = @import("../supervisor.zig").Supervisor;
    const device_mod = @import("../config/device.zig");
    const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
    const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
    const DeviceIO = @import("../io/device_io.zig").DeviceIO;
    const EventLoop = @import("../event_loop.zig").EventLoop;
    const Interpreter = @import("../core/interpreter.zig").Interpreter;

    const allocator = testing.allocator;
    const minimal_toml =
        \\[device]
        \\name = "WedgeT"
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

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var sup = try Supervisor.initForTest(allocator);

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
        .interp = Interpreter.init(&parsed.value),
        .mapper = null,
        .owner = .none,
        .primary_output = null,
        .imu_output = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = &parsed.value,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };

    try sup.attachWithInstance("wedge0", "usb-1-1", inst, null);

    const resp_fds = blk: {
        var fds: [2]posix.fd_t = undefined;
        if (std.c.socketpair(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0, &fds) != 0) {
            return posix.unexpectedErrno(posix.errno(0));
        }
        break :blk fds;
    };
    defer posix.close(resp_fds[0]);
    defer posix.close(resp_fds[1]);
    sup.ctrl_sock = .{
        .listen_fd = -1,
        .client_fds = .{ -1, -1, -1, -1 },
        .client_count = 0,
        .path = "",
        .allocator = allocator,
    };

    // Pin a fake "now" so we can prove the write_in_flight_ms math.
    const fake_now: u64 = 10 * std.time.ns_per_s;
    sup.test_now_override_ns = fake_now;
    // Pre-arm: write started 500ms ago.
    @atomicStore(u64, &inst.wedge.write_in_flight_since_ns, fake_now - 500 * std.time.ns_per_ms, .release);
    @atomicStore(u64, &inst.wedge.last_inbound_ns, fake_now - 1500 * std.time.ns_per_ms, .release);
    @atomicStore(u64, &inst.wedge.last_outbound_ns, fake_now - 250 * std.time.ns_per_ms, .release);

    sup.handleStatus(resp_fds[0]);
    var resp_buf: [4096]u8 = undefined;
    const n = try posix.read(resp_fds[1], &resp_buf);
    const resp = resp_buf[0..n];

    try testing.expect(std.mem.indexOf(u8, resp, "last_inbound_ms_ago=") != null);
    try testing.expect(std.mem.indexOf(u8, resp, "last_outbound_ms_ago=") != null);
    try testing.expect(std.mem.indexOf(u8, resp, "write_in_flight_ms=") != null);
    // Exact value proof: 500ms in-flight, 1500ms inbound, 250ms outbound.
    try testing.expect(std.mem.indexOf(u8, resp, "write_in_flight_ms=500") != null);
    try testing.expect(std.mem.indexOf(u8, resp, "last_inbound_ms_ago=1500") != null);
    try testing.expect(std.mem.indexOf(u8, resp, "last_outbound_ms_ago=250") != null);

    defer {
        sup.stopAll();
        sup.ctrl_sock = null;
        sup.deinit();
    }
}

// Sanity: WedgeAtomics defaults are zero (so STATUS reports 0 ms_ago for fresh devices).
test "wedge: default values are all zero" {
    const w = WedgeAtomics{};
    try testing.expectEqual(@as(u64, 0), w.loadInbound());
    try testing.expectEqual(@as(u64, 0), w.loadOutbound());
    try testing.expectEqual(@as(u64, 0), w.loadInFlight());
}

// Test E (BLOCKING fix follow-up): spawnInstance is the single wedge-wiring
// chokepoint. Every production attach path (run() bootstrap, doReload, hotplug
// retry, attachWithInstance) routes through spawnInstance, so wiring there
// must wire the wedge pointer on a hidraw-backed DeviceIO without any
// per-call-site attachWedges() invocation.
//
// Falsifiability: deleting `instance.attachWedges()` from spawnInstance makes
// this test fail with `hidraw.wedge == null`. The reviewer's BLOCKING
// observation (run() and doReload bypasses) is structurally prevented as long
// as this test guards the chokepoint.
test "wedge: spawnInstance wires hidraw wedge pointer via single chokepoint" {
    const Supervisor = @import("../supervisor.zig").Supervisor;
    const device_mod = @import("../config/device.zig");
    const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
    const DeviceIO = @import("../io/device_io.zig").DeviceIO;
    const EventLoop = @import("../event_loop.zig").EventLoop;
    const Interpreter = @import("../core/interpreter.zig").Interpreter;

    const allocator = testing.allocator;
    const minimal_toml =
        \\[device]
        \\name = "WedgeChokepoint"
        \\vid = 1
        \\pid = 3
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

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    // Pipe acts as a tame hidraw fd: the polling thread sees no data and
    // idles until sup.stopAll() signals shutdown. HidrawDevice.close()
    // destroys the heap allocation, so allocate via the testing allocator.
    const fds = try posix.pipe2(.{});
    defer posix.close(fds[1]);

    const hidraw = try allocator.create(HidrawDevice);
    hidraw.* = .{
        .fd = fds[0],
        .evdev_fds = .{},
        .allocator = allocator,
        .wedge = null,
    };

    var sup = try Supervisor.initForTest(allocator);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = hidraw.deviceIO();
    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    const inst = try allocator.create(DeviceInstance);
    inst.* = .{
        .allocator = allocator,
        .devices = devices,
        .loop = loop,
        .interp = Interpreter.init(&parsed.value),
        .mapper = null,
        .owner = .none,
        .primary_output = null,
        .imu_output = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = &parsed.value,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };

    // Pre-condition: HidrawDevice wedge is unwired before attach.
    try testing.expect(hidraw.wedge == null);

    // Drive the same path production uses; spawnInstance must auto-wire.
    try sup.attachWithInstance("wedge-chokepoint0", "usb-1-3", inst, null);

    // Post-condition: wedge pointer is wired to the instance's own atomics.
    try testing.expect(hidraw.wedge != null);
    try testing.expectEqual(@as(*WedgeAtomics, &inst.wedge), hidraw.wedge.?);
}
