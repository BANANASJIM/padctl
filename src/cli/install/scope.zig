// LifecycleScope: single source of truth for install/uninstall scope.
//
// Replaces ad-hoc derivation of {staging_mode, effective_user_service,
// do_xdg_dirs, do_enable_systemctl, ...} at multiple call sites with one
// pure function `detect()` called once at parse time.

const std = @import("std");

pub const LifecycleScope = enum {
    /// Staged build for a downstream packager. No live runtime touch:
    /// no systemctl, no socket probe, no dangling-symlink GC.
    package,
    /// Root install to /usr or /usr/local with a system-scope padctl.service.
    system,
    /// Unprivileged install to $HOME/.local with a user-scope padctl.service.
    user,
};

pub const ScopeError = error{
    NonRootSystemPrefix,
    RootUserScopeNoSudoUser,
};

pub const DetectInput = struct {
    destdir: []const u8 = "",
    forced_scope: ?LifecycleScope = null,
    install_phase_env: ?[]const u8 = null,
    destdir_env: ?[]const u8 = null,
    euid: u32,
    sudo_user_env: ?[]const u8 = null,
    prefix: []const u8 = "/usr/local",
};

/// True iff `prefix` is system territory off-limits to a non-root install.
/// `/usr/local` is the documented sanctioned non-root sibling, everything
/// else under `/usr` is rejected.
fn rejectsSystemPrefix(prefix: []const u8) bool {
    if (std.mem.eql(u8, prefix, "/usr")) return true;
    return std.mem.startsWith(u8, prefix, "/usr/") and
        !std.mem.startsWith(u8, prefix, "/usr/local");
}

pub fn detect(input: DetectInput) ScopeError!LifecycleScope {
    // 1. Package mode is unconditional — any packager-set signal wins.
    //    Empty-but-set env vars (common in Makefiles: `export DESTDIR=`) do
    //    NOT count as a signal; require non-empty content.
    if (input.destdir.len > 0) return .package;
    if (input.install_phase_env) |v| {
        if (std.mem.eql(u8, v, "package")) return .package;
    }
    if (input.destdir_env) |v| {
        if (v.len > 0) return .package;
    }

    // 2. Explicit --scope override, validated against current privilege.
    if (input.forced_scope) |s| {
        if (s == .system and input.euid != 0) return error.NonRootSystemPrefix;
        if (s == .user and input.euid == 0 and input.sudo_user_env == null) {
            return error.RootUserScopeNoSudoUser;
        }
        if (s == .user and input.euid != 0 and rejectsSystemPrefix(input.prefix)) {
            return error.NonRootSystemPrefix;
        }
        return s;
    }

    // 3. Privilege auto-detect.
    if (input.euid == 0) return .system;

    // 4. Non-root + system-territory prefix is structurally impossible.
    if (rejectsSystemPrefix(input.prefix)) return error.NonRootSystemPrefix;

    return .user;
}

test "scope: package via destdir" {
    const got = try detect(.{ .destdir = "/tmp/staging", .euid = 0 });
    try std.testing.expectEqual(LifecycleScope.package, got);
}

test "scope: package via PADCTL_INSTALL_PHASE env" {
    const got = try detect(.{ .install_phase_env = "package", .euid = 0 });
    try std.testing.expectEqual(LifecycleScope.package, got);
}

test "scope: package via DESTDIR env" {
    const got = try detect(.{ .destdir_env = "/tmp/staging", .euid = 0 });
    try std.testing.expectEqual(LifecycleScope.package, got);
}

test "scope: system auto when root" {
    const got = try detect(.{ .euid = 0, .prefix = "/usr" });
    try std.testing.expectEqual(LifecycleScope.system, got);
}

test "scope: user auto when non-root" {
    const got = try detect(.{ .euid = 1000, .prefix = "/home/u/.local" });
    try std.testing.expectEqual(LifecycleScope.user, got);
}

test "scope: NonRootSystemPrefix when non-root targets /usr" {
    try std.testing.expectError(error.NonRootSystemPrefix, detect(.{
        .euid = 1000,
        .prefix = "/usr",
    }));
}

test "scope: RootUserScopeNoSudoUser when root forces user without SUDO_USER" {
    try std.testing.expectError(error.RootUserScopeNoSudoUser, detect(.{
        .euid = 0,
        .forced_scope = .user,
        .sudo_user_env = null,
    }));
}

test "scope: forced system as root" {
    const got = try detect(.{ .euid = 0, .forced_scope = .system });
    try std.testing.expectEqual(LifecycleScope.system, got);
}

test "scope: forced user with SUDO_USER under root" {
    const got = try detect(.{
        .euid = 0,
        .forced_scope = .user,
        .sudo_user_env = "jim",
    });
    try std.testing.expectEqual(LifecycleScope.user, got);
}

test "scope: forced package always works regardless of euid" {
    const got_root = try detect(.{ .euid = 0, .forced_scope = .package });
    try std.testing.expectEqual(LifecycleScope.package, got_root);
    const got_user = try detect(.{ .euid = 1000, .forced_scope = .package });
    try std.testing.expectEqual(LifecycleScope.package, got_user);
}

test "scope: empty DESTDIR env does not force .package" {
    const got = try detect(.{
        .euid = 0,
        .destdir_env = "",
        .prefix = "/usr",
    });
    try std.testing.expectEqual(LifecycleScope.system, got);
}

test "scope: PADCTL_INSTALL_PHASE=package triggers .package" {
    const got = try detect(.{
        .euid = 0,
        .install_phase_env = "package",
        .prefix = "/usr",
    });
    try std.testing.expectEqual(LifecycleScope.package, got);
}

test "scope: forced user with /usr prefix non-root errors" {
    try std.testing.expectError(error.NonRootSystemPrefix, detect(.{
        .euid = 1000,
        .forced_scope = .user,
        .prefix = "/usr",
    }));
}

test "scope: forced user with $HOME prefix non-root works" {
    const got = try detect(.{
        .euid = 1000,
        .forced_scope = .user,
        .prefix = "/home/u/.local",
    });
    try std.testing.expectEqual(LifecycleScope.user, got);
}
