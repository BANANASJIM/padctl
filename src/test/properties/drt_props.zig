// drt_props.zig — Differential Reference Testing for field extraction.
//
// For every device TOML: generate random HID packets, run the production
// interpreter and compare against the Lean oracle (proven correct).
//
// DRT SCOPE: catches runtime extraction bugs (wrong read logic, bad transform
// math) but NOT config compilation bugs, because both oracle and production
// share CompiledField/CompiledReport from production.  A wrong offset or
// type_tag in compileReport would affect both sides equally and go undetected.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interp_mod = @import("../../core/interpreter.zig");
const lean = @import("../lean_oracle_client.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interp_mod.Interpreter;
const CompiledReport = interp_mod.CompiledReport;
const FieldType = interp_mod.FieldType;
const MAX_FIELDS = interp_mod.MAX_FIELDS;

const HAT_X = [8]i8{ 0, 1, 1, 1, 0, -1, -1, -1 };
const HAT_Y = [8]i8{ -1, -1, 0, 1, 1, 1, 0, -1 };

fn saturate(comptime T: type, v: i64) T {
    if (v > std.math.maxInt(T)) return std.math.maxInt(T);
    if (v < std.math.minInt(T)) return std.math.minInt(T);
    return @intCast(v);
}

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

fn hatDecode(hat: i64) struct { x: i8, y: i8 } {
    if (hat >= 0 and hat < 8) {
        const idx: usize = @intCast(hat);
        return .{ .x = HAT_X[idx], .y = HAT_Y[idx] };
    }
    return .{ .x = 0, .y = 0 };
}

// Compare oracle results against production delta.
fn compareDelta(fr: lean.FieldResult, delta: anytype) !void {
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
            const hat = fr.val;
            const exp_x: i8 = if (hat >= 0 and hat < 8) HAT_X[@intCast(hat)] else 0;
            const exp_y: i8 = if (hat >= 0 and hat < 8) HAT_Y[@intCast(hat)] else 0;
            try testing.expectEqual(exp_x, delta.dpad_x orelse 0);
            try testing.expectEqual(exp_y, delta.dpad_y orelse 0);
        },
        .unknown => {},
    }
}

fn initOracle() error{SkipZigTest}!*lean.LeanOracle {
    var oracle = lean.LeanOracle.init() catch {
        return error.SkipZigTest;
    };
    const heap_oracle = std.heap.page_allocator.create(lean.LeanOracle) catch {
        oracle.deinit();
        return error.SkipZigTest;
    };
    heap_oracle.* = oracle;
    std.log.info("DRT: using Lean subprocess oracle", .{});
    return heap_oracle;
}

fn deinitOracle(oracle: *lean.LeanOracle) void {
    oracle.deinit();
    std.heap.page_allocator.destroy(oracle);
}

test "DRT: production interpreter matches reference oracle on random packets" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    var rng = std.Random.DefaultPrng.init(0xC0FFEE_42);
    const random = rng.random();

    const oracle = initOracle() catch |err| switch (err) {
        error.SkipZigTest => return error.SkipZigTest,
    };
    defer deinitOracle(oracle);

    for (paths.items) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();

        const cfg = &parsed.value;
        const interp = Interpreter.init(cfg);

        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);
            var buf: [1024]u8 = undefined;
            const pkt = buf[0..@min(size, buf.len)];

            const iface: u8 = @intCast(cr.src.interface);
            var tested_count: usize = 0;

            for (0..1000) |_| {
                random.bytes(pkt);
                if (cr.src.match) |m| {
                    const off: usize = @intCast(m.offset);
                    for (m.expect, 0..) |byte, i| {
                        if (off + i < pkt.len) pkt[off + i] = @intCast(byte);
                    }
                }
                if (cr.checksum != null) injectChecksum(cr, pkt);

                const prod_delta = try interp.processReport(iface, pkt);
                const delta = prod_delta orelse continue;
                tested_count += 1;

                var ref_buf: [MAX_FIELDS]lean.FieldResult = undefined;
                const ref_count = try lean.extractFieldsViaLean(oracle, cr, pkt, &ref_buf);

                for (ref_buf[0..ref_count]) |fr| try compareDelta(fr, delta);
            }
            try testing.expect(tested_count > 0);
        }
    }
}

test "DRT: structured random packets — valid field values at correct offsets" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    var rng = std.Random.DefaultPrng.init(0xABCD_EF01);
    const random = rng.random();

    const oracle = initOracle() catch |err| switch (err) {
        error.SkipZigTest => return error.SkipZigTest,
    };
    defer deinitOracle(oracle);

    for (paths.items) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();

        const cfg = &parsed.value;
        const interp = Interpreter.init(cfg);

        for (interp.compiled[0..interp.report_count]) |*cr| {
            const size: usize = @intCast(cr.src.size);
            var buf: [1024]u8 = undefined;
            const pkt = buf[0..@min(size, buf.len)];
            const iface: u8 = @intCast(cr.src.interface);

            var tested_count: usize = 0;
            for (0..200) |_| {
                @memset(pkt, 0);

                if (cr.src.match) |m| {
                    const off: usize = @intCast(m.offset);
                    for (m.expect, 0..) |byte, i| {
                        if (off + i < pkt.len) pkt[off + i] = @intCast(byte);
                    }
                }

                for (cr.fields[0..cr.field_count]) |*cf| {
                    if (cf.mode == .standard) {
                        const lo = typeMin(cf.type_tag);
                        const hi = typeMax(cf.type_tag);
                        const range: u64 = @intCast(hi - lo);
                        const val: i64 = lo + @as(i64, @intCast(random.intRangeAtMost(u64, 0, range)));
                        writeField(pkt, cf.offset, cf.type_tag, val);
                    } else {
                        if (cf.bit_count == 0) continue;
                        const max_val: u32 = if (cf.bit_count >= 32) std.math.maxInt(u32) else (@as(u32, 1) << @as(u5, @intCast(cf.bit_count))) - 1;
                        const raw: u32 = random.intRangeAtMost(u32, 0, max_val);
                        const shifted = @as(u64, raw) << @intCast(cf.start_bit);
                        const needed: u8 = (@as(u8, cf.start_bit) + @as(u8, cf.bit_count) + 7) / 8;
                        for (0..needed) |i| {
                            pkt[cf.byte_offset + i] |= @intCast((shifted >> @intCast(i * 8)) & 0xFF);
                        }
                    }
                }

                if (cr.checksum != null) injectChecksum(cr, pkt);

                const prod_delta = try interp.processReport(iface, pkt);
                const delta = prod_delta orelse continue;
                tested_count += 1;

                var ref_buf: [MAX_FIELDS]lean.FieldResult = undefined;
                const ref_count = try lean.extractFieldsViaLean(oracle, cr, pkt, &ref_buf);

                for (ref_buf[0..ref_count]) |fr| try compareDelta(fr, delta);
            }
            try testing.expect(tested_count > 0);
        }
    }
}

fn typeMin(t: FieldType) i64 {
    return switch (t) {
        .u8, .u16le, .u16be, .u32le, .u32be => 0,
        .i8 => -128,
        .i16le, .i16be => -32768,
        .i32le, .i32be => -2147483648,
    };
}

fn typeMax(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 4294967295,
        .i32le, .i32be => 2147483647,
    };
}

fn writeField(buf: []u8, offset: usize, t: FieldType, value: i64) void {
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
