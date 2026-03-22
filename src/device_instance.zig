const std = @import("std");
const posix = std.posix;

const DeviceIO = @import("io/device_io.zig").DeviceIO;
const HidrawDevice = @import("io/hidraw.zig").HidrawDevice;
const UsbrawDevice = @import("io/usbraw.zig").UsbrawDevice;
const uinput = @import("io/uinput.zig");
const UinputDevice = uinput.UinputDevice;
const AuxDevice = uinput.AuxDevice;
const TouchpadDevice = uinput.TouchpadDevice;
const OutputDevice = uinput.OutputDevice;
const AuxOutputDevice = uinput.AuxOutputDevice;
const TouchpadOutputDevice = uinput.TouchpadOutputDevice;
const GenericUinputDevice = uinput.GenericUinputDevice;
const GenericOutputDevice = uinput.GenericOutputDevice;
const generic = @import("core/generic.zig");
const EventLoop = @import("event_loop.zig").EventLoop;
const Interpreter = @import("core/interpreter.zig").Interpreter;
const Mapper = @import("core/mapper.zig").Mapper;
const DeviceConfig = @import("config/device.zig").DeviceConfig;
const InterfaceConfig = @import("config/device.zig").InterfaceConfig;
const MappingConfig = @import("config/mapping.zig").MappingConfig;
const init_seq = @import("init.zig");
const GamepadState = @import("core/state.zig").GamepadState;
const FfEvent = uinput.FfEvent;

fn createDeviceIO(
    allocator: std.mem.Allocator,
    iface: InterfaceConfig,
    vid: u16,
    pid: u16,
) !DeviceIO {
    if (std.mem.eql(u8, iface.class, "hid")) {
        const path = try HidrawDevice.discover(allocator, vid, pid, @intCast(iface.id));
        defer allocator.free(path);
        var dev = try allocator.create(HidrawDevice);
        dev.* = HidrawDevice.init(allocator);
        try dev.open(path);
        dev.grabAssociatedEvdev(path) catch |err| {
            std.log.warn("grabAssociatedEvdev failed: {}", .{err});
        };
        return dev.deviceIO();
    } else if (std.mem.eql(u8, iface.class, "vendor")) {
        const ep_in: u8 = @intCast(iface.ep_in orelse return error.MissingEndpoint);
        const ep_out: u8 = @intCast(iface.ep_out orelse return error.MissingEndpoint);
        const dev = try UsbrawDevice.open(allocator, vid, pid, @intCast(iface.id), ep_in, ep_out);
        return dev.deviceIO();
    }
    return error.UnknownInterfaceClass;
}

pub fn openDeviceWithRetry(
    allocator: std.mem.Allocator,
    iface: InterfaceConfig,
    vid: u16,
    pid: u16,
) !DeviceIO {
    const delays = [_]u64{ 1, 2, 4 };
    var attempt: usize = 0;
    while (true) {
        return createDeviceIO(allocator, iface, vid, pid) catch |err| {
            if (attempt >= delays.len) {
                std.log.err("failed to open interface {d} after retries: {}", .{ iface.id, err });
                return err;
            }
            std.log.warn("open interface {d} failed ({}), retrying in {}s...", .{ iface.id, err, delays[attempt] });
            std.Thread.sleep(delays[attempt] * std.time.ns_per_s);
            attempt += 1;
            continue;
        };
    }
}

pub const DeviceInstance = struct {
    allocator: std.mem.Allocator,
    devices: []DeviceIO,
    loop: EventLoop,
    interp: Interpreter,
    mapper: ?Mapper,
    uinput_dev: ?UinputDevice,
    aux_dev: ?AuxDevice,
    touchpad_dev: ?TouchpadDevice,
    generic_state: ?generic.GenericDeviceState,
    generic_uinput: ?GenericUinputDevice,
    device_cfg: *const DeviceConfig,
    mapping_cfg: ?*const MappingConfig = null,
    pending_mapping: ?*MappingConfig,
    stopped: bool,
    poll_timeout_ms: ?u32 = null,

    /// Open all interfaces, run init handshake, create EventLoop/Interpreter/Output.
    pub fn init(allocator: std.mem.Allocator, cfg: *const DeviceConfig) !DeviceInstance {
        const vid: u16 = @intCast(cfg.device.vid);
        const pid: u16 = @intCast(cfg.device.pid);

        const devices = try allocator.alloc(DeviceIO, cfg.device.interface.len);
        errdefer allocator.free(devices);

        var opened: usize = 0;
        errdefer for (devices[0..opened]) |dev| dev.close();

        for (cfg.device.interface, 0..) |iface, i| {
            devices[i] = try openDeviceWithRetry(allocator, iface, vid, pid);
            opened += 1;
        }

        if (cfg.device.init) |init_cfg| {
            for (cfg.device.interface, devices) |iface, dev| {
                const match = if (init_cfg.interface) |init_iface|
                    iface.id == init_iface
                else
                    std.mem.eql(u8, iface.class, "vendor");
                if (!match) continue;
                init_seq.runInitSequence(allocator, dev, init_cfg) catch |err| {
                    std.log.debug("init on interface {d}: {}", .{ iface.id, err });
                };
            }
        }
        std.log.info("init: handshake done", .{});

        var loop = try EventLoop.initManaged();
        errdefer loop.deinit();
        std.log.info("init: event loop created", .{});

        for (devices) |dev| try loop.addDevice(dev);

        const interp = Interpreter.init(cfg);

        const is_generic = if (cfg.device.mode) |m| std.mem.eql(u8, m, "generic") else false;

        var uinput_dev: ?UinputDevice = null;
        var aux_dev: ?AuxDevice = null;
        var touchpad_dev: ?TouchpadDevice = null;
        var generic_state: ?generic.GenericDeviceState = null;
        var generic_uinput: ?GenericUinputDevice = null;

        if (is_generic) {
            generic_state = try generic.compileGenericState(cfg);
            if (cfg.output) |*out_cfg| {
                generic_uinput = try GenericUinputDevice.create(out_cfg, &generic_state.?);
            }
        } else if (cfg.output) |*out_cfg| {
            uinput_dev = try UinputDevice.create(out_cfg);
            std.log.info("init: uinput created", .{});
            if (out_cfg.force_feedback != null) {
                errdefer uinput_dev.?.close();
                try loop.addUinputFf(uinput_dev.?.pollFfFd());
            }
            if (out_cfg.aux != null) {
                aux_dev = try AuxDevice.create(&.{});
            }
            if (out_cfg.touchpad) |*tp_cfg| {
                touchpad_dev = try TouchpadDevice.create(tp_cfg);
            }
        }
        std.log.info("init: output devices done, returning instance", .{});

        return .{
            .allocator = allocator,
            .devices = devices,
            .loop = loop,
            .interp = interp,
            .mapper = null,
            .uinput_dev = uinput_dev,
            .aux_dev = aux_dev,
            .touchpad_dev = touchpad_dev,
            .generic_state = generic_state,
            .generic_uinput = generic_uinput,
            .device_cfg = cfg,
            .pending_mapping = null,
            .stopped = false,
        };
    }

    pub fn deinit(self: *DeviceInstance) void {
        if (self.mapper) |*m| m.deinit();
        if (self.uinput_dev) |*u| u.close();
        if (self.aux_dev) |*a| a.close();
        if (self.touchpad_dev) |*tp| tp.close();
        if (self.generic_uinput) |*gu| gu.close();
        for (self.devices) |dev| dev.close();
        self.allocator.free(self.devices);
        self.loop.deinit();
    }

    /// Thread entry point. Runs the event loop; applies pending mapping swaps
    /// between iterations (woken via stop_pipe by updateMapping).
    pub fn run(self: *DeviceInstance) !void {
        while (!@atomicLoad(bool, &self.stopped, .acquire)) {
            // Apply pending mapping before processing any fds
            if (@atomicLoad(?*MappingConfig, &self.pending_mapping, .acquire)) |new| {
                if (self.mapper) |*m| m.config = new;
                @atomicStore(?*MappingConfig, &self.pending_mapping, null, .release);
            }

            // Drain any stop_pipe wake signal left from a prior updateMapping call,
            // then re-check stopped — stop() may have written this byte.
            var dummy: [1]u8 = undefined;
            _ = posix.read(self.loop.stop_r, &dummy) catch {};
            if (@atomicLoad(bool, &self.stopped, .acquire)) break;

            const output = if (self.uinput_dev) |*u| u.outputDevice() else nullOutput();
            const aux_output: ?AuxOutputDevice = if (self.aux_dev) |*a| a.auxOutputDevice() else null;
            const touchpad_output: ?TouchpadOutputDevice = if (self.touchpad_dev) |*tp| tp.touchpadOutputDevice() else null;
            const generic_output: ?GenericOutputDevice = if (self.generic_uinput) |*gu| gu.genericOutputDevice() else null;
            const mapper_ptr: ?*Mapper = if (self.mapper) |*m| m else null;

            const mcfg: ?*const MappingConfig = if (mapper_ptr) |m| m.config else self.mapping_cfg;

            try self.loop.run(.{
                .devices = self.devices,
                .interpreter = &self.interp,
                .output = output,
                .mapper = mapper_ptr,
                .aux_output = aux_output,
                .touchpad_output = touchpad_output,
                .allocator = self.allocator,
                .device_config = self.device_cfg,
                .mapping_config = mcfg,
                .poll_timeout_ms = self.poll_timeout_ms,
                .generic_state = if (self.generic_state) |*gs| gs else null,
                .generic_output = generic_output,
            });
            if (self.loop.disconnected) break;
        }
    }

    /// Signal the event loop to stop. run() returns after the current ppoll.
    pub fn stop(self: *DeviceInstance) void {
        @atomicStore(bool, &self.stopped, true, .release);
        self.loop.stop();
    }

    /// Atomically queue a mapping swap; applied on the next event loop iteration.
    pub fn updateMapping(self: *DeviceInstance, new: *MappingConfig) void {
        @atomicStore(?*MappingConfig, &self.pending_mapping, new, .release);
        self.loop.stop();
    }
};

const null_output_vtable = OutputDevice.VTable{
    .emit = struct {
        fn f(_: *anyopaque, _: GamepadState) uinput.EmitError!void {}
    }.f,
    .poll_ff = struct {
        fn f(_: *anyopaque) uinput.PollFfError!?FfEvent {
            return null;
        }
    }.f,
    .close = struct {
        fn f(_: *anyopaque) void {}
    }.f,
};

fn nullOutput() OutputDevice {
    return .{ .ptr = undefined, .vtable = &null_output_vtable };
}

// --- tests ---

const testing = std.testing;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const mapping = @import("config/mapping.zig");
const device_mod = @import("config/device.zig");

/// Minimal DeviceInstance for L0 tests: pre-wired mock device, null output.
fn testInstance(
    allocator: std.mem.Allocator,
    mock: *MockDeviceIO,
    cfg: *const device_mod.DeviceConfig,
) !DeviceInstance {
    const devices = try allocator.alloc(DeviceIO, 1);
    errdefer allocator.free(devices);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    return DeviceInstance{
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
}

const minimal_toml =
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

test "DeviceInstance: stop() causes run() to exit" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var inst = try testInstance(allocator, &mock, &parsed.value);
    defer {
        inst.loop.deinit();
        allocator.free(inst.devices);
    }

    const T = struct {
        fn runFn(i: *DeviceInstance) !void {
            try i.run();
        }
    };
    const thread = try std.Thread.spawn(.{}, T.runFn, .{&inst});
    std.Thread.sleep(5 * std.time.ns_per_ms);
    inst.stop();
    thread.join();

    try testing.expect(inst.stopped);
}

test "DeviceInstance: updateMapping sets pending_mapping and wakes run()" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    const mapping_parsed = try mapping.parseString(allocator, "");
    defer mapping_parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    var inst = DeviceInstance{
        .allocator = allocator,
        .devices = devices,
        .loop = loop,
        .interp = Interpreter.init(&parsed.value),
        .mapper = try Mapper.init(&mapping_parsed.value, loop.timer_fd, allocator),
        .uinput_dev = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = &parsed.value,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    defer {
        inst.mapper.?.deinit();
        inst.loop.deinit();
        allocator.free(inst.devices);
    }

    var new_cfg = mapping_parsed.value;

    const T = struct {
        fn runFn(i: *DeviceInstance) !void {
            try i.run();
        }
    };
    const thread = try std.Thread.spawn(.{}, T.runFn, .{&inst});

    std.Thread.sleep(5 * std.time.ns_per_ms);
    inst.updateMapping(&new_cfg);
    std.Thread.sleep(5 * std.time.ns_per_ms);
    inst.stop();
    thread.join();

    // pending_mapping consumed (set to null) after being applied
    try testing.expectEqual(@as(?*mapping.MappingConfig, null), inst.pending_mapping);
}
