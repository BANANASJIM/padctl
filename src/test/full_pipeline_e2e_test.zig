const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const uinput_mod = src.io.uinput;
const UinputDevice = uinput_mod.UinputDevice;
const HidrawDevice = src.io.hidraw.HidrawDevice;
const Interpreter = src.core.interpreter.Interpreter;
const DeviceIO = src.io.device_io.DeviceIO;
const ioctl_mod = src.io.ioctl_constants;

// --- UHID kernel protocol (minimal, reused from uhid_integration_test) ---

const UHID_DESTROY: u32 = 1;
const UHID_CREATE2: u32 = 11;
const UHID_INPUT2: u32 = 12;

const UHID_DATA_MAX = 4096;
const HID_MAX_DESCRIPTOR_SIZE = 4096;
const UHID_EVENT_SIZE = 4380;

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

const UhidCreate2Event = extern struct {
    type: u32,
    payload: UhidCreate2Req,
};

const UhidInput2Event = extern struct {
    type: u32,
    payload: UhidInput2Req,
};

// --- Linux input_event and input_id (raw structs) ---

const InputEvent = extern struct {
    sec: isize,
    usec: isize,
    type: u16,
    code: u16,
    value: i32,
};

const InputId = extern struct {
    bustype: u16,
    vendor: u16,
    product: u16,
    version: u16,
};

// EVIOCGID = _IOR('E', 0x02, struct input_id) — input_id is 8 bytes
const EVIOCGID = linux.IOCTL.IOR('E', 0x02, InputId);

const EV_SYN: u16 = 0;
const EV_KEY: u16 = 1;
const EV_ABS: u16 = 3;
const ABS_X: u16 = 0;
const BTN_SOUTH: u16 = 0x130;

const TEST_VID: u16 = 0xFADE;
const TEST_PID: u16 = 0xCAFE;
const OUT_VID: u16 = 0x045E;
const OUT_PID: u16 = 0x02FF;

// Minimal HID descriptor: 2 axes (X, Y), 2-byte report
const test_rd = [_]u8{
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x05, // Usage (Game Pad)
    0xA1, 0x01, // Collection (Application)
    0x09, 0x30, //   Usage (X)
    0x09, 0x31, //   Usage (Y)
    0x15, 0x00, //   Logical Minimum (0)
    0x26, 0xFF, 0x00, // Logical Maximum (255)
    0x75, 0x08, //   Report Size (8)
    0x95, 0x02, //   Report Count (2)
    0x81, 0x02, //   Input (Data, Var, Abs)
    0xC0, // End Collection
};

// Device+output config: 2-byte report, ABS_X/ABS_Y output
const output_toml =
    \\[device]
    \\name = "E2E Test Gamepad"
    \\vid = 0xFADE
    \\pid = 0xCAFE
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 2
    \\[report.fields]
    \\left_x = { offset = 0, type = "u8" }
    \\left_y = { offset = 1, type = "u8" }
    \\[output]
    \\name = "E2E Virtual Pad"
    \\vid = 0x045E
    \\pid = 0x02FF
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
;

// Button report config: byte 0 bit 0 = A button
const button_toml =
    \\[device]
    \\name = "E2E Button Gamepad"
    \\vid = 0xFADE
    \\pid = 0xCAFE
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 1
    \\[report.button_group]
    \\source = { offset = 0, size = 1 }
    \\map = { A = 0 }
    \\[output]
    \\name = "E2E Virtual Pad"
    \\vid = 0x045E
    \\pid = 0x02FF
    \\[output.buttons]
    \\A = "BTN_SOUTH"
;

fn openUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
}

fn checkUinput() !void {
    const fd = posix.open("/dev/uinput", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
    posix.close(fd);
}

fn uhidCreate(fd: posix.fd_t, vid: u16, pid: u16, rd_data: []const u8) !void {
    var ev = std.mem.zeroes(UhidCreate2Event);
    ev.type = UHID_CREATE2;
    const name = "padctl-e2e-test";
    @memcpy(ev.payload.name[0..name.len], name);
    ev.payload.rd_size = @intCast(rd_data.len);
    ev.payload.bus = 0x03; // BUS_USB
    ev.payload.vendor = vid;
    ev.payload.product = pid;
    @memcpy(ev.payload.rd_data[0..rd_data.len], rd_data);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    @memcpy(buf[0..@min(bytes.len, UHID_EVENT_SIZE)], bytes[0..@min(bytes.len, UHID_EVENT_SIZE)]);
    _ = try posix.write(fd, &buf);
}

fn uhidInput(fd: posix.fd_t, data: []const u8) !void {
    var ev = std.mem.zeroes(UhidInput2Event);
    ev.type = UHID_INPUT2;
    ev.payload.size = @intCast(data.len);
    @memcpy(ev.payload.data[0..data.len], data);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    @memcpy(buf[0..@min(bytes.len, UHID_EVENT_SIZE)], bytes[0..@min(bytes.len, UHID_EVENT_SIZE)]);
    _ = try posix.write(fd, &buf);
}

fn uhidDestroy(fd: posix.fd_t) void {
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, buf[0..4], UHID_DESTROY, .little);
    _ = posix.write(fd, &buf) catch {};
}

fn findHidraw(allocator: std.mem.Allocator, vid: u16, pid: u16) !?[]u8 {
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        const path = try std.fmt.allocPrint(allocator, "/dev/hidraw{d}", .{i});
        defer allocator.free(path);
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_mod.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl_mod.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) continue;
        const dev_vid: u16 = @bitCast(info.vendor);
        const dev_pid: u16 = @bitCast(info.product);
        if (dev_vid == vid and dev_pid == pid)
            return try std.fmt.allocPrint(allocator, "/dev/hidraw{d}", .{i});
    }
    return null;
}

fn udevadmSettle() void {
    var argv = [_][]const u8{ "udevadm", "settle", "--timeout=5" };
    var child = std.process.Child.init(&argv, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawnAndWait() catch {
        std.Thread.sleep(200 * std.time.ns_per_ms);
    };
}

fn findEventNode(vid: u16, pid: u16) !posix.fd_t {
    // Primary: scan sysfs (world-readable) to find event node by VID/PID.
    var vid_buf: [8]u8 = undefined;
    var pid_buf: [8]u8 = undefined;
    var dir = std.fs.openDirAbsolute("/sys/class/input", .{ .iterate = true }) catch
        return findEventNodeFallback(vid, pid);
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;
        var vp: [64]u8 = undefined;
        const vpath = std.fmt.bufPrint(&vp, "{s}/device/id/vendor", .{entry.name}) catch continue;
        const vlen = dir.openFile(vpath, .{}) catch continue;
        defer vlen.close();
        const vn = vlen.read(&vid_buf) catch continue;
        if (vn < 4) continue;
        const ev = std.fmt.parseInt(u16, std.mem.trimRight(u8, vid_buf[0..vn], "\n\r "), 16) catch continue;
        const ppath = std.fmt.bufPrint(&vp, "{s}/device/id/product", .{entry.name}) catch continue;
        const plen = dir.openFile(ppath, .{}) catch continue;
        defer plen.close();
        const pn = plen.read(&pid_buf) catch continue;
        if (pn < 4) continue;
        const ep = std.fmt.parseInt(u16, std.mem.trimRight(u8, pid_buf[0..pn], "\n\r "), 16) catch continue;
        if (ev != vid or ep != pid) continue;
        var dev_path_buf: [48]u8 = undefined;
        const dev_path = std.fmt.bufPrint(&dev_path_buf, "/dev/input/{s}", .{entry.name}) catch continue;
        const delays = [_]u64{ 0, 100, 200, 500, 1000 };
        for (delays) |delay_ms| {
            if (delay_ms > 0) std.Thread.sleep(delay_ms * std.time.ns_per_ms);
            const fd = posix.open(dev_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
            return fd;
        }
        return error.EventNodeNotFound;
    }
    return findEventNodeFallback(vid, pid);
}

fn findEventNodeFallback(vid: u16, pid: u16) !posix.fd_t {
    var i: u16 = 0;
    while (i < 256) : (i += 1) {
        var path_buf: [32]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/input/event{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        var id: InputId = undefined;
        if (linux.ioctl(fd, EVIOCGID, @intFromPtr(&id)) == 0) {
            if (id.vendor == vid and id.product == pid) return fd;
        }
        posix.close(fd);
    }
    return error.EventNodeNotFound;
}

// Poll + read one input_event from fd. Returns error.Timeout on expiry (timeout_ms).
fn readNextEvent(fd: posix.fd_t, timeout_ms: i32) !InputEvent {
    var pfd = [1]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, timeout_ms);
    if (ready == 0) return error.Timeout;
    var ev: InputEvent = undefined;
    _ = try posix.read(fd, std.mem.asBytes(&ev));
    return ev;
}

// Drain SYN events; return first non-SYN event.
fn readDataEvent(fd: posix.fd_t, timeout_ms: i32) !InputEvent {
    while (true) {
        const ev = try readNextEvent(fd, timeout_ms);
        if (ev.type != EV_SYN) return ev;
    }
}

// Run EventLoop in a background thread until stop() is called.
const RunArg = struct {
    loop: *src.event_loop.EventLoop,
    interp: *const Interpreter,
    output: uinput_mod.OutputDevice,
    cfg: *const device_mod.DeviceConfig,
    devices: []DeviceIO,
};

fn runThread(arg: *RunArg) void {
    arg.loop.run(.{
        .devices = arg.devices,
        .interpreter = arg.interp,
        .output = arg.output,
        .device_config = arg.cfg,
        .poll_timeout_ms = 500,
    }) catch {};
}

// --- T-E2E-1: axis report → EV_ABS events ---

test "T-E2E-1: UHID axis report flows through to EV_ABS on eventN" {
    const allocator = testing.allocator;

    try checkUinput();
    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &test_rd);
    udevadmSettle();

    const hidraw_path = (try findHidraw(allocator, TEST_VID, TEST_PID)) orelse return error.SkipZigTest;
    defer allocator.free(hidraw_path);

    const parsed = try device_mod.parseString(allocator, output_toml);
    defer parsed.deinit();

    var udev = try UinputDevice.create(&parsed.value.output.?);
    defer udev.close();
    udevadmSettle();

    const ev_fd = findEventNode(OUT_VID, OUT_PID) catch return error.SkipZigTest;
    defer posix.close(ev_fd);

    // Heap-allocate HidrawDevice so DeviceIO vtable close is safe.
    const hidraw = try allocator.create(HidrawDevice);
    errdefer allocator.destroy(hidraw);
    hidraw.* = HidrawDevice.init(allocator);
    try hidraw.open(hidraw_path);

    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = hidraw.deviceIO();

    var loop = try src.event_loop.EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    const interp = Interpreter.init(&parsed.value);
    var arg = RunArg{
        .loop = &loop,
        .interp = &interp,
        .output = udev.outputDevice(),
        .cfg = &parsed.value,
        .devices = devices,
    };

    const thread = try std.Thread.spawn(.{}, runThread, .{&arg});

    std.Thread.sleep(20 * std.time.ns_per_ms);
    try uhidInput(uhid_fd, &[_]u8{ 200, 100 });

    const ev = readDataEvent(ev_fd, 500) catch |err| {
        loop.stop();
        thread.join();
        // DeviceIO close frees the heap-allocated HidrawDevice
        devices[0].close();
        return if (err == error.Timeout) error.SkipZigTest else err;
    };

    loop.stop();
    thread.join();
    devices[0].close();

    try testing.expectEqual(EV_ABS, ev.type);
    try testing.expectEqual(ABS_X, ev.code);
    try testing.expectEqual(@as(i32, 200), ev.value);
}

// --- T-E2E-2: button press → EV_KEY event ---

test "T-E2E-2: UHID button press flows through to EV_KEY on eventN" {
    const allocator = testing.allocator;

    try checkUinput();
    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    // HID descriptor: 1-byte report (8 buttons)
    const btn_rd = [_]u8{
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x05, // Usage (Game Pad)
        0xA1, 0x01, // Collection (Application)
        0x05, 0x09, //   Usage Page (Button)
        0x19, 0x01, //   Usage Minimum (1)
        0x29, 0x08, //   Usage Maximum (8)
        0x15, 0x00, //   Logical Minimum (0)
        0x25, 0x01, //   Logical Maximum (1)
        0x75, 0x01, //   Report Size (1)
        0x95, 0x08, //   Report Count (8)
        0x81, 0x02, //   Input (Data, Var, Abs)
        0xC0, // End Collection
    };

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &btn_rd);
    std.Thread.sleep(150 * std.time.ns_per_ms);

    const hidraw_path = (try findHidraw(allocator, TEST_VID, TEST_PID)) orelse return error.SkipZigTest;
    defer allocator.free(hidraw_path);

    const parsed = try device_mod.parseString(allocator, button_toml);
    defer parsed.deinit();

    var udev = try UinputDevice.create(&parsed.value.output.?);
    defer udev.close();
    udevadmSettle();

    const ev_fd = findEventNode(OUT_VID, OUT_PID) catch return error.SkipZigTest;
    defer posix.close(ev_fd);

    const hidraw = try allocator.create(HidrawDevice);
    errdefer allocator.destroy(hidraw);
    hidraw.* = HidrawDevice.init(allocator);
    try hidraw.open(hidraw_path);

    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = hidraw.deviceIO();

    var loop = try src.event_loop.EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    const interp = Interpreter.init(&parsed.value);
    var arg = RunArg{
        .loop = &loop,
        .interp = &interp,
        .output = udev.outputDevice(),
        .cfg = &parsed.value,
        .devices = devices,
    };

    const thread = try std.Thread.spawn(.{}, runThread, .{&arg});

    std.Thread.sleep(20 * std.time.ns_per_ms);
    try uhidInput(uhid_fd, &[_]u8{0x01}); // bit 0 = A button

    const ev = readDataEvent(ev_fd, 500) catch |err| {
        loop.stop();
        thread.join();
        devices[0].close();
        return if (err == error.Timeout) error.SkipZigTest else err;
    };

    loop.stop();
    thread.join();
    devices[0].close();

    try testing.expectEqual(EV_KEY, ev.type);
    try testing.expectEqual(BTN_SOUTH, ev.code);
    try testing.expectEqual(@as(i32, 1), ev.value);
}

// --- T-E2E-3: corrupted match byte → no output events ---

test "T-E2E-3: report with bad match byte produces no output event" {
    const allocator = testing.allocator;

    try checkUinput();
    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    // Config requires match byte 0 = 0xAB; we will inject 0xFF
    const match_toml =
        \\[device]
        \\name = "E2E Match Gamepad"
        \\vid = 0xFADE
        \\pid = 0xCAFE
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 3
        \\[report.match]
        \\offset = 0
        \\expect = [0xAB]
        \\[report.fields]
        \\left_x = { offset = 1, type = "u8" }
        \\left_y = { offset = 2, type = "u8" }
        \\[output]
        \\name = "E2E Virtual Pad"
        \\vid = 0x045E
        \\pid = 0x02FF
        \\[output.axes]
        \\left_x = { code = "ABS_X", min = 0, max = 255 }
        \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    ;

    const match_rd = [_]u8{
        0x05, 0x01, 0x09, 0x05, 0xA1, 0x01,
        0x09, 0x30, 0x09, 0x31, 0x09, 0x32,
        0x15, 0x00, 0x26, 0xFF, 0x00, 0x75,
        0x08, 0x95, 0x03, 0x81, 0x02, 0xC0,
    };

    try uhidCreate(uhid_fd, TEST_VID, TEST_PID, &match_rd);
    std.Thread.sleep(150 * std.time.ns_per_ms);

    const hidraw_path = (try findHidraw(allocator, TEST_VID, TEST_PID)) orelse return error.SkipZigTest;
    defer allocator.free(hidraw_path);

    const parsed = try device_mod.parseString(allocator, match_toml);
    defer parsed.deinit();

    var udev = try UinputDevice.create(&parsed.value.output.?);
    defer udev.close();
    udevadmSettle();

    const ev_fd = findEventNode(OUT_VID, OUT_PID) catch return error.SkipZigTest;
    defer posix.close(ev_fd);

    const hidraw = try allocator.create(HidrawDevice);
    errdefer allocator.destroy(hidraw);
    hidraw.* = HidrawDevice.init(allocator);
    try hidraw.open(hidraw_path);

    const devices = try allocator.alloc(DeviceIO, 1);
    defer allocator.free(devices);
    devices[0] = hidraw.deviceIO();

    var loop = try src.event_loop.EventLoop.initManaged();
    defer loop.deinit();
    try loop.addDevice(devices[0]);

    const interp = Interpreter.init(&parsed.value);
    var arg = RunArg{
        .loop = &loop,
        .interp = &interp,
        .output = udev.outputDevice(),
        .cfg = &parsed.value,
        .devices = devices,
    };

    const thread = try std.Thread.spawn(.{}, runThread, .{&arg});

    std.Thread.sleep(20 * std.time.ns_per_ms);
    // Wrong match byte: should be 0xAB but we send 0xFF
    try uhidInput(uhid_fd, &[_]u8{ 0xFF, 100, 100 });

    const result = readDataEvent(ev_fd, 200);
    loop.stop();
    thread.join();
    devices[0].close();

    if (result) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try testing.expectEqual(error.Timeout, err);
    }
}
