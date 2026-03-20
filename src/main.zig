const std = @import("std");

pub const core = struct {
    pub const state = @import("core/state.zig");
    pub const interpreter = @import("core/interpreter.zig");
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
};

pub const config = struct {
    pub const device = @import("config/device.zig");
    pub const toml = @import("config/toml.zig");
    pub const input_codes = @import("config/input_codes.zig");
};

pub const event_loop = @import("event_loop.zig");
pub const init_seq = @import("init.zig");

const DeviceIO = io.device_io.DeviceIO;
const DeviceConfig = config.device.DeviceConfig;
const InterfaceConfig = config.device.InterfaceConfig;
const HidrawDevice = io.hidraw.HidrawDevice;
const UsbrawDevice = io.usbraw.UsbrawDevice;
const EventLoop = event_loop.EventLoop;
const Interpreter = core.interpreter.Interpreter;

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

fn createDeviceIO(
    allocator: std.mem.Allocator,
    iface: InterfaceConfig,
    vid: u16,
    pid: u16,
) !DeviceIO {
    if (std.mem.eql(u8, iface.class, "hid")) {
        const path = try HidrawDevice.discover(allocator, vid, pid, @intCast(iface.id));
        defer allocator.free(path);
        var dev = try allocator.create(HidrawDevice);
        dev.* = HidrawDevice.init(allocator);
        try dev.open(path);
        dev.grabAssociatedEvdev(path) catch |err| {
            std.log.warn("grabAssociatedEvdev failed: {}", .{err});
        };
        return dev.deviceIO();
    } else if (std.mem.eql(u8, iface.class, "vendor")) {
        const ep_in: u8 = @intCast(iface.ep_in orelse return error.MissingEndpoint);
        const ep_out: u8 = @intCast(iface.ep_out orelse return error.MissingEndpoint);
        const dev = try UsbrawDevice.open(allocator, vid, pid, @intCast(iface.id), ep_in, ep_out);
        return dev.deviceIO();
    }
    return error.UnknownInterfaceClass;
}

fn openDeviceWithRetry(
    allocator: std.mem.Allocator,
    iface: InterfaceConfig,
    vid: u16,
    pid: u16,
) !DeviceIO {
    const delays = [_]u64{ 1, 2, 4 };
    var attempt: usize = 0;
    while (true) {
        return createDeviceIO(allocator, iface, vid, pid) catch |err| {
            if (attempt >= delays.len) {
                std.log.err("failed to open interface {d} after retries: {}", .{ iface.id, err });
                return err;
            }
            std.log.warn("open interface {d} failed ({}), retrying in {}s...", .{ iface.id, err, delays[attempt] });
            std.Thread.sleep(delays[attempt] * std.time.ns_per_s);
            attempt += 1;
            continue;
        };
    }
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

    // --validate mode: load + validate config, exit 0/1
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
    const cfg = &parsed.value;

    const vid: u16 = @intCast(cfg.device.vid);
    const pid: u16 = @intCast(cfg.device.pid);

    // Open one DeviceIO per interface
    var devices = try allocator.alloc(DeviceIO, cfg.device.interface.len);
    defer allocator.free(devices);

    for (cfg.device.interface, 0..) |iface, i| {
        devices[i] = try openDeviceWithRetry(allocator, iface, vid, pid);
    }
    defer for (devices) |dev| dev.close();

    // Run init handshake on all interfaces if config provides one
    if (cfg.device.init) |init_cfg| {
        for (devices) |dev| {
            init_seq.runInitSequence(allocator, dev, init_cfg) catch |err| {
                std.log.err("init handshake failed: {}", .{err});
                std.process.exit(1);
            };
        }
    }

    // Set up interpreter and event loop
    const interp = Interpreter.init(cfg);

    // TODO T9c: create UinputDevice from cfg.output and wire OutputDevice
    // For now use a no-op output so the event loop compiles
    const NopOutput = struct {
        fn emit(_: *anyopaque, _: core.state.GamepadState) anyerror!void {}
        fn poll_ff(_: *anyopaque) anyerror!?io.uinput.FfEvent { return null; }
        fn close_(_: *anyopaque) void {}
    };
    var nop: u8 = 0;
    const output = io.uinput.OutputDevice{
        .ptr = &nop,
        .vtable = &.{
            .emit = NopOutput.emit,
            .poll_ff = NopOutput.poll_ff,
            .close = NopOutput.close_,
        },
    };

    var loop = try EventLoop.init();
    defer loop.deinit();

    for (devices) |dev| {
        try loop.addDevice(dev);
    }

    try loop.run(devices, &interp, output);
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
