// Phase 3 end-to-end integration tests (T6: L0/L1).
// Covers T1 (capture analyse), T2 (debug render), T4 (uevent parse), T5 (attach/detach lifecycle).

const std = @import("std");
const testing = std.testing;

const analyse_mod = @import("analyse");
const toml_gen_mod = @import("toml_gen");
const render_mod = @import("../debug/render.zig");
const netlink_mod = @import("../io/netlink.zig");
const state_mod = @import("../core/state.zig");
const device_mod = @import("../config/device.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const Supervisor = @import("../supervisor.zig").Supervisor;

const Frame = analyse_mod.Frame;
const AnalysisResult = analyse_mod.AnalysisResult;
const DeviceInfo = toml_gen_mod.DeviceInfo;
const GamepadState = state_mod.GamepadState;
const ButtonId = state_mod.ButtonId;

// --- T1: capture analyse ---

test "T1: 32-byte frames — magic prefix detected" {
    const allocator = testing.allocator;

    // 100 frames; bytes 0-2 always 0x5a 0xa5 0xef; rest vary
    var datas: [100][32]u8 = undefined;
    var frames: [100]Frame = undefined;
    var prng = std.rand.DefaultPrng.init(42);
    const rng = prng.random();
    for (&datas, 0..) |*d, i| {
        rng.bytes(d);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    try testing.expectEqual(@as(u16, 32), result.report_size);

    var found_magic: [3]bool = .{ false, false, false };
    for (result.magic) |m| {
        if (m.offset == 0 and m.value == 0x5a) found_magic[0] = true;
        if (m.offset == 1 and m.value == 0xa5) found_magic[1] = true;
        if (m.offset == 2 and m.value == 0xef) found_magic[2] = true;
    }
    try testing.expect(found_magic[0]);
    try testing.expect(found_magic[1]);
    try testing.expect(found_magic[2]);
}

test "T1: i16le axis at offset 3-4, range -32468..32102" {
    const allocator = testing.allocator;

    const axis_vals = [_]i16{ -32468, 0, 16000, 32102, -10000 };
    var datas: [5][32]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        const u: u16 = @bitCast(axis_vals[i]);
        d[3] = @intCast(u & 0xff);
        d[4] = @intCast(u >> 8);
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 3 and a.axis_type == .i16le) {
            found = true;
            try testing.expect(a.min_val <= -10000);
            try testing.expect(a.max_val >= 16000);
        }
    }
    try testing.expect(found);
}

test "T1: u8 axis at offset 8, range 0..255" {
    const allocator = testing.allocator;

    const u8_vals = [_]u8{ 0, 64, 128, 200, 255 };
    var datas: [5][32]u8 = undefined;
    var frames: [5]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        d[8] = u8_vals[i];
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.axes) |a| {
        if (a.offset == 8 and a.axis_type == .u8_axis) {
            found = true;
            try testing.expectEqual(@as(i32, 0), a.min_val);
            try testing.expectEqual(@as(i32, 255), a.max_val);
        }
    }
    try testing.expect(found);
}

test "T1: button detection — bit 3 of byte 11, 6 toggles, high confidence" {
    const allocator = testing.allocator;

    var datas: [7][32]u8 = undefined;
    var frames: [7]Frame = undefined;
    for (&datas, 0..) |*d, i| {
        @memset(d, 0);
        d[0] = 0x5a;
        d[1] = 0xa5;
        d[2] = 0xef;
        if (i % 2 == 1) d[11] = 0x08;
        frames[i] = .{ .timestamp_us = @as(u64, i) * 1000, .data = d };
    }

    const result = try analyse_mod.analyse(&frames, allocator);
    defer result.deinit(allocator);

    var found = false;
    for (result.buttons) |b| {
        if (b.byte_offset == 11 and b.bit == 3 and b.high_confidence) {
            found = true;
        }
    }
    try testing.expect(found);
}

// --- T2: TOML skeleton generation ---

test "T2: emitToml — contains [device], [[report]], [report.fields]" {
    const allocator = testing.allocator;

    // Build a minimal AnalysisResult
    var magic = [_]analyse_mod.MagicByte{.{ .offset = 0, .value = 0x5a }};
    var buttons = [_]analyse_mod.ButtonCandidate{
        .{ .byte_offset = 11, .bit = 3, .toggle_count = 6, .high_confidence = true },
        .{ .byte_offset = 11, .bit = 5, .toggle_count = 6, .high_confidence = true },
    };
    var axes = [_]analyse_mod.AxisCandidate{
        .{ .offset = 3, .axis_type = .i16le, .min_val = -32468, .max_val = 32102 },
        .{ .offset = 8, .axis_type = .u8_axis, .min_val = 0, .max_val = 255 },
    };
    const result = AnalysisResult{
        .report_size = 32,
        .magic = &magic,
        .buttons = &buttons,
        .axes = &axes,
    };

    const info = DeviceInfo{ .name = "Test Device", .vid = 0x37d7, .pid = 0x2401, .interface_id = 0 };

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try toml_gen_mod.emitToml(result, info, allocator, buf.writer());

    const out = buf.items;
    try testing.expect(std.mem.indexOf(u8, out, "[device]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[[report]]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.fields]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.button_group]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "i16le") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"u8\"") != null);
}

// --- T3: debug render ---

test "T3: renderFrame — ANSI sequences present" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const gs = GamepadState{};
    try render_mod.renderFrame(fbs.writer(), &gs, &[_]u8{}, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[") != null);
}

test "T3: renderFrame — correct axis values rendered" {
    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var gs = GamepadState{};
    gs.ax = -1234;
    gs.ry = 5678;
    gs.gyro_x = 2345;
    try render_mod.renderFrame(fbs.writer(), &gs, &[_]u8{}, false);
    const out = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, out, "-1234") != null);
    try testing.expect(std.mem.indexOf(u8, out, "5678") != null);
    try testing.expect(std.mem.indexOf(u8, out, "2345") != null);
}

test "T3: renderFrame — pressed button differs from released" {
    var buf_on: [8192]u8 = undefined;
    var buf_off: [8192]u8 = undefined;
    var fbs_on = std.io.fixedBufferStream(&buf_on);
    var fbs_off = std.io.fixedBufferStream(&buf_off);

    var gs_on = GamepadState{};
    gs_on.buttons = @as(u32, 1) << @as(u5, @intCast(@intFromEnum(ButtonId.A)));
    var gs_off = GamepadState{};

    try render_mod.renderFrame(fbs_on.writer(), &gs_on, &[_]u8{}, false);
    try render_mod.renderFrame(fbs_off.writer(), &gs_off, &[_]u8{}, false);

    try testing.expect(!std.mem.eql(u8, fbs_on.getWritten(), fbs_off.getWritten()));
}

// --- T4: uevent parsing ---

test "T4: parseUevent — add hidraw3" {
    const msg = "add@/devices/pci0000:00/0000:00:14.0/usb1/1-1/1-1:1.0/0003:37D7:2401.0001/hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.add, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
    try testing.expectEqualStrings("hidraw", ev.subsystem.?);
}

test "T4: parseUevent — remove hidraw3" {
    const msg = "remove@/devices/.../hidraw/hidraw3\x00SUBSYSTEM=hidraw\x00DEVNAME=hidraw3\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.remove, ev.action);
    try testing.expectEqualStrings("hidraw3", ev.devname.?);
}

test "T4: parseUevent — non-hidraw subsystem" {
    const msg = "add@/devices/.../input/input7\x00SUBSYSTEM=input\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(netlink_mod.UeventAction.add, ev.action);
    try testing.expectEqualStrings("input", ev.subsystem.?);
    try testing.expectEqual(@as(?[]const u8, null), ev.devname);
}

test "T4: parseUevent — no DEVNAME key" {
    const msg = "add@/devices/.../hidraw/hidraw5\x00SUBSYSTEM=hidraw\x00";
    const ev = netlink_mod.parseUevent(msg);
    try testing.expectEqual(@as(?[]const u8, null), ev.devname);
}

test "T4: parseUevent — no SUBSYSTEM key" {
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
    var loop = try EventLoop.init();
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
    };
    return inst;
}

test "T5: attach — one instance created, thread running" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var sup = try Supervisor.init(allocator);
    defer sup.deinit();

    const inst = try makeInstance(allocator, &mock, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    sup.stopAll();
}

test "T5: attach duplicate devname — no-op, still one instance" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    var sup = try Supervisor.init(allocator);
    defer sup.deinit();

    const inst_a = try makeInstance(allocator, &mock_a, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_a);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    // Second attach with same devname — must be no-op.
    const inst_b = try makeInstance(allocator, &mock_b, &parsed.value);
    // inst_b is not attached; we must clean it up ourselves.
    defer {
        inst_b.loop.deinit();
        allocator.free(inst_b.devices);
        allocator.destroy(inst_b);
    }
    try sup.attachWithInstance("hidraw3", "usb-1-1b", inst_b);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.stopAll();
}

test "T5: detach — instance stopped and freed" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var sup = try Supervisor.init(allocator);
    defer sup.deinit();

    const inst = try makeInstance(allocator, &mock, &parsed.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.detach("hidraw3");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "T5: detach unknown devname — no panic" {
    const allocator = testing.allocator;

    var sup = try Supervisor.init(allocator);
    defer sup.deinit();

    sup.detach("hidraw99"); // must not panic
}

test "T5: attach-detach-attach — second instance created normally" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    var sup = try Supervisor.init(allocator);
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
