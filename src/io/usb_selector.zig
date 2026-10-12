const std = @import("std");
pub const c = @cImport({
    @cInclude("libusb-1.0/libusb.h");
});

pub const Resolved = struct { interface_id: u8, ep_in: u8, ep_out: u8 };
pub const SelectionError = error{ MissingAlternate, AmbiguousAlternate, InvalidEndpoint, MissingEndpoint, AmbiguousEndpoint };

pub fn addUnique(selected: *?Resolved, candidate: Resolved) error{AmbiguousUsbInterface}!void {
    if (selected.* != null) return error.AmbiguousUsbInterface;
    selected.* = candidate;
}

pub fn selectAny(config: c.libusb_config_descriptor, patterns: []const [3]u8, context: anytype, comptime read_active: anytype) !Resolved {
    var selected: ?Resolved = null;
    for (config.interface[0..config.bNumInterfaces]) |iface| {
        if (!mayMatchAny(iface, patterns)) continue;
        const number = iface.altsetting[0].bInterfaceNumber;
        for (iface.altsetting[0..@intCast(iface.num_altsetting)]) |alt|
            if (alt.bInterfaceNumber != number) return error.UsbDescriptorUnavailable;
        var active = iface.altsetting[0].bAlternateSetting;
        if (iface.num_altsetting > 1 or active != 0) active = try read_active(context, number);
        if (try resolveAny(iface, active, patterns)) |candidate| try addUnique(&selected, candidate);
    }
    return selected orelse error.UsbInterfaceNotFound;
}

test "USB selector: full descriptor traversal rejects zero and multiple active matches" {
    const Query = struct {
        fn read(_: void, _: u8) !u8 {
            return error.QueryFailed;
        }
    };
    var eps = [_]c.libusb_endpoint_descriptor{ std.mem.zeroes(c.libusb_endpoint_descriptor), std.mem.zeroes(c.libusb_endpoint_descriptor) };
    eps[0].bEndpointAddress = 0x85;
    eps[1].bEndpointAddress = 6;
    for (&eps) |*ep| {
        ep.bmAttributes = 3;
        ep.wMaxPacketSize = 64;
    }
    var alts = [_]c.libusb_interface_descriptor{std.mem.zeroes(c.libusb_interface_descriptor)} ** 2;
    for (&alts, 0..) |*alt, index| {
        alt.bInterfaceClass = 255;
        alt.bInterfaceSubClass = 93;
        alt.bInterfaceProtocol = 1;
        alt.bInterfaceNumber = @intCast(index + 7);
        alt.bNumEndpoints = 2;
        alt.endpoint = &eps;
    }
    var ifaces = [_]c.libusb_interface{ .{ .altsetting = &alts[0], .num_altsetting = 1 }, .{ .altsetting = &alts[1], .num_altsetting = 1 } };
    var cfg = std.mem.zeroes(c.libusb_config_descriptor);
    cfg.interface = &ifaces;
    const match = [3]u8{ 255, 93, 1 };
    try std.testing.expectError(error.UsbInterfaceNotFound, selectAny(cfg, &.{match}, {}, Query.read));
    cfg.bNumInterfaces = 1;
    try std.testing.expectEqual(@as(u8, 7), (try selectAny(cfg, &.{match}, {}, Query.read)).interface_id);
    cfg.bNumInterfaces = 2;
    try std.testing.expectError(error.AmbiguousUsbInterface, selectAny(cfg, &.{match}, {}, Query.read));
    cfg.bNumInterfaces = 1;
    alts[0].bAlternateSetting = 3;
    try std.testing.expectError(error.QueryFailed, selectAny(cfg, &.{match}, {}, Query.read));
    alts[0].bInterfaceProtocol = 2;
    try std.testing.expectError(error.UsbInterfaceNotFound, selectAny(cfg, &.{match}, {}, Query.read));
}

test "USB selector: multiple eligible physical interfaces fail closed" {
    var selected: ?Resolved = null;
    try addUnique(&selected, .{ .interface_id = 7, .ep_in = 0x85, .ep_out = 6 });
    try std.testing.expectError(error.AmbiguousUsbInterface, addUnique(&selected, .{ .interface_id = 9, .ep_in = 0x81, .ep_out = 2 }));
}

test "USB selector: exact binding alternatives count each physical interface once" {
    const Query = struct {
        fn read(active: u8, _: u8) !u8 {
            return active;
        }
    };
    const patterns = [_][3]u8{ .{ 255, 93, 1 }, .{ 255, 93, 129 }, .{ 255, 71, 208 } };
    var eps = [_]c.libusb_endpoint_descriptor{std.mem.zeroes(c.libusb_endpoint_descriptor)} ** 2;
    eps[0].bEndpointAddress = 0x85;
    eps[1].bEndpointAddress = 6;
    for (&eps) |*ep| {
        ep.bmAttributes = 3;
        ep.wMaxPacketSize = 64;
    }
    var alts = [_]c.libusb_interface_descriptor{std.mem.zeroes(c.libusb_interface_descriptor)} ** 2;
    for (&alts, 0..) |*alt, index| {
        alt.bInterfaceNumber = 7;
        alt.bAlternateSetting = @intCast(index);
        alt.bInterfaceClass = patterns[index][0];
        alt.bInterfaceSubClass = patterns[index][1];
        alt.bInterfaceProtocol = patterns[index][2];
        alt.endpoint = &eps;
        alt.bNumEndpoints = 2;
    }
    var iface = c.libusb_interface{ .altsetting = &alts, .num_altsetting = 2 };
    var cfg = std.mem.zeroes(c.libusb_config_descriptor);
    cfg.interface = &iface;
    cfg.bNumInterfaces = 1;
    for (0..2) |active| try std.testing.expectEqual(@as(u8, 7), (try selectAny(cfg, &patterns, @as(u8, @intCast(active)), Query.read)).interface_id);
    const overlap = [_][3]u8{ patterns[0], patterns[0], patterns[1] };
    try std.testing.expectEqual(@as(u8, 7), (try selectAny(cfg, &overlap, @as(u8, 0), Query.read)).interface_id);
    iface.num_altsetting = 1;
    for (patterns) |pattern| {
        alts[0].bInterfaceClass = pattern[0];
        alts[0].bInterfaceSubClass = pattern[1];
        alts[0].bInterfaceProtocol = pattern[2];
        try std.testing.expectEqual(@as(u8, 7), (try selectAny(cfg, &patterns, @as(u8, 0), Query.read)).interface_id);
    }
    alts[0].bInterfaceSubClass = 3;
    try std.testing.expectError(error.UsbInterfaceNotFound, selectAny(cfg, &patterns, @as(u8, 0), Query.read));
    alts[0].bInterfaceSubClass = 71;
    var second = alts[0];
    second.bInterfaceNumber = 9;
    const ifaces = [_]c.libusb_interface{ iface, .{ .altsetting = &second, .num_altsetting = 1 } };
    cfg.interface = &ifaces;
    cfg.bNumInterfaces = 2;
    try std.testing.expectError(error.AmbiguousUsbInterface, selectAny(cfg, &patterns, @as(u8, 0), Query.read));
}

fn matches(alt: c.libusb_interface_descriptor, match: [3]u8) bool {
    return alt.bInterfaceClass == match[0] and alt.bInterfaceSubClass == match[1] and alt.bInterfaceProtocol == match[2];
}

fn matchesAny(alt: c.libusb_interface_descriptor, patterns: []const [3]u8) bool {
    for (patterns) |pattern| if (matches(alt, pattern)) return true;
    return false;
}

pub fn mayMatchAny(iface: c.libusb_interface, patterns: []const [3]u8) bool {
    if (iface.num_altsetting <= 0) return false;
    for (iface.altsetting[0..@intCast(iface.num_altsetting)]) |alt| if (matchesAny(alt, patterns)) return true;
    return false;
}

/// Inspect only the active alternate. Fixtures and the live descriptor path use
/// the same endpoint validation, independent of physical endpoint numbering.
pub fn resolveAny(iface: c.libusb_interface, active: u8, patterns: []const [3]u8) SelectionError!?Resolved {
    if (iface.num_altsetting <= 0) return error.MissingAlternate;
    var selected: ?c.libusb_interface_descriptor = null;
    for (iface.altsetting[0..@intCast(iface.num_altsetting)]) |alt| {
        if (alt.bAlternateSetting != active) continue;
        if (selected != null) return error.AmbiguousAlternate;
        selected = alt;
    }
    const alt = selected orelse return error.MissingAlternate;
    if (!matchesAny(alt, patterns)) return null;
    var ep_in: ?u8 = null;
    var ep_out: ?u8 = null;
    for (alt.endpoint[0..alt.bNumEndpoints]) |ep| {
        if ((ep.bmAttributes & 3) != 3) continue;
        if ((ep.bEndpointAddress & 0x70) != 0 or (ep.bEndpointAddress & 0x0f) == 0 or
            (ep.wMaxPacketSize & 0x7ff) == 0) return error.InvalidEndpoint;
        if ((ep.bEndpointAddress & 0x80) != 0) {
            if (ep_in != null) return error.AmbiguousEndpoint;
            ep_in = ep.bEndpointAddress;
        } else {
            if (ep_out != null) return error.AmbiguousEndpoint;
            ep_out = ep.bEndpointAddress;
        }
    }
    return .{ .interface_id = alt.bInterfaceNumber, .ep_in = ep_in orelse return error.MissingEndpoint, .ep_out = ep_out orelse return error.MissingEndpoint };
}

test "USB selector: active alternate and arbitrary endpoint addresses" {
    var eps = [_]c.libusb_endpoint_descriptor{ std.mem.zeroes(c.libusb_endpoint_descriptor), std.mem.zeroes(c.libusb_endpoint_descriptor) };
    eps[0].bEndpointAddress = 0x85;
    eps[1].bEndpointAddress = 0x06;
    for (&eps) |*ep| {
        ep.bmAttributes = 3;
        ep.wMaxPacketSize = 64;
    }
    var alts = [_]c.libusb_interface_descriptor{ std.mem.zeroes(c.libusb_interface_descriptor), std.mem.zeroes(c.libusb_interface_descriptor) };
    alts[0].bInterfaceClass = 255;
    alts[0].bInterfaceSubClass = 93;
    alts[0].bInterfaceProtocol = 1;
    alts[0].bInterfaceNumber = 7;
    alts[0].bNumEndpoints = 2;
    alts[0].endpoint = &eps;
    alts[1] = alts[0];
    alts[1].bAlternateSetting = 1;
    alts[1].bInterfaceProtocol = 2;
    const iface = c.libusb_interface{ .altsetting = &alts, .num_altsetting = 2 };
    const match = [3]u8{ 255, 93, 1 };
    try std.testing.expect(mayMatchAny(iface, &.{match}));
    try std.testing.expectEqual(Resolved{ .interface_id = 7, .ep_in = 0x85, .ep_out = 6 }, (try resolveAny(iface, 0, &.{match})).?);
    try std.testing.expectEqual(@as(?Resolved, null), try resolveAny(iface, 1, &.{match}));
    try std.testing.expectError(error.MissingAlternate, resolveAny(iface, 2, &.{match}));
    alts[1].bAlternateSetting = 0;
    try std.testing.expectError(error.AmbiguousAlternate, resolveAny(iface, 0, &.{match}));
}

test "USB selector: missing, ambiguous and malformed interrupt endpoints fail closed" {
    var eps = [_]c.libusb_endpoint_descriptor{ std.mem.zeroes(c.libusb_endpoint_descriptor), std.mem.zeroes(c.libusb_endpoint_descriptor) };
    eps[0].bEndpointAddress = 0x81;
    eps[1].bEndpointAddress = 0x02;
    for (&eps) |*ep| {
        ep.bmAttributes = 3;
        ep.wMaxPacketSize = 64;
    }
    var alt = std.mem.zeroes(c.libusb_interface_descriptor);
    alt.bInterfaceClass = 255;
    alt.bInterfaceSubClass = 93;
    alt.bInterfaceProtocol = 1;
    alt.bNumEndpoints = 2;
    alt.endpoint = &eps;
    const iface = c.libusb_interface{ .altsetting = &alt, .num_altsetting = 1 };
    const match = [3]u8{ 255, 93, 1 };
    eps[1].bmAttributes = 2;
    try std.testing.expectError(error.MissingEndpoint, resolveAny(iface, 0, &.{match}));
    eps[1].bmAttributes = 3;
    eps[1].bEndpointAddress = 0x82;
    try std.testing.expectError(error.AmbiguousEndpoint, resolveAny(iface, 0, &.{match}));
    eps[1].bEndpointAddress = 0;
    try std.testing.expectError(error.InvalidEndpoint, resolveAny(iface, 0, &.{match}));
    eps[1].bEndpointAddress = 0x72;
    try std.testing.expectError(error.InvalidEndpoint, resolveAny(iface, 0, &.{match}));
    eps[1].bEndpointAddress = 2;
    eps[1].wMaxPacketSize = 0;
    try std.testing.expectError(error.InvalidEndpoint, resolveAny(iface, 0, &.{match}));
}
