// drt_props.zig — Differential Reference Testing for field extraction.
//
// For every device TOML: generate 1000 random HID packets, run both the
// production interpreter and the reference interpreter, and verify that each
// scalar field extracted by production matches the reference oracle.
//
// DRT SCOPE: catches runtime extraction bugs (wrong read logic, bad transform
// math) but NOT config compilation bugs, because both oracle and production
// share CompiledField/CompiledReport from production.  A wrong offset or
// type_tag in compileReport would affect both sides equally and go undetected.
// See reference_interp.zig for the canonical note on this compromise.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interp_mod = @import("../../core/interpreter.zig");
const ref = @import("../reference_interp.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interp_mod.Interpreter;
const CompiledReport = interp_mod.CompiledReport;
const MAX_FIELDS = interp_mod.MAX_FIELDS;

// Dpad hat-switch decode: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW, 8+=neutral
const HAT_X = [8]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
const HAT_Y = [8]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };

// saturate mirrors production's saturateCast.
fn saturate(comptime T: type, v: i64) T {
    if (v > std.math.maxInt(T)) return std.math.maxInt(T);
    if (v < std.math.minInt(T)) return std.math.minInt(T);
    return @intCast(v);
}

// Inject a valid checksum into pkt so verifyChecksumCompiled passes.
fn injectChecksum(cr: *const CompiledReport, pkt: []u8) void {
    const cs = cr.checksum orelse return;
    const data = pkt[cs.range_start..cs.range_end];
    switch (cs.algo) {
        .sum8 => {
            var sum: u8 = 0;
            for (data) |b| sum +%= b;
            pkt[cs.expect_off] = sum;
        },
        .xor => {
            var xv: u8 = 0;
            for (data) |b| xv ^= b;
            pkt[cs.expect_off] = xv;
        },
        .crc32 => {
            var crc = std.hash.crc.Crc32IsoHdlc.init();
            if (cs.seed) |seed| {
                const seed_byte: u8 = @intCast(seed & 0xff);
                crc.update(&[_]u8{seed_byte});
            }
            crc.update(data);
            const computed = crc.final();
            std.mem.writeInt(u32, pkt[cs.expect_off..][0..4], computed, .little);
        },
    }
}

// Reference hat decode — independent of production.
// HID hat: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, 8+=neutral
fn hatDecode(hat: i64) struct { x: i8, y: i8 } {
    if (hat >= 0 and hat < 8) {
        const idx: usize = @intCast(hat);
        return .{ .x = HAT_X[idx], .y = HAT_Y[idx] };
    }
    return .{ .x = 0, .y = 0 };
}

test "DRT: production interpreter matches reference oracle on random packets" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);

    var rng = std.Random.DefaultPrng.init(0xC0FFEE_42);
    const random = rng.random();

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const cfg = &parsed.value;
        const interp = Interpreter.init(cfg);

        // Iterate over compiled reports directly — avoids pointer-equality issues.
        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);
            var buf: [1024]u8 = undefined;
            const pkt = buf[0..@min(size, buf.len)];

            const iface: u8 = @intCast(cr.src.interface);
            var tested_count: usize = 0;

            for (0..1000) |_| {
                random.bytes(pkt);
                // Inject match bytes so the report is recognised by production.
                if (cr.src.match) |m| {
                    const off: usize = @intCast(m.offset);
                    for (m.expect, 0..) |byte, i| {
                        if (off + i < pkt.len) pkt[off + i] = @intCast(byte);
                    }
                }
                // For checksum devices, inject a valid checksum so extraction
                // logic is actually exercised (not silently skipped every time).
                if (cr.checksum != null) injectChecksum(cr, pkt);

                const prod_delta = interp.processReport(iface, pkt) catch continue;
                const delta = prod_delta orelse continue;
                tested_count += 1;

                // Reference oracle
                var ref_buf: [MAX_FIELDS]ref.FieldResult = undefined;
                const ref_count = ref.extractFields(cr, pkt, &ref_buf);

                for (ref_buf[0..ref_count]) |fr| {
                    switch (fr.tag) {
                        .ax => {
                            try testing.expect(delta.ax != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.ax.?);
                        },
                        .ay => {
                            try testing.expect(delta.ay != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.ay.?);
                        },
                        .rx => {
                            try testing.expect(delta.rx != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.rx.?);
                        },
                        .ry => {
                            try testing.expect(delta.ry != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.ry.?);
                        },
                        .lt => {
                            try testing.expect(delta.lt != null);
                            try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), delta.lt.?);
                        },
                        .rt => {
                            try testing.expect(delta.rt != null);
                            try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), delta.rt.?);
                        },
                        .gyro_x => {
                            try testing.expect(delta.gyro_x != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.gyro_x.?);
                        },
                        .gyro_y => {
                            try testing.expect(delta.gyro_y != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.gyro_y.?);
                        },
                        .gyro_z => {
                            try testing.expect(delta.gyro_z != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.gyro_z.?);
                        },
                        .accel_x => {
                            try testing.expect(delta.accel_x != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.accel_x.?);
                        },
                        .accel_y => {
                            try testing.expect(delta.accel_y != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.accel_y.?);
                        },
                        .accel_z => {
                            try testing.expect(delta.accel_z != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.accel_z.?);
                        },
                        .touch0_x => {
                            try testing.expect(delta.touch0_x != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.touch0_x.?);
                        },
                        .touch0_y => {
                            try testing.expect(delta.touch0_y != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.touch0_y.?);
                        },
                        .touch1_x => {
                            try testing.expect(delta.touch1_x != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.touch1_x.?);
                        },
                        .touch1_y => {
                            try testing.expect(delta.touch1_y != null);
                            try testing.expectEqual(saturate(i16, fr.val), delta.touch1_y.?);
                        },
                        .touch0_active => {
                            try testing.expect(delta.touch0_active != null);
                            try testing.expectEqual(fr.val != 0, delta.touch0_active.?);
                        },
                        .touch1_active => {
                            try testing.expect(delta.touch1_active != null);
                            try testing.expectEqual(fr.val != 0, delta.touch1_active.?);
                        },
                        .battery_level => {
                            try testing.expect(delta.battery_level != null);
                            try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), delta.battery_level.?);
                        },
                        .dpad => {
                            // Compare hat-switch decode: raw val → dpad_x/dpad_y
                            const hat = fr.val;
                            const exp_x: i8 = if (hat >= 0 and hat < 8) HAT_X[@intCast(hat)] else 0;
                            const exp_y: i8 = if (hat >= 0 and hat < 8) HAT_Y[@intCast(hat)] else 0;
                            try testing.expectEqual(exp_x, delta.dpad_x orelse 0);
                            try testing.expectEqual(exp_y, delta.dpad_y orelse 0);
                        },
                        .unknown => {},
                    }
                }

                // Dpad coverage: compare each dpad field against reference hat decode.
                for (cr.fields[0..cr.field_count]) |*cf| {
                    if (cf.tag != .dpad) continue;
                    const hat_raw: i64 = switch (cf.mode) {
                        .standard => ref.readField(pkt, cf.offset, cf.type_tag),
                        .bits => blk: {
                            const u = ref.readBits(pkt, cf.byte_offset, cf.start_bit, cf.bit_count);
                            break :blk if (cf.is_signed)
                                @as(i64, ref.signExtend(u, cf.bit_count))
                            else
                                @as(i64, u);
                        },
                    };
                    const hat_val = ref.runChain(hat_raw, cf);
                    const expected = hatDecode(hat_val);
                    try testing.expect(delta.dpad_x != null);
                    try testing.expect(delta.dpad_y != null);
                    try testing.expectEqual(expected.x, delta.dpad_x.?);
                    try testing.expectEqual(expected.y, delta.dpad_y.?);
                }
            }
            // Every report must have been tested at least once.  Without this,
            // checksum devices silently skip all 1000 iterations (I4).
            try testing.expect(tested_count > 0);
        }
    }
}

// I3: exhaustive dpad test — all 9 hat values (0-8) against hardcoded expected.
test "DRT: dpad hat-switch exhaustive — all 9 values decode correctly" {
    const allocator = testing.allocator;
    const toml =
        \\[device]
        \\name = "DpadTest"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.fields]
        \\dpad = { offset = 1, type = "u8" }
    ;
    const parsed = try device_mod.parseString(allocator, toml);
    defer parsed.deinit();
    const interp = interp_mod.Interpreter.init(&parsed.value);

    const expected_x = [9]i8{ 0, 1, 1, 1, 0, -1, -1, -1, 0 };
    const expected_y = [9]i8{ -1, -1, 0, 1, 1, 1, 0, -1, 0 };

    for (0..9) |hat| {
        var raw = [_]u8{ 0xAA, @intCast(hat), 0, 0 };
        const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
        try testing.expectEqual(expected_x[hat], delta.dpad_x orelse 0);
        try testing.expectEqual(expected_y[hat], delta.dpad_y orelse 0);
    }
}
