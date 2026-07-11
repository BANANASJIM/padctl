const std = @import("std");
const toml = @import("toml");
const toml_lint = @import("toml_lint.zig");
const state = @import("../core/state.zig");
const presets = @import("presets.zig");
const input_codes = @import("input_codes.zig");

pub const ButtonId = state.ButtonId;

// Largest report a read path can deliver. The hidraw read buffer
// (src/event_loop.zig — `var buf: [512]u8`) caps HID reports at 512 bytes; the
// libusb ring slot (src/io/usbraw.zig — SLOT_SIZE = 64) truncates vendor reads
// to 64. A report.size above MAX_REPORT_SIZE can never be filled, so the
// interpreter (src/core/interpreter.zig — `raw.len < cr.src.size` guard) drops
// every report with no diagnostic. Reject at validate time instead.
pub const MAX_REPORT_SIZE: i64 = 512;
pub const LIBUSB_SLOT_SIZE: i64 = 64;

pub const InterfaceConfig = struct {
    id: i64,
    class: []const u8,
    ep_in: ?i64 = null,
    ep_out: ?i64 = null,
};

pub const InitConfig = struct {
    commands: ?[]const []const u8 = null,
    response_prefix: ?[]const i64 = null,
    enable: ?[]const u8 = null,
    disable: ?[]const u8 = null,
    require_response: bool = false,
    interface: ?i64 = null,
    report_size: ?i64 = null,
    /// HID feature report to send via HIDIOCSFEATURE immediately after commands.
    /// Encoded as a list of byte values (0–255); report ID is byte[0].
    feature_report: ?[]const i64 = null,
};

pub const DeviceInfo = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    interface: []const InterfaceConfig,
    init: ?InitConfig = null,
    mode: ?[]const u8 = null,
    block_kernel_drivers: ?[]const []const u8 = null,
};

pub const MatchConfig = struct {
    offset: i64,
    expect: []const i64,
};

pub const FieldConfig = struct {
    offset: ?i64 = null,
    type: ?[]const u8 = null,
    bits: ?[]const i64 = null,
    transform: ?[]const u8 = null,
};

pub const ButtonGroupSource = struct {
    offset: i64,
    size: i64,
};

pub const ButtonGroupConfig = struct {
    source: ButtonGroupSource,
    map: toml.HashMap(i64),
};

pub const ChecksumExpect = struct {
    offset: i64,
    type: []const u8,
};

pub const ChecksumConfig = struct {
    algo: []const u8,
    range: []const i64,
    expect: ChecksumExpect,
    seed: ?i64 = null,
};

pub const ReportConfig = struct {
    name: []const u8,
    interface: i64,
    size: i64,
    match: ?MatchConfig = null,
    fields: ?toml.HashMap(FieldConfig) = null,
    button_group: ?ButtonGroupConfig = null,
    checksum: ?ChecksumConfig = null,
};

pub const CommandChecksumConfig = struct {
    algo: []const u8,
    range: []const i64,
    offset: i64,
    seed: ?i64 = null,
};

pub const CommandConfig = struct {
    interface: i64,
    template: []const u8,
    checksum: ?CommandChecksumConfig = null,
};

pub const AxisConfig = struct {
    code: []const u8,
    min: i64,
    max: i64,
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
};

pub const DpadOutputConfig = struct {
    type: []const u8, // "hat" | "buttons"
};

pub const FfConfig = struct {
    type: []const u8, // "rumble"
    max_effects: ?i64 = null,
    auto_stop: bool = true,
};

pub const AuxConfig = struct {
    type: ?[]const u8 = null, // "mouse" | "keyboard"
    name: ?[]const u8 = null,
    keyboard: ?bool = null,
    buttons: ?toml.HashMap([]const u8) = null,
};

pub const ImuConfig = struct {
    // Default is "uhid" so bare `ImuConfig{}` literals are validator-legal and
    // a TOML `[output.imu]` block without an explicit `backend` key picks the
    // only accepted value (validate() rejects "uinput").
    backend: []const u8 = "uhid",
    name: ?[]const u8 = null,
    vid: ?i64 = null,
    pid: ?i64 = null,
    accel_range: ?[2]i64 = null,
    gyro_range: ?[2]i64 = null,
};

// Force-feedback config. Extends the legacy fields (type, max_effects,
// auto_stop) with backend/kind/clone_vid_pid for UHID PID passthrough.
pub const ForceFeedbackConfig = struct {
    // Legacy rumble fields — used by uinput path callers.
    type: []const u8 = "rumble",
    max_effects: ?i64 = null,
    // When true padctl runs a userspace rumble auto-stop scheduler.
    // Set false for firmware that auto-stops internally.
    auto_stop: bool = true,
    // UHID PID passthrough fields.
    backend: []const u8 = "uinput", // "uinput" | "uhid"
    kind: []const u8 = "rumble", // "rumble" | "pid"
    clone_vid_pid: bool = false,
};

pub const TouchpadConfig = struct {
    name: ?[]const u8 = null,
    x_min: i64 = 0,
    x_max: i64 = 0,
    y_min: i64 = 0,
    y_max: i64 = 0,
    max_slots: ?i64 = null,
};

pub const TouchSynthesisConfig = struct {
    left_button: []const u8,
    right_button: []const u8,
    left_x: i64,
    right_x: i64,
    y: i64,
    click: bool,
};

pub const MappingEntry = struct {
    event: []const u8,
    range: ?[]const i64 = null,
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
};

pub const OutputConfig = struct {
    emulate: ?[]const u8 = null,
    default_profile: ?[]const u8 = null,
    backend: []const u8 = "auto", // "auto" | "uinput" | "uhid"
    protocol: []const u8 = "generic", // "generic" | "dualsense-edge-usb"
    name: ?[]const u8 = null,
    vid: ?i64 = null,
    pid: ?i64 = null,
    axes: ?toml.HashMap(AxisConfig) = null,
    buttons: ?toml.HashMap([]const u8) = null,
    dpad: ?DpadOutputConfig = null,
    force_feedback: ?ForceFeedbackConfig = null,
    aux: ?AuxConfig = null,
    touchpad: ?TouchpadConfig = null,
    mapping: ?toml.HashMap(MappingEntry) = null,
    imu: ?ImuConfig = null,
    touch_synthesis: ?TouchSynthesisConfig = null,
    profiles: ?toml.HashMap(OutputProfileConfig) = null,
};

pub const OutputProfileConfig = struct {
    emulate: ?[]const u8 = null,
    // Null means inherit the root output. Concrete defaults are applied only
    // after overlay, where OutputConfig supplies auto/generic.
    backend: ?[]const u8 = null, // "auto" | "uinput" | "uhid"
    protocol: ?[]const u8 = null, // "generic" | "dualsense-edge-usb"
    name: ?[]const u8 = null,
    vid: ?i64 = null,
    pid: ?i64 = null,
    axes: ?toml.HashMap(AxisConfig) = null,
    buttons: ?toml.HashMap([]const u8) = null,
    dpad: ?DpadOutputConfig = null,
    force_feedback: ?ForceFeedbackConfig = null,
    aux: ?AuxConfig = null,
    touchpad: ?TouchpadConfig = null,
    mapping: ?toml.HashMap(MappingEntry) = null,
    imu: ?ImuConfig = null,
    touch_synthesis: ?TouchSynthesisConfig = null,
};

pub const WasmOverridesConfig = struct {
    process_report: ?bool = null,
};

pub const WasmConfig = struct {
    plugin: []const u8,
    overrides: ?WasmOverridesConfig = null,
};

pub const DeviceConfig = struct {
    device: DeviceInfo,
    report: []const ReportConfig,
    commands: ?toml.HashMap(CommandConfig) = null,
    output: ?OutputConfig = null,
    wasm: ?WasmConfig = null,
};

fn outputFromProfile(profile: OutputProfileConfig) OutputConfig {
    return .{
        .emulate = profile.emulate,
        .backend = profile.backend orelse "auto",
        .protocol = profile.protocol orelse "generic",
        .name = profile.name,
        .vid = profile.vid,
        .pid = profile.pid,
        .axes = profile.axes,
        .buttons = profile.buttons,
        .dpad = profile.dpad,
        .force_feedback = profile.force_feedback,
        .aux = profile.aux,
        .touchpad = profile.touchpad,
        .mapping = profile.mapping,
        .imu = profile.imu,
        .touch_synthesis = profile.touch_synthesis,
    };
}

fn profileFromOutput(out: OutputConfig) OutputProfileConfig {
    return .{
        .emulate = out.emulate,
        .backend = out.backend,
        .protocol = out.protocol,
        .name = out.name,
        .vid = out.vid,
        .pid = out.pid,
        .axes = out.axes,
        .buttons = out.buttons,
        .dpad = out.dpad,
        .force_feedback = out.force_feedback,
        .aux = out.aux,
        .touchpad = out.touchpad,
        .mapping = out.mapping,
        .imu = out.imu,
        .touch_synthesis = out.touch_synthesis,
    };
}

fn overlayOutputProfile(base: OutputConfig, profile: OutputProfileConfig) OutputConfig {
    var out = base;
    if (profile.emulate) |v| out.emulate = v;
    if (profile.backend) |v| out.backend = v;
    if (profile.protocol) |v| out.protocol = v;
    if (profile.name) |v| out.name = v;
    if (profile.vid) |v| out.vid = v;
    if (profile.pid) |v| out.pid = v;
    if (profile.axes) |v| out.axes = v;
    if (profile.buttons) |v| out.buttons = v;
    if (profile.dpad) |v| out.dpad = v;
    if (profile.force_feedback) |v| out.force_feedback = v;
    if (profile.aux) |v| out.aux = v;
    if (profile.touchpad) |v| out.touchpad = v;
    if (profile.mapping) |v| out.mapping = v;
    if (profile.imu) |v| out.imu = v;
    if (profile.touch_synthesis) |v| out.touch_synthesis = v;
    out.default_profile = null;
    out.profiles = null;
    return out;
}

pub fn selectOutputProfile(cfg: *DeviceConfig, profile_name: []const u8) bool {
    var out = cfg.output orelse return false;
    if (out.default_profile) |default_profile| {
        if (std.mem.eql(u8, default_profile, profile_name)) return true;
    }
    const profiles = out.profiles orelse return false;
    const profile = profiles.map.get(profile_name) orelse return false;
    out = overlayOutputProfile(out, profile);
    cfg.output = out;
    return true;
}

const valid_transforms = [_][]const u8{ "negate", "abs", "scale", "clamp", "deadzone" };

fn isValidTransform(t: []const u8) bool {
    const name = std.mem.trim(u8, t, " \t");
    const paren = std.mem.indexOfScalar(u8, name, '(');
    const base = if (paren) |p| name[0..p] else name;
    const base_trimmed = std.mem.trim(u8, base, " \t");
    for (valid_transforms) |v| {
        if (std.mem.eql(u8, base_trimmed, v)) return true;
    }
    return false;
}

const max_transforms = state.MAX_TRANSFORMS;

fn isValidTransformChain(chain: []const u8) bool {
    var pos: usize = 0;
    var depth: usize = 0;
    var seg_start: usize = 0;
    var count: usize = 0;
    while (pos < chain.len) : (pos += 1) {
        switch (chain[pos]) {
            '(' => depth += 1,
            ')' => if (depth > 0) {
                depth -= 1;
            },
            ',' => if (depth == 0) {
                if (!isValidTransform(chain[seg_start..pos])) return false;
                count += 1;
                if (count > max_transforms) return false;
                seg_start = pos + 1;
            },
            else => {},
        }
    }
    count += 1;
    if (count > max_transforms) return false;
    return isValidTransform(chain[seg_start..]);
}

fn fieldTypeSize(type_str: []const u8) ?i64 {
    if (std.mem.eql(u8, type_str, "u8") or std.mem.eql(u8, type_str, "i8")) return 1;
    if (std.mem.eql(u8, type_str, "u16le") or std.mem.eql(u8, type_str, "i16le") or
        std.mem.eql(u8, type_str, "u16be") or std.mem.eql(u8, type_str, "i16be")) return 2;
    if (std.mem.eql(u8, type_str, "u32le") or std.mem.eql(u8, type_str, "i32le") or
        std.mem.eql(u8, type_str, "u32be") or std.mem.eql(u8, type_str, "i32be")) return 4;
    return null;
}

pub fn isSuppressClass(class: []const u8) bool {
    return std.mem.eql(u8, class, "suppress");
}

/// True when any interface is claimed via libusb (vendor or suppress class),
/// which needs raw USB device-node access rather than a hidraw node.
pub fn usesLibusb(cfg: *const DeviceConfig) bool {
    for (cfg.device.interface) |iface| {
        if (std.mem.eql(u8, iface.class, "vendor") or isSuppressClass(iface.class)) return true;
    }
    return false;
}

fn isSuppressInterface(cfg: *const DeviceConfig, iface_id: i64) bool {
    for (cfg.device.interface) |iface| {
        if (iface.id == iface_id) return isSuppressClass(iface.class);
    }
    return false;
}

fn interfaceExists(cfg: *const DeviceConfig, iface_id: i64) bool {
    for (cfg.device.interface) |iface| {
        if (iface.id == iface_id) return true;
    }
    return false;
}

/// Number of interfaces opened into the devices[] array (everything except
/// suppress-class interfaces). Suppress interfaces are claimed separately and
/// consume no DeviceIO slot.
pub fn openedInterfaceCount(cfg: *const DeviceConfig) usize {
    var n: usize = 0;
    for (cfg.device.interface) |iface| {
        if (!isSuppressClass(iface.class)) n += 1;
    }
    return n;
}

/// Map a USB interface id to its index in the devices[] array, counting only
/// non-suppress interfaces. Returns null when the id is unknown or suppressed.
pub fn deviceIndexForInterface(cfg: *const DeviceConfig, iface_id: i64) ?usize {
    var idx: usize = 0;
    for (cfg.device.interface) |iface| {
        if (isSuppressClass(iface.class)) continue;
        if (iface.id == iface_id) return idx;
        idx += 1;
    }
    return null;
}

/// Inverse of deviceIndexForInterface: map a devices[] index back to its
/// InterfaceConfig, skipping suppress interfaces. Returns null when out of range.
pub fn interfaceForDeviceIndex(cfg: *const DeviceConfig, dev_idx: usize) ?*const InterfaceConfig {
    var idx: usize = 0;
    for (cfg.device.interface) |*iface| {
        if (isSuppressClass(iface.class)) continue;
        if (idx == dev_idx) return iface;
        idx += 1;
    }
    return null;
}

pub fn validate(cfg: *const DeviceConfig) !void {
    for (cfg.device.interface) |iface| {
        const is_hid = std.mem.eql(u8, iface.class, "hid");
        const is_vendor = std.mem.eql(u8, iface.class, "vendor");
        const is_suppress = std.mem.eql(u8, iface.class, "suppress");
        if (!is_hid and !is_vendor and !is_suppress) return error.InvalidConfig;
        if (is_suppress and (iface.ep_in != null or iface.ep_out != null))
            return error.InvalidConfig;
    }

    // An all-suppress config opens no read fd, so it can never be observed
    // for liveness; require at least one readable (hid/vendor) interface.
    if (openedInterfaceCount(cfg) == 0) return error.InvalidConfig;

    // A suppress interface is claimed only to evict the kernel driver; it is
    // never read or written, so no report/command/init may reference it. Every
    // referenced interface id must also exist in [[device.interface]].
    for (cfg.report) |report| {
        if (!interfaceExists(cfg, report.interface)) return error.InvalidConfig;
        if (isSuppressInterface(cfg, report.interface)) return error.InvalidConfig;
    }
    if (cfg.commands) |cmds| {
        var it = cmds.map.iterator();
        while (it.next()) |entry| {
            if (!interfaceExists(cfg, entry.value_ptr.interface)) return error.InvalidConfig;
            if (isSuppressInterface(cfg, entry.value_ptr.interface)) return error.InvalidConfig;
        }
    }
    if (cfg.device.init) |init_cfg| {
        if (init_cfg.interface) |iface_id| {
            if (!interfaceExists(cfg, iface_id)) return error.InvalidConfig;
            if (isSuppressInterface(cfg, iface_id)) return error.InvalidConfig;
        }
    }

    for (cfg.report) |report| {
        if (report.size < 0 or report.size > MAX_REPORT_SIZE) return error.ReportSizeTooLarge;

        if (report.fields) |fields| {
            var seen_buf: [64][]const u8 = undefined;
            var seen_len: usize = 0;
            var it = fields.map.iterator();
            while (it.next()) |entry| {
                const name = entry.key_ptr.*;
                const field = entry.value_ptr.*;

                for (seen_buf[0..seen_len]) |s| {
                    if (std.mem.eql(u8, s, name)) return error.InvalidConfig;
                }
                if (seen_len < seen_buf.len) {
                    seen_buf[seen_len] = name;
                    seen_len += 1;
                }

                if (field.bits) |bits| {
                    // bits mode: mutual exclusivity
                    if (field.offset != null) return error.InvalidConfig;
                    if (field.transform != null) return error.InvalidConfig;
                    if (bits.len != 3) return error.InvalidConfig;
                    if (bits[1] < 0 or bits[1] > 7) return error.InvalidConfig;
                    if (bits[2] < 1 or bits[2] > 32) return error.InvalidConfig;
                    if (bits[0] < 0) return error.InvalidConfig;
                    // bounds check: byte_offset + ceil((start_bit + bit_count) / 8) <= report.size
                    const span = @divTrunc(bits[1] + bits[2] + 7, 8);
                    if (span > 4) return error.InvalidConfig;
                    if (bits[0] + span > report.size) return error.OffsetOutOfBounds;
                    // type must be null, "unsigned", or "signed"
                    if (field.type) |t| {
                        if (!std.mem.eql(u8, t, "unsigned") and !std.mem.eql(u8, t, "signed"))
                            return error.InvalidConfig;
                    }
                } else {
                    // standard mode: both offset and type required
                    const offset = field.offset orelse return error.InvalidConfig;
                    const type_str = field.type orelse return error.InvalidConfig;
                    const sz = fieldTypeSize(type_str) orelse return error.InvalidConfig;
                    if (offset < 0 or offset + sz > report.size) return error.OffsetOutOfBounds;
                }

                if (field.transform) |tr| {
                    if (!isValidTransformChain(tr)) return error.InvalidConfig;
                }
            }
        }

        if (report.button_group) |bg| {
            if (bg.source.offset < 0 or bg.source.offset + bg.source.size > report.size) return error.OffsetOutOfBounds;
            const bg_source_size = bg.source.size;
            const is_generic = if (cfg.device.mode) |m| std.mem.eql(u8, m, "generic") else false;
            var it = bg.map.map.iterator();
            while (it.next()) |entry| {
                if (!is_generic) {
                    const btn_name = entry.key_ptr.*;
                    _ = std.meta.stringToEnum(ButtonId, btn_name) orelse return error.InvalidConfig;
                }
                const bit_val = entry.value_ptr.*;
                if (bit_val < 0 or bit_val >= bg_source_size * 8) return error.InvalidConfig;
            }
        }

        if (report.match) |m| {
            if (m.offset < 0) return error.InvalidConfig;
            for (m.expect) |byte| {
                if (byte < 0 or byte > 255) return error.InvalidConfig;
            }
            if (m.offset + @as(i64, @intCast(m.expect.len)) > report.size) return error.InvalidConfig;
        }

        if (report.checksum) |cs| {
            if (cs.range.len != 2) return error.InvalidConfig;
            if (cs.range[0] < 0 or cs.range[1] > report.size) return error.InvalidConfig;
            if (cs.range[0] >= cs.range[1]) return error.InvalidConfig;
            if (cs.expect.offset < 0) return error.InvalidConfig;
            const expect_end = cs.expect.offset + if (std.mem.eql(u8, cs.algo, "crc32")) @as(i64, 4) else 1;
            if (expect_end > report.size) return error.InvalidConfig;
        }
    }

    // Generic mode validation
    if (cfg.device.mode) |m| {
        if (std.mem.eql(u8, m, "generic")) {
            const out = cfg.output orelse return error.InvalidConfig;
            _ = out.mapping orelse return error.InvalidConfig;
        }
    }

    // feature_report byte-range validation
    if (cfg.device.init) |init_cfg| {
        if (init_cfg.feature_report) |fr| {
            for (fr) |b| if (b < 0 or b > 255) return error.InvalidConfig;
        }
    }

    if (cfg.output) |out| {
        try validateOutputConfig(cfg, &out);
        if (out.profiles) |profiles| {
            var it = profiles.map.iterator();
            while (it.next()) |entry| {
                var profile_out = overlayOutputProfile(out, entry.value_ptr.*);
                try validateOutputConfig(cfg, &profile_out);
            }
        }
    }
}

fn validateMappingEntries(mapping: toml.HashMap(MappingEntry)) !void {
    var it = mapping.map.iterator();
    while (it.next()) |entry| {
        const me = entry.value_ptr.*;
        _ = input_codes.resolveEventCode(me.event) catch return error.InvalidConfig;
        // ABS events require range
        if (std.mem.startsWith(u8, me.event, "ABS_")) {
            const range = me.range orelse return error.InvalidConfig;
            if (range.len != 2) return error.InvalidConfig;
        }
    }
}

const NativeAxisRequirement = struct {
    name: []const u8,
    code: []const u8,
};

const native_axis_requirements = [_]NativeAxisRequirement{
    .{ .name = "left_x", .code = "ABS_X" },
    .{ .name = "left_y", .code = "ABS_Y" },
    .{ .name = "right_x", .code = "ABS_RX" },
    .{ .name = "right_y", .code = "ABS_RY" },
    .{ .name = "lt", .code = "ABS_Z" },
    .{ .name = "rt", .code = "ABS_RZ" },
};

const NativeButtonRequirement = struct {
    name: []const u8,
    code: []const u8,
};

// The logical DualSense Edge table materialized by the dualsense-edge preset.
// Native profiles may add source-only buttons such as C/Z, but may not omit or
// retarget any of the protocol's required logical controls.
const native_button_requirements = [_]NativeButtonRequirement{
    .{ .name = "A", .code = "BTN_SOUTH" },
    .{ .name = "B", .code = "BTN_EAST" },
    .{ .name = "X", .code = "BTN_WEST" },
    .{ .name = "Y", .code = "BTN_NORTH" },
    .{ .name = "LB", .code = "BTN_TL" },
    .{ .name = "RB", .code = "BTN_TR" },
    .{ .name = "Select", .code = "BTN_SELECT" },
    .{ .name = "Start", .code = "BTN_START" },
    .{ .name = "Home", .code = "BTN_MODE" },
    .{ .name = "LS", .code = "BTN_THUMBL" },
    .{ .name = "RS", .code = "BTN_THUMBR" },
    .{ .name = "M1", .code = "BTN_TRIGGER_HAPPY1" },
    .{ .name = "M2", .code = "BTN_TRIGGER_HAPPY2" },
    .{ .name = "M3", .code = "BTN_TRIGGER_HAPPY3" },
    .{ .name = "M4", .code = "BTN_TRIGGER_HAPPY4" },
    .{ .name = "TouchPad", .code = "BTN_TOUCH" },
    .{ .name = "Mic", .code = "BTN_MISC" },
};

fn validateNativeAxes(axes: ?toml.HashMap(AxisConfig)) !void {
    const native_axes = axes orelse return error.InvalidConfig;
    if (native_axes.map.count() != native_axis_requirements.len) return error.InvalidConfig;

    for (native_axis_requirements) |required| {
        const axis = native_axes.map.get(required.name) orelse return error.InvalidConfig;
        if (!std.mem.eql(u8, axis.code, required.code)) return error.InvalidConfig;
        if (axis.min != 0 or axis.max != 255) return error.InvalidConfig;
    }
}

fn validateNativeButtons(buttons: ?toml.HashMap([]const u8)) !void {
    const native_buttons = buttons orelse return error.InvalidConfig;
    for (native_button_requirements) |required| {
        const code = native_buttons.map.get(required.name) orelse return error.InvalidConfig;
        if (!std.mem.eql(u8, code, required.code)) return error.InvalidConfig;
    }
}

fn validateTouchSynthesis(touch: TouchSynthesisConfig) !void {
    _ = std.meta.stringToEnum(ButtonId, touch.left_button) orelse return error.InvalidConfig;
    _ = std.meta.stringToEnum(ButtonId, touch.right_button) orelse return error.InvalidConfig;
    if (touch.left_x < 0 or touch.left_x > 1919) return error.InvalidConfig;
    if (touch.right_x < 0 or touch.right_x > 1919) return error.InvalidConfig;
    if (touch.y < 0 or touch.y > 1079) return error.InvalidConfig;
}

fn validateOutputConfig(cfg: *const DeviceConfig, out: *const OutputConfig) !void {
    if (cfg.device.mode) |m| {
        if (std.mem.eql(u8, m, "generic")) {
            if (out.mapping == null) return error.InvalidConfig;
            // Generic source-mode owns the GenericUinput pipeline. It cannot
            // also request a fixed native UHID wire personality; reject the
            // conflict instead of silently discarding final discriminators.
            if (std.mem.eql(u8, out.protocol, "dualsense-edge-usb")) return error.InvalidConfig;
        }
    }

    if (out.mapping) |mapping| try validateMappingEntries(mapping);

    const backend_auto = std.mem.eql(u8, out.backend, "auto");
    const backend_uinput = std.mem.eql(u8, out.backend, "uinput");
    const backend_uhid = std.mem.eql(u8, out.backend, "uhid");
    const protocol_generic = std.mem.eql(u8, out.protocol, "generic");
    const protocol_edge = std.mem.eql(u8, out.protocol, "dualsense-edge-usb");

    if (!backend_auto and !backend_uinput and !backend_uhid) return error.InvalidConfig;
    if (!protocol_generic and !protocol_edge) return error.InvalidConfig;
    if (protocol_edge and !backend_uhid) return error.InvalidConfig;

    if (out.touch_synthesis) |touch| {
        if (!protocol_edge) return error.InvalidConfig;
        try validateTouchSynthesis(touch);
    }

    if (protocol_edge) {
        if (out.vid != 0x054c or out.pid != 0x0df2) return error.InvalidConfig;
        const name = out.name orelse return error.InvalidConfig;
        if (name.len == 0) return error.InvalidConfig;
        // Edge carries accel + gyro in its one native input report. A
        // companion IMU card would violate both the wire personality and the
        // single-UHID identity contract.
        if (out.imu != null) return error.InvalidConfig;
        _ = out.touch_synthesis orelse return error.InvalidConfig;
        const ffb = out.force_feedback orelse return error.InvalidConfig;
        if (!std.mem.eql(u8, ffb.type, "rumble")) return error.InvalidConfig;
        try validateNativeButtons(out.buttons);
        try validateNativeAxes(out.axes);
    }

    // IMU backend validation: uinput's EVIOCGUNIQ always returns -ENOENT,
    // so SDL's uniq-based pairing fails. Only "uhid" is legal when
    // [output.imu] is declared; unknown strings fail closed.
    if (out.imu) |imu| {
        if (!std.mem.eql(u8, imu.backend, "uhid")) return error.InvalidConfig;
        // An explicit root uinput discriminator cannot expose the companion
        // UHID card. Reject instead of silently dropping configured IMU.
        if (backend_uinput) return error.InvalidConfig;
    }

    // Force feedback backend/kind matrix. Absent force_feedback is always legal.
    if (out.force_feedback) |ffb| {
        const is_uinput = std.mem.eql(u8, ffb.backend, "uinput");
        const is_uhid = std.mem.eql(u8, ffb.backend, "uhid");
        const is_rumble = std.mem.eql(u8, ffb.kind, "rumble");
        const is_pid = std.mem.eql(u8, ffb.kind, "pid");

        if (!is_uinput and !is_uhid) return error.InvalidConfig;
        if (!is_rumble and !is_pid) return error.InvalidConfig;

        if (is_uinput and is_pid) return error.InvalidConfig;
        if (is_uhid and is_rumble) return error.InvalidConfig;

        // uhid+pid requires [output.imu] as the UHID routing gate.
        if (is_uhid and is_pid) {
            if (out.imu == null) return error.InvalidConfig;
        }

        // clone_vid_pid=true is meaningless without a real VID/PID to clone.
        if (ffb.clone_vid_pid) {
            if (cfg.device.vid == 0 or cfg.device.pid == 0) return error.InvalidConfig;
        }
    }
}

// --- schema lint: detect unknown keys in device config tables ---
//
// sam701/zig-toml silently drops unknown fields, so a typo'd device key (e.g.
// `ofset` for `offset`) parses cleanly and is never applied. devices/*.toml is
// the primary contribution surface, so flag stray keys the same way mapping
// configs do. Free-form HashMap sections (report.fields, output.axes/buttons/
// mapping, button_group.map, command/aux button maps) accept arbitrary keys
// and are skipped.
pub const LintFinding = toml_lint.LintFinding;

fn lintAllowlistFor(header: []const u8) ?[]const []const u8 {
    const sf = toml_lint.structFieldNames;
    if (header.len == 0) return null; // device config has no top-level keys

    if (std.mem.eql(u8, header, "device")) return sf(DeviceInfo);
    if (std.mem.eql(u8, header, "device.init")) return sf(InitConfig);
    if (std.mem.eql(u8, header, "device.interface")) return sf(InterfaceConfig);

    if (std.mem.eql(u8, header, "report")) return sf(ReportConfig);
    if (std.mem.eql(u8, header, "report.match")) return sf(MatchConfig);
    if (std.mem.eql(u8, header, "report.button_group")) return sf(ButtonGroupConfig);
    if (std.mem.eql(u8, header, "report.fields")) return null; // free-form
    if (std.mem.eql(u8, header, "report.checksum")) return sf(ChecksumConfig);

    if (std.mem.eql(u8, header, "output")) return sf(OutputConfig);
    if (std.mem.eql(u8, header, "output.dpad")) return sf(DpadOutputConfig);
    if (std.mem.eql(u8, header, "output.force_feedback")) return sf(ForceFeedbackConfig);
    if (std.mem.eql(u8, header, "output.aux")) return sf(AuxConfig);
    if (std.mem.eql(u8, header, "output.touchpad")) return sf(TouchpadConfig);
    if (std.mem.eql(u8, header, "output.touch_synthesis")) return sf(TouchSynthesisConfig);
    if (std.mem.eql(u8, header, "output.imu")) return sf(ImuConfig);
    if (std.mem.eql(u8, header, "output.axes") or
        std.mem.eql(u8, header, "output.buttons") or
        std.mem.eql(u8, header, "output.mapping") or
        std.mem.eql(u8, header, "output.aux.buttons")) return null; // free-form

    if (std.mem.startsWith(u8, header, "output.profiles.")) {
        const rest = header["output.profiles.".len..];
        const dot = std.mem.indexOfScalar(u8, rest, '.');
        if (dot == null) return sf(OutputProfileConfig);
        const child = rest[dot.? + 1 ..];
        if (std.mem.eql(u8, child, "dpad")) return sf(DpadOutputConfig);
        if (std.mem.eql(u8, child, "force_feedback")) return sf(ForceFeedbackConfig);
        if (std.mem.eql(u8, child, "aux")) return sf(AuxConfig);
        if (std.mem.eql(u8, child, "touchpad")) return sf(TouchpadConfig);
        if (std.mem.eql(u8, child, "touch_synthesis")) return sf(TouchSynthesisConfig);
        if (std.mem.eql(u8, child, "imu")) return sf(ImuConfig);
        if (std.mem.eql(u8, child, "axes") or
            std.mem.eql(u8, child, "buttons") or
            std.mem.eql(u8, child, "mapping") or
            std.mem.eql(u8, child, "aux.buttons")) return null; // free-form
    }

    if (std.mem.eql(u8, header, "wasm")) return sf(WasmConfig);
    if (std.mem.eql(u8, header, "wasm.overrides")) return sf(WasmOverridesConfig);

    // commands.<name> -> CommandConfig; commands.<name>.checksum -> CommandChecksumConfig.
    if (std.mem.startsWith(u8, header, "commands.")) {
        if (std.mem.endsWith(u8, header, ".checksum")) return sf(CommandChecksumConfig);
        return sf(CommandConfig);
    }

    return null; // unrecognised header — skip (forward-compat)
}

pub fn lintUnknownFields(allocator: std.mem.Allocator, raw_toml: []const u8) !std.ArrayList(LintFinding) {
    return toml_lint.lint(allocator, raw_toml, lintAllowlistFor);
}

fn warnLintFindings(findings: []const LintFinding) void {
    toml_lint.warnFindings(findings);
}

pub const ParseResult = toml.Parsed(DeviceConfig);

// Parse + apply presets without running validate(). The CLI lint tool needs the
// parsed config to emit detailed diagnostics (e.g. "interface 99 not declared")
// before validate()'s fail-closed error.InvalidConfig masks them. Daemon/CLI
// load paths must use parseString/parseFile, which stay fail-closed.
pub fn parseStringRaw(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var parser = toml.Parser(DeviceConfig).init(allocator);
    defer parser.deinit();
    var result = try parser.parseString(content);
    if (result.value.output) |*out| {
        if (out.emulate) |preset_name| {
            presets.applyPreset(result.arena.allocator(), out, preset_name) catch |err| {
                result.deinit();
                return err;
            };
        }
        if (out.profiles) |*profiles| {
            var it = profiles.map.iterator();
            while (it.next()) |entry| {
                // Applying a preset needs a concrete OutputConfig, but its
                // auto/generic defaults must not turn absent profile fields
                // into explicit overrides during conversion back.
                const backend = entry.value_ptr.backend;
                const protocol = entry.value_ptr.protocol;
                var profile_out = outputFromProfile(entry.value_ptr.*);
                if (profile_out.emulate) |preset_name| {
                    presets.applyPreset(result.arena.allocator(), &profile_out, preset_name) catch |err| {
                        result.deinit();
                        return err;
                    };
                    var expanded = profileFromOutput(profile_out);
                    expanded.backend = backend;
                    expanded.protocol = protocol;
                    entry.value_ptr.* = expanded;
                }
            }
        }
    }
    if (lintUnknownFields(allocator, content)) |findings| {
        defer {
            var f = findings;
            f.deinit(allocator);
        }
        warnLintFindings(findings.items);
    } else |_| {} // lint failure (OOM) must not break parsing
    return result;
}

pub fn parseString(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var result = try parseStringRaw(allocator, content);
    validate(&result.value) catch |err| {
        result.deinit();
        return err;
    };
    return result;
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);
    return parseString(allocator, content);
}

// --- tests ---

const test_toml =
    \\[device]
    \\name = "Test Device"
    \\vid = 0x37d7
    \\pid = 0x2401
    \\
    \\[[device.interface]]
    \\id = 0
    \\class = "vendor"
    \\
    \\[[device.interface]]
    \\id = 1
    \\class = "hid"
    \\
    \\[device.init]
    \\commands = ["5aa5 0102 03"]
    \\response_prefix = [0x5a, 0xa5]
    \\
    \\[[report]]
    \\name = "extended"
    \\interface = 1
    \\size = 32
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x5a, 0xa5, 0xef]
    \\
    \\[report.fields]
    \\left_x = { offset = 3, type = "i16le" }
    \\left_y = { offset = 5, type = "i16le", transform = "negate" }
    \\
    \\[report.button_group]
    \\source = { offset = 11, size = 2 }
    \\map = { A = 0, B = 1, X = 3, Y = 4 }
    \\
    \\[report.checksum]
    \\algo = "crc32"
    \\range = [0, 27]
    \\expect = { offset = 28, type = "u32le" }
    \\
    \\[[report]]
    \\name = "standard"
    \\interface = 0
    \\size = 20
    \\
    \\[report.match]
    \\offset = 0
    \\expect = [0x00]
    \\
    \\[report.fields]
    \\left_x = { offset = 6, type = "i16le" }
    \\
    \\[commands.rumble]
    \\interface = 0
    \\template = "00 08 00 {strong} {weak} 00 00 00"
    \\
    \\[commands.led]
    \\interface = 1
    \\template = "5aa5 2001 {r} {g} {b} 00"
    \\
    \\[output]
    \\name = "Test Output"
    \\vid = 0x3820
    \\pid = 0x0001
    \\
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = -32768, max = 32767, fuzz = 16, flat = 128 }
    \\
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\
    \\[output.dpad]
    \\type = "hat"
    \\
    \\[output.force_feedback]
    \\type = "rumble"
    \\max_effects = 16
;

test "device: load devices/valve/steam-deck.toml has feature_report init" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/valve/steam-deck.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Valve Steam Deck", cfg.device.name);
    const init_cfg = cfg.device.init orelse return error.MissingInit;
    const fr = init_cfg.feature_report orelse return error.MissingFeatureReport;
    try std.testing.expectEqual(@as(usize, 64), fr.len);
    try std.testing.expectEqual(@as(i64, 0x81), fr[0]);
    for (fr[1..]) |b| try std.testing.expectEqual(@as(i64, 0), b);
}

test "device: load flydigi/vader5.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Flydigi Vader 5 Pro", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x2401), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 1), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
}

test "device: output profile overlays default output and preset identity" {
    const allocator = std.testing.allocator;
    const toml_with_profile =
        \\[device]
        \\name = "Profile Test"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 4
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
        \\
        \\[report.fields]
        \\left_x = { offset = 1, type = "i16le" }
        \\
        \\[output]
        \\name = "Base Output"
        \\vid = 0x1111
        \\pid = 0x2222
        \\
        \\[output.axes]
        \\left_x = { code = "ABS_X", min = -32768, max = 32767 }
        \\
        \\[output.buttons]
        \\A = "BTN_SOUTH"
        \\
        \\[output.dpad]
        \\type = "hat"
        \\
        \\[output.force_feedback]
        \\type = "rumble"
        \\max_effects = 16
        \\
        \\[output.profiles.dualsense-edge]
        \\emulate = "dualsense-edge"
    ;
    var result = try parseString(allocator, toml_with_profile);
    defer result.deinit();

    try std.testing.expect(selectOutputProfile(&result.value, "dualsense-edge"));
    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0df2), out.pid);
    try std.testing.expectEqualStrings("Sony DualSense Edge", out.name.?);
    try std.testing.expectEqualStrings("hat", out.dpad.?.type);
    try std.testing.expectEqual(@as(?i64, 16), out.force_feedback.?.max_effects);

    const buttons = out.buttons orelse return error.MissingButtons;
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY1", buttons.map.get("M1") orelse return error.MissingM1);
    const axes = out.axes orelse return error.MissingAxes;
    const left_x = axes.map.get("left_x") orelse return error.MissingLeftX;
    try std.testing.expectEqual(@as(i64, -32768), left_x.min);
    try std.testing.expectEqual(@as(i64, 32767), left_x.max);
}

test "device: unknown output profile leaves default output unchanged" {
    const allocator = std.testing.allocator;
    var result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    try std.testing.expect(!selectOutputProfile(&result.value, "not-a-profile"));
    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0b00), out.pid);
    try std.testing.expectEqualStrings("Xbox Elite Series 2", out.name.?);
}

test "device: vader5 dualsense-edge output profile preserves high resolution controls" {
    const allocator = std.testing.allocator;
    var result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    try std.testing.expect(selectOutputProfile(&result.value, "dualsense-edge"));
    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0df2), out.pid);
    try std.testing.expectEqualStrings("Sony DualSense Edge", out.name.?);
    // This existing option deliberately stays on the generic auto route.
    // With no IMU or UHID PID request, DeviceInstance resolves it to uinput.
    try std.testing.expectEqualStrings("auto", out.backend);
    try std.testing.expectEqualStrings("generic", out.protocol);
    try std.testing.expect(out.imu == null);
    try std.testing.expect(out.touch_synthesis == null);

    const axes = out.axes orelse return error.MissingAxes;
    try std.testing.expectEqual(@as(usize, 6), axes.map.count());
    for (&[_][]const u8{ "left_x", "left_y", "right_x", "right_y" }) |name| {
        const axis = axes.map.get(name) orelse return error.MissingAxis;
        try std.testing.expectEqual(@as(i64, -32768), axis.min);
        try std.testing.expectEqual(@as(i64, 32767), axis.max);
    }
    for (&[_][]const u8{ "lt", "rt" }) |name| {
        const axis = axes.map.get(name) orelse return error.MissingAxis;
        try std.testing.expectEqual(@as(i64, 0), axis.min);
        try std.testing.expectEqual(@as(i64, 255), axis.max);
    }

    const buttons = out.buttons orelse return error.MissingButtons;
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY1", buttons.map.get("M1") orelse return error.MissingM1);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY2", buttons.map.get("M2") orelse return error.MissingM2);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY3", buttons.map.get("M3") orelse return error.MissingM3);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY4", buttons.map.get("M4") orelse return error.MissingM4);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY5", buttons.map.get("C") orelse return error.MissingC);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY9", buttons.map.get("O") orelse return error.MissingO);

    try std.testing.expectEqualStrings("hat", out.dpad.?.type);
    try std.testing.expectEqual(@as(?i64, 16), out.force_feedback.?.max_effects);
    try std.testing.expectEqualStrings("mouse", out.aux.?.type.?);
}

test "device: vader5 dualsense-edge-native profile is complete native USB without custom buttons or IMU" {
    const allocator = std.testing.allocator;
    const path = "devices/flydigi/vader5.toml";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(source);

    // Preset expansion must own the complete Edge button table. A partial
    // profile table would replace it wholesale, while a companion IMU would
    // violate the single-UHID native protocol contract.
    try std.testing.expect(std.mem.indexOf(
        u8,
        source,
        "[output.profiles.dualsense-edge-native.buttons]",
    ) == null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        source,
        "[output.profiles.dualsense-edge-native.imu]",
    ) == null);

    var result = try parseFile(allocator, path);
    defer result.deinit();
    try std.testing.expect(selectOutputProfile(&result.value, "dualsense-edge-native"));

    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("dualsense-edge", out.emulate.?);
    try std.testing.expectEqualStrings("uhid", out.backend);
    try std.testing.expectEqualStrings("dualsense-edge-usb", out.protocol);
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0df2), out.pid);
    try std.testing.expectEqualStrings("Sony DualSense Edge", out.name.?);
    try std.testing.expect(out.profiles == null);
    try std.testing.expect(out.imu == null);

    const axes = out.axes orelse return error.MissingAxes;
    try std.testing.expectEqual(@as(usize, native_axis_requirements.len), axes.map.count());
    for (native_axis_requirements) |required| {
        const axis = axes.map.get(required.name) orelse return error.MissingAxis;
        try std.testing.expectEqualStrings(required.code, axis.code);
        try std.testing.expectEqual(@as(i64, 0), axis.min);
        try std.testing.expectEqual(@as(i64, 255), axis.max);
    }

    const buttons = out.buttons orelse return error.MissingButtons;
    try std.testing.expectEqual(@as(usize, native_button_requirements.len), buttons.map.count());
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY1", buttons.map.get("M1") orelse return error.MissingM1);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY2", buttons.map.get("M2") orelse return error.MissingM2);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY3", buttons.map.get("M3") orelse return error.MissingM3);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY4", buttons.map.get("M4") orelse return error.MissingM4);

    const ff = out.force_feedback orelse return error.MissingForceFeedback;
    try std.testing.expectEqualStrings("rumble", ff.type);
    const touch = out.touch_synthesis orelse return error.MissingTouchSynthesis;
    try std.testing.expectEqualStrings("C", touch.left_button);
    try std.testing.expectEqualStrings("Z", touch.right_button);
    try std.testing.expectEqual(@as(i64, 480), touch.left_x);
    try std.testing.expectEqual(@as(i64, 1440), touch.right_x);
    try std.testing.expectEqual(@as(i64, 540), touch.y);
    try std.testing.expect(touch.click);
}

const native_profile_base_toml =
    \\[device]
    \\name = "Synthetic Native Profile Test"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[output]
    \\name = "Base Output"
    \\vid = 0x1111
    \\pid = 0x2222
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = -32768, max = 32767 }
    \\[output.buttons]
    \\A = "BTN_SOUTH"
    \\[output.force_feedback]
    \\type = "rumble"
    \\
;

const native_profile_header =
    \\[output.profiles.native]
    \\emulate = "dualsense-edge"
    \\backend = "uhid"
    \\protocol = "dualsense-edge-usb"
    \\
;

const native_profile_axes =
    \\[output.profiles.native.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    \\right_x = { code = "ABS_RX", min = 0, max = 255 }
    \\right_y = { code = "ABS_RY", min = 0, max = 255 }
    \\lt = { code = "ABS_Z", min = 0, max = 255 }
    \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    \\
;

const native_profile_force_feedback =
    \\[output.profiles.native.force_feedback]
    \\type = "rumble"
    \\
;

const native_profile_touch =
    \\[output.profiles.native.touch_synthesis]
    \\left_button = "C"
    \\right_button = "Z"
    \\left_x = 480
    \\right_x = 1440
    \\y = 540
    \\click = true
    \\
;

const valid_native_profile_toml = native_profile_base_toml ++
    native_profile_header ++
    native_profile_axes ++
    native_profile_force_feedback ++
    native_profile_touch;

const native_root_for_profile_overlay_toml =
    \\[device]
    \\name = "Synthetic Native Root Test"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "main"
    \\interface = 0
    \\size = 4
    \\[output]
    \\emulate = "dualsense-edge"
    \\backend = "uhid"
    \\protocol = "dualsense-edge-usb"
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    \\right_x = { code = "ABS_RX", min = 0, max = 255 }
    \\right_y = { code = "ABS_RY", min = 0, max = 255 }
    \\lt = { code = "ABS_Z", min = 0, max = 255 }
    \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    \\[output.force_feedback]
    \\type = "rumble"
    \\[output.touch_synthesis]
    \\left_button = "C"
    \\right_button = "Z"
    \\left_x = 480
    \\right_x = 1440
    \\y = 540
    \\click = true
    \\
;

test "device: output backend and protocol default to generic auto routing" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("auto", out.backend);
    try std.testing.expectEqualStrings("generic", out.protocol);
}

test "device: profile absent backend and protocol inherit native root" {
    const allocator = std.testing.allocator;
    const toml_str = native_root_for_profile_overlay_toml ++
        \\[output.profiles.renamed]
        \\name = "Renamed Native Output"
    ;
    var result = try parseString(allocator, toml_str);
    defer result.deinit();

    const parsed_out = result.value.output orelse return error.MissingOutput;
    const profiles = parsed_out.profiles orelse return error.MissingProfiles;
    const profile = profiles.map.get("renamed") orelse return error.MissingProfile;
    try std.testing.expect(profile.backend == null);
    try std.testing.expect(profile.protocol == null);

    try std.testing.expect(selectOutputProfile(&result.value, "renamed"));
    const selected = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("Renamed Native Output", selected.name.?);
    try std.testing.expectEqualStrings("uhid", selected.backend);
    try std.testing.expectEqualStrings("dualsense-edge-usb", selected.protocol);
}

test "device: profile explicit native backend and protocol override generic root" {
    const allocator = std.testing.allocator;
    var result = try parseString(allocator, valid_native_profile_toml);
    defer result.deinit();

    const root = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("auto", root.backend);
    try std.testing.expectEqualStrings("generic", root.protocol);

    try std.testing.expect(selectOutputProfile(&result.value, "native"));
    const selected = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("uhid", selected.backend);
    try std.testing.expectEqualStrings("dualsense-edge-usb", selected.protocol);
}

test "device: profile preset expansion preserves absent routing fields" {
    const allocator = std.testing.allocator;
    const toml_str = native_root_for_profile_overlay_toml ++
        \\[output.profiles.preset]
        \\emulate = "dualsense-edge"
        \\name = "Preset Expanded Native Output"
        \\[output.profiles.preset.axes]
        \\left_x = { code = "ABS_X", min = 0, max = 255 }
        \\left_y = { code = "ABS_Y", min = 0, max = 255 }
        \\right_x = { code = "ABS_RX", min = 0, max = 255 }
        \\right_y = { code = "ABS_RY", min = 0, max = 255 }
        \\lt = { code = "ABS_Z", min = 0, max = 255 }
        \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    ;
    var result = try parseString(allocator, toml_str);
    defer result.deinit();

    const parsed_out = result.value.output orelse return error.MissingOutput;
    const profiles = parsed_out.profiles orelse return error.MissingProfiles;
    const profile = profiles.map.get("preset") orelse return error.MissingProfile;
    try std.testing.expect(profile.backend == null);
    try std.testing.expect(profile.protocol == null);

    try std.testing.expect(selectOutputProfile(&result.value, "preset"));
    const selected = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("uhid", selected.backend);
    try std.testing.expectEqualStrings("dualsense-edge-usb", selected.protocol);
}

test "device: synthetic native profile expands complete buttons and replaces preset axes" {
    const allocator = std.testing.allocator;
    var result = try parseString(allocator, valid_native_profile_toml);
    defer result.deinit();

    try std.testing.expect(selectOutputProfile(&result.value, "native"));
    const out = result.value.output orelse return error.MissingOutput;
    try std.testing.expectEqualStrings("uhid", out.backend);
    try std.testing.expectEqualStrings("dualsense-edge-usb", out.protocol);
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0df2), out.pid);
    try std.testing.expect(out.profiles == null);

    const axes = out.axes orelse return error.MissingAxes;
    try std.testing.expectEqual(@as(usize, 6), axes.map.count());
    for (native_axis_requirements) |required| {
        const axis = axes.map.get(required.name) orelse return error.MissingAxis;
        try std.testing.expectEqualStrings(required.code, axis.code);
        try std.testing.expectEqual(@as(i64, 0), axis.min);
        try std.testing.expectEqual(@as(i64, 255), axis.max);
    }

    const buttons = out.buttons orelse return error.MissingButtons;
    try std.testing.expectEqual(@as(usize, native_button_requirements.len), buttons.map.count());
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY1", buttons.map.get("M1") orelse return error.MissingM1);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY2", buttons.map.get("M2") orelse return error.MissingM2);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY3", buttons.map.get("M3") orelse return error.MissingM3);
    try std.testing.expectEqualStrings("BTN_TRIGGER_HAPPY4", buttons.map.get("M4") orelse return error.MissingM4);

    const touch = out.touch_synthesis orelse return error.MissingTouchSynthesis;
    try std.testing.expectEqualStrings("C", touch.left_button);
    try std.testing.expectEqualStrings("Z", touch.right_button);
    try std.testing.expectEqual(@as(i64, 480), touch.left_x);
    try std.testing.expectEqual(@as(i64, 1440), touch.right_x);
    try std.testing.expectEqual(@as(i64, 540), touch.y);
    try std.testing.expect(touch.click);
}

test "device: native protocol requires touch synthesis" {
    const allocator = std.testing.allocator;
    const missing_touch = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        native_profile_force_feedback;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, missing_touch));
}

test "device: native protocol requires non-empty output name" {
    const allocator = std.testing.allocator;
    var result = try parseString(allocator, valid_native_profile_toml);
    defer result.deinit();
    try std.testing.expect(selectOutputProfile(&result.value, "native"));

    var out = result.value.output orelse return error.MissingOutput;
    out.name = null;
    result.value.output = out;
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));

    out.name = "";
    result.value.output = out;
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "device: native profile rejects partial replacement button table" {
    const allocator = std.testing.allocator;
    const partial_buttons = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        native_profile_force_feedback ++
        native_profile_touch ++
        \\[output.profiles.native.buttons]
        \\A = "BTN_SOUTH"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, partial_buttons));
}

test "device: native profile rejects partial extra wrong-code and wrong-range axes" {
    const allocator = std.testing.allocator;

    const partial_axes = native_profile_base_toml ++
        native_profile_header ++
        \\[output.profiles.native.axes]
        \\left_x = { code = "ABS_X", min = 0, max = 255 }
        \\left_y = { code = "ABS_Y", min = 0, max = 255 }
        \\right_x = { code = "ABS_RX", min = 0, max = 255 }
        \\right_y = { code = "ABS_RY", min = 0, max = 255 }
        \\lt = { code = "ABS_Z", min = 0, max = 255 }
    ++ native_profile_force_feedback ++
        native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, partial_axes));

    const extra_axes = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        \\extra = { code = "ABS_MISC", min = 0, max = 255 }
    ++ native_profile_force_feedback ++
        native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, extra_axes));

    const wrong_code_axes = native_profile_base_toml ++
        native_profile_header ++
        \\[output.profiles.native.axes]
        \\left_x = { code = "ABS_RX", min = 0, max = 255 }
        \\left_y = { code = "ABS_Y", min = 0, max = 255 }
        \\right_x = { code = "ABS_RX", min = 0, max = 255 }
        \\right_y = { code = "ABS_RY", min = 0, max = 255 }
        \\lt = { code = "ABS_Z", min = 0, max = 255 }
        \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    ++ native_profile_force_feedback ++
        native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, wrong_code_axes));

    const wrong_range_axes = native_profile_base_toml ++
        native_profile_header ++
        \\[output.profiles.native.axes]
        \\left_x = { code = "ABS_X", min = 0, max = 254 }
        \\left_y = { code = "ABS_Y", min = 0, max = 255 }
        \\right_x = { code = "ABS_RX", min = 0, max = 255 }
        \\right_y = { code = "ABS_RY", min = 0, max = 255 }
        \\lt = { code = "ABS_Z", min = 0, max = 255 }
        \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    ++ native_profile_force_feedback ++
        native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, wrong_range_axes));
}

test "device: native touch synthesis validates protocol sources and coordinate bounds" {
    const allocator = std.testing.allocator;

    const generic_touch = test_toml ++ "\n" ++
        \\[output.touch_synthesis]
        \\left_button = "C"
        \\right_button = "Z"
        \\left_x = 480
        \\right_x = 1440
        \\y = 540
        \\click = true
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, generic_touch));

    const bad_source = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        native_profile_force_feedback ++
        \\[output.profiles.native.touch_synthesis]
        \\left_button = "not-a-button"
        \\right_button = "Z"
        \\left_x = 480
        \\right_x = 1440
        \\y = 540
        \\click = true
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad_source));

    const bad_coordinates = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        native_profile_force_feedback ++
        \\[output.profiles.native.touch_synthesis]
        \\left_button = "C"
        \\right_button = "Z"
        \\left_x = -1
        \\right_x = 1920
        \\y = 1080
        \\click = true
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad_coordinates));
}

test "device: backend protocol matrix and native identity rumble requirements fail closed" {
    const allocator = std.testing.allocator;

    const unknown_backend = native_profile_base_toml ++
        \\[output.profiles.native]
        \\backend = "magic"
        \\protocol = "generic"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, unknown_backend));

    const unknown_protocol = native_profile_base_toml ++
        \\[output.profiles.native]
        \\backend = "uhid"
        \\protocol = "unknown"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, unknown_protocol));

    const auto_native = native_profile_base_toml ++
        \\[output.profiles.native]
        \\backend = "auto"
        \\protocol = "dualsense-edge-usb"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, auto_native));

    const uinput_native = native_profile_base_toml ++
        \\[output.profiles.native]
        \\backend = "uinput"
        \\protocol = "dualsense-edge-usb"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, uinput_native));

    const wrong_identity = native_profile_base_toml ++
        \\[output.profiles.native]
        \\backend = "uhid"
        \\protocol = "dualsense-edge-usb"
        \\vid = 0x054c
        \\pid = 0x0ce6
    ++ "\n" ++ native_profile_axes ++
        native_profile_force_feedback ++
        native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, wrong_identity));

    const wrong_rumble_type = native_profile_base_toml ++
        native_profile_header ++
        native_profile_axes ++
        \\[output.profiles.native.force_feedback]
        \\type = "pid"
        \\
    ++ native_profile_touch;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, wrong_rumble_type));

    const native_with_companion_imu = valid_native_profile_toml ++
        \\[output.profiles.native.imu]
        \\backend = "uhid"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, native_with_companion_imu));
}

test "device: vader5 IF1 is claimed via libusb (vendor transport)" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    const cfg = result.value;
    // IF1 read transport + IF2/IF3 suppress-only claims.
    try std.testing.expectEqual(@as(usize, 3), cfg.device.interface.len);
    try std.testing.expectEqual(@as(usize, 1), openedInterfaceCount(&cfg));
    const if1 = cfg.device.interface[0];
    try std.testing.expectEqual(@as(i64, 1), if1.id);
    try std.testing.expectEqualStrings("vendor", if1.class);
    try std.testing.expectEqual(@as(i64, 0x82), if1.ep_in orelse return error.MissingEpIn);
    try std.testing.expectEqual(@as(i64, 0x06), if1.ep_out orelse return error.MissingEpOut);

    try std.testing.expectEqualStrings("suppress", cfg.device.interface[1].class);
    try std.testing.expectEqual(@as(i64, 2), cfg.device.interface[1].id);
    try std.testing.expect(cfg.device.interface[1].ep_in == null);
    try std.testing.expectEqualStrings("suppress", cfg.device.interface[2].class);
    try std.testing.expectEqual(@as(i64, 3), cfg.device.interface[2].id);

    const init_cfg = cfg.device.init orelse return error.MissingInit;
    try std.testing.expectEqual(@as(i64, 1), init_cfg.interface orelse return error.MissingInterface);
    try std.testing.expect(init_cfg.commands != null);
    try std.testing.expect(init_cfg.enable != null);
}

test "device: vader5 blocks only xpad (regression #355)" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer result.deinit();

    // Blocking hid_generic/usbhid removed the hidraw node that discovery needs;
    // padctl self-detaches the kernel HID driver at libusb claim, so only xpad
    // must be blocked.
    const blocked = result.value.device.block_kernel_drivers orelse return error.MissingBlockList;
    try std.testing.expectEqual(@as(usize, 1), blocked.len);
    try std.testing.expectEqualStrings("xpad", blocked[0]);
    for (blocked) |drv| {
        try std.testing.expect(!std.mem.eql(u8, drv, "hid_generic"));
        try std.testing.expect(!std.mem.eql(u8, drv, "usbhid"));
    }
}

test "device: usesLibusb true for vendor/suppress, false for hid-only" {
    const allocator = std.testing.allocator;

    const vader = try parseFile(allocator, "devices/flydigi/vader5.toml");
    defer vader.deinit();
    try std.testing.expect(usesLibusb(&vader.value));

    const hid_only =
        \\[device]
        \\name = "H"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
    ;
    const hid = try parseString(allocator, hid_only);
    defer hid.deinit();
    try std.testing.expect(!usesLibusb(&hid.value));
}

fn suppressIndexToml(comptime suppress_first: bool) []const u8 {
    const report_block =
        \\[[device.interface]]
        \\id = 5
        \\class = "hid"
        \\
    ;
    const suppress_block =
        \\[[device.interface]]
        \\id = 9
        \\class = "suppress"
        \\
    ;
    const head =
        \\[device]
        \\name = "Mixed"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
    ;
    const tail =
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 5
        \\size = 16
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
        \\
        \\[report.fields]
        \\left_x = { offset = 6, type = "i16le" }
        \\
    ;
    return if (suppress_first)
        head ++ suppress_block ++ report_block ++ tail
    else
        head ++ report_block ++ suppress_block ++ tail;
}

test "device: suppress interface excluded from devices[] index regardless of order" {
    const allocator = std.testing.allocator;

    inline for (.{ true, false }) |suppress_first| {
        const result = try parseString(allocator, suppressIndexToml(suppress_first));
        defer result.deinit();
        const cfg = result.value;

        try validate(&cfg);
        try std.testing.expectEqual(@as(usize, 2), cfg.device.interface.len);
        // Only the hid interface gets a devices[] slot.
        try std.testing.expectEqual(@as(usize, 1), openedInterfaceCount(&cfg));
        // The report interface (id 5) always resolves to devices[0] whether the
        // suppress interface (id 9) precedes or follows it.
        try std.testing.expectEqual(@as(?usize, 0), deviceIndexForInterface(&cfg, 5));
        try std.testing.expectEqual(@as(?usize, null), deviceIndexForInterface(&cfg, 9));
        // Inverse mapping yields the report interface, never the suppress one.
        const iface0 = interfaceForDeviceIndex(&cfg, 0) orelse return error.MissingInterface;
        try std.testing.expectEqual(@as(i64, 5), iface0.id);
        try std.testing.expectEqual(@as(?*const InterfaceConfig, null), interfaceForDeviceIndex(&cfg, 1));
    }
}

test "device: validate rejects suppress interface with endpoints" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Bad"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 1
        \\class = "suppress"
        \\ep_in = 0x81
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 1
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: validate rejects report referencing a suppress interface" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Bad"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 1
        \\class = "suppress"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 1
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: validate rejects report->suppress reference even with a readable interface" {
    const allocator = std.testing.allocator;
    // A readable hid interface (id 5) keeps openedInterfaceCount >= 1 so the
    // all-suppress guard does NOT fire; the report targets the suppress
    // interface (id 9), so only the report->suppress check can reject it.
    const bad =
        \\[device]
        \\name = "Mixed"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 5
        \\class = "hid"
        \\
        \\[[device.interface]]
        \\id = 9
        \\class = "suppress"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 9
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: validate rejects an all-suppress config with no readable interface" {
    const ifaces = [_]InterfaceConfig{
        .{ .id = 1, .class = "suppress" },
        .{ .id = 2, .class = "suppress" },
    };
    const cfg = DeviceConfig{
        .device = .{
            .name = "AllSuppress",
            .vid = 0x1234,
            .pid = 0x5678,
            .interface = &ifaces,
        },
        .report = &.{},
    };
    try std.testing.expectError(error.InvalidConfig, validate(&cfg));
}

test "device: validate rejects negative button_group source.offset" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Bad ButtonGroup Offset"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 8
        \\
        \\[report.button_group]
        \\source = { offset = -1, size = 1 }
        \\map = { A = 0 }
    ;
    try std.testing.expectError(error.OffsetOutOfBounds, parseString(allocator, bad));
}

test "device: force_feedback.auto_stop defaults to true when unspecified" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    // The test TOML declares [output.force_feedback] type = "rumble" without
    // auto_stop. The default must be true (userspace rumble auto-stop enabled).
    const ff = result.value.output.?.force_feedback.?;
    try std.testing.expect(ff.auto_stop);
}

test "device: force_feedback.auto_stop = false parses to disabled scheduler" {
    const allocator = std.testing.allocator;
    const toml_with_opt_out =
        \\[device]
        \\name = "Test Opt-Out"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 16
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
        \\
        \\[report.fields]
        \\left_x = { offset = 6, type = "i16le" }
        \\
        \\[output]
        \\name = "Test"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[output.axes]
        \\left_x = { code = "ABS_X", min = -32768, max = 32767 }
        \\
        \\[output.force_feedback]
        \\type = "rumble"
        \\auto_stop = false
    ;
    const result = try parseString(allocator, toml_with_opt_out);
    defer result.deinit();

    const ff = result.value.output.?.force_feedback.?;
    try std.testing.expect(!ff.auto_stop);
}

test "device: valid config parses and validates" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("extended", cfg.report[0].name);
    try std.testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
}

test "device: offset out of bounds returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[report.fields]
        \\x = { offset = 3, type = "i16le" }
    ;
    try std.testing.expectError(error.OffsetOutOfBounds, parseString(allocator, bad));
}

test "device: validate rejects a config with no interface at all" {
    const cfg = DeviceConfig{
        .device = .{
            .name = "test",
            .vid = 1,
            .pid = 2,
            .interface = &.{},
        },
        .report = &.{},
    };
    try std.testing.expectError(error.InvalidConfig, validate(&cfg));
}

test "device: invalid transform returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\x = { offset = 0, type = "u8", transform = "$val * 2 + 1" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: transform chain exceeding max count returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\x = { offset = 0, type = "u8", transform = "abs, abs, abs, abs, abs, abs, abs, abs, abs" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: transform chain at max count is accepted" {
    const allocator = std.testing.allocator;
    const ok =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\x = { offset = 0, type = "u8", transform = "abs, abs, abs, abs, abs, abs, abs, abs" }
    ;
    const parsed = try parseString(allocator, ok);
    defer parsed.deinit();
}

test "device: unknown button name returns error" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.button_group]
        \\source = { offset = 0, size = 1 }
        \\map = { INVALID_BTN = 0 }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: load devices/sony/dualsense.toml succeeds" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("Sony DualSense", cfg.device.name);
    try std.testing.expectEqual(@as(i64, 0x054c), cfg.device.vid);
    try std.testing.expectEqual(@as(i64, 0x0ce6), cfg.device.pid);
    try std.testing.expectEqual(@as(usize, 2), cfg.report.len);
    try std.testing.expectEqualStrings("usb", cfg.report[0].name);
    try std.testing.expectEqualStrings("bt", cfg.report[1].name);
}

test "device: dualsense.toml report field count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const fields = cfg.report[0].fields orelse return error.NoFields;
    // left_x, left_y, right_x, right_y, lt, rt,
    // gyro_x, gyro_y, gyro_z, accel_x, accel_y, accel_z,
    // sensor_timestamp, touch0_contact, touch1_contact, battery_level = 16
    try std.testing.expectEqual(@as(usize, 16), fields.map.count());
}

test "device: dualsense.toml commands count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const cmds = cfg.commands orelse return error.NoCommands;
    // rumble + led + 4 adaptive trigger = 6
    try std.testing.expectEqual(@as(usize, 6), cmds.map.count());
}

test "device: dualsense.toml output axes and buttons count" {
    const allocator = std.testing.allocator;
    const result = try parseFile(allocator, "devices/sony/dualsense.toml");
    defer result.deinit();

    const cfg = result.value;
    const out = cfg.output orelse return error.NoOutput;
    const axes = out.axes orelse return error.NoAxes;
    const buttons = out.buttons orelse return error.NoButtons;
    // left_x, left_y, right_x, right_y, lt, rt = 6
    try std.testing.expectEqual(@as(usize, 6), axes.map.count());
    // A, B, X, Y, LB, RB, Select, Start, Home, LS, RS, TouchPad, Mic = 13
    try std.testing.expectEqual(@as(usize, 13), buttons.map.count());
}

const emulate_toml =
    \\[device]
    \\name = "My Device"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 4
    \\[output]
    \\emulate = "xbox-360"
;

test "device: emulate preset resolves vid/pid/name and axes/buttons" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, emulate_toml);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x028e), out.pid);
    try std.testing.expectEqualStrings("Xbox 360 Controller", out.name.?);
    try std.testing.expect(out.axes != null);
    try std.testing.expect(out.buttons != null);
}

test "device: emulate preset: explicit vid overrides preset" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1234
        \\pid = 0x5678
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "dualsense"
        \\vid = 0xdead
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqual(@as(?i64, 0xdead), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0ce6), out.pid);
}

test "device: emulate preset: dualsense-edge resolves identity and preserves explicit axes" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1234
        \\pid = 0x5678
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "dualsense-edge"
        \\[output.axes]
        \\left_x = { code = "ABS_X", min = -32768, max = 32767, fuzz = 16, flat = 128 }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();

    const out = result.value.output.?;
    try std.testing.expectEqual(@as(?i64, 0x054c), out.vid);
    try std.testing.expectEqual(@as(?i64, 0x0df2), out.pid);
    try std.testing.expectEqualStrings("Sony DualSense Edge", out.name.?);
    const axes = out.axes orelse return error.MissingAxes;
    try std.testing.expectEqual(@as(usize, 1), axes.map.count());
    const left_x = axes.map.get("left_x") orelse return error.MissingLeftX;
    try std.testing.expectEqual(@as(i64, -32768), left_x.min);
    try std.testing.expectEqual(@as(i64, 32767), left_x.max);
}

test "device: emulate preset: unknown preset returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1234
        \\pid = 0x5678
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "no-such-preset"
    ;
    try std.testing.expectError(error.UnknownPreset, parseString(allocator, toml_str));
}

test "device: VID=0 is a valid config value" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "wildcard"
        \\vid = 0
        \\pid = 0
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqual(@as(i64, 0), result.value.device.vid);
}

test "device: empty device name parses and validates without error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = ""
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 1
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("", result.value.device.name);
}

// bits DSL config validation

test "device: bits field parses and validates" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12] }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const fields = result.value.report[0].fields orelse return error.NoFields;
    var it = fields.map.iterator();
    const entry = it.next() orelse return error.Empty;
    const fc = entry.value_ptr.*;
    try std.testing.expect(fc.bits != null);
    try std.testing.expect(fc.offset == null);
}

test "device: bits field with signed type" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 4, 12], type = "signed" }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
}

test "device: bits field with invalid type returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], type = "i16le" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits out of bounds returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 4
        \\[report.fields]
        \\left_x = { bits = [3, 0, 12] }
    ;
    try std.testing.expectError(error.OffsetOutOfBounds, parseString(allocator, toml_str));
}

test "device: bits with offset present returns error (mutual exclusivity)" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], offset = 2 }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: missing both offset and bits returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { type = "u8" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits with transform returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 16
        \\[report.fields]
        \\left_x = { bits = [2, 0, 12], transform = "negate" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: bits span > 4 bytes returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 64
        \\[report.fields]
        \\left_x = { bits = [0, 1, 32] }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: lookup transform is rejected" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\x = { offset = 0, type = "u8", transform = "lookup" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: generic mode: valid config parses" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[report.button_group]
        \\source = { offset = 4, size = 1 }
        \\map = { gear_up = 0 }
        \\[output]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\[output.mapping]
        \\wheel = { event = "ABS_WHEEL", range = [-32768, 32767] }
        \\gear_up = { event = "BTN_GEAR_UP" }
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("generic", result.value.device.mode.?);
}

test "device: generic mode: missing output.mapping returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[output]
        \\name = "Wheel"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: generic mode: unknown event code returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[output]
        \\name = "Wheel"
        \\[output.mapping]
        \\wheel = { event = "INVALID_CODE", range = [-100, 100] }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: generic mode: ABS event missing range returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Wheel"
        \\vid = 1
        \\pid = 2
        \\mode = "generic"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
        \\[report.fields]
        \\wheel = { offset = 0, type = "i16le" }
        \\[output]
        \\name = "Wheel"
        \\[output.mapping]
        \\wheel = { event = "ABS_WHEEL" }
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "device: feature_report rejects byte > 255" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[device.init]
        \\feature_report = [256]
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: feature_report rejects byte < 0" {
    const allocator = std.testing.allocator;
    const bad =
        \\[device]
        \\name = "Test"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[device.init]
        \\feature_report = [-1]
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad));
}

test "device: fuzz parseString: no panic on arbitrary input" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) !void {
            const result = parseString(std.testing.allocator, input);
            if (result) |r| r.deinit() else |_| {}
        }
    }.run, .{});
}

// ImuConfig validate cases.

test "validate: ImuConfig default (absent) is legal" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml);
    defer result.deinit();
    try std.testing.expect(result.value.output.?.imu == null);
}

test "validate: backend=uhid + [output.imu] present is legal" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\[output.imu]
        \\backend = "uhid"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("uhid", result.value.output.?.imu.?.backend);
}

test "validate: backend=uinput + [output.imu] present is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\[output.imu]
        \\backend = "uinput"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: root output backend=uinput cannot silently drop a UHID IMU" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\backend = "uinput"
        \\protocol = "generic"
        \\[output.imu]
        \\backend = "uhid"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: backend=unknown is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\[output.imu]
        \\backend = "xyz"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: TOML round-trip with [output.imu] backend and name" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\[output.imu]
        \\backend = "uhid"
        \\name = "Pad IMU"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("uhid", result.value.output.?.imu.?.backend);
    try std.testing.expectEqualStrings("Pad IMU", result.value.output.?.imu.?.name.?);
}

test "validate: TOML round-trip missing [output.imu] leaves imu=null" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqual(@as(?ImuConfig, null), result.value.output.?.imu);
}

test "validate: [output.imu] without explicit backend defaults to uhid and passes validate" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[device]
        \\name = "Pad"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\name = "Pad"
        \\[output.imu]
        \\name = "Pad IMU"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqualStrings("uhid", result.value.output.?.imu.?.backend);
}

// [output.force_feedback] schema validate matrix.

const ffb_base_toml =
    \\[device]
    \\name = "Wheel"
    \\vid = 0x11FF
    \\pid = 0x1211
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 4
;

test "validate: force_feedback absent (default) is legal" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectEqual(@as(?ForceFeedbackConfig, null), result.value.output.?.force_feedback);
}

test "validate: backend=uinput + kind=rumble is legal" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.force_feedback]
        \\backend = "uinput"
        \\kind = "rumble"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const ffb = result.value.output.?.force_feedback.?;
    try std.testing.expectEqualStrings("uinput", ffb.backend);
    try std.testing.expectEqualStrings("rumble", ffb.kind);
}

test "validate: backend=uinput + kind=pid is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.force_feedback]
        \\backend = "uinput"
        \\kind = "pid"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: backend=uhid + kind=rumble is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.force_feedback]
        \\backend = "uhid"
        \\kind = "rumble"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: backend=uhid + kind=pid + [output.imu] absent is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.force_feedback]
        \\backend = "uhid"
        \\kind = "pid"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "validate: backend=uhid + kind=pid + [output.imu] present is legal" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.imu]
        \\backend = "uhid"
        \\[output.force_feedback]
        \\backend = "uhid"
        \\kind = "pid"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const ffb = result.value.output.?.force_feedback.?;
    try std.testing.expectEqualStrings("uhid", ffb.backend);
    try std.testing.expectEqualStrings("pid", ffb.kind);
}

test "validate: force_feedback unknown backend is error.InvalidConfig" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.force_feedback]
        \\backend = "foo"
        \\kind = "rumble"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_str));
}

test "force_feedback: TOML round-trip" {
    const allocator = std.testing.allocator;
    const toml_str = ffb_base_toml ++
        \\
        \\[output]
        \\name = "Wheel"
        \\[output.imu]
        \\backend = "uhid"
        \\[output.force_feedback]
        \\backend       = "uhid"
        \\kind          = "pid"
        \\clone_vid_pid = true
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const ffb = result.value.output.?.force_feedback.?;
    try std.testing.expectEqualStrings("uhid", ffb.backend);
    try std.testing.expectEqualStrings("pid", ffb.kind);
    try std.testing.expect(ffb.clone_vid_pid);
}

// clone_vid_pid validate tests.

const ffb_zero_vid_toml =
    \\[device]
    \\name = "Zero VID Wheel"
    \\vid = 0x0000
    \\pid = 0x1211
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "r"
    \\interface = 0
    \\size = 4
;

test "validate: clone_vid_pid=true requires non-zero device.vid/pid" {
    const allocator = std.testing.allocator;
    // Zero vid — must reject
    const toml_zero_vid = ffb_zero_vid_toml ++
        \\
        \\[output]
        \\name = "Zero VID Wheel"
        \\[output.imu]
        \\backend = "uhid"
        \\[output.force_feedback]
        \\backend       = "uhid"
        \\kind          = "pid"
        \\clone_vid_pid = true
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, toml_zero_vid));
}

test "validate: clone_vid_pid=false with zero device.vid is legal" {
    const allocator = std.testing.allocator;
    // clone_vid_pid=false (default) — zero vid is fine, no clonable identity needed
    const toml_zero_vid_no_clone = ffb_zero_vid_toml ++
        \\
        \\[output]
        \\name = "Zero VID Wheel"
        \\[output.imu]
        \\backend = "uhid"
        \\[output.force_feedback]
        \\backend       = "uhid"
        \\kind          = "pid"
        \\clone_vid_pid = false
    ;
    const result = try parseString(allocator, toml_zero_vid_no_clone);
    defer result.deinit();
    try std.testing.expect(!result.value.output.?.force_feedback.?.clone_vid_pid);
}

test "device: report referencing nonexistent interface id is rejected" {
    const allocator = std.testing.allocator;
    const bad_ref_toml =
        \\[device]
        \\name = "Bad Ref"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 9
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad_ref_toml));
}

test "device: command referencing nonexistent interface id is rejected" {
    const allocator = std.testing.allocator;
    const bad_cmd_toml =
        \\[device]
        \\name = "Bad Cmd Ref"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
        \\
        \\[commands.rumble]
        \\interface = 7
        \\template = "00 {strong} {weak}"
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad_cmd_toml));
}

test "device: init referencing nonexistent interface id is rejected" {
    const allocator = std.testing.allocator;
    const bad_init_toml =
        \\[device]
        \\name = "Bad Init Ref"
        \\vid = 0x1234
        \\pid = 0x5678
        \\
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = 8
        \\
        \\[report.match]
        \\offset = 0
        \\expect = [0x00]
        \\
        \\[device.init]
        \\interface = 5
        \\commands = ["5aa5"]
    ;
    try std.testing.expectError(error.InvalidConfig, parseString(allocator, bad_init_toml));
}

// --- report.size bound tests ---

fn reportSizeToml(comptime size: []const u8) []const u8 {
    return "[device]\n" ++
        "name = \"T\"\n" ++
        "vid = 1\n" ++
        "pid = 2\n" ++
        "[[device.interface]]\n" ++
        "id = 0\n" ++
        "class = \"hid\"\n" ++
        "[[report]]\n" ++
        "name = \"r\"\n" ++
        "interface = 0\n" ++
        "size = " ++ size ++ "\n";
}

test "device: report.size at the 512-byte cap validates" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, reportSizeToml("512"));
    defer result.deinit();
    try std.testing.expectEqual(@as(i64, 512), result.value.report[0].size);
}

test "device: report.size above the 512-byte cap is rejected" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.ReportSizeTooLarge, parseString(allocator, reportSizeToml("513")));
}

test "device: report.size far above the cap is rejected" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.ReportSizeTooLarge, parseString(allocator, reportSizeToml("4096")));
}

// --- unknown-field linter tests ---

test "device: lintUnknownFields flags an unknown key in [device]" {
    const allocator = std.testing.allocator;
    const typo =
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\nam = "typo"
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 8
    ;
    var findings = try lintUnknownFields(allocator, typo);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), findings.items.len);
    try std.testing.expectEqualStrings("nam", findings.items[0].unknown_key);
    try std.testing.expectEqualStrings("device", findings.items[0].table);
}

test "device: lintUnknownFields flags a typo'd [[report]] key" {
    const allocator = std.testing.allocator;
    const typo =
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
        \\siz = 8
    ;
    var findings = try lintUnknownFields(allocator, typo);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), findings.items.len);
    try std.testing.expectEqualStrings("siz", findings.items[0].unknown_key);
    try std.testing.expectEqualStrings("report", findings.items[0].table);
}

test "device: lintUnknownFields leaves a clean config unflagged" {
    const allocator = std.testing.allocator;
    var findings = try lintUnknownFields(allocator, test_toml);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "device: lintUnknownFields does not flag free-form HashMap sections" {
    const allocator = std.testing.allocator;
    const toml_str =
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
        \\size = 8
        \\[report.fields]
        \\any_user_field = { offset = 0, type = "u8" }
        \\[output]
        \\name = "T"
        \\[output.buttons]
        \\A = "BTN_SOUTH"
        \\Whatever = "BTN_NORTH"
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "device: all shipped devices/*.toml lint clean" {
    const allocator = std.testing.allocator;
    var dir = try std.fs.cwd().openDir("devices", .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    var checked: usize = 0;
    while (try walker.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".toml")) continue;
        const content = try dir.readFileAlloc(allocator, entry.path, 1024 * 1024);
        defer allocator.free(content);
        var findings = try lintUnknownFields(allocator, content);
        defer findings.deinit(allocator);
        if (findings.items.len > 0) {
            for (findings.items) |f|
                std.debug.print("  {s}: unknown key '{s}' in [{s}] (line {d})\n", .{ entry.path, f.unknown_key, f.table, f.line });
        }
        try std.testing.expectEqual(@as(usize, 0), findings.items.len);
        checked += 1;
    }
    try std.testing.expect(checked >= 1);
}
