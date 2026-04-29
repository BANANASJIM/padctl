// TODO(v0.3.0): drop legacy migration paths after one release cycle.
const std = @import("std");
const plan_mod = @import("plan.zig");
const services = @import("services.zig");
const InstallPlan = plan_mod.InstallPlan;
const writeAll = plan_mod.writeAll;
const promptYesNoDefaultYes = plan_mod.promptYesNoDefaultYes;

/// Removes `path` if it is a dangling symlink (target missing). No-op if path
/// is not a symlink or if the target is reachable. Best-effort.
pub fn removeBrokenSymlink(path: []const u8) void {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    // readLinkAbsolute returns error.NotLink for real files/dirs, error.FileNotFound
    // for missing paths — both mean nothing to clean up.
    _ = std.fs.readLinkAbsolute(path, &buf) catch return;
    // Symlink exists. accessAbsolute follows the link; FileNotFound means dangling.
    std.fs.accessAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.fs.deleteFileAbsolute(path) catch |del_err| {
                var errbuf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(
                    &errbuf,
                    "warning: could not remove broken symlink {s}: {}\n",
                    .{ path, del_err },
                ) catch "warning: broken symlink cleanup failed\n";
                writeAll(std.posix.STDERR_FILENO, msg);
            };
        },
        else => {}, // target reachable (or permission denied) — leave it alone
    };
}

/// Removes `path` if it is a symlink, regardless of whether the target exists.
/// No-op if path is a real file/dir or does not exist. Best-effort.
pub fn removeAnySymlink(path: []const u8) void {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = std.fs.readLinkAbsolute(path, &buf) catch return;
    std.fs.deleteFileAbsolute(path) catch |err| {
        var errbuf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &errbuf,
            "warning: could not remove symlink {s}: {}\n",
            .{ path, err },
        ) catch "warning: symlink removal failed\n";
        writeAll(std.posix.STDERR_FILENO, msg);
    };
}

/// Resolve the real user's home directory. When running as root (sudo), reads
/// SUDO_USER from `passwd_path` (/etc/passwd in production). Falls back to
/// `/home/<SUDO_USER>` if the passwd lookup fails. Non-root returns HOME env.
/// Caller must free the returned slice.
pub fn resolveTargetHomeFromFile(allocator: std.mem.Allocator, passwd_path: []const u8) ![]const u8 {
    if (std.os.linux.getuid() != 0) {
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
        return allocator.dupe(u8, home);
    }
    const sudo_user = std.posix.getenv("SUDO_USER") orelse return error.CannotResolveUserHome;
    if (sudo_user.len == 0) return error.CannotResolveUserHome;

    if (std.fs.cwd().readFileAlloc(allocator, passwd_path, 256 * 1024)) |contents| {
        defer allocator.free(contents);
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            // Format: name:pass:uid:gid:gecos:home:shell
            var it = std.mem.splitScalar(u8, line, ':');
            const name = it.next() orelse continue;
            if (!std.mem.eql(u8, name, sudo_user)) continue;
            _ = it.next(); // pass
            _ = it.next(); // uid
            _ = it.next(); // gid
            _ = it.next(); // gecos
            const home_field = it.next() orelse continue;
            if (home_field.len == 0) continue;
            return allocator.dupe(u8, home_field);
        }
    } else |_| {}

    return std.fmt.allocPrint(allocator, "/home/{s}", .{sudo_user});
}

pub fn resolveTargetHome(allocator: std.mem.Allocator) ![]const u8 {
    return resolveTargetHomeFromFile(allocator, "/etc/passwd");
}

/// Create the XDG parent dirs that systemd's StateDirectory= requires to exist.
/// systemd only creates the final component ($XDG_STATE_HOME/padctl), not its
/// parents. When a user has wiped ~/.local/state the service fails at startup.
/// Chowns newly created dirs to SUDO_UID:SUDO_GID when running as root.
pub fn ensureUserXdgDirs(allocator: std.mem.Allocator, home: []const u8) !void {
    // `.local/state/padctl` is included so systemd v254+ cannot auto-create it
    // as a symlink to `$XDG_CONFIG_HOME/padctl` via its legacy migration path
    // (exec-invoke.c:3044-3072). See removeAnySymlink call below.
    const dirs = [_][]const u8{
        ".config",
        ".config/systemd",
        ".config/systemd/user",
        ".local",
        ".local/state",
        ".local/state/padctl",
        ".local/share",
    };

    // Force `.local/state/padctl` to be a real directory: any pre-existing
    // symlink there (valid or broken) is removed so the mkdir in the loop below
    // succeeds. systemd v254+ creates a compatibility symlink from
    // $XDG_STATE_HOME/padctl → $XDG_CONFIG_HOME/padctl when the state dir is
    // missing and the config dir exists; that symlink makes the runtime write
    // state to $XDG_CONFIG_HOME and breaks StateDirectory= semantics (#139).
    const state_padctl = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home});
    defer allocator.free(state_padctl);
    removeAnySymlink(state_padctl);

    // Defensive broken-symlink cleanup on .config/padctl: not the v254+
    // trigger, but user environments occasionally leave dangling links that
    // block systemd from using ConfigurationDirectory=.
    const config_padctl = try std.fmt.allocPrint(allocator, "{s}/.config/padctl", .{home});
    defer allocator.free(config_padctl);
    removeBrokenSymlink(config_padctl);

    const sudo_uid_str = std.posix.getenv("SUDO_UID");
    const sudo_gid_str = std.posix.getenv("SUDO_GID");
    const running_as_root = std.os.linux.getuid() == 0;
    const parsed_uid: ?std.posix.uid_t = if (running_as_root and sudo_uid_str != null)
        std.fmt.parseInt(std.posix.uid_t, sudo_uid_str.?, 10) catch null
    else
        null;
    const parsed_gid: ?std.posix.gid_t = if (running_as_root and sudo_gid_str != null)
        std.fmt.parseInt(std.posix.gid_t, sudo_gid_str.?, 10) catch null
    else
        null;
    const do_chown = parsed_uid != null and parsed_gid != null;
    if (running_as_root and !do_chown and (sudo_uid_str != null or sudo_gid_str != null)) {
        writeAll(
            std.posix.STDERR_FILENO,
            "warning: SUDO_UID/SUDO_GID malformed — XDG dirs will be root-owned; user service may fail\n",
        );
    }
    const chown_uid = parsed_uid orelse 0;
    const chown_gid = parsed_gid orelse 0;

    for (dirs) |rel| {
        const abs = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, rel });
        defer allocator.free(abs);
        std.fs.makeDirAbsolute(abs) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };
        if (do_chown) {
            var d = std.fs.openDirAbsolute(abs, .{ .iterate = true }) catch continue;
            defer d.close();
            std.posix.fchown(d.fd, chown_uid, chown_gid) catch {};
        }
    }
}

/// Detect + optionally auto-migrate a legacy /etc/systemd/system/padctl.service
/// unit. Pre-user-service installs placed the unit here; leaving it enabled
/// would race with the new per-user unit for the hidraw grab. Prompt-driven
/// on TTY, safe no-op when the legacy file is absent or the install is staged.
pub fn runLegacySystemUnitMigration(plan: *const InstallPlan) !void {
    if (plan.staging_mode) return;
    const old_unit = "/etc/systemd/system/padctl.service";
    std.fs.accessAbsolute(old_unit, .{}) catch return;

    _ = std.posix.write(std.posix.STDERR_FILENO,
        \\warning: legacy system service detected at /etc/systemd/system/padctl.service
        \\  padctl now runs as a user service. The legacy system unit
        \\  would race with the new per-user unit for the hidraw grab,
        \\  so we recommend removing it now. Proposed actions:
        \\    - stop     padctl.service
        \\    - disable  padctl.service
        \\    - remove   /etc/systemd/system/padctl.service
        \\    - remove   /etc/systemd/system/padctl.service.d/ (drop-ins)
        \\    - remove   /etc/systemd/system/padctl-resume.service (if present)
        \\
    ) catch {};

    // Auto-migration requires root: systemctl stop/disable on a system-scope
    // unit and deletes under /etc/ both need uid 0. Non-root callers get the
    // manual command list so they can finish the migration themselves.
    if (!plan.is_root) {
        _ = std.posix.write(std.posix.STDERR_FILENO,
            \\  auto-migration needs root — skipped. Re-run as
            \\  `sudo padctl install` or clean up manually:
            \\    sudo systemctl stop padctl.service
            \\    sudo systemctl disable padctl.service
            \\    sudo rm /etc/systemd/system/padctl.service
            \\    sudo rm -rf /etc/systemd/system/padctl.service.d
            \\    sudo rm -f /etc/systemd/system/padctl-resume.service
            \\
        ) catch {};
        return;
    }

    if (promptYesNoDefaultYes("Migrate legacy system service now?")) {
        services.runSystemctlSystem(&.{ "stop", "padctl.service" });
        services.runSystemctlSystem(&.{ "disable", "padctl.service" });
        std.fs.deleteFileAbsolute(old_unit) catch {};
        std.fs.deleteTreeAbsolute("/etc/systemd/system/padctl.service.d") catch {};
        const old_resume = "/etc/systemd/system/padctl-resume.service";
        if (std.fs.accessAbsolute(old_resume, .{})) |_| {
            services.runSystemctlSystem(&.{ "disable", "padctl-resume.service" });
            std.fs.deleteFileAbsolute(old_resume) catch {};
        } else |_| {}
        _ = std.posix.write(std.posix.STDERR_FILENO, "  legacy migration complete\n\n") catch {};
    } else {
        _ = std.posix.write(std.posix.STDERR_FILENO,
            \\  skipped — keeping the legacy unit in place. You can
            \\  remove it later by rerunning `padctl install` and
            \\  answering yes, or manually:
            \\    sudo systemctl stop padctl.service
            \\    sudo systemctl disable padctl.service
            \\    sudo rm /etc/systemd/system/padctl.service
            \\    sudo rm -rf /etc/systemd/system/padctl.service.d
            \\    sudo rm -f /etc/systemd/system/padctl-resume.service
            \\
        ) catch {};
    }
}
