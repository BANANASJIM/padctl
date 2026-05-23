const std = @import("std");
const aux_event_mod = @import("../core/aux_event.zig");

pub const AuxEvent = aux_event_mod.AuxEvent;

pub const CompareError = error{
    MissingAuxEvent,
    UnexpectedAuxEvent,
    AuxEventMismatch,
};

fn isDeterministic(ev: AuxEvent) bool {
    return switch (ev) {
        .key, .mouse_button => true,
        .rel => false,
    };
}

fn nextDeterministic(events: []const AuxEvent, cursor: *usize) ?AuxEvent {
    while (cursor.* < events.len) : (cursor.* += 1) {
        const ev = events[cursor.*];
        if (isDeterministic(ev)) {
            cursor.* += 1;
            return ev;
        }
    }
    return null;
}

fn sameDeterministic(a: AuxEvent, b: AuxEvent) bool {
    return switch (a) {
        .key => |ak| switch (b) {
            .key => |bk| ak.code == bk.code and ak.pressed == bk.pressed,
            else => false,
        },
        .mouse_button => |am| switch (b) {
            .mouse_button => |bm| am.code == bm.code and am.pressed == bm.pressed,
            else => false,
        },
        .rel => false,
    };
}

/// Strict DRT comparator for deterministic aux output.
///
/// `rel` events are intentionally ignored because gyro/stick mouse output is
/// float-derived and covered by property constraints elsewhere. KEY_* and
/// mouse-button events are exact: same count, same order, same code/pressed.
pub fn compareDeterministicAux(expected: []const AuxEvent, captured: []const AuxEvent) CompareError!void {
    var ei: usize = 0;
    var ci: usize = 0;

    while (true) {
        const e = nextDeterministic(expected, &ei);
        const c = nextDeterministic(captured, &ci);

        if (e == null and c == null) return;
        if (e != null and c == null) return error.MissingAuxEvent;
        if (e == null and c != null) return error.UnexpectedAuxEvent;
        if (!sameDeterministic(e.?, c.?)) return error.AuxEventMismatch;
    }
}

const testing = std.testing;

test "aux_drt: positive exact key/mouse sequence passes" {
    const expected = [_]AuxEvent{
        .{ .key = .{ .code = 30, .pressed = true } },
        .{ .key = .{ .code = 30, .pressed = false } },
        .{ .mouse_button = .{ .code = 0x110, .pressed = true } },
    };
    const captured = [_]AuxEvent{
        .{ .rel = .{ .code = 0, .value = 4 } },
        .{ .key = .{ .code = 30, .pressed = true } },
        .{ .key = .{ .code = 30, .pressed = false } },
        .{ .mouse_button = .{ .code = 0x110, .pressed = true } },
    };

    try compareDeterministicAux(&expected, &captured);
}

test "aux_drt: negative missing expected key fails" {
    const expected = [_]AuxEvent{.{ .key = .{ .code = 30, .pressed = true } }};
    const captured = [_]AuxEvent{};

    try testing.expectError(error.MissingAuxEvent, compareDeterministicAux(&expected, &captured));
}

test "aux_drt: negative ghost key while oracle is idle fails" {
    const expected = [_]AuxEvent{};
    const captured = [_]AuxEvent{.{ .key = .{ .code = 23, .pressed = true } }};

    try testing.expectError(error.UnexpectedAuxEvent, compareDeterministicAux(&expected, &captured));
}

test "aux_drt: negative wrong key code fails" {
    const expected = [_]AuxEvent{.{ .key = .{ .code = 30, .pressed = true } }};
    const captured = [_]AuxEvent{.{ .key = .{ .code = 31, .pressed = true } }};

    try testing.expectError(error.AuxEventMismatch, compareDeterministicAux(&expected, &captured));
}
