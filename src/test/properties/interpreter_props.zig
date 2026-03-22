const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interpreter_mod.Interpreter;
const FieldType = interpreter_mod.FieldType;

// P1: any random packet → processReport never panics (returns Ok or null)
test "property: interpreter robustness — random packets never crash" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);

    if (paths.items.len == 0) return;

    var rng = std.Random.DefaultPrng.init(0xDEAD_BEEF);
    const random = rng.random();

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const cfg = &parsed.value;
        const interp = Interpreter.init(cfg);

        for (cfg.report) |report| {
            const size: usize = @intCast(report.size);
            var buf: [1024]u8 = undefined;
            const pkt = buf[0..@min(size, buf.len)];

            for (0..1000) |_| {
                random.bytes(pkt);
                const iface: u8 = @intCast(report.interface);
                _ = interp.processReport(iface, pkt) catch |err| switch (err) {
                    error.ChecksumMismatch => {},
                    error.MalformedConfig => {},
                };
            }
        }
    }
}

// P2: packets with correct match bytes → field values within type range
test "property: field values within type range for matched reports" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);

    if (paths.items.len == 0) return;

    var rng = std.Random.DefaultPrng.init(0xCAFE_BABE);
    const random = rng.random();

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const cfg = &parsed.value;

        for (cfg.report) |report| {
            if (report.fields == null) continue;
            if (report.checksum != null) continue; // skip checksum-protected reports

            const size: usize = @intCast(report.size);
            var buf: [1024]u8 = undefined;
            if (size > buf.len) continue;
            const pkt = buf[0..size];

            for (0..1000) |_| {
                random.bytes(pkt);

                // Set match bytes so the report is recognized
                if (report.match) |match| {
                    const off: usize = @intCast(match.offset);
                    for (match.expect, 0..) |byte_val, i| {
                        if (off + i < pkt.len) {
                            pkt[off + i] = @intCast(byte_val & 0xFF);
                        }
                    }
                }

                const fields = report.fields.?;
                var it = fields.map.iterator();
                while (it.next()) |entry| {
                    const fc = entry.value_ptr.*;
                    const type_str = fc.type orelse continue;
                    const field_type = interpreter_mod.parseFieldType(type_str) orelse continue;
                    const offset: usize = @intCast(fc.offset orelse continue);

                    const end = offset + fieldTypeSize(field_type);
                    if (end > pkt.len) continue;

                    const val = interpreter_mod.readFieldByTag(pkt, offset, field_type);
                    const max = typeMax(field_type);
                    const min = typeMin(field_type);

                    if (val > max or val < min) {
                        std.debug.print("FAIL range: {s} field type={s} val={d} range=[{d},{d}]\n", .{ path, type_str, val, min, max });
                        return error.TestUnexpectedResult;
                    }
                }
            }
        }
    }
}

fn fieldTypeSize(t: FieldType) usize {
    return switch (t) {
        .u8, .i8 => 1,
        .u16le, .i16le, .u16be, .i16be => 2,
        .u32le, .i32le, .u32be, .i32be => 4,
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

fn typeMin(t: FieldType) i64 {
    return switch (t) {
        .u8, .u16le, .u16be, .u32le, .u32be => 0,
        .i8 => -128,
        .i16le, .i16be => -32768,
        .i32le, .i32be => -2147483648,
    };
}
