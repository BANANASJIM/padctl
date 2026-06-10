//! Layer 0 tests guarding the libusb build capability against shipped configs.
//!
//! Two lanes:
//!   real-libusb (-Dlibusb=true, default): a vendored libusb context inits, and
//!     every in-repo device config loads.
//!   stub (-Dlibusb=false): UsbrawDevice.open fails fast with LibusbUnavailable,
//!     that error is non-transient, and exactly the known config set needs libusb.

const std = @import("std");
const testing = std.testing;

const usbraw = @import("../io/usbraw.zig");
const supervisor = @import("../supervisor.zig");
const device_mod = @import("../config/device.zig");
const helpers = @import("helpers.zig");

// Configs known to require libusb. Drift here surfaces a shipped-config vs
// build-capability mismatch instead of a silent runtime failure.
const libusb_configs = [_][]const u8{"vader5.toml"};

fn basename(path: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |i| return path[i + 1 ..];
    return path;
}

fn isKnownLibusbConfig(path: []const u8) bool {
    const name = basename(path);
    for (libusb_configs) |known| {
        if (std.mem.eql(u8, name, known)) return true;
    }
    return false;
}

test "libusb: vendored context init reaches real backend in real-libusb lane" {
    if (!usbraw.have_libusb) return error.SkipZigTest;
    const c = @cImport({
        @cInclude("libusb-1.0/libusb.h");
    });
    var ctx: ?*c.libusb_context = null;
    const rc = c.libusb_init(&ctx);
    // Real libusb returns 0 when usbfs (/dev/bus/usb) is present, or
    // LIBUSB_ERROR_OTHER when it is absent (headless containers). The stub
    // unconditionally returns LIBUSB_ERROR_IO; either real outcome proves the
    // vendored library is linked and running its Linux backend.
    try testing.expect(rc == 0 or rc == c.LIBUSB_ERROR_OTHER);
    if (rc == 0) c.libusb_exit(ctx);
}

test "libusb: stub UsbrawDevice.open returns LibusbUnavailable" {
    if (usbraw.have_libusb) return error.SkipZigTest;
    const result = usbraw.UsbrawDevice.open(testing.allocator, 0x1234, 0x5678, 0, 0x81, 0x01);
    try testing.expectError(error.LibusbUnavailable, result);
}

test "libusb: stub openSuppress returns LibusbUnavailable" {
    if (usbraw.have_libusb) return error.SkipZigTest;
    const result = usbraw.UsbrawSuppress.openSuppress(testing.allocator, 0x1234, 0x5678, 0);
    try testing.expectError(error.LibusbUnavailable, result);
}

test "libusb: LibusbUnavailable is not a transient open error" {
    try testing.expect(!supervisor.Supervisor.isTransientOpenError(error.LibusbUnavailable));
}

test "libusb: shipped configs load under real libusb" {
    if (!usbraw.have_libusb) return error.SkipZigTest;
    var paths = try helpers.collectTomlPaths(testing.allocator);
    defer paths.deinit(testing.allocator);
    if (paths.items.len == 0) return error.SkipZigTest;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(testing.allocator, path) catch |err| {
            std.debug.print("config failed to load: {s}: {}\n", .{ path, err });
            return err;
        };
        parsed.deinit();
    }
}

test "libusb: shipped libusb-needing configs match the known set" {
    var paths = try helpers.collectTomlPaths(testing.allocator);
    defer paths.deinit(testing.allocator);
    if (paths.items.len == 0) return error.SkipZigTest;

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(testing.allocator, path) catch continue;
        defer parsed.deinit();
        if (device_mod.usesLibusb(&parsed.value)) {
            try testing.expect(isKnownLibusbConfig(path));
        }
    }
}
