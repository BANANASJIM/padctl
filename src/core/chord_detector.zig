const std = @import("std");
const state = @import("state.zig");
const ButtonId = state.ButtonId;
const user_config = @import("../config/user_config.zig");

pub const MAX_SELECTORS = 16;

pub const Config = struct {
    modifier_mask: u64,
    selectors: [MAX_SELECTORS]u64 = [_]u64{0} ** MAX_SELECTORS,
    selector_count: u8 = 0,
    hold_ns: u64 = 80 * std.time.ns_per_ms,
};

pub const Detector = struct {
    cfg: Config,
    modifier_first_held_ns: ?u64 = null,
    last_fired_idx: ?u8 = null,

    pub fn init(cfg: Config) Detector {
        return .{ .cfg = cfg };
    }

    pub const Result = struct {
        chord_index: ?u8 = null,
        suppress_mask: u64 = 0,
    };

    pub fn step(self: *Detector, buttons: u64, prev: u64, now_ns: u64) Result {
        if (self.cfg.selector_count == 0 or self.cfg.modifier_mask == 0) return .{};

        const modifier_held = (buttons & self.cfg.modifier_mask) == self.cfg.modifier_mask;
        if (!modifier_held) {
            self.modifier_first_held_ns = null;
            self.last_fired_idx = null;
            return .{};
        }

        if (self.modifier_first_held_ns == null) self.modifier_first_held_ns = now_ns;

        var suppress: u64 = 0;
        var i: u8 = 0;
        while (i < self.cfg.selector_count) : (i += 1) {
            suppress |= self.cfg.selectors[i];
        }

        const elapsed = now_ns -| (self.modifier_first_held_ns orelse now_ns);
        if (elapsed < self.cfg.hold_ns) return .{ .suppress_mask = suppress };

        var fired: ?u8 = null;
        i = 0;
        while (i < self.cfg.selector_count) : (i += 1) {
            const m = self.cfg.selectors[i];
            const now_pressed = (buttons & m) != 0;
            const was_pressed = (prev & m) != 0;
            if (now_pressed and !was_pressed) {
                fired = i + 1;
                break;
            }
        }

        if (fired) |idx| {
            if (self.last_fired_idx != null and self.last_fired_idx.? == idx) {
                return .{ .suppress_mask = suppress };
            }
            self.last_fired_idx = idx;
            return .{ .chord_index = idx, .suppress_mask = suppress };
        }

        return .{ .suppress_mask = suppress };
    }
};

pub fn buttonBit(name: []const u8) ?u64 {
    const id = std.meta.stringToEnum(ButtonId, name) orelse return null;
    return @as(u64, 1) << @as(u6, @intCast(@intFromEnum(id)));
}

pub fn buildModifierMask(names: []const []const u8) ?u64 {
    if (names.len == 0) return null;
    var mask: u64 = 0;
    for (names) |n| {
        const b = buttonBit(n) orelse return null;
        mask |= b;
    }
    return mask;
}

pub fn buildSelectors(names: []const []const u8, out: *[MAX_SELECTORS]u64) ?u8 {
    if (names.len == 0 or names.len > MAX_SELECTORS) return null;
    for (names, 0..) |n, i| {
        const b = buttonBit(n) orelse return null;
        out[i] = b;
    }
    return @intCast(names.len);
}

pub fn fromUserConfig(maybe_cfg: ?user_config.ChordSwitchConfig) ?Config {
    const cfg = maybe_cfg orelse return null;
    const modifier_names = cfg.modifier orelse return null;
    const selector_names = cfg.selectors orelse return null;
    const mod_mask = buildModifierMask(modifier_names) orelse {
        std.log.warn("[chord_switch] modifier contains unknown button name; feature disabled", .{});
        return null;
    };
    var selectors: [MAX_SELECTORS]u64 = [_]u64{0} ** MAX_SELECTORS;
    const count = buildSelectors(selector_names, &selectors) orelse {
        std.log.warn("[chord_switch] selectors invalid (empty, too many, or unknown name); feature disabled", .{});
        return null;
    };
    const hold_ms: u64 = if (cfg.hold_ms <= 0) 0 else @intCast(cfg.hold_ms);
    return .{
        .modifier_mask = mod_mask,
        .selectors = selectors,
        .selector_count = count,
        .hold_ns = hold_ms * std.time.ns_per_ms,
    };
}

const testing = std.testing;

fn bit(id: ButtonId) u64 {
    return @as(u64, 1) << @intFromEnum(id);
}

test "chord_detector: no modifier held -> no fire, no suppress" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const r = d.step(bit(.A), 0, 0);
    try testing.expectEqual(@as(?u8, null), r.chord_index);
    try testing.expectEqual(@as(u64, 0), r.suppress_mask);
}

test "chord_detector: modifier+selector after hold fires chord 1" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM) | bit(.RM), 0, t0);
    const r = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, 1), r.chord_index);
    try testing.expect((r.suppress_mask & bit(.A)) != 0);
}

test "chord_detector: chord_index missing -> selector list empty -> no fire" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selector_count = 0,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    const r = d.step(bit(.LM) | bit(.RM) | bit(.A), 0, t0);
    try testing.expectEqual(@as(?u8, null), r.chord_index);
    try testing.expectEqual(@as(u64, 0), r.suppress_mask);
}

test "chord_detector: partial modifier (only LM held) does not fire" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM), 0, t0);
    const r = d.step(bit(.LM) | bit(.A), bit(.LM), t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), r.chord_index);
    try testing.expectEqual(@as(u64, 0), r.suppress_mask);
}

test "chord_detector: selector before debounce hold elapses -> no fire, but suppress" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM) | bit(.RM), 0, t0);
    const r = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 50 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), r.chord_index);
    try testing.expect((r.suppress_mask & bit(.A)) != 0);
}

test "chord_detector: fires once, repeated press of same selector does not retrigger" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM) | bit(.RM), 0, t0);
    const r1 = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, 1), r1.chord_index);
    const r2 = d.step(bit(.LM) | bit(.RM), bit(.LM) | bit(.RM) | bit(.A), t0 + 110 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), r2.chord_index);
    const r3 = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 120 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, null), r3.chord_index);
}

test "chord_detector: modifier release resets debounce + last-fired" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM) | bit(.RM), 0, t0);
    _ = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 100 * std.time.ns_per_ms);
    _ = d.step(0, bit(.LM) | bit(.RM) | bit(.A), t0 + 200 * std.time.ns_per_ms);
    _ = d.step(bit(.LM) | bit(.RM), 0, t0 + 300 * std.time.ns_per_ms);
    const r = d.step(bit(.LM) | bit(.RM) | bit(.A), bit(.LM) | bit(.RM), t0 + 400 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, 1), r.chord_index);
}

test "chord_detector: third selector fires chord 3" {
    var d = Detector.init(.{
        .modifier_mask = bit(.LM) | bit(.RM),
        .selectors = .{ bit(.A), bit(.B), bit(.X), bit(.Y) } ++ [_]u64{0} ** 12,
        .selector_count = 4,
        .hold_ns = 80 * std.time.ns_per_ms,
    });
    const t0: u64 = 1_000_000_000;
    _ = d.step(bit(.LM) | bit(.RM), 0, t0);
    const r = d.step(bit(.LM) | bit(.RM) | bit(.X), bit(.LM) | bit(.RM), t0 + 100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(?u8, 3), r.chord_index);
}

test "buildModifierMask: known buttons produce OR-mask" {
    const mask = buildModifierMask(&.{ "LM", "RM" }) orelse return error.TestUnexpectedResult;
    try testing.expectEqual(bit(.LM) | bit(.RM), mask);
}

test "buildModifierMask: unknown button name returns null" {
    try testing.expectEqual(@as(?u64, null), buildModifierMask(&.{ "LM", "ZZZ" }));
}

test "buildSelectors: known buttons produce array" {
    var out: [MAX_SELECTORS]u64 = [_]u64{0} ** MAX_SELECTORS;
    const n = buildSelectors(&.{ "A", "B", "X", "Y" }, &out) orelse return error.TestUnexpectedResult;
    try testing.expectEqual(@as(u8, 4), n);
    try testing.expectEqual(bit(.A), out[0]);
    try testing.expectEqual(bit(.Y), out[3]);
}

test "buildSelectors: too many entries returns null" {
    var out: [MAX_SELECTORS]u64 = [_]u64{0} ** MAX_SELECTORS;
    var names_buf: [MAX_SELECTORS + 1][]const u8 = undefined;
    for (0..MAX_SELECTORS + 1) |i| names_buf[i] = "A";
    try testing.expectEqual(@as(?u8, null), buildSelectors(&names_buf, &out));
}
