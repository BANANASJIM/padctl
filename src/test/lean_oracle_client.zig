// lean_oracle_client.zig — Lean subprocess oracle for DRT.
//
// Spawns the Lean oracle in --interactive mode and queries it via
// stdin/stdout pipes.  Falls back gracefully if the binary is absent.
// Legacy Zig reference_interp.zig will be removed once Lean oracle is
// the sole DRT source.

const std = @import("std");
const interp_mod = @import("../core/interpreter.zig");

pub const FieldType = interp_mod.FieldType;
pub const CompiledField = interp_mod.CompiledField;
pub const CompiledReport = interp_mod.CompiledReport;

pub const FieldTag = interp_mod.FieldTag;

pub const FieldResult = struct {
    tag: FieldTag,
    val: i64,
};

const ORACLE_PATH = "formal/lean/.lake/build/bin/oracle";

pub const LeanOracle = struct {
    process: std.process.Child,
    // Persistent read buffer for stdout reader.
    read_buf: [4096]u8 = undefined,

    pub fn init() !LeanOracle {
        // Check binary exists before spawning — fork succeeds but exec fails
        // in child, causing EPIPE on parent write instead of a clean error.
        std.fs.cwd().access(ORACLE_PATH, .{}) catch return error.FileNotFound;

        var child = std.process.Child.init(
            &.{ ORACLE_PATH, "--interactive" },
            std.heap.page_allocator,
        );
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Inherit;
        try child.spawn();
        return .{ .process = child };
    }

    pub fn deinit(self: *LeanOracle) void {
        if (self.process.stdin) |f| {
            f.writeAll("QUIT\n") catch {};
            var mf = f;
            mf.close();
            self.process.stdin = null;
        }
        if (self.process.stdout) |f| {
            var mf = f;
            mf.close();
            self.process.stdout = null;
        }
        _ = self.process.wait() catch {};
    }

    fn readLine(self: *LeanOracle) ![]const u8 {
        const stdout_file = self.process.stdout orelse return error.OracleError;
        var pos: usize = 0;
        while (pos < self.read_buf.len) {
            const n = stdout_file.read(self.read_buf[pos .. pos + 1]) catch return error.OracleError;
            if (n == 0) return error.OracleError; // EOF
            if (self.read_buf[pos] == '\n') return self.read_buf[0..pos];
            pos += 1;
        }
        return error.OracleError; // line too long
    }

    fn sendRecv(self: *LeanOracle, cmd: []const u8) ![]const u8 {
        const stdin_file = self.process.stdin orelse return error.OracleError;
        try stdin_file.writeAll(cmd);
        try stdin_file.writeAll("\n");

        const line = try self.readLine();
        if (std.mem.startsWith(u8, line, "ERROR")) return error.OracleError;
        if (!std.mem.startsWith(u8, line, "RESULT ")) return error.BadProtocol;
        return line["RESULT ".len..];
    }

    pub fn queryTransform(self: *LeanOracle, op_str: []const u8, input: i64, t_max: i64) !i64 {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "TRANSFORM {s} {d} {d}", .{ op_str, input, t_max }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return parseInt(result);
    }

    pub fn queryChain(self: *LeanOracle, ops_str: []const u8, input: i64, t_max: i64) !i64 {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "CHAIN {s} {d} {d}", .{ ops_str, input, t_max }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return parseInt(result);
    }

    pub fn queryField(self: *LeanOracle, ft_str: []const u8, offset: usize, hex: []const u8) !i64 {
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "FIELD {s} {d} {s}", .{ ft_str, offset, hex }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return parseInt(result);
    }

    pub fn queryBits(self: *LeanOracle, byte_off: usize, start_bit: u3, bit_count: u6, hex: []const u8) !u32 {
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "BITS {d} {d} {d} {s}", .{ byte_off, @as(u8, start_bit), @as(u8, bit_count), hex }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return @intCast(try parseUnsigned(result));
    }

    pub fn queryDpadHat(self: *LeanOracle, value: u8) !struct { dx: i8, dy: i8 } {
        var cmd_buf: [64]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "DPAD_HAT {d}", .{value}) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        var it = std.mem.splitScalar(u8, result, ' ');
        const dx_str = it.next() orelse return error.BadProtocol;
        const dy_str = it.next() orelse return error.BadProtocol;
        return .{
            .dx = @intCast(try parseInt(dx_str)),
            .dy = @intCast(try parseInt(dy_str)),
        };
    }

    pub fn querySignExtend(self: *LeanOracle, value: u32, bit_count: u6) !i64 {
        var cmd_buf: [128]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "SIGNEXTEND {d} {d}", .{ value, @as(u8, bit_count) }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return parseInt(result);
    }

    pub fn queryAssemble(self: *LeanOracle, raw: u64, suppress: u64, inject: u64) !u64 {
        var cmd_buf: [128]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "ASSEMBLE {d} {d} {d}", .{ raw, suppress, inject }) catch return error.BufOverflow;
        const result = try self.sendRecv(cmd);
        return try parseUnsigned(result);
    }
};

pub fn extractFieldsViaLean(oracle: *LeanOracle, cr: *const CompiledReport, raw: []const u8, out: []FieldResult) !usize {
    var hex_buf: [2048]u8 = undefined;
    const hex = bytesToHex(raw, &hex_buf);

    var n: usize = 0;
    for (cr.fields[0..cr.field_count]) |*cf| {
        const val: i64 = switch (cf.mode) {
            .standard => blk: {
                const ft_str = fieldTypeStr(cf.type_tag);
                const raw_val = try oracle.queryField(ft_str, cf.offset, hex);
                break :blk if (cf.has_transform) try runChainViaLean(oracle, raw_val, cf) else raw_val;
            },
            .bits => blk: {
                const raw_u32 = try oracle.queryBits(cf.byte_offset, cf.start_bit, cf.bit_count, hex);
                const raw_val: i64 = if (cf.is_signed)
                    try oracle.querySignExtend(raw_u32, cf.bit_count)
                else
                    @as(i64, raw_u32);
                break :blk if (cf.has_transform) try runChainViaLean(oracle, raw_val, cf) else raw_val;
            },
        };
        if (n < out.len) {
            out[n] = .{ .tag = cf.tag, .val = val };
            n += 1;
        }
    }
    return n;
}

fn runChainViaLean(oracle: *LeanOracle, initial: i64, cf: *const CompiledField) !i64 {
    const t_max = typeMax(cf.transforms.type_tag);
    var chain_buf: [512]u8 = undefined;
    var pos: usize = 0;
    for (cf.transforms.items[0..cf.transforms.len], 0..) |tr, i| {
        if (i > 0) {
            chain_buf[pos] = ',';
            pos += 1;
        }
        const seg = try formatTransformOp(tr, chain_buf[pos..]);
        pos += seg;
    }
    if (pos == 0) return initial;
    return oracle.queryChain(chain_buf[0..pos], initial, t_max);
}

fn formatTransformOp(tr: interp_mod.CompiledTransform, buf: []u8) !usize {
    const s = switch (tr.op) {
        .negate => try std.fmt.bufPrint(buf, "negate", .{}),
        .abs => try std.fmt.bufPrint(buf, "abs", .{}),
        .scale => try std.fmt.bufPrint(buf, "scale({d},{d})", .{ tr.a, tr.b }),
        .clamp => try std.fmt.bufPrint(buf, "clamp({d},{d})", .{ tr.a, tr.b }),
        .deadzone => try std.fmt.bufPrint(buf, "deadzone({d})", .{tr.a}),
    };
    return s.len;
}

fn typeMax(t: FieldType) i64 {
    return switch (t) {
        .u8 => 255,
        .i8 => 127,
        .u16le, .u16be => 65535,
        .i16le, .i16be => 32767,
        .u32le, .u32be => 4294967295,
        .i32le, .i32be => 2147483647,
    };
}

fn fieldTypeStr(t: FieldType) []const u8 {
    return switch (t) {
        .u8 => "u8",
        .i8 => "i8",
        .u16le => "u16le",
        .i16le => "i16le",
        .u16be => "u16be",
        .i16be => "i16be",
        .u32le => "u32le",
        .i32le => "i32le",
        .u32be => "u32be",
        .i32be => "i32be",
    };
}

pub fn bytesToHex(bytes: []const u8, buf: []u8) []const u8 {
    const hex_chars = "0123456789abcdef";
    var i: usize = 0;
    for (bytes) |b| {
        if (i + 2 > buf.len) break;
        buf[i] = hex_chars[b >> 4];
        buf[i + 1] = hex_chars[b & 0x0f];
        i += 2;
    }
    return buf[0..i];
}

fn parseInt(s: []const u8) !i64 {
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    if (trimmed.len == 0) return error.BadProtocol;
    if (trimmed[0] == '-') {
        const abs = std.fmt.parseInt(u64, trimmed[1..], 10) catch return error.BadProtocol;
        if (abs > @as(u64, @intCast(std.math.maxInt(i64))) + 1) return error.BadProtocol;
        if (abs == @as(u64, @intCast(std.math.maxInt(i64))) + 1) return std.math.minInt(i64);
        return -@as(i64, @intCast(abs));
    }
    return std.fmt.parseInt(i64, trimmed, 10) catch return error.BadProtocol;
}

fn parseUnsigned(s: []const u8) !u64 {
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    return std.fmt.parseInt(u64, trimmed, 10) catch return error.BadProtocol;
}
