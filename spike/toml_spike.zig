const std = @import("std");
const toml = @import("toml");

// --- Structs matching test-vader5.toml ---

const Interface = struct {
    id: i64,
    class: []const u8,
};

const DeviceInit = struct {
    commands: []const []const u8,
    response_prefix: []const i64,
};

const Device = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    interface: []const Interface,
    init: DeviceInit,
};

const MatchConfig = struct {
    offset: i64,
    expect: []const i64,
};

const FieldDef = struct {
    offset: i64,
    type: []const u8,
    transform: ?[]const u8 = null,
};

const ButtonGroupSource = struct {
    offset: i64,
    size: i64,
};

const ButtonGroup = struct {
    source: ButtonGroupSource,
    map: toml.HashMap(i64),
};

const ChecksumExpect = struct {
    offset: i64,
    type: []const u8,
};

const Checksum = struct {
    algo: []const u8,
    range: []const i64,
    expect: ChecksumExpect,
};

const Report = struct {
    name: []const u8,
    interface: i64,
    size: i64,
    match: ?MatchConfig = null,
    fields: ?toml.HashMap(FieldDef) = null,
    button_group: ?ButtonGroup = null,
    checksum: ?Checksum = null,
};

const Command = struct {
    interface: i64,
    template: []const u8,
};

const AxisConfig = struct {
    code: []const u8,
    min: i64,
    max: i64,
    fuzz: i64,
    flat: i64,
};

const DpadConfig = struct {
    type: []const u8,
};

const ForceFeedback = struct {
    type: []const u8,
    max_effects: i64,
};

const Output = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    axes: toml.HashMap(AxisConfig),
    buttons: toml.HashMap([]const u8),
    dpad: DpadConfig,
    force_feedback: ForceFeedback,
};

const Config = struct {
    device: Device,
    report: []const Report,
    commands: toml.HashMap(Command),
    output: Output,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const toml_src = @embedFile("test-vader5.toml");

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    const result = parser.parseString(toml_src) catch |err| {
        if (parser.error_info) |info| {
            switch (info) {
                .parse => |pos| std.debug.print("parse error at line {} pos {}\n", .{ pos.line, pos.pos }),
                .struct_mapping => |path| {
                    std.debug.print("struct mapping error at field path: ", .{});
                    for (path) |p| std.debug.print(".{s}", .{p});
                    std.debug.print("\n", .{});
                },
            }
        }
        return err;
    };
    defer result.deinit();

    const cfg = result.value;

    // --- SPIKE CHECK 1: [[report]] array of tables + nested sub-tables ---
    std.debug.print("\n=== SPIKE CHECK 1: [[report]] array + nested sub-tables ===\n", .{});
    std.debug.print("report count: {}\n", .{cfg.report.len});
    for (cfg.report) |r| {
        std.debug.print("  report '{s}': interface={}, size={}\n", .{ r.name, r.interface, r.size });
        if (r.match) |m| {
            std.debug.print("    match: offset={}, expect.len={}\n", .{ m.offset, m.expect.len });
        }
        if (r.fields) |f| {
            std.debug.print("    fields count: {}\n", .{f.map.count()});
            if (f.map.get("left_x")) |lx| {
                std.debug.print("    left_x: offset={}, type={s}\n", .{ lx.offset, lx.type });
            }
        }
        if (r.checksum) |cs| {
            std.debug.print("    checksum: algo={s}, range.len={}\n", .{ cs.algo, cs.range.len });
        }
    }
    const check1_pass = cfg.report.len == 2 and
        std.mem.eql(u8, cfg.report[0].name, "extended") and
        cfg.report[0].match != null and
        cfg.report[0].fields != null and
        cfg.report[0].checksum != null and
        std.mem.eql(u8, cfg.report[1].name, "standard") and
        cfg.report[1].match != null;
    std.debug.print("CHECK 1: {s}\n", .{if (check1_pass) "PASS" else "FAIL"});

    // --- SPIKE CHECK 2: hex integer literals ---
    std.debug.print("\n=== SPIKE CHECK 2: hex integer literals ===\n", .{});
    std.debug.print("device.vid=0x{x} (expected 0x37d7)\n", .{cfg.device.vid});
    std.debug.print("device.pid=0x{x} (expected 0x2401)\n", .{cfg.device.pid});
    std.debug.print("device.init.response_prefix[0]=0x{x} (expected 0x5a)\n", .{cfg.device.init.response_prefix[0]});
    std.debug.print("output.vid=0x{x} (expected 0x3820)\n", .{cfg.output.vid});
    const check2_pass = cfg.device.vid == 0x37d7 and
        cfg.device.pid == 0x2401 and
        cfg.device.init.response_prefix.len == 2 and
        cfg.device.init.response_prefix[0] == 0x5a and
        cfg.device.init.response_prefix[1] == 0xa5 and
        cfg.output.vid == 0x3820;
    std.debug.print("CHECK 2: {s}\n", .{if (check2_pass) "PASS" else "FAIL"});

    // --- SPIKE CHECK 3: [commands.X] dynamic key names ---
    std.debug.print("\n=== SPIKE CHECK 3: [commands.*] dynamic keys ===\n", .{});
    std.debug.print("commands count: {}\n", .{cfg.commands.map.count()});
    if (cfg.commands.map.get("rumble")) |r| {
        std.debug.print("  rumble: interface={}, template={s}\n", .{ r.interface, r.template });
    }
    if (cfg.commands.map.get("led")) |l| {
        std.debug.print("  led: interface={}, template={s}\n", .{ l.interface, l.template });
    }
    const check3_pass = cfg.commands.map.count() == 2 and
        cfg.commands.map.contains("rumble") and
        cfg.commands.map.contains("led");
    std.debug.print("CHECK 3: {s}\n", .{if (check3_pass) "PASS" else "FAIL"});

    // --- SPIKE CHECK 4: optional nested table ([report.checksum] optional) ---
    std.debug.print("\n=== SPIKE CHECK 4: optional nested ([report.checksum]) ===\n", .{});
    std.debug.print("report[0].checksum present: {}\n", .{cfg.report[0].checksum != null});
    std.debug.print("report[1].checksum present: {}\n", .{cfg.report[1].checksum != null});
    const check4_pass = cfg.report[0].checksum != null and cfg.report[1].checksum == null;
    std.debug.print("CHECK 4: {s}\n", .{if (check4_pass) "PASS" else "FAIL"});

    std.debug.print("\n=== SUMMARY ===\n", .{});
    std.debug.print("CHECK 1 ([[report]] array + nested sub-tables): {s}\n", .{if (check1_pass) "PASS" else "FAIL"});
    std.debug.print("CHECK 2 (hex integer literals):                  {s}\n", .{if (check2_pass) "PASS" else "FAIL"});
    std.debug.print("CHECK 3 ([commands.*] dynamic keys):             {s}\n", .{if (check3_pass) "PASS" else "FAIL"});
    std.debug.print("CHECK 4 (optional nested table):                 {s}\n", .{if (check4_pass) "PASS" else "FAIL"});

    const all_pass = check1_pass and check2_pass and check3_pass and check4_pass;
    std.debug.print("\nOVERALL: {s}\n", .{if (all_pass) "PASS — zig-toml viable for padctl DSL" else "FAIL — see individual checks"});
}
