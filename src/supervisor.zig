const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const DeviceInstance = @import("device_instance.zig").DeviceInstance;
const MappingConfig = @import("config/mapping.zig").MappingConfig;
const DeviceConfig = @import("config/device.zig").DeviceConfig;

/// One running device under Supervisor management.
pub const ManagedInstance = struct {
    phys_key: []const u8, // physical path — unique stable identity
    instance: *DeviceInstance,
    thread: std.Thread,
    mapping_arena: std.heap.ArenaAllocator, // owns mapping configs allocated during reload
};

/// Config snapshot used for hot-reload diffing.
pub const ConfigEntry = struct {
    phys_key: []const u8,
    device_cfg: *const DeviceConfig,
    mapping_cfg: ?*MappingConfig, // null = no mapping
};

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

        return .{
            .allocator = allocator,
            .managed = .{},
            .stop_fd = stop_fd,
            .hup_fd = hup_fd,
        };
    }

    pub fn deinit(self: *Supervisor) void {
        posix.close(self.stop_fd);
        posix.close(self.hup_fd);
        // Caller responsible for stopping instances before deinit.
        for (self.managed.items) |*m| {
            m.instance.deinit();
            self.allocator.destroy(m.instance);
            m.mapping_arena.deinit();
            self.allocator.free(m.phys_key);
        }
        self.managed.deinit(self.allocator);
    }

    /// Spawn a single DeviceInstance for an already-initialized instance pointer.
    fn spawnInstance(self: *Supervisor, phys_key: []const u8, instance: *DeviceInstance) !void {
        const thread = try std.Thread.spawn(.{}, threadEntry, .{instance});
        const key_copy = try self.allocator.dupe(u8, phys_key);
        errdefer self.allocator.free(key_copy);
        try self.managed.append(self.allocator, .{
            .phys_key = key_copy,
            .instance = instance,
            .thread = thread,
            .mapping_arena = std.heap.ArenaAllocator.init(self.allocator),
        });
    }

    /// Stop and join all instances, then clear the list.
    pub fn stopAll(self: *Supervisor) void {
        for (self.managed.items) |*m| m.instance.stop();
        for (self.managed.items) |*m| m.thread.join();
        for (self.managed.items) |*m| {
            m.instance.deinit();
            self.allocator.destroy(m.instance);
            m.mapping_arena.deinit();
            self.allocator.free(m.phys_key);
        }
        self.managed.clearRetainingCapacity();
    }

    /// Hot-reload: diff new_configs against running instances by phys_key.
    /// - new key   → initFn(entry) → spawn
    /// - removed   → stop + join + free
    /// - same key, mapping changed → updateMapping (atomic swap)
    /// Serialized: call blocks until diff completes.
    pub fn reload(
        self: *Supervisor,
        new_configs: []const ConfigEntry,
        initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
    ) !void {
        // Collect keys to remove: running instances not in new_configs
        var to_remove = std.ArrayList(usize){};
        defer to_remove.deinit(self.allocator);

        outer: for (self.managed.items, 0..) |*m, i| {
            for (new_configs) |nc| {
                if (std.mem.eql(u8, m.phys_key, nc.phys_key)) continue :outer;
            }
            try to_remove.append(self.allocator, i);
        }

        // Stop + join removed instances (in reverse order to keep indices stable)
        var r = to_remove.items.len;
        while (r > 0) {
            r -= 1;
            const idx = to_remove.items[r];
            const m = &self.managed.items[idx];
            m.instance.stop();
            m.thread.join();
            m.instance.deinit();
            self.allocator.destroy(m.instance);
            m.mapping_arena.deinit();
            self.allocator.free(m.phys_key);
            _ = self.managed.swapRemove(idx);
        }

        // For each new config: spawn new or update mapping
        for (new_configs) |nc| {
            var found: ?*ManagedInstance = null;
            for (self.managed.items) |*m| {
                if (std.mem.eql(u8, m.phys_key, nc.phys_key)) {
                    found = m;
                    break;
                }
            }

            if (found == null) {
                // New device — spawn
                const instance = try initFn(self.allocator, nc);
                try self.spawnInstance(nc.phys_key, instance);
            } else if (nc.mapping_cfg) |new_map| {
                // Existing device — hot-swap mapping
                const m = found.?;
                // Allocate new mapping config in the managed arena so it outlives this call
                _ = m.mapping_arena.reset(.retain_capacity);
                const arena_alloc = m.mapping_arena.allocator();
                const map_copy = try arena_alloc.create(MappingConfig);
                map_copy.* = new_map.*;
                m.instance.updateMapping(map_copy);
            }
        }
    }

    pub fn run(
        self: *Supervisor,
        initial_configs: []const ConfigEntry,
        initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
        reloadFn: *const fn (allocator: std.mem.Allocator) anyerror![]ConfigEntry,
        reload_allocator: std.mem.Allocator,
    ) !void {
        // Spawn initial instances
        for (initial_configs) |nc| {
            const instance = try initFn(self.allocator, nc);
            try self.spawnInstance(nc.phys_key, instance);
        }
        defer self.stopAll();

        var pollfds = [2]posix.pollfd{
            .{ .fd = self.stop_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = self.hup_fd, .events = posix.POLL.IN, .revents = 0 },
        };

        while (true) {
            _ = posix.ppoll(&pollfds, null, null) catch |err| switch (err) {
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

                const new_configs = reloadFn(reload_allocator) catch |err| {
                    std.log.err("reload failed: {}", .{err});
                    continue;
                };
                defer reload_allocator.free(new_configs);

                self.reload(new_configs, initFn) catch |err| {
                    std.log.err("hot-reload diff failed: {}", .{err});
                };

                pollfds[1].revents = 0;
            }
        }
    }
};

// --- tests ---

const testing = std.testing;
const mapping_mod = @import("config/mapping.zig");
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

/// Create a DeviceInstance backed by an already-initialized MockDeviceIO.
/// `inst_alloc` owns the DeviceInstance and devices slice.
/// Caller owns `mock` and must call mock.deinit() after DeviceInstance.deinit().
fn makeTestInstance(
    inst_alloc: std.mem.Allocator,
    mock: *MockDeviceIO,
    cfg: *const device_mod.DeviceConfig,
) !*DeviceInstance {

    const devices = try inst_alloc.alloc(DeviceIO, 1);
    devices[0] = mock.deviceIO();

    var loop = try EventLoop.init();
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
        .device_cfg = cfg,
        .pending_mapping = null,
        .stopped = false,
    };
    return inst;
}

// Thread-local mock slot used by testInitFn to pass a per-call mock.
threadlocal var g_mock_slot: ?*MockDeviceIO = null;

fn testInitFn(allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance {
    const mock = g_mock_slot orelse return error.NoMockSlot;
    g_mock_slot = null;
    return makeTestInstance(allocator, mock, entry.device_cfg);
}

test "Supervisor: SIGHUP updates mapping without restarting instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    const parsed_map = try mapping_mod.parseString(allocator, "");
    defer parsed_map.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    var sup = try Supervisor.init(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst);

    var new_map = parsed_map.value;
    const entry = ConfigEntry{
        .phys_key = "usb-1-1",
        .device_cfg = &parsed_dev.value,
        .mapping_cfg = &new_map,
    };

    try sup.reload(&.{entry}, testInitFn);
    std.Thread.sleep(20 * std.time.ns_per_ms);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expectEqualStrings("usb-1-1", sup.managed.items[0].phys_key);

    sup.stopAll();
    sup.deinit();
    mock_a.deinit();
}

test "Supervisor: SIGHUP with new phys_key spawns new instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    var sup = try Supervisor.init(allocator);

    const entry_a = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = null };
    const entry_b = ConfigEntry{ .phys_key = "usb-1-2", .device_cfg = &parsed_dev.value, .mapping_cfg = null };

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst_a);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    // Provide mock for the new instance that testInitFn will create
    g_mock_slot = &mock_b;
    try sup.reload(&.{ entry_a, entry_b }, testInitFn);
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);

    sup.stopAll();
    sup.deinit();
    mock_a.deinit();
    mock_b.deinit();
}

test "Supervisor: SIGHUP with removed phys_key stops instance" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    var mock_b = try MockDeviceIO.init(allocator, &.{});
    var sup = try Supervisor.init(allocator);

    const entry_a = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = null };

    const inst_a = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    const inst_b = try makeTestInstance(allocator, &mock_b, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst_a);
    try sup.spawnInstance("usb-1-2", inst_b);
    try testing.expectEqual(@as(usize, 2), sup.managed.items.len);

    // Reload with only usb-1-1 — usb-1-2 should be stopped and joined
    try sup.reload(&.{entry_a}, testInitFn);
    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);
    try testing.expectEqualStrings("usb-1-1", sup.managed.items[0].phys_key);

    sup.stopAll();
    sup.deinit();
    mock_a.deinit();
    mock_b.deinit();
}

test "Supervisor: two rapid reloads serialize — no race condition" {
    const allocator = testing.allocator;

    const parsed_dev = try device_mod.parseString(allocator, minimal_device_toml);
    defer parsed_dev.deinit();

    const parsed_map1 = try mapping_mod.parseString(allocator, "");
    defer parsed_map1.deinit();
    const parsed_map2 = try mapping_mod.parseString(allocator, "name = \"v2\"");
    defer parsed_map2.deinit();

    var mock_a = try MockDeviceIO.init(allocator, &.{});
    var sup = try Supervisor.init(allocator);

    const inst = try makeTestInstance(allocator, &mock_a, &parsed_dev.value);
    try sup.spawnInstance("usb-1-1", inst);

    var map1 = parsed_map1.value;
    var map2 = parsed_map2.value;

    const entry1 = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = &map1 };
    const entry2 = ConfigEntry{ .phys_key = "usb-1-1", .device_cfg = &parsed_dev.value, .mapping_cfg = &map2 };

    try sup.reload(&.{entry1}, testInitFn);
    try sup.reload(&.{entry2}, testInitFn);

    try testing.expectEqual(@as(usize, 1), sup.managed.items.len);

    sup.stopAll();
    sup.deinit();
    mock_a.deinit();
}
