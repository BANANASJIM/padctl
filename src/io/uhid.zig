//! UHID (userspace HID) kernel protocol bindings.
//!
//! The Linux `/dev/uhid` character device accepts a stream of fixed-size
//! `struct uhid_event` records. Each record is a `u32` event type followed by
//! a union payload; userspace must write exactly `UHID_EVENT_SIZE` bytes per
//! event regardless of which variant is used (`sizeof(struct uhid_event)` on
//! a current 64-bit Linux kernel).
//!
//! This module exposes the minimal subset padctl needs:
//!   - `UHID_CREATE2` — create a virtual HID device with an embedded
//!     report descriptor.
//!   - `UHID_INPUT2`  — inject an input report (payload = HID report bytes).
//!   - `UHID_DESTROY` — tear the device down.
//!
//! Phase 13 Wave 1 T1 scope: extract the previously test-local UAPI bindings
//! from `src/test/uhid_integration_test.zig:11-99` into a reusable module so
//! production code (added in T2/T3) can share them. This is a mechanical
//! refactor — no behaviour change.

const std = @import("std");
const posix = std.posix;
const state = @import("../core/state.zig");
const uinput = @import("uinput.zig");

// --- Kernel protocol constants ---------------------------------------------

/// Destroy a previously-created virtual HID device. No payload.
pub const UHID_DESTROY: u32 = 1;
/// Create a virtual HID device (variant 2 — embeds descriptor inline).
pub const UHID_CREATE2: u32 = 11;
/// Inject an input report from userspace to the kernel (variant 2).
pub const UHID_INPUT2: u32 = 12;

/// Maximum payload size for UHID_INPUT2 / UHID_OUTPUT etc. per kernel UAPI.
pub const UHID_DATA_MAX: usize = 4096;
/// Maximum HID report descriptor size accepted by UHID_CREATE2.
pub const HID_MAX_DESCRIPTOR_SIZE: usize = 4096;

/// Full size of `struct uhid_event` on a current 64-bit Linux kernel. Userspace
/// must write exactly this many bytes per event; the kernel parses only the
/// fields relevant to the event type but rejects short writes.
pub const UHID_EVENT_SIZE: usize = 4380;

/// USB bus type — used for `UhidCreate2Req.bus` so FFB (Wave 6) sees a bustype
/// the kernel `hid-pidff` driver accepts. See ADR-015 R2.
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
    return posix.open("/dev/uhid", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
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

    const bytes = std.mem.asBytes(&ev);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

/// Send a `UHID_INPUT2` event carrying an input report payload.
pub fn uhidInput(fd: posix.fd_t, data: []const u8) !void {
    var ev = std.mem.zeroes(UhidInput2Event);
    ev.type = UHID_INPUT2;
    ev.payload.size = @intCast(data.len);
    @memcpy(ev.payload.data[0..data.len], data);

    const bytes = std.mem.asBytes(&ev);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

/// Send a `UHID_DESTROY` event on the given fd. Best-effort (errors
/// swallowed) — callers close the fd immediately afterwards.
pub fn uhidDestroy(fd: posix.fd_t) void {
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, buf[0..4], UHID_DESTROY, .little);
    _ = posix.write(fd, &buf) catch {};
}

// --- High-level UhidDevice (T2 + T3) ---------------------------------------

/// Precise error set for `UhidDevice.init` / `UhidDevice.initWithFd`. Keeps
/// the vtable callers out of `anyerror` land (see Phase 10 T9 VTable
/// error-set convergence work). `InvalidFd` is only reachable from
/// `initWithFd`; both constructors share the set for API symmetry.
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
/// main-pad nodes (see `decisions/015-uhid-imu-migration.md` §7 AC4). Wave 1
/// accepts a caller-provided descriptor; Wave 2 introduces the TOML-driven
/// descriptor builder.
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
    /// Bus type — defaults to USB. `hid-pidff` (Wave 6) requires `BUS_USB`.
    bus: u16 = BUS_USB,
    /// Device version (`bcdDevice`-like). Optional; 0 is accepted.
    version: u32 = 0,
    /// HID country code. 0 = "not localized" which matches most gamepads.
    country: u32 = 0,
};

/// A UHID-backed output device implementing the shared `OutputDevice` vtable.
///
/// Phase 13 Wave 1 scope (T2):
///   - Struct layout + vtable wiring matching `UinputDevice`
///     (`src/io/uinput.zig:73-94`).
///   - `emit(state)` ships a minimal 4-byte stick payload via `UHID_INPUT2`
///     (Wave 2 replaces this with the descriptor-driven encoder).
///   - `pollFf()` always returns `null` (Wave 2+ wires FF routing).
///   - `close()` sends `UHID_DESTROY` and closes the fd.
pub const UhidDevice = struct {
    fd: posix.fd_t,
    vid: u16,
    pid: u16,
    /// Last state passed to `emit()`. Wave 3 reads this during routing
    /// switches to preserve pressed buttons / stick positions across backend
    /// handoffs.
    state_snapshot: state.GamepadState = .{},
    /// Owned-by-caller copies: `UhidDevice` does not free these. The daemon
    /// stores the backing TOML allocator; CI tests use string literals.
    name: []const u8,
    uniq: []const u8,

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

        try sendCreate(fd, cfg);
        // After sendCreate succeeded the kernel has a live UHID device wired
        // to `fd`; if the allocation below fails we must tear the kernel
        // side down in addition to closing `fd` (otherwise the virtual
        // device lingers until the process exits). `uhidDestroy` is
        // best-effort — errors are swallowed, exactly like `close()` does.
        errdefer uhidDestroy(fd);

        const self = try allocator.create(UhidDevice);
        self.* = .{
            .fd = fd,
            .vid = cfg.vid,
            .pid = cfg.pid,
            .name = cfg.name,
            .uniq = cfg.uniq,
        };
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
        };
        return self;
    }

    fn sendCreate(fd: posix.fd_t, cfg: Config) InitError!void {
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

        ev.payload.rd_size = std.math.cast(u16, cfg.descriptor.len) orelse
            return error.DescriptorTooLarge;
        ev.payload.bus = cfg.bus;
        ev.payload.vendor = cfg.vid;
        ev.payload.product = cfg.pid;
        ev.payload.version = cfg.version;
        ev.payload.country = cfg.country;
        @memcpy(ev.payload.rd_data[0..cfg.descriptor.len], cfg.descriptor);

        const bytes = std.mem.asBytes(&ev);
        var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
        const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
        @memcpy(buf[0..copy_len], bytes[0..copy_len]);
        _ = posix.write(fd, &buf) catch return error.UhidCreateFailed;
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

    /// Emit a `UHID_INPUT2` event carrying a Wave-1 stub payload derived from
    /// `s`. The payload is 4 bytes of stick axes mapped into the 0..255 HID
    /// logical range — enough to exercise the vtable contract and the
    /// `UhidSimulator` consumer harness. Wave 2 replaces this with the real
    /// descriptor-driven encoder.
    pub fn emit(self: *UhidDevice, s: state.GamepadState) uinput.EmitError!void {
        var payload: [4]u8 = undefined;
        payload[0] = axisToU8(s.ax);
        payload[1] = axisToU8(s.ay);
        payload[2] = axisToU8(s.rx);
        payload[3] = axisToU8(s.ry);

        uhidInput(self.fd, &payload) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
            else => return error.WriteFailed,
        };

        self.state_snapshot = s;
    }

    /// Inject an arbitrary payload as a `UHID_INPUT2` event. Wave 2 callers
    /// (descriptor-aware encoder) feed already-encoded bytes in directly;
    /// Wave 1 tests use it to exercise framing without a real descriptor.
    /// Prefer `emit()` for GamepadState-driven paths.
    pub fn emitRaw(self: *UhidDevice, payload: []const u8) uinput.EmitError!void {
        uhidInput(self.fd, payload) catch |err| switch (err) {
            error.BrokenPipe, error.ConnectionResetByPeer => return error.DeviceGone,
            else => return error.WriteFailed,
        };
    }

    /// Wave 1 stub: no FF events yet. Wave 2+ replaces this with real
    /// `UHID_OUTPUT` handling (kernel → userspace → physical hidraw when the
    /// PID descriptor path lands in Wave 6).
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
        posix.close(self.fd);
        self.fd = -1;
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

test "uhid: UhidDevice vtable signature matches OutputDevice" {
    // Compile-time guardrail: if UinputDevice's vtable ever evolves (say, to
    // add a new member), this test forces UhidDevice to be updated in
    // lockstep before the code base can even compile its tests.
    const uhid_vt = std.meta.fieldInfo(@TypeOf(UhidDevice.vtable), .emit).type;
    const uinput_vt = std.meta.fieldInfo(uinput.OutputDevice.VTable, .emit).type;
    try testing.expectEqual(uinput_vt, uhid_vt);
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
    // `extern struct { u16 size; [4096]u8 data }` and inherits a 2-byte
    // alignment, so it sits at offset 4.
    const size = std.mem.readInt(u16, buf[4..6], .little);
    try testing.expectEqual(@as(u16, 4), size);

    // Payload bytes: centred sticks → 128,128,128,128.
    try testing.expectEqual(@as(u8, 128), buf[6]);
    try testing.expectEqual(@as(u8, 128), buf[7]);
    try testing.expectEqual(@as(u8, 128), buf[8]);
    try testing.expectEqual(@as(u8, 128), buf[9]);

    // pollFf stub returns null in Wave 1.
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
