const std = @import("std");

/// High enough to skip the ACKs and status frames some devices send after init.
pub const threshold = 200;

pub const ReportWatch = struct {
    unmatched: u32 = 0,
    matched_any: bool = false,
    warned: bool = false,
    last_buf: [16]u8 = undefined,
    last_shown: usize = 0,
    last_len: usize = 0,

    /// True once per bind, when `threshold` frames arrived and none matched.
    pub fn observe(self: *ReportWatch, matched: bool, frame: []const u8) bool {
        if (self.matched_any or self.warned) return false;
        if (matched) {
            self.matched_any = true;
            return false;
        }
        self.unmatched += 1;
        self.last_len = frame.len;
        self.last_shown = @min(frame.len, self.last_buf.len);
        @memcpy(self.last_buf[0..self.last_shown], frame[0..self.last_shown]);
        if (self.unmatched < threshold) return false;
        self.warned = true;
        return true;
    }

    pub fn last(self: *const ReportWatch) []const u8 {
        return self.last_buf[0..self.last_shown];
    }
};

const testing = std.testing;

test "report_watch: warns once after threshold unmatched frames" {
    var w = ReportWatch{};
    const frame = [_]u8{ 0x01, 0x02, 0x03 };
    var fired: usize = 0;
    for (0..threshold * 2) |_| {
        if (w.observe(false, &frame)) fired += 1;
    }
    try testing.expectEqual(@as(usize, 1), fired);
    try testing.expectEqualSlices(u8, &frame, w.last());
    try testing.expectEqual(@as(usize, 3), w.last_len);
}

test "report_watch: a single match silences it" {
    var w = ReportWatch{};
    const frame = [_]u8{0x00};
    for (0..threshold - 1) |_| try testing.expect(!w.observe(false, &frame));
    try testing.expect(!w.observe(true, &frame));
    for (0..threshold * 2) |_| try testing.expect(!w.observe(false, &frame));
}

test "report_watch: keeps only the first 16 bytes of a long frame" {
    var w = ReportWatch{};
    const frame = [_]u8{0xab} ** 64;
    _ = w.observe(false, &frame);
    try testing.expectEqual(@as(usize, 16), w.last().len);
    try testing.expectEqual(@as(usize, 64), w.last_len);
}
