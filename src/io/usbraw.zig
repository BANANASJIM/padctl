const std = @import("std");
const io = @import("device_io.zig");

pub const DeviceIO = io.DeviceIO;

const c = @cImport({
    @cInclude("libusb-1.0/libusb.h");
});

// Fixed-size ring buffer: 64 slots x 64 bytes each.
// Overflow drops oldest report and logs a warning.
pub const RingBuffer = struct {
    const SLOTS = 64;
    const SLOT_SIZE = 64;

    slots: [SLOTS][SLOT_SIZE]u8 = undefined,
    lens: [SLOTS]usize = [_]usize{0} ** SLOTS,
    head: usize = 0, // next write pos
    tail: usize = 0, // next read pos
    count: usize = 0,
    mu: std.Thread.Mutex = .{},

    pub fn push(self: *RingBuffer, data: []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();

        if (self.count == SLOTS) {
            // Drop oldest
            self.tail = (self.tail + 1) % SLOTS;
            self.count -= 1;
            std.log.warn("usbraw: ring buffer overflow, dropping oldest report", .{});
        }
        const n = @min(data.len, SLOT_SIZE);
        @memcpy(self.slots[self.head][0..n], data[0..n]);
        self.lens[self.head] = n;
        self.head = (self.head + 1) % SLOTS;
        self.count += 1;
    }

    // Returns bytes copied, or 0 if empty.
    pub fn pop(self: *RingBuffer, buf: []u8) usize {
        self.mu.lock();
        defer self.mu.unlock();

        if (self.count == 0) return 0;
        const n = self.lens[self.tail];
        const copy_len = @min(n, buf.len);
        @memcpy(buf[0..copy_len], self.slots[self.tail][0..copy_len]);
        self.tail = (self.tail + 1) % SLOTS;
        self.count -= 1;
        return copy_len;
    }
};

pub const UsbrawDevice = struct {
    handle: *c.libusb_device_handle,
    ctx: *c.libusb_context,
    ep_in: u8,
    ep_out: u8,
    interface_id: i32,
    pipe_r: std.posix.fd_t,
    pipe_w: std.posix.fd_t,
    ring: RingBuffer,
    should_stop: std.atomic.Value(bool),
    thread: std.Thread,

    pub fn open(
        alloc: std.mem.Allocator,
        vid: u16,
        pid: u16,
        interface_id: u8,
        ep_in: u8,
        ep_out: u8,
    ) !*UsbrawDevice {
        var ctx: ?*c.libusb_context = null;
        if (c.libusb_init(&ctx) != 0) return error.LibusbInit;

        const handle = c.libusb_open_device_with_vid_pid(ctx, vid, pid) orelse {
            c.libusb_exit(ctx);
            return error.NotFound;
        };

        _ = c.libusb_detach_kernel_driver(handle, interface_id);

        const rc = c.libusb_claim_interface(handle, interface_id);
        if (rc == c.LIBUSB_ERROR_BUSY) {
            c.libusb_close(handle);
            c.libusb_exit(ctx);
            return error.Busy;
        }
        if (rc != 0) {
            c.libusb_close(handle);
            c.libusb_exit(ctx);
            return error.ClaimFailed;
        }

        const pipe_fds = try std.posix.pipe();

        const self = try alloc.create(UsbrawDevice);
        self.* = .{
            .handle = handle,
            .ctx = ctx.?,
            .ep_in = ep_in,
            .ep_out = ep_out,
            .interface_id = @intCast(interface_id),
            .pipe_r = pipe_fds[0],
            .pipe_w = pipe_fds[1],
            .ring = .{},
            .should_stop = std.atomic.Value(bool).init(false),
            .thread = undefined,
        };
        self.thread = try std.Thread.spawn(.{}, readLoop, .{self});
        return self;
    }

    fn readLoop(self: *UsbrawDevice) void {
        var buf: [RingBuffer.SLOT_SIZE]u8 = undefined;
        var transferred: c_int = 0;

        while (!self.should_stop.load(.acquire)) {
            const rc = c.libusb_interrupt_transfer(
                self.handle,
                self.ep_in,
                &buf,
                buf.len,
                &transferred,
                100, // 100ms timeout
            );

            if (rc == c.LIBUSB_ERROR_NO_DEVICE) {
                // Device disconnected — write sentinel and exit
                _ = std.posix.write(self.pipe_w, "\x00") catch {};
                break;
            }

            if (rc == 0 and transferred > 0) {
                self.ring.push(buf[0..@intCast(transferred)]);
                _ = std.posix.write(self.pipe_w, "\x01") catch {};
            }
            // LIBUSB_ERROR_TIMEOUT is normal — loop continues
        }
    }

    pub fn deviceIO(self: *UsbrawDevice) DeviceIO {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = DeviceIO.VTable{
        .read = read,
        .write = write,
        .pollfd = pollfd,
        .close = close,
    };

    fn read(ptr: *anyopaque, buf: []u8) DeviceIO.ReadError!usize {
        const self: *UsbrawDevice = @ptrCast(@alignCast(ptr));
        // Drain the pipe byte first
        var dummy: [1]u8 = undefined;
        _ = std.posix.read(self.pipe_r, &dummy) catch {};

        const n = self.ring.pop(buf);
        if (n == 0) return DeviceIO.ReadError.Again;

        // Check sentinel: byte 0x00 means disconnected
        if (dummy[0] == 0x00 and n == 0) return DeviceIO.ReadError.Disconnected;

        return n;
    }

    fn write(ptr: *anyopaque, data: []const u8) DeviceIO.WriteError!void {
        const self: *UsbrawDevice = @ptrCast(@alignCast(ptr));
        var transferred: c_int = 0;
        // libusb wants a mutable pointer even for writes
        var buf: [RingBuffer.SLOT_SIZE]u8 = undefined;
        const n = @min(data.len, buf.len);
        @memcpy(buf[0..n], data[0..n]);

        const rc = c.libusb_interrupt_transfer(
            self.handle,
            self.ep_out,
            &buf,
            @intCast(n),
            &transferred,
            100,
        );
        if (rc == c.LIBUSB_ERROR_NO_DEVICE) return DeviceIO.WriteError.Disconnected;
        if (rc != 0) return DeviceIO.WriteError.Io;
    }

    fn pollfd(ptr: *anyopaque) std.posix.pollfd {
        const self: *UsbrawDevice = @ptrCast(@alignCast(ptr));
        return .{ .fd = self.pipe_r, .events = std.posix.POLL.IN, .revents = 0 };
    }

    fn close(ptr: *anyopaque) void {
        const self: *UsbrawDevice = @ptrCast(@alignCast(ptr));
        self.should_stop.store(true, .release);
        self.thread.join();
        std.posix.close(self.pipe_w);
        std.posix.close(self.pipe_r);
        _ = c.libusb_release_interface(self.handle, self.interface_id);
        c.libusb_close(self.handle);
        c.libusb_exit(self.ctx);
    }
};

// --- Tests ---

test "RingBuffer push/pop basic" {
    var rb: RingBuffer = .{};
    const data = [_]u8{ 0x01, 0x02, 0x03 };
    rb.push(&data);
    var out: [64]u8 = undefined;
    const n = rb.pop(&out);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualSlices(u8, &data, out[0..3]);
}

test "RingBuffer empty pop returns 0" {
    var rb: RingBuffer = .{};
    var out: [64]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), rb.pop(&out));
}

test "RingBuffer full overflow drops oldest" {
    var rb: RingBuffer = .{};
    // Fill all 64 slots with distinguishable content
    var i: u8 = 0;
    while (i < RingBuffer.SLOTS) : (i += 1) {
        rb.push(&[_]u8{i});
    }
    try std.testing.expectEqual(@as(usize, RingBuffer.SLOTS), rb.count);
    // Push one more — should drop slot 0
    rb.push(&[_]u8{0xff});
    try std.testing.expectEqual(@as(usize, RingBuffer.SLOTS), rb.count);
    // First pop should now return slot 1 (slot 0 was dropped)
    var out: [64]u8 = undefined;
    const n = rb.pop(&out);
    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(@as(u8, 1), out[0]);
}

test "RingBuffer wraps around correctly" {
    var rb: RingBuffer = .{};
    const a = [_]u8{0xAA};
    const b = [_]u8{0xBB};
    rb.push(&a);
    rb.push(&b);
    var out: [64]u8 = undefined;
    _ = rb.pop(&out);
    try std.testing.expectEqual(@as(u8, 0xAA), out[0]);
    _ = rb.pop(&out);
    try std.testing.expectEqual(@as(u8, 0xBB), out[0]);
    try std.testing.expectEqual(@as(usize, 0), rb.count);
}
