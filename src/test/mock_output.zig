const std = @import("std");

const state = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");

pub const GamepadState = state.GamepadState;
pub const GamepadStateDelta = state.GamepadStateDelta;

pub const MockOutput = struct {
    allocator: std.mem.Allocator,
    emitted: std.ArrayList(GamepadState),
    diffs: std.ArrayList(GamepadStateDelta),
    prev: GamepadState = .{},

    pub fn init(allocator: std.mem.Allocator) MockOutput {
        return .{ .allocator = allocator, .emitted = .{}, .diffs = .{} };
    }

    pub fn deinit(self: *MockOutput) void {
        self.emitted.deinit(self.allocator);
        self.diffs.deinit(self.allocator);
    }

    pub fn outputDevice(self: *MockOutput) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(ptr: *anyopaque, s: GamepadState) uinput.EmitError!void {
        const self: *MockOutput = @ptrCast(@alignCast(ptr));
        self.diffs.append(self.allocator, s.diff(self.prev)) catch return error.WriteFailed;
        self.emitted.append(self.allocator, s) catch return error.WriteFailed;
        self.prev = s;
    }

    fn mockPollFf(_: *anyopaque) uinput.PollFfError!uinput.FfEventBatch {
        return .{};
    }

    fn mockClose(_: *anyopaque) void {}
};
