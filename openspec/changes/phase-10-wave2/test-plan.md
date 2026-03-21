# Phase 10 Wave 2: Test Plan — Code Quality Fixes (T6-T11)

Each test maps to a success criterion in `brief.md`.
All tasks are refactors/cleanups — no new functionality. Primary goal: verify no regressions.

## T6: teardownManaged DRY Verification

- [ ] TP1: **Existing deinit test passes** — `Supervisor.initForTest()`, add instances via
  `attachWithInstance`, call `deinit()`. No leak, no crash. Allocator reports zero outstanding.

- [ ] TP2: **Existing detach test passes** — attach then detach by devname. Instance is
  stopped, joined, and freed. devname_map entry removed.

- [ ] TP3: **Existing reload test passes** — attach instances, call `reload()` with a
  config set that removes one instance. Removed instance is torn down via `teardownManaged`.

- [ ] TP4: **stopAll test passes** — attach multiple instances, call `stopAll()`. All
  instances stopped, joined, freed. `managed` list is empty after call.

## T7: doReload DRY Verification

- [ ] TP5: **SIGHUP reload path unchanged** — existing test that triggers SIGHUP handler
  still calls `reloadFn` and applies diff via `self.reload()`.

- [ ] TP6: **Debounce reload path unchanged** — existing test that triggers debounce timer
  still calls `reloadFn` and applies diff via `self.reload()`.

- [ ] TP7: **reloadFn error is logged, loop continues** — `reloadFn` returns error.
  `doReload` logs it and returns. Supervisor loop continues (does not crash or exit).

## T8: deltaFromBytes Safety

- [ ] TP8: **Existing wasm3 processReport test passes** — echo plugin round-trip produces
  correct `.override` result with matching output bytes.

- [ ] TP9: **Comptime assertion holds** — `zig build test` compiles successfully, meaning
  `@sizeOf(GamepadStateDelta) == @bitSizeOf(GamepadStateDelta) / 8` is true.

- [ ] TP10: **deltaFromBytes short buffer returns default** — buffer shorter than
  `@sizeOf(GamepadStateDelta)` returns a zero-initialized delta. (Existing behavior,
  covered by existing tests.)

## T9: Precise Error Sets

- [ ] TP11: **UinputDevice.emit compiles with EmitError** — no `anyerror` fallback.
  The function signature uses `EmitError!void` and all internal error paths map to
  `WriteFailed` or `DeviceGone`.

- [ ] TP12: **UinputDevice.pollFf compiles with PollFfError** — no `anyerror` fallback.
  The function signature uses `PollFfError!?FfEvent`.

- [ ] TP13: **Callers compile without changes** — `event_loop.zig` uses `catch` on
  `ctx.output.emit(...)` and `ctx.output.pollFf()`. These continue to work because
  `catch` accepts any error set.

- [ ] TP14: **Noop mock in event_loop tests updated** — `NoopOutput.emit` and
  `NoopOutput.pollFf` use the new error set return types and compile.

- [ ] TP15: **AuxOutputDevice vtable updated** — if `emit_aux` used `anyerror`, it now
  uses `EmitError` (or equivalent). Existing tests compile and pass.

## T10: EFD Constants + Inline @import + Dead moveTo

### T10a: EFD Constants

- [ ] TP16: **EFD constants defined once** — `ioctl_constants.zig` contains `EFD_CLOEXEC`
  and `EFD_NONBLOCK`. No other file defines these constants locally.

- [ ] TP17: **event_loop.zig initManaged uses ioctl constants** — `initManaged` calls
  `posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK)` (or equivalent import alias).

- [ ] TP18: **supervisor.zig initForTest uses ioctl constants** — `initForTest` calls
  `posix.eventfd(0, ioctl.EFD_CLOEXEC | ioctl.EFD_NONBLOCK)`.

- [ ] TP19: **initManaged test passes** — `EventLoop.initManaged()` creates valid eventfd
  and timerfd. fd_count == 3.

- [ ] TP20: **initForTest test passes** — `Supervisor.initForTest()` creates valid stop_fd
  and hup_fd.

### T10b: Inline @import

- [ ] TP21: **No inline @import in EventLoopContext** — `EventLoopContext` struct fields
  use named top-level consts (`OutputDevice`, `AuxOutputDevice`, `TouchpadOutputDevice`),
  not `@import(...)` expressions.

- [ ] TP22: **No inline @import in run() body** — `GamepadStateDelta` references use the
  top-level const, not `@import("core/interpreter.zig").GamepadStateDelta`.

- [ ] TP23: **All event_loop.zig tests compile and pass** — no regression from import
  restructuring.

### T10c: Dead moveTo

- [ ] TP24: **moveTo function removed** — `render.zig` does not contain `fn moveTo`.

- [ ] TP25: **Suppression line removed** — `render.zig` does not contain `_ = moveTo`.

- [ ] TP26: **All render.zig tests pass** — `renderFrame` still produces correct ANSI
  output with axes, buttons, triggers, gyro, hex dump, and rumble indicator.

## T11: attachWithInstance errdefer

- [ ] TP27: **Successful attach unchanged** — `attachWithInstance` with valid devname and
  phys_key adds entry to `devname_map` and spawns instance. Existing test passes.

- [ ] TP28: **Duplicate devname is no-op** — calling `attachWithInstance` twice with same
  devname returns without error on second call. Existing test passes.

- [ ] TP29: **spawnInstance failure rolls back map** — if `spawnInstance` fails (e.g.,
  thread spawn error), `devname_map` does not contain the devname entry. The leaked-entry
  bug is fixed.

## Regression Guard

- [ ] TP30: All existing `supervisor.zig` tests pass
- [ ] TP31: All existing `wasm3_backend.zig` tests pass
- [ ] TP32: All existing `uinput.zig` tests pass
- [ ] TP33: All existing `event_loop.zig` tests pass
- [ ] TP34: All existing `render.zig` tests pass
- [ ] TP35: Full `zig build test` passes (all modules, Layer 0+1)
