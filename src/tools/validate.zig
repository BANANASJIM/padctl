const std = @import("std");
const device = @import("../config/device.zig");
const DeviceConfig = device.DeviceConfig;

pub const ValidationError = struct {
    file: []const u8,
    message: []const u8,

    pub fn deinit(self: ValidationError, allocator: std.mem.Allocator) void {
        allocator.free(self.file);
        allocator.free(self.message);
    }
};

const valid_checksum_algos = [_][]const u8{ "crc32", "xor", "sum8" };

fn isValidChecksumAlgo(algo: []const u8) bool {
    for (valid_checksum_algos) |a| {
        if (std.mem.eql(u8, algo, a)) return true;
    }
    return false;
}

fn addError(
    errors: *std.ArrayList(ValidationError),
    allocator: std.mem.Allocator,
    file: []const u8,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    const file_copy = try allocator.dupe(u8, file);
    try errors.append(allocator, .{ .file = file_copy, .message = msg });
}

// Passes 5–7 on an already-parsed config (passes 1–4 are handled by device.parseFile).
fn validateExtended(
    cfg: *const DeviceConfig,
    file: []const u8,
    errors: *std.ArrayList(ValidationError),
    allocator: std.mem.Allocator,
) !void {
    for (cfg.report) |report| {
        // Pass 5: button_group bit_index < 8 * group_size
        if (report.button_group) |bg| {
            const max_bits = @as(i64, bg.source.size) * 8;
            var it = bg.map.map.iterator();
            while (it.next()) |entry| {
                const bit_idx = entry.value_ptr.*;
                if (bit_idx < 0 or bit_idx >= max_bits) {
                    try addError(errors, allocator, file, "report '{s}': button '{s}' bit_index {d} out of range (group size {d} bytes = {d} bits)", .{ report.name, entry.key_ptr.*, bit_idx, bg.source.size, max_bits });
                }
            }
        }
    }

    // Pass 6: match overlap — reports sharing the same interface and same match.offset + expect
    for (cfg.report, 0..) |r1, i| {
        const m1 = r1.match orelse continue;
        for (cfg.report[i + 1 ..]) |r2| {
            const m2 = r2.match orelse continue;
            if (r1.interface != r2.interface) continue;
            if (m1.offset != m2.offset) continue;
            if (!std.mem.eql(i64, m1.expect, m2.expect)) continue;
            try addError(errors, allocator, file, "reports '{s}' and '{s}' have identical match conditions (interface {d}, offset {d})", .{ r1.name, r2.name, r1.interface, m1.offset });
        }
    }

    // Pass 7: checksum algo must be in known set
    for (cfg.report) |report| {
        const cs = report.checksum orelse continue;
        if (!isValidChecksumAlgo(cs.algo)) {
            try addError(errors, allocator, file, "report '{s}': unknown checksum algo '{s}' (valid: crc32, xor, sum8)", .{ report.name, cs.algo });
        }
    }

    // Pass 8: report.interface and commands.*.interface must reference a declared device.interface id
    for (cfg.report) |report| {
        var found = false;
        for (cfg.device.interface) |iface| {
            if (iface.id == report.interface) {
                found = true;
                break;
            }
        }
        if (!found) {
            try addError(errors, allocator, file, "report '{s}': interface {d} not declared in device.interface", .{ report.name, report.interface });
        }
    }
    if (cfg.commands) |cmds| {
        var it = cmds.map.iterator();
        while (it.next()) |entry| {
            const cmd = entry.value_ptr.*;
            var found = false;
            for (cfg.device.interface) |iface| {
                if (iface.id == cmd.interface) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try addError(errors, allocator, file, "command '{s}': interface {d} not declared in device.interface", .{ entry.key_ptr.*, cmd.interface });
            }
        }
    }
}

/// Validate a single TOML file. Returns a slice of errors (caller owns, call freeErrors).
/// Exit semantics: 0 errors = valid, >0 = invalid, null return = parse/IO failure.
pub fn validateFile(
    path: []const u8,
    allocator: std.mem.Allocator,
) ![]ValidationError {
    var errors = std.ArrayList(ValidationError){};
    errdefer {
        for (errors.items) |e| e.deinit(allocator);
        errors.deinit(allocator);
    }

    const parsed = device.parseFile(allocator, path) catch |err| {
        // Passes 1-4 failed; report as a single error entry
        const msg = try std.fmt.allocPrint(allocator, "parse/schema error: {}", .{err});
        const file_copy = try allocator.dupe(u8, path);
        try errors.append(allocator, .{ .file = file_copy, .message = msg });
        return errors.toOwnedSlice(allocator);
    };
    defer parsed.deinit();

    try validateExtended(&parsed.value, path, &errors, allocator);
    return errors.toOwnedSlice(allocator);
}

pub fn freeErrors(errors: []ValidationError, allocator: std.mem.Allocator) void {
    for (errors) |e| e.deinit(allocator);
    allocator.free(errors);
}

// --- tests ---

const testing = std.testing;

const valid_toml =
    \\[device]
    \\name = "T"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 8
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.button_group]
    \\source = { offset = 1, size = 1 }
    \\map = { A = 0, B = 1 }
    \\[report.checksum]
    \\algo = "sum8"
    \\range = [0, 6]
    \\expect = { offset = 7, type = "u8" }
    \\[output]
    \\name = "T"
;

fn validateString(allocator: std.mem.Allocator, content: []const u8) ![]ValidationError {
    // Write to a temp file, then validate
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    try tmp_dir.dir.writeFile(.{ .sub_path = "test.toml", .data = content });
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("test.toml", &buf);
    return validateFile(path, allocator);
}

test "valid config: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateString(allocator, valid_toml);
    defer freeErrors(errors, allocator);
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "bit_index out of range: error reported" {
    const allocator = testing.allocator;
    const bad =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.button_group]
        \\source = { offset = 0, size = 1 }
        \\map = { A = 8 }
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, bad);
    defer freeErrors(errors, allocator);
    try testing.expect(errors.len > 0);
}

test "match overlap: error reported" {
    const allocator = testing.allocator;
    const bad =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r1"
        \\interface = 0
        \\size = 8
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[[report]]
        \\name = "r2"
        \\interface = 0
        \\size = 8
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, bad);
    defer freeErrors(errors, allocator);
    try testing.expect(errors.len > 0);
}

test "unknown checksum algo: error reported" {
    const allocator = testing.allocator;
    const bad =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.checksum]
        \\algo = "md5"
        \\range = [0, 6]
        \\expect = { offset = 6, type = "u16le" }
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, bad);
    defer freeErrors(errors, allocator);
    try testing.expect(errors.len > 0);
    var found = false;
    for (errors) |e| {
        if (std.mem.indexOf(u8, e.message, "md5") != null) found = true;
    }
    try testing.expect(found);
}

test "offset boundary exact: 60 + u32le in 64-byte report is valid" {
    const allocator = testing.allocator;
    const good =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 64
        \\[report.fields]
        \\x = { offset = 60, type = "u32le" }
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, good);
    defer freeErrors(errors, allocator);
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "offset out of bounds: 61 + u32le in 64-byte report is error" {
    const allocator = testing.allocator;
    const bad =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 64
        \\[report.fields]
        \\x = { offset = 61, type = "u32le" }
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, bad);
    defer freeErrors(errors, allocator);
    try testing.expect(errors.len > 0);
}

test "validate devices/sony/dualsense.toml: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateFile("devices/sony/dualsense.toml", allocator);
    defer freeErrors(errors, allocator);
    if (errors.len > 0) {
        for (errors) |e| std.debug.print("  error: {s}\n", .{e.message});
    }
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "validate devices/nintendo/switch-pro.toml: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateFile("devices/nintendo/switch-pro.toml", allocator);
    defer freeErrors(errors, allocator);
    if (errors.len > 0) {
        for (errors) |e| std.debug.print("  error: {s}\n", .{e.message});
    }
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "validate devices/8bitdo/ultimate.toml: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateFile("devices/8bitdo/ultimate.toml", allocator);
    defer freeErrors(errors, allocator);
    if (errors.len > 0) {
        for (errors) |e| std.debug.print("  error: {s}\n", .{e.message});
    }
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "validate devices/microsoft/xbox-elite.toml: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateFile("devices/microsoft/xbox-elite.toml", allocator);
    defer freeErrors(errors, allocator);
    if (errors.len > 0) {
        for (errors) |e| std.debug.print("  error: {s}\n", .{e.message});
    }
    try testing.expectEqual(@as(usize, 0), errors.len);
}

test "undeclared interface in report: error reported" {
    const allocator = testing.allocator;
    const bad =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 99
        \\size = 8
        \\[output]
        \\name = "T"
    ;
    const errors = try validateString(allocator, bad);
    defer freeErrors(errors, allocator);
    try testing.expect(errors.len > 0);
    var found = false;
    for (errors) |e| {
        if (std.mem.indexOf(u8, e.message, "interface 99") != null) found = true;
    }
    try testing.expect(found);
}

test "validate devices/flydigi/vader5.toml: 0 errors" {
    const allocator = testing.allocator;
    const errors = try validateFile("devices/flydigi/vader5.toml", allocator);
    defer freeErrors(errors, allocator);
    if (errors.len > 0) {
        for (errors) |e| std.debug.print("  error: {s}\n", .{e.message});
    }
    try testing.expectEqual(@as(usize, 0), errors.len);
}
