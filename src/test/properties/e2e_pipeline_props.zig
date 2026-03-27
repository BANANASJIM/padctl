// E2E pipeline property tests: TOML config → Interpreter → processReport → GamepadState → Mapper
//
// Validates the complete path from DSL device definition to remapped output.

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const state_mod = @import("../../core/state.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interpreter_mod.Interpreter;
const FieldType = interpreter_mod.FieldType;
const GamepadState = state_mod.GamepadState;
const GamepadStateDelta = state_mod.GamepadStateDelta;
const ButtonId = state_mod.ButtonId;

const makeMapper = helpers.makeMapper;
const btnMask = helpers.btnMask;

// --- A. Config bounds: interface id references exist ---

test "property: config — interface ids reference declared interfaces" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);
    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();
        const cfg = &parsed.value;

        for (cfg.report) |report| {
            var found = false;
            for (cfg.device.interface) |iface| {
                if (iface.id == report.interface) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("FAIL: {s} report '{s}' references interface {d} not in device.interface[]\n", .{
                    path, report.name, report.interface,
                });
                return error.TestUnexpectedResult;
            }
        }
    }
}

test "property: config — checksum range within report bounds" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);
    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        for (parsed.value.report) |report| {
            const cs = report.checksum orelse continue;
            const size: usize = @intCast(report.size);
            if (cs.range.len < 2) continue;
            const range_end: usize = @intCast(cs.range[1]);
            const expect_off: usize = @intCast(cs.expect.offset);

            if (range_end > size) {
                std.debug.print("FAIL: {s} checksum range_end={d} > report.size={d}\n", .{ path, range_end, size });
                return error.TestUnexpectedResult;
            }

            const expect_size: usize = if (std.mem.eql(u8, cs.expect.type, "u32le")) 4 else 1;
            if (expect_off + expect_size > size) {
                std.debug.print("FAIL: {s} checksum expect offset={d}+{d} > report.size={d}\n", .{ path, expect_off, expect_size, size });
                return error.TestUnexpectedResult;
            }
        }
    }
}

test "property: config — vid/pid non-zero" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);
    if (paths.items.len == 0) return;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        if (parsed.value.device.vid == 0) {
            std.debug.print("FAIL: {s} vid == 0\n", .{path});
            return error.TestUnexpectedResult;
        }
        if (parsed.value.device.pid == 0) {
            std.debug.print("FAIL: {s} pid == 0\n", .{path});
            return error.TestUnexpectedResult;
        }
    }
}

// --- B. Per-device fuzz: every config, random packets, no crash ---

test "fuzz: per-device random packets via std.testing.fuzz — vader5" {
    try std.testing.fuzz(.{}, struct {
        fn run(_: @TypeOf(.{}), input: []const u8) !void {
            fuzzDevice(vader5_toml, input);
        }
    }.run, .{});
}

test "fuzz: per-device random packets via std.testing.fuzz — dualsense" {
    try std.testing.fuzz(.{}, struct {
        fn run(_: @TypeOf(.{}), input: []const u8) !void {
            fuzzDevice(dualsense_toml, input);
        }
    }.run, .{});
}

test "fuzz: per-device random packets via std.testing.fuzz — switch_pro" {
    try std.testing.fuzz(.{}, struct {
        fn run(_: @TypeOf(.{}), input: []const u8) !void {
            fuzzDevice(switch_pro_toml, input);
        }
    }.run, .{});
}

fn fuzzDevice(comptime toml: []const u8, input: []const u8) void {
    const parsed = device_mod.parseString(testing.allocator, toml) catch return;
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);
    for (0..4) |iface| {
        _ = interp.processReport(@intCast(iface), input) catch {};
    }
}

// --- C. Interpreter round-trip: writeField → processReport → read matches ---

fn writeFieldByTag(raw: []u8, off: usize, t: FieldType, val: i64) void {
    switch (t) {
        .u8 => raw[off] = @intCast(val & 0xff),
        .i8 => raw[off] = @bitCast(@as(i8, @intCast(std.math.clamp(val, -128, 127)))),
        .u16le => std.mem.writeInt(u16, raw[off..][0..2], @intCast(val & 0xffff), .little),
        .i16le => std.mem.writeInt(i16, raw[off..][0..2], @intCast(std.math.clamp(val, -32768, 32767)), .little),
        .u16be => std.mem.writeInt(u16, raw[off..][0..2], @intCast(val & 0xffff), .big),
        .i16be => std.mem.writeInt(i16, raw[off..][0..2], @intCast(std.math.clamp(val, -32768, 32767)), .big),
        .u32le => std.mem.writeInt(u32, raw[off..][0..4], @intCast(val & 0xffffffff), .little),
        .i32le => std.mem.writeInt(i32, raw[off..][0..4], @intCast(std.math.clamp(val, -2147483648, 2147483647)), .little),
        .u32be => std.mem.writeInt(u32, raw[off..][0..4], @intCast(val & 0xffffffff), .big),
        .i32be => std.mem.writeInt(i32, raw[off..][0..4], @intCast(std.math.clamp(val, -2147483648, 2147483647)), .big),
    }
}

fn fieldTypeSize(t: FieldType) usize {
    return switch (t) {
        .u8, .i8 => 1,
        .u16le, .i16le, .u16be, .i16be => 2,
        .u32le, .i32le, .u32be, .i32be => 4,
    };
}

fn typeMaxVal(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 4294967295,
        .i32le, .i32be => 2147483647,
    };
}

fn typeMinVal(t: FieldType) i64 {
    return switch (t) {
        .u8, .u16le, .u16be, .u32le, .u32be => 0,
        .i8 => -128,
        .i16le, .i16be => -32768,
        .i32le, .i32be => -2147483648,
    };
}

fn randomInRange(rng: std.Random, min: i64, max: i64) i64 {
    if (min == max) return min;
    const range: u64 = @intCast(max - min);
    return min + @as(i64, @intCast(rng.uintAtMost(u64, range)));
}

// Minimal inline TOML for round-trip: single field, no transform
const roundtrip_toml_prefix =
    \\[device]
    \\name = "RT"
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
    \\expect = [0xAA]
    \\[report.fields]
;

test "property: interpreter round-trip — write field → processReport → read matches (no transform)" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xCAFE_1234);
    const rng = prng.random();

    // Test each field type
    const TypeAndTag = struct { type_str: []const u8, field_type: FieldType, tag: []const u8, offset: usize };
    const cases = [_]TypeAndTag{
        .{ .type_str = "u8", .field_type = .u8, .tag = "lt", .offset = 1 },
        .{ .type_str = "i16le", .field_type = .i16le, .tag = "left_x", .offset = 2 },
        .{ .type_str = "u16le", .field_type = .u16le, .tag = "rt", .offset = 2 },
        .{ .type_str = "i8", .field_type = .i8, .tag = "gyro_x", .offset = 1 },
    };

    for (cases) |c| {
        var toml_buf: [512]u8 = undefined;
        const toml_str = std.fmt.bufPrint(&toml_buf, "{s}{s} = {{ offset = {d}, type = \"{s}\" }}\n", .{
            roundtrip_toml_prefix, c.tag, c.offset, c.type_str,
        }) catch continue;

        const parsed = device_mod.parseString(allocator, toml_str) catch continue;
        defer parsed.deinit();
        const interp = Interpreter.init(&parsed.value);

        for (0..1000) |_| {
            var raw = [_]u8{0} ** 8;
            raw[0] = 0xAA; // match byte

            const val = randomInRange(rng, typeMinVal(c.field_type), typeMaxVal(c.field_type));
            writeFieldByTag(&raw, c.offset, c.field_type, val);

            const delta = (interp.processReport(0, &raw) catch continue) orelse continue;

            // Verify extracted value matches written value
            const extracted: i64 = extractDeltaField(delta, c.tag);
            if (extracted != val) {
                std.debug.print("FAIL round-trip: type={s} wrote={d} got={d}\n", .{ c.type_str, val, extracted });
                return error.TestUnexpectedResult;
            }
        }
    }
}

fn extractDeltaField(delta: GamepadStateDelta, tag: []const u8) i64 {
    if (std.mem.eql(u8, tag, "lt")) return delta.lt orelse 0;
    if (std.mem.eql(u8, tag, "rt")) return delta.rt orelse 0;
    if (std.mem.eql(u8, tag, "left_x")) return delta.ax orelse 0;
    if (std.mem.eql(u8, tag, "gyro_x")) return delta.gyro_x orelse 0;
    return 0;
}

// --- C2. Round-trip with transform: write → processReport == manual transform ---

test "property: interpreter round-trip with transform — processReport matches manual transform" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xBEEF_CAFE);
    const rng = prng.random();

    const transforms = [_]struct { str: []const u8, apply: *const fn (i64) i64 }{
        .{ .str = "negate", .apply = &negateFn },
        .{ .str = "abs", .apply = &absFn },
    };

    for (transforms) |tr| {
        var toml_buf: [512]u8 = undefined;
        const toml_str = std.fmt.bufPrint(&toml_buf, "{s}left_x = {{ offset = 2, type = \"i16le\", transform = \"{s}\" }}\n", .{
            roundtrip_toml_prefix, tr.str,
        }) catch continue;

        const parsed = device_mod.parseString(allocator, toml_str) catch continue;
        defer parsed.deinit();
        const interp = Interpreter.init(&parsed.value);

        for (0..1000) |_| {
            var raw = [_]u8{0} ** 8;
            raw[0] = 0xAA;

            const val = randomInRange(rng, -32768, 32767);
            writeFieldByTag(&raw, 2, .i16le, val);

            const delta = (interp.processReport(0, &raw) catch continue) orelse continue;
            const extracted: i64 = delta.ax orelse 0;
            const expected = saturateCastI16(tr.apply(val));

            if (extracted != expected) {
                std.debug.print("FAIL transform round-trip: {s}({d}) expected={d} got={d}\n", .{ tr.str, val, expected, extracted });
                return error.TestUnexpectedResult;
            }
        }
    }
}

fn negateFn(v: i64) i64 {
    return if (v == std.math.minInt(i64)) std.math.maxInt(i64) else -v;
}

fn absFn(v: i64) i64 {
    const clamped = if (v == std.math.minInt(i64)) std.math.maxInt(i64) else v;
    return @intCast(@abs(clamped));
}

fn saturateCastI16(val: i64) i64 {
    if (val > 32767) return 32767;
    if (val < -32768) return -32768;
    return val;
}

// --- D. E2E DSL-to-remap: TOML → Interpreter → processReport → GamepadState → Mapper ---

test "e2e pipeline: vader5 — axes + button A → remap A→KEY_F13" {
    const allocator = testing.allocator;
    const parsed = device_mod.parseString(allocator, vader5_toml) catch return;
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Build raw packet: match bytes + known axes + button A
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], 5000, .little); // left_x
    std.mem.writeInt(i16, raw[5..7], -3000, .little); // left_y (negate → 3000)
    raw[11] = 0x10; // A = bit 4
    raw[15] = 200; // lt

    const delta = (try interp.processReport(1, &raw)) orelse return error.NoMatch;

    // Verify interpreter output
    try testing.expectEqual(@as(?i16, 5000), delta.ax);
    try testing.expectEqual(@as(?i16, 3000), delta.ay); // negated
    try testing.expectEqual(@as(?u8, 200), delta.lt);
    const btns = delta.buttons orelse return error.NoBtns;
    try testing.expect(btns & btnMask(.A) != 0);

    // Feed into mapper with A→KEY_F13
    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(delta, 16);
    // A suppressed in gamepad output
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    // KEY_F13 emitted as aux
    try testing.expectEqual(@as(usize, 1), ev.aux.len);
    // Axes pass through
    try testing.expectEqual(@as(i16, 5000), ev.gamepad.ax);
    try testing.expectEqual(@as(i16, 3000), ev.gamepad.ay);
    try testing.expectEqual(@as(u8, 200), ev.gamepad.lt);
}

test "e2e pipeline: dualsense USB — scaled axes + buttons → remap B→mouse_left" {
    const allocator = testing.allocator;
    const parsed = device_mod.parseString(allocator, dualsense_toml) catch return;
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var raw = [_]u8{0} ** 64;
    raw[0] = 0x01; // report ID match
    raw[1] = 0x80; // left_x = 128 (center, scale → ~0)
    raw[2] = 0x00; // left_y = 0 (full up, scale → -32768, negate → 32767)
    raw[5] = 0xFF; // lt = 255
    raw[6] = 0x00; // rt = 0
    // Button byte 8: bits 4-7: X=4, A=5, B=6, Y=7
    raw[8] = 0x40; // B = bit 6

    const delta = (try interp.processReport(3, &raw)) orelse return error.NoMatch;
    try testing.expect(delta.lt != null);
    try testing.expectEqual(@as(?u8, 255), delta.lt);
    const btns = delta.buttons orelse return error.NoBtns;
    try testing.expect(btns & btnMask(.B) != 0);

    // Feed into mapper with B→mouse_left
    var ctx = try makeMapper(
        \\[remap]
        \\B = "mouse_left"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(delta, 16);
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.B));
    var found_mouse_left = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .mouse_button => |mb| if (mb.code == helpers.BTN_LEFT and mb.pressed) {
                found_mouse_left = true;
            },
            else => {},
        }
    }
    try testing.expect(found_mouse_left);
}

test "e2e pipeline: switch-pro — button press → remap A→B, Y→KEY_F1" {
    const allocator = testing.allocator;
    const parsed = device_mod.parseString(allocator, switch_pro_toml) catch return;
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var raw = [_]u8{0} ** 49;
    raw[0] = 0x30; // report ID match
    // byte 3: Y=0, X=1, B=2, A=3 → set A (bit 3) and Y (bit 0)
    raw[3] = 0x09; // bits 0 and 3

    const delta = (try interp.processReport(0, &raw)) orelse return error.NoMatch;
    const btns = delta.buttons orelse return error.NoBtns;
    try testing.expect(btns & btnMask(.A) != 0);
    try testing.expect(btns & btnMask(.Y) != 0);

    // Mapper: A→B, Y→KEY_F1
    var ctx = try makeMapper(
        \\[remap]
        \\A = "B"
        \\Y = "KEY_F1"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    const ev = try m.apply(delta, 16);
    // A suppressed, B injected
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.A));
    try testing.expect((ev.gamepad.buttons & btnMask(.B)) != 0);
    // Y suppressed, KEY_F1 in aux
    try testing.expectEqual(@as(u64, 0), ev.gamepad.buttons & btnMask(.Y));
    var found_f1 = false;
    for (ev.aux.slice()) |e| {
        switch (e) {
            .key => |k| if (k.code == helpers.KEY_F1 and k.pressed) {
                found_f1 = true;
            },
            else => {},
        }
    }
    try testing.expect(found_f1);
}

// --- D2. E2E PRNG fuzz: random raw → interpreter → mapper never crashes ---

test "e2e pipeline: random packets through full pipeline — no crash" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xE2EF_0022);
    const rng = prng.random();

    const parsed = device_mod.parseString(allocator, vader5_toml) catch return;
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var ctx = try makeMapper(
        \\[remap]
        \\A = "KEY_F13"
        \\B = "mouse_left"
        \\X = "Y"
    , allocator);
    defer ctx.deinit();
    var m = &ctx.mapper;

    for (0..1000) |_| {
        var raw: [32]u8 = undefined;
        rng.bytes(&raw);
        // Force match bytes so processReport finds the report
        raw[0] = 0x5a;
        raw[1] = 0xa5;
        raw[2] = 0xef;

        const delta = (interp.processReport(1, &raw) catch continue) orelse continue;
        _ = try m.apply(delta, 16);
    }
}

// --- Embedded TOML configs (minimal versions for comptime fuzz) ---

const vader5_toml =
    \\[device]
    \\name = "Vader 5 PBT"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
    \\[[report]]
    \\name = "extended"
    \\interface = 1
    \\size = 32
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\[report.fields]
    \\left_x  = { offset = 3,  type = "i16le" }
    \\left_y  = { offset = 5,  type = "i16le", transform = "negate" }
    \\right_x = { offset = 7,  type = "i16le" }
    \\right_y = { offset = 9,  type = "i16le", transform = "negate" }
    \\lt      = { offset = 15, type = "u8" }
    \\rt      = { offset = 16, type = "u8" }
    \\[report.button_group]
    \\source = { offset = 11, size = 4 }
    \\map = { A = 4, B = 5, X = 7, Y = 8, LB = 10, RB = 11, Select = 6, Start = 9, LS = 14, RS = 15, Home = 27 }
;

const dualsense_toml =
    \\[device]
    \\name = "DualSense PBT"
    \\vid = 0x054c
    \\pid = 0x0ce6
    \\[[device.interface]]
    \\id = 3
    \\class = "hid"
    \\[[report]]
    \\name = "usb"
    \\interface = 3
    \\size = 64
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x  = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
    \\left_y  = { offset = 2, type = "u8", transform = "scale(-32768, 32767), negate" }
    \\lt      = { offset = 5, type = "u8" }
    \\rt      = { offset = 6, type = "u8" }
    \\gyro_x  = { offset = 16, type = "i16le" }
    \\gyro_y  = { offset = 18, type = "i16le" }
    \\gyro_z  = { offset = 20, type = "i16le" }
    \\[report.button_group]
    \\source = { offset = 8, size = 3 }
    \\map = { X = 4, A = 5, B = 6, Y = 7, LB = 8, RB = 9, LT = 10, RT = 11, Select = 12, Start = 13, LS = 14, RS = 15, Home = 16, TouchPad = 17, Mic = 18 }
;

const switch_pro_toml =
    \\[device]
    \\name = "Switch Pro PBT"
    \\vid = 0x057e
    \\pid = 0x2009
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "bt_standard"
    \\interface = 0
    \\size = 49
    \\[report.match]
    \\offset = 0
    \\expect = [0x30]
    \\[report.button_group]
    \\source = { offset = 3, size = 3 }
    \\map = { Y = 0, X = 1, B = 2, A = 3, RB = 6, RT = 7, Select = 8, Start = 9, RS = 10, LS = 11, Home = 12, DPadDown = 16, DPadUp = 17, DPadRight = 18, DPadLeft = 19, LB = 22, LT = 23 }
;
