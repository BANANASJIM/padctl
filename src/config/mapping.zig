const std = @import("std");
const toml = @import("toml");
const input_codes = @import("input_codes.zig");
pub const MacroStep = @import("../core/macro.zig").MacroStep;
pub const Macro = @import("../core/macro.zig").Macro;

pub const DerivedAuxCaps = struct {
    needs_rel: bool = false, // REL_X/Y/WHEEL/HWHEEL (gyro mouse, stick mouse/scroll)
    needs_keyboard: bool = false, // KEY_* remaps, dpad arrows
    // bitmask: bit0=BTN_LEFT bit1=BTN_RIGHT bit2=BTN_MIDDLE bit3=BTN_SIDE bit4=BTN_EXTRA
    mouse_buttons: u8 = 0,

    pub fn needsAux(self: DerivedAuxCaps) bool {
        return self.needs_rel or self.needs_keyboard or self.mouse_buttons != 0;
    }
};

pub fn deriveAuxFromMapping(cfg: *const MappingConfig) DerivedAuxCaps {
    var caps = DerivedAuxCaps{};

    if (cfg.gyro) |g| {
        if (std.mem.eql(u8, g.mode, "mouse")) caps.needs_rel = true;
    }

    if (cfg.stick) |sp| {
        scanStick(&caps, sp.left);
        scanStick(&caps, sp.right);
    }

    if (cfg.dpad) |d| {
        if (std.mem.eql(u8, d.mode, "arrows")) caps.needs_keyboard = true;
    }

    if (cfg.remap) |*remap| scanRemapTargets(&caps, cfg, remap);

    if (cfg.layer) |layers| {
        for (layers) |*layer| {
            if (layer.gyro) |g| {
                if (std.mem.eql(u8, g.mode, "mouse")) caps.needs_rel = true;
            }
            scanStick(&caps, layer.stick_left);
            scanStick(&caps, layer.stick_right);
            if (layer.dpad) |d| {
                if (std.mem.eql(u8, d.mode, "arrows")) caps.needs_keyboard = true;
            }
            if (layer.remap) |*remap| scanRemapTargets(&caps, cfg, remap);
        }
    }

    return caps;
}

fn scanStick(caps: *DerivedAuxCaps, stick: ?StickConfig) void {
    const s = stick orelse return;
    if (std.mem.eql(u8, s.mode, "mouse") or std.mem.eql(u8, s.mode, "scroll"))
        caps.needs_rel = true;
}

fn scanTarget(caps: *DerivedAuxCaps, target: []const u8) void {
    if (std.mem.startsWith(u8, target, "KEY_")) {
        caps.needs_keyboard = true;
    } else if (std.mem.eql(u8, target, "mouse_left") or std.mem.eql(u8, target, "BTN_LEFT")) {
        caps.mouse_buttons |= 1;
    } else if (std.mem.eql(u8, target, "mouse_right") or std.mem.eql(u8, target, "BTN_RIGHT")) {
        caps.mouse_buttons |= 2;
    } else if (std.mem.eql(u8, target, "mouse_middle") or std.mem.eql(u8, target, "BTN_MIDDLE")) {
        caps.mouse_buttons |= 4;
    } else if (std.mem.eql(u8, target, "mouse_side") or std.mem.eql(u8, target, "BTN_SIDE")) {
        caps.mouse_buttons |= 8;
    } else if (std.mem.eql(u8, target, "mouse_extra") or std.mem.eql(u8, target, "BTN_EXTRA")) {
        caps.mouse_buttons |= 16;
    } else if (std.mem.eql(u8, target, "mouse_forward") or std.mem.eql(u8, target, "BTN_FORWARD")) {
        caps.mouse_buttons |= 32;
    } else if (std.mem.eql(u8, target, "mouse_back") or std.mem.eql(u8, target, "BTN_BACK")) {
        caps.mouse_buttons |= 64;
    }
}

fn scanRemapTargets(caps: *DerivedAuxCaps, cfg: *const MappingConfig, remap: *const toml.HashMap([]const u8)) void {
    var it = remap.map.iterator();
    while (it.next()) |entry| {
        const target = entry.value_ptr.*;
        if (std.mem.startsWith(u8, target, "macro:")) {
            const macro_name = target["macro:".len..];
            const macros = cfg.macro orelse continue;
            for (macros) |*m| {
                if (!std.mem.eql(u8, m.name, macro_name)) continue;
                for (m.steps) |s| {
                    switch (s) {
                        .tap => |name| scanTarget(caps, name),
                        .down => |name| scanTarget(caps, name),
                        .up => |name| scanTarget(caps, name),
                        .delay, .pause_for_release => {},
                    }
                }
                break;
            }
        } else {
            scanTarget(caps, target);
        }
    }
}

// Maximum EV_KEY codes that buildAuxKeyCodes may produce: all key_table entries (97) + 7 mouse buttons
pub const AUX_KEY_CODES_MAX = 106;

/// Build a key_codes slice for AuxDevice.create() from derived caps.
/// buf must be at least AUX_KEY_CODES_MAX elements.
pub fn buildAuxKeyCodes(caps: DerivedAuxCaps, buf: []u16) []u16 {
    var n: usize = 0;
    if (caps.needs_keyboard) {
        for (input_codes.key_table) |entry| {
            buf[n] = entry.code;
            n += 1;
        }
        // include arrow keys for dpad "arrows" mode (already in key_table, but also dpad arrows mode)
    }
    const mouse_codes = [_]struct { mask: u8, name: []const u8 }{
        .{ .mask = 1, .name = "mouse_left" },
        .{ .mask = 2, .name = "mouse_right" },
        .{ .mask = 4, .name = "mouse_middle" },
        .{ .mask = 8, .name = "mouse_side" },
        .{ .mask = 16, .name = "mouse_extra" },
        .{ .mask = 32, .name = "mouse_forward" },
        .{ .mask = 64, .name = "mouse_back" },
    };
    for (mouse_codes) |mc| {
        if (caps.mouse_buttons & mc.mask != 0) {
            if (input_codes.resolveMouseCode(mc.name)) |code| {
                buf[n] = code;
                n += 1;
            } else |_| {}
        }
    }
    return buf[0..n];
}

pub const GyroConfig = struct {
    mode: []const u8 = "off",
    target: ?[]const u8 = null, // "right_stick" (default) or "left_stick"
    activate: ?[]const u8 = null,
    sensitivity: ?f64 = null,
    sensitivity_x: ?f64 = null,
    sensitivity_y: ?f64 = null,
    deadzone: ?i64 = null,
    smoothing: ?f64 = null,
    curve: ?f64 = null,
    max_val: ?f64 = null,
    invert_x: ?bool = null,
    invert_y: ?bool = null,
};

pub const StickConfig = struct {
    mode: []const u8 = "gamepad",
    deadzone: ?i64 = null,
    sensitivity: ?f64 = null,
    suppress_gamepad: ?bool = null,
};

pub const StickPairConfig = struct {
    left: ?StickConfig = null,
    right: ?StickConfig = null,
};

pub const DpadConfig = struct {
    mode: []const u8 = "gamepad",
    suppress_gamepad: ?bool = null,
};

pub const AdaptiveTriggerParamConfig = struct {
    position: ?i64 = null,
    strength: ?i64 = null,
    start: ?i64 = null,
    end: ?i64 = null,
    amplitude: ?i64 = null,
    frequency: ?i64 = null,
};

pub const AdaptiveTriggerConfig = struct {
    mode: []const u8 = "off",
    command_prefix: []const u8 = "adaptive_trigger_",
    left: ?AdaptiveTriggerParamConfig = null,
    right: ?AdaptiveTriggerParamConfig = null,
};

pub const LayerConfig = struct {
    name: []const u8,
    trigger: []const u8,
    activation: []const u8 = "hold",
    tap: ?[]const u8 = null,
    hold_timeout: ?i64 = null,
    remap: ?toml.HashMap([]const u8) = null,
    gyro: ?GyroConfig = null,
    stick_left: ?StickConfig = null,
    stick_right: ?StickConfig = null,
    dpad: ?DpadConfig = null,
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
};

pub const MappingConfig = struct {
    name: ?[]const u8 = null,
    chord_index: ?u8 = null,
    remap: ?toml.HashMap([]const u8) = null,
    gyro: ?GyroConfig = null,
    stick: ?StickPairConfig = null,
    dpad: ?DpadConfig = null,
    layer: ?[]const LayerConfig = null,
    macro: ?[]const Macro = null,
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
    trigger_threshold: ?u8 = null,
};

pub const ParseResult = toml.Parsed(MappingConfig);

pub fn parseString(allocator: std.mem.Allocator, content: []const u8) !ParseResult {
    var parser = toml.Parser(MappingConfig).init(allocator);
    defer parser.deinit();
    const result = try parser.parseString(content);
    if (lintUnknownFields(allocator, content)) |findings| {
        defer {
            var f = findings;
            f.deinit(allocator);
        }
        warnLintFindings(findings.items);
    } else |_| {} // lint failure (OOM) must not break parsing
    return result;
}

pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);
    return parseString(allocator, content);
}

fn macroExists(cfg: *const MappingConfig, name: []const u8) bool {
    const macros = cfg.macro orelse return false;
    for (macros) |*m| {
        if (std.mem.eql(u8, m.name, name)) return true;
    }
    return false;
}

fn checkRemapMacros(cfg: *const MappingConfig, map: *const toml.HashMap([]const u8)) !void {
    var it = map.map.iterator();
    while (it.next()) |entry| {
        const val = entry.value_ptr.*;
        if (std.mem.startsWith(u8, val, "macro:")) {
            const macro_name = val["macro:".len..];
            if (!macroExists(cfg, macro_name)) return error.UnknownMacro;
        }
    }
}

const valid_at_modes = [_][]const u8{ "off", "feedback", "weapon", "vibration" };

fn validateAdaptiveTrigger(at: *const AdaptiveTriggerConfig) !void {
    for (valid_at_modes) |v| {
        if (std.mem.eql(u8, at.mode, v)) return;
    }
    return error.InvalidConfig;
}

fn remapHasTriggerKey(map: *const toml.HashMap([]const u8)) bool {
    var it = map.map.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "LT") or std.mem.eql(u8, key, "RT")) return true;
    }
    return false;
}

// Returns true when LT/RT appear in any remap but trigger_threshold is not set.
// Exposed for testing; warn at validate time so users see the failure mode before runtime.
pub fn needsTriggerThresholdWarn(cfg: *const MappingConfig) bool {
    if (cfg.trigger_threshold != null) return false;
    if (cfg.remap) |*m| {
        if (remapHasTriggerKey(m)) return true;
    }
    if (cfg.layer) |layers| {
        for (layers) |*layer| {
            if (layer.remap) |*m| {
                if (remapHasTriggerKey(m)) return true;
            }
        }
    }
    return false;
}

// --- schema lint: detect unknown keys in known table contexts ---
//
// Rationale: the underlying TOML library (sam701/zig-toml) silently ignores
// unknown fields by design (forward-compat). For mapping configs that is the
// wrong tradeoff — typos like `trigger_threshold = 128` placed inside
// [[layer]] (instead of top-level) silently break the user's setup (#163).
// This linter re-walks the raw TOML text and warns on any key that does not
// belong to the schema for the current table context.

pub const LintFinding = struct {
    line: usize, // 1-based line number
    table: []const u8, // table path or "" for top-level; borrowed from input
    unknown_key: []const u8, // borrowed from input
};

const TableKind = enum {
    top_level,
    free_form, // HashMap-backed: any key allowed
    mapping_config,
    layer_config,
    gyro_config,
    stick_pair_config,
    stick_config,
    dpad_config,
    adaptive_trigger_config,
    adaptive_trigger_param_config,
    macro_config,
    unknown, // unrecognised header — skip lint (do not punish forward-compat sections)
};

fn structFieldNames(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;
    comptime var names: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |f, i| names[i] = f.name;
    const final = names;
    return &final;
}

fn allowlistFor(kind: TableKind) ?[]const []const u8 {
    return switch (kind) {
        .top_level, .mapping_config => structFieldNames(MappingConfig),
        .layer_config => structFieldNames(LayerConfig),
        .gyro_config => structFieldNames(GyroConfig),
        .stick_pair_config => structFieldNames(StickPairConfig),
        .stick_config => structFieldNames(StickConfig),
        .dpad_config => structFieldNames(DpadConfig),
        .adaptive_trigger_config => structFieldNames(AdaptiveTriggerConfig),
        .adaptive_trigger_param_config => structFieldNames(AdaptiveTriggerParamConfig),
        .macro_config => structFieldNames(Macro),
        .free_form, .unknown => null,
    };
}

fn classifyTable(header: []const u8) TableKind {
    if (header.len == 0) return .top_level;

    if (std.mem.eql(u8, header, "remap")) return .free_form;
    if (std.mem.eql(u8, header, "gyro")) return .gyro_config;
    if (std.mem.eql(u8, header, "stick")) return .stick_pair_config;
    if (std.mem.eql(u8, header, "stick.left") or std.mem.eql(u8, header, "stick.right")) return .stick_config;
    if (std.mem.eql(u8, header, "dpad")) return .dpad_config;
    if (std.mem.eql(u8, header, "adaptive_trigger")) return .adaptive_trigger_config;
    if (std.mem.eql(u8, header, "adaptive_trigger.left") or
        std.mem.eql(u8, header, "adaptive_trigger.right")) return .adaptive_trigger_param_config;

    if (std.mem.eql(u8, header, "layer")) return .layer_config;
    if (std.mem.eql(u8, header, "layer.remap")) return .free_form;
    if (std.mem.eql(u8, header, "layer.gyro")) return .gyro_config;
    if (std.mem.eql(u8, header, "layer.stick_left") or
        std.mem.eql(u8, header, "layer.stick_right")) return .stick_config;
    if (std.mem.eql(u8, header, "layer.dpad")) return .dpad_config;
    if (std.mem.eql(u8, header, "layer.adaptive_trigger")) return .adaptive_trigger_config;
    if (std.mem.eql(u8, header, "layer.adaptive_trigger.left") or
        std.mem.eql(u8, header, "layer.adaptive_trigger.right")) return .adaptive_trigger_param_config;

    if (std.mem.eql(u8, header, "macro")) return .macro_config;

    return .unknown;
}

// Find the first occurrence of `c` in `s` outside of double-quoted spans.
fn indexOfUnquoted(s: []const u8, c: u8) ?usize {
    var in_str = false;
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const ch = s[i];
        if (ch == '\\' and i + 1 < s.len and in_str) {
            i += 1;
            continue;
        }
        if (ch == '"') {
            in_str = !in_str;
            continue;
        }
        if (!in_str and ch == c) return i;
    }
    return null;
}

fn trimWhitespace(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn isValidBareKey(key: []const u8) bool {
    if (key.len == 0) return false;
    for (key) |c| {
        const ok = (c >= 'A' and c <= 'Z') or
            (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or
            c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

// Increase / decrease bracket depth for chars on a line, respecting
// quoted spans. Returns net depth delta.
fn bracketDelta(s: []const u8) i32 {
    var depth: i32 = 0;
    var in_str = false;
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const ch = s[i];
        if (ch == '\\' and i + 1 < s.len and in_str) {
            i += 1;
            continue;
        }
        if (ch == '"') {
            in_str = !in_str;
            continue;
        }
        if (in_str) continue;
        if (ch == '#') break; // comment to end-of-line
        switch (ch) {
            '[', '{' => depth += 1,
            ']', '}' => depth -= 1,
            else => {},
        }
    }
    return depth;
}

fn keyIsKnown(allowlist: []const []const u8, key: []const u8) bool {
    for (allowlist) |name| {
        if (std.mem.eql(u8, name, key)) return true;
    }
    return false;
}

/// Walk raw TOML text and collect findings for keys that do not match the
/// schema of the enclosing table. Caller owns the returned ArrayList.
///
/// This is intentionally a lightweight line-based scan — it does NOT replace
/// the TOML parser. Multi-line values (arrays, inline tables spanning lines)
/// are skipped while bracket depth is non-zero, so keys nested inside arrays
/// of inline tables (e.g. macro `steps = [{ tap = "B" }, ...]`) are not
/// mis-classified as top-level keys.
pub fn lintUnknownFields(allocator: std.mem.Allocator, raw_toml: []const u8) !std.ArrayList(LintFinding) {
    var findings: std.ArrayList(LintFinding) = .empty;
    errdefer findings.deinit(allocator);

    var current_header: []const u8 = "";
    var depth: i32 = 0;
    var line_no: usize = 0;

    var it = std.mem.splitScalar(u8, raw_toml, '\n');
    while (it.next()) |raw_line| {
        line_no += 1;

        // Strip a trailing comment but only when not inside an open bracket /
        // quoted span — the cheap path is fine for our purposes.
        const trimmed_full = trimWhitespace(raw_line);
        if (trimmed_full.len == 0) continue;
        if (trimmed_full[0] == '#') continue;

        // If currently inside a multi-line value, just track depth.
        if (depth > 0) {
            depth += bracketDelta(raw_line);
            if (depth < 0) depth = 0;
            continue;
        }

        // Section header: [foo] or [[foo]]
        if (trimmed_full[0] == '[') {
            if (std.mem.startsWith(u8, trimmed_full, "[[")) {
                const end = std.mem.indexOf(u8, trimmed_full, "]]") orelse continue;
                current_header = trimWhitespace(trimmed_full[2..end]);
            } else {
                const end = std.mem.indexOfScalar(u8, trimmed_full, ']') orelse continue;
                current_header = trimWhitespace(trimmed_full[1..end]);
            }
            continue;
        }

        // Otherwise: candidate `key = value` line.
        const eq_idx = indexOfUnquoted(trimmed_full, '=') orelse continue;
        const key_raw = trimWhitespace(trimmed_full[0..eq_idx]);
        const value_raw = if (eq_idx + 1 < trimmed_full.len) trimmed_full[eq_idx + 1 ..] else "";

        // Bare keys only — quoted/dotted keys are uncommon in our schema and
        // safer to skip than to mis-flag.
        if (!isValidBareKey(key_raw)) {
            depth += bracketDelta(value_raw);
            if (depth < 0) depth = 0;
            continue;
        }

        const kind = classifyTable(current_header);
        if (allowlistFor(kind)) |allow| {
            if (!keyIsKnown(allow, key_raw)) {
                try findings.append(allocator, .{
                    .line = line_no,
                    .table = current_header,
                    .unknown_key = key_raw,
                });
            }
        }

        depth += bracketDelta(value_raw);
        if (depth < 0) depth = 0;
    }

    return findings;
}

fn warnLintFindings(findings: []const LintFinding) void {
    for (findings) |f| {
        if (f.table.len == 0) {
            std.log.warn("config: unknown key '{s}' at top-level (line {d}) — typo or misplaced field?", .{ f.unknown_key, f.line });
        } else {
            std.log.warn("config: unknown key '{s}' inside [{s}] (line {d}) — typo or misplaced field?", .{ f.unknown_key, f.table, f.line });
        }
    }
}

pub fn validate(cfg: *const MappingConfig) !void {
    if (cfg.remap) |*m| try checkRemapMacros(cfg, m);
    if (cfg.adaptive_trigger) |*at| try validateAdaptiveTrigger(at);

    if (needsTriggerThresholdWarn(cfg)) {
        std.log.warn("config: LT/RT used in [remap] or [layer.remap] without trigger_threshold — analog triggers are not synthesized into button events; add trigger_threshold = 128 (or your preferred 0-255 value) to enable", .{});
    }

    const layers = cfg.layer orelse return;

    var seen_buf: [64][]const u8 = undefined;
    var seen_len: usize = 0;

    for (layers) |*layer| {
        if (!std.mem.eql(u8, layer.activation, "hold") and
            !std.mem.eql(u8, layer.activation, "toggle"))
            return error.InvalidConfig;

        if (layer.hold_timeout) |t| {
            if (t < 1 or t > 5000) return error.InvalidConfig;
        }

        for (seen_buf[0..seen_len]) |name| {
            if (std.mem.eql(u8, name, layer.name)) return error.InvalidConfig;
        }
        if (seen_len >= seen_buf.len) return error.InvalidConfig;
        seen_buf[seen_len] = layer.name;
        seen_len += 1;

        if (layer.tap) |tap| {
            if (std.mem.startsWith(u8, tap, "macro:")) {
                return error.LayerTapCannotBeMacro;
            }
        }

        if (layer.remap) |*m| try checkRemapMacros(cfg, m);
        if (layer.adaptive_trigger) |*at| try validateAdaptiveTrigger(at);
    }
}

// --- tests ---

const test_toml_basic =
    \\name = "test"
    \\
    \\[remap]
    \\M1 = "KEY_F13"
    \\M2 = "disabled"
    \\A = "B"
;

test "mapping: MappingConfig parses name and remap" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_basic);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("test", cfg.name.?);
    try std.testing.expect(cfg.remap != null);
    try std.testing.expectEqualStrings("KEY_F13", cfg.remap.?.map.get("M1").?);
    try std.testing.expectEqualStrings("disabled", cfg.remap.?.map.get("M2").?);
    try std.testing.expectEqualStrings("B", cfg.remap.?.map.get("A").?);
}

test "mapping: MappingConfig: empty config" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try std.testing.expect(result.value.name == null);
    try std.testing.expect(result.value.remap == null);
    try std.testing.expect(result.value.layer == null);
    try std.testing.expect(result.value.chord_index == null);
}

test "mapping: MappingConfig: chord_index parses (issue #183)" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\name = "fps"
        \\chord_index = 1
    );
    defer result.deinit();
    try std.testing.expectEqual(@as(?u8, 1), result.value.chord_index);
}

const test_toml_full =
    \\name = "default"
    \\
    \\[remap]
    \\M1 = "KEY_F13"
    \\C = "BTN_TRIGGER_HAPPY1"
    \\
    \\[gyro]
    \\mode = "mouse"
    \\activate = "hold_RB"
    \\sensitivity = 15.0
    \\deadzone = 50
    \\smoothing = 0.3
    \\curve = 1.0
    \\invert_x = false
    \\invert_y = false
    \\
    \\[stick.left]
    \\mode = "gamepad"
    \\deadzone = 128
    \\sensitivity = 1.0
    \\suppress_gamepad = false
    \\
    \\[stick.right]
    \\mode = "gamepad"
    \\deadzone = 128
    \\sensitivity = 1.0
    \\suppress_gamepad = false
    \\
    \\[dpad]
    \\mode = "gamepad"
    \\suppress_gamepad = false
    \\
    \\[[layer]]
    \\name = "aim"
    \\trigger = "LM"
    \\activation = "hold"
    \\tap = "mouse_side"
    \\hold_timeout = 200
    \\
    \\[layer.remap]
    \\RB = "mouse_left"
    \\
    \\[layer.gyro]
    \\mode = "mouse"
    \\sensitivity = 2.0
    \\
    \\[layer.stick_left]
    \\mode = "scroll"
    \\
    \\[layer.stick_right]
    \\mode = "mouse"
    \\sensitivity = 1.0
    \\suppress_gamepad = true
    \\
    \\[layer.dpad]
    \\mode = "arrows"
    \\suppress_gamepad = true
    \\
    \\[[layer]]
    \\name = "fn"
    \\trigger = "Select"
    \\activation = "toggle"
    \\
    \\[layer.remap]
    \\A = "KEY_F1"
    \\B = "KEY_F2"
;

test "mapping: MappingConfig: full config with layers, gyro, stick, dpad" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_full);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expectEqualStrings("default", cfg.name.?);

    // gyro
    try std.testing.expect(cfg.gyro != null);
    try std.testing.expectEqualStrings("mouse", cfg.gyro.?.mode);
    try std.testing.expectEqualStrings("hold_RB", cfg.gyro.?.activate.?);
    try std.testing.expectEqual(@as(?f64, 15.0), cfg.gyro.?.sensitivity);
    try std.testing.expectEqual(@as(?i64, 50), cfg.gyro.?.deadzone);

    // stick
    try std.testing.expect(cfg.stick != null);
    try std.testing.expect(cfg.stick.?.left != null);
    try std.testing.expectEqualStrings("gamepad", cfg.stick.?.left.?.mode);
    try std.testing.expectEqual(@as(?i64, 128), cfg.stick.?.left.?.deadzone);

    // dpad
    try std.testing.expect(cfg.dpad != null);
    try std.testing.expectEqualStrings("gamepad", cfg.dpad.?.mode);

    // layers ordered
    try std.testing.expect(cfg.layer != null);
    try std.testing.expectEqual(@as(usize, 2), cfg.layer.?.len);
    try std.testing.expectEqualStrings("aim", cfg.layer.?[0].name);
    try std.testing.expectEqualStrings("fn", cfg.layer.?[1].name);

    // layer[0] fields
    const aim = cfg.layer.?[0];
    try std.testing.expectEqualStrings("hold", aim.activation);
    try std.testing.expectEqualStrings("mouse_side", aim.tap.?);
    try std.testing.expectEqual(@as(?i64, 200), aim.hold_timeout);
    try std.testing.expect(aim.remap != null);
    try std.testing.expectEqualStrings("mouse_left", aim.remap.?.map.get("RB").?);

    // layer[0] gyro override
    try std.testing.expect(aim.gyro != null);
    try std.testing.expectEqualStrings("mouse", aim.gyro.?.mode);
    try std.testing.expectEqual(@as(?f64, 2.0), aim.gyro.?.sensitivity);

    // layer[0] stick overrides
    try std.testing.expect(aim.stick_left != null);
    try std.testing.expectEqualStrings("scroll", aim.stick_left.?.mode);
    try std.testing.expect(aim.stick_right != null);
    try std.testing.expectEqualStrings("mouse", aim.stick_right.?.mode);
    try std.testing.expectEqual(@as(?bool, true), aim.stick_right.?.suppress_gamepad);

    // layer[0] dpad override
    try std.testing.expect(aim.dpad != null);
    try std.testing.expectEqualStrings("arrows", aim.dpad.?.mode);

    // layer[1] fields
    const fn_layer = cfg.layer.?[1];
    try std.testing.expectEqualStrings("toggle", fn_layer.activation);
    try std.testing.expect(fn_layer.remap != null);
    try std.testing.expectEqualStrings("KEY_F1", fn_layer.remap.?.map.get("A").?);

    try validate(&cfg);
}

test "mapping: validate: missing [mapping] section returns default empty MappingConfig" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try validate(&result.value);
}

test "mapping: validate: [[layer]] preserved in declaration order" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "first"
        \\trigger = "A"
        \\
        \\[[layer]]
        \\name = "second"
        \\trigger = "B"
        \\
        \\[[layer]]
        \\name = "third"
        \\trigger = "X"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const layers = result.value.layer.?;
    try std.testing.expectEqual(@as(usize, 3), layers.len);
    try std.testing.expectEqualStrings("first", layers[0].name);
    try std.testing.expectEqualStrings("second", layers[1].name);
    try std.testing.expectEqualStrings("third", layers[2].name);
    try validate(&result.value);
}

test "mapping: validate: invalid activation value returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "bad"
        \\trigger = "A"
        \\activation = "press"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: validate: duplicate layer name returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "aim"
        \\trigger = "A"
        \\
        \\[[layer]]
        \\name = "aim"
        \\trigger = "B"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: validate: hold_timeout out of range returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "bad"
        \\trigger = "A"
        \\hold_timeout = 9999
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

const test_toml_macro =
    \\[[macro]]
    \\name = "dodge_roll"
    \\steps = [
    \\    { tap = "B" },
    \\    { delay = 50 },
    \\    { tap = "LEFT" },
    \\]
    \\
    \\[[macro]]
    \\name = "shift_hold"
    \\steps = [
    \\    { down = "KEY_LEFTSHIFT" },
    \\    "pause_for_release",
    \\    { up = "KEY_LEFTSHIFT" },
    \\]
    \\
    \\[[macro]]
    \\name = "noop"
    \\steps = []
    \\
    \\[remap]
    \\M1 = "macro:dodge_roll"
;

test "mapping: [[macro]] multi-entry parse: all step primitives correct" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, test_toml_macro);
    defer result.deinit();

    const cfg = result.value;
    try std.testing.expect(cfg.macro != null);
    const macros = cfg.macro.?;
    try std.testing.expectEqual(@as(usize, 3), macros.len);

    const dodge = macros[0];
    try std.testing.expectEqualStrings("dodge_roll", dodge.name);
    try std.testing.expectEqual(@as(usize, 3), dodge.steps.len);
    try std.testing.expectEqualStrings("B", dodge.steps[0].tap);
    try std.testing.expectEqual(@as(u32, 50), dodge.steps[1].delay);
    try std.testing.expectEqualStrings("LEFT", dodge.steps[2].tap);

    const shift = macros[1];
    try std.testing.expectEqualStrings("shift_hold", shift.name);
    try std.testing.expectEqual(@as(usize, 3), shift.steps.len);
    try std.testing.expectEqualStrings("KEY_LEFTSHIFT", shift.steps[0].down);
    _ = shift.steps[1].pause_for_release;
    try std.testing.expectEqualStrings("KEY_LEFTSHIFT", shift.steps[2].up);

    const noop = macros[2];
    try std.testing.expectEqualStrings("noop", noop.name);
    try std.testing.expectEqual(@as(usize, 0), noop.steps.len);

    try std.testing.expectEqualStrings("macro:dodge_roll", cfg.remap.?.map.get("M1").?);
    try validate(&cfg);
}

test "mapping: validate: macro:name remap target references unknown macro returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[remap]
        \\M1 = "macro:nonexistent"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.UnknownMacro, validate(&result.value));
}

test "mapping: validate: macro:name in layer remap references unknown macro returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\
        \\[layer.remap]
        \\M1 = "macro:ghost"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.UnknownMacro, validate(&result.value));
}

test "mapping: adaptive_trigger: valid mode parses and validates" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[adaptive_trigger]
        \\mode = "feedback"
        \\
        \\[adaptive_trigger.left]
        \\position = 70
        \\strength = 200
        \\
        \\[adaptive_trigger.right]
        \\position = 40
        \\strength = 180
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    const cfg = result.value;
    try std.testing.expect(cfg.adaptive_trigger != null);
    const at = cfg.adaptive_trigger.?;
    try std.testing.expectEqualStrings("feedback", at.mode);
    try std.testing.expectEqual(@as(?i64, 70), at.left.?.position);
    try std.testing.expectEqual(@as(?i64, 200), at.left.?.strength);
    try std.testing.expectEqual(@as(?i64, 40), at.right.?.position);
    try validate(&cfg);
}

test "mapping: adaptive_trigger: invalid mode returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[adaptive_trigger]
        \\mode = "bogus"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: adaptive_trigger: invalid mode in layer returns error" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fps"
        \\trigger = "LT"
        \\
        \\[layer.adaptive_trigger]
        \\mode = "unknown"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.InvalidConfig, validate(&result.value));
}

test "mapping: adaptive_trigger: per-layer valid mode validates" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "racing"
        \\trigger = "RB"
        \\
        \\[layer.adaptive_trigger]
        \\mode = "weapon"
        \\
        \\[layer.adaptive_trigger.left]
        \\start = 30
        \\end = 120
        \\strength = 200
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try validate(&result.value);
    const at = result.value.layer.?[0].adaptive_trigger.?;
    try std.testing.expectEqualStrings("weapon", at.mode);
    try std.testing.expectEqual(@as(?i64, 30), at.left.?.start);
}

test "deriveAuxFromMapping: empty mapping needs no aux" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(!caps.needsAux());
}

test "deriveAuxFromMapping: gyro mouse needs_rel" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[gyro]
        \\mode = "mouse"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.needs_rel);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: remap KEY_F13 needs_keyboard" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M1 = "KEY_F13"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.needs_keyboard);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: remap mouse_left sets mouse_buttons bit" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M2 = "mouse_left"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.mouse_buttons & 1 != 0);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: layer stick mouse needs_rel" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LM"
        \\
        \\[layer.stick_right]
        \\mode = "mouse"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.needs_rel);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: remap mouse_forward sets bit 32" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M3 = "mouse_forward"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.mouse_buttons & 32 != 0);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: remap mouse_back sets bit 64" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M4 = "mouse_back"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.mouse_buttons & 64 != 0);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: BTN_FORWARD alias sets bit 32" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M3 = "BTN_FORWARD"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.mouse_buttons & 32 != 0);
}

test "deriveAuxFromMapping: pure KEY_ remap yields needs_rel=false and needs_keyboard=true" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\C = "KEY_M"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(!caps.needs_rel);
    try std.testing.expect(caps.needs_keyboard);
    try std.testing.expect(caps.mouse_buttons == 0);
    try std.testing.expect(caps.needsAux());
}

test "deriveAuxFromMapping: BTN_BACK alias sets bit 64" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\M4 = "BTN_BACK"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.mouse_buttons & 64 != 0);
}

test "mapping: trigger_threshold parses from TOML" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "trigger_threshold = 128");
    defer result.deinit();
    try std.testing.expectEqual(@as(?u8, 128), result.value.trigger_threshold);
}

test "mapping: trigger_threshold defaults to null" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try std.testing.expectEqual(@as(?u8, null), result.value.trigger_threshold);
}

test "deriveAuxFromMapping: macro:dodge_roll emitting KEY_B sets needs_keyboard" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[[macro]]
        \\name = "dodge_roll"
        \\steps = [{ tap = "KEY_B" }]
        \\
        \\[remap]
        \\M1 = "macro:dodge_roll"
    );
    defer result.deinit();
    const caps = deriveAuxFromMapping(&result.value);
    try std.testing.expect(caps.needs_keyboard);
    try std.testing.expect(caps.needsAux());
}

test "mapping: fuzz parseString: no panic on arbitrary input" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) !void {
            const result = parseString(std.testing.allocator, input);
            if (result) |r| r.deinit() else |_| {}
        }
    }.run, .{});
}

test "mapping: needsTriggerThresholdWarn: LT in top-level remap without trigger_threshold" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\LT = "mouse_left"
    );
    defer result.deinit();
    try std.testing.expect(needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: RT in top-level remap without trigger_threshold" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\RT = "mouse_right"
    );
    defer result.deinit();
    try std.testing.expect(needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: LT in layer remap without trigger_threshold" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\
        \\[layer.remap]
        \\LT = "mouse_left"
    );
    defer result.deinit();
    try std.testing.expect(needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: RT in layer remap without trigger_threshold" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[[layer]]
        \\name = "fn"
        \\trigger = "Select"
        \\
        \\[layer.remap]
        \\RT = "KEY_F1"
    );
    defer result.deinit();
    try std.testing.expect(needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: no warn when trigger_threshold set" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\trigger_threshold = 128
        \\
        \\[remap]
        \\LT = "mouse_left"
        \\RT = "mouse_right"
    );
    defer result.deinit();
    try std.testing.expect(!needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: no warn when LT/RT not in remap" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator,
        \\[remap]
        \\A = "KEY_F1"
        \\B = "mouse_left"
    );
    defer result.deinit();
    try std.testing.expect(!needsTriggerThresholdWarn(&result.value));
}

test "mapping: needsTriggerThresholdWarn: no warn on empty config" {
    const allocator = std.testing.allocator;
    const result = try parseString(allocator, "");
    defer result.deinit();
    try std.testing.expect(!needsTriggerThresholdWarn(&result.value));
}

// --- lintUnknownFields tests ---

fn findFinding(items: []const LintFinding, table: []const u8, key: []const u8) ?LintFinding {
    for (items) |f| {
        if (std.mem.eql(u8, f.table, table) and std.mem.eql(u8, f.unknown_key, key)) return f;
    }
    return null;
}

test "lintUnknownFields: trigger_threshold inside [[layer]] is flagged (issue #163 class)" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "fps"
        \\trigger = "Select"
        \\trigger_threshold = 128
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expect(findFinding(findings.items, "layer", "trigger_threshold") != null);
}

test "lintUnknownFields: typo at top-level is flagged" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\name = "test"
        \\tigger_threshold = 128
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expect(findFinding(findings.items, "", "tigger_threshold") != null);
    // legitimate key must not be flagged
    try std.testing.expect(findFinding(findings.items, "", "name") == null);
}

test "lintUnknownFields: HashMap context like [remap] does not flag arbitrary keys" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[remap]
        \\RT = "mouse_right"
        \\LT = "mouse_left"
        \\Y = "KEY_F1"
        \\M1 = "macro:dodge_roll"
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "lintUnknownFields: known fields produce no warnings" {
    const allocator = std.testing.allocator;
    var findings = try lintUnknownFields(allocator, test_toml_full);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "lintUnknownFields: nested [layer.gyro] context routes to GyroConfig allowlist" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LM"
        \\
        \\[layer.gyro]
        \\mode = "mouse"
        \\unknown_gyro_field = 42
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expect(findFinding(findings.items, "layer.gyro", "unknown_gyro_field") != null);
    // legit gyro field must not be flagged
    try std.testing.expect(findFinding(findings.items, "layer.gyro", "mode") == null);
}

test "lintUnknownFields: [[macro]] steps array does not mis-flag inline-table keys" {
    const allocator = std.testing.allocator;
    var findings = try lintUnknownFields(allocator, test_toml_macro);
    defer findings.deinit(allocator);
    // `tap`, `down`, `up`, `delay` appear inside `steps = [...]` array — they
    // must not be classified as Macro fields and must not flag.
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "lintUnknownFields: forward-compat field flagged once with table context" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\name = "ok"
        \\
        \\[gyro]
        \\mode = "mouse"
        \\some_future_gyro_knob = 1.0
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), findings.items.len);
    try std.testing.expectEqualStrings("gyro", findings.items[0].table);
    try std.testing.expectEqualStrings("some_future_gyro_knob", findings.items[0].unknown_key);
}

test "lintUnknownFields: comments and blank lines are skipped" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\# top-level comment
        \\name = "ok"
        \\
        \\# another comment
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LM"
        \\# a layer comment with key = 1 inside it should not match
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "lintUnknownFields: unknown table header skipped (forward-compat)" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[some_future_section]
        \\anything = "goes"
        \\here = 42
    ;
    var findings = try lintUnknownFields(allocator, toml_str);
    defer findings.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), findings.items.len);
}

test "validate: layer tap cannot be macro:..." {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "x"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "macro:single_shot"
        \\
        \\[[macro]]
        \\name = "single_shot"
        \\steps = [{ tap = "A" }]
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try std.testing.expectError(error.LayerTapCannotBeMacro, validate(&result.value));
}

test "validate: layer tap to gamepad button works (regression)" {
    const allocator = std.testing.allocator;
    const toml_str =
        \\[[layer]]
        \\name = "aim"
        \\trigger = "LT"
        \\activation = "hold"
        \\tap = "mouse_side"
    ;
    const result = try parseString(allocator, toml_str);
    defer result.deinit();
    try validate(&result.value);
}
