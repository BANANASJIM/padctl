pub const ButtonId = enum {
    A,
    B,
    X,
    Y,
    LB,
    RB,
    LT,
    RT,
    Start,
    Select,
    Home,
    Capture,
    LS,
    RS,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
    M1,
    M2,
    M3,
    M4,
    Paddle1,
    Paddle2,
    Paddle3,
    Paddle4,
    TouchPad,
    Mic,
};

pub const GamepadState = struct {
    ax: i16 = 0,
    ay: i16 = 0,
    rx: i16 = 0,
    ry: i16 = 0,
    lt: u8 = 0,
    rt: u8 = 0,
    dpad_x: i8 = 0,
    dpad_y: i8 = 0,
    buttons: u32 = 0,
    gyro_x: i16 = 0,
    gyro_y: i16 = 0,
    gyro_z: i16 = 0,
    accel_x: i16 = 0,
    accel_y: i16 = 0,
    accel_z: i16 = 0,

    pub fn diff(self: GamepadState, prev: GamepadState) GamepadStateDelta {
        var d = GamepadStateDelta{};
        if (self.ax != prev.ax) d.ax = self.ax;
        if (self.ay != prev.ay) d.ay = self.ay;
        if (self.rx != prev.rx) d.rx = self.rx;
        if (self.ry != prev.ry) d.ry = self.ry;
        if (self.lt != prev.lt) d.lt = self.lt;
        if (self.rt != prev.rt) d.rt = self.rt;
        if (self.dpad_x != prev.dpad_x) d.dpad_x = self.dpad_x;
        if (self.dpad_y != prev.dpad_y) d.dpad_y = self.dpad_y;
        if (self.buttons != prev.buttons) d.buttons = self.buttons;
        if (self.gyro_x != prev.gyro_x) d.gyro_x = self.gyro_x;
        if (self.gyro_y != prev.gyro_y) d.gyro_y = self.gyro_y;
        if (self.gyro_z != prev.gyro_z) d.gyro_z = self.gyro_z;
        if (self.accel_x != prev.accel_x) d.accel_x = self.accel_x;
        if (self.accel_y != prev.accel_y) d.accel_y = self.accel_y;
        if (self.accel_z != prev.accel_z) d.accel_z = self.accel_z;
        return d;
    }

    pub fn applyDelta(self: *GamepadState, delta: GamepadStateDelta) void {
        if (delta.ax) |v| self.ax = v;
        if (delta.ay) |v| self.ay = v;
        if (delta.rx) |v| self.rx = v;
        if (delta.ry) |v| self.ry = v;
        if (delta.lt) |v| self.lt = v;
        if (delta.rt) |v| self.rt = v;
        if (delta.dpad_x) |v| self.dpad_x = v;
        if (delta.dpad_y) |v| self.dpad_y = v;
        if (delta.buttons) |v| self.buttons = v;
        if (delta.gyro_x) |v| self.gyro_x = v;
        if (delta.gyro_y) |v| self.gyro_y = v;
        if (delta.gyro_z) |v| self.gyro_z = v;
        if (delta.accel_x) |v| self.accel_x = v;
        if (delta.accel_y) |v| self.accel_y = v;
        if (delta.accel_z) |v| self.accel_z = v;
    }
};

const std = @import("std");

pub const GamepadStateDelta = struct {
    ax: ?i16 = null,
    ay: ?i16 = null,
    rx: ?i16 = null,
    ry: ?i16 = null,
    lt: ?u8 = null,
    rt: ?u8 = null,
    dpad_x: ?i8 = null,
    dpad_y: ?i8 = null,
    buttons: ?u32 = null,
    gyro_x: ?i16 = null,
    gyro_y: ?i16 = null,
    gyro_z: ?i16 = null,
    accel_x: ?i16 = null,
    accel_y: ?i16 = null,
    accel_z: ?i16 = null,
};

// --- tests ---

test "applyDelta: null fields leave state unchanged" {
    var s = GamepadState{ .ax = 10, .ay = 20, .buttons = 0xFF };
    s.applyDelta(.{});
    try std.testing.expectEqual(@as(i16, 10), s.ax);
    try std.testing.expectEqual(@as(i16, 20), s.ay);
    try std.testing.expectEqual(@as(u32, 0xFF), s.buttons);
}

test "applyDelta: full overwrite" {
    var s = GamepadState{};
    s.applyDelta(.{
        .ax = 100,
        .ay = -100,
        .rx = 200,
        .ry = -200,
        .lt = 128,
        .rt = 64,
        .dpad_x = 1,
        .dpad_y = -1,
        .buttons = 0xDEAD,
        .gyro_x = 10,
        .gyro_y = 20,
        .gyro_z = 30,
        .accel_x = -10,
        .accel_y = -20,
        .accel_z = -30,
    });
    try std.testing.expectEqual(@as(i16, 100), s.ax);
    try std.testing.expectEqual(@as(i16, -100), s.ay);
    try std.testing.expectEqual(@as(i16, 200), s.rx);
    try std.testing.expectEqual(@as(i16, -200), s.ry);
    try std.testing.expectEqual(@as(u8, 128), s.lt);
    try std.testing.expectEqual(@as(u8, 64), s.rt);
    try std.testing.expectEqual(@as(i8, 1), s.dpad_x);
    try std.testing.expectEqual(@as(i8, -1), s.dpad_y);
    try std.testing.expectEqual(@as(u32, 0xDEAD), s.buttons);
    try std.testing.expectEqual(@as(i16, 10), s.gyro_x);
    try std.testing.expectEqual(@as(i16, -30), s.accel_z);
}

test "applyDelta: partial overwrite leaves other fields unchanged" {
    var s = GamepadState{ .ax = 5, .ay = 6, .rx = 7, .buttons = 0xF0 };
    s.applyDelta(.{ .ax = 99, .buttons = 0x0F });
    try std.testing.expectEqual(@as(i16, 99), s.ax);
    try std.testing.expectEqual(@as(i16, 6), s.ay); // unchanged
    try std.testing.expectEqual(@as(i16, 7), s.rx); // unchanged
    try std.testing.expectEqual(@as(u32, 0x0F), s.buttons);
}

test "diff: identical states produce empty delta" {
    const s = GamepadState{ .ax = 10, .buttons = 0xFF };
    const d = s.diff(s);
    try std.testing.expectEqual(@as(?i16, null), d.ax);
    try std.testing.expectEqual(@as(?u32, null), d.buttons);
}

test "diff: changed fields appear in delta" {
    const prev = GamepadState{ .ax = 10, .ay = 20 };
    const curr = GamepadState{ .ax = 50, .ay = 20, .lt = 128 };
    const d = curr.diff(prev);
    try std.testing.expectEqual(@as(?i16, 50), d.ax);
    try std.testing.expectEqual(@as(?i16, null), d.ay); // unchanged
    try std.testing.expectEqual(@as(?u8, 128), d.lt);
}
