// Kernel-touching UHID tests. Requires /dev/uhid + CAP_SYS_ADMIN (or input group).
// Run with: zig build test-uhid
// NOT included in test, test-safe, test-tsan — those are pure userspace.
comptime {
    _ = @import("src/test/uhid_uniq_pairing_test.zig");
}
