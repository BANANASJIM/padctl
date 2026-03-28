// shrink.zig — failure minimization for generative test cases.
//
// When the harness detects a production-oracle divergence, shrink the
// failing frame sequence to the smallest reproducing case.

const std = @import("std");
const Allocator = std.mem.Allocator;
const sequence_gen = @import("sequence_gen.zig");
const mapping = @import("../../config/mapping.zig");

pub const Frame = sequence_gen.Frame;
pub const MappingConfig = mapping.MappingConfig;

/// Callback type: returns true if the failure still reproduces on `frames`.
/// `ctx` is an opaque pointer to caller-provided state (e.g. TOML + allocator).
pub const CheckFn = *const fn (ctx: *anyopaque, frames: []const Frame) bool;

/// Shrink `frames` to the minimal sub-sequence that still triggers a failure.
/// `checkFn(ctx, frames)` must return true iff the failure reproduces.
/// Caller owns the returned slice (allocated with `allocator`).
pub fn shrinkSequence(
    allocator: Allocator,
    frames: []const Frame,
    ctx: *anyopaque,
    checkFn: CheckFn,
) Allocator.Error![]Frame {
    if (frames.len == 0) return allocator.dupe(Frame, frames);

    var current = try allocator.dupe(Frame, frames);

    // Pass 1: binary search on length
    current = try binaryTrimLength(allocator, current, ctx, checkFn);

    // Pass 2: remove individual frames
    current = try removeIndividualFrames(allocator, current, ctx, checkFn);

    // Pass 3: simplify delta fields
    simplifyDeltas(current, ctx, checkFn);

    return current;
}

fn binaryTrimLength(
    allocator: Allocator,
    frames: []Frame,
    ctx: *anyopaque,
    checkFn: CheckFn,
) Allocator.Error![]Frame {
    var cur = frames;
    while (cur.len > 1) {
        const half = cur.len / 2;
        if (checkFn(ctx, cur[0..half])) {
            const smaller = try allocator.dupe(Frame, cur[0..half]);
            allocator.free(cur);
            cur = smaller;
        } else if (checkFn(ctx, cur[half..])) {
            const smaller = try allocator.dupe(Frame, cur[half..]);
            allocator.free(cur);
            cur = smaller;
        } else {
            break;
        }
    }
    return cur;
}

fn removeIndividualFrames(
    allocator: Allocator,
    frames: []Frame,
    ctx: *anyopaque,
    checkFn: CheckFn,
) Allocator.Error![]Frame {
    var cur = frames;
    var i: usize = 0;
    while (i < cur.len) {
        const candidate = try allocator.alloc(Frame, cur.len - 1);
        @memcpy(candidate[0..i], cur[0..i]);
        @memcpy(candidate[i..], cur[i + 1 ..]);

        if (checkFn(ctx, candidate)) {
            allocator.free(cur);
            cur = candidate;
        } else {
            allocator.free(candidate);
            i += 1;
        }
    }
    return cur;
}

fn simplifyDeltas(frames: []Frame, ctx: *anyopaque, checkFn: CheckFn) void {
    for (frames) |*f| {
        const saved = f.delta;

        if (f.delta.ax != null) {
            f.delta.ax = null;
            if (!checkFn(ctx, frames)) f.delta.ax = saved.ax;
        }
        if (f.delta.ay != null) {
            f.delta.ay = null;
            if (!checkFn(ctx, frames)) f.delta.ay = saved.ay;
        }
        if (f.delta.rx != null) {
            f.delta.rx = null;
            if (!checkFn(ctx, frames)) f.delta.rx = saved.rx;
        }
        if (f.delta.ry != null) {
            f.delta.ry = null;
            if (!checkFn(ctx, frames)) f.delta.ry = saved.ry;
        }
        if (f.delta.gyro_x != null) {
            f.delta.gyro_x = null;
            if (!checkFn(ctx, frames)) f.delta.gyro_x = saved.gyro_x;
        }
        if (f.delta.gyro_y != null) {
            f.delta.gyro_y = null;
            if (!checkFn(ctx, frames)) f.delta.gyro_y = saved.gyro_y;
        }
        if (f.delta.gyro_z != null) {
            f.delta.gyro_z = null;
            if (!checkFn(ctx, frames)) f.delta.gyro_z = saved.gyro_z;
        }
    }
}

// --- tests ---

const testing = std.testing;

fn makeFrame(ax: ?i16) Frame {
    return .{ .delta = .{ .ax = ax }, .dt_ms = 0 };
}

// alwaysTrue: failure reproduces on any non-empty sequence
fn alwaysTrue(_: *anyopaque, frames: []const Frame) bool {
    return frames.len > 0;
}

// firstFrame: failure reproduces only when first frame has ax != null
fn firstFrame(_: *anyopaque, frames: []const Frame) bool {
    return frames.len > 0 and frames[0].delta.ax != null;
}

test "shrink: empty input returns empty" {
    const result = try shrinkSequence(testing.allocator, &.{}, undefined, alwaysTrue);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "shrink: single reproducing frame is kept" {
    const input = [_]Frame{makeFrame(42)};
    const result = try shrinkSequence(testing.allocator, &input, undefined, alwaysTrue);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 1), result.len);
}

test "shrink: reduces to minimal reproducing prefix" {
    // failure only when first frame present — binary trim should reduce to 1
    var input: [8]Frame = undefined;
    for (&input, 0..) |*f, i| f.* = makeFrame(@intCast(i));
    const result = try shrinkSequence(testing.allocator, &input, undefined, firstFrame);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expect(result[0].delta.ax != null);
}

test "shrink: simplifyDeltas nulls irrelevant delta fields" {
    // failure reproduces regardless of ax value — simplify should null it
    const alwaysTrueIgnoreAx = struct {
        fn check(_: *anyopaque, frames: []const Frame) bool {
            return frames.len > 0;
        }
    }.check;

    var input = [_]Frame{.{ .delta = .{ .ax = 100, .ay = 200 }, .dt_ms = 0 }};
    const result = try shrinkSequence(testing.allocator, &input, undefined, alwaysTrueIgnoreAx);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqual(@as(?i16, null), result[0].delta.ax);
    try testing.expectEqual(@as(?i16, null), result[0].delta.ay);
}
