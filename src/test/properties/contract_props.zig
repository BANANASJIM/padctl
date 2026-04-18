// Vtable contract tests: any implementation of DeviceIO / OutputDevice must satisfy these.
//
// Run against mock implementations to verify the mocks themselves are compliant.

const std = @import("std");
const testing = std.testing;
const posix = std.posix;

const DeviceIO = @import("../../io/device_io.zig").DeviceIO;
const uinput = @import("../../io/uinput.zig");
const state_mod = @import("../../core/state.zig");

const MockDeviceIO = @import("../mock_device_io.zig").MockDeviceIO;
const MockOutput = @import("../mock_output.zig").MockOutput;

const OutputDevice = uinput.OutputDevice;
const GamepadState = state_mod.GamepadState;

// --- DeviceIO contract ---

// C1: read() on an exhausted mock returns Again (not a hard error).
test "contract DeviceIO: read exhausted → Again" {
    const allocator = testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    var buf: [64]u8 = undefined;
    const result = io.read(&buf);
    try testing.expectError(DeviceIO.ReadError.Again, result);
}

// C2: read() on a disconnected mock returns Disconnected consistently.
test "contract DeviceIO: disconnected → Disconnected on every read" {
    const allocator = testing.allocator;
    const frame = &[_]u8{0x01};
    var mock = try MockDeviceIO.init(allocator, &.{frame});
    defer mock.deinit();

    try mock.injectDisconnect();

    const io = mock.deviceIO();
    var buf: [64]u8 = undefined;
    try testing.expectError(DeviceIO.ReadError.Disconnected, io.read(&buf));
    try testing.expectError(DeviceIO.ReadError.Disconnected, io.read(&buf));
}

// C3: write() accepts a non-empty buffer without error.
test "contract DeviceIO: write non-empty buffer succeeds" {
    const allocator = testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    try io.write(&[_]u8{ 0xAA, 0xBB, 0xCC });
    try testing.expectEqualSlices(u8, &[_]u8{ 0xAA, 0xBB, 0xCC }, mock.write_log.items);
}

// C4: pollfd() returns a valid fd (>= 0) with events = POLL.IN.
test "contract DeviceIO: pollfd returns valid fd with POLL.IN" {
    const allocator = testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    const pfd = io.pollfd();
    try testing.expect(pfd.fd >= 0);
    try testing.expectEqual(posix.POLL.IN, pfd.events);
}

// C5: read() returns frames in the order they were registered.
test "contract DeviceIO: read preserves frame order" {
    const allocator = testing.allocator;
    const f1 = &[_]u8{0x01};
    const f2 = &[_]u8{0x02};
    const f3 = &[_]u8{0x03};
    var mock = try MockDeviceIO.init(allocator, &.{ f1, f2, f3 });
    defer mock.deinit();

    const io = mock.deviceIO();
    var buf: [8]u8 = undefined;

    _ = try io.read(&buf);
    try testing.expectEqual(@as(u8, 0x01), buf[0]);
    _ = try io.read(&buf);
    try testing.expectEqual(@as(u8, 0x02), buf[0]);
    _ = try io.read(&buf);
    try testing.expectEqual(@as(u8, 0x03), buf[0]);
    try testing.expectError(DeviceIO.ReadError.Again, io.read(&buf));
}

// C6: close() is callable and does not crash.
test "contract DeviceIO: close is safe to call" {
    const allocator = testing.allocator;
    var mock = try MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();

    const io = mock.deviceIO();
    io.close(); // must not crash
}

// --- OutputDevice contract ---

// C7: emit() accepts any valid GamepadState.
test "contract OutputDevice: emit accepts arbitrary GamepadState" {
    const allocator = testing.allocator;
    var out = MockOutput.init(allocator);
    defer out.deinit();

    const dev = out.outputDevice();

    var prng = std.Random.DefaultPrng.init(0xF00D);
    const rng = prng.random();

    for (0..200) |_| {
        const gs = GamepadState{
            .ax = rng.int(i16),
            .ay = rng.int(i16),
            .rx = rng.int(i16),
            .ry = rng.int(i16),
            .lt = rng.int(u8),
            .rt = rng.int(u8),
            .buttons = rng.int(u64),
        };
        try dev.emit(gs);
    }
    try testing.expectEqual(@as(usize, 200), out.emitted.items.len);
}

// C8: close() can be called without any prior emit.
test "contract OutputDevice: close without prior emit is safe" {
    const allocator = testing.allocator;
    var out = MockOutput.init(allocator);
    defer out.deinit();

    const dev = out.outputDevice();
    dev.close(); // must not crash
}

// C9: poll_ff() on a fresh MockOutput returns null (no force-feedback queued).
test "contract OutputDevice: poll_ff on fresh mock returns null" {
    const allocator = testing.allocator;
    var out = MockOutput.init(allocator);
    defer out.deinit();

    const dev = out.outputDevice();
    const ff = try dev.pollFf();
    try testing.expectEqual(@as(usize, 0), ff.len);
}

// C10: emit() records exact state — no mutation of the passed value.
test "contract OutputDevice: emit records the exact state passed" {
    const allocator = testing.allocator;
    var out = MockOutput.init(allocator);
    defer out.deinit();

    const dev = out.outputDevice();
    const gs = GamepadState{ .ax = 1234, .lt = 255, .buttons = 0xDEAD_BEEF };
    try dev.emit(gs);

    try testing.expectEqual(@as(usize, 1), out.emitted.items.len);
    try testing.expectEqual(gs.ax, out.emitted.items[0].ax);
    try testing.expectEqual(gs.lt, out.emitted.items[0].lt);
    try testing.expectEqual(gs.buttons, out.emitted.items[0].buttons);
}
