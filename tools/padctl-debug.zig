const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const src = @import("src");
const device_config = src.config.device;
const InterfaceConfig = device_config.InterfaceConfig;
const Interpreter = src.core.interpreter.Interpreter;
const GamepadState = src.core.state.GamepadState;
const DeviceIO = src.io.device_io.DeviceIO;
const HidrawDevice = src.io.hidraw.HidrawDevice;
const UsbrawDevice = src.io.usbraw.UsbrawDevice;
const init_seq = src.init_seq;
const render = src.debug.render;

const TCGETS: u32 = 0x5401;
const TCSETS: u32 = 0x5402;
const ICANON: u32 = 0x0002;
const ECHO: u32 = 0x0008;
const VMIN: usize = 6;
const VTIME: usize = 5;

// termios for x86_64 Linux
const Termios = extern struct {
    iflag: u32,
    oflag: u32,
    cflag: u32,
    lflag: u32,
    line: u8,
    cc: [32]u8,
    ispeed: u32,
    ospeed: u32,
};

fn tcgetattr(fd: posix.fd_t) !Termios {
    var t: Termios = undefined;
    const rc = linux.syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), TCGETS, @intFromPtr(&t));
    if (rc != 0) return error.IoctlFailed;
    return t;
}

fn tcsetattr(fd: posix.fd_t, t: *const Termios) !void {
    const rc = linux.syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), TCSETS, @intFromPtr(t));
    if (rc != 0) return error.IoctlFailed;
}

fn enableRawMode(fd: posix.fd_t, orig: *Termios) !void {
    orig.* = try tcgetattr(fd);
    var raw = orig.*;
    raw.lflag &= ~(ICANON | ECHO);
    raw.cc[VMIN] = 1;
    raw.cc[VTIME] = 0;
    try tcsetattr(fd, &raw);
}

fn disableRawMode(fd: posix.fd_t, orig: *const Termios) void {
    tcsetattr(fd, orig) catch {};
}

fn sendRumble(dev: DeviceIO, strong: u8, weak: u8) void {
    const pkt = [_]u8{ 0x00, 0x08, 0x00, strong, weak, 0x00, 0x00, 0x00 };
    dev.write(&pkt) catch {};
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
        return dev.deviceIO();
    } else if (std.mem.eql(u8, iface.class, "vendor")) {
        const ep_in: u8 = @intCast(iface.ep_in orelse return error.MissingEndpoint);
        const ep_out: u8 = @intCast(iface.ep_out orelse return error.MissingEndpoint);
        const dev = try UsbrawDevice.open(allocator, vid, pid, @intCast(iface.id), ep_in, ep_out);
        return dev.deviceIO();
    }
    return error.UnknownInterfaceClass;
}

const Cli = struct {
    config_path: ?[]const u8 = null,
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var cli = Cli{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--config")) {
            cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const help =
                \\Usage: padctl-debug --config <path>
                \\
                \\  --config <path>      Device config TOML (required)
                \\  --help               Show this help
                \\
                \\Opens all interfaces from config (vendor via libusb, HID via hidraw).
                \\Keys: Q = quit, R = toggle rumble test
                \\
            ;
            _ = posix.write(posix.STDOUT_FILENO, help) catch 0;
            std.process.exit(0);
        } else {
            std.log.err("unknown argument: {s}", .{arg});
            return error.UnknownArgument;
        }
    }
    return cli;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cli = parseArgs(allocator) catch |err| {
        std.log.err("argument error: {}", .{err});
        std.process.exit(1);
    };

    const config_path = cli.config_path orelse {
        std.log.err("--config is required", .{});
        std.process.exit(1);
    };

    const parsed = device_config.parseFile(allocator, config_path) catch |err| {
        std.log.err("failed to parse config '{s}': {}", .{ config_path, err });
        std.process.exit(1);
    };
    defer parsed.deinit();

    const cfg = &parsed.value;
    const interp = Interpreter.init(cfg);
    const vid: u16 = @intCast(cfg.device.vid & 0xffff);
    const pid: u16 = @intCast(cfg.device.pid & 0xffff);

    // Open all interfaces
    const devices = allocator.alloc(DeviceIO, cfg.device.interface.len) catch |err| {
        std.log.err("alloc failed: {}", .{err});
        std.process.exit(1);
    };
    defer allocator.free(devices);

    var opened: usize = 0;
    defer for (devices[0..opened]) |dev| dev.close();

    for (cfg.device.interface, 0..) |iface, i| {
        devices[i] = createDeviceIO(allocator, iface, vid, pid) catch |err| {
            std.log.err("failed to open interface {d} (class={s}): {}", .{ iface.id, iface.class, err });
            std.process.exit(1);
        };
        opened += 1;
        std.log.info("opened interface {d} (class={s})", .{ iface.id, iface.class });
    }

    // Run init handshake on all devices
    if (cfg.device.init) |init_cfg| {
        for (devices[0..opened]) |dev| {
            init_seq.runInitSequence(allocator, dev, init_cfg) catch |err| {
                std.log.warn("init handshake failed: {}, continuing", .{err});
            };
        }
    }

    // Find vendor-class device for rumble output
    var vendor_dev: ?DeviceIO = null;
    for (cfg.device.interface, 0..) |iface, i| {
        if (std.mem.eql(u8, iface.class, "vendor")) {
            vendor_dev = devices[i];
            break;
        }
    }

    const stdin_fd = posix.STDIN_FILENO;
    const stdout_fd = posix.STDOUT_FILENO;

    var orig_term: Termios = undefined;
    enableRawMode(stdin_fd, &orig_term) catch {};
    defer disableRawMode(stdin_fd, &orig_term);

    _ = posix.write(stdout_fd, "\x1b[?25l") catch 0;
    defer _ = posix.write(stdout_fd, "\x1b[?25h\x1b[0m") catch 0;

    var gs = GamepadState{};
    var raw_buf: [256]u8 = undefined;
    var last_raw_storage: [256]u8 = undefined;
    var last_raw_len: usize = 0;
    var rumble_on = false;
    var last_render: i64 = 0;

    var frame_buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&frame_buf);
    const writer = fbs.writer();

    // Build pollfds: one per device + stdin
    const n_devs = opened;
    const n_fds = n_devs + 1;
    var pollfds_buf: [17]posix.pollfd = undefined; // up to 16 interfaces + stdin
    for (devices[0..n_devs], 0..) |dev, i| {
        pollfds_buf[i] = dev.pollfd();
    }
    pollfds_buf[n_devs] = .{ .fd = stdin_fd, .events = posix.POLL.IN, .revents = 0 };
    const pollfds = pollfds_buf[0..n_fds];

    while (true) {
        // Reset revents
        for (pollfds) |*pfd| pfd.revents = 0;

        _ = posix.poll(pollfds, 16) catch break;

        // Check device fds
        for (0..n_devs) |i| {
            if (pollfds[i].revents & posix.POLL.IN != 0) {
                const n = devices[i].read(&raw_buf) catch |err| switch (err) {
                    error.Again => continue,
                    error.Disconnected => break,
                    error.Io => continue,
                };
                if (n > 0) {
                    const iface_id: u8 = @intCast(cfg.device.interface[i].id);
                    if (interp.processReport(iface_id, raw_buf[0..n])) |maybe_delta| {
                        if (maybe_delta) |delta| gs.applyDelta(delta);
                    } else |_| {}
                    @memcpy(last_raw_storage[0..n], raw_buf[0..n]);
                    last_raw_len = n;
                }
            }
        }

        // Check stdin
        if (pollfds[n_devs].revents & posix.POLL.IN != 0) {
            var key_buf: [4]u8 = undefined;
            const kn = posix.read(stdin_fd, &key_buf) catch 0;
            if (kn > 0) {
                switch (key_buf[0]) {
                    'q', 'Q' => break,
                    'r', 'R' => {
                        rumble_on = !rumble_on;
                        if (vendor_dev) |vd| {
                            sendRumble(vd, if (rumble_on) 0x80 else 0x00, if (rumble_on) 0x80 else 0x00);
                        }
                    },
                    else => {},
                }
            }
        }

        const now = std.time.milliTimestamp();
        if (now - last_render >= 16) {
            last_render = now;
            fbs.reset();
            render.renderFrame(writer, &gs, last_raw_storage[0..last_raw_len], rumble_on) catch {};
            _ = posix.write(stdout_fd, fbs.getWritten()) catch {};
        }
    }
}
