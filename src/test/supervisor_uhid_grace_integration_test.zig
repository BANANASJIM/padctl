const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const DeviceInstance = src.device_instance.DeviceInstance;
const Supervisor = src.supervisor.Supervisor;
const UhidSimulator = src.testing_support.uhid_simulator.UhidSimulator;

const TEST_VID: u16 = 0xFADE;
const TEST_PID: u16 = 0xCAFE;
const TEST_UNIQ = "padctl/grace-integration-0";

// Minimal HID report descriptor — 4-byte report, two sticks X/Y/RX/RY packed as u8.
const test_rd = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x05, // Usage (Game Pad)
    0xA1, 0x01, // Collection (Application)
    0x09, 0x30,
    0x09, 0x31,
    0x09, 0x33,
    0x09, 0x34,
    0x15, 0x00,
    0x26, 0xFF,
    0x00, 0x75,
    0x08, 0x95,
    0x04, 0x81,
    0x02, 0xC0,
};

const test_toml =
    \\[device]
    \\name = "UHID Grace Integration"
    \\vid = 0xFADE
    \\pid = 0xCAFE
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[report.fields]
    \\left_x = { offset = 0, type = "u8" }
    \\left_y = { offset = 1, type = "u8" }
    \\right_x = { offset = 2, type = "u8" }
    \\right_y = { offset = 3, type = "u8" }
;

test "issue-131-A integration: UHID disconnect triggers grace teardown on real kernel" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const allocator = testing.allocator;

    var sim = UhidSimulator.create(.{
        .vid = TEST_VID,
        .pid = TEST_PID,
        .uniq = TEST_UNIQ,
        .descriptor = &test_rd,
    }) catch |err| switch (err) {
        error.SkipZigTest, error.HidrawNotFound, error.KernelBusy => return error.SkipZigTest,
        else => |e| return e,
    };
    var sim_alive = true;
    defer if (sim_alive) sim.destroy();

    const hidraw_path = sim.hidrawPath() orelse return error.SkipZigTest;

    const parsed = try device_mod.parseString(allocator, test_toml);
    defer parsed.deinit();

    const instance_ptr = try allocator.create(DeviceInstance);
    var instance_owned = true;
    errdefer if (instance_owned) {
        instance_ptr.deinit();
        allocator.destroy(instance_ptr);
    };
    var local_counter: u16 = 1;
    instance_ptr.* = try DeviceInstance.init(allocator, &parsed.value, null, null, &local_counter);

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    sup.suspend_grace_sec = 5;
    const t0: u64 = 1_000_000_000;
    sup.test_now_override_ns = t0;

    try sup.attachWithInstance(hidraw_path, TEST_UNIQ, instance_ptr, null);
    instance_owned = false;

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(!sup.managed.items[0].suspended);
    try testing.expect(sup.managed.items[0].grace_deadline_ns == null);

    sim.destroy();
    sim_alive = false;

    sup.detach(hidraw_path);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].suspended);
    try testing.expect(sup.managed.items[0].grace_deadline_ns != null);

    sup.test_now_override_ns = t0 + 6 * std.time.ns_per_s;
    sup.gcExpiredGrace(sup.nowNs());

    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "issue-131-A integration: rebind within grace keeps uinput alive" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const allocator = testing.allocator;

    var sim = UhidSimulator.create(.{
        .vid = TEST_VID,
        .pid = TEST_PID,
        .uniq = TEST_UNIQ,
        .descriptor = &test_rd,
    }) catch |err| switch (err) {
        error.SkipZigTest, error.HidrawNotFound, error.KernelBusy => return error.SkipZigTest,
        else => |e| return e,
    };
    defer sim.destroy();

    const hidraw_path = sim.hidrawPath() orelse return error.SkipZigTest;

    const parsed = try device_mod.parseString(allocator, test_toml);
    defer parsed.deinit();

    const instance_ptr = try allocator.create(DeviceInstance);
    var instance_owned = true;
    errdefer if (instance_owned) {
        instance_ptr.deinit();
        allocator.destroy(instance_ptr);
    };
    var local_counter: u16 = 1;
    instance_ptr.* = try DeviceInstance.init(allocator, &parsed.value, null, null, &local_counter);

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    sup.suspend_grace_sec = 5;
    sup.test_now_override_ns = 1_000_000_000;

    try sup.attachWithInstance(hidraw_path, TEST_UNIQ, instance_ptr, null);
    instance_owned = false;

    sup.detach(hidraw_path);
    try testing.expect(sup.managed.items[0].grace_deadline_ns != null);

    sup.clearGraceDeadline(&sup.managed.items[0]);
    try testing.expect(sup.managed.items[0].grace_deadline_ns == null);

    sup.test_now_override_ns = 1_000_000_000 + 6 * std.time.ns_per_s;
    sup.gcExpiredGrace(sup.nowNs());

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
}
