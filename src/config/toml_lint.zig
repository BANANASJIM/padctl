const std = @import("std");

// Shared unknown-field linter for TOML configs.
//
// The underlying TOML library (sam701/zig-toml) silently ignores unknown
// fields by design (forward-compat). For our schemas that is the wrong
// tradeoff — a typo'd key (e.g. `ofset` for `offset`) parses cleanly and is
// silently dropped, leaving the author no diagnostic. This walks the raw TOML
// text and reports any key that does not belong to the schema of its enclosing
// table.
//
// This is a lightweight line-based scan, NOT a second TOML parser. Multi-line
// values (arrays, inline tables spanning lines) are skipped while bracket depth
// is non-zero, so keys nested inside arrays of inline tables are not
// mis-classified as table keys.

pub const LintFinding = struct {
    line: usize, // 1-based line number
    table: []const u8, // table path or "" for top-level; borrowed from input
    unknown_key: []const u8, // borrowed from input
};

// Maps a table header to its allowed key set. Return null to skip linting the
// table (free-form HashMap sections and unrecognised forward-compat headers).
pub const Classifier = *const fn (header: []const u8) ?[]const []const u8;

pub fn structFieldNames(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;
    comptime var names: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |f, i| names[i] = f.name;
    const final = names;
    return &final;
}

fn keyIsKnown(allowlist: []const []const u8, key: []const u8) bool {
    for (allowlist) |name| {
        if (std.mem.eql(u8, name, key)) return true;
    }
    return false;
}

fn trimWhitespace(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn isValidBareKey(key: []const u8) bool {
    if (key.len == 0) return false;
    for (key) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

// First occurrence of `c` in `s` outside double-quoted spans.
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

// Net bracket-depth delta for a line, respecting quoted spans and comments.
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
        if (ch == '#') break;
        switch (ch) {
            '[', '{' => depth += 1,
            ']', '}' => depth -= 1,
            else => {},
        }
    }
    return depth;
}

/// Walk raw TOML text and collect findings for keys that do not match the
/// schema of the enclosing table, as resolved by `classify`. Caller owns the
/// returned ArrayList.
pub fn lint(
    allocator: std.mem.Allocator,
    raw_toml: []const u8,
    classify: Classifier,
) !std.ArrayList(LintFinding) {
    var findings: std.ArrayList(LintFinding) = .empty;
    errdefer findings.deinit(allocator);

    var current_header: []const u8 = "";
    var depth: i32 = 0;
    var line_no: usize = 0;

    var it = std.mem.splitScalar(u8, raw_toml, '\n');
    while (it.next()) |raw_line| {
        line_no += 1;

        const trimmed_full = trimWhitespace(raw_line);
        if (trimmed_full.len == 0) continue;
        if (trimmed_full[0] == '#') continue;

        if (depth > 0) {
            depth += bracketDelta(raw_line);
            if (depth < 0) depth = 0;
            continue;
        }

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

        const eq_idx = indexOfUnquoted(trimmed_full, '=') orelse continue;
        const key_raw = trimWhitespace(trimmed_full[0..eq_idx]);
        const value_raw = if (eq_idx + 1 < trimmed_full.len) trimmed_full[eq_idx + 1 ..] else "";

        if (!isValidBareKey(key_raw)) {
            depth += bracketDelta(value_raw);
            if (depth < 0) depth = 0;
            continue;
        }

        if (classify(current_header)) |allow| {
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

pub fn warnFindings(findings: []const LintFinding) void {
    for (findings) |f| {
        if (f.table.len == 0) {
            std.log.warn("config: unknown key '{s}' at top-level (line {d}) — typo or misplaced field?", .{ f.unknown_key, f.line });
        } else {
            std.log.warn("config: unknown key '{s}' inside [{s}] (line {d}) — typo or misplaced field?", .{ f.unknown_key, f.table, f.line });
        }
    }
}
