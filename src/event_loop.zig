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
const command = @import("core/command.zig");
const fillTemplate = command.fillTemplate;
const applyChecksum = command.applyChecksum;
const Param = command.Param;
const AdaptiveTriggerConfig = @import("config/mapping.zig").AdaptiveTriggerConfig;
const MappingConfig = @import("config/mapping.zig").MappingConfig;
const wasm_runtime = @import("wasm/runtime.zig");
pub const WasmPlugin = wasm_runtime.WasmPlugin;
const rumble_scheduler_mod = @import("core/rumble_scheduler.zig");
const RumbleScheduler = rumble_scheduler_mod.RumbleScheduler;
const rumble_log = std.log.scoped(.rumble);
const padctl_log = @import("log.zig");

// Fixed poll slots for the event loop.
pub const Slots = struct {
    pub const signal: usize = 0;
    pub const stop: usize = 1;
    pub const layer_timer: usize = 2;
    pub const rumble_stop: usize = 3;
    pub const macro_timer: usize = 4;
    pub const device_base: usize = 5;
};

// signal + stop + layer_timer + rumble_stop + macro_timer = 5 fixed; up to 6 device interfaces + 1 FF/uinput slot.
pub const FIXED_SLOT_COUNT: usize = 5;
pub const MAX_DEVICE_INTERFACES: usize = 6;
pub const MAX_FDS: usize = FIXED_SLOT_COUNT + MAX_DEVICE_INTERFACES + 1;

const signalfd_siginfo_size = 128;

pub const TimerCallback = struct {
    ptr: *anyopaque,
    on_expired: *const fn (*anyopaque) void,

    pub fn call(self: TimerCallback) void {
        self.on_expired(self.ptr);
    }
};

/// Returns the current CLOCK_MONOTONIC time in nanoseconds.
///
/// Scheduler deadlines and timerfd arm paths use this in preference to
/// `std.time.nanoTimestamp()` because Zig 0.15's nanoTimestamp is backed
/// by CLOCK_REALTIME on Linux. Since padctl's timerfds are created with
/// CLOCK_MONOTONIC, mixing clock sources would cause auto-stop deadlines
/// to fire early, late, or disappear whenever wall time jumps (NTP slew,
/// suspend/resume, manual clock set). CLOCK_MONOTONIC matches the
/// timerfd clock and is immune to wall-time discontinuities.
///
/// clock_gettime(.MONOTONIC) cannot fail on any supported Linux kernel,
/// but we defensively coerce any error to 0 rather than propagating.
pub fn monotonicNs() i128 {
    const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
    return @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
}

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

/// Arm or disarm the rumble auto-stop timerfd using an absolute
/// CLOCK_MONOTONIC deadline. `deadline_ns == null` → disarm.
///
/// Uses `TFD_TIMER.ABSTIME` so the kernel handles the delta against its
/// own monotonic clock. No caller-side "now" read is needed, and there
/// is no opportunity for the arm delta to be computed against a
/// different clock than the one the timerfd fires against.
fn armRumbleStopFd(fd: posix.fd_t, deadline_ns: ?i128) void {
    const target = deadline_ns orelse {
        disarmTimer(fd);
        return;
    };
    // Guard: ABSTIME with it_value.{sec,nsec} == 0 would disarm the
    // timer. A deadline in the past (or exactly 0) should still fire
    // ASAP, so clamp to 1ns.
    const target_clamped: i128 = if (target > 0) target else 1;
    const spec = linux.itimerspec{
        .it_value = .{
            .sec = @intCast(@divFloor(target_clamped, std.time.ns_per_s)),
            .nsec = @intCast(@mod(target_clamped, std.time.ns_per_s)),
        },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    const rc = linux.timerfd_settime(fd, .{ .ABSTIME = true }, &spec, null);
    if (rc != 0) {
        const errno = std.posix.errno(rc);
        rumble_log.debug("TIMERFD: timerfd_settime FAILED errno={s} deadline={d}", .{
            @tagName(errno), target,
        });
    }
}

/// Returns true when this device's config wants userspace rumble auto-stop.
/// Defaults to true when `[output.force_feedback]` is absent or does not
/// explicitly set `auto_stop`.
fn autoStopEnabled(dcfg: ?*const DeviceConfig) bool {
    const cfg = dcfg orelse return true;
    const out = cfg.output orelse return true;
    const ff = out.force_feedback orelse return true;
    return ff.auto_stop;
}

/// Format scheduler slot state with relative deltas from now_ns.
/// Shows: slots=[0:INF, 1:+250ms, 3:+1200ms] or slots=[empty]
fn fmtSchedulerSlots(slots: [rumble_scheduler_mod.MAX_EFFECTS]i128, now_ns: i128) [256]u8 {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();
    w.writeAll("slots=[") catch {};
    var any = false;
    for (slots, 0..) |s, i| {
        if (s == 0) continue;
        if (any) w.writeAll(", ") catch {};
        any = true;
        if (s == RumbleScheduler.INFINITE) {
            w.print("{d}:INF", .{i}) catch {};
        } else {
            const delta_ms = @divFloor(s - now_ns, std.time.ns_per_ms);
            w.print("{d}:{s}{d}ms", .{ i, if (delta_ms >= 0) "+" else "", delta_ms }) catch {};
        }
    }
    if (!any) w.writeAll("empty") catch {};
    w.writeAll("]") catch {};
    const written = fbs.getWritten().len;
    if (written < buf.len) buf[written] = 0;
    return buf;
}

fn slotStr(buf: *const [256]u8) []const u8 {
    // Find the null terminator or end of buffer.
    for (buf, 0..) |b, i| {
        if (b == 0) return buf[0..i];
    }
    return buf;
}

/// Write a single rumble frame (strong, weak) to the HID device using the
/// device's `commands.rumble` (or alternate FF type) template. Used by
/// both the uinput-FF-event path and the userspace auto-stop timerfd path.
/// Returns true if the frame was successfully written to HID. Callers
/// must only advance scheduler/throttle state when this returns true.
fn emitRumbleFrame(
    devices: []DeviceIO,
    alloc: std.mem.Allocator,
    dcfg: *const DeviceConfig,
    strong: u16,
    weak: u16,
    tag: []const u8,
) bool {
    const cmds = dcfg.commands orelse return false;
    const ff_type = if (dcfg.output) |out|
        if (out.force_feedback) |ff_cfg| ff_cfg.type else "rumble"
    else
        "rumble";
    const cmd = cmds.map.get(ff_type) orelse return false;
    const iface_idx = resolveIfaceIdx(dcfg, cmd.interface) orelse return false;
    if (iface_idx >= devices.len) return false;
    const params = [_]Param{
        .{ .name = "strong", .value = strong },
        .{ .name = "weak", .value = weak },
    };
    const bytes = fillTemplate(alloc, cmd.template, &params) catch return false;
    defer alloc.free(bytes);
    if (cmd.checksum) |*cs| applyChecksum(bytes, cs);

    // Log the full post-checksum HID frame — but only when dump is on;
    // otherwise the hex-dump loop runs unconditionally on every rumble
    // frame (100+ Hz during gameplay) even with nothing listening.
    if (padctl_log.shouldWriteToFile(.debug)) {
        var hex_buf: [512]u8 = undefined;
        var hex_fbs = std.io.fixedBufferStream(&hex_buf);
        const hw = hex_fbs.writer();
        for (bytes) |b| {
            hw.print("{x:0>2} ", .{b}) catch break;
        }
        rumble_log.debug("[{s}] HID_WRITE: cmd={s} strong={d} weak={d} iface={d} len={d} frame=[{s}]", .{
            tag, ff_type, strong, weak, iface_idx, bytes.len, hex_fbs.getWritten(),
        });
    }

    devices[iface_idx].write(bytes) catch |err| {
        rumble_log.debug("[{s}] HID_WRITE: FAILED cmd={s} strong={d} weak={d} err={}", .{ tag, ff_type, strong, weak, err });
        return false;
    };
    return true;
}

/// Disarm a timerfd by setting all fields to zero.
pub fn disarmTimer(fd: posix.fd_t) void {
    const spec = linux.itimerspec{
        .it_value = .{ .sec = 0, .nsec = 0 },
        .it_interval = .{ .sec = 0, .nsec = 0 },
    };
    const rc = linux.timerfd_settime(fd, .{}, &spec, null);
    if (rc != 0) {
        rumble_log.debug("TIMERFD: disarm FAILED rc={d}", .{rc});
    }
}

pub const EventLoopContext = struct {
    devices: []DeviceIO,
    interpreter: *const Interpreter,
    output: OutputDevice,
    mapper: ?*mapper_mod.Mapper = null,
    aux_output: ?AuxOutputDevice = null,
    touchpad_output: ?TouchpadOutputDevice = null,
    /// Phase 13 Wave 3: optional IMU companion output. Populated when the
    /// UHID backend is active and `[output.imu]` is present. `emit` receives
    /// the same `GamepadState` as the primary — the IMU encoder reads only
    /// accel/gyro axes and ignores the rest.
    imu_output: ?OutputDevice = null,
    allocator: ?std.mem.Allocator = null,
    device_config: ?*const DeviceConfig = null,
    mapping_config: ?*const MappingConfig = null,
    poll_timeout_ms: ?u32 = null,
    wasm_plugin: ?WasmPlugin = null,
    wasm_override_report: bool = false,
    generic_state: ?*GenericDeviceState = null,
    generic_output: ?GenericOutputDevice = null,
    /// Device name for log correlation (set from device_config.device.name).
    device_tag: []const u8 = "unknown",
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

/// Resolve a USB interface ID to the devices array index by matching
/// against the device config's interface list.  Returns null when the
/// interface ID is not found.
fn resolveIfaceIdx(dcfg: *const DeviceConfig, iface_id: i64) ?usize {
    for (dcfg.device.interface, 0..) |iface, i| {
        if (iface.id == iface_id) return i;
    }
    return null;
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
        if (cmd.checksum) |*cs| command.applyChecksum(bytes, cs);
        if (resolveIfaceIdx(dcfg, cmd.interface)) |idx| {
            if (idx < devices.len) {
                devices[idx].write(bytes) catch {};
            }
        }
    } else |_| {}
}

pub const EventLoop = struct {
    pollfds: [MAX_FDS]posix.pollfd,
    fd_count: usize,
    signal_fd: posix.fd_t,
    stop_r: posix.fd_t,
    stop_w: posix.fd_t,
    // device fds start at slot 5 (after signalfd + stop_pipe + timer_fd + rumble_stop_fd + macro_timer_fd)
    device_base: usize,
    /// Dedicated timerfd for layer hold-trigger arm/disarm (slot 2).
    /// Written by `timer_request` returned from `Mapper.apply()`.
    timer_fd: posix.fd_t,
    /// Dedicated timerfd for userspace rumble auto-stop (slot 3).
    rumble_stop_fd: posix.fd_t,
    /// Dedicated timerfd for macro delay / TimerQueue (slot 4).
    /// Passed to `Mapper.init` so `TimerQueue` arms only this fd, keeping
    /// it independent from the layer-hold `timer_fd`.
    macro_timer_fd: posix.fd_t,
    /// State machine that tracks per-effect deadlines and decides when
    /// to fire a stop frame. See src/core/rumble_scheduler.zig.
    rumble_scheduler: RumbleScheduler,
    uinput_ff_slot: ?usize,
    disconnected: bool,
    running: bool,
    gamepad_state: state.GamepadState,
    last_ts: i128,
    last_rumble_ns: i128,
    last_heartbeat_ns: i128 = 0,

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

        const rumble_stop_fd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
        errdefer posix.close(rumble_stop_fd);

        const macro_timer_fd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
        errdefer posix.close(macro_timer_fd);

        var loop = EventLoop{
            .pollfds = undefined,
            .fd_count = 0,
            .signal_fd = sig_fd,
            .stop_r = stop_r,
            .stop_w = stop_w,
            .device_base = 0,
            .timer_fd = timer_fd,
            .rumble_stop_fd = rumble_stop_fd,
            .rumble_scheduler = .{},
            .macro_timer_fd = macro_timer_fd,
            .uinput_ff_slot = null,
            .disconnected = false,
            .running = false,
            .gamepad_state = .{},
            .last_ts = monotonicNs(),
            .last_rumble_ns = 0,
        };

        loop.pollfds[Slots.signal] = .{ .fd = sig_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[Slots.stop] = .{ .fd = stop_r, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[Slots.layer_timer] = .{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[Slots.rumble_stop] = .{ .fd = rumble_stop_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.pollfds[Slots.macro_timer] = .{ .fd = macro_timer_fd, .events = posix.POLL.IN, .revents = 0 };
        loop.fd_count = FIXED_SLOT_COUNT;
        loop.device_base = Slots.device_base;

        return loop;
    }

    pub fn addDevice(self: *EventLoop, device: DeviceIO) !void {
        const slot = self.fd_count;
        if (slot >= MAX_FDS) return error.TooManyFds;
        self.pollfds[slot] = device.pollfd();
        self.fd_count += 1;
    }

    /// Replace pollfd entries for device slots with fds from new DeviceIO
    /// slice. The number of devices must match the original count.
    pub fn rebindDevices(self: *EventLoop, devices: []DeviceIO) void {
        for (devices, 0..) |dev, i| {
            self.pollfds[self.device_base + i] = dev.pollfd();
        }
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
        var buf: [512]u8 = undefined;

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

            const now = monotonicNs();
            const dt_ns = now - self.last_ts;
            const dt_ms: u32 = @intCast(@min(100, @max(1, @divFloor(dt_ns, 1_000_000))));
            self.last_ts = now;

            // Heartbeat: log every 60s to confirm daemon is alive and trigger
            // log file reopen if the file was deleted.
            const heartbeat_interval: i128 = 60 * std.time.ns_per_s;
            if (now - self.last_heartbeat_ns >= heartbeat_interval) {
                self.last_heartbeat_ns = now;
                if (padctl_log.shouldWriteToFile(.debug)) {
                    const slot_buf = fmtSchedulerSlots(self.rumble_scheduler.dumpSlots(), now);
                    rumble_log.debug("[{s}] HEARTBEAT: alive {s}", .{ ctx.device_tag, slotStr(&slot_buf) });
                }
            }

            // Check signalfd (slot 0)
            if (self.pollfds[Slots.signal].revents & posix.POLL.IN != 0) {
                var siginfo: [signalfd_siginfo_size]u8 = undefined;
                _ = posix.read(self.signal_fd, &siginfo) catch {};
                break;
            }

            // Check stop pipe (slot 1) — drain byte and return to caller
            if (self.pollfds[Slots.stop].revents & posix.POLL.IN != 0) {
                var drain: [1]u8 = undefined;
                _ = posix.read(self.stop_r, &drain) catch {};
                break;
            }

            // Layer timerfd (slot 2) is handled inline; macro timerfd (slot 4) is
            // drained after the device fd loop below — see issue #79.

            // Check rumble auto-stop timerfd (slot 3).
            if (self.pollfds[Slots.rumble_stop].revents & posix.POLL.IN != 0) {
                var rs_expiry: [8]u8 = undefined;
                _ = posix.read(self.rumble_stop_fd, &rs_expiry) catch {};
                const now_ns = monotonicNs();
                const result = self.rumble_scheduler.onTimerExpired(now_ns);
                if (padctl_log.shouldWriteToFile(.debug)) {
                    const slot_buf = fmtSchedulerSlots(self.rumble_scheduler.dumpSlots(), now_ns);
                    rumble_log.debug("[{s}] TIMERFD: expired now={d} emit_stop={} next_dl={?d} {s}", .{
                        ctx.device_tag, now_ns, result.emit_stop_frame, result.next_deadline_ns, slotStr(&slot_buf),
                    });
                }
                if (result.emit_stop_frame) {
                    if (ctx.allocator) |alloc| {
                        if (ctx.device_config) |dcfg| {
                            if (!emitRumbleFrame(ctx.devices, alloc, dcfg, 0, 0, ctx.device_tag)) {
                                rumble_log.debug("[{s}] TIMERFD: stop frame FAILED to emit", .{ctx.device_tag});
                            }
                        }
                    }
                }
                armRumbleStopFd(self.rumble_stop_fd, result.next_deadline_ns);
            }

            // Check uinput FF fd.
            if (self.uinput_ff_slot) |slot| {
                if (self.pollfds[slot].revents & posix.POLL.IN != 0) {
                    const ff_result = ctx.output.pollFf() catch |err| blk: {
                        rumble_log.debug("[{s}] FF_ERROR: pollFf failed err={}", .{ ctx.device_tag, err });
                        break :blk null;
                    };
                    if (ff_result) |ff_ev| {
                        const now_ns = monotonicNs();
                        const min_interval_ns: i128 = 10_000_000; // 10ms
                        const is_stop = ff_ev.strong == 0 and ff_ev.weak == 0;
                        const scheduler_on = autoStopEnabled(ctx.device_config);

                        rumble_log.debug("[{s}] FF_EVENT: id={d} strong={d} weak={d} dur={d}ms is_stop={} sched_on={}", .{
                            ctx.device_tag,    ff_ev.effect_id, ff_ev.strong, ff_ev.weak,
                            ff_ev.duration_ms, is_stop,         scheduler_on,
                        });

                        if (is_stop) {
                            if (scheduler_on) {
                                const result = self.rumble_scheduler.onStop(ff_ev.effect_id);
                                if (padctl_log.shouldWriteToFile(.debug)) {
                                    const slot_buf = fmtSchedulerSlots(self.rumble_scheduler.dumpSlots(), now_ns);
                                    rumble_log.debug("[{s}] FF_STOP: id={d} emit_stop={} next_dl={?d} {s}", .{
                                        ctx.device_tag,          ff_ev.effect_id,    result.emit_stop_frame,
                                        result.next_deadline_ns, slotStr(&slot_buf),
                                    });
                                }
                                if (result.emit_stop_frame) {
                                    if (ctx.allocator) |alloc| {
                                        if (ctx.device_config) |dcfg| {
                                            if (!emitRumbleFrame(ctx.devices, alloc, dcfg, 0, 0, ctx.device_tag)) {
                                                rumble_log.debug("[{s}] FF_STOP: stop frame FAILED to emit", .{ctx.device_tag});
                                            }
                                        }
                                    }
                                }
                                armRumbleStopFd(self.rumble_stop_fd, result.next_deadline_ns);
                            } else {
                                rumble_log.debug("[{s}] FF_STOP: auto_stop disabled, direct zero frame", .{ctx.device_tag});
                                if (ctx.allocator) |alloc| {
                                    if (ctx.device_config) |dcfg| {
                                        if (!emitRumbleFrame(ctx.devices, alloc, dcfg, 0, 0, ctx.device_tag)) {
                                            rumble_log.debug("[{s}] FF_STOP: direct zero frame FAILED to emit", .{ctx.device_tag});
                                        }
                                    }
                                }
                            }
                        } else {
                            // Play event: throttle applies to play frames.
                            var forwarded = false;
                            const elapsed = now_ns - self.last_rumble_ns;
                            if (elapsed >= min_interval_ns) {
                                if (ctx.allocator) |alloc| {
                                    if (ctx.device_config) |dcfg| {
                                        if (emitRumbleFrame(ctx.devices, alloc, dcfg, ff_ev.strong, ff_ev.weak, ctx.device_tag)) {
                                            self.last_rumble_ns = now_ns;
                                            forwarded = true;
                                        } else {
                                            rumble_log.debug("[{s}] FF_PLAY: emitRumbleFrame FAILED id={d}", .{ ctx.device_tag, ff_ev.effect_id });
                                        }
                                    }
                                }
                            } else {
                                rumble_log.debug("[{s}] FF_PLAY: THROTTLED id={d} elapsed={d}ns", .{
                                    ctx.device_tag,                                          ff_ev.effect_id,
                                    @as(u64, @intCast(@min(elapsed, std.math.maxInt(u64)))),
                                });
                            }
                            if (scheduler_on and forwarded) {
                                const next_dl = self.rumble_scheduler.onPlay(
                                    ff_ev.effect_id,
                                    ff_ev.duration_ms,
                                    now_ns,
                                );
                                if (padctl_log.shouldWriteToFile(.debug)) {
                                    const slot_buf = fmtSchedulerSlots(self.rumble_scheduler.dumpSlots(), now_ns);
                                    rumble_log.debug("[{s}] FF_PLAY: id={d} dur={d}ms next_dl={?d} {s}", .{
                                        ctx.device_tag, ff_ev.effect_id,    ff_ev.duration_ms,
                                        next_dl,        slotStr(&slot_buf),
                                    });
                                }
                                armRumbleStopFd(self.rumble_stop_fd, next_dl);
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
                    if (padctl_log.shouldWriteToFile(.debug)) {
                        const disc_now = monotonicNs();
                        const disc_slots = fmtSchedulerSlots(self.rumble_scheduler.dumpSlots(), disc_now);
                        rumble_log.debug("[{s}] DISCONNECT: HUP/ERR on device slot {d} {s}", .{
                            ctx.device_tag, slot, slotStr(&disc_slots),
                        });
                    }
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
                            self.gamepad_state.applyDelta(delta);

                            if (ctx.mapper) |m| {
                                const events = m.apply(delta, dt_ms, now) catch |err| {
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
                                if (ctx.imu_output) |imu_out| {
                                    imu_out.emit(events.gamepad) catch |err| {
                                        std.log.warn("imu emit failed: {}", .{err});
                                    };
                                }
                                if (ctx.touchpad_output) |tp| tp.emitTouch(events.gamepad) catch {};
                                if (ctx.aux_output) |ao| {
                                    if (events.aux.len > 0) ao.emitAux(events.aux.slice()) catch {};
                                }
                            } else {
                                self.gamepad_state.synthesizeDpadAxes();
                                ctx.output.emit(self.gamepad_state) catch |err| {
                                    std.log.err("output.emit failed: {}", .{err});
                                    continue;
                                };
                                if (ctx.imu_output) |imu_out| {
                                    imu_out.emit(self.gamepad_state) catch |err| {
                                        std.log.warn("imu emit failed: {}", .{err});
                                    };
                                }
                                if (ctx.touchpad_output) |tp| tp.emitTouch(self.gamepad_state) catch {};
                            }
                        }
                    }
                }
            }

            // Layer timerfd (slot 2): drained after device fds so an
            // on-wakeup tap release reaches apply() before PENDING is
            // promoted to ACTIVE (issue #79). Routes to the layer-only
            // expiry handler so a concurrent macro fd expiry on slot 4
            // does not cause the layer half to run twice.
            if (self.pollfds[Slots.layer_timer].revents & posix.POLL.IN != 0) {
                var expiry: [8]u8 = undefined;
                _ = posix.read(self.timer_fd, &expiry) catch {};
                if (ctx.mapper) |m| {
                    const aux = m.onLayerTimerExpired();
                    if (aux.len > 0) {
                        if (ctx.aux_output) |ao| ao.emitAux(aux.slice()) catch {};
                    }
                }
            }

            // Macro timerfd (slot 4): separate fd so macro delays cannot be
            // clobbered by layer-hold arm/disarm (issue #72). Routes to the
            // macro-only expiry handler — must not promote a PENDING layer
            // when a macro `delay` shorter than hold_timeout fires.
            if (self.pollfds[Slots.macro_timer].revents & posix.POLL.IN != 0) {
                var expiry: [8]u8 = undefined;
                _ = posix.read(self.macro_timer_fd, &expiry) catch {};
                if (ctx.mapper) |m| {
                    const macro_aux = m.onMacroTimerExpired(now);
                    if (macro_aux.len > 0) {
                        if (ctx.aux_output) |ao| ao.emitAux(macro_aux.slice()) catch {};
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
        posix.close(self.rumble_stop_fd);
        posix.close(self.macro_timer_fd);
    }
};

// --- tests ---

const testing = std.testing;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const uinput = @import("io/uinput.zig");

test "event_loop: monotonicNs is backed by CLOCK_MONOTONIC (not wall clock)" {
    // All scheduler deadlines and timerfd arm computations MUST come from
    // CLOCK_MONOTONIC so NTP slews, suspend/resume, and manual wall-clock
    // adjustments cannot make auto-stop deadlines fire early, late, or be
    // lost entirely. Zig 0.15's std.time.nanoTimestamp() returns
    // CLOCK_REALTIME on Linux, so padctl uses this local monotonicNs()
    // helper instead. This test pins the implementation.
    const a = monotonicNs();
    const ts = try posix.clock_gettime(.MONOTONIC);
    const mono: i128 = @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);

    // Our helper and a direct clock_gettime(.MONOTONIC) read must agree
    // within a generous 10ms window (test execution overhead + scheduler
    // jitter). Anything beyond that means monotonicNs is reading a
    // different clock.
    const diff: i128 = if (a > mono) a - mono else mono - a;
    try testing.expect(diff < 10 * std.time.ns_per_ms);

    // Must be strictly positive and monotonically non-decreasing.
    try testing.expect(a > 0);
    const b = monotonicNs();
    try testing.expect(b >= a);
}

test "event_loop: EventLoop.addUinputFf registers fd and increments fd_count" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const pfds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(pfds[0]);
    defer posix.close(pfds[1]);

    try loop.addUinputFf(pfds[0]);
    // Fixed slots 0..4 are signalfd, stop_pipe, layer timer_fd,
    // rumble_stop_fd, macro_timer_fd; the FF fd becomes slot 5,
    // fd_count goes 5 → 6.
    try testing.expectEqual(@as(usize, 6), loop.fd_count);
    try testing.expectEqual(@as(?usize, 5), loop.uinput_ff_slot);
    try testing.expectEqual(pfds[0], loop.pollfds[Slots.device_base].fd);
}

test "event_loop: EventLoop: Disconnected device causes loop to exit without panic" {
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

test "event_loop: EventLoop.initManaged creates eventfd and timerfds" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    try testing.expect(loop.signal_fd >= 0);
    try testing.expect(loop.timer_fd >= 0);
    try testing.expect(loop.rumble_stop_fd >= 0);
    // slot 0 = eventfd, slot 1 = stop_pipe, slot 2 = layer timer_fd,
    // slot 3 = rumble-stop timerfd, slot 4 = macro timerfd
    try testing.expect(loop.macro_timer_fd >= 0);
    try testing.expectEqual(@as(usize, 5), loop.fd_count);
}

test "event_loop: EventLoop.stop wakes ppoll" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();
    loop.stop();
    var pfd = [1]posix.pollfd{.{ .fd = loop.stop_r, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 1), ready);
}

test "event_loop: EventLoop.addDevice registers fd" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    try loop.addDevice(dev);
    // Fixed slots: 0=signalfd, 1=stop_pipe, 2=layer timer_fd,
    // 3=rumble_stop_fd, 4=macro timerfd. First device lands at slot 5,
    // fd_count goes 5 → 6.
    try testing.expectEqual(@as(usize, 6), loop.fd_count);
    try testing.expectEqual(mock.pipe_r, loop.pollfds[Slots.device_base].fd);
}

test "event_loop: EventLoop.addDevice rejects overflow" {
    const allocator = testing.allocator;
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    // Fill remaining slots (already have 5: signalfd + stop_pipe +
    // layer timer_fd + rumble-stop timerfd + macro timerfd).
    var mocks: [MAX_FDS - FIXED_SLOT_COUNT]MockDeviceIO = undefined;
    for (0..MAX_FDS - FIXED_SLOT_COUNT) |i| {
        mocks[i] = try MockDeviceIO.init(allocator, &.{});
    }
    defer for (0..MAX_FDS - FIXED_SLOT_COUNT) |i| mocks[i].deinit();

    for (0..MAX_FDS - FIXED_SLOT_COUNT) |i| {
        const dev = mocks[i].deviceIO();
        try loop.addDevice(dev);
    }
    var extra = try MockDeviceIO.init(allocator, &.{});
    defer extra.deinit();
    const extra_dev = extra.deviceIO();
    try testing.expectError(error.TooManyFds, loop.addDevice(extra_dev));
}

test "event_loop: armTimer / disarmTimer: arm then disarm does not leave fd readable" {
    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    armTimer(loop.timer_fd, 5000); // 5 seconds — will not fire during test
    disarmTimer(loop.timer_fd);

    // After disarm, timerfd should not be readable
    var pfd = [1]posix.pollfd{.{ .fd = loop.timer_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 0);
    try testing.expectEqual(@as(usize, 0), ready);
}

test "event_loop: armTimer: fires after timeout" {
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

test "event_loop: EventLoop timerfd: mapper.onLayerTimerExpired invoked on timer expiry" {
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

    var m = try mapper_mod.Mapper.init(&mapper_empty.value, loop.macro_timer_fd, allocator);
    defer m.deinit();

    // Put layer in PENDING so timer expiry advances it to ACTIVE
    _ = m.layer.onTriggerPress("aim", 200, 0);

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

const device_mod = @import("config/device.zig");

// intentionally minimal; not a vader5 fixture
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

test "event_loop: EventLoop mini: device frame dispatched to interpreter and output" {
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

// --- T8/T9: Adaptive trigger tests ---

const mapping_mod = @import("config/mapping.zig");

test "event_loop: buildAdaptiveTriggerParams: maps left/right values with shift" {
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

test "event_loop: buildAdaptiveTriggerParams: null params default to 0" {
    const at = mapping_mod.AdaptiveTriggerConfig{ .mode = "off" };
    var buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&buf, &at);
    for (params) |p| {
        try testing.expectEqual(@as(u16, 0), p.value);
    }
}

test "event_loop: fillTemplate: adaptive trigger feedback template produces correct bytes" {
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

test "event_loop: fillTemplate: adaptive trigger off template is all zeros except report ID and flags" {
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

test "event_loop: applyAdaptiveTrigger: round-trip mapping config to device write" {
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

test "event_loop: applyAdaptiveTrigger: unknown mode silently skips" {
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

test "event_loop: applyAdaptiveTrigger: custom command_prefix routes correctly" {
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
