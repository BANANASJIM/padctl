const std = @import("std");

/// Daemon control-socket replies are terse tokens (e.g. "ERR mapping-not-found")
/// meant for machine parsing. The two most-used runtime commands — `switch` and
/// `status` — printed those tokens verbatim, which gives a user typing at a shell
/// no idea what went wrong or what to do next. These helpers turn a known ERR
/// token into a sentence plus a concrete next step, while unknown tokens fall
/// back to the raw line so a newer daemon never produces a crash or empty output.
/// Strip the leading "ERR " prefix and trailing newline from a daemon reply,
/// leaving just the bare code token (e.g. "mapping-not-found"). Returns null
/// when the reply is not an ERR line.
pub fn errorCode(reply: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimRight(u8, reply, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, "ERR")) return null;
    const rest = trimmed["ERR".len..];
    return std.mem.trimLeft(u8, rest, " ");
}

/// Human-readable explanation + next step for a known daemon ERR code, or null
/// when the code is unmapped. The mapping name is interpolated where it makes
/// the hint concrete (only `switch` has it in scope; pass "" otherwise).
pub fn hintFor(writer: anytype, code: []const u8, mapping_name: []const u8) bool {
    if (std.mem.eql(u8, code, "mapping-not-found")) {
        writer.print("error: no mapping named '{s}' found.\n", .{mapping_name}) catch {};
        writer.writeAll("hint: run `padctl list-mappings` to see available profiles, or `padctl config init` to create one.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "no-devices")) {
        writer.writeAll("error: no managed devices to switch.\n") catch {};
        writer.writeAll("hint: connect a supported controller, then run `padctl status` to confirm it is managed.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "device-not-found")) {
        writer.writeAll("error: the requested device is not managed by the daemon.\n") catch {};
        writer.writeAll("hint: run `padctl status` to list managed devices and their identifiers.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "mapping-not-allowed")) {
        writer.writeAll("error: that mapping path is outside the trusted config directories.\n") catch {};
        writer.writeAll("hint: place the file under ~/.config/padctl/mappings/ (or /etc/padctl/mappings/) and switch by name.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "mapping-parse-failed")) {
        writer.print("error: the mapping '{s}' could not be parsed.\n", .{mapping_name}) catch {};
        writer.writeAll("hint: check the TOML syntax with `padctl validate <file>`.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "mapping-lookup-failed")) {
        writer.writeAll("error: the daemon could not search the mapping config directories.\n") catch {};
        writer.writeAll("hint: run `padctl doctor` to check config-directory permissions.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "switch-failed") or std.mem.eql(u8, code, "restart-failed")) {
        writer.writeAll("error: the daemon failed to apply the mapping and rolled back.\n") catch {};
        writer.writeAll("hint: check the daemon log (`journalctl --user -u padctl.service`) for details.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "unknown-command")) {
        writer.writeAll("error: the daemon did not recognize the command.\n") catch {};
        writer.writeAll("hint: the daemon may be an older version; reinstall or restart it, then retry.\n") catch {};
        return true;
    }
    if (std.mem.eql(u8, code, "oom")) {
        writer.writeAll("error: the daemon ran out of memory handling the request.\n") catch {};
        writer.writeAll("hint: check daemon memory pressure with `padctl doctor` and the system log.\n") catch {};
        return true;
    }
    return false;
}

/// Print the daemon ERR reply as a friendly sentence + hint when the code is
/// known, otherwise echo the raw reply verbatim (always newline-terminated).
/// `mapping_name` is the user-supplied name for commands that carry one.
pub fn report(writer: anytype, reply: []const u8, mapping_name: []const u8) void {
    const code = errorCode(reply) orelse {
        writeRaw(writer, reply);
        return;
    };
    if (!hintFor(writer, code, mapping_name)) writeRaw(writer, reply);
}

fn writeRaw(writer: anytype, reply: []const u8) void {
    writer.writeAll(reply) catch {};
    if (reply.len == 0 or reply[reply.len - 1] != '\n') writer.writeAll("\n") catch {};
}

// --- tests ---

const testing = std.testing;

fn renderReport(reply: []const u8, mapping_name: []const u8) []const u8 {
    const S = struct {
        var buf: [512]u8 = undefined;
    };
    var fbs = std.io.fixedBufferStream(&S.buf);
    report(fbs.writer(), reply, mapping_name);
    return fbs.getWritten();
}

test "error_hint: errorCode strips prefix and newline" {
    try testing.expectEqualStrings("mapping-not-found", errorCode("ERR mapping-not-found\n").?);
    try testing.expectEqualStrings("switch-failed", errorCode("ERR switch-failed").?);
    try testing.expect(errorCode("OK fps\n") == null);
    try testing.expect(errorCode("STATUS device=x\n") == null);
}

test "error_hint: mapping-not-found interpolates the requested name" {
    const out = renderReport("ERR mapping-not-found\n", "fps");
    try testing.expect(std.mem.indexOf(u8, out, "no mapping named 'fps' found") != null);
    try testing.expect(std.mem.indexOf(u8, out, "padctl list-mappings") != null);
    try testing.expect(std.mem.indexOf(u8, out, "padctl config init") != null);
    // The terse wire token must not leak into the friendly output.
    try testing.expect(std.mem.indexOf(u8, out, "ERR mapping-not-found") == null);
}

test "error_hint: no-devices and device-not-found get actionable hints" {
    const nd = renderReport("ERR no-devices\n", "");
    try testing.expect(std.mem.indexOf(u8, nd, "no managed devices") != null);
    try testing.expect(std.mem.indexOf(u8, nd, "padctl status") != null);

    const dnf = renderReport("ERR device-not-found\n", "");
    try testing.expect(std.mem.indexOf(u8, dnf, "not managed by the daemon") != null);
    try testing.expect(std.mem.indexOf(u8, dnf, "padctl status") != null);
}

test "error_hint: switch-failed and restart-failed point at the journal" {
    const sf = renderReport("ERR switch-failed\n", "fps");
    try testing.expect(std.mem.indexOf(u8, sf, "rolled back") != null);
    try testing.expect(std.mem.indexOf(u8, sf, "journalctl") != null);

    const rf = renderReport("ERR restart-failed\n", "");
    try testing.expect(std.mem.indexOf(u8, rf, "journalctl") != null);
}

test "error_hint: unknown code falls back to the raw token" {
    // A future daemon code we have no hint for must echo verbatim, not crash.
    const out = renderReport("ERR brand-new-code\n", "fps");
    try testing.expectEqualStrings("ERR brand-new-code\n", out);
}

test "error_hint: raw reply without trailing newline is terminated" {
    const out = renderReport("ERR brand-new-code", "");
    try testing.expectEqualStrings("ERR brand-new-code\n", out);
}

test "error_hint: known code does not degrade to raw token" {
    const out = renderReport("ERR mapping-not-allowed\n", "");
    try testing.expect(std.mem.indexOf(u8, out, "ERR mapping-not-allowed") == null);
    try testing.expect(std.mem.indexOf(u8, out, "trusted config directories") != null);
}
