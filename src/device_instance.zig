const std = @import("std");
const builtin = @import("builtin");
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
const uhid_mod = @import("io/uhid.zig");
const uhid_descriptor = @import("io/uhid_descriptor.zig");
const uniq_mod = @import("io/uniq.zig");
const device_cfg = @import("config/device.zig");
const generic = @import("core/generic.zig");
const EventLoop = @import("event_loop.zig").EventLoop;
const Interpreter = @import("core/interpreter.zig").Interpreter;
const Mapper = @import("core/mapper.zig").Mapper;
const DeviceConfig = @import("config/device.zig").DeviceConfig;
const InterfaceConfig = @import("config/device.zig").InterfaceConfig;
const mapping_mod = @import("config/mapping.zig");
const MappingConfig = mapping_mod.MappingConfig;
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

/// Primary output ownership. T3 introduces the union so T4 can route the
/// primary card to either uinput or UHID without widening call sites.
pub const Owner = union(enum) {
    none,
    uinput: *UinputDevice,
    uhid: *uhid_mod.UhidDevice,
};

/// Test-only seam (T5). When either fd override is non-null, the UHID
/// backend path binds the corresponding `UhidDevice` to the caller-supplied
/// fd via `initWithFd` AND manually emits a `UHID_CREATE2` event on the fd
/// (matching what `init` would have sent to `/dev/uhid`). Production call
/// sites leave both fields null so the normal `openUhid` path runs.
///
/// `test_devices_override` (CodeRabbit PR #159 #6) skips the interface-
/// opening loop entirely and installs the caller-provided `DeviceIO` slice.
/// Needed so a Layer 1 test can drive `DeviceInstance.init` end-to-end
/// without a real `/dev/hidraw*` node — otherwise `HidrawDevice.discover`
/// would retry for ~7s and fail in CI before the routing switch is reached.
/// The slice is consumed (stored in `DeviceInstance.devices`) and freed by
/// `deinit`; caller must not free it.
pub const InitOptions = struct {
    test_primary_uhid_fd: ?posix.fd_t = null,
    test_imu_uhid_fd: ?posix.fd_t = null,
    test_devices_override: ?[]DeviceIO = null,
};

/// Build a `UhidDevice` — either against a caller-supplied test fd (pipe
/// write-end in Layer 1 fixtures) or against a freshly opened `/dev/uhid`.
/// Behaviour is byte-identical on the wire in both branches: the same
/// `UHID_CREATE2` payload is written.
fn openUhidDevice(
    allocator: std.mem.Allocator,
    cfg: uhid_mod.Config,
    test_fd: ?posix.fd_t,
) !*uhid_mod.UhidDevice {
    if (test_fd) |fd| {
        const dev = try uhid_mod.UhidDevice.initWithFd(allocator, fd, cfg);
        errdefer {
            dev.close();
            allocator.destroy(dev);
        }
        try uhid_mod.UhidDevice.sendCreate(fd, cfg);
        return dev;
    }
    return uhid_mod.UhidDevice.init(allocator, cfg);
}

/// Layer 1 test seam for `src/test/supervisor_uhid_routing_test.zig`.
/// Wraps `openUhidDevice` so the Layer 1 test can exercise the same code
/// path used by the UHID routing branch without needing a full
/// `DeviceInstance.init` call (which would pull in hidraw interface
/// discovery that requires a real `/dev/hidraw*` node).
pub fn openUhidDeviceForTest(
    allocator: std.mem.Allocator,
    cfg: uhid_mod.Config,
    test_fd: posix.fd_t,
) !*uhid_mod.UhidDevice {
    return openUhidDevice(allocator, cfg, test_fd);
}

pub const DeviceInstance = struct {
    allocator: std.mem.Allocator,
    devices: []DeviceIO,
    loop: EventLoop,
    interp: Interpreter,
    mapper: ?Mapper,
    owner: Owner = .none,
    primary_output: ?OutputDevice = null,
    imu_output: ?OutputDevice = null,
    /// IMU UHID companion card (T4). Separate from `owner` — the union models
    /// the single primary output; a plain optional pair keeps the companion
    /// card's lifetime explicit without muddying the primary invariant.
    imu_dev: ?*uhid_mod.UhidDevice = null,
    /// Allocator-owned backing storage for `imu_dev.name`. `UhidDevice.name`
    /// is owned-by-caller (see `src/io/uhid.zig`); this field outlives the
    /// kernel device and is freed in `deinit` strictly AFTER `imu_dev.close()`.
    imu_name_owned: ?[]const u8 = null,
    aux_dev: ?AuxDevice,
    touchpad_dev: ?TouchpadDevice,
    generic_state: ?generic.GenericDeviceState,
    generic_uinput: ?GenericUinputDevice,
    device_cfg: *const DeviceConfig,
    mapping_cfg: ?*const MappingConfig = null,
    pending_mapping: ?*MappingConfig,
    stopped: bool,
    poll_timeout_ms: ?u32 = null,
    // Test-only observability hook for issue #142 regression: counts
    // rebuildAuxIfChanged invocations so tests can verify the switch path
    // actually rebuilds aux caps without relying on /dev/uinput.
    rebuild_aux_calls: if (builtin.is_test) usize else void = if (builtin.is_test) 0 else {},

    /// Open all interfaces, run init handshake, create EventLoop/Interpreter/Output.
    ///
    /// - `init_mapping`: optional MappingConfig used to auto-derive aux
    ///   capabilities when [output.aux] is absent from the device config.
    /// - `phys_key`: sysfs phys path of the backing hidraw node (owned by the
    ///   caller). Feeds the UHID `uniq` hash when `[output.imu].backend = "uhid"`;
    ///   when null the fallback daemon counter is used.
    /// - `uniq_counter`: pointer to the daemon-wide u16 counter owned by the
    ///   Supervisor. Read snapshot + incremented ONLY when phys_key is null.
    pub fn init(
        allocator: std.mem.Allocator,
        cfg: *const DeviceConfig,
        init_mapping: ?*const MappingConfig,
        phys_key: ?[]const u8,
        uniq_counter: *u16,
        opts: InitOptions,
    ) !DeviceInstance {
        const vid: u16 = @intCast(cfg.device.vid);
        const pid: u16 = @intCast(cfg.device.pid);

        const override_active = opts.test_devices_override != null;
        const devices = opts.test_devices_override orelse try allocator.alloc(DeviceIO, cfg.device.interface.len);
        errdefer if (!override_active) allocator.free(devices);

        var opened: usize = 0;
        errdefer for (devices[0..opened]) |dev| dev.close();

        if (!override_active) {
            for (cfg.device.interface, 0..) |iface, i| {
                devices[i] = try openDeviceWithRetry(allocator, iface, vid, pid);
                opened += 1;
            }
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
        var loop = try EventLoop.initManaged();
        errdefer loop.deinit();

        for (devices) |dev| try loop.addDevice(dev);

        const interp = Interpreter.init(cfg);

        const is_generic = if (cfg.device.mode) |m| std.mem.eql(u8, m, "generic") else false;

        var owner: Owner = .none;
        var primary_output: ?OutputDevice = null;
        var imu_output: ?OutputDevice = null;
        var imu_dev_ptr: ?*uhid_mod.UhidDevice = null;
        var imu_name_ptr: ?[]const u8 = null;
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
            const imu_cfg_opt: ?device_cfg.ImuConfig = if (out_cfg.imu) |imu| imu else null;
            const use_uhid = if (imu_cfg_opt) |imu_cfg|
                std.mem.eql(u8, imu_cfg.backend, "uhid")
            else
                false;

            if (use_uhid) {
                // ADR-015 Stage 1: primary + IMU cards share a byte-identical
                // uniq. Snapshot the counter once, bump only if the counter
                // branch was taken (phys_key == null).
                const counter_snapshot: u16 = uniq_counter.*;
                const uniq_z = try uniq_mod.buildUniq(allocator, cfg.device.name, phys_key, counter_snapshot);
                defer allocator.free(uniq_z);
                if (phys_key == null) uniq_counter.* += 1;

                const primary_descriptor = try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg.*);
                defer allocator.free(primary_descriptor);

                const primary_cfg = uhid_mod.Config{
                    .name = cfg.device.name,
                    .uniq = std.mem.sliceTo(uniq_z, 0),
                    .vid = @intCast(cfg.device.vid),
                    .pid = @intCast(cfg.device.pid),
                    .descriptor = primary_descriptor,
                    .output = out_cfg.*,
                };
                const primary_uhid = try openUhidDevice(allocator, primary_cfg, opts.test_primary_uhid_fd);
                errdefer {
                    primary_uhid.close();
                    allocator.destroy(primary_uhid);
                }

                if (out_cfg.force_feedback != null) {
                    std.log.warn("rumble not supported in uhid backend until Wave 6", .{});
                }

                owner = .{ .uhid = primary_uhid };
                primary_output = primary_uhid.outputDevice();

                if (imu_cfg_opt) |imu_cfg| {
                    const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg);
                    defer allocator.free(imu_desc);

                    const imu_name_alloc: []const u8 = if (imu_cfg.name) |n|
                        try allocator.dupe(u8, n)
                    else
                        try std.fmt.allocPrint(allocator, "{s} IMU", .{cfg.device.name});
                    errdefer allocator.free(imu_name_alloc);

                    const imu_cfg_uhid = uhid_mod.Config{
                        .name = imu_name_alloc,
                        .uniq = std.mem.sliceTo(uniq_z, 0),
                        .vid = @intCast(imu_cfg.vid orelse cfg.device.vid),
                        .pid = @intCast(imu_cfg.pid orelse cfg.device.pid),
                        .descriptor = imu_desc,
                        .output = null,
                        .imu = imu_cfg,
                    };
                    const imu_uhid = try openUhidDevice(allocator, imu_cfg_uhid, opts.test_imu_uhid_fd);
                    errdefer {
                        imu_uhid.close();
                        allocator.destroy(imu_uhid);
                    }
                    imu_dev_ptr = imu_uhid;
                    imu_name_ptr = imu_name_alloc;
                    imu_output = imu_uhid.outputDevice();
                }
            } else {
                const uinput_ptr = try UinputDevice.initBoxed(allocator, out_cfg);
                errdefer {
                    uinput_ptr.close();
                    allocator.destroy(uinput_ptr);
                }
                uinput_ptr.log_tag = cfg.device.name;
                owner = .{ .uinput = uinput_ptr };
                primary_output = uinput_ptr.outputDevice();
                if (out_cfg.force_feedback != null) {
                    try loop.addUinputFf(uinput_ptr.pollFfFd());
                }
            }
            if (out_cfg.aux != null or init_mapping != null) {
                const mcfg_opt = init_mapping;
                const caps: mapping_mod.DerivedAuxCaps = if (mcfg_opt) |m|
                    mapping_mod.deriveAuxFromMapping(m)
                else
                    .{};
                if (out_cfg.aux != null or caps.needsAux()) {
                    var buf: [mapping_mod.AUX_KEY_CODES_MAX]u16 = undefined;
                    const key_codes = mapping_mod.buildAuxKeyCodes(caps, &buf);
                    aux_dev = try AuxDevice.create(key_codes, caps.needs_rel);
                    var cap_buf: [64]u8 = undefined;
                    var cap_fbs = std.io.fixedBufferStream(&cap_buf);
                    const cap_w = cap_fbs.writer();
                    var sep = false;
                    if (caps.needs_keyboard or out_cfg.aux != null) {
                        cap_w.writeAll("keyboard") catch {};
                        sep = true;
                    }
                    if (caps.mouse_buttons != 0) {
                        if (sep) {
                            cap_w.writeAll(", ") catch {};
                        }
                        cap_w.writeAll("mouse") catch {};
                        sep = true;
                    }
                    if (caps.needs_rel) {
                        if (sep) {
                            cap_w.writeAll(", ") catch {};
                        }
                        cap_w.writeAll("rel") catch {};
                    }
                    std.log.info("aux device created: {s}", .{cap_fbs.getWritten()});
                }
            }
            if (out_cfg.touchpad) |*tp_cfg| {
                touchpad_dev = try TouchpadDevice.create(tp_cfg);
            }
        }
        const mapper: ?Mapper = if (init_mapping) |mcfg|
            Mapper.init(mcfg, loop.macro_timer_fd, allocator) catch |err| blk: {
                std.log.warn("failed to init mapper from default_mapping: {}", .{err});
                break :blk null;
            }
        else
            null;

        if (mapper != null) {
            std.log.info("device \"{s}\": mapping loaded", .{cfg.device.name});
        } else {
            std.log.info("device \"{s}\": passthrough (no mapping)", .{cfg.device.name});
        }
        std.log.info("device ready: \"{s}\"", .{cfg.device.name});

        return .{
            .allocator = allocator,
            .devices = devices,
            .loop = loop,
            .interp = interp,
            .mapper = mapper,
            .owner = owner,
            .primary_output = primary_output,
            .imu_output = imu_output,
            .imu_dev = imu_dev_ptr,
            .imu_name_owned = imu_name_ptr,
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
        // IMU teardown first: close kernel device, THEN free name backing
        // store. `UhidDevice.name` is owned-by-caller, so freeing the backing
        // memory before `close` would dangle the pointer while UHID_DESTROY
        // is in flight.
        if (self.imu_dev) |p| {
            p.close();
            self.allocator.destroy(p);
        }
        if (self.imu_name_owned) |n| {
            self.allocator.free(n);
        }
        switch (self.owner) {
            .none => {},
            .uinput => |p| {
                p.close();
                self.allocator.destroy(p);
            },
            .uhid => |p| {
                p.close();
                self.allocator.destroy(p);
            },
        }
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
                const old_mcfg: ?*const MappingConfig = if (self.mapper) |*m| m.config else self.mapping_cfg;
                if (Mapper.init(new, self.loop.macro_timer_fd, self.allocator)) |nm| {
                    if (self.mapper) |*m| m.deinit();
                    self.mapper = nm;
                    self.mapping_cfg = new;
                } else |err| {
                    std.log.err("mapping hot-swap failed: {}", .{err});
                }
                self.rebuildAuxIfChanged(new, old_mcfg) catch |err| {
                    std.log.err("aux rebuild after mapping swap failed: {}", .{err});
                };
                @atomicStore(?*MappingConfig, &self.pending_mapping, null, .release);
            }

            const output = self.primary_output orelse nullOutput();
            const aux_output: ?AuxOutputDevice = if (self.aux_dev) |*a| a.auxOutputDevice() else null;
            const touchpad_output: ?TouchpadOutputDevice = if (self.touchpad_dev) |*tp| tp.touchpadOutputDevice() else null;
            const generic_output: ?GenericOutputDevice = if (self.generic_uinput) |*gu| gu.genericOutputDevice() else null;
            const mapper_ptr: ?*Mapper = if (self.mapper) |*m| m else null;

            const mcfg: ?*const MappingConfig = if (mapper_ptr) |m| m.config else self.mapping_cfg;

            self.loop.run(.{
                .devices = self.devices,
                .interpreter = &self.interp,
                .output = output,
                .mapper = mapper_ptr,
                .aux_output = aux_output,
                .touchpad_output = touchpad_output,
                .imu_output = self.imu_output,
                .allocator = self.allocator,
                .device_config = self.device_cfg,
                .mapping_config = mcfg,
                .poll_timeout_ms = self.poll_timeout_ms,
                .generic_state = if (self.generic_state) |*gs| gs else null,
                .generic_output = generic_output,
                .device_tag = self.device_cfg.device.name,
            }) catch |err| {
                std.log.err("event loop failed: {}", .{err});
                break;
            };
            if (self.loop.disconnected) break;
        }
    }

    /// Rebuild AuxDevice if caps changed after a mapping swap. old_mcfg may be null
    /// if there was no prior mapping. Called from run() after pending_mapping swap.
    pub fn rebuildAuxIfChanged(self: *DeviceInstance, new_mcfg: *const MappingConfig, old_mcfg: ?*const MappingConfig) !void {
        if (builtin.is_test) self.rebuild_aux_calls += 1;
        if (self.device_cfg.output == null) return;
        const new_caps = mapping_mod.deriveAuxFromMapping(new_mcfg);
        const old_caps: mapping_mod.DerivedAuxCaps = if (old_mcfg) |m|
            mapping_mod.deriveAuxFromMapping(m)
        else
            .{};
        if (std.meta.eql(new_caps, old_caps)) return;
        if (self.aux_dev) |*a| {
            a.close();
            self.aux_dev = null;
        }
        if (new_caps.needsAux() or self.device_cfg.output.?.aux != null) {
            var buf: [mapping_mod.AUX_KEY_CODES_MAX]u16 = undefined;
            const key_codes = mapping_mod.buildAuxKeyCodes(new_caps, &buf);
            if (AuxDevice.create(key_codes, new_caps.needs_rel)) |dev| {
                self.aux_dev = dev;
            } else |err| {
                std.log.warn("aux device rebuild failed: {}, old device closed", .{err});
                return err;
            }
        }
    }

    /// Create AuxDevice if mapping needs it and device has an output section.
    /// Safe to call only when the run() thread is NOT running.
    pub fn ensureAuxForMapping(self: *DeviceInstance, mcfg: *const MappingConfig) !void {
        if (self.aux_dev != null) return;
        const out_cfg = self.device_cfg.output orelse return;
        const caps = mapping_mod.deriveAuxFromMapping(mcfg);
        if (!caps.needsAux() and out_cfg.aux == null) return;
        var buf: [mapping_mod.AUX_KEY_CODES_MAX]u16 = undefined;
        const key_codes = mapping_mod.buildAuxKeyCodes(caps, &buf);
        self.aux_dev = try AuxDevice.create(key_codes, caps.needs_rel);
    }

    /// Close physical device fds only, keeping uinput/aux/touchpad alive.
    /// Used when suspending an instance across device sleep/wake.
    pub fn closeDeviceIO(self: *DeviceInstance) void {
        for (self.devices) |dev| dev.close();
    }

    /// Replace physical device fds with new ones and re-register them in the
    /// event loop. Caller must provide the same number of DeviceIO entries as
    /// the original devices[] slice.
    pub fn rebindDeviceIO(self: *DeviceInstance, new_devices: []DeviceIO) void {
        @memcpy(self.devices, new_devices);
        self.loop.rebindDevices(self.devices);
    }

    /// Re-run the device init sequence (e.g. handshake packets) using the
    /// current devices[] fds and device_cfg.
    pub fn rerunInitSequence(self: *DeviceInstance) void {
        if (self.device_cfg.device.init) |init_cfg| {
            for (self.device_cfg.device.interface, self.devices) |iface, dev| {
                const match = if (init_cfg.interface) |init_iface|
                    iface.id == init_iface
                else
                    std.mem.eql(u8, iface.class, "vendor");
                if (!match) continue;
                init_seq.runInitSequence(self.allocator, dev, init_cfg) catch |err| {
                    std.log.debug("re-init on interface {d}: {}", .{ iface.id, err });
                };
            }
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

fn waitRunning(loop: *const EventLoop) !void {
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        if (@atomicLoad(bool, &loop.running, .acquire)) return;
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

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
    try waitRunning(&inst.loop);
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
        .mapper = try Mapper.init(&mapping_parsed.value, loop.macro_timer_fd, allocator),
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

    try waitRunning(&inst.loop);
    inst.updateMapping(&new_cfg);
    // poll until pending_mapping is consumed (applied on the next loop iteration)
    var w: usize = 0;
    while (w < 1000) : (w += 1) {
        if (@atomicLoad(?*mapping.MappingConfig, &inst.pending_mapping, .acquire) == null) break;
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }
    inst.stop();
    thread.join();

    // pending_mapping consumed (set to null) after being applied
    try testing.expectEqual(@as(?*mapping.MappingConfig, null), inst.pending_mapping);
    // mapping_cfg updated to new after swap (problem 3 fix)
    try testing.expectEqual(@as(?*const mapping.MappingConfig, &new_cfg), inst.mapping_cfg);
}

test "DeviceInstance: updateMapping updates mapping_cfg after swap" {
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
        .mapper = try Mapper.init(&mapping_parsed.value, loop.macro_timer_fd, allocator),
        .owner = .none,
        .primary_output = null,
        .imu_output = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = &parsed.value,
        .mapping_cfg = null,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    defer {
        if (inst.mapper) |*m| m.deinit();
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

    try waitRunning(&inst.loop);
    inst.updateMapping(&new_cfg);

    var w: usize = 0;
    while (w < 1000) : (w += 1) {
        if (@atomicLoad(?*mapping.MappingConfig, &inst.pending_mapping, .acquire) == null) break;
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }
    inst.stop();
    thread.join();

    try testing.expectEqual(@as(?*const mapping.MappingConfig, &new_cfg), inst.mapping_cfg);
}

test "DeviceInstance: rebuildAuxIfChanged is no-op when device has no output config" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    const mapping_parsed = try mapping.parseString(allocator, "");
    defer mapping_parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var inst = try testInstance(allocator, &mock, &parsed.value);
    defer {
        inst.loop.deinit();
        allocator.free(inst.devices);
    }

    // no output config on minimal_toml device — rebuildAuxIfChanged must return without error
    try inst.rebuildAuxIfChanged(&mapping_parsed.value, null);
    try testing.expectEqual(@as(?AuxDevice, null), inst.aux_dev);
}

test "DeviceInstance: closeDeviceIO closes device fds without touching uinput" {
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

    // closeDeviceIO must not crash; owner stays .none (not touched)
    inst.closeDeviceIO();
    try testing.expect(inst.owner == .none);
}

test "DeviceInstance: rebindDeviceIO replaces device fds" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();

    var inst = try testInstance(allocator, &mock_a, &parsed.value);
    defer {
        inst.loop.deinit();
        allocator.free(inst.devices);
    }

    // Close old device IO
    inst.closeDeviceIO();

    // Create new mock and rebind
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var new_devs = [_]DeviceIO{mock_b.deviceIO()};
    inst.rebindDeviceIO(&new_devs);

    // Verify the device was replaced (new mock's pollfd)
    const pfd = inst.devices[0].pollfd();
    const expected_pfd = mock_b.deviceIO().pollfd();
    try testing.expectEqual(expected_pfd.fd, pfd.fd);
}
