const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const src = @import("src");
const device_config = src.config.device;
const mapping_config = src.config.mapping;
const InterfaceConfig = device_config.InterfaceConfig;
const Interpreter = src.core.interpreter.Interpreter;
const Mapper = src.core.mapper.Mapper;
const GamepadState = src.core.state.GamepadState;
const ButtonId = src.core.state.ButtonId;
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

const command = src.core.command;

fn sendRumbleFromConfig(
    allocator: std.mem.Allocator,
    dev: DeviceIO,
    cfg: *const device_config.DeviceConfig,
    strong: u8,
    weak: u8,
) void {
    const cmds = cfg.commands orelse return;
    const ff_type = if (cfg.output) |out| if (out.force_feedback) |ff_cfg| ff_cfg.type else "rumble" else "rumble";
    const cmd = cmds.map.get(ff_type) orelse return;
    const params = [_]command.Param{
        .{ .name = "strong", .value = @as(u16, strong) << 8 },
        .{ .name = "weak", .value = @as(u16, weak) << 8 },
    };
    if (command.fillTemplate(allocator, cmd.template, &params)) |bytes| {
        defer allocator.free(bytes);
        if (cmd.checksum) |*cs| {
            command.applyChecksum(bytes, cs);
        }
        dev.write(bytes) catch {};
    } else |_| {}
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
        errdefer allocator.destroy(dev);
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
    mapping_path: ?[]const u8 = null,
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var cli = Cli{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--config")) {
            cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--mapping")) {
            cli.mapping_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const help =
                \\Usage: padctl-debug --config <path> [--mapping <path>]
                \\
                \\  --config <path>      Device config TOML (required)
                \\  --mapping <path>     Mapping config TOML (optional, enables mapped view)
                \\  --help               Show this help
                \\
                \\Opens all interfaces from config (vendor via libusb, HID via hidraw).
                \\Keys: Q = quit, R = toggle rumble, M = toggle raw/mapped, S = stats
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
    var render_cfg = render.RenderConfig.deriveFromConfig(cfg);

    // Populate output info from config
    if (cfg.output) |out| {
        render_cfg.output_info = .{
            .name = out.name orelse cfg.device.name,
        };
    }
    const vid: u16 = @intCast(cfg.device.vid & 0xffff);
    const pid: u16 = @intCast(cfg.device.pid & 0xffff);

    // Load mapping config and create mapper if --mapping provided
    var mapping_parsed: ?mapping_config.ParseResult = null;
    defer if (mapping_parsed) |mp| mp.deinit();

    var mapper: ?Mapper = null;
    defer if (mapper) |*m| m.deinit();

    if (cli.mapping_path) |mpath| {
        mapping_parsed = mapping_config.parseFile(allocator, mpath) catch |err| {
            std.log.err("failed to parse mapping '{s}': {}", .{ mpath, err });
            std.process.exit(1);
        };
        const timer_fd = posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true }) catch |err| {
            std.log.err("failed to create timerfd: {}", .{err});
            std.process.exit(1);
        };
        mapper = Mapper.init(&mapping_parsed.?.value, timer_fd, allocator) catch |err| {
            std.log.err("failed to init mapper: {}", .{err});
            posix.close(timer_fd);
            std.process.exit(1);
        };
        std.log.info("mapping loaded: {s}", .{mpath});
        if (render_cfg.output_info) |*info| {
            info.mapping_file = mpath;
        } else {
            render_cfg.output_info = .{ .mapping_file = mpath };
        }
    }

    // Build mapped button list for mapped view
    var mapped_btn_buf: [64]render.MappedButton = undefined;
    var mapped_btn_count: usize = 0;

    if (cfg.output) |out| {
        if (out.buttons) |buttons| {
            // Start with output.buttons: each maps a ButtonId to an event code
            var it = buttons.map.iterator();
            while (it.next()) |entry| {
                if (std.meta.stringToEnum(ButtonId, entry.key_ptr.*)) |btn| {
                    var event_code = entry.value_ptr.*;

                    // Apply remap override if mapping is loaded
                    if (mapping_parsed) |mp| {
                        if (mp.value.remap) |remap| {
                            if (remap.map.get(entry.key_ptr.*)) |target| {
                                if (std.mem.eql(u8, target, "disabled")) {
                                    continue; // skip disabled buttons
                                }
                                // If remapped to another ButtonId, resolve its output event code
                                if (std.meta.stringToEnum(ButtonId, target)) |_| {
                                    if (buttons.map.get(target)) |resolved| {
                                        event_code = resolved;
                                    } else {
                                        event_code = target;
                                    }
                                } else {
                                    event_code = target;
                                }
                            }
                        }
                    }

                    if (mapped_btn_count < mapped_btn_buf.len) {
                        const short = render.shortenEventCode(event_code);
                        var mb = render.MappedButton{
                            .btn_id = btn,
                            .category = render.categorizeEventCode(event_code),
                            .label_len = @intCast(short.len),
                        };
                        @memcpy(mb.short_label[0..short.len], short);
                        mapped_btn_buf[mapped_btn_count] = mb;
                        mapped_btn_count += 1;
                    }
                }
            }
        }

        // Add buttons from remap that aren't in output.buttons (e.g. back paddles → KEY_*)
        if (mapping_parsed) |mp| {
            if (mp.value.remap) |remap| {
                var it = remap.map.iterator();
                while (it.next()) |entry| {
                    if (std.meta.stringToEnum(ButtonId, entry.key_ptr.*)) |btn| {
                        const target = entry.value_ptr.*;
                        if (std.mem.eql(u8, target, "disabled")) continue;

                        // Skip if already added from output.buttons
                        var already = false;
                        for (mapped_btn_buf[0..mapped_btn_count]) |existing| {
                            if (existing.btn_id == btn) {
                                already = true;
                                break;
                            }
                        }
                        if (already) continue;

                        // Determine event code
                        var event_code = target;
                        if (std.meta.stringToEnum(ButtonId, target)) |_| {
                            if (out.buttons) |buttons| {
                                if (buttons.map.get(target)) |resolved| {
                                    event_code = resolved;
                                }
                            }
                        }

                        if (mapped_btn_count < mapped_btn_buf.len) {
                            const short = render.shortenEventCode(event_code);
                            var mb = render.MappedButton{
                                .btn_id = btn,
                                .category = render.categorizeEventCode(event_code),
                                .label_len = @intCast(short.len),
                            };
                            @memcpy(mb.short_label[0..short.len], short);
                            mapped_btn_buf[mapped_btn_count] = mb;
                            mapped_btn_count += 1;
                        }
                    }
                }
            }
        }
    }
    if (mapped_btn_count > 0) {
        render_cfg.mapped_buttons = mapped_btn_buf[0..mapped_btn_count];
    }

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

    // Run init handshake on the configured interface (or vendor-class fallback)
    if (cfg.device.init) |init_cfg| {
        for (cfg.device.interface[0..opened], devices[0..opened]) |iface, dev| {
            const match = if (init_cfg.interface) |init_iface|
                iface.id == init_iface
            else
                std.mem.eql(u8, iface.class, "vendor");
            if (!match) continue;
            init_seq.runInitSequence(allocator, dev, init_cfg) catch |err| {
                std.log.debug("init handshake failed on interface {d}: {}, continuing", .{ iface.id, err });
            };
        }
    }

    // Find the device for rumble output using the command config's interface ID
    var rumble_dev: ?DeviceIO = null;
    if (cfg.commands) |cmds| {
        const ff_type = if (cfg.output) |out| if (out.force_feedback) |ff_cfg| ff_cfg.type else "rumble" else "rumble";
        if (cmds.map.get(ff_type)) |cmd| {
            for (cfg.device.interface, 0..) |iface, i| {
                if (iface.id == cmd.interface) {
                    rumble_dev = devices[i];
                    break;
                }
            }
        }
    }

    const stdin_fd = posix.STDIN_FILENO;
    const stdout_fd = posix.STDOUT_FILENO;

    var orig_term: Termios = std.mem.zeroes(Termios);
    enableRawMode(stdin_fd, &orig_term) catch |err| {
        std.log.warn("could not enable raw mode: {}", .{err});
    };
    defer disableRawMode(stdin_fd, &orig_term);

    _ = posix.write(stdout_fd, "\x1b[?25l") catch 0;
    defer _ = posix.write(stdout_fd, "\x1b[?25h\x1b[0m") catch 0;

    var gs = GamepadState{};
    var mapped_gs = GamepadState{};
    var aux_display = render.AuxDisplayState{};
    var raw_buf: [256]u8 = undefined;
    var last_raw_storage: [256]u8 = undefined;
    var last_raw_len: usize = 0;
    var rumble_on = false;
    var view_mode: render.ViewMode = .raw;
    var show_stats = false;
    var stats = render.Stats.init(std.time.milliTimestamp());
    var last_render: i64 = 0;
    var prev_buttons: u64 = 0;

    var frame_buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&frame_buf);
    const writer = fbs.writer();

    // Build pollfds: one per device + stdin
    const n_devs = opened;
    if (n_devs > 16) {
        std.log.err("too many interfaces ({d}), max 16", .{n_devs});
        std.process.exit(1);
    }
    const n_fds = n_devs + 1;
    var pollfds_buf: [17]posix.pollfd = undefined; // up to 16 interfaces + stdin
    for (devices[0..n_devs], 0..) |dev, i| {
        pollfds_buf[i] = dev.pollfd();
    }
    pollfds_buf[n_devs] = .{ .fd = stdin_fd, .events = posix.POLL.IN, .revents = 0 };
    const pollfds = pollfds_buf[0..n_fds];

    var running = true;
    while (running) {
        // Reset revents
        for (pollfds) |*pfd| pfd.revents = 0;

        _ = posix.poll(pollfds, 16) catch |err| {
            std.log.err("poll failed: {}", .{err});
            break;
        };

        // Check device fds
        for (0..n_devs) |i| {
            if (pollfds[i].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                std.log.info("device disconnected", .{});
                running = false;
                break;
            }

            if (pollfds[i].revents & posix.POLL.IN != 0) {
                const n = devices[i].read(&raw_buf) catch |err| switch (err) {
                    error.Again => continue,
                    error.Disconnected => {
                        std.log.info("device disconnected", .{});
                        running = false;
                        break;
                    },
                    error.Io => continue,
                };
                if (!running) break;
                if (n > 0) {
                    const pkt_now = std.time.milliTimestamp();
                    stats.recordPacket(pkt_now);
                    const iface_id: u8 = @intCast(cfg.device.interface[i].id);
                    if (interp.processReport(iface_id, raw_buf[0..n])) |maybe_delta| {
                        if (maybe_delta) |delta| {
                            gs.applyDelta(delta);
                            gs.synthesizeDpadAxes();
                            comptime std.debug.assert(std.meta.fields(ButtonId).len <= 64);
                            if (delta.buttons) |new_btns| {
                                const changed = new_btns ^ prev_buttons;
                                if (changed != 0) {
                                    for (0..std.meta.fields(ButtonId).len) |bi| {
                                        const bit: u6 = @intCast(bi);
                                        if (changed & (@as(u64, 1) << bit) != 0) {
                                            const pressed = new_btns & (@as(u64, 1) << bit) != 0;
                                            stats.recordButtonChange(@enumFromInt(bi), pressed, pkt_now);
                                        }
                                    }
                                }
                                prev_buttons = new_btns;
                            }
                            if (mapper) |*m| {
                                if (m.apply(delta, 16)) |out| {
                                    mapped_gs = out.gamepad;
                                    mapped_gs.synthesizeDpadAxes();
                                    // Process aux events
                                    aux_display.mouse_dx = 0;
                                    aux_display.mouse_dy = 0;
                                    aux_display.scroll_v = 0;
                                    aux_display.scroll_h = 0;
                                    for (out.aux.slice()) |ev| {
                                        switch (ev) {
                                            .rel => |r| {
                                                if (r.code == 0) aux_display.mouse_dx += r.value else if (r.code == 1) aux_display.mouse_dy += r.value else if (r.code == 8) aux_display.scroll_v += r.value else if (r.code == 6) aux_display.scroll_h += r.value;
                                            },
                                            .key => |k| {
                                                const now_ms = std.time.milliTimestamp();
                                                aux_display.last_keys[aux_display.key_write_pos] = .{
                                                    .code = k.code,
                                                    .pressed = k.pressed,
                                                    .timestamp_ms = now_ms,
                                                };
                                                aux_display.key_write_pos = (aux_display.key_write_pos + 1) % 8;
                                                aux_display.key_total += 1;
                                            },
                                            .mouse_button => |mb| {
                                                const bit: u3 = switch (mb.code) {
                                                    0x110 => 0,
                                                    0x111 => 1,
                                                    0x112 => 2,
                                                    0x113 => 3,
                                                    0x114 => 4,
                                                    0x115 => 5,
                                                    0x116 => 6,
                                                    else => continue,
                                                };
                                                if (mb.pressed) {
                                                    aux_display.mouse_buttons |= @as(u8, 1) << bit;
                                                } else {
                                                    aux_display.mouse_buttons &= ~(@as(u8, 1) << bit);
                                                }
                                            },
                                        }
                                    }
                                    // Update active layer name
                                    const configs = m.config.layer orelse &.{};
                                    if (m.layer.getActive(configs)) |lc| {
                                        aux_display.active_layer = lc.name;
                                    } else {
                                        aux_display.active_layer = null;
                                    }
                                } else |_| {}
                            }
                        }
                    } else |_| {}
                    @memcpy(last_raw_storage[0..n], raw_buf[0..n]);
                    last_raw_len = n;
                }
            }
        }

        if (!running) break;

        // Check stdin — handle POLLHUP (pipe closed / backgrounded) to avoid busy-spin
        if (pollfds[n_devs].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
            // Disable stdin polling to prevent poll() from returning immediately
            pollfds[n_devs].fd = -1;
        }

        if (pollfds[n_devs].revents & posix.POLL.IN != 0) {
            var key_buf: [4]u8 = undefined;
            const kn = posix.read(stdin_fd, &key_buf) catch 0;
            if (kn > 0) {
                switch (key_buf[0]) {
                    'q', 'Q' => break,
                    'r', 'R' => {
                        rumble_on = !rumble_on;
                        if (rumble_dev) |rd| {
                            sendRumbleFromConfig(allocator, rd, cfg, if (rumble_on) 0x80 else 0x00, if (rumble_on) 0x80 else 0x00);
                        }
                    },
                    'm', 'M' => {
                        if (mapper != null) {
                            view_mode = if (view_mode == .raw) .mapped else .raw;
                        }
                    },
                    's', 'S' => {
                        show_stats = !show_stats;
                    },
                    else => {},
                }
            }
        }

        const now = std.time.milliTimestamp();
        if (now - last_render >= 16) {
            last_render = now;
            fbs.reset();
            render_cfg.stats = if (show_stats) &stats else null;
            render_cfg.aux = if (view_mode == .mapped and mapper != null) &aux_display else null;
            const display_gs = if (view_mode == .mapped and mapper != null) &mapped_gs else &gs;
            render.renderFrame(writer, display_gs, last_raw_storage[0..last_raw_len], rumble_on, render_cfg, view_mode) catch {};
            _ = posix.write(stdout_fd, fbs.getWritten()) catch {};
        }
    }
}
