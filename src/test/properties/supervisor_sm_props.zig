// supervisor_sm_props.zig — 1-switch (2-step) state machine coverage for Supervisor.
//
// Tests all valid and invalid transition pairs using attachWithInstance / detach /
// reload and MockDeviceIO.  No real hardware or filesystem access.

const std = @import("std");
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
    try sup.attachWithInstance(devname, phys, inst);
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
    try sup.attachWithInstance("hidraw0", "key0b", inst_b);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "SM: attach → detach → count == 0" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try initSup(allocator);
    defer sup.deinit();

    try attach(&sup, allocator, &mock, &parsed.value, "hidraw0", "key0");
    sup.detach("hidraw0");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "SM: attach → detach → attach — second instance accepted" {
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
    try attach(&sup, allocator, &mock_b, &parsed.value, "hidraw0", "key0");
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

test "SM: attach two devices → detach one → count == 1" {
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
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}
