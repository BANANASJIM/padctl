const std = @import("std");
const analyse = @import("analyse");

fn writeTomlString(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '"' => try writer.writeAll("\\\""),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => try writer.print("\\u00{x:0>2}", .{c}),
            else => try writer.writeByte(c),
        }
    }
}

pub const DeviceInfo = struct {
    name: []const u8,
    vid: u16,
    pid: u16,
    interface_id: u8,
};

pub fn emitToml(result: analyse.AnalysisResult, info: DeviceInfo, allocator: std.mem.Allocator, writer: anytype) !void {
    try writer.writeAll("[device]\nname = \"");
    try writeTomlString(writer, info.name);
    try writer.print(
        \\"
        \\vid = 0x{x:0>4}
        \\pid = 0x{x:0>4}
        \\
        \\[[device.interface]]
        \\id = {d}
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = {d}
        \\size = {d}
        \\
    ,
        .{ info.vid, info.pid, info.interface_id, info.interface_id, result.report_size },
    );

    // match section if we have magic bytes
    if (result.magic.len > 0) {
        try writer.writeAll("[report.match]\n");
        try writer.print("offset = {d}\n", .{result.magic[0].offset});
        try writer.writeAll("expect = [");
        for (result.magic, 0..) |m, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("0x{x:0>2}", .{m.value});
        }
        try writer.writeAll("]\n\n");
    }

    // fields section for axes
    if (result.axes.len > 0) {
        try writer.writeAll("[report.fields]\n");
        for (result.axes, 0..) |ax, i| {
            switch (ax.axis_type) {
                .i16le => try writer.print(
                    "axis_{d} = {{ offset = {d}, type = \"i16le\" }}\n",
                    .{ i, ax.offset },
                ),
                .u8_axis => try writer.print(
                    "axis_{d} = {{ offset = {d}, type = \"u8\" }}\n",
                    .{ i, ax.offset },
                ),
            }
        }
        try writer.writeAll("\n");
    }

    // button_group section
    if (result.buttons.len > 0) {
        // group consecutive high-confidence bits by byte
        const first = result.buttons[0];
        try writer.writeAll("[report.button_group]\n");
        try writer.print("source = {{ offset = {d}, size = 1 }}\n", .{first.byte_offset});
        try writer.writeAll("map = {");
        var first_entry = true;
        for (result.buttons) |btn| {
            if (!btn.high_confidence) continue;
            if (!first_entry) try writer.writeAll(", ");
            try writer.print(" btn_{d}_{d} = {d}", .{ btn.byte_offset, btn.bit, btn.bit });
            first_entry = false;
        }
        try writer.writeAll(" }\n\n");
    }

    // unknown bytes comment
    const size: usize = result.report_size;
    var covered = try allocator.alloc(bool, size);
    defer allocator.free(covered);
    @memset(covered, false);

    for (result.magic) |m| {
        if (m.offset < size) covered[m.offset] = true;
    }
    for (result.axes) |ax| {
        if (ax.offset < size) covered[ax.offset] = true;
        if (ax.axis_type == .i16le and ax.offset + 1 < size) covered[ax.offset + 1] = true;
    }
    for (result.buttons) |btn| {
        if (btn.byte_offset < size) covered[btn.byte_offset] = true;
    }

    for (0..size) |b| {
        if (!covered[b]) try writer.print("# unknown: offset {d}\n", .{b});
    }
}

// --- tests ---

const testing = std.testing;
const MagicByte = analyse.MagicByte;
const ButtonCandidate = analyse.ButtonCandidate;
const AxisCandidate = analyse.AxisCandidate;
const AnalysisResult = analyse.AnalysisResult;

fn emitToString(result: AnalysisResult, info: DeviceInfo) ![]u8 {
    const allocator = testing.allocator;
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();
    try emitToml(result, info, allocator, buf.writer());
    return buf.toOwnedSlice();
}

const test_info = DeviceInfo{ .name = "Test Pad", .vid = 0x045e, .pid = 0x028e, .interface_id = 0 };

test "emitToml: empty result — has [device] and [[report]], no fields" {
    const result = AnalysisResult{
        .report_size = 4,
        .magic = &.{},
        .buttons = &.{},
        .axes = &.{},
    };
    const out = try emitToString(result, test_info);
    defer testing.allocator.free(out);

    try testing.expect(std.mem.indexOf(u8, out, "[device]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[[report]]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.fields]") == null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.button_group]") == null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.match]") == null);
}

test "emitToml: magic-only — [report.match] with hex values" {
    var magic = [_]MagicByte{
        .{ .offset = 0, .value = 0x5a },
        .{ .offset = 1, .value = 0xa5 },
    };
    const result = AnalysisResult{
        .report_size = 4,
        .magic = &magic,
        .buttons = &.{},
        .axes = &.{},
    };
    const out = try emitToString(result, test_info);
    defer testing.allocator.free(out);

    try testing.expect(std.mem.indexOf(u8, out, "[report.match]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "0x5a") != null);
    try testing.expect(std.mem.indexOf(u8, out, "0xa5") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.fields]") == null);
}

test "emitToml: axes + buttons — fields and button_group present" {
    var axes = [_]AxisCandidate{
        .{ .offset = 3, .axis_type = .i16le, .min_val = -32000, .max_val = 32000 },
        .{ .offset = 8, .axis_type = .u8_axis, .min_val = 0, .max_val = 255 },
    };
    var buttons = [_]ButtonCandidate{
        .{ .byte_offset = 11, .bit = 3, .toggle_count = 8, .high_confidence = true },
        .{ .byte_offset = 11, .bit = 5, .toggle_count = 6, .high_confidence = true },
    };
    const result = AnalysisResult{
        .report_size = 16,
        .magic = &.{},
        .buttons = &buttons,
        .axes = &axes,
    };
    const out = try emitToString(result, test_info);
    defer testing.allocator.free(out);

    try testing.expect(std.mem.indexOf(u8, out, "[report.fields]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "i16le") != null);
    try testing.expect(std.mem.indexOf(u8, out, "[report.button_group]") != null);
    try testing.expect(std.mem.indexOf(u8, out, "btn_11_3") != null);
    try testing.expect(std.mem.indexOf(u8, out, "btn_11_5") != null);
}

test "emitToml: device name with quote/backslash/newline — toml string injection prevented" {
    const result = AnalysisResult{
        .report_size = 2,
        .magic = &.{},
        .buttons = &.{},
        .axes = &.{},
    };
    const info = DeviceInfo{ .name = "Pad \"Evil\"\nback\\slash", .vid = 0x1234, .pid = 0x5678, .interface_id = 0 };
    const out = try emitToString(result, info);
    defer testing.allocator.free(out);

    const expected_name_line = "name = \"Pad \\\"Evil\\\"\\nback\\\\slash\"";
    try testing.expect(std.mem.indexOf(u8, out, expected_name_line) != null);
}

test "emitToml: single u8 axis — type string correct" {
    var axes = [_]AxisCandidate{
        .{ .offset = 2, .axis_type = .u8_axis, .min_val = 10, .max_val = 200 },
    };
    const result = AnalysisResult{
        .report_size = 4,
        .magic = &.{},
        .buttons = &.{},
        .axes = &axes,
    };
    const out = try emitToString(result, test_info);
    defer testing.allocator.free(out);

    try testing.expect(std.mem.indexOf(u8, out, "\"u8\"") != null);
    try testing.expect(std.mem.indexOf(u8, out, "axis_0") != null);
    try testing.expect(std.mem.indexOf(u8, out, "i16le") == null);
}
