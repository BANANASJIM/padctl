const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const interpreter_mod = src.core.interpreter;
const Interpreter = interpreter_mod.Interpreter;

// --- UHID kernel protocol (minimal) ---

const UHID_DESTROY: u32 = 1;
const UHID_CREATE2: u32 = 11;
const UHID_INPUT2: u32 = 12;

const UHID_DATA_MAX = 4096;
const HID_MAX_DESCRIPTOR_SIZE = 4096;

const UhidCreate2Req = extern struct {
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

const UhidInput2Req = extern struct {
    size: u16,
    data: [UHID_DATA_MAX]u8,
};

// The kernel UHID event is a u32 type followed by a union payload.
// We define the two variants we need as separate structs with a leading type field,
// and write them at their full padded sizes.
const UHID_EVENT_SIZE = 4380; // sizeof(struct uhid_event) on Linux

const UhidCreate2Event = extern struct {
    type: u32,
    payload: UhidCreate2Req,
};

const UhidInput2Event = extern struct {
    type: u32,
    payload: UhidInput2Req,
};

const UhidDestroyEvent = extern struct {
    type: u32,
};

fn openUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
}

fn uhidCreate(fd: posix.fd_t, vid: u16, pid: u16, rd_data: []const u8) !void {
    var ev = std.mem.zeroes(UhidCreate2Event);
    ev.type = UHID_CREATE2;
    const name = "padctl-test";
    @memcpy(ev.payload.name[0..name.len], name);
    ev.payload.rd_size = @intCast(rd_data.len);
    ev.payload.bus = 0x03; // BUS_USB
    ev.payload.vendor = vid;
    ev.payload.product = pid;
    ev.payload.version = 0;
    ev.payload.country = 0;
    @memcpy(ev.payload.rd_data[0..rd_data.len], rd_data);
    const bytes = std.mem.asBytes(&ev);
    // Write full UHID_EVENT_SIZE to satisfy kernel
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

fn uhidInput(fd: posix.fd_t, data: []const u8) !void {
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

fn uhidDestroy(fd: posix.fd_t) void {
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, buf[0..4], UHID_DESTROY, .little);
    _ = posix.write(fd, &buf) catch {};
}

// Minimal HID report descriptor: 2 axes (X, Y), 4-byte report
const test_rd = [_]u8{
    0x05, 0x01, //   Usage Page (Generic Desktop)
    0x09, 0x05, //   Usage (Game Pad)
    0xA1, 0x01, //   Collection (Application)
    0x09, 0x30, //     Usage (X)
    0x09, 0x31, //     Usage (Y)
    0x15, 0x00, //     Logical Minimum (0)
    0x26, 0xFF, 0x00, // Logical Maximum (255)
    0x75, 0x08, //     Report Size (8)
    0x95, 0x04, //     Report Count (4) — 4 bytes total
    0x81, 0x02, //     Input (Data, Var, Abs)
    0xC0, //   End Collection
};

const TEST_VID: u16 = 0xFADE;
const TEST_PID: u16 = 0xCAFE;

fn findHidraw(vid: u16, pid: u16) !?[64]u8 {
    const ioctl_mod = src.io.ioctl_constants;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_mod.HidrawDevinfo = undefined;
        const rc = linux.ioctl(fd, ioctl_mod.HIDIOCGRAWINFO, @intFromPtr(&info));
        if (rc != 0) continue;
        const dev_vid: u16 = @bitCast(info.vendor);
        const dev_pid: u16 = @bitCast(info.product);
        if (dev_vid == vid and dev_pid == pid) {
            var result: [64]u8 = undefined;
            @memcpy(result[0..path.len], path);
            result[path.len] = 0;
            return result;
        }
    }
    return null;
}

// --- Test 1: UHID virtual device appears as hidraw ---

test "uhid: virtual device appears as hidraw" {
    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &test_rd);

    // Give the kernel a moment to create the hidraw node
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const found = try findHidraw(TEST_VID, TEST_PID);
    if (found == null) return error.SkipZigTest; // kernel may not have created it in time

    // Open the hidraw node and inject a report
    const path_buf = found.?;
    const path_end = std.mem.indexOfScalar(u8, &path_buf, 0) orelse path_buf.len;
    const hidraw_path = path_buf[0..path_end];

    const hidraw_fd = try posix.open(hidraw_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(hidraw_fd);

    // Inject a report via UHID_INPUT2
    const report = [_]u8{ 0x80, 0x40, 0xC0, 0x20 };
    try uhidInput(uhid_fd, &report);

    // Poll for data
    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest; // timeout, kernel too slow

    var buf: [64]u8 = undefined;
    const n = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    try testing.expectEqual(@as(usize, 4), n);
    try testing.expectEqualSlices(u8, &report, buf[0..4]);
}

// --- Test 2: Full pipeline with interpreter ---

const simple_toml =
    \\[device]
    \\name = "UHID Test Gamepad"
    \\vid = 0xFADE
    \\pid = 0xCAFE
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[report.fields]
    \\left_x = { offset = 0, type = "u8" }
    \\left_y = { offset = 1, type = "u8" }
    \\right_x = { offset = 2, type = "u8" }
    \\right_y = { offset = 3, type = "u8" }
;

test "uhid: full pipeline hidraw read through interpreter" {
    const allocator = testing.allocator;

    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &test_rd);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const found = try findHidraw(TEST_VID, TEST_PID);
    if (found == null) return error.SkipZigTest;

    const path_buf = found.?;
    const path_end = std.mem.indexOfScalar(u8, &path_buf, 0) orelse path_buf.len;
    const hidraw_path = path_buf[0..path_end];

    const hidraw_fd = try posix.open(hidraw_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0);
    defer posix.close(hidraw_fd);

    // Parse config and create interpreter
    const parsed = try device_mod.parseString(allocator, simple_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Inject a known report: ax=100, ay=200, rx=50, ry=150
    const report = [_]u8{ 100, 200, 50, 150 };
    try uhidInput(uhid_fd, &report);

    // Read from hidraw
    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest;

    var buf: [64]u8 = undefined;
    const n = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    try testing.expectEqual(@as(usize, 4), n);

    // Pass through interpreter (interface 0, no match filter)
    const delta = (try interp.processReport(0, buf[0..n])) orelse return error.SkipZigTest;

    try testing.expectEqual(@as(?i16, 100), delta.ax);
    try testing.expectEqual(@as(?i16, 200), delta.ay);
    try testing.expectEqual(@as(?i16, 50), delta.rx);
    try testing.expectEqual(@as(?i16, 150), delta.ry);
}
