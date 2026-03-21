// Phase 6 E2E tests.
// MED-1: T5 contributing guide existence (skip until T5 delivers the file).
// MED-3: config edit/test subcommand stubs.

const std = @import("std");
const testing = std.testing;

// MED-1: docs/contributing/device-toml-from-inputplumber.md must exist after T5.
// Skipped until T5 is complete.
test "T5: device-toml-from-inputplumber guide exists" {
    if (true) return error.SkipZigTest;
    _ = try std.fs.cwd().statFile("docs/contributing/device-toml-from-inputplumber.md");
}

// MED-3: `padctl config edit` and `padctl config test` stub — subcommand parse round-trip.
// Full implementation lands in T9; these verify the CLI wiring compiles and is reachable.

test "config edit: stub returns error.NotImplemented" {
    const config_edit = @import("../cli/config/edit.zig");
    const allocator = testing.allocator;
    const result = config_edit.run(allocator, null);
    try testing.expectError(error.NotImplemented, result);
}

test "config test: stub returns error.NotImplemented" {
    const config_test = @import("../cli/config/test.zig");
    const allocator = testing.allocator;
    const result = config_test.run(allocator, null);
    try testing.expectError(error.NotImplemented, result);
}
