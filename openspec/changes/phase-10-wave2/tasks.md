# Tasks: Phase 10 Wave 2 — Code Quality Fixes (T6-T11)

Branch: `fix/phase-10-wave2`
Commit: (leave blank -- filled after implementation)

## Execution Plan

All 6 tasks are independent — can be implemented in any order or in parallel.
Within each task, sub-steps are sequential.

---

## T6: Supervisor teardownManaged() Extraction

### T6a: Extract private function

- [ ] Add `teardownManaged` method to `Supervisor`:
  ```zig
  fn teardownManaged(self: *Supervisor, m: *ManagedInstance) void {
      m.instance.deinit();
      self.allocator.destroy(m.instance);
      m.mapping_arena.deinit();
      self.allocator.free(m.phys_key);
      if (m.devname) |dn| self.allocator.free(dn);
  }
  ```

### T6b: Replace all 4 duplicate sites

- [ ] `deinit`: replace 5-line loop body with `self.teardownManaged(m)`
- [ ] `detach`: replace 5-line block after `m.thread.join()` with
  `self.teardownManaged(m)` (keep `m.instance.stop()`, `m.thread.join()`,
  and `self.managed.swapRemove(i)` at call site)
- [ ] `reload` removal loop: replace 5-line block after `m.thread.join()` with
  `self.teardownManaged(m)` (keep `m.instance.stop()`, `m.thread.join()`,
  and `self.managed.swapRemove(idx)` at call site)
- [ ] `stopAll`: replace 5-line block in final loop with `self.teardownManaged(m)`

---

## T7: Supervisor doReload() Extraction

### T7a: Extract private method

- [ ] Add `doReload` method to `Supervisor`:
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

### T7b: Replace both call sites in run()

- [ ] SIGHUP handler (pollfds[1] block): drain hup_fd, call `self.doReload(reloadFn, reload_allocator, initFn)`
- [ ] Debounce handler (pollfds[4] block): drain debounce_fd, call `self.doReload(reloadFn, reload_allocator, initFn)`

---

## T8: WASM deltaFromBytes @bitCast Safety

### T8a: Add SAFETY comment

- [ ] Add `// SAFETY:` comment above the `@bitCast` line in `deltaFromBytes`:
  ```zig
  // SAFETY: GamepadStateDelta is a flat struct of optional numeric primitives.
  // @bitCast is valid because the WASM plugin writes matching layout.
  // If GamepadStateDelta gains padding-sensitive fields, replace with field-by-field copy.
  ```

### T8b: Add comptime assertion

- [ ] Add comptime block in `Wasm3Plugin` or at file scope:
  ```zig
  comptime {
      // If this fails, deltaFromBytes @bitCast may be invalid — review padding.
      std.debug.assert(@sizeOf(GamepadStateDelta) == @bitSizeOf(GamepadStateDelta) / 8);
  }
  ```

---

## T9: OutputDevice.VTable anyerror -> Precise Error Sets

### T9a: Define error sets

- [ ] Add in `src/io/uinput.zig` before `OutputDevice`:
  ```zig
  pub const EmitError = error{ WriteFailed, DeviceGone };
  pub const PollFfError = error{ ReadFailed, DeviceGone };
  ```

### T9b: Update VTable signatures

- [ ] Change `OutputDevice.VTable.emit` return type from `anyerror!void` to `EmitError!void`
- [ ] Change `OutputDevice.VTable.poll_ff` return type from `anyerror!?FfEvent` to `PollFfError!?FfEvent`

### T9c: Update UinputDevice implementations

- [ ] Update `UinputDevice.emit` return type to `EmitError!void`
  - Map posix write errors to `EmitError.WriteFailed` or `EmitError.DeviceGone`
- [ ] Update `UinputDevice.pollFf` return type to `PollFfError!?FfEvent`
  - Map posix read errors to `PollFfError.ReadFailed` or `PollFfError.DeviceGone`

### T9d: Update AuxOutputDevice VTable (if anyerror)

- [ ] Change `AuxOutputDevice.VTable.emit_aux` return type from `anyerror!void` to
  `EmitError!void` (reuse same error set — same I/O semantics)

### T9e: Update all mock implementations

- [ ] Update `NoopOutput` in `event_loop.zig` test section: match new return types
- [ ] Update any mock in `test/mock_output.zig` if present: match new return types
- [ ] Verify all vtable implementors compile with the narrowed error sets

---

## T10: EFD Constants + Inline @import + Dead moveTo

### T10a: Add EFD constants to ioctl_constants.zig

- [ ] Add to `src/io/ioctl_constants.zig`:
  ```zig
  pub const EFD_CLOEXEC: u32 = 0o2000000;
  pub const EFD_NONBLOCK: u32 = 0o4000;
  ```

### T10b: Update event_loop.zig

- [ ] Remove local `EFD_CLOEXEC` / `EFD_NONBLOCK` definitions from `initManaged`
- [ ] Import from ioctl_constants (add import if not present, or use existing)
- [ ] Replace usages with `ioctl.EFD_CLOEXEC` / `ioctl.EFD_NONBLOCK`
  (or appropriate import alias)

### T10c: Update supervisor.zig

- [ ] Remove local `EFD_CLOEXEC` / `EFD_NONBLOCK` definitions from `initForTest`
- [ ] Replace usages with `ioctl.EFD_CLOEXEC` / `ioctl.EFD_NONBLOCK`
  (ioctl_constants already imported as `ioctl`)

### T10d: Fix inline @import in event_loop.zig

- [ ] Add top-level `const` declarations for types used inline:
  ```zig
  const AuxOutputDevice = @import("io/uinput.zig").AuxOutputDevice;
  const TouchpadOutputDevice = @import("io/uinput.zig").TouchpadOutputDevice;
  const GamepadStateDelta = state.GamepadStateDelta;
  ```
- [ ] Replace all inline `@import(...)` references in `EventLoopContext` struct
  fields and function bodies with the named constants
- [ ] Replace inline `@import` in test section with top-level test-block consts

### T10e: Remove dead moveTo in render.zig

- [ ] Delete `moveTo` function definition (lines 17-19)
- [ ] Delete `_ = moveTo;` suppression line (line 214 in `renderFrame`)

---

## T11: Supervisor attachWithInstance errdefer Rollback

### T11a: Add errdefer after devname_map.put

- [ ] In `attachWithInstance`, after `try self.devname_map.put(dev_copy, phys_copy);`,
  add errdefer to remove the map entry if `spawnInstance` fails:
  ```zig
  try self.devname_map.put(dev_copy, phys_copy);
  errdefer {
      // put succeeded but spawnInstance failed — remove stale map entry.
      // Memory for dev_copy/phys_copy freed by the errdefers above.
      _ = self.devname_map.fetchRemove(dev_copy);
  }
  try self.spawnInstance(phys_key, instance);
  ```

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/phase-10.md` T6-T11 status checkboxes
