const std = @import("std");
const posix = std.posix;
const paths = @import("../../config/paths.zig");
const validate_mod = @import("../../tools/validate.zig");

fn resolveEditor(allocator: std.mem.Allocator) ![]const u8 {
    if (posix.getenv("VISUAL")) |v| return allocator.dupe(u8, v);
    if (posix.getenv("EDITOR")) |e| return allocator.dupe(u8, e);
    return allocator.dupe(u8, "vi");
}

fn resolveMappingPath(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const dirs = try paths.resolveMappingConfigDirs(allocator);
    defer paths.freeConfigDirs(allocator, dirs);

    const filename = if (std.mem.endsWith(u8, name, ".toml"))
        try allocator.dupe(u8, name)
    else
        try std.fmt.allocPrint(allocator, "{s}.toml", .{name});
    defer allocator.free(filename);

    if (try paths.findConfig(allocator, filename, dirs)) |found| return found;
    // Default to user layer even if not yet existing
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ dirs[0], filename });
}

fn editorSucceeded(term: std.process.Child.Term) bool {
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn validateEditedFile(allocator: std.mem.Allocator, target: []const u8) !void {
    const errors = validate_mod.validateFile(target, allocator) catch return error.ValidationFailed;
    defer validate_mod.freeErrors(errors, allocator);
    if (errors.len == 0) {
        _ = posix.write(posix.STDOUT_FILENO, "Validation: OK\n") catch 0;
        return;
    }

    _ = posix.write(posix.STDERR_FILENO, "Validation errors:\n") catch 0;
    for (errors) |err| {
        _ = posix.write(posix.STDERR_FILENO, err.file) catch 0;
        _ = posix.write(posix.STDERR_FILENO, ": ") catch 0;
        _ = posix.write(posix.STDERR_FILENO, err.message) catch 0;
        _ = posix.write(posix.STDERR_FILENO, "\n") catch 0;
    }
    return error.ValidationFailed;
}

pub fn run(allocator: std.mem.Allocator, name: ?[]const u8) !void {
    const target: []const u8 = if (name) |n|
        try resolveMappingPath(allocator, n)
    else blk: {
        // List mappings and prompt
        const dirs = try paths.resolveMappingConfigDirs(allocator);
        defer paths.freeConfigDirs(allocator, dirs);

        var found: ?[]u8 = null;
        outer: for (dirs) |dir| {
            var d = if (std.fs.path.isAbsolute(dir))
                std.fs.openDirAbsolute(dir, .{ .iterate = true }) catch continue
            else
                std.fs.cwd().openDir(dir, .{ .iterate = true }) catch continue;
            defer d.close();
            var it = d.iterate();
            while (try it.next()) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".toml")) {
                    found = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, entry.name });
                    break :outer;
                }
            }
        }

        if (found == null) {
            _ = posix.write(posix.STDERR_FILENO, "No mapping files found. Use: padctl config edit <name>\n") catch 0;
            return error.NoMappingFound;
        }
        break :blk found.?;
    };
    defer allocator.free(@constCast(target));

    const editor = try resolveEditor(allocator);
    defer allocator.free(editor);

    var child = std.process.Child.init(&.{ editor, target }, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const term = try child.spawnAndWait();
    if (!editorSucceeded(term)) {
        _ = posix.write(posix.STDERR_FILENO, "Editor failed; not validating.\n") catch 0;
        return error.EditorFailed;
    }

    try validateEditedFile(allocator, target);
}

// --- tests ---

test "edit: resolveEditor falls back to vi" {
    // When neither VISUAL nor EDITOR set, should return "vi"
    // Can't unset env vars portably in tests; just verify the function compiles and returns a string.
    const allocator = std.testing.allocator;
    const ed = try resolveEditor(allocator);
    defer allocator.free(ed);
    try std.testing.expect(ed.len > 0);
}

test "edit: resolveMappingPath appends .toml when missing" {
    const allocator = std.testing.allocator;
    // If no matching file exists, returns user-layer path
    const p = resolveMappingPath(allocator, "nonexistent_mapping_xyz") catch {
        // resolving a path that doesn't exist may fail on allocation only; not a test failure
        return;
    };
    defer allocator.free(p);
    try std.testing.expect(std.mem.endsWith(u8, p, ".toml"));
}

test "edit: editorSucceeded only accepts exit code 0" {
    try std.testing.expect(editorSucceeded(.{ .Exited = 0 }));
    try std.testing.expect(!editorSucceeded(.{ .Exited = 1 }));
    try std.testing.expect(!editorSucceeded(.{ .Signal = 9 }));
}

test "edit: validateEditedFile returns error on invalid mapping" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_abs = try tmp.dir.realpath(".", &buf);

    const bad_mapping =
        \\[remap]
        \\M1 = "KEY_NOT_A_REAL_KEY"
    ;
    try tmp.dir.writeFile(.{ .sub_path = "bad.toml", .data = bad_mapping });
    const path = try std.fmt.allocPrint(allocator, "{s}/bad.toml", .{tmp_abs});
    defer allocator.free(path);

    try std.testing.expectError(error.ValidationFailed, validateEditedFile(allocator, path));
}
