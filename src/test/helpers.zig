const std = @import("std");

const mapping = @import("../config/mapping.zig");
const mapper_mod = @import("../core/mapper.zig");
const state_mod = @import("../core/state.zig");

pub const Mapper = mapper_mod.Mapper;
pub const ButtonId = state_mod.ButtonId;

// Linux input codes (from linux/input-event-codes.h)
pub const REL_X: u16 = 0;
pub const REL_Y: u16 = 1;
pub const BTN_LEFT: u16 = 272;
pub const KEY_UP: u16 = 103;
pub const KEY_DOWN: u16 = 108;
pub const KEY_LEFT: u16 = 105;
pub const KEY_RIGHT: u16 = 106;
pub const KEY_F1: u16 = 59;
pub const KEY_F13: u16 = 183;
pub const KEY_B: u16 = 48;
pub const KEY_LEFTSHIFT: u16 = 42;

pub fn btnMask(id: ButtonId) u32 {
    return @as(u32, 1) << @as(u5, @intCast(@intFromEnum(id)));
}

pub const MapperContext = struct {
    parsed: mapping.ParseResult,
    mapper: Mapper,
    timer_fd: std.posix.fd_t,

    pub fn deinit(self: *MapperContext) void {
        self.mapper.deinit();
        std.posix.close(self.timer_fd);
        self.parsed.deinit();
    }
};

pub fn makeMapper(toml_str: []const u8, allocator: std.mem.Allocator) !MapperContext {
    const parsed = try mapping.parseString(allocator, toml_str);
    const timer_fd = try std.posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
    errdefer std.posix.close(timer_fd);
    const m = try Mapper.init(&parsed.value, timer_fd, allocator);
    return .{ .parsed = parsed, .mapper = m, .timer_fd = timer_fd };
}

const devices_dir = "devices/";

pub fn collectTomlPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit();
    }

    var dir = std.fs.cwd().openDir(devices_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return paths,
        else => return err,
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".toml")) continue;
        const full = try std.fmt.allocPrint(allocator, "{s}{s}", .{ devices_dir, entry.path });
        try paths.append(full);
    }

    return paths;
}

pub fn freeTomlPaths(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8)) void {
    for (paths.items) |p| allocator.free(p);
    paths.deinit();
}
