//! Pure uniq-string builder for padctl UHID devices.
//!
//! ADR-015 Stage 1 (§AC4) requires the primary pad + IMU UHID cards to share
//! a byte-identical `uhid_create2_req.uniq`. Layout:
//!
//!   "padctl/<device-id>-<instance>"
//!
//! - `device-id` = normalized `cfg.device.name`: lowercase ASCII, non-alphanum
//!   folded to `-`, consecutive `-` collapsed, leading/trailing `-` trimmed,
//!   clipped to 32 bytes.
//! - `instance`  = `hash16(phys_key)` rendered as 4 lowercase hex digits when
//!   `phys_key` is non-null; otherwise `ctr{xxxx}` counter fallback.
//!
//! The function is deliberately pure (no syscalls, no I/O) so it runs as a
//! Layer 0 unit test with zero privileges and matches the file-per-pure-
//! concern pattern already set by `src/io/uhid_descriptor.zig`.

const std = @import("std");

pub const MAX_UNIQ_LEN: usize = 64;

/// Build the shared uniq string. Caller owns the returned NUL-terminated
/// buffer and must free it.
///
/// `counter` is consulted only when `phys_key` is null — the caller is
/// responsible for snapshotting + advancing the counter (see
/// `device_instance.DeviceInstance.init`).
pub fn buildUniq(
    allocator: std.mem.Allocator,
    device_name: []const u8,
    phys_key: ?[]const u8,
    counter: u16,
) std.mem.Allocator.Error![:0]u8 {
    var id_buf: [32]u8 = undefined;
    const device_id = normalizeDeviceId(&id_buf, device_name);

    var inst_buf: [16]u8 = undefined;
    const instance: []const u8 = if (phys_key) |pk| blk: {
        const h = hash16(pk);
        break :blk std.fmt.bufPrint(&inst_buf, "{x:0>4}", .{h}) catch unreachable;
    } else blk: {
        break :blk std.fmt.bufPrint(&inst_buf, "ctr{x:0>4}", .{counter}) catch unreachable;
    };

    const body = try std.fmt.allocPrint(allocator, "padctl/{s}-{s}", .{ device_id, instance });
    defer allocator.free(body);
    const out = try allocator.allocSentinel(u8, body.len, 0);
    @memcpy(out, body);
    // Sanity: total (incl NUL terminator) must fit the 64-byte UHID field.
    std.debug.assert(out.len + 1 <= MAX_UNIQ_LEN);
    return out;
}

/// FNV-1a 32-bit truncated to 16 bits. Canonical parameters — identical to
/// the C reference and to `std.hash.Fnv1a_32` if it existed in-tree. Kept
/// explicit so an algorithm change would flip the pinned known-answer test
/// red immediately.
pub fn hash16(bytes: []const u8) u16 {
    var h: u32 = 0x811c9dc5;
    for (bytes) |b| {
        h ^= @as(u32, b);
        h *%= 0x01000193;
    }
    return @truncate(h);
}

/// Write a normalized device id into `buf`, returning the populated slice.
/// Destructive truncation at 32 bytes. Non-ASCII bytes fold to `-` — the
/// UHID uniq field must stay in printable ASCII for SDL's downstream
/// hash-of-uniq pairing logic to behave predictably.
pub fn normalizeDeviceId(buf: *[32]u8, name: []const u8) []u8 {
    var w: usize = 0;
    var last_dash: bool = true; // treat start as dash so we drop leading runs
    for (name) |b| {
        if (w >= buf.len) break;
        const c: u8 = blk: {
            if (b >= 'A' and b <= 'Z') break :blk b + ('a' - 'A');
            if ((b >= 'a' and b <= 'z') or (b >= '0' and b <= '9')) break :blk b;
            break :blk '-';
        };
        if (c == '-') {
            if (last_dash) continue;
            buf[w] = '-';
            w += 1;
            last_dash = true;
        } else {
            buf[w] = c;
            w += 1;
            last_dash = false;
        }
    }
    // Trim trailing '-'.
    while (w > 0 and buf[w - 1] == '-') : (w -= 1) {}
    return buf[0..w];
}

// --- tests ------------------------------------------------------------------

const testing = std.testing;

test "buildUniq: with phys_key produces stable hash suffix" {
    const allocator = testing.allocator;
    const uniq = try buildUniq(allocator, "Flydigi Vader 3 Pro", "usb-0000:00:14.0-3/input0", 0);
    defer allocator.free(uniq);
    try testing.expect(std.mem.startsWith(u8, uniq, "padctl/flydigi-vader-3-pro-"));
    // Suffix (after the last '-') must be exactly 4 lowercase hex digits.
    const last_dash = std.mem.lastIndexOfScalar(u8, uniq, '-').?;
    const suffix = uniq[last_dash + 1 ..];
    try testing.expectEqual(@as(usize, 4), suffix.len);
    for (suffix) |c| try testing.expect((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'));
}

test "buildUniq: null phys_key uses counter fallback" {
    const allocator = testing.allocator;
    const uniq = try buildUniq(allocator, "DualSense", null, 1);
    defer allocator.free(uniq);
    try testing.expectEqualStrings("padctl/dualsense-ctr0001", uniq);
}

test "buildUniq: idempotent on same inputs" {
    const allocator = testing.allocator;
    const a = try buildUniq(allocator, "Test Pad", "phys-abc", 0);
    defer allocator.free(a);
    const b = try buildUniq(allocator, "Test Pad", "phys-abc", 0);
    defer allocator.free(b);
    try testing.expectEqualStrings(a, b);
}

test "buildUniq: output <= MAX_UNIQ_LEN including NUL" {
    const allocator = testing.allocator;
    const long_name = "A" ** 60;
    const uniq = try buildUniq(allocator, long_name, null, 1);
    defer allocator.free(uniq);
    try testing.expect(uniq.len + 1 <= MAX_UNIQ_LEN);
}

test "buildUniq: non-ASCII bytes fold to '-'" {
    const allocator = testing.allocator;
    // "Pad " followed by a 3-byte UTF-8 CJK sequence. Each non-ASCII byte
    // folds to '-' and the resulting run is trimmed, leaving "pad".
    const uniq = try buildUniq(allocator, "Pad \xe4\xb8\xad", null, 1);
    defer allocator.free(uniq);
    try testing.expectEqualStrings("padctl/pad-ctr0001", uniq);
    // Every byte before the terminator must be ASCII alphanum, '/' or '-'.
    for (uniq) |c| {
        const ok = (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '-' or c == '/';
        try testing.expect(ok);
    }
}

test "buildUniq: counter fallback differs between counter values" {
    const allocator = testing.allocator;
    const a = try buildUniq(allocator, "Pad", null, 1);
    defer allocator.free(a);
    const b = try buildUniq(allocator, "Pad", null, 2);
    defer allocator.free(b);
    try testing.expect(!std.mem.eql(u8, a, b));
}

test "hash16: known-answer vector pins FNV-1a-32 truncated output" {
    // Pinned first-run value. Any change to the algorithm (parameters, fold
    // strategy, non-wrapping multiply) will flip this red.
    const v = hash16("padctl/vader-5-pro-0000:00:14.0-1.3");
    try testing.expectEqual(@as(u16, 0xeedd), v);
}

test "normalizeDeviceId: collapses runs and trims edges" {
    var buf: [32]u8 = undefined;
    const out = normalizeDeviceId(&buf, "  Flydigi  Vader 3  Pro  ");
    try testing.expectEqualStrings("flydigi-vader-3-pro", out);
}

test "normalizeDeviceId: truncates at 32 bytes" {
    var buf: [32]u8 = undefined;
    const out = normalizeDeviceId(&buf, "A" ** 64);
    try testing.expect(out.len <= 32);
}
