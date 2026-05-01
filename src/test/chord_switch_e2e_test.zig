// Integration test: ChordSwitchConfig TOML parse → detector → chord_index.
//
// Covers the gap between the per-unit chord_detector tests and the
// supervisor-level lookupChordMappingName tests: verifies that the full
// pipeline from TOML text → parsed ChordSwitchConfig → fromUserConfig
// → Detector.step() produces the correct chord_index signal, and that
// mapping files with chord_index parse correctly through mapping.parseString.

const std = @import("std");
const testing = std.testing;

const toml = @import("toml");
const user_config = @import("../config/user_config.zig");
const mapping_cfg = @import("../config/mapping.zig");
const chord_detector = @import("../core/chord_detector.zig");
const state = @import("../core/state.zig");

const ButtonId = state.ButtonId;

fn bit(id: ButtonId) u64 {
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

// --- TOML parse → ChordSwitchConfig ---

// SSOT: consume the canonical example file so any drift is caught at build time.
test "chord_switch_e2e: examples/configs/chord-switch.toml parses correctly" {
    const allocator = testing.allocator;
    const toml_text = @embedFile("../../examples/configs/chord-switch.toml");
    var parser = toml.Parser(user_config.UserConfig).init(allocator);
    defer parser.deinit();
    const result = try parser.parseString(toml_text);
    defer result.deinit();

    const cs = result.value.chord_switch orelse return error.MissingChordSwitch;
    // modifier = ["LM", "RM"]
    try testing.expectEqual(@as(usize, 2), cs.modifier.?.len);
    try testing.expectEqualStrings("LM", cs.modifier.?[0]);
    try testing.expectEqualStrings("RM", cs.modifier.?[1]);
    // selectors = ["A", "B", "X", "Y"]
    try testing.expectEqual(@as(usize, 4), cs.selectors.?.len);
    try testing.expectEqualStrings("A", cs.selectors.?[0]);
    // hold_ms = 120
    try testing.expectEqual(@as(i64, 120), cs.hold_ms);
}

// SSOT: mapping example file pins chord_index field round-trip.
test "chord_switch_e2e: examples/mappings/chord-switch-mapping-a.toml parses correctly" {
    const allocator = testing.allocator;
    const toml_text = @embedFile("../../examples/mappings/chord-switch-mapping-a.toml");
    const result = try mapping_cfg.parseString(allocator, toml_text);
    defer result.deinit();
    // chord_index = 1 per file
    try testing.expectEqual(@as(?u8, 1), result.value.chord_index);
}

// --- ChordSwitchConfig → Detector wiring ---

test "chord_switch_e2e: modifier alone does not fire" {
    const cs = user_config.ChordSwitchConfig{
        .modifier = &.{"LM"},
        .selectors = &.{ "A", "B" },
        .hold_ms = 80,
    };
    const cfg = chord_detector.fromUserConfig(cs).?;
    var det = chord_detector.Detector.init(cfg);

    const lm = bit(.LM);
    const t0: u64 = 0;
    const result = det.step(lm, 0, t0);
    try testing.expectEqual(@as(?u8, null), result.chord_index);
}

test "chord_switch_e2e: hold LM then tap A after debounce → chord_index=1" {
    const cs = user_config.ChordSwitchConfig{
        .modifier = &.{"LM"},
        .selectors = &.{ "A", "B" },
        .hold_ms = 80,
    };
    const cfg = chord_detector.fromUserConfig(cs).?;
    var det = chord_detector.Detector.init(cfg);

    const lm = bit(.LM);
    const a = bit(.A);
    const hold_ns: u64 = 80 * std.time.ns_per_ms;

    // Press LM at t=0
    _ = det.step(lm, 0, 0);
    // After debounce, tap A
    const result = det.step(lm | a, lm, hold_ns + 1);
    try testing.expectEqual(@as(?u8, 1), result.chord_index);
}

test "chord_switch_e2e: hold LM then tap B after debounce → chord_index=2" {
    const cs = user_config.ChordSwitchConfig{
        .modifier = &.{"LM"},
        .selectors = &.{ "A", "B" },
        .hold_ms = 80,
    };
    const cfg = chord_detector.fromUserConfig(cs).?;
    var det = chord_detector.Detector.init(cfg);

    const lm = bit(.LM);
    const b = bit(.B);
    const hold_ns: u64 = 80 * std.time.ns_per_ms;

    _ = det.step(lm, 0, 0);
    const result = det.step(lm | b, lm, hold_ns + 1);
    try testing.expectEqual(@as(?u8, 2), result.chord_index);
}

test "chord_switch_e2e: A alone (no modifier) does not fire" {
    const cs = user_config.ChordSwitchConfig{
        .modifier = &.{"LM"},
        .selectors = &.{ "A", "B" },
        .hold_ms = 80,
    };
    const cfg = chord_detector.fromUserConfig(cs).?;
    var det = chord_detector.Detector.init(cfg);

    const a = bit(.A);
    const result = det.step(a, 0, 200 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), result.chord_index);
}

test "chord_switch_e2e: selector edge within hold_ms window is suppressed but not fired" {
    const cs = user_config.ChordSwitchConfig{
        .modifier = &.{"LM"},
        .selectors = &.{"A"},
        .hold_ms = 80,
    };
    const cfg = chord_detector.fromUserConfig(cs).?;
    var det = chord_detector.Detector.init(cfg);

    const lm = bit(.LM);
    const a = bit(.A);

    _ = det.step(lm, 0, 0);
    // Tap A within the debounce window (40 ms < 80 ms)
    const result = det.step(lm | a, lm, 40 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), result.chord_index);
    // Selectors are suppressed while modifier held (even in debounce)
    try testing.expect(result.suppress_mask & a != 0);
}

// --- mapping TOML: chord_index field ---

test "chord_switch_e2e: mapping with chord_index=1 parses correctly" {
    const allocator = testing.allocator;
    const result = try mapping_cfg.parseString(allocator,
        \\chord_index = 1
    );
    defer result.deinit();
    try testing.expectEqual(@as(?u8, 1), result.value.chord_index);
}

test "chord_switch_e2e: mapping without chord_index has null" {
    const allocator = testing.allocator;
    const result = try mapping_cfg.parseString(allocator, "");
    defer result.deinit();
    try testing.expectEqual(@as(?u8, null), result.value.chord_index);
}

test "chord_switch_e2e: mapping with chord_index=255 (max) parses correctly" {
    const allocator = testing.allocator;
    const result = try mapping_cfg.parseString(allocator,
        \\chord_index = 255
    );
    defer result.deinit();
    try testing.expectEqual(@as(?u8, 255), result.value.chord_index);
}
