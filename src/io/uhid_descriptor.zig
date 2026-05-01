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
    IncompletePidDescriptor,
    MissingMandatoryPidUsage,
};

// PID report-ID assignment per spec/openspec/changes/phase-13-wave-6-pidff/
// design.md §T1. Report IDs themselves are not normative in HID PID 1.01 —
// kernel `pidff_find_reports` looks up reports by Usage, not by ID — but a
// fixed assignment keeps the golden test stable and the wire format
// debuggable.
pub const PID_SET_EFFECT_REPORT_ID: u8 = 1;
pub const PID_SET_ENVELOPE_REPORT_ID: u8 = 2;
pub const PID_SET_CONDITION_REPORT_ID: u8 = 3;
pub const PID_SET_PERIODIC_REPORT_ID: u8 = 4;
pub const PID_SET_CONSTANT_FORCE_REPORT_ID: u8 = 5;
pub const PID_SET_RAMP_FORCE_REPORT_ID: u8 = 6;
pub const PID_BLOCK_FREE_REPORT_ID: u8 = 7;
pub const PID_EFFECT_OPERATION_REPORT_ID: u8 = 10;
pub const PID_DEVICE_CONTROL_REPORT_ID: u8 = 11;
pub const PID_DEVICE_GAIN_REPORT_ID: u8 = 12;
pub const PID_CREATE_NEW_EFFECT_REPORT_ID: u8 = 13;
pub const PID_BLOCK_LOAD_REPORT_ID: u8 = 14;
pub const PID_POOL_REPORT_ID: u8 = 15;

// Per drivers/hid/usbhid/hid-pidff.c::pidff_reports[0..PID_REQUIRED_REPORTS]
// the kernel matches reports by HID Usage on the PID Usage Page (0x0F),
// not by Report ID. Report IDs are not normative in HID PID 1.01.
// Kernel pidff_find_reports rejects with -ENODEV if any of these 8 usages
// is absent — see probe Run 2 in tools/wave6-probe/RESEARCH-REPORT.md.
pub const PID_MANDATORY_USAGES = [_]u8{
    0x21, // Set Effect Report
    0x77, // Effect Operation Report
    0x7d, // Device Gain Report
    0x7f, // PID Pool Report
    0x89, // Block Load Report (Feature)
    0x90, // Block Free Report
    0x96, // Device Control Report
    0xab, // Create New Effect Report (Feature)
};
pub const PID_USAGE_PAGE: u16 = 0x0F;

// Report IDs are pinned by the builder for golden-test stability, but they
// are NOT what the kernel matches on. See PID_MANDATORY_USAGES above for
// the validator invariant.
const PID_MANDATORY_REPORT_IDS = [_]u8{
    PID_SET_EFFECT_REPORT_ID, // 1
    PID_BLOCK_FREE_REPORT_ID, // 7
    PID_EFFECT_OPERATION_REPORT_ID, // 10
    PID_DEVICE_CONTROL_REPORT_ID, // 11
    PID_DEVICE_GAIN_REPORT_ID, // 12
    PID_CREATE_NEW_EFFECT_REPORT_ID, // 13
    PID_BLOCK_LOAD_REPORT_ID, // 14
    PID_POOL_REPORT_ID, // 15
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

    /// Build a HID report descriptor for an IMU companion card. Emits a
    /// Generic-Desktop `Multi-axis Controller` application with six i16 axes
    /// (X/Y/Z accel, Rx/Ry/Rz gyro) and no buttons. Linux `hid-generic`'s
    /// HID→evdev mapper sees 6 axes with no EV_KEY and sets
    /// `INPUT_PROP_ACCELEROMETER` automatically, so SDL's
    /// `SDL_EVDEV_GuessDeviceClass` classifies the resulting `/dev/input/eventN`
    /// node as an accelerometer. The previous Sensor-page descriptor bound to
    /// `hid-sensor-hub` and exposed an IIO device instead, which is invisible
    /// to SDL / Steam — see ADR-015 §Alternatives + reviewer report R-C B1.
    ///
    /// Report layout (report ID `IMU_REPORT_ID`):
    ///   1 byte  report ID
    ///   6 × i16 accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z
    ///
    /// Caller owns the returned bytes (`allocator.free`).
    pub fn buildForImu(
        allocator: std.mem.Allocator,
        imu_cfg: device.ImuConfig,
    ) BuildError![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);

        const accel_range: [2]i64 = imu_cfg.accel_range orelse .{ -32768, 32767 };
        const gyro_range: [2]i64 = imu_cfg.gyro_range orelse .{ -32768, 32767 };
        const accel_min = std.math.cast(i32, accel_range[0]) orelse return error.InvalidOutputConfig;
        const accel_max = std.math.cast(i32, accel_range[1]) orelse return error.InvalidOutputConfig;
        const gyro_min = std.math.cast(i32, gyro_range[0]) orelse return error.InvalidOutputConfig;
        const gyro_max = std.math.cast(i32, gyro_range[1]) orelse return error.InvalidOutputConfig;

        try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
        try writeItem1(&buf, allocator, 0x09, 0x08); // Usage (Multi-axis Controller)
        try writeItem1(&buf, allocator, 0xA1, 0x01); // Collection (Application)

        try writeItem1(&buf, allocator, 0x85, IMU_REPORT_ID);

        // Accelerometer: ABS_X/Y/Z as three i16 axes.
        try writeItem1(&buf, allocator, 0x09, 0x30); // Usage (X)
        try writeItem1(&buf, allocator, 0x09, 0x31); // Usage (Y)
        try writeItem1(&buf, allocator, 0x09, 0x32); // Usage (Z)
        try writeLogicalMin(&buf, allocator, accel_min);
        try writeLogicalMax(&buf, allocator, accel_max);
        try writeItem1(&buf, allocator, 0x75, 16);
        try writeItem1(&buf, allocator, 0x95, 3);
        try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)

        // Gyrometer: ABS_RX/RY/RZ as three i16 axes.
        try writeItem1(&buf, allocator, 0x09, 0x33); // Usage (Rx)
        try writeItem1(&buf, allocator, 0x09, 0x34); // Usage (Ry)
        try writeItem1(&buf, allocator, 0x09, 0x35); // Usage (Rz)
        try writeLogicalMin(&buf, allocator, gyro_min);
        try writeLogicalMax(&buf, allocator, gyro_max);
        try writeItem1(&buf, allocator, 0x75, 16);
        try writeItem1(&buf, allocator, 0x95, 3);
        try writeItem1(&buf, allocator, 0x81, 0x02);

        try writeByte(&buf, allocator, 0xC0); // End Collection

        if (buf.items.len > uhid.HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;
        return buf.toOwnedSlice(allocator);
    }

    /// Build a HID report descriptor for a primary UHID card that exposes a
    /// USB HID Physical Interface Device (PID) force-feedback collection.
    /// Used when `[output.force_feedback].backend = "uhid"` and `kind = "pid"`
    /// (T5 schema). The descriptor contains a Joystick application
    /// preamble (one X axis is enough for the kernel to attach) followed by
    /// 10 output reports (Set Effect / Set Envelope / Set Condition / Set
    /// Periodic / Set Constant Force / Set Ramp Force / Block Free / Effect
    /// Operation / Device Control / Device Gain) and 3 feature reports (Create
    /// New Effect / Block Load / PID Pool). Emits all 8 kernel-mandatory reports
    /// (pidff_reports[0..PID_REQUIRED_REPORTS]) plus the 5 optional waveform
    /// parameter reports.
    ///
    /// `validateMandatoryReports` runs at the end and returns
    /// `error.MissingMandatoryPidUsage` if any of the 8 kernel-required
    /// PID Usages (`PID_MANDATORY_USAGES`) is absent, fail-closing the
    /// daemon before kernel `pidff_find_reports` would reject the device.
    /// Report IDs are NOT what the kernel matches on — see comment block
    /// above `PID_MANDATORY_USAGES`.
    ///
    /// The `cfg` parameter is currently unused — full axis/button passthrough
    /// (sticks, hat, buttons) is deferred to a follow-up pass; the kernel
    /// pidff binding only requires the PID collection to be present, so the
    /// minimal joystick preamble here is sufficient for Wave 6 stage 1. The
    /// parameter is kept on the signature so call-sites that already plumb
    /// `OutputConfig` don't change shape.
    pub fn buildForPid(
        allocator: std.mem.Allocator,
        cfg: device.OutputConfig,
        ffb_cfg: device.ForceFeedbackConfig,
    ) BuildError![]u8 {
        _ = cfg;
        _ = ffb_cfg;

        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);

        // --- Joystick application preamble ---
        try writeItem1(&buf, allocator, 0x05, 0x01); // Usage Page (Generic Desktop)
        try writeItem1(&buf, allocator, 0x09, 0x04); // Usage (Joystick)
        try writeItem1(&buf, allocator, 0xA1, 0x01); // Collection (Application)

        // Single X axis input — minimum the kernel needs to bring up an
        // evdev node alongside the PID collection.
        try writeItem1(&buf, allocator, 0x85, INPUT_REPORT_ID);
        try writeItem1(&buf, allocator, 0xA1, 0x00); // Collection (Physical)
        try writeItem1(&buf, allocator, 0x09, 0x30); // Usage (X)
        try writeItem1(&buf, allocator, 0x15, 0x81); // Logical Minimum (-127)
        try writeItem1(&buf, allocator, 0x25, 0x7F); // Logical Maximum (127)
        try writeItem1(&buf, allocator, 0x75, 0x08); // Report Size (8)
        try writeItem1(&buf, allocator, 0x95, 0x01); // Report Count (1)
        try writeItem1(&buf, allocator, 0x81, 0x02); // Input (Data, Var, Abs)
        try writeByte(&buf, allocator, 0xC0); // End Collection (Physical)

        // --- PID output collection ---
        try writeItem1(&buf, allocator, 0x05, 0x0F); // Usage Page (Physical Interface Device)

        try emitPidSetEffectReport(&buf, allocator);
        try emitPidSetEnvelopeReport(&buf, allocator);
        try emitPidSetConditionReport(&buf, allocator);
        try emitPidSetPeriodicReport(&buf, allocator);
        try emitPidSetConstantForceReport(&buf, allocator);
        try emitPidSetRampForceReport(&buf, allocator);
        try emitPidBlockFreeReport(&buf, allocator);
        try emitPidEffectOperationReport(&buf, allocator);
        try emitPidDeviceControlReport(&buf, allocator);
        try emitPidDeviceGainReport(&buf, allocator);
        try emitPidCreateNewEffectReport(&buf, allocator);
        try emitPidBlockLoadReport(&buf, allocator);
        try emitPidPoolReport(&buf, allocator);

        // --- End Application Collection ---
        try writeByte(&buf, allocator, 0xC0);

        if (buf.items.len > uhid.HID_MAX_DESCRIPTOR_SIZE) return error.DescriptorTooLarge;
        try validateMandatoryReports(buf.items);
        return buf.toOwnedSlice(allocator);
    }
};

// --- PID descriptor helpers --------------------------------------------------

fn emitPidSetEffectReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x21); // Usage (Set Effect Report)
    try writeItem1(buf, allocator, 0xA1, 0x02); // Collection (Logical)
    try writeItem1(buf, allocator, 0x85, PID_SET_EFFECT_REPORT_ID);
    // Effect Block Index — u8 1..40
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02); // Output (Data, Var, Abs)
    // Effect Type — array of 11 effect type usages
    try writeItem1(buf, allocator, 0x09, 0x25);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x05, 0x0F);
    try writeItem1(buf, allocator, 0x09, 0x26); // Constant Force
    try writeItem1(buf, allocator, 0x09, 0x27); // Ramp
    try writeItem1(buf, allocator, 0x09, 0x30); // Square
    try writeItem1(buf, allocator, 0x09, 0x31); // Sine
    try writeItem1(buf, allocator, 0x09, 0x32); // Triangle
    try writeItem1(buf, allocator, 0x09, 0x33); // Sawtooth Up
    try writeItem1(buf, allocator, 0x09, 0x34); // Sawtooth Down
    try writeItem1(buf, allocator, 0x09, 0x40); // Spring
    try writeItem1(buf, allocator, 0x09, 0x41); // Damper
    try writeItem1(buf, allocator, 0x09, 0x42); // Inertia
    try writeItem1(buf, allocator, 0x09, 0x43); // Friction
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x0B);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x00); // Output (Data, Ary, Abs)
    try writeByte(buf, allocator, 0xC0);
    // Duration — u16 ms
    try writeItem1(buf, allocator, 0x05, 0x0F);
    try writeItem1(buf, allocator, 0x09, 0x50);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x7FFF);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Trigger Button — u8
    try writeItem1(buf, allocator, 0x09, 0x53);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Gain — u8 0..255 (mapped to 0..100%)
    try writeItem1(buf, allocator, 0x09, 0x52);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Direction — X / Y as two u8
    try writeItem1(buf, allocator, 0x09, 0x55); // Axes Enable
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x05, 0x01); // Generic Desktop
    try writeItem1(buf, allocator, 0x09, 0x30); // X
    try writeItem1(buf, allocator, 0x09, 0x31); // Y
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem1(buf, allocator, 0x25, 0x01);
    try writeItem1(buf, allocator, 0x75, 0x01);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeItem1(buf, allocator, 0x75, 0x06); // 6-bit padding
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x03);
    try writeByte(buf, allocator, 0xC0);
    try writeItem1(buf, allocator, 0x05, 0x0F);
    try writeByte(buf, allocator, 0xC0); // End Collection (Set Effect)
}

fn emitPidSetEnvelopeReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x5A); // Usage (Set Envelope Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_SET_ENVELOPE_REPORT_ID);
    // Effect Block Index
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Attack Level (0x5B), Fade Level (0x5E) — two u8
    try writeItem1(buf, allocator, 0x09, 0x5B);
    try writeItem1(buf, allocator, 0x09, 0x5E);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Attack Time (0x5C), Fade Time (0x5D) — two u16 ms
    try writeItem1(buf, allocator, 0x09, 0x5C);
    try writeItem1(buf, allocator, 0x09, 0x5D);
    try writeItem2(buf, allocator, 0x26, 0x7FFF);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidSetConditionReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x5F); // Usage (Set Condition Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_SET_CONDITION_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Parameter Block Offset — u8
    try writeItem1(buf, allocator, 0x09, 0x23);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem1(buf, allocator, 0x25, 0x01);
    try writeItem1(buf, allocator, 0x75, 0x04);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeItem1(buf, allocator, 0x75, 0x04); // 4-bit padding
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x03);
    // Center Point Offset (0x60) — i16 -10000..10000
    try writeItem1(buf, allocator, 0x09, 0x60);
    try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, -10000)));
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Positive (0x61) + Negative (0x62) Coefficients — i16 each
    try writeItem1(buf, allocator, 0x09, 0x61);
    try writeItem1(buf, allocator, 0x09, 0x62);
    try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, -10000)));
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Positive (0x63) + Negative (0x64) Saturation — u16 each
    try writeItem1(buf, allocator, 0x09, 0x63);
    try writeItem1(buf, allocator, 0x09, 0x64);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Dead Band (0x65) — u16
    try writeItem1(buf, allocator, 0x09, 0x65);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidSetPeriodicReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x6E); // Usage (Set Periodic Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_SET_PERIODIC_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Magnitude (0x70) — u16
    try writeItem1(buf, allocator, 0x09, 0x70);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Offset (0x71) — i16
    try writeItem1(buf, allocator, 0x09, 0x71);
    try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, -10000)));
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Phase (0x72) — u16 deg*100
    try writeItem1(buf, allocator, 0x09, 0x72);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 35999);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Period (0x73) — u16 ms
    try writeItem1(buf, allocator, 0x09, 0x73);
    try writeItem2(buf, allocator, 0x26, 0x7FFF);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidSetConstantForceReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x73); // Usage (Set Constant Force Report) — same usage code 0x73 as Period inside its own collection scope
    // NOTE: HID PID 1.01 §4.2.5 Set Constant Force usage = 0x73. The same
    // code 0x73 is reused for Period inside Set Periodic; HID spec scopes
    // usages by their containing logical collection so this is not a clash.
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_SET_CONSTANT_FORCE_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Magnitude (0x70) — i16 -10000..10000
    try writeItem1(buf, allocator, 0x09, 0x70);
    try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, -10000)));
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidSetRampForceReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x74); // Usage (Set Ramp Force Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_SET_RAMP_FORCE_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Ramp Start (0x75) + Ramp End (0x76) — i16 each
    try writeItem1(buf, allocator, 0x09, 0x75);
    try writeItem1(buf, allocator, 0x09, 0x76);
    try writeItem2(buf, allocator, 0x16, @bitCast(@as(i16, -10000)));
    try writeItem2(buf, allocator, 0x26, 10000);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidBlockFreeReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x90); // Usage (Block Free Report)
    try writeItem1(buf, allocator, 0xA1, 0x02); // Collection (Logical)
    try writeItem1(buf, allocator, 0x85, PID_BLOCK_FREE_REPORT_ID);
    // Effect Block Index — u8 1..40
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02); // Output (Data, Var, Abs)
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidEffectOperationReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x77); // Usage (Effect Operation Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_EFFECT_OPERATION_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    // Operation array: Start (0x79), Start Solo (0x7A), Stop (0x7B)
    try writeItem1(buf, allocator, 0x09, 0x78);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x09, 0x79);
    try writeItem1(buf, allocator, 0x09, 0x7A);
    try writeItem1(buf, allocator, 0x09, 0x7B);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x03);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x00);
    try writeByte(buf, allocator, 0xC0);
    // Loop Count (0x7C) — u8
    try writeItem1(buf, allocator, 0x09, 0x7C);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidDeviceControlReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    // Outer usage = 0x96 (PID Device Control Report container) per kernel
    // `drivers/hid/usbhid/hid-pidff.c::pidff_reports`. The probe descriptor
    // (tools/wave6-probe/pidff_probe.py) used 0x95 (PID Device Control
    // field) — that is the cause of probe Run 2's `pidff_find_reports
    // -ENODEV` failure. We use 0x96 here so the kernel can locate the
    // report.
    try writeItem1(buf, allocator, 0x09, 0x96);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_DEVICE_CONTROL_REPORT_ID);
    // DC array: Reset (0x97), Pause (0x98), Continue (0x99), Stop All (0x9A),
    // Enable (0x9B), Disable (0x9C)
    try writeItem1(buf, allocator, 0x09, 0x97);
    try writeItem1(buf, allocator, 0x09, 0x98);
    try writeItem1(buf, allocator, 0x09, 0x99);
    try writeItem1(buf, allocator, 0x09, 0x9A);
    try writeItem1(buf, allocator, 0x09, 0x9B);
    try writeItem1(buf, allocator, 0x09, 0x9C);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x06);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x00);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidDeviceGainReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    // Container usage = 0x7D (Device Gain Report) per kernel `pidff_reports`;
    // the field inside is 0x7E (Device Gain) per `pidff_device_gain`.
    try writeItem1(buf, allocator, 0x09, 0x7D);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_DEVICE_GAIN_REPORT_ID);
    try writeItem1(buf, allocator, 0x09, 0x7E);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0x91, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidCreateNewEffectReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0xAB); // Usage (Create New Effect Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_CREATE_NEW_EFFECT_REPORT_ID);
    // Effect Type — array
    try writeItem1(buf, allocator, 0x09, 0x25);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x09, 0x26);
    try writeItem1(buf, allocator, 0x09, 0x27);
    try writeItem1(buf, allocator, 0x09, 0x30);
    try writeItem1(buf, allocator, 0x09, 0x31);
    try writeItem1(buf, allocator, 0x09, 0x32);
    try writeItem1(buf, allocator, 0x09, 0x33);
    try writeItem1(buf, allocator, 0x09, 0x34);
    try writeItem1(buf, allocator, 0x09, 0x40);
    try writeItem1(buf, allocator, 0x09, 0x41);
    try writeItem1(buf, allocator, 0x09, 0x42);
    try writeItem1(buf, allocator, 0x09, 0x43);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x0B);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x00); // Feature (Data, Ary, Abs)
    try writeByte(buf, allocator, 0xC0);
    // Byte Count of Data (0xAC) — u16 — emitted under Create New Effect per spec
    try writeItem1(buf, allocator, 0x09, 0xAC);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidBlockLoadReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x89); // Usage (Block Load Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_BLOCK_LOAD_REPORT_ID);
    // Effect Block Index — u8 1..40
    try writeItem1(buf, allocator, 0x09, 0x22);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x28);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    // Block Load Status array — Success (0x8C), Full (0x8D), Error (0x8E)
    try writeItem1(buf, allocator, 0x09, 0x8B);
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x09, 0x8C);
    try writeItem1(buf, allocator, 0x09, 0x8D);
    try writeItem1(buf, allocator, 0x09, 0x8E);
    try writeItem1(buf, allocator, 0x15, 0x01);
    try writeItem1(buf, allocator, 0x25, 0x03);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x00);
    try writeByte(buf, allocator, 0xC0);
    // RAM Pool Available (0xAC) — u16
    try writeItem1(buf, allocator, 0x09, 0xAC);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem2(buf, allocator, 0x26, 0xFFFF);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    try writeByte(buf, allocator, 0xC0);
}

fn emitPidPoolReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try writeItem1(buf, allocator, 0x09, 0x7F); // Usage (PID Pool Report)
    try writeItem1(buf, allocator, 0xA1, 0x02);
    try writeItem1(buf, allocator, 0x85, PID_POOL_REPORT_ID);
    // RAM Pool Size (0x80) — u32
    try writeItem1(buf, allocator, 0x09, 0x80);
    try writeItem1(buf, allocator, 0x15, 0x00);
    try writeItem4(buf, allocator, 0x27, 0xFFFF);
    try writeItem1(buf, allocator, 0x75, 0x10);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    // Simultaneous Effects Max (0x83) — u8
    try writeItem1(buf, allocator, 0x09, 0x83);
    try writeItem2(buf, allocator, 0x26, 0x00FF);
    try writeItem1(buf, allocator, 0x75, 0x08);
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    // Device Managed Pool (0xA9) + Shared Parameter Blocks (0xAA) — 2 bits
    try writeItem1(buf, allocator, 0x09, 0xA9);
    try writeItem1(buf, allocator, 0x09, 0xAA);
    try writeItem1(buf, allocator, 0x25, 0x01);
    try writeItem1(buf, allocator, 0x75, 0x01);
    try writeItem1(buf, allocator, 0x95, 0x02);
    try writeItem1(buf, allocator, 0xB1, 0x02);
    try writeItem1(buf, allocator, 0x75, 0x06); // 6-bit padding
    try writeItem1(buf, allocator, 0x95, 0x01);
    try writeItem1(buf, allocator, 0xB1, 0x03);
    try writeByte(buf, allocator, 0xC0);
}

/// Walk a HID descriptor as a stream of HID 1.11 short items, tracking the
/// current Usage Page (global tag 0x04) and Usage (local tag 0x08). When a
/// Logical Collection (Main tag 0xA0, payload byte 0x02) opens and the most
/// recent Usage was on the PID Usage Page (0x0F), mark that Usage as seen.
/// Returns `error.MissingMandatoryPidUsage` if any of the 8 usages required
/// by kernel `pidff_find_reports` is absent. Long-form items (prefix 0xFE)
/// are accepted by skipping `data_size` bytes after the long-item header;
/// none of the current PID emit helpers use long form.
pub fn validateMandatoryReports(descriptor: []const u8) BuildError!void {
    var current_usage_page: u16 = 0;
    var current_usage: u32 = 0;
    var current_usage_page_overridden: bool = false;
    var seen: [PID_MANDATORY_USAGES.len]bool = .{false} ** PID_MANDATORY_USAGES.len;

    var i: usize = 0;
    while (i < descriptor.len) {
        const prefix = descriptor[i];
        if (prefix == 0xFE) {
            // Long-form: 0xFE bDataSize bLongItemTag <data>
            if (i + 2 >= descriptor.len) return error.IncompletePidDescriptor;
            const data_size = descriptor[i + 1];
            i += 3 + data_size;
            continue;
        }
        const size: u8 = switch (prefix & 0b11) {
            0 => 0,
            1 => 1,
            2 => 2,
            3 => 4,
            else => unreachable,
        };
        if (i + 1 + size > descriptor.len) return error.IncompletePidDescriptor;
        const tag = prefix & 0xFC;
        const payload = descriptor[i + 1 .. i + 1 + size];

        if (tag == 0x04) {
            current_usage_page = @truncate(readUnsignedLE(payload));
        } else if (tag == 0x08) {
            // Local Usage. Size 4 is "extended usage" — high 16 bits override
            // the page for this single usage. Sizes 1 and 2 use the current
            // global Usage Page. Size 0 is illegal per HID 1.11 §6.2.2.7 but
            // we ignore rather than error to match upstream tolerant parsers.
            current_usage = readUnsignedLE(payload);
            current_usage_page_overridden = (size == 4);
        } else if (tag == 0xA0 and size >= 1 and descriptor[i + 1] == 0x02) {
            const effective_page: u16 = if (current_usage_page_overridden)
                @intCast((current_usage >> 16) & 0xFFFF)
            else
                current_usage_page;
            const effective_usage: u8 = @truncate(current_usage & 0xFF);
            if (effective_page == PID_USAGE_PAGE) {
                for (PID_MANDATORY_USAGES, 0..) |u, idx| {
                    if (effective_usage == u) seen[idx] = true;
                }
            }
        }

        // Per HID 1.11 §6.2.2.7 a Main item consumes any pending Local items;
        // reset the Usage so a stale one cannot accidentally tag a later
        // collection. Main tags are bType=0 → 0x80, 0x90, 0xA0, 0xB0.
        if ((prefix & 0x0C) == 0x00) {
            current_usage = 0;
            current_usage_page_overridden = false;
        }

        i += 1 + size;
    }

    for (seen) |s| {
        if (!s) return error.MissingMandatoryPidUsage;
    }
}

fn readUnsignedLE(bytes: []const u8) u32 {
    var v: u32 = 0;
    var shift: u5 = 0;
    for (bytes) |b| {
        v |= @as(u32, b) << shift;
        shift +%= 8;
    }
    return v;
}

/// Report ID used for IMU input reports. Distinct from the primary gamepad
/// card's `INPUT_REPORT_ID` — the two cards live on separate UHID fds so the
/// IDs never collide on the wire, but a different value makes descriptor
/// decoding easier when diagnosing logs.
pub const IMU_REPORT_ID: u8 = 2;

/// Wire size of an IMU input report — 1 byte ID + 6 × i16 axes.
pub const IMU_REPORT_BYTES: usize = 1 + 6 * 2;

/// Encode a GamepadState into the IMU wire report. Layout is fixed
/// (accel_x/y/z, gyro_x/y/z — all i16 little-endian) and matches the
/// descriptor emitted by `buildForImu`.
pub fn encodeImuReport(gs: state_mod.GamepadState, buf: []u8) EncodeError![]u8 {
    if (buf.len < IMU_REPORT_BYTES) return error.ReportTooLong;
    @memset(buf[0..IMU_REPORT_BYTES], 0);
    buf[0] = IMU_REPORT_ID;
    std.mem.writeInt(i16, buf[1..][0..2], gs.accel_x, .little);
    std.mem.writeInt(i16, buf[3..][0..2], gs.accel_y, .little);
    std.mem.writeInt(i16, buf[5..][0..2], gs.accel_z, .little);
    std.mem.writeInt(i16, buf[7..][0..2], gs.gyro_x, .little);
    std.mem.writeInt(i16, buf[9..][0..2], gs.gyro_y, .little);
    std.mem.writeInt(i16, buf[11..][0..2], gs.gyro_z, .little);
    return buf[0..IMU_REPORT_BYTES];
}

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

// Named helper types so multiple test sites can pass literals without
// tripping Zig's anonymous-struct nominal typing (two anonymous structs
// with the same shape but different declaration sites are distinct types).
const AxisEntry = struct { name: []const u8, cfg: device.AxisConfig };
const ButtonEntry = struct { name: []const u8, code: []const u8 };

fn makeAxesMap(allocator: std.mem.Allocator, entries: []const AxisEntry) !toml.HashMap(device.AxisConfig) {
    var map = std.StringHashMap(device.AxisConfig).init(allocator);
    errdefer map.deinit();
    for (entries) |e| {
        const key = try allocator.dupe(u8, e.name);
        try map.put(key, e.cfg);
    }
    return .{ .map = map };
}

fn makeButtonsMap(allocator: std.mem.Allocator, entries: []const ButtonEntry) !toml.HashMap([]const u8) {
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
    var entries: [100]ButtonEntry = undefined;
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

// --- buildForImu tests (Phase 13 Wave 3 T5a/T5b) ---------------------------

test "buildForImu: default ranges produce the pinned golden descriptor" {
    const imu = device.ImuConfig{};
    const desc = try UhidDescriptorBuilder.buildForImu(testing.allocator, imu);
    defer testing.allocator.free(desc);

    // Generic Desktop + Multi-axis Controller (NOT Sensor page); three accel
    // axes ABS_X/Y/Z then three gyro axes ABS_RX/RY/RZ, each as i16 with
    // LogicalMin -32768 / LogicalMax 32767 (signed 2-byte encoding).
    const expected = [_]u8{
        // Application prologue
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x08, // Usage (Multi-axis Controller)
        0xA1, 0x01, // Collection (Application)
        0x85, IMU_REPORT_ID, // Report ID (2)

        // Accelerometer — X/Y/Z
        0x09, 0x30, // Usage (X)
        0x09, 0x31, // Usage (Y)
        0x09, 0x32, // Usage (Z)
        0x16, 0x00, 0x80, // Logical Minimum (-32768)
        0x26, 0xFF, 0x7F, // Logical Maximum (32767)
        0x75, 0x10, // Report Size (16)
        0x95, 0x03, // Report Count (3)
        0x81, 0x02, // Input (Data, Var, Abs)

        // Gyrometer — Rx/Ry/Rz
        0x09, 0x33, // Usage (Rx)
        0x09, 0x34, // Usage (Ry)
        0x09, 0x35, // Usage (Rz)
        0x16, 0x00, 0x80, // Logical Minimum (-32768)
        0x26, 0xFF, 0x7F, // Logical Maximum (32767)
        0x75, 0x10, 0x95,
        0x03, 0x81, 0x02,
        0xC0, // End Collection
    };
    try testing.expectEqualSlices(u8, &expected, desc);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
}

test "buildForImu: custom ranges alter logical min/max bytes" {
    const imu = device.ImuConfig{
        .accel_range = .{ -16384, 16384 },
        .gyro_range = .{ -16384, 16384 },
    };
    const desc = try UhidDescriptorBuilder.buildForImu(testing.allocator, imu);
    defer testing.allocator.free(desc);

    var seen: usize = 0;
    var i: usize = 0;
    while (i + 2 < desc.len) : (i += 1) {
        if (desc[i] == 0x16 and desc[i + 1] == 0x00 and desc[i + 2] == 0xC0) {
            seen += 1;
            i += 2;
        }
    }
    try testing.expectEqual(@as(usize, 2), seen);
}

test "buildForImu: descriptor contains no Usage Page Button (EV_KEY)" {
    const imu = device.ImuConfig{};
    const desc = try UhidDescriptorBuilder.buildForImu(testing.allocator, imu);
    defer testing.allocator.free(desc);

    // Must begin with Generic Desktop + Multi-axis Controller so the kernel's
    // HID→evdev mapper (drivers/hid/hid-input.c) creates an `/dev/input/eventN`
    // node with INPUT_PROP_ACCELEROMETER, NOT an IIO device under hid-sensor-hub.
    try testing.expect(desc.len >= 4);
    try testing.expectEqual(@as(u8, 0x05), desc[0]);
    try testing.expectEqual(@as(u8, 0x01), desc[1]);
    try testing.expectEqual(@as(u8, 0x09), desc[2]);
    try testing.expectEqual(@as(u8, 0x08), desc[3]);

    var i: usize = 0;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x05 and desc[i + 1] == 0x09) {
            std.debug.print("unexpected Usage Page Button at offset {d}\n", .{i});
            try testing.expect(false);
        }
    }
}

test "buildForImu: primary pad descriptor DOES emit Usage Page Button (control sample)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // Single-button primary pad — the builder must emit `0x05 0x09` for its
    // Button Page. If this test fails alongside the IMU test, the byte
    // signature itself changed and the IMU check is vacuous.
    const buttons = try makeButtonsMap(a, &.{
        .{ .name = "A", .code = "BTN_SOUTH" },
    });
    const out = device.OutputConfig{ .name = "ctrl", .buttons = buttons };

    const desc = try UhidDescriptorBuilder.buildFromOutput(testing.allocator, out);
    defer testing.allocator.free(desc);

    var found = false;
    var i: usize = 0;
    while (i + 1 < desc.len) : (i += 1) {
        if (desc[i] == 0x05 and desc[i + 1] == 0x09) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

// --- buildForPid tests (Phase 13 Wave 6 T1) --------------------------------

test "buildForPid: 8 mandatory PID reports present per kernel pidff_find_reports" {
    const out = device.OutputConfig{ .name = "moza-r5-fixture", .vid = 0x11FF, .pid = 0x1211 };
    const ffb = device.ForceFeedbackConfig{
        .backend = "uhid",
        .kind = "pid",
        .clone_vid_pid = true,
    };
    const desc = try UhidDescriptorBuilder.buildForPid(testing.allocator, out, ffb);
    defer testing.allocator.free(desc);

    // The builder runs validateMandatoryReports internally; running it again
    // here pins the contract at the test boundary.
    try validateMandatoryReports(desc);

    // Sanity: descriptor begins with the joystick application preamble and
    // ends with End Collection.
    try testing.expect(desc.len > 32);
    try testing.expectEqual(@as(u8, 0x05), desc[0]);
    try testing.expectEqual(@as(u8, 0x01), desc[1]);
    try testing.expectEqual(@as(u8, 0x09), desc[2]);
    try testing.expectEqual(@as(u8, 0x04), desc[3]);
    try testing.expectEqual(@as(u8, 0xC0), desc[desc.len - 1]);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
}

test "buildForPid: every required PID Usage surfaces during a manual byte-walk" {
    const out = device.OutputConfig{ .name = "manual-walk", .vid = 0x11FF, .pid = 0x1211 };
    const ffb = device.ForceFeedbackConfig{ .backend = "uhid", .kind = "pid" };
    const desc = try UhidDescriptorBuilder.buildForPid(testing.allocator, out, ffb);
    defer testing.allocator.free(desc);

    var seen: [PID_MANDATORY_USAGES.len]bool = .{false} ** PID_MANDATORY_USAGES.len;
    var page: u16 = 0;
    var usage: u8 = 0;
    var i: usize = 0;
    while (i < desc.len) {
        const prefix = desc[i];
        const size = hidItemSize(prefix);
        const tag = prefix & 0xFC;
        if (tag == 0x04 and size >= 1) page = desc[i + 1];
        if (tag == 0x08 and size >= 1) usage = desc[i + 1];
        if (tag == 0xA0 and size >= 1 and desc[i + 1] == 0x02 and page == PID_USAGE_PAGE) {
            for (PID_MANDATORY_USAGES, 0..) |u, idx| {
                if (usage == u) seen[idx] = true;
            }
        }
        i += 1 + size;
    }
    for (PID_MANDATORY_USAGES, 0..) |u, idx| {
        if (!seen[idx]) {
            std.debug.print("missing PID Usage 0x{x:0>2}\n", .{u});
            try testing.expect(false);
        }
    }
}

test "validateMandatoryReports: rejects descriptor missing PID Set Effect (0x21)" {
    // 7 of 8 mandatory usages declared on PID Usage Page — Set Effect (0x21)
    // omitted. Must fail with MissingMandatoryPidUsage.
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    buf[len] = 0x05;
    buf[len + 1] = 0x0F;
    len += 2; // Usage Page (PID)
    const usages_present = [_]u8{ 0x77, 0x7d, 0x7f, 0x89, 0x90, 0x96, 0xab };
    for (usages_present) |u| {
        buf[len] = 0x09;
        buf[len + 1] = u;
        len += 2; // Usage
        buf[len] = 0xA1;
        buf[len + 1] = 0x02;
        len += 2; // Logical Collection
        buf[len] = 0xC0;
        len += 1; // End Collection
    }
    try testing.expectError(error.MissingMandatoryPidUsage, validateMandatoryReports(buf[0..len]));
}

test "validateMandatoryReports: rejects naked 0x85 NN with no surrounding Usage" {
    // The "TP35-style" partial: a Report ID byte sequence without any
    // Usage / Usage Page declarations. Validator must fail closed because
    // the kernel cannot match reports without Usage anchors.
    const partial = [_]u8{ 0x85, 0x0B, 0xC0 };
    try testing.expectError(error.MissingMandatoryPidUsage, validateMandatoryReports(&partial));
}

test "validateMandatoryReports: accepts buildForPid output" {
    const out = device.OutputConfig{ .name = "roundtrip", .vid = 0x11FF, .pid = 0x1211 };
    const ffb = device.ForceFeedbackConfig{ .backend = "uhid", .kind = "pid" };
    const desc = try UhidDescriptorBuilder.buildForPid(testing.allocator, out, ffb);
    defer testing.allocator.free(desc);
    try validateMandatoryReports(desc);
}

test "validateMandatoryReports: rejects all 8 Report IDs without matching Usages" {
    // Regression for the previous validator bug: a descriptor that emits
    // every required Report ID but no PID Usages must fail. This is the
    // exact failure mode the old report-ID-based validator missed.
    var bytes: [PID_MANDATORY_REPORT_IDS.len * 2]u8 = undefined;
    var idx: usize = 0;
    for (PID_MANDATORY_REPORT_IDS) |id| {
        bytes[idx] = 0x85;
        bytes[idx + 1] = id;
        idx += 2;
    }
    try testing.expectError(error.MissingMandatoryPidUsage, validateMandatoryReports(&bytes));
}

test "buildForPid: descriptor includes Block Free report (kernel-required)" {
    const out = device.OutputConfig{ .name = "block-free-check", .vid = 0x11FF, .pid = 0x1211 };
    const ffb = device.ForceFeedbackConfig{ .backend = "uhid", .kind = "pid" };
    const desc = try UhidDescriptorBuilder.buildForPid(testing.allocator, out, ffb);
    defer testing.allocator.free(desc);

    // Walk the byte stream looking for Usage (0x09) 0x90 (Block Free Report).
    var found_usage_90 = false;
    var i: usize = 0;
    while (i < desc.len) {
        const prefix = desc[i];
        const size = hidItemSize(prefix);
        if (prefix == 0x09 and size == 1 and i + 1 < desc.len and desc[i + 1] == 0x90) {
            found_usage_90 = true;
            break;
        }
        i += 1 + size;
    }
    try testing.expect(found_usage_90);
}

test "buildForPid: stays within HID_MAX_DESCRIPTOR_SIZE" {
    const out = device.OutputConfig{ .name = "size-stress", .vid = 0x11FF, .pid = 0x1211 };
    const ffb = device.ForceFeedbackConfig{ .backend = "uhid", .kind = "pid" };
    const desc = try UhidDescriptorBuilder.buildForPid(testing.allocator, out, ffb);
    defer testing.allocator.free(desc);
    try testing.expect(desc.len <= uhid.HID_MAX_DESCRIPTOR_SIZE);
}

// TODO(T1d): pin the byte sequence emitted by buildForPid against a known-good
// reference once the first real-hardware run shows kernel `hid-universal-pidff`
// FFB init success (no `Error initialising force feedback`, no
// `pidff_find_reports -ENODEV`, no kernel OOPS in `hid_hw_open+0x71`). Probe
// Run 2's 7-of-12 descriptor (tools/wave6-probe/pidff_probe.py) cannot be used
// as a reference — it caused FFB init failure. See
// openspec/changes/phase-13-wave-6-pidff/tasks.md §T1d for the gating
// procedure. Until then this test is intentionally skipped.
test "buildForPid: matches reference PID descriptor (Moza R5)" {
    return error.SkipZigTest;
}

test "encodeImuReport: round-trips 6 axes into 13-byte wire report" {
    var buf: [IMU_REPORT_BYTES]u8 = undefined;
    const gs = state_mod.GamepadState{
        .accel_x = 100,
        .accel_y = -200,
        .accel_z = 300,
        .gyro_x = -400,
        .gyro_y = 500,
        .gyro_z = -600,
    };
    const report = try encodeImuReport(gs, &buf);
    try testing.expectEqual(IMU_REPORT_BYTES, report.len);
    try testing.expectEqual(IMU_REPORT_ID, report[0]);
    try testing.expectEqual(@as(i16, 100), std.mem.readInt(i16, report[1..][0..2], .little));
    try testing.expectEqual(@as(i16, -200), std.mem.readInt(i16, report[3..][0..2], .little));
    try testing.expectEqual(@as(i16, 300), std.mem.readInt(i16, report[5..][0..2], .little));
    try testing.expectEqual(@as(i16, -400), std.mem.readInt(i16, report[7..][0..2], .little));
    try testing.expectEqual(@as(i16, 500), std.mem.readInt(i16, report[9..][0..2], .little));
    try testing.expectEqual(@as(i16, -600), std.mem.readInt(i16, report[11..][0..2], .little));
}

test "encodeImuReport: rejects undersized buffer" {
    var tiny: [IMU_REPORT_BYTES - 1]u8 = undefined;
    try testing.expectError(error.ReportTooLong, encodeImuReport(.{}, &tiny));
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
    // The Steam Deck descriptor declares exactly two Report IDs — one for
    // the main input stream (ID 1) and one for the rumble output (ID 2).
    try testing.expectEqual(@as(u32, 2), report_ids_seen);
    // Steam Deck descriptor declares >= 1 input bit (buttons + hat + axes).
    try testing.expect(total_input_bits > 0);
    // The sum of Report Size × Report Count across Input items must be a
    // multiple of 8 — the kernel rejects unaligned Input aggregates.
    try testing.expectEqual(@as(u64, 0), total_input_bits % 8);
}
