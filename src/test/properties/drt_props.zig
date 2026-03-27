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
                var ref_buf: [32]ref.FieldResult = undefined;
                const ref_count = ref.extractFields(cr, pkt, &ref_buf);

                for (ref_buf[0..ref_count]) |fr| {
                    switch (fr.tag) {
                        .ax => if (delta.ax) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .ay => if (delta.ay) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .rx => if (delta.rx) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .ry => if (delta.ry) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .lt => if (delta.lt) |v| try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), v),
                        .rt => if (delta.rt) |v| try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), v),
                        .gyro_x => if (delta.gyro_x) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .gyro_y => if (delta.gyro_y) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .gyro_z => if (delta.gyro_z) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .accel_x => if (delta.accel_x) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .accel_y => if (delta.accel_y) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .accel_z => if (delta.accel_z) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .touch0_x => if (delta.touch0_x) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .touch0_y => if (delta.touch0_y) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .touch1_x => if (delta.touch1_x) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .touch1_y => if (delta.touch1_y) |v| try testing.expectEqual(saturate(i16, fr.val), v),
                        .touch0_active => if (delta.touch0_active) |v| try testing.expectEqual(fr.val != 0, v),
                        .touch1_active => if (delta.touch1_active) |v| try testing.expectEqual(fr.val != 0, v),
                        .battery_level => if (delta.battery_level) |v| try testing.expectEqual(@as(u8, @intCast(fr.val & 0xff)), v),
                        .dpad, .unknown => {}, // multi-output tags
                    }
                }
            }
        }
    }
}
