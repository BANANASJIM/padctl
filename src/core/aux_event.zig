const std = @import("std");

pub const AuxEvent = union(enum) {
    key: struct { code: u16, pressed: bool },
    mouse_button: struct { code: u16, pressed: bool },
    rel: struct { code: u16, value: i32 },
};

var overflow_warned = std.atomic.Value(bool).init(false);

fn warnOverflowOnce() void {
    if (overflow_warned.cmpxchgStrong(false, true, .monotonic, .monotonic) == null) {
        std.log.warn("aux event buffer overflow (64 slots): some events dropped or shed; check for oversized single-frame macros", .{});
    }
}

fn isRelease(val: AuxEvent) bool {
    return switch (val) {
        .key => |k| !k.pressed,
        .mouse_button => |b| !b.pressed,
        .rel => false,
    };
}

fn isPress(val: AuxEvent) bool {
    return switch (val) {
        .key => |k| k.pressed,
        .mouse_button => |b| b.pressed,
        .rel => false,
    };
}

fn isRel(val: AuxEvent) bool {
    return switch (val) {
        .rel => true,
        else => false,
    };
}

pub const AuxEventList = struct {
    buffer: [64]AuxEvent = undefined,
    len: usize = 0,

    pub fn append(self: *AuxEventList, val: AuxEvent) error{Overflow}!void {
        if (self.len < 64) {
            self.buffer[self.len] = val;
            self.len += 1;
            return;
        }

        // A dropped release strands a key (stuck); a dropped press is benign.
        // On overflow, evict the newest press to seat an incoming release.
        warnOverflowOnce();
        if (isRelease(val)) {
            var i: usize = self.len;
            while (i > 0) {
                i -= 1;
                if (isPress(self.buffer[i])) {
                    self.buffer[i] = val;
                    return;
                }
            }
            i = self.len;
            while (i > 0) {
                i -= 1;
                if (isRel(self.buffer[i])) {
                    self.buffer[i] = val;
                    return;
                }
            }
        }
        return error.Overflow;
    }

    pub fn get(self: *const AuxEventList, i: usize) AuxEvent {
        std.debug.assert(i < self.len);
        return self.buffer[i];
    }

    pub fn slice(self: *const AuxEventList) []const AuxEvent {
        return self.buffer[0..self.len];
    }
};

const testing = std.testing;

test "AuxEventList: release evicts most recent press on overflow (F-3)" {
    var list = AuxEventList{};
    for (0..64) |i| {
        try list.append(.{ .key = .{ .code = @intCast(i), .pressed = true } });
    }
    try list.append(.{ .key = .{ .code = 99, .pressed = false } });
    try testing.expectEqual(@as(usize, 64), list.len);

    // The evicted slot is the last (most recent) press.
    switch (list.buffer[63]) {
        .key => |k| {
            try testing.expectEqual(@as(u16, 99), k.code);
            try testing.expect(!k.pressed);
        },
        else => return error.WrongType,
    }
    // The prior slot still holds an original press.
    switch (list.buffer[62]) {
        .key => |k| try testing.expect(k.pressed),
        else => return error.WrongType,
    }
    // Exactly one release seated.
    var releases: usize = 0;
    for (list.slice()) |ev| {
        switch (ev) {
            .key => |k| if (!k.pressed) {
                releases += 1;
            },
            else => {},
        }
    }
    try testing.expectEqual(@as(usize, 1), releases);
}

test "AuxEventList: all-release buffer still overflows on release" {
    var list = AuxEventList{};
    for (0..64) |_| {
        try list.append(.{ .key = .{ .code = 30, .pressed = false } });
    }
    try testing.expectError(error.Overflow, list.append(.{ .key = .{ .code = 30, .pressed = false } }));
}
