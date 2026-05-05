// cli_smoke_test: assert the produced binary (zig-out/bin/padctl) behaves correctly.
// Skips gracefully if the binary is absent (e.g. isolated test run without prior build).

const std = @import("std");
const testing = std.testing;
const build_options = @import("build_options");

const BIN = "zig-out/bin/padctl";
const DUALSENSE = "devices/sony/dualsense.toml";

fn run(allocator: std.mem.Allocator, argv: []const []const u8) !std.process.Child.RunResult {
    return std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    });
}

fn binExists() bool {
    std.fs.cwd().access(BIN, .{}) catch return false;
    return true;
}

test "smoke: padctl --version exits 0 and reports correct version" {
    if (!binExists()) return error.SkipZigTest;
    const allocator = testing.allocator;
    const result = try run(allocator, &.{ BIN, "--version" });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try testing.expectEqual(@as(u8, 0), result.term.Exited);
    try testing.expect(std.mem.startsWith(u8, result.stdout, "padctl "));
    try testing.expect(std.mem.indexOf(u8, result.stdout, build_options.version) != null);
}

test "smoke: padctl --help exits 0 and lists all subcommands" {
    if (!binExists()) return error.SkipZigTest;
    const allocator = testing.allocator;
    const result = try run(allocator, &.{ BIN, "--help" });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try testing.expectEqual(@as(u8, 0), result.term.Exited);
    const out = result.stdout;
    for (&[_][]const u8{
        "install", "uninstall", "scan",   "list-mappings",
        "reload",  "switch",    "status", "devices",
        "dump",
    }) |cmd| {
        if (std.mem.indexOf(u8, out, cmd) == null) {
            std.debug.print("--help output missing subcommand: {s}\n", .{cmd});
            return error.TestFailed;
        }
    }
}

test "smoke: padctl --validate dualsense exits 0 with OK" {
    if (!binExists()) return error.SkipZigTest;
    std.fs.cwd().access(DUALSENSE, .{}) catch return error.SkipZigTest;
    const allocator = testing.allocator;
    const result = try run(allocator, &.{ BIN, "--validate", DUALSENSE });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try testing.expectEqual(@as(u8, 0), result.term.Exited);
    const combined = try std.fmt.allocPrint(allocator, "{s}{s}", .{ result.stdout, result.stderr });
    defer allocator.free(combined);
    try testing.expect(std.mem.indexOf(u8, combined, ": OK") != null);
}
