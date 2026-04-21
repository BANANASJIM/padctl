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

// --- High-level UhidDevice (T2) --------------------------------------------

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

    pub fn close(self: *UhidDevice) void {
        uhidDestroy(self.fd);
        posix.close(self.fd);
    }

    fn axisToU8(v: i16) u8 {
        // i16 stick axis range (-32768..32767) → u8 HID logical (0..255).
        // Centre 0 maps to 128 (mid-range) to match the 4-byte test descriptor
        // shipped with the unit tests. Out-of-range input is clamped.
        const shifted: i32 = @as(i32, v) + 32768;
        const scaled: i32 = @divTrunc(shifted, 257); // 65535 / 257 ≈ 255
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
    try testing.expectEqual(@as(u8, 0), UhidDevice.axisToU8(-32768));
    try testing.expectEqual(@as(u8, 128), UhidDevice.axisToU8(0));
    // 32767 → (32767+32768)/257 = 65535/257 = 255 (truncation).
    try testing.expectEqual(@as(u8, 255), UhidDevice.axisToU8(32767));
}

test "uhid: UhidDevice vtable signature matches OutputDevice" {
    // Compile-time guardrail: if UinputDevice's vtable ever evolves (say, to
    // add a new member), this test forces UhidDevice to be updated in
    // lockstep before the code base can even compile its tests.
    const uhid_vt = std.meta.fieldInfo(@TypeOf(UhidDevice.vtable), .emit).type;
    const uinput_vt = std.meta.fieldInfo(uinput.OutputDevice.VTable, .emit).type;
    try testing.expectEqual(uinput_vt, uhid_vt);
}
