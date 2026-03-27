// drt_props.zig — Differential Reference Testing for field extraction.
//
// For every device TOML: generate 1000 random HID packets, run both the
// production interpreter and the reference interpreter, and verify that each
// scalar field extracted by production matches the reference oracle.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interp_mod = @import("../../core/interpreter.zig");
const ref = @import("../reference_interp.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interp_mod.Interpreter;
const MAX_FIELDS = interp_mod.MAX_FIELDS;

// saturate mirrors production's saturateCast.
fn saturate(comptime T: type, v: i64) T {
    if (v > std.math.maxInt(T)) return std.math.maxInt(T);
    if (v < std.math.minInt(T)) return std.math.minInt(T);
    return @intCast(v);
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

            for (0..1000) |_| {
                random.bytes(pkt);
                // Inject match bytes so the report is recognised by production.
                if (cr.src.match) |m| {
                    const off: usize = @intCast(m.offset);
                    for (m.expect, 0..) |byte, i| {
                        if (off + i < pkt.len) pkt[off + i] = @intCast(byte);
                    }
                }

                // Production result — skip on checksum mismatch (expected).
                const prod_delta = interp.processReport(iface, pkt) catch continue;
                const delta = prod_delta orelse continue;

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
                        .dpad, .unknown => {}, // multi-output tags
                    }
                }
            }
        }
    }
}
