//! Stable identity value consumed by the pure DualSense Edge USB codec.
//!
//! Runtime derivation is domain-separated and depends only on a canonical,
//! persistent physical identity. Keeping the wire value separate lets codec
//! tests pin feature bytes without a UHID fd or a process-global counter.

const std = @import("std");

pub const IDENTITY_DOMAIN = "padctl/dualsense-edge-usb/identity/v1\x00";
pub const UNIQ_PREFIX = "padctl/edge-";
pub const UNIQ_HEX_LEN = 12;
pub const UNIQ_LEN = UNIQ_PREFIX.len + UNIQ_HEX_LEN;

pub const EdgeIdentity = struct {
    pairing_mac: [6]u8,
};

pub const StableIdentity = struct {
    edge: EdgeIdentity,
    uniq: [UNIQ_LEN]u8,
};

pub const DeriveError = error{UnstablePhysicalIdentity};

/// Derive the pairing MAC and UHID uniq from one canonical persistent key.
/// Absolute paths are explicitly rejected: those are discovery fallbacks,
/// not the stable `HID_PHYS`-style identity this protocol requires.
pub fn deriveStableIdentity(phys_key: []const u8) DeriveError!StableIdentity {
    if (phys_key.len == 0 or phys_key[0] == '/') return error.UnstablePhysicalIdentity;

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(IDENTITY_DOMAIN);
    hasher.update(phys_key);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);

    var mac: [6]u8 = digest[0..6].*;
    // IEEE address bits: bit 0 clear means unicast, bit 1 set means locally
    // administered. The remaining 46 bits retain the domain-separated hash.
    mac[0] = (mac[0] & 0xfc) | 0x02;

    var uniq: [UNIQ_LEN]u8 = undefined;
    @memcpy(uniq[0..UNIQ_PREFIX.len], UNIQ_PREFIX);
    const hex = "0123456789abcdef";
    for (mac, 0..) |byte, i| {
        uniq[UNIQ_PREFIX.len + i * 2] = hex[byte >> 4];
        uniq[UNIQ_PREFIX.len + i * 2 + 1] = hex[byte & 0x0f];
    }
    return .{ .edge = .{ .pairing_mac = mac }, .uniq = uniq };
}

const testing = std.testing;

test "edge identity: SHA-256 domain vectors pin MAC and uniq" {
    const first = try deriveStableIdentity("phys-abc");
    try testing.expectEqual([6]u8{ 0x56, 0x94, 0x56, 0x5d, 0x71, 0x52 }, first.edge.pairing_mac);
    try testing.expectEqualStrings("padctl/edge-5694565d7152", &first.uniq);

    const second = try deriveStableIdentity("phys-abd");
    try testing.expectEqual([6]u8{ 0xea, 0xe6, 0xb6, 0x29, 0x77, 0x64 }, second.edge.pairing_mac);
    try testing.expectEqualStrings("padctl/edge-eae6b6297764", &second.uniq);
    try testing.expect(!std.mem.eql(u8, &first.uniq, &second.uniq));
}

test "edge identity: same canonical phys key is stable and MAC is local unicast" {
    const a = try deriveStableIdentity("usb-0000:00:14.0-1/input0");
    const b = try deriveStableIdentity("usb-0000:00:14.0-1/input0");
    try testing.expectEqual(a, b);
    try testing.expectEqual(@as(u8, 0x02), a.edge.pairing_mac[0] & 0x03);
}

test "edge identity: unstable phys fallbacks fail closed" {
    try testing.expectError(error.UnstablePhysicalIdentity, deriveStableIdentity(""));
    try testing.expectError(error.UnstablePhysicalIdentity, deriveStableIdentity("/sys/devices/absolute-fallback"));
}
