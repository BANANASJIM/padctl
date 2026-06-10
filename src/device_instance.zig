const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const DeviceIO = @import("io/device_io.zig").DeviceIO;
const HidrawDevice = @import("io/hidraw.zig").HidrawDevice;
const UsbrawDevice = @import("io/usbraw.zig").UsbrawDevice;
const UsbrawSuppress = @import("io/usbraw.zig").UsbrawSuppress;
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
const ffb_mod = @import("io/ffb_forwarder.zig");
const FfbForwarder = ffb_mod.FfbForwarder;
const WedgeAtomics = @import("io/wedge_atomics.zig").WedgeAtomics;
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
const ButtonId = @import("core/state.zig").ButtonId;
const FfEvent = uinput.FfEvent;

var closed_device_sentinel: u8 = 0;

const closed_device_vtable = DeviceIO.VTable{
    .read = closedRead,
    .write = closedWrite,
    .feature_report = closedFeatureReport,
    .pollfd = closedPollfd,
    .close = closedClose,
};

fn closedDeviceIO() DeviceIO {
    return .{ .ptr = &closed_device_sentinel, .vtable = &closed_device_vtable };
}

fn closedRead(_: *anyopaque, _: []u8) DeviceIO.ReadError!usize {
    return DeviceIO.ReadError.Disconnected;
}

fn closedWrite(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
    return DeviceIO.WriteError.Disconnected;
}

fn closedFeatureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
    return DeviceIO.WriteError.Disconnected;
}

fn closedPollfd(_: *anyopaque) posix.pollfd {
    return .{ .fd = -1, .events = 0, .revents = 0 };
}

fn closedClose(_: *anyopaque) void {}

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

/// Single open attempt. Transient failures are NOT retried here: a blocking
/// sleep/retry loop on the supervisor thread stalls the control socket (issue
/// #397). Retries are scheduled by the supervisor's event-driven hotplug queue.
pub fn openDeviceWithRetry(
    allocator: std.mem.Allocator,
    iface: InterfaceConfig,
    vid: u16,
    pid: u16,
) !DeviceIO {
    return createDeviceIO(allocator, iface, vid, pid);
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
/// `test_devices_override` skips the interface-opening loop entirely and
/// installs the caller-provided `DeviceIO` slice. Needed so a Layer 1 test
/// can drive `DeviceInstance.init` end-to-end without a real `/dev/hidraw*`
/// node — otherwise the legacy in-thread open retry blocked ~7s and failed in
/// CI before the routing switch is reached. The slice is consumed (stored in
/// `DeviceInstance.devices`) and freed by `deinit`; caller must not free it.
/// If `init` returns an error, no instance exists and the caller still owns
/// the override slice and any backing mock/device resources.
pub const InitOptions = struct {
    test_primary_uhid_fd: ?posix.fd_t = null,
    test_imu_uhid_fd: ?posix.fd_t = null,
    test_devices_override: ?[]DeviceIO = null,
    /// Test-only: substitute for the physical hidraw write-end used by FfbForwarder.
    /// When non-null, FfbForwarder.init receives this fd instead of the real device fd.
    test_physical_hidraw_fd: ?posix.fd_t = null,
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
    /// Interfaces claimed via libusb solely to evict the kernel driver so the
    /// physical device exposes no hidraw node for them. Never read or written.
    suppress_devs: []*UsbrawSuppress = &.{},
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
    /// Active only when force_feedback.backend="uhid" + kind="pid".
    ffb_forwarder: ?FfbForwarder = null,
    /// PR-ε.1 wedge instrumentation. Bumped by hidraw + ffb_forwarder; read by
    /// Supervisor.handleStatus. Inert until consumers attach (see attachWedges).
    wedge: WedgeAtomics = .{},
    // Test-only: counts rebuildAuxIfChanged invocations so tests can verify
    // the switch path rebuilds aux caps without relying on /dev/uinput.
    rebuild_aux_calls: if (builtin.is_test) usize else void = if (builtin.is_test) 0 else {},

    pub const QuiesceOptions = struct {
        reset_input_state: bool = false,
        reset_mapper_state: bool = false,
    };

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
        const devices = opts.test_devices_override orelse try allocator.alloc(DeviceIO, device_cfg.openedInterfaceCount(cfg));
        errdefer if (!override_active) allocator.free(devices);

        var opened: usize = 0;
        errdefer for (devices[0..opened]) |dev| dev.close();

        // Suppress interfaces are claimed only to evict the kernel driver; they
        // are not read or written and get no DeviceIO slot.
        const suppress_count = cfg.device.interface.len - device_cfg.openedInterfaceCount(cfg);
        const suppress_devs: []*UsbrawSuppress = if (!override_active and suppress_count > 0)
            try allocator.alloc(*UsbrawSuppress, suppress_count)
        else
            &.{};
        errdefer if (!override_active and suppress_count > 0) allocator.free(suppress_devs);

        var suppressed: usize = 0;
        errdefer for (suppress_devs[0..suppressed]) |sd| sd.close();

        if (!override_active) {
            // Pass 1: open hid/vendor interfaces into devices[] positionally.
            for (cfg.device.interface) |iface| {
                if (device_cfg.isSuppressClass(iface.class)) continue;
                devices[opened] = try openDeviceWithRetry(allocator, iface, vid, pid);
                opened += 1;
            }
            // Pass 2: claim suppress interfaces to remove their hidraw nodes.
            for (cfg.device.interface) |iface| {
                if (!device_cfg.isSuppressClass(iface.class)) continue;
                suppress_devs[suppressed] = try UsbrawSuppress.openSuppress(allocator, vid, pid, @intCast(iface.id));
                suppressed += 1;
            }
        }

        if (cfg.device.init) |init_cfg| {
            for (cfg.device.interface) |iface| {
                if (device_cfg.isSuppressClass(iface.class)) continue;
                const dev_idx = device_cfg.deviceIndexForInterface(cfg, iface.id) orelse continue;
                const match = if (init_cfg.interface) |init_iface|
                    iface.id == init_iface
                else
                    std.mem.eql(u8, iface.class, "vendor");
                if (!match) continue;
                init_seq.runInitSequence(allocator, devices[dev_idx], init_cfg) catch |err| {
                    std.log.debug("init on interface {d}: {}", .{ iface.id, err });
                    return err;
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
        var ffb_fwd: ?FfbForwarder = null;
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
            // Enter UHID path when IMU backend=uhid (gamepad+IMU pair) OR
            // when force_feedback.backend=uhid (racing wheel PID FFB).
            const use_uhid = blk: {
                if (imu_cfg_opt) |imu_cfg| {
                    if (std.mem.eql(u8, imu_cfg.backend, "uhid")) break :blk true;
                }
                if (out_cfg.force_feedback) |ffb| {
                    if (std.mem.eql(u8, ffb.backend, "uhid")) break :blk true;
                }
                break :blk false;
            };

            if (use_uhid) {
                // Primary + IMU cards share a byte-identical uniq. Snapshot the
                // counter once, bump only if the counter branch was taken
                // (phys_key == null).
                const counter_snapshot: u16 = uniq_counter.*;
                const uniq_z = try uniq_mod.buildUniq(allocator, cfg.device.name, phys_key, counter_snapshot);
                defer allocator.free(uniq_z);
                if (phys_key == null) uniq_counter.* += 1;

                // PID devices need the HID PID descriptor so that kernel
                // hid-universal-pidff's pidff_find_reports finds all 8 mandatory
                // usages; buildFromOutput emits only a gamepad descriptor.
                const primary_descriptor = if (out_cfg.force_feedback) |ffb|
                    if (std.mem.eql(u8, ffb.backend, "uhid") and std.mem.eql(u8, ffb.kind, "pid"))
                        try uhid_descriptor.UhidDescriptorBuilder.buildForPid(allocator, out_cfg.*, ffb)
                    else
                        try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg.*)
                else
                    try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg.*);
                defer allocator.free(primary_descriptor);

                const ffb_cfg = out_cfg.force_feedback orelse device_cfg.ForceFeedbackConfig{};
                // clone_vid_pid=true: wheel's real VID/PID (hid-universal-pidff modalias binding).
                // clone_vid_pid=false (default): daemon identity so non-PID devices stay as FADE:C001.
                const effective_vid: u16 = if (ffb_cfg.clone_vid_pid)
                    @intCast(cfg.device.vid)
                else
                    0xFADE;
                const effective_pid: u16 = if (ffb_cfg.clone_vid_pid)
                    @intCast(cfg.device.pid)
                else
                    0xC001;

                const primary_cfg = uhid_mod.Config{
                    .name = cfg.device.name,
                    .uniq = std.mem.sliceTo(uniq_z, 0),
                    .vid = effective_vid,
                    .pid = effective_pid,
                    .descriptor = primary_descriptor,
                    .output = out_cfg.*,
                };
                const primary_uhid = try openUhidDevice(allocator, primary_cfg, opts.test_primary_uhid_fd);
                errdefer {
                    primary_uhid.close();
                    allocator.destroy(primary_uhid);
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

                // Wire FfbForwarder when backend=uhid + kind=pid. Callback
                // registration is deferred to run() so the pointer to
                // ffb_forwarder is stable (DeviceInstance is heap-allocated by
                // the Supervisor before run() is called).
                if (out_cfg.force_feedback) |pid_ffb| {
                    if (std.mem.eql(u8, pid_ffb.backend, "uhid") and
                        std.mem.eql(u8, pid_ffb.kind, "pid"))
                    {
                        // TODO: devices[0] is a heuristic — correct for single-interface
                        // wheels but may select the wrong interface on multi-interface
                        // devices (e.g. a separate HID++ control interface at index 0
                        // and the FFB interface at index 1).
                        if (devices.len > 1) {
                            std.log.warn("PID FFB: {d} interfaces found; using devices[0] as hidraw fd — may be wrong for multi-interface wheels", .{devices.len});
                        }
                        const phys_fd = opts.test_physical_hidraw_fd orelse
                            if (devices.len > 0) devices[0].pollfd().fd else -1;
                        if (phys_fd >= 0) {
                            ffb_fwd = FfbForwarder.init(phys_fd);
                            try loop.addUhidOutput(primary_uhid.fd);
                        }
                    }
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
            .suppress_devs = suppress_devs,
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
            .ffb_forwarder = ffb_fwd,
        };
    }

    /// Wire wedge instrumentation into hidraw devices and the FFB forwarder.
    /// Safe to call only AFTER the DeviceInstance is heap-stable (Supervisor
    /// allocates it via allocator.create before spawnInstance). Idempotent.
    pub fn attachWedges(self: *DeviceInstance) void {
        const Hidraw = @import("io/hidraw.zig").HidrawDevice;
        const tag = Hidraw.vtablePtr();
        for (self.devices) |dev| {
            if (dev.vtable == tag) {
                const h: *Hidraw = @ptrCast(@alignCast(dev.ptr));
                h.attachWedge(&self.wedge);
            }
        }
        if (self.ffb_forwarder) |*fwd| fwd.attachWedge(&self.wedge);
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
                // Clear callback before closing so no in-flight report reaches
                // a stale FfbForwarder pointer after the device is gone.
                p.clearOutputCallback();
                p.close();
                self.allocator.destroy(p);
            },
        }
        if (self.ffb_forwarder) |*fwd| fwd.deinit();
        if (self.aux_dev) |*a| a.close();
        if (self.touchpad_dev) |*tp| tp.close();
        if (self.generic_uinput) |*gu| gu.close();
        for (self.suppress_devs) |sd| sd.close();
        if (self.suppress_devs.len > 0) self.allocator.free(self.suppress_devs);
        for (self.devices) |dev| dev.close();
        self.allocator.free(self.devices);
        self.loop.deinit();
    }

    /// Thread entry point. Runs the event loop; applies pending mapping swaps
    /// between iterations (woken via stop_pipe by updateMapping).
    pub fn run(self: *DeviceInstance) !void {
        // Register FfbForwarder callback now that self is stable on the heap.
        if (self.ffb_forwarder != null) {
            if (self.owner == .uhid) {
                self.owner.uhid.setOutputCallback(ffb_mod.forwarderCallback, &self.ffb_forwarder.?);
            }
        }
        while (!@atomicLoad(bool, &self.stopped, .acquire)) {
            // Apply pending mapping before processing any fds
            if (@atomicLoad(?*MappingConfig, &self.pending_mapping, .acquire)) |new| {
                const old_mcfg: ?*const MappingConfig = if (self.mapper) |*m| m.config else self.mapping_cfg;
                if (Mapper.init(new, self.loop.macro_timer_fd, self.allocator)) |created| {
                    var new_mapper = created;
                    self.quiesceOutputs(.{});
                    if (self.mapper) |*old| {
                        old.deinit();
                    }
                    new_mapper.seedInputState(self.loop.gamepad_state);
                    self.mapper = new_mapper;
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
                .uhid_primary = switch (self.owner) {
                    .uhid => |p| p,
                    else => null,
                },
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

    pub fn quiesceOutputs(self: *DeviceInstance, options: QuiesceOptions) void {
        self.loop.quiesceTimersAndRumble(self.devices, self.allocator, self.device_cfg, self.device_cfg.device.name);

        if (self.mapper) |*m| {
            self.releaseMapperAux(m);
            if (options.reset_mapper_state) {
                m.resetRuntimeState();
            }
        }

        const neutral = GamepadState{};
        if (self.primary_output) |output| {
            output.emit(neutral) catch |err| {
                std.log.warn("primary output quiesce failed: {}", .{err});
            };
        }
        if (self.imu_output) |imu_output| {
            imu_output.emit(neutral) catch |err| {
                std.log.warn("imu output quiesce failed: {}", .{err});
            };
        }
        if (self.touchpad_dev) |*tp| {
            tp.touchpadOutputDevice().emitTouch(neutral) catch |err| {
                std.log.warn("touchpad output quiesce failed: {}", .{err});
            };
        }
        if (self.generic_state) |*gs| {
            if (self.generic_uinput) |*gu| {
                @memset(gs.values[0..gs.count], 0);
                gu.genericOutputDevice().emitGeneric(gs) catch |err| {
                    std.log.warn("generic output quiesce failed: {}", .{err});
                };
            }
        }
        if (options.reset_input_state) {
            self.loop.gamepad_state = .{};
        }
    }

    /// Close physical device fds only, keeping uinput/aux/touchpad alive.
    /// Used when suspending an instance across device sleep/wake.
    pub fn closeDeviceIO(self: *DeviceInstance) void {
        for (self.devices) |*dev| {
            dev.close();
            dev.* = closedDeviceIO();
        }
    }

    /// Replace physical device fds with new ones and re-register them in the
    /// event loop. Caller must provide the same number of DeviceIO entries as
    /// the original devices[] slice.
    pub fn rebindDeviceIO(self: *DeviceInstance, new_devices: []DeviceIO) !void {
        if (new_devices.len != self.devices.len) return error.DeviceCountMismatch;
        try self.loop.rebindDevices(new_devices);
        @memcpy(self.devices, new_devices);
    }

    /// Re-run the device init sequence (e.g. handshake packets) using the
    /// current devices[] fds and device_cfg.
    pub fn rerunInitSequence(self: *DeviceInstance) !void {
        if (self.device_cfg.device.init) |init_cfg| {
            for (self.device_cfg.device.interface) |iface| {
                if (device_cfg.isSuppressClass(iface.class)) continue;
                const dev_idx = device_cfg.deviceIndexForInterface(self.device_cfg, iface.id) orelse continue;
                const match = if (init_cfg.interface) |init_iface|
                    iface.id == init_iface
                else
                    std.mem.eql(u8, iface.class, "vendor");
                if (!match) continue;
                init_seq.runInitSequence(self.allocator, self.devices[dev_idx], init_cfg) catch |err| {
                    std.log.debug("re-init on interface {d}: {}", .{ iface.id, err });
                    return err;
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

    pub fn releaseMapperAux(self: *DeviceInstance, mapper: *Mapper) void {
        const releases = mapper.releaseHeldAux();
        if (releases.len == 0) return;
        if (self.aux_dev) |*aux| {
            aux.emitAux(releases.slice()) catch |err| {
                std.log.warn("aux release during mapping swap failed: {}", .{err});
            };
        }
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
const MockOutput = @import("test/mock_output.zig").MockOutput;
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

const init_toml =
    \\[device]
    \\name = "InitDevice"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[device.init]
    \\interface = 0
    \\commands = ["0101"]
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

const strict_init_toml =
    \\[device]
    \\name = "StrictInitDevice"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[device.init]
    \\interface = 0
    \\commands = ["0101"]
    \\response_prefix = [0x5a]
    \\require_response = true
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

const feature_init_toml =
    \\[device]
    \\name = "FeatureInitDevice"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[device.init]
    \\interface = 0
    \\feature_report = [0x81, 0, 0]
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

const FailWriteDeviceIO = struct {
    pub fn deviceIO(self: *FailWriteDeviceIO) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .feature_report = featureReport,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(_: *anyopaque, _: []u8) DeviceIO.ReadError!usize {
        return DeviceIO.ReadError.Again;
    }

    fn write(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        return DeviceIO.WriteError.Io;
    }

    fn featureReport(_: *anyopaque, _: []const u8) DeviceIO.WriteError!void {
        return DeviceIO.WriteError.Io;
    }

    fn pollfd(_: *anyopaque) posix.pollfd {
        return .{ .fd = -1, .events = 0, .revents = 0 };
    }

    fn close(_: *anyopaque) void {}
};

test "DeviceInstance.init propagates init write errors" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, init_toml);
    defer parsed.deinit();

    var failing = FailWriteDeviceIO{};
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = failing.deviceIO();

    var uniq_counter: u16 = 1;
    const result = DeviceInstance.init(allocator, &parsed.value, null, null, &uniq_counter, .{
        .test_devices_override = devices,
    });

    try testing.expectError(DeviceIO.WriteError.Io, result);
}

test "DeviceInstance.init propagates required init ack failures" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, strict_init_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = mock.deviceIO();

    var uniq_counter: u16 = 1;
    const result = DeviceInstance.init(allocator, &parsed.value, null, null, &uniq_counter, .{
        .test_devices_override = devices,
    });

    try testing.expectError(error.InitFailed, result);
}

test "DeviceInstance.init propagates feature_report init errors" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, feature_init_toml);
    defer parsed.deinit();

    var failing = FailWriteDeviceIO{};
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = failing.deviceIO();

    var uniq_counter: u16 = 1;
    const result = DeviceInstance.init(allocator, &parsed.value, null, null, &uniq_counter, .{
        .test_devices_override = devices,
    });

    try testing.expectError(DeviceIO.WriteError.Io, result);
}

const suppress_first_init_toml =
    \\[device]
    \\name = "SuppressFirst"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "suppress"
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
    \\[[device.interface]]
    \\id = 2
    \\class = "hid"
    \\[device.init]
    \\interface = 1
    \\commands = ["aabb"]
    \\[[report]]
    \\name = "r1"
    \\interface = 1
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[[report]]
    \\name = "r2"
    \\interface = 2
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x02]
;

const report_then_suppress_init_toml =
    \\[device]
    \\name = "ReportThenSuppress"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[device.interface]]
    \\id = 1
    \\class = "suppress"
    \\[device.init]
    \\interface = 0
    \\commands = ["ccdd"]
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 1
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
;

// Regression guard for the suppress-interface index alignment (issue #355).
// The init-handshake loop must route the init command to the devices[] slot
// computed by deviceIndexForInterface, NOT to a positional interface[i]
// counter. With a suppress interface preceding the report interfaces, a
// positional counter would target the wrong mock (or overflow).
test "DeviceInstance.init: suppress preceding report routes init via helper, not positional" {
    const allocator = testing.allocator;

    {
        const parsed = try device_mod.parseString(allocator, suppress_first_init_toml);
        defer parsed.deinit();

        var mock0 = try MockDeviceIO.init(allocator, &.{});
        defer mock0.deinit();
        var mock1 = try MockDeviceIO.init(allocator, &.{});
        defer mock1.deinit();

        const devices = try allocator.alloc(DeviceIO, 2);
        devices[0] = mock0.deviceIO();
        devices[1] = mock1.deviceIO();

        var uniq_counter: u16 = 1;
        var inst = try DeviceInstance.init(allocator, &parsed.value, null, null, &uniq_counter, .{
            .test_devices_override = devices,
        });
        defer inst.deinit();

        // init.interface = 1 maps to devices[0] (suppress id=0 consumes no slot).
        try testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0xbb }, mock0.write_log.items);
        try testing.expectEqual(@as(usize, 0), mock1.write_log.items.len);
    }

    {
        const parsed = try device_mod.parseString(allocator, report_then_suppress_init_toml);
        defer parsed.deinit();

        var mock = try MockDeviceIO.init(allocator, &.{});
        defer mock.deinit();

        const devices = try allocator.alloc(DeviceIO, 1);
        devices[0] = mock.deviceIO();

        var uniq_counter: u16 = 1;
        var inst = try DeviceInstance.init(allocator, &parsed.value, null, null, &uniq_counter, .{
            .test_devices_override = devices,
        });
        defer inst.deinit();

        try testing.expectEqualSlices(u8, &[_]u8{ 0xcc, 0xdd }, mock.write_log.items);
    }
}

test "DeviceInstance: rerunInitSequence propagates init write errors" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, init_toml);
    defer parsed.deinit();

    var failing = FailWriteDeviceIO{};
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = failing.deviceIO();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    var inst = DeviceInstance{
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

    try testing.expectError(DeviceIO.WriteError.Io, inst.rerunInitSequence());
}

test "DeviceInstance: rerunInitSequence propagates required init ack failures" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, strict_init_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    var inst = DeviceInstance{
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

    try testing.expectError(error.InitFailed, inst.rerunInitSequence());
}

test "DeviceInstance: rerunInitSequence propagates feature_report errors" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, feature_init_toml);
    defer parsed.deinit();

    var failing = FailWriteDeviceIO{};
    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = failing.deviceIO();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    var inst = DeviceInstance{
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

    try testing.expectError(DeviceIO.WriteError.Io, inst.rerunInitSequence());
}

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
    try testing.expectEqual(@as(posix.fd_t, -1), inst.devices[0].pollfd().fd);
    try testing.expectError(DeviceIO.WriteError.Disconnected, inst.devices[0].write(&[_]u8{0x01}));
}

test "DeviceInstance: quiesceOutputs emits neutral primary frame and resets input state when requested" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var out = MockOutput.init(allocator);
    defer out.deinit();

    var inst = try testInstance(allocator, &mock, &parsed.value);
    defer {
        inst.loop.deinit();
        allocator.free(inst.devices);
    }
    inst.primary_output = out.outputDevice();
    inst.loop.gamepad_state = .{
        .ax = 123,
        .buttons = @as(u64, 1) << @intFromEnum(ButtonId.A),
    };
    out.prev = inst.loop.gamepad_state;

    inst.quiesceOutputs(.{ .reset_input_state = true });

    try testing.expectEqual(@as(usize, 1), out.emitted.items.len);
    try testing.expect(std.meta.eql(GamepadState{}, out.emitted.items[0]));
    try testing.expect(std.meta.eql(GamepadState{}, inst.loop.gamepad_state));
}

test "DeviceInstance: quiesceOutputs can preserve input state for mapper reseed" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var out = MockOutput.init(allocator);
    defer out.deinit();

    var inst = try testInstance(allocator, &mock, &parsed.value);
    defer {
        inst.loop.deinit();
        allocator.free(inst.devices);
    }
    const held = GamepadState{
        .rx = -50,
        .buttons = @as(u64, 1) << @intFromEnum(ButtonId.RB),
    };
    inst.primary_output = out.outputDevice();
    inst.loop.gamepad_state = held;
    out.prev = held;

    inst.quiesceOutputs(.{});

    try testing.expectEqual(@as(usize, 1), out.emitted.items.len);
    try testing.expect(std.meta.eql(GamepadState{}, out.emitted.items[0]));
    try testing.expect(std.meta.eql(held, inst.loop.gamepad_state));
}

// input_event wire layout (linux/input.h) for decoding aux fd writes in tests.
const TestInputEvent = extern struct {
    sec: isize,
    usec: isize,
    type: u16,
    code: u16,
    value: i32,
};
const EV_KEY_T: u16 = 1;
const KEY_LEFTSHIFT_T: u16 = 42;

// Read aux fd records and return true iff a KEY_LEFTSHIFT release (value=0) is present.
fn pipeHasShiftRelease(read_fd: posix.fd_t) !bool {
    var buf: [4096]u8 = undefined;
    const n = posix.read(read_fd, &buf) catch |err| switch (err) {
        error.WouldBlock => return false,
        else => return err,
    };
    const rec = @sizeOf(TestInputEvent);
    var off: usize = 0;
    var found = false;
    while (off + rec <= n) : (off += rec) {
        var ev: TestInputEvent = undefined;
        @memcpy(std.mem.asBytes(&ev), buf[off .. off + rec]);
        if (ev.type == EV_KEY_T and ev.code == KEY_LEFTSHIFT_T and ev.value == 0) found = true;
    }
    return found;
}

// Drive a layer-hold KEY mapper to its ACTIVE state (KEY_LEFTSHIFT pressed) and
// install it on `inst`, wiring `inst.aux_dev` to `write_fd` so quiesceOutputs'
// releaseMapperAux release edge lands on a pipe we can read back.
fn primeLayerHoldActive(inst: *DeviceInstance, m: *Mapper, write_fd: posix.fd_t) !void {
    const lb_mask = @as(u64, 1) << @intFromEnum(ButtonId.LB);
    _ = try m.apply(.{ .buttons = lb_mask }, 16, 0);
    _ = m.onLayerTimerExpiredAt(210_000_000);
    try testing.expect(m.layer_hold_aux_down != null);
    inst.mapper = m.*;
    inst.aux_dev = AuxDevice{ .fd = write_fd };
}

const layer_hold_key_toml =
    \\[[layer]]
    \\name = "sense"
    \\trigger = "LB"
    \\activation = "hold"
    \\hold = "KEY_LEFTSHIFT"
    \\hold_timeout = 200
;

test "DeviceInstance: quiesceOutputs releases held layer-hold KEY through aux path" {
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

    const mparsed = try mapping.parseString(allocator, layer_hold_key_toml);
    defer mparsed.deinit();
    var m = try Mapper.init(&mparsed.value, std.posix.STDIN_FILENO, allocator);
    defer m.deinit();

    const pfds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(pfds[0]);
    defer posix.close(pfds[1]);

    try primeLayerHoldActive(&inst, &m, pfds[1]);

    inst.quiesceOutputs(.{});

    // releaseMapperAux at device_instance.zig:657 must have funneled the held
    // KEY_LEFTSHIFT release through inst.aux_dev. Removing that call leaks the key.
    try testing.expect(try pipeHasShiftRelease(pfds[0]));
    try testing.expect(inst.mapper.?.layer_hold_aux_down == null);

    inst.aux_dev = null; // owned by pipe close, not AuxDevice.close
}

test "DeviceInstance: quiesceOutputs reset_mapper_state releases held layer-hold KEY" {
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

    const mparsed = try mapping.parseString(allocator, layer_hold_key_toml);
    defer mparsed.deinit();
    var m = try Mapper.init(&mparsed.value, std.posix.STDIN_FILENO, allocator);
    defer m.deinit();

    const pfds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(pfds[0]);
    defer posix.close(pfds[1]);

    try primeLayerHoldActive(&inst, &m, pfds[1]);

    inst.quiesceOutputs(.{ .reset_mapper_state = true });

    // Release edge must precede resetRuntimeState (which only clears state, no
    // edge). Order is releaseMapperAux -> resetRuntimeState in quiesceOutputs.
    try testing.expect(try pipeHasShiftRelease(pfds[0]));
    try testing.expect(inst.mapper.?.layer_hold_aux_down == null);

    inst.aux_dev = null;
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
    try inst.rebindDeviceIO(&new_devs);

    // Verify the device was replaced (new mock's pollfd)
    const pfd = inst.devices[0].pollfd();
    const expected_pfd = mock_b.deviceIO().pollfd();
    try testing.expectEqual(expected_pfd.fd, pfd.fd);
}

test "DeviceInstance: rebindDeviceIO rejects device count mismatch" {
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

    var empty = [_]DeviceIO{};
    try testing.expectError(error.DeviceCountMismatch, inst.rebindDeviceIO(&empty));
}

// issue #397: openDeviceWithRetry must NOT sleep/retry on the supervisor
// thread. A failing open must return promptly so the supervisor poll loop can
// keep servicing the control socket (`padctl status`). The legacy loop slept
// 1+2+4=7s before returning the error.
test "openDeviceWithRetry returns promptly on a failing open (no in-thread sleep)" {
    const allocator = testing.allocator;

    // VID/PID 0xFFFF/0xFFFF matches no real device, so hidraw discover fails
    // with error.NotFound. The old retry loop classified this as retryable and
    // slept 7s; the fix returns the error on the first attempt.
    const iface = InterfaceConfig{ .id = 0, .class = "hid" };

    var timer = try std.time.Timer.start();
    const result = openDeviceWithRetry(allocator, iface, 0xFFFF, 0xFFFF);
    const elapsed_ns = timer.read();

    try testing.expectError(error.NotFound, result);
    // Old code: >= 7s. New code: a bare /dev scan, well under 3s.
    try testing.expect(elapsed_ns < 3 * std.time.ns_per_s);
}
