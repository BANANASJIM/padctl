//! Shared PADCTL_TEST_REQUIRE_UHID / PADCTL_TEST_REQUIRE_UINPUT gate for the
//! Layer 2/3 UHID + uinput test suites.
//!
//! Extracted from three previously-duplicated inline copies
//! (uhid_uniq_pairing_test.zig, shadow_grab_integration_test.zig,
//! uinput_ff_erase_integration_test.zig) so every privileged suite shares one
//! enforcement policy:
//!
//!   - Default (flag unset): log a warning so the missing device is audible in
//!     CI output, then return `error.SkipZigTest`. The suite stays green while
//!     the gap stays visible.
//!   - Flag set to `1`/`true`: return `error.UhidAccessRequired` /
//!     `error.UinputAccessRequired` — a hard failure. The privileged e2e job
//!     sets the flag when the device is accessible, so a regression that would
//!     otherwise `SkipZigTest` into a green run turns RED instead.

const std = @import("std");
const testing = std.testing;

pub fn requireUhid() bool {
    const v = std.posix.getenv("PADCTL_TEST_REQUIRE_UHID") orelse return false;
    return std.mem.eql(u8, v, "1") or std.mem.eql(u8, v, "true");
}

pub fn requireUinput() bool {
    const v = std.posix.getenv("PADCTL_TEST_REQUIRE_UINPUT") orelse return false;
    return std.mem.eql(u8, v, "1") or std.mem.eql(u8, v, "true");
}

// Pure decision, factored out of the public entry points so the in-tree unit
// test can exercise both branches without mutating process env (which would
// leak into sibling tests sharing the same runner process).
fn decideUhid(require: bool) error{ SkipZigTest, UhidAccessRequired } {
    if (require) return error.UhidAccessRequired;
    return error.SkipZigTest;
}

fn decideUinput(require: bool) error{ SkipZigTest, UinputAccessRequired } {
    if (require) return error.UinputAccessRequired;
    return error.SkipZigTest;
}

pub fn reportMissingUhid(reason: []const u8) error{ SkipZigTest, UhidAccessRequired } {
    std.log.warn(
        "UHID test gate: /dev/uhid unavailable or the expected node is absent ({s}) — " ++
            "the L2/L3 UHID CI signal is SILENT here. Install udev rules via " ++
            "'sudo ./zig-out/bin/padctl install' and reload udev, or set " ++
            "PADCTL_TEST_REQUIRE_UHID=1 to turn this into a hard failure.",
        .{reason},
    );
    return decideUhid(requireUhid());
}

pub fn reportMissingUinput(reason: []const u8) error{ SkipZigTest, UinputAccessRequired } {
    std.log.warn(
        "uinput test gate: /dev/uinput unavailable or the expected node is absent ({s}) — " ++
            "the shadow-grab / FF-erase / e2e CI signal is SILENT here. Run in a " ++
            "privileged environment with /dev/uinput, or set " ++
            "PADCTL_TEST_REQUIRE_UINPUT=1 to turn this into a hard failure.",
        .{reason},
    );
    return decideUinput(requireUinput());
}

test "uhid_gate: require flag forces hard failure, default skips" {
    // Pure decision logic — env read is factored out so both branches run
    // deterministically under the zero-privilege `zig build test`.
    try testing.expect(decideUhid(true) == error.UhidAccessRequired);
    try testing.expect(decideUhid(false) == error.SkipZigTest);
    try testing.expect(decideUinput(true) == error.UinputAccessRequired);
    try testing.expect(decideUinput(false) == error.SkipZigTest);

    // The public env readers default to false when the flag is unset. The CI
    // `test` step never sets these flags, so this holds there.
    if (std.posix.getenv("PADCTL_TEST_REQUIRE_UHID") == null) {
        try testing.expect(!requireUhid());
    }
    if (std.posix.getenv("PADCTL_TEST_REQUIRE_UINPUT") == null) {
        try testing.expect(!requireUinput());
    }
}
