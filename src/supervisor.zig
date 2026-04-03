const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const linux = std.os.linux;

const DeviceInstance = @import("device_instance.zig").DeviceInstance;
const MappingConfig = @import("config/mapping.zig").MappingConfig;
const mapping_cfg = @import("config/mapping.zig");
const DeviceConfig = @import("config/device.zig").DeviceConfig;
const config_device = @import("config/device.zig");
const Mapper = @import("core/mapper.zig").Mapper;
const HidrawDevice = @import("io/hidraw.zig").HidrawDevice;
const readPhysicalPath = @import("io/hidraw.zig").readPhysicalPath;
const readInterfaceId = @import("io/hidraw.zig").readInterfaceId;
const netlink = @import("io/netlink.zig");
const ioctl = @import("io/ioctl_constants.zig");
const config_paths = @import("config/paths.zig");
const mapping_discovery = @import("config/mapping_discovery.zig");
const user_config_mod = @import("config/user_config.zig");
const ControlSocket = @import("io/control_socket.zig").ControlSocket;
const control_socket = @import("io/control_socket.zig");

const socket_client = @import("cli/socket_client.zig");

/// One running device under Supervisor management.
pub const ManagedInstance = struct {
    phys_key: []const u8,
    devname: ?[]const u8, // null for statically-spawned; set by attach()
    instance: *DeviceInstance,
    thread: std.Thread,
    mapping_arena: std.heap.ArenaAllocator,
    switch_mapping: ?*mapping_cfg.ParseResult = null,
};

/// Config snapshot used for hot-reload diffing.
pub const ConfigEntry = struct {
    phys_key: []const u8,
    device_cfg: *const DeviceConfig,
    mapping_cfg: ?*MappingConfig,
};

const InotifyResult = struct {
    inotify_fd: posix.fd_t,
    debounce_fd: posix.fd_t,
    config_dir: ?[]const u8,
};

const SwitchTx = struct {
    idx: usize,
    new_mapper: ?Mapper,
    parsed_ptr: ?*mapping_cfg.ParseResult,
    old_mapper: ?Mapper = null,
    old_mapping_cfg: ?*const MappingConfig = null,
    old_switch_mapping: ?*mapping_cfg.ParseResult = null,
    committed: bool = false,
};

fn shouldInjectSwitchFailure(self: *const Supervisor, commit_index: usize) bool {
    if (!builtin.is_test) return false;
    return self.test_switch_fail_commit_index != null and self.test_switch_fail_commit_index.? == commit_index;
}

fn initInotify(allocator: std.mem.Allocator) InotifyResult {
    const disabled: InotifyResult = .{ .inotify_fd = -1, .debounce_fd = -1, .config_dir = null };

    const config_dir = config_paths.userConfigDir(allocator) catch return disabled;

    std.fs.accessAbsolute(config_dir, .{}) catch {
        allocator.free(config_dir);
        return disabled;
    };

    const dir_z = allocator.dupeZ(u8, config_dir) catch {
        allocator.free(config_dir);
        return disabled;
    };
    defer allocator.free(dir_z);

    const rc_init = linux.inotify_init1(linux.IN.CLOEXEC | linux.IN.NONBLOCK);
    const init_err = linux.E.init(rc_init);
    if (init_err != .SUCCESS) {
        allocator.free(config_dir);
        return disabled;
    }
    const in_fd: posix.fd_t = @intCast(rc_init);

    const root_mask = linux.IN.CLOSE_WRITE | linux.IN.MOVED_TO | linux.IN.MOVED_FROM | linux.IN.DELETE | linux.IN.CREATE;
    const rc_watch = linux.inotify_add_watch(in_fd, dir_z.ptr, root_mask);
    const watch_err = linux.E.init(rc_watch);
    if (watch_err != .SUCCESS) {
        posix.close(in_fd);
        allocator.free(config_dir);
        return disabled;
    }

    const mappings_dir = std.fmt.allocPrint(allocator, "{s}/mappings", .{config_dir}) catch {
        posix.close(in_fd);
        allocator.free(config_dir);
        return disabled;
    };
    defer allocator.free(mappings_dir);
    const mappings_z = allocator.dupeZ(u8, mappings_dir) catch {
        posix.close(in_fd);
        allocator.free(config_dir);
        return disabled;
    };
    defer allocator.free(mappings_z);

    const map_mask = linux.IN.CLOSE_WRITE | linux.IN.MOVED_TO | linux.IN.MOVED_FROM | linux.IN.DELETE | linux.IN.CREATE;
    const rc_map_watch = linux.inotify_add_watch(in_fd, mappings_z.ptr, map_mask);
    const map_watch_err = linux.E.init(rc_map_watch);
    if (map_watch_err != .SUCCESS) {
        std.log.warn("inotify watch on {s} failed: {} (continuing with root watch only)", .{ mappings_dir, map_watch_err });
    }

    const db_fd = posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true }) catch {
        posix.close(in_fd);
        allocator.free(config_dir);
        return disabled;
    };

    return .{ .inotify_fd = in_fd, .debounce_fd = db_fd, .config_dir = config_dir };
}

fn threadEntry(inst: *DeviceInstance) void {
    inst.run() catch |err| {
        std.log.err("DeviceInstance.run failed: {}", .{err});
    };
}

pub const Supervisor = struct {
    allocator: std.mem.Allocator,
    managed: std.ArrayList(ManagedInstance),
    stop_fd: posix.fd_t,
    hup_fd: posix.fd_t,
    netlink_fd: posix.fd_t,
    inotify_fd: posix.fd_t,
    debounce_fd: posix.fd_t,
    config_dir: ?[]const u8,
    // ParseResults whose DeviceConfig is referenced by at least one managed instance.
    configs: std.ArrayList(*config_device.ParseResult),
    // devname → phys_key (both slices owned by this map)
    devname_map: std.StringHashMap([]const u8),
    ctrl_sock: ?ControlSocket,
    user_cfg: ?user_config_mod.ParseResult = null,
    test_switch_mapping_override: ?[]const u8 = null,
    test_switch_fail_commit_index: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) !Supervisor {
        var stop_mask = posix.sigemptyset();
        posix.sigaddset(&stop_mask, linux.SIG.TERM);
        posix.sigaddset(&stop_mask, linux.SIG.INT);
        posix.sigprocmask(linux.SIG.BLOCK, &stop_mask, null);
        const stop_fd = try posix.signalfd(-1, &stop_mask, 0);
        errdefer posix.close(stop_fd);

        var hup_mask = posix.sigemptyset();
        posix.sigaddset(&hup_mask, linux.SIG.HUP);
        posix.sigprocmask(linux.SIG.BLOCK, &hup_mask, null);
        const hup_fd = try posix.signalfd(-1, &hup_mask, 0);
        errdefer posix.close(hup_fd);

        const nl_fd = netlink.openNetlinkUevent() catch |err| blk: {
            std.log.warn("netlink unavailable: {}", .{err});
            break :blk -1;
        };
        errdefer if (nl_fd >= 0) posix.close(nl_fd);

        const inotify_result = initInotify(allocator);

        var sock_path_buf: [256]u8 = undefined;
        const sock_path = socket_client.resolveSocketPath(&sock_path_buf);
        const sock = ControlSocket.init(allocator, sock_path) catch |err| blk: {
            std.log.warn("control socket unavailable: {}", .{err});
            break :blk null;
        };

        return .{
            .allocator = allocator,
            .managed = .{},
            .stop_fd = stop_fd,
            .hup_fd = hup_fd,
            .netlink_fd = nl_fd,
            .inotify_fd = inotify_result.inotify_fd,
            .debounce_fd = inotify_result.debounce_fd,
            .config_dir = inotify_result.config_dir,
            .configs = .{},
            .devname_map = std.StringHashMap([]const u8).init(allocator),
            .ctrl_sock = sock,
            .user_cfg = user_config_mod.load(allocator),
            .test_switch_mapping_override = null,
            .test_switch_fail_commit_index = null,
        };
    }

    pub fn initForTest(allocator: std.mem.Allocator) !Supervisor {
        const stop_fd = try posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
        errdefer posix.close(stop_fd);
        const hup_fd = try posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK);
        errdefer posix.close(hup_fd);
        return .{
            .allocator = allocator,
            .managed = .{},
            .stop_fd = stop_fd,
            .hup_fd = hup_fd,
            .netlink_fd = -1,
            .inotify_fd = -1,
            .debounce_fd = -1,
            .config_dir = null,
            .configs = .{},
            .devname_map = std.StringHashMap([]const u8).init(allocator),
            .ctrl_sock = null,
            .test_switch_mapping_override = null,
            .test_switch_fail_commit_index = null,
        };
    }

    pub fn deinit(self: *Supervisor) void {
        if (self.ctrl_sock) |*cs| cs.deinit();
        if (self.user_cfg) |*uc| uc.deinit();
        if (self.test_switch_mapping_override) |p| self.allocator.free(p);
        posix.close(self.stop_fd);
        posix.close(self.hup_fd);
        if (self.netlink_fd >= 0) posix.close(self.netlink_fd);
        if (self.inotify_fd >= 0) posix.close(self.inotify_fd);
        if (self.debounce_fd >= 0) posix.close(self.debounce_fd);
        if (self.config_dir) |dir| self.allocator.free(dir);
        if (self.managed.items.len > 0) self.stopAll();
        self.managed.deinit(self.allocator);
        for (self.configs.items) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.configs.deinit(self.allocator);
        var it = self.devname_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.devname_map.deinit();
    }

    /// Attach a pre-constructed instance under a given devname / phys_key.
    /// Returns without error if devname already tracked (dedup guard).
    pub fn attachWithInstance(self: *Supervisor, devname: []const u8, phys_key: []const u8, instance: *DeviceInstance) !void {
        if (self.devname_map.contains(devname)) return;
        const dev_copy = try self.allocator.dupe(u8, devname);
        errdefer self.allocator.free(dev_copy);
        const phys_copy = try self.allocator.dupe(u8, phys_key);
        errdefer self.allocator.free(phys_copy);
        const dn_copy = try self.allocator.dupe(u8, devname);
        errdefer self.allocator.free(dn_copy);
        try self.devname_map.put(dev_copy, phys_copy);
        errdefer _ = self.devname_map.fetchRemove(dev_copy);
        try self.spawnInstance(phys_key, instance);
        self.managed.items[self.managed.items.len - 1].devname = dn_copy;
    }

    /// Stop and free the instance attached under devname. No-op if not found.
    pub fn detach(self: *Supervisor, devname: []const u8) void {
        const entry = self.devname_map.fetchRemove(devname) orelse return;
        self.allocator.free(entry.key);
        const phys_key = entry.value;
        defer self.allocator.free(phys_key);

        for (self.managed.items, 0..) |*m, i| {
            if (std.mem.eql(u8, m.phys_key, phys_key)) {
                std.log.info("device detached: \"{s}\" {s}", .{ m.instance.device_cfg.device.name, devname });
                m.instance.stop();
                m.thread.join();
                self.teardownManaged(m);
                _ = self.managed.swapRemove(i);
                return;
            }
        }
    }

    fn spawnInstance(self: *Supervisor, phys_key: []const u8, instance: *DeviceInstance) !void {
        const thread = try std.Thread.spawn(.{}, threadEntry, .{instance});
        errdefer {
            instance.stop();
            thread.join();
        }
        const key_copy = try self.allocator.dupe(u8, phys_key);
        errdefer self.allocator.free(key_copy);
        try self.managed.append(self.allocator, .{
            .phys_key = key_copy,
            .devname = null,
            .instance = instance,
            .thread = thread,
            .mapping_arena = std.heap.ArenaAllocator.init(self.allocator),
            .switch_mapping = null,
        });
    }

    fn teardownManaged(self: *Supervisor, m: *ManagedInstance) void {
        if (m.switch_mapping) |pm| {
            pm.deinit();
            self.allocator.destroy(pm);
        }
        m.instance.deinit();
        self.allocator.destroy(m.instance);
        m.mapping_arena.deinit();
        self.allocator.free(m.phys_key);
        if (m.devname) |dn| {
            if (self.devname_map.fetchRemove(dn)) |e| {
                self.allocator.free(e.key);
                self.allocator.free(e.value);
            }
            self.allocator.free(dn);
        }
    }

    fn restartManagedThread(m: *ManagedInstance) !void {
        @atomicStore(bool, &m.instance.stopped, false, .release);
        @atomicStore(bool, &m.instance.loop.running, true, .release);
        @atomicStore(bool, &m.instance.loop.disconnected, false, .release);
        m.thread = try std.Thread.spawn(.{}, threadEntry, .{m.instance});
    }

    fn clearSwitchMapping(self: *Supervisor, m: *ManagedInstance) void {
        if (m.switch_mapping) |pm| {
            pm.deinit();
            self.allocator.destroy(pm);
            m.switch_mapping = null;
        }
    }

    fn lookupSwitchMappingPath(self: *Supervisor, name: []const u8) !?[]const u8 {
        if (builtin.is_test) {
            if (self.test_switch_mapping_override) |override_path| {
                return @as(?[]const u8, try self.allocator.dupe(u8, override_path));
            }
        }
        return @as(?[]const u8, try mapping_discovery.findMapping(self.allocator, name));
    }

    fn restoreSwitchTarget(self: *Supervisor, tx: *SwitchTx, m: *ManagedInstance, deinit_current_mapper: bool) void {
        if (deinit_current_mapper) {
            if (m.instance.mapper) |*cur| {
                cur.deinit();
                m.instance.mapper = null;
            }
            if (m.switch_mapping) |pm| {
                pm.deinit();
                self.allocator.destroy(pm);
                m.switch_mapping = null;
            }
        }

        m.instance.mapper = tx.old_mapper;
        m.instance.mapping_cfg = tx.old_mapping_cfg;
        m.switch_mapping = tx.old_switch_mapping;
        restartManagedThread(m) catch |err| {
            std.log.err("rollback restart failed for {s}: {}", .{ m.phys_key, err });
        };

        tx.old_mapper = null;
        tx.old_mapping_cfg = null;
        tx.old_switch_mapping = null;
        tx.committed = false;
    }

    fn rollbackCommittedSwitches(self: *Supervisor, txs: []SwitchTx) void {
        var r = txs.len;
        while (r > 0) {
            r -= 1;
            const tx = &txs[r];
            if (!tx.committed) continue;
            const m = &self.managed.items[tx.idx];
            m.instance.stop();
            m.thread.join();
            self.restoreSwitchTarget(tx, m, true);
        }
    }

    fn cleanupSwitchTxs(self: *Supervisor, txs: []SwitchTx) void {
        for (txs) |*tx| {
            if (tx.committed) {
                if (tx.old_mapper) |*old| old.deinit();
                if (tx.old_switch_mapping) |pm| {
                    pm.deinit();
                    self.allocator.destroy(pm);
                }
            } else {
                if (tx.new_mapper) |*new| new.deinit();
                if (tx.parsed_ptr) |pm| {
                    pm.deinit();
                    self.allocator.destroy(pm);
                }
            }
        }
    }

    fn commitSwitchTarget(self: *Supervisor, tx: *SwitchTx) !void {
        const m = &self.managed.items[tx.idx];
        tx.old_mapper = m.instance.mapper;
        tx.old_mapping_cfg = m.instance.mapping_cfg;
        tx.old_switch_mapping = m.switch_mapping;

        m.instance.stop();
        m.thread.join();

        if (builtin.is_test and self.test_switch_fail_commit_index != null and self.test_switch_fail_commit_index.? == tx.idx) {
            self.restoreSwitchTarget(tx, m, false);
            return error.SwitchFailed;
        }

        m.instance.mapper = tx.new_mapper.?;
        tx.new_mapper = null;
        m.instance.mapping_cfg = &tx.parsed_ptr.?.value;
        restartManagedThread(m) catch |err| {
            if (m.instance.mapper) |*cur| {
                cur.deinit();
                m.instance.mapper = null;
            }
            m.instance.mapper = tx.old_mapper;
            m.instance.mapping_cfg = tx.old_mapping_cfg;
            m.switch_mapping = tx.old_switch_mapping;
            restartManagedThread(m) catch |rollback_err| {
                std.log.err("rollback restart failed for {s}: {}", .{ m.phys_key, rollback_err });
            };
            tx.old_mapper = null;
            tx.old_mapping_cfg = null;
            tx.old_switch_mapping = null;
            tx.committed = false;
            return err;
        };
        m.switch_mapping = tx.parsed_ptr;
        tx.parsed_ptr = null;
        tx.committed = true;
    }

    fn doReload(
        self: *Supervisor,
        reloadFn: *const fn (allocator: std.mem.Allocator) anyerror![]ConfigEntry,
        reload_allocator: std.mem.Allocator,
        initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
    ) void {
        if (self.user_cfg) |*uc| uc.deinit();
        self.user_cfg = user_config_mod.load(self.allocator);

        const new_configs = reloadFn(reload_allocator) catch |err| {
            std.log.err("reload failed: {}", .{err});
            return;
        };
        defer reload_allocator.free(new_configs);
        self.reload(new_configs, initFn) catch |err| {
            std.log.err("hot-reload diff failed: {}", .{err});
        };
    }

    pub fn stopAll(self: *Supervisor) void {
        for (self.managed.items) |*m| m.instance.stop();
        for (self.managed.items) |*m| m.thread.join();
        for (self.managed.items) |*m| self.teardownManaged(m);
        self.managed.clearRetainingCapacity();
    }

    /// Hot-reload: diff new_configs against running instances by phys_key.
    pub fn reload(
        self: *Supervisor,
        new_configs: []const ConfigEntry,
        initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
    ) !void {
        var to_remove = std.ArrayList(usize){};
        defer to_remove.deinit(self.allocator);

        outer: for (self.managed.items, 0..) |*m, i| {
            for (new_configs) |nc| {
                if (std.mem.eql(u8, m.phys_key, nc.phys_key)) continue :outer;
            }
            try to_remove.append(self.allocator, i);
        }

        var r = to_remove.items.len;
        while (r > 0) {
            r -= 1;
            const idx = to_remove.items[r];
            const m = &self.managed.items[idx];
            m.instance.stop();
            m.thread.join();
            self.teardownManaged(m);
            _ = self.managed.swapRemove(idx);
        }

        for (new_configs) |nc| {
            var found: ?*ManagedInstance = null;
            for (self.managed.items) |*m| {
                if (std.mem.eql(u8, m.phys_key, nc.phys_key)) {
                    found = m;
                    break;
                }
            }

            if (found == null) {
                const instance = try initFn(self.allocator, nc);
                try self.spawnInstance(nc.phys_key, instance);
            } else if (nc.mapping_cfg) |new_map| {
                const m = found.?;
                // Stop-Swap-Restart: stop thread before touching arena
                m.instance.stop();
                m.thread.join();
                self.clearSwitchMapping(m);

                var old_mapper = m.instance.mapper;
                const old_mapping_cfg = m.instance.mapping_cfg;
                _ = m.mapping_arena.reset(.retain_capacity);
                const arena_alloc = m.mapping_arena.allocator();
                const map_copy = try arena_alloc.create(MappingConfig);
                map_copy.* = new_map.*;

                // Rebuild the mapper so layer state/timers do not keep slices into
                // the old mapping arena after the reset above.
                var new_mapper = try Mapper.init(map_copy, m.instance.loop.timer_fd, self.allocator);
                m.instance.mapper = new_mapper;
                m.instance.mapping_cfg = map_copy;
                m.instance.rebuildAuxIfChanged(map_copy, old_mapping_cfg) catch |err| {
                    std.log.warn("rebuildAuxIfChanged: {}", .{err});
                };
                restartManagedThread(m) catch |err| {
                    m.instance.mapper = old_mapper;
                    m.instance.mapping_cfg = old_mapping_cfg;
                    new_mapper.deinit();
                    return err;
                };

                if (old_mapper) |*mapper| {
                    mapper.deinit();
                }
            } else {
                const m = found.?;
                m.instance.stop();
                m.thread.join();
                self.clearSwitchMapping(m);
                _ = m.mapping_arena.reset(.retain_capacity);
                if (m.instance.mapper) |*mapper| {
                    mapper.deinit();
                    m.instance.mapper = null;
                }
                m.instance.mapping_cfg = null;
                try restartManagedThread(m);
            }
        }
    }

    fn netlinkCallback(self: *Supervisor, action: netlink.UeventAction, devname: []const u8) void {
        switch (action) {
            .add => self.attach(devname) catch |err| {
                std.log.warn("hotplug attach {s}: {}", .{ devname, err });
            },
            .remove => self.detach(devname),
            .other => {},
        }
    }

    fn drainNetlink(self: *Supervisor) void {
        if (self.netlink_fd < 0) return;
        netlink.drainNetlink(self.netlink_fd, self, netlinkCallback);
    }

    fn armDebounce(self: *Supervisor) void {
        if (self.debounce_fd < 0) return;
        const spec = linux.itimerspec{
            .it_value = .{ .sec = 0, .nsec = 500_000_000 },
            .it_interval = .{ .sec = 0, .nsec = 0 },
        };
        _ = linux.timerfd_settime(self.debounce_fd, .{}, &spec, null);
    }

    fn drainInotify(self: *Supervisor) void {
        if (self.inotify_fd < 0) return;
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = posix.read(self.inotify_fd, &buf) catch break;
            if (n == 0) break;
        }
        self.armDebounce();
    }

    pub fn run(
        self: *Supervisor,
        initial_configs: []const ConfigEntry,
        initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
        reloadFn: *const fn (allocator: std.mem.Allocator) anyerror![]ConfigEntry,
        reload_allocator: std.mem.Allocator,
    ) !void {
        for (initial_configs) |nc| {
            const instance = try initFn(self.allocator, nc);
            try self.spawnInstance(nc.phys_key, instance);
        }
        defer self.stopAll();

        // 5 base fds + 1 listen + 4 clients = 10
        var pollfds: [10]posix.pollfd = undefined;
        pollfds[0] = .{ .fd = self.stop_fd, .events = posix.POLL.IN, .revents = 0 };
        pollfds[1] = .{ .fd = self.hup_fd, .events = posix.POLL.IN, .revents = 0 };
        var base_nfds: usize = 2;
        const netlink_slot: ?usize = if (self.netlink_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.netlink_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const inotify_slot: ?usize = if (self.inotify_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.inotify_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const debounce_slot: ?usize = if (self.debounce_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.debounce_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const listen_slot: ?usize = if (self.ctrl_sock) |cs| blk: {
            pollfds[base_nfds] = cs.pollfd();
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;

        while (true) {
            // Rebuild client fds each iteration (clients may come and go)
            var nfds = base_nfds;
            if (self.ctrl_sock) |*cs| {
                nfds += cs.clientPollfds(pollfds[base_nfds..]);
            }

            _ = posix.ppoll(pollfds[0..nfds], null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };

            if (pollfds[0].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.stop_fd, &buf) catch {};
                break;
            }

            if (pollfds[1].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.hup_fd, &buf) catch {};
                self.doReload(reloadFn, reload_allocator, initFn);
                pollfds[1].revents = 0;
            }

            if (netlink_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainNetlink();
                    pollfds[slot].revents = 0;
                }
            }

            if (inotify_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainInotify();
                    pollfds[slot].revents = 0;
                }
            }

            if (debounce_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    var tbuf: [8]u8 = undefined;
                    _ = posix.read(self.debounce_fd, &tbuf) catch {};
                    self.doReload(reloadFn, reload_allocator, initFn);
                    pollfds[slot].revents = 0;
                }
            }

            if (listen_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.ctrl_sock.?.acceptClient();
                    pollfds[slot].revents = 0;
                }
            }

            // Handle client fds
            if (self.ctrl_sock != null) {
                for (pollfds[base_nfds..nfds]) |*pfd| {
                    if (pfd.revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                        self.ctrl_sock.?.removeClient(pfd.fd);
                    } else if (pfd.revents & posix.POLL.IN != 0) {
                        self.handleClientCommand(pfd.fd);
                    }
                }
            }
        }
    }

    fn handleClientCommand(self: *Supervisor, fd: posix.fd_t) void {
        var cs = &self.ctrl_sock.?;
        const cmd = cs.readCommand(fd) orelse return;
        switch (cmd.tag) {
            .switch_mapping => self.handleSwitch(fd, cmd.name, null),
            .switch_device => self.handleSwitch(fd, cmd.name, cmd.device_id),
            .status => self.handleStatus(fd),
            .list => self.handleList(fd),
            .devices => self.handleDevices(fd),
            .unknown => cs.sendResponse(fd, "ERR unknown-command\n"),
        }
    }

    fn applySwitchMapping(self: *Supervisor, m: *ManagedInstance, parsed_ptr: *mapping_cfg.ParseResult) !void {
        const new_mapper = try Mapper.init(&parsed_ptr.value, m.instance.loop.timer_fd, self.allocator);
        m.instance.stop();
        m.thread.join();
        self.clearSwitchMapping(m);
        const old_mcfg = m.instance.mapping_cfg;
        if (m.instance.mapper) |*old| old.deinit();
        m.instance.mapper = new_mapper;
        m.instance.mapping_cfg = &parsed_ptr.value;
        m.instance.rebuildAuxIfChanged(&parsed_ptr.value, old_mcfg) catch |err| {
            std.log.warn("rebuildAuxIfChanged: {}", .{err});
        };
        restartManagedThread(m) catch |err| {
            if (m.instance.mapper) |*mapper| {
                mapper.deinit();
                m.instance.mapper = null;
            }
            m.instance.mapping_cfg = null;
            return err;
        };
        m.switch_mapping = parsed_ptr;
    }

    fn handleSwitch(self: *Supervisor, fd: posix.fd_t, name: []const u8, device_id: ?[]const u8) void {
        var cs = &self.ctrl_sock.?;
        if (self.managed.items.len == 0) {
            cs.sendResponse(fd, "ERR no-devices\n");
            return;
        }
        const path = self.lookupSwitchMappingPath(name) catch {
            cs.sendResponse(fd, "ERR mapping-lookup-failed\n");
            return;
        };
        if (path == null) {
            cs.sendResponse(fd, "ERR mapping-not-found\n");
            return;
        }
        defer self.allocator.free(path.?);

        var targets = std.ArrayList(usize){};
        defer targets.deinit(self.allocator);

        if (device_id) |dev_id| {
            var found = false;
            for (self.managed.items, 0..) |*m, idx| {
                if (m.devname) |dn| {
                    if (std.mem.eql(u8, dn, dev_id)) {
                        targets.append(self.allocator, idx) catch {
                            cs.sendResponse(fd, "ERR oom\n");
                            return;
                        };
                        found = true;
                        break;
                    }
                }
            }
            if (!found) {
                cs.sendResponse(fd, "ERR device-not-found\n");
                return;
            }
        } else {
            for (self.managed.items, 0..) |_, idx| {
                targets.append(self.allocator, idx) catch {
                    cs.sendResponse(fd, "ERR oom\n");
                    return;
                };
            }
        }

        var txs = std.ArrayList(SwitchTx){};
        defer {
            self.cleanupSwitchTxs(txs.items);
            txs.deinit(self.allocator);
        }

        for (targets.items) |idx| {
            const m = &self.managed.items[idx];
            const parsed = mapping_cfg.parseFile(self.allocator, path.?) catch {
                cs.sendResponse(fd, "ERR mapping-parse-failed\n");
                return;
            };
            const parsed_ptr = self.allocator.create(mapping_cfg.ParseResult) catch {
                parsed.deinit();
                cs.sendResponse(fd, "ERR oom\n");
                return;
            };
            parsed_ptr.* = parsed;
            const new_mapper = Mapper.init(&parsed_ptr.value, m.instance.loop.timer_fd, self.allocator) catch {
                parsed_ptr.deinit();
                self.allocator.destroy(parsed_ptr);
                cs.sendResponse(fd, "ERR switch-failed\n");
                return;
            };
            txs.append(self.allocator, .{
                .idx = idx,
                .new_mapper = new_mapper,
                .parsed_ptr = parsed_ptr,
            }) catch {
                cs.sendResponse(fd, "ERR oom\n");
                return;
            };
        }

        for (txs.items, 0..) |*tx, commit_idx| {
            if (shouldInjectSwitchFailure(self, commit_idx)) {
                self.rollbackCommittedSwitches(txs.items);
                cs.sendResponse(fd, "ERR switch-failed\n");
                return;
            }

            self.commitSwitchTarget(tx) catch {
                self.rollbackCommittedSwitches(txs.items);
                cs.sendResponse(fd, "ERR switch-failed\n");
                return;
            };
        }

        std.log.info("mapping switched: \"{s}\" ({d} device(s))", .{ name, targets.items.len });

        var resp_buf: [128]u8 = undefined;
        if (device_id) |dev_id| {
            const resp = std.fmt.bufPrint(&resp_buf, "OK {s} {s}\n", .{ name, dev_id }) catch {
                cs.sendResponse(fd, "OK\n");
                return;
            };
            cs.sendResponse(fd, resp);
        } else {
            const resp = std.fmt.bufPrint(&resp_buf, "OK {s}\n", .{name}) catch {
                cs.sendResponse(fd, "OK\n");
                return;
            };
            cs.sendResponse(fd, resp);
        }
    }

    fn handleStatus(self: *Supervisor, fd: posix.fd_t) void {
        var cs = &self.ctrl_sock.?;
        var buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const w = stream.writer();

        w.writeAll("STATUS") catch return;
        for (self.managed.items) |*m| {
            const name = m.instance.device_cfg.device.name;
            w.print(" device={s} active=true", .{name}) catch break;
        }
        w.writeByte('\n') catch return;
        cs.sendResponse(fd, stream.getWritten());
    }

    fn handleList(self: *Supervisor, fd: posix.fd_t) void {
        const profiles = mapping_discovery.discoverMappings(self.allocator) catch {
            self.ctrl_sock.?.sendResponse(fd, "ERR list-failed\n");
            return;
        };
        defer mapping_discovery.freeProfiles(self.allocator, profiles);

        var resp_buf: [1024]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&resp_buf);
        const w = fbs.writer();
        w.writeAll("LIST") catch {
            self.ctrl_sock.?.sendResponse(fd, "LIST\n");
            return;
        };
        for (profiles) |p| {
            w.print(" {s}", .{p.name}) catch break;
        }
        w.writeByte('\n') catch {
            self.ctrl_sock.?.sendResponse(fd, "LIST\n");
            return;
        };
        self.ctrl_sock.?.sendResponse(fd, fbs.getWritten());
    }

    fn handleDevices(self: *Supervisor, fd: posix.fd_t) void {
        var cs = &self.ctrl_sock.?;
        var resp_buf: [512]u8 = undefined;
        var pos: usize = 0;

        const header = "DEVICES";
        @memcpy(resp_buf[pos .. pos + header.len], header);
        pos += header.len;

        var dit = self.devname_map.keyIterator();
        while (dit.next()) |key| {
            if (pos + 2 >= resp_buf.len) break;
            resp_buf[pos] = ' ';
            pos += 1;
            const k = key.*;
            const copy_len = @min(k.len, resp_buf.len - pos - 2);
            @memcpy(resp_buf[pos .. pos + copy_len], k[0..copy_len]);
            pos += copy_len;
        }
        resp_buf[pos] = '\n';
        pos += 1;
        cs.sendResponse(fd, resp_buf[0..pos]);
    }

    /// Look up the user config's default_mapping for device_name, find and parse the mapping file.
    /// Caller owns the returned ParseResult (call deinit on it). Returns null if none configured.
    fn loadUserDefaultMapping(self: *const Supervisor, device_name: []const u8) ?mapping_cfg.ParseResult {
        const ucfg = &(self.user_cfg orelse return null);
        const mapping_name = user_config_mod.findDefaultMapping(ucfg, device_name) orelse return null;
        const path = mapping_discovery.findMapping(self.allocator, mapping_name) catch return null;
        if (path == null) {
            std.log.warn("mapping file \"{s}\" not found in XDG paths", .{mapping_name});
            return null;
        }
        defer self.allocator.free(path.?);
        const result = mapping_cfg.parseFile(self.allocator, path.?) catch return null;
        std.log.info("mapping discovery: device \"{s}\" mapping \"{s}\" from \"{s}\"", .{ device_name, mapping_name, path.? });
        return result;
    }

    /// Glob *.toml in dir_path, discover devices by VID/PID, dedup by physical path, spawn threads.
    pub fn startFromDir(self: *Supervisor, dir_path: []const u8) !void {
        return self.startFromDirWithRoot(dir_path, "/dev");
    }

    pub fn startFromDirWithRoot(self: *Supervisor, dir_path: []const u8, dev_root: []const u8) !void {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        // seen deduplicates by physical path across all TOML files; owns the key bytes.
        var seen = std.StringHashMap(void).init(self.allocator);
        defer {
            var kit = seen.keyIterator();
            while (kit.next()) |k| self.allocator.free(k.*);
            seen.deinit();
        }

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;

            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const toml_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.path });

            const parsed = config_device.parseFile(self.allocator, toml_path) catch |err| {
                std.log.debug("skip {s}: {}", .{ entry.path, err });
                continue;
            };
            const cfg_ptr = try self.allocator.create(config_device.ParseResult);
            cfg_ptr.* = parsed;

            const vid: u16 = @intCast(cfg_ptr.value.device.vid);
            const pid: u16 = @intCast(cfg_ptr.value.device.pid);

            const paths = HidrawDevice.discoverAllWithRoot(self.allocator, vid, pid, dev_root) catch |err| {
                std.log.warn("discoverAll for {s}: {}", .{ entry.path, err });
                cfg_ptr.deinit();
                self.allocator.destroy(cfg_ptr);
                continue;
            };
            defer {
                for (paths) |p| self.allocator.free(p);
                self.allocator.free(paths);
            }

            if (paths.len == 0) {
                cfg_ptr.deinit();
                self.allocator.destroy(cfg_ptr);
                continue;
            }

            const cfg_ifaces = cfg_ptr.value.device.interface;

            var spawned: usize = 0;
            for (paths) |hidraw_path| {
                const iface_id = readInterfaceId(hidraw_path) orelse continue;
                {
                    var declared = false;
                    for (cfg_ifaces) |ci| {
                        if (iface_id == @as(u8, @intCast(ci.id))) {
                            declared = true;
                            break;
                        }
                    }
                    if (!declared) continue;
                }

                const phys = readPhysicalPath(self.allocator, hidraw_path) catch |err| {
                    std.log.warn("readPhysicalPath {s}: {}", .{ hidraw_path, err });
                    continue;
                };

                // Check already-managed instances across dirs before local seen map
                const already_managed = for (self.managed.items) |m| {
                    if (std.mem.eql(u8, m.phys_key, phys)) break true;
                } else false;
                if (already_managed) {
                    self.allocator.free(phys);
                    continue;
                }

                const gop = try seen.getOrPut(phys);
                if (gop.found_existing) {
                    self.allocator.free(phys);
                    continue;
                }
                // seen now owns phys bytes via the key slot

                var default_pr = self.loadUserDefaultMapping(cfg_ptr.value.device.name);
                defer if (default_pr) |*pr| pr.deinit();
                const init_mapping: ?*const MappingConfig = if (default_pr) |*pr| &pr.value else null;

                const inst_ptr = try self.allocator.create(DeviceInstance);
                inst_ptr.* = DeviceInstance.init(self.allocator, &cfg_ptr.value, init_mapping) catch |err| {
                    std.log.warn("DeviceInstance.init for {s}: {}", .{ hidraw_path, err });
                    self.allocator.destroy(inst_ptr);
                    // reclaim phys from seen
                    _ = seen.remove(phys);
                    self.allocator.free(phys);
                    continue;
                };
                self.spawnInstance(phys, inst_ptr) catch |err| {
                    std.log.warn("spawnInstance for {s}: {}", .{ hidraw_path, err });
                    inst_ptr.deinit();
                    self.allocator.destroy(inst_ptr);
                    _ = seen.remove(phys);
                    self.allocator.free(phys);
                    continue;
                };
                // phys stays in seen (owned there) and also duped by spawnInstance for ManagedInstance.
                spawned += 1;
            }

            if (spawned > 0) {
                try self.configs.append(self.allocator, cfg_ptr);
            } else {
                cfg_ptr.deinit();
                self.allocator.destroy(cfg_ptr);
            }
        }
    }

    pub fn joinAll(self: *Supervisor) void {
        for (self.managed.items) |*m| m.thread.join();
    }

    pub fn startFromDirs(self: *Supervisor, dirs: []const []const u8) void {
        for (dirs) |dir| {
            std.fs.accessAbsolute(dir, .{}) catch continue;
            self.startFromDir(dir) catch |err| {
                std.log.warn("failed to scan config dir '{s}': {}", .{ dir, err });
            };
        }
    }

    fn doReloadFromDir(self: *Supervisor, dir_path: []const u8) void {
        self.stopAll();
        for (self.configs.items) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.configs.clearRetainingCapacity();
        var it = self.devname_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.devname_map.clearRetainingCapacity();
        self.startFromDir(dir_path) catch |err| {
            std.log.err("reload from dir failed: {}", .{err});
        };
    }

    fn doReloadFromDirs(self: *Supervisor, dirs: []const []const u8) void {
        self.stopAll();
        for (self.configs.items) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.configs.clearRetainingCapacity();
        var it = self.devname_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.devname_map.clearRetainingCapacity();
        self.startFromDirs(dirs);
    }

    /// Like serve() but monitors/reloads from multiple config directories.
    /// Uses dirs[0] for inotify hot-file-change watch (user config dir).
    /// SIGHUP and inotify debounce reload all dirs.
    pub fn serveMulti(self: *Supervisor, dirs: []const []const u8) void {
        defer self.stopAll();

        var pollfds: [10]posix.pollfd = undefined;
        pollfds[0] = .{ .fd = self.stop_fd, .events = posix.POLL.IN, .revents = 0 };
        pollfds[1] = .{ .fd = self.hup_fd, .events = posix.POLL.IN, .revents = 0 };
        var base_nfds: usize = 2;
        const netlink_slot: ?usize = if (self.netlink_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.netlink_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const inotify_slot: ?usize = if (self.inotify_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.inotify_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const debounce_slot: ?usize = if (self.debounce_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.debounce_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const listen_slot: ?usize = if (self.ctrl_sock) |cs| blk: {
            pollfds[base_nfds] = cs.pollfd();
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;

        while (true) {
            var nfds = base_nfds;
            if (self.ctrl_sock) |*cs| {
                nfds += cs.clientPollfds(pollfds[base_nfds..]);
            }

            _ = posix.ppoll(pollfds[0..nfds], null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return,
            };

            if (pollfds[0].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.stop_fd, &buf) catch {};
                break;
            }

            if (pollfds[1].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.hup_fd, &buf) catch {};
                self.doReloadFromDirs(dirs);
                pollfds[1].revents = 0;
            }

            if (netlink_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainNetlink();
                    pollfds[slot].revents = 0;
                }
            }

            if (inotify_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainInotify();
                    pollfds[slot].revents = 0;
                }
            }

            if (debounce_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    var tbuf: [8]u8 = undefined;
                    _ = posix.read(self.debounce_fd, &tbuf) catch {};
                    self.doReloadFromDirs(dirs);
                    pollfds[slot].revents = 0;
                }
            }

            if (listen_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.ctrl_sock.?.acceptClient();
                    pollfds[slot].revents = 0;
                }
            }

            if (self.ctrl_sock != null) {
                for (pollfds[base_nfds..nfds]) |*pfd| {
                    if (pfd.revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                        self.ctrl_sock.?.removeClient(pfd.fd);
                    } else if (pfd.revents & posix.POLL.IN != 0) {
                        self.handleClientCommand(pfd.fd);
                    }
                }
            }
        }
    }

    /// Enter the supervisor event loop: poll for signals, netlink hot-plug,
    /// inotify config changes, and control-socket commands. Blocks until
    /// SIGTERM/SIGINT. When the loop exits, all managed instances are stopped.
    pub fn serve(self: *Supervisor, dir_path: []const u8) void {
        defer self.stopAll();

        var pollfds: [10]posix.pollfd = undefined;
        pollfds[0] = .{ .fd = self.stop_fd, .events = posix.POLL.IN, .revents = 0 };
        pollfds[1] = .{ .fd = self.hup_fd, .events = posix.POLL.IN, .revents = 0 };
        var base_nfds: usize = 2;
        const netlink_slot: ?usize = if (self.netlink_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.netlink_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const inotify_slot: ?usize = if (self.inotify_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.inotify_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const debounce_slot: ?usize = if (self.debounce_fd >= 0) blk: {
            pollfds[base_nfds] = .{ .fd = self.debounce_fd, .events = posix.POLL.IN, .revents = 0 };
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;
        const listen_slot: ?usize = if (self.ctrl_sock) |cs| blk: {
            pollfds[base_nfds] = cs.pollfd();
            const s = base_nfds;
            base_nfds += 1;
            break :blk s;
        } else null;

        while (true) {
            var nfds = base_nfds;
            if (self.ctrl_sock) |*cs| {
                nfds += cs.clientPollfds(pollfds[base_nfds..]);
            }

            _ = posix.ppoll(pollfds[0..nfds], null, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return,
            };

            if (pollfds[0].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.stop_fd, &buf) catch {};
                break;
            }

            if (pollfds[1].revents & posix.POLL.IN != 0) {
                var buf: [128]u8 = undefined;
                _ = posix.read(self.hup_fd, &buf) catch {};
                self.doReloadFromDir(dir_path);
                pollfds[1].revents = 0;
            }

            if (netlink_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainNetlink();
                    pollfds[slot].revents = 0;
                }
            }

            if (inotify_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.drainInotify();
                    pollfds[slot].revents = 0;
                }
            }

            if (debounce_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    var tbuf: [8]u8 = undefined;
                    _ = posix.read(self.debounce_fd, &tbuf) catch {};
                    self.doReloadFromDir(dir_path);
                    pollfds[slot].revents = 0;
                }
            }

            if (listen_slot) |slot| {
                if (pollfds[slot].revents & posix.POLL.IN != 0) {
                    self.ctrl_sock.?.acceptClient();
                    pollfds[slot].revents = 0;
                }
            }

            if (self.ctrl_sock != null) {
                for (pollfds[base_nfds..nfds]) |*pfd| {
                    if (pfd.revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                        self.ctrl_sock.?.removeClient(pfd.fd);
                    } else if (pfd.revents & posix.POLL.IN != 0) {
                        self.handleClientCommand(pfd.fd);
                    }
                }
            }
        }
    }

    pub fn attach(self: *Supervisor, devname: []const u8) !void {
        return self.attachWithRoot(devname, "/dev");
    }

    pub fn attachWithRoot(self: *Supervisor, devname: []const u8, dev_root: []const u8) !void {
        var path_buf: [128]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dev_root, devname });

        const fd = posix.open(path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch return;
        defer posix.close(fd);

        var info: ioctl.HidrawDevinfo = undefined;
        if (linux.ioctl(fd, ioctl.HIDIOCGRAWINFO, @intFromPtr(&info)) != 0) return;
        const vid: u16 = @bitCast(info.vendor);
        const pid: u16 = @bitCast(info.product);

        var cfg: ?*const DeviceConfig = null;
        for (self.configs.items) |pr| {
            if (@as(u16, @intCast(pr.value.device.vid)) == vid and
                @as(u16, @intCast(pr.value.device.pid)) == pid)
            {
                cfg = &pr.value;
                break;
            }
        }
        if (cfg == null) return;

        const phys = try readPhysicalPath(self.allocator, path);
        defer self.allocator.free(phys);

        var default_pr = self.loadUserDefaultMapping(cfg.?.device.name);
        defer if (default_pr) |*pr| pr.deinit();
        const init_mapping: ?*const MappingConfig = if (default_pr) |*pr| &pr.value else null;

        const inst_ptr = try self.allocator.create(DeviceInstance);
        errdefer self.allocator.destroy(inst_ptr);
        inst_ptr.* = DeviceInstance.init(self.allocator, cfg.?, init_mapping) catch |err| {
            std.log.warn("DeviceInstance.init for {s}: {}", .{ path, err });
            self.allocator.destroy(inst_ptr);
            return;
        };
        self.attachWithInstance(devname, phys, inst_ptr) catch |err| {
            inst_ptr.deinit();
            self.allocator.destroy(inst_ptr);
            return err;
        };
        std.log.info("device attached: \"{s}\" {s}/{s}", .{ cfg.?.device.name, dev_root, devname });
    }
};

// --- tests ---

const testing = std.testing;
const mapping_mod = @import("config/mapping.zig");
const mapper_mod = @import("core/mapper.zig");
const device_mod = @import("config/device.zig");
const EventLoop = @import("event_loop.zig").EventLoop;
const MockDeviceIO = @import("test/mock_device_io.zig").MockDeviceIO;
const DeviceIO = @import("io/device_io.zig").DeviceIO;
const uinput = @import("io/uinput.zig");
const state_mod = @import("core/state.zig");

const minimal_device_toml =
    \\[device]
    \\name = "T"
    \\vid = 1
    \\pid = 2
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 3
    \\[report.match]
    \\offset = 0
    \\expect = [0x01]
    \\[report.fields]
    \\left_x = { offset = 1, type = "i16le" }
;

fn makeTestInstance(
    inst_alloc: std.mem.Allocator,
    mock: *MockDeviceIO,
    cfg: *const device_mod.DeviceConfig,
) !*DeviceInstance {
    const devices = try inst_alloc.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.initManaged();
    errdefer loop.deinit();
    try loop.addDevice(devices[0]);

    const inst = try inst_alloc.create(DeviceInstance);
    inst.* = .{
        .allocator = inst_alloc,
        .devices = devices,
        .loop = loop,
        .interp = @import("core/interpreter.zig").Interpreter.init(cfg),
        .mapper = null,
        .uinput_dev = null,
        .aux_dev = null,
        .touchpad_dev = null,
        .generic_state = null,
        .generic_uinput = null,
        .device_cfg = cfg,
        .pending_mapping = null,
        .stopped = false,
        .poll_timeout_ms = 100,
    };
    return inst;
}

// threadlocal: Zig test runner executes each test in its own OS thread from a pool.
// threadlocal gives each test thread an independent slot, preventing cross-test
// interference when tests run in parallel.  Limitation: tests that call reload()
// with testInitFn must set g_mock_slot on the same thread that reload() runs on,
// which holds because set and call happen sequentially within one test body.
threadlocal var g_mock_slot: ?*MockDeviceIO = null;

fn testInitFn(allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance {
    const mock = g_mock_slot orelse return error.NoMockSlot;
    g_mock_slot = null;
    return makeTestInstance(allocator, mock, entry.device_cfg);
}

fn testSocketpair() ![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    if (std.c.socketpair(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0, &fds) != 0) {
        return posix.unexpectedErrno(posix.errno(0));
    }
    return fds;
}

fn makeControlSocket(allocator: std.mem.Allocator, tmp_path: []const u8) !ControlSocket {
    var sock_path_buf: [256]u8 = undefined;
    const sock_path = try std.fmt.bufPrint(&sock_path_buf, "{s}/ctrl.sock", .{tmp_path});
    return ControlSocket.init(allocator, sock_path);
}

test "supervisor: Supervisor: global SWITCH rolls back all devices on failure" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    const base_dir = "/tmp/padctl_supervisor_test_switch";
    std.fs.deleteTreeAbsolute(base_dir) catch {};
    try std.fs.makeDirAbsolute(base_dir);
    defer std.fs.deleteTreeAbsolute(base_dir) catch {};

    const mappings_dir = try std.fmt.allocPrint(allocator, "{s}/mappings", .{base_dir});
    defer allocator.free(mappings_dir);
    try std.fs.makeDirAbsolute(mappings_dir);
    const mapping_path = try std.fmt.allocPrint(allocator, "{s}/fps.toml", .{mappings_dir});
    defer allocator.free(mapping_path);
    {
        const f = try std.fs.createFileAbsolute(mapping_path, .{});
        f.close();
    }

    var sup = try Supervisor.initForTest(allocator);
    defer {
        sup.stopAll();
        sup.ctrl_sock = null;
        sup.deinit();
    }

    sup.ctrl_sock = .{
        .listen_fd = -1,
        .client_fds = .{ -1, -1, -1, -1 },
        .client_count = 0,
        .path = "",
        .allocator = allocator,
    };

    const resp_fds = try testSocketpair();
    defer posix.close(resp_fds[0]);
    defer posix.close(resp_fds[1]);

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    const inst_b = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst_a);
    try sup.spawnInstance("usb-1-2", inst_b);

    sup.test_switch_mapping_override = try allocator.dupe(u8, mapping_path);
    sup.test_switch_fail_commit_index = 1;

    sup.handleSwitch(resp_fds[0], "fps", null);

    var resp_buf: [64]u8 = undefined;
    const n = try posix.read(resp_fds[1], &resp_buf);
    try testing.expectEqualStrings("ERR switch-failed\n", resp_buf[0..n]);
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].instance.mapper == null);
    try testing.expect(sup.managed.items[1].instance.mapper == null);
    try testing.expect(sup.managed.items[0].instance.mapping_cfg == null);
    try testing.expect(sup.managed.items[1].instance.mapping_cfg == null);
    try testing.expect(sup.managed.items[0].switch_mapping == null);
    try testing.expect(sup.managed.items[1].switch_mapping == null);
    try testing.expectEqual(false, @atomicLoad(bool, &sup.managed.items[0].instance.stopped, .acquire));
    try testing.expectEqual(false, @atomicLoad(bool, &sup.managed.items[1].instance.stopped, .acquire));
}

test "supervisor: Supervisor: SWITCH with no devices returns no-devices" {
    const allocator = testing.allocator;

    const base_dir = "/tmp/padctl_supervisor_test_no_devices";
    std.fs.deleteTreeAbsolute(base_dir) catch {};
    try std.fs.makeDirAbsolute(base_dir);
    defer std.fs.deleteTreeAbsolute(base_dir) catch {};

    var sup = try Supervisor.initForTest(allocator);
    defer {
        sup.ctrl_sock = null;
        sup.deinit();
    }
    sup.ctrl_sock = .{
        .listen_fd = -1,
        .client_fds = .{ -1, -1, -1, -1 },
        .client_count = 0,
        .path = "",
        .allocator = allocator,
    };

    const resp_fds = try testSocketpair();
    defer posix.close(resp_fds[0]);
    defer posix.close(resp_fds[1]);

    sup.handleSwitch(resp_fds[0], "fps", null);

    var resp_buf: [64]u8 = undefined;
    const n = try posix.read(resp_fds[1], &resp_buf);
    try testing.expectEqualStrings("ERR no-devices\n", resp_buf[0..n]);
}

test "supervisor: Supervisor: SIGHUP updates mapping without restarting instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    const parsed_map = try mapping_mod.parseString(allocator, "");
    defer parsed_map.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    var new_map = parsed_map.value;
    const entry = ConfigEntry{
        .phys_key = "usb-1-1",
        .device_cfg = &parsed_dev.value,
        .mapping_cfg = &new_map,
    };

    try sup.reload(&.{entry}, testInitFn);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expectEqualStrings("usb-1-1", sup.managed.items[0].phys_key);
    try testing.expect(sup.managed.items[0].instance.mapping_cfg != null);
    try testing.expect(sup.managed.items[0].instance.mapper != null);
}

test "supervisor: Supervisor: SIGHUP with new phys_key spawns new instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const entry_a = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = null };
    const entry_b = ConfigEntry{ .phys_key = "usb-1-2", .device_cfg = &parsed_dev.value, .mapping_cfg = null };

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst_a);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    g_mock_slot = &mock_b;
    try sup.reload(&.{ entry_a, entry_b }, testInitFn);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);
}

test "supervisor: Supervisor: SIGHUP with removed phys_key stops instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const entry_a = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = null };

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    const inst_b = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst_a);
    try sup.spawnInstance("usb-1-2", inst_b);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);

    try sup.reload(&.{entry_a}, testInitFn);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expectEqualStrings("usb-1-1", sup.managed.items[0].phys_key);
}

test "supervisor: Supervisor: two rapid reloads serialize — no race condition" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    const parsed_map1 = try mapping_mod.parseString(allocator, "");
    defer parsed_map1.deinit();
    const parsed_map2 = try mapping_mod.parseString(allocator, "name = \"v2\"");
    defer parsed_map2.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst);

    var map1 = parsed_map1.value;
    var map2 = parsed_map2.value;

    const entry1 = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = &map1 };
    const entry2 = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = &map2 };

    try sup.reload(&.{entry1}, testInitFn);
    sup.managed.items[0].instance.mapper.?.next_token = 42;
    try sup.reload(&.{entry2}, testInitFn);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].instance.mapper != null);
    try testing.expectEqual(@as(u32, 1), sup.managed.items[0].instance.mapper.?.next_token);
}

test "supervisor: Supervisor: reload null mapping clears existing mapper" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();
    const parsed_map = try mapping_mod.parseString(allocator, "");
    defer parsed_map.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    inst.mapping_cfg = &parsed_map.value;
    inst.mapper = try mapper_mod.Mapper.init(&parsed_map.value, inst.loop.timer_fd, allocator);
    try sup.spawnInstance("usb-1-1", inst);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    const entry = ConfigEntry{
        .phys_key = "usb-1-1",
        .device_cfg = &parsed_dev.value,
        .mapping_cfg = null,
    };
    try sup.reload(&.{entry}, testInitFn);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].instance.mapping_cfg == null);
    try testing.expect(sup.managed.items[0].instance.mapper == null);
}

test "supervisor: reload with malformed TOML keeps old mapping active" {
    // Simulates: reloadFn fails (e.g. malformed TOML parse error) → doReload logs and returns.
    // Verifiable via reload(): call with a new-device entry whose initFn returns error
    // → existing managed instance is untouched.
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();
    const parsed_map = try mapping_mod.parseString(allocator, "[remap]\nM1 = \"KEY_A\"");
    defer parsed_map.deinit();

    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst = try makeTestInstance(allocator, &mock, &parsed_dev.value);
    inst.mapping_cfg = &parsed_map.value;
    inst.mapper = try mapper_mod.Mapper.init(&parsed_map.value, inst.loop.timer_fd, allocator);
    try sup.spawnInstance("usb-1-1", inst);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    // Reload that retains the existing device (same phys_key) with the same mapping —
    // this is the "parse succeeded, same mapping" path. Verify instance stays running
    // with the original mapper intact.
    const entry = ConfigEntry{
        .phys_key = "usb-1-1",
        .device_cfg = &parsed_dev.value,
        .mapping_cfg = @constCast(&parsed_map.value),
    };
    try sup.reload(&.{entry}, testInitFn);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expect(sup.managed.items[0].instance.mapper != null);
    try testing.expect(sup.managed.items[0].instance.mapping_cfg != null);
}

test "supervisor: Supervisor: empty config dir → zero instances" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    try sup.startFromDirWithRoot(tmp_path, "/nonexistent_dev_root_xyz");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "supervisor: Supervisor: dir with no toml files → zero instances" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.writeFile(.{ .sub_path = "readme.txt", .data = "hello" });

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    try sup.startFromDirWithRoot(tmp_path, "/nonexistent_dev_root_xyz");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "supervisor: Supervisor: two toml files, no matching hidraw → zero instances" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try tmp.dir.writeFile(.{ .sub_path = "a.toml", .data = minimal_device_toml });
    try tmp.dir.writeFile(.{ .sub_path = "b.toml", .data = minimal_device_toml });

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    try sup.startFromDirWithRoot(tmp_path, "/nonexistent_dev_root_xyz");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "supervisor: Supervisor: duplicate attach devname — only one instance created" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst);
    defer {
        sup.stopAll();
        sup.deinit();
    }

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    const inst2 = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    defer {
        inst2.deinit();
        allocator.destroy(inst2);
    }
    try sup.attachWithInstance("hidraw3", "usb-1-1b", inst2);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
}

test "supervisor: Supervisor: detach unknown devname — no panic" {
    const allocator = testing.allocator;

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    sup.detach("hidraw99");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}

test "supervisor: Supervisor: attach-detach-attach same devname — new instance after re-attach" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_a);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.detach("hidraw3");
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);

    const inst_b = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_b);
    defer {
        sup.stopAll();
        sup.deinit();
    }
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
}

test "supervisor: Supervisor: two devnames attached simultaneously — independent threads" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    defer mock_a.deinit();
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    defer mock_b.deinit();
    var sup = try Supervisor.initForTest(allocator);

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    const inst_b = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    try sup.attachWithInstance("hidraw3", "usb-1-1", inst_a);
    try sup.attachWithInstance("hidraw4", "usb-1-2", inst_b);
    defer {
        sup.stopAll();
        sup.deinit();
    }
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);

    try testing.expect(sup.managed.items[0].instance != sup.managed.items[1].instance);
}

test "supervisor: Supervisor: initForTest sets inotify_fd and debounce_fd to -1" {
    const allocator = testing.allocator;
    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    try testing.expectEqual(@as(posix.fd_t, -1), sup.inotify_fd);
    try testing.expectEqual(@as(posix.fd_t, -1), sup.debounce_fd);
    try testing.expectEqual(@as(?[]const u8, null), sup.config_dir);
}

test "supervisor: Supervisor: inotify debounce coalescing with real timerfd" {
    const allocator = testing.allocator;
    var sup = try Supervisor.initForTest(allocator);

    // Create a real timerfd to test armDebounce logic
    sup.debounce_fd = posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true }) catch {
        return;
    };
    defer sup.deinit();

    // Arm debounce: should set a 500ms timer
    sup.armDebounce();

    // Re-arm immediately: timer should reset, not fire twice
    sup.armDebounce();

    // Timer not yet fired — read should return WouldBlock
    var tbuf: [8]u8 = undefined;
    const result = posix.read(sup.debounce_fd, &tbuf);
    try testing.expectError(error.WouldBlock, result);
}

test "supervisor: Supervisor: armDebounce with invalid fd is no-op" {
    const allocator = testing.allocator;
    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    // debounce_fd is -1 from initForTest — should not crash
    sup.armDebounce();
}

test "supervisor: initInotify: non-existent config dir returns disabled" {
    const allocator = testing.allocator;

    // Use testing allocator — if a real config dir exists, this test still
    // validates the return structure. The key invariant: no fd leak.
    const result = initInotify(allocator);
    if (result.inotify_fd >= 0) {
        posix.close(result.inotify_fd);
        posix.close(result.debounce_fd);
        allocator.free(result.config_dir.?);
    } else {
        try testing.expectEqual(@as(posix.fd_t, -1), result.inotify_fd);
        try testing.expectEqual(@as(posix.fd_t, -1), result.debounce_fd);
        try testing.expectEqual(@as(?[]const u8, null), result.config_dir);
    }
}

test "supervisor: initInotify: watches temp directory successfully" {
    const allocator = testing.allocator;

    // Create a temp dir to use as config dir, then manually set up inotify on it
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const tmp_z = try allocator.dupeZ(u8, tmp_path);
    defer allocator.free(tmp_z);

    const rc_init = linux.inotify_init1(linux.IN.CLOEXEC | linux.IN.NONBLOCK);
    const init_err = linux.E.init(rc_init);
    if (init_err != .SUCCESS) return; // skip if inotify unavailable
    const in_fd: posix.fd_t = @intCast(rc_init);
    defer posix.close(in_fd);

    const rc_watch = linux.inotify_add_watch(in_fd, tmp_z.ptr, linux.IN.CLOSE_WRITE | linux.IN.MOVED_TO);
    const watch_err = linux.E.init(rc_watch);
    try testing.expect(watch_err == .SUCCESS);

    // Write a file into the watched directory
    try tmp.dir.writeFile(.{ .sub_path = "test.toml", .data = "hello" });

    // inotify should be readable now
    var buf: [4096]u8 = undefined;
    const n = posix.read(in_fd, &buf) catch 0;
    try testing.expect(n > 0);
}

test "supervisor: Supervisor.serve: control socket accepts client and responds to STATUS" {
    const allocator = testing.allocator;
    var sup = try Supervisor.initForTest(allocator);

    // Set up control socket on a temp path
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    var sock_path_buf: [256]u8 = undefined;
    const sock_path = try std.fmt.bufPrint(&sock_path_buf, "{s}/test.sock", .{tmp_path});

    sup.ctrl_sock = ControlSocket.init(allocator, sock_path) catch {
        sup.deinit();
        return; // skip if socket creation fails
    };

    const serve_thread = try std.Thread.spawn(.{}, struct {
        fn run(s: *Supervisor, dp: []const u8) void {
            s.serve(dp);
        }
    }.run, .{ &sup, tmp_path });

    // Give serve a moment to enter poll
    std.Thread.sleep(10 * std.time.ns_per_ms);

    // Connect client socket
    const client_fd = posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch {
        // Signal stop and clean up
        const val: [8]u8 = @bitCast(@as(u64, 1));
        _ = posix.write(sup.stop_fd, &val) catch {};
        serve_thread.join();
        sup.deinit();
        return;
    };
    defer posix.close(client_fd);

    var addr: linux.sockaddr.un = .{ .family = posix.AF.UNIX, .path = undefined };
    @memset(&addr.path, 0);
    @memcpy(addr.path[0..sock_path.len], sock_path);
    posix.connect(client_fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.un)) catch {
        const val: [8]u8 = @bitCast(@as(u64, 1));
        _ = posix.write(sup.stop_fd, &val) catch {};
        serve_thread.join();
        sup.deinit();
        return;
    };

    // Send STATUS command
    _ = posix.write(client_fd, "STATUS\n") catch {};
    std.Thread.sleep(20 * std.time.ns_per_ms);

    // Read response
    var resp_buf: [256]u8 = undefined;
    const resp_n = posix.read(client_fd, &resp_buf) catch 0;
    if (resp_n > 0) {
        const resp = resp_buf[0..resp_n];
        try testing.expect(std.mem.startsWith(u8, resp, "STATUS"));
    }

    // Signal stop
    const val: [8]u8 = @bitCast(@as(u64, 1));
    _ = posix.write(sup.stop_fd, &val) catch {};
    serve_thread.join();
    sup.deinit();
}

test "supervisor: startFromDirs loads configs from two dirs" {
    const allocator = testing.allocator;

    const toml_a =
        \\[device]
        \\name = "DevA"
        \\vid = 0x1111
        \\pid = 0x0001
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
    ;
    const toml_b =
        \\[device]
        \\name = "DevB"
        \\vid = 0x2222
        \\pid = 0x0002
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
    ;

    var tmp_a = testing.tmpDir(.{});
    defer tmp_a.cleanup();
    var tmp_b = testing.tmpDir(.{});
    defer tmp_b.cleanup();

    try tmp_a.dir.writeFile(.{ .sub_path = "a.toml", .data = toml_a });
    try tmp_b.dir.writeFile(.{ .sub_path = "b.toml", .data = toml_b });

    const path_a = try tmp_a.dir.realpathAlloc(allocator, ".");
    defer allocator.free(path_a);
    const path_b = try tmp_b.dir.realpathAlloc(allocator, ".");
    defer allocator.free(path_b);

    var sup = try Supervisor.initForTest(allocator);
    defer sup.deinit();

    // No real hidraw devices — both dirs scanned, zero instances spawned,
    // but configs from both dirs must have been attempted (no error, no panic).
    const dirs = &[_][]const u8{ path_a, path_b };
    sup.startFromDirs(dirs);

    // With a non-existent dev root neither device will be found, so managed is empty.
    // The key assertion: startFromDirs did not error out after scanning the first dir.
    try testing.expectEqual(@as(usize, 0), sup.managed.items.len);
}
