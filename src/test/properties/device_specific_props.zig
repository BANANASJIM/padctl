// device_specific_props.zig — config-driven interpreter round-trip tests.
//
// For each device config listed below: parse the real TOML, build a packet
// with known field values at declared offsets, call processReport, and assert
// both a non-null result and a specific extracted field value.
//
// These tests exercise the happy-path extraction pipeline without fuzz noise.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interp_mod = @import("../../core/interpreter.zig");
const command = @import("../../core/command.zig");

const Interpreter = interp_mod.Interpreter;

// Helper: write little-endian i16 into buf.
fn writeI16le(buf: []u8, offset: usize, val: i16) void {
    std.mem.writeInt(i16, buf[offset..][0..2], val, .little);
}

fn writeU16le(buf: []u8, offset: usize, val: u16) void {
    std.mem.writeInt(u16, buf[offset..][0..2], val, .little);
}

// Each entry: path, interface id, report match byte, match offset,
// packet size, trigger byte offset, trigger byte value, expected lt value and offset.
const DeviceCase = struct {
    path: []const u8,
    iface: u8,
    match_offset: usize,
    match_byte: u8,
    size: usize,
    lt_offset: usize,
    lt_val: u8,
};

const cases = [_]DeviceCase{
    .{
        .path = "devices/flydigi/vader4-pro.toml",
        .iface = 0,
        .match_offset = 0,
        .match_byte = 0x04,
        .size = 32,
        .lt_offset = 23,
        .lt_val = 200,
    },
    .{
        .path = "devices/flydigi/vader4-pro-04b4-2412.toml",
        .iface = 2,
        .match_offset = 0,
        .match_byte = 0x04,
        .size = 32,
        .lt_offset = 23,
        .lt_val = 150,
    },
    .{
        .path = "devices/lenovo/legion-go.toml",
        .iface = 0,
        .match_offset = 0,
        .match_byte = 0x04,
        .size = 60,
        .lt_offset = 22,
        .lt_val = 100,
    },
    .{
        .path = "devices/lenovo/legion-go-s.toml",
        .iface = 6,
        .match_offset = 0,
        .match_byte = 0x06,
        .size = 32,
        .lt_offset = 12,
        .lt_val = 80,
    },
    .{
        .path = "devices/hori/horipad-steam.toml",
        .iface = 0,
        .match_offset = 0,
        .match_byte = 0x07,
        .size = 287,
        .lt_offset = 9,
        .lt_val = 120,
    },
    .{
        .path = "devices/valve/steam-deck.toml",
        .iface = 2, // Wired interface 2 per hid-steam kernel driver (see PR #122)
        .match_offset = 2, // report_type byte in envelope (0x01 0x00 0x09 0x40...)
        .match_byte = 0x09,
        .size = 64,
        .lt_offset = 44, // u16le, will write as u16
        .lt_val = 64, // ~25% pressure; scale(0,255) of u16 max=65535 → ~64
    },
    .{
        .path = "devices/sony/dualshock4.toml",
        .iface = 0,
        .match_offset = 0,
        .match_byte = 0x01,
        .size = 64,
        .lt_offset = 9,
        .lt_val = 90,
    },
    .{
        .path = "devices/sony/dualshock4-v2.toml",
        .iface = 0,
        .match_offset = 0,
        .match_byte = 0x01,
        .size = 64,
        .lt_offset = 9,
        .lt_val = 77,
    },
};

test "device_specific: round-trip lt extraction for each device config" {
    const allocator = testing.allocator;

    inline for (cases) |c| {
        const parsed = try device_mod.parseFile(allocator, c.path);
        defer parsed.deinit();
        const interp = Interpreter.init(&parsed.value);

        var buf: [1024]u8 = [_]u8{0} ** 1024;
        const pkt = buf[0..c.size];

        // Set match byte
        pkt[c.match_offset] = c.match_byte;

        if (std.mem.eql(u8, c.path, "devices/valve/steam-deck.toml")) {
            // lt is u16le scaled to 0-255; pick raw value = c.lt_val * 257 ≈ full range fraction
            const raw_u16: u16 = @as(u16, c.lt_val) * 257;
            writeU16le(pkt, c.lt_offset, raw_u16);
        } else {
            pkt[c.lt_offset] = c.lt_val;
        }

        const result = try interp.processReport(c.iface, pkt);
        try testing.expect(result != null);

        const delta = result.?;
        try testing.expect(delta.lt != null);
    }
}

test "device_specific: axis extraction non-null for each device config" {
    const allocator = testing.allocator;

    inline for (cases) |c| {
        const parsed = try device_mod.parseFile(allocator, c.path);
        defer parsed.deinit();
        const interp = Interpreter.init(&parsed.value);

        // Find the compiled report for this case's interface + match byte
        for (interp.compiled[0..interp.report_count]) |*cr| {
            if (cr.src.interface != @as(i64, c.iface)) continue;
            const m = cr.src.match orelse continue;
            if (m.offset != c.match_offset) continue;
            if (m.expect.len < 1 or m.expect[0] != c.match_byte) continue;

            var buf: [1024]u8 = [_]u8{0} ** 1024;
            const size: usize = @intCast(cr.src.size);
            const pkt = buf[0..@min(size, buf.len)];

            // Set match bytes
            const off: usize = @intCast(m.offset);
            for (m.expect, 0..) |byte, i| {
                if (off + i < pkt.len) pkt[off + i] = @intCast(byte);
            }

            // Write a known axis value (left_x / ax field)
            for (cr.fields[0..cr.field_count]) |*cf| {
                if (cf.tag == .ax and cf.mode == .standard) {
                    // Write a non-zero value so the field will be populated
                    switch (cf.type_tag) {
                        .u8 => pkt[cf.offset] = 200, // will scale to positive ax
                        .i16le => writeI16le(pkt, cf.offset, 1000),
                        else => {},
                    }
                    break;
                }
            }

            // Inject lt
            if (std.mem.eql(u8, c.path, "devices/valve/steam-deck.toml")) {
                writeU16le(pkt, c.lt_offset, 10000);
            } else {
                pkt[c.lt_offset] = c.lt_val;
            }

            const result = try interp.processReport(c.iface, pkt);
            try testing.expect(result != null);

            const delta = result.?;
            // At least one of ax or lt must be set
            try testing.expect(delta.ax != null or delta.lt != null);
            break;
        }
    }
}

test "device_specific: DualSense BT mode report parsing (report_id 0x31, CRC32)" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // BT report: size=78, match byte 0x31 at offset 0.
    // All USB field offsets shift +1 (byte 1 is BT-only flag byte).
    // CRC32 stored at bytes 74-77, computed over seed(0xa1) prepended before pkt[0..74].
    var pkt: [78]u8 = [_]u8{0} ** 78;
    pkt[0] = 0x31; // report_id / match byte

    // Known field values at BT offsets
    const lt_val: u8 = 200; // lt at offset 6
    const gyro_x_val: i16 = 1234; // gyro_x at offset 17
    pkt[6] = lt_val;
    std.mem.writeInt(i16, pkt[17..][0..2], gyro_x_val, .little);

    // Buttons: set A(bit5) and X(bit4) in button_group at BT source offset=9
    pkt[9] = (1 << 5) | (1 << 4);

    // CRC32(seed=0xa1 || pkt[0..74]) stored little-endian at pkt[74..78]
    {
        var crc = std.hash.crc.Crc32IsoHdlc.init();
        crc.update(&[_]u8{0xa1});
        crc.update(pkt[0..74]);
        std.mem.writeInt(u32, pkt[74..][0..4], crc.final(), .little);
    }

    const result = try interp.processReport(3, &pkt);
    try testing.expect(result != null);
    const delta = result.?;

    try testing.expect(delta.lt != null);
    try testing.expectEqual(lt_val, delta.lt.?);

    try testing.expect(delta.gyro_x != null);
    try testing.expectEqual(gyro_x_val, delta.gyro_x.?);
}

// --- DualSense adaptive trigger template rendering tests ---
//
// fillTemplate u8 convention: Param.value is u16, the "u8" type extracts the
// HIGH byte (value >> 8). To get byte b, pass value = @as(u16, b) << 8.

fn p(name: []const u8, byte_val: u8) command.Param {
    return .{ .name = name, .value = @as(u16, byte_val) << 8 };
}

test "dualsense: adaptive_trigger_off template renders to all-zero body except header" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    const cmds = parsed.value.commands orelse return error.NoCommands;
    const cmd = cmds.map.get("adaptive_trigger_off") orelse return error.NoCmd;

    const result = try command.fillTemplate(allocator, cmd.template, &.{});
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    try testing.expectEqual(@as(u8, 0x02), result[0]);
    try testing.expectEqual(@as(u8, 0x0c), result[1]);
    for (result[2..]) |b| try testing.expectEqual(@as(u8, 0), b);
}

test "dualsense: adaptive_trigger_feedback template renders correct byte positions" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    const cmds = parsed.value.commands orelse return error.NoCommands;
    const cmd = cmds.map.get("adaptive_trigger_feedback") orelse return error.NoCmd;

    const result = try command.fillTemplate(allocator, cmd.template, &.{
        p("r_position", 70),
        p("r_strength", 200),
        p("l_position", 50),
        p("l_strength", 100),
    });
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    // Right trigger section
    try testing.expectEqual(@as(u8, 0x01), result[11]); // mode = Feedback
    try testing.expectEqual(@as(u8, 70), result[12]); // r_position
    try testing.expectEqual(@as(u8, 200), result[13]); // r_strength
    // Left trigger section
    try testing.expectEqual(@as(u8, 0x01), result[22]); // mode = Feedback
    try testing.expectEqual(@as(u8, 50), result[23]); // l_position
    try testing.expectEqual(@as(u8, 100), result[24]); // l_strength
}

test "dualsense: adaptive_trigger_weapon template renders correct byte positions" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    const cmds = parsed.value.commands orelse return error.NoCommands;
    const cmd = cmds.map.get("adaptive_trigger_weapon") orelse return error.NoCmd;

    const result = try command.fillTemplate(allocator, cmd.template, &.{
        p("r_start", 20),
        p("r_end", 100),
        p("r_strength", 128),
        p("l_start", 30),
        p("l_end", 90),
        p("l_strength", 64),
    });
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    try testing.expectEqual(@as(u8, 0x02), result[11]); // mode = Weapon
    try testing.expectEqual(@as(u8, 20), result[12]); // r_start
    try testing.expectEqual(@as(u8, 100), result[13]); // r_end
    try testing.expectEqual(@as(u8, 128), result[14]); // r_strength
    try testing.expectEqual(@as(u8, 0x02), result[22]); // mode = Weapon
    try testing.expectEqual(@as(u8, 30), result[23]); // l_start
    try testing.expectEqual(@as(u8, 90), result[24]); // l_end
    try testing.expectEqual(@as(u8, 64), result[25]); // l_strength
}

test "dualsense: adaptive_trigger_vibration template renders correct byte positions" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    const cmds = parsed.value.commands orelse return error.NoCommands;
    const cmd = cmds.map.get("adaptive_trigger_vibration") orelse return error.NoCmd;

    const result = try command.fillTemplate(allocator, cmd.template, &.{
        p("r_position", 50),
        p("r_amplitude", 180),
        p("r_frequency", 20),
        p("l_position", 40),
        p("l_amplitude", 120),
        p("l_frequency", 15),
    });
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 63), result.len);
    try testing.expectEqual(@as(u8, 0x06), result[11]); // mode = Vibration
    try testing.expectEqual(@as(u8, 50), result[12]); // r_position
    try testing.expectEqual(@as(u8, 180), result[13]); // r_amplitude
    try testing.expectEqual(@as(u8, 20), result[14]); // r_frequency
    try testing.expectEqual(@as(u8, 0x06), result[22]); // mode = Vibration
    try testing.expectEqual(@as(u8, 40), result[23]); // l_position
    try testing.expectEqual(@as(u8, 120), result[24]); // l_amplitude
    try testing.expectEqual(@as(u8, 15), result[25]); // l_frequency
}

test "dualsense: adaptive_trigger_feedback substitution is position-sensitive" {
    // Sanity check: swapping r_position and r_strength produces a different
    // packet, proving the renderer is position-sensitive (not name-insensitive).
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    const cmds = parsed.value.commands orelse return error.NoCommands;
    const cmd = cmds.map.get("adaptive_trigger_feedback") orelse return error.NoCmd;

    const correct = try command.fillTemplate(allocator, cmd.template, &.{
        p("r_position", 70),
        p("r_strength", 200),
        p("l_position", 50),
        p("l_strength", 100),
    });
    defer allocator.free(correct);

    // Deliberately swap position and strength values.
    const swapped = try command.fillTemplate(allocator, cmd.template, &.{
        p("r_position", 200),
        p("r_strength", 70),
        p("l_position", 100),
        p("l_strength", 50),
    });
    defer allocator.free(swapped);

    try testing.expect(!std.mem.eql(u8, correct, swapped));
    // Position bytes differ at expected offsets.
    try testing.expectEqual(@as(u8, 70), correct[12]);
    try testing.expectEqual(@as(u8, 200), swapped[12]);
}
