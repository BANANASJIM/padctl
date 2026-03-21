// Wasm3 backend — real IM3 runtime implementing WasmPlugin.VTable.

const std = @import("std");
const c = @cImport(@cInclude("wasm3.h"));
const HostContext = @import("host.zig").HostContext;
const runtime_mod = @import("runtime.zig");
const WasmPlugin = runtime_mod.WasmPlugin;
const LoadError = runtime_mod.LoadError;
const ProcessResult = runtime_mod.ProcessResult;
const GamepadStateDelta = @import("../core/state.zig").GamepadStateDelta;

const wasm_log = std.log.scoped(.wasm3);

const input_offset: u32 = 0;
const output_offset: u32 = 4096;
const stack_size: u32 = 1024 * 1024;

pub const Wasm3Plugin = struct {
    env: c.IM3Environment = null,
    rt: c.IM3Runtime = null,
    module_: c.IM3Module = null,
    ctx: ?*HostContext = null,
    fn_init: c.IM3Function = null,
    fn_calib: c.IM3Function = null,
    fn_proc: c.IM3Function = null,
    trap_count: u32 = 0,
    last_trap_ts: i64 = 0,
    allocator: std.mem.Allocator,

    const vtable = WasmPlugin.VTable{
        .load = load,
        .initDevice = initDevice,
        .processCalibration = processCalibration,
        .processReport = processReport,
        .unload = unload,
        .destroy = destroy,
    };

    pub fn create(allocator: std.mem.Allocator) !WasmPlugin {
        const self = try allocator.create(Wasm3Plugin);
        self.* = .{ .allocator = allocator };
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn getSelf(ptr: *anyopaque) *Wasm3Plugin {
        return @ptrCast(@alignCast(ptr));
    }

    // -- vtable implementations --

    fn load(ptr: *anyopaque, wasm_bytes: []const u8, host_ctx: *HostContext) LoadError!void {
        const s = getSelf(ptr);
        s.env = c.m3_NewEnvironment() orelse return error.PluginLoadFailed;
        errdefer {
            if (s.env) |env| c.m3_FreeEnvironment(env);
            s.env = null;
        }
        s.rt = c.m3_NewRuntime(s.env, stack_size, null) orelse return error.PluginLoadFailed;
        errdefer {
            if (s.rt) |rt| c.m3_FreeRuntime(rt);
            s.rt = null;
        }
        s.ctx = host_ctx;

        var mod: c.IM3Module = null;
        if (c.m3_ParseModule(s.env, &mod, wasm_bytes.ptr, @intCast(wasm_bytes.len)) != null)
            return error.InvalidModule;
        if (c.m3_LoadModule(s.rt, mod) != null) {
            c.m3_FreeModule(mod);
            return error.PluginLoadFailed;
        }
        s.module_ = mod;

        linkHostFunctions(s);

        _ = c.m3_FindFunction(&s.fn_init, s.rt, "init_device");
        _ = c.m3_FindFunction(&s.fn_calib, s.rt, "process_calibration");
        _ = c.m3_FindFunction(&s.fn_proc, s.rt, "process_report");
    }

    fn initDevice(ptr: *anyopaque) bool {
        const s = getSelf(ptr);
        const f = s.fn_init orelse return false;
        if (callWasm(f, &.{})) |trap| {
            handleTrap(s, trap);
            return false;
        }
        var ret: i32 = 0;
        if (getResultI32(f, &ret)) return false;
        return ret == 0;
    }

    fn processCalibration(ptr: *anyopaque, buf: []const u8) void {
        const s = getSelf(ptr);
        const f = s.fn_calib orelse return;
        const mem = getWasmMemory(s) orelse return;
        memcpyToWasm(mem, input_offset, buf) orelse return;
        const a0: u32 = input_offset;
        const a1: u32 = @intCast(buf.len);
        if (callWasm(f, &.{ &a0, &a1 })) |trap| handleTrap(s, trap);
    }

    fn processReport(ptr: *anyopaque, raw: []const u8, out: []u8) ProcessResult {
        const s = getSelf(ptr);
        const f = s.fn_proc orelse return .passthrough;
        const mem = getWasmMemory(s) orelse return .drop;
        memcpyToWasm(mem, input_offset, raw) orelse return .drop;

        const a0: u32 = input_offset;
        const a1: u32 = @intCast(raw.len);
        const a2: u32 = output_offset;
        const a3: u32 = @intCast(out.len);
        if (callWasm(f, &.{ &a0, &a1, &a2, &a3 })) |trap| {
            handleTrap(s, trap);
            return .drop;
        }

        var ret: i32 = -1;
        if (getResultI32(f, &ret)) return .drop;

        if (ret >= 0) {
            memcpyFromWasm(out, mem, output_offset) orelse return .drop;
            return .{ .override = deltaFromBytes(out) };
        } else {
            return .drop;
        }
    }

    fn unload(ptr: *anyopaque) void {
        const s = getSelf(ptr);
        if (s.rt) |rt| c.m3_FreeRuntime(rt);
        if (s.env) |env| c.m3_FreeEnvironment(env);
        s.rt = null;
        s.env = null;
        s.module_ = null;
        s.fn_init = null;
        s.fn_calib = null;
        s.fn_proc = null;
        s.ctx = null;
    }

    fn destroy(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const s = getSelf(ptr);
        if (s.env != null) unload(ptr);
        allocator.destroy(s);
    }

    // -- call helpers --

    fn callWasm(f: c.IM3Function, args: []const ?*const anyopaque) c.M3Result {
        if (args.len == 0) return c.m3_Call(f, 0, null);
        return c.m3_Call(f, @intCast(args.len), @ptrCast(args.ptr));
    }

    fn getResultI32(f: c.IM3Function, out: *i32) bool {
        const p: ?*const anyopaque = out;
        return c.m3_GetResults(f, 1, @ptrCast(&p)) != null;
    }

    // -- host function binding --

    fn linkHostFunctions(s: *Wasm3Plugin) void {
        const mod = s.module_ orelse return;
        const ud: ?*const anyopaque = @ptrCast(s);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "device_read", "i(iii)", hostDeviceRead, ud);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "device_write", "i(ii)", hostDeviceWrite, ud);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "log", "v(iii)", hostLog, ud);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "get_config", "i(iiii)", hostGetConfig, ud);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "set_state", "v(iiii)", hostSetState, ud);
        _ = c.m3_LinkRawFunctionEx(mod, "env", "get_state", "i(iiii)", hostGetState, ud);
    }

    // M3RawCall signature: fn(IM3Runtime, IM3ImportContext, [*c]u64, ?*anyopaque) callconv(.c) ?*const anyopaque
    // Return null on success, non-null M3Result pointer on trap.
    // For functions with return value ("i(...)"), sp layout: [ret, arg0, arg1, ...]
    // For void functions ("v(...)"), sp layout: [arg0, arg1, ...]

    fn hostDeviceRead(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        const report_id: i32 = @bitCast(@as(u32, @truncate(sp[1])));
        const buf_ptr: u32 = @truncate(sp[2]);
        const buf_len: u32 = @truncate(sp[3]);
        const mem = getWasmMemory(s) orelse return setRetI32(sp, -1);
        if (!boundsCheck(mem, buf_ptr, buf_len)) return setRetI32(sp, -1);
        const ret = ctx.deviceRead(report_id, mem.ptr[buf_ptr .. buf_ptr + buf_len]);
        return setRetI32(sp, ret);
    }

    fn hostDeviceWrite(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        const buf_ptr: u32 = @truncate(sp[1]);
        const buf_len: u32 = @truncate(sp[2]);
        const mem = getWasmMemory(s) orelse return setRetI32(sp, -1);
        if (!boundsCheck(mem, buf_ptr, buf_len)) return setRetI32(sp, -1);
        const ret = ctx.deviceWrite(mem.ptr[buf_ptr .. buf_ptr + buf_len]);
        return setRetI32(sp, ret);
    }

    fn hostLog(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        // void return — args start at sp[0]
        const level: i32 = @bitCast(@as(u32, @truncate(sp[0])));
        const msg_ptr: u32 = @truncate(sp[1]);
        const msg_len: u32 = @truncate(sp[2]);
        const mem = getWasmMemory(s) orelse return null;
        if (!boundsCheck(mem, msg_ptr, msg_len)) return null;
        ctx.log(level, mem.ptr[msg_ptr .. msg_ptr + msg_len]);
        return null;
    }

    fn hostGetConfig(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        const key_ptr: u32 = @truncate(sp[1]);
        const key_len: u32 = @truncate(sp[2]);
        const out_ptr: u32 = @truncate(sp[3]);
        const out_len: u32 = @truncate(sp[4]);
        const mem = getWasmMemory(s) orelse return setRetI32(sp, -1);
        if (!boundsCheck(mem, key_ptr, key_len) or !boundsCheck(mem, out_ptr, out_len))
            return setRetI32(sp, -1);
        const ret = ctx.getConfig(mem.ptr[key_ptr .. key_ptr + key_len], mem.ptr[out_ptr .. out_ptr + out_len]);
        return setRetI32(sp, ret);
    }

    fn hostSetState(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        // void return — args start at sp[0]
        const key_ptr: u32 = @truncate(sp[0]);
        const key_len: u32 = @truncate(sp[1]);
        const val_ptr: u32 = @truncate(sp[2]);
        const val_len: u32 = @truncate(sp[3]);
        const mem = getWasmMemory(s) orelse return null;
        if (!boundsCheck(mem, key_ptr, key_len) or !boundsCheck(mem, val_ptr, val_len)) return null;
        ctx.setState(mem.ptr[key_ptr .. key_ptr + key_len], mem.ptr[val_ptr .. val_ptr + val_len]);
        return null;
    }

    fn hostGetState(_: c.IM3Runtime, ic: c.IM3ImportContext, sp: [*c]u64, _: ?*anyopaque) callconv(.c) ?*const anyopaque {
        const s = pluginFromIc(ic) orelse return trapAbort();
        const ctx = s.ctx orelse return trapAbort();
        const key_ptr: u32 = @truncate(sp[1]);
        const key_len: u32 = @truncate(sp[2]);
        const out_ptr: u32 = @truncate(sp[3]);
        const out_len: u32 = @truncate(sp[4]);
        const mem = getWasmMemory(s) orelse return setRetI32(sp, -1);
        if (!boundsCheck(mem, key_ptr, key_len) or !boundsCheck(mem, out_ptr, out_len))
            return setRetI32(sp, -1);
        const key: []const u8 = mem.ptr[key_ptr .. key_ptr + key_len];
        const val = ctx.getState(key) orelse return setRetI32(sp, 0);
        const copy_len = @min(val.len, out_len);
        @memcpy(mem.ptr[out_ptr .. out_ptr + copy_len], val[0..copy_len]);
        return setRetI32(sp, @intCast(copy_len));
    }

    // -- memory helpers --

    const WasmMem = struct { ptr: [*]u8, size: u32 };

    fn getWasmMemory(s: *Wasm3Plugin) ?WasmMem {
        const rt = s.rt orelse return null;
        var size: u32 = 0;
        const ptr = c.m3_GetMemory(rt, &size, 0) orelse return null;
        return .{ .ptr = ptr, .size = size };
    }

    fn boundsCheck(mem: WasmMem, offset: u32, len: u32) bool {
        if (len == 0) return true;
        return @as(u64, offset) + @as(u64, len) <= @as(u64, mem.size);
    }

    fn memcpyToWasm(mem: WasmMem, offset: u32, src: []const u8) ?void {
        if (!boundsCheck(mem, offset, @intCast(src.len))) {
            wasm_log.warn("memcpyToWasm OOB: off={} len={} mem={}", .{ offset, src.len, mem.size });
            return null;
        }
        @memcpy(mem.ptr[offset .. offset + src.len], src);
    }

    fn memcpyFromWasm(dst: []u8, mem: WasmMem, offset: u32) ?void {
        if (!boundsCheck(mem, offset, @intCast(dst.len))) {
            wasm_log.warn("memcpyFromWasm OOB: off={} len={} mem={}", .{ offset, dst.len, mem.size });
            return null;
        }
        @memcpy(dst, mem.ptr[offset .. offset + dst.len]);
    }

    // -- host callback helpers --

    fn pluginFromIc(ic: c.IM3ImportContext) ?*Wasm3Plugin {
        const ctx = ic orelse return null;
        return @ptrCast(@alignCast(ctx.userdata));
    }

    fn setRetI32(sp: [*c]u64, val: i32) ?*const anyopaque {
        sp[0] = @bitCast(@as(i64, val));
        return null;
    }

    fn trapAbort() ?*const anyopaque {
        return @ptrCast(c.m3Err_trapAbort);
    }

    // -- trap rate limiting --

    fn handleTrap(s: *Wasm3Plugin, trap: c.M3Result) void {
        if (trap) |t| wasm_log.warn("wasm trap: {s}", .{t});
        const now = std.time.milliTimestamp();
        if (now - s.last_trap_ts > 1000) {
            s.trap_count = 1;
        } else {
            s.trap_count += 1;
        }
        s.last_trap_ts = now;
        if (s.trap_count >= 10) {
            wasm_log.err("plugin auto-unloaded: trap rate exceeded", .{});
            unload(@ptrCast(s));
        }
    }

    // -- helpers --

    fn deltaFromBytes(buf: []const u8) GamepadStateDelta {
        var d = GamepadStateDelta{};
        if (buf.len < @sizeOf(GamepadStateDelta)) return d;
        const bytes: *const [@sizeOf(GamepadStateDelta)]u8 = buf[0..@sizeOf(GamepadStateDelta)];
        d = @bitCast(bytes.*);
        return d;
    }
};

// --- tests ---

const testing = std.testing;

fn testCreate() !struct { plugin: WasmPlugin, self: *Wasm3Plugin } {
    const plugin = try Wasm3Plugin.create(testing.allocator);
    return .{ .plugin = plugin, .self = @ptrCast(@alignCast(plugin.ptr)) };
}

test "wasm3: load echo plugin succeeds" {
    const t = try testCreate();
    const plugin = t.plugin;
    const self = t.self;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/echo_plugin.wasm"), &ctx);
    try testing.expect(self.env != null);
    try testing.expect(self.rt != null);
}

test "wasm3: initDevice returns true" {
    const t = try testCreate();
    const plugin = t.plugin;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/echo_plugin.wasm"), &ctx);
    try testing.expect(plugin.initDevice());
}

test "wasm3: processReport echo round-trip returns override" {
    const t = try testCreate();
    const plugin = t.plugin;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/echo_plugin.wasm"), &ctx);
    const input = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD };
    var out: [4]u8 = undefined;
    const result = plugin.processReport(&input, &out);
    switch (result) {
        .override => {},
        else => return error.ExpectedOverride,
    }
    try testing.expectEqualSlices(u8, &input, &out);
}

test "wasm3: no exports returns false/passthrough" {
    const t = try testCreate();
    const plugin = t.plugin;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/no_exports.wasm"), &ctx);
    try testing.expect(!plugin.initDevice());
    var out: [4]u8 = undefined;
    const result = plugin.processReport(&[_]u8{ 0x01, 0x02, 0x03, 0x04 }, &out);
    try testing.expectEqual(ProcessResult.passthrough, result);
}

test "wasm3: invalid wasm bytes returns error" {
    const t = try testCreate();
    const plugin = t.plugin;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try testing.expectError(error.InvalidModule, plugin.load(&[_]u8{ 0xDE, 0xAD }, &ctx));
}

test "wasm3: unload then destroy lifecycle" {
    const t = try testCreate();
    const plugin = t.plugin;
    const self = t.self;
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/echo_plugin.wasm"), &ctx);
    plugin.unload();
    try testing.expect(self.env == null);
    try testing.expect(self.rt == null);
    plugin.destroy(testing.allocator);
}

test "wasm3: processCalibration does not crash" {
    const t = try testCreate();
    const plugin = t.plugin;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/echo_plugin.wasm"), &ctx);
    plugin.processCalibration(&[_]u8{ 0x01, 0x02, 0x03, 0x04 });
}

test "wasm3: trap in processReport returns drop" {
    const t = try testCreate();
    const plugin = t.plugin;
    const self = t.self;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/trap_plugin.wasm"), &ctx);
    var out: [4]u8 = undefined;
    const result = plugin.processReport(&[_]u8{ 0x01, 0x02, 0x03, 0x04 }, &out);
    try testing.expectEqual(ProcessResult.drop, result);
    try testing.expectEqual(@as(u32, 1), self.trap_count);
}

test "wasm3: trap rate-limiting auto-unloads plugin" {
    const t = try testCreate();
    const plugin = t.plugin;
    const self = t.self;
    defer plugin.destroy(testing.allocator);
    var ctx = HostContext.init(testing.allocator);
    defer ctx.deinit();
    try plugin.load(@embedFile("../../tests/wasm/trap_plugin.wasm"), &ctx);
    var out: [4]u8 = undefined;
    const input = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    // First call: resets trap_count to 1 (last_trap_ts was 0).
    // Subsequent rapid calls: accumulate within 1s window.
    // At trap_count >= 10, handleTrap auto-unloads.
    for (0..10) |_| {
        _ = plugin.processReport(&input, &out);
    }
    try testing.expect(self.env == null);
    try testing.expect(self.rt == null);
    // After unload, fn_proc is null so processReport returns passthrough.
    const result = plugin.processReport(&input, &out);
    try testing.expectEqual(ProcessResult.passthrough, result);
}
