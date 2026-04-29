const std = @import("std");
const plan_mod = @import("plan.zig");
const services = @import("services.zig");
const udev = @import("udev.zig");
const migration = @import("migration.zig");
const mappings = @import("mappings.zig");

const InstallOptions = plan_mod.InstallOptions;
const InstallPlan = plan_mod.InstallPlan;
const EnvSnapshot = plan_mod.EnvSnapshot;
const detectImmutableOs = plan_mod.detectImmutableOs;
const shouldAbortForImmutable = plan_mod.shouldAbortForImmutable;
const ensureDirAll = plan_mod.ensureDirAll;
const userInGroup = plan_mod.userInGroup;
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

    // PR #148 v3 sudo_hop XDG seeding — gate must cover root+SUDO_USER path.
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

    if (plan.do_enable_systemctl) {
        services.runSystemctlPhase(&plan);
    } else if (!plan.staging_mode) {
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\nReloading system daemons...\n") catch {};
        runCmd(&.{ "udevadm", "control", "--reload-rules" });
        runCmd(&.{ "udevadm", "trigger" });
    }

    if (mapping_failed) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "\nInstall completed with mapping errors.\n") catch {};
        return error.MappingInstallFailed;
    }

    printCompletionHint(&plan);
    printInputGroupHint();
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

fn printInputGroupHint() void {
    if (userInGroup("input")) return;
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
    const is_root = std.os.linux.getuid() == 0;
    const effective_user_service = opts.user_service orelse !is_root;
    if (opts.destdir.len == 0 and !is_root and !effective_user_service) {
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

    if (destdir.len == 0) {
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

    // PR #145: cover both /lib/systemd/user/padctl.service and
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
            "/etc/udev/rules.d/60-padctl.rules",
            "/etc/udev/rules.d/61-padctl-driver-block.rules",
            "/etc/udev/rules.d/90-padctl.rules",
            "/etc/udev/rules.d/99-padctl.rules",
            "/etc/modules-load.d/padctl.conf",
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

    std.fs.deleteFileAbsolute("/run/padctl/padctl.pid") catch {};
    std.fs.deleteFileAbsolute("/run/padctl/padctl.sock") catch {};

    if (destdir.len == 0) {
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
