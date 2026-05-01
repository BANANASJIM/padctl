//! Permanent canary that proves the test runner discovers tests inside
//! `testing_support` (the nested struct in src/main.zig).
//!
//! Mechanism: this file is registered as `pub const _meta_wiring_check_test = ...`
//! inside `testing_support`. The test block in src/main.zig calls
//! `std.testing.refAllDeclsRecursive(@This())`, which must walk into nested
//! namespaces. If that walk regresses (e.g. someone reverts to refAllDecls),
//! the deliberate-failure protocol below will catch it.
//!
//! Verification protocol when changing the discovery mechanism:
//!   1. Temporarily change the test below to `try std.testing.expect(false);`
//!   2. Push to a throwaway branch and confirm CI FAILS
//!   3. Revert the deliberate failure and confirm CI passes again
//!   4. Land the discovery-mechanism change with confidence
//!
//! See HISTORICAL NOTE on `testing_support` in src/main.zig (PR #213).

const std = @import("std");

test "_meta: test runner discovers tests in testing_support nested imports" {
    // Existence + execution of this test proves the wiring. Do not remove.
    try std.testing.expect(true);
}
