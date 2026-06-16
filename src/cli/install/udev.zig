const std = @import("std");
const paths = @import("../../config/paths.zig");
const toml_extract = @import("../toml_extract.zig");
const plan_mod = @import("plan.zig");
const InstallPlan = plan_mod.InstallPlan;
const ensureDirAll = plan_mod.ensureDirAll;
const dirExistsAbsolute = plan_mod.dirExistsAbsolute;
const dirIsNonEmpty = plan_mod.dirIsNonEmpty;
const copyFile = plan_mod.copyFile;
const runCmd = plan_mod.runCmd;

pub const modules_load_content =
    \\# padctl requires these kernel modules for virtual gamepad support
    \\uhid
    \\uinput
    \\
;

// Static udev rule tagging padctl's UHID IMU nodes as accelerometers so
// systemd-udev's `input_id` builtin and SDL's `SDL_EVDEV_GuessDeviceClass`
// treat them as sensors rather than joysticks. Kernel `hid-input.c` does not
// set `INPUT_PROP_ACCELEROMETER` for generic HID — both the udev builtin and
// SDL fall back to a heuristic ("no EV_KEY + ABS_X/Y/Z"); this explicit tag
// hardens that signal and additionally clears `ID_INPUT_JOYSTICK` so SDL
// never opens the sensor node as a gamepad.
//
// Match criteria:
//   - SUBSYSTEM == input: only evdev nodes, never hidraw.
//   - ATTRS{uniq} == "padctl/*": set by padctl via UHID_CREATE2 (`buildUniq`).
//   - ATTRS{name} == "*IMU*": padctl IMU companion card uses "<device> IMU"
//     (see device_instance.zig T5c) or an explicit imu.name override.
pub const imu_udev_rules_content =
    \\# padctl UHID IMU nodes: tag as accelerometer so SDL/Steam recognize them
    \\# as sensors instead of joysticks. Matches padctl's uniq pattern `padctl/*`
    \\# and a name containing "IMU" (padctl's convention for the IMU UHID card).
    \\# Also untags ID_INPUT_JOYSTICK to avoid SDL opening the sensor as a gamepad.
    \\SUBSYSTEM=="input", ATTRS{uniq}=="padctl/*", ATTRS{name}=="*IMU*", \
    \\  ENV{ID_INPUT_ACCELEROMETER}="1", ENV{ID_INPUT_JOYSTICK}=""
    \\
;

pub const UdevEntry = struct {
    name: []const u8,
    vid: u16,
    pid: u16,
    block_kernel_drivers: []const []const u8 = &.{},
    clone_vid_pid: bool = false,
    needs_libusb: bool = false,
};

/// POSIX sh guard used inside generated udev RUN+= commands: exits 0 iff a
/// padctl daemon control socket exists — user-scope /run/user/<uid>/padctl.sock
/// or system-scope /run/padctl/padctl.sock (socket_client.zig). One glob per ls
/// invocation: an unmatched glob stays a literal argument and the missing
/// operand makes ls fail, while a match means every operand exists. A single
/// `ls glob1 glob2` would fail whenever either glob is unmatched.
pub const daemon_socket_guard = "(ls /run/user/*/padctl.sock || ls /run/padctl/padctl.sock) >/dev/null 2>&1";

/// Proactive unbind is performed only when this install actually enables and
/// starts a runnable user service; otherwise an unbound device would be left
/// ownerless. Pure predicate so tests can table-drive it.
pub fn shouldProactiveUnbind(plan: *const InstallPlan) bool {
    return plan.do_enable_systemctl and !plan.opts.no_enable;
}

pub fn writeImuUdevRules(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    const rules_path = try std.fmt.allocPrint(allocator, "{s}/90-padctl.rules", .{plan.udev_dir});
    defer allocator.free(rules_path);

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(imu_udev_rules_content);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, rules_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
}

pub fn writeModulesLoad(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool) void {
    const dir_path = if (immutable)
        std.fmt.allocPrint(allocator, "{s}/etc/modules-load.d", .{destdir}) catch return
    else
        std.fmt.allocPrint(allocator, "{s}{s}/lib/modules-load.d", .{ destdir, prefix }) catch return;
    defer allocator.free(dir_path);

    ensureDirAll(allocator, dir_path) catch |err| {
        var errbuf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: modules-load.d dir not created: {}\n", .{err}) catch "warning: modules-load.d dir error\n";
        _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
        return;
    };

    const conf_path = std.fmt.allocPrint(allocator, "{s}/padctl.conf", .{dir_path}) catch return;
    defer allocator.free(conf_path);

    if (std.fs.createFileAbsolute(conf_path, .{ .truncate = true })) |f| {
        defer f.close();
        f.writeAll(modules_load_content) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, conf_path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    } else |err| {
        var errbuf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: modules-load.d not written: {}\n", .{err}) catch "warning: modules-load.d write error\n";
        _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
    }
}

pub fn findDevicesSourceDir(allocator: std.mem.Allocator, self_dir: []const u8, cwd_override: ?[]const u8) !?[]u8 {
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

pub fn copyDevicesTomls(allocator: std.mem.Allocator, src_dir: []const u8, dst_dir: []const u8) !void {
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

pub fn installDeviceConfigs(allocator: std.mem.Allocator, plan: *const InstallPlan, self_dir: []const u8) !void {
    const src_devices = try findDevicesSourceDir(allocator, self_dir, null);
    defer if (src_devices) |path| allocator.free(path);
    if (src_devices) |path| {
        copyDevicesTomls(allocator, path, plan.share_dir) catch |err| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "warning: device configs not installed: ") catch {};
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "{}\n", .{err}) catch "unknown error\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
        };
    } else if (dirExistsAbsolute(plan.share_dir) and dirIsNonEmpty(plan.share_dir)) {
        // Packaging (AUR/deb/rpm) already shipped device configs into the target
        // share dir; the "near binary / cwd" heuristic would otherwise emit a
        // scary warning even though devices are present.
        var infobuf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &infobuf,
            "info: device configs already present at {s}; source copy skipped\n",
            .{plan.share_dir},
        ) catch "info: device configs already present; source copy skipped\n";
        _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
    } else {
        var warnbuf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &warnbuf,
            "warning: source `devices/` directory not found (near binary, in cwd, or at {s})\n" ++
                "hint: run `padctl install` from the source checkout, or ensure your package ships device configs under {s}\n",
            .{ plan.share_dir, plan.share_dir },
        ) catch "warning: source `devices/` directory not found\n";
        _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
    }
}

pub fn collectAllDeviceEntries(allocator: std.mem.Allocator, plan: *const InstallPlan) !std.ArrayList(UdevEntry) {
    const config_dirs = paths.resolveDeviceConfigDirs(allocator) catch null;
    defer if (config_dirs) |dirs| paths.freeConfigDirs(allocator, dirs);
    var all_dirs: std.ArrayList([]const u8) = .{};
    defer all_dirs.deinit(allocator);
    try all_dirs.append(allocator, plan.share_dir);
    if (config_dirs) |dirs| {
        for (dirs) |d| try all_dirs.append(allocator, d);
    }
    return try collectDeviceEntries(allocator, all_dirs.items);
}

/// Like collectAllDeviceEntries but without an InstallPlan. Used by uninstall,
/// which has no plan; reads the resolved device config dirs plus an explicit
/// share dir (still present at call time, before it is removed).
pub fn collectDeviceEntriesForUninstall(
    allocator: std.mem.Allocator,
    share_dir: []const u8,
) !std.ArrayList(UdevEntry) {
    const config_dirs = paths.resolveDeviceConfigDirs(allocator) catch null;
    defer if (config_dirs) |dirs| paths.freeConfigDirs(allocator, dirs);
    var all_dirs: std.ArrayList([]const u8) = .{};
    defer all_dirs.deinit(allocator);
    try all_dirs.append(allocator, share_dir);
    if (config_dirs) |dirs| {
        for (dirs) |d| try all_dirs.append(allocator, d);
    }
    return try collectDeviceEntries(allocator, all_dirs.items);
}

pub fn installUdevRules(allocator: std.mem.Allocator, plan: *const InstallPlan, entries: []const UdevEntry) !void {
    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{plan.udev_dir});
    defer allocator.free(rules_path);
    try generateUdevRulesFromEntries(allocator, entries, rules_path, plan.prefix);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, rules_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    const driver_rules_path = try std.fmt.allocPrint(allocator, "{s}/61-padctl-driver-block.rules", .{plan.udev_dir});
    defer allocator.free(driver_rules_path);
    generateDriverBlockRulesFromEntries(allocator, entries, driver_rules_path) catch |err| {
        var errbuf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: driver block rules not generated: {}\n", .{err}) catch "warning: driver block rules error\n";
        _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
    };
}

/// Modules are loaded only on a live root install — never in staging/package
/// mode (no live kernel to act on) and never unprivileged (modprobe would
/// fail). Pure predicate so tests can table-drive it. Same gate as
/// applyDriverState.
pub fn shouldLoadModules(plan: *const InstallPlan) bool {
    return !plan.staging_mode and plan.is_root;
}

/// Best-effort load of the kernel modules padctl needs at runtime (uhid,
/// uinput). modules-load.d only fires at the next boot, so a first live
/// `padctl install` on a host where these are not yet resident would otherwise
/// crash-loop the daemon until reboot. modprobe failure (absent binary,
/// builtin module) is ignored by runCmd — it must never fail the install.
pub fn loadModules(plan: *const InstallPlan) void {
    if (!shouldLoadModules(plan)) return;
    runCmd(&.{ "modprobe", "uhid", "uinput" });
}

/// Mutate live kernel driver state to match the freshly written udev rules.
/// MUST be called AFTER `udevadm control --reload-rules`: re-probe generates
/// bind uevents that udevd evaluates against its currently loaded ruleset, so a
/// stale "block usbhid" rule still loaded from a previous install would re-unbind
/// usbhid and strip the device's hidraw node ("no device"). Self-gates to a
/// no-op outside root or in staging mode.
pub fn applyDriverState(allocator: std.mem.Allocator, plan: *const InstallPlan, entries: []const UdevEntry) void {
    if (plan.staging_mode or !plan.is_root) return;

    // Re-probe interfaces left driverless by an earlier install whose block
    // list this install no longer covers, BEFORE evicting currently-blocked
    // drivers. udevadm trigger only re-runs rules; it does not make the kernel
    // re-evaluate drivers for an already-attached device, so a previously
    // unbound interface stays ownerless until replug. Running reprobe first
    // means it only ever rebinds interfaces that are already driverless and
    // skips bound ones, so it never re-binds a driver the unbind step below is
    // about to evict. Not gated by shouldProactiveUnbind so it still recovers
    // when the block list is empty/reduced.
    probeAndReprobeDrivers(allocator, entries, "");

    // Evict already-attached devices without waiting for reboot. Proactively
    // writing to sysfs unbind covers devices already claimed by a blocking
    // driver at install time — but only when this install actually starts a
    // runnable service, otherwise an unbound device is left ownerless. Runs
    // last so the eviction is authoritative over the reprobe above.
    if (shouldProactiveUnbind(plan)) {
        probeAndUnbindDrivers(allocator, entries, "");
    }
}

pub fn cleanupLegacyUdevFiles(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    // padctl rules live in two trees: {prefix}/lib/udev/rules.d (normal) and
    // /etc/udev/rules.d (immutable). /etc shadows /usr/lib, so a leftover rule in
    // the non-active tree silently overrides the freshly written one after a mode
    // switch. Sweep every padctl basename from whichever tree is NOT the active
    // one; the std.mem.eql guard ensures the just-written rules are never deleted.
    // 99-padctl.rules is the historical 60- name, kept here for upgrade hygiene.
    const basenames = [_][]const u8{
        "60-padctl.rules",
        "61-padctl-driver-block.rules",
        "90-padctl.rules",
        "99-padctl.rules",
    };
    const etc_dir = try std.fmt.allocPrint(allocator, "{s}/etc/udev/rules.d", .{plan.opts.destdir});
    defer allocator.free(etc_dir);
    const lib_dir = try std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d", .{ plan.opts.destdir, plan.prefix });
    defer allocator.free(lib_dir);

    for ([_][]const u8{ etc_dir, lib_dir }) |dir| {
        if (std.mem.eql(u8, dir, plan.udev_dir)) continue;
        for (basenames) |name| {
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, name });
            defer allocator.free(path);
            std.fs.deleteFileAbsolute(path) catch {};
        }
    }
}

/// Scan all device TOML files in dirs, extract VID/PID/name/block_kernel_drivers,
/// and deduplicate by VID:PID (preferring entries with richer data).
/// Caller owns the returned entries and must call freeDeviceEntries when done.
pub fn collectDeviceEntries(allocator: std.mem.Allocator, dirs: []const []const u8) !std.ArrayList(UdevEntry) {
    var entries = std.ArrayList(UdevEntry){};
    errdefer {
        for (entries.items) |e| {
            allocator.free(e.name);
            for (e.block_kernel_drivers) |d| allocator.free(d);
            if (e.block_kernel_drivers.len > 0) allocator.free(e.block_kernel_drivers);
        }
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
            // Prefer the entry with richer data (block_kernel_drivers populated).
            if (entries.items[i].block_kernel_drivers.len == 0 and entries.items[j].block_kernel_drivers.len > 0) {
                entries.items[i].block_kernel_drivers = entries.items[j].block_kernel_drivers;
                entries.items[j].block_kernel_drivers = &.{};
            }
            // clone_vid_pid is a boolean OR: a VID:PID is "cloned" if any
            // contributing TOML carries the flag.
            if (entries.items[j].clone_vid_pid) {
                entries.items[i].clone_vid_pid = true;
            }
            if (entries.items[j].needs_libusb) {
                entries.items[i].needs_libusb = true;
            }
            const removed = entries.items[j];
            allocator.free(removed.name);
            for (removed.block_kernel_drivers) |d| allocator.free(d);
            if (removed.block_kernel_drivers.len > 0) allocator.free(removed.block_kernel_drivers);
            _ = entries.swapRemove(j);
        } else {
            i += 1;
        }
    }

    return entries;
}

pub fn freeDeviceEntries(allocator: std.mem.Allocator, entries: *std.ArrayList(UdevEntry)) void {
    for (entries.items) |e| {
        allocator.free(e.name);
        for (e.block_kernel_drivers) |d| allocator.free(d);
        if (e.block_kernel_drivers.len > 0) allocator.free(e.block_kernel_drivers);
    }
    entries.deinit(allocator);
}

pub fn generateUdevRulesFromEntries(allocator: std.mem.Allocator, entries: []const UdevEntry, rules_path: []const u8, prefix: []const u8) !void {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — do not edit\n");
    for (entries) |e| {
        const line = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"hidraw\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"\nACTION==\"add\", SUBSYSTEM==\"input\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", GROUP=\"input\", MODE=\"0660\"\n# {s}\n",
            .{ e.vid, e.pid, e.vid, e.pid, e.name },
        );
        defer allocator.free(line);
        try buf.appendSlice(allocator, line);
    }

    try buf.appendSlice(allocator, "\n# Hotplug reconnect — start padctl on device add\n");
    for (entries) |e| {
        const hotplug_line = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"hidraw\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", RUN+=\"/usr/bin/systemd-run --no-block {s}/bin/padctl-reconnect\"\n",
            .{ e.vid, e.pid, prefix },
        );
        defer allocator.free(hotplug_line);
        try buf.appendSlice(allocator, hotplug_line);
    }

    // uaccess: graphical login ACL; GROUP+MODE: headless/SSH/test fallback via 'input' group
    try buf.appendSlice(allocator, "\nSUBSYSTEM==\"misc\", KERNEL==\"uinput\", TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"\n");
    try buf.appendSlice(allocator, "SUBSYSTEM==\"misc\", KERNEL==\"uhid\",   TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"\n");

    // Per-VID/PID udev rules for cloned UHID cards (clone_vid_pid=true).
    // hid-universal-pidff binds by modalias on the cloned VID/PID; uaccess must
    // follow so the user session retains access to the resulting hidraw node.
    for (entries) |e| {
        if (!e.clone_vid_pid) continue;
        const rule = try std.fmt.allocPrint(
            allocator,
            "KERNELS==\"uhid\", SUBSYSTEM==\"input\", ATTRS{{id/vendor}}==\"{x:0>4}\", ATTRS{{id/product}}==\"{x:0>4}\", TAG+=\"uaccess\"\n",
            .{ e.vid, e.pid },
        );
        defer allocator.free(rule);
        try buf.appendSlice(allocator, rule);
    }

    // Devices with vendor/suppress interfaces are claimed via libusb, which needs
    // write access to the raw USB device node (/dev/bus/usb/...) plus driver
    // detach — the hidraw grant above does not cover that node, so without this
    // the user-scope daemon cannot claim the device and the bind fails.
    var has_libusb = false;
    for (entries) |e| {
        if (!e.needs_libusb) continue;
        if (!has_libusb) {
            try buf.appendSlice(allocator, "\n# Raw USB device node access for libusb-claimed devices\n");
            has_libusb = true;
        }
        const rule = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"usb\", ENV{{DEVTYPE}}==\"usb_device\", ATTR{{idVendor}}==\"{x:0>4}\", ATTR{{idProduct}}==\"{x:0>4}\", TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"\n# {s}\n",
            .{ e.vid, e.pid, e.name },
        );
        defer allocator.free(rule);
        try buf.appendSlice(allocator, rule);
    }

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

/// Collects entries then generates rules.
fn generateUdevRulesFromDirs(allocator: std.mem.Allocator, dirs: []const []const u8, rules_path: []const u8, prefix: []const u8) !void {
    var entries = try collectDeviceEntries(allocator, dirs);
    defer freeDeviceEntries(allocator, &entries);
    try generateUdevRulesFromEntries(allocator, entries.items, rules_path, prefix);
}

pub fn generateDriverBlockRulesFromEntries(allocator: std.mem.Allocator, entries: []const UdevEntry, rules_path: []const u8) !void {
    var has_blocks = false;
    for (entries) |e| {
        if (e.block_kernel_drivers.len > 0) {
            has_blocks = true;
            break;
        }
    }
    if (!has_blocks) {
        // Remove stale rules file from a previous install that had driver blocking.
        std.fs.deleteFileAbsolute(rules_path) catch {};
        return;
    }

    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — kernel driver conflict rules\n");

    for (entries) |e| {
        for (e.block_kernel_drivers) |driver| {
            // Unbind only when a padctl daemon is actually running (control
            // socket present). No daemon ⇒ the kernel driver keeps the device
            // so the controller still works as a plain kernel gamepad.
            const line = try std.fmt.allocPrint(
                allocator,
                "ACTION==\"add|bind\", SUBSYSTEM==\"usb\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", DRIVER==\"{s}\", RUN+=\"/bin/sh -c '{s} && echo %k > /sys/bus/usb/drivers/{s}/unbind'\"\n# {s}\n",
                .{ e.vid, e.pid, driver, daemon_socket_guard, driver, e.name },
            );
            defer allocator.free(line);
            try buf.appendSlice(allocator, line);
        }
    }

    // On device removal, restore the kernel driver only when no daemon is
    // running; a running padctl keeps owning the VID:PID across replug.
    for (entries) |e| {
        for (e.block_kernel_drivers) |driver| {
            const line = try std.fmt.allocPrint(
                allocator,
                "ACTION==\"remove\", SUBSYSTEM==\"usb\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", RUN+=\"/bin/sh -c '{s} || /sbin/modprobe {s}'\"\n",
                .{ e.vid, e.pid, daemon_socket_guard, driver },
            );
            defer allocator.free(line);
            try buf.appendSlice(allocator, line);
        }
    }

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

/// Collects entries then generates driver block rules.
fn generateDriverBlockRules(allocator: std.mem.Allocator, dirs: []const []const u8, rules_path: []const u8) !void {
    var entries = try collectDeviceEntries(allocator, dirs);
    defer freeDeviceEntries(allocator, &entries);
    try generateDriverBlockRulesFromEntries(allocator, entries.items, rules_path);
}

/// Walk <sys_root>/sys/bus/usb/drivers/<driver>/ and synchronously unbind any
/// device whose idVendor:idProduct matches an entry in `entries`. Called after
/// writing the udev rule file and before udevadm trigger so already-attached
/// devices are evicted without needing a reboot.
/// Requires root; skips (warn log) on permission errors so non-root and
/// staging-mode callers are unaffected.
/// `sys_root` is "" in production; tests inject a tmpDir path (P9).
pub fn probeAndUnbindDrivers(allocator: std.mem.Allocator, entries: []const UdevEntry, sys_root: []const u8) void {
    for (entries) |entry| {
        for (entry.block_kernel_drivers) |driver| {
            const driver_path = std.fmt.allocPrint(
                allocator,
                "{s}/sys/bus/usb/drivers/{s}",
                .{ sys_root, driver },
            ) catch continue;
            defer allocator.free(driver_path);

            var driver_dir = std.fs.openDirAbsolute(driver_path, .{ .iterate = true }) catch continue;
            defer driver_dir.close();

            var it = driver_dir.iterate();
            while (it.next() catch null) |de| {
                // USB device symlinks look like "1-1.4:1.0" (interface notation).
                if (de.kind != .sym_link and de.kind != .directory) continue;
                if (de.name.len == 0 or de.name[0] < '0' or de.name[0] > '9') continue;

                // Read idVendor and idProduct from the parent device node.
                // Strip the interface suffix ":N.M" to get the device name.
                const colon = std.mem.lastIndexOf(u8, de.name, ":") orelse continue;
                const dev_name = de.name[0..colon];

                const vendor_path = std.fmt.allocPrint(
                    allocator,
                    "{s}/sys/bus/usb/devices/{s}/idVendor",
                    .{ sys_root, dev_name },
                ) catch continue;
                defer allocator.free(vendor_path);

                const product_path = std.fmt.allocPrint(
                    allocator,
                    "{s}/sys/bus/usb/devices/{s}/idProduct",
                    .{ sys_root, dev_name },
                ) catch continue;
                defer allocator.free(product_path);

                const vid = readSysHex(vendor_path) catch continue;
                const pid = readSysHex(product_path) catch continue;

                if (vid != entry.vid or pid != entry.pid) continue;

                const unbind_path = std.fmt.allocPrint(
                    allocator,
                    "{s}/sys/bus/usb/drivers/{s}/unbind",
                    .{ sys_root, driver },
                ) catch continue;
                defer allocator.free(unbind_path);

                if (std.fs.openFileAbsolute(unbind_path, .{ .mode = .write_only })) |f| {
                    defer f.close();
                    f.writeAll(de.name) catch |err| {
                        std.log.warn("could not unbind {s} from kernel driver '{s}' (try replug or reboot to evict the shadow device): {}", .{ de.name, driver, err });
                    };
                } else |err| {
                    std.log.warn("could not unbind {s} from kernel driver '{s}' (try replug or reboot to evict the shadow device): {}", .{ de.name, driver, err });
                }
            }
        }
    }
}

/// Inverse of probeAndUnbindDrivers: walk <sys_root>/sys/bus/usb/devices/ and,
/// for any USB device whose idVendor:idProduct matches an entry, rebind every
/// interface that currently has no driver back to a blocked driver. Called by
/// uninstall after the driver-block rule is removed so a controller
/// that is still plugged in and currently unbound is restored to the kernel
/// driver without requiring a physical replug.
/// Requires root; skips silently / warn-logs on permission errors. A best-effort
/// `modprobe <driver>` is issued first so the rebind target exists even if the
/// module was never auto-loaded. `sys_root` is "" in production; tests inject a
/// tmpDir path (P9).
pub fn probeAndRebindDrivers(allocator: std.mem.Allocator, entries: []const UdevEntry, sys_root: []const u8) void {
    const devices_path = std.fmt.allocPrint(
        allocator,
        "{s}/sys/bus/usb/devices",
        .{sys_root},
    ) catch return;
    defer allocator.free(devices_path);

    var devices_dir = std.fs.openDirAbsolute(devices_path, .{ .iterate = true }) catch return;
    defer devices_dir.close();

    for (entries) |entry| {
        if (entry.block_kernel_drivers.len == 0) continue;

        var it = devices_dir.iterate();
        while (it.next() catch null) |de| {
            if (de.kind != .sym_link and de.kind != .directory) continue;
            if (de.name.len == 0 or de.name[0] < '0' or de.name[0] > '9') continue;
            // Skip interface nodes ("1-1.4:1.0"); only match top-level devices.
            if (std.mem.indexOfScalar(u8, de.name, ':') != null) continue;

            const vendor_path = std.fmt.allocPrint(
                allocator,
                "{s}/sys/bus/usb/devices/{s}/idVendor",
                .{ sys_root, de.name },
            ) catch continue;
            defer allocator.free(vendor_path);

            const product_path = std.fmt.allocPrint(
                allocator,
                "{s}/sys/bus/usb/devices/{s}/idProduct",
                .{ sys_root, de.name },
            ) catch continue;
            defer allocator.free(product_path);

            const vid = readSysHex(vendor_path) catch continue;
            const pid = readSysHex(product_path) catch continue;
            if (vid != entry.vid or pid != entry.pid) continue;

            for (entry.block_kernel_drivers) |driver| {
                // Best-effort: ensure the module is present before binding.
                if (sys_root.len == 0) runCmd(&.{ "modprobe", driver });

                const bind_path = std.fmt.allocPrint(
                    allocator,
                    "{s}/sys/bus/usb/drivers/{s}/bind",
                    .{ sys_root, driver },
                ) catch continue;
                defer allocator.free(bind_path);

                rebindInterfaces(allocator, sys_root, de.name, bind_path, driver);
            }
        }
    }
}

/// For each interface child of USB device `dev_name` ("<dev_name>:N.M") that has
/// no `driver` symlink, write its name to the driver `bind` attribute.
fn rebindInterfaces(
    allocator: std.mem.Allocator,
    sys_root: []const u8,
    dev_name: []const u8,
    bind_path: []const u8,
    driver: []const u8,
) void {
    const dev_dir_path = std.fmt.allocPrint(
        allocator,
        "{s}/sys/bus/usb/devices/{s}",
        .{ sys_root, dev_name },
    ) catch return;
    defer allocator.free(dev_dir_path);

    var dev_dir = std.fs.openDirAbsolute(dev_dir_path, .{ .iterate = true }) catch return;
    defer dev_dir.close();

    var it = dev_dir.iterate();
    while (it.next() catch null) |child| {
        if (child.kind != .directory and child.kind != .sym_link) continue;
        // Interface dirs are named "<dev_name>:cfg.iface".
        if (!std.mem.startsWith(u8, child.name, dev_name)) continue;
        if (child.name.len <= dev_name.len or child.name[dev_name.len] != ':') continue;

        const driver_link = std.fmt.allocPrint(
            allocator,
            "{s}/sys/bus/usb/devices/{s}/{s}/driver",
            .{ sys_root, dev_name, child.name },
        ) catch continue;
        defer allocator.free(driver_link);

        // Already bound to some driver — leave it alone.
        if (std.fs.accessAbsolute(driver_link, .{})) |_| continue else |_| {}

        if (std.fs.openFileAbsolute(bind_path, .{ .mode = .write_only })) |f| {
            defer f.close();
            f.writeAll(child.name) catch |err| {
                std.log.warn("could not rebind {s} to kernel driver '{s}' (replug or run `modprobe {s}` to restore it): {}", .{ child.name, driver, driver, err });
            };
        } else |err| {
            std.log.warn("could not rebind {s} to kernel driver '{s}' (replug or run `modprobe {s}` to restore it): {}", .{ child.name, driver, driver, err });
        }
    }
}

/// Walk <sys_root>/sys/bus/usb/devices/ and, for any USB device whose
/// idVendor:idProduct matches an entry, ask the kernel to re-probe every
/// interface child that currently has no `driver` symlink by writing its name
/// to the global <sys_root>/sys/bus/usb/drivers_probe. The kernel selects the
/// correct driver from the descriptor, so no driver name is hard-coded.
/// Best-effort: catch+continue on every fs error; silent no-op when the tree is
/// absent or non-root. `sys_root` is "" in production; tests inject a tmpDir.
pub fn probeAndReprobeDrivers(allocator: std.mem.Allocator, entries: []const UdevEntry, sys_root: []const u8) void {
    const devices_path = std.fmt.allocPrint(
        allocator,
        "{s}/sys/bus/usb/devices",
        .{sys_root},
    ) catch return;
    defer allocator.free(devices_path);

    var devices_dir = std.fs.openDirAbsolute(devices_path, .{ .iterate = true }) catch return;
    defer devices_dir.close();

    const probe_path = std.fmt.allocPrint(
        allocator,
        "{s}/sys/bus/usb/drivers_probe",
        .{sys_root},
    ) catch return;
    defer allocator.free(probe_path);

    for (entries) |entry| {
        var it = devices_dir.iterate();
        while (it.next() catch null) |de| {
            if (de.kind != .sym_link and de.kind != .directory) continue;
            if (de.name.len == 0 or de.name[0] < '0' or de.name[0] > '9') continue;
            // Skip interface nodes ("1-1.4:1.0"); only match top-level devices.
            if (std.mem.indexOfScalar(u8, de.name, ':') != null) continue;

            const vendor_path = std.fmt.allocPrint(
                allocator,
                "{s}/sys/bus/usb/devices/{s}/idVendor",
                .{ sys_root, de.name },
            ) catch continue;
            defer allocator.free(vendor_path);

            const product_path = std.fmt.allocPrint(
                allocator,
                "{s}/sys/bus/usb/devices/{s}/idProduct",
                .{ sys_root, de.name },
            ) catch continue;
            defer allocator.free(product_path);

            const vid = readSysHex(vendor_path) catch continue;
            const pid = readSysHex(product_path) catch continue;
            if (vid != entry.vid or pid != entry.pid) continue;

            reprobeInterfaces(allocator, sys_root, de.name, probe_path);
        }
    }
}

/// For each interface child of USB device `dev_name` ("<dev_name>:N.M") that has
/// no `driver` symlink, write its name to the global `drivers_probe` attribute.
fn reprobeInterfaces(
    allocator: std.mem.Allocator,
    sys_root: []const u8,
    dev_name: []const u8,
    probe_path: []const u8,
) void {
    const dev_dir_path = std.fmt.allocPrint(
        allocator,
        "{s}/sys/bus/usb/devices/{s}",
        .{ sys_root, dev_name },
    ) catch return;
    defer allocator.free(dev_dir_path);

    var dev_dir = std.fs.openDirAbsolute(dev_dir_path, .{ .iterate = true }) catch return;
    defer dev_dir.close();

    var it = dev_dir.iterate();
    while (it.next() catch null) |child| {
        if (child.kind != .directory and child.kind != .sym_link) continue;
        if (!std.mem.startsWith(u8, child.name, dev_name)) continue;
        if (child.name.len <= dev_name.len or child.name[dev_name.len] != ':') continue;

        const driver_link = std.fmt.allocPrint(
            allocator,
            "{s}/sys/bus/usb/devices/{s}/{s}/driver",
            .{ sys_root, dev_name, child.name },
        ) catch continue;
        defer allocator.free(driver_link);

        // Already bound to some driver — nothing to re-probe.
        if (std.fs.accessAbsolute(driver_link, .{})) |_| continue else |_| {}

        if (std.fs.openFileAbsolute(probe_path, .{ .mode = .write_only })) |f| {
            defer f.close();
            f.writeAll(child.name) catch {};
        } else |_| {}
    }
}

pub fn readSysHex(path: []const u8) !u16 {
    var f = try std.fs.openFileAbsolute(path, .{});
    defer f.close();
    var buf: [8]u8 = undefined;
    const n = try f.read(&buf);
    const trimmed = std.mem.trim(u8, buf[0..n], " \t\r\n");
    return std.fmt.parseInt(u16, trimmed, 16);
}

fn generateUdevRules(allocator: std.mem.Allocator, devices_dir: []const u8, rules_path: []const u8, prefix: []const u8) !void {
    const dirs = [_][]const u8{devices_dir};
    return generateUdevRulesFromDirs(allocator, &dirs, rules_path, prefix);
}

fn isFieldKey(line: []const u8, key: []const u8) bool {
    if (!std.mem.startsWith(u8, line, key)) return false;
    if (line.len == key.len) return true;
    const next = line[key.len];
    return next == '=' or next == ' ' or next == '\t';
}

/// Validate that a string is a safe identifier (alphanumeric, underscore, hyphen).
/// Prevents command injection when interpolated into udev RUN+= shell commands.
pub fn isValidIdentifier(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
    }
    return true;
}

/// Parse a TOML inline array of strings, e.g. `["xpad", "hid_generic"]`.
fn parseStringArray(allocator: std.mem.Allocator, value: []const u8) ![]const []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len < 2 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']') return &.{};
    const inner = trimmed[1 .. trimmed.len - 1];
    if (std.mem.trim(u8, inner, " \t").len == 0) return &.{};

    var count: usize = 0;
    var it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |_| count += 1;

    const result = try allocator.alloc([]const u8, count);
    var idx: usize = 0;
    it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |elem| {
        const clean = std.mem.trim(u8, elem, " \t\"'");
        // ! Reject unsafe identifiers — these are interpolated into udev shell commands.
        if (!isValidIdentifier(clean)) {
            for (result[0..idx]) |prev| allocator.free(prev);
            allocator.free(result);
            return &.{};
        }
        result[idx] = try allocator.dupe(u8, clean);
        idx += 1;
    }
    return result;
}

fn extractVidPid(allocator: std.mem.Allocator, path: []const u8, entries: *std.ArrayList(UdevEntry)) !void {
    var f = try std.fs.openFileAbsolute(path, .{});
    defer f.close();
    const content = try f.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(content);

    const dev = (try toml_extract.extractDeviceVidPid(allocator, content)) orelse return;
    errdefer toml_extract.freeDeviceInfo(allocator, dev);

    var name_buf: [256]u8 = undefined;
    var name: []const u8 = std.fs.path.stem(path);
    var clone_vid_pid: bool = false;
    var needs_libusb: bool = false;
    var in_device_section = false;
    var in_ffb_section = false;
    var in_interface_section = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0 and trimmed[0] == '[') {
            in_device_section = std.mem.startsWith(u8, trimmed, "[device]");
            in_ffb_section = std.mem.startsWith(u8, trimmed, "[output.force_feedback]");
            in_interface_section = std.mem.startsWith(u8, trimmed, "[[device.interface]]");
            continue;
        }
        if (in_device_section) {
            if (isFieldKey(trimmed, "name")) {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                    const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t\"");
                    const n = @min(val.len, name_buf.len - 1);
                    @memcpy(name_buf[0..n], val[0..n]);
                    name = name_buf[0..n];
                }
            }
        } else if (in_ffb_section) {
            if (isFieldKey(trimmed, "clone_vid_pid")) {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                    const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t");
                    clone_vid_pid = std.mem.eql(u8, val, "true");
                }
            }
        } else if (in_interface_section) {
            // vendor/suppress interfaces are claimed via libusb, not hidraw.
            if (isFieldKey(trimmed, "class")) {
                if (std.mem.indexOfScalar(u8, trimmed, '"')) |q1| {
                    if (std.mem.indexOfScalarPos(u8, trimmed, q1 + 1, '"')) |q2| {
                        const val = trimmed[q1 + 1 .. q2];
                        if (std.mem.eql(u8, val, "vendor") or std.mem.eql(u8, val, "suppress"))
                            needs_libusb = true;
                    }
                }
            }
        }
    }

    try entries.append(allocator, .{
        .name = try allocator.dupe(u8, name),
        .vid = dev.vid,
        .pid = dev.pid,
        .block_kernel_drivers = dev.block_kernel_drivers,
        .clone_vid_pid = clone_vid_pid,
        .needs_libusb = needs_libusb,
    });
}

fn parseHexOrDec(comptime T: type, s: []const u8) !T {
    const trimmed = std.mem.trim(u8, s, " \t\r");
    if (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X")) {
        return std.fmt.parseInt(T, trimmed[2..], 16);
    }
    return std.fmt.parseInt(T, trimmed, 10);
}

/// Private helpers exposed to tests. Production code must use collectAllDeviceEntries
/// + generateUdevRulesFromEntries instead of reaching through this namespace.
pub const _internals_for_tests = struct {
    pub const isFieldKey = @import("udev.zig").isFieldKey;
    pub const parseStringArray = @import("udev.zig").parseStringArray;
    pub const extractVidPid = @import("udev.zig").extractVidPid;
    pub const parseHexOrDec = @import("udev.zig").parseHexOrDec;
    pub const collectDeviceEntries = @import("udev.zig").collectDeviceEntries;
    pub const generateUdevRules = @import("udev.zig").generateUdevRules;
    pub const generateDriverBlockRules = @import("udev.zig").generateDriverBlockRules;
    pub const generateDriverBlockRulesFromEntries = @import("udev.zig").generateDriverBlockRulesFromEntries;
};

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
