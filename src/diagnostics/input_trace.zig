const std = @import("std");
const padctl_log = @import("../log.zig");

const input_log = std.log.scoped(.input);
const gesture_log = std.log.scoped(.gesture);

/// Button reports are the useful unit for mapping diagnostics. Logging every
/// axis/IMU report would rotate a 100 MiB dump in minutes on high-rate pads.
pub const MAX_RAW_BYTES: usize = 64;

pub fn enabled() bool {
    return padctl_log.shouldWriteToFile(.debug);
}

pub fn isButtonEdge(before: u64, after: u64) bool {
    return before != after;
}

fn rawHex(raw: []const u8, buf: *[MAX_RAW_BYTES * 2]u8) []const u8 {
    const hex = "0123456789abcdef";
    const n: usize = @min(raw.len, MAX_RAW_BYTES);
    for (raw[0..n], 0..) |byte, i| {
        buf[i * 2] = hex[byte >> 4];
        buf[i * 2 + 1] = hex[byte & 0x0f];
    }
    return buf[0 .. n * 2];
}

/// Physical layer: raw report bytes plus the decoded button transition. This
/// deliberately fires only when the decoded button mask changes.
pub fn logInputEdge(
    device_tag: []const u8,
    interface_id: u8,
    before: u64,
    after: u64,
    raw: []const u8,
    now_ns: i128,
) void {
    if (!isButtonEdge(before, after) or !enabled()) return;
    var hex_buf: [MAX_RAW_BYTES * 2]u8 = undefined;
    const encoded = rawHex(raw, &hex_buf);
    input_log.debug(
        "[{s}] INPUT_EDGE now_ns={d} iface={d} changed=0x{x:0>16} buttons=0x{x:0>16} raw={s}{s}",
        .{ device_tag, now_ns, interface_id, before ^ after, after, encoded, if (raw.len > MAX_RAW_BYTES) "..." else "" },
    );
}

/// Virtual layer: log only output button transitions, not axis-only frames.
pub fn logOutputEdge(
    device_tag: []const u8,
    cause: []const u8,
    before: u64,
    after: u64,
    now_ns: i128,
) void {
    if (!isButtonEdge(before, after) or !enabled()) return;
    input_log.debug(
        "[{s}] OUTPUT_EDGE now_ns={d} cause={s} changed=0x{x:0>16} buttons=0x{x:0>16}",
        .{ device_tag, now_ns, cause, before ^ after, after },
    );
}

/// Gesture layer: one line for each physical edge and the state-machine result.
pub fn logGestureEdge(
    source: []const u8,
    pressed: bool,
    now_ns: i128,
    elapsed_ns: i128,
    emit_len: usize,
    arm_leg: []const u8,
    arm_deadline_ns: i128,
    cancel_hold: bool,
    cancel_double: bool,
) void {
    if (!enabled()) return;
    gesture_log.debug(
        "GESTURE_EDGE source={s} edge={s} now_ns={d} elapsed_ns={d} emits={d} arm={s} deadline_ns={d} cancel_hold={} cancel_double={}",
        .{ source, if (pressed) "down" else "up", now_ns, elapsed_ns, emit_len, arm_leg, arm_deadline_ns, cancel_hold, cancel_double },
    );
}

pub fn logGestureEmit(
    source: []const u8,
    action: []const u8,
    target: []const u8,
    from_timer: bool,
    now_ns: i128,
) void {
    if (!enabled()) return;
    gesture_log.debug(
        "GESTURE_EMIT source={s} action={s} target={s} origin={s} now_ns={d}",
        .{ source, action, target, if (from_timer) "timer" else "edge", now_ns },
    );
}

pub fn logGestureTimer(
    source: []const u8,
    leg: []const u8,
    held: bool,
    emit_len: usize,
    now_ns: i128,
) void {
    if (!enabled()) return;
    gesture_log.debug(
        "GESTURE_TIMER source={s} leg={s} held={} emits={d} now_ns={d}",
        .{ source, leg, held, emit_len, now_ns },
    );
}

test "input trace: button-edge filter ignores axis-only reports" {
    try std.testing.expect(!isButtonEdge(0, 0));
    try std.testing.expect(isButtonEdge(0, @as(u64, 1) << 14));
    try std.testing.expect(isButtonEdge(@as(u64, 1) << 15, 0));
}

test "input trace: raw hex is exact and bounded" {
    var buf: [MAX_RAW_BYTES * 2]u8 = undefined;
    try std.testing.expectEqualStrings("5aa5ef00", rawHex(&.{ 0x5a, 0xa5, 0xef, 0x00 }, &buf));

    var oversized: [MAX_RAW_BYTES + 7]u8 = undefined;
    @memset(&oversized, 0xab);
    const got = rawHex(&oversized, &buf);
    try std.testing.expectEqual(MAX_RAW_BYTES * 2, got.len);
    try std.testing.expectEqualStrings("ab", got[got.len - 2 ..]);
}

test "input trace: debug diagnostics are gated by dump" {
    padctl_log.setEnabled(false);
    try std.testing.expect(!enabled());
    padctl_log.setEnabled(true);
    defer padctl_log.setEnabled(false);
    try std.testing.expect(enabled());
}
