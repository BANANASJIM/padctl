const std = @import("std");
const posix = std.posix;
const paths = @import("../../config/paths.zig");
const socket_client = @import("../socket_client.zig");

/// Probe whether the daemon is running by attempting to connect to the IPC
/// socket. Uses the same `resolveSocketPath()` as every other client, so a
/// user-scope daemon (XDG_RUNTIME_DIR/padctl.sock) is detected correctly.
///
/// Previous implementation probed `/run/padctl.pid` which (a) is only written
/// when `--pid-file` is explicitly passed (never true in the installed user
/// systemd unit), and (b) lives in a path that a user-scope daemon has no
/// permission to write — so the status line always reported "Daemon: not
/// running" even when the daemon was healthy (Sleaker 2026-04-20).
fn daemonRunning() bool {
    var buf: [256]u8 = undefined;
    const path = socket_client.resolveSocketPath(&buf);
    // `access` check first — cheap short-circuit when no socket at all.
    std.fs.accessAbsolute(path, .{}) catch return false;
    // Probe: full connect() round-trip. AF_UNIX connect fails with
    // ECONNREFUSED when the socket file exists but nothing is listening
    // (e.g. stale socket from a crashed previous daemon).
    const fd = socket_client.connectToSocket(path) catch return false;
    posix.close(fd);
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
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".toml")) {
            if (!found) {
                try w.print("  [{s}] {s}\n", .{ label, dir_path });
                found = true;
            }
            try w.print("    {s}\n", .{entry.name});
        } else if (entry.kind == .directory) {
            var sub = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
            defer sub.close();
            var sub_it = sub.iterate();
            while (try sub_it.next()) |sub_entry| {
                if (sub_entry.kind != .file) continue;
                if (!std.mem.endsWith(u8, sub_entry.name, ".toml")) continue;
                if (!found) {
                    try w.print("  [{s}] {s}\n", .{ label, dir_path });
                    found = true;
                }
                try w.print("    {s}/{s}\n", .{ entry.name, sub_entry.name });
            }
        }
    }
}

pub fn run(allocator: std.mem.Allocator, writer: anytype) !void {
    const running = daemonRunning();

    if (running) {
        try writer.writeAll("Daemon: running [active]\n\n");
    } else {
        try writer.writeAll("Daemon: not running\n\n");
    }

    const dev_dirs = try paths.resolveDeviceConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dev_dirs);

    const map_dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, map_dirs);

    try writer.writeAll("Devices:\n");
    const dev_labels = [_][]const u8{ "user", "system", "builtin" };
    for (dev_dirs, dev_labels) |d, lbl| {
        try listDir(allocator, writer, d, lbl);
    }

    try writer.writeAll("\nMappings:\n");
    const map_labels = [_][]const u8{ "user", "system", "builtin" };
    for (map_dirs, map_labels) |d, lbl| {
        try listDir(allocator, writer, d, lbl);
    }
}

// --- tests ---

test "list: smoke (no panic on empty dirs)" {
    const allocator = std.testing.allocator;
    run(allocator, std.io.null_writer) catch {};
}
