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
        if (f.delta.cx != null) {
            f.delta.cx = null;
            if (!checkFn(ctx, frames)) f.delta.cx = saved.cx;
        }
        if (f.delta.cy != null) {
            f.delta.cy = null;
            if (!checkFn(ctx, frames)) f.delta.cy = saved.cy;
        }
        if (f.delta.gx != null) {
            f.delta.gx = null;
            if (!checkFn(ctx, frames)) f.delta.gx = saved.gx;
        }
        if (f.delta.gy != null) {
            f.delta.gy = null;
            if (!checkFn(ctx, frames)) f.delta.gy = saved.gy;
        }
        if (f.delta.gz != null) {
            f.delta.gz = null;
            if (!checkFn(ctx, frames)) f.delta.gz = saved.gz;
        }
    }
}
