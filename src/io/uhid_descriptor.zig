//! UHID HID report descriptor builder — translates an `OutputConfig` into a
//! kernel-acceptable HID report descriptor byte stream.
//!
//! Phase 13 Wave 2 (T6). Wave 1 introduced `UhidDevice` in `src/io/uhid.zig`
//! which accepts a raw descriptor bytes blob; Wave 2 builds the production
//! path: given a device's `[output]` TOML (buttons, axes, dpad,
//! force_feedback, touchpad) produce the descriptor bytes. Wave 3 will wire
//! the builder into the supervisor; Wave 2 is pure builder + tests, with no
//! behavioural change to the supervisor path.
//!
//! ## Descriptor layout (baseline gamepad)
//!
//! We emit a single top-level Application Collection with Usage
//! `Game Pad` on Usage Page `Generic Desktop` — the canonical "xpad-style"
//! layout that Steam Input, SDL, and kernel `hid-generic` all accept.
//!
//! Input report (report ID 1, when multiple reports exist):
//!
//! 1. Face buttons — emitted as a Button Page bitmap.
//! 2. DPad — emitted as a 4-bit hat switch on Generic Desktop (Usage `Hat
//!    Switch`). Values 0..7 = N, NE, E, SE, S, SW, W, NW; 8 = neutral.
//! 3. Sticks — `ABS_X`/`ABS_Y`/`ABS_RX`/`ABS_RY` mapped to Usage
//!    `X`/`Y`/`Rx`/`Ry`, 16-bit signed with `Logical Minimum`
//!    /`Logical Maximum` taken from the `AxisConfig`.
//! 4. Triggers — `ABS_Z`/`ABS_RZ` → Usage `Z`/`Rz`, 8-bit unsigned 0..255.
//! 5. Touchpad — if `[output.touchpad]` present, emitted as a separate
//!    Logical Collection with `MT` (multi-touch) contact slots.
//!
//! Output report (if `[output.force_feedback]` is `rumble`):
//!
//! 6. A 3-byte Vendor-Defined output carrying `{report_id, strong_magnitude,
//!    weak_magnitude}` — the minimum the supervisor's Wave 3 rumble bridge
//!    will need. A full PID descriptor lands in Wave 6 (issue #82).
//!
//! ## Error handling
//!
//! `buildFromOutput` returns an owned `[]u8` on success. Callers must call
//! `allocator.free(desc)` on the returned slice. On failure the builder
//! reports:
//!   - `error.OutOfMemory` — ArrayList could not grow.
//!   - `error.DescriptorTooLarge` — emitted byte count exceeds
//!     `uhid.HID_MAX_DESCRIPTOR_SIZE` (4096 bytes). The builder refuses to
//!     hand back an oversized descriptor because `UHID_CREATE2` will reject
//!     it downstream.
//!   - `error.InvalidOutputConfig` — the `OutputConfig` is semantically
//!     unusable (e.g. no inputs and no FFB output, or axis/touchpad bounds
//!     outside the 32-bit signed range HID item encoding supports).

const std = @import("std");
const uhid = @import("uhid.zig");
const device = @import("../config/device.zig");

pub const BuildError = std.mem.Allocator.Error || error{
    DescriptorTooLarge,
    InvalidOutputConfig,
};

/// Input report ID used for the main gamepad report. Kept `1` so a simple
/// gamepad (no output/feature reports) could legally omit the ID prefix; we
/// still emit it for forward-compat with FFB output reports.
pub const INPUT_REPORT_ID: u8 = 1;

/// Output report ID used for the FFB rumble output report. 2 byte payload
/// `{strong_magnitude, weak_magnitude}` (both u8 0..255). Matches the layout
/// Wave 3's rumble bridge is expected to parse.
pub const FF_OUTPUT_REPORT_ID: u8 = 2;

/// Maximum touch contacts the builder will emit. Matches Steam Deck's
/// trackpad layout (2 trackpads). Touchpads requesting more slots fall back
/// to 2 — a warning would require a logger we don't want to pull into
/// build-time pure code, so we clamp silently.
pub const MAX_TOUCH_CONTACTS: u8 = 2;

// --- HID item encoding helpers ---------------------------------------------
//
// A HID short item is a 1-byte prefix followed by 0-4 payload bytes. The
// prefix encodes bSize (payload length), bType (main/global/local), and
// bTag (item tag). We emit hand-crafted prefix bytes matching USB HID 1.11
// §6.2.2.2 to keep the output byte-comparable to existing xbox-style
// descriptors that Steam Input already understands.

/// Emit a byte to the builder.
fn writeByte(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, b: u8) !void {
    try buf.append(allocator, b);
}

/// Emit a prefix byte followed by a little-endian 1-byte payload.
fn writeItem1(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: u8, v: u8) !void {
    try buf.append(allocator, prefix);
    try buf.append(allocator, v);
}

/// Emit a prefix byte followed by a little-endian 2-byte payload.
fn writeItem2(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: u8, v: u16) !void {
    try buf.append(allocator, prefix);
    try buf.append(allocator, @intCast(v & 0xFF));
    try buf.append(allocator, @intCast((v >> 8) & 0xFF));
}

/// Emit a prefix byte followed by a little-endian 4-byte payload.
fn writeItem4(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: u8, v: u32) !void {
    try buf.append(allocator, prefix);
    try buf.append(allocator, @intCast(v & 0xFF));
    try buf.append(allocator, @intCast((v >> 8) & 0xFF));
    try buf.append(allocator, @intCast((v >> 16) & 0xFF));
    try buf.append(allocator, @intCast((v >> 24) & 0xFF));
}

/// Emit a `Logical Minimum` / `Logical Maximum` pair. Picks the shortest
/// encoding that fits the signed value (1-byte, 2-byte, or 4-byte), which
/// matches what Linux's `hid-debug` decoder prints for xpad-style
/// descriptors.
fn writeLogicalMin(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, v: i32) !void {
    if (v >= -128 and v <= 127) {
        try writeItem1(buf, allocator, 0x15, @bitCast(@as(i8, @intCast(v))));
    } else if (v >= -32768 and v <= 32767) {
        try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, @intCast(v))));
    } else {
        try writeItem4(buf, allocator, 0x17, @bitCast(v));
    }
}

fn writeLogicalMax(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, v: i32) !void {
    if (v >= -128 and v <= 127) {
        try writeItem1(buf, allocator, 0x25, @bitCast(@as(i8, @intCast(v))));
    } else if (v >= -32768 and v <= 32767) {
        try writeItem2(buf, allocator, 0x26, @bitCast(@as(i16, @intCast(v))));
    } else {
        try writeItem4(buf, allocator, 0x27, @bitCast(v));
    }
}

// --- Axis mapping -----------------------------------------------------------

/// HID Usage (Generic Desktop page) for common axis codes. Returns null for
/// axis codes the baseline descriptor does not cover (e.g. `ABS_WHEEL`,
/// `ABS_HAT0X` — those are handled by separate dpad/wheel paths or deferred
/// to Wave 3+).
fn axisUsage(code: []const u8) ?u8 {
    if (std.mem.eql(u8, code, "ABS_X")) return 0x30;
    if (std.mem.eql(u8, code, "ABS_Y")) return 0x31;
    if (std.mem.eql(u8, code, "ABS_Z")) return 0x32;
    if (std.mem.eql(u8, code, "ABS_RX")) return 0x33;
    if (std.mem.eql(u8, code, "ABS_RY")) return 0x34;
    if (std.mem.eql(u8, code, "ABS_RZ")) return 0x35;
    return null;
}

// Axis routing is driven by HID Usage (see `buildFromOutput` axis pass).
// The previous `isSignedStickAxis(min, max)` heuristic is gone: it silently
// dropped DualSense-shape sticks (min=0 max=255 on X/Y/Rx/Ry) because those
// ranges fall into the trigger predicate, and trigger emission only iterated
// over ABS_Z/ABS_RZ.

// --- Builder ----------------------------------------------------------------

pub const UhidDescriptorBuilder = struct {
    /// Build a HID report descriptor from an `OutputConfig`. Returns owned
    /// bytes that the caller must free.
    ///
    /// The builder refuses to emit a completely empty descriptor: an
    /// `OutputConfig` with no buttons, no axes, no touchpad, and no
    /// force_feedback is rejected with `error.InvalidOutputConfig` — a
    /// zero-capability HID device cannot be sanely created. FFB-only
    /// configurations (force_feedback but no input collections) ARE
    /// permitted and will produce a valid descriptor.
    pub fn buildFromOutput(allocator: std.mem.Allocator, out: device.OutputConfig) BuildError![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);

        // --- Application Collection prologue ---
        try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
        try writeItem1(&buf, allocator, 0x09, 0x05); // Usage (Game Pad)
        try writeItem1(&buf, allocator, 0xA1, 0x01); // Collection (Application)

        // --- Report ID 1 = main input report ---
        try writeItem1(&buf, allocator, 0x85, INPUT_REPORT_ID);

        // Counts for sanity checks on an entirely empty descriptor.
        var emitted_any_input: bool = false;

        // --- 1. Face buttons (Button Page) ---
        const button_count: u8 = if (out.buttons) |b| blk: {
            const n = b.map.count();
            if (n > 64) break :blk 64;
            break :blk @intCast(n);
        } else 0;
        if (button_count > 0) {
            try writeItem1(&buf, allocator, 0x05, 0x09); // Usage Page (Button)
            try writeItem1(&buf, allocator, 0x19, 0x01); // Usage Minimum (1)
            try writeItem1(&buf, allocator, 0x29, button_count); // Usage Maximum (N)
            try writeItem1(&buf, allocator, 0x15, 0x00); // Logical Minimum (0)
            try writeItem1(&buf, allocator, 0x25, 0x01); // Logical Maximum (1)
            try writeItem1(&buf, allocator, 0x75, 0x01); // Report Size (1)
            try writeItem1(&buf, allocator, 0x95, button_count); // Report Count (N)
            try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)

            // Pad to a byte boundary if needed.
            const pad_bits: u8 = @intCast((8 - (@as(usize, button_count) % 8)) % 8);
            if (pad_bits != 0) {
                try writeItem1(&buf, allocator, 0x75, 0x01);
                try writeItem1(&buf, allocator, 0x95, pad_bits);
                try writeItem1(&buf, allocator, 0x81, 0x03); // Input (Const, Var, Abs) — padding
            }
            emitted_any_input = true;
        }

        // --- 2. DPad (hat switch) ---
        const has_hat_dpad: bool = if (out.dpad) |d|
            std.mem.eql(u8, d.type, "hat")
        else
            false;
        if (has_hat_dpad) {
            try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
            try writeItem1(&buf, allocator, 0x09, 0x39); // Usage (Hat switch)
            try writeItem1(&buf, allocator, 0x15, 0x00); // Logical Minimum (0)
            try writeItem1(&buf, allocator, 0x25, 0x07); // Logical Maximum (7)
            try writeItem1(&buf, allocator, 0x35, 0x00); // Physical Minimum (0)
            try writeItem2(&buf, allocator, 0x46, 0x013B); // Physical Maximum (315 degrees)
            try writeItem1(&buf, allocator, 0x65, 0x14); // Unit (Eng Rot: Degrees)
            try writeItem1(&buf, allocator, 0x75, 0x04); // Report Size (4)
            try writeItem1(&buf, allocator, 0x95, 0x01); // Report Count (1)
            try writeItem1(&buf, allocator, 0x81, 0x42); // Input (Data, Var, Abs, Null)
            // Clear unit so following axes aren't forced into degrees.
            try writeItem1(&buf, allocator, 0x65, 0x00); // Unit (None)
            // 4-bit padding to realign to a byte boundary.
            try writeItem1(&buf, allocator, 0x75, 0x04);
            try writeItem1(&buf, allocator, 0x95, 0x01);
            try writeItem1(&buf, allocator, 0x81, 0x03); // Input (Const)
            emitted_any_input = true;
        }

        // --- 3 + 4. Axes: sticks (16-bit signed) then triggers (8-bit unsigned) ---
        //
        // Routing is driven by the HID Usage (X/Y/Rx/Ry → stick; Z/Rz →
        // trigger), NOT by `min`/`max`. Presets such as DualSense declare
        // sticks as 0..255, and the pre-fix `isSignedStickAxis` heuristic
        // silently dropped those axes. Axis ranges that do not fit into
        // `i32` are rejected with `error.InvalidOutputConfig` rather than
        // panicking at `@intCast`.
        //
        // Emission order is fixed (stick_order first, then trigger_order)
        // to keep the golden-file byte stream deterministic regardless of
        // TOML insertion order.
        if (out.axes) |axes| {
            const stick_order = [_][]const u8{ "ABS_X", "ABS_Y", "ABS_RX", "ABS_RY" };
            var sticks_emitted: u32 = 0;
            for (stick_order) |want| {
                var it = axes.map.iterator();
                while (it.next()) |entry| {
                    const cfg = entry.value_ptr.*;
                    if (!std.mem.eql(u8, cfg.code, want)) continue;
                    const usage = axisUsage(cfg.code) orelse unreachable; // stick_order codes always map
                    const min_i32 = std.math.cast(i32, cfg.min) orelse return error.InvalidOutputConfig;
                    const max_i32 = std.math.cast(i32, cfg.max) orelse return error.InvalidOutputConfig;

                    try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
                    try writeItem1(&buf, allocator, 0x09, usage); // Usage
                    try writeLogicalMin(&buf, allocator, min_i32);
                    try writeLogicalMax(&buf, allocator, max_i32);
                    try writeItem1(&buf, allocator, 0x75, 0x10); // Report Size (16)
                    try writeItem1(&buf, allocator, 0x95, 0x01); // Report Count (1)
                    try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)
                    sticks_emitted += 1;
                    break;
                }
            }

            const trigger_order = [_][]const u8{ "ABS_Z", "ABS_RZ" };
            var triggers_emitted: u32 = 0;
            for (trigger_order) |want| {
                var it = axes.map.iterator();
                while (it.next()) |entry| {
                    const cfg = entry.value_ptr.*;
                    if (!std.mem.eql(u8, cfg.code, want)) continue;
                    const usage = axisUsage(cfg.code) orelse unreachable; // trigger_order codes always map
                    // Trigger Logical Min/Max are fixed 0..255 on the wire
                    // regardless of the TOML `min`/`max` — those are only
                    // used by the supervisor to scale input events. Still
                    // guard the i64→i32 cast so malformed configs surface as
                    // InvalidOutputConfig rather than panicking.
                    _ = std.math.cast(i32, cfg.min) orelse return error.InvalidOutputConfig;
                    _ = std.math.cast(i32, cfg.max) orelse return error.InvalidOutputConfig;

                    try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
                    try writeItem1(&buf, allocator, 0x09, usage); // Usage
                    try writeItem1(&buf, allocator, 0x15, 0x00); // Logical Minimum (0)
                    try writeItem2(&buf, allocator, 0x26, 0x00FF); // Logical Maximum (255)
                    try writeItem1(&buf, allocator, 0x75, 0x08); // Report Size (8)
                    try writeItem1(&buf, allocator, 0x95, 0x01); // Report Count (1)
                    try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)
                    triggers_emitted += 1;
                    break;
                }
            }
            if (sticks_emitted != 0 or triggers_emitted != 0) emitted_any_input = true;
        }

        // --- 5. Touchpad (separate Logical Collection, multi-touch digitizer) ---
        if (out.touchpad) |tp| {
            const x_min = std.math.cast(i32, tp.x_min) orelse return error.InvalidOutputConfig;
            const x_max = std.math.cast(i32, tp.x_max) orelse return error.InvalidOutputConfig;
            const y_min = std.math.cast(i32, tp.y_min) orelse return error.InvalidOutputConfig;
            const y_max = std.math.cast(i32, tp.y_max) orelse return error.InvalidOutputConfig;
            const slots_raw: u8 = if (tp.max_slots) |s| @intCast(@min(@max(s, 1), MAX_TOUCH_CONTACTS)) else MAX_TOUCH_CONTACTS;

            try writeItem1(&buf, allocator, 0x05, 0x0D); // Usage Page (Digitizer)
            try writeItem1(&buf, allocator, 0x09, 0x05); // Usage (Touch Pad)
            try writeItem1(&buf, allocator, 0xA1, 0x02); // Collection (Logical)

            var i: u8 = 0;
            while (i < slots_raw) : (i += 1) {
                try writeItem1(&buf, allocator, 0x09, 0x22); // Usage (Finger)
                try writeItem1(&buf, allocator, 0xA1, 0x02); // Collection (Logical)

                // Contact state (tip switch, 1 bit) + 7 bits padding.
                try writeItem1(&buf, allocator, 0x09, 0x42); // Usage (Tip Switch)
                try writeItem1(&buf, allocator, 0x15, 0x00);
                try writeItem1(&buf, allocator, 0x25, 0x01);
                try writeItem1(&buf, allocator, 0x75, 0x01);
                try writeItem1(&buf, allocator, 0x95, 0x01);
                try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)
                try writeItem1(&buf, allocator, 0x75, 0x07);
                try writeItem1(&buf, allocator, 0x95, 0x01);
                try writeItem1(&buf, allocator, 0x81, 0x03); // Input (Const) — padding

                // X coordinate (16-bit signed).
                try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
                try writeItem1(&buf, allocator, 0x09, 0x30); // Usage (X)
                try writeLogicalMin(&buf, allocator, x_min);
                try writeLogicalMax(&buf, allocator, x_max);
                try writeItem1(&buf, allocator, 0x75, 0x10);
                try writeItem1(&buf, allocator, 0x95, 0x01);
                try writeItem1(&buf, allocator, 0x81, 0x02);

                // Y coordinate (16-bit signed).
                try writeItem1(&buf, allocator, 0x09, 0x31); // Usage (Y)
                try writeLogicalMin(&buf, allocator, y_min);
                try writeLogicalMax(&buf, allocator, y_max);
                try writeItem1(&buf, allocator, 0x75, 0x10);
                try writeItem1(&buf, allocator, 0x95, 0x01);
                try writeItem1(&buf, allocator, 0x81, 0x02);

                try writeItem1(&buf, allocator, 0x05, 0x0D); // back to Digitizer page
                try writeByte(&buf, allocator, 0xC0); // End Collection (Finger)
            }
            try writeByte(&buf, allocator, 0xC0); // End Collection (Touch Pad)
            emitted_any_input = true;
        }

        // --- 6. Force feedback output report (rumble minimal) ---
        //
        // A well-formed FFB-only `OutputConfig` (no buttons/axes/touchpad,
        // only `[output.force_feedback]`) is legal per the module docstring
        // — the builder must still produce a descriptor the kernel accepts.
        // We therefore track "something was emitted" rather than
        // "something on the input side was emitted".
        var emitted_any: bool = emitted_any_input;
        if (out.force_feedback) |ff| {
            if (std.mem.eql(u8, ff.type, "rumble")) {
                // A placeholder vendor-defined 2-byte output report that the
                // Wave 3 supervisor can parse as {strong, weak} magnitudes.
                // The PID descriptor for FFB lands in Wave 6; this minimal
                // stub is enough for the kernel `UHID_CREATE2` to accept the
                // descriptor + for the rumble path to exist in Wave 3.
                try writeItem2(&buf, allocator, 0x06, 0xFF00); // Usage Page (Vendor-Defined 0xFF00)
                try writeItem1(&buf, allocator, 0x85, FF_OUTPUT_REPORT_ID);
                try writeItem1(&buf, allocator, 0x09, 0x01); // Usage (Vendor Usage 1)
                try writeItem1(&buf, allocator, 0x15, 0x00); // Logical Minimum (0)
                try writeItem2(&buf, allocator, 0x26, 0x00FF); // Logical Maximum (255)
                try writeItem1(&buf, allocator, 0x75, 0x08); // Report Size (8)
                try writeItem1(&buf, allocator, 0x95, 0x02); // Report Count (2) — strong + weak
                try writeItem1(&buf, allocator, 0x91, 0x02); // Output (Data, Var, Abs)
                emitted_any = true;
            }
        }

        // --- End Application Collection ---
        try writeByte(&buf, allocator, 0xC0);

        if (!emitted_any) return error.InvalidOutputConfig;
        if (buf.items.len > uhid.HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;

        return buf.toOwnedSlice(allocator);
    }
};

// ---------------------------------------------------------------------------
// Tests — kept in-module so new contributors reading `uhid_descriptor.zig`
// see the contract next to the implementation. Layer 0/1 tests (pure
// byte-level), no `/dev/uhid` required.
// ---------------------------------------------------------------------------

const testing = std.testing;
const toml = @import("toml");

fn makeAxesMap(allocator: std.mem.Allocator, entries: []const struct {
    name: []const u8,
    cfg: device.AxisConfig,
}) !toml.HashMap(device.AxisConfig) {
    var map = std.StringHashMap(device.AxisConfig).init(allocator);
    errdefer map.deinit();
    for (entries) |e| {
        const key = try allocator.dupe(u8, e.name);
        try map.put(key, e.cfg);
    }
    return .{ .map = map };
}

fn makeButtonsMap(allocator: std.mem.Allocator, entries: []const struct {
    name: []const u8,
    code: []const u8,
}) !toml.HashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer map.deinit();
    for (entries) |e| {
        const key = try allocator.dupe(u8, e.name);
        const code = try allocator.dupe(u8, e.code);
        try map.put(key, code);
    }
    return .{ .map = map };
}

test "descriptor: empty config (no buttons, no axes, no touchpad) is rejected" {
    const alloc = testing.allocator;
    const out = device.OutputConfig{ .name = "empty" };
    try testing.expectError(error.InvalidOutputConfig, UhidDescriptorBuilder.buildFromOutput(alloc, out));
}

test "descriptor: minimal gamepad (2 buttons + 1 stick axis pair) produces valid bytes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
        .{ .name = "left_y", .cfg = .{ .code = "ABS_Y", .min = -32768, .max = 32767 } },
    });
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
        .{ .name = "B", .code = "BTN_EAST" },
    });

    const out = device.OutputConfig{
        .name = "test",
        .vid = 0x28de,
        .pid = 0x1205,
        .axes = axes,
        .buttons = buttons,
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Prologue must be Usage Page (Generic Desktop), Usage (Game Pad),
    // Collection (Application), Report ID (1).
    try testing.expect(desc.len >= 9);
    try testing.expectEqual(@as(u8, 0x05), desc[0]);
    try testing.expectEqual(@as(u8, 0x01), desc[1]);
    try testing.expectEqual(@as(u8, 0x09), desc[2]);
    try testing.expectEqual(@as(u8, 0x05), desc[3]);
    try testing.expectEqual(@as(u8, 0xA1), desc[4]);
    try testing.expectEqual(@as(u8, 0x01), desc[5]);
    try testing.expectEqual(@as(u8, 0x85), desc[6]);
    try testing.expectEqual(@as(u8, INPUT_REPORT_ID), desc[7]);

    // Ends with End Collection (0xC0).
    try testing.expectEqual(@as(u8, 0xC0), desc[desc.len - 1]);

    // Reasonable size bounds.
    try testing.expect(desc.len < uhid.HID_MAX_DESCRIPTOR_SIZE);
}

test "descriptor: button count padding rounds to byte boundary" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // 3 buttons → needs 5 bits of padding to reach 1 byte.
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
        .{ .name = "B", .code = "BTN_EAST" },
        .{ .name = "X", .code = "BTN_WEST" },
    });
    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "three-button",
        .axes = axes,
        .buttons = buttons,
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Search for the Button Page (0x05, 0x09) and verify the padding item
    // sequence (Report Size 1, Report Count 5, Input Const) follows the
    // button Input item.
    var i: usize = 0;
    var found_button_page = false;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x05 and desc[i + 1] == 0x09) {
            found_button_page = true;
            break;
        }
    }
    try testing.expect(found_button_page);
}

test "descriptor: emits Hat switch when dpad.type = hat" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "hat-dpad",
        .axes = axes,
        .dpad = .{ .type = "hat" },
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Search for Usage (Hat switch) = 0x09 0x39.
    var i: usize = 0;
    var found = false;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x09 and desc[i + 1] == 0x39) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "descriptor: emits Vendor Output collection when force_feedback.type = rumble" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "ffb-gamepad",
        .axes = axes,
        .force_feedback = .{ .type = "rumble", .max_effects = 4 },
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Look for the Vendor-Defined Usage Page prefix (0x06, 0x00, 0xFF).
    var i: usize = 0;
    var found = false;
    while (i + 2 < desc.len) : (i += 1) {
        if (desc[i] == 0x06 and desc[i + 1] == 0x00 and desc[i + 2] == 0xFF) {
            found = true;
            break;
        }
    }
    try testing.expect(found);

    // Look for Output (Data, Var, Abs) = 0x91 0x02.
    i = 0;
    var found_output = false;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x91 and desc[i + 1] == 0x02) {
            found_output = true;
            break;
        }
    }
    try testing.expect(found_output);
}

test "descriptor: emits touchpad digitizer collection when output.touchpad set" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "touch-gamepad",
        .axes = axes,
        .touchpad = .{
            .name = "pad",
            .x_min = -32768,
            .x_max = 32767,
            .y_min = -32768,
            .y_max = 32767,
            .max_slots = 2,
        },
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Digitizer Usage Page is 0x0D.
    var i: usize = 0;
    var found_digitizer = false;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x05 and desc[i + 1] == 0x0D) {
            found_digitizer = true;
            break;
        }
    }
    try testing.expect(found_digitizer);
}

test "descriptor: matches golden fixture for Steam Deck output" {
    const alloc = testing.allocator;
    const parsed = try device.parseFile(alloc, "devices/valve/steam-deck.toml");
    defer parsed.deinit();

    const out = parsed.value.output orelse return error.MissingOutputSection;
    const desc = try UhidDescriptorBuilder.buildFromOutput(alloc, out);
    defer alloc.free(desc);

    const golden = try std.fs.cwd().readFileAlloc(
        alloc,
        "src/test/fixtures/golden/steam_deck_hid_descriptor.bin",
        65536,
    );
    defer alloc.free(golden);

    try testing.expectEqualSlices(u8, golden, desc);
}

test "descriptor: fits within HID_MAX_DESCRIPTOR_SIZE for Steam Deck" {
    const alloc = testing.allocator;
    const parsed = try device.parseFile(alloc, "devices/valve/steam-deck.toml");
    defer parsed.deinit();
    const out = parsed.value.output orelse return error.MissingOutputSection;

    const desc = try UhidDescriptorBuilder.buildFromOutput(alloc, out);
    defer alloc.free(desc);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
}

test "descriptor: xbox-360 preset-shaped config produces byte-valid descriptor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
        .{ .name = "left_y", .cfg = .{ .code = "ABS_Y", .min = -32768, .max = 32767 } },
        .{ .name = "right_x", .cfg = .{ .code = "ABS_RX", .min = -32768, .max = 32767 } },
        .{ .name = "right_y", .cfg = .{ .code = "ABS_RY", .min = -32768, .max = 32767 } },
        .{ .name = "lt", .cfg = .{ .code = "ABS_Z", .min = 0, .max = 255 } },
        .{ .name = "rt", .cfg = .{ .code = "ABS_RZ", .min = 0, .max = 255 } },
    });
    const buttons = try makeButtonsMap(a, &.{
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
    });

    const out = device.OutputConfig{
        .name = "Xbox 360 Controller",
        .vid = 0x045e,
        .pid = 0x028e,
        .axes = axes,
        .buttons = buttons,
        .dpad = .{ .type = "hat" },
        .force_feedback = .{ .type = "rumble" },
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    try testing.expect(desc.len > 0);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
    // First two bytes: Usage Page (Generic Desktop).
    try testing.expectEqual(@as(u8, 0x05), desc[0]);
    try testing.expectEqual(@as(u8, 0x01), desc[1]);
    // Last byte: End Collection.
    try testing.expectEqual(@as(u8, 0xC0), desc[desc.len - 1]);
}

test "descriptor: reject > UHID_DATA_MAX via excessive button count is capped to 64" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // Create 100 button entries; builder should cap at 64.
    var entries: [100]struct { name: []const u8, code: []const u8 } = undefined;
    var name_buf: [100][16]u8 = undefined;
    for (&entries, 0..) |*e, i| {
        const n = std.fmt.bufPrint(&name_buf[i], "B{d}", .{i}) catch unreachable;
        e.* = .{ .name = n, .code = "BTN_SOUTH" };
    }
    const buttons = try makeButtonsMap(a, &entries);
    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "big",
        .axes = axes,
        .buttons = buttons,
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
}

// --- Regression tests for CodeRabbit PR #132 findings ------------------------
// Each test exercises a failure mode that was silent (axis drop, unchecked
// @intCast) or contradicted the docstring (FFB-only rejection) in the
// pre-fix builder.

test "descriptor: DualSense-shape X/Y/RX/RY with min=0 max=255 emits all four usages" {
    // Regression for silent axis drop: a DualSense-shape config where
    // X/Y/RX/RY use unsigned 0..255 must still emit four stick axes, routed
    // by HID Usage rather than min/max heuristic.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = 0, .max = 255 } },
        .{ .name = "left_y", .cfg = .{ .code = "ABS_Y", .min = 0, .max = 255 } },
        .{ .name = "right_x", .cfg = .{ .code = "ABS_RX", .min = 0, .max = 255 } },
        .{ .name = "right_y", .cfg = .{ .code = "ABS_RY", .min = 0, .max = 255 } },
    });
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
    });
    const out = device.OutputConfig{
        .name = "dualsense-shape",
        .axes = axes,
        .buttons = buttons,
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // For each of the four Generic Desktop Usages (X=0x30, Y=0x31, Rx=0x33,
    // Ry=0x34) we expect a `0x09 <usage>` Usage item to appear somewhere in
    // the descriptor. (0x09 is the 1-byte Usage prefix on the current Usage
    // Page; the builder switches back to Generic Desktop before each axis.)
    const wanted_usages = [_]u8{ 0x30, 0x31, 0x33, 0x34 };
    for (wanted_usages) |u| {
        var found = false;
        var i: usize = 0;
        while (i + 1 < desc.len) : (i += 1) {
            if (desc[i] == 0x09 and desc[i + 1] == u) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

test "descriptor: out-of-range i64 axis min returns InvalidOutputConfig instead of panicking" {
    // Regression for unchecked @intCast(i64→i32): malformed TOML with an
    // axis min/max outside i32 range must be rejected cleanly rather than
    // panicking in safe builds.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = std.math.maxInt(i64), .max = std.math.maxInt(i64) } },
    });
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
    });
    const out = device.OutputConfig{
        .name = "bad-axis",
        .axes = axes,
        .buttons = buttons,
    };

    try testing.expectError(
        error.InvalidOutputConfig,
        UhidDescriptorBuilder.buildFromOutput(testing.allocator, out),
    );
}

test "descriptor: FFB-only output (no input buttons/axes) produces a valid descriptor" {
    // The module docstring states an OutputConfig with force_feedback but no
    // inputs must still yield a descriptor. The pre-fix code bookkept only
    // input-side emission, so FFB-only outputs were wrongly rejected.
    const out = device.OutputConfig{
        .name = "ffb-only",
        .force_feedback = .{ .type = "rumble" },
    };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    try testing.expect(desc.len > 0);
    try testing.expectEqual(@as(u8, 0xC0), desc[desc.len - 1]);
    // The FFB branch must have emitted the Vendor-Defined Usage Page.
    var i: usize = 0;
    var found = false;
    while (i + 2 < desc.len) : (i += 1) {
        if (desc[i] == 0x06 and desc[i + 1] == 0x00 and desc[i + 2] == 0xFF) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}
