const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const helpers = @import("../helpers.zig");

// P4: config self-consistency for all device TOML files
test "property: config self-consistency — field bounds within report size" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer paths.deinit(allocator);

    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch |err| {
            std.debug.print("FAIL parse: {s}: {}\n", .{ path, err });
            return err;
        };
        defer parsed.deinit();

        const cfg = &parsed.value;

        // Vendor class interfaces must have ep_in and ep_out
        for (cfg.device.interface) |iface| {
            if (std.mem.eql(u8, iface.class, "vendor")) {
                if (iface.ep_in == null) {
                    std.debug.print("FAIL: {s} vendor interface {d} missing ep_in\n", .{ path, iface.id });
                    return error.TestUnexpectedResult;
                }
                if (iface.ep_out == null) {
                    std.debug.print("FAIL: {s} vendor interface {d} missing ep_out\n", .{ path, iface.id });
                    return error.TestUnexpectedResult;
                }
            }
        }

        for (cfg.report) |report| {
            const size: usize = @intCast(report.size);

            // field.offset + sizeof(field.type) <= report.size
            if (report.fields) |fields| {
                var it = fields.map.iterator();
                while (it.next()) |entry| {
                    const name = entry.key_ptr.*;
                    const fc = entry.value_ptr.*;

                    if (fc.bits != null) continue; // bits fields use different addressing

                    const offset: usize = @intCast(fc.offset orelse continue);
                    const type_str = fc.type orelse continue;
                    const field_type = interpreter_mod.parseFieldType(type_str) orelse continue;
                    const field_size = fieldTypeSize(field_type);

                    if (offset + field_size > size) {
                        std.debug.print("FAIL: {s} field '{s}' offset={d}+size={d} > report.size={d}\n", .{ path, name, offset, field_size, size });
                        return error.TestUnexpectedResult;
                    }
                }
            }

            // button_group source.offset + source.size <= report.size
            if (report.button_group) |bg| {
                const bg_offset: usize = @intCast(bg.source.offset);
                const bg_size: usize = @intCast(bg.source.size);
                if (bg_offset + bg_size > size) {
                    std.debug.print("FAIL: {s} button_group offset={d}+size={d} > report.size={d}\n", .{ path, bg_offset, bg_size, size });
                    return error.TestUnexpectedResult;
                }
            }

            // match.offset + match.expect.len <= report.size
            if (report.match) |match| {
                const match_offset: usize = @intCast(match.offset);
                if (match_offset + match.expect.len > size) {
                    std.debug.print("FAIL: {s} match offset={d}+len={d} > report.size={d}\n", .{ path, match_offset, match.expect.len, size });
                    return error.TestUnexpectedResult;
                }
            }
        }
    }
}

fn fieldTypeSize(t: interpreter_mod.FieldType) usize {
    return switch (t) {
        .u8, .i8 => 1,
        .u16le, .i16le, .u16be, .i16be => 2,
        .u32le, .i32le, .u32be, .i32be => 4,
    };
}
