const std = @import("std");
const device_config = @import("../config/device.zig");
const paths = @import("../config/paths.zig");
const user_config = @import("../config/user_config.zig");

pub const Action = union(enum) {
    list: struct { device: ?[]const u8 = null },
    select: struct { profile: []const u8, device: []const u8 },
    reset: struct { device: []const u8 },
};

pub const ParseError = error{
    MissingSubcommand,
    MissingArgument,
    MissingDevice,
    UnexpectedArgument,
    UnknownSubcommand,
};

pub const help_text =
    \\Usage: padctl output-profile list [--device <name>]
    \\       padctl output-profile select <profile> --device <name>
    \\       padctl output-profile reset --device <name>
    \\
    \\List or persist a device output profile. Changes are saved without an
    \\explicit reload; running user daemons normally watch the file.
    \\
;

fn inlineOptionValue(arg: []const u8, option: []const u8) ?[]const u8 {
    if (arg.len <= option.len or arg[option.len] != '=') return null;
    if (!std.mem.eql(u8, arg[0..option.len], option)) return null;
    return arg[option.len + 1 ..];
}

pub fn parseArgs(args: []const []const u8) ParseError!Action {
    if (args.len == 0) return error.MissingSubcommand;
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        var device: ?[]const u8 = null;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (device != null) return error.UnexpectedArgument;
            if (std.mem.eql(u8, args[i], "--device")) {
                i += 1;
                if (i >= args.len) return error.MissingArgument;
                device = args[i];
            } else if (inlineOptionValue(args[i], "--device")) |value| {
                device = value;
            } else {
                return error.UnexpectedArgument;
            }
        }
        return .{ .list = .{ .device = device } };
    }
    if (std.mem.eql(u8, sub, "select")) {
        var profile: ?[]const u8 = null;
        var device: ?[]const u8 = null;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--device")) {
                i += 1;
                if (i >= args.len) return error.MissingArgument;
                if (device != null) return error.UnexpectedArgument;
                device = args[i];
            } else if (inlineOptionValue(args[i], "--device")) |value| {
                if (device != null) return error.UnexpectedArgument;
                device = value;
            } else {
                if (profile != null or args[i].len == 0 or args[i][0] == '-') return error.UnexpectedArgument;
                profile = args[i];
            }
        }
        return .{ .select = .{
            .profile = profile orelse return error.MissingArgument,
            .device = device orelse return error.MissingDevice,
        } };
    }
    if (std.mem.eql(u8, sub, "reset")) {
        var device: ?[]const u8 = null;
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (device != null) return error.UnexpectedArgument;
            if (std.mem.eql(u8, args[i], "--device")) {
                i += 1;
                if (i >= args.len) return error.MissingArgument;
                device = args[i];
            } else if (inlineOptionValue(args[i], "--device")) |value| {
                device = value;
            } else {
                return error.UnexpectedArgument;
            }
        }
        return .{ .reset = .{ .device = device orelse return error.MissingDevice } };
    }
    return error.UnknownSubcommand;
}

const ProfileInfo = struct {
    device: []u8,
    profile: []u8,
    backend: []u8,
    protocol: []u8,
    stick_range: []u8,

    fn deinit(self: *ProfileInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.device);
        allocator.free(self.profile);
        allocator.free(self.backend);
        allocator.free(self.protocol);
        allocator.free(self.stick_range);
    }
};

const DeviceIdentity = struct { vid: i64, pid: i64 };

const Catalog = struct {
    profiles: std.ArrayList(ProfileInfo) = .{},
    device_names: std.ArrayList([]u8) = .{},
    device_ids: std.ArrayList(DeviceIdentity) = .{},

    fn deinit(self: *Catalog, allocator: std.mem.Allocator) void {
        for (self.profiles.items) |*profile| profile.deinit(allocator);
        self.profiles.deinit(allocator);
        for (self.device_names.items) |name| allocator.free(name);
        self.device_names.deinit(allocator);
        self.device_ids.deinit(allocator);
    }

    fn canonicalDevice(self: *const Catalog, name: []const u8) ?[]const u8 {
        for (self.device_names.items) |candidate| {
            if (std.ascii.eqlIgnoreCase(candidate, name)) return candidate;
        }
        return null;
    }

    fn hasProfile(self: *const Catalog, device: []const u8, profile: []const u8) bool {
        for (self.profiles.items) |candidate| {
            if (std.mem.eql(u8, candidate.device, device) and std.mem.eql(u8, candidate.profile, profile)) return true;
        }
        return false;
    }

    fn hasIdentity(self: *const Catalog, vid: i64, pid: i64) bool {
        for (self.device_ids.items) |identity| {
            if (identity.vid == vid and identity.pid == pid) return true;
        }
        return false;
    }
};

fn lessString(_: void, a: []u8, b: []u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn lessProfile(_: void, a: ProfileInfo, b: ProfileInfo) bool {
    const device_order = std.mem.order(u8, a.device, b.device);
    if (device_order != .eq) return device_order == .lt;
    return std.mem.lessThan(u8, a.profile, b.profile);
}

fn resolvedBackend(out: device_config.OutputConfig) []const u8 {
    if (!std.mem.eql(u8, out.backend, "auto")) return out.backend;
    if (out.imu) |imu| {
        if (std.mem.eql(u8, imu.backend, "uhid")) return "uhid";
    }
    if (out.force_feedback) |ffb| {
        if (std.mem.eql(u8, ffb.backend, "uhid")) return "uhid";
    }
    return "uinput";
}

fn formatStickRange(allocator: std.mem.Allocator, out: device_config.OutputConfig) ![]u8 {
    const axes = out.axes orelse return allocator.dupe(u8, "n/a");
    const names = [_][]const u8{ "left_x", "left_y", "right_x", "right_y" };
    const first = axes.map.get(names[0]) orelse return allocator.dupe(u8, "n/a");
    for (names[1..]) |name| {
        const axis = axes.map.get(name) orelse return allocator.dupe(u8, "n/a");
        if (axis.min != first.min or axis.max != first.max) return allocator.dupe(u8, "mixed");
    }
    return std.fmt.allocPrint(allocator, "{d}..{d}", .{ first.min, first.max });
}

fn addProfile(
    allocator: std.mem.Allocator,
    catalog: *Catalog,
    config_path: []const u8,
    canonical_device: []const u8,
    profile_name: []const u8,
) !void {
    var parsed = try device_config.parseFile(allocator, config_path);
    defer parsed.deinit();
    if (!device_config.selectOutputProfile(&parsed.value, profile_name)) return error.InvalidConfig;
    const out = parsed.value.output orelse return error.InvalidConfig;

    var item = ProfileInfo{
        .device = try allocator.dupe(u8, canonical_device),
        .profile = undefined,
        .backend = undefined,
        .protocol = undefined,
        .stick_range = undefined,
    };
    errdefer allocator.free(item.device);
    item.profile = try allocator.dupe(u8, profile_name);
    errdefer allocator.free(item.profile);
    item.backend = try allocator.dupe(u8, resolvedBackend(out));
    errdefer allocator.free(item.backend);
    item.protocol = try allocator.dupe(u8, out.protocol);
    errdefer allocator.free(item.protocol);
    item.stick_range = try formatStickRange(allocator, out);
    errdefer allocator.free(item.stick_range);
    try catalog.profiles.append(allocator, item);
}

fn collectConfigPaths(allocator: std.mem.Allocator, dir_path: []const u8) !std.ArrayList([]u8) {
    var files: std.ArrayList([]u8) = .{};
    errdefer {
        for (files.items) |path| allocator.free(path);
        files.deinit(allocator);
    }
    var dir = if (std.fs.path.isAbsolute(dir_path))
        std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return files
    else
        std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return files;
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".toml")) continue;
        const path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
        files.append(allocator, path) catch |err| {
            allocator.free(path);
            return err;
        };
    }
    std.mem.sort([]u8, files.items, {}, lessString);
    return files;
}

fn buildCatalog(allocator: std.mem.Allocator, device_dirs: []const []const u8) !Catalog {
    var catalog = Catalog{};
    errdefer catalog.deinit(allocator);

    // The first XDG layer defining a physical VID:PID owns it completely,
    // even if an override changes the human-readable device name.
    for (device_dirs) |dir_path| {
        var config_paths = try collectConfigPaths(allocator, dir_path);
        defer {
            for (config_paths.items) |path| allocator.free(path);
            config_paths.deinit(allocator);
        }
        for (config_paths.items) |config_path| {
            var parsed = device_config.parseFile(allocator, config_path) catch |err| {
                std.log.warn("output-profile: ignoring invalid device config {s}: {}", .{ config_path, err });
                continue;
            };
            defer parsed.deinit();
            const canonical_device = parsed.value.device.name;
            const vid = parsed.value.device.vid;
            const pid = parsed.value.device.pid;
            if (catalog.hasIdentity(vid, pid)) continue;

            const owned_name = try allocator.dupe(u8, canonical_device);
            catalog.device_names.append(allocator, owned_name) catch |err| {
                allocator.free(owned_name);
                return err;
            };
            try catalog.device_ids.append(allocator, .{ .vid = vid, .pid = pid });

            var profile_names: std.ArrayList([]u8) = .{};
            defer {
                for (profile_names.items) |name| allocator.free(name);
                profile_names.deinit(allocator);
            }
            if (parsed.value.output) |out| {
                if (out.default_profile) |default_profile| {
                    const owned_profile = try allocator.dupe(u8, default_profile);
                    profile_names.append(allocator, owned_profile) catch |err| {
                        allocator.free(owned_profile);
                        return err;
                    };
                }
                if (out.profiles) |profiles| {
                    var it = profiles.map.iterator();
                    while (it.next()) |entry| {
                        const name = entry.key_ptr.*;
                        var duplicate = false;
                        for (profile_names.items) |existing| {
                            if (std.mem.eql(u8, existing, name)) {
                                duplicate = true;
                                break;
                            }
                        }
                        if (!duplicate) {
                            const owned_profile = try allocator.dupe(u8, name);
                            profile_names.append(allocator, owned_profile) catch |err| {
                                allocator.free(owned_profile);
                                return err;
                            };
                        }
                    }
                }
            }
            std.mem.sort([]u8, profile_names.items, {}, lessString);
            for (profile_names.items) |profile_name| {
                try addProfile(allocator, &catalog, config_path, canonical_device, profile_name);
            }
        }
    }
    std.mem.sort(ProfileInfo, catalog.profiles.items, {}, lessProfile);
    return catalog;
}

fn reportMutationError(err_writer: anytype, err: anyerror) void {
    switch (err) {
        error.MalformedConfig => err_writer.writeAll("error: user config.toml is malformed; fix it before changing output profiles\n") catch {},
        error.NoHomeDir => err_writer.writeAll("error: HOME/XDG_CONFIG_HOME is required to write user config\n") catch {},
        else => err_writer.print("error: could not write user config: {}\n", .{err}) catch {},
    }
}

pub fn runWithPaths(
    allocator: std.mem.Allocator,
    action: Action,
    device_dirs: []const []const u8,
    user_dir: ?[]const u8,
    system_dir: []const u8,
    writer: anytype,
    err_writer: anytype,
) u8 {
    var catalog = buildCatalog(allocator, device_dirs) catch |err| {
        err_writer.print("error: could not load output profiles: {}\n", .{err}) catch {};
        return 1;
    };
    defer catalog.deinit(allocator);

    switch (action) {
        .list => |opts| {
            const canonical_filter = if (opts.device) |device| blk: {
                break :blk catalog.canonicalDevice(device) orelse {
                    err_writer.print("error: unknown device: {s}\n", .{device}) catch {};
                    return 1;
                };
            } else null;
            writer.writeAll("DEVICE\tPROFILE\tBACKEND\tPROTOCOL\tSTICK_RANGE\n") catch return 1;
            for (catalog.profiles.items) |profile| {
                if (canonical_filter) |device| {
                    if (!std.mem.eql(u8, profile.device, device)) continue;
                }
                writer.print("{s}\t{s}\t{s}\t{s}\t{s}\n", .{
                    profile.device,
                    profile.profile,
                    profile.backend,
                    profile.protocol,
                    profile.stick_range,
                }) catch return 1;
            }
            return 0;
        },
        .select => |opts| {
            const canonical_device = catalog.canonicalDevice(opts.device) orelse {
                err_writer.print("error: unknown device: {s}\n", .{opts.device}) catch {};
                return 1;
            };
            if (!catalog.hasProfile(canonical_device, opts.profile)) {
                err_writer.print("error: unknown output profile for {s}: {s}\n", .{ canonical_device, opts.profile }) catch {};
                return 1;
            }
            const target_user_dir = user_dir orelse {
                err_writer.writeAll("error: HOME/XDG_CONFIG_HOME is required to write user config\n") catch {};
                return 1;
            };
            user_config.updateOutputProfileInDirs(allocator, target_user_dir, system_dir, canonical_device, opts.profile) catch |err| {
                reportMutationError(err_writer, err);
                return 1;
            };
            writer.print("selected {s} for {s}; saved (running user daemons normally watch this file, otherwise reload or restart)\n", .{ opts.profile, canonical_device }) catch {};
            return 0;
        },
        .reset => |opts| {
            const canonical_device = catalog.canonicalDevice(opts.device) orelse {
                err_writer.print("error: unknown device: {s}\n", .{opts.device}) catch {};
                return 1;
            };
            const target_user_dir = user_dir orelse {
                err_writer.writeAll("error: HOME/XDG_CONFIG_HOME is required to write user config\n") catch {};
                return 1;
            };
            user_config.updateOutputProfileInDirs(allocator, target_user_dir, system_dir, canonical_device, null) catch |err| {
                reportMutationError(err_writer, err);
                return 1;
            };
            writer.print("reset output profile for {s}; saved (running user daemons normally watch this file, otherwise reload or restart)\n", .{canonical_device}) catch {};
            return 0;
        },
    }
}

pub fn run(allocator: std.mem.Allocator, action: Action, writer: anytype, err_writer: anytype) u8 {
    const device_dirs = paths.resolveDeviceConfigDirs(allocator) catch |err| {
        err_writer.print("error: could not resolve device configs: {}\n", .{err}) catch {};
        return 1;
    };
    defer paths.freeConfigDirs(allocator, device_dirs);

    const user_dir = paths.userConfigDir(allocator) catch null;
    defer if (user_dir) |dir| allocator.free(dir);
    return runWithPaths(allocator, action, device_dirs, user_dir, paths.systemConfigDir(), writer, err_writer);
}

test "output-profile parser enforces select and reset device" {
    const select_args = [_][]const u8{ "select", "dualsense-edge-native", "--device", "Flydigi Vader 5 Pro" };
    const selected = try parseArgs(&select_args);
    try std.testing.expectEqualStrings("dualsense-edge-native", selected.select.profile);
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", selected.select.device);

    const missing_device = [_][]const u8{ "select", "dualsense-edge-native" };
    try std.testing.expectError(error.MissingDevice, parseArgs(&missing_device));
    const reset_missing = [_][]const u8{"reset"};
    try std.testing.expectError(error.MissingDevice, parseArgs(&reset_missing));
}

test "output-profile parser accepts inline device values" {
    const list_args = [_][]const u8{ "list", "--device=Flydigi Vader 5 Pro" };
    const listed = try parseArgs(&list_args);
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", listed.list.device.?);

    const select_args = [_][]const u8{ "select", "dualsense-edge-native", "--device=Flydigi Vader 5 Pro" };
    const selected = try parseArgs(&select_args);
    try std.testing.expectEqualStrings("dualsense-edge-native", selected.select.profile);
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", selected.select.device);

    const reset_args = [_][]const u8{ "reset", "--device=Flydigi Vader 5 Pro" };
    const reset = try parseArgs(&reset_args);
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", reset.reset.device);
}

test "output-profile list is sorted and shows resolved route" {
    const allocator = std.testing.allocator;
    const dirs = [_][]const u8{"devices/flydigi"};
    const action = Action{ .list = .{ .device = "Flydigi Vader 5 Pro" } };
    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    var err_out: std.ArrayList(u8) = .{};
    defer err_out.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), runWithPaths(
        allocator,
        action,
        &dirs,
        null,
        "/nonexistent",
        out.writer(allocator),
        err_out.writer(allocator),
    ));
    try std.testing.expectEqualStrings(
        "DEVICE\tPROFILE\tBACKEND\tPROTOCOL\tSTICK_RANGE\n" ++
            "Flydigi Vader 5 Pro\tdualsense-edge\tuinput\tgeneric\t-32768..32767\n" ++
            "Flydigi Vader 5 Pro\tdualsense-edge-native\tuhid\tdualsense-edge-usb\t0..255\n" ++
            "Flydigi Vader 5 Pro\txbox-elite2\tuinput\tgeneric\t-32768..32767\n",
        out.items,
    );
    try std.testing.expectEqualStrings("", err_out.items);
}

test "output-profile canonicalizes device case but profile remains strict" {
    const allocator = std.testing.allocator;
    const dirs = [_][]const u8{"devices/flydigi"};
    var out: std.ArrayList(u8) = .{};
    defer out.deinit(allocator);
    var err_out: std.ArrayList(u8) = .{};
    defer err_out.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 1), runWithPaths(
        allocator,
        .{ .select = .{ .profile = "DualSense-Edge-Native", .device = "flydigi vader 5 pro" } },
        &dirs,
        "/nonexistent",
        "/nonexistent",
        out.writer(allocator),
        err_out.writer(allocator),
    ));
    try std.testing.expect(std.mem.indexOf(u8, err_out.items, "unknown output profile for Flydigi Vader 5 Pro") != null);
}

test "output-profile XDG override shadows builtin by VID PID and invalid neighbors are skipped" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.makeDir("user");
    try tmp.dir.makeDir("builtin");
    const source = try std.fs.cwd().readFileAlloc(allocator, "devices/flydigi/vader5.toml", 1024 * 1024);
    defer allocator.free(source);
    const renamed = try std.mem.replaceOwned(
        u8,
        allocator,
        source,
        "name = \"Flydigi Vader 5 Pro\"",
        "name = \"My Vader Override\"",
    );
    defer allocator.free(renamed);
    {
        const file = try tmp.dir.createFile("user/override.toml", .{});
        defer file.close();
        try file.writeAll(renamed);
    }
    {
        const file = try tmp.dir.createFile("user/broken.toml", .{});
        defer file.close();
        try file.writeAll("not valid {{{ TOML");
    }
    {
        const file = try tmp.dir.createFile("builtin/vader5.toml", .{});
        defer file.close();
        try file.writeAll(source);
    }
    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);
    const user_dir = try std.fmt.allocPrint(allocator, "{s}/user", .{root});
    defer allocator.free(user_dir);
    const builtin_dir = try std.fmt.allocPrint(allocator, "{s}/builtin", .{root});
    defer allocator.free(builtin_dir);
    const dirs = [_][]const u8{ user_dir, builtin_dir };

    var catalog = try buildCatalog(allocator, &dirs);
    defer catalog.deinit(allocator);
    try std.testing.expect(catalog.canonicalDevice("my vader override") != null);
    try std.testing.expect(catalog.canonicalDevice("Flydigi Vader 5 Pro") == null);
    try std.testing.expectEqual(@as(usize, 3), catalog.profiles.items.len);
    for (catalog.profiles.items) |profile| {
        try std.testing.expectEqualStrings("My Vader Override", profile.device);
    }
}
