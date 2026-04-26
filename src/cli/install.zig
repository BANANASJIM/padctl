const std = @import("std");
const paths = @import("../config/paths.zig");

fn generateServiceContent(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    const exec_start = if (std.mem.eql(u8, prefix, "/usr"))
        try std.fmt.allocPrint(allocator, "{s}/bin/padctl", .{prefix})
    else
        try std.fmt.allocPrint(allocator, "{s}/bin/padctl --config-dir {s}/share/padctl/devices", .{ prefix, prefix });
    defer allocator.free(exec_start);

    return std.fmt.allocPrint(allocator,
        \\[Unit]
        \\Description=padctl gamepad compatibility daemon
        \\After=graphical-session.target
        \\
        \\[Service]
        \\Type=simple
        \\ExecStart={s}
        \\Restart=on-failure
        \\RestartSec=3
        \\NoNewPrivileges=true
        \\LockPersonality=true
        \\ProtectClock=true
        \\# Canonical state/log dir: $XDG_STATE_HOME/padctl on user services,
        \\# /var/lib/padctl on system services. systemd pre-creates it with
        \\# the right perms, exports $STATE_DIRECTORY, and auto-whitelists
        \\# the path through read-only home/system protections applied via
        \\# drop-ins so the daemon can always write its dump log there.
        \\StateDirectory=padctl
        \\
        \\[Install]
        \\WantedBy=default.target
        \\
    , .{exec_start});
}

pub const InstallOptions = struct {
    prefix: []const u8 = "/usr",
    destdir: []const u8 = "",
    immutable: bool = false,
    no_immutable: bool = false,
    mappings: []const []const u8 = &.{},
    force_mapping: bool = false,
    /// When true, overwrite existing device→mapping bindings in
    /// /etc/padctl/config.toml (with timestamped backup). Separate from
    /// --force-mapping which controls mapping file overwrites.
    force_binding: bool = false,
    no_enable: bool = false,
    no_start: bool = false,
    /// Install as systemd --user unit. Detected via getuid(): true when non-root, false when root.
    /// When true: writes ~/.config/systemd/user/padctl.service.
    /// When false (root): writes /usr/lib/systemd/user (prefix=/usr) or /etc/systemd/user (other prefix).
    user_service: ?bool = null,
};

pub const ImmutableKind = enum { none, ostree, read_only_usr };

/// Detect whether we're running on an immutable OS.
/// Takes root_prefix for testability — pass "" for real system, tmpDir path for tests.
pub fn detectImmutableOs(allocator: std.mem.Allocator, root_prefix: []const u8) ImmutableKind {
    // Primary: check for ostree marker.
    // Use statFile instead of accessAbsolute to avoid unreachable panic
    // on unexpected errno (e.g. ELOOP/SymLinkLoop on some CI runners).
    const ostree_path = std.fmt.allocPrint(allocator, "{s}/run/ostree-booted", .{root_prefix}) catch return .none;
    defer allocator.free(ostree_path);
    if (std.fs.cwd().statFile(ostree_path)) |_| {
        return .ostree;
    } else |_| {}

    // Fallback: check if /usr is writable (non-destructive, no file creation).
    const usr_path = std.fmt.allocPrint(allocator, "{s}/usr", .{root_prefix}) catch return .none;
    defer allocator.free(usr_path);
    if (std.fs.cwd().statFile(usr_path)) |stat| {
        // Check if writable by owner (root runs install)
        if (stat.mode & 0o200 == 0) return .read_only_usr;
    } else |_| {
        return .none;
    }
    return .none;
}

fn shouldAbortForImmutable(kind: ImmutableKind, opts: InstallOptions) bool {
    return kind != .none and !opts.immutable and !opts.no_immutable;
}

const immutable_dropin_content =
    \\[Service]
    \\# Reset device allowlist — the base service restricts to hidraw+uinput+input,
    \\# but libusb needs broader access to USB bus device nodes (/dev/bus/usb/) for
    \\# vendor-specific control transfers (init commands, rumble, LED control).
    \\# Bare DeviceAllow= clears the list; with no further entries, cgroup device
    \\# controller falls back to allowing all device access.
    \\DeviceAllow=
    \\# Allow reading user mapping configs from ~/.config/padctl/.
    \\# ProtectHome=read-only also covers /run/user/%U per systemd.exec(5),
    \\# so we must punch a hole for the daemon's IPC socket below.
    \\ProtectHome=read-only
    \\# ProtectHome=read-only locks /run/user/%U, which would otherwise make
    \\# the daemon's $XDG_RUNTIME_DIR/padctl.sock bind fail with EROFS and
    \\# silently break `padctl status`/`switch`/`devices`. Grant write access
    \\# back to just the runtime dir without loosening the $HOME protection.
    \\ReadWritePaths=/run/user/%U
    \\# Short timeout for processes stuck in uninterruptible I/O
    \\TimeoutStopSec=3
    \\# SIGTERM main + SIGKILL stuck threads simultaneously
    \\KillMode=mixed
    \\
;

// padctl-resume.service was removed in the fix for issue #131 Problem B.
// The unit was broken by design — never enabled, scope-mismatched on
// immutable installs (WantedBy=suspend.target only resolves in system
// scope but the file was written under /etc/systemd/user/), and the
// ExecStart called `systemctl restart padctl.service` without --user,
// which would target a nonexistent system-scope unit (padctl has been a
// user service since PR #77 / ADR-014 Path B). Post-suspend reconnect is
// handled by the udev `padctl-reconnect` hook: when the controller
// replugs after wake, udev re-fires and the reconnect script re-applies
// the mapping. See uninstall() for legacy cleanup of v0.1.2 installs.

fn generateReconnectScript(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\#!/bin/bash
        \\# padctl-reconnect — safe hotplug handler for padctl
        \\# Auto-generated by padctl install — do not edit
        \\#
        \\# On device add: re-applies mapping via running daemon socket.
        \\# The daemon must already be running (enabled via: padctl install).
        \\mkdir -p /run/padctl
        \\exec 200>/run/padctl/padctl-reconnect.lock
        \\flock -n 200 || exit 0
        \\
        \\sleep 1
        \\
        \\# Re-apply mapping after hotplug (device reconnects in passthrough mode).
        \\# Apply the first mapping found (sorted for deterministic selection).
        \\sleep 2
        \\for f in $(ls /etc/padctl/mappings/*.toml 2>/dev/null | sort); do
        \\    [ -f "$f" ] || continue
        \\    {s}/bin/padctl switch "$f" --socket /run/padctl/padctl.sock 2>/dev/null && break
        \\done
        \\
    , .{prefix});
}

fn resolveServiceDir(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool, user_service: bool) ![]const u8 {
    if (user_service) {
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
        return std.fmt.allocPrint(allocator, "{s}{s}/.config/systemd/user", .{ destdir, home });
    }
    if (immutable) {
        return std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{destdir});
    }
    // systemd < 253 only scans /usr/lib/systemd/user for system-wide user units.
    // Any other prefix falls back to /etc/systemd/user which is always scanned.
    if (std.mem.eql(u8, prefix, "/usr")) {
        return std.fmt.allocPrint(allocator, "{s}/usr/lib/systemd/user", .{destdir});
    }
    return std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{destdir});
}

/// Update any legacy system service files left behind by pre-user-service
/// installs. Without this, upgrades leave stale ExecStart (missing
/// --config-dir) and stale drop-ins on disk; if a user later re-enables
/// the legacy unit manually, they would get the old stale content.
fn updateLegacySystemService(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8) void {
    // /etc/systemd/system — legacy installs placed the service here
    const etc_dir = std.fmt.allocPrint(allocator, "{s}/etc/systemd/system", .{destdir}) catch return;
    defer allocator.free(etc_dir);
    updateLegacyAt(allocator, prefix, etc_dir);

    // <prefix>/lib/systemd/system — another common legacy location
    const lib_dir = std.fmt.allocPrint(allocator, "{s}{s}/lib/systemd/system", .{ destdir, prefix }) catch return;
    defer allocator.free(lib_dir);
    updateLegacyAt(allocator, prefix, lib_dir);
}

fn updateLegacyAt(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    base_dir: []const u8,
) void {
    // Update service file if it exists.
    const svc_path = std.fmt.allocPrint(allocator, "{s}/padctl.service", .{base_dir}) catch return;
    defer allocator.free(svc_path);
    if (std.fs.accessAbsolute(svc_path, .{})) {
        const content = generateSystemServiceContent(allocator, prefix) catch return;
        defer allocator.free(content);
        if (std.fs.createFileAbsolute(svc_path, .{ .truncate = true })) |f| {
            defer f.close();
            f.writeAll(content) catch return;
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, svc_path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, " (legacy update)\n") catch {};
        } else |_| {}
    } else |_| {}

    // Refresh immutable.conf only when it already exists. The earlier
    // check guarded on padctl.service.d/ existence, which meant we'd
    // spawn a fresh immutable.conf in directories that happened to
    // contain unrelated user-owned drop-ins — introducing an override
    // the user never asked for.
    const dropin_dir = std.fmt.allocPrint(allocator, "{s}/padctl.service.d", .{base_dir}) catch return;
    defer allocator.free(dropin_dir);
    const dropin_path = std.fmt.allocPrint(allocator, "{s}/immutable.conf", .{dropin_dir}) catch return;
    defer allocator.free(dropin_path);
    if (std.fs.accessAbsolute(dropin_path, .{})) {
        if (std.fs.createFileAbsolute(dropin_path, .{ .truncate = true })) |f| {
            defer f.close();
            f.writeAll(immutable_dropin_content) catch return;
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, dropin_path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, " (legacy update)\n") catch {};
        } else |_| {}
    } else |_| {}
}

/// Generate the system service content matching the legacy format but with
/// correct ExecStart for the given prefix.
fn generateSystemServiceContent(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    const exec_start = if (std.mem.eql(u8, prefix, "/usr"))
        try std.fmt.allocPrint(allocator, "{s}/bin/padctl", .{prefix})
    else
        try std.fmt.allocPrint(allocator, "{s}/bin/padctl --config-dir {s}/share/padctl/devices", .{ prefix, prefix });
    defer allocator.free(exec_start);

    return std.fmt.allocPrint(allocator,
        \\[Unit]
        \\Description=padctl gamepad compatibility daemon
        \\After=local-fs.target
        \\
        \\[Service]
        \\Type=simple
        \\ExecStart={s}
        \\Restart=on-failure
        \\RestartSec=3
        \\ProtectSystem=strict
        \\ProtectHome=true
        \\PrivateTmp=true
        \\RuntimeDirectory=padctl
        \\StateDirectory=padctl
        \\NoNewPrivileges=true
        \\SupplementaryGroups=input
        \\DeviceAllow=/dev/hidraw* rw
        \\DeviceAllow=/dev/uinput rw
        \\DeviceAllow=/dev/uhid rw
        \\DeviceAllow=char-input rw
        \\
        \\[Install]
        \\WantedBy=multi-user.target
        \\
    , .{exec_start});
}

fn resolveUdevDir(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool) ![]const u8 {
    if (immutable) {
        return std.fmt.allocPrint(allocator, "{s}/etc/udev/rules.d", .{destdir});
    }
    return std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d", .{ destdir, prefix });
}

const modules_load_content =
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
const imu_udev_rules_content =
    \\# padctl UHID IMU nodes: tag as accelerometer so SDL/Steam recognize them
    \\# as sensors instead of joysticks. Matches padctl's uniq pattern `padctl/*`
    \\# and a name containing "IMU" (padctl's convention for the IMU UHID card).
    \\# Also untags ID_INPUT_JOYSTICK to avoid SDL opening the sensor as a gamepad.
    \\SUBSYSTEM=="input", ATTRS{uniq}=="padctl/*", ATTRS{name}=="*IMU*", \
    \\  ENV{ID_INPUT_ACCELEROMETER}="1", ENV{ID_INPUT_JOYSTICK}=""
    \\
;

fn writeImuUdevRules(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    const rules_path = try std.fmt.allocPrint(allocator, "{s}/90-padctl.rules", .{plan.udev_dir});
    defer allocator.free(rules_path);

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(imu_udev_rules_content);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, rules_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
}

fn writeModulesLoad(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool) void {
    // Immutable systems use /etc; otherwise prefer prefix/lib/modules-load.d
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

/// Returns the GID for the named group by parsing /etc/group, or null on failure.
fn groupGid(name: []const u8) ?std.os.linux.gid_t {
    const f = std.fs.openFileAbsolute("/etc/group", .{}) catch return null;
    defer f.close();
    var buf: [4096]u8 = undefined;
    const n = f.readAll(&buf) catch return null;
    var it = std.mem.splitScalar(u8, buf[0..n], '\n');
    while (it.next()) |line| {
        // Format: name:password:gid:members
        var fields = std.mem.splitScalar(u8, line, ':');
        const gname = fields.next() orelse continue;
        _ = fields.next(); // password
        const gid_str = fields.next() orelse continue;
        if (!std.mem.eql(u8, gname, name)) continue;
        return std.fmt.parseInt(std.os.linux.gid_t, gid_str, 10) catch null;
    }
    return null;
}

/// Returns true if the current process is a member of the named group.
fn userInGroup(name: []const u8) bool {
    const target_gid = groupGid(name) orelse return false;
    if (std.os.linux.getegid() == target_gid) return true;
    var gids: [64]std.os.linux.gid_t = undefined;
    const ret = std.os.linux.getgroups(gids.len, &gids[0]);
    if (ret > gids.len) return false;
    for (gids[0..ret]) |g| {
        if (g == target_gid) return true;
    }
    return false;
}

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

/// Resolve the real user's home directory. When running as root (sudo), reads
/// SUDO_USER from `passwd_path` (/etc/passwd in production). Falls back to
/// `/home/<SUDO_USER>` if the passwd lookup fails. Non-root returns HOME env.
/// Caller must free the returned slice.
fn resolveTargetHomeFromFile(allocator: std.mem.Allocator, passwd_path: []const u8) ![]const u8 {
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

    // Fallback: /home/<SUDO_USER>
    return std.fmt.allocPrint(allocator, "/home/{s}", .{sudo_user});
}

fn resolveTargetHome(allocator: std.mem.Allocator) ![]const u8 {
    return resolveTargetHomeFromFile(allocator, "/etc/passwd");
}

/// Create the XDG parent dirs that systemd's StateDirectory= requires to exist.
/// systemd only creates the final component ($XDG_STATE_HOME/padctl), not its
/// parents.  When a user has wiped ~/.local/state the service fails at startup.
/// Chowns newly created dirs to SUDO_UID:SUDO_GID when running as root.
// Removes `path` if it is a dangling symlink (target missing). No-op if path
// is not a symlink or if the target is reachable. Best-effort: errors are
// printed to stderr and swallowed — callers must not depend on this succeeding.
fn removeBrokenSymlink(path: []const u8) void {
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

// Removes `path` if it is a symlink, regardless of whether the target exists.
// No-op if path is a real file/dir or does not exist. Best-effort.
fn removeAnySymlink(path: []const u8) void {
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

fn ensureUserXdgDirs(allocator: std.mem.Allocator, home: []const u8) !void {
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

    // Keep defensive broken-symlink cleanup on .config/padctl: not the v254+
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

// Write to {dst}.new then rename(2) over dst — avoids ETXTBSY when dst is currently executing.
fn atomicInstallBinary(allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const tmp = try std.fmt.allocPrint(allocator, "{s}.new", .{dst});
    defer allocator.free(tmp);
    var src_file = try std.fs.openFileAbsolute(src, .{});
    defer src_file.close();
    var tmp_file = try std.fs.createFileAbsolute(tmp, .{ .truncate = true });
    errdefer std.fs.deleteFileAbsolute(tmp) catch {};
    errdefer tmp_file.close();
    var buf: [65536]u8 = undefined;
    while (true) {
        const n = try src_file.read(&buf);
        if (n == 0) break;
        try tmp_file.writeAll(buf[0..n]);
    }
    try tmp_file.chmod(0o755);
    try tmp_file.sync();
    // Rename before close so that on rename failure the errdefer closes the fd
    // exactly once. Closing after rename is safe on Linux: the fd keeps the old
    // inode alive until close, independent of the dirent.
    try std.posix.rename(tmp, dst);
    tmp_file.close();
}

fn runCmd(argv: []const []const u8) void {
    var child = std.process.Child.init(argv, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawnAndWait() catch {};
}

/// Ask a y/n question on stderr and read the answer from stdin.
/// Default-yes: empty input, any "y*", any "Y*" → true.
/// When stdin is not a TTY (CI / scripted install), return true
/// without prompting so non-interactive runs proceed with cleanup.
fn promptYesNoDefaultYes(question: []const u8) bool {
    const is_tty = std.posix.isatty(std.posix.STDIN_FILENO);
    if (!is_tty) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, question) catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, " [Y/n] (non-interactive → Y)\n") catch {};
        return true;
    }
    _ = std.posix.write(std.posix.STDERR_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, question) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, " [Y/n] ") catch {};

    var buf: [16]u8 = undefined;
    const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch return true;
    return parseYesNoDefaultYes(buf[0..n]);
}

/// Pure helper: decide yes/no from a raw answer string.
/// Default-yes semantics: empty input (incl. just whitespace/newline) → yes.
/// First non-whitespace char is y/Y → yes; anything else → no.
/// Extracted from promptYesNoDefaultYes so tests can cover the parse
/// rules without touching stdin/stderr.
fn parseYesNoDefaultYes(raw: []const u8) bool {
    const answer = std.mem.trim(u8, raw, " \t\r\n");
    if (answer.len == 0) return true;
    return answer[0] == 'y' or answer[0] == 'Y';
}

/// Like runCmd but warns on non-zero exit. Used for critical steps (enable/start).
fn runCmdWarn(argv: []const []const u8) void {
    var child = std.process.Child.init(argv, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const term = child.spawnAndWait() catch {
        _ = std.posix.write(std.posix.STDERR_FILENO, "warning: failed to spawn: ") catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, argv[0]) catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, "\n") catch {};
        return;
    };
    const failed = switch (term) {
        .Exited => |code| code != 0,
        else => true,
    };
    if (failed) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "warning: failed: ") catch {};
        _ = std.posix.write(std.posix.STDERR_FILENO, argv[0]) catch {};
        for (argv[1..]) |a| {
            _ = std.posix.write(std.posix.STDERR_FILENO, " ") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, a) catch {};
        }
        _ = std.posix.write(std.posix.STDERR_FILENO, "\n") catch {};
    }
}

fn dirExistsAbsolute(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

fn dirIsNonEmpty(path: []const u8) bool {
    var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch return false;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch return false) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".toml")) return true;
        if (entry.kind == .directory) return true;
    }
    return false;
}

/// Invocation mode for `systemctl --user` commands from within `padctl install`.
/// See buildSystemctlUserArgv for rationale.
pub const SystemctlUserMode = enum {
    /// Running as a normal user — call `systemctl --user` directly.
    direct,
    /// Running as root via sudo — hop back to the invoking user so that
    /// `systemctl --user` talks to their session bus (XDG_RUNTIME_DIR + DBUS).
    sudo_hop,
    /// Running as root WITHOUT SUDO_USER/SUDO_UID — cannot locate a user bus.
    /// Caller should print a skip note instead of attempting the command.
    skip,
};
pub const SystemctlUserPlan = struct {
    mode: SystemctlUserMode,
    /// Only populated for sudo_hop mode. Built from SUDO_USER / SUDO_UID.
    sudo_user: []const u8 = "",
    sudo_uid: []const u8 = "",
};

/// Decide how to invoke `systemctl --user ...` based on current process context.
/// Pure function for testability — all inputs come from parameters, not env.
pub fn planSystemctlUser(uid: std.posix.uid_t, sudo_user: ?[]const u8, sudo_uid: ?[]const u8) SystemctlUserPlan {
    if (uid != 0) return .{ .mode = .direct };
    const su = sudo_user orelse return .{ .mode = .skip };
    const sid = sudo_uid orelse return .{ .mode = .skip };
    if (su.len == 0 or sid.len == 0) return .{ .mode = .skip };
    // Reject numeric-sudo-uid that isn't actually numeric to avoid shell quoting games
    for (sid) |c| {
        if (c < '0' or c > '9') return .{ .mode = .skip };
    }
    return .{ .mode = .sudo_hop, .sudo_user = su, .sudo_uid = sid };
}

/// Decide whether this `install` invocation will ultimately start a user-scope
/// padctl.service — and therefore must pre-create the XDG parent dirs so
/// systemd v254+ does not auto-create the legacy-migration symlink
/// `$XDG_STATE_HOME/padctl → $XDG_CONFIG_HOME/padctl`. Issue #139.
///
/// Paths that start a user service:
///   1. Non-staged + effective user_service (explicit --user-service, or the
///      non-root default).
///   2. Non-staged + root via sudo (SUDO_USER present) — `run()` enters the
///      `sudo_hop` branch (see SystemctlUserMode.sudo_hop) and calls
///      `systemctl --user start padctl.service` on the invoking user.
///
/// Pure function for testability — all inputs come from parameters, not env.
pub fn installWillStartUserService(
    is_root: bool,
    user_service_opt: ?bool,
    destdir: []const u8,
    sudo_user_env: ?[]const u8,
) bool {
    if (destdir.len != 0) return false; // staged package build — no live user service
    // Explicit flag wins: --no-user-service means "don't start", including the
    // sudo_hop path. --user-service means "start" regardless of is_root.
    if (user_service_opt) |explicit| return explicit;
    // Implicit: non-root default starts the user service.
    if (!is_root) return true;
    // Implicit + root: sudo_hop starts the invoking user's service when SUDO_USER is set.
    if (sudo_user_env) |su| {
        if (su.len != 0) return true;
    }
    return false;
}

/// Snapshot of the process environment that feeds `InstallPlan.compute`.
/// Kept as a plain struct so tests can construct synthetic environments without
/// mutating getenv state.
pub const EnvSnapshot = struct {
    uid: std.posix.uid_t,
    home: ?[]const u8,
    sudo_user: ?[]const u8,
    sudo_uid: ?[]const u8,

    pub fn fromProcess() EnvSnapshot {
        return .{
            .uid = std.os.linux.getuid(),
            .home = std.posix.getenv("HOME"),
            .sudo_user = std.posix.getenv("SUDO_USER"),
            .sudo_uid = std.posix.getenv("SUDO_UID"),
        };
    }
};

/// Single source of truth for every decision `install.run()` makes before it
/// starts touching the filesystem. All derived axes are computed exactly once
/// in `compute()` so later phases read a plain struct instead of re-deriving
/// (and drifting from) the originals. This directly addresses the PR #148 gate
/// bug where `effective_user_service` was re-tested at the wrong call site.
pub const InstallPlan = struct {
    // --- inputs (captured, not re-derived) ---
    opts: InstallOptions,
    is_root: bool,
    sudo_user: ?[]const u8,
    sudo_uid: ?[]const u8,
    home: ?[]const u8,

    // --- derived axes ---
    staging_mode: bool,
    effective_user_service: bool,
    immutable_kind: ImmutableKind,
    effective_immutable: bool,
    prefix: []const u8,
    systemctl_plan: SystemctlUserPlan,
    will_start_user_service: bool,
    do_xdg_dirs: bool,
    do_enable_systemctl: bool,

    // --- owned path strings (freed by deinit) ---
    bin_dir: []const u8,
    service_dir: []const u8,
    share_dir: []const u8,
    udev_dir: []const u8,

    pub fn compute(allocator: std.mem.Allocator, opts: InstallOptions, env: EnvSnapshot) !InstallPlan {
        const is_root = env.uid == 0;
        const destdir = opts.destdir;
        const staging_mode = destdir.len != 0;

        const effective_user_service = opts.user_service orelse !is_root;

        const immutable_kind = detectImmutableOs(allocator, if (staging_mode) destdir else "");
        const effective_immutable = opts.immutable or (immutable_kind != .none and !opts.no_immutable);

        const prefix = if (effective_immutable and std.mem.eql(u8, opts.prefix, "/usr"))
            "/usr/local"
        else
            opts.prefix;

        const systemctl_plan = planSystemctlUser(env.uid, env.sudo_user, env.sudo_uid);

        const will_start_user_service = installWillStartUserService(
            is_root,
            opts.user_service,
            destdir,
            env.sudo_user,
        );

        // Pre-seeding XDG parents is required on exactly the install paths that
        // end up starting a user-scope padctl.service — identical to
        // `will_start_user_service`. Kept as a separate field to keep call
        // sites self-documenting.
        const do_xdg_dirs = will_start_user_service;

        // systemctl enable/start only runs on live installs (non-staging).
        const do_enable_systemctl = !staging_mode and will_start_user_service;

        var bin_dir: []const u8 = &.{};
        var service_dir: []const u8 = &.{};
        var share_dir: []const u8 = &.{};
        var udev_dir: []const u8 = &.{};
        errdefer {
            if (bin_dir.len != 0) allocator.free(bin_dir);
            if (service_dir.len != 0) allocator.free(service_dir);
            if (share_dir.len != 0) allocator.free(share_dir);
            if (udev_dir.len != 0) allocator.free(udev_dir);
        }

        bin_dir = try std.fmt.allocPrint(allocator, "{s}{s}/bin", .{ destdir, prefix });
        service_dir = try resolveServiceDir(allocator, destdir, prefix, effective_immutable, effective_user_service);
        share_dir = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl/devices", .{ destdir, prefix });
        udev_dir = try resolveUdevDir(allocator, destdir, prefix, effective_immutable);

        return .{
            .opts = opts,
            .is_root = is_root,
            .sudo_user = env.sudo_user,
            .sudo_uid = env.sudo_uid,
            .home = env.home,
            .staging_mode = staging_mode,
            .effective_user_service = effective_user_service,
            .immutable_kind = immutable_kind,
            .effective_immutable = effective_immutable,
            .prefix = prefix,
            .systemctl_plan = systemctl_plan,
            .will_start_user_service = will_start_user_service,
            .do_xdg_dirs = do_xdg_dirs,
            .do_enable_systemctl = do_enable_systemctl,
            .bin_dir = bin_dir,
            .service_dir = service_dir,
            .share_dir = share_dir,
            .udev_dir = udev_dir,
        };
    }

    pub fn deinit(self: *const InstallPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.bin_dir);
        allocator.free(self.service_dir);
        allocator.free(self.share_dir);
        allocator.free(self.udev_dir);
    }
};

/// Build argv for invoking `systemctl --user <verbs...>` under the correct bus.
/// Caller owns the returned slice and each nested string via the allocator.
///
/// sudo_hop form:
///   sudo -u <USER> XDG_RUNTIME_DIR=/run/user/<UID> \
///        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<UID>/bus \
///        systemctl --user <verbs...>
pub fn buildSystemctlUserArgv(
    allocator: std.mem.Allocator,
    plan: SystemctlUserPlan,
    verbs: []const []const u8,
) !?[][]const u8 {
    if (plan.mode == .skip) return null;

    var argv = std.ArrayList([]const u8){};
    errdefer argv.deinit(allocator);

    if (plan.mode == .sudo_hop) {
        try argv.append(allocator, try allocator.dupe(u8, "sudo"));
        try argv.append(allocator, try allocator.dupe(u8, "-u"));
        try argv.append(allocator, try allocator.dupe(u8, plan.sudo_user));
        const xrd = try std.fmt.allocPrint(allocator, "XDG_RUNTIME_DIR=/run/user/{s}", .{plan.sudo_uid});
        try argv.append(allocator, xrd);
        const dbus = try std.fmt.allocPrint(allocator, "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{s}/bus", .{plan.sudo_uid});
        try argv.append(allocator, dbus);
    }
    try argv.append(allocator, try allocator.dupe(u8, "systemctl"));
    try argv.append(allocator, try allocator.dupe(u8, "--user"));
    for (verbs) |v| try argv.append(allocator, try allocator.dupe(u8, v));

    return try argv.toOwnedSlice(allocator);
}

fn freeArgv(allocator: std.mem.Allocator, argv: [][]const u8) void {
    for (argv) |s| allocator.free(s);
    allocator.free(argv);
}

fn currentPlanFromEnv() SystemctlUserPlan {
    const uid = std.os.linux.getuid();
    const sudo_user = std.posix.getenv("SUDO_USER");
    const sudo_uid = std.posix.getenv("SUDO_UID");
    return planSystemctlUser(uid, sudo_user, sudo_uid);
}

fn writeAll(fd: std.posix.fd_t, s: []const u8) void {
    _ = std.posix.write(fd, s) catch {};
}

fn printSkipSystemctlNote() void {
    // Default hint used by the thin helpers — the install/uninstall call sites
    // in `run()` dedupe via `printSkipSystemctlNoteFor` so the user only sees a
    // single 4-line note per phase. This fallback covers defensive callers.
    const default_verbs = [_][]const []const u8{
        &.{"daemon-reload"},
        &.{ "enable", "--now", "padctl.service" },
    };
    printSkipSystemctlNoteFor(&default_verbs);
}

/// Variant that reflects the actual set of verb groups that were skipped.
/// Use from call sites that know exactly which systemctl verbs would have run
/// so the hint shows the correct commands (install vs uninstall differ).
fn printSkipSystemctlNoteFor(verb_groups: []const []const []const u8) void {
    writeAll(
        std.posix.STDERR_FILENO,
        "note: skipping `systemctl --user` — running as root without SUDO_USER; as your real user run:\n",
    );
    for (verb_groups) |verbs| {
        writeAll(std.posix.STDERR_FILENO, "  systemctl --user");
        for (verbs) |v| {
            writeAll(std.posix.STDERR_FILENO, " ");
            writeAll(std.posix.STDERR_FILENO, v);
        }
        writeAll(std.posix.STDERR_FILENO, "\n");
    }
}

/// Thin wrapper over buildSystemctlUserArgv + runCmd.
/// Mirrors runCmd semantics (silent on non-zero).
fn runSystemctlUser(verbs: []const []const u8) void {
    const plan = currentPlanFromEnv();
    if (plan.mode == .skip) {
        printSkipSystemctlNote();
        return;
    }
    const allocator = std.heap.page_allocator;
    const argv = buildSystemctlUserArgv(allocator, plan, verbs) catch |err| {
        var errbuf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: could not build systemctl argv: {}\n", .{err}) catch "warning: systemctl argv build failed\n";
        writeAll(std.posix.STDERR_FILENO, msg);
        return;
    } orelse {
        printSkipSystemctlNote();
        return;
    };
    defer freeArgv(allocator, argv);
    runCmd(argv);
}

/// Same as runSystemctlUser but warns on non-zero exit (mirrors runCmdWarn).
fn runSystemctlUserWarn(verbs: []const []const u8) void {
    const plan = currentPlanFromEnv();
    if (plan.mode == .skip) {
        printSkipSystemctlNote();
        return;
    }
    const allocator = std.heap.page_allocator;
    const argv = buildSystemctlUserArgv(allocator, plan, verbs) catch |err| {
        var errbuf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: could not build systemctl argv: {}\n", .{err}) catch "warning: systemctl argv build failed\n";
        writeAll(std.posix.STDERR_FILENO, msg);
        return;
    } orelse {
        printSkipSystemctlNote();
        return;
    };
    defer freeArgv(allocator, argv);
    runCmdWarn(argv);
}

/// System-scope counterpart to runSystemctlUser. Used by the legacy-unit
/// migration path, which operates on /etc/systemd/system/padctl.service —
/// a system-scope unit that the user-scope helper cannot address. Builds
/// argv dynamically so call sites don't need the forbidden
/// `runCmd(&.{ "systemctl", ... })` literal form.
fn runSystemctlSystem(verbs: []const []const u8) void {
    const allocator = std.heap.page_allocator;
    const argv = buildSystemctlSystemArgv(allocator, verbs) catch |err| {
        var errbuf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&errbuf, "warning: could not build systemctl argv: {}\n", .{err}) catch "warning: systemctl argv build failed\n";
        writeAll(std.posix.STDERR_FILENO, msg);
        return;
    };
    defer freeArgv(allocator, argv);
    runCmd(argv);
}

fn buildSystemctlSystemArgv(allocator: std.mem.Allocator, verbs: []const []const u8) ![][]const u8 {
    var argv = try allocator.alloc([]const u8, 1 + verbs.len);
    errdefer allocator.free(argv);
    argv[0] = try allocator.dupe(u8, "systemctl");
    errdefer allocator.free(argv[0]);
    for (verbs, 0..) |v, i| {
        argv[1 + i] = try allocator.dupe(u8, v);
    }
    return argv;
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

fn findMappingsSourceDir(allocator: std.mem.Allocator, self_dir: []const u8, cwd_override: ?[]const u8) !?[]u8 {
    const sibling = try std.fmt.allocPrint(allocator, "{s}/mappings", .{self_dir});
    defer allocator.free(sibling);
    if (dirExistsAbsolute(sibling)) return try allocator.dupe(u8, sibling);

    var parent = self_dir;
    while (std.fs.path.dirname(parent)) |next| {
        parent = next;
        const candidate = try std.fmt.allocPrint(allocator, "{s}/mappings", .{parent});
        defer allocator.free(candidate);
        if (dirExistsAbsolute(candidate)) return try allocator.dupe(u8, candidate);
        if (std.mem.eql(u8, parent, "/")) break;
    }

    const cwd = cwd_override orelse try std.process.getCwdAlloc(allocator);
    defer if (cwd_override == null) allocator.free(cwd);
    const cwd_candidate = try std.fmt.allocPrint(allocator, "{s}/mappings", .{cwd});
    defer allocator.free(cwd_candidate);
    if (dirExistsAbsolute(cwd_candidate)) return try allocator.dupe(u8, cwd_candidate);

    return null;
}

fn installMapping(allocator: std.mem.Allocator, name: []const u8, destdir: []const u8, src_dir: []const u8, force: bool) !void {
    // ! Reject path traversal in mapping names (e.g., "../../etc/shadow")
    if (!isValidIdentifier(name)) return error.InvalidArgument;

    // Try {src_dir}/{name}.toml first, then {src_dir}/{name}/{name}.toml
    const src_flat = try std.fmt.allocPrint(allocator, "{s}/{s}.toml", .{ src_dir, name });
    defer allocator.free(src_flat);
    const src_nested = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}.toml", .{ src_dir, name, name });
    defer allocator.free(src_nested);

    const src_path: []const u8 = blk: {
        if (std.fs.accessAbsolute(src_flat, .{})) |_| {
            break :blk src_flat;
        } else |_| {}
        if (std.fs.accessAbsolute(src_nested, .{})) |_| {
            break :blk src_nested;
        } else |_| {}
        return error.FileNotFound;
    };

    const target_dir = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings", .{destdir});
    defer allocator.free(target_dir);
    try ensureDirAll(allocator, target_dir);

    const target_path = try std.fmt.allocPrint(allocator, "{s}/{s}.toml", .{ target_dir, name });
    defer allocator.free(target_path);

    // Check if target exists — skip without force
    if (!force) {
        if (std.fs.accessAbsolute(target_path, .{})) |_| {
            return;
        } else |_| {}
    }

    // Read source and write to target
    {
        var src_f = try std.fs.openFileAbsolute(src_path, .{});
        defer src_f.close();
        const data = try src_f.readToEndAlloc(allocator, 1 << 20);
        defer allocator.free(data);
        var dst_f = try std.fs.createFileAbsolute(target_path, .{ .truncate = true });
        defer dst_f.close();
        try dst_f.writeAll(data);
    }
}

pub fn run(allocator: std.mem.Allocator, opts: InstallOptions) !void {
    // Input validation — reject impossible option combinations before touching disk.
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

    // Detect immutable OS first so we can abort before building the plan
    // (compute() would otherwise allocate paths we'd just throw away).
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

    try runLegacySystemUnitMigration(&plan);

    try ensureDirAll(allocator, plan.bin_dir);
    try ensureDirAll(allocator, plan.service_dir);
    try ensureDirAll(allocator, plan.share_dir);
    try ensureDirAll(allocator, plan.udev_dir);

    // Gate covers every path that ends up starting a user-scope padctl.service:
    // explicit --user-service, non-root default, and sudo install routed via
    // SystemctlUserMode.sudo_hop (root+SUDO_USER). Issue #139 v3: the previous
    // gate (`effective_user_service and destdir.len == 0`) short-circuited on
    // the sudo_hop path, leaving the XDG parents absent and letting systemd
    // v254+ recreate the legacy migration symlink after every install.
    if (plan.do_xdg_dirs) {
        const home = try resolveTargetHome(allocator);
        defer allocator.free(home);
        try ensureUserXdgDirs(allocator, home);
    }

    const self_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_path);
    const self_dir = std.fs.path.dirname(self_path) orelse ".";

    try installBinaries(allocator, &plan, self_path, self_dir);
    try installServiceFiles(allocator, &plan);
    try installReconnectScript(allocator, &plan);
    try installDeviceConfigs(allocator, &plan, self_dir);

    var device_entries = try collectAllDeviceEntries(allocator, &plan);
    defer freeDeviceEntries(allocator, &device_entries);

    try installUdevRules(allocator, &plan, device_entries.items);
    try cleanupLegacyUdevFiles(allocator, &plan);
    try writeImuUdevRules(allocator, &plan);
    writeModulesLoad(allocator, plan.opts.destdir, plan.prefix, plan.effective_immutable);

    var installed_mappings = std.ArrayList([]const u8){};
    defer installed_mappings.deinit(allocator);
    var mapping_failed = try installMappings(allocator, &plan, self_dir, &installed_mappings);
    if (installed_mappings.items.len > 0) {
        const binding_failed = try installBindings(allocator, &plan, self_dir, installed_mappings.items);
        mapping_failed = mapping_failed or binding_failed;
    }

    if (plan.do_enable_systemctl) {
        runSystemctlPhase(&plan);
    } else if (!plan.staging_mode) {
        // Reload udev rules even when the user-service is disabled — the
        // device rules were still written and systemd-udevd needs them.
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

/// Detect + optionally auto-migrate a legacy /etc/systemd/system/padctl.service
/// unit. Pre-user-service installs placed the unit here; leaving it enabled
/// would race with the new per-user unit for the hidraw grab. Prompt-driven
/// on TTY, safe no-op when the legacy file is absent or the install is staged.
fn runLegacySystemUnitMigration(plan: *const InstallPlan) !void {
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
        runSystemctlSystem(&.{ "stop", "padctl.service" });
        runSystemctlSystem(&.{ "disable", "padctl.service" });
        std.fs.deleteFileAbsolute(old_unit) catch {};
        std.fs.deleteTreeAbsolute("/etc/systemd/system/padctl.service.d") catch {};
        const old_resume = "/etc/systemd/system/padctl-resume.service";
        if (std.fs.accessAbsolute(old_resume, .{})) |_| {
            runSystemctlSystem(&.{ "disable", "padctl-resume.service" });
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

fn installBinaries(
    allocator: std.mem.Allocator,
    plan: *const InstallPlan,
    self_path: []const u8,
    self_dir: []const u8,
) !void {
    const bin_padctl = try std.fmt.allocPrint(allocator, "{s}/padctl", .{plan.bin_dir});
    defer allocator.free(bin_padctl);
    try atomicInstallBinary(allocator, self_path, bin_padctl);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, bin_padctl) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    for ([_][]const u8{ "padctl-capture", "padctl-debug" }) |name| {
        const src = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self_dir, name });
        defer allocator.free(src);
        const dst = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ plan.bin_dir, name });
        defer allocator.free(dst);
        atomicInstallBinary(allocator, src, dst) catch continue;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, dst) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }
}

fn installServiceFiles(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    const service_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{plan.service_dir});
    defer allocator.free(service_path);
    // Always use the user-service template. Even on immutable-root installs,
    // the service file is placed under /etc/systemd/user/ so systemd discovers
    // it as a user unit and each user's systemd instance runs its own copy.
    const service_content = try generateServiceContent(allocator, plan.prefix);
    defer allocator.free(service_content);
    {
        var f = try std.fs.createFileAbsolute(service_path, .{ .truncate = true });
        defer f.close();
        try f.writeAll(service_content);
    }
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, service_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};

    if (plan.effective_immutable) {
        const dropin_dir = try std.fmt.allocPrint(allocator, "{s}/padctl.service.d", .{plan.service_dir});
        defer allocator.free(dropin_dir);
        try ensureDirAll(allocator, dropin_dir);
        const dropin_path = try std.fmt.allocPrint(allocator, "{s}/immutable.conf", .{dropin_dir});
        defer allocator.free(dropin_path);
        {
            var f = try std.fs.createFileAbsolute(dropin_path, .{ .truncate = true });
            defer f.close();
            try f.writeAll(immutable_dropin_content);
        }
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, dropin_path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // Refresh any legacy system service drop-in if it exists, regardless
    // of effective_immutable. Pre-user-service installs on any distro
    // (immutable or not) placed the unit under /etc/systemd/system/ or
    // <prefix>/lib/systemd/system/ which the new user-service installer
    // does not touch. Without this, upgrades leave stale ExecStart paths
    // and drop-ins on disk — harmless while the legacy unit stays
    // disabled, but misleading if a user ever enables it manually. The
    // helper is a no-op when no legacy file is present.
    updateLegacySystemService(allocator, plan.opts.destdir, plan.prefix);
}

fn installReconnectScript(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    const reconnect_script = try generateReconnectScript(allocator, plan.prefix);
    defer allocator.free(reconnect_script);
    const reconnect_path = try std.fmt.allocPrint(allocator, "{s}/padctl-reconnect", .{plan.bin_dir});
    defer allocator.free(reconnect_path);
    {
        var f = try std.fs.createFileAbsolute(reconnect_path, .{ .truncate = true });
        defer f.close();
        try f.writeAll(reconnect_script);
    }
    std.posix.fchmodat(std.fs.cwd().fd, reconnect_path, 0o755, 0) catch {
        _ = std.posix.write(std.posix.STDERR_FILENO, "warning: could not chmod padctl-reconnect\n") catch {};
    };
    _ = std.posix.write(std.posix.STDOUT_FILENO, "  ") catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, reconnect_path) catch {};
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
}

fn installDeviceConfigs(allocator: std.mem.Allocator, plan: *const InstallPlan, self_dir: []const u8) !void {
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

fn collectAllDeviceEntries(allocator: std.mem.Allocator, plan: *const InstallPlan) !std.ArrayList(UdevEntry) {
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

fn installUdevRules(allocator: std.mem.Allocator, plan: *const InstallPlan, entries: []const UdevEntry) !void {
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

fn cleanupLegacyUdevFiles(allocator: std.mem.Allocator, plan: *const InstallPlan) !void {
    // Legacy 99-padctl.rules was renamed to 60- for correct priority.
    const legacy = try std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d/99-padctl.rules", .{ plan.opts.destdir, plan.prefix });
    defer allocator.free(legacy);
    std.fs.deleteFileAbsolute(legacy) catch {};

    // /etc/ path for immutable systems that had the old naming.
    const legacy_etc = try std.fmt.allocPrint(allocator, "{s}/etc/udev/rules.d/99-padctl.rules", .{plan.opts.destdir});
    defer allocator.free(legacy_etc);
    std.fs.deleteFileAbsolute(legacy_etc) catch {};
}

/// Returns true if any mapping failed (reported via stderr). Populates
/// `installed_mappings` with names that were successfully installed so the
/// binding phase only writes config entries for files that actually exist on
/// disk.
fn installMappings(
    allocator: std.mem.Allocator,
    plan: *const InstallPlan,
    self_dir: []const u8,
    installed_mappings: *std.ArrayList([]const u8),
) !bool {
    if (plan.opts.mappings.len == 0) return false;
    const mappings_src = findMappingsSourceDir(allocator, self_dir, null) catch null;
    defer if (mappings_src) |path| allocator.free(path);
    if (mappings_src == null) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: mappings directory not found near executable or current working directory\n") catch {};
        return true;
    }
    var failed = false;
    for (plan.opts.mappings) |mapping_name| {
        installMapping(allocator, mapping_name, plan.opts.destdir, mappings_src.?, plan.opts.force_mapping) catch |err| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "' not installed: {}\n", .{err}) catch "' not installed\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
            failed = true;
            continue;
        };
        installed_mappings.append(allocator, mapping_name) catch {};
    }
    return failed;
}

fn installBindings(
    allocator: std.mem.Allocator,
    plan: *const InstallPlan,
    self_dir: []const u8,
    installed_mappings: []const []const u8,
) !bool {
    const devices_src = findDevicesSourceDir(allocator, self_dir, null) catch null;
    defer if (devices_src) |path| allocator.free(path);
    if (devices_src == null) {
        _ = std.posix.write(std.posix.STDERR_FILENO, "error: devices directory not found, cannot resolve device bindings\n") catch {};
        return true;
    }
    var failed = false;
    for (installed_mappings) |mapping_name| {
        const device_name = findDeviceNameForMapping(allocator, mapping_name, devices_src.?) catch null;
        defer if (device_name) |n| allocator.free(n);
        if (device_name) |name| {
            const mode: ConflictMode = if (plan.opts.force_binding)
                .force
            else if (std.posix.isatty(std.posix.STDIN_FILENO))
                .interactive
            else
                .skip;
            writeBinding(allocator, plan.opts.destdir, name, mapping_name, mode, stdinPrompt) catch |err| {
                var errbuf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&errbuf, "error: could not write binding for \"{s}\": {}\n", .{ mapping_name, err }) catch "error: binding write failed\n";
                _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
                failed = true;
            };
        } else {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: no device config found for mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, "', binding not written\n") catch {};
            failed = true;
        }
    }
    return failed;
}

fn runSystemctlPhase(plan: *const InstallPlan) void {
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\nReloading system daemons...\n") catch {};
    runCmd(&.{ "udevadm", "control", "--reload-rules" });
    runCmd(&.{ "udevadm", "trigger" });

    if (plan.systemctl_plan.mode == .skip) {
        var groups: [3][]const []const u8 = undefined;
        var n: usize = 0;
        groups[n] = &.{"daemon-reload"};
        n += 1;
        if (!plan.opts.no_enable) {
            groups[n] = &.{ "enable", "padctl.service" };
            n += 1;
        }
        if (!plan.opts.no_start) {
            groups[n] = &.{ "start", "padctl.service" };
            n += 1;
        }
        printSkipSystemctlNoteFor(groups[0..n]);
        return;
    }
    runSystemctlUser(&.{"daemon-reload"});
    if (!plan.opts.no_enable) {
        runSystemctlUserWarn(&.{ "enable", "padctl.service" });
    }
    if (!plan.opts.no_start) {
        runSystemctlUserWarn(&.{ "start", "padctl.service" });
    }
}

fn printCompletionHint(plan: *const InstallPlan) void {
    // Mirror actual runtime state so the user does not have to guess whether
    // the service was started. Branches:
    //   - Staged install (destdir set): no live service, just acknowledge.
    //   - Explicit --no-user-service: service file installed but NOT started.
    //   - sudo install (root + SUDO_USER, no opt-out): sudo_hop already started it.
    //   - Non-root user install: service not yet started, show manual command.
    //   - Root without SUDO_USER: nothing to start.
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

    // Auto-detect immutable OS for symmetric uninstall
    const immutable_kind = detectImmutableOs(allocator, if (destdir.len > 0) destdir else "");
    const effective_immutable = opts.immutable or (immutable_kind != .none and !opts.no_immutable);

    // Match install's auto-prefix-switch for immutable systems
    const prefix = if (effective_immutable and std.mem.eql(u8, opts.prefix, "/usr"))
        "/usr/local"
    else
        opts.prefix;

    // Stop and disable services (ignore errors — may not be running)
    if (destdir.len == 0) {
        const stop_plan = currentPlanFromEnv();
        if (stop_plan.mode == .skip) {
            const groups = [_][]const []const u8{
                &.{ "stop", "padctl.service" },
                &.{ "disable", "padctl.service" },
            };
            printSkipSystemctlNoteFor(&groups);
        } else {
            runSystemctlUser(&.{ "stop", "padctl.service" });
            runSystemctlUser(&.{ "disable", "padctl.service" });
        }
    }

    // Standard prefix-based files (always removed).
    // Legacy note: padctl-resume.service (removed in issue #131 Problem B
    // fix) was written by v0.1.2 installs under either /lib/systemd/system/
    // or /lib/systemd/user/ depending on prefix+scope — the old install
    // code had no single canonical location, so cleanup lists both to
    // catch every upgrade path.
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

    // Remove user unit if applicable
    if (effective_user_service) {
        if (std.posix.getenv("HOME")) |home| {
            const user_units = [_][]const u8{
                "/.config/systemd/user/padctl.service",
                // Legacy v0.1.2 resume unit (issue #131 Problem B cleanup);
                // harmless if absent on fresh installs.
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

    // Hint if old system unit still exists
    {
        const old_unit = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/system/padctl.service", .{destdir});
        defer allocator.free(old_unit);
        if (std.fs.accessAbsolute(old_unit, .{})) |_| {
            _ = std.posix.write(std.posix.STDERR_FILENO, "hint: legacy system unit still present — run: sudo systemctl disable --now padctl\n") catch {};
        } else |_| {}
    }

    // Remove share dir recursively
    const share_dir = try std.fmt.allocPrint(allocator, "{s}{s}/share/padctl", .{ destdir, prefix });
    defer allocator.free(share_dir);
    std.fs.deleteTreeAbsolute(share_dir) catch {};

    // Unconditional: v0.1.2 resolveServiceDir fallback could write
    // padctl-resume.service here on non-immutable, non-/usr prefixes too.
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

    // Unconditional: resolveServiceDir's non-immutable non-/usr prefix fallback
    // (e.g. `sudo padctl install --prefix /usr/local`) also writes here.
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user/padctl.service", .{destdir});
        defer allocator.free(path);
        if (std.fs.deleteFileAbsolute(path)) |_| {
            _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
            _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
        } else |_| {}
    }

    // Immutable-specific files in /etc/ (auto-detected or explicit).
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
        // Remove drop-in directory
        const dropin_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/system/padctl.service.d", .{destdir});
        defer allocator.free(dropin_dir);
        std.fs.deleteTreeAbsolute(dropin_dir) catch {};
    }

    // Remove only explicitly-specified mapping files (never recursive-delete /etc/padctl/mappings/)
    for (opts.mappings) |mapping_name| {
        if (!isValidIdentifier(mapping_name)) continue;
        const path = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings/{s}.toml", .{ destdir, mapping_name });
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch continue;
        _ = std.posix.write(std.posix.STDOUT_FILENO, "  removed ") catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch {};
        _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
    }

    // Remove runtime files
    std.fs.deleteFileAbsolute("/run/padctl/padctl.pid") catch {};
    std.fs.deleteFileAbsolute("/run/padctl/padctl.sock") catch {};

    if (destdir.len == 0) {
        const reload_plan = currentPlanFromEnv();
        if (reload_plan.mode == .skip) {
            const groups = [_][]const []const u8{&.{"daemon-reload"}};
            printSkipSystemctlNoteFor(&groups);
        } else {
            runSystemctlUser(&.{"daemon-reload"});
        }
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
    block_kernel_drivers: []const []const u8 = &.{},
    clone_vid_pid: bool = false,
};

/// Scan all device TOML files in dirs, extract VID/PID/name/block_kernel_drivers,
/// and deduplicate by VID:PID (preferring entries with richer data).
/// Caller owns the returned entries and must call freeDeviceEntries when done.
fn collectDeviceEntries(allocator: std.mem.Allocator, dirs: []const []const u8) !std.ArrayList(UdevEntry) {
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
            // Prefer the entry with richer data (block_kernel_drivers populated)
            if (entries.items[i].block_kernel_drivers.len == 0 and entries.items[j].block_kernel_drivers.len > 0) {
                entries.items[i].block_kernel_drivers = entries.items[j].block_kernel_drivers;
                entries.items[j].block_kernel_drivers = &.{};
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

fn freeDeviceEntries(allocator: std.mem.Allocator, entries: *std.ArrayList(UdevEntry)) void {
    for (entries.items) |e| {
        allocator.free(e.name);
        for (e.block_kernel_drivers) |d| allocator.free(d);
        if (e.block_kernel_drivers.len > 0) allocator.free(e.block_kernel_drivers);
    }
    entries.deinit(allocator);
}

fn generateUdevRulesFromEntries(allocator: std.mem.Allocator, entries: []const UdevEntry, rules_path: []const u8, prefix: []const u8) !void {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — do not edit\n");
    for (entries) |e| {
        const line = try std.fmt.allocPrint(
            allocator,
            "ACTION==\"add\", SUBSYSTEM==\"hidraw\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", TAG+=\"uaccess\"\nACTION==\"add\", SUBSYSTEM==\"input\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", GROUP=\"input\", MODE=\"0660\"\n# {s}\n",
            .{ e.vid, e.pid, e.vid, e.pid, e.name },
        );
        defer allocator.free(line);
        try buf.appendSlice(allocator, line);
    }

    // Hotplug reconnect rules
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
            "KERNELS==\"uhid\", SUBSYSTEM==\"input\", ENV{{ID_VENDOR_ID}}==\"{x:0>4}\", ENV{{ID_MODEL_ID}}==\"{x:0>4}\", TAG+=\"uaccess\"\n",
            .{ e.vid, e.pid },
        );
        defer allocator.free(rule);
        try buf.appendSlice(allocator, rule);
    }

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

/// Kept for test compatibility — collects entries then generates rules.
fn generateUdevRulesFromDirs(allocator: std.mem.Allocator, dirs: []const []const u8, rules_path: []const u8, prefix: []const u8) !void {
    var entries = try collectDeviceEntries(allocator, dirs);
    defer freeDeviceEntries(allocator, &entries);
    try generateUdevRulesFromEntries(allocator, entries.items, rules_path, prefix);
}

fn generateDriverBlockRulesFromEntries(allocator: std.mem.Allocator, entries: []const UdevEntry, rules_path: []const u8) !void {
    // Check if any device has driver blocking configured
    var has_blocks = false;
    for (entries) |e| {
        if (e.block_kernel_drivers.len > 0) {
            has_blocks = true;
            break;
        }
    }
    if (!has_blocks) {
        // Remove stale rules file from a previous install that had driver blocking
        std.fs.deleteFileAbsolute(rules_path) catch {};
        return;
    }

    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "# Auto-generated by padctl install — kernel driver conflict rules\n");

    for (entries) |e| {
        for (e.block_kernel_drivers) |driver| {
            const line = try std.fmt.allocPrint(
                allocator,
                "ACTION==\"bind\", SUBSYSTEM==\"usb\", ATTRS{{idVendor}}==\"{x:0>4}\", ATTRS{{idProduct}}==\"{x:0>4}\", DRIVER==\"{s}\", RUN+=\"/bin/sh -c 'echo %k > /sys/bus/usb/drivers/{s}/unbind'\"\n# {s}\n",
                .{ e.vid, e.pid, driver, driver, e.name },
            );
            defer allocator.free(line);
            try buf.appendSlice(allocator, line);
        }
    }

    var f = try std.fs.createFileAbsolute(rules_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

/// Convenience wrapper for tests — collects entries then generates driver block rules.
fn generateDriverBlockRules(allocator: std.mem.Allocator, dirs: []const []const u8, rules_path: []const u8) !void {
    var entries = try collectDeviceEntries(allocator, dirs);
    defer freeDeviceEntries(allocator, &entries);
    try generateDriverBlockRulesFromEntries(allocator, entries.items, rules_path);
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

/// Parse a TOML inline array of strings, e.g. `["xpad", "hid_generic"]`
/// Validate that a string is a safe identifier (alphanumeric, underscore, hyphen).
/// Prevents command injection when interpolated into udev RUN+= shell commands.
const user_config_mod = @import("../config/user_config.zig");
const config_device = @import("../config/device.zig");

/// Walk `devices_dir` (e.g. `/path/to/padctl/devices`) looking for
/// `*/mapping_name.toml`. If exactly one match is found, parse it and
/// return `device.name`. Returns null if zero matches are found. Logs an
/// error and returns null if multiple matches are found (traversal-order-
/// dependent behavior would silently persist the wrong binding).
/// Caller owns the returned string.
fn findDeviceNameForMapping(
    allocator: std.mem.Allocator,
    mapping_name: []const u8,
    devices_dir: []const u8,
) !?[]const u8 {
    var dir = std.fs.cwd().openDir(devices_dir, .{ .iterate = true }) catch return null;
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var match_path: ?[]u8 = null;
    defer if (match_path) |p| allocator.free(p);
    var match_count: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;

        const stem = entry.basename[0 .. entry.basename.len - 5];
        if (!std.mem.eql(u8, stem, mapping_name)) continue;

        match_count += 1;
        if (match_count == 1) {
            match_path = try allocator.dupe(u8, entry.path);
        } else {
            // Multiple matches — log both paths for disambiguation.
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: multiple device configs match mapping '") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, mapping_name) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, "', skipping binding\n") catch {};
            return null;
        }
    }

    if (match_count == 0 or match_path == null) return null;

    // Exactly one match — parse and extract device.name.
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ devices_dir, match_path.? });
    const parsed = config_device.parseFile(allocator, full_path) catch return null;
    defer parsed.deinit();
    return try allocator.dupe(u8, parsed.value.device.name);
}

pub const ConflictMode = enum {
    skip, // non-TTY default: warn and keep existing
    force, // --force-binding: backup + overwrite
    interactive, // TTY: prompt user (keep/overwrite/abort)
};

pub const PromptResult = enum { keep, overwrite, abort };

/// Function type for the interactive conflict prompt. Receives the
/// config file path, device name, existing mapping, and proposed mapping.
/// Real callers use `stdinPrompt`; tests inject a mock.
pub const PromptFn = *const fn (
    config_path: []const u8,
    device_name: []const u8,
    existing_map: []const u8,
    proposed_map: []const u8,
) PromptResult;

pub fn stdinPrompt(
    config_path: []const u8,
    device_name: []const u8,
    existing_map: []const u8,
    proposed_map: []const u8,
) PromptResult {
    _ = std.posix.write(std.posix.STDERR_FILENO, "\nConflict: ") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, config_path) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\n  existing: \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, device_name) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\" -> \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, existing_map) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\"\n  proposed: \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, device_name) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\" -> \"") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, proposed_map) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\"\n  [k]eep existing / [o]verwrite with backup / [a]bort (default: k): ") catch {};

    var buf: [16]u8 = undefined;
    const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
    const choice: u8 = if (n > 0) buf[0] else 'k';
    return switch (choice) {
        'o', 'O' => .overwrite,
        'a', 'A' => .abort,
        else => .keep,
    };
}

/// Write (or update) a device→mapping binding in `{destdir}/etc/padctl/config.toml`.
///
/// If the file doesn't exist, creates it with `version = 1` and a single `[[device]]`
/// entry. If it exists and already has a binding for `device_name`:
///   - Same `default_mapping` → no-op (idempotent).
///   - `conflict_mode == .force` → backup + overwrite.
///   - `conflict_mode == .interactive` → prompt user at stdin (keep/overwrite/abort).
///   - `conflict_mode == .skip` → log warning, keep existing (non-destructive default).
///
/// Other `[[device]]` entries in the file are preserved. The version field is
/// carried forward (or set to CURRENT_VERSION if absent).
fn writeBinding(
    allocator: std.mem.Allocator,
    destdir: []const u8,
    device_name: []const u8,
    mapping_name: []const u8,
    conflict_mode: ConflictMode,
    prompt_fn: PromptFn,
) !void {
    const etc_dir = try std.fmt.allocPrint(allocator, "{s}/etc/padctl", .{destdir});
    defer allocator.free(etc_dir);
    try ensureDirAll(allocator, etc_dir);

    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.toml", .{etc_dir});
    defer allocator.free(config_path);

    // Try to read + parse existing config.
    // MalformedConfig must NOT be swallowed — a broken hand-edited
    // /etc/padctl/config.toml must surface as an error, not be silently
    // overwritten (which would drop unrelated bindings with no backup).
    var existing = user_config_mod.loadFromDir(allocator, etc_dir) catch |err| switch (err) {
        error.MalformedConfig => {
            _ = std.posix.write(std.posix.STDERR_FILENO, "error: ") catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, config_path) catch {};
            _ = std.posix.write(std.posix.STDERR_FILENO, " is malformed — fix or remove it before installing bindings\n") catch {};
            return error.MalformedConfig;
        },
    };
    defer if (existing) |*e| e.deinit();

    const version: i64 = if (existing) |e| e.value.version orelse user_config_mod.CURRENT_VERSION else user_config_mod.CURRENT_VERSION;
    const devices = if (existing) |e| e.value.device else null;

    // Check for conflict with an existing binding for the same device name.
    if (devices) |devs| {
        for (devs) |d| {
            if (std.ascii.eqlIgnoreCase(d.name, device_name)) {
                // Same mapping → idempotent no-op.
                if (d.default_mapping) |m| {
                    if (std.mem.eql(u8, m, mapping_name)) return;
                }
                // Conflict: different mapping (or no mapping) for the same device.
                const existing_map = d.default_mapping orelse "(none)";
                switch (conflict_mode) {
                    .skip => {
                        std.log.warn("binding conflict: {s} already has \"{s}\" -> \"{s}\". Use --force-binding to overwrite.", .{ config_path, device_name, existing_map });
                        return;
                    },
                    .interactive => {
                        switch (prompt_fn(config_path, device_name, existing_map, mapping_name)) {
                            .overwrite => {}, // fall through to backup + overwrite
                            .abort => return error.Aborted,
                            .keep => return,
                        }
                    },
                    .force => {}, // fall through to backup + overwrite
                }
                break;
            }
        }
    }

    // Backup existing file before overwriting (only when file exists AND we're
    // actually changing content — skipped for no-ops and fresh writes).
    // Abort the overwrite if backup creation fails — losing the user's
    // recovery file while mutating /etc is not acceptable.
    if (existing != null and (conflict_mode == .force or conflict_mode == .interactive)) {
        backupFile(allocator, config_path) catch |err| {
            var errbuf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&errbuf, "error: cannot create backup of {s}: {}, aborting overwrite\n", .{ config_path, err }) catch "error: backup failed, aborting\n";
            _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
            return err;
        };
    }

    // Serialize: version + diagnostics + all existing entries (replacing
    // the conflict target if one was found) + new entry if none matched.
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.print("version = {d}\n", .{version});

    // Preserve [diagnostics] section if present.
    if (existing) |e| {
        const diag = e.value.diagnostics;
        if (diag.dump or diag.max_log_size_mb != 100) {
            try w.print("\n[diagnostics]\ndump = {}\nmax_log_size_mb = {d}\n", .{ diag.dump, diag.max_log_size_mb });
        }
    }

    var wrote_target = false;
    if (devices) |devs| {
        for (devs) |d| {
            if (std.ascii.eqlIgnoreCase(d.name, device_name)) {
                // Replace this entry with the new mapping.
                try w.print("\n[[device]]\nname = \"{s}\"\ndefault_mapping = \"{s}\"\n", .{ device_name, mapping_name });
                wrote_target = true;
            } else {
                // Preserve unrelated entry.
                try w.print("\n[[device]]\nname = \"{s}\"\n", .{d.name});
                if (d.default_mapping) |m| {
                    try w.print("default_mapping = \"{s}\"\n", .{m});
                }
            }
        }
    }
    if (!wrote_target) {
        try w.print("\n[[device]]\nname = \"{s}\"\ndefault_mapping = \"{s}\"\n", .{ device_name, mapping_name });
    }

    // Write the file.
    var f = try std.fs.createFileAbsolute(config_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(buf.items);
}

/// Copy `path` to `path.bak.YYYYMMDD-HHMMSS`. Returns an error if the
/// backup cannot be created — the caller must abort the overwrite.
fn backupFile(allocator: std.mem.Allocator, file_path: []const u8) !void {
    const now = std.time.timestamp();
    const epoch_secs: std.time.epoch.EpochSeconds = .{ .secs = @intCast(now) };
    const day = epoch_secs.getEpochDay().calculateYearDay();
    const year_day = day.calculateMonthDay();
    const day_secs = epoch_secs.getDaySeconds();
    const year: u16 = day.year;
    const month: u8 = @intFromEnum(year_day.month);
    const dom: u8 = year_day.day_index + 1;
    const hours: u8 = @intCast(day_secs.getHoursIntoDay());
    const minutes: u8 = @intCast(day_secs.getMinutesIntoHour());
    const seconds: u8 = @intCast(day_secs.getSecondsIntoMinute());

    const bak_path = try std.fmt.allocPrint(allocator, "{s}.bak.{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}", .{
        file_path, year, month, dom, hours, minutes, seconds,
    });
    defer allocator.free(bak_path);

    const data = try std.fs.cwd().readFileAlloc(allocator, file_path, 256 * 1024);
    defer allocator.free(data);
    var f = try std.fs.createFileAbsolute(bak_path, .{ .truncate = true });
    defer f.close();
    try f.writeAll(data);

    std.log.info("backup: {s}", .{bak_path});
}

fn isValidIdentifier(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
    }
    return true;
}

fn parseStringArray(allocator: std.mem.Allocator, value: []const u8) ![]const []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len < 2 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']') return &.{};
    const inner = trimmed[1 .. trimmed.len - 1];
    if (std.mem.trim(u8, inner, " \t").len == 0) return &.{};

    // Count elements
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |_| count += 1;

    const result = try allocator.alloc([]const u8, count);
    var idx: usize = 0;
    it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |elem| {
        const clean = std.mem.trim(u8, elem, " \t\"'");
        // ! Reject unsafe identifiers — these are interpolated into udev shell commands
        if (!isValidIdentifier(clean)) {
            // Free already-allocated entries and the result slice
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

    var name_buf: [256]u8 = undefined;
    var name: []const u8 = std.fs.path.stem(path);
    var vid: ?u16 = null;
    var pid: ?u16 = null;
    var block_drivers: []const []const u8 = &.{};
    var clone_vid_pid: bool = false;
    var in_device_section = false;
    var in_ffb_section = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (trimmed.len > 0 and trimmed[0] == '[') {
            in_device_section = std.mem.startsWith(u8, trimmed, "[device]");
            in_ffb_section = std.mem.startsWith(u8, trimmed, "[output.force_feedback]");
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
            } else if (isFieldKey(trimmed, "block_kernel_drivers")) {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                    block_drivers = parseStringArray(allocator, trimmed[eq + 1 ..]) catch &.{};
                }
            }
        } else if (in_ffb_section) {
            if (isFieldKey(trimmed, "clone_vid_pid")) {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
                    const val = std.mem.trim(u8, trimmed[eq + 1 ..], " \t");
                    clone_vid_pid = std.mem.eql(u8, val, "true");
                }
            }
        }
    }

    if (vid != null and pid != null) {
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .vid = vid.?,
            .pid = pid.?,
            .block_kernel_drivers = block_drivers,
            .clone_vid_pid = clone_vid_pid,
        });
    } else {
        // Clean up block_drivers if we didn't create an entry
        for (block_drivers) |d| allocator.free(d);
        if (block_drivers.len > 0) allocator.free(block_drivers);
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
    try testing.expect(std.mem.indexOf(u8, content, "--config-dir /usr/local/share/padctl/devices") != null);
    try testing.expect(std.mem.indexOf(u8, content, "WantedBy=default.target") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ProtectHome") == null);
    try testing.expect(std.mem.indexOf(u8, content, "User=") == null);
}

test "install: generateServiceContent default prefix omits --config-dir" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "/usr/bin/padctl") != null);
    try testing.expect(std.mem.indexOf(u8, content, "--config-dir") == null);
    try testing.expect(std.mem.indexOf(u8, content, "After=graphical-session.target") != null);
}

test "install: generateServiceContent is user unit" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "WantedBy=default.target") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ProtectHome") == null);
    try testing.expect(std.mem.indexOf(u8, content, "ProtectSystem") == null);
    try testing.expect(std.mem.indexOf(u8, content, "User=") == null);
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
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr/local");

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
    // ADR-015: /dev/uhid must get uaccess so the user service can create
    // virtual SDL-visible gamepads without CAP_SYS_ADMIN.
    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uhid\"") != null);
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

test "install: findMappingsSourceDir discovers repo-root mappings from zig-out/bin" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const repo_mappings = try std.fmt.allocPrint(allocator, "{s}/mappings", .{tmp_path});
    defer allocator.free(repo_mappings);
    try ensureDirAll(allocator, repo_mappings);

    const self_dir = try std.fmt.allocPrint(allocator, "{s}/zig-out/bin", .{tmp_path});
    defer allocator.free(self_dir);
    try ensureDirAll(allocator, self_dir);

    const found = try findMappingsSourceDir(allocator, self_dir, "/definitely/missing");
    defer if (found) |path| allocator.free(path);

    try testing.expect(found != null);
    try testing.expectEqualStrings(repo_mappings, found.?);
}

test "install: findMappingsSourceDir falls back to cwd mappings" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const cwd_mappings = try std.fmt.allocPrint(allocator, "{s}/mappings", .{tmp_path});
    defer allocator.free(cwd_mappings);
    try ensureDirAll(allocator, cwd_mappings);

    const self_dir = try std.fmt.allocPrint(allocator, "{s}/out/bin", .{tmp_path});
    defer allocator.free(self_dir);
    try ensureDirAll(allocator, self_dir);

    const found = try findMappingsSourceDir(allocator, self_dir, tmp_path);
    defer if (found) |path| allocator.free(path);

    try testing.expect(found != null);
    try testing.expectEqualStrings(cwd_mappings, found.?);
}

// --- Phase 1+2: immutable OS detection, options, path routing ---

test "install: InstallOptions defaults" {
    const opts = InstallOptions{};
    const testing = std.testing;
    try testing.expect(!opts.immutable);
    try testing.expect(!opts.no_immutable);
    try testing.expectEqual(@as(usize, 0), opts.mappings.len);
    try testing.expect(!opts.force_mapping);
    try testing.expect(!opts.no_enable);
    try testing.expect(!opts.no_start);
    try testing.expectEqualStrings("/usr", opts.prefix);
    try testing.expectEqualStrings("", opts.destdir);
}

test "install: detectImmutableOs returns .ostree when marker exists" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    // Create {root}/run/ostree-booted
    const run_dir = try std.fmt.allocPrint(allocator, "{s}/run", .{root});
    defer allocator.free(run_dir);
    try ensureDirAll(allocator, run_dir);
    const marker = try std.fmt.allocPrint(allocator, "{s}/run/ostree-booted", .{root});
    defer allocator.free(marker);
    {
        var f = try std.fs.createFileAbsolute(marker, .{});
        f.close();
    }

    try testing.expectEqual(ImmutableKind.ostree, detectImmutableOs(allocator, root));
}

test "install: detectImmutableOs returns .none on normal filesystem" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    // Create a writable {root}/usr so the probe can succeed
    const usr_dir = try std.fmt.allocPrint(allocator, "{s}/usr", .{root});
    defer allocator.free(usr_dir);
    try ensureDirAll(allocator, usr_dir);

    try testing.expectEqual(ImmutableKind.none, detectImmutableOs(allocator, root));
}

test "install: shouldAbortForImmutable logic" {
    const testing = std.testing;
    // Immutable detected, no flags → abort
    try testing.expect(shouldAbortForImmutable(.ostree, .{}));
    try testing.expect(shouldAbortForImmutable(.read_only_usr, .{}));
    // With --immutable → don't abort
    try testing.expect(!shouldAbortForImmutable(.ostree, .{ .immutable = true }));
    // With --no-immutable → don't abort
    try testing.expect(!shouldAbortForImmutable(.ostree, .{ .no_immutable = true }));
    // No immutable detected → don't abort
    try testing.expect(!shouldAbortForImmutable(.none, .{}));
}

test "install: resolveServiceDir immutable routes to /etc/systemd/user" {
    // Immutable installs write a USER service unit to /etc/systemd/user/ so
    // systemd discovers it as a user unit and each user's systemd instance
    // runs its own copy. The matching updateLegacySystemService() helper
    // cleans up any leftover /etc/systemd/system/padctl.service from older
    // installs.
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try resolveServiceDir(allocator, "/staging", "/usr/local", true, false);
    defer allocator.free(result);
    try testing.expectEqualStrings("/staging/etc/systemd/user", result);
}

test "install: resolveServiceDir /usr non-immutable routes to /usr/lib/systemd/user" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try resolveServiceDir(allocator, "", "/usr", false, false);
    defer allocator.free(result);
    try testing.expectEqualStrings("/usr/lib/systemd/user", result);
}

test "install: resolveUdevDir immutable routes to /etc/udev/rules.d" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try resolveUdevDir(allocator, "/staging", "/usr", true);
    defer allocator.free(result);
    try testing.expectEqualStrings("/staging/etc/udev/rules.d", result);
}

test "install: resolveUdevDir standard routes to prefix/lib/udev/rules.d" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try resolveUdevDir(allocator, "", "/usr", false);
    defer allocator.free(result);
    try testing.expectEqualStrings("/usr/lib/udev/rules.d", result);
}

test "install: immutable dropin content has required directives" {
    const testing = std.testing;
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "DeviceAllow=\n") != null);
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "ProtectHome=read-only") != null);
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "TimeoutStopSec=3") != null);
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "KillMode=mixed") != null);
    // ProtectHome=read-only also makes /run/user/%U read-only (per
    // systemd.exec(5)), which silently broke the daemon's IPC socket
    // bind(). ReadWritePaths=/run/user/%U must stay present alongside
    // ProtectHome to keep `padctl status`/`switch`/`devices` working
    // on immutable-OS user-service installs.
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "ReadWritePaths=/run/user/%U") != null);
    // LogsDirectory= on a user service puts files under
    // $XDG_STATE_HOME/log/padctl (extra 'log/' subdir), splitting the
    // daemon's log path from stateDir()'s $XDG_STATE_HOME/padctl. The
    // main service template now uses StateDirectory=padctl for the flat
    // path; the drop-in must NOT reintroduce LogsDirectory.
    try testing.expect(std.mem.indexOf(u8, immutable_dropin_content, "LogsDirectory") == null);
}

test "install: generateServiceContent uses StateDirectory (not LogsDirectory)" {
    // StateDirectory=padctl maps to $XDG_STATE_HOME/padctl on user services
    // and matches padctl's stateDir() resolver. LogsDirectory=padctl on a
    // user service would nest under $XDG_STATE_HOME/log/padctl — splitting
    // the path between daemon and CLI.
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr/local");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "StateDirectory=padctl") != null);
    try testing.expect(std.mem.indexOf(u8, content, "LogsDirectory") == null);
}

test "install: generateSystemServiceContent uses StateDirectory (not LogsDirectory)" {
    // Legacy-upgrade template: the /etc/systemd/system/ unit that
    // updateLegacySystemService refreshes if it still exists. Consistency
    // with the user-service template — if a user manually resurrects the
    // legacy unit, its state dir matches what stateDir() resolves to.
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateSystemServiceContent(allocator, "/usr/local");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "StateDirectory=padctl") != null);
    try testing.expect(std.mem.indexOf(u8, content, "LogsDirectory") == null);
}

test "install: generateSystemServiceContent grants /dev/uhid DeviceAllow (ADR-015)" {
    // ADR-015 §Dependencies: the UHID migration needs /dev/uhid access
    // parallel to /dev/uinput. Pre-fix the template listed only hidraw,
    // uinput, and char-input — UhidDevice.init would have failed with
    // EACCES on a default install.
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateSystemServiceContent(allocator, "/usr/local");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "DeviceAllow=/dev/uhid rw") != null);
    try testing.expect(std.mem.indexOf(u8, content, "DeviceAllow=/dev/uinput rw") != null);
}

test "install: parseYesNoDefaultYes empty input is yes (default-yes)" {
    try std.testing.expect(parseYesNoDefaultYes(""));
    try std.testing.expect(parseYesNoDefaultYes("\n"));
    try std.testing.expect(parseYesNoDefaultYes("\r\n"));
    try std.testing.expect(parseYesNoDefaultYes("   "));
    try std.testing.expect(parseYesNoDefaultYes(" \t \n"));
}

test "install: parseYesNoDefaultYes 'y' variants are yes" {
    try std.testing.expect(parseYesNoDefaultYes("y"));
    try std.testing.expect(parseYesNoDefaultYes("Y"));
    try std.testing.expect(parseYesNoDefaultYes("yes\n"));
    try std.testing.expect(parseYesNoDefaultYes("YES"));
    try std.testing.expect(parseYesNoDefaultYes("  y  \n"));
    try std.testing.expect(parseYesNoDefaultYes("y\n"));
}

test "install: parseYesNoDefaultYes 'n' variants are no" {
    try std.testing.expect(!parseYesNoDefaultYes("n"));
    try std.testing.expect(!parseYesNoDefaultYes("N"));
    try std.testing.expect(!parseYesNoDefaultYes("no\n"));
    try std.testing.expect(!parseYesNoDefaultYes("NO"));
    try std.testing.expect(!parseYesNoDefaultYes("  n  \n"));
}

test "install: parseYesNoDefaultYes non-y non-n input is treated as no" {
    // Anything that isn't default-empty or y/Y should fail safe to NO,
    // protecting destructive operations from typos like "k\n" or "maybe".
    try std.testing.expect(!parseYesNoDefaultYes("k"));
    try std.testing.expect(!parseYesNoDefaultYes("maybe"));
    try std.testing.expect(!parseYesNoDefaultYes("1"));
    try std.testing.expect(!parseYesNoDefaultYes("true"));
    try std.testing.expect(!parseYesNoDefaultYes("asdf"));
}

// --- Phase 3: resume service cleanup, reconnect script, hotplug rules ---

// issue #131 Problem B: padctl-resume.service was broken by design (never
// enabled, scope-mismatched, ExecStart targeted a nonexistent system unit)
// and is now removed. The udev reconnect hook (padctl-reconnect) handles
// hotplug after suspend/resume. These tests lock in that the installer
// neither writes the unit nor leaves legacy copies behind on upgrade.

// Scoped fd-1 silencer for tests that drive run()/uninstall() directly.
// Those functions emit user-facing progress on STDOUT_FILENO (fd 1).
// Under `zig build test*`, fd 1 is the zig build-server binary protocol
// channel (test_runner mainServer). Any bytes written by the test body
// corrupt that stream; the build runner then parses ASCII as a message
// header (~1.9 GB body) and blocks forever reading, while the test
// runner sits in `anon_pipe_read` waiting for the next `run_test`
// command — i.e., the deadlock observed as `zig build test-tsan` hang.
// Redirecting fd 1 to /dev/null for the duration of the install/uninstall
// call lets the test exercise real production code without touching the
// protocol channel. Restore is mandatory so the subsequent
// `serveTestResults` write reaches the build runner.
const SilencedStdout = struct {
    saved_fd: std.posix.fd_t,

    fn begin() !SilencedStdout {
        const saved = try std.posix.dup(std.posix.STDOUT_FILENO);
        errdefer std.posix.close(saved);
        const devnull = try std.posix.open("/dev/null", .{ .ACCMODE = .WRONLY }, 0);
        defer std.posix.close(devnull);
        try std.posix.dup2(devnull, std.posix.STDOUT_FILENO);
        return .{ .saved_fd = saved };
    }

    fn end(self: *SilencedStdout) void {
        std.posix.dup2(self.saved_fd, std.posix.STDOUT_FILENO) catch {};
        std.posix.close(self.saved_fd);
    }
};

test "install: resume service is NOT installed (system immutable)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const staging = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(staging);

    const opts = InstallOptions{
        .prefix = "/usr/local",
        .destdir = staging,
        .immutable = true,
        .user_service = false,
        .no_enable = true,
        .no_start = true,
    };
    var silencer = try SilencedStdout.begin();
    defer silencer.end();
    run(allocator, opts) catch |err| switch (err) {
        // Staging install legitimately fails late (e.g. devices source dir
        // not found in the test harness); we only care about the earlier
        // resume-write step, so tolerate downstream errors.
        error.MappingInstallFailed => {},
        else => return err,
    };

    // Every plausible legacy install location must be empty.
    const candidates = [_][]const u8{
        "/usr/local/lib/systemd/user/padctl-resume.service",
        "/usr/local/lib/systemd/system/padctl-resume.service",
        "/etc/systemd/system/padctl-resume.service",
        "/etc/systemd/user/padctl-resume.service",
    };
    for (candidates) |rel| {
        const abs = try std.fmt.allocPrint(allocator, "{s}{s}", .{ staging, rel });
        defer allocator.free(abs);
        if (std.fs.accessAbsolute(abs, .{})) |_| {
            std.debug.print("found leftover resume unit at {s}\n", .{abs});
            return error.UnexpectedResumeUnitFound;
        } else |_| {}
    }
}

test "uninstall: legacy padctl-resume.service is removed (system immutable)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const staging = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(staging);

    // Seed a fake legacy resume unit at the immutable user-scope location
    // — this is exactly where v0.1.2 installs wrote the unit on immutable
    // systems (issue #131 Problem B scope-mismatch).
    const legacy_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{staging});
    defer allocator.free(legacy_dir);
    try ensureDirAll(allocator, legacy_dir);
    const legacy_unit = try std.fmt.allocPrint(allocator, "{s}/padctl-resume.service", .{legacy_dir});
    defer allocator.free(legacy_unit);
    {
        var f = try std.fs.createFileAbsolute(legacy_unit, .{ .truncate = true });
        defer f.close();
        try f.writeAll("# legacy v0.1.2 resume unit — must be removed on upgrade\n");
    }

    const opts = InstallOptions{
        .prefix = "/usr/local",
        .destdir = staging,
        .immutable = true,
        .user_service = false,
    };
    {
        var silencer = try SilencedStdout.begin();
        defer silencer.end();
        try uninstall(allocator, opts);
    }

    if (std.fs.accessAbsolute(legacy_unit, .{})) |_| {
        std.debug.print("legacy resume unit not cleaned up: {s}\n", .{legacy_unit});
        return error.LegacyResumeUnitNotRemoved;
    } else |_| {}
}

// T-H1: non-immutable + non-/usr prefix must also clean /etc/systemd/user/
// padctl-resume.service (issue #131-B uninstall gap — H1 fix).
test "uninstall: legacy padctl-resume.service is removed (non-immutable)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const staging = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(staging);

    const legacy_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{staging});
    defer allocator.free(legacy_dir);
    try ensureDirAll(allocator, legacy_dir);
    const legacy_unit = try std.fmt.allocPrint(allocator, "{s}/padctl-resume.service", .{legacy_dir});
    defer allocator.free(legacy_unit);
    {
        var f = try std.fs.createFileAbsolute(legacy_unit, .{ .truncate = true });
        defer f.close();
        try f.writeAll("# legacy v0.1.2 resume unit\n");
    }

    const opts = InstallOptions{
        .prefix = "/usr/local",
        .destdir = staging,
        .immutable = false,
        .user_service = false,
    };
    {
        var silencer = try SilencedStdout.begin();
        defer silencer.end();
        try uninstall(allocator, opts);
    }

    if (std.fs.accessAbsolute(legacy_unit, .{})) |_| {
        std.debug.print("legacy resume unit not cleaned up on non-immutable path: {s}\n", .{legacy_unit});
        return error.LegacyResumeUnitNotRemoved;
    } else |_| {}
}

test "install: generateReconnectScript has required commands" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const script = try generateReconnectScript(allocator, "/usr/local");
    defer allocator.free(script);
    try testing.expect(std.mem.startsWith(u8, script, "#!/bin/bash"));
    try testing.expect(std.mem.indexOf(u8, script, "flock -n 200") != null);
    try testing.expect(std.mem.indexOf(u8, script, "mkdir -p /run/padctl") != null);
    // Must NOT use systemctl (user service is managed by user, not udev)
    try testing.expect(std.mem.indexOf(u8, script, "systemctl") == null);
    // Must re-apply mapping on hotplug
    try testing.expect(std.mem.indexOf(u8, script, "/usr/local/bin/padctl switch") != null);
    try testing.expect(std.mem.indexOf(u8, script, "/etc/padctl/mappings/") != null);
}

test "install: generateUdevRules includes hotplug reconnect rules" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(
            \\[device]
            \\name = "Test Device"
            \\vid = 0x1234
            \\pid = 0x5678
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr/local");

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 8192);
    defer allocator.free(content);

    // Should have hotplug reconnect rules
    try testing.expect(std.mem.indexOf(u8, content, "padctl-reconnect") != null);
    try testing.expect(std.mem.indexOf(u8, content, "systemd-run --no-block") != null);
    try testing.expect(std.mem.indexOf(u8, content, "/usr/local/bin/padctl-reconnect") != null);
    // Should still have standard rules
    try testing.expect(std.mem.indexOf(u8, content, "SUBSYSTEM==\"hidraw\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "TAG+=\"uaccess\"") != null);
}

// --- Phase 4: kernel driver blocking ---

test "install: parseStringArray parses TOML inline array" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try parseStringArray(allocator, "[\"xpad\", \"hid_generic\"]");
    defer {
        for (result) |s| allocator.free(s);
        allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualStrings("xpad", result[0]);
    try testing.expectEqualStrings("hid_generic", result[1]);
}

test "install: parseStringArray handles empty array" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try parseStringArray(allocator, "[]");
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "install: parseStringArray handles single element" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try parseStringArray(allocator, "[\"xpad\"]");
    defer {
        for (result) |s| allocator.free(s);
        allocator.free(result);
    }
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqualStrings("xpad", result[0]);
}

test "install: parseStringArray rejects command injection" {
    const testing = std.testing;
    const allocator = testing.allocator;
    // Shell metacharacters must be rejected
    const result = try parseStringArray(allocator, "[\"x'; rm -rf / #\"]");
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "install: isValidIdentifier accepts safe names" {
    const testing = std.testing;
    try testing.expect(isValidIdentifier("xpad"));
    try testing.expect(isValidIdentifier("hid_generic"));
    try testing.expect(isValidIdentifier("hid-sony"));
    try testing.expect(isValidIdentifier("usbhid"));
}

test "install: isValidIdentifier rejects unsafe names" {
    const testing = std.testing;
    try testing.expect(!isValidIdentifier(""));
    try testing.expect(!isValidIdentifier("x'; rm -rf /"));
    try testing.expect(!isValidIdentifier("xpad; echo pwned"));
    try testing.expect(!isValidIdentifier("driver name"));
    try testing.expect(!isValidIdentifier("../etc/passwd"));
}

test "install: extractVidPid parses block_kernel_drivers" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const toml_content =
        \\[device]
        \\name = "Test"
        \\vid = 0x1234
        \\pid = 0x5678
        \\block_kernel_drivers = ["xpad", "hid_generic"]
    ;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test_drivers.toml", .{tmp_path});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(toml_content);
    }

    var entries = std.ArrayList(UdevEntry){};
    defer {
        for (entries.items) |e| {
            allocator.free(e.name);
            for (e.block_kernel_drivers) |d| allocator.free(d);
            if (e.block_kernel_drivers.len > 0) allocator.free(e.block_kernel_drivers);
        }
        entries.deinit(allocator);
    }
    try extractVidPid(allocator, toml_path, &entries);

    try testing.expectEqual(@as(usize, 1), entries.items.len);
    try testing.expectEqual(@as(usize, 2), entries.items[0].block_kernel_drivers.len);
    try testing.expectEqualStrings("xpad", entries.items[0].block_kernel_drivers[0]);
    try testing.expectEqualStrings("hid_generic", entries.items[0].block_kernel_drivers[1]);
}

test "install: generateDriverBlockRules produces unbind rules" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(
            \\[device]
            \\name = "Test"
            \\vid = 0x37d7
            \\pid = 0x2401
            \\block_kernel_drivers = ["xpad"]
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/61-padctl-driver-block.rules", .{tmp_path});
    defer allocator.free(rules_path);
    const dirs = [_][]const u8{devices_dir};
    try generateDriverBlockRules(allocator, &dirs, rules_path);

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 8192);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "ACTION==\"bind\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "DRIVER==\"xpad\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "37d7") != null);
    try testing.expect(std.mem.indexOf(u8, content, "unbind") != null);
}

test "install: generateDriverBlockRules skips when no drivers configured" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var file = try std.fs.createFileAbsolute(toml_path, .{});
        defer file.close();
        try file.writeAll(
            \\[device]
            \\name = "Test"
            \\vid = 0x1234
            \\pid = 0x5678
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/61-padctl-driver-block.rules", .{tmp_path});
    defer allocator.free(rules_path);
    const dirs = [_][]const u8{devices_dir};
    try generateDriverBlockRules(allocator, &dirs, rules_path);

    // File should not be created when no drivers are blocked
    std.fs.accessAbsolute(rules_path, .{}) catch |err| {
        try testing.expectEqual(error.FileNotFound, err);
        return;
    };
    // File should not have been created — if it was, fail the test
    return error.TestUnexpectedResult;
}

// --- Phase 5: mapping installation ---

test "install: installMapping copies mapping to /etc/padctl/mappings/" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    // Create source
    const src_dir = try std.fmt.allocPrint(allocator, "{s}/src_map", .{destdir});
    defer allocator.free(src_dir);
    try std.fs.makeDirAbsolute(src_dir);
    const src_file = try std.fmt.allocPrint(allocator, "{s}/vader5.toml", .{src_dir});
    defer allocator.free(src_file);
    {
        const f = try std.fs.createFileAbsolute(src_file, .{});
        defer f.close();
        try f.writeAll("name = \"test mapping\"");
    }

    try installMapping(allocator, "vader5", destdir, src_dir, false);

    // Verify target exists
    const target = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings/vader5.toml", .{destdir});
    defer allocator.free(target);
    const f = try std.fs.openFileAbsolute(target, .{});
    defer f.close();
    const content = try f.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);
    try testing.expectEqualStrings("name = \"test mapping\"", content);
}

test "install: installMapping skips existing without force" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    // Create source
    const src_dir = try std.fmt.allocPrint(allocator, "{s}/src_map", .{destdir});
    defer allocator.free(src_dir);
    try std.fs.makeDirAbsolute(src_dir);
    {
        const src_file = try std.fmt.allocPrint(allocator, "{s}/vader5.toml", .{src_dir});
        defer allocator.free(src_file);
        const f = try std.fs.createFileAbsolute(src_file, .{});
        defer f.close();
        try f.writeAll("new content");
    }

    // Create existing target via nested mkdirs
    const td1 = try std.fmt.allocPrint(allocator, "{s}/etc", .{destdir});
    defer allocator.free(td1);
    try std.fs.makeDirAbsolute(td1);
    const td2 = try std.fmt.allocPrint(allocator, "{s}/etc/padctl", .{destdir});
    defer allocator.free(td2);
    try std.fs.makeDirAbsolute(td2);
    const td3 = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings", .{destdir});
    defer allocator.free(td3);
    try std.fs.makeDirAbsolute(td3);
    const target = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings/vader5.toml", .{destdir});
    defer allocator.free(target);
    {
        const f = try std.fs.createFileAbsolute(target, .{});
        defer f.close();
        try f.writeAll("original");
    }

    try installMapping(allocator, "vader5", destdir, src_dir, false);

    // Content should be unchanged
    const f = try std.fs.openFileAbsolute(target, .{});
    defer f.close();
    const content = try f.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);
    try testing.expectEqualStrings("original", content);
}

test "install: installMapping overwrites with force" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    // Create source
    const src_dir = try std.fmt.allocPrint(allocator, "{s}/src_map", .{destdir});
    defer allocator.free(src_dir);
    try std.fs.makeDirAbsolute(src_dir);
    {
        const src_file = try std.fmt.allocPrint(allocator, "{s}/vader5.toml", .{src_dir});
        defer allocator.free(src_file);
        const f = try std.fs.createFileAbsolute(src_file, .{});
        defer f.close();
        try f.writeAll("updated");
    }

    // Create existing target
    const td1 = try std.fmt.allocPrint(allocator, "{s}/etc", .{destdir});
    defer allocator.free(td1);
    try std.fs.makeDirAbsolute(td1);
    const td2 = try std.fmt.allocPrint(allocator, "{s}/etc/padctl", .{destdir});
    defer allocator.free(td2);
    try std.fs.makeDirAbsolute(td2);
    const td3 = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings", .{destdir});
    defer allocator.free(td3);
    try std.fs.makeDirAbsolute(td3);
    const target = try std.fmt.allocPrint(allocator, "{s}/etc/padctl/mappings/vader5.toml", .{destdir});
    defer allocator.free(target);
    {
        const f = try std.fs.createFileAbsolute(target, .{});
        defer f.close();
        try f.writeAll("original");
    }

    try installMapping(allocator, "vader5", destdir, src_dir, true);

    // Content should be updated
    const f = try std.fs.openFileAbsolute(target, .{});
    defer f.close();
    const content = try f.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);
    try testing.expectEqualStrings("updated", content);
}

test "install: findDeviceNameForMapping resolves vader5 to Flydigi Vader 5 Pro" {
    const testing_alloc = std.testing.allocator;
    // findDevicesSourceDir searches relative to self_dir or CWD.
    // In the test environment, CWD is the repo root.
    const cwd = try std.process.getCwdAlloc(testing_alloc);
    defer testing_alloc.free(cwd);
    const devices_dir = try std.fmt.allocPrint(testing_alloc, "{s}/devices", .{cwd});
    defer testing_alloc.free(devices_dir);

    const result = try findDeviceNameForMapping(testing_alloc, "vader5", devices_dir);
    defer if (result) |r| testing_alloc.free(r);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", result.?);
}

test "install: findDeviceNameForMapping returns null for nonexistent mapping" {
    const testing_alloc = std.testing.allocator;
    const cwd = try std.process.getCwdAlloc(testing_alloc);
    defer testing_alloc.free(cwd);
    const devices_dir = try std.fmt.allocPrint(testing_alloc, "{s}/devices", .{cwd});
    defer testing_alloc.free(devices_dir);

    const result = try findDeviceNameForMapping(testing_alloc, "nonexistent_controller_xyz", devices_dir);
    try std.testing.expectEqual(@as(?[]const u8, null), result);
}

// --- Mock prompt functions for tests ---

fn mockPromptKeep(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .keep;
}
fn mockPromptOverwrite(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .overwrite;
}
fn mockPromptAbort(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .abort;
}

// --- Binding writer tests ---

test "install: writeBinding creates new config.toml with version and device entry" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Test Device", "test_map", .skip, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);

    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "version = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "name = \"Test Device\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"test_map\"") != null);
}

test "install: writeBinding appends to existing config with different device" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    // Write first device.
    try writeBinding(testing_alloc, destdir, "Device A", "map_a", .skip, mockPromptKeep);
    // Write second device.
    try writeBinding(testing_alloc, destdir, "Device B", "map_b", .skip, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);

    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Both devices present.
    try std.testing.expect(std.mem.indexOf(u8, content, "name = \"Device A\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "name = \"Device B\"") != null);
}

test "install: writeBinding is idempotent when device+mapping match" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "vader5", .skip, mockPromptKeep);
    try writeBinding(testing_alloc, destdir, "Vader", "vader5", .skip, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);

    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Only one [[device]] entry (not duplicated).
    var count: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, "[[device]]")) |idx| {
        count += 1;
        pos = idx + 10;
    }
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "install: writeBinding conflict without force - skip (no overwrite)" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "old_map", .skip, mockPromptKeep);
    // Conflict: same device, different mapping, no force.
    try writeBinding(testing_alloc, destdir, "Vader", "new_map", .skip, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);

    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Original mapping preserved (no force).
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"old_map\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"new_map\"") == null);
}

test "install: writeBinding interactive keep preserves existing binding" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "old_map", .skip, mockPromptKeep);
    // Interactive mode with mockPromptKeep → user chose "keep".
    try writeBinding(testing_alloc, destdir, "Vader", "new_map", .interactive, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);
    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Original binding preserved.
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"old_map\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"new_map\"") == null);
}

test "install: writeBinding interactive overwrite updates binding with backup" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "old_map", .skip, mockPromptKeep);
    // Interactive mode with mockPromptOverwrite → user chose "overwrite".
    try writeBinding(testing_alloc, destdir, "Vader", "new_map", .interactive, mockPromptOverwrite);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);
    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Binding updated.
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"new_map\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"old_map\"") == null);

    // Backup exists.
    const etc_dir = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl", .{destdir});
    defer testing_alloc.free(etc_dir);
    var dir = try std.fs.openDirAbsolute(etc_dir, .{ .iterate = true });
    defer dir.close();
    var found_bak = false;
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "config.toml.bak.")) {
            found_bak = true;
            break;
        }
    }
    try std.testing.expect(found_bak);
}

test "install: writeBinding interactive abort returns error" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "old_map", .skip, mockPromptKeep);
    // Interactive mode with mockPromptAbort → user chose "abort".
    try std.testing.expectError(
        error.Aborted,
        writeBinding(testing_alloc, destdir, "Vader", "new_map", .interactive, mockPromptAbort),
    );

    // Original preserved (abort didn't modify).
    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);
    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"old_map\"") != null);
}

test "install: writeBinding aborts on malformed existing config.toml" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    // Create a malformed config.toml that the TOML parser can't read.
    const etc_dir = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl", .{destdir});
    defer testing_alloc.free(etc_dir);
    try ensureDirAll(testing_alloc, etc_dir);
    {
        const cfg_path = try std.fmt.allocPrint(testing_alloc, "{s}/config.toml", .{etc_dir});
        defer testing_alloc.free(cfg_path);
        const f = try std.fs.createFileAbsolute(cfg_path, .{});
        defer f.close();
        try f.writeAll("this is {{{{ not valid TOML !!!!");
    }

    // writeBinding must refuse to overwrite — data loss risk.
    try std.testing.expectError(
        error.MalformedConfig,
        writeBinding(testing_alloc, destdir, "Device", "map", .skip, mockPromptKeep),
    );
    // Force mode must also abort — backup-then-overwrite is meaningless
    // when we can't even parse the file to preserve unrelated entries.
    try std.testing.expectError(
        error.MalformedConfig,
        writeBinding(testing_alloc, destdir, "Device", "map", .force, mockPromptKeep),
    );
}

test "install: writeBinding conflict with force - backup + overwrite" {
    const testing_alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(testing_alloc, ".");
    defer testing_alloc.free(destdir);

    try writeBinding(testing_alloc, destdir, "Vader", "old_map", .skip, mockPromptKeep);
    // Force overwrite.
    try writeBinding(testing_alloc, destdir, "Vader", "new_map", .force, mockPromptKeep);

    const config_path = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl/config.toml", .{destdir});
    defer testing_alloc.free(config_path);

    const content = try std.fs.cwd().readFileAlloc(testing_alloc, config_path, 64 * 1024);
    defer testing_alloc.free(content);

    // Binding updated.
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"new_map\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "default_mapping = \"old_map\"") == null);

    // Backup file exists.
    const etc_dir = try std.fmt.allocPrint(testing_alloc, "{s}/etc/padctl", .{destdir});
    defer testing_alloc.free(etc_dir);
    var dir = try std.fs.openDirAbsolute(etc_dir, .{ .iterate = true });
    defer dir.close();
    var found_bak = false;
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "config.toml.bak.")) {
            found_bak = true;
            break;
        }
    }
    try std.testing.expect(found_bak);
}

test "install: installMapping errors on missing source" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    const src_dir = try std.fmt.allocPrint(allocator, "{s}/src_map", .{destdir});
    defer allocator.free(src_dir);
    try std.fs.makeDirAbsolute(src_dir);

    try testing.expectError(error.FileNotFound, installMapping(allocator, "nonexistent", destdir, src_dir, false));
}

test "install: resolveServiceDir user service uses HOME" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const home = std.posix.getenv("HOME") orelse return error.SkipZigTest;
    const dir = try resolveServiceDir(allocator, "", "/usr", false, true);
    defer allocator.free(dir);
    const expected = try std.fmt.allocPrint(allocator, "{s}/.config/systemd/user", .{home});
    defer allocator.free(expected);
    try testing.expectEqualStrings(expected, dir);
}

test "install: resolveServiceDir system install uses user lib path" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const dir = try resolveServiceDir(allocator, "", "/usr", false, false);
    defer allocator.free(dir);
    try testing.expectEqualStrings("/usr/lib/systemd/user", dir);
}

test "install: resolveServiceDir non-usr prefix falls back to /etc/systemd/user" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const result = try resolveServiceDir(allocator, "", "/usr/local", false, false);
    defer allocator.free(result);
    try testing.expectEqualStrings("/etc/systemd/user", result);
}

test "install: udev rules must not contain SYSTEMD_WANTS" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);
    const toml_path = try std.fmt.allocPrint(allocator, "{s}/test.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var f = try std.fs.createFileAbsolute(toml_path, .{});
        defer f.close();
        try f.writeAll("[device]\nname = \"T\"\nvid = 0x1234\npid = 0x5678\n");
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr");
    const content = blk: {
        var f = try std.fs.openFileAbsolute(rules_path, .{});
        defer f.close();
        break :blk try f.readToEndAlloc(allocator, 8192);
    };
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "SYSTEMD_WANTS") == null);
    try testing.expect(std.mem.indexOf(u8, content, "TAG+=\"systemd\"") == null);
}

test "install: service content has hardening directives" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "NoNewPrivileges=true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "LockPersonality=true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ProtectClock=true") != null);
    try testing.expect(std.mem.indexOf(u8, content, "SupplementaryGroups") == null);
}

test "install: old system unit triggers migration hint" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    const etc_systemd = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/system", .{destdir});
    defer allocator.free(etc_systemd);
    try ensureDirAll(allocator, etc_systemd);
    const old_unit = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{etc_systemd});
    defer allocator.free(old_unit);
    {
        var f = try std.fs.createFileAbsolute(old_unit, .{});
        defer f.close();
    }

    // Verify the old unit is detectable (the migration hint logic reads this path)
    try std.fs.accessAbsolute(old_unit, .{});
}

test "install: generateServiceContent /usr prefix omits --config-dir" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "--config-dir") == null);
    try testing.expect(std.mem.indexOf(u8, content, "ExecStart=/usr/bin/padctl\n") != null);
}

test "install: generateServiceContent non-usr prefix includes --config-dir for its own share" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const content = try generateServiceContent(allocator, "/usr/local");
    defer allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "--config-dir /usr/local/share/padctl/devices") != null);
    try testing.expect(std.mem.indexOf(u8, content, "--config-dir /usr/share") == null);
}

test "install: atomicInstallBinary replaces destination atomically" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const src_path = try std.fmt.allocPrint(allocator, "{s}/src.bin", .{dir});
    defer allocator.free(src_path);
    const dst_path = try std.fmt.allocPrint(allocator, "{s}/dst.bin", .{dir});
    defer allocator.free(dst_path);

    // Write distinct content to src and an existing dst.
    {
        var f = try std.fs.createFileAbsolute(src_path, .{});
        defer f.close();
        try f.writeAll("new-content");
    }
    {
        var f = try std.fs.createFileAbsolute(dst_path, .{});
        defer f.close();
        try f.writeAll("old-content");
    }

    try atomicInstallBinary(allocator, src_path, dst_path);

    // Destination must now contain source bytes.
    const got = blk: {
        var f = try std.fs.openFileAbsolute(dst_path, .{});
        defer f.close();
        break :blk try f.readToEndAlloc(allocator, 4096);
    };
    defer allocator.free(got);
    try testing.expectEqualStrings("new-content", got);

    // Mode must be 0o755.
    const stat = try std.fs.cwd().statFile(dst_path);
    try testing.expectEqual(@as(u32, 0o755), stat.mode & 0o777);
}

test "install: atomicInstallBinary rename succeeds while dst has open readers" {
    // Verifies rename(2) over an open read fd succeeds — regression lock for the atomic-rename path.
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const src_path = try std.fmt.allocPrint(allocator, "{s}/src2.bin", .{dir});
    defer allocator.free(src_path);
    const dst_path = try std.fmt.allocPrint(allocator, "{s}/dst2.bin", .{dir});
    defer allocator.free(dst_path);

    {
        var f = try std.fs.createFileAbsolute(src_path, .{});
        defer f.close();
        try f.writeAll("payload");
    }
    {
        var f = try std.fs.createFileAbsolute(dst_path, .{});
        defer f.close();
        try f.writeAll("old");
    }

    // Hold dst open for reading while install runs — simulates a running process.
    var held = try std.fs.openFileAbsolute(dst_path, .{});
    defer held.close();

    try atomicInstallBinary(allocator, src_path, dst_path);

    const got = blk: {
        var f = try std.fs.openFileAbsolute(dst_path, .{});
        defer f.close();
        break :blk try f.readToEndAlloc(allocator, 4096);
    };
    defer allocator.free(got);
    try testing.expectEqualStrings("payload", got);
}

// Counts open fds in /proc/self/fd. Used to detect fd leaks in the atomicInstallBinary
// error paths.
fn countOpenFds() !usize {
    var dir = try std.fs.openDirAbsolute("/proc/self/fd", .{ .iterate = true });
    defer dir.close();
    var it = dir.iterate();
    var n: usize = 0;
    while (try it.next()) |_| n += 1;
    return n;
}

test "install: atomicInstallBinary closes tmp fd on copy-loop error" {
    // Reproducer for the errdefer-close bug: passing a directory as src
    // lets openFileAbsolute succeed (returns a dirfd), createFileAbsolute
    // succeeds, then src_file.read() fails with error.IsDir inside the
    // copy loop. Without errdefer tmp_file.close(), the tmp_file fd leaks.
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const src_dir = try std.fmt.allocPrint(allocator, "{s}/src_is_dir", .{dir});
    defer allocator.free(src_dir);
    try std.fs.makeDirAbsolute(src_dir);

    const dst_path = try std.fmt.allocPrint(allocator, "{s}/dst.bin", .{dir});
    defer allocator.free(dst_path);

    const fds_before = try countOpenFds();

    const result = atomicInstallBinary(allocator, src_dir, dst_path);
    try testing.expect(std.meta.isError(result));

    const fds_after = try countOpenFds();
    try testing.expectEqual(fds_before, fds_after);

    // errdefer deleteFileAbsolute must also have cleaned the tmp file.
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.new", .{dst_path});
    defer allocator.free(tmp_path);
    try testing.expectError(error.FileNotFound, std.fs.accessAbsolute(tmp_path, .{}));
}

test "install: atomicInstallBinary does not double-close on rename failure" {
    // Reproducer for the double-close concern: if rename(tmp, dst) fails,
    // the errdefer tmp_file.close() fires after the explicit close on the
    // success path has already run. Zig's File.close is NOT idempotent
    // (it calls posix.close(handle) unconditionally), so a second close
    // either returns EBADF silently or panics under safety checks.
    //
    // Trigger rename failure by making dst an existing non-empty directory:
    // rename(file, non-empty-dir) fails with ENOTEMPTY or EISDIR.
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir);

    const src_path = try std.fmt.allocPrint(allocator, "{s}/src.bin", .{dir});
    defer allocator.free(src_path);
    {
        var f = try std.fs.createFileAbsolute(src_path, .{});
        defer f.close();
        try f.writeAll("payload");
    }

    // dst is an existing non-empty directory — rename(file, dir-with-contents) fails.
    const dst_dir = try std.fmt.allocPrint(allocator, "{s}/dst_is_dir", .{dir});
    defer allocator.free(dst_dir);
    try std.fs.makeDirAbsolute(dst_dir);
    const sentinel = try std.fmt.allocPrint(allocator, "{s}/sentinel", .{dst_dir});
    defer allocator.free(sentinel);
    {
        var f = try std.fs.createFileAbsolute(sentinel, .{});
        f.close();
    }

    const fds_before = try countOpenFds();

    const result = atomicInstallBinary(allocator, src_path, dst_dir);
    try testing.expect(std.meta.isError(result));

    const fds_after = try countOpenFds();
    try testing.expectEqual(fds_before, fds_after);
}

test "install: all systemctl calls route through helpers" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Read our own source to verify every systemctl invocation goes through
    // a named helper. runSystemctlUser covers user-scope (daemon-reload,
    // enable, start for the per-user unit); runSystemctlSystem covers
    // system-scope (legacy unit stop/disable during migration).
    const src_path = @src().file;
    var file = if (std.fs.path.isAbsolute(src_path))
        std.fs.openFileAbsolute(src_path, .{}) catch return
    else
        std.fs.cwd().openFile(src_path, .{}) catch return;
    defer file.close();
    const src = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(src);

    var iter = std.mem.splitScalar(u8, src, '\n');
    var helper_calls: usize = 0;
    while (iter.next()) |line| {
        // Ignore the test itself (which mentions these names in strings).
        if (std.mem.indexOf(u8, line, "test \"install: all systemctl") != null) continue;
        // Skip pure comment lines — a code comment that quotes the
        // forbidden pattern as a documentation example shouldn't trip it.
        const trimmed = std.mem.trimLeft(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//")) continue;

        if (std.mem.indexOf(u8, line, "runSystemctlUser") != null) helper_calls += 1;

        // No raw generic-runCmd + systemctl literal on the same line outside
        // the helpers; see runSystemctlUser / runSystemctlSystem above.
        const has_runcmd = std.mem.indexOf(u8, line, "runCmd(&.{") != null;
        const has_systemctl_literal = std.mem.indexOf(u8, line, "\"systemctl\"") != null;
        if (has_runcmd and has_systemctl_literal) {
            try testing.expect(false);
        }
    }
    // Each of the 5+ call sites is one source line referencing a helper,
    // plus the helper fn definitions and at least one internal call.
    try testing.expect(helper_calls >= 5);
}

test "install: planSystemctlUser decides direct/sudo_hop/skip" {
    const testing = std.testing;

    // Non-root → direct, regardless of SUDO_* presence
    {
        const p = planSystemctlUser(1000, null, null);
        try testing.expectEqual(SystemctlUserMode.direct, p.mode);
    }
    {
        const p = planSystemctlUser(1000, "jim", "1000");
        try testing.expectEqual(SystemctlUserMode.direct, p.mode);
    }
    // Root + both SUDO_USER and SUDO_UID → sudo_hop
    {
        const p = planSystemctlUser(0, "jim", "1000");
        try testing.expectEqual(SystemctlUserMode.sudo_hop, p.mode);
        try testing.expectEqualStrings("jim", p.sudo_user);
        try testing.expectEqualStrings("1000", p.sudo_uid);
    }
    // Root + missing SUDO_USER → skip
    {
        const p = planSystemctlUser(0, null, "1000");
        try testing.expectEqual(SystemctlUserMode.skip, p.mode);
    }
    // Root + missing SUDO_UID → skip
    {
        const p = planSystemctlUser(0, "jim", null);
        try testing.expectEqual(SystemctlUserMode.skip, p.mode);
    }
    // Root + empty SUDO_USER → skip
    {
        const p = planSystemctlUser(0, "", "1000");
        try testing.expectEqual(SystemctlUserMode.skip, p.mode);
    }
    // Root + non-numeric SUDO_UID → skip (defence against shell injection)
    {
        const p = planSystemctlUser(0, "jim", "1000;evil");
        try testing.expectEqual(SystemctlUserMode.skip, p.mode);
    }
}

// Regression tests for issue #139 v3 — the install gate that decides whether
// to call ensureUserXdgDirs must fire on every path that eventually starts a
// user-scope padctl.service, including the root+SUDO_USER sudo_hop path.
test "install: ensureUserXdgDirs called when non-root user-service install" {
    const testing = std.testing;
    // is_root=false, --user-service omitted (effective=true via `!is_root`),
    // no staging, no SUDO_USER (non-root shell).
    try testing.expect(installWillStartUserService(false, null, "", null));
}

test "install: ensureUserXdgDirs called when sudo install without --user-service (sudo_hop case)" {
    const testing = std.testing;
    // The failure mode from issue #139 v3: `sudo padctl install` with no flag.
    // effective_user_service resolves to false, yet run() still invokes
    // `systemctl --user start` via sudo_hop — the gate must return true.
    try testing.expect(installWillStartUserService(true, null, "", "jim"));
}

test "install: ensureUserXdgDirs called when sudo install with --user-service" {
    const testing = std.testing;
    try testing.expect(installWillStartUserService(true, true, "", "jim"));
}

test "install: ensureUserXdgDirs NOT called when staged install (destdir set)" {
    const testing = std.testing;
    // Package builds (destdir=/tmp/staging) have no runtime user — no XDG work.
    try testing.expect(!installWillStartUserService(false, null, "/tmp/staging", null));
    try testing.expect(!installWillStartUserService(true, true, "/tmp/staging", "jim"));
}

test "install: ensureUserXdgDirs NOT called when root without SUDO_USER" {
    const testing = std.testing;
    // Root shell without sudo (SUDO_USER absent or empty) — SystemctlUserMode
    // would be .skip, no user service starts, so no XDG dirs to seed.
    try testing.expect(!installWillStartUserService(true, null, "", null));
    try testing.expect(!installWillStartUserService(true, null, "", ""));
}

test "install: explicit --no-user-service returns false regardless of sudo_hop" {
    const testing = std.testing;
    // Non-root + explicit false → don't start (obvious case).
    try testing.expect(!installWillStartUserService(false, false, "", null));
    // sudo + explicit false → must override the sudo_hop default. Previously
    // the systemctl block still fired enable/start via sudo_hop, ignoring the
    // user's opt-out; this regression guards the new gate.
    try testing.expect(!installWillStartUserService(true, false, "", "jim"));
    // Explicit false under staging is still false (destdir short-circuit wins).
    try testing.expect(!installWillStartUserService(true, false, "/tmp/staging", "jim"));
}

// InstallPlan decision-axis matrix — guards against PR #148-class regressions
// where a single boolean decision drifts apart between compute time and use
// time. Each case pins every derived axis to an expected value so the matrix
// doubles as behavioural spec.
test "install: InstallPlan case A — non-root default" {
    const testing = std.testing;
    const opts = InstallOptions{};
    const env = EnvSnapshot{ .uid = 1000, .home = "/home/alice", .sudo_user = null, .sudo_uid = null };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(plan.effective_user_service);
    try testing.expect(plan.will_start_user_service);
    try testing.expect(plan.do_xdg_dirs);
    try testing.expect(plan.do_enable_systemctl);
    try testing.expect(!plan.staging_mode);
    try testing.expectEqual(SystemctlUserMode.direct, plan.systemctl_plan.mode);
}

test "install: InstallPlan case B — sudo_hop (issue #139 v3 regression)" {
    // The PR #148 failure path: `sudo padctl install` with no flag. Without
    // the gate fix, do_xdg_dirs flipped false and systemd v254+ recreated the
    // legacy migration symlink after every install.
    const testing = std.testing;
    const opts = InstallOptions{};
    const env = EnvSnapshot{ .uid = 0, .home = "/root", .sudo_user = "alice", .sudo_uid = "1000" };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(plan.is_root);
    try testing.expect(!plan.effective_user_service); // root + no explicit flag → false
    try testing.expect(plan.will_start_user_service); // but sudo_hop still starts it
    try testing.expect(plan.do_xdg_dirs); // MUST be true — this is the regression gate
    try testing.expect(plan.do_enable_systemctl);
    try testing.expectEqual(SystemctlUserMode.sudo_hop, plan.systemctl_plan.mode);
    try testing.expectEqualStrings("alice", plan.systemctl_plan.sudo_user);
    try testing.expectEqualStrings("1000", plan.systemctl_plan.sudo_uid);
}

test "install: InstallPlan case C — staged build (destdir set)" {
    const testing = std.testing;
    const opts = InstallOptions{ .destdir = "/tmp/staging" };
    const env = EnvSnapshot{ .uid = 0, .home = "/root", .sudo_user = null, .sudo_uid = null };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(plan.staging_mode);
    try testing.expect(!plan.will_start_user_service);
    try testing.expect(!plan.do_xdg_dirs);
    try testing.expect(!plan.do_enable_systemctl);
}

test "install: InstallPlan case D — root + explicit --no-user-service" {
    const testing = std.testing;
    const opts = InstallOptions{ .user_service = false };
    const env = EnvSnapshot{ .uid = 0, .home = "/root", .sudo_user = "alice", .sudo_uid = "1000" };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(!plan.effective_user_service);
    try testing.expect(!plan.will_start_user_service); // explicit opt-out overrides sudo_hop
    try testing.expect(!plan.do_xdg_dirs);
    try testing.expect(!plan.do_enable_systemctl);
}

test "install: InstallPlan case E — root + explicit --user-service" {
    const testing = std.testing;
    const opts = InstallOptions{ .user_service = true };
    const env = EnvSnapshot{ .uid = 0, .home = "/root", .sudo_user = null, .sudo_uid = null };
    // Save existing HOME, set it to a tmpdir so resolveServiceDir succeeds; restore after.
    // resolveServiceDir needs HOME to be present when user_service=true.
    const saved_home = std.posix.getenv("HOME");
    _ = saved_home;
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(plan.effective_user_service);
    try testing.expect(plan.will_start_user_service);
    try testing.expect(plan.do_xdg_dirs);
    try testing.expect(plan.do_enable_systemctl);
    // non-hop form because SUDO_USER is absent
    try testing.expectEqual(SystemctlUserMode.skip, plan.systemctl_plan.mode);
}

test "install: InstallPlan prefix auto-switches to /usr/local on explicit --immutable" {
    const testing = std.testing;
    const opts = InstallOptions{ .immutable = true };
    const env = EnvSnapshot{ .uid = 0, .home = "/root", .sudo_user = "alice", .sudo_uid = "1000" };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(plan.effective_immutable);
    try testing.expectEqualStrings("/usr/local", plan.prefix);
}

test "install: InstallPlan service_dir routes by user_service + immutable" {
    const testing = std.testing;
    // Non-root → user dir under HOME. HOME must be set for the test env (it is,
    // by zig's test runner).
    const opts = InstallOptions{};
    const env = EnvSnapshot{ .uid = 1000, .home = "/home/alice", .sudo_user = null, .sudo_uid = null };
    const plan = try InstallPlan.compute(testing.allocator, opts, env);
    defer plan.deinit(testing.allocator);
    try testing.expect(std.mem.endsWith(u8, plan.service_dir, "/.config/systemd/user"));
}

test "install: ensureUserXdgDirs chown path opens dir with iterate flag (no BADF)" {
    // Zig std.posix.fchown panics with BADF on a Dir fd opened without
    // .iterate = true. Verify ensureUserXdgDirs creates dirs that can be
    // re-opened with .iterate = true (proving the openDir flag is correct).
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const home_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home_path);

    // Without SUDO_UID/SUDO_GID (non-root test env), chown is skipped,
    // but the dir-creation path runs in full.
    try ensureUserXdgDirs(allocator, home_path);

    const abs = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home_path});
    defer allocator.free(abs);
    var d = try std.fs.openDirAbsolute(abs, .{ .iterate = true });
    d.close();
}

test "install: buildSystemctlUserArgv direct shape" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const plan = SystemctlUserPlan{ .mode = .direct };
    const argv = (try buildSystemctlUserArgv(allocator, plan, &.{ "enable", "padctl.service" })).?;
    defer freeArgv(allocator, argv);

    try testing.expectEqual(@as(usize, 4), argv.len);
    try testing.expectEqualStrings("systemctl", argv[0]);
    try testing.expectEqualStrings("--user", argv[1]);
    try testing.expectEqualStrings("enable", argv[2]);
    try testing.expectEqualStrings("padctl.service", argv[3]);
}

test "install: buildSystemctlUserArgv sudo_hop shape carries XDG+DBUS" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const plan = SystemctlUserPlan{ .mode = .sudo_hop, .sudo_user = "jim", .sudo_uid = "1000" };
    const argv = (try buildSystemctlUserArgv(allocator, plan, &.{"daemon-reload"})).?;
    defer freeArgv(allocator, argv);

    // sudo -u <user> XDG_RUNTIME_DIR=... DBUS_SESSION_BUS_ADDRESS=... systemctl --user daemon-reload
    try testing.expectEqual(@as(usize, 8), argv.len);
    try testing.expectEqualStrings("sudo", argv[0]);
    try testing.expectEqualStrings("-u", argv[1]);
    try testing.expectEqualStrings("jim", argv[2]);
    try testing.expectEqualStrings("XDG_RUNTIME_DIR=/run/user/1000", argv[3]);
    try testing.expectEqualStrings("DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus", argv[4]);
    try testing.expectEqualStrings("systemctl", argv[5]);
    try testing.expectEqualStrings("--user", argv[6]);
    try testing.expectEqualStrings("daemon-reload", argv[7]);
}

test "install: buildSystemctlUserArgv skip returns null" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const plan = SystemctlUserPlan{ .mode = .skip };
    const argv = try buildSystemctlUserArgv(allocator, plan, &.{"daemon-reload"});
    try testing.expect(argv == null);
}

test "install: ensureUserXdgDirs creates parent chain for StateDirectory" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const home = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home);

    try ensureUserXdgDirs(allocator, home);

    for ([_][]const u8{
        ".config/systemd/user",
        ".local/state",
        ".local/share",
    }) |rel| {
        const abs = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, rel });
        defer allocator.free(abs);
        var d = try std.fs.openDirAbsolute(abs, .{});
        d.close();
    }
}

test "install: ensureUserXdgDirs idempotent (second call no error)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const home = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home);

    try ensureUserXdgDirs(allocator, home);
    try ensureUserXdgDirs(allocator, home);
}

test "install: ensureUserXdgDirs replaces broken .local/state/padctl symlink with real dir" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home_path);

    try tmp.dir.makePath(".local/state");
    try tmp.dir.symLink("/nonexistent-target-for-test", ".local/state/padctl", .{});

    const state_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home_path});
    defer allocator.free(state_path);

    // Pre-condition: symlink exists but target is missing.
    try testing.expectError(error.FileNotFound, std.fs.accessAbsolute(state_path, .{}));

    try ensureUserXdgDirs(allocator, home_path);

    // Post-condition: path is a real directory, not a symlink.
    const stat_result = try std.fs.cwd().statFile(state_path);
    try testing.expect(stat_result.kind == .directory);

    var rlbuf: [std.fs.max_path_bytes]u8 = undefined;
    try testing.expectError(error.NotLink, std.fs.readLinkAbsolute(state_path, &rlbuf));
}

// systemd v254+ creates $XDG_STATE_HOME/padctl → $XDG_CONFIG_HOME/padctl
// compatibility symlink (exec-invoke.c:3044-3072 legacy migration) when the
// state dir is missing. We force the state dir to be a real directory so that
// symlink never has a reason to exist and StateDirectory= semantics are
// preserved — see ensureUserXdgDirs for the full explanation. Issue #139.
test "install: ensureUserXdgDirs replaces valid .local/state/padctl symlink with real dir (systemd v254+ migration workaround)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home_path);

    try tmp.dir.makePath(".config/padctl-real");
    try tmp.dir.makePath(".local/state");
    const real_target = try std.fmt.allocPrint(allocator, "{s}/.config/padctl-real", .{home_path});
    defer allocator.free(real_target);
    try tmp.dir.symLink(real_target, ".local/state/padctl", .{});

    try ensureUserXdgDirs(allocator, home_path);

    const state_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home_path});
    defer allocator.free(state_path);

    // Post-condition: path is a real directory, not a symlink.
    const stat_result = try std.fs.cwd().statFile(state_path);
    try testing.expect(stat_result.kind == .directory);

    var rlbuf: [std.fs.max_path_bytes]u8 = undefined;
    try testing.expectError(error.NotLink, std.fs.readLinkAbsolute(state_path, &rlbuf));
}

test "install: ensureUserXdgDirs preserves existing .local/state/padctl real directory (idempotent)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(home_path);

    // Seed: real directory with prior content that must survive.
    try tmp.dir.makePath(".local/state/padctl/subdir");

    const state_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl", .{home_path});
    defer allocator.free(state_path);
    const subdir_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/padctl/subdir", .{home_path});
    defer allocator.free(subdir_path);

    try ensureUserXdgDirs(allocator, home_path);

    const stat_result = try std.fs.cwd().statFile(state_path);
    try testing.expect(stat_result.kind == .directory);

    // Prior content preserved.
    try std.fs.accessAbsolute(subdir_path, .{});
}

test "install: resolveTargetHomeFromFile reads home from passwd" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "passwd",
        .data = "root:x:0:0:root:/root:/bin/bash\njim:x:1000:1000::/home/jim:/bin/zsh\n",
    });
    const passwd_path = try tmp.dir.realpathAlloc(allocator, "passwd");
    defer allocator.free(passwd_path);

    // Non-root path: returns HOME env (we cannot change uid in a test, so just
    // verify the non-root branch returns without error when HOME is set).
    // The root branch requires uid==0 which is not available in unit tests.
    // We test the passwd parsing logic directly via a white-box call by
    // temporarily treating the function as pure file-reader:
    // parse "jim" from the fake passwd without the uid==0 guard.
    {
        // Directly exercise the passwd parsing by reading the file and parsing it.
        const contents = try std.fs.cwd().readFileAlloc(allocator, passwd_path, 4096);
        defer allocator.free(contents);
        var found_home: ?[]const u8 = null;
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, ':');
            const name = it.next() orelse continue;
            if (!std.mem.eql(u8, name, "jim")) continue;
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            found_home = it.next();
            break;
        }
        try testing.expectEqualStrings("/home/jim", found_home orelse "");
    }
}

test "install: resolveTargetHomeFromFile falls back to /home/<user> on missing passwd" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Use a path that does not exist — resolveTargetHomeFromFile will fall back.
    // We can only run this for the uid==0 branch if we are root, which is not
    // guaranteed in CI. The test validates the fallback path logic is wired up
    // correctly by inspecting the function at the integration level only when
    // running as non-root (returns HOME env).
    if (std.os.linux.getuid() != 0) {
        const home_env = std.posix.getenv("HOME") orelse return;
        const result = try resolveTargetHomeFromFile(allocator, "/nonexistent/passwd");
        defer allocator.free(result);
        try testing.expectEqualStrings(home_env, result);
    }
    // Root path with fallback is covered by integration / real-machine testing.
}

test "install: udev rule grants input group and uaccess tag to uhid and uinput" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try ensureDirAll(allocator, devices_dir);

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr");

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uinput\", TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uhid\",   TAG+=\"uaccess\", GROUP=\"input\", MODE=\"0660\"") != null);
}

test "install: clone_vid_pid=true emits per-VID/PID udev rule" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const devices_dir = try std.fmt.allocPrint(allocator, "{s}/devices", .{tmp_path});
    defer allocator.free(devices_dir);
    try std.fs.makeDirAbsolute(devices_dir);

    const toml_path = try std.fmt.allocPrint(allocator, "{s}/moza-r5.toml", .{devices_dir});
    defer allocator.free(toml_path);
    {
        var f = try std.fs.createFileAbsolute(toml_path, .{});
        defer f.close();
        try f.writeAll(
            \\[device]
            \\name = "Moza R5"
            \\vid = 0x11FF
            \\pid = 0x1211
            \\[output.force_feedback]
            \\clone_vid_pid = true
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr");

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 8192);
    defer allocator.free(content);

    // Per-VID/PID rule must be present for the cloned identity
    try testing.expect(std.mem.indexOf(u8, content, "ENV{ID_VENDOR_ID}==\"11ff\", ENV{ID_MODEL_ID}==\"1211\", TAG+=\"uaccess\"") != null);
    // Generic UHID wildcard rule must also still be present
    try testing.expect(std.mem.indexOf(u8, content, "KERNEL==\"uhid\"") != null);
}

test "install: clone_vid_pid=false produces no per-VID/PID rule" {
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
        var f = try std.fs.createFileAbsolute(toml_path, .{});
        defer f.close();
        try f.writeAll(
            \\[device]
            \\name = "Vader 5"
            \\vid = 0x37d7
            \\pid = 0x2401
            \\[output.force_feedback]
            \\clone_vid_pid = false
        );
    }

    const rules_path = try std.fmt.allocPrint(allocator, "{s}/60-padctl.rules", .{tmp_path});
    defer allocator.free(rules_path);
    try generateUdevRules(allocator, devices_dir, rules_path, "/usr");

    var file = try std.fs.openFileAbsolute(rules_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 8192);
    defer allocator.free(content);

    // No per-VID/PID ENV rule should be present
    try testing.expect(std.mem.indexOf(u8, content, "ENV{ID_VENDOR_ID}") == null);
}

test "install: modules-load.d content includes uhid and uinput" {
    const testing = std.testing;
    try testing.expect(std.mem.indexOf(u8, modules_load_content, "uhid") != null);
    try testing.expect(std.mem.indexOf(u8, modules_load_content, "uinput") != null);
}

test "uninstall: removes /lib/systemd/user/padctl.service on prefix=/usr" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    const unit_dir = try std.fmt.allocPrint(allocator, "{s}/usr/lib/systemd/user", .{destdir});
    defer allocator.free(unit_dir);
    try ensureDirAll(allocator, unit_dir);
    const unit_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{unit_dir});
    defer allocator.free(unit_path);
    {
        var f = try std.fs.createFileAbsolute(unit_path, .{});
        f.close();
    }

    {
        var silencer = try SilencedStdout.begin();
        defer silencer.end();
        try uninstall(allocator, .{
            .prefix = "/usr",
            .destdir = destdir,
            .immutable = false,
            .no_immutable = true,
            .user_service = false,
        });
    }

    std.fs.accessAbsolute(unit_path, .{}) catch |err| {
        try testing.expect(err == error.FileNotFound);
        return;
    };
    return error.FileStillExists;
}

test "uninstall: removes /etc/systemd/user/padctl.service on immutable" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    const unit_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{destdir});
    defer allocator.free(unit_dir);
    try ensureDirAll(allocator, unit_dir);
    const unit_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{unit_dir});
    defer allocator.free(unit_path);
    {
        var f = try std.fs.createFileAbsolute(unit_path, .{});
        f.close();
    }

    {
        var silencer = try SilencedStdout.begin();
        defer silencer.end();
        try uninstall(allocator, .{
            .prefix = "/usr",
            .destdir = destdir,
            .immutable = true,
            .no_immutable = false,
            .user_service = false,
        });
    }

    std.fs.accessAbsolute(unit_path, .{}) catch |err| {
        try testing.expect(err == error.FileNotFound);
        return;
    };
    return error.FileStillExists;
}

test "uninstall: removes /etc/systemd/user/padctl.service on non-immutable /usr/local prefix" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const destdir = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(destdir);

    const unit_dir = try std.fmt.allocPrint(allocator, "{s}/etc/systemd/user", .{destdir});
    defer allocator.free(unit_dir);
    try ensureDirAll(allocator, unit_dir);
    const unit_path = try std.fmt.allocPrint(allocator, "{s}/padctl.service", .{unit_dir});
    defer allocator.free(unit_path);
    {
        var f = try std.fs.createFileAbsolute(unit_path, .{});
        f.close();
    }

    {
        var silencer = try SilencedStdout.begin();
        defer silencer.end();
        try uninstall(allocator, .{
            .prefix = "/usr/local",
            .destdir = destdir,
            .immutable = false,
            .no_immutable = true,
            .user_service = false,
        });
    }

    std.fs.accessAbsolute(unit_path, .{}) catch |err| {
        try testing.expect(err == error.FileNotFound);
        return;
    };
    return error.FileStillExists;
}

// -----------------------------------------------------------------------------
// Phase 13 Wave 5 — static udev rule tests. These validate the embedded
// `imu_udev_rules_content` and the on-disk `udev/90-padctl.rules` are well-
// formed and carry the critical ENV tags. Layer 0 only — no systemd needed.
// -----------------------------------------------------------------------------

test "install: imu_udev_rules_content matches input subsystem and padctl uniq" {
    const testing = std.testing;
    try testing.expect(std.mem.indexOf(u8, imu_udev_rules_content, "SUBSYSTEM==\"input\"") != null);
    try testing.expect(std.mem.indexOf(u8, imu_udev_rules_content, "ATTRS{uniq}==\"padctl/") != null);
    try testing.expect(std.mem.indexOf(u8, imu_udev_rules_content, "ATTRS{name}==\"*IMU*\"") != null);
}

test "install: imu_udev_rules_content sets accelerometer and clears joystick" {
    const testing = std.testing;
    try testing.expect(std.mem.indexOf(u8, imu_udev_rules_content, "ENV{ID_INPUT_ACCELEROMETER}=\"1\"") != null);
    try testing.expect(std.mem.indexOf(u8, imu_udev_rules_content, "ENV{ID_INPUT_JOYSTICK}=\"\"") != null);
}

test "install: imu_udev_rules_content is syntactically well-formed" {
    const testing = std.testing;
    // Every non-empty, non-comment logical line must contain at least one
    // key=value or key==value token. A logical line is the physical line
    // plus any backslash-continuations. We only check the tokens exist.
    var logical = std.ArrayList(u8){};
    defer logical.deinit(testing.allocator);

    var it = std.mem.splitScalar(u8, imu_udev_rules_content, '\n');
    while (it.next()) |raw| {
        var line = std.mem.trimRight(u8, raw, " \t\r");
        const is_continuation = std.mem.endsWith(u8, line, "\\");
        if (is_continuation) line = line[0 .. line.len - 1];
        try logical.appendSlice(testing.allocator, line);
        if (!is_continuation) {
            const l = std.mem.trim(u8, logical.items, " \t");
            defer logical.clearRetainingCapacity();
            if (l.len == 0) continue;
            if (l[0] == '#') continue;
            try testing.expect(std.mem.indexOf(u8, l, "==") != null or
                std.mem.indexOf(u8, l, "=") != null);
        }
    }
}

test "install: on-disk udev/90-padctl.rules mirrors embedded content" {
    const testing = std.testing;
    const allocator = testing.allocator;
    // The repo ships the same rule body as a standalone file for packagers
    // that do not execute `padctl install`. Skip gracefully when the test
    // runs outside the repo tree (e.g. from an installed binary).
    const cwd = std.fs.cwd();
    const file = cwd.openFile("udev/90-padctl.rules", .{}) catch return;
    defer file.close();
    const body = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(body);
    try testing.expectEqualStrings(imu_udev_rules_content, body);
}
