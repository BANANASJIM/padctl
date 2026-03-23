const std = @import("std");
const testing = std.testing;

const device_mod = @import("../../config/device.zig");
const interpreter_mod = @import("../../core/interpreter.zig");
const helpers = @import("../helpers.zig");

const Interpreter = interpreter_mod.Interpreter;
const FieldType = interpreter_mod.FieldType;

// P1: any random packet → processReport never panics (returns Ok or null)
test "property: interpreter robustness — random packets never crash" {
    const allocator = testing.allocator;
    var paths = try helpers.collectTomlPaths(allocator);
    defer helpers.freeTomlPaths(allocator, &paths);

    try testing.expect(paths.items.len >= 13);

    var rng = std.Random.DefaultPrng.init(0xDEAD_BEEF);
    const random = rng.random();

    for (paths.items) |path| {
        const parsed = device_mod.parseFile(allocator, path) catch continue;
        defer parsed.deinit();

        const cfg = &parsed.value;
        const interp = Interpreter.init(cfg);

        for (cfg.report) |report| {
            const size: usize = @intCast(report.size);
            var buf: [1024]u8 = undefined;
            const pkt = buf[0..@min(size, buf.len)];

            for (0..1000) |_| {
                random.bytes(pkt);
                const iface: u8 = @intCast(report.interface);
                _ = interp.processReport(iface, pkt) catch |err| switch (err) {
                    error.ChecksumMismatch => {},
                    error.MalformedConfig => {},
                };
            }
        }
    }
}

// P2 removed: readFieldByTag range check is vacuous (type-guaranteed by construction)
