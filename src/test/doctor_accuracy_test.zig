const std = @import("std");
const testing = std.testing;
const scan = @import("../cli/scan.zig");
const doctor = @import("../cli/doctor.zig");
const socket_client = @import("../cli/socket_client.zig");
const shadow_grab = @import("../io/shadow_grab.zig");

// --- hidraw uevent parsing (permission-denied identity without open()) ---

test "doctor_accuracy: parseHidrawUevent extracts vid/pid/name from HID_ID and HID_NAME" {
    const uevent =
        "DRIVER=flydigi\n" ++
        "HID_ID=0003:000037D7:00002401\n" ++
        "HID_NAME=Flydigi VADER5\n" ++
        "HID_PHYS=usb-0000:10:00.0-3/input1\n" ++
        "MODALIAS=hid:b0003g0001v000037D7p00002401\n";
    const info = scan.parseHidrawUevent(uevent).?;
    try testing.expectEqual(@as(u16, 0x37d7), info.vid);
    try testing.expectEqual(@as(u16, 0x2401), info.pid);
    try testing.expectEqualStrings("Flydigi VADER5", info.name);
}

test "doctor_accuracy: parseHidrawUevent without HID_ID returns null" {
    try testing.expect(scan.parseHidrawUevent("DRIVER=hid-generic\nHID_NAME=foo\n") == null);
    try testing.expect(scan.parseHidrawUevent("") == null);
}

test "doctor_accuracy: parseHidrawUevent tolerates CRLF and missing HID_NAME" {
    const info = scan.parseHidrawUevent("HID_ID=0003:0000045E:00000B00\r\n").?;
    try testing.expectEqual(@as(u16, 0x045e), info.vid);
    try testing.expectEqual(@as(u16, 0x0b00), info.pid);
    try testing.expectEqualStrings("", info.name);
}

// --- scan: permission warning printed once per run, not per config dir ---

test "doctor_accuracy: render prints one permission warning for multiple denied nodes" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const entries = [_]scan.ScanEntry{
        .{ .path = "/dev/hidraw1", .vid = 0x37d7, .pid = 0x2401, .name = "Vader 5", .phys = "usb-1", .config_path = null, .access_denied = true },
        .{ .path = "/dev/hidraw2", .vid = 0x045e, .pid = 0x0b00, .name = "Elite 2", .phys = "usb-2", .config_path = null, .access_denied = true },
    };
    try scan.render(fbs.writer(), &entries, &.{});
    const out = fbs.getWritten();

    try testing.expect(std.mem.indexOf(u8, out, "permission denied opening 2 hidraw node(s)") != null);
    try testing.expect(std.mem.indexOf(u8, out, "usermod -aG input") != null);
    const first = std.mem.indexOf(u8, out, "permission denied").?;
    try testing.expect(std.mem.indexOfPos(u8, out, first + 1, "permission denied") == null);
}

test "doctor_accuracy: render prints no permission warning when nothing denied" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const entries = [_]scan.ScanEntry{
        .{ .path = "/dev/hidraw0", .vid = 0x37d7, .pid = 0x2401, .name = "Vader 5", .phys = "usb-1", .config_path = "devices/vader5.toml" },
    };
    try scan.render(fbs.writer(), &entries, &.{});
    try testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "permission denied") == null);
}

// --- doctor: hidraw line tells the truth for access-denied nodes ---

test "doctor_accuracy: printHidrawDiagnosis denied node names the node and remedy" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try doctor.printHidrawDiagnosis(buf.writer(testing.allocator), "/dev/hidraw3", true);
    try testing.expectEqualStrings(
        "  hidraw: /dev/hidraw3 exists but permission denied (mode/owner; you are not in the input group)\n" ++
            "  hint: sudo usermod -aG input $USER && re-login (or replug to apply udev rules)\n",
        buf.items,
    );
}

test "doctor_accuracy: printHidrawDiagnosis readable node and missing node" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try doctor.printHidrawDiagnosis(buf.writer(testing.allocator), "/dev/hidraw3", false);
    try testing.expectEqualStrings("  hidraw: /dev/hidraw3\n", buf.items);
    buf.clearRetainingCapacity();
    try doctor.printHidrawDiagnosis(buf.writer(testing.allocator), null, false);
    try testing.expectEqualStrings("  hidraw: none\n", buf.items);
}

// --- doctor: verdict decision ---

test "doctor_accuracy: decideVerdict denied node is permission_denied, not shadowed or no-node" {
    const base: doctor.VerdictInput = .{
        .usb_present = true,
        .claimed = false,
        .hidraw = .denied,
        .kernel_driver = false,
        .flagged_driver = false,
        .shadow_grabs = 0,
    };
    try testing.expectEqual(doctor.Verdict.permission_denied, doctor.decideVerdict(base));

    var with_driver = base;
    with_driver.kernel_driver = true;
    with_driver.flagged_driver = true;
    try testing.expectEqual(doctor.Verdict.permission_denied, doctor.decideVerdict(with_driver));
}

test "doctor_accuracy: decideVerdict unclaimed missing-node branches" {
    var in: doctor.VerdictInput = .{
        .usb_present = true,
        .claimed = false,
        .hidraw = .missing,
        .kernel_driver = true,
        .flagged_driver = false,
        .shadow_grabs = 0,
    };
    try testing.expectEqual(doctor.Verdict.shadowed_no_hidraw, doctor.decideVerdict(in));
    in.kernel_driver = false;
    try testing.expectEqual(doctor.Verdict.no_hidraw, doctor.decideVerdict(in));
    in.hidraw = .ok;
    try testing.expectEqual(doctor.Verdict.present_not_claimed, doctor.decideVerdict(in));
    in.usb_present = false;
    try testing.expectEqual(doctor.Verdict.not_detected, doctor.decideVerdict(in));
}

test "doctor_accuracy: decideVerdict managed device downgraded only when flagged driver has no grab" {
    var in: doctor.VerdictInput = .{
        .usb_present = true,
        .claimed = true,
        .hidraw = .ok,
        .kernel_driver = true,
        .flagged_driver = true,
        .shadow_grabs = 0,
    };
    try testing.expectEqual(doctor.Verdict.managed_unguarded_shadow, doctor.decideVerdict(in));
    in.shadow_grabs = 2;
    try testing.expectEqual(doctor.Verdict.ok_managed, doctor.decideVerdict(in));
    in.shadow_grabs = 0;
    in.flagged_driver = false;
    try testing.expectEqual(doctor.Verdict.ok_managed, doctor.decideVerdict(in));
}

test "doctor_accuracy: findFlaggedShadow flags xpad and block-listed drivers, never usbhid" {
    const ifaces = [_]doctor.UsbInterface{
        .{ .iface = "1-2:1.0", .driver = "usbhid" },
        .{ .iface = "1-2:1.1", .driver = null },
        .{ .iface = "1-2:1.2", .driver = "xpad" },
    };
    const hit = doctor.findFlaggedShadow(&ifaces, &.{}).?;
    try testing.expectEqualStrings("1-2:1.2", hit.iface);
    try testing.expectEqualStrings("xpad", hit.driver.?);

    const usbhid_only = [_]doctor.UsbInterface{
        .{ .iface = "1-2:1.0", .driver = "usbhid" },
    };
    try testing.expect(doctor.findFlaggedShadow(&usbhid_only, &.{}) == null);
    try testing.expect(doctor.findFlaggedShadow(&usbhid_only, &.{"usbhid"}) == null);

    const custom = [_]doctor.UsbInterface{
        .{ .iface = "3-1:1.0", .driver = "hid-tmff2" },
    };
    try testing.expect(doctor.findFlaggedShadow(&custom, &.{}) == null);
    const flagged = doctor.findFlaggedShadow(&custom, &.{"hid-tmff2"}).?;
    try testing.expectEqualStrings("hid-tmff2", flagged.driver.?);
}

// --- doctor: config provenance (#397 stale-override trap) ---

test "doctor_accuracy: printProvenance single match has no OVERRIDES" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try doctor.printProvenance(buf.writer(testing.allocator), &.{"/usr/share/padctl/devices/flydigi/vader5.toml"});
    try testing.expectEqualStrings("  config: /usr/share/padctl/devices/flydigi/vader5.toml\n", buf.items);
}

test "doctor_accuracy: printProvenance shadowed files listed after OVERRIDES" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try doctor.printProvenance(buf.writer(testing.allocator), &.{
        "/home/u/.config/padctl/devices/vader5.toml",
        "/usr/share/padctl/devices/flydigi/vader5.toml",
    });
    try testing.expectEqualStrings(
        "  config: /home/u/.config/padctl/devices/vader5.toml (OVERRIDES /usr/share/padctl/devices/flydigi/vader5.toml)\n",
        buf.items,
    );
}

test "doctor_accuracy: printProvenance empty match prints nothing" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try doctor.printProvenance(buf.writer(testing.allocator), &.{});
    try testing.expectEqual(@as(usize, 0), buf.items.len);
}

test "doctor_accuracy: collectConfigMatches walks dirs in resolution order" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    try tmp.dir.makePath("user/devices");
    try tmp.dir.makePath("system/devices/flydigi");
    inline for (.{ "user/devices/vader5.toml", "system/devices/flydigi/vader5.toml" }) |rel| {
        var f = try tmp.dir.createFile(rel, .{});
        defer f.close();
        try f.writeAll("[device]\nname = \"vader5\"\nvid = 0x37d7\npid = 0x2401\n");
    }
    {
        var f = try tmp.dir.createFile("system/devices/other.toml", .{});
        defer f.close();
        try f.writeAll("[device]\nname = \"other\"\nvid = 0x1111\npid = 0x2222\n");
    }

    const user_dir = try std.fmt.allocPrint(allocator, "{s}/user/devices", .{root});
    defer allocator.free(user_dir);
    const sys_dir = try std.fmt.allocPrint(allocator, "{s}/system/devices", .{root});
    defer allocator.free(sys_dir);

    const matches = try doctor.collectConfigMatches(allocator, &.{ user_dir, sys_dir }, 0x37d7, 0x2401);
    defer doctor.freeConfigMatches(allocator, matches);
    try testing.expectEqual(@as(usize, 2), matches.len);
    try testing.expect(std.mem.endsWith(u8, matches[0], "user/devices/vader5.toml"));
    try testing.expect(std.mem.endsWith(u8, matches[1], "system/devices/flydigi/vader5.toml"));

    const none = try doctor.collectConfigMatches(allocator, &.{ user_dir, sys_dir }, 0xffff, 0xffff);
    defer doctor.freeConfigMatches(allocator, none);
    try testing.expectEqual(@as(usize, 0), none.len);
}

// --- STATUS wire: shadow_grabs fields, additive ---

test "doctor_accuracy: GrabList.appendStatusFields emits count and node list" {
    var list = shadow_grab.GrabList{};
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try list.appendStatusFields(fbs.writer());
    try testing.expectEqualStrings(" shadow_grabs=0", fbs.getWritten());

    inline for (.{ "event5", "event17" }, 0..) |n, i| {
        list.grabs[i] = .{ .fd = -1, .name_buf = undefined, .name_len = n.len };
        @memcpy(list.grabs[i].name_buf[0..n.len], n);
    }
    list.len = 2;
    fbs.reset();
    try list.appendStatusFields(fbs.writer());
    try testing.expectEqualStrings(" shadow_grabs=2 shadow_nodes=event5,event17", fbs.getWritten());
}

test "doctor_accuracy: parseStatusLine reads shadow_grabs and shadow_nodes" {
    const line = "STATUS device=vader5 state=active mapping=default phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true evdev_node=/dev/input/event5 hotplug_pending=0 last_inbound_ms_ago=12 last_outbound_ms_ago=8 write_in_flight_ms=0 shadow_grabs=2 shadow_nodes=event5,event17\n";
    const devices = try socket_client.parseStatusLine(line, testing.allocator);
    defer socket_client.freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 1), devices.len);
    try testing.expectEqual(@as(usize, 2), devices[0].shadow_grabs);
    try testing.expectEqualStrings("event5,event17", devices[0].shadow_nodes);
    try testing.expectEqualStrings("vader5", devices[0].name);
    try testing.expectEqual(@as(u16, 0x37d7), devices[0].vid);
}

test "doctor_accuracy: parseStatusLine without shadow fields defaults to zero" {
    const line = "STATUS device=vader5 state=active mapping=default phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true\n";
    const devices = try socket_client.parseStatusLine(line, testing.allocator);
    defer socket_client.freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 1), devices.len);
    try testing.expectEqual(@as(usize, 0), devices[0].shadow_grabs);
    try testing.expectEqualStrings("", devices[0].shadow_nodes);
}

test "doctor_accuracy: parseStatusLine two devices with distinct shadow fields" {
    const line = "STATUS device=vader5 state=active mapping=fps phys_key=usb-1 vid=0x37d7 pid=0x2401 output_kind=uhid output_fd_alive=true shadow_grabs=1 shadow_nodes=event9 device=wheel state=active mapping=racing phys_key=usb-2 vid=0x044f pid=0xb67f output_kind=uinput output_fd_alive=true shadow_grabs=0\n";
    const devices = try socket_client.parseStatusLine(line, testing.allocator);
    defer socket_client.freeStatusDevices(testing.allocator, devices);
    try testing.expectEqual(@as(usize, 2), devices.len);
    try testing.expectEqual(@as(usize, 1), devices[0].shadow_grabs);
    try testing.expectEqualStrings("event9", devices[0].shadow_nodes);
    try testing.expectEqual(@as(usize, 0), devices[1].shadow_grabs);
    try testing.expectEqualStrings("", devices[1].shadow_nodes);
}
