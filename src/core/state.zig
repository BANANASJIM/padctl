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
