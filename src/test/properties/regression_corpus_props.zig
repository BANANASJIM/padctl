// regression_corpus_props.zig — deterministic regression tests for mapper bugs
// discovered by the generative harness.
//
// Each RegressionCase encodes the minimal reproducing sequence found by shrink.zig.
// Add new cases here as bugs are confirmed.

const std = @import("std");
const testing = std.testing;

const helpers = @import("../helpers.zig");
const mapper_oracle = @import("../gen/mapper_oracle.zig");
const sequence_gen = @import("../gen/sequence_gen.zig");
const mapping = @import("../../config/mapping.zig");

const OracleState = mapper_oracle.OracleState;
const Frame = sequence_gen.Frame;

const RegressionCase = struct {
    name: []const u8,
    mapping_toml: []const u8,
    frames: []const Frame,
    /// Expected button state after each frame (parallel to frames[]).
    expected_buttons: []const u64,
};

// Corpus is empty until the generative harness discovers a reproducible bug
// and its minimal case is committed here.
const cases = [_]RegressionCase{
    // Cases will be added here as bugs are found
};

test "regression: all corpus cases pass" {
    const allocator = testing.allocator;

    for (cases) |case| {
        var ctx = try helpers.makeMapper(case.mapping_toml, allocator);
        defer ctx.deinit();

        var oracle = OracleState{};

        std.debug.assert(case.frames.len == case.expected_buttons.len);

        for (case.frames, case.expected_buttons, 0..) |frame, expected, idx| {
            const prod = try ctx.mapper.apply(frame.delta, @as(u32, frame.dt_ms));
            const oout = mapper_oracle.apply(&oracle, frame.delta, &ctx.parsed.value, @as(u64, frame.dt_ms));

            testing.expectEqual(expected, prod.gamepad.buttons) catch |err| {
                std.log.err("regression '{s}' frame {d}: production={d} expected={d}", .{
                    case.name, idx, prod.gamepad.buttons, expected,
                });
                return err;
            };
            testing.expectEqual(expected, oout.gamepad.buttons) catch |err| {
                std.log.err("regression '{s}' frame {d}: oracle={d} expected={d}", .{
                    case.name, idx, oout.gamepad.buttons, expected,
                });
                return err;
            };
        }
    }
}
