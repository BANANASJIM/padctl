// Supervisor E2E tests: uevent parsing, attach/detach lifecycle.
// Split from phase3_e2e_test.zig (T4-T5).

const std = @import("std");
const testing = std.testing;

const netlink_mod = @import("../io/netlink.zig");
const device_mod = @import("../config/device.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const Supervisor = @import("../supervisor.zig").Supervisor;

// --- T4: uevent parsing ---

test "supervisor: parseUevent — add hidraw3" {
    const msg = "add@/devices/pci0000:00/0000:00:14.0/usb1/1-1/1-1:1.0/0003:37D7:2401.0001/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.add, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
    try testing.expectEqualStrings("hidraw", ev.subsystem.?);
}

test "supervisor: parseUevent — remove hidraw3" {
    const msg = "remove@/devices/.../hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.remove, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
}

test "supervisor: parseUevent — non-hidraw subsystem" {
    const msg = "add@/devices/.../input/input7\x00SUBSYSTEM=input\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.add, ev.action);
    try testing.expectEqualStrings("input", ev.subsystem.?);
    try testing.expectEqual(@as(?[]const u8, null), ev.devname);
}

test "supervisor: parseUevent — no DEVNAME key" {
    const msg = "add@/devices/.../hidraw/hidraw5\x00SUBSYSTEM=hidraw\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(@as(?[]const u8, null), ev.devname);
}

test "supervisor: parseUevent — no SUBSYSTEM key" {
    const msg = "add@/devices/.../hidraw/hidraw5\x00DEVNAME=hidraw5\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(@as(?[]const u8, null), ev.subsystem);
    try testing.expectEqualStrings("hidraw5", ev.devname.?);
}

// --- T5: Supervisor attach/detach lifecycle ---

const minimal_device_toml =
    \\[device]
    \\name = "T"
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
        .device_cfg = cfg,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    return inst;
}

test "supervisor: attach — one instance created, thread running" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    const inst = try makeInstance(allocator, &mock, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "supervisor: attach duplicate devname — no-op, still one instance" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    const inst_a = try makeInstance(allocator, &mock_a, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_a);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    // Second attach with same devname — must be no-op.
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    // inst_b is not attached; we must clean it up ourselves.
    defer {
        inst_b.deinit();
        allocator.destroy(inst_b);
    }
    try sup.attachWithInstance("hidraw3", "usb-1-1b", inst_b);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.stopAll();
}

test "supervisor: detach — instance stopped and freed" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    const inst = try makeInstance(allocator, &mock, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.detach("hidraw3");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "supervisor: detach unknown devname — no panic" {
    const allocator = testing.allocator;

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    sup.detach("hidraw99"); // must not panic
}

test "supervisor: attach-detach-attach — second instance created normally" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    const inst_a = try makeInstance(allocator, &mock_a, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_a);
    sup.detach("hidraw3");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);

    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_b);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.stopAll();
}
