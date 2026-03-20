const std = @import("std");
const state = @import("../core/state.zig");
const device = @import("../config/device.zig");
const input_codes = @import("../config/input_codes.zig");

const c = @cImport({
    @cInclude("linux/uinput.h");
    @cInclude("linux/input.h");
    @cInclude("linux/input-event-codes.h");
});

const IOCTL = std.os.linux.ioctl;
const UI_SET_EVBIT = IOCTL.IOW('U', 100, c_int);
const UI_SET_KEYBIT = IOCTL.IOW('U', 101, c_int);
const UI_SET_ABSBIT = IOCTL.IOW('U', 103, c_int);
const UI_SET_FFBIT = IOCTL.IOW('U', 107, c_int);
const UI_DEV_SETUP = IOCTL.IOW('U', 3, c.uinput_setup);
const UI_ABS_SETUP = IOCTL.IOW('U', 4, c.uinput_abs_setup);
const UI_DEV_CREATE = IOCTL.IO('U', 1);
const UI_DEV_DESTROY = IOCTL.IO('U', 2);
const UI_BEGIN_FF_UPLOAD = IOCTL.IOWR('U', 200, c.uinput_ff_upload);
const UI_END_FF_UPLOAD = IOCTL.IOW('U', 201, c.uinput_ff_upload);
const UI_BEGIN_FF_ERASE = IOCTL.IOWR('U', 202, c.uinput_ff_erase);
const UI_END_FF_ERASE = IOCTL.IOW('U', 203, c.uinput_ff_erase);

const MAX_EVENTS = 64;

fn ioctlInt(fd: std.posix.fd_t, request: u32, val: c_int) !void {
    const rc = std.os.linux.ioctl(fd, request, @intCast(val));
    return switch (std.posix.errno(rc)) {
        .SUCCESS => {},
        .PERM => error.PermissionDenied,
        else => |e| std.posix.unexpectedErrno(e),
    };
}

fn ioctlPtr(fd: std.posix.fd_t, request: u32, ptr: usize) !void {
    const rc = std.os.linux.ioctl(fd, request, ptr);
    return switch (std.posix.errno(rc)) {
        .SUCCESS => {},
        .PERM => error.PermissionDenied,
        else => |e| std.posix.unexpectedErrno(e),
    };
}

pub const FfEvent = struct {
    effect_type: u16,
    strong: u16,
    weak: u16,
};

pub const OutputDevice = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        emit: *const fn (ptr: *anyopaque, s: state.GamepadState) anyerror!void,
        poll_ff: *const fn (ptr: *anyopaque) anyerror!?FfEvent,
        close: *const fn (ptr: *anyopaque) void,
    };

    pub fn emit(self: OutputDevice, s: state.GamepadState) !void {
        return self.vtable.emit(self.ptr, s);
    }

    pub fn pollFf(self: OutputDevice) !?FfEvent {
        return self.vtable.poll_ff(self.ptr);
    }

    pub fn close(self: OutputDevice) void {
        self.vtable.close(self.ptr);
    }
};

pub const AuxEvent = union(enum) {
    key: struct { code: u16, pressed: bool },
    mouse_button: struct { code: u16, pressed: bool },
};

pub const AuxOutputDevice = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        emit_aux: *const fn (ptr: *anyopaque, events: []const AuxEvent) anyerror!void,
        close: *const fn (ptr: *anyopaque) void,
    };

    pub fn emitAux(self: AuxOutputDevice, events: []const AuxEvent) !void {
        return self.vtable.emit_aux(self.ptr, events);
    }

    pub fn close(self: AuxOutputDevice) void {
        self.vtable.close(self.ptr);
    }
};

// Resolved button mapping: ButtonId index → uinput BTN code (0 = unmapped)
const BUTTON_COUNT = @typeInfo(state.ButtonId).@"enum".fields.len;

pub const UinputDevice = struct {
    fd: std.posix.fd_t,
    prev: state.GamepadState = .{},
    // button_codes[i] = BTN code for ButtonId with tag value i (0 = not mapped)
    button_codes: [BUTTON_COUNT]u16,
    // ABS axis info: parallel arrays indexed by OutputConfig axes order
    axis_codes: [16]u16 = undefined,
    axis_state_offsets: [16]AxisStateField = undefined,
    axis_count: usize = 0,
    has_dpad_hat: bool = false,

    const AxisStateField = enum { ax, ay, rx, ry, lt, rt, dpad_x, dpad_y };

    pub fn create(cfg: *const device.OutputConfig) !UinputDevice {
        const flags = std.posix.O{ .ACCMODE = .WRONLY, .NONBLOCK = true };
        const fd = try std.posix.open("/dev/uinput", flags, 0);
        errdefer std.posix.close(fd);

        var has_abs = false;
        var has_key = false;
        var has_ff = false;

        var axis_codes: [16]u16 = undefined;
        var axis_state_offsets: [16]AxisStateField = undefined;
        var axis_count: usize = 0;
        var has_dpad_hat = false;

        if (cfg.axes != null) has_abs = true;
        if (cfg.buttons != null) has_key = true;
        if (cfg.dpad) |dp| {
            if (std.mem.eql(u8, dp.type, "hat")) {
                has_abs = true;
                has_dpad_hat = true;
            } else {
                has_key = true;
            }
        }
        if (cfg.force_feedback != null) has_ff = true;

        // Step 1: register event types
        if (has_abs) try ioctlInt(fd, UI_SET_EVBIT, c.EV_ABS);
        if (has_key) try ioctlInt(fd, UI_SET_EVBIT, c.EV_KEY);
        if (has_ff) try ioctlInt(fd, UI_SET_EVBIT, c.EV_FF);

        // Step 2+3: register abs bits and key bits
        if (cfg.axes) |axes| {
            var it = axes.map.iterator();
            while (it.next()) |entry| {
                const code = try input_codes.resolveAbsCode(entry.value_ptr.*.code);
                try ioctlInt(fd, UI_SET_ABSBIT, @intCast(code));
                if (axis_count < 16) {
                    axis_codes[axis_count] = code;
                    axis_state_offsets[axis_count] = stateFieldForAxis(entry.key_ptr.*);
                    axis_count += 1;
                }
            }
        }
        if (has_dpad_hat) {
            try ioctlInt(fd, UI_SET_ABSBIT, c.ABS_HAT0X);
            try ioctlInt(fd, UI_SET_ABSBIT, c.ABS_HAT0Y);
        }

        var button_codes: [BUTTON_COUNT]u16 = [_]u16{0} ** BUTTON_COUNT;
        if (cfg.buttons) |buttons| {
            var it = buttons.map.iterator();
            while (it.next()) |entry| {
                const btn_id = std.meta.stringToEnum(state.ButtonId, entry.key_ptr.*) orelse continue;
                const code = try input_codes.resolveBtnCode(entry.value_ptr.*);
                try ioctlInt(fd, UI_SET_KEYBIT, @intCast(code));
                button_codes[@intFromEnum(btn_id)] = code;
            }
        }
        if (cfg.dpad) |dp| {
            if (!std.mem.eql(u8, dp.type, "hat")) {
                try ioctlInt(fd, UI_SET_KEYBIT, c.BTN_DPAD_UP);
                try ioctlInt(fd, UI_SET_KEYBIT, c.BTN_DPAD_DOWN);
                try ioctlInt(fd, UI_SET_KEYBIT, c.BTN_DPAD_LEFT);
                try ioctlInt(fd, UI_SET_KEYBIT, c.BTN_DPAD_RIGHT);
            }
        }
        if (has_ff) try ioctlInt(fd, UI_SET_FFBIT, c.FF_RUMBLE);

        // Step 4: uinput_setup (name/vid/pid/bustype/ff_effects_max)
        var setup = std.mem.zeroes(c.uinput_setup);
        const name = cfg.name;
        const copy_len = @min(name.len, setup.name.len - 1);
        @memcpy(setup.name[0..copy_len], name[0..copy_len]);
        setup.id.bustype = c.BUS_VIRTUAL;
        setup.id.vendor = if (cfg.vid) |v| @intCast(v) else 0;
        setup.id.product = if (cfg.pid) |p| @intCast(p) else 0;
        if (cfg.force_feedback) |ff| {
            setup.ff_effects_max = @intCast(ff.max_effects orelse 16);
        }
        try ioctlPtr(fd, UI_DEV_SETUP, @intFromPtr(&setup));

        // Step 5: UI_ABS_SETUP for each axis
        if (cfg.axes) |axes| {
            var it = axes.map.iterator();
            while (it.next()) |entry| {
                const code = try input_codes.resolveAbsCode(entry.value_ptr.*.code);
                var abs_setup = std.mem.zeroes(c.uinput_abs_setup);
                abs_setup.code = code;
                abs_setup.absinfo.minimum = @intCast(entry.value_ptr.*.min);
                abs_setup.absinfo.maximum = @intCast(entry.value_ptr.*.max);
                abs_setup.absinfo.fuzz = @intCast(entry.value_ptr.*.fuzz orelse 0);
                abs_setup.absinfo.flat = @intCast(entry.value_ptr.*.flat orelse 0);
                abs_setup.absinfo.resolution = @intCast(entry.value_ptr.*.res orelse 0);
                try ioctlPtr(fd, UI_ABS_SETUP, @intFromPtr(&abs_setup));
            }
        }
        if (has_dpad_hat) {
            for ([_]u16{ c.ABS_HAT0X, c.ABS_HAT0Y }) |hat_code| {
                var abs_setup = std.mem.zeroes(c.uinput_abs_setup);
                abs_setup.code = hat_code;
                abs_setup.absinfo.minimum = -1;
                abs_setup.absinfo.maximum = 1;
                try ioctlPtr(fd, UI_ABS_SETUP, @intFromPtr(&abs_setup));
            }
        }

        // Step 6: UI_DEV_CREATE
        try ioctlPtr(fd, UI_DEV_CREATE, 0);

        return .{
            .fd = fd,
            .button_codes = button_codes,
            .axis_codes = axis_codes,
            .axis_state_offsets = axis_state_offsets,
            .axis_count = axis_count,
            .has_dpad_hat = has_dpad_hat,
        };
    }

    fn stateFieldForAxis(name: []const u8) AxisStateField {
        if (std.mem.eql(u8, name, "left_x")) return .ax;
        if (std.mem.eql(u8, name, "left_y")) return .ay;
        if (std.mem.eql(u8, name, "right_x")) return .rx;
        if (std.mem.eql(u8, name, "right_y")) return .ry;
        if (std.mem.eql(u8, name, "lt")) return .lt;
        if (std.mem.eql(u8, name, "rt")) return .rt;
        if (std.mem.eql(u8, name, "dpad_x")) return .dpad_x;
        if (std.mem.eql(u8, name, "dpad_y")) return .dpad_y;
        return .ax;
    }

    fn getAxisValue(s: state.GamepadState, field: AxisStateField) i32 {
        return switch (field) {
            .ax => s.ax,
            .ay => s.ay,
            .rx => s.rx,
            .ry => s.ry,
            .lt => s.lt,
            .rt => s.rt,
            .dpad_x => s.dpad_x,
            .dpad_y => s.dpad_y,
        };
    }

    pub fn outputDevice(self: *UinputDevice) OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = OutputDevice.VTable{
        .emit = emitVtable,
        .poll_ff = pollFfVtable,
        .close = closeVtable,
    };

    fn emitVtable(ptr: *anyopaque, s: state.GamepadState) anyerror!void {
        const self: *UinputDevice = @ptrCast(@alignCast(ptr));
        return self.emit(s);
    }

    fn pollFfVtable(ptr: *anyopaque) anyerror!?FfEvent {
        const self: *UinputDevice = @ptrCast(@alignCast(ptr));
        return self.pollFf();
    }

    fn closeVtable(ptr: *anyopaque) void {
        const self: *UinputDevice = @ptrCast(@alignCast(ptr));
        self.close();
    }

    pub fn emit(self: *UinputDevice, s: state.GamepadState) !void {
        var events: [MAX_EVENTS]c.input_event = undefined;
        var n: usize = 0;

        // ABS axes: differential
        for (0..self.axis_count) |i| {
            const curr_val = getAxisValue(s, self.axis_state_offsets[i]);
            const prev_val = getAxisValue(self.prev, self.axis_state_offsets[i]);
            if (curr_val != prev_val) {
                events[n] = .{ .type = c.EV_ABS, .code = self.axis_codes[i], .value = curr_val, .time = undefined };
                n += 1;
            }
        }

        // DPad hat: differential
        if (self.has_dpad_hat) {
            if (s.dpad_x != self.prev.dpad_x) {
                events[n] = .{ .type = c.EV_ABS, .code = c.ABS_HAT0X, .value = s.dpad_x, .time = undefined };
                n += 1;
            }
            if (s.dpad_y != self.prev.dpad_y) {
                events[n] = .{ .type = c.EV_ABS, .code = c.ABS_HAT0Y, .value = s.dpad_y, .time = undefined };
                n += 1;
            }
        }

        // Buttons: differential by bit
        const btn_fields = @typeInfo(state.ButtonId).@"enum".fields;
        inline for (btn_fields, 0..) |_, i| {
            const mask: u32 = @as(u32, 1) << i;
            const code = self.button_codes[i];
            if (code == 0) continue;
            const curr_pressed = (s.buttons & mask) != 0;
            const prev_pressed = (self.prev.buttons & mask) != 0;
            if (curr_pressed != prev_pressed) {
                events[n] = .{
                    .type = c.EV_KEY,
                    .code = code,
                    .value = if (curr_pressed) @as(i32, 1) else @as(i32, 0),
                    .time = undefined,
                };
                n += 1;
            }
        }

        if (n > 0) {
            events[n] = .{ .type = c.EV_SYN, .code = c.SYN_REPORT, .value = 0, .time = undefined };
            n += 1;
            _ = try std.posix.write(self.fd, std.mem.sliceAsBytes(events[0..n]));
        }

        self.prev = s;
    }

    pub fn pollFf(self: *UinputDevice) !?FfEvent {
        var ev: c.input_event = undefined;
        const nread = std.posix.read(self.fd, std.mem.asBytes(&ev)) catch |err| switch (err) {
            error.WouldBlock => return null,
            else => return err,
        };
        if (nread < @sizeOf(c.input_event)) return null;

        if (ev.type == c.EV_UINPUT) {
            if (ev.code == c.UI_FF_UPLOAD) {
                var upload = std.mem.zeroes(c.uinput_ff_upload);
                upload.request_id = @intCast(ev.value);
                _ = std.os.linux.ioctl(self.fd, UI_BEGIN_FF_UPLOAD, @intFromPtr(&upload));
                upload.retval = 0;
                _ = std.os.linux.ioctl(self.fd, UI_END_FF_UPLOAD, @intFromPtr(&upload));
            } else if (ev.code == c.UI_FF_ERASE) {
                var erase = std.mem.zeroes(c.uinput_ff_erase);
                erase.request_id = @intCast(ev.value);
                _ = std.os.linux.ioctl(self.fd, UI_BEGIN_FF_ERASE, @intFromPtr(&erase));
                erase.retval = 0;
                _ = std.os.linux.ioctl(self.fd, UI_END_FF_ERASE, @intFromPtr(&erase));
            }
            return null;
        }

        if (ev.type == c.EV_FF) {
            // Phase 1: return the event for future routing; strong/weak not available without effect store
            return FfEvent{ .effect_type = c.FF_RUMBLE, .strong = 0, .weak = 0 };
        }

        return null;
    }

    pub fn close(self: *UinputDevice) void {
        _ = std.os.linux.ioctl(self.fd, UI_DEV_DESTROY, 0);
        std.posix.close(self.fd);
    }
};

pub const AuxDevice = struct {
    fd: std.posix.fd_t,

    pub fn create(key_codes: []const u16) !AuxDevice {
        const flags = std.posix.O{ .ACCMODE = .WRONLY, .NONBLOCK = true };
        const fd = try std.posix.open("/dev/uinput", flags, 0);
        errdefer std.posix.close(fd);

        try ioctlInt(fd, UI_SET_EVBIT, c.EV_KEY);
        for (key_codes) |code| {
            try ioctlInt(fd, UI_SET_KEYBIT, @intCast(code));
        }

        var setup = std.mem.zeroes(c.uinput_setup);
        const name = "padctl-aux";
        @memcpy(setup.name[0..name.len], name);
        setup.id.bustype = c.BUS_VIRTUAL;
        try ioctlPtr(fd, UI_DEV_SETUP, @intFromPtr(&setup));
        try ioctlPtr(fd, UI_DEV_CREATE, 0);

        return .{ .fd = fd };
    }

    pub fn auxOutputDevice(self: *AuxDevice) AuxOutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = AuxOutputDevice.VTable{
        .emit_aux = emitAuxVtable,
        .close = closeVtable,
    };

    fn emitAuxVtable(ptr: *anyopaque, events: []const AuxEvent) anyerror!void {
        const self: *AuxDevice = @ptrCast(@alignCast(ptr));
        return self.emitAux(events);
    }

    fn closeVtable(ptr: *anyopaque) void {
        const self: *AuxDevice = @ptrCast(@alignCast(ptr));
        self.close();
    }

    pub fn emitAux(self: *AuxDevice, events: []const AuxEvent) !void {
        var buf: [MAX_EVENTS]c.input_event = undefined;
        var n: usize = 0;
        for (events) |ev| {
            switch (ev) {
                .key => |k| {
                    buf[n] = .{ .type = c.EV_KEY, .code = k.code, .value = if (k.pressed) @as(i32, 1) else 0, .time = undefined };
                    n += 1;
                },
                .mouse_button => |mb| {
                    buf[n] = .{ .type = c.EV_KEY, .code = mb.code, .value = if (mb.pressed) @as(i32, 1) else 0, .time = undefined };
                    n += 1;
                },
            }
        }
        if (n > 0) {
            buf[n] = .{ .type = c.EV_SYN, .code = c.SYN_REPORT, .value = 0, .time = undefined };
            n += 1;
            _ = try std.posix.write(self.fd, std.mem.sliceAsBytes(buf[0..n]));
        }
    }

    pub fn close(self: *AuxDevice) void {
        _ = std.os.linux.ioctl(self.fd, UI_DEV_DESTROY, 0);
        std.posix.close(self.fd);
    }
};

// --- tests ---

const MockOutputDevice = struct {
    emitted: std.ArrayList(state.GamepadState),
    prev: state.GamepadState = .{},

    fn init(allocator: std.mem.Allocator) MockOutputDevice {
        return .{ .emitted = std.ArrayList(state.GamepadState).init(allocator) };
    }

    fn deinit(self: *MockOutputDevice) void {
        self.emitted.deinit();
    }

    fn outputDevice(self: *MockOutputDevice) OutputDevice {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = OutputDevice.VTable{
        .emit = mockEmit,
        .poll_ff = mockPollFf,
        .close = mockClose,
    };

    fn mockEmit(ptr: *anyopaque, s: state.GamepadState) anyerror!void {
        const self: *MockOutputDevice = @ptrCast(@alignCast(ptr));
        // Only record if state changed (simulate differential)
        if (std.meta.eql(s, self.prev)) return;
        try self.emitted.append(s);
        self.prev = s;
    }

    fn mockPollFf(_: *anyopaque) anyerror!?FfEvent {
        return null;
    }

    fn mockClose(_: *anyopaque) void {}
};

test "ioctl constants match Linux kernel values" {
    // Linux: #define UI_SET_EVBIT _IOW('U', 100, int)  → type=0x55,nr=100,size=4 → 0x40045564
    // _IOW encodes: dir=1(write),type='U',nr,size
    // dir=1 << 30, type << 8, nr, size << 16
    const expected_evbit: u32 = (1 << 30) | (@as(u32, 'U') << 8) | 100 | (@as(u32, @sizeOf(c_int)) << 16);
    try std.testing.expectEqual(expected_evbit, UI_SET_EVBIT);

    const expected_keybit: u32 = (1 << 30) | (@as(u32, 'U') << 8) | 101 | (@as(u32, @sizeOf(c_int)) << 16);
    try std.testing.expectEqual(expected_keybit, UI_SET_KEYBIT);

    const expected_create: u32 = (@as(u32, 'U') << 8) | 1;
    try std.testing.expectEqual(expected_create, UI_DEV_CREATE);
}

test "emit: same state produces no events (via mock)" {
    const allocator = std.testing.allocator;
    var mock = MockOutputDevice.init(allocator);
    defer mock.deinit();
    const od = mock.outputDevice();

    const s = state.GamepadState{};
    try od.emit(s);
    try od.emit(s);
    try od.emit(s);

    try std.testing.expectEqual(@as(usize, 0), mock.emitted.items.len);
}

test "emit: state change recorded once" {
    const allocator = std.testing.allocator;
    var mock = MockOutputDevice.init(allocator);
    defer mock.deinit();
    const od = mock.outputDevice();

    const s0 = state.GamepadState{};
    var s1 = state.GamepadState{};
    s1.ax = 100;

    try od.emit(s0);
    try od.emit(s1);
    try od.emit(s1); // same, no new emit

    try std.testing.expectEqual(@as(usize, 1), mock.emitted.items.len);
    try std.testing.expectEqual(@as(i16, 100), mock.emitted.items[0].ax);
}

test "emit: button change recorded" {
    const allocator = std.testing.allocator;
    var mock = MockOutputDevice.init(allocator);
    defer mock.deinit();
    const od = mock.outputDevice();

    var s = state.GamepadState{};
    s.buttons = 1; // ButtonId.A pressed
    try od.emit(s);
    try std.testing.expectEqual(@as(usize, 1), mock.emitted.items.len);
    try std.testing.expectEqual(@as(u32, 1), mock.emitted.items[0].buttons);
}
