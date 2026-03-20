const toml = @import("toml");

pub const AxisConfig = struct {
    code: []const u8,
    min: i64,
    max: i64,
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
};

pub const DpadOutputConfig = struct {
    type: []const u8, // "hat" | "buttons"
};

pub const FfConfig = struct {
    type: []const u8, // "rumble"
    max_effects: ?i64 = null,
};

pub const AuxConfig = struct {
    type: ?[]const u8 = null, // "mouse" | "keyboard"
    name: ?[]const u8 = null,
    keyboard: ?bool = null,
    buttons: ?toml.HashMap([]const u8) = null,
};

pub const OutputConfig = struct {
    name: []const u8,
    vid: ?i64 = null,
    pid: ?i64 = null,
    axes: ?toml.HashMap(AxisConfig) = null,
    buttons: ?toml.HashMap([]const u8) = null,
    dpad: ?DpadOutputConfig = null,
    force_feedback: ?FfConfig = null,
    aux: ?AuxConfig = null,
};
