const std = @import("std");
const testing = std.testing;

const control_socket = @import("../../io/control_socket.zig");
const parseCommand = control_socket.parseCommand;
const CommandTag = control_socket.CommandTag;
const socket_client = @import("../../cli/socket_client.zig");
const render = @import("../../debug/render.zig");
const Stats = render.Stats;
const ButtonId = render.ButtonId;

// --- Protocol robustness ---

test "property: random bytes never crash parseCommand" {
    var rng = std.Random.DefaultPrng.init(0xDEAD_BEEF);
    const random = rng.random();

    for (0..1000) |_| {
        const len = random.intRangeAtMost(usize, 0, 256);
        var buf: [256]u8 = undefined;
        for (buf[0..len]) |*b| b.* = random.int(u8);
        _ = parseCommand(buf[0..len]);
    }
}

// --- Protocol parsing correctness ---

test "property: valid commands always parse correctly" {
    const cases = [_]struct { input: []const u8, tag: CommandTag }{
        .{ .input = "SWITCH fps\n", .tag = .switch_mapping },
        .{ .input = "switch FPS\n", .tag = .switch_mapping },
        .{ .input = "STATUS\n", .tag = .status },
        .{ .input = "status\n", .tag = .status },
        .{ .input = "LIST\n", .tag = .list },
        .{ .input = "list\n", .tag = .list },
        .{ .input = "DEVICES\n", .tag = .devices },
        .{ .input = "devices\n", .tag = .devices },
        .{ .input = "SWITCH racing --device hidraw0\n", .tag = .switch_device },
    };
    for (cases) |c| {
        try testing.expectEqual(c.tag, parseCommand(c.input).tag);
    }
}

test "property: SWITCH with path traversal returns unknown" {
    const bad = [_][]const u8{
        "SWITCH ../etc/passwd\n",
        "SWITCH foo/bar\n",
        "SWITCH ..\\windows\n",
        "SWITCH ok --device ../x\n",
        "SWITCH ok --device foo/bar\n",
    };
    for (bad) |input| {
        try testing.expectEqual(CommandTag.unknown, parseCommand(input).tag);
    }
}

test "property: empty input returns unknown" {
    try testing.expectEqual(CommandTag.unknown, parseCommand("").tag);
    try testing.expectEqual(CommandTag.unknown, parseCommand("\n").tag);
    try testing.expectEqual(CommandTag.unknown, parseCommand("\r\n").tag);
}

test "property: long name handled without crash" {
    var buf: [270]u8 = undefined;
    const prefix = "SWITCH ";
    @memcpy(buf[0..prefix.len], prefix);
    @memset(buf[prefix.len .. prefix.len + 255], 'A');
    buf[prefix.len + 255] = '\n';
    const cmd = parseCommand(buf[0 .. prefix.len + 256]);
    try testing.expectEqual(CommandTag.switch_mapping, cmd.tag);
    try testing.expectEqual(@as(usize, 255), cmd.name.len);
}

// --- Path validation ---

test "property: connectToSocket rejects empty path" {
    try testing.expectError(error.InvalidPath, socket_client.connectToSocket(""));
}

test "property: connectToSocket rejects relative paths" {
    try testing.expectError(error.InvalidPath, socket_client.connectToSocket("relative/path.sock"));
    try testing.expectError(error.InvalidPath, socket_client.connectToSocket("sock"));
}

test "property: connectToSocket rejects paths with .." {
    try testing.expectError(error.InvalidPath, socket_client.connectToSocket("/run/../etc/shadow"));
    try testing.expectError(error.InvalidPath, socket_client.connectToSocket("/tmp/..sock"));
}

// --- Stats ring buffer ---

test "property: after N>8 recordButtonChange, eventCount == 8" {
    var stats = Stats.init(0);
    for (0..20) |i| {
        stats.recordButtonChange(.A, true, @intCast(i));
    }
    try testing.expectEqual(@as(u8, 8), stats.eventCount());
}

test "property: eventAt(0) is most recent" {
    var stats = Stats.init(0);
    const buttons = [_]ButtonId{ .A, .B, .X, .Y, .LB, .RB, .Select, .Start, .DPadUp, .DPadDown };
    for (buttons, 0..) |btn, i| {
        stats.recordButtonChange(btn, true, @intCast(i * 10));
    }
    const latest = stats.eventAt(0).?;
    try testing.expectEqual(ButtonId.DPadDown, latest.button);
    try testing.expectEqual(@as(i64, 90), latest.timestamp_ms);
}

test "property: 10000 events — no overflow or panic" {
    var stats = Stats.init(0);
    var rng = std.Random.DefaultPrng.init(0x1234_5678);
    const random = rng.random();

    for (0..10000) |i| {
        const max_btn = @as(u6, @intCast(std.meta.fields(ButtonId).len - 1));
        const btn: ButtonId = @enumFromInt(random.intRangeAtMost(u6, 0, max_btn));
        stats.recordButtonChange(btn, random.boolean(), @intCast(i));
    }
    try testing.expectEqual(@as(u8, 8), stats.eventCount());
    try testing.expectEqual(@as(u64, 10000), stats.event_total);
    // All 8 slots readable
    for (0..8) |i| {
        try testing.expect(stats.eventAt(@intCast(i)) != null);
    }
    try testing.expectEqual(@as(?render.KeyEvent, null), stats.eventAt(8));
}

test "property: ring buffer wrap — timestamps in descending order" {
    var stats = Stats.init(0);
    var prng = std.Random.DefaultPrng.init(0xABCD_EF01);
    const rng = prng.random();

    const n = rng.intRangeAtMost(usize, 9, 200);
    for (0..n) |i| {
        const max_btn = @as(u6, @intCast(std.meta.fields(ButtonId).len - 1));
        const btn: ButtonId = @enumFromInt(rng.intRangeAtMost(u6, 0, max_btn));
        stats.recordButtonChange(btn, rng.boolean(), @intCast(i));
    }

    // eventAt(0) is most recent; timestamps must be non-increasing
    const count = stats.eventCount();
    var i: u8 = 0;
    while (i + 1 < count) : (i += 1) {
        const cur = stats.eventAt(i).?.timestamp_ms;
        const nxt = stats.eventAt(i + 1).?.timestamp_ms;
        try testing.expect(cur >= nxt);
    }
}

// --- Mapping discovery idempotency ---

test "property: discoverMappings on nonexistent XDG dirs does not crash" {
    // With default XDG paths that may not exist, should not panic
    const allocator = testing.allocator;
    const profiles = try @import("../../config/mapping_discovery.zig").discoverMappings(allocator);
    defer @import("../../config/mapping_discovery.zig").freeProfiles(allocator, profiles);
}

test "property: discoverMappings idempotency — two calls yield same count" {
    const allocator = testing.allocator;
    const discovery = @import("../../config/mapping_discovery.zig");

    const p1 = try discovery.discoverMappings(allocator);
    defer discovery.freeProfiles(allocator, p1);

    const p2 = try discovery.discoverMappings(allocator);
    defer discovery.freeProfiles(allocator, p2);

    try testing.expectEqual(p1.len, p2.len);
}
