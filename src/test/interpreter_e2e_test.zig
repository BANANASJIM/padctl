const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const interpreter_mod = @import("../core/interpreter.zig");
const state_mod = @import("../core/state.zig");
const uinput = @import("../io/uinput.zig");
const MockDeviceIO = @import("mock_device_io.zig").MockDeviceIO;
const EventLoop = @import("../event_loop.zig").EventLoop;
const EventLoopContext = @import("../event_loop.zig").EventLoopContext;
const DeviceIO = @import("../io/device_io.zig").DeviceIO;

const Interpreter = interpreter_mod.Interpreter;
const GamepadState = state_mod.GamepadState;
const ButtonId = state_mod.ButtonId;

// Vader 5 IF1 extended report layout (32 bytes):
//   [0..2]  magic: 5a a5 ef
//   [3..4]  left_x  i16le
//   [5..6]  left_y  i16le (negate transform → stored negated)
//   [7..8]  right_x i16le
//   [9..10] right_y i16le (negate transform)
//   [11..14] button_group source (4 bytes), bit 4 = A
//   [15]    lt u8
//   [16]    rt u8
//   [17..28] IMU fields

const vader5_toml =
    \\[device]
    \\name = "Flydigi Vader 5 Pro"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
    \\[device.init]
    \\commands = ["5aa5 0102 03"]
    \\response_prefix = [0x5a, 0xa5]
    \\[[report]]
    \\name = "extended"
    \\interface = 1
    \\size = 32
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\[report.fields]
    \\left_x  = { offset = 3,  type = "i16le" }
    \\left_y  = { offset = 5,  type = "i16le", transform = "negate" }
    \\right_x = { offset = 7,  type = "i16le" }
    \\right_y = { offset = 9,  type = "i16le", transform = "negate" }
    \\lt      = { offset = 15, type = "u8" }
    \\rt      = { offset = 16, type = "u8" }
    \\[report.button_group]
    \\source = { offset = 11, size = 4 }
    \\map = { DPadUp = 0, DPadRight = 1, DPadDown = 2, DPadLeft = 3, A = 4, B = 5, Select = 6, X = 7, Y = 8, Start = 9, LB = 10, RB = 11, LS = 14, RS = 15, C = 16, Z = 17, M1 = 18, M2 = 19, M3 = 20, M4 = 21, LM = 22, RM = 23, O = 24, Home = 27 }
;

fn makeIf1Sample() [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], 1000, .little); // left_x
    std.mem.writeInt(i16, raw[5..7], -500, .little); // left_y → after negate → 500
    raw[11] = 0x10; // A = bit 4
    raw[15] = 128; // lt
    return raw;
}

// --- Layer 1: raw bytes → GamepadState ---

test "interpreter_e2e: Vader5 IF1 — axes, button A, lt" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, vader5_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const raw = makeIf1Sample();
    const delta = (try interp.processReport(1, &raw)) orelse return error.NoMatch;

    try testing.expectEqual(@as(?i16, 1000), delta.ax);
    try testing.expectEqual(@as(?i16, 500), delta.ay); // negated
    try testing.expectEqual(@as(?u8, 128), delta.lt);

    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
}

test "interpreter_e2e: Vader5 IF1 — load from file and process" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const raw = makeIf1Sample();
    const delta = (try interp.processReport(1, &raw)) orelse return error.NoMatch;

    try testing.expectEqual(@as(?i16, 1000), delta.ax);
    try testing.expectEqual(@as(?i16, 500), delta.ay);
    try testing.expectEqual(@as(?u8, 128), delta.lt);

    const btns = delta.buttons orelse return error.NoBtns;
    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    try testing.expect(btns & (@as(u64, 1) << a_bit) != 0);
}

test "interpreter_e2e: Vader5 IF1 — checksum mismatch suppresses emit" {
    const allocator = testing.allocator;
    const toml_with_cs =
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
        \\size = 6
        \\[report.match]
        \\offset = 0
        \\expect = [0xAA]
        \\[report.checksum]
        \\algo = "sum8"
        \\range = [0, 4]
        \\expect = { offset = 4, type = "u8" }
    ;
    const parsed = try device_mod.parseString(allocator, toml_with_cs);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    const raw = [_]u8{ 0xAA, 0x01, 0x02, 0x03, 0x00, 0x00 }; // wrong checksum
    try testing.expectError(interpreter_mod.ProcessError.ChecksumMismatch, interp.processReport(0, &raw));
}

// --- Layer 1: complete pipeline via EventLoop ---
// Config uses interface = 0 so device at slice index 0 matches.

const pipeline_toml =
    \\[device]
    \\name = "Vader5 Pipeline Test"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[device.init]
    \\commands = []
    \\response_prefix = []
    \\[[report]]
    \\name = "extended"
    \\interface = 0
    \\size = 32
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\[report.fields]
    \\left_x  = { offset = 3,  type = "i16le" }
    \\left_y  = { offset = 5,  type = "i16le", transform = "negate" }
    \\lt      = { offset = 15, type = "u8" }
    \\[report.button_group]
    \\source = { offset = 11, size = 2 }
    \\map = { A = 0, B = 1 }
;

const GamepadStateDelta = state_mod.GamepadStateDelta;

const MockOutput = @import("mock_output.zig").MockOutput;

fn makeFrame(left_x: i16, left_y_raw: i16, buttons_byte: u8, lt: u8) [32]u8 {
    var raw = [_]u8{0} ** 32;
    raw[0] = 0x5a;
    raw[1] = 0xa5;
    raw[2] = 0xef;
    std.mem.writeInt(i16, raw[3..5], left_x, .little);
    std.mem.writeInt(i16, raw[5..7], left_y_raw, .little);
    raw[11] = buttons_byte;
    raw[15] = lt;
    return raw;
}

test "EventLoop pipeline: A press then release" {
    const allocator = testing.allocator;

    var frame1 = makeFrame(1000, -500, 0x01, 128); // A pressed
    var frame2 = makeFrame(1000, -500, 0x00, 128); // A released

    var mock = try MockDeviceIO.init(allocator, &.{ &frame1, &frame2 });
    defer mock.deinit();

    var loop = try EventLoop.initManaged();
    defer loop.deinit();

    const dev = mock.deviceIO();
    try loop.addDevice(dev);

    const parsed = try device_mod.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var out = MockOutput.init(allocator);
    defer out.deinit();
    const output = out.outputDevice();

    try mock.signal();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *EventLoop,
        elc: EventLoopContext,
    };
    var ctx = RunCtx{
        .loop = &loop,
        .elc = .{ .devices = &devs, .interpreter = &interp, .output = output, .poll_timeout_ms = 100 },
    };
    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.elc);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(15 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expect(out.diffs.items.len >= 2);

    const a_bit: u6 = @intCast(@intFromEnum(ButtonId.A));
    const a_mask: u64 = @as(u64, 1) << a_bit;

    // First diff: buttons changed, A pressed
    const d0_btns = out.diffs.items[0].buttons orelse return error.NoDiff;
    try testing.expect(d0_btns & a_mask != 0);
    // Second diff: buttons changed, A released
    const d1_btns = out.diffs.items[1].buttons orelse return error.NoDiff;
    try testing.expect(d1_btns & a_mask == 0);
}

// --- Layer 2 (manual) ---
// 1. zig build -Doptimize=Debug
// 2. sudo ./zig-out/bin/padctl --config devices/flydigi/vader5.toml
// 3. evtest /dev/input/eventN — verify axes and buttons
// 4. jstest --normal /dev/input/jsN — verify joystick
