const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const DeviceIO = @import("io/device_io.zig").DeviceIO;
const interpreter_mod = @import("core/interpreter.zig");
const Interpreter = interpreter_mod.Interpreter;
const OutputDevice = @import("io/uinput.zig").OutputDevice;
const AuxOutputDevice = @import("io/uinput.zig").AuxOutputDevice;
const TouchpadOutputDevice = @import("io/uinput.zig").TouchpadOutputDevice;
const generic = @import("core/generic.zig");
const GenericDeviceState = generic.GenericDeviceState;
const GenericOutputDevice = @import("io/uinput.zig").GenericOutputDevice;
const state = @import("core/state.zig");
const GamepadStateDelta = state.GamepadStateDelta;
const mapper_mod = @import("core/mapper.zig");
const DeviceConfig = @import("config/device.zig").DeviceConfig;
const fillTemplate = @import("core/command.zig").fillTemplate;
const Param = @import("core/command.zig").Param;
const AdaptiveTriggerConfig = @import("config/mapping.zig").AdaptiveTriggerConfig;
const MappingConfig = @import("config/mapping.zig").MappingConfig;
const wasm_runtime = @import("wasm/runtime.zig");
pub const WasmPlugin = wasm_runtime.WasmPlugin;

// signalfd(0) + stop_pipe(1) + per-interface fds + uinput FF fd + timerfd slot
pub const MAX_FDS = 10;

const signalfd_siginfo_size = 128;

pub const TimerCallback = struct {
    ptr: *anyopaque,
    on_expired: *const fn (*anyopaque) void,

    pub fn call(self: TimerCallback) void {
        self.on_expired(self.ptr);
    }
};

/// Arm a timerfd for a one-shot timeout (it_interval = 0).
pub fn armTimer(fd: posix.fd_t, timeout_ms: u32) void {
    const spec = linux.itimerspec{
        .it_value = .{
            .sec = @intCast(timeout_ms / 1000),
            .nsec = @intCast((timeout_ms % 1000) * 1_000_000),
        },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

/// Disarm a timerfd by setting all fields to zero.
pub fn disarmTimer(fd: posix.fd_t) void {
    const spec = linux.itimerspec{
        .it_value = .{ .sec = 0, .nsec = 0 },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    _ = linux.timerfd_settime(fd, .{}, &spec, null);
}

pub const EventLoopContext = struct {
    devices: []DeviceIO,
    interpreter: *const Interpreter,
    output: OutputDevice,
    mapper: ?*mapper_mod.Mapper = null,
    aux_output: ?AuxOutputDevice = null,
    touchpad_output: ?TouchpadOutputDevice = null,
    allocator: ?std.mem.Allocator = null,
    device_config: ?*const DeviceConfig = null,
    mapping_config: ?*const MappingConfig = null,
    poll_timeout_ms: ?u32 = null,
    wasm_plugin: ?WasmPlugin = null,
    wasm_override_report: bool = false,
    generic_state: ?*GenericDeviceState = null,
    generic_output: ?GenericOutputDevice = null,
};

fn i64ToParamValue(v: ?i64) u16 {
    const raw = v orelse 0;
    const clamped: u8 = @intCast(std.math.clamp(raw, 0, 255));
    return @as(u16, clamped) << 8;
}

const AdaptiveTriggerParamConfig = @import("config/mapping.zig").AdaptiveTriggerParamConfig;
const empty_at_params = AdaptiveTriggerParamConfig{};

fn buildAdaptiveTriggerParams(buf: *[12]Param, at: *const AdaptiveTriggerConfig) []const Param {
    const r = at.right orelse empty_at_params;
    const l = at.left orelse empty_at_params;
    buf[0] = .{ .name = "r_position", .value = i64ToParamValue(r.position) };
    buf[1] = .{ .name = "r_strength", .value = i64ToParamValue(r.strength) };
    buf[2] = .{ .name = "r_start", .value = i64ToParamValue(r.start) };
    buf[3] = .{ .name = "r_end", .value = i64ToParamValue(r.end) };
    buf[4] = .{ .name = "r_amplitude", .value = i64ToParamValue(r.amplitude) };
    buf[5] = .{ .name = "r_frequency", .value = i64ToParamValue(r.frequency) };
    buf[6] = .{ .name = "l_position", .value = i64ToParamValue(l.position) };
    buf[7] = .{ .name = "l_strength", .value = i64ToParamValue(l.strength) };
    buf[8] = .{ .name = "l_start", .value = i64ToParamValue(l.start) };
    buf[9] = .{ .name = "l_end", .value = i64ToParamValue(l.end) };
    buf[10] = .{ .name = "l_amplitude", .value = i64ToParamValue(l.amplitude) };
    buf[11] = .{ .name = "l_frequency", .value = i64ToParamValue(l.frequency) };
    return buf[0..12];
}

pub fn applyAdaptiveTrigger(
    devices: []DeviceIO,
    alloc: std.mem.Allocator,
    dcfg: *const DeviceConfig,
    at_cfg: *const AdaptiveTriggerConfig,
) void {
    const cmds = dcfg.commands orelse return;

    var name_buf: [64]u8 = undefined;
    const prefix = at_cfg.command_prefix;
    if (prefix.len + at_cfg.mode.len > name_buf.len) return;
    @memcpy(name_buf[0..prefix.len], prefix);
    @memcpy(name_buf[prefix.len .. prefix.len + at_cfg.mode.len], at_cfg.mode);
    const cmd_name = name_buf[0 .. prefix.len + at_cfg.mode.len];

    const cmd = cmds.map.get(cmd_name) orelse return;
    var params_buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&params_buf, at_cfg);

    if (fillTemplate(alloc, cmd.template, params)) |bytes| {
        defer alloc.free(bytes);
        const iface_idx: usize = @intCast(cmd.interface);
        if (iface_idx < devices.len) {
            devices[iface_idx].write(bytes) catch {};
        }
    } else |_| {}
}

pub const EventLoop = struct {
    pollfds: [MAX_FDS]posix.pollfd,
    fd_count: usize,
    signal_fd: posix.fd_t,
    stop_r: posix.fd_t,
    stop_w: posix.fd_t,
    // device fds start at slot 2 (after signalfd + stop_pipe)
    device_base: usize,
    timer_fd: posix.fd_t,
    uinput_ff_slot: ?usize,
    disconnected: bool,
    running: bool,
    gamepad_state: state.GamepadState,
    last_ts: i128,
    last_rumble_ns: i128,

    pub fn init() !EventLoop {
        var mask = posix.sigemptyset();
        posix.sigaddset(&mask, linux.SIG.TERM);
        posix.sigaddset(&mask, linux.SIG.INT);
        posix.sigprocmask(linux.SIG.BLOCK, &mask, null);

        const sig_fd = try posix.signalfd(-1, &mask, 0);
        errdefer posix.close(sig_fd);

        return initWithSigFd(sig_fd);
    }

    /// Init without creating a signalfd — for use under Supervisor.
    /// Signals are managed by the Supervisor; the EventLoop exits only via stop_pipe or disconnect.
    pub fn initManaged() !EventLoop {
        const ioctl = @import("io/ioctl_constants.zig");
        const efd = try posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
        errdefer posix.close(efd);
        return initWithSigFd(efd);
    }

    fn initWithSigFd(sig_fd: posix.fd_t) !EventLoop {
        const pfds = try posix.pipe2(.{ .NONBLOCK = true });
        const stop_r = pfds[0];
        const stop_w = pfds[1];
        errdefer {
            posix.close(stop_r);
            posix.close(stop_w);
        }

        const timer_fd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
        errdefer posix.close(timer_fd);

        var loop = EventLoop{
            .pollfds = undefined,
            .fd_count = 0,
            .signal_fd = sig_fd,
            .stop_r = stop_r,
            .stop_w = stop_w,
            .device_base = 0,
            .timer_fd = timer_fd,
            .uinput_ff_slot = null,
            .disconnected = false,
            .running = false,
            .gamepad_state = .{},
            .last_ts = std.time.nanoTimestamp(),
            .last_rumble_ns = 0,
        };

        // slot 0 = signalfd (or dummy pipe), slot 1 = stop pipe, slot 2 = timerfd
        loop.pollfds[0] = .{ .fd = sig_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[1] = .{ .fd = stop_r, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[2] = .{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.fd_count = 3;
        loop.device_base = 3;

        return loop;
    }

    pub fn addDevice(self: *EventLoop, device: DeviceIO) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = device.pollfd();
        self.fd_count += 1;
    }

    pub fn addUinputFf(self: *EventLoop, fd: posix.fd_t) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = .{ .fd = fd, .events = posix.POLL.IN, .revents = 0 };
        self.uinput_ff_slot = slot;
        self.fd_count += 1;
    }

    pub fn run(self: *EventLoop, ctx: EventLoopContext) !void {
        self.running = true;
        var buf: [64]u8 = undefined;

        // Apply adaptive trigger config at startup (one-shot send)
        if (ctx.allocator) |alloc| {
            if (ctx.device_config) |dcfg| {
                if (ctx.mapping_config) |mcfg| {
                    if (mcfg.adaptive_trigger) |*at| {
                        applyAdaptiveTrigger(ctx.devices, alloc, dcfg, at);
                    }
                }
            }
        }

        const timeout: ?posix.timespec = if (ctx.poll_timeout_ms) |ms|
            .{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * 1_000_000) }
        else
            null;

        while (self.running) {
            _ = posix.ppoll(self.pollfds[0..self.fd_count], if (timeout) |*t| t else null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => {
                    std.log.err("ppoll failed: {}", .{err});
                    break;
                },
            };

            const now = std.time.nanoTimestamp();
            const dt_ns = now - self.last_ts;
            const dt_ms: u32 = @intCast(@min(100, @max(1, @divFloor(dt_ns, 1_000_000))));
            self.last_ts = now;

            // Check signalfd (slot 0)
            if (self.pollfds[0].revents & posix.POLL.IN != 0) {
                var siginfo: [signalfd_siginfo_size]u8 = undefined;
                _ = posix.read(self.signal_fd, &siginfo) catch {};
                break;
            }

            // Check stop pipe (slot 1) — drain byte and return to caller
            if (self.pollfds[1].revents & posix.POLL.IN != 0) {
                var drain: [1]u8 = undefined;
                _ = posix.read(self.stop_r, &drain) catch {};
                break;
            }

            // Check timerfd (slot 2)
            if (self.pollfds[2].revents & posix.POLL.IN != 0) {
                var expiry: [8]u8 = undefined;
                _ = posix.read(self.timer_fd, &expiry) catch {};
                if (ctx.mapper) |m| {
                    const macro_aux = m.onTimerExpired();
                    if (macro_aux.len > 0) {
                        if (ctx.aux_output) |ao| ao.emitAux(macro_aux.slice()) catch {};
                    }
                }
            }

            // Check uinput FF fd
            if (self.uinput_ff_slot) |slot| {
                if (self.pollfds[slot].revents & posix.POLL.IN != 0) {
                    if (ctx.output.pollFf() catch null) |ff_ev| {
                        const now_ns = std.time.nanoTimestamp();
                        const min_interval_ns: i128 = 10_000_000; // 10ms
                        if (now_ns - self.last_rumble_ns >= min_interval_ns) {
                            if (ctx.allocator) |alloc| {
                                if (ctx.device_config) |dcfg| {
                                    if (dcfg.commands) |cmds| {
                                        const ff_type = if (dcfg.output) |out| if (out.force_feedback) |ff_cfg| ff_cfg.type else "rumble" else "rumble";
                                        if (cmds.map.get(ff_type)) |cmd| {
                                            const iface_idx: usize = @intCast(cmd.interface);
                                            if (iface_idx < ctx.devices.len) {
                                                const params = [_]Param{
                                                    .{ .name = "strong", .value = ff_ev.strong },
                                                    .{ .name = "weak", .value = ff_ev.weak },
                                                };
                                                if (fillTemplate(alloc, cmd.template, &params)) |bytes| {
                                                    defer alloc.free(bytes);
                                                    ctx.devices[iface_idx].write(bytes) catch {};
                                                    self.last_rumble_ns = now_ns;
                                                } else |_| {}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Check device fds
            for (ctx.devices, 0..) |dev, i| {
                const slot = self.device_base + i;
                if (slot >= self.fd_count) break;

                const revents = self.pollfds[slot].revents;
                const has_in = revents & posix.POLL.IN != 0;
                const has_hup = revents & (posix.POLL.HUP | posix.POLL.ERR) != 0;

                if (!has_in and has_hup) {
                    self.disconnected = true;
                    self.running = false;
                    break;
                }

                if (!has_in) continue;

                // Drain all available frames from this device
                while (true) {
                    const n = dev.read(&buf) catch |err| switch (err) {
                        error.Again => break,
                        error.Disconnected => {
                            self.disconnected = true;
                            self.running = false;
                            break;
                        },
                        error.Io => break,
                    };
                    if (n == 0) break;

                    const interface_id: u8 = if (ctx.device_config) |dcfg|
                        @intCast(dcfg.device.interface[i].id)
                    else
                        @intCast(i);

                    if (ctx.generic_state) |gs| {
                        // Generic path: match report, extract fields, emit directly
                        if (ctx.interpreter.matchReport(interface_id, buf[0..n])) |cr| {
                            if (buf[0..n].len >= @as(usize, @intCast(cr.src.size))) {
                                interpreter_mod.verifyChecksumCompiled(cr, buf[0..n]) catch continue;
                                generic.extractGenericFields(gs, buf[0..n]);
                                if (ctx.generic_output) |go| go.emitGeneric(gs) catch {};
                            }
                        }
                    } else {
                        // Gamepad path
                        const maybe_delta: ?GamepadStateDelta = blk: {
                            if (ctx.wasm_plugin) |wp| {
                                if (ctx.wasm_override_report) {
                                    var out_buf: [64]u8 = undefined;
                                    switch (wp.processReport(buf[0..n], &out_buf)) {
                                        .override => |d| break :blk d,
                                        .drop => break :blk null,
                                        .passthrough => {},
                                    }
                                }
                            }
                            break :blk ctx.interpreter.processReport(interface_id, buf[0..n]) catch null;
                        };
                        if (maybe_delta) |delta| {
                            if (ctx.mapper) |m| {
                                const events = m.apply(delta, dt_ms) catch |err| {
                                    std.log.err("mapper.apply failed: {}", .{err});
                                    continue;
                                };
                                if (events.timer_request) |tr| switch (tr) {
                                    .arm => |ms| armTimer(self.timer_fd, ms),
                                    .disarm => disarmTimer(self.timer_fd),
                                };
                                ctx.output.emit(events.gamepad) catch |err| {
                                    std.log.err("output.emit failed: {}", .{err});
                                    continue;
                                };
                                if (ctx.touchpad_output) |tp| tp.emitTouch(events.gamepad) catch {};
                                if (ctx.aux_output) |ao| {
                                    if (events.aux.len > 0) ao.emitAux(events.aux.slice()) catch {};
                                }
                            } else {
                                self.gamepad_state.applyDelta(delta);
                                self.gamepad_state.synthesizeDpadAxes();
                                ctx.output.emit(self.gamepad_state) catch |err| {
                                    std.log.err("output.emit failed: {}", .{err});
                                    continue;
                                };
                                if (ctx.touchpad_output) |tp| tp.emitTouch(self.gamepad_state) catch {};
                            }
                        }
                    }
                }
            }
        }
        self.running = false;
    }

    /// Interrupt a blocking ppoll in run() from another thread.
    pub fn stop(self: *EventLoop) void {
        _ = posix.write(self.stop_w, &[_]u8{1}) catch {};
    }

    pub fn deinit(self: *EventLoop) void {
        posix.close(self.signal_fd);
        posix.close(self.stop_r);
        posix.close(self.stop_w);
        posix.close(self.timer_fd);
    }
};

// --- tests ---

const testing = std.testing;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const uinput = @import("io/uinput.zig");

test "EventLoop.addUinputFf registers fd and increments fd_count" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const pfds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(pfds[0]);
    defer posix.close(pfds[1]);

    try loop.addUinputFf(pfds[0]);
    try testing.expectEqual(@as(usize, 4), loop.fd_count);
    try testing.expectEqual(@as(?usize, 3), loop.uinput_ff_slot);
    try testing.expectEqual(pfds[0], loop.pollfds[3].fd);
}

test "EventLoop: Disconnected device causes loop to exit without panic" {
    const allocator = testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    // Noop OutputDevice
    const NoopOutput = struct {
        fn emit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}
        fn pollFf(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
            return null;
        }
        fn close(_: *anyopaque) void {}
        const vtable = uinput.OutputDevice.VTable{ .emit = emit, .poll_ff = pollFf, .close = close };
    };
    var noop_sentinel: u8 = 0;
    const output = uinput.OutputDevice{ .ptr = &noop_sentinel, .vtable = &NoopOutput.vtable };

    const interp_toml =
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
    ;
    const config_device = @import("config/device.zig");
    const parsed_dev = try config_device.parseString(allocator, interp_toml);
    defer parsed_dev.deinit();
    const interp = Interpreter.init(&parsed_dev.value);

    var devs = [_]DeviceIO{dev};
    const ctx = EventLoopContext{
        .devices = &devs,
        .interpreter = &interp,
        .output = output,
        .poll_timeout_ms = 100,
    };

    // Inject disconnect before run() — loop should read Disconnected and exit
    try mock.injectDisconnect();

    try loop.run(ctx);
    try testing.expect(!loop.running);
}

test "EventLoop.initManaged creates eventfd and timerfd" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try testing.expect(loop.signal_fd >= 0);
    try testing.expect(loop.timer_fd >= 0);
    // slot 0 = eventfd, slot 1 = stop_pipe, slot 2 = timerfd
    try testing.expectEqual(@as(usize, 3), loop.fd_count);
}

test "EventLoop.stop wakes ppoll" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    loop.stop();
    var pfd = [1]posix.pollfd{.{ .fd = loop.stop_r, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 1), ready);
}

test "EventLoop.addDevice registers fd" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    try loop.addDevice(dev);
    // fd_count goes from 3 → 4, device is at slot 3
    try testing.expectEqual(@as(usize, 4), loop.fd_count);
    try testing.expectEqual(mock.pipe_r, loop.pollfds[3].fd);
}

test "EventLoop.addDevice rejects overflow" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    // Fill remaining slots (already have 3: signalfd + stop_pipe + timerfd)
    var mocks: [MAX_FDS - 3]MockDeviceIO = undefined;
    for (0..MAX_FDS - 3) |i| {
        mocks[i] = try MockDeviceIO.init(allocator, &.{});
    }
    defer for (0..MAX_FDS - 3) |i| mocks[i].deinit();

    for (0..MAX_FDS - 3) |i| {
        const dev = mocks[i].deviceIO();
        try loop.addDevice(dev);
    }
    var extra = try MockDeviceIO.init(allocator, &.{});
    defer extra.deinit();
    const extra_dev = extra.deviceIO();
    try testing.expectError(error.TooManyFds, loop.addDevice(extra_dev));
}

test "armTimer / disarmTimer: arm then disarm does not leave fd readable" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    armTimer(loop.timer_fd, 5000); // 5 seconds — will not fire during test
    disarmTimer(loop.timer_fd);

    // After disarm, timerfd should not be readable
    var pfd = [1]posix.pollfd{.{ .fd = loop.timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 0), ready);
}

test "armTimer: fires after timeout" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    armTimer(loop.timer_fd, 20); // 20ms

    var pfd = [1]posix.pollfd{.{ .fd = loop.timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    // Wait up to 200ms for the timer to fire
    const ready = try posix.poll(&pfd, 200);
    try testing.expectEqual(@as(usize, 1), ready);

    // Consume 8 bytes — must not block
    var expiry: [8]u8 = undefined;
    const n = try posix.read(loop.timer_fd, &expiry);
    try testing.expectEqual(@as(usize, 8), n);
}

test "EventLoop timerfd: mapper.onTimerExpired invoked on timer expiry" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    // Arm for 20ms, then run the loop
    armTimer(loop.timer_fd, 20);

    const mapper_empty = try mapping_mod.parseString(allocator,
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
    );
    defer mapper_empty.deinit();

    var m = try mapper_mod.Mapper.init(&mapper_empty.value, loop.timer_fd, allocator);
    defer m.deinit();

    // Put layer in PENDING so timer expiry advances it to ACTIVE
    _ = m.layer.onTriggerPress("aim", 200);

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const MockOut = struct {
        fn outputDevice() uinput.OutputDevice {
            return .{ .ptr = undefined, .vtable = &vtable };
        }
        const vtable = uinput.OutputDevice.VTable{
            .emit = mockEmit,
            .poll_ff = mockPollFf,
            .close = mockClose,
        };
        fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}
        fn mockPollFf(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
            return null;
        }
        fn mockClose(_: *anyopaque) void {}
    };

    const RunCtx = struct {
        loop: *EventLoop,
        elc: EventLoopContext,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .elc = .{ .devices = &devs, .interpreter = &interp, .output = MockOut.outputDevice(), .mapper = &m, .poll_timeout_ms = 100 },
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.elc);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(150 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // Timer expiry should have advanced aim layer from PENDING to ACTIVE
    try testing.expect(m.layer.tap_hold != null);
    try testing.expect(m.layer.tap_hold.?.layer_activated);
}

const MockOutput = @import("test/mock_output.zig").MockOutput;

// Minimal DeviceConfig + Interpreter for event loop tests
const device_mod = @import("config/device.zig");

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

test "EventLoop mini: device frame dispatched to interpreter and output" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    // frame: match byte 0x01, left_x = 500 (i16le)
    var frame: [3]u8 = undefined;
    frame[0] = 0x01;
    std.mem.writeInt(i16, frame[1..3], 500, .little);

    var mock = try MockDeviceIO.init(allocator, &.{&frame});
    defer mock.deinit();
    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var out = MockOutput.init(allocator);
    defer out.deinit();
    const output = out.outputDevice();

    try mock.signal();

    const RunCtx = struct {
        loop: *EventLoop,
        elc: EventLoopContext,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .elc = .{ .devices = &devs, .interpreter = &interp, .output = output, .poll_timeout_ms = 100 },
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.elc);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(i16, 500), loop.gamepad_state.ax);
    try testing.expectEqual(@as(usize, 1), out.diffs.items.len);
    try testing.expectEqual(@as(?i16, 500), out.diffs.items[0].ax);
}

// T4: FF routing tests

const ff_toml =
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
    \\[commands.rumble]
    \\interface = 0
    \\template = "00 08 00 {strong:u8} {weak:u8} 00 00 00"
;

const MockFfOutput = struct {
    allocator: std.mem.Allocator,
    ff_event: ?uinput.FfEvent,
    call_count: usize = 0,

    fn outputDevice(self: *MockFfOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(_: *anyopaque, _: state.GamepadState) uinput.EmitError!void {}

    fn mockPollFf(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *MockFfOutput = @ptrCast(@alignCast(ptr));
        if (self.call_count == 0) {
            self.call_count += 1;
            return self.ff_event;
        }
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "event_loop: FF event routed to DeviceIO.write via fillTemplate" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    // FF wake pipe: write side signals readiness
    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    // Signal uinput FF fd ready, then stop
    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // strong=0x8000 >> 8 = 0x80, weak=0x4000 >> 8 = 0x40
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x08, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00 }, mock_dev.write_log.items);
}

test "event_loop: no commands.rumble — silent skip" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    // Config has no [commands] section
    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // No write should have occurred
    try testing.expectEqual(@as(usize, 0), mock_dev.write_log.items.len);
}

const custom_ff_toml =
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
    \\[output.force_feedback]
    \\type = "custom_ff"
    \\max_effects = 16
    \\[commands.rumble]
    \\interface = 0
    \\template = "ff ff ff ff"
    \\[commands.custom_ff]
    \\interface = 0
    \\template = "aa {strong:u8} {weak:u8} bb"
;

test "event_loop: config-driven FF command key — output.force_feedback.type overrides default rumble" {
    const allocator = testing.allocator;

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    const dev = mock_dev.deviceIO();
    try loop.addDevice(dev);

    const ff_pipe = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(ff_pipe[0]);
    defer posix.close(ff_pipe[1]);
    try loop.addUinputFf(ff_pipe[0]);

    const parsed = try device_mod.parseString(allocator, custom_ff_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ff_out = MockFfOutput{
        .allocator = allocator,
        .ff_event = .{ .effect_type = 0x50, .strong = 0x8000, .weak = 0x4000 },
    };

    const RunCtx = struct {
        loop: *EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        ff_out: *MockFfOutput,
        cfg: *const device_mod.DeviceConfig,
        alloc: std.mem.Allocator,
    };
    var devs = [_]DeviceIO{dev};
    var ctx = RunCtx{
        .loop = &loop,
        .devs = &devs,
        .interp = &interp,
        .ff_out = &ff_out,
        .cfg = &parsed.value,
        .alloc = allocator,
    };

    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.ff_out.outputDevice(), .allocator = c.alloc, .device_config = c.cfg, .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});

    _ = try posix.write(ff_pipe[1], &[_]u8{1});
    std.Thread.sleep(20 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    // custom_ff template: "aa {strong:u8} {weak:u8} bb"
    // strong=0x8000 >> 8 = 0x80, weak=0x4000 >> 8 = 0x40
    // Must NOT match "ff ff ff ff" (the rumble template)
    try testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0x80, 0x40, 0xbb }, mock_dev.write_log.items);
}

// --- T8/T9: Adaptive trigger tests ---

const command = @import("core/command.zig");
const mapping_mod = @import("config/mapping.zig");

test "buildAdaptiveTriggerParams: maps left/right values with shift" {
    const at = mapping_mod.AdaptiveTriggerConfig{
        .mode = "feedback",
        .right = .{ .position = 40, .strength = 180 },
        .left = .{ .position = 70, .strength = 200 },
    };
    var buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&buf, &at);
    try testing.expectEqual(@as(usize, 12), params.len);
    // r_position = 40 << 8
    try testing.expectEqualStrings("r_position", params[0].name);
    try testing.expectEqual(@as(u16, 40 << 8), params[0].value);
    // r_strength = 180 << 8
    try testing.expectEqualStrings("r_strength", params[1].name);
    try testing.expectEqual(@as(u16, 180 << 8), params[1].value);
    // l_position = 70 << 8
    try testing.expectEqualStrings("l_position", params[6].name);
    try testing.expectEqual(@as(u16, 70 << 8), params[6].value);
    // l_strength = 200 << 8
    try testing.expectEqualStrings("l_strength", params[7].name);
    try testing.expectEqual(@as(u16, 200 << 8), params[7].value);
}

test "buildAdaptiveTriggerParams: null params default to 0" {
    const at = mapping_mod.AdaptiveTriggerConfig{ .mode = "off" };
    var buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&buf, &at);
    for (params) |p| {
        try testing.expectEqual(@as(u16, 0), p.value);
    }
}

test "fillTemplate: adaptive trigger feedback template produces correct bytes" {
    const allocator = testing.allocator;
    const template = "02 0c 00 00 00 00 00 00 00 00 00 01 {r_position:u8} {r_strength:u8} 00 00 00 00 00 00 00 00 01 {l_position:u8} {l_strength:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00";
    const at = mapping_mod.AdaptiveTriggerConfig{
        .mode = "feedback",
        .right = .{ .position = 40, .strength = 180 },
        .left = .{ .position = 70, .strength = 200 },
    };
    var buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&buf, &at);
    const result = try command.fillTemplate(allocator, template, params);
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    // byte 0 = report ID 0x02
    try testing.expectEqual(@as(u8, 0x02), result[0]);
    // byte 1 = valid_flag0 0x0c
    try testing.expectEqual(@as(u8, 0x0c), result[1]);
    // byte 11 = right mode 0x01
    try testing.expectEqual(@as(u8, 0x01), result[11]);
    // byte 12 = r_position = 40
    try testing.expectEqual(@as(u8, 40), result[12]);
    // byte 13 = r_strength = 180
    try testing.expectEqual(@as(u8, 180), result[13]);
    // byte 22 = left mode 0x01
    try testing.expectEqual(@as(u8, 0x01), result[22]);
    // byte 23 = l_position = 70
    try testing.expectEqual(@as(u8, 70), result[23]);
    // byte 24 = l_strength = 200
    try testing.expectEqual(@as(u8, 200), result[24]);
}

test "fillTemplate: adaptive trigger off template is all zeros except report ID and flags" {
    const allocator = testing.allocator;
    const template = "02 0c 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00";
    const result = try command.fillTemplate(allocator, template, &.{});
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    try testing.expectEqual(@as(u8, 0x02), result[0]);
    try testing.expectEqual(@as(u8, 0x0c), result[1]);
    for (result[2..]) |b| {
        try testing.expectEqual(@as(u8, 0), b);
    }
}

test "applyAdaptiveTrigger: round-trip mapping config to device write" {
    const allocator = testing.allocator;

    const at_toml =
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
        \\[commands.adaptive_trigger_feedback]
        \\interface = 0
        \\template = "02 0c 00 00 00 00 00 00 00 00 00 01 {r_position:u8} {r_strength:u8} 00 00 00 00 00 00 00 00 01 {l_position:u8} {l_strength:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    ;
    const parsed = try device_mod.parseString(allocator, at_toml);
    defer parsed.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    var devs = [_]DeviceIO{mock_dev.deviceIO()};

    const at_cfg = mapping_mod.AdaptiveTriggerConfig{
        .mode = "feedback",
        .right = .{ .position = 50, .strength = 128 },
        .left = .{ .position = 90, .strength = 255 },
    };

    applyAdaptiveTrigger(&devs, allocator, &parsed.value, &at_cfg);

    // Should have written 63 bytes
    try testing.expectEqual(@as(usize, 63), mock_dev.write_log.items.len);
    // Verify key bytes
    try testing.expectEqual(@as(u8, 0x02), mock_dev.write_log.items[0]);
    try testing.expectEqual(@as(u8, 0x0c), mock_dev.write_log.items[1]);
    try testing.expectEqual(@as(u8, 50), mock_dev.write_log.items[12]); // r_position
    try testing.expectEqual(@as(u8, 128), mock_dev.write_log.items[13]); // r_strength
    try testing.expectEqual(@as(u8, 90), mock_dev.write_log.items[23]); // l_position
    try testing.expectEqual(@as(u8, 255), mock_dev.write_log.items[24]); // l_strength
}

test "applyAdaptiveTrigger: unknown mode silently skips" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseString(allocator, minimal_toml);
    defer parsed.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    var devs = [_]DeviceIO{mock_dev.deviceIO()};

    const at_cfg = mapping_mod.AdaptiveTriggerConfig{ .mode = "nonexistent" };
    applyAdaptiveTrigger(&devs, allocator, &parsed.value, &at_cfg);

    try testing.expectEqual(@as(usize, 0), mock_dev.write_log.items.len);
}

test "applyAdaptiveTrigger: custom command_prefix routes correctly" {
    const allocator = testing.allocator;

    const toml_str =
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
        \\[commands.my_at_feedback]
        \\interface = 0
        \\template = "aa {r_position:u8} {l_position:u8}"
    ;
    const parsed = try device_mod.parseString(allocator, toml_str);
    defer parsed.deinit();

    var mock_dev = try MockDeviceIO.init(allocator, &.{});
    defer mock_dev.deinit();
    var devs = [_]DeviceIO{mock_dev.deviceIO()};

    const at_cfg = mapping_mod.AdaptiveTriggerConfig{
        .mode = "feedback",
        .command_prefix = "my_at_",
        .right = .{ .position = 10 },
        .left = .{ .position = 20 },
    };
    applyAdaptiveTrigger(&devs, allocator, &parsed.value, &at_cfg);

    try testing.expectEqual(@as(usize, 3), mock_dev.write_log.items.len);
    try testing.expectEqual(@as(u8, 0xaa), mock_dev.write_log.items[0]);
    try testing.expectEqual(@as(u8, 10), mock_dev.write_log.items[1]);
    try testing.expectEqual(@as(u8, 20), mock_dev.write_log.items[2]);
}
