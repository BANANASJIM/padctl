const std = @import("std");

fn stdoutWrite(_: void, data: []const u8) error{}!usize {
    return std.posix.write(std.posix.STDOUT_FILENO, data) catch data.len;
}
const stdout_writer: std.io.GenericWriter(void, error{}, stdoutWrite) = .{ .context = {} };

fn stderrWrite(_: void, data: []const u8) error{}!usize {
    return std.posix.write(std.posix.STDERR_FILENO, data) catch data.len;
}
const stderr_writer: std.io.GenericWriter(void, error{}, stderrWrite) = .{ .context = {} };

pub const tools = struct {
    pub const validate = @import("tools/validate.zig");
    pub const docgen = @import("tools/docgen.zig");
};

pub const cli = struct {
    pub const install = @import("cli/install.zig");
    pub const scan = @import("cli/scan.zig");
    pub const reload = @import("cli/reload.zig");
    pub const list_mappings = @import("cli/list_mappings.zig");
    pub const socket_client = @import("cli/socket_client.zig");
    pub const switch_mapping = @import("cli/switch_mapping.zig");
    pub const status = @import("cli/status.zig");
    pub const devices = @import("cli/devices.zig");
    pub const config = struct {
        pub const list = @import("cli/config/list.zig");
        pub const init = @import("cli/config/init.zig");
        pub const edit = @import("cli/config/edit.zig");
        pub const @"test" = @import("cli/config/test.zig");
    };
};

pub const wasm = struct {
    pub const runtime = @import("wasm/runtime.zig");
    pub const host = @import("wasm/host.zig");
    pub const wasm3_backend = if (@import("build_options").use_wasm)
        @import("wasm/wasm3_backend.zig")
    else
        struct {};
};

pub const core = struct {
    pub const state = @import("core/state.zig");
    pub const interpreter = @import("core/interpreter.zig");
    pub const generic = @import("core/generic.zig");
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
    pub const netlink = @import("io/netlink.zig");
};

pub const testing_support = struct {
    pub const mock_device_io = @import("test/mock_device_io.zig");
    pub const mock_output = @import("test/mock_output.zig");
    pub const helpers = @import("test/helpers.zig");
    pub const interpreter_e2e_test = @import("test/interpreter_e2e_test.zig");
    pub const mapper_e2e_test = @import("test/mapper_e2e_test.zig");
    pub const gyro_stick_e2e_test = @import("test/gyro_stick_e2e_test.zig");
    pub const macro_e2e_test = @import("test/macro_e2e_test.zig");
    pub const capture_e2e_test = @import("test/capture_e2e_test.zig");
    pub const supervisor_e2e_test = @import("test/supervisor_e2e_test.zig");
    pub const wasm_e2e_test = @import("test/wasm_e2e_test.zig");
    pub const validate_e2e_test = @import("test/validate_e2e_test.zig");
    pub const cli_e2e_test = @import("test/cli_e2e_test.zig");
    pub const auto_device_test = @import("test/auto_device_test.zig");
    pub const transform_boundary_test = @import("test/transform_boundary_test.zig");
    pub const bugfix_regression_test = @import("test/bugfix_regression_test.zig");
    pub const interpreter_props = @import("test/properties/interpreter_props.zig");
    pub const render_props = @import("test/properties/render_props.zig");
    pub const config_props = @import("test/properties/config_props.zig");
    pub const hidraw_dedup_props = @import("test/properties/hidraw_dedup_props.zig");
    pub const state_props = @import("test/properties/state_props.zig");
    pub const mapper_props = @import("test/properties/mapper_props.zig");
    pub const ipc_props = @import("test/properties/ipc_props.zig");
    pub const transform_props = @import("test/properties/transform_props.zig");
    pub const e2e_pipeline_props = @import("test/properties/e2e_pipeline_props.zig");
    pub const metamorphic_props = @import("test/properties/metamorphic_props.zig");
    pub const contract_props = @import("test/properties/contract_props.zig");
    pub const drt_props = @import("test/properties/drt_props.zig");
    pub const supervisor_sm_props = @import("test/properties/supervisor_sm_props.zig");
    pub const negative_corpus_props = @import("test/properties/negative_corpus_props.zig");
    pub const generative_mapper_props = @import("test/properties/generative_mapper_props.zig");
    pub const regression_corpus_props = @import("test/properties/regression_corpus_props.zig");
    pub const device_specific_props = @import("test/properties/device_specific_props.zig");
    pub const reference_interp = @import("test/reference_interp.zig");
    pub const gen = @import("test/gen/gen.zig");
};

pub const config = struct {
    pub const device = @import("config/device.zig");
    pub const input_codes = @import("config/input_codes.zig");
    pub const mapping = @import("config/mapping.zig");
    pub const mapping_discovery = @import("config/mapping_discovery.zig");
    pub const presets = @import("config/presets.zig");
    pub const paths = @import("config/paths.zig");
};

pub const debug = struct {
    pub const render = @import("debug/render.zig");
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
    allocator: std.mem.Allocator,
    config_path: ?[]const u8 = null,
    config_dir: ?[]const u8 = null,
    mapping_path: ?[]const u8 = null,
    validate_files: std.ArrayList([]const u8) = .{},
    doc_gen: bool = false,
    doc_gen_output: []const u8 = "docs/src/devices",
    install_opts: ?cli.install.InstallOptions = null,
    uninstall_opts: ?cli.install.InstallOptions = null,
    setup_test_udev: bool = false,
    scan: bool = false,
    scan_config_dir: ?[]const u8 = null,
    list_mappings: bool = false,
    list_mappings_config_dir: ?[]const u8 = null,
    reload: bool = false,
    reload_pid: ?[]const u8 = null,
    pid_file: ?[]const u8 = null,
    config_cmd: ?ConfigCmd = null,
    switch_cmd: ?struct { name: []const u8, device_id: ?[]const u8 = null } = null,
    status_cmd: bool = false,
    devices_cmd: bool = false,
    socket_path: []const u8 = cli.socket_client.DEFAULT_SOCKET_PATH,
    socket_explicit: bool = false,

    fn deinit(self: *Cli) void {
        self.validate_files.deinit(self.allocator);
    }
};

const ConfigCmd = union(enum) {
    list,
    init: struct { device: ?[]const u8, preset: ?[]const u8 },
    edit: ?[]const u8,
    @"test": struct { config: ?[]const u8, mapping: ?[]const u8 },
};

fn parseArgs(allocator: std.mem.Allocator) !Cli {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip argv[0]

    var parsed_cli = Cli{ .allocator = allocator };
    var in_validate = false;
    while (args.next()) |arg| {
        if (in_validate and !std.mem.startsWith(u8, arg, "--")) {
            try parsed_cli.validate_files.append(allocator, arg);
            continue;
        }
        in_validate = false;
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            _ = std.posix.write(std.posix.STDOUT_FILENO, "padctl " ++ VERSION ++ "\n") catch 0;
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "install")) {
            var opts = cli.install.InstallOptions{};
            while (args.next()) |iarg| {
                if (std.mem.eql(u8, iarg, "--prefix")) {
                    opts.prefix = args.next() orelse return error.MissingArgValue;
                } else if (std.mem.eql(u8, iarg, "--destdir")) {
                    opts.destdir = args.next() orelse return error.MissingArgValue;
                } else {
                    std.log.err("unknown install argument: {s}", .{iarg});
                    return error.UnknownArgument;
                }
            }
            parsed_cli.install_opts = opts;
        } else if (std.mem.eql(u8, arg, "uninstall")) {
            var opts = cli.install.InstallOptions{};
            while (args.next()) |iarg| {
                if (std.mem.eql(u8, iarg, "--prefix")) {
                    opts.prefix = args.next() orelse return error.MissingArgValue;
                } else if (std.mem.eql(u8, iarg, "--destdir")) {
                    opts.destdir = args.next() orelse return error.MissingArgValue;
                } else {
                    std.log.err("unknown uninstall argument: {s}", .{iarg});
                    return error.UnknownArgument;
                }
            }
            parsed_cli.uninstall_opts = opts;
        } else if (std.mem.eql(u8, arg, "setup-test-udev")) {
            parsed_cli.setup_test_udev = true;
        } else if (std.mem.eql(u8, arg, "scan")) {
            parsed_cli.scan = true;
            while (args.next()) |sub_arg| {
                if (std.mem.eql(u8, sub_arg, "--config-dir")) {
                    parsed_cli.scan_config_dir = args.next() orelse return error.MissingArgValue;
                } else {
                    std.log.err("unknown scan argument: {s}", .{sub_arg});
                    return error.UnknownArgument;
                }
            }
        } else if (std.mem.eql(u8, arg, "list-mappings")) {
            parsed_cli.list_mappings = true;
            while (args.next()) |sub_arg| {
                if (std.mem.eql(u8, sub_arg, "--config-dir")) {
                    parsed_cli.list_mappings_config_dir = args.next() orelse return error.MissingArgValue;
                } else {
                    std.log.err("unknown list-mappings argument: {s}", .{sub_arg});
                    return error.UnknownArgument;
                }
            }
        } else if (std.mem.eql(u8, arg, "--config")) {
            parsed_cli.config_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--config-dir")) {
            parsed_cli.config_dir = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--mapping")) {
            parsed_cli.mapping_path = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--validate")) {
            in_validate = true;
            const first = args.next() orelse return error.MissingArgValue;
            try parsed_cli.validate_files.append(allocator, first);
        } else if (std.mem.eql(u8, arg, "--pid-file")) {
            parsed_cli.pid_file = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "--doc-gen")) {
            parsed_cli.doc_gen = true;
        } else if (std.mem.eql(u8, arg, "--output")) {
            parsed_cli.doc_gen_output = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "reload")) {
            parsed_cli.reload = true;
        } else if (std.mem.eql(u8, arg, "--pid")) {
            parsed_cli.reload_pid = args.next() orelse return error.MissingArgValue;
        } else if (std.mem.eql(u8, arg, "config")) {
            const sub = args.next() orelse {
                std.log.err("config: missing subcommand (list|init|edit|test)", .{});
                return error.MissingArgValue;
            };
            if (std.mem.eql(u8, sub, "list")) {
                parsed_cli.config_cmd = .list;
            } else if (std.mem.eql(u8, sub, "init")) {
                var device: ?[]const u8 = null;
                var preset: ?[]const u8 = null;
                while (args.next()) |iarg| {
                    if (std.mem.eql(u8, iarg, "--device")) {
                        device = args.next() orelse return error.MissingArgValue;
                    } else if (std.mem.eql(u8, iarg, "--preset")) {
                        preset = args.next() orelse return error.MissingArgValue;
                    } else {
                        std.log.err("unknown config init argument: {s}", .{iarg});
                        return error.UnknownArgument;
                    }
                }
                parsed_cli.config_cmd = .{ .init = .{ .device = device, .preset = preset } };
            } else if (std.mem.eql(u8, sub, "edit")) {
                const mapping_name = args.next();
                parsed_cli.config_cmd = .{ .edit = mapping_name };
            } else if (std.mem.eql(u8, sub, "test")) {
                var test_config: ?[]const u8 = null;
                var test_mapping: ?[]const u8 = null;
                while (args.next()) |targ| {
                    if (std.mem.eql(u8, targ, "--config")) {
                        test_config = args.next() orelse return error.MissingArgValue;
                    } else if (std.mem.eql(u8, targ, "--mapping")) {
                        test_mapping = args.next() orelse return error.MissingArgValue;
                    } else {
                        std.log.err("unknown config test argument: {s}", .{targ});
                        return error.UnknownArgument;
                    }
                }
                parsed_cli.config_cmd = .{ .@"test" = .{ .config = test_config, .mapping = test_mapping } };
            } else {
                std.log.err("unknown config subcommand: {s}", .{sub});
                return error.UnknownArgument;
            }
        } else if (std.mem.eql(u8, arg, "switch")) {
            const name = args.next() orelse {
                std.log.err("switch: missing mapping name", .{});
                return error.MissingArgValue;
            };
            var device_id: ?[]const u8 = null;
            while (args.next()) |sub_arg| {
                if (std.mem.eql(u8, sub_arg, "--device")) {
                    device_id = args.next() orelse return error.MissingArgValue;
                } else if (std.mem.eql(u8, sub_arg, "--socket")) {
                    parsed_cli.socket_path = args.next() orelse return error.MissingArgValue;
                    parsed_cli.socket_explicit = true;
                } else {
                    std.log.err("unknown switch argument: {s}", .{sub_arg});
                    return error.UnknownArgument;
                }
            }
            parsed_cli.switch_cmd = .{ .name = name, .device_id = device_id };
        } else if (std.mem.eql(u8, arg, "status")) {
            parsed_cli.status_cmd = true;
            while (args.next()) |sub_arg| {
                if (std.mem.eql(u8, sub_arg, "--socket")) {
                    parsed_cli.socket_path = args.next() orelse return error.MissingArgValue;
                    parsed_cli.socket_explicit = true;
                } else {
                    std.log.err("unknown status argument: {s}", .{sub_arg});
                    return error.UnknownArgument;
                }
            }
        } else if (std.mem.eql(u8, arg, "devices")) {
            parsed_cli.devices_cmd = true;
            while (args.next()) |sub_arg| {
                if (std.mem.eql(u8, sub_arg, "--socket")) {
                    parsed_cli.socket_path = args.next() orelse return error.MissingArgValue;
                    parsed_cli.socket_explicit = true;
                } else {
                    std.log.err("unknown devices argument: {s}", .{sub_arg});
                    return error.UnknownArgument;
                }
            }
        } else {
            std.log.err("unknown argument: {s}", .{arg});
            return error.UnknownArgument;
        }
    }
    return parsed_cli;
}

fn printHelp() void {
    const help =
        \\Usage: padctl [options]
        \\       padctl install [--prefix /usr] [--destdir ""]
        \\       padctl uninstall [--prefix /usr] [--destdir ""]
        \\       padctl scan [--config-dir <dir>]
        \\       padctl list-mappings [--config-dir <dir>]
        \\       padctl reload [--pid <pid>]
        \\       padctl switch <name> [--device <id>] [--socket <path>]
        \\       padctl status [--socket <path>]
        \\       padctl devices [--socket <path>]
        \\
        \\Subcommands:
        \\  install               Install binary, service, udev rules, and device configs
        \\    --prefix <dir>      Installation prefix (default: /usr)
        \\    --destdir <dir>     Staging root for package builds (default: "")
        \\  uninstall             Remove installed files, stop and disable service
        \\    --prefix <dir>      Installation prefix (default: /usr)
        \\    --destdir <dir>     Staging root (default: "")
        \\  scan                  List connected HID devices and config match status
        \\    --config-dir <dir>  Search for device configs here (default: XDG paths)
        \\  list-mappings         List discovered mapping profiles from XDG paths
        \\    --config-dir <dir>  Also show device-specific mappings from this directory
        \\  reload [--pid <pid>]  Send SIGHUP to running padctl daemon
        \\  switch <name>         Switch active mapping profile (name must come before options)
        \\    --device <id>       Apply only to specific device
        \\    --socket <path>     Socket path (default: /run/padctl/padctl.sock)
        \\  status                Show daemon status (current mapping, devices)
        \\    --socket <path>     Socket path (default: /run/padctl/padctl.sock)
        \\  devices               List connected devices via daemon
        \\    --socket <path>     Socket path (default: /run/padctl/padctl.sock)
        \\  config list           List XDG-layer device and mapping configs
        \\  config init           Interactively create a mapping in ~/.config/padctl/mappings/
        \\    --device <name>     Skip device selection prompt
        \\    --preset <name>     Skip output preset prompt (xbox-360/xbox-elite2/dualsense/switch-pro)
        \\  config edit [name]    Open mapping in $VISUAL/$EDITOR; validate on exit
        \\  config test           Live input preview (Ctrl-C to exit)
        \\    --config <path>     Device config to identify input
        \\    --mapping <path>    Mapping to apply for display
        \\
        \\Options:
        \\  --config <path>     Device config TOML file (required to run)
        \\  --config-dir <dir>  Glob *.toml in dir; discover all matching devices
        \\  --mapping <path>    Mapping config TOML file (optional)
        \\  --validate <path>   Validate device config and exit (returns 0/1)
        \\  --pid-file <path>   Write PID to file on start, remove on exit
        \\  --doc-gen           Generate Markdown device reference from --config path(s)
        \\  --output <dir>      Output directory for --doc-gen (default: docs/src/devices)
        \\  --help, -h          Show this help
        \\  --version, -V       Show version
        \\
    ;
    _ = std.posix.write(std.posix.STDOUT_FILENO, help) catch 0;
}

fn writePidFile(path: []const u8) void {
    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}\n", .{std.os.linux.getpid()}) catch return;
    var f = std.fs.createFileAbsolute(path, .{ .truncate = true }) catch return;
    defer f.close();
    _ = f.writeAll(s) catch {};
}

fn deletePidFile(path: []const u8) void {
    std.fs.deleteFileAbsolute(path) catch {};
}

fn runFromDir(allocator: std.mem.Allocator, dir_path: []const u8, pid_file: ?[]const u8) void {
    var sup = Supervisor.init(allocator) catch |err| {
        std.log.err("failed to init supervisor: {}", .{err});
        std.process.exit(1);
    };
    defer sup.deinit();

    sup.startFromDir(dir_path) catch |err| {
        std.log.err("failed to scan config dir '{s}': {}", .{ dir_path, err });
        std.process.exit(1);
    };

    if (sup.managed.items.len == 0) {
        std.log.info("no devices found in '{s}', waiting for hot-plug", .{dir_path});
    }

    if (pid_file) |pf| writePidFile(pf);
    defer if (pid_file) |pf| deletePidFile(pf);

    sup.serve(dir_path);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parsed = parseArgs(allocator) catch |err| {
        std.log.err("argument error: {}", .{err});
        printHelp();
        std.process.exit(1);
    };
    defer parsed.deinit();

    var sock_path_buf: [256]u8 = undefined;
    if (!parsed.socket_explicit) {
        parsed.socket_path = cli.socket_client.resolveSocketPath(&sock_path_buf);
    }

    // install subcommand
    if (parsed.install_opts) |opts| {
        cli.install.run(allocator, opts) catch |err| {
            std.log.err("install failed: {}", .{err});
            std.process.exit(1);
        };
        std.process.exit(0);
    }

    // uninstall subcommand
    if (parsed.uninstall_opts) |opts| {
        cli.install.uninstall(allocator, opts) catch |err| {
            std.log.err("uninstall failed: {}", .{err});
            std.process.exit(1);
        };
        std.process.exit(0);
    }

    // setup-test-udev: write udev rule for UHID test devices and reload
    if (parsed.setup_test_udev) {
        cli.install.setupTestUdev();
        std.process.exit(0);
    }

    // scan subcommand
    if (parsed.scan) {
        if (parsed.scan_config_dir) |dir| {
            const dirs = [_][]const u8{dir};
            cli.scan.run(allocator, &dirs, stdout_writer) catch |err| {
                std.log.err("scan failed: {}", .{err});
                std.process.exit(1);
            };
        } else {
            const dirs = config.paths.resolveDeviceConfigDirs(allocator) catch |err| {
                std.log.err("failed to resolve XDG config dirs: {}", .{err});
                std.process.exit(1);
            };
            defer config.paths.freeConfigDirs(allocator, dirs);
            cli.scan.run(allocator, dirs, stdout_writer) catch |err| {
                std.log.err("scan failed: {}", .{err});
                std.process.exit(1);
            };
        }
        std.process.exit(0);
    }

    // list-mappings subcommand
    if (parsed.list_mappings) {
        cli.list_mappings.run(allocator, parsed.list_mappings_config_dir, stdout_writer) catch |err| {
            std.log.err("list-mappings failed: {}", .{err});
            std.process.exit(1);
        };
        std.process.exit(0);
    }

    // reload subcommand
    if (parsed.reload) {
        cli.reload.run(allocator, parsed.reload_pid) catch |err| {
            std.log.err("reload failed: {}", .{err});
            std.process.exit(1);
        };
        std.process.exit(0);
    }

    // switch subcommand
    if (parsed.switch_cmd) |sw| {
        const rc = cli.switch_mapping.run(sw.name, sw.device_id, parsed.socket_path, stdout_writer, stderr_writer);
        std.process.exit(rc);
    }

    // status subcommand
    if (parsed.status_cmd) {
        const rc = cli.status.run(parsed.socket_path, stdout_writer, stderr_writer);
        std.process.exit(rc);
    }

    // devices subcommand
    if (parsed.devices_cmd) {
        const rc = cli.devices.run(parsed.socket_path, stdout_writer, stderr_writer);
        std.process.exit(rc);
    }

    // config subcommand group
    if (parsed.config_cmd) |cmd| {
        switch (cmd) {
            .list => {
                cli.config.list.run(allocator, stdout_writer) catch |err| {
                    std.log.err("config list failed: {}", .{err});
                    std.process.exit(1);
                };
            },
            .init => |opts| {
                cli.config.init.run(allocator, opts.device, opts.preset) catch |err| {
                    std.log.err("config init failed: {}", .{err});
                    std.process.exit(1);
                };
            },
            .edit => |name| {
                cli.config.edit.run(allocator, name) catch |err| {
                    std.log.err("config edit failed: {}", .{err});
                    std.process.exit(1);
                };
            },
            .@"test" => |opts| {
                cli.config.@"test".run(allocator, opts.config, opts.mapping, stdout_writer) catch |err| {
                    std.log.err("config test failed: {}", .{err});
                    std.process.exit(1);
                };
            },
        }
        std.process.exit(0);
    }

    // --validate mode: validate one or more files and exit
    // Exit 0 = all valid, 1 = validation errors, 2 = file not found / parse error
    if (parsed.validate_files.items.len > 0) {
        var any_error = false;
        var any_parse_fail = false;
        for (parsed.validate_files.items) |path| {
            const errors = tools.validate.validateFile(path, allocator) catch |err| {
                std.log.err("{s}: {}", .{ path, err });
                any_parse_fail = true;
                continue;
            };
            defer tools.validate.freeErrors(errors, allocator);
            for (errors) |e| {
                std.log.err("{s}: {s}", .{ e.file, e.message });
                if (std.mem.indexOf(u8, e.message, "parse/schema error") != null) {
                    any_parse_fail = true;
                } else {
                    any_error = true;
                }
            }
            if (errors.len == 0) {
                _ = std.posix.write(std.posix.STDOUT_FILENO, path) catch 0;
                _ = std.posix.write(std.posix.STDOUT_FILENO, ": OK\n") catch 0;
            }
        }
        if (any_parse_fail) std.process.exit(2);
        if (any_error) std.process.exit(1);
        std.process.exit(0);
    }

    // --doc-gen mode: generate Markdown reference page(s) and exit
    if (parsed.doc_gen) {
        const path = parsed.config_path orelse {
            std.log.err("--doc-gen requires --config <path>", .{});
            std.process.exit(1);
        };
        const inputs = &[_][]const u8{path};
        tools.docgen.runDocGen(allocator, inputs, parsed.doc_gen_output) catch |err| {
            std.log.err("doc-gen failed: {}", .{err});
            std.process.exit(1);
        };
        std.process.exit(0);
    }

    // --config-dir mode: glob *.toml, discover all devices, dedup by physical path, hot-reload on SIGHUP
    if (parsed.config_dir) |dir_path| {
        runFromDir(allocator, dir_path, parsed.pid_file);
        return;
    }

    // Bare invocation: XDG three-layer search
    if (parsed.config_path == null) {
        const dirs = config.paths.resolveDeviceConfigDirs(allocator) catch |err| {
            std.log.err("failed to resolve XDG config dirs: {}", .{err});
            std.process.exit(1);
        };
        defer config.paths.freeConfigDirs(allocator, dirs);

        for (dirs) |dir| {
            std.fs.accessAbsolute(dir, .{}) catch continue;
            runFromDir(allocator, dir, parsed.pid_file);
            return;
        }

        std.log.err("no device configs found in XDG paths; use --config or --config-dir", .{});
        printHelp();
        std.process.exit(1);
    }

    const config_path = parsed.config_path.?;

    const device_cfg = config.device.parseFile(allocator, config_path) catch |err| {
        std.log.err("failed to load config '{s}': {}", .{ config_path, err });
        std.process.exit(1);
    };
    defer device_cfg.deinit();

    var inst = DeviceInstance.init(allocator, &device_cfg.value) catch |err| {
        std.log.err("failed to init device: {}", .{err});
        std.process.exit(1);
    };
    defer inst.deinit();

    try inst.run();
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("test/bugfix_regression_test.zig");
    _ = @import("test/properties/config_props.zig");
    _ = @import("test/properties/contract_props.zig");
    _ = @import("test/properties/device_specific_props.zig");
    _ = @import("test/properties/drt_props.zig");
    _ = @import("test/properties/e2e_pipeline_props.zig");
    _ = @import("test/properties/generative_mapper_props.zig");
    _ = @import("test/properties/hidraw_dedup_props.zig");
    _ = @import("test/properties/interpreter_props.zig");
    _ = @import("test/properties/ipc_props.zig");
    _ = @import("test/properties/mapper_props.zig");
    _ = @import("test/properties/metamorphic_props.zig");
    _ = @import("test/properties/negative_corpus_props.zig");
    _ = @import("test/properties/regression_corpus_props.zig");
    _ = @import("test/properties/render_props.zig");
    _ = @import("test/properties/state_props.zig");
    _ = @import("test/properties/supervisor_sm_props.zig");
    _ = @import("test/properties/transform_props.zig");
    _ = @import("test/gen/config_gen.zig");
    _ = @import("test/gen/mapper_oracle.zig");
    _ = @import("test/gen/sequence_gen.zig");
    _ = @import("test/gen/shrink.zig");
    _ = @import("test/gen/transition_id.zig");
}

// --- CLI tests ---

const testing = std.testing;

test "main: parseHexBytes via init_seq" {
    // Smoke-test that init_seq is reachable from main
    const allocator = testing.allocator;
    const bytes = try init_seq.parseHexBytes(allocator, "5aa5 01");
    defer allocator.free(bytes);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x5a, 0xa5, 0x01 }, bytes);
}

// --- T9c Layer 1 integration tests ---

const MockOutput = testing_support.mock_output.MockOutput;

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

test "main: known frame dispatched to output" {
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

    var loop = try event_loop.EventLoop.initManaged();
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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.out.outputDevice(), .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expect(out.diffs.items.len >= 1);
    try testing.expectEqual(@as(?i16, 750), out.diffs.items[0].ax);
}

test "main: unknown report does not call output.emit" {
    const allocator = testing.allocator;

    const parsed = try config.device.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Wrong magic byte — no report match
    const frame = [_]u8{ 0xFF, 0x00, 0x00 };

    var mock = try testing_support.mock_device_io.MockDeviceIO.init(allocator, &.{&frame});
    defer mock.deinit();
    const dev = mock.deviceIO();

    var loop = try event_loop.EventLoop.initManaged();
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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.out.outputDevice(), .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    std.Thread.sleep(10 * std.time.ns_per_ms);
    loop.stop();
    thread.join();

    try testing.expectEqual(@as(usize, 0), out.diffs.items.len);
}

test "main: signalfd stop — no fd leak" {
    const allocator = testing.allocator;

    const parsed = try config.device.parseString(allocator, pipeline_toml);
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var mock = try testing_support.mock_device_io.MockDeviceIO.init(allocator, &.{});
    defer mock.deinit();
    const dev = mock.deviceIO();

    var loop = try event_loop.EventLoop.initManaged();
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
            try c.loop.run(.{ .devices = c.devs, .interpreter = c.interp, .output = c.out.outputDevice(), .poll_timeout_ms = 100 });
        }
    };
    const thread = try std.Thread.spawn(.{}, T.run, .{&ctx});
    // Stop immediately without any frames
    std.Thread.sleep(5 * std.time.ns_per_ms);
    loop.stop();
    thread.join();
    // If we reach here without crash, fds are properly managed (GPA would catch leaks)
    try testing.expectEqual(@as(usize, 0), out.diffs.items.len);
}
