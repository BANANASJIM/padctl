// Regression: DeviceInstance.deinit must destroy(imu_dev) BEFORE free(imu_name_owned).
// imu_dev.close() runs inside destroy and writes UHID_DESTROY to the fd while
// UhidDevice.name still points at the imu_name backing buffer. If the free order
// is reversed the name pointer dangled during the UHID_DESTROY write.

const std = @import("std");
const posix = std.posix;
const testing = std.testing;

const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const uhid = @import("../io/uhid.zig");
const EventLoop = @import("../event_loop.zig").EventLoop;
const Interpreter = @import("../core/interpreter.zig").Interpreter;
const device_mod = @import("../config/device.zig");

// Ordered event log shared between the recording allocator and the test.
const EventKind = enum { destroy_imu_dev, free_imu_name };
const MAX_EVENTS = 8;
var g_log: [MAX_EVENTS]EventKind = undefined;
var g_count: usize = 0;

fn logEvent(k: EventKind) void {
    if (g_count < MAX_EVENTS) {
        g_log[g_count] = k;
        g_count += 1;
    }
}

// Allocator that records free() calls for two tracked pointers.
const RecordingAllocator = struct {
    inner: std.mem.Allocator,
    imu_dev_ptr: [*]const u8, // raw byte ptr of the UhidDevice allocation
    imu_name_ptr: [*]const u8,

    fn alloc(ctx: *anyopaque, n: usize, al: std.mem.Alignment, ra: usize) ?[*]u8 {
        const s: *RecordingAllocator = @ptrCast(@alignCast(ctx));
        return s.inner.rawAlloc(n, al, ra);
    }

    fn resize(ctx: *anyopaque, buf: []u8, al: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const s: *RecordingAllocator = @ptrCast(@alignCast(ctx));
        return s.inner.rawResize(buf, al, new_len, ra);
    }

    fn free(ctx: *anyopaque, buf: []u8, al: std.mem.Alignment, ra: usize) void {
        const s: *RecordingAllocator = @ptrCast(@alignCast(ctx));
        if (buf.ptr == s.imu_dev_ptr) logEvent(.destroy_imu_dev);
        if (buf.ptr == s.imu_name_ptr) logEvent(.free_imu_name);
        s.inner.rawFree(buf, al, ra);
    }

    fn allocator(self: *RecordingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
            .remap = std.mem.Allocator.noRemap,
        } };
    }
};

const MINIMAL_TOML =
    \\[device]
    \\name = "IMU Ordering Test"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 3
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i16le" }
;

test "DeviceInstance.deinit: imu_name freed after imu_dev destroyed" {
    g_count = 0;

    const base_alloc = testing.allocator;
    const parsed = try device_mod.parseString(base_alloc, MINIMAL_TOML);
    defer parsed.deinit();

    // Pipe: write-end is the fake UHID fd; read-end lets us detect UHID_DESTROY.
    const pipe_fds = try posix.pipe2(.{ .NONBLOCK = true });
    const read_end = pipe_fds[0];
    defer posix.close(read_end);

    // Allocate imu_name and imu_dev struct via base_alloc to get stable pointers,
    // then hand both to RecordingAllocator for tracking.
    const imu_name_raw = try base_alloc.dupe(u8, "IMU Ordering Test IMU");
    const imu_cfg = uhid.Config{
        .name = imu_name_raw,
        .uniq = "test-uniq",
        .vid = 0x1234,
        .pid = 0x5678,
        .descriptor = &[_]u8{ 0x05, 0x01, 0x09, 0x05, 0xA1, 0x01, 0xC0 },
    };
    // initWithFd allocates the UhidDevice struct via base_alloc; we capture the ptr.
    const imu_dev = try uhid.UhidDevice.initWithFd(base_alloc, pipe_fds[1], imu_cfg);

    var rec = RecordingAllocator{
        .inner = base_alloc,
        .imu_dev_ptr = @ptrCast(imu_dev),
        .imu_name_ptr = imu_name_raw.ptr,
    };
    const alloc = rec.allocator();

    const devices = try alloc.alloc(DeviceIO, 0);
    const loop = try EventLoop.initManaged();

    var inst = DeviceInstance{
        .allocator = alloc,
        .devices = devices,
        .loop = loop,
        .interp = Interpreter.init(&parsed.value),
        .mapper = null,
        .owner = .none,
        .primary_output = null,
        .imu_output = null,
        .imu_dev = imu_dev,
        .imu_name_owned = imu_name_raw,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = &parsed.value,
        .pending_mapping = null,
        .stopped = false,
    };

    inst.deinit();

    // Confirm UHID_DESTROY reached the pipe (imu_dev.close() actually ran).
    var buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const n = posix.read(read_end, &buf) catch 0;
    try testing.expect(n >= @sizeOf(u32));
    try testing.expectEqual(uhid.UHID_DESTROY, std.mem.readInt(u32, buf[0..4], .little));

    // Both allocator events must have fired.
    try testing.expectEqual(@as(usize, 2), g_count);

    // destroy(imu_dev) must precede free(imu_name_owned).
    try testing.expectEqual(EventKind.destroy_imu_dev, g_log[0]);
    try testing.expectEqual(EventKind.free_imu_name, g_log[1]);
}
