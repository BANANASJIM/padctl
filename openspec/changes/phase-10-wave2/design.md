# Design: Phase 10 Wave 2 — Code Quality Fixes (T6-T11)

## Files

| File | Role |
|------|------|
| `src/supervisor.zig` | T6: extract `teardownManaged`; T7: extract `doReload`; T11: `errdefer` rollback |
| `src/wasm/wasm3_backend.zig` | T8: `deltaFromBytes` safety |
| `src/io/uinput.zig` | T9: precise error sets on `OutputDevice.VTable` |
| `src/event_loop.zig` | T10: remove inline `@import`, use `ioctl_constants.EFD_*` |
| `src/io/ioctl_constants.zig` | T10: add `EFD_CLOEXEC` / `EFD_NONBLOCK` constants |
| `src/debug/render.zig` | T10: remove dead `moveTo` function |

---

## T6: Supervisor teardownManaged() Extraction

### Problem

Teardown of a `ManagedInstance` (deinit + destroy + arena + free phys_key + free devname)
appears in 4 places: `deinit`, `detach`, `reload` (removal loop), and `stopAll`. Any change
to teardown ordering must be replicated 4 times.

### Solution

Extract a private function:

```zig
fn teardownManaged(self: *Supervisor, m: *ManagedInstance) void {
    m.instance.deinit();
    self.allocator.destroy(m.instance);
    m.mapping_arena.deinit();
    self.allocator.free(m.phys_key);
    if (m.devname) |dn| self.allocator.free(dn);
}
```

Call sites:
- `deinit`: loop body becomes `self.teardownManaged(m)`
- `detach`: replace 5-line block after `m.thread.join()` with `self.teardownManaged(m)`
- `reload` removal loop: replace 5-line block after `m.thread.join()` with `self.teardownManaged(m)`
- `stopAll`: replace 5-line block in final loop with `self.teardownManaged(m)`

Note: `m.instance.stop()` and `m.thread.join()` are NOT part of `teardownManaged` — they are
caller responsibilities with different patterns (detach stops one, stopAll stops all first then
joins all).

---

## T7: Supervisor doReload() Extraction

### Problem

The reload sequence (call `reloadFn` -> call `self.reload`) appears identically in two places
within `run()`: the SIGHUP handler (pollfds[1]) and the debounce timer handler (pollfds[4]).

### Solution

Extract a private method:

```zig
fn doReload(
    self: *Supervisor,
    reloadFn: *const fn (allocator: std.mem.Allocator) anyerror![]ConfigEntry,
    reload_allocator: std.mem.Allocator,
    initFn: *const fn (allocator: std.mem.Allocator, entry: ConfigEntry) anyerror!*DeviceInstance,
) void {
    const new_configs = reloadFn(reload_allocator) catch |err| {
        std.log.err("reload failed: {}", .{err});
        return;
    };
    defer reload_allocator.free(new_configs);
    self.reload(new_configs, initFn) catch |err| {
        std.log.err("hot-reload diff failed: {}", .{err});
    };
}
```

Both SIGHUP and debounce handlers reduce to draining their fd + calling `self.doReload(...)`.
The `continue` after `reloadFn` error becomes a `return` since we're inside a function now —
the outer `while (true)` loop continues naturally.

---

## T8: WASM deltaFromBytes @bitCast Safety

### Problem

`deltaFromBytes` in `wasm3_backend.zig` uses `@bitCast(bytes.*)` to reinterpret raw bytes as
`GamepadStateDelta`. This is correct when `GamepadStateDelta` has no padding bytes, but the
assumption is undocumented. If `GamepadStateDelta` gains bool/optional fields with padding,
`@bitCast` becomes UB.

### Current Code

```zig
fn deltaFromBytes(buf: []const u8) GamepadStateDelta {
    var d = GamepadStateDelta{};
    if (buf.len < @sizeOf(GamepadStateDelta)) return d;
    const bytes: *const [@sizeOf(GamepadStateDelta)]u8 = buf[0..@sizeOf(GamepadStateDelta)];
    d = @bitCast(bytes.*);
    return d;
}
```

### Solution

Add a `// SAFETY:` comment documenting the accepted risk and the invariant:

```zig
fn deltaFromBytes(buf: []const u8) GamepadStateDelta {
    var d = GamepadStateDelta{};
    if (buf.len < @sizeOf(GamepadStateDelta)) return d;
    const bytes: *const [@sizeOf(GamepadStateDelta)]u8 = buf[0..@sizeOf(GamepadStateDelta)];
    // SAFETY: GamepadStateDelta is a flat struct of optional numeric primitives.
    // @bitCast is valid because the WASM plugin writes matching layout.
    // If GamepadStateDelta gains padding-sensitive fields, replace with field-by-field copy.
    d = @bitCast(bytes.*);
    return d;
}
```

Rationale: `GamepadStateDelta` currently contains only `?i16` and `?bool` fields. The WASM ABI
contract requires plugins to write this exact layout. Field-by-field extraction would be safer
but adds significant complexity with no current benefit — the `// SAFETY:` comment flags the
assumption for future maintainers.

Additionally, add a comptime assertion to catch layout changes early:

```zig
comptime {
    // If this fails, deltaFromBytes @bitCast may be invalid — review padding.
    std.debug.assert(@sizeOf(GamepadStateDelta) == @bitSizeOf(GamepadStateDelta) / 8);
}
```

---

## T9: OutputDevice.VTable anyerror -> Precise Error Sets

### Problem

`OutputDevice.VTable` uses `anyerror` for `emit` and `poll_ff` return types. This discards
error information and prevents the compiler from verifying error handling completeness.

### Current Code

```zig
pub const VTable = struct {
    emit: *const fn (ptr: *anyopaque, s: state.GamepadState) anyerror!void,
    poll_ff: *const fn (ptr: *anyopaque) anyerror!?FfEvent,
    close: *const fn (ptr: *anyopaque) void,
};
```

### Solution

Define precise error sets and use them in the vtable:

```zig
pub const EmitError = error{ WriteFailed, DeviceGone };
pub const PollFfError = error{ ReadFailed, DeviceGone };

pub const VTable = struct {
    emit: *const fn (ptr: *anyopaque, s: state.GamepadState) EmitError!void,
    poll_ff: *const fn (ptr: *anyopaque) PollFfError!?FfEvent,
    close: *const fn (ptr: *anyopaque) void,
};
```

Update all vtable implementors:
- `UinputDevice.emit` return type: `EmitError!void`
- `UinputDevice.pollFf` return type: `PollFfError!?FfEvent`
- Test mocks in `event_loop.zig` and `test/mock_output.zig`: update return types

At call sites, the error type narrows from `anyerror` to the specific set. Callers that use
`catch` without matching specific errors continue to work (Zig's `catch` handles any error set).

Also apply the same pattern to `AuxOutputDevice.VTable` and `TouchpadOutputDevice.VTable`
if they exist with `anyerror`:

```zig
pub const AuxEmitError = error{ WriteFailed, DeviceGone };
```

---

## T10: EFD Constants + Inline @import + Dead moveTo

### T10a: EFD Constants Consolidation

`EFD_CLOEXEC` and `EFD_NONBLOCK` are defined as local constants in two places:
- `event_loop.zig` line 152-153 (`initManaged`)
- `supervisor.zig` line 135-136 (`initForTest`)

Move to `src/io/ioctl_constants.zig`:

```zig
pub const EFD_CLOEXEC: u32 = 0o2000000;
pub const EFD_NONBLOCK: u32 = 0o4000;
```

Update both files to import from `ioctl_constants`:
- `event_loop.zig`: `const ioctl = @import("io/ioctl_constants.zig");` (already used for
  other constants if present, otherwise add)
- `supervisor.zig`: already imports `ioctl_constants` as `ioctl`

Replace local definitions with `ioctl.EFD_CLOEXEC` / `ioctl.EFD_NONBLOCK`.

### T10b: Inline @import Cleanup in event_loop.zig

Several lines use `@import(...)` inline in type annotations and expressions instead of
top-level `const` declarations:

| Line | Current | Fix |
|------|---------|-----|
| 56 | `output: @import("io/uinput.zig").OutputDevice` | Use existing `OutputDevice` const |
| 58 | `aux_output: ?@import("io/uinput.zig").AuxOutputDevice` | Add top-level const, use it |
| 59 | `touchpad_output: ?@import("io/uinput.zig").TouchpadOutputDevice` | Add top-level const, use it |
| 319 | `?@import("core/interpreter.zig").GamepadStateDelta` | Use `state.GamepadStateDelta` (already imported via `state`) |
| ~404,427,431 | Various test-only inline `@import` | Add top-level consts in test block |

Add missing top-level imports:

```zig
const AuxOutputDevice = @import("io/uinput.zig").AuxOutputDevice;
const TouchpadOutputDevice = @import("io/uinput.zig").TouchpadOutputDevice;
const GamepadStateDelta = state.GamepadStateDelta;
```

Replace all inline `@import` references with these named constants.

### T10c: Dead moveTo Removal in render.zig

`moveTo` (line 17-19) is defined but only referenced on line 214 via `_ = moveTo;` (an
explicit "suppress unused" pattern). The comment says "used in non-clearScreen rendering path
if needed" — but no such path exists. Both the function and the suppression line are dead code.

Remove:
1. The `moveTo` function definition (lines 17-19)
2. The `_ = moveTo;` suppression (line 214)

---

## T11: Supervisor attachWithInstance errdefer Rollback

### Problem

In `attachWithInstance`, after `devname_map.put` succeeds, if `spawnInstance` fails the map
entry remains — a leaked stale entry that blocks future attach attempts for the same devname.

### Current Code

```zig
pub fn attachWithInstance(self: *Supervisor, devname: []const u8, phys_key: []const u8, instance: *DeviceInstance) !void {
    if (self.devname_map.contains(devname)) return;
    const dev_copy = try self.allocator.dupe(u8, devname);
    errdefer self.allocator.free(dev_copy);
    const phys_copy = try self.allocator.dupe(u8, phys_key);
    errdefer self.allocator.free(phys_copy);
    try self.devname_map.put(dev_copy, phys_copy);
    try self.spawnInstance(phys_key, instance);  // if this fails, map entry leaks
}
```

### Solution

Add an errdefer after `put` to remove the entry on failure:

```zig
try self.devname_map.put(dev_copy, phys_copy);
errdefer {
    _ = self.devname_map.fetchRemove(dev_copy);
    // dev_copy and phys_copy freed by earlier errdefers
}
try self.spawnInstance(phys_key, instance);
```

Note: the earlier `errdefer self.allocator.free(dev_copy)` and `errdefer self.allocator.free(phys_copy)`
handle memory deallocation. The new errdefer only needs to remove the map entry. However,
since `put` transfers ownership of the key/value pointers to the map, and `fetchRemove`
returns them, we need to adjust: remove the earlier `errdefer free` for `dev_copy`/`phys_copy`
and instead free them via the fetchRemove result:

```zig
pub fn attachWithInstance(self: *Supervisor, devname: []const u8, phys_key: []const u8, instance: *DeviceInstance) !void {
    if (self.devname_map.contains(devname)) return;
    const dev_copy = try self.allocator.dupe(u8, devname);
    errdefer self.allocator.free(dev_copy);
    const phys_copy = try self.allocator.dupe(u8, phys_key);
    errdefer self.allocator.free(phys_copy);
    try self.devname_map.put(dev_copy, phys_copy);
    errdefer {
        // put succeeded but spawnInstance failed — remove stale map entry.
        // Memory for dev_copy/phys_copy freed by the errdefers above.
        _ = self.devname_map.fetchRemove(dev_copy);
    }
    try self.spawnInstance(phys_key, instance);
}
```

Wait — `StringHashMap.put` does NOT take ownership of the key/value memory in the sense of
freeing earlier errdefers. The errdefer stack unwinds in reverse order: first the map removal
errdefer fires (removing the entry), then the `phys_copy` free, then the `dev_copy` free. The
key/value pointers in the map are the same as `dev_copy`/`phys_copy`, so `fetchRemove` returns
them but we don't need to free them separately — the earlier errdefers do that. This is correct.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | `teardownManaged` does NOT include `stop()` or `join()` | Stop/join patterns differ across call sites (single vs batch). Teardown is purely cleanup after join. |
| D2 | `doReload` is a method, not a free function | Needs `self` for `self.reload()`. Keeps it co-located with `run()`. |
| D3 | `@bitCast` kept with SAFETY comment, not replaced | Field-by-field copy adds complexity with no current benefit. Comptime assertion guards against layout drift. |
| D4 | Named error sets on vtable, not error union | Named sets (`EmitError`, `PollFfError`) are self-documenting and enable exhaustive switching at call sites. |
| D5 | EFD constants in `ioctl_constants.zig` | Single source of truth for all Linux ioctl/eventfd constants. Both `event_loop.zig` and `supervisor.zig` already import this module. |
| D6 | Remove `moveTo` entirely, not just the suppression | No rendering path uses cursor positioning. If needed later, it can be re-added. Dead code should not accumulate. |
