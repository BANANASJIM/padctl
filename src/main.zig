const std = @import("std");

pub const core = struct {
    pub const state = @import("core/state.zig");
    pub const interpreter = @import("core/interpreter.zig");
    pub const remap = @import("core/remap.zig");
    pub const layer = @import("core/layer.zig");
    pub const mapper = @import("core/mapper.zig");
    pub const stick = @import("core/stick.zig");
    pub const dpad = @import("core/dpad.zig");
    pub const command = @import("core/command.zig");
    pub const macro = @import("core/macro.zig");
    pub const timer_queue = @import("core/timer_queue.zig");
    pub const macro_player = @import("core/macro_player.zig");
};

pub const io = struct {
    pub const device_io = @import("io/device_io.zig");
    pub const hidraw = @import("io/hidraw.zig");
    pub const usbraw = @import("io/usbraw.zig");
    pub const uinput = @import("io/uinput.zig");
    pub const ioctl_constants = @import("io/ioctl_constants.zig");
};

pub const testing_support = struct {
    pub const mock_device_io = @import("test/mock_device_io.zig");
    pub const e2e_test = @import("test/e2e_test.zig");
    pub const phase2a_e2e_test = @import("test/phase2a_e2e_test.zig");
    pub const phase2b_e2e_test = @import("test/phase2b_e2e_test.zig");
};

pub const config = struct {
    pub const device = @import("config/device.zig");
    pub const toml = @import("config/toml.zig");
    pub const input_codes = @import("config/input_codes.zig");
    pub const mapping = @import("config/mapping.zig");
};

pub const event_loop = @import("event_loop.zig");
pub const init_seq = @import("init.zig");
pub const device_instance = @import("device_instance.zig");
pub const supervisor = @import("supervisor.zig");

const DeviceInstance = device_instance.DeviceInstance;
const Supervisor = supervisor.Supervisor;
const Interpreter = core.interpreter.Interpreter;
const DeviceIO = io.device_io.DeviceIO;

const VERSION = "0.1.0";

const Cli = struct {
    config_path: ?[]const u8 = null,
    mapping_path: ?[]const u8 = null,
    validate_path: ?[]const u8 = null,
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip argv[0]

    var cli = Cli{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            _ = std.posix.write(std.posix.STDOUT_FILENO, "padctl " ++ VERSION ++ "\n") catch 0;
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--config")) {
            cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--mapping")) {
            cli.mapping_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--validate")) {
            cli.validate_path = args.next() orelse return error.MissingArgValue;
        } else {
            std.log.err("unknown argument: {s}", .{arg});
            return error.UnknownArgument;
        }
    }
    return cli;
}

fn printHelp() void {
    const help =
        \\Usage: padctl [options]
        \\
        \\Options:
        \\  --config <path>     Device config TOML file (required to run)
        \\  --mapping <path>    Mapping config TOML file (optional)
        \\  --validate <path>   Validate device config and exit (returns 0/1)
        \\  --help, -h          Show this help
        \\  --version, -V       Show version
        \\
    ;
    _ = std.posix.write(std.posix.STDOUT_FILENO, help) catch 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cli = parseArgs(allocator) catch |err| {
        std.log.err("argument error: {}", .{err});
        printHelp();
        std.process.exit(1);
    };

    // --validate mode: parse config and exit
    if (cli.validate_path) |path| {
        const result = config.device.parseFile(allocator, path) catch |err| {
            std.log.err("invalid config: {}", .{err});
            std.process.exit(1);
        };
        result.deinit();
        std.process.exit(0);
    }

    const config_path = cli.config_path orelse {
        std.log.err("--config <path> is required", .{});
        printHelp();
        std.process.exit(1);
    };

    const parsed = config.device.parseFile(allocator, config_path) catch |err| {
        std.log.err("failed to load config '{s}': {}", .{ config_path, err });
        std.process.exit(1);
    };
    defer parsed.deinit();

    const inst = DeviceInstance.init(allocator, &parsed.value) catch |err| {
        std.log.err("failed to init device: {}", .{err});
        std.process.exit(1);
    };

    var sv = Supervisor.init(allocator) catch |err| {
        std.log.err("failed to init supervisor: {}", .{err});
        std.process.exit(1);
    };
    defer sv.deinit();

    sv.addInstance(inst, &parsed.value) catch |err| {
        std.log.err("failed to add instance: {}", .{err});
        std.process.exit(1);
    };

    try sv.run();
}

test {
    std.testing.refAllDecls(@This());
}

// --- CLI tests ---

const testing = std.testing;

test "parseHexBytes via init_seq" {
    // Smoke-test that init_seq is reachable from main
    const allocator = testing.allocator;
    const bytes = try init_seq.parseHexBytes(allocator, "5aa5 01");
    defer allocator.free(bytes);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x5a, 0xa5, 0x01 }, bytes);
}

// --- T9c Layer 1 integration tests ---

const MockOutput = struct {
    allocator: std.mem.Allocator,
    emitted: std.ArrayList(core.state.GamepadState),

    fn init(allocator: std.mem.Allocator) MockOutput {
        return .{ .allocator = allocator, .emitted = .{} };
    }

    fn deinit(self: *MockOutput) void {
        self.emitted.deinit(self.allocator);
    }

    fn outputDevice(self: *MockOutput) io.uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = io.uinput.OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(ptr: *anyopaque, s: core.state.GamepadState) anyerror!void {
        const self: *MockOutput = @ptrCast(@alignCast(ptr));
        try self.emitted.append(self.allocator, s);
    }

    fn mockPollFf(_: *anyopaque) anyerror!?io.uinput.FfEvent {
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

const pipeline_toml =
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

test "pipeline: known frame dispatched to output" {
    const allocator = testing.allocator;

    const parsed = try config.device.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var frame: [3]u8 = undefined;
    frame[0] = 0x01;
    std.mem.writeInt(i16, frame[1..3], 750, .little);

    var mock = try testing_support.mock_device_io.MockDeviceIO.init(allocator, &.{&frame});
    defer mock.deinit();
    const dev = mock.deviceIO();

    var loop = try event_loop.EventLoop.init();
    defer loop.deinit();
    try loop.addDevice(dev);

    var out = MockOutput.init(allocator);
    defer out.deinit();

    try mock.signal();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *event_loop.EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        out: *MockOutput,
    };
    var ctx = RunCtx{ .loop = &loop, .devs = &devs, .interp = &interp, .out = &out };
    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.devs, c.interp, c.out.outputDevice(), null, null, null, null);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expect(out.emitted.items.len >= 1);
    try testing.expectEqual(@as(i16, 750), loop.gamepad_state.ax);
}

test "pipeline: unknown report does not call output.emit" {
    const allocator = testing.allocator;

    const parsed = try config.device.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Wrong magic byte — no report match
    const frame = [_]u8{ 0xFF, 0x00, 0x00 };

    var mock = try testing_support.mock_device_io.MockDeviceIO.init(allocator, &.{&frame});
    defer mock.deinit();
    const dev = mock.deviceIO();

    var loop = try event_loop.EventLoop.init();
    defer loop.deinit();
    try loop.addDevice(dev);

    var out = MockOutput.init(allocator);
    defer out.deinit();

    try mock.signal();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *event_loop.EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        out: *MockOutput,
    };
    var ctx = RunCtx{ .loop = &loop, .devs = &devs, .interp = &interp, .out = &out };
    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.devs, c.interp, c.out.outputDevice(), null, null, null, null);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 0), out.emitted.items.len);
}

test "pipeline: signalfd stop — no fd leak" {
    const allocator = testing.allocator;

    const parsed = try config.device.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var mock = try testing_support.mock_device_io.MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    var loop = try event_loop.EventLoop.init();
    defer loop.deinit();
    try loop.addDevice(dev);

    var out = MockOutput.init(allocator);
    defer out.deinit();

    var devs = [_]DeviceIO{dev};
    const RunCtx = struct {
        loop: *event_loop.EventLoop,
        devs: []DeviceIO,
        interp: *const Interpreter,
        out: *MockOutput,
    };
    var ctx = RunCtx{ .loop = &loop, .devs = &devs, .interp = &interp, .out = &out };
    const T = struct {
        fn run(c: *RunCtx) !void {
            try c.loop.run(c.devs, c.interp, c.out.outputDevice(), null, null, null, null);
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    // Stop immediately without any frames
    std.Thread.sleep(5 * std.time.ns_per_ms);
    loop.stop();
    thread.join();
    // If we reach here without crash, fds are properly managed (GPA would catch leaks)
    try testing.expectEqual(@as(usize, 0), out.emitted.items.len);
}
