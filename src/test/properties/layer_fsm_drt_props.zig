// layer_fsm_drt_props.zig — Lean oracle DRT for the LAYER_FSM and
// BUTTON_DECODE theorem classes.
//
// The Lean 4 formal spec (formal/lean/) emits proven-correct test vectors
// for the tap-hold layer state machine and the button-group decode path.
// Before this file those two CSV sections had ZERO Zig consumers (audit
// research/test-code-audit-2026-05-15.md F-gap): proven theorems with no
// runtime verification against production.
//
// Lean oracle output is THE truth (theorem-proven). The "expected" values
// here come exclusively from the embedded Lean CSV — production state is
// driven independently and compared to that independent authority. No
// shared helper computes both sides.

const std = @import("std");
const testing = std.testing;
const layer = @import("../../core/layer.zig");
const interpreter = @import("../../core/interpreter.zig");
const device = @import("../../config/device.zig");

const csv_data = @embedFile("../../../formal/lean/test_vectors.csv");

// Upper bound for entries in one BUTTON_DECODE row; mirrors the private
// interpreter.MAX_BUTTONS (32) — the Lean rows use at most 2 entries.
const MAX_ENTRIES = 32;

// --- CSV helpers (mirrors lean_drt_props.zig) ---

const Lines = struct {
    data: []const u8,
    pos: usize = 0,

    fn next(self: *Lines) ?[]const u8 {
        if (self.pos >= self.data.len) return null;
        const start = self.pos;
        while (self.pos < self.data.len and self.data[self.pos] != '\n') : (self.pos += 1) {}
        const line = self.data[start..self.pos];
        if (self.pos < self.data.len) self.pos += 1;
        return line;
    }
};

fn isDataLine(line: []const u8) bool {
    return line.len > 0 and line[0] != '#';
}

fn seekSection(comptime header: []const u8) Lines {
    var lines = Lines{ .data = csv_data };
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, header)) return lines;
    }
    return lines;
}

fn parseUint(s: []const u8) u64 {
    return std.fmt.parseInt(u64, s, 10) catch 0;
}

// LAYER_FSM rows are `action,description,before,after` where `before` and
// `after` are Lean `repr (Option TapHoldState)` blobs that are EITHER the
// literal `none` OR `some { ... }` with internal commas (but no nested
// braces — `repr (Option TapHoldState)` has exactly one brace pair). A
// fixed-comma split corrupts `before`/`after`, so locate the
// before/after boundary structurally: skip the two comma-free leading
// fields, then find the comma that terminates the first repr blob (right
// after `none`, or right after the matching `}`).
fn splitLayerFsmRow(line: []const u8) [4][]const u8 {
    var out: [4][]const u8 = .{""} ** 4;
    const c1 = std.mem.indexOfScalar(u8, line, ',') orelse return out;
    out[0] = line[0..c1];
    const rest1 = line[c1 + 1 ..];
    const c2 = std.mem.indexOfScalar(u8, rest1, ',') orelse return out;
    out[1] = rest1[0..c2];
    const blobs = rest1[c2 + 1 ..];

    const trimmed = std.mem.trimLeft(u8, blobs, " ");
    var boundary: usize = undefined;
    if (std.mem.startsWith(u8, trimmed, "none")) {
        boundary = std.mem.indexOfScalar(u8, blobs, ',') orelse blobs.len;
    } else {
        const close = std.mem.indexOfScalar(u8, blobs, '}') orelse blobs.len;
        boundary = if (std.mem.indexOfScalarPos(u8, blobs, close, ',')) |b| b else blobs.len;
    }
    out[2] = blobs[0..boundary];
    out[3] = if (boundary < blobs.len) blobs[boundary + 1 ..] else "";
    return out;
}

// --- BUTTON_DECODE ---
//
// True Lean-vs-PRODUCTION differential. The Lean oracle proves
// `decodeButtonGroup`; this drives the REAL production decode through the
// public `Interpreter.processReport` entrypoint, which internally runs the
// private `interpreter.extractAndFillCompiled` button_group path
// (src/core/interpreter.zig). No inlined reference reimplementation — the
// "actual" value comes from production, the "expected" value comes solely
// from the embedded Lean CSV.
//
// CSV schema (declared header): `srcOff,srcSize,entries,hex_bytes,expected`
//   entries  := `srcBit:dstBit` pairs joined by `|`
//   hex_bytes:= declared by the Lean header but CURRENTLY UNPOPULATED — the
//               generator (formal/lean/test/OracleMain.lean
//               emitButtonDecodeVectors) emits only 4 fields per data row.
//   expected := decoded u64 bitset (Lean decodeButtonGroup result)
// The arity-defensive parser below accepts BOTH the current 4-field form
// (hex_bytes omitted) and a future 5-field form (hex_bytes populated), and
// FAILS LOUDLY with the row index on any other arity, so a future populated
// column can never silently shift `expected` to the wrong column (#237-trap).
//
// Production mapping note: production maps a source bit to a `ButtonId`
// enum, and the decoded bitset sets bit `@intFromEnum(ButtonId)`. The Lean
// `dstBit` is a raw destination bit index. We therefore choose, per entry,
// the ButtonId whose enum ordinal == dstBit, so the production output
// bitset is directly comparable to the Lean `expected` bitset.

const Entry = struct { src_bit: u6, dst_bit: u6 };

// Parse the `entries` cell (`srcBit:dstBit` pairs joined by `|`).
fn parseEntries(spec: []const u8, buf: *[MAX_ENTRIES]Entry) []const Entry {
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, spec, '|');
    while (it.next()) |pair| {
        const sep = std.mem.indexOfScalar(u8, pair, ':') orelse continue;
        buf[n] = .{
            .src_bit = @intCast(parseUint(pair[0..sep])),
            .dst_bit = @intCast(parseUint(pair[sep + 1 ..])),
        };
        n += 1;
    }
    return buf[0..n];
}

// Split a CSV row on EVERY comma. Returns the field count so the caller can
// assert the row arity explicitly. The Lean `entries` cell uses `|` and `:`
// as separators (never `,`), so a flat comma split is unambiguous here.
fn splitAll(line: []const u8, buf: *[8][]const u8) usize {
    var n: usize = 0;
    var start: usize = 0;
    for (line, 0..) |c, i| {
        if (c == ',') {
            if (n >= buf.len) return n;
            buf[n] = line[start..i];
            n += 1;
            start = i + 1;
        }
    }
    if (n < buf.len) {
        buf[n] = line[start..];
        n += 1;
    }
    return n;
}

// Resolve a destination bit index to the ButtonId whose enum ordinal equals
// it, so the production decoded bitset (which sets bit @intFromEnum) is
// directly comparable to the Lean `expected` bitset.
fn buttonNameForBit(dst_bit: u6) ?[]const u8 {
    inline for (@typeInfo(interpreter.ButtonId).@"enum".fields) |f| {
        if (f.value == dst_bit) return f.name;
    }
    return null;
}

// Drive the REAL production button_group decode for one CSV row: synthesize
// a device TOML whose `[report.button_group].map` encodes the row's
// src→dst entries, parse it, and run `Interpreter.processReport` (which
// calls the private extractAndFillCompiled button_group path). Returns the
// production `delta.buttons` bitset.
fn productionDecodeRow(
    allocator: std.mem.Allocator,
    raw_byte: u8,
    entries: []const Entry,
) !u64 {
    var toml: std.ArrayList(u8) = .{};
    defer toml.deinit(allocator);
    const w = toml.writer(allocator);
    try w.writeAll(
        \\[device]
        \\name = "T"
        \\vid = 1
        \\pid = 2
        \\[[device.interface]]
        \\id = 0
        \\class = "hid"
        \\[[report]]
        \\name = "r"
        \\interface = 0
        \\size = 2
        \\[report.match]
        \\offset = 0
        \\expect = [0x01]
        \\[report.button_group]
        \\source = { offset = 1, size = 1 }
        \\map = {
    );
    for (entries, 0..) |e, i| {
        const name = buttonNameForBit(e.dst_bit) orelse return error.LeanOracleNoButtonForBit;
        if (i != 0) try w.writeAll(", ");
        try w.print("{s} = {d}", .{ name, e.src_bit });
    }
    try w.writeAll(" }\n");

    const parsed = try device.parseString(allocator, toml.items);
    defer parsed.deinit();
    const interp = interpreter.Interpreter.init(&parsed.value);
    // raw[0]=0x01 satisfies report.match; raw[1] is the button_group source
    // byte the Lean row hardcodes.
    const raw = [_]u8{ 0x01, raw_byte };
    const delta = (try interp.processReport(0, &raw)) orelse return error.LeanOracleNoMatch;
    return delta.buttons orelse 0;
}

test "layer_fsm_drt: BUTTON_DECODE vectors vs production decode" {
    var lines = seekSection("# BUTTON_DECODE");
    _ = lines.next(); // skip column header

    // Source bytes hardcoded by the Lean oracle generator, matched
    // positionally (formal/lean/test/OracleMain.lean emitButtonDecodeVectors:
    // 0x05, 0xFF, 0x00). srcOff/srcSize from the CSV are asserted below to
    // stay 0/1 so this single-byte mapping remains valid.
    const raw_bytes = [_]u8{ 0x05, 0xFF, 0x00 };

    var row: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;

        // D1 arity-defensive parse: split on EVERY comma and select fields
        // by position from a verified arity. The header declares 5 columns
        // (srcOff,srcSize,entries,hex_bytes,expected) but the generator
        // currently emits only 4 (hex_bytes omitted). Accept exactly the
        // 4-field form OR a future 5-field form, fail LOUDLY otherwise so a
        // populated hex_bytes column can never silently become `expected`.
        var fbuf: [8][]const u8 = undefined;
        const nf = splitAll(line, &fbuf);
        const has_hex = switch (nf) {
            4 => false, // srcOff,srcSize,entries,expected
            5 => true, // srcOff,srcSize,entries,hex_bytes,expected
            else => {
                std.debug.print(
                    "BUTTON_DECODE row {d}: unexpected field count {d} " ++
                        "(want 4 or 5): {s}\n",
                    .{ row, nf, line },
                );
                return error.LeanOracleBadArity;
            },
        };
        const src_off: usize = @intCast(parseUint(fbuf[0]));
        const src_size: usize = @intCast(parseUint(fbuf[1]));
        const entries_cell = fbuf[2];
        // `expected` is ALWAYS the LAST field; `hex_bytes`, when present, is
        // field index 3. Selecting by arity (not a fixed split count)
        // eliminates the wrong-column compare.
        const expected = parseUint(fbuf[nf - 1]);
        if (has_hex) {
            // Cross-check: when the generator does populate hex_bytes, its
            // low byte must equal the raw byte we hardcode for this row, or
            // the differential is silently testing the wrong input.
            const hex = parseUint(fbuf[3]);
            if (row < raw_bytes.len and @as(u8, @truncate(hex)) != raw_bytes[row]) {
                std.debug.print(
                    "BUTTON_DECODE row {d}: CSV hex_bytes low={x} != " ++
                        "hardcoded raw {x}\n",
                    .{ row, @as(u8, @truncate(hex)), raw_bytes[row] },
                );
                return error.LeanOracleRawDrift;
            }
        }

        if (row >= raw_bytes.len) {
            std.debug.print(
                "BUTTON_DECODE row {d}: no hardcoded raw byte — CSV grew, " ++
                    "update raw_bytes[]\n",
                .{row},
            );
            return error.LeanOracleRawMissing;
        }
        // This consumer's single-byte source assumption; assert rather than
        // silently mis-decode if a future row changes srcOff/srcSize.
        if (src_off != 0 or src_size != 1) {
            std.debug.print(
                "BUTTON_DECODE row {d}: srcOff={d} srcSize={d} — consumer " ++
                    "assumes 0/1, extend productionDecodeRow\n",
                .{ row, src_off, src_size },
            );
            return error.LeanOracleUnsupportedSource;
        }

        var ebuf: [MAX_ENTRIES]Entry = undefined;
        const entries = parseEntries(entries_cell, &ebuf);
        const actual = try productionDecodeRow(
            testing.allocator,
            raw_bytes[row],
            entries,
        );
        if (actual != expected) {
            std.debug.print(
                "BUTTON_DECODE row {d} MISMATCH: lean-expected={d} " ++
                    "production-actual={d} (entries={s})\n",
                .{ row, expected, actual, entries_cell },
            );
            return error.LeanOracleMismatch;
        }
        row += 1;
    }
    try testing.expect(row > 0);
}

// --- LAYER_FSM ---
//
// CSV schema: `action,description,tapHold_before,tapHold_after`
//   action := press | timer | release
//   tapHold_before / tapHold_after := Lean `repr (Option TapHoldState)`:
//     `none`
//     `some { layerIdx := N, phase := TapHoldPhase.pending|active, layerActivated := true|false }`
//
// We parse the Lean repr into a small expected projection (present, phase,
// activated), seed production `LayerState` to the `before` projection,
// apply `action` to the production FSM, then assert the production
// `tap_hold` projection equals the `after` projection from the CSV.
// The expected values originate solely from the Lean CSV repr; production
// is driven independently through layer.zig's public FSM API.

const FsmProj = struct {
    present: bool,
    phase: layer.TapHoldPhase = .pending,
    activated: bool = false,
};

fn parseRepr(s: []const u8) FsmProj {
    const t = std.mem.trim(u8, s, " \r");
    if (std.mem.startsWith(u8, t, "none")) return .{ .present = false };
    var p = FsmProj{ .present = true };
    if (std.mem.indexOf(u8, t, "TapHoldPhase.active") != null) {
        p.phase = .active;
    } else {
        p.phase = .pending;
    }
    // `layerActivated := true` (avoid matching the `false` substring).
    if (std.mem.indexOf(u8, t, "layerActivated := true") != null) {
        p.activated = true;
    }
    return p;
}

fn projOf(ls: *const layer.LayerState) FsmProj {
    if (ls.tap_hold) |th| {
        return .{ .present = true, .phase = th.phase, .activated = th.layer_activated };
    }
    return .{ .present = false };
}

fn seedState(ls: *layer.LayerState, p: FsmProj) void {
    if (!p.present) {
        ls.tap_hold = null;
        return;
    }
    ls.tap_hold = .{
        .layer_name = "aim",
        .phase = p.phase,
        .layer_activated = p.activated,
        .press_ns = 0,
        .hold_timeout_ns = 200 * 1_000_000,
    };
}

fn applyAction(ls: *layer.LayerState, action: []const u8) void {
    if (std.mem.eql(u8, action, "press")) {
        _ = ls.onTriggerPress("aim", 200, 0);
    } else if (std.mem.eql(u8, action, "timer")) {
        _ = ls.onTimerExpired();
    } else if (std.mem.eql(u8, action, "release")) {
        // COUPLING (D3): seedState sets press_ns=0, hold_timeout_ns=200ms.
        // now_ns=1s ≫ press_ns + hold_timeout_ns, so elapsed ≫ timeout and
        // onTriggerRelease takes the active→plain-deactivate branch (and the
        // pending→tap branch when phase is pending). This is correct ONLY
        // for release rows whose Lean `before` is past-timeout / pending. A
        // future "release within timeout from pending/active" row would need
        // now_ns derived from the seeded timeout (e.g. < hold_timeout_ns) —
        // adding such a row without revisiting this constant would silently
        // mask a divergence.
        _ = ls.onTriggerRelease(null, 1_000_000_000);
    }
}

fn projEql(a: FsmProj, b: FsmProj) bool {
    if (a.present != b.present) return false;
    if (!a.present) return true;
    return a.phase == b.phase and a.activated == b.activated;
}

test "layer_fsm_drt: LAYER_FSM transitions vs production LayerState" {
    var lines = seekSection("# LAYER_FSM");
    _ = lines.next(); // skip column header

    var ls = layer.LayerState.init(testing.allocator);
    defer ls.deinit();

    var row: usize = 0;
    while (lines.next()) |line| {
        if (!isDataLine(line)) break;
        const f = splitLayerFsmRow(line); // action, description, before, after
        const action = f[0];
        const before = parseRepr(f[2]);
        const after = parseRepr(f[3]);

        seedState(&ls, before);
        applyAction(&ls, action);
        const actual = projOf(&ls);

        if (!projEql(actual, after)) {
            std.debug.print(
                "LAYER_FSM row {d} ({s}, {s}) MISMATCH:\n" ++
                    "  lean-expected: present={} phase={} activated={}\n" ++
                    "  production:    present={} phase={} activated={}\n",
                .{
                    row,            action,       f[1],
                    after.present,  after.phase,  after.activated,
                    actual.present, actual.phase, actual.activated,
                },
            );
            return error.LeanOracleMismatch;
        }
        row += 1;
    }
    try testing.expect(row > 0);
}
