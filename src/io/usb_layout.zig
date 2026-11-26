//! USB interface/endpoint layout of a physical device, read from sysfs, and
//! selection among device configs that share a VID/PID (ADR-029).
//!
//! Firmware revisions can move endpoints between interfaces without changing
//! VID/PID or bcdDevice, so the layout itself is what decides which config
//! can bind.

const std = @import("std");
const config_device = @import("../config/device.zig");
const DeviceConfig = config_device.DeviceConfig;
const InterfaceConfig = config_device.InterfaceConfig;

pub const max_interfaces = 32;
pub const max_endpoints = 16;

const desc_config = 2;
const desc_interface = 4;
const desc_endpoint = 5;
const device_descriptor_len = 18;
const usb_class_hid = 3;

pub const Interface = struct {
    number: u8,
    class: u8,
    endpoint_buf: [max_endpoints]u8 = undefined,
    endpoint_count: u8 = 0,

    pub fn endpoints(self: *const Interface) []const u8 {
        return self.endpoint_buf[0..self.endpoint_count];
    }

    fn hasEndpoint(self: *const Interface, ep: u8) bool {
        return std.mem.indexOfScalar(u8, self.endpoints(), ep) != null;
    }
};

pub const UsbLayout = struct {
    interface_buf: [max_interfaces]Interface = undefined,
    interface_count: usize = 0,

    pub fn interfaces(self: *const UsbLayout) []const Interface {
        return self.interface_buf[0..self.interface_count];
    }

    pub fn find(self: *const UsbLayout, number: u8) ?*const Interface {
        for (self.interfaces()) |*i| {
            if (i.number == number) return i;
        }
        return null;
    }

    /// One line, e.g. "IF0 ff [81 05], IF1 03 [82]": the interface number, its
    /// class and endpoint addresses, enough to rewrite a device config.
    pub fn format(self: *const UsbLayout, writer: anytype) !void {
        for (self.interfaces(), 0..) |*i, n| {
            if (n > 0) try writer.writeAll(", ");
            try writer.print("IF{d} {x:0>2} [", .{ i.number, i.class });
            for (i.endpoints(), 0..) |ep, k| {
                if (k > 0) try writer.writeByte(' ');
                try writer.print("{x:0>2}", .{ep});
            }
            try writer.writeByte(']');
        }
    }

    fn endpointOwner(self: *const UsbLayout, ep: u8) ?u8 {
        for (self.interfaces()) |*i| {
            if (i.hasEndpoint(ep)) return i.number;
        }
        return null;
    }
};

/// Parse the sysfs `descriptors` blob: the device descriptor followed by every
/// configuration's full descriptor set. Only the active configuration and each
/// interface's altsetting 0 are kept, matching what usbraw claims. Returns null
/// for malformed data or when the active configuration is absent.
pub fn parse(bytes: []const u8, active_config: u8) ?UsbLayout {
    if (active_config == 0 or bytes.len < device_descriptor_len) return null;
    var layout = UsbLayout{};
    var in_active = false;
    var found_active = false;
    var current: ?*Interface = null;

    var i: usize = device_descriptor_len;
    while (i < bytes.len) {
        if (bytes.len - i < 2) return null;
        const len = bytes[i];
        if (len < 2 or len > bytes.len - i) return null;
        const d = bytes[i .. i + len];
        switch (d[1]) {
            desc_config => {
                if (len < 6) return null;
                in_active = d[5] == active_config;
                if (in_active) found_active = true;
                current = null;
            },
            desc_interface => {
                if (len < 9) return null;
                current = null;
                // Endpoints of a non-zero altsetting must not be attributed to
                // the preceding altsetting 0.
                if (in_active and d[3] == 0 and layout.find(d[2]) == null and layout.interface_count < max_interfaces) {
                    layout.interface_buf[layout.interface_count] = .{ .number = d[2], .class = d[5] };
                    current = &layout.interface_buf[layout.interface_count];
                    layout.interface_count += 1;
                }
            },
            desc_endpoint => {
                if (len < 7) return null;
                if (current) |cur| {
                    if (cur.endpoint_count < max_endpoints) {
                        cur.endpoint_buf[cur.endpoint_count] = d[2];
                        cur.endpoint_count += 1;
                    }
                }
            },
            else => {},
        }
        i += len;
    }
    if (!found_active) return null;
    return layout;
}

/// Read the layout of the USB device owning a hidraw node. `devname` is the
/// node basename (e.g. "hidraw3"). Returns null when sysfs is unavailable,
/// e.g. for non-USB transports; callers then fall back to the first config.
pub fn readForHidraw(sys_root: []const u8, devname: []const u8) ?UsbLayout {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    // hidrawN/device is the HID device, its parent the USB interface, and the
    // grandparent the USB device that carries `descriptors`.
    const usb_dir = std.fmt.bufPrint(&path_buf, "{s}/class/hidraw/{s}/device/../..", .{ sys_root, devname }) catch return null;
    return readFromUsbDeviceDir(usb_dir);
}

/// Read the layout of a USB device directory such as /sys/bus/usb/devices/1-4.
pub fn readFromUsbDeviceDir(usb_dir: []const u8) ?UsbLayout {
    var dir = std.fs.openDirAbsolute(usb_dir, .{}) catch return null;
    defer dir.close();

    var cfg_buf: [8]u8 = undefined;
    const cfg_text = dir.readFile("bConfigurationValue", &cfg_buf) catch return null;
    const active = std.fmt.parseInt(u8, std.mem.trim(u8, cfg_text, " \t\r\n"), 10) catch return null;

    var desc_buf: [16 * 1024]u8 = undefined;
    const desc = dir.readFile("descriptors", &desc_buf) catch return null;
    // A full buffer may have cut the blob on a descriptor boundary, which would
    // parse as a partial layout; treat it as unreadable instead.
    if (desc.len == desc_buf.len) return null;
    return parse(desc, active);
}

pub const Mismatch = union(enum) {
    missing_interface: u8,
    not_hid: u8,
    endpoint_on_other_interface: struct { ep: u8, interface: u8, owner: u8 },
    endpoint_absent: struct { ep: u8, interface: u8 },

    pub fn format(self: Mismatch, writer: anytype) !void {
        switch (self) {
            .missing_interface => |n| try writer.print("interface {d} does not exist", .{n}),
            .not_hid => |n| try writer.print("interface {d} is not a HID interface", .{n}),
            .endpoint_on_other_interface => |m| try writer.print(
                "endpoint 0x{x:0>2} is on interface {d}, not {d}",
                .{ m.ep, m.owner, m.interface },
            ),
            .endpoint_absent => |m| try writer.print(
                "endpoint 0x{x:0>2} (interface {d}) does not exist",
                .{ m.ep, m.interface },
            ),
        }
    }
};

/// Check the layout a config declares against the device. Only fields the
/// config already carries are used; no extra DSL.
pub fn check(ifaces: []const InterfaceConfig, layout: *const UsbLayout) ?Mismatch {
    for (ifaces) |ic| {
        const number: u8 = std.math.cast(u8, ic.id) orelse return .{ .missing_interface = 0xff };
        const actual = layout.find(number) orelse return .{ .missing_interface = number };
        if (std.mem.eql(u8, ic.class, "hid")) {
            if (actual.class != usb_class_hid) return .{ .not_hid = number };
        } else if (std.mem.eql(u8, ic.class, "vendor")) {
            for ([_]?i64{ ic.ep_in, ic.ep_out }) |maybe_ep| {
                const ep: u8 = std.math.cast(u8, maybe_ep orelse continue) orelse
                    return .{ .endpoint_absent = .{ .ep = 0xff, .interface = number } };
                if (actual.hasEndpoint(ep)) continue;
                if (layout.endpointOwner(ep)) |owner| {
                    return .{ .endpoint_on_other_interface = .{ .ep = ep, .interface = number, .owner = owner } };
                }
                return .{ .endpoint_absent = .{ .ep = ep, .interface = number } };
            }
        }
        // suppress (and any other class) only needs the interface to exist.
    }
    return null;
}

pub const Candidate = struct {
    cfg: *const DeviceConfig,
    /// Source file, for diagnostics only.
    path: []const u8,
    /// A user/system file standing in for a builtin; skipping it is worth a
    /// warning, skipping a builtin variant is routine.
    is_override: bool = false,
};

/// Pick the config for one physical device. `candidates` share its VID/PID and
/// are in priority order (user > system > builtin). Without a layout the first
/// candidate wins, as before ADR-029. With one, the first candidate whose
/// declared layout matches wins. Returns null when none match.
pub fn select(candidates: []const Candidate, layout: ?*const UsbLayout) ?usize {
    if (candidates.len == 0) return null;
    const l = layout orelse return 0;
    for (candidates, 0..) |c, idx| {
        if (check(c.cfg.device.interface, l) == null) return idx;
    }
    return null;
}

/// Indices of every candidate whose declared layout matches, in order.
pub fn matching(candidates: []const Candidate, layout: *const UsbLayout, out: []usize) []usize {
    var n: usize = 0;
    for (candidates, 0..) |c, idx| {
        if (n == out.len) break;
        if (check(c.cfg.device.interface, layout) == null) {
            out[n] = idx;
            n += 1;
        }
    }
    return out[0..n];
}

/// The model query to run when several candidates match the same layout: the
/// first matched candidate that declares one (ADR-030).
pub fn probeFor(candidates: []const Candidate, matched: []const usize) ?*const config_device.ProbeConfig {
    if (matched.len < 2) return null;
    for (matched) |idx| {
        if (candidates[idx].cfg.device.probe) |*p| return p;
    }
    return null;
}

pub const ModelChoice = union(enum) {
    /// A candidate lists this model ID.
    listed: usize,
    /// A user/system override without `ids` ahead of any listing candidate.
    override: usize,
    /// The model was identified but no candidate lists it; first match is a guess.
    unlisted: usize,
    /// No model ID; first match is a guess.
    unidentified: usize,
};

/// Choose among layout-matched candidates by the probed model ID. A user or
/// system override without `ids` keeps its priority (ADR-029): it was written
/// for this device before probing existed, so it wins over listed builtins.
pub fn chooseByModel(candidates: []const Candidate, matched: []const usize, id: ?u8) ModelChoice {
    std.debug.assert(matched.len > 0);
    const model = id orelse return .{ .unidentified = matched[0] };
    for (matched) |idx| {
        const c = candidates[idx];
        const ids: []const i64 = if (c.cfg.device.probe) |p| p.ids else &.{};
        if (ids.len == 0) {
            if (c.is_override) return .{ .override = idx };
            continue;
        }
        for (ids) |listed| {
            if (listed == model) return .{ .listed = idx };
        }
    }
    return .{ .unlisted = matched[0] };
}

/// Explain a `select` result. Skipped user/system overrides and a failed
/// match are warnings and name every candidate's mismatch plus the actual
/// layout, so a report can be fixed without asking for `lsusb`.
pub fn logSelection(
    vid: u16,
    pid: u16,
    candidates: []const Candidate,
    layout: ?*const UsbLayout,
    selected: ?usize,
) void {
    const l = layout orelse {
        if (candidates.len > 1) std.log.info(
            "{x:0>4}:{x:0>4}: USB layout unreadable; using the first of {d} configs, {s}",
            .{ vid, pid, candidates.len, candidates[0].path },
        );
        return;
    };
    const idx = selected orelse {
        std.log.warn(
            "{x:0>4}:{x:0>4}: no device config matches this device's USB layout: {f}. The firmware likely differs from every config:",
            .{ vid, pid, l },
        );
        for (candidates) |c| {
            const m = check(c.cfg.device.interface, l) orelse continue;
            std.log.warn("  {s}: {f}", .{ c.path, m });
        }
        return;
    };
    for (candidates[0..idx]) |c| {
        const m = check(c.cfg.device.interface, l) orelse continue;
        if (c.is_override) {
            std.log.warn("{x:0>4}:{x:0>4}: skipping {s}: {f}", .{ vid, pid, c.path, m });
        } else {
            std.log.debug("{x:0>4}:{x:0>4}: skipping {s}: {f}", .{ vid, pid, c.path, m });
        }
    }
    if (candidates.len > 1) std.log.info(
        "{x:0>4}:{x:0>4}: using {s} (matches USB layout {f})",
        .{ vid, pid, candidates[idx].path, l },
    );
}

// --- tests ---

const testing = std.testing;

fn devDesc() [device_descriptor_len]u8 {
    var d = [_]u8{0} ** device_descriptor_len;
    d[0] = device_descriptor_len;
    d[1] = 1;
    return d;
}

fn cfgDesc(value: u8) [9]u8 {
    return .{ 9, desc_config, 0, 0, 0, value, 0, 0x80, 250 };
}

fn ifDesc(number: u8, alt: u8, class: u8) [9]u8 {
    return .{ 9, desc_interface, number, alt, 0, class, 0, 0, 0 };
}

fn epDesc(addr: u8) [7]u8 {
    return .{ 7, desc_endpoint, addr, 3, 0x20, 0, 1 };
}

fn hidDesc() [9]u8 {
    return .{ 9, 0x21, 0x11, 0x01, 0, 1, 0x22, 0x22, 0 };
}

/// Descriptor fixtures shared with supervisor/doctor tests.
pub const fixtures = struct {
    /// Vader 5 Pro, current firmware, from the `lsusb -v -d 37d7:2401` in #526.
    pub const vader5_new_firmware = devDesc() ++ cfgDesc(1) ++
        ifDesc(0, 0, 0xff) ++ epDesc(0x81) ++ epDesc(0x05) ++
        ifDesc(1, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x82) ++
        ifDesc(2, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x83) ++ epDesc(0x06) ++
        ifDesc(3, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x84);

    /// Vader 5 Pro, earlier firmware, as described by devices/flydigi/vader5.toml.
    pub const vader5_old_firmware = devDesc() ++ cfgDesc(1) ++
        ifDesc(0, 0, 0xff) ++ epDesc(0x81) ++ epDesc(0x05) ++
        ifDesc(1, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x82) ++ epDesc(0x06) ++
        ifDesc(2, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x83) ++
        ifDesc(3, 0, usb_class_hid) ++ hidDesc() ++ epDesc(0x84);

    /// Lay out `{root}/class/hidraw/{devname}` → `{root}/devices/{bus_id}` the way
    /// sysfs does, with `descriptors` on the USB device.
    pub fn writeSysfs(dir: std.fs.Dir, devname: []const u8, bus_id: []const u8, descriptors: []const u8) !void {
        var buf: [256]u8 = undefined;
        const hid_dev = try std.fmt.bufPrint(&buf, "devices/{s}/{s}:1.0/0003:0000:0000.0001", .{ bus_id, bus_id });
        try dir.makePath(hid_dev);
        var cbuf: [64]u8 = undefined;
        const class_dir = try std.fmt.bufPrint(&cbuf, "class/hidraw/{s}", .{devname});
        try dir.makePath(class_dir);
        var lbuf: [256]u8 = undefined;
        const link = try std.fmt.bufPrint(&lbuf, "{s}/device", .{class_dir});
        var tbuf: [256]u8 = undefined;
        const target = try std.fmt.bufPrint(&tbuf, "../../../{s}", .{hid_dev});
        try dir.symLink(target, link, .{ .is_directory = true });
        var dbuf: [256]u8 = undefined;
        try dir.writeFile(.{ .sub_path = try std.fmt.bufPrint(&dbuf, "devices/{s}/descriptors", .{bus_id}), .data = descriptors });
        try dir.writeFile(.{ .sub_path = try std.fmt.bufPrint(&dbuf, "devices/{s}/bConfigurationValue", .{bus_id}), .data = "1\n" });
    }
};

fn vader5NewFirmware() []const u8 {
    return &fixtures.vader5_new_firmware;
}

fn vader5OldFirmware() []const u8 {
    return &fixtures.vader5_old_firmware;
}

test "usb_layout: parse Vader 5 new-firmware layout" {
    const l = parse(vader5NewFirmware(), 1) orelse return error.ParseFailed;
    try testing.expectEqual(@as(usize, 4), l.interfaces().len);
    try testing.expectEqualSlices(u8, &.{ 0x81, 0x05 }, l.find(0).?.endpoints());
    try testing.expectEqualSlices(u8, &.{0x82}, l.find(1).?.endpoints());
    try testing.expectEqualSlices(u8, &.{ 0x83, 0x06 }, l.find(2).?.endpoints());
    try testing.expectEqual(@as(u8, 0xff), l.find(0).?.class);
    try testing.expectEqual(@as(u8, usb_class_hid), l.find(3).?.class);
}

test "usb_layout: only the active configuration is kept" {
    const bytes = devDesc() ++ cfgDesc(1) ++ ifDesc(0, 0, 3) ++ epDesc(0x81) ++
        cfgDesc(2) ++ ifDesc(0, 0, 0xff) ++ epDesc(0x82) ++ ifDesc(1, 0, 0xff);
    const l1 = parse(&bytes, 1) orelse return error.ParseFailed;
    try testing.expectEqual(@as(usize, 1), l1.interfaces().len);
    try testing.expectEqualSlices(u8, &.{0x81}, l1.find(0).?.endpoints());
    const l2 = parse(&bytes, 2) orelse return error.ParseFailed;
    try testing.expectEqual(@as(usize, 2), l2.interfaces().len);
    try testing.expectEqualSlices(u8, &.{0x82}, l2.find(0).?.endpoints());
    try testing.expect(parse(&bytes, 3) == null);
}

test "usb_layout: alternate-setting endpoints are not attributed to altsetting 0" {
    const bytes = devDesc() ++ cfgDesc(1) ++ ifDesc(2, 0, 1) ++
        ifDesc(2, 1, 1) ++ epDesc(0x03) ++ ifDesc(2, 2, 1) ++ epDesc(0x84);
    const l = parse(&bytes, 1) orelse return error.ParseFailed;
    try testing.expectEqual(@as(usize, 1), l.interfaces().len);
    try testing.expectEqual(@as(usize, 0), l.find(2).?.endpoints().len);
}

test "usb_layout: interface without endpoints is kept" {
    const bytes = devDesc() ++ cfgDesc(1) ++ ifDesc(1, 0, 1);
    const l = parse(&bytes, 1) orelse return error.ParseFailed;
    try testing.expectEqual(@as(usize, 0), l.find(1).?.endpoints().len);
}

test "usb_layout: malformed input returns null" {
    const good = vader5NewFirmware();
    try testing.expect(parse(good[0 .. good.len - 3], 1) == null); // truncated
    try testing.expect(parse(good[0..10], 1) == null); // shorter than device descriptor
    try testing.expect(parse(good, 0) == null); // unconfigured device
    var zero_len = devDesc() ++ cfgDesc(1) ++ [_]u8{ 0, 4 };
    try testing.expect(parse(&zero_len, 1) == null);
}

fn testConfig(ifaces: []const InterfaceConfig) DeviceConfig {
    return .{
        .device = .{ .name = "T", .vid = 0x37d7, .pid = 0x2401, .interface = ifaces },
        .report = &.{},
    };
}

const old_ifaces = [_]InterfaceConfig{
    .{ .id = 1, .class = "vendor", .ep_in = 0x82, .ep_out = 0x06 },
    .{ .id = 0, .class = "vendor", .ep_out = 0x05 },
    .{ .id = 2, .class = "suppress" },
    .{ .id = 3, .class = "suppress" },
};
const new_ifaces = [_]InterfaceConfig{
    .{ .id = 2, .class = "vendor", .ep_in = 0x83, .ep_out = 0x06 },
    .{ .id = 0, .class = "vendor", .ep_out = 0x05 },
    .{ .id = 1, .class = "suppress" },
    .{ .id = 3, .class = "suppress" },
};

test "usb_layout: check reports where an endpoint moved" {
    const l = parse(vader5NewFirmware(), 1).?;
    const m = check(&old_ifaces, &l) orelse return error.ExpectedMismatch;
    try testing.expectEqual(@as(u8, 0x06), m.endpoint_on_other_interface.ep);
    try testing.expectEqual(@as(u8, 1), m.endpoint_on_other_interface.interface);
    try testing.expectEqual(@as(u8, 2), m.endpoint_on_other_interface.owner);
    try testing.expect(check(&new_ifaces, &l) == null);

    const old = parse(vader5OldFirmware(), 1).?;
    try testing.expect(check(&old_ifaces, &old) == null);
    try testing.expect(check(&new_ifaces, &old) != null);
}

test "usb_layout: check covers missing interface, non-HID and absent endpoint" {
    const l = parse(vader5NewFirmware(), 1).?;
    const missing = [_]InterfaceConfig{.{ .id = 5, .class = "suppress" }};
    try testing.expectEqual(@as(u8, 5), check(&missing, &l).?.missing_interface);
    const not_hid = [_]InterfaceConfig{.{ .id = 0, .class = "hid" }};
    try testing.expectEqual(@as(u8, 0), check(&not_hid, &l).?.not_hid);
    const hid_ok = [_]InterfaceConfig{.{ .id = 2, .class = "hid" }};
    try testing.expect(check(&hid_ok, &l) == null);
    const absent = [_]InterfaceConfig{.{ .id = 2, .class = "vendor", .ep_in = 0x87 }};
    try testing.expectEqual(@as(u8, 0x87), check(&absent, &l).?.endpoint_absent.ep);
}

test "usb_layout: select picks the first candidate matching the layout" {
    const old_cfg = testConfig(&old_ifaces);
    const new_cfg = testConfig(&new_ifaces);
    const cands = [_]Candidate{
        .{ .cfg = &old_cfg, .path = "user/vader5.toml" },
        .{ .cfg = &new_cfg, .path = "builtin/vader5-if2.toml" },
    };
    const new_l = parse(vader5NewFirmware(), 1).?;
    const old_l = parse(vader5OldFirmware(), 1).?;
    try testing.expectEqual(@as(?usize, 1), select(&cands, &new_l));
    try testing.expectEqual(@as(?usize, 0), select(&cands, &old_l));
}

test "usb_layout: select without a layout keeps first-candidate behaviour" {
    const old_cfg = testConfig(&old_ifaces);
    const new_cfg = testConfig(&new_ifaces);
    const cands = [_]Candidate{
        .{ .cfg = &new_cfg, .path = "a.toml" },
        .{ .cfg = &old_cfg, .path = "b.toml" },
    };
    try testing.expectEqual(@as(?usize, 0), select(&cands, null));
    try testing.expectEqual(@as(?usize, null), select(&.{}, null));
}

test "usb_layout: select returns null when nothing matches" {
    const new_cfg = testConfig(&new_ifaces);
    const cands = [_]Candidate{.{ .cfg = &new_cfg, .path = "a.toml" }};
    const old_l = parse(vader5OldFirmware(), 1).?;
    try testing.expectEqual(@as(?usize, null), select(&cands, &old_l));
}

test "usb_layout: select keeps priority order among matching candidates" {
    const a = testConfig(&new_ifaces);
    const b = testConfig(&new_ifaces);
    const cands = [_]Candidate{ .{ .cfg = &a, .path = "a.toml" }, .{ .cfg = &b, .path = "b.toml" } };
    const l = parse(vader5NewFirmware(), 1).?;
    try testing.expectEqual(@as(?usize, 0), select(&cands, &l));
}

test "usb_layout: layout formats as one line per interface" {
    const l = parse(vader5NewFirmware(), 1).?;
    var buf: [128]u8 = undefined;
    const out = try std.fmt.bufPrint(&buf, "{f}", .{&l});
    try testing.expectEqualStrings("IF0 ff [81 05], IF1 03 [82], IF2 03 [83 06], IF3 03 [84]", out);
}

test "usb_layout: logSelection explains a failed match" {
    // Exercises the no-match path; the warnings name every candidate.
    const old_cfg = testConfig(&old_ifaces);
    const cands = [_]Candidate{.{ .cfg = &old_cfg, .path = "builtin/vader5.toml" }};
    const l = parse(vader5NewFirmware(), 1).?;
    const idx = select(&cands, &l);
    try testing.expectEqual(@as(?usize, null), idx);
    logSelection(0x37d7, 0x2401, &cands, &l, idx);
}

fn probeConfig(ifaces: []const InterfaceConfig, probe: ?config_device.ProbeConfig) DeviceConfig {
    var c = testConfig(ifaces);
    c.device.probe = probe;
    return c;
}

fn flydigiProbe(ids: []const i64) config_device.ProbeConfig {
    return .{ .interface = 2, .command = "05 ec", .reply = .{ .offset = 15, .expect = &.{0xec} }, .id_offset = 3, .ids = ids };
}

test "usb_layout: chooseByModel picks the candidate listing the model" {
    const hid2 = [_]InterfaceConfig{.{ .id = 2, .class = "hid" }};
    const apex = probeConfig(&hid2, flydigiProbe(&.{84}));
    const vader4 = probeConfig(&hid2, flydigiProbe(&.{ 85, 91, 105 }));
    const vader3 = probeConfig(&hid2, flydigiProbe(&.{28}));
    const cands = [_]Candidate{
        .{ .cfg = &apex, .path = "apex4.toml" },
        .{ .cfg = &vader4, .path = "vader4.toml" },
        .{ .cfg = &vader3, .path = "vader3.toml" },
    };
    const l = parse(vader5OldFirmware(), 1).?; // has a HID IF2
    var buf: [8]usize = undefined;
    const matched = matching(&cands, &l, &buf);
    try testing.expectEqual(@as(usize, 3), matched.len);
    try testing.expect(probeFor(&cands, matched) != null);

    try testing.expectEqual(@as(usize, 2), chooseByModel(&cands, matched, 28).listed);
    try testing.expectEqual(@as(usize, 1), chooseByModel(&cands, matched, 91).listed);
    try testing.expectEqual(@as(usize, 0), chooseByModel(&cands, matched, 19).unlisted);
    try testing.expectEqual(@as(usize, 0), chooseByModel(&cands, matched, null).unidentified);

    // A user override without ids, ahead of the builtins, keeps priority.
    const user_copy = testConfig(&hid2);
    const with_override = [_]Candidate{
        .{ .cfg = &user_copy, .path = "user/vader4.toml", .is_override = true },
        .{ .cfg = &apex, .path = "apex4.toml" },
        .{ .cfg = &vader4, .path = "vader4.toml" },
    };
    try testing.expectEqual(@as(usize, 0), chooseByModel(&with_override, &.{ 0, 1, 2 }, 84).override);
    // A builtin without ids is not a catch-all.
    const plain_builtin = [_]Candidate{
        .{ .cfg = &user_copy, .path = "other.toml" },
        .{ .cfg = &apex, .path = "apex4.toml" },
    };
    try testing.expectEqual(@as(usize, 1), chooseByModel(&plain_builtin, &.{ 0, 1 }, 84).listed);
}

test "usb_layout: probeFor needs two matches and a declared probe" {
    const hid2 = [_]InterfaceConfig{.{ .id = 2, .class = "hid" }};
    const plain = testConfig(&hid2);
    const probed = probeConfig(&hid2, flydigiProbe(&.{84}));
    const two_plain = [_]Candidate{ .{ .cfg = &plain, .path = "a" }, .{ .cfg = &plain, .path = "b" } };
    try testing.expect(probeFor(&two_plain, &.{ 0, 1 }) == null);
    const one = [_]Candidate{.{ .cfg = &probed, .path = "a" }};
    try testing.expect(probeFor(&one, &.{0}) == null);
    const mixed = [_]Candidate{ .{ .cfg = &plain, .path = "a" }, .{ .cfg = &probed, .path = "b" } };
    try testing.expect(probeFor(&mixed, &.{ 0, 1 }) != null);
}

test "usb_layout: readForHidraw follows sysfs from the hidraw node to the USB device" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try fixtures.writeSysfs(tmp.dir, "hidraw7", "1-4", vader5NewFirmware());

    var root_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root = try tmp.dir.realpath(".", &root_buf);
    const l = readForHidraw(root, "hidraw7") orelse return error.ReadFailed;
    try testing.expectEqualSlices(u8, &.{ 0x83, 0x06 }, l.find(2).?.endpoints());
    try testing.expect(readForHidraw(root, "hidraw8") == null);
}
