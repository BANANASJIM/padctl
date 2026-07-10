//! UHID (userspace HID) kernel protocol bindings.
//!
//! The Linux `/dev/uhid` character device exchanges `struct uhid_event`
//! records. Each record is a `u32` event type followed by a packed union
//! payload. Kernel reads may be shorter than `UHID_EVENT_SIZE`; userspace must
//! zero-extend them before decoding and validate the bytes required by the
//! selected event variant.
//!
//! This module exposes the minimal subset padctl needs:
//!   - `UHID_CREATE2` — create a virtual HID device with an embedded
//!     report descriptor.
//!   - `UHID_INPUT2`  — inject an input report (payload = HID report bytes).
//!   - `UHID_DESTROY` — tear the device down.
//!
//! UHID UAPI bindings extracted into a shared module so both production code
//! and tests can import them without duplication.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const state = @import("../core/state.zig");
const uinput = @import("uinput.zig");
const device_cfg = @import("../config/device.zig");
const descriptor = @import("uhid_descriptor.zig");
const write_exact = @import("write_exact.zig");

// --- Kernel protocol constants ---------------------------------------------

/// Destroy a previously-created virtual HID device. No payload.
pub const UHID_DESTROY: u32 = 1;
/// Kernel starts/stops and opens/closes a userspace HID device with these
/// lifecycle notifications.
pub const UHID_START: u32 = 2;
pub const UHID_STOP: u32 = 3;
pub const UHID_OPEN: u32 = 4;
pub const UHID_CLOSE: u32 = 5;
/// Kernel sends an output report to userspace.
pub const UHID_OUTPUT: u32 = 6;
/// Kernel report control requests and their userspace replies.
pub const UHID_GET_REPORT: u32 = 9;
pub const UHID_GET_REPORT_REPLY: u32 = 10;
/// Create a virtual HID device (variant 2 — embeds descriptor inline).
pub const UHID_CREATE2: u32 = 11;
/// Inject an input report from userspace to the kernel (variant 2).
pub const UHID_INPUT2: u32 = 12;
pub const UHID_SET_REPORT: u32 = 13;
pub const UHID_SET_REPORT_REPLY: u32 = 14;

/// Maximum payload size for UHID_INPUT2 / UHID_OUTPUT etc. per kernel UAPI.
pub const UHID_DATA_MAX: usize = 4096;
/// Maximum HID report descriptor size accepted by UHID_CREATE2.
pub const HID_MAX_DESCRIPTOR_SIZE: usize = 4096;

/// Full size of `struct uhid_event` on a current 64-bit Linux kernel. Userspace
/// must write exactly this many bytes per event; the kernel parses only the
/// fields relevant to the event type but rejects short writes.
pub const UHID_EVENT_SIZE: usize = 4380;

/// USB bus type required by the kernel `hid-pidff` driver for force-feedback binding.
pub const BUS_USB: u16 = 0x03;

// --- UAPI payload structs --------------------------------------------------

/// Payload for a `UHID_CREATE2` event — mirrors `struct uhid_create2_req`.
pub const UhidCreate2Req = extern struct {
    name: [128]u8,
    phys: [64]u8,
    uniq: [64]u8,
    rd_size: u16,
    bus: u16,
    vendor: u32,
    product: u32,
    version: u32,
    country: u32,
    rd_data: [HID_MAX_DESCRIPTOR_SIZE]u8,
};

/// Payload for a `UHID_INPUT2` event — mirrors `struct uhid_input2_req`.
pub const UhidInput2Req = extern struct {
    size: u16,
    data: [UHID_DATA_MAX]u8,
};

/// Full `UHID_CREATE2` event layout (type header + payload).
pub const UhidCreate2Event = extern struct {
    type: u32,
    payload: UhidCreate2Req,
};

/// Full `UHID_INPUT2` event layout (type header + payload).
pub const UhidInput2Event = extern struct {
    type: u32,
    payload: UhidInput2Req,
};

/// `UHID_DESTROY` event layout — no payload, just the type header.
pub const UhidDestroyEvent = extern struct {
    type: u32,
};

// --- Low-level helpers -----------------------------------------------------

/// Open `/dev/uhid` RDWR. Returns `error.SkipZigTest` if the node is missing
/// or the caller lacks permission so tests relying on a real UHID device
/// skip cleanly on CI hosts without the capability.
pub fn openUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
}

/// Send a `UHID_CREATE2` event on an already-open uhid fd. The kernel requires
/// a full `UHID_EVENT_SIZE` write; this helper zero-pads before writing.
pub fn uhidCreate(
    fd: posix.fd_t,
    vid: u16,
    pid: u16,
    rd_data: []const u8,
) !void {
    var ev = std.mem.zeroes(UhidCreate2Event);
    ev.type = UHID_CREATE2;
    const name = "padctl-test";
    @memcpy(ev.payload.name[0..name.len], name);
    ev.payload.rd_size = @intCast(rd_data.len);
    ev.payload.bus = BUS_USB;
    ev.payload.vendor = vid;
    ev.payload.product = pid;
    ev.payload.version = 0;
    ev.payload.country = 0;
    @memcpy(ev.payload.rd_data[0..rd_data.len], rd_data);

    comptime std.debug.assert(@sizeOf(UhidCreate2Event) <= UHID_EVENT_SIZE);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    @memcpy(buf[0..bytes.len], bytes);
    try write_exact.writeExact(fd, &buf);
}

/// Send a `UHID_INPUT2` event carrying an input report payload. Rejects
/// payloads larger than `UHID_DATA_MAX` — the kernel's `uhid_input2_req.data`
/// is a fixed `[4096]u8` and `uhid_input2_req.size` is a `u16`, so anything
/// beyond 4096 bytes would both overrun the payload array (panic in safe
/// builds, silent corruption in release) and truncate in the `size` field.
pub fn uhidInput(fd: posix.fd_t, data: []const u8) !void {
    if (data.len > UHID_DATA_MAX) return error.PayloadTooLong;

    var ev = std.mem.zeroes(UhidInput2Event);
    ev.type = UHID_INPUT2;
    ev.payload.size = @intCast(data.len);
    @memcpy(ev.payload.data[0..data.len], data);

    comptime std.debug.assert(@sizeOf(UhidInput2Event) <= UHID_EVENT_SIZE);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    @memcpy(buf[0..bytes.len], bytes);
    try write_exact.writeExact(fd, &buf);
}

/// Send a `UHID_DESTROY` event on the given fd. Best-effort (errors
/// swallowed) — callers close the fd immediately afterwards.
pub fn uhidDestroy(fd: posix.fd_t) void {
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, buf[0..4], UHID_DESTROY, .little);
    write_exact.writeExact(fd, &buf) catch {};
}

// --- Kernel-to-userspace event decoding ------------------------------------

const TYPE_SIZE: usize = 4;
const START_TOTAL_SIZE: usize = TYPE_SIZE + 8;
const GET_REPORT_TOTAL_SIZE: usize = TYPE_SIZE + 4 + 1 + 1;
const SET_REPORT_HEADER_TOTAL_SIZE: usize = TYPE_SIZE + 4 + 1 + 1 + 2;
const OUTPUT_DATA_OFFSET: usize = TYPE_SIZE;
const OUTPUT_SIZE_OFFSET: usize = OUTPUT_DATA_OFFSET + UHID_DATA_MAX;
const OUTPUT_RTYPE_OFFSET: usize = OUTPUT_SIZE_OFFSET + 2;
const OUTPUT_HEADER_TOTAL_SIZE: usize = OUTPUT_RTYPE_OFFSET + 1;

pub const ReportType = enum(u8) {
    feature = 0,
    output = 1,
    input = 2,
    _,
};

pub const StartRequest = struct {
    dev_flags: u64,
};

pub const GetReportRequest = struct {
    id: u32,
    report_number: u8,
    report_type: ReportType,
};

pub const SetReportRequest = struct {
    id: u32,
    report_number: u8,
    report_type: ReportType,
    data: []const u8,
};

/// Zig layout helper retained for compatibility assertions. This is not an
/// exact mirror: the Linux UAPI payload is packed, so decoding uses checked
/// byte offsets instead of pointer-casting this naturally aligned type.
pub const UhidOutputReq = extern struct {
    data: [UHID_DATA_MAX]u8,
    size: u16,
    rtype: u8,
};

/// A parsed output report extracted from a `UHID_OUTPUT` event.
/// Borrows the caller's read buffer — do not retain past the current frame.
pub const OutputReport = struct {
    report_id: u8,
    report_type: ReportType = .output,
    data: []const u8,
};

/// A checked, typed view of one kernel-to-userspace UHID event. Payload slices
/// borrow the caller's read buffer.
pub const UhidEvent = union(enum) {
    start: StartRequest,
    stop,
    open,
    close,
    output: OutputReport,
    get_report: GetReportRequest,
    set_report: SetReportRequest,
    unknown: u32,
};

pub const GetReportResult = struct {
    err: u16 = 0,
    size: usize = 0,
};

/// Injected protocol seam used by regression tests and the native pump. A
/// GET callback fills `reply_data` and returns its used size; SET returns the
/// UAPI error value directly. Missing callbacks reject with a nonzero error.
pub const ControlHandler = struct {
    ctx: ?*anyopaque = null,
    get_report: ?*const fn (
        ctx: *anyopaque,
        request: GetReportRequest,
        reply_data: []u8,
    ) GetReportResult = null,
    set_report: ?*const fn (ctx: *anyopaque, request: SetReportRequest) u16 = null,
};

/// Protocol-independent command handed from a native UHID output decoder to
/// padctl's existing physical `[commands.rumble]` path.
pub const RumbleCommand = struct {
    strong: u16,
    weak: u16,
};

/// Injected native protocol seam. The pump passes one checked UHID output
/// report to this callback; a null result means the report is valid traffic
/// but carries no compatible rumble command.
pub const NativeOutputHandler = struct {
    ctx: ?*anyopaque = null,
    decode: ?*const fn (ctx: *anyopaque, report: OutputReport) ?RumbleCommand = null,
};

/// Enabling this config transfers sole read ownership of the UHID fd to a
/// dedicated pump before CREATE2. Generic descriptor/PID devices leave it
/// null and retain the existing EventLoop reader.
pub const NativePumpConfig = struct {
    control_handler: ControlHandler = .{},
    output_handler: NativeOutputHandler = .{},
};

// Zig's futex mutex lacks TSan annotations. Match the existing usbraw queue:
// pthread mutexes provide explicit happens-before edges in sanitizer builds.
const MailboxMutex = if (builtin.sanitize_thread) struct {
    m: std.c.pthread_mutex_t = .{},

    fn lock(self: *@This()) void {
        std.debug.assert(std.c.pthread_mutex_lock(&self.m) == .SUCCESS);
    }

    fn unlock(self: *@This()) void {
        std.debug.assert(std.c.pthread_mutex_unlock(&self.m) == .SUCCESS);
    }
} else std.Thread.Mutex;

/// Capacity-one, latest-wins mailbox. The pump is the producer and EventLoop
/// is the consumer; the mutex also makes decoder-independent tests race-free.
pub const RumbleMailbox = struct {
    mutex: MailboxMutex = .{},
    pending: ?RumbleCommand = null,

    pub fn publish(self: *RumbleMailbox, command: RumbleCommand) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.pending = command;
    }

    pub fn take(self: *RumbleMailbox) ?RumbleCommand {
        self.mutex.lock();
        defer self.mutex.unlock();
        const command = self.pending;
        self.pending = null;
        return command;
    }
};

pub const UHID_PROTOCOL_ERROR: u16 = 1;

/// Decode one zero-extended UHID read without relying on compiler alignment
/// for the packed UAPI payloads. `actual_len` is the byte count returned by
/// read(2), not the capacity of `buf`.
pub fn decodeEvent(buf: []const u8, actual_len: usize) !UhidEvent {
    if (actual_len > buf.len) return error.InvalidEventLength;
    if (actual_len < TYPE_SIZE) return error.IncompleteUhidEvent;

    const event_type = std.mem.readInt(u32, buf[0..TYPE_SIZE], .little);
    return switch (event_type) {
        UHID_START => blk: {
            if (actual_len < START_TOTAL_SIZE) return error.IncompleteUhidEvent;
            break :blk .{ .start = .{
                .dev_flags = std.mem.readInt(u64, buf[TYPE_SIZE..START_TOTAL_SIZE], .little),
            } };
        },
        UHID_STOP => .stop,
        UHID_OPEN => .open,
        UHID_CLOSE => .close,
        UHID_OUTPUT => blk: {
            // `uhid_output_req` places size/rtype after its fixed 4096-byte
            // data member, so a valid short event must still reach byte 4103.
            if (actual_len < OUTPUT_HEADER_TOTAL_SIZE) return error.IncompleteUhidEvent;
            const declared_size = std.mem.readInt(u16, buf[OUTPUT_SIZE_OFFSET .. OUTPUT_SIZE_OFFSET + 2], .little);
            const size: usize = declared_size;
            if (size > UHID_DATA_MAX) return error.OversizedUhidDeclaration;
            if (actual_len < OUTPUT_DATA_OFFSET + size) return error.IncompleteUhidEvent;
            const data = buf[OUTPUT_DATA_OFFSET..][0..size];
            break :blk .{ .output = .{
                .report_id = if (data.len == 0) 0 else data[0],
                .report_type = @enumFromInt(buf[OUTPUT_RTYPE_OFFSET]),
                .data = data,
            } };
        },
        UHID_GET_REPORT => blk: {
            if (actual_len < GET_REPORT_TOTAL_SIZE) return error.IncompleteUhidEvent;
            break :blk .{ .get_report = .{
                .id = std.mem.readInt(u32, buf[4..8], .little),
                .report_number = buf[8],
                .report_type = @enumFromInt(buf[9]),
            } };
        },
        UHID_SET_REPORT => blk: {
            if (actual_len < SET_REPORT_HEADER_TOTAL_SIZE) return error.IncompleteUhidEvent;
            const declared_size = std.mem.readInt(u16, buf[10..12], .little);
            const size: usize = declared_size;
            if (size > UHID_DATA_MAX) return error.OversizedUhidDeclaration;
            const required = SET_REPORT_HEADER_TOTAL_SIZE + size;
            if (actual_len < required) return error.IncompleteUhidEvent;
            break :blk .{ .set_report = .{
                .id = std.mem.readInt(u32, buf[4..8], .little),
                .report_number = buf[8],
                .report_type = @enumFromInt(buf[9]),
                .data = buf[SET_REPORT_HEADER_TOTAL_SIZE..required],
            } };
        },
        else => .{ .unknown = event_type },
    };
}

/// Encode a full, zero-initialized GET_REPORT_REPLY frame. Full-size writes
/// preserve the existing padctl UHID write contract; all packed fields use
/// explicit byte offsets.
pub fn encodeGetReportReply(
    out: []u8,
    id: u32,
    err: u16,
    data: []const u8,
) ![]const u8 {
    if (out.len < UHID_EVENT_SIZE) return error.ReplyBufferTooSmall;
    if (data.len > UHID_DATA_MAX) return error.ReplyPayloadTooLong;
    @memset(out[0..UHID_EVENT_SIZE], 0);
    std.mem.writeInt(u32, out[0..4], UHID_GET_REPORT_REPLY, .little);
    std.mem.writeInt(u32, out[4..8], id, .little);
    std.mem.writeInt(u16, out[8..10], err, .little);
    std.mem.writeInt(u16, out[10..12], @intCast(data.len), .little);
    @memcpy(out[12..][0..data.len], data);
    return out[0..UHID_EVENT_SIZE];
}

pub fn encodeSetReportReply(out: []u8, id: u32, err: u16) ![]const u8 {
    if (out.len < UHID_EVENT_SIZE) return error.ReplyBufferTooSmall;
    @memset(out[0..UHID_EVENT_SIZE], 0);
    std.mem.writeInt(u32, out[0..4], UHID_SET_REPORT_REPLY, .little);
    std.mem.writeInt(u32, out[4..8], id, .little);
    std.mem.writeInt(u16, out[8..10], err, .little);
    return out[0..UHID_EVENT_SIZE];
}

// --- High-level UhidDevice (T2 + T3) ---------------------------------------

/// Precise error set for `UhidDevice.init` / `UhidDevice.initWithFd`. Keeps
/// the vtable callers out of `anyerror` land. `InvalidFd` is only reachable
/// from `initWithFd`; both constructors share the set for API symmetry.
pub const InitError = error{
    ConfigInvalid,
    DescriptorTooLarge,
    InvalidFd,
    UhidCreateFailed,
    OutOfMemory,
} || posix.OpenError || posix.WriteError;

/// Parameters for constructing a `UhidDevice`.
///
/// The `uniq` string feeds the `/sys/class/hid/.../uniq` attribute that
/// padctl's routing layer reads via `EVIOCGUNIQ` to pair SDL IMU and
/// main-pad nodes (see `decisions/015-uhid-imu-migration.md` §7 AC4).
pub const Config = struct {
    vid: u16,
    pid: u16,
    /// Device name. Copied into a 128-byte field; longer strings are
    /// truncated to fit (with a NUL reserved).
    name: []const u8,
    /// Unique identifier string. Copied into a 64-byte field.
    uniq: []const u8 = "",
    /// Raw HID report descriptor bytes. Must fit in `HID_MAX_DESCRIPTOR_SIZE`.
    descriptor: []const u8,
    /// Bus type — defaults to USB. `hid-pidff` requires `BUS_USB`.
    bus: u16 = BUS_USB,
    /// Device version (`bcdDevice`-like). Optional; 0 is accepted.
    version: u32 = 0,
    /// HID country code. 0 = "not localized" which matches most gamepads.
    country: u32 = 0,
    /// Optional `[output]` section the descriptor was built from. When set,
    /// `emit()` packs HID reports via `uhid_descriptor.encodeReport` so the
    /// bytes on the wire match the declared layout. When null, `emit()`
    /// falls back to a raw 4-byte stick stub (legacy tests that pass a hand
    /// -written descriptor without a matching `OutputConfig` still work).
    output: ?device_cfg.OutputConfig = null,
    /// Optional `[output.imu]` section. When set, the device is an IMU
    /// companion card — `emit()` packs accel + gyro axes via
    /// `uhid_descriptor.encodeImuReport` and the primary-path encoder is
    /// bypassed. Mutually exclusive with `output` at the emit branch: if
    /// both are set, `output` wins (primary card shape).
    imu: ?device_cfg.ImuConfig = null,
    /// Native protocols install all handlers before the pump starts. The
    /// pump is running before CREATE2 so kernel probe GET/SET traffic cannot
    /// race an EventLoop-owned reader.
    native_pump: ?NativePumpConfig = null,
};

/// A UHID-backed output device implementing the shared `OutputDevice` vtable.
///
///   - `emit(state)` dispatches to `uhid_descriptor.encodeReport` when
///     `Config.output` is set, to `encodeImuReport` when only `Config.imu`
///     is set, or to a raw 4-byte stick stub for legacy tests with no config.
///   - `pollFf()` always returns `null` — FF output reports are consumed
///     via `pollOutputReport`; the vtable path is unused.
///   - `close()` sends `UHID_DESTROY` and closes the fd.
pub const UhidDevice = struct {
    fd: posix.fd_t,
    vid: u16,
    pid: u16,
    /// Last state passed to `emit()`. Read by the routing layer during
    /// backend handoffs to preserve pressed buttons / stick positions.
    state_snapshot: state.GamepadState = .{},
    /// Owned-by-caller copies: `UhidDevice` does not free these. The daemon
    /// stores the backing TOML allocator; CI tests use string literals.
    name: []const u8,
    uniq: []const u8,
    /// Optional `OutputConfig` — when set, `emit()` dispatches to the
    /// descriptor-driven encoder. See `Config.output`.
    output: ?device_cfg.OutputConfig,
    /// Optional `ImuConfig` — when set AND `output` is null, `emit()`
    /// dispatches to `encodeImuReport` (6 × i16 accel + gyro axes).
    imu: ?device_cfg.ImuConfig,
    /// Optional callback invoked for each `UHID_OUTPUT` report received from
    /// the kernel (FFB effect data forwarded to physical hidraw).
    output_cb: ?*const fn (ctx: *anyopaque, report: OutputReport) void = null,
    output_ctx: ?*anyopaque = null,
    /// Protocol callbacks for GET_REPORT / SET_REPORT control requests.
    control_handler: ControlHandler = .{},
    native_output_handler: NativeOutputHandler = .{},
    rumble_mailbox: RumbleMailbox = .{},
    mailbox_wake_fd: posix.fd_t = -1,
    shutdown_wake_fd: posix.fd_t = -1,
    pump_thread: ?std.Thread = null,
    pump_shutdown: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    pump_abort: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    pump_exited: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    pump_drain_timed_out: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    /// Construct a `UhidDevice` against a real `/dev/uhid` fd. Opens the
    /// kernel node, populates a `UhidCreate2Req`, and writes it.
    ///
    /// Ownership: caller owns the returned `*UhidDevice`. `close()` tears the
    /// kernel device down but does not free the struct — callers hold it in
    /// an arena or free it via `allocator.destroy(dev)` explicitly.
    pub fn init(allocator: std.mem.Allocator, cfg: Config) InitError!*UhidDevice {
        if (cfg.name.len == 0) return error.ConfigInvalid;
        if (cfg.descriptor.len == 0) return error.ConfigInvalid;
        if (cfg.descriptor.len > HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;

        const fd = openUhid() catch |err| switch (err) {
            error.SkipZigTest => return error.UhidCreateFailed,
            else => |e| return e,
        };
        errdefer posix.close(fd);
        const self = try allocator.create(UhidDevice);
        errdefer allocator.destroy(self);
        self.* = .{
            .fd = fd,
            .vid = cfg.vid,
            .pid = cfg.pid,
            .name = cfg.name,
            .uniq = cfg.uniq,
            .output = cfg.output,
            .imu = cfg.imu,
        };

        if (cfg.native_pump) |pump_cfg| {
            self.startNativePump(pump_cfg) catch return error.UhidCreateFailed;
            errdefer self.abortNativePump();
        }

        try self.sendCreateOwned(cfg);
        return self;
    }

    /// Test-only constructor: bind the device to a caller-supplied fd
    /// (typically a pipe or unix socket write-end) so we can assert on the
    /// bytes that would be sent to the kernel without touching `/dev/uhid`.
    ///
    /// Unlike `init`, this does NOT send a `UHID_CREATE2` event — the caller
    /// drives that manually if desired. Use only from tests.
    ///
    /// Shares `InitError` with `init` so callers see a uniform error set.
    /// Negative fds are rejected (`error.InvalidFd`) — otherwise a `-1`
    /// sentinel leaks from `close()` idempotency back into a fresh
    /// `UhidDevice` and silently poisons every downstream write.
    pub fn initWithFd(
        allocator: std.mem.Allocator,
        fd: posix.fd_t,
        cfg: Config,
    ) InitError!*UhidDevice {
        if (fd < 0) return error.InvalidFd;
        if (cfg.name.len == 0) return error.ConfigInvalid;
        if (cfg.descriptor.len == 0) return error.ConfigInvalid;
        if (cfg.descriptor.len > HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;

        const self = try allocator.create(UhidDevice);
        self.* = .{
            .fd = fd,
            .vid = cfg.vid,
            .pid = cfg.pid,
            .name = cfg.name,
            .uniq = cfg.uniq,
            .output = cfg.output,
            .imu = cfg.imu,
        };
        if (cfg.native_pump) |pump_cfg| {
            self.startNativePump(pump_cfg) catch {
                allocator.destroy(self);
                return error.UhidCreateFailed;
            };
        }
        return self;
    }

    /// CREATE2 helper for callers using `initWithFd`. Native callers must use
    /// this method (rather than the static `sendCreate`) so a failed CREATE2
    /// can stop and join the already-running pre-probe pump without waiting
    /// for the normal post-DESTROY drain window.
    pub fn sendCreateOwned(self: *UhidDevice, cfg: Config) InitError!void {
        sendCreate(self.fd, cfg) catch |err| {
            self.abortNativePump();
            return err;
        };
    }

    pub fn sendCreate(fd: posix.fd_t, cfg: Config) InitError!void {
        var ev = std.mem.zeroes(UhidCreate2Event);
        ev.type = UHID_CREATE2;

        // Reserve one byte for the trailing NUL even when the caller passes
        // a shorter string — the kernel does not require NUL termination, but
        // the /sys/class/hid/.../name readout will include trailing junk
        // otherwise, which confuses udev rules.
        const name_copy = @min(cfg.name.len, ev.payload.name.len - 1);
        @memcpy(ev.payload.name[0..name_copy], cfg.name[0..name_copy]);
        const uniq_copy = @min(cfg.uniq.len, ev.payload.uniq.len - 1);
        if (uniq_copy != 0) @memcpy(ev.payload.uniq[0..uniq_copy], cfg.uniq[0..uniq_copy]);

        if (cfg.descriptor.len > HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;
        ev.payload.rd_size = @intCast(cfg.descriptor.len);
        ev.payload.bus = cfg.bus;
        ev.payload.vendor = cfg.vid;
        ev.payload.product = cfg.pid;
        ev.payload.version = cfg.version;
        ev.payload.country = cfg.country;
        @memcpy(ev.payload.rd_data[0..cfg.descriptor.len], cfg.descriptor);

        comptime std.debug.assert(@sizeOf(UhidCreate2Event) <= UHID_EVENT_SIZE);
        var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
        const bytes = std.mem.asBytes(&ev);
        @memcpy(buf[0..bytes.len], bytes);
        write_exact.writeExact(fd, &buf) catch return error.UhidCreateFailed;
    }

    const PUMP_DRAIN_TIMEOUT_MS: i64 = 500;

    fn createWakeFd() !posix.fd_t {
        const ioctl = @import("ioctl_constants.zig");
        return posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
    }

    fn signalWake(fd: posix.fd_t) !void {
        var one: u64 = 1;
        const bytes = std.mem.asBytes(&one);
        const n = posix.write(fd, bytes) catch |err| switch (err) {
            // A saturated eventfd already contains a pending wake. The
            // mailbox has been published, so this is successful coalescing.
            error.WouldBlock => return,
            else => return err,
        };
        if (n != bytes.len) return error.ShortWakeWrite;
    }

    fn drainWake(fd: posix.fd_t) void {
        var value: u64 = 0;
        while (true) {
            const n = posix.read(fd, std.mem.asBytes(&value)) catch |err| switch (err) {
                error.WouldBlock => return,
                else => return,
            };
            if (n == 0) return;
        }
    }

    fn monotonicNs() i128 {
        const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
        return @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
    }

    fn startNativePump(self: *UhidDevice, cfg: NativePumpConfig) !void {
        std.debug.assert(self.pump_thread == null);
        const mailbox_wake_fd = try createWakeFd();
        errdefer posix.close(mailbox_wake_fd);
        const shutdown_wake_fd = try createWakeFd();
        errdefer posix.close(shutdown_wake_fd);

        self.control_handler = cfg.control_handler;
        self.native_output_handler = cfg.output_handler;
        self.mailbox_wake_fd = mailbox_wake_fd;
        self.shutdown_wake_fd = shutdown_wake_fd;
        self.pump_shutdown.store(false, .release);
        self.pump_abort.store(false, .release);
        self.pump_exited.store(false, .release);
        self.pump_drain_timed_out.store(false, .release);
        self.pump_thread = try std.Thread.spawn(.{}, nativePumpMain, .{self});
    }

    fn nativePumpMain(self: *UhidDevice) void {
        defer self.pump_exited.store(true, .release);

        var drain_deadline_ns: ?i128 = null;
        while (true) {
            if (self.pump_abort.load(.acquire)) return;
            if (self.pump_shutdown.load(.acquire) and drain_deadline_ns == null) {
                drain_deadline_ns = monotonicNs() + PUMP_DRAIN_TIMEOUT_MS * std.time.ns_per_ms;
            }

            const timeout_ms: i32 = if (drain_deadline_ns) |deadline| blk: {
                const remaining = deadline - monotonicNs();
                // Check the absolute deadline before poll. A continuously
                // readable malicious/noisy peer must not keep returning
                // readiness and thereby evade a timeout==0 check forever.
                if (remaining <= 0) {
                    self.recordDrainTimeout();
                    return;
                }
                const rounded_up = @divFloor(remaining + std.time.ns_per_ms - 1, std.time.ns_per_ms);
                break :blk @intCast(@min(rounded_up, PUMP_DRAIN_TIMEOUT_MS));
            } else -1;

            var pfds = [_]posix.pollfd{
                .{ .fd = self.fd, .events = posix.POLL.IN, .revents = 0 },
                .{ .fd = self.shutdown_wake_fd, .events = posix.POLL.IN, .revents = 0 },
            };
            const ready = posix.poll(&pfds, timeout_ms) catch return;
            if (ready == 0) {
                if (drain_deadline_ns != null) {
                    self.recordDrainTimeout();
                    return;
                }
                continue;
            }

            if (pfds[1].revents & posix.POLL.IN != 0) drainWake(self.shutdown_wake_fd);
            if (self.pump_abort.load(.acquire)) return;

            if (pfds[0].revents & posix.POLL.IN != 0) {
                if (self.processOneNativeEvent()) return;
            }
            if (pfds[0].revents & (posix.POLL.HUP | posix.POLL.ERR | posix.POLL.NVAL) != 0) return;
        }
    }

    fn recordDrainTimeout(self: *UhidDevice) void {
        self.pump_drain_timed_out.store(true, .release);
        std.log.warn("UHID native pump timed out after {d}ms waiting for STOP/POLLHUP", .{PUMP_DRAIN_TIMEOUT_MS});
    }

    /// Consume at most one event before returning to the outer deadline
    /// check. This bounded batch prevents sustained non-STOP traffic from
    /// starving shutdown while still letting poll immediately re-signal a
    /// readable fd during normal operation.
    /// Returns true when STOP or a fatal fd/reply error ends read ownership.
    fn processOneNativeEvent(self: *UhidDevice) bool {
        var buf: [UHID_EVENT_SIZE]u8 = undefined;
        const event = self.readEvent(&buf) catch |err| {
            // The malformed packet was consumed. Return to poll/deadline
            // arbitration before accepting another packet.
            std.log.warn("UHID native pump rejected malformed event: {}", .{err});
            return false;
        } orelse return false;

        switch (event) {
            .stop => return true,
            .get_report => |request| self.replyToGetReport(request) catch return true,
            .set_report => |request| self.replyToSetReport(request) catch return true,
            .output => |report| {
                if (self.native_output_handler.decode) |decode| {
                    if (self.native_output_handler.ctx) |ctx| {
                        if (decode(ctx, report)) |command| {
                            self.publishRumbleCommand(command) catch |err| {
                                std.log.warn("UHID native rumble wake failed: {}", .{err});
                            };
                        }
                    }
                }
            },
            else => {},
        }
        return false;
    }

    fn closeWakeResources(self: *UhidDevice) void {
        if (self.mailbox_wake_fd >= 0) {
            posix.close(self.mailbox_wake_fd);
            self.mailbox_wake_fd = -1;
        }
        if (self.shutdown_wake_fd >= 0) {
            posix.close(self.shutdown_wake_fd);
            self.shutdown_wake_fd = -1;
        }
    }

    fn abortNativePump(self: *UhidDevice) void {
        const thread = self.pump_thread orelse return;
        self.pump_abort.store(true, .release);
        self.pump_shutdown.store(true, .release);
        signalWake(self.shutdown_wake_fd) catch {};
        thread.join();
        self.pump_thread = null;
        self.closeWakeResources();
    }

    pub fn hasNativePump(self: *const UhidDevice) bool {
        return self.pump_thread != null;
    }

    pub fn rumbleWakeFd(self: *const UhidDevice) posix.fd_t {
        return self.mailbox_wake_fd;
    }

    pub fn drainRumbleWake(self: *UhidDevice) void {
        if (self.mailbox_wake_fd >= 0) drainWake(self.mailbox_wake_fd);
    }

    pub fn publishRumbleCommand(self: *UhidDevice, command: RumbleCommand) !void {
        if (self.mailbox_wake_fd < 0) return error.NativePumpNotRunning;
        self.rumble_mailbox.publish(command);
        try signalWake(self.mailbox_wake_fd);
    }

    pub fn takeRumbleCommand(self: *UhidDevice) ?RumbleCommand {
        return self.rumble_mailbox.take();
    }

    pub fn drainTimedOut(self: *const UhidDevice) bool {
        return self.pump_drain_timed_out.load(.acquire);
    }

    pub fn pumpExited(self: *const UhidDevice) bool {
        return self.pump_exited.load(.acquire);
    }

    pub fn nativeWakeResourcesClosed(self: *const UhidDevice) bool {
        return self.mailbox_wake_fd < 0 and self.shutdown_wake_fd < 0;
    }

    /// Expose this device through the shared `OutputDevice` vtable.
    pub fn outputDevice(self: *UhidDevice) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = emitVtable,
        .poll_ff = pollFfVtable,
        .close = closeVtable,
    };

    fn emitVtable(ptr: *anyopaque, s: state.GamepadState) uinput.EmitError!void {
        const self: *UhidDevice = @ptrCast(@alignCast(ptr));
        return self.emit(s);
    }

    fn pollFfVtable(ptr: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        const self: *UhidDevice = @ptrCast(@alignCast(ptr));
        return self.pollFf();
    }

    fn closeVtable(ptr: *anyopaque) void {
        const self: *UhidDevice = @ptrCast(@alignCast(ptr));
        self.close();
    }

    /// Emit a `UHID_INPUT2` event carrying an input report derived from `s`.
    /// When `Config.output` was supplied, bytes are packed by
    /// `uhid_descriptor.encodeReport` against the exact layout declared by
    /// the descriptor (Report ID + buttons + hat + sticks + triggers +
    /// touchpad). When `output` is null, a 4-byte stick-only stub is sent —
    /// retained for tests that bring a hand-written descriptor without a
    /// matching `OutputConfig`.
    pub fn emit(self: *UhidDevice, s: state.GamepadState) uinput.EmitError!void {
        if (self.output) |out| {
            var report_buf: [descriptor.MAX_REPORT_BYTES]u8 = undefined;
            const bytes = descriptor.encodeReport(out, s, &report_buf) catch
                return error.WriteFailed;
            uhidInput(self.fd, bytes) catch |err| switch (err) {
                error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
                else => return error.WriteFailed,
            };
        } else if (self.imu != null) {
            var report_buf: [descriptor.IMU_REPORT_BYTES]u8 = undefined;
            const bytes = descriptor.encodeImuReport(s, &report_buf) catch
                return error.WriteFailed;
            uhidInput(self.fd, bytes) catch |err| switch (err) {
                error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
                else => return error.WriteFailed,
            };
        } else {
            var payload: [4]u8 = undefined;
            payload[0] = axisToU8(s.ax);
            payload[1] = axisToU8(s.ay);
            payload[2] = axisToU8(s.rx);
            payload[3] = axisToU8(s.ry);
            uhidInput(self.fd, &payload) catch |err| switch (err) {
                error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
                else => return error.WriteFailed,
            };
        }

        self.state_snapshot = s;
    }

    /// Inject an arbitrary payload as a `UHID_INPUT2` event. Prefer `emit()`
    /// for `GamepadState`-driven paths; use `emitRaw` only when the caller
    /// has already encoded the HID report bytes (e.g. tests with hand-written
    /// descriptors).
    pub fn emitRaw(self: *UhidDevice, payload: []const u8) uinput.EmitError!void {
        uhidInput(self.fd, payload) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
            else => return error.WriteFailed,
        };
    }

    pub fn setOutputCallback(
        self: *UhidDevice,
        cb: *const fn (ctx: *anyopaque, report: OutputReport) void,
        ctx: *anyopaque,
    ) void {
        self.output_cb = cb;
        self.output_ctx = ctx;
    }

    pub fn clearOutputCallback(self: *UhidDevice) void {
        self.output_cb = null;
        self.output_ctx = null;
    }

    pub fn setControlHandler(self: *UhidDevice, handler: ControlHandler) void {
        self.control_handler = handler;
    }

    pub fn clearControlHandler(self: *UhidDevice) void {
        self.control_handler = .{};
    }

    /// Read and decode one event. The entire maximum event buffer is cleared
    /// before every read so a short kernel event is zero-extended exactly as
    /// required by `linux/uhid.h`.
    pub fn readEvent(self: *UhidDevice, buf: []u8) !?UhidEvent {
        if (buf.len < UHID_EVENT_SIZE) return error.EventBufferTooSmall;
        @memset(buf[0..UHID_EVENT_SIZE], 0);
        const n = posix.read(self.fd, buf[0..UHID_EVENT_SIZE]) catch |err| switch (err) {
            error.WouldBlock => return null,
            else => return err,
        };
        if (n == 0) return null;
        return try decodeEvent(buf[0..UHID_EVENT_SIZE], n);
    }

    fn replyToGetReport(self: *UhidDevice, request: GetReportRequest) !void {
        var data: [UHID_DATA_MAX]u8 = std.mem.zeroes([UHID_DATA_MAX]u8);
        var result = GetReportResult{ .err = UHID_PROTOCOL_ERROR };
        if (self.control_handler.get_report) |handler| {
            if (self.control_handler.ctx) |ctx| {
                result = handler(ctx, request, &data);
            }
        }

        if (result.size > UHID_DATA_MAX) {
            result = .{ .err = UHID_PROTOCOL_ERROR, .size = 0 };
        }
        const reply_data = if (result.err == 0) data[0..result.size] else data[0..0];
        var reply: [UHID_EVENT_SIZE]u8 = undefined;
        const encoded = try encodeGetReportReply(&reply, request.id, result.err, reply_data);
        try write_exact.writeExact(self.fd, encoded);
    }

    fn replyToSetReport(self: *UhidDevice, request: SetReportRequest) !void {
        var reply_err = UHID_PROTOCOL_ERROR;
        if (self.control_handler.set_report) |handler| {
            if (self.control_handler.ctx) |ctx| {
                reply_err = handler(ctx, request);
            }
        }
        var reply: [UHID_EVENT_SIZE]u8 = undefined;
        const encoded = try encodeSetReportReply(&reply, request.id, reply_err);
        try write_exact.writeExact(self.fd, encoded);
    }

    /// Drain lifecycle/control events until an OUTPUT event or WouldBlock.
    /// GET/SET are replied to synchronously with their original request IDs;
    /// missing protocol handlers receive a nonzero error reply. The returned
    /// output slice borrows `buf` and must not outlive the next call.
    ///
    /// Returns null on `WouldBlock` (no event ready) or a non-OUTPUT event type.
    /// The caller should loop until null to drain all pending events.
    pub fn pollOutputReport(self: *UhidDevice, buf: []u8) !?OutputReport {
        if (self.hasNativePump()) return error.NativePumpOwnsReader;
        while (try self.readEvent(buf)) |event| {
            switch (event) {
                .output => |report| return report,
                .get_report => |request| try self.replyToGetReport(request),
                .set_report => |request| try self.replyToSetReport(request),
                else => {},
            }
        }
        return null;
    }

    /// Always returns `null` — FF output reports from the kernel are consumed
    /// via `pollOutputReport` and routed through `output_cb`; the vtable
    /// `poll_ff` path is unused for UHID devices.
    pub fn pollFf(self: *UhidDevice) uinput.PollFfError!?uinput.FfEvent {
        _ = self;
        return null;
    }

    /// Tear the kernel device down and close the backing fd. Safe to call
    /// multiple times — the second call is a no-op (we sentinel `self.fd`
    /// to `-1` on the first call and short-circuit on entry). Matches the
    /// idempotency pattern used by `UhidSimulator.destroy()`.
    pub fn close(self: *UhidDevice) void {
        if (self.fd < 0) return;
        uhidDestroy(self.fd);
        if (self.pump_thread) |thread| {
            // DESTROY is written first. The pump then owns the fd until STOP,
            // POLLHUP, or the bounded drain deadline; only after join do we
            // close the UHID fd and its wake resources.
            self.pump_shutdown.store(true, .release);
            signalWake(self.shutdown_wake_fd) catch {};
            thread.join();
            self.pump_thread = null;
        }
        posix.close(self.fd);
        self.fd = -1;
        self.closeWakeResources();
    }

    /// Map an i16 stick axis (-32768..32767) to a u8 HID logical value
    /// (0..255) centred at 128. Fixed points:
    ///   axisToU8(-32768) = 0      (full negative)
    ///   axisToU8(     0) = 128    (centre / rest)
    ///   axisToU8(+32767) = 255    (full positive, truncated)
    ///
    /// Divisor = 256 (not 257): we add 32768 first so the input lies in the
    /// unsigned range 0..65535, then `>> 8` (= `/ 256`) compresses to 0..255
    /// with 0 landing exactly on 128. A divisor of 257 would map 0 to 127
    /// (65535 / 257 ≈ 254.9, so (0+32768)/257 = 127) which breaks the
    /// "centred at 128" contract asserted by `uhid_device_vtable_match`.
    fn axisToU8(v: i16) u8 {
        const shifted: i32 = @as(i32, v) + 32768; // now in 0..65535
        const scaled: i32 = @divTrunc(shifted, 256); // 65535 / 256 = 255 (floor)
        if (scaled < 0) return 0;
        if (scaled > 255) return 255;
        return @intCast(scaled);
    }
};

// --- Tests -----------------------------------------------------------------

const testing = std.testing;

test "uhid: constants and struct layout" {
    // These are load-bearing for the kernel UAPI — regressions here are
    // silent disasters. Pin them.
    try testing.expectEqual(@as(u32, 1), UHID_DESTROY);
    try testing.expectEqual(@as(u32, 11), UHID_CREATE2);
    try testing.expectEqual(@as(u32, 12), UHID_INPUT2);
    try testing.expectEqual(@as(usize, 4096), UHID_DATA_MAX);
    try testing.expectEqual(@as(usize, 4096), HID_MAX_DESCRIPTOR_SIZE);

    // UhidCreate2Req: 128 + 64 + 64 + 2 + 2 + 4*4 + 4096 = 4372.
    try testing.expectEqual(@as(usize, 4372), @sizeOf(UhidCreate2Req));
    // UhidInput2Req: 2 + 4096 = 4098 with no compiler-inserted padding.
    try testing.expectEqual(@as(usize, 4098), @sizeOf(UhidInput2Req));
}

test "uhid: axisToU8 clamps and centres" {
    // Fixed points for the i16 -> u8 remap (divisor = 256, centre at 128).
    try testing.expectEqual(@as(u8, 0), UhidDevice.axisToU8(-32768));
    try testing.expectEqual(@as(u8, 128), UhidDevice.axisToU8(0));
    // 32767 → (32767+32768)/256 = 65535/256 = 255 (floor).
    try testing.expectEqual(@as(u8, 255), UhidDevice.axisToU8(32767));
    // Spot-check an intermediate: -1 → (32767)/256 = 127.
    try testing.expectEqual(@as(u8, 127), UhidDevice.axisToU8(-1));
}

test "uhid: outputDevice().emit routes through UhidDevice.emit (not a stub)" {
    // The prior revision compared UhidDevice.vtable.emit's type to
    // OutputDevice.VTable.emit's type — a tautology since vtable is declared
    // as `uinput.OutputDevice.VTable{ ... }`. This replacement asserts that a
    // vtable-routed emit call reaches the real implementation by observing
    // the bytes written to the backing fd change with the input state.
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;
    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-vtable-dispatch",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[1], cfg);
    defer alloc.destroy(dev);

    const out = dev.outputDevice();
    // Emit a non-zero state — axisToU8 shifts away from the 128 centre.
    try out.emit(.{ .ax = 32767, .ay = -32768, .rx = 0, .ry = 0 });

    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try posix.read(fds[0], &buf);
    try testing.expectEqual(UHID_INPUT2, std.mem.readInt(u32, buf[0..4], .little));
    // Bytes 6..10 are the stick payload after the u16 size field at offset 4.
    try testing.expectEqual(@as(u8, 255), buf[6]); // ax full positive
    try testing.expectEqual(@as(u8, 0), buf[7]); // ay full negative
    try testing.expectEqual(@as(u8, 128), buf[8]); // rx centre
    try testing.expectEqual(@as(u8, 128), buf[9]); // ry centre

    // A second emit with the opposite state must produce different bytes —
    // proves the call routed into the live UhidDevice.emit each time rather
    // than capturing the first invocation's state.
    try out.emit(.{ .ax = -32768, .ay = 32767, .rx = 0, .ry = 0 });
    _ = try posix.read(fds[0], &buf);
    try testing.expectEqual(@as(u8, 0), buf[6]);
    try testing.expectEqual(@as(u8, 255), buf[7]);

    out.close();
    var scratch: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try posix.read(fds[0], &scratch);
}

test "uhid: init rejects empty name" {
    const alloc = testing.allocator;
    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "",
        .descriptor = &[_]u8{ 0x05, 0x01 },
    };
    try testing.expectError(error.ConfigInvalid, UhidDevice.init(alloc, cfg));
}

test "uhid: init rejects empty descriptor" {
    const alloc = testing.allocator;
    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-test",
        .descriptor = &[_]u8{},
    };
    try testing.expectError(error.ConfigInvalid, UhidDevice.init(alloc, cfg));
}

test "uhid: init rejects descriptor too large" {
    const alloc = testing.allocator;
    const too_big = try alloc.alloc(u8, HID_MAX_DESCRIPTOR_SIZE + 1);
    defer alloc.free(too_big);
    @memset(too_big, 0);
    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-test",
        .descriptor = too_big,
    };
    try testing.expectError(error.DescriptorTooLarge, UhidDevice.init(alloc, cfg));
}

test "uhid: sendCreate self-guards an oversized descriptor (bypassing init)" {
    const alloc = testing.allocator;
    const too_big = try alloc.alloc(u8, HID_MAX_DESCRIPTOR_SIZE + 1);
    defer alloc.free(too_big);
    @memset(too_big, 0);
    const cfg = Config{ .vid = 0xFADE, .pid = 0xCAFE, .name = "x", .descriptor = too_big };
    // Guard returns before any fd write, so fd = -1 is never touched.
    try testing.expectError(error.DescriptorTooLarge, UhidDevice.sendCreate(-1, cfg));
}

test "uhid_device_vtable_match: emit + close frame UHID_INPUT2 / UHID_DESTROY" {
    // Use a pipe as a stand-in for `/dev/uhid`. The write side receives the
    // exact bytes a real kernel would; the read side lets the test assert on
    // them. Keeps the test CI-safe: no `/dev/uhid` required.
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);
    // fds[1] is closed via UhidDevice.close() below.

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-test",
        .uniq = "padctl/test-0",
        .descriptor = &[_]u8{ 0x05, 0x01, 0x09, 0x05, 0xC0 },
    };

    const dev = try UhidDevice.initWithFd(alloc, fds[1], cfg);
    defer alloc.destroy(dev);

    try dev.emit(.{ .ax = 0, .ay = 0, .rx = 0, .ry = 0 });

    // Read back one event frame and validate framing.
    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    const n = try posix.read(fds[0], &buf);
    try testing.expectEqual(UHID_EVENT_SIZE, n);

    const event_type = std.mem.readInt(u32, buf[0..4], .little);
    try testing.expectEqual(UHID_INPUT2, event_type);

    // UhidInput2Event = { u32 type, UhidInput2Req payload }. The payload is
    // `extern struct { u16 size; [4096]u8 data }` (2-byte aligned), so it sits
    // at offset 4.
    const size = std.mem.readInt(u16, buf[4..6], .little);
    try testing.expectEqual(@as(u16, 4), size);

    // Payload bytes: centred sticks → 128,128,128,128.
    try testing.expectEqual(@as(u8, 128), buf[6]);
    try testing.expectEqual(@as(u8, 128), buf[7]);
    try testing.expectEqual(@as(u8, 128), buf[8]);
    try testing.expectEqual(@as(u8, 128), buf[9]);

    try testing.expectEqual(@as(?uinput.FfEvent, null), try dev.pollFf());

    // close() sends UHID_DESTROY and closes fd — validate the destroy frame
    // before we lose the pipe.
    dev.close();
    const n2 = try posix.read(fds[0], &buf);
    try testing.expectEqual(UHID_EVENT_SIZE, n2);
    const destroy_type = std.mem.readInt(u32, buf[0..4], .little);
    try testing.expectEqual(UHID_DESTROY, destroy_type);
}

test "uhid_device_vtable_match: outputDevice() dispatches through vtable" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);

    const cfg = Config{
        .vid = 0x1234,
        .pid = 0x5678,
        .name = "padctl-vtable-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };

    const dev = try UhidDevice.initWithFd(alloc, fds[1], cfg);
    defer alloc.destroy(dev);

    const out = dev.outputDevice();
    try out.emit(.{ .ax = 0, .ay = 0, .rx = 0, .ry = 0 });
    try testing.expectEqual(@as(?uinput.FfEvent, null), try out.pollFf());

    // Drain frames so the pipe doesn't block a future test.
    var scratch: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try posix.read(fds[0], &scratch);

    out.close();
    _ = try posix.read(fds[0], &scratch);
}

test "uhid: initWithFd rejects negative fd" {
    const alloc = testing.allocator;
    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    // A raw `-1` is ambiguous across platforms (some prefer wrapping via
    // `@as(posix.fd_t, -1)`). Zig's stdlib treats the fd as `c_int`, so -1
    // round-trips cleanly. Use a `var` so @as survives the const inference.
    const bogus_fd: posix.fd_t = -1;
    try testing.expectError(error.InvalidFd, UhidDevice.initWithFd(alloc, bogus_fd, cfg));
}

test "uhid: uhidInput rejects oversized payload (regression H4)" {
    // Pre-fix: uhidInput blindly `@memcpy`'d `data` into the fixed 4096-byte
    // payload array, which panics in safe builds and corrupts adjacent
    // memory in release. Assert a slice larger than UHID_DATA_MAX now
    // returns error.PayloadTooLong before touching the buffer.
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const oversized = try testing.allocator.alloc(u8, UHID_DATA_MAX + 1);
    defer testing.allocator.free(oversized);
    @memset(oversized, 0xAA);

    try testing.expectError(error.PayloadTooLong, uhidInput(fds[1], oversized));

    // A boundary-case payload of exactly UHID_DATA_MAX must pass.
    const ok_size = try testing.allocator.alloc(u8, UHID_DATA_MAX);
    defer testing.allocator.free(ok_size);
    @memset(ok_size, 0x55);
    try uhidInput(fds[1], ok_size);

    // Drain to keep the pipe clean for later tests.
    var scratch: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try posix.read(fds[0], &scratch);
}

test "uhid: emitRaw maps PayloadTooLong to WriteFailed (vtable error stability)" {
    // `emitRaw` returns `uinput.EmitError` which is `{ WriteFailed, DeviceGone }`
    // — adding a new variant would ripple across every vtable call site. Map
    // oversized payloads to `WriteFailed` so the new guard stays inside the
    // existing error set.
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;
    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-payload-guard",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[1], cfg);
    defer alloc.destroy(dev);

    const oversized = try alloc.alloc(u8, UHID_DATA_MAX + 512);
    defer alloc.free(oversized);
    @memset(oversized, 0x42);

    try testing.expectError(error.WriteFailed, dev.emitRaw(oversized));

    dev.close();
    var scratch: [UHID_EVENT_SIZE]u8 = undefined;
    _ = posix.read(fds[0], &scratch) catch {};
}

test "uhid: close() is idempotent (second call is a no-op)" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };

    const dev = try UhidDevice.initWithFd(alloc, fds[1], cfg);
    defer alloc.destroy(dev);

    // First close: real teardown. Second close: must be a no-op — in
    // particular, it MUST NOT call `posix.close(fds[1])` a second time
    // (that would EBADF and, worse, recycle the fd into a concurrent
    // caller's open slot).
    dev.close();
    try testing.expectEqual(@as(posix.fd_t, -1), dev.fd);
    dev.close(); // no-op, must not panic
    try testing.expectEqual(@as(posix.fd_t, -1), dev.fd);

    // Drain the UHID_DESTROY frame the first close() wrote so the pipe
    // buffer doesn't linger into a later test.
    var scratch: [UHID_EVENT_SIZE]u8 = undefined;
    _ = try posix.read(fds[0], &scratch);
}

test "uhid: sendCreate writes uniq bytes correctly into UHID_CREATE2 payload" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const test_uniq = "padctl/steam-deck-0";
    const cfg = Config{
        .vid = 0x1234,
        .pid = 0x5678,
        .name = "test",
        .uniq = test_uniq,
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };

    try UhidDevice.sendCreate(fds[1], cfg);

    var buf: [UHID_EVENT_SIZE]u8 = undefined;
    const n = try posix.read(fds[0], &buf);
    try testing.expectEqual(UHID_EVENT_SIZE, n);

    try testing.expectEqual(UHID_CREATE2, std.mem.readInt(u32, buf[0..4], .little));

    const uniq_off = @offsetOf(UhidCreate2Event, "payload") + @offsetOf(UhidCreate2Req, "uniq");
    try testing.expectEqualSlices(u8, test_uniq, buf[uniq_off..][0..test_uniq.len]);
    try testing.expectEqual(@as(u8, 0), buf[uniq_off + test_uniq.len]);
}

test "uhid: sendCreate truncates uniq at 63 bytes (64-byte field, NUL reserved)" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    var fds: [2]posix.fd_t = undefined;
    fds = try posix.pipe();
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const uniq_off = @offsetOf(UhidCreate2Event, "payload") + @offsetOf(UhidCreate2Req, "uniq");

    // 63 bytes — fits without truncation.
    {
        const uniq63 = "A" ** 63;
        const cfg = Config{
            .vid = 0x1,
            .pid = 0x2,
            .name = "t",
            .uniq = uniq63,
            .descriptor = &[_]u8{0xC0},
        };
        try UhidDevice.sendCreate(fds[1], cfg);
        var buf: [UHID_EVENT_SIZE]u8 = undefined;
        _ = try posix.read(fds[0], &buf);
        try testing.expectEqualSlices(u8, uniq63, buf[uniq_off..][0..63]);
        try testing.expectEqual(@as(u8, 0), buf[uniq_off + 63]);
    }

    // 64 bytes — truncated to 63 + NUL.
    {
        const uniq64 = "B" ** 64;
        const cfg = Config{
            .vid = 0x1,
            .pid = 0x2,
            .name = "t",
            .uniq = uniq64,
            .descriptor = &[_]u8{0xC0},
        };
        try UhidDevice.sendCreate(fds[1], cfg);
        var buf: [UHID_EVENT_SIZE]u8 = undefined;
        _ = try posix.read(fds[0], &buf);
        try testing.expectEqualSlices(u8, "B" ** 63, buf[uniq_off..][0..63]);
        try testing.expectEqual(@as(u8, 0), buf[uniq_off + 63]);
    }

    // 80 bytes — truncated to 63 + NUL.
    {
        const uniq80 = "C" ** 80;
        const cfg = Config{
            .vid = 0x1,
            .pid = 0x2,
            .name = "t",
            .uniq = uniq80,
            .descriptor = &[_]u8{0xC0},
        };
        try UhidDevice.sendCreate(fds[1], cfg);
        var buf: [UHID_EVENT_SIZE]u8 = undefined;
        _ = try posix.read(fds[0], &buf);
        try testing.expectEqualSlices(u8, "C" ** 63, buf[uniq_off..][0..63]);
        try testing.expectEqual(@as(u8, 0), buf[uniq_off + 63]);
    }
}

test "uhid: UHID_OUTPUT constant is 6" {
    try testing.expectEqual(@as(u32, 6), UHID_OUTPUT);
}

test "uhid: UhidOutputReq layout matches kernel UAPI" {
    // data[4096] + size(u16) + rtype(u8) = 4099 kernel packed bytes;
    // extern struct rounds to 4100 due to u16 alignment (1-byte trailing pad).
    try testing.expectEqual(@as(usize, 4100), @sizeOf(UhidOutputReq));
    try testing.expectEqual(@as(usize, 0), @offsetOf(UhidOutputReq, "data"));
    try testing.expectEqual(@as(usize, 4096), @offsetOf(UhidOutputReq, "size"));
    try testing.expectEqual(@as(usize, 4098), @offsetOf(UhidOutputReq, "rtype"));
}

test "uhid: pollOutputReport parses UHID_OUTPUT bytes" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;
    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[0]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-output-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer alloc.destroy(dev);

    // Hand-craft a UHID_OUTPUT event: u32 type=6, then uhid_output_req.
    // uhid_output_req layout: data[4096], size u16, rtype u8.
    var ev_buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, ev_buf[0..4], UHID_OUTPUT, .little);
    // data starts at offset 4: data[0]=0x0A (report_id), data[1..4]=payload
    ev_buf[4] = 0x0A;
    ev_buf[5] = 0x01;
    ev_buf[6] = 0x02;
    ev_buf[7] = 0x03;
    // size field is at offset 4 + 4096 = 4100
    std.mem.writeInt(u16, ev_buf[4100..4102], 4, .little);

    _ = try posix.write(fds[1], &ev_buf);
    defer posix.close(fds[1]);

    var read_buf: [UHID_EVENT_SIZE]u8 = undefined;
    const report = try dev.pollOutputReport(&read_buf);
    try testing.expect(report != null);
    try testing.expectEqual(@as(u8, 0x0A), report.?.report_id);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x0A, 0x01, 0x02, 0x03 }, report.?.data);
}

test "uhid: pollOutputReport returns null for non-UHID_OUTPUT event" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;
    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-output-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer alloc.destroy(dev);

    // Write a UHID_INPUT2 event (type=12) — not a UHID_OUTPUT.
    var ev_buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, ev_buf[0..4], UHID_INPUT2, .little);
    _ = try posix.write(fds[1], &ev_buf);

    var read_buf: [UHID_EVENT_SIZE]u8 = undefined;
    const report = try dev.pollOutputReport(&read_buf);
    try testing.expectEqual(@as(?OutputReport, null), report);
}

test "uhid: pollOutputReport returns null on WouldBlock (empty pipe)" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const alloc = testing.allocator;
    const fds = try posix.pipe2(.{ .NONBLOCK = true });
    defer posix.close(fds[0]);
    defer posix.close(fds[1]);

    const cfg = Config{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-output-test",
        .descriptor = &[_]u8{ 0x05, 0x01, 0xC0 },
    };
    const dev = try UhidDevice.initWithFd(alloc, fds[0], cfg);
    defer alloc.destroy(dev);

    var read_buf: [UHID_EVENT_SIZE]u8 = undefined;
    const report = try dev.pollOutputReport(&read_buf);
    try testing.expectEqual(@as(?OutputReport, null), report);
}

test "uhid: openUhid sets O_NONBLOCK on the fd" {
    const fd = openUhid() catch |err| switch (err) {
        error.SkipZigTest => return error.SkipZigTest,
        else => return err,
    };
    defer posix.close(fd);
    const flags: i32 = @intCast(try posix.fcntl(fd, posix.F.GETFL, 0));
    const O_NONBLOCK_BIT: i32 = 0o4000;
    try std.testing.expect((flags & O_NONBLOCK_BIT) != 0);
}
