// Validate E2E tests: device config validation, emulate presets, docgen, parseFile.
// Merged from phase4_e2e_test.zig (validate/emulate/docgen/parseFile) and
// phase6_e2e_test.zig (validate section).

const std = @import("std");
const testing = std.testing;

const device_mod = @import("../config/device.zig");
const validate_mod = @import("../tools/validate.zig");
const docgen_mod = @import("../tools/docgen.zig");
const helpers = @import("helpers.zig");
const collectTomlPaths = helpers.collectTomlPaths;
const freeTomlPaths = helpers.freeTomlPaths;

// --- 1. validate: all device configs pass with 0 errors ---

test "E2E validate: all device configs produce 0 errors" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);
    try testing.expect(paths.items.len >= 13);

    for (paths.items) |path| {
        const errors = try validate_mod.validateFile(path, allocator);
        defer validate_mod.freeErrors(errors, allocator);
        if (errors.len > 0) {
            for (errors) |e| std.debug.print("{s}: {s}\n", .{ path, e.message });
        }
        try testing.expectEqual(@as(usize, 0), errors.len);
    }
}

// --- 2. emulate: preset load and per-field override ---

const emulate_base =
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

test "E2E emulate: xbox-360 preset fills vid/pid/name/axes/buttons" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseString(allocator, emulate_base);
    defer parsed.deinit();
    const out = parsed.value.output.?;
    try testing.expectEqual(@as(?i64, 0x045e), out.vid);
    try testing.expectEqual(@as(?i64, 0x028e), out.pid);
    try testing.expectEqualStrings("Xbox 360 Controller", out.name.?);
    try testing.expect(out.axes != null);
    try testing.expect(out.buttons != null);
}

test "E2E emulate: explicit vid overrides preset, pid from preset" {
    const allocator = testing.allocator;
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
    const parsed = try device_mod.parseString(allocator, toml_str);
    defer parsed.deinit();
    const out = parsed.value.output.?;
    try testing.expectEqual(@as(?i64, 0xdead), out.vid);
    try testing.expectEqual(@as(?i64, 0x0ce6), out.pid);
}

test "E2E emulate: switch-pro preset axes count" {
    const allocator = testing.allocator;
    const toml_str =
        \\[device]
        \\name = "My Device"
        \\vid = 0x1111
        \\pid = 0x2222
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 4
        \\[output]
        \\emulate = "switch-pro"
    ;
    const parsed = try device_mod.parseString(allocator, toml_str);
    defer parsed.deinit();
    const out = parsed.value.output.?;
    try testing.expectEqual(@as(?i64, 0x057e), out.vid);
    const axes = out.axes orelse return error.NoAxes;
    // switch-pro has 4 axes: left_x/y, right_x/y
    try testing.expectEqual(@as(usize, 4), axes.map.count());
}

// --- 3. docgen: required sections present for a real config ---

test "E2E docgen: dualsense output contains required sections" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    try docgen_mod.generateDevicePage(&parsed.value, "sony", buf.writer(allocator));

    const out = buf.items;
    // H1 device name
    try testing.expect(std.mem.indexOf(u8, out, "# Sony DualSense") != null);
    // VID:PID line
    try testing.expect(std.mem.indexOf(u8, out, "0x054c:0x0ce6") != null);
    // Interfaces section
    try testing.expect(std.mem.indexOf(u8, out, "## Interfaces") != null);
    // Report section
    try testing.expect(std.mem.indexOf(u8, out, "## Report:") != null);
    // Fields subsection
    try testing.expect(std.mem.indexOf(u8, out, "### Fields") != null);
    // Button Map subsection
    try testing.expect(std.mem.indexOf(u8, out, "### Button Map") != null);
    // Commands section
    try testing.expect(std.mem.indexOf(u8, out, "## Commands") != null);
    // Output Capabilities section
    try testing.expect(std.mem.indexOf(u8, out, "## Output Capabilities") != null);
}

test "E2E docgen: vader5 output contains required sections" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();

    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    try docgen_mod.generateDevicePage(&parsed.value, "flydigi", buf.writer(allocator));

    const out = buf.items;
    try testing.expect(std.mem.indexOf(u8, out, "# Flydigi Vader 5 Pro") != null);
    try testing.expect(std.mem.indexOf(u8, out, "0x37d7:0x2401") != null);
    try testing.expect(std.mem.indexOf(u8, out, "## Interfaces") != null);
    try testing.expect(std.mem.indexOf(u8, out, "## Report:") != null);
    try testing.expect(std.mem.indexOf(u8, out, "## Commands") != null);
    try testing.expect(std.mem.indexOf(u8, out, "## Output Capabilities") != null);
}

// --- 4. parseFile: all 5 device configs load correctly ---

test "E2E parseFile: 8bitdo/ultimate.toml" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/8bitdo/ultimate.toml");
    defer parsed.deinit();
    const cfg = parsed.value;
    try testing.expectEqualStrings("8BitDo Ultimate Controller", cfg.device.name);
    try testing.expectEqual(@as(i64, 0x2dc8), cfg.device.vid);
    try testing.expectEqual(@as(i64, 0x6003), cfg.device.pid);
    try testing.expect(cfg.report.len >= 1);
}

test "E2E parseFile: flydigi/vader5.toml" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");
    defer parsed.deinit();
    const cfg = parsed.value;
    try testing.expectEqualStrings("Flydigi Vader 5 Pro", cfg.device.name);
    try testing.expectEqual(@as(i64, 0x37d7), cfg.device.vid);
    try testing.expectEqual(@as(i64, 0x2401), cfg.device.pid);
    try testing.expectEqual(@as(usize, 2), cfg.report.len);
}

test "E2E parseFile: microsoft/xbox-elite.toml" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/microsoft/xbox-elite.toml");
    defer parsed.deinit();
    const cfg = parsed.value;
    try testing.expectEqualStrings("Xbox Elite Series 2", cfg.device.name);
    try testing.expectEqual(@as(i64, 0x045e), cfg.device.vid);
    try testing.expectEqual(@as(i64, 0x0b00), cfg.device.pid);
    try testing.expect(cfg.report.len >= 1);
}

test "E2E parseFile: nintendo/switch-pro.toml" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/nintendo/switch-pro.toml");
    defer parsed.deinit();
    const cfg = parsed.value;
    try testing.expectEqualStrings("Nintendo Switch Pro Controller", cfg.device.name);
    try testing.expectEqual(@as(i64, 0x057e), cfg.device.vid);
    try testing.expectEqual(@as(i64, 0x2009), cfg.device.pid);
}

test "E2E parseFile: sony/dualsense.toml" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/sony/dualsense.toml");
    defer parsed.deinit();
    const cfg = parsed.value;
    try testing.expectEqualStrings("Sony DualSense", cfg.device.name);
    try testing.expectEqual(@as(i64, 0x054c), cfg.device.vid);
    try testing.expectEqual(@as(i64, 0x0ce6), cfg.device.pid);
    try testing.expect(cfg.report.len >= 1);
}

// --- 5. validate (from phase6): structural checks ---

test "validate: all device TOMLs have non-empty name" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);

    for (paths.items) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();
        try testing.expect(parsed.value.device.name.len > 0);
    }
}

test "validate: all device TOMLs have at least one report" {
    const allocator = testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer freeTomlPaths(allocator, &paths);

    for (paths.items) |path| {
        const parsed = try device_mod.parseFile(allocator, path);
        defer parsed.deinit();
        try testing.expect(parsed.value.report.len >= 1);
    }
}
