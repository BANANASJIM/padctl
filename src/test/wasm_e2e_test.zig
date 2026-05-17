// WASM E2E tests: mock plugin processReport modes, load error propagation.

const std = @import("std");
const testing = std.testing;

const runtime_mod = @import("../wasm/runtime.zig");
const host_mod = @import("../wasm/host.zig");

const MockPlugin = runtime_mod.MockPlugin;
const ProcessResult = runtime_mod.ProcessResult;
const GamepadStateDelta = @import("../core/state.zig").GamepadStateDelta;

test "E2E WASM mock: processReport override delivers delta" {
    const delta = GamepadStateDelta{ .ax = 1234, .lt = 200 };
    var mock = MockPlugin{ .process_report_result = .{ .override = delta } };
    const plugin = mock.wasmPlugin();
    var out_buf: [64]u8 = undefined;
    const result = plugin.processReport(&[_]u8{0x01}, &out_buf);
    switch (result) {
        .override => |d| {
            try testing.expectEqual(@as(?i16, 1234), d.ax);
            try testing.expectEqual(@as(?u8, 200), d.lt);
        },
        else => return error.WrongResultTag,
    }
    try testing.expect(mock.process_report_called);
}

test "E2E WASM mock: processReport passthrough falls back to TOML parse" {
    var mock = MockPlugin{ .process_report_result = .passthrough };
    const plugin = mock.wasmPlugin();
    var out_buf: [64]u8 = undefined;
    const result = plugin.processReport(&[_]u8{0xFF}, &out_buf);
    try testing.expectEqual(ProcessResult.passthrough, result);
    try testing.expect(mock.process_report_called);
}

test "E2E WASM mock: processReport drop signals frame discard" {
    var mock = MockPlugin{ .process_report_result = .drop };
    const plugin = mock.wasmPlugin();
    var out_buf: [64]u8 = undefined;
    const result = plugin.processReport(&[_]u8{0xAB}, &out_buf);
    try testing.expectEqual(ProcessResult.drop, result);
    try testing.expect(mock.process_report_called);
}

test "E2E WASM mock: load error propagates, initDevice not reached" {
    var mock = MockPlugin{ .load_error = runtime_mod.LoadError.InvalidModule };
    const plugin = mock.wasmPlugin();
    var ctx = host_mod.HostContext.init(testing.allocator);
    defer ctx.deinit();
    try testing.expectError(
        runtime_mod.LoadError.InvalidModule,
        plugin.load(&[_]u8{}, &ctx),
    );
    try testing.expect(!mock.init_device_called);
}
