const std = @import("std");
const config = @import("../config/device.zig");
const interpreter = @import("../core/interpreter.zig");
const state = @import("../core/state.zig");
const docgen = @import("../tools/docgen.zig");
const testing = std.testing;

fn load() !config.ParseResult {
    return config.parseFile(testing.allocator, "devices/razer/wolverine-v3-pro-pc.toml");
}

// Independent Xbox 360 field-position/mask oracle: Linux xpad360_process_packet at
// paroj/xpad@3e79f00201178e5364e3bcd205e10411c5bc6501 (PR #324).
// These are constructed protocol vectors, not captures from Razer hardware.
test "Razer PC: production config decodes signed sticks and independent triggers" {
    var parsed = try load();
    defer parsed.deinit();
    try testing.expectEqual(@as(i64, 0x1532), parsed.value.device.vid);
    try testing.expectEqual(@as(i64, 0x0a4c), parsed.value.device.pid);
    const output = parsed.value.output.?;
    try testing.expectEqual(@as(i64, 0x045e), output.vid.?);
    try testing.expectEqual(@as(i64, 0x028e), output.pid.?);
    try testing.expectEqualStrings("BTN_NORTH", output.buttons.?.map.get("X").?);
    try testing.expectEqualStrings("BTN_WEST", output.buttons.?.map.get("Y").?);
    try testing.expect(output.force_feedback == null);
    try testing.expect(output.buttons.?.map.get("M1") == null);
    const iface = parsed.value.device.interface[0];
    try testing.expectEqualSlices(i64, &.{ 255, 93, 1 }, iface.usb_match.?);
    try testing.expect(iface.ep_in == null and iface.ep_out == null);
    var interp = interpreter.Interpreter.init(&parsed.value);
    const packet = [_]u8{ 0x00, 0x14, 0x00, 0x00, 0x23, 0xe1, 0x34, 0x12, 0x00, 0x80, 0x00, 0x80, 0xff, 0x7f, 0, 0, 0, 0, 0, 0 };
    const delta = (try interp.processReport(0, &packet)).?;
    try testing.expectEqual(@as(i16, 0x1234), delta.ax.?);
    try testing.expectEqual(@as(i16, 32767), delta.ay.?);
    try testing.expectEqual(@as(i16, -32768), delta.rx.?);
    try testing.expectEqual(@as(i16, -32767), delta.ry.?);
    try testing.expectEqual(@as(u8, 0x23), delta.lt.?);
    try testing.expectEqual(@as(u8, 0xe1), delta.rt.?);
    var ramp = packet;
    for (0..256) |value| {
        ramp[4] = @intCast(value);
        const sample = (try interp.processReport(0, &ramp)).?;
        try testing.expectEqual(@as(u8, @intCast(value)), sample.lt.?);
        try testing.expectEqual(@as(u8, 0xe1), sample.rt.?);
    }
    ramp[4] = 0;
    for (0..256) |value| {
        ramp[5] = @intCast(value);
        const sample = (try interp.processReport(0, &ramp)).?;
        try testing.expectEqual(@as(u8, 0), sample.lt.?);
        try testing.expectEqual(@as(u8, @intCast(value)), sample.rt.?);
    }
}

test "Razer PC: all standard buttons and eight dpad directions match xpad wire masks" {
    var parsed = try load();
    defer parsed.deinit();
    var interp = interpreter.Interpreter.init(&parsed.value);
    const Entry = struct { byte: usize, mask: u8, button: state.ButtonId };
    const entries = [_]Entry{
        .{ .byte = 2, .mask = 0x10, .button = .Start }, .{ .byte = 2, .mask = 0x20, .button = .Select },
        .{ .byte = 2, .mask = 0x40, .button = .LS },    .{ .byte = 2, .mask = 0x80, .button = .RS },
        .{ .byte = 3, .mask = 0x01, .button = .LB },    .{ .byte = 3, .mask = 0x02, .button = .RB },
        .{ .byte = 3, .mask = 0x04, .button = .Home },  .{ .byte = 3, .mask = 0x10, .button = .A },
        .{ .byte = 3, .mask = 0x20, .button = .B },     .{ .byte = 3, .mask = 0x40, .button = .X },
        .{ .byte = 3, .mask = 0x80, .button = .Y },
    };
    var packet = [_]u8{0} ** 20;
    packet[1] = 0x14;
    for (entries) |entry| {
        packet[2] = 0;
        packet[3] = 0;
        packet[entry.byte] = entry.mask;
        const delta = (try interp.processReport(0, &packet)).?;
        try testing.expectEqual(@as(u64, 1) << @intFromEnum(entry.button), delta.buttons.?);
    }
    const Direction = struct { mask: u8, x: i8, y: i8 };
    const directions = [_]Direction{
        .{ .mask = 0, .x = 0, .y = 0 },  .{ .mask = 1, .x = 0, .y = -1 }, .{ .mask = 9, .x = 1, .y = -1 },
        .{ .mask = 8, .x = 1, .y = 0 },  .{ .mask = 10, .x = 1, .y = 1 }, .{ .mask = 2, .x = 0, .y = 1 },
        .{ .mask = 6, .x = -1, .y = 1 }, .{ .mask = 4, .x = -1, .y = 0 }, .{ .mask = 5, .x = -1, .y = -1 },
    };
    packet[3] = 0;
    for (directions) |direction| {
        packet[2] = direction.mask;
        const delta = (try interp.processReport(0, &packet)).?;
        var gamepad = state.GamepadState{};
        gamepad.applyDelta(delta);
        gamepad.synthesizeDpadAxes();
        try testing.expectEqual(direction.x, gamepad.dpad_x);
        try testing.expectEqual(direction.y, gamepad.dpad_y);
    }
    packet[2] = 0;
    packet[3] = 8; // Reserved wire bit must not become an extra button.
    try testing.expectEqual(@as(u64, 0), (try interp.processReport(0, &packet)).?.buttons.?);
}

test "Razer PC: wrong report identity, logical interface and short packets are ignored" {
    var parsed = try load();
    defer parsed.deinit();
    var interp = interpreter.Interpreter.init(&parsed.value);
    var packet = [_]u8{0} ** 20;
    packet[1] = 0x14;
    try testing.expect((try interp.processReport(1, &packet)) == null);
    for (0..20) |len| try testing.expect((try interp.processReport(0, packet[0..len])) == null);
    packet[0] = 0x20;
    try testing.expect((try interp.processReport(0, &packet)) == null);
    packet[0] = 0;
    packet[1] = 0x13;
    try testing.expect((try interp.processReport(0, &packet)) == null);
}

test "Razer PC: descriptor selector schema rejects unsupported and mixed declarations" {
    const source = try std.fs.cwd().readFileAlloc(testing.allocator, "devices/razer/wolverine-v3-pro-pc.toml", 65536);
    defer testing.allocator.free(source);
    const replacements = [_][]const u8{
        "usb_match = [255, 93]",                  "usb_match = [255, 93, 256]",              "usb_match = [255, -1, 1]",
        "usb_match = [255, 93, 1]\nep_in = 0x81", "usb_match = [255, 93, 1]\nep_out = 0x01",
    };
    for (replacements) |replacement| {
        const text = try std.mem.replaceOwned(u8, testing.allocator, source, "usb_match = [0xff, 0x5d, 0x01]", replacement);
        defer testing.allocator.free(text);
        try testing.expectError(error.InvalidConfig, config.parseString(testing.allocator, text));
    }
    for ([_][]const u8{ "hid", "suppress" }) |class| {
        const replacement = try std.fmt.allocPrint(testing.allocator, "class = \"{s}\"", .{class});
        defer testing.allocator.free(replacement);
        const text = try std.mem.replaceOwned(u8, testing.allocator, source, "class = \"vendor\"", replacement);
        defer testing.allocator.free(text);
        try testing.expectError(error.InvalidConfig, config.parseString(testing.allocator, text));
    }
}

test "Razer PC: generated reference explains logical descriptor routing" {
    var parsed = try load();
    defer parsed.deinit();
    var output: std.ArrayList(u8) = .{};
    defer output.deinit(testing.allocator);
    try docgen.generateDevicePage(&parsed.value, "razer", output.writer(testing.allocator));
    try testing.expect(std.mem.indexOf(u8, output.items, "Logical interface `0`") != null);
    try testing.expect(std.mem.indexOf(u8, output.items, "`0xff/0x5d/0x01`") != null);
    try testing.expect(std.mem.indexOf(u8, output.items, "Force Feedback") == null);
}
