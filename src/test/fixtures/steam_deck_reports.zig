//! Synthetic Steam Deck 0x09 input report generator for end-to-end tests.
//!
//! Kernel reference: drivers/hid/hid-steam.c :1748-1766 (envelope),
//! :1597 steam_do_deck_input_event (bit mapping).
//!
//! Layout (64 bytes, little-endian) — mirrors `devices/valve/steam-deck.toml`
//! on `main`:
//!   byte 0 : 0x01  envelope header byte 0 (version)
//!   byte 1 : 0x00  reserved / envelope padding
//!   byte 2 : 0x09  report_type (matches `[report.match]` offset=2 expect=[0x09])
//!   byte 3 : 0x40  payload_len (64)
//!   bytes 4-7    : frame_counter u32le
//!   bytes 8-15   : buttons bitfield (per button_group map in steam-deck.toml)
//!   bytes 16-23  : trackpad L/R X/Y i16le (touch0_x/y, touch1_x/y)
//!   bytes 24-35  : accel/gyro i16le (accel_x/y/z, gyro_x/y/z)
//!   bytes 44-47  : trigger L/R pressure u16le (lt, rt after scale transform)
//!   bytes 48-55  : stick L/R X/Y i16le (left_x/y, right_x/y)
//!
//! Button bit mapping (per `steam-deck.toml[report.button_group]`):
//!   - `source = { offset = 8, size = 8 }` — 64-bit field starting at byte 8.
//!   - Entries like `A = 7, B = 5, X = 6, Y = 4` are **bit indices** into
//!     that 64-bit field, read little-endian: byte 8 bit 0 = index 0.
//!
//! Steam-mode state machine: real Steam Decks boot in "lizard" mode where
//! the digital buttons are held muted by firmware. SDL / Steam sends a
//! feature report (0x81, ID_CLEAR_DIGITAL_MAPPINGS) to unlatch them. This
//! fixture models that: before `acceptModeSwitch()` is called, `buttonPress`
//! payloads are returned with the button bits zeroed. After, they pass
//! through. Tests that want the post-mode-switch path just call
//! `acceptModeSwitch()` on the `ReportGenerator` before injecting reports.

const std = @import("std");

pub const ReportSize: usize = 64;

/// Synthetic VID/PID used by the test harness — **not** Valve's real IDs.
/// A developer running these tests on a machine with a real Steam Deck
/// attached would otherwise see `UhidSimulator.findHidrawPath` alias to the
/// real hardware node (same 0x28de:0x1205 match), corrupting both the test
/// harness and potentially the real device's input stream. Picking a value
/// outside any known vendor range (0xFADE is not assigned by USB-IF) ensures
/// the virtual device we create is the only match.
pub const DECK_VID: u16 = 0xFADE;
pub const DECK_PID: u16 = 0xD00D;

/// Subset of `ButtonId` relevant to Deck digital buttons. Enum values are the
/// bit indices inside the 64-bit `button_group` field that starts at byte 8.
/// Matches `devices/valve/steam-deck.toml`.
pub const Button = enum(u6) {
    RT_digital = 0,
    LT_digital = 1,
    RB = 2,
    LB = 3,
    Y = 4,
    B = 5,
    X = 6,
    A = 7,
    DPadUp = 8,
    DPadRight = 9,
    DPadLeft = 10,
    DPadDown = 11,
    Select = 12,
    Home = 13,
    Start = 14,
    M1 = 15,
    M2 = 16,
    LS = 22,
    RS = 26,
    M3 = 41,
    M4 = 42,
};

/// ID of the Steam-mode switch feature report (ID_CLEAR_DIGITAL_MAPPINGS).
pub const STEAM_MODE_FEATURE_ID: u8 = 0x81;

/// Report-generator state machine. Default state = lizard mode (buttons
/// suppressed). Call `acceptModeSwitch()` to transition to Steam mode.
pub const ReportGenerator = struct {
    in_steam_mode: bool = false,
    frame_counter: u32 = 0,

    /// Transition to Steam mode. After this, `buttonPress` returns reports
    /// with the button bits actually set. Mirrors the effect of sending the
    /// 0x81 feature report to a real Deck (see issue #126).
    pub fn acceptModeSwitch(self: *ReportGenerator) void {
        self.in_steam_mode = true;
    }

    /// Produce an envelope-valid report with all buttons / sticks at rest.
    pub fn idleReport(self: *ReportGenerator) [ReportSize]u8 {
        return self.buildReport(.{});
    }

    /// Produce a report with a single digital button asserted. In lizard
    /// mode (pre-`acceptModeSwitch`), button bits are zeroed to model the
    /// firmware-driven suppression. Stick axes stay centred.
    pub fn buttonPressReport(self: *ReportGenerator, button: Button) [ReportSize]u8 {
        if (!self.in_steam_mode) return self.idleReport();
        var params = Params{};
        params.buttons = @as(u64, 1) << @intFromEnum(button);
        return self.buildReport(params);
    }

    /// Produce a report with explicit stick values. Follows the TOML's
    /// `transform = "negate"` on left_y / right_y at the *report* level — we
    /// simply encode the raw bytes; the interpreter re-applies the transform
    /// and the two cancel, so callers see `delta.ay == ly` etc.
    pub fn stickReport(self: *ReportGenerator, lx: i16, ly: i16, rx: i16, ry: i16) [ReportSize]u8 {
        var params = Params{};
        params.left_x = lx;
        params.left_y = ly;
        params.right_x = rx;
        params.right_y = ry;
        return self.buildReport(params);
    }

    /// Produce the Steam-mode switch feature report a real SDL / Steam client
    /// would send to exit lizard mode. The layout is one byte (report ID);
    /// SDL also sends an unlock sequence, but the kernel only cares that the
    /// ID matches.
    pub fn modeSwitchFeatureReport(_: *const ReportGenerator) [1]u8 {
        return [_]u8{STEAM_MODE_FEATURE_ID};
    }

    const Params = struct {
        buttons: u64 = 0,
        left_x: i16 = 0,
        left_y: i16 = 0,
        right_x: i16 = 0,
        right_y: i16 = 0,
    };

    fn buildReport(self: *ReportGenerator, params: Params) [ReportSize]u8 {
        var out: [ReportSize]u8 = std.mem.zeroes([ReportSize]u8);
        // Envelope per `devices/valve/steam-deck.toml` + kernel hid-steam.c
        // :1748-1766. `[report.match]` requires offset=2 expect=[0x09].
        out[0] = 0x01; // envelope header byte 0 (version)
        out[1] = 0x00; // reserved / envelope padding
        out[2] = 0x09; // report_type — matches `[report.match]` offset=2 expect=[0x09]
        out[3] = 0x40; // payload_len (64)

        self.frame_counter +%= 1;
        std.mem.writeInt(u32, out[4..8], self.frame_counter, .little);
        std.mem.writeInt(u64, out[8..16], params.buttons, .little);

        // Sticks at bytes 48-55.
        std.mem.writeInt(i16, out[48..50], params.left_x, .little);
        std.mem.writeInt(i16, out[50..52], params.left_y, .little);
        std.mem.writeInt(i16, out[52..54], params.right_x, .little);
        std.mem.writeInt(i16, out[54..56], params.right_y, .little);

        return out;
    }
};

// --- Tests -----------------------------------------------------------------

const testing = std.testing;

test "fixtures.steam_deck: idle report envelope" {
    var gen = ReportGenerator{};
    const r = gen.idleReport();
    try testing.expectEqual(@as(u8, 0x01), r[0]);
    try testing.expectEqual(@as(u8, 0x00), r[1]);
    try testing.expectEqual(@as(u8, 0x09), r[2]); // match.offset=2 expect=[0x09]
    try testing.expectEqual(@as(u8, 0x40), r[3]); // payload_len
    // frame_counter bumped to 1 on first call (starts at 0, +%= 1).
    try testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, r[4..8], .little));
    // No buttons, no sticks.
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, r[8..16], .little));
    try testing.expectEqual(@as(i16, 0), std.mem.readInt(i16, r[48..50], .little));
}

test "fixtures.steam_deck: buttonPressReport in lizard mode returns zero buttons" {
    var gen = ReportGenerator{};
    const r = gen.buttonPressReport(.A);
    try testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, r[8..16], .little));
}

test "fixtures.steam_deck: buttonPressReport after mode switch sets correct bit" {
    var gen = ReportGenerator{};
    gen.acceptModeSwitch();
    const r = gen.buttonPressReport(.A);
    // A maps to bit 7 per steam-deck.toml button_group.
    try testing.expectEqual(@as(u64, 1 << 7), std.mem.readInt(u64, r[8..16], .little));

    const r2 = gen.buttonPressReport(.M3);
    // M3 maps to bit 41.
    try testing.expectEqual(@as(u64, 1 << 41), std.mem.readInt(u64, r2[8..16], .little));
}

test "fixtures.steam_deck: stickReport encodes little-endian i16 at 48-55" {
    var gen = ReportGenerator{};
    const r = gen.stickReport(100, -100, 0, 32767);
    try testing.expectEqual(@as(i16, 100), std.mem.readInt(i16, r[48..50], .little));
    try testing.expectEqual(@as(i16, -100), std.mem.readInt(i16, r[50..52], .little));
    try testing.expectEqual(@as(i16, 0), std.mem.readInt(i16, r[52..54], .little));
    try testing.expectEqual(@as(i16, 32767), std.mem.readInt(i16, r[54..56], .little));
}

test "fixtures.steam_deck: modeSwitchFeatureReport returns the ID byte" {
    const gen = ReportGenerator{};
    const r = gen.modeSwitchFeatureReport();
    try testing.expectEqual(@as(u8, 0x81), r[0]);
}
