const std = @import("std");
const plan_mod = @import("plan.zig");
const assets = @import("completion_assets");

pub const bash_source = assets.bash_source;
pub const zsh_source = assets.zsh_source;

fn installFile(allocator: std.mem.Allocator, directory: []const u8, name: []const u8, content: []const u8) !void {
    try plan_mod.ensureDirAll(allocator, directory);
    const path = try std.fs.path.join(allocator, &.{ directory, name });
    defer allocator.free(path);

    const temporary_path = try std.fmt.allocPrint(allocator, "{s}.new", .{path});
    defer allocator.free(temporary_path);
    errdefer std.fs.deleteFileAbsolute(temporary_path) catch {};

    var file = try std.fs.createFileAbsolute(temporary_path, .{ .truncate = true, .mode = 0o644 });
    errdefer file.close();
    try file.writeAll(content);
    try file.chmod(0o644);
    try file.sync();
    try std.posix.rename(temporary_path, path);
    file.close();
}

pub fn install(allocator: std.mem.Allocator, plan: *const plan_mod.InstallPlan) !void {
    try installFile(allocator, plan.bash_completion_dir, "padctl.bash", bash_source);
    try installFile(allocator, plan.zsh_completion_dir, "_padctl", zsh_source);
}

fn removeFile(allocator: std.mem.Allocator, directory: []const u8, name: []const u8) void {
    const path = std.fs.path.join(allocator, &.{ directory, name }) catch return;
    defer allocator.free(path);
    if (std.fs.deleteFileAbsolute(path)) |_| {
        plan_mod.writeAll(std.posix.STDOUT_FILENO, "  removed ");
        plan_mod.writeAll(std.posix.STDOUT_FILENO, path);
        plan_mod.writeAll(std.posix.STDOUT_FILENO, "\n");
    } else |_| {}
}

pub fn uninstall(allocator: std.mem.Allocator, bash_dir: []const u8, zsh_dir: []const u8) void {
    removeFile(allocator, bash_dir, "padctl.bash");
    removeFile(allocator, zsh_dir, "_padctl");

    // Debian and Ubuntu packages relocate the same function into their
    // distro-specific discovery directory after running the installer.
    const zsh_share_dir = std.fs.path.dirname(zsh_dir) orelse return;
    const vendor_dir = std.fs.path.join(allocator, &.{ zsh_share_dir, "vendor-completions" }) catch return;
    defer allocator.free(vendor_dir);
    removeFile(allocator, vendor_dir, "_padctl");
}

pub const ActivationHintKind = enum { none, user_zsh, custom_prefix };

pub fn activationHintKind(scope: plan_mod.LifecycleScope, prefix: []const u8) ActivationHintKind {
    if (scope == .package) return .none;
    if (scope == .user) return .user_zsh;
    if (!std.mem.eql(u8, prefix, "/usr") and !std.mem.eql(u8, prefix, "/usr/local")) {
        return .custom_prefix;
    }
    return .none;
}

pub fn printActivationHint(plan: *const plan_mod.InstallPlan) void {
    const hint_kind = activationHintKind(plan.scope, plan.prefix);
    if (hint_kind == .none) return;

    if (hint_kind == .custom_prefix) {
        const bash_parent = std.fs.path.dirname(plan.bash_completion_dir) orelse plan.bash_completion_dir;
        const bash_share_root = std.fs.path.dirname(bash_parent) orelse bash_parent;

        plan_mod.writeAll(std.posix.STDOUT_FILENO, "\nCompletion files were installed under a custom prefix, which shells may not discover automatically.\n");
        plan_mod.writeAll(std.posix.STDOUT_FILENO, "Bash: source the completion file directly (portable across supported bash-completion versions):\n  source \"");
        plan_mod.writeAll(std.posix.STDOUT_FILENO, plan.bash_completion_dir);
        plan_mod.writeAll(std.posix.STDOUT_FILENO, "/padctl.bash\"\nBash-completion 2.12+ can instead discover the custom prefix when XDG_DATA_DIRS includes:\n  export XDG_DATA_DIRS=\"");
        plan_mod.writeAll(std.posix.STDOUT_FILENO, bash_share_root);
        plan_mod.writeAll(std.posix.STDOUT_FILENO,
            \\:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        );
    } else {
        plan_mod.writeAll(std.posix.STDOUT_FILENO, "\nZsh completion was installed in a user site-functions directory, which is not guaranteed to be in fpath.\n");
    }

    plan_mod.writeAll(std.posix.STDOUT_FILENO, "Zsh: add its function directory to fpath before compinit in ~/.zshrc:\n  fpath=(\"");
    plan_mod.writeAll(std.posix.STDOUT_FILENO, plan.zsh_completion_dir);
    plan_mod.writeAll(std.posix.STDOUT_FILENO,
        \\" $fpath)
        \\  autoload -Uz compinit && compinit
        \\The installer does not edit shell startup files or .zcompdump. If completion was already initialized, refresh compinit; an old .zcompdump may otherwise hide the new function.
        \\
    );
}
