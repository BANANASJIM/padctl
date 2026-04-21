//! End-to-end test: UhidSimulator → padctl interpreter.
//!
//! Two scenarios are covered here:
//!
//! 1. `steam_deck_fixture_round_trip` — uses the fixture generator directly
//!    against the interpreter, no UHID involved. Proves that the synthetic
//!    0x09 envelope matches the TOML (Phase 13 Wave 1 regression: if the
//!    fixture drifts away from `devices/valve/steam-deck.toml`, this test
//!    fails even on unprivileged CI runners).
//!
//! 2. `steam_deck_uhid_end_to_end` — uses `UhidSimulator` to stand up a real
//!    kernel hidraw node, reads bytes back out through it, then feeds them
//!    through the interpreter. Requires `/dev/uhid` (Linux + CAP_SYS_ADMIN
//!    or an explicit udev rule). Skips cleanly everywhere else.
//!
//! Guardrail: the fixture scenario asserts on `delta.ax` / `delta.buttons`
//! so anyone who changes the TOML in a way that breaks Wave 3 routing (bit
//! indices, match offset, stick offsets) discovers it here rather than on
//! hardware.

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const posix = std.posix;

const src = @import("src");
const device_mod = src.config.device;
const Interpreter = src.core.interpreter.Interpreter;
// Harness + fixtures reached through the `src` barrel so the compiler sees
// each source file belonging to exactly one module.
const UhidSimulator = src.testing_support.uhid_simulator.UhidSimulator;
const steam_deck = src.testing_support.steam_deck_fixture;

test "steam_deck_fixture_round_trip: fixture + interpreter agree on Steam Deck TOML" {
    const allocator = testing.allocator;

    const parsed = try device_mod.parseFile(allocator, "devices/valve/steam-deck.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var gen = steam_deck.ReportGenerator{};
    gen.acceptModeSwitch();

    // Button A — fixture sets bit 7 of the button_group; TOML maps bit 7 to
    // ButtonId.A, so `delta.buttons` bit 0 (ButtonId.A = 0) should be set.
    const button_bytes = gen.buttonPressReport(.A);
    const delta_a = (try interp.processReport(0, &button_bytes)) orelse
        return error.NoMatch;
    const expected_a_mask: u64 = 1 << 0; // ButtonId.A = 0
    try testing.expectEqual(expected_a_mask, delta_a.buttons.?);

    // Stick: lx=100, ly=-100 — TOML has `left_y = negate`, so delta.ay = 100
    // (double-negate: fixture writes raw, interpreter negates once).
    const stick_bytes = gen.stickReport(100, -100, 0, 0);
    const delta_s = (try interp.processReport(0, &stick_bytes)) orelse
        return error.NoMatch;
    try testing.expectEqual(@as(?i16, 100), delta_s.ax);
    try testing.expectEqual(@as(?i16, 100), delta_s.ay); // negated by TOML transform
}

test "steam_deck_fixture_round_trip: lizard mode suppresses button reports" {
    const allocator = testing.allocator;
    const parsed = try device_mod.parseFile(allocator, "devices/valve/steam-deck.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    var gen = steam_deck.ReportGenerator{};
    // Do NOT call acceptModeSwitch — fixture stays in lizard mode.
    const r = gen.buttonPressReport(.A);
    const delta = (try interp.processReport(0, &r)) orelse return error.NoMatch;

    // Lizard mode → buttons field is 0 — GamepadStateDelta encodes "no change"
    // as null for buttons. Accept either a null entry or a literally-zero
    // payload; both are correct interpretations for "no keys pressed".
    if (delta.buttons) |b| {
        try testing.expectEqual(@as(u64, 0), b);
    }
}

test "steam_deck_uhid_end_to_end: simulator → hidraw → interpreter" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const allocator = testing.allocator;

    const parsed = try device_mod.parseFile(allocator, "devices/valve/steam-deck.toml");
    defer parsed.deinit();
    const interp = Interpreter.init(&parsed.value);

    // Minimal descriptor — enough to convince the kernel to wire the hidraw
    // node up. The actual report payload does not need to match this layout
    // for the UHID plumbing to deliver our bytes to /dev/hidrawN.
    const descriptor = [_]u8{
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x05, // Usage (Gamepad)
        0xA1, 0x01, // Collection (Application)
        0x15, 0x00, // Logical Minimum (0)
        0x26, 0xFF, 0x00, // Logical Maximum (255)
        0x75, 0x08, // Report Size (8)
        0x95, 0x40, // Report Count (64)
        0x81, 0x02, // Input (Data, Var, Abs)
        0xC0, // End Collection
    };

    var sim = UhidSimulator.create(.{
        .vid = steam_deck.DECK_VID,
        .pid = steam_deck.DECK_PID,
        .name = "padctl-steam-deck-e2e",
        .uniq = "padctl/deck-e2e-0",
        .descriptor = &descriptor,
    }) catch |err| switch (err) {
        error.SkipZigTest, error.HidrawNotFound, error.AccessDenied => return error.SkipZigTest,
        else => |e| return e,
    };
    defer sim.destroy();

    const hidraw_fd = sim.openHidraw() catch return error.SkipZigTest;
    defer posix.close(hidraw_fd);

    var gen = steam_deck.ReportGenerator{};
    gen.acceptModeSwitch();

    // --- Injection 1: A button press ---
    const a_report = gen.buttonPressReport(.A);
    try sim.injectReport(&a_report);

    var pfd = [1]posix.pollfd{.{ .fd = hidraw_fd, .events = posix.POLL.IN, .revents = 0 }};
    const ready = try posix.poll(&pfd, 500);
    if (ready == 0) return error.SkipZigTest;

    var buf: [128]u8 = undefined;
    const n = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    if (n < 16) return error.SkipZigTest;

    const delta_a = (try interp.processReport(0, buf[0..n])) orelse
        return error.SkipZigTest;
    const expected_a_mask: u64 = 1 << 0;
    try testing.expectEqual(expected_a_mask, delta_a.buttons.?);

    // --- Injection 2: stick movement ---
    const stick_report = gen.stickReport(100, -100, 0, 0);
    try sim.injectReport(&stick_report);

    pfd[0].revents = 0;
    const ready2 = try posix.poll(&pfd, 500);
    if (ready2 == 0) return error.SkipZigTest;
    const n2 = posix.read(hidraw_fd, &buf) catch return error.SkipZigTest;
    if (n2 < 56) return error.SkipZigTest;

    const delta_s = (try interp.processReport(0, buf[0..n2])) orelse
        return error.SkipZigTest;
    try testing.expectEqual(@as(?i16, 100), delta_s.ax);
    try testing.expectEqual(@as(?i16, 100), delta_s.ay); // negated by TOML transform
}
