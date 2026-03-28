pub const MAX_TRANSFORMS = 8;

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
    C,
    Z,
    LM,
    RM,
    O,
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
    buttons: u64 = 0,
    gyro_x: i16 = 0,
    gyro_y: i16 = 0,
    gyro_z: i16 = 0,
    accel_x: i16 = 0,
    accel_y: i16 = 0,
    accel_z: i16 = 0,
    touch0_x: i16 = 0,
    touch0_y: i16 = 0,
    touch1_x: i16 = 0,
    touch1_y: i16 = 0,
    touch0_active: bool = false,
    touch1_active: bool = false,
    battery_level: u8 = 0,

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
        if (self.touch0_x != prev.touch0_x) d.touch0_x = self.touch0_x;
        if (self.touch0_y != prev.touch0_y) d.touch0_y = self.touch0_y;
        if (self.touch1_x != prev.touch1_x) d.touch1_x = self.touch1_x;
        if (self.touch1_y != prev.touch1_y) d.touch1_y = self.touch1_y;
        if (self.touch0_active != prev.touch0_active) d.touch0_active = self.touch0_active;
        if (self.touch1_active != prev.touch1_active) d.touch1_active = self.touch1_active;
        if (self.battery_level != prev.battery_level) d.battery_level = self.battery_level;
        return d;
    }

    pub fn synthesizeDpadAxes(gs: *GamepadState) void {
        const up = (gs.buttons & (@as(u64, 1) << @intFromEnum(ButtonId.DPadUp))) != 0;
        const down = (gs.buttons & (@as(u64, 1) << @intFromEnum(ButtonId.DPadDown))) != 0;
        const left = (gs.buttons & (@as(u64, 1) << @intFromEnum(ButtonId.DPadLeft))) != 0;
        const right = (gs.buttons & (@as(u64, 1) << @intFromEnum(ButtonId.DPadRight))) != 0;

        const dx: i8 = @as(i8, @intFromBool(right)) - @as(i8, @intFromBool(left));
        const dy: i8 = @as(i8, @intFromBool(down)) - @as(i8, @intFromBool(up));
        gs.dpad_x = dx;
        gs.dpad_y = dy;
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
        if (delta.touch0_x) |v| self.touch0_x = v;
        if (delta.touch0_y) |v| self.touch0_y = v;
        if (delta.touch1_x) |v| self.touch1_x = v;
        if (delta.touch1_y) |v| self.touch1_y = v;
        if (delta.touch0_active) |v| self.touch0_active = v;
        if (delta.touch1_active) |v| self.touch1_active = v;
        if (delta.battery_level) |v| self.battery_level = v;
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
    buttons: ?u64 = null,
    gyro_x: ?i16 = null,
    gyro_y: ?i16 = null,
    gyro_z: ?i16 = null,
    accel_x: ?i16 = null,
    accel_y: ?i16 = null,
    accel_z: ?i16 = null,
    touch0_x: ?i16 = null,
    touch0_y: ?i16 = null,
    touch1_x: ?i16 = null,
    touch1_y: ?i16 = null,
    touch0_active: ?bool = null,
    touch1_active: ?bool = null,
    battery_level: ?u8 = null,
};

pub fn generateRandomDelta(rng: std.Random) GamepadStateDelta {
    var d = GamepadStateDelta{};
    inline for (std.meta.fields(GamepadStateDelta)) |f| {
        if (rng.boolean()) {
            const Inner = @typeInfo(f.type).optional.child;
            @field(d, f.name) = switch (Inner) {
                bool => rng.boolean(),
                i16 => @bitCast(rng.int(u16)),
                i8 => @bitCast(rng.int(u8)),
                u8 => rng.int(u8),
                u64 => rng.int(u64),
                else => unreachable,
            };
        }
    }
    return d;
}

// --- tests ---

test "state: applyDelta: null fields leave state unchanged" {
    var s = GamepadState{ .ax = 10, .ay = 20, .buttons = 0xFF };
    s.applyDelta(.{});
    try std.testing.expectEqual(@as(i16, 10), s.ax);
    try std.testing.expectEqual(@as(i16, 20), s.ay);
    try std.testing.expectEqual(@as(u64, 0xFF), s.buttons);
}

test "state: applyDelta: full overwrite" {
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
    try std.testing.expectEqual(@as(u64, 0xDEAD), s.buttons);
    try std.testing.expectEqual(@as(i16, 10), s.gyro_x);
    try std.testing.expectEqual(@as(i16, -30), s.accel_z);
}

test "state: applyDelta: partial overwrite leaves other fields unchanged" {
    var s = GamepadState{ .ax = 5, .ay = 6, .rx = 7, .buttons = 0xF0 };
    s.applyDelta(.{ .ax = 99, .buttons = 0x0F });
    try std.testing.expectEqual(@as(i16, 99), s.ax);
    try std.testing.expectEqual(@as(i16, 6), s.ay); // unchanged
    try std.testing.expectEqual(@as(i16, 7), s.rx); // unchanged
    try std.testing.expectEqual(@as(u64, 0x0F), s.buttons);
}

test "state: diff: identical states produce empty delta" {
    const s = GamepadState{ .ax = 10, .buttons = 0xFF };
    const d = s.diff(s);
    try std.testing.expectEqual(@as(?i16, null), d.ax);
    try std.testing.expectEqual(@as(?u64, null), d.buttons);
}

test "state: diff: changed fields appear in delta" {
    const prev = GamepadState{ .ax = 10, .ay = 20 };
    const curr = GamepadState{ .ax = 50, .ay = 20, .lt = 128 };
    const d = curr.diff(prev);
    try std.testing.expectEqual(@as(?i16, 50), d.ax);
    try std.testing.expectEqual(@as(?i16, null), d.ay); // unchanged
    try std.testing.expectEqual(@as(?u8, 128), d.lt);
}

test "state: applyDelta: touchpad fields" {
    var s = GamepadState{};
    s.applyDelta(.{ .touch0_x = 1000, .touch0_y = -500, .touch0_active = true });
    try std.testing.expectEqual(@as(i16, 1000), s.touch0_x);
    try std.testing.expectEqual(@as(i16, -500), s.touch0_y);
    try std.testing.expectEqual(true, s.touch0_active);
    try std.testing.expectEqual(@as(i16, 0), s.touch1_x);
    try std.testing.expectEqual(false, s.touch1_active);
}

test "state: diff: touchpad fields appear in delta" {
    const prev = GamepadState{};
    const curr = GamepadState{ .touch0_x = 100, .touch1_active = true };
    const d = curr.diff(prev);
    try std.testing.expectEqual(@as(?i16, 100), d.touch0_x);
    try std.testing.expectEqual(@as(?bool, true), d.touch1_active);
    try std.testing.expectEqual(@as(?i16, null), d.touch0_y);
    try std.testing.expectEqual(@as(?bool, null), d.touch0_active);
}

test "state: applyDelta: battery_level field" {
    var s = GamepadState{};
    try std.testing.expectEqual(@as(u8, 0), s.battery_level);
    s.applyDelta(.{ .battery_level = 7 });
    try std.testing.expectEqual(@as(u8, 7), s.battery_level);
    s.applyDelta(.{}); // null leaves unchanged
    try std.testing.expectEqual(@as(u8, 7), s.battery_level);
}

test "state: diff: battery_level appears in delta when changed" {
    const prev = GamepadState{};
    const curr = GamepadState{ .battery_level = 10 };
    const d = curr.diff(prev);
    try std.testing.expectEqual(@as(?u8, 10), d.battery_level);

    const same = curr.diff(curr);
    try std.testing.expectEqual(@as(?u8, null), same.battery_level);
}

test "state: property: applyDelta(a, diff(b, a)) == b" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (0..1000) |_| {
        var a = GamepadState{};
        a.applyDelta(generateRandomDelta(rng));
        var b = GamepadState{};
        b.applyDelta(generateRandomDelta(rng));
        const d = b.diff(a);
        var result = a;
        result.applyDelta(d);
        inline for (std.meta.fields(GamepadState)) |f| {
            try std.testing.expectEqual(@field(b, f.name), @field(result, f.name));
        }
    }
}

test "state: property: diff(s, s) produces all-null delta" {
    var prng = std.Random.DefaultPrng.init(99);
    const rng = prng.random();
    for (0..1000) |_| {
        var s = GamepadState{};
        s.applyDelta(generateRandomDelta(rng));
        const d = s.diff(s);
        inline for (std.meta.fields(GamepadStateDelta)) |f| {
            try std.testing.expectEqual(@as(f.type, null), @field(d, f.name));
        }
    }
}

test "state: synthesizeDpadAxes: no buttons → 0,0" {
    var gs = GamepadState{};
    gs.synthesizeDpadAxes();
    try std.testing.expectEqual(@as(i8, 0), gs.dpad_x);
    try std.testing.expectEqual(@as(i8, 0), gs.dpad_y);
}

test "state: synthesizeDpadAxes: cardinal directions" {
    const T = std.testing;
    const cases = [_]struct { btn: ButtonId, dx: i8, dy: i8 }{
        .{ .btn = .DPadUp, .dx = 0, .dy = -1 },
        .{ .btn = .DPadDown, .dx = 0, .dy = 1 },
        .{ .btn = .DPadLeft, .dx = -1, .dy = 0 },
        .{ .btn = .DPadRight, .dx = 1, .dy = 0 },
    };
    for (cases) |c| {
        var gs = GamepadState{};
        gs.buttons = @as(u64, 1) << @intFromEnum(c.btn);
        gs.synthesizeDpadAxes();
        try T.expectEqual(c.dx, gs.dpad_x);
        try T.expectEqual(c.dy, gs.dpad_y);
    }
}

test "state: synthesizeDpadAxes: diagonal combinations" {
    const T = std.testing;
    const cases = [_]struct { btns: []const ButtonId, dx: i8, dy: i8 }{
        .{ .btns = &.{ .DPadUp, .DPadRight }, .dx = 1, .dy = -1 },
        .{ .btns = &.{ .DPadUp, .DPadLeft }, .dx = -1, .dy = -1 },
        .{ .btns = &.{ .DPadDown, .DPadRight }, .dx = 1, .dy = 1 },
        .{ .btns = &.{ .DPadDown, .DPadLeft }, .dx = -1, .dy = 1 },
    };
    for (cases) |c| {
        var gs = GamepadState{};
        for (c.btns) |b| {
            gs.buttons |= @as(u64, 1) << @intFromEnum(b);
        }
        gs.synthesizeDpadAxes();
        try T.expectEqual(c.dx, gs.dpad_x);
        try T.expectEqual(c.dy, gs.dpad_y);
    }
}
