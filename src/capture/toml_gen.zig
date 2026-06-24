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

    // MatchConfig expresses only a single offset + contiguous expect run, so emit
    // the contiguous run from the first invariant byte; drop non-contiguous bytes.
    if (result.magic.len > 0) {
        const start: usize = result.magic[0].offset;
        var run_len: usize = 1;
        while (run_len < result.magic.len and
            @as(usize, result.magic[run_len].offset) == start + run_len) : (run_len += 1)
        {}
        try writer.writeAll("[report.match]\n");
        try writer.print("offset = {d}\n", .{result.magic[0].offset});
        try writer.writeAll("expect = [");
        for (result.magic[0..run_len], 0..) |m, i| {
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

    // button_group section — the interpreter reads `size` bytes from `offset` and
    // treats each map bit index as group-global, so encode the full byte span and
    // re-base each button's bit to (byte - min_byte)*8 + bit.
    {
        var min_byte: u16 = std.math.maxInt(u16);
        var max_byte: u16 = 0;
        var any = false;
        for (result.buttons) |btn| {
            if (!btn.high_confidence) continue;
            any = true;
            min_byte = @min(min_byte, btn.byte_offset);
            max_byte = @max(max_byte, btn.byte_offset);
        }
        if (any) {
            try writer.writeAll("[report.button_group]\n");
            try writer.print("source = {{ offset = {d}, size = {d} }}\n", .{ min_byte, max_byte - min_byte + 1 });
            try writer.writeAll("map = {");
            var first_entry = true;
            for (result.buttons) |btn| {
                if (!btn.high_confidence) continue;
                if (!first_entry) try writer.writeAll(", ");
                const global_bit = (@as(u16, btn.byte_offset) - min_byte) * 8 + btn.bit;
                try writer.print(" btn_{d}_{d} = {d}", .{ btn.byte_offset, btn.bit, global_bit });
                first_entry = false;
            }
            try writer.writeAll(" }\n\n");
        }
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
