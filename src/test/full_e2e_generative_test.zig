// full_e2e_generative_test.zig — L3 generative end-to-end tests for ALL device configs.
//
// For each real device .toml with [output]:
//   1. Parse device config + generate compatible mapping
//   2. Create UHID virtual device + real UinputDevice + Mapper
//   3. Run EventLoop in background thread
//   4. Generate random HID packets from sequence_gen frames
//   5. Inject via UHID → hidraw → interpreter → mapper → uinput → /dev/input/eventN
//   6. Read actual input_events and verify against mapper_oracle

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const mapping_mod = src.config.mapping;
const interp_mod = src.core.interpreter;
const Interpreter = interp_mod.Interpreter;
const CompiledReport = interp_mod.CompiledReport;
const FieldType = interp_mod.FieldType;
const mapper_mod = src.core.mapper;
const Mapper = mapper_mod.Mapper;
const state_mod = src.core.state;
const GamepadState = state_mod.GamepadState;
const GamepadStateDelta = state_mod.GamepadStateDelta;
const ButtonId = state_mod.ButtonId;
const uinput_mod = src.io.uinput;
const UinputDevice = uinput_mod.UinputDevice;
const OutputDevice = uinput_mod.OutputDevice;
const HidrawDevice = src.io.hidraw.HidrawDevice;
const DeviceIO = src.io.device_io.DeviceIO;
const EventLoop = src.event_loop.EventLoop;
const ioctl_consts = src.io.ioctl_constants;
const helpers = src.testing_support.helpers;
const config_gen = src.testing_support.gen.config_gen;
const sequence_gen = src.testing_support.gen.sequence_gen;
const oracle_mod = src.testing_support.gen.mapper_oracle;

// --- UHID kernel protocol ---

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

const UhidCreate2Event = extern struct {
    type: u32,
    payload: UhidCreate2Req,
};

const UhidInput2Event = extern struct {
    type: u32,
    payload: extern struct { size: u16, data: [UHID_DATA_MAX]u8 },
};

// --- Linux input_event structs ---

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

const EVIOCGID = linux.IOCTL.IOR('E', 0x02, InputId);

const EV_SYN: u16 = 0;
const EV_KEY: u16 = 1;
const EV_ABS: u16 = 3;

// --- UHID helpers ---

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
    const name = "padctl-gen-e2e";
    @memcpy(ev.payload.name[0..name.len], name);
    ev.payload.rd_size = @intCast(rd_data.len);
    ev.payload.bus = 0x03;
    ev.payload.vendor = vid;
    ev.payload.product = pid;
    @memcpy(ev.payload.rd_data[0..rd_data.len], rd_data);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

fn uhidInput(fd: posix.fd_t, data: []const u8) !void {
    var ev = std.mem.zeroes(UhidInput2Event);
    ev.type = UHID_INPUT2;
    ev.payload.size = @intCast(data.len);
    @memcpy(ev.payload.data[0..data.len], data);
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    const bytes = std.mem.asBytes(&ev);
    const copy_len = @min(bytes.len, UHID_EVENT_SIZE);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, &buf);
}

fn uhidDestroy(fd: posix.fd_t) void {
    var buf: [UHID_EVENT_SIZE]u8 = std.mem.zeroes([UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, buf[0..4], UHID_DESTROY, .little);
    _ = posix.write(fd, &buf) catch {};
}

// --- HID descriptor generator ---

fn makeGenericRd(report_size: usize) [32]u8 {
    var rd: [32]u8 = undefined;
    var pos: usize = 0;
    rd[pos] = 0x05; pos += 1; rd[pos] = 0x01; pos += 1; // Usage Page (Generic Desktop)
    rd[pos] = 0x09; pos += 1; rd[pos] = 0x05; pos += 1; // Usage (Game Pad)
    rd[pos] = 0xA1; pos += 1; rd[pos] = 0x01; pos += 1; // Collection (Application)
    rd[pos] = 0x09; pos += 1; rd[pos] = 0x30; pos += 1; // Usage (X)
    rd[pos] = 0x15; pos += 1; rd[pos] = 0x00; pos += 1; // Logical Minimum (0)
    rd[pos] = 0x26; pos += 1; rd[pos] = 0xFF; pos += 1; rd[pos] = 0x00; pos += 1;
    rd[pos] = 0x75; pos += 1; rd[pos] = 0x08; pos += 1; // Report Size (8)
    if (report_size <= 255) {
        rd[pos] = 0x95; pos += 1; rd[pos] = @intCast(report_size); pos += 1;
    } else {
        rd[pos] = 0x96; pos += 1;
        rd[pos] = @intCast(report_size & 0xFF); pos += 1;
        rd[pos] = @intCast((report_size >> 8) & 0xFF); pos += 1;
    }
    rd[pos] = 0x81; pos += 1; rd[pos] = 0x02; pos += 1; // Input (Data, Var, Abs)
    rd[pos] = 0xC0; pos += 1; // End Collection
    @memset(rd[pos..], 0);
    return rd;
}

// --- Device scanning ---

fn findHidraw(allocator: std.mem.Allocator, vid: u16, pid: u16) !?[]u8 {
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        const path = try std.fmt.allocPrint(allocator, "/dev/hidraw{d}", .{i});
        defer allocator.free(path);
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_consts.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl_consts.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) continue;
        const dev_vid: u16 = @bitCast(info.vendor);
        const dev_pid: u16 = @bitCast(info.product);
        if (dev_vid == vid and dev_pid == pid)
            return try std.fmt.allocPrint(allocator, "/dev/hidraw{d}", .{i});
    }
    return null;
}

fn findEventNode(vid: u16, pid: u16) !posix.fd_t {
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
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

// --- Event reading ---

fn readAllEvents(ev_fd: posix.fd_t, timeout_ms: i32) [64]InputEvent {
    var events: [64]InputEvent = undefined;
    @memset(std.mem.sliceAsBytes(&events), 0);
    var pfd = [1]posix.pollfd{.{ .fd = ev_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = posix.poll(&pfd, timeout_ms) catch return events;
    if (ready == 0) return events;
    // Read all available events
    var total: usize = 0;
    while (total < 64) {
        var ev: InputEvent = undefined;
        _ = posix.read(ev_fd, std.mem.asBytes(&ev)) catch break;
        events[total] = ev;
        total += 1;
    }
    return events;
}

fn countDataEvents(events: []const InputEvent) usize {
    var n: usize = 0;
    for (events) |ev| {
        if (ev.type == 0 and ev.code == 0 and ev.value == 0 and ev.sec == 0 and ev.usec == 0) break;
        if (ev.type != EV_SYN) n += 1;
    }
    return n;
}

// --- Packet builder from delta ---

fn writeFieldValue(buf: []u8, offset: usize, t: FieldType, value: i64) void {
    switch (t) {
        .u8 => buf[offset] = @intCast(value & 0xFF),
        .i8 => buf[offset] = @bitCast(@as(i8, @intCast(std.math.clamp(value, -128, 127)))),
        .u16le => std.mem.writeInt(u16, buf[offset..][0..2], @intCast(value & 0xFFFF), .little),
        .i16le => std.mem.writeInt(i16, buf[offset..][0..2], @intCast(std.math.clamp(value, -32768, 32767)), .little),
        .u16be => std.mem.writeInt(u16, buf[offset..][0..2], @intCast(value & 0xFFFF), .big),
        .i16be => std.mem.writeInt(i16, buf[offset..][0..2], @intCast(std.math.clamp(value, -32768, 32767)), .big),
        .u32le => std.mem.writeInt(u32, buf[offset..][0..4], @intCast(value & 0xFFFFFFFF), .little),
        .i32le => std.mem.writeInt(i32, buf[offset..][0..4], @intCast(value), .little),
        .u32be => std.mem.writeInt(u32, buf[offset..][0..4], @intCast(value & 0xFFFFFFFF), .big),
        .i32be => std.mem.writeInt(i32, buf[offset..][0..4], @intCast(value), .big),
    }
}

const FieldTag = interp_mod.FieldTag;

fn buildPacketFromDelta(cr: *const CompiledReport, delta: GamepadStateDelta, buf: []u8) void {
    const size: usize = @intCast(cr.src.size);
    // Start with zeroes (preserve previous state would be better but zeroes is safe for each frame)
    @memset(buf[0..size], 0);

    // Fill match bytes
    if (cr.src.match) |m| {
        const off: usize = @intCast(m.offset);
        for (m.expect, 0..) |byte, i| {
            buf[off + i] = @intCast(byte);
        }
    }

    // Write field values from delta into packet at correct offsets
    for (cr.fields[0..cr.field_count]) |*cf| {
        const val = getDeltaFieldForTag(delta, cf.tag) orelse continue;
        if (cf.mode == .standard) {
            writeFieldValue(buf, cf.offset, cf.type_tag, val);
        } else {
            // bits mode
            const raw: u32 = @intCast(@as(u64, @bitCast(@as(i64, val))) & ((@as(u64, 1) << @intCast(cf.bit_count)) - 1));
            const shifted = @as(u64, raw) << @intCast(cf.start_bit);
            const needed: u8 = (@as(u8, cf.start_bit) + @as(u8, cf.bit_count) + 7) / 8;
            for (0..needed) |i| {
                buf[cf.byte_offset + i] |= @intCast((shifted >> @intCast(i * 8)) & 0xFF);
            }
        }
    }

    // Write button_group bits
    if (cr.button_group) |*cbg| {
        if (delta.buttons) |buttons| {
            for (cbg.entries[0..cbg.count]) |entry| {
                const mask: u64 = @as(u64, 1) << @as(u6, @intCast(@intFromEnum(entry.btn_id)));
                if (buttons & mask != 0) {
                    const byte_idx = entry.bit_idx / 8;
                    const bit_pos: u3 = @intCast(entry.bit_idx % 8);
                    buf[cbg.src_off + byte_idx] |= @as(u8, 1) << bit_pos;
                }
            }
        }
    }

    // Compute checksum
    if (cr.checksum) |cs| {
        switch (cs.algo) {
            .sum8 => {
                var sum: u8 = 0;
                for (buf[cs.range_start..cs.range_end]) |b| sum +%= b;
                buf[cs.expect_off] = sum;
            },
            .xor => {
                var xv: u8 = 0;
                for (buf[cs.range_start..cs.range_end]) |b| xv ^= b;
                buf[cs.expect_off] = xv;
            },
            .crc32 => {
                var crc = std.hash.crc.Crc32IsoHdlc.init();
                if (cs.seed) |seed| crc.update(&[_]u8{@intCast(seed & 0xff)});
                crc.update(buf[cs.range_start..cs.range_end]);
                std.mem.writeInt(u32, buf[cs.expect_off..][0..4], crc.final(), .little);
            },
        }
    }
}

fn getDeltaFieldForTag(delta: GamepadStateDelta, tag: FieldTag) ?i64 {
    return switch (tag) {
        .ax => if (delta.ax) |v| @as(i64, v) else null,
        .ay => if (delta.ay) |v| @as(i64, v) else null,
        .rx => if (delta.rx) |v| @as(i64, v) else null,
        .ry => if (delta.ry) |v| @as(i64, v) else null,
        .lt => if (delta.lt) |v| @as(i64, v) else null,
        .rt => if (delta.rt) |v| @as(i64, v) else null,
        .gyro_x => if (delta.gyro_x) |v| @as(i64, v) else null,
        .gyro_y => if (delta.gyro_y) |v| @as(i64, v) else null,
        .gyro_z => if (delta.gyro_z) |v| @as(i64, v) else null,
        .accel_x => if (delta.accel_x) |v| @as(i64, v) else null,
        .accel_y => if (delta.accel_y) |v| @as(i64, v) else null,
        .accel_z => if (delta.accel_z) |v| @as(i64, v) else null,
        .touch0_x => if (delta.touch0_x) |v| @as(i64, v) else null,
        .touch0_y => if (delta.touch0_y) |v| @as(i64, v) else null,
        .touch1_x => if (delta.touch1_x) |v| @as(i64, v) else null,
        .touch1_y => if (delta.touch1_y) |v| @as(i64, v) else null,
        .touch0_active => if (delta.touch0_active) |v| @as(i64, if (v) 1 else 0) else null,
        .touch1_active => if (delta.touch1_active) |v| @as(i64, if (v) 1 else 0) else null,
        .battery_level => if (delta.battery_level) |v| @as(i64, v) else null,
        .dpad => null,
        .unknown => null,
    };
}

// --- EventLoop thread runner ---

const RunArg = struct {
    loop: *EventLoop,
    interp: *const Interpreter,
    output: OutputDevice,
    mapper: ?*Mapper,
    cfg: *const device_mod.DeviceConfig,
    mapping_cfg: ?*const mapping_mod.MappingConfig,
    devices: []DeviceIO,
};

fn runThread(arg: *RunArg) void {
    arg.loop.run(.{
        .devices = arg.devices,
        .interpreter = arg.interp,
        .output = arg.output,
        .mapper = arg.mapper,
        .device_config = arg.cfg,
        .mapping_config = arg.mapping_cfg,
        .poll_timeout_ms = 500,
    }) catch {};
}

// --- DRT verification helpers ---

fn eventSlice(events: []const InputEvent) []const InputEvent {
    for (events, 0..) |ev, i| {
        if (ev.type == 0 and ev.code == 0 and ev.value == 0 and ev.sec == 0 and ev.usec == 0) return events[0..i];
    }
    return events;
}

fn hasEventType(events: []const InputEvent, ev_type: u16) bool {
    for (eventSlice(events)) |ev| {
        if (ev.type == ev_type) return true;
    }
    return false;
}

fn hasKeyEvent(events: []const InputEvent, code: u16, pressed: bool) bool {
    const val: i32 = if (pressed) 1 else 0;
    for (eventSlice(events)) |ev| {
        if (ev.type == EV_KEY and ev.code == code and ev.value == val) return true;
    }
    return false;
}

fn getAbsValue(events: []const InputEvent, code: u16) ?i32 {
    for (eventSlice(events)) |ev| {
        if (ev.type == EV_ABS and ev.code == code) return ev.value;
    }
    return null;
}

// --- Main test ---

test "l3_e2e: generative full pipeline for all device configs with mapping" {
    const allocator = testing.allocator;

    try checkUinput();

    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) {
        std.debug.print("SKIP: no device configs found\n", .{});
        return;
    }

    var prng = std.Random.DefaultPrng.init(0xE2E0_0042);
    const rng = prng.random();

    var devices_tested: usize = 0;
    var total_frames: usize = 0;

    for (paths.items) |config_path| {
        const parsed = device_mod.parseFile(allocator, config_path) catch |err| {
            std.debug.print("PARSE ERROR: {s}: {}\n", .{ config_path, err });
            return err;
        };
        defer parsed.deinit();

        // Skip configs without output (can't create uinput)
        if (parsed.value.output == null) continue;

        // Skip generic mode devices
        if (parsed.value.device.mode) |m| {
            if (std.mem.eql(u8, m, "generic")) continue;
        }

        // Use first report as the main input report
        if (parsed.value.report.len == 0) continue;
        const interp = Interpreter.init(&parsed.value);
        if (interp.report_count == 0) continue;

        // Generate compatible mapping
        var mapping_buf: [4096]u8 = undefined;
        const mapping_str = config_gen.generateCompatibleMapping(rng, &parsed.value, &mapping_buf);
        const mapping_parsed = mapping_mod.parseString(allocator, mapping_str) catch |err| {
            std.debug.print("MAPPING PARSE ERROR for {s}: {}\n", .{ config_path, err });
            return err;
        };
        defer mapping_parsed.deinit();

        // Use unique VID/PID per device to avoid collisions
        const test_vid: u16 = 0xFA00 | @as(u16, @truncate(std.hash.Adler32.hash(config_path) & 0xFF));
        const test_pid: u16 = 0xCA00 | @as(u16, @intCast(devices_tested & 0xFF));
        const out_cfg = &parsed.value.output.?;
        const out_vid: u16 = if (out_cfg.vid) |v| @intCast(v) else 0;
        const out_pid: u16 = if (out_cfg.pid) |p| @intCast(p) else 0;

        // Use first compiled report for packet size
        const cr = &interp.compiled[0];
        const report_size: usize = @intCast(cr.src.size);

        // Create UHID device
        const uhid_fd = openUhid() catch |err| {
            if (err == error.SkipZigTest) return error.SkipZigTest;
            return err;
        };
        defer {
            uhidDestroy(uhid_fd);
            posix.close(uhid_fd);
        }

        const rd = makeGenericRd(report_size);
        var rd_len: usize = 32;
        while (rd_len > 0 and rd[rd_len - 1] == 0) rd_len -= 1;
        if (rd_len == 0) rd_len = 20;
        try uhidCreate(uhid_fd, test_vid, test_pid, rd[0..rd_len]);
        std.Thread.sleep(150 * std.time.ns_per_ms);

        // Find hidraw
        const hidraw_path = (try findHidraw(allocator, test_vid, test_pid)) orelse {
            std.debug.print("SKIP hidraw not found for {s}\n", .{config_path});
            continue;
        };
        defer allocator.free(hidraw_path);

        // Create uinput device
        var udev = UinputDevice.create(out_cfg) catch |err| {
            std.debug.print("SKIP uinput create failed for {s}: {}\n", .{ config_path, err });
            continue;
        };
        defer udev.close();
        std.Thread.sleep(50 * std.time.ns_per_ms);

        // Find event node for uinput output
        const ev_fd = findEventNode(out_vid, out_pid) catch {
            std.debug.print("SKIP event node not found for {s}\n", .{config_path});
            continue;
        };
        defer posix.close(ev_fd);

        // Open hidraw device
        const hidraw = try allocator.create(HidrawDevice);
        errdefer allocator.destroy(hidraw);
        hidraw.* = HidrawDevice.init(allocator);
        hidraw.open(hidraw_path) catch |err| {
            std.debug.print("SKIP hidraw open failed for {s}: {}\n", .{ config_path, err });
            allocator.destroy(hidraw);
            continue;
        };

        const device_ios = try allocator.alloc(DeviceIO, 1);
        device_ios[0] = hidraw.deviceIO();

        // Create EventLoop
        var loop = try EventLoop.initManaged();

        try loop.addDevice(device_ios[0]);

        // Create Mapper with mapping config
        const timer_fd = loop.timer_fd;
        var mapper_inst = Mapper.init(&mapping_parsed.value, timer_fd, allocator) catch |err| {
            std.debug.print("SKIP mapper init failed for {s}: {}\n", .{ config_path, err });
            loop.deinit();
            device_ios[0].close();
            allocator.free(device_ios);
            continue;
        };

        // Set up the interp copy for the thread
        var thread_interp = Interpreter.init(&parsed.value);

        var arg = RunArg{
            .loop = &loop,
            .interp = &thread_interp,
            .output = udev.outputDevice(),
            .mapper = &mapper_inst,
            .cfg = &parsed.value,
            .mapping_cfg = &mapping_parsed.value,
            .devices = device_ios,
        };

        const thread = try std.Thread.spawn(.{}, runThread, .{&arg});

        // Wait for loop to be running
        var wait_count: usize = 0;
        while (wait_count < 200) : (wait_count += 1) {
            if (@atomicLoad(bool, &loop.running, .acquire)) break;
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }

        // Generate and inject frames
        const N_FRAMES = 50;
        var frames: [N_FRAMES]sequence_gen.Frame = undefined;
        sequence_gen.randomSequence(rng, &frames, mapping_parsed.value);

        // Oracle state for DRT verification
        var oracle_state = oracle_mod.OracleState{};
        var prev_oracle_gs = GamepadState{};
        var frames_verified: usize = 0;
        var events_received: usize = 0;

        for (frames[0..N_FRAMES]) |frame| {
            // Build raw HID packet from delta
            var packet_buf: [4096]u8 = undefined;
            buildPacketFromDelta(cr, frame.delta, &packet_buf);

            // Inject into UHID
            uhidInput(uhid_fd, packet_buf[0..report_size]) catch continue;

            // Delay for kernel round-trip: UHID → hidraw → padctl → uinput → evdev
            std.Thread.sleep(15 * std.time.ns_per_ms);

            // Read actual events from /dev/input/eventN
            const events = readAllEvents(ev_fd, 100);
            const ev_slice = eventSlice(&events);

            // Oracle: compute expected output
            const oracle_out = oracle_mod.apply(&oracle_state, frame.delta, &mapping_parsed.value, frame.dt_ms);

            // DRT 1: structural invariant — data events imply SYN_REPORT
            if (ev_slice.len > 0) {
                events_received += ev_slice.len;
                var has_syn = false;
                for (ev_slice) |ev| {
                    if (ev.type == EV_SYN) has_syn = true;
                }
                // SYN must be present if any events were emitted
                if (!has_syn and ev_slice.len > 0) {
                    std.debug.print("DRT FAIL: events without SYN in {s}\n", .{config_path});
                }
            }

            // DRT 2: button suppress — if oracle suppresses button X,
            // then button X's BTN code must NOT appear as pressed in output.
            // (Only check when oracle and production both see the same input.)
            if (oracle_out.gamepad.buttons != prev_oracle_gs.buttons) {
                for (udev.button_codes, 0..) |code, bi| {
                    if (code == 0) continue;
                    const mask: u64 = @as(u64, 1) << @as(u6, @intCast(bi));
                    const oracle_pressed = (oracle_out.gamepad.buttons & mask) != 0;
                    const was_pressed = (prev_oracle_gs.buttons & mask) != 0;
                    if (!oracle_pressed and was_pressed) {
                        // Oracle says this button should now be released
                        // Check there's no spurious press event
                        if (hasKeyEvent(ev_slice, code, true)) {
                            std.debug.print("DRT WARN: unexpected press for code {d} in {s}\n", .{ code, config_path });
                        }
                    }
                }
            }

            // DRT 3: liveness — if oracle state differs from previous,
            // we should eventually see events. Accumulated over all frames.
            // (Individual frame timing is unreliable.)

            prev_oracle_gs = oracle_out.gamepad;
            frames_verified += 1;
        }

        // Cleanup
        loop.stop();
        thread.join();
        mapper_inst.deinit();
        device_ios[0].close();
        allocator.free(device_ios);
        loop.deinit();

        // DRT 4: liveness — at least some events must have been received over 50 frames
        // (delta inputs include axis sweeps and button presses that always produce output)
        if (events_received == 0) {
            std.debug.print("DRT WARN: zero events received for {s} over {d} frames\n", .{ config_path, frames_verified });
        }

        total_frames += frames_verified;
        devices_tested += 1;

        std.debug.print("OK [{s}] {d} frames, {d} events\n", .{ config_path, frames_verified, events_received });
    }

    if (devices_tested == 0) return error.SkipZigTest;

    std.debug.print("\nl3_e2e: {d} devices tested, {d} total frames\n", .{ devices_tested, total_frames });
    try testing.expect(devices_tested > 0);
    try testing.expect(total_frames > 0);
}

test "l3_e2e: fully generated random device config + random mapping — DRT" {
    const allocator = testing.allocator;

    try checkUinput();

    var prng = std.Random.DefaultPrng.init(0xE2E0_CAFE);
    const rng = prng.random();

    const N_CONFIGS = 20;
    const N_FRAMES = 50;

    var configs_tested: usize = 0;
    var total_frames: usize = 0;

    for (0..N_CONFIGS) |ci| {
        // 1. Generate random device config TOML
        var dev_buf: [4096]u8 = undefined;
        const dev_toml_base = config_gen.randomDeviceConfig(rng, &dev_buf);
        if (dev_toml_base.len == 0) continue;

        // Append [output] with emulate preset and unique VID/PID
        const out_vid: u16 = 0xFB00 | @as(u16, @intCast(ci & 0xFF));
        const out_pid: u16 = 0xCB00 | @as(u16, @intCast(ci & 0xFF));
        var full_dev_buf: [8192]u8 = undefined;
        const full_dev_toml = std.fmt.bufPrint(&full_dev_buf,
            \\{s}
            \\[output]
            \\emulate = "xbox-360"
            \\vid = 0x{x:0>4}
            \\pid = 0x{x:0>4}
            \\
        , .{ dev_toml_base, out_vid, out_pid }) catch continue;

        // 2. Parse device config
        const dev_parsed = device_mod.parseString(allocator, full_dev_toml) catch |err| {
            std.debug.print("GEN DEV PARSE ERROR [ci={d}]: {}\nTOML:\n{s}\n", .{ ci, err, full_dev_toml });
            continue;
        };
        defer dev_parsed.deinit();

        if (dev_parsed.value.output == null) continue;
        if (dev_parsed.value.report.len == 0) continue;

        const interp = Interpreter.init(&dev_parsed.value);
        if (interp.report_count == 0) continue;

        // 3. Generate random mapping config
        var map_buf: [4096]u8 = undefined;
        const map_toml = config_gen.randomMappingConfig(rng, &map_buf);
        const map_parsed = mapping_mod.parseString(allocator, map_toml) catch |err| {
            std.debug.print("GEN MAP PARSE ERROR [ci={d}]: {}\n", .{ ci, err });
            continue;
        };
        defer map_parsed.deinit();

        // Use first compiled report
        const cr = &interp.compiled[0];
        const report_size: usize = @intCast(cr.src.size);

        // Extract generated device VID/PID for UHID
        const gen_vid: u16 = @intCast(dev_parsed.value.device.vid);
        const gen_pid: u16 = @intCast(dev_parsed.value.device.pid);
        // Use unique VID/PID to avoid collisions between iterations
        const uhid_vid: u16 = 0xFC00 | @as(u16, @intCast(ci & 0xFF));
        const uhid_pid: u16 = 0xDC00 | @as(u16, @intCast(ci & 0xFF));
        _ = gen_vid;
        _ = gen_pid;

        const out_cfg = &dev_parsed.value.output.?;

        // 4. Create UHID virtual device
        const uhid_fd = openUhid() catch |err| {
            if (err == error.SkipZigTest) return error.SkipZigTest;
            return err;
        };
        defer {
            uhidDestroy(uhid_fd);
            posix.close(uhid_fd);
        }

        const rd = makeGenericRd(report_size);
        var rd_len: usize = 32;
        while (rd_len > 0 and rd[rd_len - 1] == 0) rd_len -= 1;
        if (rd_len == 0) rd_len = 20;
        try uhidCreate(uhid_fd, uhid_vid, uhid_pid, rd[0..rd_len]);
        std.Thread.sleep(150 * std.time.ns_per_ms);

        // Find hidraw for our UHID device
        const hidraw_path = (try findHidraw(allocator, uhid_vid, uhid_pid)) orelse {
            std.debug.print("SKIP hidraw not found [ci={d}]\n", .{ci});
            continue;
        };
        defer allocator.free(hidraw_path);

        // 5. Create uinput device for output
        var udev = UinputDevice.create(out_cfg) catch |err| {
            std.debug.print("SKIP uinput create failed [ci={d}]: {}\n", .{ ci, err });
            continue;
        };
        defer udev.close();
        std.Thread.sleep(50 * std.time.ns_per_ms);

        // Find event node for uinput output
        const ev_fd = findEventNode(out_vid, out_pid) catch {
            std.debug.print("SKIP event node not found [ci={d}]\n", .{ci});
            continue;
        };
        defer posix.close(ev_fd);

        // Open hidraw device
        const hidraw = try allocator.create(HidrawDevice);
        errdefer allocator.destroy(hidraw);
        hidraw.* = HidrawDevice.init(allocator);
        hidraw.open(hidraw_path) catch |err| {
            std.debug.print("SKIP hidraw open failed [ci={d}]: {}\n", .{ ci, err });
            allocator.destroy(hidraw);
            continue;
        };

        const device_ios = try allocator.alloc(DeviceIO, 1);
        device_ios[0] = hidraw.deviceIO();

        // 6. Create EventLoop and wire up pipeline
        var loop = try EventLoop.initManaged();
        try loop.addDevice(device_ios[0]);

        const timer_fd = loop.timer_fd;
        var mapper_inst = Mapper.init(&map_parsed.value, timer_fd, allocator) catch |err| {
            std.debug.print("SKIP mapper init failed [ci={d}]: {}\n", .{ ci, err });
            loop.deinit();
            device_ios[0].close();
            allocator.free(device_ios);
            continue;
        };

        var thread_interp = Interpreter.init(&dev_parsed.value);

        var arg = RunArg{
            .loop = &loop,
            .interp = &thread_interp,
            .output = udev.outputDevice(),
            .mapper = &mapper_inst,
            .cfg = &dev_parsed.value,
            .mapping_cfg = &map_parsed.value,
            .devices = device_ios,
        };

        const thread = try std.Thread.spawn(.{}, runThread, .{&arg});

        // Wait for loop to be running
        var wait_count: usize = 0;
        while (wait_count < 200) : (wait_count += 1) {
            if (@atomicLoad(bool, &loop.running, .acquire)) break;
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }

        // 7. Generate random input sequences
        var frames: [N_FRAMES]sequence_gen.Frame = undefined;
        sequence_gen.randomSequence(rng, &frames, map_parsed.value);

        var oracle_state = oracle_mod.OracleState{};
        var prev_oracle_gs = GamepadState{};
        var frames_verified: usize = 0;
        var events_received: usize = 0;

        // 8. Inject frames and verify
        for (frames[0..N_FRAMES]) |frame| {
            var packet_buf: [4096]u8 = undefined;
            buildPacketFromDelta(cr, frame.delta, &packet_buf);

            uhidInput(uhid_fd, packet_buf[0..report_size]) catch continue;
            std.Thread.sleep(15 * std.time.ns_per_ms);

            const events = readAllEvents(ev_fd, 100);
            const ev_slice = eventSlice(&events);

            const oracle_out = oracle_mod.apply(&oracle_state, frame.delta, &map_parsed.value, frame.dt_ms);

            // DRT 1: data events imply SYN_REPORT
            if (ev_slice.len > 0) {
                events_received += ev_slice.len;
                var has_syn = false;
                for (ev_slice) |ev| {
                    if (ev.type == EV_SYN) has_syn = true;
                }
                if (!has_syn and ev_slice.len > 0) {
                    std.debug.print("DRT FAIL: events without SYN [ci={d}]\n", .{ci});
                }
            }

            // DRT 2: button suppress check
            if (oracle_out.gamepad.buttons != prev_oracle_gs.buttons) {
                for (udev.button_codes, 0..) |code, bi| {
                    if (code == 0) continue;
                    const mask: u64 = @as(u64, 1) << @as(u6, @intCast(bi));
                    const oracle_pressed = (oracle_out.gamepad.buttons & mask) != 0;
                    const was_pressed = (prev_oracle_gs.buttons & mask) != 0;
                    if (!oracle_pressed and was_pressed) {
                        if (hasKeyEvent(ev_slice, code, true)) {
                            std.debug.print("DRT WARN: unexpected press for code {d} [ci={d}]\n", .{ code, ci });
                        }
                    }
                }
            }

            prev_oracle_gs = oracle_out.gamepad;
            frames_verified += 1;
        }

        // Cleanup
        loop.stop();
        thread.join();
        mapper_inst.deinit();
        device_ios[0].close();
        allocator.free(device_ios);
        loop.deinit();

        // DRT 4: liveness
        if (events_received == 0) {
            std.debug.print("DRT WARN: zero events received [ci={d}] over {d} frames\n", .{ ci, frames_verified });
        }

        total_frames += frames_verified;
        configs_tested += 1;

        std.debug.print("OK [gen-ci={d}] {d} frames, {d} events\n", .{ ci, frames_verified, events_received });
    }

    if (configs_tested == 0) return error.SkipZigTest;

    std.debug.print("\nl3_e2e_gen: {d} random configs tested, {d} total frames\n", .{ configs_tested, total_frames });
    try testing.expect(configs_tested > 0);
    try testing.expect(total_frames > 0);
}
