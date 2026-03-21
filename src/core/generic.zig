const std = @import("std");
const interpreter = @import("interpreter.zig");
const device = @import("../config/device.zig");
const input_codes = @import("../config/input_codes.zig");

pub const MAX_GENERIC_FIELDS = 32;

pub const GenericFieldSlot = struct {
    event_type: u16 = 0,
    event_code: u16 = 0,
    range_min: i32 = 0,
    range_max: i32 = 1,
    is_button: bool = false,
    mode: enum { standard, bits } = .standard,
    type_tag: interpreter.FieldType = .u8,
    offset: usize = 0,
    byte_offset: u16 = 0,
    start_bit: u3 = 0,
    bit_count: u6 = 0,
    is_signed: bool = false,
    transforms: interpreter.CompiledTransformChain = .{ .type_tag = .u8 },
    has_transform: bool = false,
};

pub const GenericDeviceState = struct {
    slots: [MAX_GENERIC_FIELDS]GenericFieldSlot = [_]GenericFieldSlot{.{}} ** MAX_GENERIC_FIELDS,
    values: [MAX_GENERIC_FIELDS]i32 = [_]i32{0} ** MAX_GENERIC_FIELDS,
    prev_values: [MAX_GENERIC_FIELDS]i32 = [_]i32{0} ** MAX_GENERIC_FIELDS,
    count: u8 = 0,
};

fn fieldTypeSize(t: interpreter.FieldType) usize {
    return switch (t) {
        .u8, .i8 => 1,
        .u16le, .i16le, .u16be, .i16be => 2,
        .u32le, .i32le, .u32be, .i32be => 4,
    };
}

pub fn extractGenericFields(state: *GenericDeviceState, raw: []const u8) void {
    for (state.slots[0..state.count], 0..state.count) |*slot, i| {
        const needed: usize = switch (slot.mode) {
            .standard => slot.offset + fieldTypeSize(slot.type_tag),
            .bits => @as(usize, slot.byte_offset) + (@as(usize, slot.start_bit) + @as(usize, slot.bit_count) + 7) / 8,
        };
        if (needed > raw.len) continue;

        var val: i64 = switch (slot.mode) {
            .standard => interpreter.readFieldByTag(raw, slot.offset, slot.type_tag),
            .bits => blk: {
                const raw_val = interpreter.extractBits(raw, slot.byte_offset, slot.start_bit, slot.bit_count);
                break :blk if (slot.is_signed) @as(i64, interpreter.signExtend(raw_val, slot.bit_count)) else @as(i64, raw_val);
            },
        };
        if (slot.has_transform) val = interpreter.runTransformChain(val, &slot.transforms);
        state.values[i] = if (slot.is_button)
            @intFromBool(val != 0)
        else
            @intCast(std.math.clamp(val, @as(i64, slot.range_min), @as(i64, slot.range_max)));
    }
}

pub fn compileGenericState(cfg: *const device.DeviceConfig) !GenericDeviceState {
    const mapping = cfg.output.?.mapping orelse return error.InvalidConfig;
    var state = GenericDeviceState{};
    var it = mapping.map.iterator();
    while (it.next()) |entry| {
        if (state.count >= MAX_GENERIC_FIELDS) break;
        const field_name = entry.key_ptr.*;
        const me = entry.value_ptr.*;

        const resolved = input_codes.resolveEventCode(me.event) catch return error.InvalidConfig;
        var slot = &state.slots[state.count];
        slot.event_type = resolved.event_type;
        slot.event_code = resolved.event_code;
        slot.is_button = (resolved.event_type == 0x01); // EV_KEY
        if (me.range) |r| {
            if (r.len >= 2) {
                slot.range_min = @intCast(r[0]);
                slot.range_max = @intCast(r[1]);
            }
        }

        // Find matching field in report configs
        var found = false;
        for (cfg.report) |report| {
            // Check fields
            if (report.fields) |fields| {
                if (fields.map.get(field_name)) |fc| {
                    if (fc.bits) |bits| {
                        slot.mode = .bits;
                        slot.byte_offset = @intCast(bits[0]);
                        slot.start_bit = @intCast(bits[1]);
                        slot.bit_count = @intCast(bits[2]);
                        slot.is_signed = if (fc.type) |t| std.mem.eql(u8, t, "signed") else false;
                    } else {
                        slot.mode = .standard;
                        const type_str = fc.type orelse continue;
                        slot.type_tag = interpreter.parseFieldType(type_str) orelse continue;
                        slot.offset = @intCast(fc.offset orelse continue);
                    }
                    if (fc.transform) |tr| {
                        slot.transforms = interpreter.compileTransformChain(tr, slot.type_tag);
                        slot.has_transform = true;
                    }
                    found = true;
                    break;
                }
            }
            // Check button_group
            if (report.button_group) |bg| {
                if (bg.map.map.get(field_name)) |bit_idx| {
                    slot.mode = .bits;
                    slot.byte_offset = @intCast(bg.source.offset);
                    slot.start_bit = @intCast(bit_idx);
                    slot.bit_count = 1;
                    slot.is_signed = false;
                    slot.is_button = true;
                    found = true;
                    break;
                }
            }
        }
        if (!found) return error.InvalidConfig;
        state.count += 1;
    }
    return state;
}

// --- tests ---

const testing = std.testing;

test "extractGenericFields: axis extraction with standard mode" {
    var state = GenericDeviceState{};
    state.count = 2;

    // Slot 0: u8 at offset 0, range [0, 255]
    state.slots[0] = .{
        .mode = .standard,
        .type_tag = .u8,
        .offset = 0,
        .range_min = 0,
        .range_max = 255,
    };
    // Slot 1: i16le at offset 1, range [-32768, 32767]
    state.slots[1] = .{
        .mode = .standard,
        .type_tag = .i16le,
        .offset = 1,
        .range_min = -32768,
        .range_max = 32767,
    };

    var raw = [_]u8{ 200, 0xe8, 0x03 }; // 200, 1000 in i16le
    extractGenericFields(&state, &raw);

    try testing.expectEqual(@as(i32, 200), state.values[0]);
    try testing.expectEqual(@as(i32, 1000), state.values[1]);
}

test "extractGenericFields: button produces 0/1" {
    var state = GenericDeviceState{};
    state.count = 1;
    state.slots[0] = .{
        .is_button = true,
        .mode = .standard,
        .type_tag = .u8,
        .offset = 0,
        .range_min = 0,
        .range_max = 1,
    };

    // Non-zero value -> 1
    var raw = [_]u8{42};
    extractGenericFields(&state, &raw);
    try testing.expectEqual(@as(i32, 1), state.values[0]);

    // Zero value -> 0
    raw[0] = 0;
    extractGenericFields(&state, &raw);
    try testing.expectEqual(@as(i32, 0), state.values[0]);
}

test "extractGenericFields: axis clamps to range" {
    var state = GenericDeviceState{};
    state.count = 1;
    state.slots[0] = .{
        .mode = .standard,
        .type_tag = .u8,
        .offset = 0,
        .range_min = 0,
        .range_max = 100,
    };

    var raw = [_]u8{200}; // exceeds range_max
    extractGenericFields(&state, &raw);
    try testing.expectEqual(@as(i32, 100), state.values[0]);
}

test "extractGenericFields: bits mode extraction" {
    var state = GenericDeviceState{};
    state.count = 1;
    state.slots[0] = .{
        .is_button = true,
        .mode = .bits,
        .byte_offset = 0,
        .start_bit = 2,
        .bit_count = 1,
        .range_min = 0,
        .range_max = 1,
    };

    // bit 2 is set
    var raw = [_]u8{0x04};
    extractGenericFields(&state, &raw);
    try testing.expectEqual(@as(i32, 1), state.values[0]);

    // bit 2 is clear
    raw[0] = 0x00;
    extractGenericFields(&state, &raw);
    try testing.expectEqual(@as(i32, 0), state.values[0]);
}

test "compileGenericState: compiles from config" {
    const allocator = testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Test Wheel"
        \\vid = 0x044f
        \\pid = 0xb66e
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel_angle = { offset = 0, type = "i16le" }
        \\gas_pedal = { offset = 2, type = "u8" }
        \\[report.button_group]
        \\source = { offset = 4, size = 1 }
        \\map = { gear_up = 0, gear_down = 1 }
        \\[output]
        \\name = "Test Wheel"
        \\vid = 0x044f
        \\pid = 0xb66e
        \\[output.mapping]
        \\wheel_angle = { event = "ABS_WHEEL", range = [-32768, 32767] }
        \\gas_pedal = { event = "ABS_GAS", range = [0, 255] }
        \\gear_up = { event = "BTN_GEAR_UP" }
        \\gear_down = { event = "BTN_GEAR_DOWN" }
    ;
    const parsed = try device.parseString(allocator, toml_str);
    defer parsed.deinit();

    const gs = try compileGenericState(&parsed.value);
    try testing.expectEqual(@as(u8, 4), gs.count);
}
