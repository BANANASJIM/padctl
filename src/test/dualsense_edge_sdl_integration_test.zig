//! Privileged SDL3 contract for the production DualSense Edge USB route.
//!
//! `zig build check-edge-sdl` only compiles this file. The explicit
//! `test-edge-sdl` target creates a real UHID node and is intentionally kept
//! out of every ordinary test/check aggregate.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const testing = std.testing;

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

const src = @import("src");
const device_config = src.config.device;
const DeviceInstance = src.device_instance.DeviceInstance;
const DeviceIO = src.io.device_io.DeviceIO;
const edge_codec = src.io.dualsense_edge_usb;
const edge_identity = src.io.edge_identity;
const uhid = src.io.uhid;
const MockDeviceIO = src.testing_support.mock_device_io.MockDeviceIO;
const cleanup = src.testing_support.uhid_test_cleanup;

const TEST_PHYS = "padctl-t8b-edge-sdl3";
const DISCOVERY_TIMEOUT_MS: i64 = 5000;
const UPDATE_TIMEOUT_MS: i64 = 2000;
const RUMBLE_SETTLE_NS = 15 * std.time.ns_per_ms;

const NATIVE_TOML =
    \\[device]
    \\name = "T8b SDL3 native Edge physical source"
    \\vid = 0x1234
    \\pid = 0x5678
    \\[[device.interface]]
    \\id = 0
    \\class = "hid"
    \\[[report]]
    \\name = "input"
    \\interface = 0
    \\size = 8
    \\[report.fields]
    \\left_x = { offset = 1, type = "i8" }
    \\[commands.rumble]
    \\interface = 0
    \\template = "a5 {strong:u8} {weak:u8} 5a"
    \\[output]
    \\emulate = "dualsense-edge"
    \\backend = "uhid"
    \\protocol = "dualsense-edge-usb"
    \\[output.axes]
    \\left_x = { code = "ABS_X", min = 0, max = 255 }
    \\left_y = { code = "ABS_Y", min = 0, max = 255 }
    \\right_x = { code = "ABS_RX", min = 0, max = 255 }
    \\right_y = { code = "ABS_RY", min = 0, max = 255 }
    \\lt = { code = "ABS_Z", min = 0, max = 255 }
    \\rt = { code = "ABS_RZ", min = 0, max = 255 }
    \\[output.force_feedback]
    \\type = "rumble"
    \\[output.touch_synthesis]
    \\left_button = "C"
    \\right_button = "Z"
    \\left_x = 480
    \\right_x = 1440
    \\y = 540
    \\click = true
;

fn forced() bool {
    const value = posix.getenv("PADCTL_TEST_REQUIRE_UHID") orelse return false;
    return std.mem.eql(u8, value, "1");
}

fn monotonicNs() i128 {
    const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

fn openRequiredUhid() !posix.fd_t {
    return posix.open("/dev/uhid", .{
        .ACCMODE = .RDWR,
        .NONBLOCK = true,
        .CLOEXEC = true,
    }, 0) catch |err| switch (err) {
        error.AccessDenied, error.FileNotFound => if (forced())
            error.RequiredUhidUnavailable
        else
            error.SkipZigTest,
        else => err,
    };
}

fn readSmallAbsolute(path: []const u8, out: []u8) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    const n = try file.readAll(out);
    return out[0..n];
}

const EDGE_HID_ID = "HID_ID=0003:0000054C:00000DF2";

fn ueventHasEdgeId(uevent: []const u8) bool {
    var lines = std.mem.splitScalar(u8, uevent, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, EDGE_HID_ID)) return true;
    }
    return false;
}

fn ueventMatches(uevent: []const u8, expected_uniq: []const u8) bool {
    var has_id = false;
    var has_uniq = false;
    var lines = std.mem.splitScalar(u8, uevent, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, EDGE_HID_ID)) has_id = true;
        if (std.mem.startsWith(u8, line, "HID_UNIQ=")) {
            has_uniq = std.mem.eql(u8, line["HID_UNIQ=".len..], expected_uniq);
        }
    }
    return has_id and has_uniq;
}

const EdgeHidrawScan = struct {
    total: usize = 0,
    matching: usize = 0,
};

fn scanEdgeHidraw(expected_uniq: []const u8) !EdgeHidrawScan {
    var dir = std.fs.openDirAbsolute("/sys/class/hidraw", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.AccessDenied => return error.HidrawSysfsUnavailable,
        else => return err,
    };
    defer dir.close();

    var result = EdgeHidrawScan{};
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "hidraw")) continue;
        var path_buf: [256]u8 = undefined;
        const path = std.fmt.bufPrint(
            &path_buf,
            "/sys/class/hidraw/{s}/device/uevent",
            .{entry.name},
        ) catch continue;
        var uevent_buf: [2048]u8 = undefined;
        const uevent = readSmallAbsolute(path, &uevent_buf) catch continue;
        if (!ueventHasEdgeId(uevent)) continue;
        result.total += 1;
        if (ueventMatches(uevent, expected_uniq)) result.matching += 1;
    }
    return result;
}

fn waitForSingleHidraw(expected_uniq: []const u8) !void {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        const scan = try scanEdgeHidraw(expected_uniq);
        if (scan.total > 1 or scan.matching > 1) return error.MultipleNativeEdgeHidrawNodes;
        if (scan.total == 1 and scan.matching == 0) return error.ForeignDualSenseEdgePresent;
        if (scan.total == 1 and scan.matching == 1) return;
        if (monotonicNs() >= deadline) {
            return if (forced()) error.NativeEdgeHidrawDiscoveryTimeout else error.SkipZigTest;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn waitForHidrawGone(expected_uniq: []const u8) !void {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        if ((try scanEdgeHidraw(expected_uniq)).total == 0) return;
        if (monotonicNs() >= deadline) return error.NativeEdgeHidrawDestroyTimeout;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn cString(ptr: [*c]const u8) []const u8 {
    if (ptr == null) return &.{};
    return std.mem.span(@as([*:0]const u8, @ptrCast(ptr)));
}

fn sdlFailure(operation: []const u8) error{SdlFailure} {
    std.log.err("{s}: {s}", .{ operation, cString(sdl.SDL_GetError()) });
    return error.SdlFailure;
}

fn setSdlHints() !void {
    const hints = [_]struct { name: [*:0]const u8, value: [*:0]const u8 }{
        .{ .name = "SDL_JOYSTICK_HIDAPI", .value = "1" },
        .{ .name = "SDL_JOYSTICK_HIDAPI_PS5", .value = "1" },
        .{ .name = "SDL_HIDAPI_LIBUSB", .value = "0" },
        .{ .name = "SDL_HIDAPI_UDEV", .value = "1" },
        .{ .name = "SDL_HIDAPI_ENUMERATE_ONLY_CONTROLLERS", .value = "1" },
        .{ .name = "SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT", .value = "0x054c/0x0df2" },
        .{ .name = "SDL_JOYSTICK_ENHANCED_REPORTS", .value = "1" },
        .{ .name = "SDL_JOYSTICK_HIDAPI_PS5_PLAYER_LED", .value = "0" },
    };
    for (hints) |hint| {
        if (!sdl.SDL_SetHintWithPriority(hint.name, hint.value, sdl.SDL_HINT_OVERRIDE)) {
            return sdlFailure("SDL_SetHintWithPriority");
        }
    }
}

fn hidrawPathMatches(path: []const u8, expected_uniq: []const u8) bool {
    const parent = std.fs.path.dirname(path) orelse return false;
    if (!std.mem.eql(u8, parent, "/dev")) return false;
    const basename = std.fs.path.basename(path);
    if (!std.mem.startsWith(u8, basename, "hidraw") or basename.len == "hidraw".len) return false;
    for (basename["hidraw".len..]) |byte| if (!std.ascii.isDigit(byte)) return false;

    var path_buf: [256]u8 = undefined;
    const uevent_path = std.fmt.bufPrint(
        &path_buf,
        "/sys/class/hidraw/{s}/device/uevent",
        .{basename},
    ) catch return false;
    var uevent_buf: [2048]u8 = undefined;
    const uevent = readSmallAbsolute(uevent_path, &uevent_buf) catch return false;
    return ueventMatches(uevent, expected_uniq);
}

const SdlCandidateScan = struct {
    count: usize = 0,
    id: sdl.SDL_JoystickID = 0,
};

fn scanSdlCandidates(expected_uniq: []const u8) !SdlCandidateScan {
    sdl.SDL_UpdateGamepads();
    var gamepad_count: c_int = 0;
    const ids = sdl.SDL_GetGamepads(&gamepad_count);
    if (ids == null) return sdlFailure("SDL_GetGamepads");
    defer sdl.SDL_free(ids);

    var result = SdlCandidateScan{};
    var index: usize = 0;
    while (index < @as(usize, @intCast(gamepad_count))) : (index += 1) {
        const id = ids[index];
        if (sdl.SDL_GetGamepadVendorForID(id) != 0x054c) continue;
        if (sdl.SDL_GetGamepadProductForID(id) != 0x0df2) continue;
        const path_ptr = sdl.SDL_GetGamepadPathForID(id);
        if (path_ptr == null) continue;
        if (!hidrawPathMatches(cString(path_ptr), expected_uniq)) continue;
        result.count += 1;
        result.id = id;
    }
    return result;
}

fn waitForSdlCandidate(expected_uniq: []const u8) !sdl.SDL_JoystickID {
    const deadline = monotonicNs() + DISCOVERY_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        const scan = try scanSdlCandidates(expected_uniq);
        if (scan.count > 1) return error.MultipleMatchingSdlGamepads;
        if (scan.count == 1) return scan.id;
        if (monotonicNs() >= deadline) return error.SdlGamepadDiscoveryTimeout;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

fn expectedSdlSerial(mac: [6]u8) [17]u8 {
    const hex = "0123456789abcdef";
    var serial: [17]u8 = undefined;
    for (0..6) |index| {
        const byte = mac[5 - index];
        serial[index * 3] = hex[byte >> 4];
        serial[index * 3 + 1] = hex[byte & 0x0f];
        if (index != 5) serial[index * 3 + 2] = '-';
    }
    return serial;
}

fn pressed(ids: []const edge_codec.ButtonId) u64 {
    var bits: u64 = 0;
    for (ids) |id| bits |= @as(u64, 1) << @intFromEnum(id);
    return bits;
}

const InitialReportFeeder = struct {
    instance: *DeviceInstance,
    stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn run(self: *InitialReportFeeder) void {
        while (!self.stop.load(.acquire)) {
            self.instance.primary_output.?.emit(.{}) catch {
                self.failed.store(true, .release);
                return;
            };
            std.Thread.sleep(2 * std.time.ns_per_ms);
        }
    }

    fn finish(self: *InitialReportFeeder, thread: std.Thread) void {
        self.stop.store(true, .release);
        thread.join();
    }
};

const EdgeButtonMapping = struct {
    source: edge_codec.ButtonId,
    target: sdl.SDL_GamepadButton,
};

const EDGE_BUTTON_MAPPINGS = [_]EdgeButtonMapping{
    .{ .source = .M1, .target = sdl.SDL_GAMEPAD_BUTTON_LEFT_PADDLE2 },
    .{ .source = .M2, .target = sdl.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2 },
    .{ .source = .M3, .target = sdl.SDL_GAMEPAD_BUTTON_LEFT_PADDLE1 },
    .{ .source = .M4, .target = sdl.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1 },
};

const EDGE_BUTTONS = [_]sdl.SDL_GamepadButton{
    sdl.SDL_GAMEPAD_BUTTON_LEFT_PADDLE2,
    sdl.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2,
    sdl.SDL_GAMEPAD_BUTTON_LEFT_PADDLE1,
    sdl.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1,
};

fn waitForButtons(gamepad: *sdl.SDL_Gamepad, expected: bool) !void {
    const deadline = monotonicNs() + UPDATE_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        sdl.SDL_UpdateGamepads();
        var matches = true;
        for (EDGE_BUTTONS) |button| {
            if (sdl.SDL_GetGamepadButton(gamepad, button) != expected) matches = false;
        }
        if (matches) return;
        if (monotonicNs() >= deadline) return error.SdlButtonUpdateTimeout;
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

fn waitForMappedButton(gamepad: *sdl.SDL_Gamepad, target: sdl.SDL_GamepadButton) !void {
    const deadline = monotonicNs() + UPDATE_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        sdl.SDL_UpdateGamepads();
        var matches = true;
        for (EDGE_BUTTONS) |button| {
            const expected = button == target;
            if (sdl.SDL_GetGamepadButton(gamepad, button) != expected) matches = false;
        }
        if (matches) return;
        if (monotonicNs() >= deadline) return error.SdlButtonMappingTimeout;
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

const Finger = struct {
    down: bool,
    x: f32,
    y: f32,
    pressure: f32,
};

fn readFinger(gamepad: *sdl.SDL_Gamepad, index: c_int) !Finger {
    var result: Finger = undefined;
    if (!sdl.SDL_GetGamepadTouchpadFinger(
        gamepad,
        0,
        index,
        &result.down,
        &result.x,
        &result.y,
        &result.pressure,
    )) return sdlFailure("SDL_GetGamepadTouchpadFinger");
    return result;
}

fn waitForTouch(gamepad: *sdl.SDL_Gamepad, left_down: bool, right_down: bool, click: bool) ![2]Finger {
    const deadline = monotonicNs() + UPDATE_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        sdl.SDL_UpdateGamepads();
        const fingers = [2]Finger{ try readFinger(gamepad, 0), try readFinger(gamepad, 1) };
        if (fingers[0].down == left_down and fingers[1].down == right_down and
            sdl.SDL_GetGamepadButton(gamepad, sdl.SDL_GAMEPAD_BUTTON_TOUCHPAD) == click)
        {
            return fingers;
        }
        if (monotonicNs() >= deadline) return error.SdlTouchUpdateTimeout;
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

fn expectActiveFinger(finger: Finger, x: f32) !void {
    try testing.expect(finger.down);
    try testing.expectApproxEqAbs(x, finger.x, @as(f32, 0.001));
    try testing.expectApproxEqAbs(@as(f32, 540.0 / 1070.0), finger.y, @as(f32, 0.001));
    try testing.expectApproxEqAbs(@as(f32, 1.0), finger.pressure, @as(f32, 0.001));
}

const SensorPair = struct {
    gyro: [3]f32,
    accel: [3]f32,
};

fn vectorsMatch(actual: [3]f32, expected: [3]f32) bool {
    for (actual, expected) |a, e| if (@abs(a - e) > 0.001) return false;
    return true;
}

fn waitForSensors(gamepad: *sdl.SDL_Gamepad, expected_gyro: [3]f32, expected_accel: [3]f32) !SensorPair {
    const deadline = monotonicNs() + UPDATE_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        sdl.SDL_UpdateGamepads();
        var result: SensorPair = undefined;
        const got_gyro = sdl.SDL_GetGamepadSensorData(gamepad, sdl.SDL_SENSOR_GYRO, &result.gyro, 3);
        const got_accel = sdl.SDL_GetGamepadSensorData(gamepad, sdl.SDL_SENSOR_ACCEL, &result.accel, 3);
        if (got_gyro and got_accel and
            vectorsMatch(result.gyro, expected_gyro) and vectorsMatch(result.accel, expected_accel))
        {
            return result;
        }
        if (monotonicNs() >= deadline) return error.SdlSensorUpdateTimeout;
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

fn waitForRumble(device: *uhid.UhidDevice, after_count: u64, strong: u16, weak: u16) !void {
    const deadline = monotonicNs() + UPDATE_TIMEOUT_MS * std.time.ns_per_ms;
    while (true) {
        // SDL's HIDAPI output queue is serviced by the gamepad update path.
        // Pump it before using the mailbox snapshot as a post-publish fence.
        sdl.SDL_UpdateGamepads();
        const snapshot = device.rumbleMailboxSnapshot();
        if (snapshot.publish_count > after_count) {
            if (snapshot.pending) |pending| {
                if (pending.strong == strong and pending.weak == weak) {
                    var wake = [_]posix.pollfd{.{
                        .fd = device.rumbleWakeFd(),
                        .events = posix.POLL.IN,
                        .revents = 0,
                    }};
                    const ready = try posix.poll(&wake, 0);
                    if (ready == 1 and wake[0].revents & posix.POLL.IN != 0) return;
                }
            }
        }
        if (monotonicNs() >= deadline) return error.SdlRumbleDecodeTimeout;
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

test "SDL3 observes native DualSense Edge input sensors touch and physical rumble handoff" {
    if (builtin.os.tag != .linux) {
        return if (forced()) error.RequiredLinuxHost else error.SkipZigTest;
    }

    cleanup.ensureSignalHandlersInstalled();
    const allocator = testing.allocator;
    var parsed = try device_config.parseString(allocator, NATIVE_TOML);
    defer parsed.deinit();
    const stable = try edge_identity.deriveStableIdentity(TEST_PHYS);
    if ((try scanEdgeHidraw(&stable.uniq)).total != 0) return error.PreexistingDualSenseEdgePresent;

    var physical = try MockDeviceIO.init(allocator, &.{});
    defer physical.deinit();
    const devices = try allocator.alloc(DeviceIO, 1);
    devices[0] = physical.deviceIO();
    var devices_transferred = false;
    defer if (!devices_transferred) allocator.free(devices);

    const uhid_fd = try openRequiredUhid();
    cleanup.registerUhidFd(uhid_fd);
    var registered = true;
    var test_owns_uhid_fd = true;
    var primary_fd_consumed = false;
    var instance: ?DeviceInstance = null;
    defer {
        if (instance) |*live| live.deinit();
        if (registered) cleanup.unregisterUhidFd(uhid_fd);
        if (test_owns_uhid_fd) {
            uhid.uhidDestroy(uhid_fd);
            posix.close(uhid_fd);
        }
    }

    var counter: u16 = 0x8b01;
    const created = DeviceInstance.init(
        allocator,
        &parsed.value,
        null,
        TEST_PHYS,
        &counter,
        .{
            .test_primary_uhid_fd = uhid_fd,
            .test_primary_uhid_fd_consumed = &primary_fd_consumed,
            .test_devices_override = devices,
        },
    ) catch |err| {
        if (primary_fd_consumed) test_owns_uhid_fd = false;
        return err;
    };
    test_owns_uhid_fd = false;
    instance = created;
    devices_transferred = true;
    instance.?.poll_timeout_ms = 50;
    try testing.expect(primary_fd_consumed);
    try testing.expect(instance.?.owner == .uhid);
    try testing.expect(instance.?.edge_runtime != null);
    try waitForSingleHidraw(&stable.uniq);

    try setSdlHints();
    const preinit_scan = try scanEdgeHidraw(&stable.uniq);
    if (preinit_scan.total != 1 or preinit_scan.matching != 1) return error.UnsafeDualSenseEdgeEnumerationSet;
    var sdl_initialized = false;
    defer if (sdl_initialized) sdl.SDL_Quit();
    var gamepad: ?*sdl.SDL_Gamepad = null;
    defer if (gamepad) |live| sdl.SDL_CloseGamepad(live);
    var gyro_enabled = false;
    var accel_enabled = false;
    defer if (gamepad) |live| {
        if (gyro_enabled) _ = sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_GYRO, false);
        if (accel_enabled) _ = sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_ACCEL, false);
    };

    var feeder = InitialReportFeeder{ .instance = &instance.? };
    const feeder_thread = try std.Thread.spawn(.{}, InitialReportFeeder.run, .{&feeder});
    var feeder_finished = false;
    defer if (!feeder_finished) feeder.finish(feeder_thread);

    if (!sdl.SDL_Init(sdl.SDL_INIT_GAMEPAD | sdl.SDL_INIT_SENSOR | sdl.SDL_INIT_EVENTS)) {
        return sdlFailure("SDL_Init");
    }
    sdl_initialized = true;
    const candidate = try waitForSdlCandidate(&stable.uniq);
    const opened = sdl.SDL_OpenGamepad(candidate);
    if (opened == null) return sdlFailure("SDL_OpenGamepad");
    gamepad = @ptrCast(opened);

    feeder.finish(feeder_thread);
    feeder_finished = true;
    if (feeder.failed.load(.acquire)) return error.InitialEnhancedReportFeederFailed;

    const live = gamepad.?;
    try testing.expectEqual(@as(u16, 0x054c), sdl.SDL_GetGamepadVendor(live));
    try testing.expectEqual(@as(u16, 0x0df2), sdl.SDL_GetGamepadProduct(live));
    try testing.expectEqual(
        @as(sdl.SDL_GamepadType, @intCast(sdl.SDL_GAMEPAD_TYPE_PS5)),
        sdl.SDL_GetGamepadType(live),
    );
    const opened_path = sdl.SDL_GetGamepadPath(live);
    try testing.expect(opened_path != null);
    try testing.expect(hidrawPathMatches(cString(opened_path), &stable.uniq));
    try testing.expectEqualStrings("DualSense Edge Wireless Controller", cString(sdl.SDL_GetGamepadName(live)));
    const expected_serial = expectedSdlSerial(stable.edge.pairing_mac);
    try testing.expectEqualStrings(&expected_serial, cString(sdl.SDL_GetGamepadSerial(live)));
    const properties = sdl.SDL_GetGamepadProperties(live);
    try testing.expect(properties != 0);
    try testing.expect(sdl.SDL_GetBooleanProperty(
        properties,
        sdl.SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN,
        false,
    ));

    for (EDGE_BUTTONS) |button| try testing.expect(sdl.SDL_GamepadHasButton(live, button));
    for (EDGE_BUTTON_MAPPINGS) |mapping| {
        try instance.?.primary_output.?.emit(.{ .buttons = pressed(&.{mapping.source}) });
        try waitForMappedButton(live, mapping.target);
        try instance.?.primary_output.?.emit(.{});
        try waitForButtons(live, false);
    }

    try testing.expectEqual(@as(c_int, 1), sdl.SDL_GetNumGamepadTouchpads(live));
    try testing.expect(sdl.SDL_GetNumGamepadTouchpadFingers(live, 0) >= 2);
    try instance.?.primary_output.?.emit(.{ .buttons = pressed(&.{ .C, .Z }) });
    var fingers = try waitForTouch(live, true, true, true);
    try expectActiveFinger(fingers[0], 0.25);
    try expectActiveFinger(fingers[1], 0.75);
    try instance.?.primary_output.?.emit(.{ .buttons = pressed(&.{.Z}) });
    fingers = try waitForTouch(live, false, true, true);
    try expectActiveFinger(fingers[1], 0.75);
    try instance.?.primary_output.?.emit(.{});
    _ = try waitForTouch(live, false, false, false);
    try instance.?.primary_output.?.emit(.{ .buttons = pressed(&.{ .C, .Z }) });
    _ = try waitForTouch(live, true, true, true);
    try instance.?.primary_output.?.emit(.{ .buttons = pressed(&.{.C}) });
    fingers = try waitForTouch(live, true, false, true);
    try expectActiveFinger(fingers[0], 0.25);
    try instance.?.primary_output.?.emit(.{});
    _ = try waitForTouch(live, false, false, false);

    try testing.expect(sdl.SDL_GamepadHasSensor(live, sdl.SDL_SENSOR_GYRO));
    try testing.expect(sdl.SDL_GamepadHasSensor(live, sdl.SDL_SENSOR_ACCEL));
    try testing.expectApproxEqAbs(@as(f32, 1000), sdl.SDL_GetGamepadSensorDataRate(live, sdl.SDL_SENSOR_GYRO), @as(f32, 0.001));
    try testing.expectApproxEqAbs(@as(f32, 1000), sdl.SDL_GetGamepadSensorDataRate(live, sdl.SDL_SENSOR_ACCEL), @as(f32, 0.001));
    if (!sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_GYRO, true)) return sdlFailure("enable gyro");
    gyro_enabled = true;
    if (!sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_ACCEL, true)) return sdlFailure("enable accel");
    accel_enabled = true;
    const expected_gyro = [3]f32{ std.math.pi, -std.math.pi / 2.0, std.math.pi / 4.0 };
    const gravity: f32 = sdl.SDL_STANDARD_GRAVITY;
    const expected_accel = [3]f32{ gravity, -gravity / 2.0, gravity / 4.0 };
    try instance.?.primary_output.?.emit(.{
        .gyro_x = 3600,
        .gyro_y = -1800,
        .gyro_z = 900,
        .accel_x = 10000,
        .accel_y = -5000,
        .accel_z = 2500,
    });
    const sensors = try waitForSensors(live, expected_gyro, expected_accel);
    for (sensors.gyro, expected_gyro) |actual, expected| try testing.expectApproxEqAbs(expected, actual, @as(f32, 0.001));
    for (sensors.accel, expected_accel) |actual, expected| try testing.expectApproxEqAbs(expected, actual, @as(f32, 0.001));

    // Drain any SDL open handshake before the handoff assertions. The mock's
    // persistent disconnect wake makes each later DeviceInstance.run finite
    // while EventLoop still drains the native pump mailbox in that iteration.
    try physical.injectDisconnect();
    try instance.?.run();
    physical.write_log.clearRetainingCapacity();
    std.Thread.sleep(RUMBLE_SETTLE_NS);

    const rumble_device = instance.?.owner.uhid;
    var before = rumble_device.rumbleMailboxSnapshot().publish_count;
    if (!sdl.SDL_RumbleGamepad(live, 0xA5A5, 0x3C3C, 5000)) return sdlFailure("SDL_RumbleGamepad");
    try waitForRumble(rumble_device, before, 0xA5A5, 0x3C3C);
    try instance.?.run();
    try testing.expectEqualSlices(u8, &.{ 0xA5, 0xA5, 0x3C, 0x5A }, physical.write_log.items);

    std.Thread.sleep(RUMBLE_SETTLE_NS);
    physical.write_log.clearRetainingCapacity();
    before = rumble_device.rumbleMailboxSnapshot().publish_count;
    if (!sdl.SDL_RumbleGamepad(live, 0x1111, 0x2222, 5000)) return sdlFailure("SDL rumble burst 1");
    if (!sdl.SDL_RumbleGamepad(live, 0x3333, 0x4444, 5000)) return sdlFailure("SDL rumble burst 2");
    if (!sdl.SDL_RumbleGamepad(live, 0x6D6D, 0x2B2B, 5000)) return sdlFailure("SDL rumble burst final");
    try waitForRumble(rumble_device, before, 0x6D6D, 0x2B2B);
    try instance.?.run();
    try testing.expectEqualSlices(u8, &.{ 0xA5, 0x6D, 0x2B, 0x5A }, physical.write_log.items);

    std.Thread.sleep(RUMBLE_SETTLE_NS);
    physical.write_log.clearRetainingCapacity();
    before = rumble_device.rumbleMailboxSnapshot().publish_count;
    if (!sdl.SDL_RumbleGamepad(live, 0, 0, 0)) return sdlFailure("SDL rumble stop");
    try waitForRumble(rumble_device, before, 0, 0);
    try instance.?.run();
    try testing.expectEqualSlices(u8, &.{ 0xA5, 0, 0, 0x5A }, physical.write_log.items);

    if (!sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_GYRO, false)) return sdlFailure("disable gyro");
    gyro_enabled = false;
    if (!sdl.SDL_SetGamepadSensorEnabled(live, sdl.SDL_SENSOR_ACCEL, false)) return sdlFailure("disable accel");
    accel_enabled = false;
    sdl.SDL_CloseGamepad(live);
    gamepad = null;
    sdl.SDL_Quit();
    sdl_initialized = false;

    // SDL no longer borrows the hidraw node. Close the production UHID owner
    // explicitly so the kernel STOP is observed before DeviceInstance's
    // idempotent teardown frees it.
    const owner = instance.?.owner.uhid;
    owner.close();
    try testing.expect(owner.pumpExited());
    try testing.expect(!owner.drainTimedOut());
    try testing.expect(owner.nativeWakeResourcesClosed());
    cleanup.unregisterUhidFd(uhid_fd);
    registered = false;

    instance.?.deinit();
    instance = null;
    try waitForHidrawGone(&stable.uniq);
}
