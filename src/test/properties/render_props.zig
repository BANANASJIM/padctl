const std = @import("std");
const testing = std.testing;

const state = @import("../../core/state.zig");
const render = @import("../../debug/render.zig");

const GamepadState = state.GamepadState;
const RenderConfig = render.RenderConfig;

// P3: random GamepadState + random raw bytes → renderFrame never panics
test "property: renderFrame robustness — random state never crashes" {
    var rng = std.Random.DefaultPrng.init(0xF00D_FACE);
    const random = rng.random();

    var out_buf: [8192]u8 = undefined;

    for (0..10000) |_| {
        const gs = randomGamepadState(random);
        const raw_len = random.intRangeAtMost(usize, 0, 64);
        var raw: [64]u8 = undefined;
        random.bytes(raw[0..raw_len]);

        // Test with has_gyro=false
        {
            var stream = std.io.fixedBufferStream(&out_buf);
            render.renderFrame(stream.writer(), &gs, raw[0..raw_len], random.boolean(), .{}, .raw) catch |err| switch (err) {
                error.NoSpaceLeft => {},
            };
        }

        // Test with has_gyro=true
        {
            var stream = std.io.fixedBufferStream(&out_buf);
            render.renderFrame(stream.writer(), &gs, raw[0..raw_len], random.boolean(), .{ .has_gyro = true }, .raw) catch |err| switch (err) {
                error.NoSpaceLeft => {},
            };
        }
    }

    // Test mapped mode with non-empty mapped_buttons
    const mapped = [_]render.MappedButton{
        blk: {
            var mb = render.MappedButton{ .btn_id = .A, .category = .gamepad, .label_len = 1 };
            mb.short_label[0] = 'S';
            break :blk mb;
        },
        blk: {
            var mb = render.MappedButton{ .btn_id = .M1, .category = .keyboard, .label_len = 3 };
            @memcpy(mb.short_label[0..3], "F13");
            break :blk mb;
        },
        blk: {
            var mb = render.MappedButton{ .btn_id = .B, .category = .mouse, .label_len = 2 };
            @memcpy(mb.short_label[0..2], "ML");
            break :blk mb;
        },
    };

    for (0..1) |_| {
        const gs = randomGamepadState(random);
        const raw_len = random.intRangeAtMost(usize, 0, 64);
        var raw: [64]u8 = undefined;
        random.bytes(raw[0..raw_len]);

        var stream = std.io.fixedBufferStream(&out_buf);
        render.renderFrame(stream.writer(), &gs, raw[0..raw_len], random.boolean(), .{
            .mapped_buttons = &mapped,
            .output_info = .{ .name = "PBT Pad" },
        }, .mapped) catch |err| switch (err) {
            error.NoSpaceLeft => {},
        };
    }
}

fn randomGamepadState(random: std.Random) GamepadState {
    return .{
        .ax = random.int(i16),
        .ay = random.int(i16),
        .rx = random.int(i16),
        .ry = random.int(i16),
        .lt = random.int(u8),
        .rt = random.int(u8),
        .dpad_x = random.int(i8),
        .dpad_y = random.int(i8),
        .buttons = random.int(u64),
        .gyro_x = random.int(i16),
        .gyro_y = random.int(i16),
        .gyro_z = random.int(i16),
        .accel_x = random.int(i16),
        .accel_y = random.int(i16),
        .accel_z = random.int(i16),
        .touch0_x = random.int(i16),
        .touch0_y = random.int(i16),
        .touch1_x = random.int(i16),
        .touch1_y = random.int(i16),
        .touch0_active = random.boolean(),
        .touch1_active = random.boolean(),
        .battery_level = random.int(u8),
    };
}
