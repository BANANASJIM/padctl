# Tasks: Phase 2a — Layer System + Suppress/Inject Pipeline

## Wave 0 — Data Structures (parallel)

### T1

```
id:          T1
title:       MappingConfig extension — [[layer]] TOML parsing
file:        src/config/mapping.zig
layer:       L0
depends:     none
```

Extend `MappingConfig` to support an ordered `[[layer]]` array. Add `LayerConfig` struct with fields: `name` (required), `trigger` (required), `activation` (`"hold"` | `"toggle"`; default `"hold"`), `tap` (optional RemapTarget string), `hold_timeout` (optional u32 ms; default 200), `remap` (optional button map).

Validation on load:
- `trigger` missing → `error.InvalidConfig`
- `activation` not `"hold"` or `"toggle"` → `error.InvalidConfig`
- `hold_timeout` outside `[1, 5000]` → `error.InvalidConfig`
- duplicate `name` → `error.InvalidConfig`
- `tap` value parsed via `resolveTarget()` (same rules as `[remap]` entries)

`[[layer]]` array is ordered; declaration order is preserved for ADR-004 priority.

```
commit:      T1: MappingConfig [[layer]] TOML parsing + LayerConfig validation
```

---

### T2

```
id:          T2
title:       LayerState + TapHoldState runtime structures
file:        src/core/layer.zig  (new)
layer:       L0
depends:     T1
```

Define runtime layer state; no logic beyond `getActive()`:

```zig
pub const TapHoldState = struct {
    layer_name: []const u8,
    layer_activated: bool = false,
};

pub const LayerState = struct {
    tap_hold: ?TapHoldState = null,
    toggled: std.StringHashMap(void),

    pub fn getActive(self: *const LayerState, configs: []const LayerConfig) ?*const LayerConfig;
    pub fn init(allocator: std.mem.Allocator) LayerState;
    pub fn deinit(self: *LayerState) void;
};
```

`getActive()`: Hold-ACTIVE layer (tap_hold.layer_activated == true) takes priority over any toggled layer; among toggled layers, first by config declaration order wins.

```
commit:      T2: LayerState + TapHoldState data structures, getActive()
```

---

## Wave 1 — Core State Machine (parallel, depends on T1/T2)

### T3

```
id:          T3
title:       timerfd integration into EventLoop
file:        src/event_loop.zig  (activate Phase 1 reserved slot)
layer:       L1
depends:     T2
```

In `EventLoop.init()`, create a `CLOCK_MONOTONIC | NONBLOCK | CLOEXEC` timerfd and register it in the `pollfds` array (the slot previously reserved by Phase 1). Store the fd in `EventLoop.timer_fd`.

Add helper functions:

```zig
pub fn armTimer(fd: std.posix.fd_t, timeout_ms: u32) !void;
pub fn disarmTimer(fd: std.posix.fd_t) !void;
```

Both are thin wrappers over `std.posix.timerfd_settime` with `it_interval = 0` (one-shot).

In `EventLoop.run()`, when `pollfds[timer_slot].revents & POLL.IN != 0`: read 8 bytes from `timer_fd` to consume the event, then call `mapper.onTimerExpired()`.

```
commit:      T3: activate timerfd slot in EventLoop, arm/disarm helpers
```

---

### T4

```
id:          T4
title:       Tap-hold state machine (Default strategy)
file:        src/core/layer.zig
layer:       L0/L1
depends:     T2, T3
```

Add to `LayerState`:

```zig
pub fn onTriggerPress(
    self: *LayerState,
    layer_name: []const u8,
    timer_fd: std.posix.fd_t,
    timeout_ms: u32,
) !void;

pub fn onTriggerRelease(
    self: *LayerState,
    layer_name: []const u8,
    timer_fd: std.posix.fd_t,
    configs: []const LayerConfig,
) !?RemapTarget;  // returns tap target if applicable

pub fn onTimerExpired(self: *LayerState) void;
```

State transitions (Default strategy):
- Press: if no layer currently ACTIVE → enter PENDING, arm timerfd with `hold_timeout`
- Timer expired: if PENDING → set `layer_activated = true` (ACTIVE)
- Release while PENDING and `tap != null`: disarm timerfd, return tap target, clear `tap_hold`
- Release while PENDING and `tap == null`: disarm timerfd, clear `tap_hold`; return null
- Release while ACTIVE: clear `tap_hold`; return null

Edge cases:
- Second Hold trigger press while any layer active or pending → silently ignored (mutual exclusion)
- Toggle activate clears `tap_hold` and disarms timerfd
- Timer fires after trigger already released: `tap_hold` is null → `onTimerExpired()` is a no-op

```
commit:      T4: tap-hold state machine, Default strategy
```

---

### T5

```
id:          T5
title:       Layer activation/deactivation logic
file:        src/core/layer.zig
layer:       L0
depends:     T1, T2, T4
```

Add to `LayerState`:

```zig
pub fn processLayerTriggers(
    self: *LayerState,
    configs: []const LayerConfig,
    buttons: u32,
    prev_buttons: u32,
    timer_fd: std.posix.fd_t,
) !?RemapTarget;  // returns tap RemapTarget when a tap fires
```

For each `LayerConfig` in declaration order:
1. Compute whether trigger button transitioned (pressed or released) by comparing `buttons` vs `prev_buttons`
2. Apply mutual exclusion: if `getActive()` returns non-null and this config is not the active layer → skip
3. Hold activation: delegate to `onTriggerPress` / `onTriggerRelease` / `onTimerExpired`
4. Toggle activation: on trigger release, if no active layer → `toggled.put(name)`; if already in toggled → `toggled.remove(name)` and disarm timerfd / clear `tap_hold`

`effectiveRemap()` (in `Mapper`): check active layer's `remap` first; fall through to `config.remap`.

```
commit:      T5: layer activation/deactivation, mutual exclusion, effectiveRemap
```

---

## Wave 2 — Pipeline + I/O (parallel, depends on T3–T5)

### T6

```
id:          T6
title:       Mapper — 7-step suppress/inject pipeline (replaces Remap)
file:        src/core/mapper.zig  (new, replaces src/core/remap.zig)
layer:       L0/L1
depends:     T5
```

```zig
pub const Mapper = struct {
    config: *const MappingConfig,
    layer: LayerState,
    state: GamepadState,
    prev: GamepadState,
    gyro: GyroProcessor,
    stick_left: StickProcessor,
    stick_right: StickProcessor,
    suppressed_buttons: u32,
    injected_buttons: u32,
    timer_fd: std.posix.fd_t,
    allocator: std.mem.Allocator,

    pub fn init(config: *const MappingConfig, timer_fd: std.posix.fd_t, allocator: std.mem.Allocator) !Mapper;
    pub fn deinit(self: *Mapper) void;
    pub fn apply(self: *Mapper, delta: GamepadStateDelta) !OutputEvents;
    pub fn onTimerExpired(self: *Mapper) void;
};
```

`apply()` implements the 7-step pipeline as defined in `design.md`. Key invariants:
- `suppressed_buttons` and `injected_buttons` reset to 0 at the start of each `apply()` call
- Step [5] inject overwrites step [4] inject for same button (last-write wins)
- Before differential in step [7]: `emit_prev.buttons = (self.prev.buttons & ~suppressed_buttons) | injected_buttons`
- After step [7]: `self.prev = self.state` (store raw, unmasked state)

Update `build.zig`: replace `remap.zig` with `mapper.zig`. Update `src/main.zig` call site.

```
commit:      T6: Mapper struct, 7-step suppress/inject pipeline, replaces Remap
```

---

### T7

```
id:          T7
title:       AuxDevice EV_REL capability extension
file:        src/io/uinput.zig
layer:       L1
depends:     none
```

In `AuxDevice.create()`, after existing `EV_KEY` registration:

```zig
try ioctlInt(fd, UI_SET_EVBIT, c.EV_REL);
const UI_SET_RELBIT = IOCTL.IOW('U', 102, c_int);
for ([_]u16{ c.REL_X, c.REL_Y, c.REL_WHEEL, c.REL_HWHEEL }) |code| {
    try ioctlInt(fd, UI_SET_RELBIT, @intCast(code));
}
```

Extend `AuxEvent` union:

```zig
pub const AuxEvent = union(enum) {
    key: struct { code: u16, pressed: bool },
    mouse_button: struct { code: u16, pressed: bool },
    rel: struct { code: u16, value: i32 },
};
```

In `AuxDevice.emitAux()`, add `rel` branch: emit `EV_REL` event only when `value != 0`. `SYN_REPORT` is appended once per batch regardless of mix of key/rel events.

```
commit:      T7: AuxDevice EV_REL capability, AuxEvent.rel variant
```

---

## Wave 3 — Processors + Validation (T8/T9/T10 parallel; T11 depends on T6/T7/T10)

### T8

```
id:          T8
title:       GyroProcessor skeleton
file:        src/core/gyro.zig  (new)
layer:       L0
depends:     T6
```

Implement full `GyroProcessor` interface with complete algorithm pipeline. `mode="off"` returns `GyroOutput{ .rel_x=0, .rel_y=0, .joy_x=null, .joy_y=null }` without executing any algorithm steps. Phase 2b will handle `mode="mouse"` and `mode="joystick"` activation.

`Mapper.apply()` step [3] calls `gyro_proc.process()` as a stub; when output is all-zero, no suppress is applied and no AuxEvents are added.

```
commit:      T8: GyroProcessor skeleton, full interface + mode=off stub
```

---

### T9

```
id:          T9
title:       StickProcessor skeleton
file:        src/core/stick.zig  (new)
layer:       L0
depends:     T6
```

Implement full `StickProcessor` interface. `mode="gamepad"` returns zeroed `StickOutput`; `dt_ms=0` always returns zero output regardless of mode. Sub-pixel accumulator fields (`mouse_accum_x/y`, `scroll_accum`) persist across frames and are stored in the struct.

Phase 2b activates `mode="mouse"` and `mode="scroll"`. Phase 2a stubs are no-ops.

```
commit:      T9: StickProcessor skeleton, full interface + mode=gamepad stub
```

---

### T10

```
id:          T10
title:       DPad arrows mode
file:        src/core/mapper.zig  (step [3] implementation)
layer:       L0/L1
depends:     T6
```

Add `DpadConfig` struct and `processDpad()` function. `arrows` mode:
1. Compare `(dpad_x, dpad_y)` with `(prev.dpad_x, prev.dpad_y)` for edge detection
2. Inject `KEY_UP` (dpad_y < 0), `KEY_DOWN` (dpad_y > 0), `KEY_LEFT` (dpad_x < 0), `KEY_RIGHT` (dpad_x > 0)
3. If `suppress_gamepad`: add DPad bits to `suppressed_buttons` (hat: suppress ABS_HAT0X/Y; buttons: suppress BTN_DPAD_* mask bits)

`effectiveDpad()` resolves active layer's `dpad` config (Phase 2b field; Phase 2a always returns base config).

```
commit:      T10: DPad arrows mode — suppress DPad, inject KEY_UP/DOWN/LEFT/RIGHT
```

---

### T11

```
id:          T11
title:       End-to-end integration validation
file:        src/test/integration/phase2a.zig  (new)
layer:       L1/L2
depends:     T6, T7, T10
```

L1 tests (CI, `zig build test`):

1. **Hold layer full cycle**: inject LT press → simulate timerfd expiry via `onTimerExpired()` → inject RB → verify `OutputEvents.aux` contains `mouse_left` event → inject LT release → inject RB → verify `OutputEvents.gamepad` contains RB bit (base layer active)

2. **Tap shortcut**: inject LT press → inject LT release within timeout (without calling `onTimerExpired()`) → verify tap event (LT press+release) in aux output

3. **Toggle layer**: inject Select release → verify fn layer active → inject A → verify `KEY_F1` aux event → inject Select release again → verify fn layer inactive → inject A → verify gamepad A bit (no remap)

4. **prev-frame differential**: inject B press (frame N-1, `prev.buttons |= B`) → inject Hold trigger + timerfd expiry → verify B is correctly suppressed and no spurious release event for B

5. **DPad arrows**: configure `mode="arrows"`, `suppress_gamepad=true` → inject dpad_y = -1 → verify `KEY_UP` press in aux; inject dpad_y = 0 → verify `KEY_UP` release in aux; verify DPad suppressed

L2 tests (local only, guarded by `error.SkipZigTest` when `/dev/uhid` absent):

- `zig build test-e2e`: UHID inject IF1 report → padctl processes → `evtest` observes Hold layer switch and mouse_button events

```
commit:      T11: Phase 2a end-to-end integration tests (L1 CI + L2 skip guards)
```
