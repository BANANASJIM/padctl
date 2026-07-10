//! Strict T1 RED-to-GREEN proof using only the pre-existing UHID device API.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const posix = std.posix;
const testing = std.testing;

const uhid = @import("../io/uhid.zig");

const DUMMY_DESCRIPTOR = [_]u8{ 0x05, 0x01, 0xC0 };
const UHID_GET_REPORT: u32 = 9;
const UHID_GET_REPORT_REPLY: u32 = 10;
const UHID_SET_REPORT: u32 = 13;
const UHID_SET_REPORT_REPLY: u32 = 14;

fn socketPair() ![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    const rc = linux.socketpair(
        linux.AF.UNIX,
        linux.SOCK.SEQPACKET | linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC,
        0,
        &fds,
    );
    if (linux.E.init(rc) != .SUCCESS) return error.SocketPairFailed;
    return fds;
}

fn fullEvent(event_type: u32) [uhid.UHID_EVENT_SIZE]u8 {
    var event = std.mem.zeroes([uhid.UHID_EVENT_SIZE]u8);
    std.mem.writeInt(u32, event[0..4], event_type, .little);
    return event;
}

fn sendFullEvent(fd: posix.fd_t, event: *const [uhid.UHID_EVENT_SIZE]u8) !void {
    try testing.expectEqual(event.len, try posix.write(fd, event));
}

fn readReplyOrZero(fd: posix.fd_t, expected_type: u32, expected_id: u32) !usize {
    var reply: [uhid.UHID_EVENT_SIZE]u8 = undefined;
    const n = posix.read(fd, &reply) catch |err| switch (err) {
        error.WouldBlock => return 0,
        else => return err,
    };
    try testing.expectEqual(reply.len, n);
    try testing.expectEqual(expected_type, std.mem.readInt(u32, reply[0..4], .little));
    try testing.expectEqual(expected_id, std.mem.readInt(u32, reply[4..8], .little));
    try testing.expect(std.mem.readInt(u16, reply[8..10], .little) != 0);
    return n;
}

test "uhid_t1_strict: GET reply OUTPUT preserved SET reply" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const fds = try socketPair();
    defer posix.close(fds[1]);

    const dev = try uhid.UhidDevice.initWithFd(testing.allocator, fds[0], .{
        .vid = 0xFADE,
        .pid = 0xCAFE,
        .name = "padctl-t1-strict",
        .descriptor = &DUMMY_DESCRIPTOR,
    });
    defer testing.allocator.destroy(dev);
    defer dev.close();

    var read_buf: [uhid.UHID_EVENT_SIZE]u8 = undefined;

    const get_id: u32 = 0x11223344;
    var get = fullEvent(UHID_GET_REPORT);
    std.mem.writeInt(u32, get[4..8], get_id, .little);
    get[8] = 0x09;
    get[9] = 0;
    try sendFullEvent(fds[1], &get);
    try testing.expect((try dev.pollOutputReport(&read_buf)) == null);
    const get_reply_n = try readReplyOrZero(fds[1], UHID_GET_REPORT_REPLY, get_id);

    var output = fullEvent(uhid.UHID_OUTPUT);
    output[4] = 0x02;
    output[5] = 0xA5;
    std.mem.writeInt(u16, output[4100..4102], 2, .little);
    output[4102] = 1;
    try sendFullEvent(fds[1], &output);
    const report = (try dev.pollOutputReport(&read_buf)).?;
    try testing.expectEqual(@as(u8, 0x02), report.report_id);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x02, 0xA5 }, report.data);

    const set_id: u32 = 0x55667788;
    var set = fullEvent(UHID_SET_REPORT);
    std.mem.writeInt(u32, set[4..8], set_id, .little);
    set[8] = 0x20;
    set[9] = 0;
    std.mem.writeInt(u16, set[10..12], 2, .little);
    set[12] = 0xDE;
    set[13] = 0xAD;
    try sendFullEvent(fds[1], &set);
    try testing.expect((try dev.pollOutputReport(&read_buf)) == null);
    const set_reply_n = try readReplyOrZero(fds[1], UHID_SET_REPORT_REPLY, set_id);

    if (get_reply_n == 0 or set_reply_n == 0) return error.MissingControlReply;
}
