const std = @import("std");

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
    // Use statFile instead of accessAbsolute to avoid unreachable panic
    // on unexpected errno (e.g. ELOOP/SymLinkLoop on some CI runners).
    const ostree_path = std.fmt.allocPrint(allocator, "{s}/run/ostree-booted", .{root_prefix}) catch return .none;
    defer allocator.free(ostree_path);
    if (std.fs.cwd().statFile(ostree_path)) |_| {
        return .ostree;
    } else |_| {}

    const usr_path = std.fmt.allocPrint(allocator, "{s}/usr", .{root_prefix}) catch return .none;
    defer allocator.free(usr_path);
    if (std.fs.cwd().statFile(usr_path)) |stat| {
        if (stat.mode & 0o200 == 0) return .read_only_usr;
    } else |_| {
        return .none;
    }
    return .none;
}

pub fn shouldAbortForImmutable(kind: ImmutableKind, opts: InstallOptions) bool {
    return kind != .none and !opts.immutable and !opts.no_immutable;
}

pub fn resolveServiceDir(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool, user_service: bool) ![]const u8 {
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

pub fn resolveUdevDir(allocator: std.mem.Allocator, destdir: []const u8, prefix: []const u8, immutable: bool) ![]const u8 {
    if (immutable) {
        return std.fmt.allocPrint(allocator, "{s}/etc/udev/rules.d", .{destdir});
    }
    return std.fmt.allocPrint(allocator, "{s}{s}/lib/udev/rules.d", .{ destdir, prefix });
}

pub fn writeAll(fd: std.posix.fd_t, s: []const u8) void {
    _ = std.posix.write(fd, s) catch {};
}

pub fn ensureDir(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

pub fn ensureDirAll(allocator: std.mem.Allocator, path: []const u8) !void {
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

pub fn dirExistsAbsolute(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

pub fn dirIsNonEmpty(path: []const u8) bool {
    var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch return false;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch return false) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".toml")) return true;
        if (entry.kind == .directory) return true;
    }
    return false;
}

pub fn copyFile(src: []const u8, dst: []const u8) !void {
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
pub fn atomicInstallBinary(allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
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
    // Rename before close: on rename failure errdefer closes the fd exactly once.
    try std.posix.rename(tmp, dst);
    tmp_file.close();
}

pub fn runCmd(argv: []const []const u8) void {
    var child = std.process.Child.init(argv, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawnAndWait() catch {};
}

/// Like runCmd but warns on non-zero exit. Used for critical steps (enable/start).
pub fn runCmdWarn(argv: []const []const u8) void {
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

/// Ask a y/n question on stderr and read the answer from stdin.
/// Default-yes: empty input, any "y*", any "Y*" → true.
/// When stdin is not a TTY (CI / scripted install), return true
/// without prompting so non-interactive runs proceed with cleanup.
pub fn promptYesNoDefaultYes(question: []const u8) bool {
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
pub fn parseYesNoDefaultYes(raw: []const u8) bool {
    const answer = std.mem.trim(u8, raw, " \t\r\n");
    if (answer.len == 0) return true;
    return answer[0] == 'y' or answer[0] == 'Y';
}

/// Returns the GID for the named group by parsing /etc/group, or null on failure.
pub fn groupGid(name: []const u8) ?std.os.linux.gid_t {
    const f = std.fs.openFileAbsolute("/etc/group", .{}) catch return null;
    defer f.close();
    var buf: [4096]u8 = undefined;
    const n = f.readAll(&buf) catch return null;
    var it = std.mem.splitScalar(u8, buf[0..n], '\n');
    while (it.next()) |line| {
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
pub fn userInGroup(name: []const u8) bool {
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

/// Invocation mode for `systemctl --user` commands from within `padctl install`.
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
/// systemd v254+ does not auto-create the legacy-migration symlink. Issue #139.
pub fn installWillStartUserService(
    is_root: bool,
    user_service_opt: ?bool,
    destdir: []const u8,
    sudo_user_env: ?[]const u8,
) bool {
    if (destdir.len != 0) return false; // staged package build — no live user service
    if (user_service_opt) |explicit| return explicit;
    if (!is_root) return true;
    if (sudo_user_env) |su| {
        if (su.len != 0) return true;
    }
    return false;
}

/// Snapshot of the process environment that feeds `InstallPlan.compute`.
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
/// in `compute()` so later phases read a plain struct instead of re-deriving.
/// Addresses the PR #148 gate bug where `effective_user_service` was re-tested
/// at the wrong call site.
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

        // staging mode (--destdir set, packaging build) always writes to system path
        const effective_user_service = opts.user_service orelse (!is_root and !staging_mode);

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
