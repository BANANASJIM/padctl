const std = @import("std");

pub const Target = struct {
    path: []const u8, // owned by caller's allocator
    interface_id: u8,
};

/// Injected dependencies (real implementations in tools/padctl-capture.zig,
/// mocks in tests). discover returns an allocated path the caller frees.
pub const Deps = struct {
    discover: *const fn (std.mem.Allocator, u16, u16, ?u8) anyerror![]const u8,
    read_interface_id: *const fn ([]const u8) ?u8,
};

pub const Error = error{ MissingDevice, MissingPid } || std.mem.Allocator.Error;

/// Resolve the hidraw path + interface id for both selection modes.
/// --device: use the path as-is, then read its real interface (#264 fix:
///           interface comes from the node, not cli.interface_id).
/// --vid/--pid: discover (optionally interface-filtered), then read the
///              resolved node's real interface.
/// The returned path is allocated with `allocator`; caller frees it.
pub fn resolveCaptureTarget(
    allocator: std.mem.Allocator,
    deps: Deps,
    device: ?[]const u8,
    vid: ?u16,
    pid: ?u16,
    explicit_interface: ?u8,
) anyerror!Target {
    const path: []const u8 = if (device) |d|
        try allocator.dupe(u8, d)
    else blk: {
        const v = vid orelse return Error.MissingDevice;
        const p = pid orelse return Error.MissingPid;
        const discovered = try deps.discover(allocator, v, p, explicit_interface);
        break :blk discovered;
    };
    errdefer allocator.free(path);

    const interface_id: u8 = deps.read_interface_id(path) orelse 0;
    return .{ .path = path, .interface_id = interface_id };
}
