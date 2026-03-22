const std = @import("std");
const mapping_discovery = @import("../config/mapping_discovery.zig");
const MappingProfile = mapping_discovery.MappingProfile;
const Source = mapping_discovery.Source;

fn padRight(buf: []u8, s: []const u8, width: usize) []const u8 {
    const len = @min(s.len, width);
    @memcpy(buf[0..len], s[0..len]);
    @memset(buf[len..width], ' ');
    return buf[0..width];
}

fn sourceLabel(source: Source) []const u8 {
    return switch (source) {
        .user => "user",
        .system => "system",
        .package => "package",
    };
}

pub fn run(allocator: std.mem.Allocator, extra_dir: ?[]const u8, writer: anytype) !void {
    const profiles = try mapping_discovery.discoverMappings(allocator);
    defer mapping_discovery.freeProfiles(allocator, profiles);

    if (profiles.len == 0 and extra_dir == null) {
        try writer.writeAll("No mapping profiles found.\n");
        return;
    }

    const name_w = 24;
    const source_w = 8;
    var pad: [name_w + source_w]u8 = undefined;

    try writer.print("{s} {s} {s}\n", .{
        padRight(pad[0..name_w], "NAME", name_w),
        padRight(pad[name_w..], "SOURCE", source_w),
        "PATH",
    });
    try writer.writeByteNTimes('-', name_w + 1 + source_w + 1 + 40);
    try writer.writeByte('\n');

    for (profiles) |p| {
        var row_pad: [name_w + source_w]u8 = undefined;
        try writer.print("{s} {s} {s}\n", .{
            padRight(row_pad[0..name_w], p.name, name_w),
            padRight(row_pad[name_w..], sourceLabel(p.source), source_w),
            p.path,
        });
    }

    if (extra_dir) |dir| {
        try writer.print("\nDevice mappings ({s}):\n", .{dir});
        var d = if (std.fs.path.isAbsolute(dir))
            std.fs.openDirAbsolute(dir, .{ .iterate = true }) catch {
                try writer.writeAll("  (directory not found)\n");
                return;
            }
        else
            std.fs.cwd().openDir(dir, .{ .iterate = true }) catch {
                try writer.writeAll("  (directory not found)\n");
                return;
            };
        defer d.close();

        var found = false;
        var it = d.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
            try writer.print("  {s}\n", .{entry.name});
            found = true;
        }
        if (!found) try writer.writeAll("  (none)\n");
    }

    try writer.print("\n{d} mapping(s) found.\n", .{profiles.len});
}

// --- tests ---

test "list_mappings: smoke (no panic)" {
    const allocator = std.testing.allocator;
    run(allocator, null, std.io.null_writer) catch {};
}
