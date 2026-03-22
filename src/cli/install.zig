const std = @import("std");

const service_content =
    \\[Unit]
    \\Description=padctl gamepad compatibility daemon
    \\After=local-fs.target
    \\
    \\[Service]
    \\Type=simple
    \\ExecStart=/usr/bin/padctl --config-dir /usr/share/padctl/devices/ --pid-file /run/padctl.pid
    \\PIDFile=/run/padctl.pid
    \\Restart=on-failure
    \\RestartSec=3
    \\
    \\[Install]
    \\WantedBy=multi-user.target
    \\
;

pub const InstallOptions = struct {
    prefix: []const u8 = "/usr",
    destdir: []const u8 = "",
};

fn ensureDir(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

fn ensureDirAll(allocator: std.mem.Allocator, path: []const u8) !void {
    // Collect path components top-down then create bottom-up
    var components = std.ArrayList([]const u8){};
    defer components.deinit(allocator);

    var remaining = path;
    while (remaining.len > 1) {
        try components.append(allocator, remaining);
        remaining = std.fs.path.dirname(remaining) orelse break;
    }

    var i: usize = components.items.len;
    while (i > 0) {
        i -= 1;
        ensureDir(components.items[i]) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

fn copyFile(src: []const u8, dst: []const u8) !void {
    var src_file = try std.fs.openFileAbsolute(src, .{});
    defer src_file.close();
    const stat = try src_file.stat();
    var dst_file = try std.fs.createFileAbsolute(dst, .{ .truncate = true });
    defer dst_file.close();
    try dst_file.chmod(stat.mode & 0o777);
    var buf: [65536]u8 = undefined;
    while (true) {
        const n = try src_file.read(&buf);
        if (n == 0) break;
        try dst_file.writeAll(buf[0..n]);
    }
}

fn runCmd(argv: []const []const u8) void {
    var child = std.process.Child.init(argv, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawnAndWait() catch {};
}

pub fn run(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    if (std.os.linux.getuid() != 0) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: must run as root — use: sudo padctl install\n") catch {};
        std.process.exit(1);
    }

    const destdir = opts.destdir;
    const prefix = opts.prefix;

    const bin_dir = try std.fmt.allocPrint(allocator, "{s}{s}/bin", .{ destdir, prefix });
    defer allocator.free(bin_dir);
    const lib_systemd_dir = try std.fmt.allocPrint(allocator, "{s}{s}/lib/systemd/system", .{ destdir, prefix });
    defer allocator.free(lib_systemd_dir);
    const share_dir = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl/devices", .{ destdir, prefix });
    defer allocator.free(share_dir);
    const udev_dir = try std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d", .{ destdir, prefix });
    defer allocator.free(udev_dir);

    try ensureDirAll(allocator, bin_dir);
    try ensureDirAll(allocator, lib_systemd_dir);
    try ensureDirAll(allocator, share_dir);
    try ensureDirAll(allocator, udev_dir);

    const self_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_path);
    const self_dir = std.fs.path.dirname(self_path) orelse ".";

    // 1. Copy binaries
    const bin_padctl = try std.fmt.allocPrint(allocator, "{s}/padctl", .{bin_dir});
    defer allocator.free(bin_padctl);
    try copyFile(self_path, bin_padctl);
    try std.posix.fchmodat(std.fs.cwd().fd, bin_padctl, 0o755, 0);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, bin_padctl) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    for ([_][]const u8{ "padctl-capture", "padctl-debug" }) |name| {
        const src = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self_dir, name });
        defer allocator.free(src);
        const dst = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ bin_dir, name });
        defer allocator.free(dst);
        copyFile(src, dst) catch continue;
        std.posix.fchmodat(std.fs.cwd().fd, dst, 0o755, 0) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, dst) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // 2. Write embedded service file
    const service_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{lib_systemd_dir});
    defer allocator.free(service_path);
    {
        var f = try std.fs.createFileAbsolute(service_path, .{ .truncate = true });
        defer f.close();
        try f.writeAll(service_content);
    }
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, service_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    // 3. Copy devices/*.toml
    const src_devices = try std.fmt.allocPrint(allocator, "{s}/devices", .{self_dir});
    defer allocator.free(src_devices);
    copyDevicesTomls(allocator, src_devices, share_dir) catch {};

    // 4. Generate 99-padctl.rules
    const rules_path = try std.fmt.allocPrint(allocator, "{s}/99-padctl.rules", .{udev_dir});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, share_dir, rules_path);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, rules_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    // 5. Reload system daemons only when not staging
    if (destdir.len == 0) {
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nReloading system daemons...\n") catch {};
        runCmd(&.{ "systemctl", "daemon-reload" });
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
        runCmd(&.{ "udevadm", "trigger" });
    }

    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete.\n") catch {};
}

fn copyDevicesTomls(allocator: std.mem.Allocator, src_dir: []const u8, dst_dir: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(src_dir, .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;

        const rel = entry.path;
        const rel_dir = std.fs.path.dirname(rel);

        const dst_subdir = if (rel_dir) |d|
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dst_dir, d })
        else
            try allocator.dupe(u8, dst_dir);
        defer allocator.free(dst_subdir);

        try ensureDirAll(allocator, dst_subdir);

        const src_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ src_dir, rel });
        defer allocator.free(src_path);
        const dst_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dst_dir, rel });
        defer allocator.free(dst_path);

        try copyFile(src_path, dst_path);
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, dst_path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }
}

const UdevEntry = struct {
    name: []const u8,
    vid: u16,
    pid: u16,
};

fn generateUdevRules(allocator: std.mem.Allocator, devices_dir: []const u8, rules_path: []const u8) !void {
    var entries = std.ArrayList(UdevEntry){};
    defer {
        for (entries.items) |e| allocator.free(e.name);
        entries.deinit(allocator);
    }

    var dir = std.fs.openDirAbsolute(devices_dir, .{ .iterate = true }) catch return;
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;

        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ devices_dir, entry.path });
        defer allocator.free(path);

        extractVidPid(allocator, path, &entries) catch continue;
    }

    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — do not edit\n");
    for (entries.items) |e| {
        const line = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"hidraw\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", TAG+=\"systemd\", ENV{{SYSTEMD_WANTS}}=\"padctl.service\", TAG+=\"uaccess\"\n# {s}\n",
            .{ e.vid, e.pid, e.name },
        );
        defer allocator.free(line);
        try buf.appendSlice(allocator, line);
    }

    try buf.appendSlice(allocator, "\n# uinput access for logged-in users\n");
    try buf.appendSlice(allocator, "SUBSYSTEM==\"misc\", KERNEL==\"uinput\", TAG+=\"uaccess\"\n");

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

fn extractVidPid(allocator: std.mem.Allocator, path: []const u8, entries: *std.ArrayList(UdevEntry)) !void {
    var f = try std.fs.openFileAbsolute(path, .{});
    defer f.close();
    const content = try f.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(content);

    var name_buf: [256]u8 = undefined;
    var name: []const u8 = std.fs.path.stem(path);
    var vid: ?u16 = null;
    var pid: ?u16 = null;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "name")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t\"");
                const n = @min(val.len, name_buf.len - 1);
                @memcpy(name_buf[0..n], val[0..n]);
                name = name_buf[0..n];
            }
        } else if (std.mem.startsWith(u8, trimmed, "vid")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t#");
                vid = parseHexOrDec(u16, val) catch continue;
            }
        } else if (std.mem.startsWith(u8, trimmed, "pid")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t#");
                pid = parseHexOrDec(u16, val) catch continue;
            }
        }
    }

    if (vid != null and pid != null) {
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .vid = vid.?,
            .pid = pid.?,
        });
    }
}

fn parseHexOrDec(comptime T: type, s: []const u8) !T {
    const trimmed = std.mem.trim(u8, s, " \t\r");
    if (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X")) {
        return std.fmt.parseInt(T, trimmed[2..], 16);
    }
    return std.fmt.parseInt(T, trimmed, 10);
}

// --- tests ---

test "parseHexOrDec" {
    const testing = std.testing;
    try testing.expectEqual(@as(u16, 0x37d7), try parseHexOrDec(u16, "0x37d7"));
    try testing.expectEqual(@as(u16, 1234), try parseHexOrDec(u16, "1234"));
    try testing.expectEqual(@as(u16, 0x054c), try parseHexOrDec(u16, "0x054c"));
}

test "extractVidPid from vader5 content" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const toml_content =
        \\[device]
        \\name = "Flydigi Vader 5 Pro"
        \\vid = 0x37d7
        \\pid = 0x2401
    ;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test.toml", .{tmp_path});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(toml_content);
    }

    var entries = std.ArrayList(UdevEntry){};
    defer {
        for (entries.items) |e| allocator.free(e.name);
        entries.deinit(allocator);
    }
    try extractVidPid(allocator, toml_path, &entries);

    try testing.expectEqual(@as(usize, 1), entries.items.len);
    try testing.expectEqual(@as(u16, 0x37d7), entries.items[0].vid);
    try testing.expectEqual(@as(u16, 0x2401), entries.items[0].pid);
    try testing.expectEqualStrings("Flydigi Vader 5 Pro", entries.items[0].name);
}

test "generateUdevRules produces valid output" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/vader5.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(
            \\[device]
            \\name = "Flydigi Vader 5 Pro"
            \\vid = 0x37d7
            \\pid = 0x2401
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/99-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path);

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "37d7") != null);
    try testing.expect(std.mem.indexOf(u8, content, "2401") != null);
    try testing.expect(std.mem.indexOf(u8, content, "SUBSYSTEM==\"hidraw\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "TAG+=\"uaccess\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uinput\"") != null);
}
