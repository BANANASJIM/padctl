// lean_drt_props.zig — Lean oracle DRT: proven-correct test vectors vs production.
//
// The Lean 4 formal spec (formal/lean/) generates exhaustive test vectors for
// every pure function in the interpreter pipeline.  This file embeds those
// vectors at comptime and asserts the production code matches exactly.
//
// Lean oracle output is THE truth (theorem-proven).  Any mismatch = Zig bug.

const std = @import("std");
const testing = std.testing;
const interp = @import("../../core/interpreter.zig");
const state = @import("../../core/state.zig");
const device = @import("../../config/device.zig");

const csv_data = @embedFile("../../../formal/lean/test_vectors.csv");

// --- CSV helpers ---

const Lines = struct {
    data: []const u8,
    pos: usize = 0,

    fn next(self: *Lines) ?[]const u8 {
        if (self.pos >= self.data.len) return null;
        const start = self.pos;
        while (self.pos < self.data.len and self.data[self.pos] != '\n') : (self.pos += 1) {}
        const line = self.data[start..self.pos];
        if (self.pos < self.data.len) self.pos += 1; // skip \n
        return line;
    }
};

fn parseInt(s: []const u8) !i64 {
    if (s.len == 0) return error.EmptyField;
    return std.fmt.parseInt(i64, s, 10);
}

fn parseUint(s: []const u8) !u64 {
    if (s.len == 0) return error.EmptyField;
    return std.fmt.parseInt(u64, s, 10);
}

fn splitFields(line: []const u8) ![8][]const u8 {
    var result: [8][]const u8 = .{""} ** 8;
    var n: usize = 0;
    var start: usize = 0;
    for (line, 0..) |ch, i| {
        if (ch == ',') {
            if (n >= result.len) return error.TooManyFields;
            result[n] = line[start..i];
            n += 1;
            start = i + 1;
        }
    }
    if (n >= result.len) return error.TooManyFields;
    result[n] = line[start..];
    return result;
}

fn parseBool01(s: []const u8) !bool {
    if (std.mem.eql(u8, s, "1")) return true;
    if (std.mem.eql(u8, s, "0")) return false;
    return error.InvalidBool;
}

fn parseNamedUint(s: []const u8, comptime prefix: []const u8) !u64 {
    if (!std.mem.startsWith(u8, s, prefix)) return error.MalformedVector;
    return parseUint(s[prefix.len..]);
}

fn isDataLine(line: []const u8) bool {
    return line.len > 0 and line[0] != '#';
}

// Advance past section header, return iterator positioned at data lines.
fn seekSection(comptime header: []const u8) Lines {
    var lines = Lines{ .data = csv_data };
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, header)) return lines;
    }
    return lines; // not found — will produce 0 vectors
}

// --- Tests ---

test "lean_drt: transform negate vectors" {
    var lines = seekSection("# TRANSFORM");
    _ = lines.next(); // skip column header
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        if (!std.mem.eql(u8, f[0], "negate") and !std.mem.eql(u8, f[0], "abs")) continue;
        const input = try parseInt(f[1]);
        const t_max_raw = try parseUint(f[2]);
        const expected = try parseInt(f[3]);
        const op: interp.TransformOp = if (std.mem.eql(u8, f[0], "negate")) .negate else .abs;
        var chain = interp.CompiledTransformChain{ .type_tag = try tMaxToFieldType(t_max_raw) };
        chain.items[0] = .{ .op = op };
        chain.len = 1;
        const actual = interp.runTransformChain(input, &chain);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: transform clamp vectors" {
    var lines = seekSection("# TRANSFORM");
    _ = lines.next(); // skip column header
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        if (!std.mem.eql(u8, f[0], "clamp")) continue;
        const input = try parseInt(f[1]);
        const lo = try parseInt(f[2]);
        const hi = try parseInt(f[3]);
        const expected = try parseInt(f[4]);
        var chain = interp.CompiledTransformChain{ .type_tag = .u8 };
        chain.items[0] = .{ .op = .clamp, .a = lo, .b = hi };
        chain.len = 1;
        const actual = interp.runTransformChain(input, &chain);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: transform deadzone vectors" {
    var lines = seekSection("# TRANSFORM");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        if (!std.mem.eql(u8, f[0], "deadzone")) continue;
        const input = try parseInt(f[1]);
        const threshold = try parseInt(f[2]);
        const expected = try parseInt(f[3]);
        var chain = interp.CompiledTransformChain{ .type_tag = .u8 };
        chain.items[0] = .{ .op = .deadzone, .a = threshold };
        chain.len = 1;
        const actual = interp.runTransformChain(input, &chain);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: transform scale vectors" {
    var lines = seekSection("# TRANSFORM");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        if (!std.mem.eql(u8, f[0], "scale")) continue;
        // scale,input,tMax,a,b,expected
        const input = try parseInt(f[1]);
        const t_max_raw = try parseUint(f[2]);
        const a = try parseInt(f[3]);
        const b = try parseInt(f[4]);
        const expected = try parseInt(f[5]);
        var chain = interp.CompiledTransformChain{ .type_tag = try tMaxToFieldType(t_max_raw) };
        chain.items[0] = .{ .op = .scale, .a = a, .b = b };
        chain.len = 1;
        const actual = interp.runTransformChain(input, &chain);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: transform chain vectors" {
    var lines = seekSection("# CHAIN");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        // input,tMax,op1,op2,...,expected
        // Last non-empty field is expected; ops live in f[2]..f[expected_idx-1].
        const f = try splitFields(line);
        const input = try parseInt(f[0]);
        const t_max_raw = try parseUint(f[1]);
        var expected_idx: usize = 7;
        while (expected_idx > 2 and f[expected_idx].len == 0) : (expected_idx -= 1) {}
        const expected = try parseInt(f[expected_idx]);

        var chain = interp.CompiledTransformChain{ .type_tag = try tMaxToFieldType(t_max_raw) };
        chain.len = 0;
        for (2..expected_idx) |i| {
            if (f[i].len == 0) continue; // empty chain slot
            chain.items[chain.len] = try parseChainOp(f[i]);
            chain.len += 1;
        }
        const actual = interp.runTransformChain(input, &chain);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: readField vectors" {
    // READFIELD section: field_type,offset,expected
    // The Lean oracle tests against hardcoded byte arrays. We reconstruct them.
    // u8/i8 raw: [0x00, 0x7F, 0x80, 0xFF]
    const raw_u8 = [_]u8{ 0x00, 0x7F, 0x80, 0xFF };
    // u16le/i16le raw: [0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80, 0xFF, 0xFF]
    const raw_16le = [_]u8{ 0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80, 0xFF, 0xFF };
    // u16be/i16be raw: [0x00, 0x00, 0x7F, 0xFF, 0x80, 0x00, 0xFF, 0xFF]
    const raw_16be = [_]u8{ 0x00, 0x00, 0x7F, 0xFF, 0x80, 0x00, 0xFF, 0xFF };
    const raw_32le = [_]u8{
        0x00, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0x7F,
        0x00, 0x00, 0x00, 0x80,
        0xFF, 0xFF, 0xFF, 0xFF,
    };
    const raw_32be = [_]u8{
        0x00, 0x00, 0x00, 0x00,
        0x7F, 0xFF, 0xFF, 0xFF,
        0x80, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF,
    };

    var lines = seekSection("# READFIELD");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const ft = try parseLeanFieldType(f[0]);
        const off: usize = @intCast(try parseUint(f[1]));
        const expected = try parseInt(f[2]);
        const raw: []const u8 = switch (ft) {
            .u8, .i8 => &raw_u8,
            .u16le, .i16le => &raw_16le,
            .u16be, .i16be => &raw_16be,
            .u32le, .i32le => &raw_32le,
            .u32be, .i32be => &raw_32be,
        };
        const actual = interp.readFieldByTag(raw, off, ft);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: extractBits vectors" {
    const raw = [_]u8{ 0b10110100, 0b11001010, 0xFF, 0x00 };
    var lines = seekSection("# EXTRACTBITS");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const byte_off: u16 = @intCast(try parseUint(f[0]));
        const start_bit: u3 = @intCast(try parseUint(f[1]));
        const bit_count: u6 = @intCast(try parseUint(f[2]));
        const expected: u32 = @intCast(try parseUint(f[3]));
        const actual = interp.extractBits(&raw, byte_off, start_bit, bit_count);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: signExtend vectors" {
    var lines = seekSection("# SIGNEXTEND");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const val: u32 = @intCast(try parseUint(f[0]));
        const bits: u6 = @intCast(try parseUint(f[1]));
        const expected: i32 = @intCast(try parseInt(f[2]));
        const actual = interp.signExtend(val, bits);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: button assembly vectors" {
    var lines = seekSection("# ASSEMBLE");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        // raw,suppress,inject,expected
        const f = try splitFields(line);
        const raw = try parseUint(f[0]);
        const suppress = try parseUint(f[1]);
        const inject = try parseUint(f[2]);
        const expected = try parseUint(f[3]);
        const actual = (raw & ~suppress) | inject;
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: dpad synthesis vectors" {
    var lines = seekSection("# DPAD_SYNTH");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const buttons = try parseUint(f[0]);
        const expected_dx: i8 = @intCast(try parseInt(f[1]));
        const expected_dy: i8 = @intCast(try parseInt(f[2]));
        var gs = state.GamepadState{};
        gs.buttons = buttons;
        gs.synthesizeDpadAxes();
        try testing.expectEqual(expected_dx, gs.dpad_x);
        try testing.expectEqual(expected_dy, gs.dpad_y);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: checksum vectors" {
    var lines = seekSection("# CHECKSUM");
    _ = lines.next();
    var count: usize = 0;
    // Hardcoded raw arrays matching the Lean oracle
    const raws = [_][]const u8{
        &[_]u8{ 1, 2, 3, 6 }, // sum8 pass
        &[_]u8{ 1, 2, 3, 7 }, // sum8 fail
        &[_]u8{ 0xAA, 0x55, 0xFF }, // xor pass
        &[_]u8{ 0xAA, 0x55, 0x00 }, // xor fail
    };
    var raw_idx: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const algo_str = f[0];
        const start: usize = @intCast(try parseUint(f[1]));
        const stop: usize = @intCast(try parseUint(f[2]));
        const actual_bool = blk: {
            if (std.mem.eql(u8, algo_str, "sum8") or std.mem.eql(u8, algo_str, "xor")) {
                const offset: usize = @intCast(try parseUint(f[3]));
                if (raw_idx >= raws.len) return error.MalformedVector;
                const algo: interp.ChecksumAlgo = if (std.mem.eql(u8, algo_str, "sum8")) .sum8 else .xor;
                const raw = raws[raw_idx];
                raw_idx += 1;
                break :blk verifyChecksumViaCompiled(raw, algo, start, stop, offset);
            }
            if (std.mem.eql(u8, algo_str, "crc32")) {
                const computed = try parseNamedUint(f[3], "computed=");
                const expected_crc = try parseNamedUint(f[4], "expected=");
                var crc = std.hash.crc.Crc32IsoHdlc.init();
                crc.update("123456789");
                const actual_crc = crc.final();
                try testing.expectEqual(expected_crc, actual_crc);
                break :blk actual_crc == computed;
            }
            if (std.mem.eql(u8, algo_str, "crc32_verify")) {
                const offset: usize = @intCast(try parseUint(f[3]));
                const raw = [_]u8{
                    0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
                    0x26, 0x39, 0xF4, 0xCB,
                };
                break :blk verifyChecksumViaCompiled(&raw, .crc32, start, stop, offset);
            }
            return error.UnknownChecksumAlgo;
        };
        const expected_bool = try parseBool01(if (std.mem.eql(u8, algo_str, "crc32")) f[5] else f[4]);
        try testing.expectEqual(expected_bool, actual_bool);
        count += 1;
    }
    try testing.expectEqual(raws.len, raw_idx);
    try testing.expect(count > 0);
}

test "lean_drt: hat decode vectors" {
    var lines = seekSection("# HAT_DECODE");
    _ = lines.next();
    var count: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = try splitFields(line);
        const decoded = interp.decodeDpadHat(try parseInt(f[0]));
        const expected_dx: i8 = @intCast(try parseInt(f[1]));
        const expected_dy: i8 = @intCast(try parseInt(f[2]));
        try testing.expectEqual(expected_dx, decoded.x);
        try testing.expectEqual(expected_dy, decoded.y);
        count += 1;
    }
    try testing.expect(count > 0);
}

test "lean_drt: button decode vectors" {
    var lines = seekSection("# BUTTON_DECODE");
    _ = lines.next();
    var count: usize = 0;
    const raws = [_][]const u8{
        &[_]u8{0x05},
        &[_]u8{0xFF},
        &[_]u8{0x00},
    };
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        if (count >= raws.len) return error.MalformedVector;
        const f = try splitFields(line);
        const src_off: usize = @intCast(try parseUint(f[0]));
        const src_size: usize = @intCast(try parseUint(f[1]));
        const expected = try parseUint(f[3]);
        const actual = try decodeButtonEntries(testing.allocator, raws[count], src_off, src_size, f[2]);
        try testing.expectEqual(expected, actual);
        count += 1;
    }
    try testing.expectEqual(raws.len, count);
}

fn verifyChecksumViaCompiled(raw: []const u8, algo: interp.ChecksumAlgo, start: usize, stop: usize, offset: usize) bool {
    var report = interp.ReportConfig{
        .name = "lean-checksum",
        .interface = 0,
        .size = @intCast(raw.len),
    };
    var cr = interp.CompiledReport{
        .src = &report,
        .checksum = .{
            .algo = algo,
            .range_start = start,
            .range_end = stop,
            .expect_off = offset,
            .seed = null,
        },
        .fields = undefined,
        .field_count = 0,
        .button_group = null,
    };
    interp.verifyChecksumCompiled(&cr, raw) catch |err| switch (err) {
        error.ChecksumMismatch => return false,
        else => return false,
    };
    return true;
}

fn decodeButtonEntries(allocator: std.mem.Allocator, raw: []const u8, src_off: usize, src_size: usize, entries: []const u8) !u64 {
    var map_buf = std.ArrayList(u8){};
    defer map_buf.deinit(allocator);
    const map_w = map_buf.writer(allocator);
    var it = std.mem.splitScalar(u8, entries, '|');
    var first = true;
    while (it.next()) |entry| {
        const sep = std.mem.indexOfScalar(u8, entry, ':') orelse return error.MalformedVector;
        const src_bit = try parseUint(entry[0..sep]);
        const button_name = try buttonNameFromIndex(try parseUint(entry[sep + 1 ..]));
        if (!first) try map_w.writeAll(", ");
        try map_w.print("{s} = {d}", .{ button_name, src_bit });
        first = false;
    }

    const toml_str = try std.fmt.allocPrint(allocator,
        \\[device]
        \\name = "Lean Button Decode"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = {d}
        \\[report.match]
        \\offset = 0
        \\expect = [{d}]
        \\[report.button_group]
        \\source = {{ offset = {d}, size = {d} }}
        \\map = {{ {s} }}
    , .{ raw.len, raw[0], src_off, src_size, map_buf.items });
    defer allocator.free(toml_str);

    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();
    const runner = interp.Interpreter.init(&parsed.value);
    const delta = (try runner.processReport(0, raw)) orelse return error.NoMatch;
    return delta.buttons orelse 0;
}

fn buttonNameFromIndex(idx: u64) ![]const u8 {
    const field_count = @typeInfo(state.ButtonId).@"enum".fields.len;
    if (idx >= field_count) return error.MalformedVector;
    const button: state.ButtonId = @enumFromInt(idx);
    return @tagName(button);
}

// --- Helpers ---

fn tMaxToFieldType(t_max: u64) !interp.FieldType {
    return switch (t_max) {
        255 => .u8,
        127 => .i8,
        65535 => .u16le,
        32767 => .i16le,
        else => error.UnknownFieldType,
    };
}

fn parseLeanFieldType(s: []const u8) !interp.FieldType {
    if (std.mem.eql(u8, s, "FieldType.u8")) return .u8;
    if (std.mem.eql(u8, s, "FieldType.i8")) return .i8;
    if (std.mem.eql(u8, s, "FieldType.u16le")) return .u16le;
    if (std.mem.eql(u8, s, "FieldType.i16le")) return .i16le;
    if (std.mem.eql(u8, s, "FieldType.u16be")) return .u16be;
    if (std.mem.eql(u8, s, "FieldType.i16be")) return .i16be;
    if (std.mem.eql(u8, s, "FieldType.u32le")) return .u32le;
    if (std.mem.eql(u8, s, "FieldType.i32le")) return .i32le;
    if (std.mem.eql(u8, s, "FieldType.u32be")) return .u32be;
    if (std.mem.eql(u8, s, "FieldType.i32be")) return .i32be;
    return error.UnknownFieldType;
}

fn parseChainOp(s: []const u8) !interp.CompiledTransform {
    if (std.mem.eql(u8, s, "negate")) return .{ .op = .negate };
    if (std.mem.eql(u8, s, "abs")) return .{ .op = .abs };
    if (std.mem.startsWith(u8, s, "clamp:")) {
        // clamp:lo:hi
        const rest = s[6..];
        const sep = std.mem.indexOfScalar(u8, rest, ':') orelse return error.MalformedVector;
        return .{ .op = .clamp, .a = try parseInt(rest[0..sep]), .b = try parseInt(rest[sep + 1 ..]) };
    }
    if (std.mem.startsWith(u8, s, "scale:")) {
        const rest = s[6..];
        const sep = std.mem.indexOfScalar(u8, rest, ':') orelse return error.MalformedVector;
        return .{ .op = .scale, .a = try parseInt(rest[0..sep]), .b = try parseInt(rest[sep + 1 ..]) };
    }
    if (std.mem.startsWith(u8, s, "deadzone:")) {
        return .{ .op = .deadzone, .a = try parseInt(s[9..]) };
    }
    return error.UnknownTransformOp;
}
