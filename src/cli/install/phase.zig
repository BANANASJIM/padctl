const std = @import("std");
const plan_mod = @import("plan.zig");
const scope_mod = @import("scope.zig");
const services = @import("services.zig");
const udev = @import("udev.zig");
const migration = @import("migration.zig");
const mappings = @import("mappings.zig");
const control_socket = @import("../../io/control_socket.zig");
const socket_client = @import("../socket_client.zig");

/// Test hook: when non-null, `probeSocketAlive` calls this instead of probing.
/// Lets uninstall tests simulate a live daemon (and toggle aliveness between
/// the pre-stop and post-stop probes) without binding a real socket.
pub var test_probe_alive_override: ?*const fn (path: []const u8) bool = null;

/// Test hook: when non-null, uninstall prefixes runtime paths
/// (/run/padctl/padctl.sock, .pid) with this root instead of "" so the
/// daemon-stop probe path can be exercised against a tmpdir without
/// flipping the lifecycle scope to .package via opts.destdir.
pub var test_runtime_root_override: ?[]const u8 = null;

/// Test hook: when non-null, uninstall uses this euid for scope detection
/// instead of `getuid()`. Lets tests drive scope=.system paths from a
/// non-root container without root.
pub var test_euid_override: ?u32 = null;

fn probeSocketAlive(path: []const u8) bool {
    if (test_probe_alive_override) |f| return f(path);
    return control_socket.probeAlive(path);
}

/// Probe-guarded unlink: if a live daemon is bound to `path`, stop it in both
/// systemctl scopes and re-probe before deleting. Refuses (returns error) when
/// the daemon survives the stop. Silent unlink when no daemon is present.
fn unlinkRuntimePath(allocator: std.mem.Allocator, path: []const u8) !void {
    if (probeSocketAlive(path)) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "  warn: padctl daemon is bound to ") catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, "; stopping before unlink\n") catch {};
        services.stopDaemonScope(allocator, .both) catch {
            _ = std.posix.write(std.posix.STDERR_FILENO,
                \\  error: failed to stop padctl daemon; refusing to unlink live socket.
                \\  Manually: sudo systemctl stop padctl.service && systemctl --user stop padctl.service
                \\
            ) catch {};
            return error.DaemonStopFailed;
        };
        std.Thread.sleep(500 * std.time.ns_per_ms);
        if (probeSocketAlive(path)) {
            _ = std.posix.write(std.posix.STDERR_FILENO,
                \\  error: padctl daemon still alive after stop; refusing to unlink live socket
                \\
            ) catch {};
            return error.DaemonStillAlive;
        }
    }
    std.fs.deleteFileAbsolute(path) catch {};
}

/// Remove `*.wants/padctl.service` symlinks whose target unit file no longer
/// exists on disk — left dangling after the stop+unlink cycle on some installs.
fn gcDanglingWantsLinks(allocator: std.mem.Allocator, destdir: []const u8) void {
    const candidates = [_][]const u8{
        "/etc/systemd/system/multi-user.target.wants/padctl.service",
        "/etc/systemd/user/default.target.wants/padctl.service",
    };
    for (candidates) |suffix| {
        const path = std.fmt.allocPrint(allocator, "{s}{s}", .{ destdir, suffix }) catch continue;
        defer allocator.free(path);
        migration.removeBrokenSymlink(path);
    }
    if (std.posix.getenv("HOME")) |home| {
        const user_path = std.fmt.allocPrint(
            allocator,
            "{s}/.config/systemd/user/default.target.wants/padctl.service",
            .{home},
        ) catch return;
        defer allocator.free(user_path);
        migration.removeBrokenSymlink(user_path);
    }
}

const InstallOptions = plan_mod.InstallOptions;
const InstallPlan = plan_mod.InstallPlan;
const EnvSnapshot = plan_mod.EnvSnapshot;
const detectImmutableOs = plan_mod.detectImmutableOs;
const shouldAbortForImmutable = plan_mod.shouldAbortForImmutable;
const ensureDirAll = plan_mod.ensureDirAll;
const userInGroup = plan_mod.userInGroup;
const hostHasInputGroup = plan_mod.hostHasInputGroup;
const runCmd = plan_mod.runCmd;

pub fn run(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    if (opts.destdir.len == 0 and std.os.linux.getuid() != 0 and
        (opts.user_service orelse true) == false)
    {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: system-wide install requires root — use: sudo padctl install\n") catch {};
        std.process.exit(1);
    }

    if (opts.immutable and opts.no_immutable) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: --immutable and --no-immutable are mutually exclusive\n") catch {};
        std.process.exit(1);
    }

    const immutable_probe = detectImmutableOs(allocator, if (opts.destdir.len > 0) opts.destdir else "");
    if (shouldAbortForImmutable(immutable_probe, opts)) {
        _ = std.posix.write(std.posix.STDERR_FILENO,
            \\error: immutable OS detected (files under /usr are read-only).
            \\Standard install will not work correctly on this system.
            \\
            \\Re-run with: sudo padctl install --immutable --prefix /usr/local
            \\
            \\This routes systemd units and udev rules to /etc/ where they persist
            \\across updates. Use --no-immutable to force standard install.
            \\
        ) catch {};
        std.process.exit(1);
    }

    const plan = try InstallPlan.compute(allocator, opts, EnvSnapshot.fromProcess());
    defer plan.deinit(allocator);

    try migration.runLegacySystemUnitMigration(&plan);

    try ensureDirAll(allocator, plan.bin_dir);
    try ensureDirAll(allocator, plan.service_dir);
    try ensureDirAll(allocator, plan.share_dir);
    try ensureDirAll(allocator, plan.udev_dir);

    // Gate must cover root+SUDO_USER path (sudo_hop) for XDG dir seeding.
    if (plan.do_xdg_dirs) {
        const home = try migration.resolveTargetHome(allocator);
        defer allocator.free(home);
        try migration.ensureUserXdgDirs(allocator, home);
    }

    const self_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_path);
    const self_dir = std.fs.path.dirname(self_path) orelse ".";

    try services.installBinaries(allocator, &plan, self_path, self_dir);
    try services.installServiceFiles(allocator, &plan);
    try services.installReconnectScript(allocator, &plan);
    try udev.installDeviceConfigs(allocator, &plan, self_dir);

    var device_entries = try udev.collectAllDeviceEntries(allocator, &plan);
    defer udev.freeDeviceEntries(allocator, &device_entries);

    try udev.installUdevRules(allocator, &plan, device_entries.items);
    try udev.cleanupLegacyUdevFiles(allocator, &plan);
    try udev.writeImuUdevRules(allocator, &plan);
    udev.writeModulesLoad(allocator, plan.opts.destdir, plan.prefix, plan.effective_immutable);

    var installed_mappings = std.ArrayList([]const u8){};
    defer installed_mappings.deinit(allocator);
    var mapping_failed = try mappings.installMappings(allocator, &plan, self_dir, &installed_mappings);
    if (installed_mappings.items.len > 0) {
        const binding_failed = try mappings.installBindings(allocator, &plan, self_dir, installed_mappings.items);
        mapping_failed = mapping_failed or binding_failed;
    }

    // Order is load-bearing: reload the udev ruleset, THEN mutate live driver
    // state, THEN start the service. applyDriverState re-probes driverless
    // interfaces, which generates bind uevents udevd evaluates against its
    // loaded ruleset — so a stale "block usbhid" rule must be unloaded first,
    // or it re-unbinds usbhid and the device loses its hidraw node (#355).
    if (plan.do_enable_systemctl or !plan.staging_mode) {
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nReloading system daemons...\n") catch {};
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
        runCmd(&.{ "udevadm", "trigger" });
        udev.applyDriverState(allocator, &plan, device_entries.items);
    }
    if (plan.do_enable_systemctl) {
        services.runSystemctlUnits(&plan);
    }

    if (mapping_failed) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "\nInstall completed with mapping errors.\n") catch {};
        return error.MappingInstallFailed;
    }

    if (plan.shouldVerifyDaemon()) {
        var sock_buf: [256]u8 = undefined;
        const sock_path = verifySocketPath(&plan, &sock_buf);
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nWaiting for the daemon to respond...\n") catch {};
        if (!waitDaemonResponding(sock_path, 5000, 250)) {
            printVerifyFailure(allocator, &plan);
            return error.DaemonNotResponding;
        }
    }

    printCompletionHint(&plan);
    printInputGroupHint();
}

/// Liveness check that proves the daemon is serving requests, not merely
/// that a socket file exists: full STATUS round-trip with a bounded read.
pub fn statusRoundTrip(path: []const u8) bool {
    const fd = socket_client.connectToSocket(path) catch return false;
    defer std.posix.close(fd);
    var buf: [4096]u8 = undefined;
    const resp = socket_client.sendCommandTimeout(fd, "STATUS\n", &buf, 1000) catch return false;
    return std.mem.startsWith(u8, resp, "STATUS");
}

pub fn waitDaemonResponding(path: []const u8, timeout_ms: i64, poll_interval_ms: u64) bool {
    const deadline = std.time.milliTimestamp() + timeout_ms;
    while (true) {
        if (statusRoundTrip(path)) return true;
        if (std.time.milliTimestamp() >= deadline) return false;
        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }
}

/// Resolve the socket the just-started user service will bind. Under
/// sudo_hop the invoking user's runtime dir is derived from SUDO_UID since
/// the process env belongs to root.
fn verifySocketPath(plan: *const InstallPlan, buf: []u8) []const u8 {
    if (plan.systemctl_plan.mode == .sudo_hop) {
        var xrd_buf: [64]u8 = undefined;
        const xrd: ?[]const u8 = std.fmt.bufPrint(&xrd_buf, "/run/user/{s}", .{plan.systemctl_plan.sudo_uid}) catch null;
        return socket_client.resolveSocketPathFor(buf, null, xrd, socket_client.SYSTEM_RUNTIME_DIR, false);
    }
    return socket_client.resolveSocketPath(buf);
}

fn printVerifyFailure(allocator: std.mem.Allocator, plan: *const InstallPlan) void {
    _ = std.posix.write(std.posix.STDERR_FILENO,
        \\
        \\error: install completed but the daemon is not responding.
        \\
        \\Recent service log:
        \\
    ) catch {};
    if (plan.systemctl_plan.mode == .sudo_hop) {
        const xrd = std.fmt.allocPrint(allocator, "XDG_RUNTIME_DIR=/run/user/{s}", .{plan.systemctl_plan.sudo_uid}) catch return;
        defer allocator.free(xrd);
        const dbus = std.fmt.allocPrint(allocator, "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{s}/bus", .{plan.systemctl_plan.sudo_uid}) catch return;
        defer allocator.free(dbus);
        runCmd(&.{ "sudo", "-u", plan.systemctl_plan.sudo_user, xrd, dbus, "journalctl", "--user", "-u", "padctl.service", "-n", "10", "--no-pager" });
    } else {
        runCmd(&.{ "journalctl", "--user", "-u", "padctl.service", "-n", "10", "--no-pager" });
    }
    _ = std.posix.write(std.posix.STDERR_FILENO,
        \\
        \\Inspect with: journalctl --user -u padctl.service
        \\Diagnose with: padctl doctor
        \\
    ) catch {};
}

fn printCompletionHint(plan: *const InstallPlan) void {
    if (plan.staging_mode) {
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete (staged).\n") catch {};
        return;
    }
    if (plan.opts.user_service != null and plan.opts.user_service.? == false) {
        _ = std.posix.write(std.posix.STDOUT_FILENO,
            \\
            \\Install complete. User service NOT started (--no-user-service given).
            \\
            \\To start manually later:
            \\  systemctl --user enable --now padctl.service
            \\
        ) catch {};
        return;
    }
    if (plan.will_start_user_service and plan.is_root and
        (plan.sudo_user orelse "").len != 0)
    {
        const action_sudo = if (plan.opts.no_start and plan.opts.no_enable)
            "installed via sudo -u $SUDO_USER (neither enabled nor started — --no-enable --no-start given)"
        else if (plan.opts.no_start)
            "enabled via sudo -u $SUDO_USER (not started — --no-start given); run `systemctl --user start padctl.service` as that user when ready"
        else if (plan.opts.no_enable)
            "started via sudo -u $SUDO_USER (not enabled — --no-enable given); run `systemctl --user enable padctl.service` as that user to auto-start on login"
        else
            "enabled and started via sudo -u $SUDO_USER";
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete. User service ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, action_sudo) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO,
            \\.
            \\
            \\Verify:
            \\  systemctl --user status padctl.service
            \\
            \\To auto-start at boot without a login session (headless/server):
            \\  sudo loginctl enable-linger $USER
            \\
        ) catch {};
        return;
    }
    if (plan.will_start_user_service) {
        const action = if (plan.opts.no_start and plan.opts.no_enable)
            "installed (neither enabled nor started — --no-enable --no-start given)"
        else if (plan.opts.no_start)
            "enabled (not started — --no-start given); run `systemctl --user start padctl.service` when ready"
        else if (plan.opts.no_enable)
            "started (not enabled — --no-enable given); run `systemctl --user enable padctl.service` to auto-start on login"
        else
            "enabled and started";
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete. User service ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, action) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO,
            \\.
            \\
            \\Verify:
            \\  systemctl --user status padctl.service
            \\
            \\To auto-start at boot without a login session (headless/server):
            \\  sudo loginctl enable-linger $USER
            \\
        ) catch {};
        return;
    }
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nInstall complete.\n") catch {};
}

/// Returns true when the hint should be printed: the host has an input group
/// but the current user is not yet a member. Exposed for testing.
pub fn inputGroupHintNeeded(has_group: bool, in_group: bool) bool {
    return has_group and !in_group;
}

fn printInputGroupHint() void {
    if (!inputGroupHintNeeded(hostHasInputGroup(), userInGroup("input"))) return;
    _ = std.posix.write(std.posix.STDOUT_FILENO,
        \\
        \\[padctl] Note: /dev/uhid and /dev/uinput now grant rw to 'input' group members.
        \\[padctl] For 0-sudo UHID access from SSH/headless/test sessions, add yourself:
        \\[padctl]   sudo usermod -aG input $USER
        \\[padctl]   (then re-login for group membership to take effect)
        \\[padctl] Graphical desktop users do not need this — uaccess ACL handles it automatically.
        \\
    ) catch {};
}

pub fn uninstall(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    const real_uid = std.os.linux.getuid();
    const effective_uid: u32 = test_euid_override orelse @intCast(real_uid);
    const is_root = effective_uid == 0;

    const scope = try scope_mod.detect(.{
        .destdir = opts.destdir,
        .forced_scope = opts.scope,
        .install_phase_env = std.posix.getenv("PADCTL_INSTALL_PHASE"),
        .destdir_env = std.posix.getenv("DESTDIR"),
        .euid = effective_uid,
        .sudo_user_env = std.posix.getenv("SUDO_USER"),
        .prefix = opts.prefix,
    });

    const effective_user_service = opts.user_service orelse (scope == .user);
    if (scope == .system and !is_root) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: system-wide uninstall requires root — use: sudo padctl uninstall\n") catch {};
        std.process.exit(1);
    }

    if (opts.immutable and opts.no_immutable) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: --immutable and --no-immutable are mutually exclusive\n") catch {};
        std.process.exit(1);
    }

    const destdir = opts.destdir;

    const immutable_kind = detectImmutableOs(allocator, if (destdir.len > 0) destdir else "");
    const effective_immutable = opts.immutable or (immutable_kind != .none and !opts.no_immutable);

    const prefix = if (effective_immutable and std.mem.eql(u8, opts.prefix, "/usr"))
        "/usr/local"
    else
        opts.prefix;

    if (scope != .package) {
        // System-scope stop is only meaningful when there's a system unit
        // (scope==.system). For scope==.user, root might still be hopping —
        // but the user unit owns the daemon, system unit was never installed.
        if (scope == .system) {
            services.runSystemctlSystem(&.{ "stop", "padctl.service" });
            services.runSystemctlSystem(&.{ "disable", "padctl.service" });
        }
        // User-scope stop covers both scope==.user and scope==.system
        // (the install path may have written a user unit alongside the
        // system one when SUDO_USER was set).
        const stop_plan = services.currentPlanFromEnv();
        if (stop_plan.mode == .skip) {
            const groups = [_][]const []const u8{
                &.{ "stop", "padctl.service" },
                &.{ "disable", "padctl.service" },
            };
            services.printSkipSystemctlNoteFor(&groups);
        } else {
            services.runSystemctlUser(&.{ "stop", "padctl.service" });
            services.runSystemctlUser(&.{ "disable", "padctl.service" });
        }
    }

    // Cover both /lib/systemd/user/padctl.service and
    // /etc/systemd/user/padctl.service across upgrade paths.
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  info: removing legacy padctl-resume.service files if present\n") catch {};
    const files = [_][]const u8{
        "/bin/padctl",
        "/bin/padctl-capture",
        "/bin/padctl-debug",
        "/bin/padctl-reconnect",
        "/lib/systemd/system/padctl.service",
        "/lib/systemd/system/padctl-resume.service",
        "/lib/systemd/user/padctl-resume.service",
        "/lib/systemd/user/padctl.service",
        "/lib/udev/rules.d/60-padctl.rules",
        "/lib/udev/rules.d/61-padctl-driver-block.rules",
        "/lib/udev/rules.d/90-padctl.rules",
        "/lib/udev/rules.d/99-padctl.rules",
        "/lib/modules-load.d/padctl.conf",
    };

    for (files) |suffix| {
        const path = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ destdir, prefix, suffix });
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch continue;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // /etc udev rules and modules-load.d shadow the {prefix}/lib copies, so an
    // immutable-mode install can leave them behind even on a normal uninstall.
    // Remove them unconditionally (the systemd /etc entries stay immutable-gated).
    const etc_rules = [_][]const u8{
        "/etc/udev/rules.d/60-padctl.rules",
        "/etc/udev/rules.d/61-padctl-driver-block.rules",
        "/etc/udev/rules.d/90-padctl.rules",
        "/etc/udev/rules.d/99-padctl.rules",
        "/etc/modules-load.d/padctl.conf",
    };
    for (etc_rules) |suffix| {
        const path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ destdir, suffix });
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch continue;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // Remove the legacy service-enabled sentinel left by older installs.
    {
        const legacy_sentinel = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/service-enabled", .{destdir});
        defer allocator.free(legacy_sentinel);
        std.fs.deleteFileAbsolute(legacy_sentinel) catch {};
    }

    // The 61-padctl-driver-block rule is now gone, so a controller still
    // plugged in and currently unbound from xpad would otherwise stay
    // unbound until a physical replug (the REMOVE-side modprobe only fires
    // on a real `remove` uevent). Actively rebind it to the kernel
    // driver. Only on a live root uninstall (a destdir staging uninstall has no
    // real sysfs to act on). The share dir is read here before it is removed
    // below; collectDeviceEntriesForUninstall also reads /etc/padctl/devices.
    if (destdir.len == 0 and is_root) {
        const share_dir_for_scan = try std.fmt.allocPrint(allocator, "{s}/share/padctl", .{prefix});
        defer allocator.free(share_dir_for_scan);
        if (udev.collectDeviceEntriesForUninstall(allocator, share_dir_for_scan)) |entries| {
            var ents = entries;
            defer udev.freeDeviceEntries(allocator, &ents);
            udev.probeAndRebindDrivers(allocator, ents.items, "");
        } else |_| {}
    }

    if (effective_user_service) {
        if (std.posix.getenv("HOME")) |home| {
            const user_units = [_][]const u8{
                "/.config/systemd/user/padctl.service",
                "/.config/systemd/user/padctl-resume.service",
            };
            for (user_units) |suffix| {
                const user_unit = try std.fmt.allocPrint(allocator, "{s}{s}", .{ home, suffix });
                defer allocator.free(user_unit);
                if (std.fs.deleteFileAbsolute(user_unit)) |_| {
                    _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
                    _ = std.posix.write(std.posix.STDOUT_FILENO, user_unit) catch {};
                    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
                } else |_| {}
            }
        }
    }

    {
        const old_unit = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/system/padctl.service", .{destdir});
        defer allocator.free(old_unit);
        if (std.fs.accessAbsolute(old_unit, .{})) |_| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "hint: legacy system unit still present — run: sudo systemctl disable --now padctl\n") catch {};
        } else |_| {}
    }

    const share_dir = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl", .{ destdir, prefix });
    defer allocator.free(share_dir);
    std.fs.deleteTreeAbsolute(share_dir) catch {};

    {
        const legacy_resume = [_][]const u8{
            "/etc/systemd/user/padctl-resume.service",
            "/etc/systemd/system/padctl-resume.service",
        };
        for (legacy_resume) |suffix| {
            const path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ destdir, suffix });
            defer allocator.free(path);
            std.fs.deleteFileAbsolute(path) catch continue;
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
        }
    }

    {
        const path = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user/padctl.service", .{destdir});
        defer allocator.free(path);
        if (std.fs.deleteFileAbsolute(path)) |_| {
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
        } else |_| {}
    }

    if (effective_immutable) {
        const etc_files = [_][]const u8{
            "/etc/systemd/system/padctl.service",
            "/etc/systemd/system/padctl.service.d/immutable.conf",
            "/etc/systemd/user/padctl.service",
        };
        for (etc_files) |suffix| {
            const path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ destdir, suffix });
            defer allocator.free(path);
            std.fs.deleteFileAbsolute(path) catch continue;
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
        }
        const dropin_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/system/padctl.service.d", .{destdir});
        defer allocator.free(dropin_dir);
        std.fs.deleteTreeAbsolute(dropin_dir) catch {};
    }

    for (opts.mappings) |mapping_name| {
        if (!udev.isValidIdentifier(mapping_name)) continue;
        const path = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings/{s}.toml", .{ destdir, mapping_name });
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch continue;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    if (scope != .package) {
        // Socket liveness is the canonical signal — the same daemon owns the
        // pid file. Probe-and-stop on the socket gates both unlinks.
        const root = test_runtime_root_override orelse "";
        const sock_path = try std.fmt.allocPrint(allocator, "{s}/run/padctl/padctl.sock", .{root});
        defer allocator.free(sock_path);
        try unlinkRuntimePath(allocator, sock_path);

        const pid_path = try std.fmt.allocPrint(allocator, "{s}/run/padctl/padctl.pid", .{root});
        defer allocator.free(pid_path);
        std.fs.deleteFileAbsolute(pid_path) catch {};

        gcDanglingWantsLinks(allocator, root);

        const reload_plan = services.currentPlanFromEnv();
        if (reload_plan.mode == .skip) {
            const groups = [_][]const []const u8{&.{"daemon-reload"}};
            services.printSkipSystemctlNoteFor(&groups);
        } else {
            services.runSystemctlUser(&.{"daemon-reload"});
        }
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
    }

    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nUninstall complete.\n") catch {};
}
