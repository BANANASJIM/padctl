const std = @import("std");
const posix = std.posix;
const paths = @import("../../config/paths.zig");

fn daemonRunning() bool {
    const data = std.fs.cwd().readFileAlloc(std.heap.page_allocator, "/run/padctl.pid", 64) catch return false;
    defer std.heap.page_allocator.free(data);
    const trimmed = std.mem.trim(u8, data, " \n\r\t");
    const pid = std.fmt.parseInt(std.posix.pid_t, trimmed, 10) catch return false;
    posix.kill(pid, 0) catch return false;
    return true;
}

fn listDir(_: std.mem.Allocator, w: anytype, dir_path: []const u8, label: []const u8) !void {
    var dir = if (std.fs.path.isAbsolute(dir_path))
        std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return
    else
        std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

    var found = false;
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
        if (!found) {
            try w.print("  [{s}] {s}\n", .{ label, dir_path });
            found = true;
        }
        try w.print("    {s}\n", .{entry.name});
    }
}

pub fn run(allocator: std.mem.Allocator) !void {
    const running = daemonRunning();

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    if (running) {
        try w.writeAll("Daemon: running [active]\n\n");
    } else {
        try w.writeAll("Daemon: not running\n\n");
    }

    const dev_dirs = try paths.resolveDeviceConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dev_dirs);

    const map_dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, map_dirs);

    try w.writeAll("Devices:\n");
    const dev_labels = [_][]const u8{ "user", "system", "builtin" };
    for (dev_dirs, dev_labels) |d, lbl| {
        try listDir(allocator, w, d, lbl);
    }

    try w.writeAll("\nMappings:\n");
    const map_labels = [_][]const u8{ "user", "system", "builtin" };
    for (map_dirs, map_labels) |d, lbl| {
        try listDir(allocator, w, d, lbl);
    }

    _ = posix.write(posix.STDOUT_FILENO, out.items) catch 0;
}

// --- tests ---

test "list: smoke (no panic on empty dirs)" {
    const allocator = std.testing.allocator;
    // Just ensure run() doesn't crash with empty/nonexistent XDG dirs.
    // We can't assert output without mocking, but no panic = pass.
    run(allocator) catch {};
}
