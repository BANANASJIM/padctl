//! Stable identity value consumed by the pure DualSense Edge USB codec.
//!
//! Runtime derivation is domain-separated and depends only on a canonical,
//! persistent physical identity. Keeping the wire value separate lets codec
//! tests pin feature bytes without a UHID fd or a process-global counter.

const std = @import("std");

pub const IDENTITY_DOMAIN = "padctl/dualsense-edge-usb/identity/v1\x00";
/// Linux hid-playstation replaces `hdev->uniq` with the pairing MAC using
/// `%pMR`: little-endian bytes rendered in reverse order with colons.
/// Supplying that value in UHID_CREATE2 keeps identity stable before and after
/// the driver reads feature report 0x09.
pub const UNIQ_LEN = 17;

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
    const hex = "0123456789abcdef";
    for (0..mac.len) |i| {
        const byte = mac[mac.len - 1 - i];
        uniq[i * 3] = hex[byte >> 4];
        uniq[i * 3 + 1] = hex[byte & 0x0f];
        if (i + 1 != mac.len) uniq[i * 3 + 2] = ':';
    }
    return .{ .edge = .{ .pairing_mac = mac }, .uniq = uniq };
}

const testing = std.testing;

test "edge identity: SHA-256 domain vectors pin MAC and uniq" {
    const first = try deriveStableIdentity("phys-abc");
    try testing.expectEqual([6]u8{ 0x56, 0x94, 0x56, 0x5d, 0x71, 0x52 }, first.edge.pairing_mac);
    try testing.expectEqualStrings("52:71:5d:56:94:56", &first.uniq);

    const second = try deriveStableIdentity("phys-abd");
    try testing.expectEqual([6]u8{ 0xea, 0xe6, 0xb6, 0x29, 0x77, 0x64 }, second.edge.pairing_mac);
    try testing.expectEqualStrings("64:77:29:b6:e6:ea", &second.uniq);
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
