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

/// Dynamic-size ioctl: caller picks the user buffer length. Kernel copies
/// up to `len` bytes of the `uniq` sysfs attribute (NUL-terminated) into it.
pub fn HIDIOCGRAWUNIQ(len: u16) u32 {
    const req = IOCTL.Request{ .dir = 2, .io_type = 'H', .nr = 0x08, .size = len };
    return @bitCast(req);
}

// evdev
pub const EVIOCGRAB = IOCTL.IOW('E', 0x90, c_int);

/// Dynamic-size evdev ioctl: kernel copies up to `len` bytes of the device's
/// uniq attribute (NUL-terminated) into the user buffer. SDL reads this to
/// pair main-pad and IMU nodes — see ADR-015 §Stage 1 AC.
pub fn EVIOCGUNIQ(len: u16) u32 {
    const req = IOCTL.Request{ .dir = 2, .io_type = 'E', .nr = 0x08, .size = len };
    return @bitCast(req);
}

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
pub const UI_SET_PROPBIT = IOCTL.IOW('U', 110, c_int);
pub const UI_BEGIN_FF_UPLOAD = IOCTL.IOWR('U', 200, c.uinput_ff_upload);
pub const UI_END_FF_UPLOAD = IOCTL.IOW('U', 201, c.uinput_ff_upload);
pub const UI_BEGIN_FF_ERASE = IOCTL.IOWR('U', 202, c.uinput_ff_erase);
pub const UI_END_FF_ERASE = IOCTL.IOW('U', 203, c.uinput_ff_erase);

pub const HidrawDevinfo = c.hidraw_devinfo;

// eventfd
pub const EFD_CLOEXEC: u32 = 0o2000000;
pub const EFD_NONBLOCK: u32 = 0o4000;
