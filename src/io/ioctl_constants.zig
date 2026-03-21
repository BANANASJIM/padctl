const std = @import("std");
const c = @cImport({
    @cInclude("linux/hidraw.h");
    @cInclude("linux/uinput.h");
    @cInclude("linux/input.h");
});
const IOCTL = std.os.linux.IOCTL;

// hidraw
pub const HIDIOCGRAWINFO = IOCTL.IOR('H', 0x03, c.hidraw_devinfo);
pub const HIDIOCGRAWPHYS = blk: {
    const req = IOCTL.Request{ .dir = 2, .io_type = 'H', .nr = 0x05, .size = 256 };
    break :blk @as(u32, @bitCast(req));
};

// evdev
pub const EVIOCGRAB = IOCTL.IOW('E', 0x90, c_int);

// uinput
pub const UI_DEV_CREATE = IOCTL.IO('U', 1);
pub const UI_DEV_DESTROY = IOCTL.IO('U', 2);
pub const UI_DEV_SETUP = IOCTL.IOW('U', 3, c.uinput_setup);
pub const UI_ABS_SETUP = IOCTL.IOW('U', 4, c.uinput_abs_setup);
pub const UI_SET_EVBIT = IOCTL.IOW('U', 100, c_int);
pub const UI_SET_KEYBIT = IOCTL.IOW('U', 101, c_int);
pub const UI_SET_RELBIT = IOCTL.IOW('U', 102, c_int);
pub const UI_SET_ABSBIT = IOCTL.IOW('U', 103, c_int);
pub const UI_SET_FFBIT = IOCTL.IOW('U', 107, c_int);
pub const UI_BEGIN_FF_UPLOAD = IOCTL.IOWR('U', 200, c.uinput_ff_upload);
pub const UI_END_FF_UPLOAD = IOCTL.IOW('U', 201, c.uinput_ff_upload);
pub const UI_BEGIN_FF_ERASE = IOCTL.IOWR('U', 202, c.uinput_ff_erase);
pub const UI_END_FF_ERASE = IOCTL.IOW('U', 203, c.uinput_ff_erase);

pub const HidrawDevinfo = c.hidraw_devinfo;
