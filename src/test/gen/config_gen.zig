const std = @import("std");
const device = @import("../../config/device.zig");
const mapping = @import("../../config/mapping.zig");
const state = @import("../../core/state.zig");

const FieldTag = @import("../../core/interpreter.zig").FieldTag;
const ButtonId = state.ButtonId;

// --- Device config generation ---

const field_tags = [_][]const u8{ "left_x", "left_y", "right_x", "right_y", "lt", "rt", "gyro_x", "gyro_y", "gyro_z", "accel_x", "accel_y", "accel_z", "touch0_x", "touch0_y", "touch1_x", "touch1_y", "touch0_active", "touch1_active", "battery_level", "dpad", "unknown" };
const field_types = [_][]const u8{ "u8", "i8", "u16le", "i16le", "u16be", "i16be", "u32le", "i32le", "u32be", "i32be" };
const transforms = [_][]const u8{ "negate", "abs", "scale(0,255)", "clamp(-128,127)", "deadzone(10)" };

const button_names = [_][]const u8{ "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Start", "Select", "Home", "LS", "RS", "DPadUp", "DPadDown", "DPadLeft", "DPadRight", "M1", "M2", "M3", "M4" };

pub fn randomDeviceConfig(rng: std.Random, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    const vid = rng.intRangeAtMost(u16, 0x1000, 0xFFFF);
    const pid = rng.intRangeAtMost(u16, 0x1000, 0xFFFF);
    const report_size: u8 = rng.intRangeAtMost(u8, 16, 64);

    w.print(
        \\[device]
        \\name = "GenDev"
        \\vid = 0x{x:0>4}
        \\pid = 0x{x:0>4}
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "main"
        \\interface = 0
        \\size = {d}
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.fields]
        \\
    , .{ vid, pid, report_size }) catch return buf[0..0];

    // Generate 3-8 fields with non-overlapping offsets.
    // Always emit at least one primary gamepad axis (left_x/left_y/right_x/right_y)
    // so that injected packets produce visible uinput events.
    const n_fields = rng.intRangeAtMost(u8, 3, @min(8, @as(u8, @intCast(field_tags.len))));
    var used: [21]bool = .{false} ** 21;
    var next_offset: u8 = 1; // skip match byte

    for (0..n_fields) |fi| {
        const idx = if (fi == 0) blk: {
            // First field: force one of left_x(0), left_y(1), right_x(2), right_y(3)
            const forced = rng.intRangeAtMost(usize, 0, 3);
            used[forced] = true;
            break :blk forced;
        } else pickUnused(rng, &used, field_tags.len);
        const tag = field_tags[idx];
        const type_idx = rng.intRangeAtMost(usize, 0, field_types.len - 1);
        const type_str = field_types[type_idx];
        const size: u8 = typeSize(type_str);
        if (next_offset + size > report_size) break;
        const offset = next_offset;
        next_offset += size;

        // Gap 6: randomly generate 1-3 transform chain
        if (rng.boolean()) {
            const n_tr = rng.intRangeAtMost(u8, 1, 3);
            var first = true;
            for (0..n_tr) |_| {
                const tr = transforms[rng.intRangeAtMost(usize, 0, transforms.len - 1)];
                if (!first) w.writeAll(", ") catch break;
                if (first) {
                    w.print("{s} = {{ offset = {d}, type = \"{s}\", transform = \"", .{ tag, offset, type_str }) catch break;
                    first = false;
                }
                w.writeAll(tr) catch break;
            }
            w.writeAll("\" }\n") catch break;
        } else {
            w.print("{s} = {{ offset = {d}, type = \"{s}\" }}\n", .{ tag, offset, type_str }) catch break;
        }
    }

    // Always generate button_group to ensure liveness (button events)
    if (next_offset + 2 <= report_size) {
        const bg_offset = next_offset;
        const bg_size: u8 = @min(4, report_size - next_offset);
        w.print("[report.button_group]\nsource = {{ offset = {d}, size = {d} }}\nmap = {{ ", .{ bg_offset, bg_size }) catch return buf[0..fbs.pos];
        const n_btns = rng.intRangeAtMost(u8, 2, @min(4, bg_size * 8));
        var btn_used: [21]bool = .{false} ** 21;
        for (0..n_btns) |i| {
            const bi = pickUnused(rng, &btn_used, button_names.len);
            if (i > 0) w.writeAll(", ") catch break;
            w.print("{s} = {d}", .{ button_names[bi], i }) catch break;
        }
        w.writeAll(" }\n") catch {};
    }

    // Gap 10: optional checksum
    if (rng.boolean() and report_size >= 8) {
        const algos = [_][]const u8{ "sum8", "xor" };
        const algo = algos[rng.intRangeAtMost(usize, 0, algos.len - 1)];
        w.print("[report.checksum]\nalgo = \"{s}\"\nrange = [1, {d}]\n[report.checksum.expect]\noffset = {d}\ntype = \"u8\"\n", .{ algo, report_size - 2, report_size - 1 }) catch {};
    }

    // Gap 7: optional second report block with different interface
    if (rng.boolean()) {
        const r2_size: u8 = rng.intRangeAtMost(u8, 8, 32);
        w.print("[[report]]\nname = \"aux\"\ninterface = 0\nsize = {d}\n[report.match]\noffset = 0\nexpect = [0x02]\n", .{r2_size}) catch {};
    }

    return buf[0..fbs.pos];
}

fn typeSize(t: []const u8) u8 {
    if (std.mem.startsWith(u8, t, "u32") or std.mem.startsWith(u8, t, "i32")) return 4;
    if (std.mem.startsWith(u8, t, "u16") or std.mem.startsWith(u8, t, "i16")) return 2;
    return 1;
}

fn pickUnused(rng: std.Random, used: []bool, len: usize) usize {
    var idx = rng.intRangeAtMost(usize, 0, len - 1);
    for (0..len) |_| {
        if (!used[idx]) {
            used[idx] = true;
            return idx;
        }
        idx = (idx + 1) % len;
    }
    // fallback: all used, just return first
    return 0;
}

// --- Mapping config generation ---

const remap_sources = [_][]const u8{ "A", "B", "X", "Y", "LB", "RB", "M1", "M2", "M3", "M4", "C", "Z" };
const remap_targets = [_][]const u8{ "A", "B", "X", "Y", "KEY_F1", "KEY_F2", "KEY_F13", "mouse_left", "mouse_right", "disabled", "macro:test_macro" };
const layer_triggers = [_][]const u8{ "LT", "RT", "Select", "Start", "Home", "LM", "RM" };
const layer_names = [_][]const u8{ "aim", "fn", "alt", "nav" };
const gyro_modes = [_][]const u8{ "mouse", "off", "joystick" };
const dpad_modes = [_][]const u8{ "arrows", "gamepad" };
const stick_modes = [_][]const u8{ "gamepad", "mouse", "scroll" };

pub fn randomMappingConfig(rng: std.Random, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();

    // Track whether macro target is used (gap 3)
    var needs_macro = false;

    // Base remaps: 2-4
    const n_remaps = rng.intRangeAtMost(u8, 2, 4);
    w.writeAll("[remap]\n") catch return buf[0..0];
    var src_used: [12]bool = .{false} ** 12;
    for (0..n_remaps) |_| {
        const si = pickUnused(rng, &src_used, remap_sources.len);
        const ti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
        const target = remap_targets[ti];
        if (std.mem.startsWith(u8, target, "macro:")) needs_macro = true;
        w.print("{s} = \"{s}\"\n", .{ remap_sources[si], target }) catch break;
    }

    // Layers: 0-2
    const n_layers = rng.intRangeAtMost(u8, 0, 2);
    var trigger_used: [7]bool = .{false} ** 7;
    for (0..n_layers) |li| {
        const ti = pickUnused(rng, &trigger_used, layer_triggers.len);
        const name = layer_names[li];
        const activation: []const u8 = if (rng.boolean()) "hold" else "toggle";
        w.print("\n[[layer]]\nname = \"{s}\"\ntrigger = \"{s}\"\nactivation = \"{s}\"\n", .{ name, layer_triggers[ti], activation }) catch break;
        // Gap 4: tap field for hold layers
        if (std.mem.eql(u8, activation, "hold")) {
            if (rng.boolean()) {
                const timeout = rng.intRangeAtMost(u16, 100, 500);
                w.print("hold_timeout = {d}\n", .{timeout}) catch {};
            }
            if (rng.boolean()) {
                w.writeAll("tap = \"KEY_F5\"\n") catch {};
            }
        }
        // 1-3 layer remaps
        const n_lr = rng.intRangeAtMost(u8, 1, 3);
        w.writeAll("[layer.remap]\n") catch {};
        var lsrc_used: [12]bool = .{false} ** 12;
        for (0..n_lr) |_| {
            const lsi = pickUnused(rng, &lsrc_used, remap_sources.len);
            const lti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
            const lt_target = remap_targets[lti];
            if (std.mem.startsWith(u8, lt_target, "macro:")) needs_macro = true;
            w.print("{s} = \"{s}\"\n", .{ remap_sources[lsi], lt_target }) catch break;
        }
        // Gap 9: per-layer overrides
        if (rng.boolean()) {
            const ldm = dpad_modes[rng.intRangeAtMost(usize, 0, dpad_modes.len - 1)];
            w.print("[layer.dpad]\nmode = \"{s}\"\n", .{ldm}) catch {};
        }
        if (rng.boolean()) {
            const lgm = gyro_modes[rng.intRangeAtMost(usize, 0, gyro_modes.len - 1)];
            w.print("[layer.gyro]\nmode = \"{s}\"\n", .{lgm}) catch {};
        }
        if (rng.boolean()) {
            const lsm = stick_modes[rng.intRangeAtMost(usize, 0, stick_modes.len - 1)];
            w.print("[layer.stick_left]\nmode = \"{s}\"\n", .{lsm}) catch {};
        }
    }

    // Optional dpad
    if (rng.boolean()) {
        const dm = dpad_modes[rng.intRangeAtMost(usize, 0, dpad_modes.len - 1)];
        w.print("\n[dpad]\nmode = \"{s}\"\n", .{dm}) catch {};
    }

    // Optional gyro (gap 8: joystick mode)
    if (rng.boolean()) {
        const gm = gyro_modes[rng.intRangeAtMost(usize, 0, gyro_modes.len - 1)];
        w.print("\n[gyro]\nmode = \"{s}\"\n", .{gm}) catch {};
        if (std.mem.eql(u8, gm, "mouse") and rng.boolean()) {
            w.writeAll("activate = \"hold_RB\"\n") catch {};
        }
    }

    // Gap 5: optional stick section
    if (rng.boolean()) {
        w.writeAll("\n[stick]\n") catch {};
        if (rng.boolean()) {
            const sm = stick_modes[rng.intRangeAtMost(usize, 0, stick_modes.len - 1)];
            const dz = rng.intRangeAtMost(u16, 5, 30);
            w.print("[stick.left]\nmode = \"{s}\"\ndeadzone = {d}\n", .{ sm, dz }) catch {};
        }
        if (rng.boolean()) {
            const sm = stick_modes[rng.intRangeAtMost(usize, 0, stick_modes.len - 1)];
            const dz = rng.intRangeAtMost(u16, 5, 30);
            w.print("[stick.right]\nmode = \"{s}\"\ndeadzone = {d}\n", .{ sm, dz }) catch {};
        }
    }

    // Gap 3: macro section if any remap target used "macro:test_macro"
    if (needs_macro) {
        w.writeAll("\n[[macro]]\nname = \"test_macro\"\n[[macro.steps]]\ntap = \"A\"\n[[macro.steps]]\ndelay = 50\n") catch {};
    }

    return buf[0..fbs.pos];
}

// --- Compatible mapping generation for real device configs ---

// Collect button names declared in a device config's button_groups (across all reports).
// Returns slice into `out` (up to out.len entries).
pub fn collectDeviceButtonNames(cfg: *const device.DeviceConfig, out: [][]const u8) []const []const u8 {
    var n: usize = 0;
    for (cfg.report) |*rc| {
        const bg = rc.button_group orelse continue;
        var it = bg.map.map.iterator();
        while (it.next()) |entry| {
            if (n >= out.len) break;
            // Validate it's a known ButtonId before adding.
            if (std.meta.stringToEnum(ButtonId, entry.key_ptr.*) == null) continue;
            out[n] = entry.key_ptr.*;
            n += 1;
        }
    }
    return out[0..n];
}

// Generate a mapping TOML that is compatible with the given device config.
// Sources in [remap] and layer triggers are drawn only from buttons that
// actually exist in the device's button_group maps.
// Falls back to randomMappingConfig if the device declares no buttons.
pub fn generateCompatibleMapping(rng: std.Random, cfg: *const device.DeviceConfig, buf: []u8) []const u8 {
    var name_buf: [32][]const u8 = undefined;
    const btn_names = collectDeviceButtonNames(cfg, &name_buf);

    if (btn_names.len < 2) return randomMappingConfig(rng, buf);

    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    var needs_macro = false;

    // Base remaps: pick 1-3 source buttons the device actually has.
    const n_remaps = rng.intRangeAtMost(usize, 1, @min(3, btn_names.len));
    w.writeAll("[remap]\n") catch return buf[0..0];
    var src_used: [32]bool = .{false} ** 32;
    for (0..n_remaps) |_| {
        const si = pickUnused(rng, src_used[0..btn_names.len], btn_names.len);
        const ti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
        const target = remap_targets[ti];
        if (std.mem.startsWith(u8, target, "macro:")) needs_macro = true;
        w.print("{s} = \"{s}\"\n", .{ btn_names[si], target }) catch break;
    }

    // Optional layer: 0-1, trigger must be a real device button.
    if (rng.boolean() and btn_names.len >= 1) {
        const ti = rng.intRangeAtMost(usize, 0, btn_names.len - 1);
        const activation: []const u8 = if (rng.boolean()) "hold" else "toggle";
        w.print("\n[[layer]]\nname = \"fn\"\ntrigger = \"{s}\"\nactivation = \"{s}\"\n", .{ btn_names[ti], activation }) catch {};
        if (std.mem.eql(u8, activation, "hold")) {
            if (rng.boolean()) {
                w.print("hold_timeout = {d}\n", .{rng.intRangeAtMost(u16, 100, 500)}) catch {};
            }
            if (rng.boolean()) {
                w.writeAll("tap = \"KEY_F5\"\n") catch {};
            }
        }
        w.writeAll("[layer.remap]\n") catch {};
        const n_lr = rng.intRangeAtMost(usize, 1, @min(2, btn_names.len));
        var lsrc_used: [32]bool = .{false} ** 32;
        for (0..n_lr) |_| {
            const lsi = pickUnused(rng, lsrc_used[0..btn_names.len], btn_names.len);
            const lti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
            const lt_target = remap_targets[lti];
            if (std.mem.startsWith(u8, lt_target, "macro:")) needs_macro = true;
            w.print("{s} = \"{s}\"\n", .{ btn_names[lsi], lt_target }) catch break;
        }
    }

    if (needs_macro) {
        w.writeAll("\n[[macro]]\nname = \"test_macro\"\n[[macro.steps]]\ntap = \"A\"\n[[macro.steps]]\ndelay = 50\n") catch {};
    }

    return buf[0..fbs.pos];
}

// --- Tests ---

test "config_gen: generated device config parses successfully" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    var buf: [4096]u8 = undefined;

    for (0..100) |_| {
        const toml_str = randomDeviceConfig(rng, &buf);
        if (toml_str.len == 0) continue;
        const result = device.parseString(allocator, toml_str) catch |err| {
            std.debug.print("Parse failed: {}\nTOML:\n{s}\n", .{ err, toml_str });
            return err;
        };
        result.deinit();
    }
}

test "config_gen: generated mapping config parses successfully" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    var buf: [4096]u8 = undefined;

    for (0..100) |_| {
        const toml_str = randomMappingConfig(rng, &buf);
        if (toml_str.len == 0) continue;
        const result = mapping.parseString(allocator, toml_str) catch |err| {
            std.debug.print("Parse failed: {}\nTOML:\n{s}\n", .{ err, toml_str });
            return err;
        };
        defer result.deinit();
        mapping.validate(&result.value) catch |err| {
            std.debug.print("Validate failed: {}\nTOML:\n{s}\n", .{ err, toml_str });
            return err;
        };
    }
}
