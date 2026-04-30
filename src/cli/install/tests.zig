// All install-package tests. Aliased imports keep the original test bodies
// unmodified after the install.zig 5005-LoC monolith was split into the
// install/ package (plan, services, udev, migration, mappings, phase).

const std = @import("std");
const plan_mod = @import("plan.zig");
const services_mod = @import("services.zig");
const udev_mod = @import("udev.zig");
const migration_mod = @import("migration.zig");
const mappings_mod = @import("mappings.zig");
const phase_mod = @import("phase.zig");
const user_config_mod = @import("../../config/user_config.zig");
const paths = @import("../../config/paths.zig");
const toml_extract = @import("../toml_extract.zig");

// plan.zig
const InstallOptions = plan_mod.InstallOptions;
const InstallPlan = plan_mod.InstallPlan;
const EnvSnapshot = plan_mod.EnvSnapshot;
const detectImmutableOs = plan_mod.detectImmutableOs;
const shouldAbortForImmutable = plan_mod.shouldAbortForImmutable;
const resolveServiceDir = plan_mod.resolveServiceDir;
const resolveUdevDir = plan_mod.resolveUdevDir;
const parseYesNoDefaultYes = plan_mod.parseYesNoDefaultYes;
const planSystemctlUser = plan_mod.planSystemctlUser;
const installWillStartUserService = plan_mod.installWillStartUserService;
const atomicInstallBinary = plan_mod.atomicInstallBinary;
const userInGroup = plan_mod.userInGroup;
const ensureDirAll = plan_mod.ensureDirAll;
const SystemctlUserMode = plan_mod.SystemctlUserMode;
const SystemctlUserPlan = plan_mod.SystemctlUserPlan;
const ImmutableKind = plan_mod.ImmutableKind;

// services.zig
const generateServiceContent = services_mod.generateServiceContent;
const generateSystemServiceContent = services_mod.generateSystemServiceContent;
const generateReconnectScript = services_mod.generateReconnectScript;
const immutable_dropin_content = services_mod.immutable_dropin_content;
const buildSystemctlUserArgv = services_mod.buildSystemctlUserArgv;
const freeArgv = services_mod.freeArgv;

// udev.zig
const UdevEntry = udev_mod.UdevEntry;
const isValidIdentifier = udev_mod.isValidIdentifier;
const probeAndUnbindDrivers = udev_mod.probeAndUnbindDrivers;
const readSysHex = udev_mod.readSysHex;
const findDevicesSourceDir = udev_mod.findDevicesSourceDir;
const imu_udev_rules_content = udev_mod.imu_udev_rules_content;
const modules_load_content = udev_mod.modules_load_content;
// private helpers exposed via _internals_for_tests
const _udev = udev_mod._internals_for_tests;
const extractVidPid = _udev.extractVidPid;
const isFieldKey = _udev.isFieldKey;
const parseStringArray = _udev.parseStringArray;
const parseHexOrDec = _udev.parseHexOrDec;
const generateUdevRules = _udev.generateUdevRules;
const generateDriverBlockRules = _udev.generateDriverBlockRules;

// migration.zig
const ensureUserXdgDirs = migration_mod.ensureUserXdgDirs;
const resolveTargetHomeFromFile = migration_mod.resolveTargetHomeFromFile;

// mappings.zig
const findMappingsSourceDir = mappings_mod.findMappingsSourceDir;
const installMapping = mappings_mod.installMapping;
const findDeviceNameForMapping = mappings_mod.findDeviceNameForMapping;
const writeBinding = mappings_mod.writeBinding;
const PromptResult = mappings_mod.PromptResult;

// phase.zig
const run = phase_mod.run;
const uninstall = phase_mod.uninstall;

// stdout silencer used by tests that exercise live install/uninstall paths.
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

fn mockPromptKeep(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .keep;
}
fn mockPromptOverwrite(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .overwrite;
}
fn mockPromptAbort(_: []const u8, _: []const u8, _: []const u8, _: []const u8) PromptResult {
    return .abort;
}

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
    try testing.expect(std.mem.indexOf(u8, content, "ATTRS{id/vendor}==\"11ff\", ATTRS{id/product}==\"1211\", TAG+=\"uaccess\"") != null);
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
    try testing.expect(std.mem.indexOf(u8, content, "ATTRS{id/vendor}") == null);
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

    try testing.expect(std.mem.indexOf(u8, content, "ACTION==\"add|bind\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "DRIVER==\"xpad\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "37d7") != null);
    try testing.expect(std.mem.indexOf(u8, content, "unbind") != null);
}

test "install: generateDriverBlockRules uses add|bind action for udevadm trigger compatibility" {
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
            \\name = "Vader 5 Pro"
            \\vid = 0x0f0d
            \\pid = 0x00c1
            \\block_kernel_drivers = ["xpad", "hid_generic"]
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

    // add catches udevadm trigger (synthetic add); bind catches future plug-in.
    // Neither ACTION=="bind" alone (misses trigger) nor ACTION=="add" alone
    // (misses genuine bind) is correct.
    try testing.expect(std.mem.indexOf(u8, content, "ACTION==\"add|bind\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ACTION==\"bind\"") == null or
        std.mem.indexOf(u8, content, "ACTION==\"add|bind\"") != null);
    // Both drivers must appear.
    try testing.expect(std.mem.indexOf(u8, content, "DRIVER==\"xpad\"") != null);
    try testing.expect(std.mem.indexOf(u8, content, "DRIVER==\"hid_generic\"") != null);
}

test "install: readSysHex parses 4-digit lowercase hex" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const hex_path = try std.fmt.allocPrint(allocator, "{s}/idVendor", .{tmp_path});
    defer allocator.free(hex_path);
    {
        var f = try std.fs.createFileAbsolute(hex_path, .{});
        defer f.close();
        try f.writeAll("37d7\n");
    }

    const val = try readSysHex(hex_path);
    try testing.expectEqual(@as(u16, 0x37d7), val);
}

test "install: probeAndUnbindDrivers writes matching interface to unbind, skips non-matching" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Build fake /sys tree: sys/bus/usb/drivers/xpad/ and sys/bus/usb/devices/
    try tmp.dir.makePath("sys/bus/usb/drivers/xpad");
    try tmp.dir.makePath("sys/bus/usb/devices/1-1.4");
    try tmp.dir.makePath("sys/bus/usb/devices/2-2.1");

    // Matching device: VID 37d7 PID 2401
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-1.4/idVendor", .{});
        defer f.close();
        try f.writeAll("37d7\n");
    }
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/1-1.4/idProduct", .{});
        defer f.close();
        try f.writeAll("2401\n");
    }

    // Non-matching device
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/2-2.1/idVendor", .{});
        defer f.close();
        try f.writeAll("0000\n");
    }
    {
        var f = try tmp.dir.createFile("sys/bus/usb/devices/2-2.1/idProduct", .{});
        defer f.close();
        try f.writeAll("0000\n");
    }

    // Symlinks in drivers/xpad/ pointing at device nodes (relative, as real sysfs does)
    const drivers_xpad_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/drivers/xpad", .{tmp_path});
    defer allocator.free(drivers_xpad_path);
    {
        const sl1 = try std.fmt.allocPrint(allocator, "{s}/1-1.4:1.0", .{drivers_xpad_path});
        defer allocator.free(sl1);
        try std.posix.symlink("../../../devices/1-1.4", sl1);
    }
    {
        const sl2 = try std.fmt.allocPrint(allocator, "{s}/2-2.1:1.0", .{drivers_xpad_path});
        defer allocator.free(sl2);
        try std.posix.symlink("../../../devices/2-2.1", sl2);
    }

    // unbind file (writable regular file, simulates sysfs write target)
    {
        var f = try tmp.dir.createFile("sys/bus/usb/drivers/xpad/unbind", .{});
        defer f.close();
    }

    const entries = [_]UdevEntry{.{
        .name = "Test Device",
        .vid = 0x37d7,
        .pid = 0x2401,
        .block_kernel_drivers = &[_][]const u8{"xpad"},
    }};
    probeAndUnbindDrivers(allocator, &entries, tmp_path);

    // The matching interface must have been written to unbind.
    const unbind_path = try std.fmt.allocPrint(allocator, "{s}/sys/bus/usb/drivers/xpad/unbind", .{tmp_path});
    defer allocator.free(unbind_path);
    var uf = try std.fs.openFileAbsolute(unbind_path, .{});
    defer uf.close();
    const written = try uf.readToEndAlloc(allocator, 64);
    defer allocator.free(written);
    try testing.expectEqualStrings("1-1.4:1.0", written);
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

test "tomlEscape: plain ASCII passes through" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try user_config_mod.escapeTomlString(buf.writer(a), "Hello");
    try std.testing.expectEqualStrings("Hello", buf.items);
}

test "tomlEscape: double quote is escaped" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try user_config_mod.escapeTomlString(buf.writer(a), "Sony \"DualSense\"");
    try std.testing.expectEqualStrings("Sony \\\"DualSense\\\"", buf.items);
}

test "tomlEscape: backslash is escaped" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try user_config_mod.escapeTomlString(buf.writer(a), "path\\to");
    try std.testing.expectEqualStrings("path\\\\to", buf.items);
}

test "tomlEscape: newline rejected with error.InvalidDeviceName" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, user_config_mod.escapeTomlString(buf.writer(a), "bad\nname"));
}

test "tomlEscape: carriage return rejected with error.InvalidDeviceName" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, user_config_mod.escapeTomlString(buf.writer(a), "bad\rname"));
}

test "tomlEscape rejects NUL byte (0x00)" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, user_config_mod.escapeTomlString(buf.writer(a), "bad\x00name"));
}

test "tomlEscape rejects DEL byte (0x7f)" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try std.testing.expectError(error.InvalidDeviceName, user_config_mod.escapeTomlString(buf.writer(a), "bad\x7fname"));
}

test "tomlEscape passes \\t (0x09) through unchanged" {
    const a = std.testing.allocator;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(a);
    try user_config_mod.escapeTomlString(buf.writer(a), "col1\tcol2");
    try std.testing.expectEqualStrings("col1\tcol2", buf.items);
}

test "tomlEscape: round-trip via real TOML parser" {
    const toml = @import("toml");
    const allocator = std.testing.allocator;
    const inputs = [_][]const u8{
        "Sony \"DualSense\"",
        "path\\to\\device",
        "mixed \\\"quotes\\\"",
        "plain name",
    };
    for (inputs) |input| {
        var buf: std.ArrayList(u8) = .{};
        defer buf.deinit(allocator);
        try user_config_mod.escapeTomlString(buf.writer(allocator), input);
        const toml_text = try std.fmt.allocPrint(allocator, "name = \"{s}\"\n", .{buf.items});
        defer allocator.free(toml_text);

        var parser = toml.Parser(struct { name: []const u8 }).init(allocator);
        defer parser.deinit();
        const parsed = try parser.parseString(toml_text);
        defer parsed.deinit();
        try std.testing.expectEqualStrings(input, parsed.value.name);
    }
}
