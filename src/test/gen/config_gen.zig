const std = @import("std");
const device = @import("../../config/device.zig");
const mapping = @import("../../config/mapping.zig");

const FieldTag = @import("../../core/interpreter.zig").FieldTag;
const ButtonId = @import("../../core/state.zig").ButtonId;

// --- Device config generation ---

const field_tags = [_][]const u8{ "left_x", "left_y", "right_x", "right_y", "lt", "rt", "gyro_x", "gyro_y", "gyro_z", "accel_x", "accel_y", "accel_z" };
const field_types_16 = [_][]const u8{ "i16le", "u16le" };
const field_types_8 = [_][]const u8{ "u8", "i8" };
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

    // Generate 3-8 fields with non-overlapping offsets
    const n_fields = rng.intRangeAtMost(u8, 3, @min(8, @as(u8, @intCast(field_tags.len))));
    var used: [12]bool = .{false} ** 12;
    var next_offset: u8 = 1; // skip match byte

    for (0..n_fields) |_| {
        const idx = pickUnused(rng, &used, field_tags.len);
        const tag = field_tags[idx];
        const is_trigger = std.mem.eql(u8, tag, "lt") or std.mem.eql(u8, tag, "rt");
        const type_str = if (is_trigger)
            field_types_8[rng.intRangeAtMost(usize, 0, field_types_8.len - 1)]
        else
            field_types_16[rng.intRangeAtMost(usize, 0, field_types_16.len - 1)];
        const size: u8 = if (is_trigger) 1 else 2;
        if (next_offset + size > report_size) break;
        const offset = next_offset;
        next_offset += size;

        if (rng.boolean()) {
            const tr = transforms[rng.intRangeAtMost(usize, 0, transforms.len - 1)];
            w.print("{s} = {{ offset = {d}, type = \"{s}\", transform = \"{s}\" }}\n", .{ tag, offset, type_str, tr }) catch break;
        } else {
            w.print("{s} = {{ offset = {d}, type = \"{s}\" }}\n", .{ tag, offset, type_str }) catch break;
        }
    }

    // Optional button_group
    if (rng.boolean() and next_offset + 2 <= report_size) {
        const bg_offset = next_offset;
        const bg_size: u8 = @min(4, report_size - next_offset);
        w.print("[report.button_group]\nsource = {{ offset = {d}, size = {d} }}\nmap = {{ ", .{ bg_offset, bg_size }) catch return fbs.getPos() catch return buf[0..0];
        const n_btns = rng.intRangeAtMost(u8, 2, @min(4, bg_size * 8));
        var btn_used: [21]bool = .{false} ** 21;
        for (0..n_btns) |i| {
            const bi = pickUnused(rng, &btn_used, button_names.len);
            if (i > 0) w.writeAll(", ") catch break;
            w.print("{s} = {d}", .{ button_names[bi], i }) catch break;
        }
        w.writeAll(" }\n") catch {};
    }

    return buf[0..fbs.pos];
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
const remap_targets = [_][]const u8{ "A", "B", "X", "Y", "KEY_F1", "KEY_F2", "KEY_F13", "mouse_left", "mouse_right", "disabled" };
const layer_triggers = [_][]const u8{ "LT", "RT", "Select", "Start", "Home", "LM", "RM" };
const layer_names = [_][]const u8{ "aim", "fn", "alt", "nav" };
const gyro_modes = [_][]const u8{ "mouse", "off" };
const dpad_modes = [_][]const u8{ "arrows", "gamepad" };

pub fn randomMappingConfig(rng: std.Random, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();

    // Base remaps: 2-4
    const n_remaps = rng.intRangeAtMost(u8, 2, 4);
    w.writeAll("[remap]\n") catch return buf[0..0];
    var src_used: [12]bool = .{false} ** 12;
    for (0..n_remaps) |_| {
        const si = pickUnused(rng, &src_used, remap_sources.len);
        const ti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
        w.print("{s} = \"{s}\"\n", .{ remap_sources[si], remap_targets[ti] }) catch break;
    }

    // Layers: 0-2
    const n_layers = rng.intRangeAtMost(u8, 0, 2);
    var trigger_used: [7]bool = .{false} ** 7;
    for (0..n_layers) |li| {
        const ti = pickUnused(rng, &trigger_used, layer_triggers.len);
        const name = layer_names[li];
        const activation: []const u8 = if (rng.boolean()) "hold" else "toggle";
        w.print("\n[[layer]]\nname = \"{s}\"\ntrigger = \"{s}\"\nactivation = \"{s}\"\n", .{ name, layer_triggers[ti], activation }) catch break;
        if (std.mem.eql(u8, activation, "hold") and rng.boolean()) {
            const timeout = rng.intRangeAtMost(u16, 100, 500);
            w.print("hold_timeout = {d}\n", .{timeout}) catch {};
        }
        // 1-3 layer remaps
        const n_lr = rng.intRangeAtMost(u8, 1, 3);
        w.writeAll("[layer.remap]\n") catch {};
        var lsrc_used: [12]bool = .{false} ** 12;
        for (0..n_lr) |_| {
            const lsi = pickUnused(rng, &lsrc_used, remap_sources.len);
            const lti = rng.intRangeAtMost(usize, 0, remap_targets.len - 1);
            w.print("{s} = \"{s}\"\n", .{ remap_sources[lsi], remap_targets[lti] }) catch break;
        }
    }

    // Optional dpad
    if (rng.boolean()) {
        const dm = dpad_modes[rng.intRangeAtMost(usize, 0, dpad_modes.len - 1)];
        w.print("\n[dpad]\nmode = \"{s}\"\n", .{dm}) catch {};
    }

    // Optional gyro
    if (rng.boolean()) {
        const gm = gyro_modes[rng.intRangeAtMost(usize, 0, gyro_modes.len - 1)];
        w.print("\n[gyro]\nmode = \"{s}\"\n", .{gm}) catch {};
        if (std.mem.eql(u8, gm, "mouse") and rng.boolean()) {
            w.writeAll("activate = \"hold_RB\"\n") catch {};
        }
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
