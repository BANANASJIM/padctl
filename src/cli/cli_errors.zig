const std = @import("std");

/// Plain stderr error reporting for interactive CLI argument failures.
///
/// Daemon log lines go through padctl_log.logFn, which prepends a wall-clock
/// timestamp and a MONO counter and renders raw Zig error names. That format is
/// right for the journal but wrong for a person typing a command: a mistyped
/// subcommand should read like a shell tool, not a daemon trace. These helpers
/// write a short two-line message straight to the writer and never emit help.
pub fn unknownArgument(writer: anytype, arg: []const u8) void {
    writer.print("padctl: unknown argument '{s}'\n", .{arg}) catch {};
    tryHelpHint(writer);
}

pub fn unknownSubcommand(writer: anytype, group: []const u8, sub: []const u8) void {
    writer.print("padctl: unknown {s} subcommand '{s}'\n", .{ group, sub }) catch {};
    tryHelpHint(writer);
}

pub fn message(writer: anytype, text: []const u8) void {
    writer.print("padctl: {s}\n", .{text}) catch {};
    tryHelpHint(writer);
}

fn tryHelpHint(writer: anytype) void {
    writer.writeAll("Try 'padctl --help' for usage.\n") catch {};
}

/// Short guide shown when `padctl` is run with no subcommand on an interactive
/// terminal. The systemd unit runs with stderr attached to the journal (not a
/// TTY), so the daemon path stays untouched; only a human at a shell sees this.
pub fn guide(writer: anytype, daemon_running: bool) void {
    if (daemon_running) {
        writer.writeAll("padctl: a daemon is already running — try 'padctl status'.\n\n") catch {};
    }
    writer.writeAll(
        \\padctl — HID gamepad daemon
        \\
        \\Common commands:
        \\  padctl status            Show daemon status
        \\  padctl devices           List connected devices
        \\  padctl scan              List HID devices and config matches
        \\  padctl switch <name>     Switch the active mapping
        \\  padctl doctor            Print a diagnostic report
        \\  padctl config init       Create a mapping interactively
        \\
        \\Run 'padctl --help' for the full command list.
        \\The background daemon is normally started by systemd, not by hand.
        \\
    ) catch {};
}

const testing = std.testing;

test "cli_errors: unknownArgument prints plain two-line message, no help dump" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    unknownArgument(buf.writer(testing.allocator), "stauts");

    try testing.expectEqualStrings(
        "padctl: unknown argument 'stauts'\nTry 'padctl --help' for usage.\n",
        buf.items,
    );
    // Plain output must not carry the daemon log formatter prefix.
    try testing.expect(std.mem.indexOf(u8, buf.items, "MONO") == null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "error.") == null);
    // A two-line message means exactly two newlines, never the full usage block.
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, buf.items, "\n"));
}

test "cli_errors: unknownSubcommand names the group" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    unknownSubcommand(buf.writer(testing.allocator), "config", "lst");
    try testing.expect(std.mem.indexOf(u8, buf.items, "config subcommand 'lst'") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "Try 'padctl --help'") != null);
}

test "cli_errors: guide lists discoverable commands without daemon notice" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    guide(buf.writer(testing.allocator), false);
    try testing.expect(std.mem.indexOf(u8, buf.items, "padctl status") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "padctl switch") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "padctl --help") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "already running") == null);
}

test "cli_errors: guide prepends a running-daemon notice" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    guide(buf.writer(testing.allocator), true);
    try testing.expect(std.mem.indexOf(u8, buf.items, "already running") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "padctl status") != null);
}
