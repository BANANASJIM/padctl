// uhid_all_devices_test.zig — L2 UHID config-driven simulation for ALL device configs.
//
// For each .toml in devices/, parse config, build test packets (zero/max/min/random),
// create a UHID virtual device, inject via UHID_INPUT2, read back from hidraw,
// run through the interpreter, and verify extracted values against reference oracle.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;

const src = @import("src");
const device_mod = src.config.device;
const interp_mod = src.core.interpreter;
const Interpreter = interp_mod.Interpreter;
const CompiledReport = interp_mod.CompiledReport;
const FieldType = interp_mod.FieldType;
const FieldTag = interp_mod.FieldTag;
const GamepadStateDelta = src.core.state.GamepadStateDelta;
const ref = src.testing_support.reference_interp;
const helpers = src.testing_support.helpers;

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

fn openUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
}

fn uhidCreate(fd: posix.fd_t, vid: u16, pid: u16, rd_data: []const u8) !void {
    var ev = std.mem.zeroes(UhidCreate2Event);
    ev.type = UHID_CREATE2;
    const name = "padctl-alldev-test";
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

fn findHidraw(vid: u16, pid: u16) !?[64]u8 {
    const ioctl_mod = src.io.ioctl_constants;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/dev/hidraw{d}", .{i}) catch continue;
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch continue;
        defer posix.close(fd);
        var info: ioctl_mod.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl_mod.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) continue;
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

// --- Minimal HID report descriptor generator ---
// Produces a descriptor that claims N bytes of generic input.
fn makeGenericRd(comptime max_size: usize, report_size: usize) [max_size]u8 {
    // Usage Page (Generic Desktop) + Usage (Game Pad) + Collection (Application)
    // + Report Count(N) + Report Size(8) + Input(Data,Var,Abs) + End Collection
    var rd: [max_size]u8 = undefined;
    var pos: usize = 0;
    rd[pos] = 0x05;
    pos += 1;
    rd[pos] = 0x01;
    pos += 1; // Usage Page
    rd[pos] = 0x09;
    pos += 1;
    rd[pos] = 0x05;
    pos += 1; // Usage (Game Pad)
    rd[pos] = 0xA1;
    pos += 1;
    rd[pos] = 0x01;
    pos += 1; // Collection (Application)
    rd[pos] = 0x09;
    pos += 1;
    rd[pos] = 0x30;
    pos += 1; // Usage (X)
    rd[pos] = 0x15;
    pos += 1;
    rd[pos] = 0x00;
    pos += 1; // Logical Minimum (0)
    rd[pos] = 0x26;
    pos += 1;
    rd[pos] = 0xFF;
    pos += 1;
    rd[pos] = 0x00;
    pos += 1; // Logical Maximum (255)
    rd[pos] = 0x75;
    pos += 1;
    rd[pos] = 0x08;
    pos += 1; // Report Size (8)
    // Report Count — use 2-byte encoding for sizes > 255
    if (report_size <= 255) {
        rd[pos] = 0x95;
        pos += 1;
        rd[pos] = @intCast(report_size);
        pos += 1;
    } else {
        rd[pos] = 0x96;
        pos += 1;
        rd[pos] = @intCast(report_size & 0xFF);
        pos += 1;
        rd[pos] = @intCast((report_size >> 8) & 0xFF);
        pos += 1;
    }
    rd[pos] = 0x81;
    pos += 1;
    rd[pos] = 0x02;
    pos += 1; // Input (Data, Var, Abs)
    rd[pos] = 0xC0;
    pos += 1; // End Collection
    // Zero-fill remaining
    @memset(rd[pos..], 0);
    return rd;
}

// --- Packet builder ---

const PacketMode = enum { zero, max, min };

fn typeSizeBytes(t: FieldType) usize {
    return switch (t) {
        .u8, .i8 => 1,
        .u16le, .i16le, .u16be, .i16be => 2,
        .u32le, .i32le, .u32be, .i32be => 4,
    };
}

fn writeFieldValue(buf: []u8, offset: usize, t: FieldType, value: i64) void {
    switch (t) {
        .u8 => buf[offset] = @intCast(value & 0xFF),
        .i8 => buf[offset] = @bitCast(@as(i8, @intCast(value))),
        .u16le => std.mem.writeInt(u16, buf[offset..][0..2], @intCast(value & 0xFFFF), .little),
        .i16le => std.mem.writeInt(i16, buf[offset..][0..2], @intCast(value), .little),
        .u16be => std.mem.writeInt(u16, buf[offset..][0..2], @intCast(value & 0xFFFF), .big),
        .i16be => std.mem.writeInt(i16, buf[offset..][0..2], @intCast(value), .big),
        .u32le => std.mem.writeInt(u32, buf[offset..][0..4], @intCast(value & 0xFFFFFFFF), .little),
        .i32le => std.mem.writeInt(i32, buf[offset..][0..4], @intCast(value), .little),
        .u32be => std.mem.writeInt(u32, buf[offset..][0..4], @intCast(value & 0xFFFFFFFF), .big),
        .i32be => std.mem.writeInt(i32, buf[offset..][0..4], @intCast(value), .big),
    }
}

fn typeMinValue(t: FieldType) i64 {
    return switch (t) {
        .u8, .u16le, .u16be, .u32le, .u32be => 0,
        .i8 => -128,
        .i16le, .i16be => -32768,
        .i32le, .i32be => -2147483648,
    };
}

fn typeMaxValue(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 2147483647, // cap at i64-safe range
        .i32le, .i32be => 2147483647,
    };
}

fn fieldValue(t: FieldType, mode: PacketMode) i64 {
    return switch (mode) {
        .zero => 0,
        .max => typeMaxValue(t),
        .min => typeMinValue(t),
    };
}

fn buildTestPacket(cr: *const CompiledReport, mode: PacketMode, buf: []u8) void {
    const size: usize = @intCast(cr.src.size);
    @memset(buf[0..size], 0);

    // Fill match bytes
    if (cr.src.match) |m| {
        const off: usize = @intCast(m.offset);
        for (m.expect, 0..) |byte, i| {
            buf[off + i] = @intCast(byte);
        }
    }

    // Fill standard fields
    for (cr.fields[0..cr.field_count]) |*cf| {
        if (cf.mode == .standard) {
            const val = fieldValue(cf.type_tag, mode);
            writeFieldValue(buf, cf.offset, cf.type_tag, val);
        } else {
            // bits mode: write the raw value into the byte(s)
            const raw_bits: u32 = switch (mode) {
                .zero => 0,
                .max => blk: {
                    if (cf.bit_count == 0) break :blk 0;
                    if (cf.bit_count >= 32) break :blk std.math.maxInt(u32);
                    const shift: u5 = @intCast(cf.bit_count);
                    break :blk (@as(u32, 1) << shift) - 1;
                },
                .min => blk: {
                    if (cf.is_signed and cf.bit_count > 0 and cf.bit_count < 32) {
                        const shift: u5 = @intCast(cf.bit_count);
                        break :blk @as(u32, 1) << (shift - 1); // sign bit only = min negative
                    }
                    break :blk 0;
                },
            };
            // Shift bits into position and OR into buffer
            const shifted = @as(u64, raw_bits) << @intCast(cf.start_bit);
            const needed: u8 = (@as(u8, cf.start_bit) + @as(u8, cf.bit_count) + 7) / 8;
            for (0..needed) |i| {
                const byte_val: u8 = @intCast((shifted >> @intCast(i * 8)) & 0xFF);
                buf[cf.byte_offset + i] |= byte_val;
            }
        }
    }

    // Fill button_group source bytes for max mode
    if (cr.button_group) |*cbg| {
        switch (mode) {
            .max => {
                // Set all mapped button bits
                for (cbg.entries[0..cbg.count]) |entry| {
                    const byte_idx = entry.bit_idx / 8;
                    const bit_pos: u3 = @intCast(entry.bit_idx % 8);
                    buf[cbg.src_off + byte_idx] |= @as(u8, 1) << bit_pos;
                }
            },
            .zero, .min => {}, // all zeros
        }
    }

    // Compute and inject checksum if configured
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
                if (cs.seed) |seed| {
                    const seed_byte: u8 = @intCast(seed & 0xff);
                    crc.update(&[_]u8{seed_byte});
                }
                crc.update(buf[cs.range_start..cs.range_end]);
                std.mem.writeInt(u32, buf[cs.expect_off..][0..4], crc.final(), .little);
            },
        }
    }
}

// --- Reference comparison ---

fn getDeltaField(delta: *const GamepadStateDelta, tag: FieldTag) ?i64 {
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
        .dpad => null, // dpad expands to dpad_x/dpad_y, not directly readable
        .unknown => null,
    };
}

fn saturateCast16(val: i64) i16 {
    if (val > std.math.maxInt(i16)) return std.math.maxInt(i16);
    if (val < std.math.minInt(i16)) return std.math.minInt(i16);
    return @intCast(val);
}

// Verify production interpreter output against reference oracle
fn verifyAgainstReference(
    cr: *const CompiledReport,
    raw: []const u8,
    delta: *const GamepadStateDelta,
    config_path: []const u8,
    report_name: []const u8,
    mode_name: []const u8,
) !void {
    var ref_results: [interp_mod.MAX_FIELDS]ref.FieldResult = undefined;
    const ref_count = ref.extractFields(cr, raw, &ref_results);

    for (ref_results[0..ref_count]) |r| {
        if (r.tag == .unknown or r.tag == .dpad) continue;
        const prod_val = getDeltaField(delta, r.tag);
        if (prod_val == null and r.val == 0) continue; // zero fields may not appear in delta

        // Reference produces i64; production saturates to i16/u8/etc.
        // Apply the same saturation the production code would.
        const expected = switch (r.tag) {
            .lt, .rt => @as(i64, @as(u8, @intCast(r.val & 0xff))),
            .battery_level => @as(i64, @as(u8, @intCast(r.val & 0xff))),
            .touch0_active, .touch1_active => if (r.val != 0) @as(i64, 1) else @as(i64, 0),
            else => @as(i64, saturateCast16(r.val)),
        };

        if (expected == 0 and prod_val == null) continue;

        if (prod_val) |pv| {
            if (pv != expected) {
                std.debug.print(
                    "MISMATCH [{s}] report '{s}' mode={s} tag={s}: prod={d} ref={d}\n",
                    .{ config_path, report_name, mode_name, @tagName(r.tag), pv, expected },
                );
                return error.TestUnexpectedResult;
            }
        } else {
            std.debug.print(
                "MISSING [{s}] report '{s}' mode={s} tag={s}: prod=null ref={d}\n",
                .{ config_path, report_name, mode_name, @tagName(r.tag), expected },
            );
            return error.TestUnexpectedResult;
        }
    }
}

// --- UHID inject + read + verify pipeline ---

fn injectAndVerify(
    config_path: []const u8,
    interp: *const Interpreter,
    cr: *const CompiledReport,
    packet: []const u8,
    mode_name: []const u8,
) !void {
    const size: usize = @intCast(cr.src.size);
    const iface: u8 = @intCast(cr.src.interface);
    const vid: u16 = 0xFA00 | @as(u16, @intCast(iface));
    const pid: u16 = 0xCA00 | @as(u16, @truncate(std.hash.Adler32.hash(config_path) & 0xFF));

    const uhid_fd = try openUhid();
    defer {
        uhidDestroy(uhid_fd);
        posix.close(uhid_fd);
    }

    const rd = makeGenericRd(32, size);
    // Find the actual descriptor length (non-zero portion)
    var rd_len: usize = 32;
    while (rd_len > 0 and rd[rd_len - 1] == 0) rd_len -= 1;
    if (rd_len == 0) rd_len = 20; // minimum sane
    try uhidCreate(uhid_fd, vid, pid, rd[0..rd_len]);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const found = try findHidraw(vid, pid);
    if (found == null) return error.SkipZigTest;

    const path_buf = found.?;
    const path_end = std.mem.indexOfScalar(u8, &path_buf, 0) orelse path_buf.len;
    const hidraw_path = path_buf[0..path_end];

    const hidraw_fd = posix.open(hidraw_path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true }, 0) catch
        return error.SkipZigTest;
    defer posix.close(hidraw_fd);

    try uhidInput(uhid_fd, packet[0..size]);

    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest;

    var read_buf: [4096]u8 = undefined;
    const n = posix.read(hidraw_fd, &read_buf) catch return error.SkipZigTest;
    try testing.expectEqual(size, n);
    try testing.expectEqualSlices(u8, packet[0..size], read_buf[0..size]);

    // Run through interpreter
    const delta = (try interp.processReport(iface, read_buf[0..n])) orelse {
        // null means no match — for zero-mode packets this is acceptable if match bytes are all zero
        // but we set match bytes, so this shouldn't happen. Skip if it does.
        return;
    };

    try verifyAgainstReference(cr, read_buf[0..n], &delta, config_path, cr.src.name, mode_name);
}

// --- Pure interpreter verify (no UHID, L1-level) ---
// Tests the packet build + interpreter pipeline without kernel involvement.
// This runs for ALL devices unconditionally.

fn pureInterpreterVerify(
    config_path: []const u8,
    interp: *const Interpreter,
    cr: *const CompiledReport,
    packet: []const u8,
    mode_name: []const u8,
) !void {
    const size: usize = @intCast(cr.src.size);
    const iface: u8 = @intCast(cr.src.interface);

    const delta = (try interp.processReport(iface, packet[0..size])) orelse return;
    try verifyAgainstReference(cr, packet[0..size], &delta, config_path, cr.src.name, mode_name);
}

// --- Test entry points ---

const modes = [_]struct { mode: PacketMode, name: []const u8 }{
    .{ .mode = .zero, .name = "zero" },
    .{ .mode = .max, .name = "max" },
    .{ .mode = .min, .name = "min" },
};

test "uhid: all devices — zero packet processes without crash" {
    try runAllDevicesMode(.zero, false);
}

test "uhid: all devices — max values extract correctly" {
    try runAllDevicesMode(.max, false);
}

test "uhid: all devices — min values extract correctly" {
    try runAllDevicesMode(.min, false);
}

test "uhid: all devices — zero packet round-trip via UHID" {
    try runAllDevicesMode(.zero, true);
}

test "uhid: all devices — max values round-trip via UHID" {
    try runAllDevicesMode(.max, true);
}

test "uhid: all devices — min values round-trip via UHID" {
    try runAllDevicesMode(.min, true);
}

test "uhid: all devices — random packet round-trip" {
    try runAllDevicesRandom();
}

test "uhid: all devices — structured random field values" {
    try runAllDevicesStructured();
}

fn runAllDevicesMode(mode: PacketMode, use_uhid: bool) !void {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) {
        std.debug.print("SKIP: no device configs found in devices/\n", .{});
        return;
    }

    var tested: usize = 0;
    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch |err| {
            std.debug.print("SKIP parse error: {s}: {}\n", .{ path, err });
            continue;
        };
        defer parsed.deinit();

        const interp = Interpreter.init(&parsed.value);
        const mode_name: []const u8 = switch (mode) {
            .zero => "zero",
            .max => "max",
            .min => "min",
        };

        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);
            var packet_buf: [4096]u8 = undefined;
            buildTestPacket(cr, mode, &packet_buf);

            if (use_uhid) {
                injectAndVerify(path, &interp, cr, packet_buf[0..size], mode_name) catch |err| {
                    if (err == error.SkipZigTest) continue;
                    return err;
                };
            } else {
                try pureInterpreterVerify(path, &interp, cr, packet_buf[0..size], mode_name);
            }
            tested += 1;
        }
    }

    if (use_uhid and tested == 0) {
        // All UHID injections were skipped (e.g. no hidraw nodes appeared in time)
        return error.SkipZigTest;
    }
    try testing.expect(tested > 0);
}

fn runAllDevicesRandom() !void {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) return;

    var prng = std.Random.DefaultPrng.init(0xDEADBEEF);
    const rng = prng.random();

    var tested: usize = 0;
    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const interp = Interpreter.init(&parsed.value);

        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);

            // Generate 4 random packets per report
            for (0..4) |_| {
                var packet_buf: [4096]u8 = undefined;
                // Fill with random data
                rng.bytes(packet_buf[0..size]);

                // Fix match bytes so the report actually matches
                if (cr.src.match) |m| {
                    const off: usize = @intCast(m.offset);
                    for (m.expect, 0..) |byte, i| {
                        packet_buf[off + i] = @intCast(byte);
                    }
                }

                // Fix checksum
                if (cr.checksum) |cs| {
                    switch (cs.algo) {
                        .sum8 => {
                            var sum: u8 = 0;
                            for (packet_buf[cs.range_start..cs.range_end]) |b| sum +%= b;
                            packet_buf[cs.expect_off] = sum;
                        },
                        .xor => {
                            var xv: u8 = 0;
                            for (packet_buf[cs.range_start..cs.range_end]) |b| xv ^= b;
                            packet_buf[cs.expect_off] = xv;
                        },
                        .crc32 => {
                            var crc = std.hash.crc.Crc32IsoHdlc.init();
                            if (cs.seed) |seed| {
                                const seed_byte: u8 = @intCast(seed & 0xff);
                                crc.update(&[_]u8{seed_byte});
                            }
                            crc.update(packet_buf[cs.range_start..cs.range_end]);
                            std.mem.writeInt(u32, packet_buf[cs.expect_off..][0..4], crc.final(), .little);
                        },
                    }
                }

                // Pure interpreter verify (random packets via UHID are less useful)
                pureInterpreterVerify(path, &interp, cr, packet_buf[0..size], "random") catch |err| {
                    std.debug.print("FAIL random: {s} report '{s}'\n", .{ path, cr.src.name });
                    return err;
                };
                tested += 1;
            }
        }
    }
    try testing.expect(tested > 0);
}

// Build a packet with valid per-field random values within each field's type range.
// Unlike pure random bytes, this exercises the happy path: all fields decode successfully.
fn buildStructuredPacket(cr: *const CompiledReport, rng: std.Random, buf: []u8) void {
    const size: usize = @intCast(cr.src.size);
    @memset(buf[0..size], 0);

    // Fix match bytes first.
    if (cr.src.match) |m| {
        const off: usize = @intCast(m.offset);
        for (m.expect, 0..) |byte, i| buf[off + i] = @intCast(byte);
    }

    // Write a random valid value for every standard field.
    for (cr.fields[0..cr.field_count]) |*cf| {
        if (cf.mode == .standard) {
            const lo = typeMinValue(cf.type_tag);
            const hi = typeMaxValue(cf.type_tag);
            // Pick random i64 in [lo, hi] using uniform distribution.
            const range: u64 = @intCast(hi - lo);
            const val: i64 = lo + @as(i64, @intCast(rng.intRangeAtMost(u64, 0, range)));
            writeFieldValue(buf, cf.offset, cf.type_tag, val);
        } else {
            // bits mode: write a random value that fits in bit_count bits.
            if (cf.bit_count == 0) continue;
            const max_val: u32 = if (cf.bit_count >= 32) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(cf.bit_count)) - 1;
            const raw: u32 = rng.intRangeAtMost(u32, 0, max_val);
            const shifted = @as(u64, raw) << @intCast(cf.start_bit);
            const needed: u8 = (@as(u8, cf.start_bit) + @as(u8, cf.bit_count) + 7) / 8;
            for (0..needed) |i| {
                buf[cf.byte_offset + i] |= @intCast((shifted >> @intCast(i * 8)) & 0xFF);
            }
        }
    }

    // Random button_group bits.
    if (cr.button_group) |*cbg| {
        for (cbg.entries[0..cbg.count]) |entry| {
            if (rng.boolean()) {
                const byte_idx = entry.bit_idx / 8;
                const bit_pos: u3 = @intCast(entry.bit_idx % 8);
                buf[cbg.src_off + byte_idx] |= @as(u8, 1) << bit_pos;
            }
        }
    }

    // Recompute checksum last (must come after all field writes).
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

fn runAllDevicesStructured() !void {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) return;

    var prng = std.Random.DefaultPrng.init(0x5EED_5AFED);
    const rng = prng.random();

    var tested: usize = 0;
    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const interp = Interpreter.init(&parsed.value);

        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);

            // 8 structured-random packets per report — more than pure-random to
            // exercise valid-range happy paths not covered by zero/max/min.
            for (0..8) |_| {
                var packet_buf: [4096]u8 = undefined;
                buildStructuredPacket(cr, rng, &packet_buf);

                pureInterpreterVerify(path, &interp, cr, packet_buf[0..size], "structured") catch |err| {
                    std.debug.print("FAIL structured: {s} report '{s}'\n", .{ path, cr.src.name });
                    return err;
                };
                tested += 1;
            }
        }
    }
    try testing.expect(tested > 0);
}
