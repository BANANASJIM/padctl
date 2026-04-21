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
