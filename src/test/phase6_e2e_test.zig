// Phase 6 E2E tests.
// MED-1: T5 contributing guide existence (skip until T5 delivers the file).
// MED-3: config edit/test subcommands — basic reachability after T9 implementation.

const std = @import("std");
const testing = std.testing;

// MED-1: docs/contributing/device-toml-from-inputplumber.md must exist after T5.
// Skipped until T5 is complete.
test "T5: device-toml-from-inputplumber guide exists" {
    if (true) return error.SkipZigTest;
    _ = try std.fs.cwd().statFile("docs/contributing/device-toml-from-inputplumber.md");
}

// MED-3: `padctl config edit` — no mapping files present returns NoMappingFound.
test "config edit: no mapping found error" {
    const config_edit = @import("../cli/config/edit.zig");
    const allocator = testing.allocator;
    const result = config_edit.run(allocator, null);
    // Expects NoMappingFound when no mapping files exist in XDG dirs
    try testing.expectError(error.NoMappingFound, result);
}

// MED-3: `padctl config test` — no hidraw device returns NoHidrawDevice.
test "config test: no hidraw device error" {
    const config_test = @import("../cli/config/test.zig");
    const allocator = testing.allocator;
    const result = config_test.run(allocator, null, null);
    // Expects NoHidrawDevice when no /dev/hidraw* devices are accessible
    try testing.expectError(error.NoHidrawDevice, result);
}
