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
const state_mod = @import("../core/state.zig");

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
// Input report encoder — mirrors the descriptor layout byte-for-byte.
// ---------------------------------------------------------------------------

/// Max bytes `encodeReport` will ever emit. Sized to cover an input report ID
/// byte + 64-bit button bitmap (cap in `buildFromOutput`) + 1-byte hat + four
/// i16 sticks + two u8 triggers + two 5-byte touch contacts. 32 bytes is
/// comfortably larger than any baseline gamepad the builder accepts; the
/// boundary is pinned by a descriptor-driven unit test.
pub const MAX_REPORT_BYTES: usize = 32;

pub const EncodeError = error{ReportTooLong};

/// Stable HID-bit-index → `state_mod.ButtonId` assignment. The builder's
/// button pass emits `Usage Minimum 1, Usage Maximum button_count`; the
/// encoder walks `ButtonId` in declaration order and packs a 1-bit entry for
/// each id that appears in `cfg.buttons`. Determinism matters: SDL assumes
/// a stable ordering between descriptor enumeration and report payload.
fn buttonIdSlot(cfg: device.OutputConfig, bit_idx: u8) ?state_mod.ButtonId {
    const buttons = cfg.buttons orelse return null;
    var slot: u8 = 0;
    inline for (@typeInfo(state_mod.ButtonId).@"enum".fields) |f| {
        if (buttons.map.contains(f.name)) {
            if (slot == bit_idx) return @enumFromInt(f.value);
            slot += 1;
        }
    }
    return null;
}

/// Number of buttons the builder declares — mirrors the `map.count()` +
/// 64-cap path in `buildFromOutput` so encoder and descriptor stay in sync.
fn buttonCount(cfg: device.OutputConfig) u8 {
    const buttons = cfg.buttons orelse return 0;
    const n = buttons.map.count();
    return if (n > 64) 64 else @intCast(n);
}

fn axisWithCode(cfg: device.OutputConfig, code: []const u8) ?device.AxisConfig {
    const axes = cfg.axes orelse return null;
    var it = axes.map.iterator();
    while (it.next()) |entry| {
        if (std.mem.eql(u8, entry.value_ptr.code, code)) return entry.value_ptr.*;
    }
    return null;
}

/// Translate (dpad_x, dpad_y) into a 4-bit hat value matching the descriptor's
/// Logical Maximum 7 (N, NE, E, SE, S, SW, W, NW; neutral = 8).
fn hatValue(gs: state_mod.GamepadState) u4 {
    const x = gs.dpad_x;
    const y = gs.dpad_y;
    if (x == 0 and y == -1) return 0;
    if (x == 1 and y == -1) return 1;
    if (x == 1 and y == 0) return 2;
    if (x == 1 and y == 1) return 3;
    if (x == 0 and y == 1) return 4;
    if (x == -1 and y == 1) return 5;
    if (x == -1 and y == 0) return 6;
    if (x == -1 and y == -1) return 7;
    return 8;
}

/// Encode a `GamepadState` into a wire-format HID input report matching the
/// bytes the descriptor produced by `UhidDescriptorBuilder.buildFromOutput`
/// describes. First byte is always `INPUT_REPORT_ID`. Layout follows the
/// same section order as the descriptor: buttons → hat → sticks → triggers
/// → touchpad. Sections absent from `cfg` are simply skipped — the resulting
/// byte length is the sum of declared section widths.
///
/// Owned by the caller. `buf` must have capacity >= `MAX_REPORT_BYTES`.
/// Returns the slice of `buf` that was populated.
pub fn encodeReport(
    cfg: device.OutputConfig,
    gs: state_mod.GamepadState,
    buf: []u8,
) EncodeError![]u8 {
    if (buf.len < MAX_REPORT_BYTES) return error.ReportTooLong;
    @memset(buf, 0);

    var pos: usize = 0;
    buf[pos] = INPUT_REPORT_ID;
    pos += 1;

    // --- Button bitmap ---
    const btn_count = buttonCount(cfg);
    if (btn_count > 0) {
        const btn_bytes: usize = (@as(usize, btn_count) + 7) / 8;
        var i: u8 = 0;
        while (i < btn_count) : (i += 1) {
            const slot = buttonIdSlot(cfg, i) orelse continue;
            const mask: u64 = @as(u64, 1) << @intFromEnum(slot);
            if ((gs.buttons & mask) != 0) {
                const byte_idx = pos + (@as(usize, i) / 8);
                const bit_pos: u3 = @intCast(i % 8);
                buf[byte_idx] |= @as(u8, 1) << bit_pos;
            }
        }
        pos += btn_bytes;
    }

    // --- Hat (4-bit + 4-bit padding packed into one byte) ---
    const has_hat: bool = if (cfg.dpad) |d| std.mem.eql(u8, d.type, "hat") else false;
    if (has_hat) {
        buf[pos] = @as(u8, hatValue(gs)) & 0x0F;
        pos += 1;
    }

    // --- Sticks (fixed order) ---
    const stick_order = [_]struct { code: []const u8, field: enum { ax, ay, rx, ry } }{
        .{ .code = "ABS_X", .field = .ax },
        .{ .code = "ABS_Y", .field = .ay },
        .{ .code = "ABS_RX", .field = .rx },
        .{ .code = "ABS_RY", .field = .ry },
    };
    for (stick_order) |s| {
        if (axisWithCode(cfg, s.code) == null) continue;
        const v: i16 = switch (s.field) {
            .ax => gs.ax,
            .ay => gs.ay,
            .rx => gs.rx,
            .ry => gs.ry,
        };
        std.mem.writeInt(i16, buf[pos..][0..2], v, .little);
        pos += 2;
    }

    // --- Triggers (fixed order) ---
    const trigger_order = [_]struct { code: []const u8, field: enum { lt, rt } }{
        .{ .code = "ABS_Z", .field = .lt },
        .{ .code = "ABS_RZ", .field = .rt },
    };
    for (trigger_order) |t| {
        if (axisWithCode(cfg, t.code) == null) continue;
        buf[pos] = switch (t.field) {
            .lt => gs.lt,
            .rt => gs.rt,
        };
        pos += 1;
    }

    // --- Touchpad (per-finger tip + X + Y) ---
    if (cfg.touchpad) |_| {
        const finger0 = [_]struct { active: bool, x: i16, y: i16 }{
            .{ .active = gs.touch0_active, .x = gs.touch0_x, .y = gs.touch0_y },
            .{ .active = gs.touch1_active, .x = gs.touch1_x, .y = gs.touch1_y },
        };
        for (finger0) |f| {
            if (pos + 5 > buf.len) return error.ReportTooLong;
            buf[pos] = if (f.active) 1 else 0;
            pos += 1;
            std.mem.writeInt(i16, buf[pos..][0..2], f.x, .little);
            pos += 2;
            std.mem.writeInt(i16, buf[pos..][0..2], f.y, .little);
            pos += 2;
        }
    }

    return buf[0..pos];
}

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

// --- encodeReport tests (H3 regression) ------------------------------------

test "encodeReport: buttons + stick pair + triggers pack in declared order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
        .{ .name = "left_y", .cfg = .{ .code = "ABS_Y", .min = -32768, .max = 32767 } },
        .{ .name = "lt", .cfg = .{ .code = "ABS_Z", .min = 0, .max = 255 } },
        .{ .name = "rt", .cfg = .{ .code = "ABS_RZ", .min = 0, .max = 255 } },
    });
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
        .{ .name = "B", .code = "BTN_EAST" },
        .{ .name = "X", .code = "BTN_WEST" },
    });
    const out = device.OutputConfig{
        .name = "layout-test",
        .axes = axes,
        .buttons = buttons,
    };

    // Build descriptor to measure the declared input report width and sanity
    // -check the encoder stays within it.
    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    // Press A (bit 0) and X (bit 2); lt=100, rt=200, ax=1234, ay=-1.
    var gs = state_mod.GamepadState{};
    gs.buttons = (@as(u64, 1) << @intFromEnum(state_mod.ButtonId.A)) |
        (@as(u64, 1) << @intFromEnum(state_mod.ButtonId.X));
    gs.ax = 1234;
    gs.ay = -1;
    gs.lt = 100;
    gs.rt = 200;

    var report_buf: [MAX_REPORT_BYTES]u8 = undefined;
    const report = try encodeReport(out, gs, &report_buf);

    // Layout: [ReportID=1][buttons=1 byte for 3 buttons][ax lo][ax hi][ay lo][ay hi][lt][rt]
    try testing.expectEqual(@as(usize, 8), report.len);
    try testing.expectEqual(@as(u8, INPUT_REPORT_ID), report[0]);
    // A = bit 0, B = bit 1, X = bit 2. Pressed: A + X → 0b0000_0101 = 0x05.
    try testing.expectEqual(@as(u8, 0x05), report[1]);
    try testing.expectEqual(@as(i16, 1234), std.mem.readInt(i16, report[2..4], .little));
    try testing.expectEqual(@as(i16, -1), std.mem.readInt(i16, report[4..6], .little));
    try testing.expectEqual(@as(u8, 100), report[6]);
    try testing.expectEqual(@as(u8, 200), report[7]);
}

test "encodeReport: hat packs cardinal/diagonal and neutral correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{
        .name = "hat-test",
        .axes = axes,
        .dpad = .{ .type = "hat" },
    };

    const cases = [_]struct { dx: i8, dy: i8, expect: u8 }{
        .{ .dx = 0, .dy = -1, .expect = 0 }, // N
        .{ .dx = 1, .dy = -1, .expect = 1 }, // NE
        .{ .dx = 1, .dy = 0, .expect = 2 }, // E
        .{ .dx = 1, .dy = 1, .expect = 3 }, // SE
        .{ .dx = 0, .dy = 1, .expect = 4 }, // S
        .{ .dx = -1, .dy = 1, .expect = 5 }, // SW
        .{ .dx = -1, .dy = 0, .expect = 6 }, // W
        .{ .dx = -1, .dy = -1, .expect = 7 }, // NW
        .{ .dx = 0, .dy = 0, .expect = 8 }, // neutral
    };
    for (cases) |tc| {
        var gs = state_mod.GamepadState{};
        gs.dpad_x = tc.dx;
        gs.dpad_y = tc.dy;
        var buf: [MAX_REPORT_BYTES]u8 = undefined;
        const r = try encodeReport(out, gs, &buf);
        // Layout: [ID=1][hat][ax lo][ax hi]
        try testing.expectEqual(@as(u8, tc.expect), r[1] & 0x0F);
        try testing.expectEqual(@as(usize, 4), r.len);
    }
}

test "encodeReport: Steam Deck TOML produces a non-empty report with correct ID" {
    const alloc = testing.allocator;
    const parsed = try device.parseFile(alloc, "devices/valve/steam-deck.toml");
    defer parsed.deinit();
    const out = parsed.value.output orelse return error.MissingOutputSection;

    var gs = state_mod.GamepadState{};
    gs.ax = 100;
    gs.ay = -100;
    gs.rx = 50;
    gs.ry = -50;
    gs.lt = 128;
    gs.rt = 64;

    var buf: [MAX_REPORT_BYTES]u8 = undefined;
    const r = try encodeReport(out, gs, &buf);

    try testing.expectEqual(@as(u8, INPUT_REPORT_ID), r[0]);
    // Steam Deck layout: ID(1) + buttons(17→3 bytes after pad) + hat(1) +
    // sticks(4×2=8) + triggers(2) + touchpad(2 fingers × 5=10) = 25.
    try testing.expect(r.len > 1);
    try testing.expect(r.len <= MAX_REPORT_BYTES);
}

test "encodeReport: empty config is rejected by descriptor builder, encoder never sees it" {
    // encodeReport is only called after buildFromOutput succeeded, so an
    // empty config path cannot occur in production. Assert the guard to
    // document the invariant.
    const out = device.OutputConfig{ .name = "empty" };
    try testing.expectError(error.InvalidOutputConfig, UhidDescriptorBuilder.buildFromOutput(testing.allocator, out));
}

test "encodeReport: buffer smaller than MAX_REPORT_BYTES returns ReportTooLong" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const axes = try makeAxesMap(a, &.{
        .{ .name = "left_x", .cfg = .{ .code = "ABS_X", .min = -32768, .max = 32767 } },
    });
    const out = device.OutputConfig{ .name = "small", .axes = axes };
    var tiny: [4]u8 = undefined;
    try testing.expectError(error.ReportTooLong, encodeReport(out, .{}, &tiny));
}

// --- Structural invariants on the Steam Deck golden fixture (H5) -----------
//
// The golden .bin is the builder's own output, so a byte-exact match is
// tautological. Instead we *parse* the bytes as HID 1.11 short items and
// assert global structure invariants that would catch any builder-level
// corruption (wrong report ID, unbalanced collections, byte alignment).

fn hidItemSize(prefix: u8) u8 {
    // HID 1.11 §6.2.2.2 short item: bSize lives in the low 2 bits of the
    // prefix byte. Encoding: 0=0 bytes, 1=1 byte, 2=2 bytes, 3=4 bytes.
    return switch (prefix & 0b11) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        else => unreachable,
    };
}

test "golden invariants: Steam Deck HID descriptor parses as balanced HID 1.11 item stream" {
    const alloc = testing.allocator;
    const bytes = try std.fs.cwd().readFileAlloc(
        alloc,
        "src/test/fixtures/golden/steam_deck_hid_descriptor.bin",
        65536,
    );
    defer alloc.free(bytes);

    // Prologue: Usage Page (Generic Desktop) 0x05 0x01, Usage (Game Pad)
    // 0x09 0x05, Collection (Application) 0xA1 0x01.
    try testing.expectEqual(@as(u8, 0x05), bytes[0]);
    try testing.expectEqual(@as(u8, 0x01), bytes[1]);
    try testing.expectEqual(@as(u8, 0x09), bytes[2]);
    try testing.expectEqual(@as(u8, 0x05), bytes[3]);
    try testing.expectEqual(@as(u8, 0xA1), bytes[4]);
    try testing.expectEqual(@as(u8, 0x01), bytes[5]);

    var collection_depth: i32 = 0;
    var max_depth: i32 = 0;
    var collection_opens: u32 = 0;
    var collection_closes: u32 = 0;
    var report_ids_seen: u32 = 0;
    var total_input_bits: u64 = 0;
    var cur_report_size: u32 = 0;
    var cur_report_count: u32 = 0;

    var i: usize = 0;
    while (i < bytes.len) {
        const prefix = bytes[i];
        const size = hidItemSize(prefix);
        i += 1;
        if (i + size > bytes.len) return error.TruncatedItem;

        const tag = prefix & 0xF0;
        const btype = (prefix >> 2) & 0b11; // 0=main, 1=global, 2=local
        const payload = bytes[i..][0..size];

        switch (prefix) {
            0xA1 => { // Collection
                collection_opens += 1;
                collection_depth += 1;
                if (collection_depth > max_depth) max_depth = collection_depth;
            },
            0xC0 => { // End Collection
                collection_closes += 1;
                collection_depth -= 1;
            },
            0x85 => { // Report ID (global)
                report_ids_seen += 1;
            },
            else => {},
        }

        // Track Report Size / Report Count to verify byte alignment on Input
        // items.
        if (prefix == 0x75 and size == 1) cur_report_size = payload[0];
        if (prefix == 0x95 and size == 1) cur_report_count = payload[0];

        // Main input item (tag 1000, btype 0) — 0x80 family. 0x81 <data> is
        // "Input".
        if (tag == 0x80 and btype == 0) {
            total_input_bits += @as(u64, cur_report_size) * @as(u64, cur_report_count);
        }

        i += size;
    }

    try testing.expectEqual(collection_opens, collection_closes);
    try testing.expectEqual(@as(i32, 0), collection_depth);
    try testing.expect(max_depth >= 1); // at least the application collection
    try testing.expectEqual(@as(u32, 1), report_ids_seen);
    // Steam Deck descriptor declares >= 1 input bit (buttons + hat + axes).
    try testing.expect(total_input_bits > 0);
    // The sum of Report Size × Report Count across Input items must be a
    // multiple of 8 — the kernel rejects unaligned Input aggregates.
    try testing.expectEqual(@as(u64, 0), total_input_bits % 8);
}
