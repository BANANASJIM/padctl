// Regression for issue #236 (Steam stops registering inputs after game close on
// Bazzite + Vader 5 Pro). Asserts that a fresh hotplug attach with same
// VID:PID but a different phys_key forces a teardown of the stale suspended
// entry instead of spawning a parallel uinput device that ends up holding the
// uniq Steam already latched onto.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const Supervisor = @import("../supervisor.zig").Supervisor;

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
    \\size = 3
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i16le" }
;

fn makeInstance(
    allocator: std.mem.Allocator,
    mock: *MockDeviceIO,
    cfg: *const device_mod.DeviceConfig,
) !*DeviceInstance {
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
        .owner = .none,
        .primary_output = null,
        .imu_output = null,
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

test "issue-236: fresh attach with same VID:PID but new phys_key forfeits stale suspended grace" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_old = try MockDeviceIO.init(allocator, &.{});
    defer mock_old.deinit();
    var mock_new = try MockDeviceIO.init(allocator, &.{});
    defer mock_new.deinit();

    var sup = try Supervisor.initForTest(allocator);
    defer {
        sup.stopAll();
        sup.deinit();
    }
    sup.suspend_grace_sec = 15;

    const old_inst = try makeInstance(allocator, &mock_old, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", old_inst, null);

    sup.detach("hidraw3");
    try testing.expect(sup.managed.items[0].suspended);
    try testing.expect(sup.managed.items[0].grace_deadline_ns != null);

    const new_inst = try makeInstance(allocator, &mock_new, &parsed.value);
    var new_attached = false;
    defer if (!new_attached) {
        new_inst.deinit();
        allocator.destroy(new_inst);
    };

    new_attached = try sup.attachWithInstanceResult("hidraw5", "usb-9-9", new_inst, null);

    try testing.expect(new_attached);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expectEqual(new_inst, sup.managed.items[0].instance);
    try testing.expect(!sup.managed.items[0].suspended);
    try testing.expectEqualStrings("usb-9-9", sup.managed.items[0].phys_key);
    try testing.expectEqualStrings("hidraw5", sup.managed.items[0].devname.?);
    try testing.expect(sup.devname_map.contains("hidraw5"));
}
