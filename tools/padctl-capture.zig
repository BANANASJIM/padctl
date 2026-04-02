const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const analyse_mod = @import("analyse");
const toml_gen = @import("toml_gen");
const hidraw_mod = @import("hidraw_mod");
const toml = @import("toml");

// Minimal structs for parsing [device.init] from a device TOML config.
const InitConfig = struct {
    commands: []const []const u8 = &.{},
    response_prefix: []const i64 = &.{},
    enable: ?[]const u8 = null,
    report_size: ?i64 = null,
};
const DeviceSection = struct { init: ?InitConfig = null };
const CaptureDeviceConfig = struct { device: DeviceSection };

const Frame = analyse_mod.Frame;

// hidraw_devinfo layout: bustype(u32) + vendor(i16) + product(i16)
const HidrawDevinfo = extern struct { bustype: u32, vendor: i16, product: i16 };
const HIDIOCGRAWINFO: u32 = blk: {
    const req = linux.IOCTL.Request{ .dir = 2, .io_type = 'H', .nr = 0x03, .size = @sizeOf(HidrawDevinfo) };
    break :blk @as(u32, @bitCast(req));
};

const Cli = struct {
    device: ?[]const u8 = null,
    vid: ?u16 = null,
    pid: ?u16 = null,
    interface_id: u8 = 0,
    duration_s: u32 = 30,
    output: ?[]const u8 = null,
    config_path: ?[]const u8 = null,
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    var cli = Cli{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--device")) {
            cli.device = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--vid")) {
            const s = args.next() orelse return error.MissingArgValue;
            cli.vid = try std.fmt.parseInt(u16, s, 0);
        } else if (std.mem.eql(u8, arg, "--pid")) {
            const s = args.next() orelse return error.MissingArgValue;
            cli.pid = try std.fmt.parseInt(u16, s, 0);
        } else if (std.mem.eql(u8, arg, "--interface")) {
            const s = args.next() orelse return error.MissingArgValue;
            cli.interface_id = try std.fmt.parseInt(u8, s, 10);
        } else if (std.mem.eql(u8, arg, "--duration")) {
            const s = args.next() orelse return error.MissingArgValue;
            const trimmed = if (std.mem.endsWith(u8, s, "s")) s[0 .. s.len - 1] else s;
            cli.duration_s = try std.fmt.parseInt(u32, trimmed, 10);
        } else if (std.mem.eql(u8, arg, "--output")) {
            cli.output = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--config")) {
            cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else {
            std.log.err("unknown argument: {s}", .{arg});
            return error.UnknownArgument;
        }
    }
    return cli;
}

fn printHelp() void {
    const help =
        \\Usage: padctl-capture [options]
        \\
        \\Device selection (one required):
        \\  --device /dev/hidrawN    Open specific hidraw node
        \\  --vid 0xVVVV --pid 0xPPPP [--interface N]  Discover by VID/PID
        \\
        \\Init:
        \\  --config <path>          Device TOML config; runs [device.init] before recording
        \\
        \\Recording:
        \\  --duration <N>[s]        Recording duration in seconds (default: 30)
        \\
        \\Output:
        \\  --output <file>          Write TOML skeleton to file (default: stdout)
        \\  --help, -h               Show this help
        \\
    ;
    _ = posix.write(posix.STDOUT_FILENO, help) catch 0;
}

// Record frames from hidraw fd until signalfd fires or duration elapses.
fn record(
    allocator: std.mem.Allocator,
    fd: posix.fd_t,
    duration_s: u32,
    frames: *std.ArrayList(Frame),
    frame_bufs: *std.ArrayList([]u8),
) !void {
    // signalfd for SIGINT/SIGTERM
    var mask: linux.sigset_t = std.mem.zeroes(linux.sigset_t);
    linux.sigaddset(&mask, linux.SIG.INT);
    linux.sigaddset(&mask, linux.SIG.TERM);
    _ = linux.sigprocmask(linux.SIG.BLOCK, &mask, null);
    const sfd = linux.signalfd(-1, &mask, linux.SFD.CLOEXEC);
    if (@as(isize, @bitCast(sfd)) < 0) return error.SignalfdFailed;
    defer posix.close(@intCast(sfd));

    const deadline_ns = std.time.nanoTimestamp() + @as(i128, duration_s) * std.time.ns_per_s;

    std.log.info("Recording — press controls on the device, Ctrl+C or wait {d}s to stop", .{duration_s});

    var read_buf: [256]u8 = undefined;

    while (true) {
        const now = std.time.nanoTimestamp();
        if (now >= deadline_ns) break;

        const remaining_ms: i64 = @intCast(@divTrunc(deadline_ns - now, std.time.ns_per_ms));
        const timeout_ms: i32 = @intCast(@min(remaining_ms, std.math.maxInt(i32)));

        var pfds = [_]posix.pollfd{
            .{ .fd = fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = @intCast(sfd), .events = posix.POLL.IN, .revents = 0 },
        };
        const n = posix.poll(&pfds, timeout_ms) catch break;
        if (n == 0) break; // timeout

        if (pfds[1].revents & posix.POLL.IN != 0) break; // signal

        if (pfds[0].revents & posix.POLL.IN != 0) {
            const nb = posix.read(fd, &read_buf) catch break;
            if (nb == 0) break;

            const ts_us: u64 = @intCast(@divTrunc(std.time.nanoTimestamp(), 1000));
            const buf = try allocator.dupe(u8, read_buf[0..nb]);
            try frame_bufs.append(allocator, buf);
            try frames.append(allocator, .{ .timestamp_us = ts_us, .data = buf });
        }
    }
    std.log.info("Captured {d} frames", .{frames.items.len});
}

fn queryDeviceName(allocator: std.mem.Allocator, fd: posix.fd_t) ![]u8 {
    var name_buf: [256]u8 = std.mem.zeroes([256]u8);
    // HIDIOCGRAWNAME: _IOC(_IOC_READ, 'H', 0x04, len)
    const HIDIOCGRAWNAME: u32 = blk: {
        const req = linux.IOCTL.Request{ .dir = 2, .io_type = 'H', .nr = 0x04, .size = 256 };
        break :blk @as(u32, @bitCast(req));
    };
    _ = linux.ioctl(fd, HIDIOCGRAWNAME, @intFromPtr(&name_buf));
    const name = std.mem.sliceTo(&name_buf, 0);
    return allocator.dupe(u8, if (name.len > 0) name else "Unknown HID Device");
}

/// Parse a hex string like "5aa5 0102 03" into bytes (skipping spaces).
fn parseHexBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    var out = std.ArrayList(u8){};
    defer out.deinit(allocator);
    var i: usize = 0;
    while (i < hex.len) {
        if (hex[i] == ' ') { i += 1; continue; }
        if (i + 1 >= hex.len) return error.InvalidHex;
        const hi = std.fmt.charToDigit(hex[i], 16) catch return error.InvalidHex;
        const lo = std.fmt.charToDigit(hex[i + 1], 16) catch return error.InvalidHex;
        try out.append(allocator, (hi << 4) | lo);
        i += 2;
    }
    return out.toOwnedSlice(allocator);
}

/// Send bytes (zero-padded to report_size) and wait for a response matching prefix.
fn sendAndAwaitPrefix(fd: posix.fd_t, bytes: []const u8, report_size: usize, prefix: []const u8) !void {
    var pad_buf: [64]u8 = .{0} ** 64;
    const send_len = @min(@max(bytes.len, report_size), pad_buf.len);
    const copy_len = @min(bytes.len, pad_buf.len);
    @memcpy(pad_buf[0..copy_len], bytes[0..copy_len]);
    _ = try posix.write(fd, pad_buf[0..send_len]);

    if (prefix.len == 0) {
        std.Thread.sleep(20 * std.time.ns_per_ms);
        return;
    }
    var read_buf: [64]u8 = undefined;
    var attempt: u8 = 0;
    while (attempt < 50) : (attempt += 1) {
        var pfds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
        const n = posix.poll(&pfds, 100) catch break;
        if (n == 0 or pfds[0].revents & posix.POLL.IN == 0) {
            std.Thread.sleep(10 * std.time.ns_per_ms);
            continue;
        }
        const nb = posix.read(fd, &read_buf) catch break;
        if (std.mem.startsWith(u8, read_buf[0..nb], prefix)) return;
    }
    std.log.debug("init command got no ack, continuing", .{});
}

/// Run the [device.init] sequence from a device config TOML file.
fn runInitFromConfig(allocator: std.mem.Allocator, fd: posix.fd_t, config_path: []const u8) !void {
    const content = try std.fs.cwd().readFileAlloc(allocator, config_path, 1024 * 1024);
    defer allocator.free(content);

    var parser = toml.Parser(CaptureDeviceConfig).init(allocator);
    defer parser.deinit();
    var parsed = try parser.parseString(content);
    defer parsed.deinit();

    const init_cfg = parsed.value.device.init orelse {
        std.log.info("no [device.init] in config, skipping", .{});
        return;
    };

    const prefix = blk: {
        var buf = try allocator.alloc(u8, init_cfg.response_prefix.len);
        for (init_cfg.response_prefix, 0..) |b, j| buf[j] = @intCast(b);
        break :blk buf;
    };
    defer allocator.free(prefix);

    const report_size: usize = if (init_cfg.report_size) |rs| @intCast(rs) else 0;

    for (init_cfg.commands) |cmd| {
        const bytes = try parseHexBytes(allocator, cmd);
        defer allocator.free(bytes);
        try sendAndAwaitPrefix(fd, bytes, report_size, prefix);
    }
    if (init_cfg.enable) |enable_cmd| {
        const bytes = try parseHexBytes(allocator, enable_cmd);
        defer allocator.free(bytes);
        try sendAndAwaitPrefix(fd, bytes, report_size, prefix);
    }
    std.log.info("init: sent {d} commands", .{init_cfg.commands.len + @as(usize, if (init_cfg.enable != null) 1 else 0)});
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

    // Resolve device path
    var path_buf: [128]u8 = undefined;
    const device_path: []const u8 = if (cli.device) |d|
        d
    else blk: {
        const vid = cli.vid orelse {
            std.log.err("--device or --vid/--pid required", .{});
            printHelp();
            std.process.exit(1);
        };
        const pid = cli.pid orelse {
            std.log.err("--pid required when --vid is specified", .{});
            std.process.exit(1);
        };
        const p = hidraw_mod.HidrawDevice.discover(allocator, vid, pid, cli.interface_id) catch |err| {
            std.log.err("device 0x{x:0>4}:0x{x:0>4} not found: {}", .{ vid, pid, err });
            std.process.exit(1);
        };
        defer allocator.free(p);
        break :blk try std.fmt.bufPrint(&path_buf, "{s}", .{p});
    };

    const accmode: posix.ACCMODE = if (cli.config_path != null) .RDWR else .RDONLY;
    const fd = posix.open(device_path, .{ .ACCMODE = accmode, .NONBLOCK = true }, 0) catch |err| {
        std.log.err("cannot open {s}: {}", .{ device_path, err });
        std.process.exit(1);
    };
    defer posix.close(fd);

    if (cli.config_path) |cfg| {
        runInitFromConfig(allocator, fd, cfg) catch |err| {
            std.log.err("init sequence failed: {}", .{err});
            std.process.exit(1);
        };
    }

    // Gather device info for TOML header
    var info_struct: HidrawDevinfo = undefined;
    if (linux.ioctl(fd, HIDIOCGRAWINFO, @intFromPtr(&info_struct)) != 0) {
        std.log.err("HIDIOCGRAWINFO failed", .{});
        std.process.exit(1);
    }
    const vid: u16 = @bitCast(info_struct.vendor);
    const pid: u16 = @bitCast(info_struct.product);
    const dev_name = try queryDeviceName(allocator, fd);
    defer allocator.free(dev_name);

    // Record
    var frames: std.ArrayList(Frame) = .{};
    defer frames.deinit(allocator);
    var frame_bufs: std.ArrayList([]u8) = .{};
    defer {
        for (frame_bufs.items) |b| allocator.free(b);
        frame_bufs.deinit(allocator);
    }

    try record(allocator, fd, cli.duration_s, &frames, &frame_bufs);

    if (frames.items.len == 0) {
        std.log.err("no frames captured", .{});
        std.process.exit(1);
    }

    // Analyse
    const result = try analyse_mod.analyse(frames.items, allocator);
    defer result.deinit(allocator);

    std.log.info("Analysis: report_size={d} magic={d} buttons={d} axes={d}", .{
        result.report_size, result.magic.len, result.buttons.len, result.axes.len,
    });

    const dev_info = toml_gen.DeviceInfo{
        .name = dev_name,
        .vid = vid,
        .pid = pid,
        .interface_id = cli.interface_id,
    };

    // Emit TOML
    var out_buf: [4096]u8 = undefined;
    if (cli.output) |out_path| {
        const f = try std.fs.cwd().createFile(out_path, .{});
        defer f.close();
        var bw = f.writer(&out_buf);
        try toml_gen.emitToml(result, dev_info, allocator, &bw.interface);
        try bw.interface.flush();
        std.log.info("Written to {s}", .{out_path});
    } else {
        const stdout = std.fs.File.stdout();
        var bw = stdout.writer(&out_buf);
        try toml_gen.emitToml(result, dev_info, allocator, &bw.interface);
        try bw.interface.flush();
    }
}
