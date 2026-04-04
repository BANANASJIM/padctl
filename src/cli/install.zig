const std = @import("std");
const paths = @import("../config/paths.zig");

fn generateServiceContent(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\[Unit]
        \\Description=padctl gamepad compatibility daemon
        \\After=local-fs.target
        \\
        \\[Service]
        \\Type=simple
        \\ExecStart={s}/bin/padctl
        \\Restart=on-failure
        \\RestartSec=3
        \\ProtectSystem=strict
        \\ProtectHome=true
        \\PrivateTmp=true
        \\RuntimeDirectory=padctl
        \\NoNewPrivileges=true
        \\SupplementaryGroups=input
        \\DeviceAllow=/dev/hidraw* rw
        \\DeviceAllow=/dev/uinput rw
        \\DeviceAllow=char-input rw
        \\
        \\[Install]
        \\WantedBy=multi-user.target
        \\
    , .{prefix});
}

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

fn dirExistsAbsolute(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

fn findDevicesSourceDir(allocator: std.mem.Allocator, self_dir: []const u8, cwd_override: ?[]const u8) !?[]u8 {
    const sibling = try std.fmt.allocPrint(allocator, "{s}/devices", .{self_dir});
    defer allocator.free(sibling);
    if (dirExistsAbsolute(sibling)) return try allocator.dupe(u8, sibling);

    var parent = self_dir;
    while (std.fs.path.dirname(parent)) |next| {
        parent = next;
        const candidate = try std.fmt.allocPrint(allocator, "{s}/devices", .{parent});
        defer allocator.free(candidate);
        if (dirExistsAbsolute(candidate)) return try allocator.dupe(u8, candidate);
        if (std.mem.eql(u8, parent, "/")) break;
    }

    const cwd = cwd_override orelse try std.process.getCwdAlloc(allocator);
    defer if (cwd_override == null) allocator.free(cwd);
    const cwd_candidate = try std.fmt.allocPrint(allocator, "{s}/devices", .{cwd});
    defer allocator.free(cwd_candidate);
    if (dirExistsAbsolute(cwd_candidate)) return try allocator.dupe(u8, cwd_candidate);

    return null;
}

pub fn run(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    if (opts.destdir.len == 0 and std.os.linux.getuid() != 0) {
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

    // 2. Write service file with correct prefix paths
    const service_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{lib_systemd_dir});
    defer allocator.free(service_path);
    const service_content = try generateServiceContent(allocator, prefix);
    defer allocator.free(service_content);
    {
        var f = try std.fs.createFileAbsolute(service_path, .{ .truncate = true });
        defer f.close();
        try f.writeAll(service_content);
    }
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, service_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    // 3. Copy devices/*.toml
    const src_devices = try findDevicesSourceDir(allocator, self_dir, null);
    defer if (src_devices) |path| allocator.free(path);
    if (src_devices) |path| {
        copyDevicesTomls(allocator, path, share_dir) catch |err| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "warning: device configs not installed: ") catch {};
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "{}\n", .{err}) catch "unknown error\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
        };
    } else {
        _ = std.posix.write(std.posix.STDERR_FILENO, "warning: device configs not installed: devices directory not found near executable or current working directory\n") catch {};
    }

    // 4. Generate 60-padctl.rules from all config dirs
    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{udev_dir});
    defer allocator.free(rules_path);
    const config_dirs = paths.resolveDeviceConfigDirs(allocator) catch null;
    defer if (config_dirs) |dirs| paths.freeConfigDirs(allocator, dirs);
    var all_dirs: std.ArrayList([]const u8) = .{};
    defer all_dirs.deinit(allocator);
    try all_dirs.append(allocator, share_dir);
    if (config_dirs) |dirs| {
        for (dirs) |d| try all_dirs.append(allocator, d);
    }
    try generateUdevRulesFromDirs(allocator, all_dirs.items, rules_path);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, rules_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    // 4b. Remove legacy 99-padctl.rules if present (renamed to 60- for correct priority)
    {
        const legacy = try std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d/99-padctl.rules", .{ destdir, prefix });
        defer allocator.free(legacy);
        std.fs.deleteFileAbsolute(legacy) catch {};
    }

    // 5. Reload system daemons only when not staging
    if (destdir.len == 0) {
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nReloading system daemons...\n") catch {};
        runCmd(&.{ "systemctl", "daemon-reload" });
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
        runCmd(&.{ "udevadm", "trigger" });
    }

    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete.\n") catch {};
}

pub fn uninstall(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    if (opts.destdir.len == 0 and std.os.linux.getuid() != 0) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: must run as root — use: sudo padctl uninstall\n") catch {};
        std.process.exit(1);
    }

    const prefix = opts.prefix;
    const destdir = opts.destdir;

    // Stop and disable the service (ignore errors — may not be running)
    if (destdir.len == 0) {
        runCmd(&.{ "systemctl", "stop", "padctl.service" });
        runCmd(&.{ "systemctl", "disable", "padctl.service" });
    }

    const files = [_][]const u8{
        "/bin/padctl",
        "/bin/padctl-capture",
        "/bin/padctl-debug",
        "/lib/systemd/system/padctl.service",
        "/lib/udev/rules.d/60-padctl.rules",
        "/lib/udev/rules.d/99-padctl.rules",
    };

    for (files) |suffix| {
        const path = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ destdir, prefix, suffix });
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch {
            continue;
        };
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // Remove share dir recursively
    const share_dir = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl", .{ destdir, prefix });
    defer allocator.free(share_dir);
    std.fs.deleteTreeAbsolute(share_dir) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, share_dir) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "/\n") catch {};

    // Remove runtime files
    std.fs.deleteFileAbsolute("/run/padctl/padctl.pid") catch {};
    std.fs.deleteFileAbsolute("/run/padctl/padctl.sock") catch {};

    if (destdir.len == 0) {
        runCmd(&.{ "systemctl", "daemon-reload" });
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
    }

    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nUninstall complete.\n") catch {};
}

// setupTestUdev writes a udev rule that grants world-read access to UHID virtual
// hidraw nodes and reloads udevd. Run once before test-e2e via:
//   sudo -n ./zig-out/bin/padctl setup-test-udev
pub fn setupTestUdev() void {
    const rule =
        \\KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="uhid", MODE="0666"
        \\SUBSYSTEM=="input", KERNEL=="event*", ATTRS{id/bustype}=="0006", MODE="0666"
        \\
    ;
    const path = "/etc/udev/rules.d/98-uhid-test.rules";
    if (std.fs.createFileAbsolute(path, .{ .truncate = true })) |f| {
        defer f.close();
        f.writeAll(rule) catch {};
    } else |_| {}
    runCmd(&.{ "udevadm", "control", "--reload-rules" });
}

fn copyDevicesTomls(allocator: std.mem.Allocator, src_dir: []const u8, dst_dir: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(src_dir, .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;
        if (std.mem.startsWith(u8, entry.path, "example/")) continue;

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

fn generateUdevRulesFromDirs(allocator: std.mem.Allocator, dirs: []const []const u8, rules_path: []const u8) !void {
    var entries = std.ArrayList(UdevEntry){};
    defer {
        for (entries.items) |e| allocator.free(e.name);
        entries.deinit(allocator);
    }

    for (dirs) |devices_dir| {
        var dir = std.fs.openDirAbsolute(devices_dir, .{ .iterate = true }) catch continue;
        defer dir.close();
        var walker = dir.walk(allocator) catch continue;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;
            if (std.mem.startsWith(u8, entry.path, "example/")) continue;

            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ devices_dir, entry.path });
            defer allocator.free(path);

            extractVidPid(allocator, path, &entries) catch continue;
        }
    }

    // Deduplicate by vid:pid
    var i: usize = 0;
    while (i < entries.items.len) {
        var j: usize = i + 1;
        var dup = false;
        while (j < entries.items.len) {
            if (entries.items[i].vid == entries.items[j].vid and entries.items[i].pid == entries.items[j].pid) {
                dup = true;
                break;
            }
            j += 1;
        }
        if (dup) {
            allocator.free(entries.items[j].name);
            _ = entries.swapRemove(j);
        } else {
            i += 1;
        }
    }

    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — do not edit\n");
    for (entries.items) |e| {
        const line = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"hidraw\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", TAG+=\"systemd\", ENV{{SYSTEMD_WANTS}}=\"padctl.service\", TAG+=\"uaccess\"\nACTION==\"add\", SUBSYSTEM==\"input\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", GROUP=\"input\", MODE=\"0660\"\n# {s}\n",
            .{ e.vid, e.pid, e.vid, e.pid, e.name },
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

fn generateUdevRules(allocator: std.mem.Allocator, devices_dir: []const u8, rules_path: []const u8) !void {
    const dirs = [_][]const u8{devices_dir};
    return generateUdevRulesFromDirs(allocator, &dirs, rules_path);
}

fn isFieldKey(line: []const u8, key: []const u8) bool {
    if (!std.mem.startsWith(u8, line, key)) return false;
    if (line.len == key.len) return true;
    const next = line[key.len];
    return next == '=' or next == ' ' or next == '\t';
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
    var in_device_section = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Track TOML sections — only extract from [device]
        if (trimmed.len > 0 and trimmed[0] == '[') {
            in_device_section = std.mem.startsWith(u8, trimmed, "[device]");
            continue;
        }

        if (!in_device_section) continue;

        if (isFieldKey(trimmed, "name")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t\"");
                const n = @min(val.len, name_buf.len - 1);
                @memcpy(name_buf[0..n], val[0..n]);
                name = name_buf[0..n];
            }
        } else if (isFieldKey(trimmed, "vid")) {
            if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t#");
                vid = parseHexOrDec(u16, val) catch continue;
            }
        } else if (isFieldKey(trimmed, "pid")) {
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

test "install: parseHexOrDec" {
    const testing = std.testing;
    try testing.expectEqual(@as(u16, 0x37d7), try parseHexOrDec(u16, "0x37d7"));
    try testing.expectEqual(@as(u16, 1234), try parseHexOrDec(u16, "1234"));
    try testing.expectEqual(@as(u16, 0x054c), try parseHexOrDec(u16, "0x054c"));
}

test "install: extractVidPid from vader5 content" {
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

test "install: isFieldKey exact and prefix-safe" {
    const testing = std.testing;
    try testing.expect(isFieldKey("pid = 0x2401", "pid"));
    try testing.expect(isFieldKey("pid=0x2401", "pid"));
    try testing.expect(isFieldKey("vid\t= 0x37d7", "vid"));
    try testing.expect(!isFieldKey("pid_controller = true", "pid"));
    try testing.expect(!isFieldKey("video = true", "vid"));
    try testing.expect(isFieldKey("name = \"Test\"", "name"));
    try testing.expect(!isFieldKey("namespace = \"x\"", "name"));
}

test "install: extractVidPid ignores pid_controller field" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const toml_content =
        \\[device]
        \\name = "Test"
        \\vid = 0x1234
        \\pid = 0x5678
        \\pid_controller = true
    ;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test2.toml", .{tmp_path});
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
    try testing.expectEqual(@as(u16, 0x1234), entries.items[0].vid);
    try testing.expectEqual(@as(u16, 0x5678), entries.items[0].pid);
}

test "install: extractVidPid ignores [output] section vid/pid" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const toml_content =
        \\[device]
        \\name = "Flydigi Vader 5 Pro"
        \\vid = 0x37d7
        \\pid = 0x2401
        \\
        \\[output]
        \\name = "Xbox Elite Series 2"
        \\vid = 0x045e
        \\pid = 0x0b00
    ;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/vader5.toml", .{tmp_path});
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

test "install: generateServiceContent uses prefix" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr/local");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "/usr/local/bin/padctl") != null);
    try testing.expect(std.mem.indexOf(u8, content, "RuntimeDirectory=padctl") != null);
    try testing.expect(std.mem.indexOf(u8, content, "/usr/bin/padctl") == null);
}

test "install: generateUdevRules produces valid output" {
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

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path);

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "37d7") != null);
    try testing.expect(std.mem.indexOf(u8, content, "2401") != null);
    try testing.expect(std.mem.indexOf(u8, content, "SUBSYSTEM==\"hidraw\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "SUBSYSTEM==\"input\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "TAG+=\"uaccess\"") != null); // hidraw rule
    try testing.expect(std.mem.indexOf(u8, content, "GROUP=\"input\", MODE=\"0660\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uinput\"") != null);
}

test "install: findDevicesSourceDir discovers repo-root devices from zig-out/bin" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const repo_devices = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(repo_devices);
    try ensureDirAll(allocator, repo_devices);

    const self_dir = try std.fmt.allocPrint(allocator, "{s}/zig-out/bin", .{tmp_path});
    defer allocator.free(self_dir);
    try ensureDirAll(allocator, self_dir);

    const found = try findDevicesSourceDir(allocator, self_dir, "/definitely/missing");
    defer if (found) |path| allocator.free(path);

    try testing.expect(found != null);
    try testing.expectEqualStrings(repo_devices, found.?);
}

test "install: findDevicesSourceDir falls back to cwd devices" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const cwd_devices = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(cwd_devices);
    try ensureDirAll(allocator, cwd_devices);

    const self_dir = try std.fmt.allocPrint(allocator, "{s}/out/bin", .{tmp_path});
    defer allocator.free(self_dir);
    try ensureDirAll(allocator, self_dir);

    const found = try findDevicesSourceDir(allocator, self_dir, tmp_path);
    defer if (found) |path| allocator.free(path);

    try testing.expect(found != null);
    try testing.expectEqualStrings(cwd_devices, found.?);
}
