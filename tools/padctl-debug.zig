const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const src = @import("src");
const device_config = src.config.device;
const Interpreter = src.core.interpreter.Interpreter;
const GamepadState = src.core.state.GamepadState;
const HidrawDevice = src.io.hidraw.HidrawDevice;
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

fn hidrawRead(fd: posix.fd_t, buf: []u8) !usize {
    const n = posix.read(fd, buf) catch |err| switch (err) {
        error.WouldBlock => return 0,
        else => return err,
    };
    return n;
}

fn sendRumble(fd: posix.fd_t, strong: u8, weak: u8) void {
    const pkt = [_]u8{ 0x00, 0x08, 0x00, strong, weak, 0x00, 0x00, 0x00 };
    _ = posix.write(fd, &pkt) catch {};
}

const Cli = struct {
    config_path: ?[]const u8 = null,
    device_path: ?[]const u8 = null,
    interface_id: u8 = 1,
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var cli = Cli{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--config")) {
            cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--device")) {
            cli.device_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--interface")) {
            const s = args.next() orelse return error.MissingArgValue;
            cli.interface_id = try std.fmt.parseInt(u8, s, 10);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const help =
                \\Usage: padctl-debug --config <path> [--device /dev/hidrawN] [--interface N]
                \\
                \\  --config <path>      Device config TOML (required)
                \\  --device <path>      hidraw device node (default: auto-discover by VID/PID)
                \\  --interface <N>      Interface ID for report matching (default: 1)
                \\  --help               Show this help
                \\
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

    var discovered_path: ?[]const u8 = null;
    defer if (discovered_path) |p| allocator.free(p);

    const dev_path = if (cli.device_path) |p| p else blk: {
        const vid: u16 = @intCast(cfg.device.vid & 0xffff);
        const pid: u16 = @intCast(cfg.device.pid & 0xffff);
        const p = HidrawDevice.discover(allocator, vid, pid, cli.interface_id) catch |err| {
            std.log.err("device not found (vid={x:0>4} pid={x:0>4}): {}", .{ vid, pid, err });
            std.process.exit(1);
        };
        discovered_path = p;
        break :blk p;
    };

    const hid_fd = posix.open(dev_path, .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0) catch |err| {
        std.log.err("failed to open '{s}': {}", .{ dev_path, err });
        std.process.exit(1);
    };
    defer posix.close(hid_fd);

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

    // Frame buffer: 80x24 ANSI output fits comfortably in 8 KiB
    var frame_buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&frame_buf);
    const writer = fbs.writer();

    while (true) {
        var fds = [_]posix.pollfd{
            .{ .fd = hid_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = stdin_fd, .events = posix.POLL.IN, .revents = 0 },
        };
        _ = posix.poll(&fds, 16) catch break;

        if (fds[0].revents & posix.POLL.IN != 0) {
            const n = hidrawRead(hid_fd, &raw_buf) catch break;
            if (n > 0) {
                const raw = raw_buf[0..n];
                if (interp.processReport(cli.interface_id, raw)) |maybe_delta| {
                    if (maybe_delta) |delta| gs.applyDelta(delta);
                } else |_| {}
                @memcpy(last_raw_storage[0..n], raw);
                last_raw_len = n;
            }
        }

        if (fds[1].revents & posix.POLL.IN != 0) {
            var key_buf: [4]u8 = undefined;
            const kn = posix.read(stdin_fd, &key_buf) catch 0;
            if (kn > 0) {
                switch (key_buf[0]) {
                    'q', 'Q' => break,
                    'r', 'R' => {
                        rumble_on = !rumble_on;
                        sendRumble(hid_fd, if (rumble_on) 0x80 else 0x00, if (rumble_on) 0x80 else 0x00);
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
