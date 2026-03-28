const std = @import("std");

pub const AuxEvent = union(enum) {
    key: struct { code: u16, pressed: bool },
    mouse_button: struct { code: u16, pressed: bool },
    rel: struct { code: u16, value: i32 },
};

pub const AuxEventList = struct {
    buffer: [64]AuxEvent = undefined,
    len: usize = 0,

    pub fn append(self: *AuxEventList, val: AuxEvent) error{Overflow}!void {
        if (self.len >= 64) return error.Overflow;
        self.buffer[self.len] = val;
        self.len += 1;
    }

    pub fn get(self: *const AuxEventList, i: usize) AuxEvent {
        std.debug.assert(i < self.len);
        return self.buffer[i];
    }

    pub fn slice(self: *const AuxEventList) []const AuxEvent {
        return self.buffer[0..self.len];
    }
};
