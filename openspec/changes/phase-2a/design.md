# Design: Phase 2a — Layer System + Suppress/Inject Pipeline

## Overview

Phase 2a introduces the `Mapper` struct as the central processing unit, replacing `Remap`. All design decisions are backed by `planning/phase-2a.md` (D1–D6) and validated against vader5's `gamepad.cpp`.

---

## Data Structures

### MappingConfig / LayerConfig (`src/config/mapping.zig`)

```zig
pub const LayerConfig = struct {
    name: []const u8,
    trigger: []const u8,
    activation: ?[]const u8 = null,  // "hold" | "toggle"; default "hold"
    tap: ?[]const u8 = null,         // RemapTarget string for Hold quick-tap
    hold_timeout: ?u32 = null,       // ms; range [1, 5000]; default 200
    remap: ?toml.HashMap([]const u8) = null,
    // Phase 2b: gyro / stick_left / stick_right / dpad override fields
};

pub const MappingConfig = struct {
    name: ?[]const u8 = null,
    remap: ?toml.HashMap([]const u8) = null,
    layer: ?[]LayerConfig = null,  // ordered array; declaration order = priority (ADR-004)
};
```

Config validation on load:
- `trigger` required; missing → `error.InvalidConfig`
- `activation` must be `"hold"` or `"toggle"`; other value → `error.InvalidConfig`
- `hold_timeout` in `[1, 5000]` ms
- `tap` string parsed through `resolveTarget()` (same as `[remap]` values)
- Duplicate `name` → `error.InvalidConfig`

TOML syntax uses `[[layer]]` ordered array (not `[layer.<name>]` table) to guarantee insertion-order priority per ADR-004, consistent with `[[report]]` and `[[device.interface]]`.

---

### LayerState / TapHoldState (`src/core/layer.zig`)

```zig
pub const TapHoldState = struct {
    layer_name: []const u8,
    layer_activated: bool = false,
};

pub const LayerState = struct {
    tap_hold: ?TapHoldState = null,       // non-null while a Hold trigger is PENDING or ACTIVE
    toggled: std.StringHashMap(void),     // set of active Toggle layer names

    pub fn getActive(
        self: *const LayerState,
        configs: []const LayerConfig,
    ) ?*const LayerConfig;
};
```

`getActive()` priority order:
1. If `tap_hold != null` and `tap_hold.layer_activated == true` → return the matching `LayerConfig`
2. Iterate `configs` in declaration order; return first whose `name` is in `toggled`
3. Return `null` (base layer)

`toggled` keys reference strings owned by `LayerConfig` (no copy needed).

---

### Mapper (`src/core/mapper.zig`)

```zig
pub const Mapper = struct {
    config: *const MappingConfig,
    layer: LayerState,
    state: GamepadState,      // current frame (fully resolved)
    prev: GamepadState,       // previous frame (used for differential)
    gyro: GyroProcessor,
    stick_left: StickProcessor,
    stick_right: StickProcessor,
    suppressed_buttons: u32,
    injected_buttons: u32,
    timer_fd: std.posix.fd_t,
    allocator: std.mem.Allocator,

    pub fn init(
        config: *const MappingConfig,
        timer_fd: std.posix.fd_t,
        allocator: std.mem.Allocator,
    ) !Mapper;

    pub fn deinit(self: *Mapper) void;

    pub fn apply(
        self: *Mapper,
        delta: GamepadStateDelta,
    ) !OutputEvents;

    pub fn onTimerExpired(self: *Mapper) void;
};
```

`apply()` implements the 7-step pipeline (see below). `onTimerExpired()` is called by `EventLoop` when the timerfd fires; it advances any PENDING Hold layer to ACTIVE.

---

### OutputEvents

```zig
pub const OutputEvents = struct {
    gamepad: GamepadState,    // assembled emit state for differential send
    aux: []const AuxEvent,    // immediate keyboard/mouse events
};

pub const AuxEvent = union(enum) {
    key: struct { code: u16, pressed: bool },
    mouse_button: struct { code: u16, pressed: bool },
    rel: struct { code: u16, value: i32 },  // new in Phase 2a
};
```

---

### GyroProcessor (`src/core/gyro.zig`)

```zig
pub const GyroConfig = struct {
    mode: []const u8 = "off",       // "off" | "mouse" | "joystick"
    sensitivity_x: f32 = 1.5,
    sensitivity_y: f32 = 1.5,
    deadzone: i16 = 0,
    smoothing: f32 = 0.3,           // EMA coefficient; 0.0 = no smoothing
    curve: f32 = 1.0,               // exponent; 1.0 = linear
    invert_x: bool = false,
    invert_y: bool = false,
};

pub const GyroOutput = struct {
    rel_x: i32,   // mouse mode: REL_X delta (0 if mode != "mouse")
    rel_y: i32,
    joy_x: ?i16,  // joystick mode: right_x override (null if mouse mode)
    joy_y: ?i16,
};

pub const GyroProcessor = struct {
    ema_x: f32 = 0,
    ema_y: f32 = 0,
    accum_x: f32 = 0,
    accum_y: f32 = 0,

    pub fn process(
        self: *GyroProcessor,
        cfg: *const GyroConfig,
        gx: i16,
        gy: i16,
        gz: i16,
    ) GyroOutput;
};
```

Algorithm pipeline (from vader5 `gamepad.cpp:434–502`, research §4.1):
1. deadzone: `if @abs(val) < cfg.deadzone then val = 0`
2. EMA: `ema = ema * cfg.smoothing + val * (1 - cfg.smoothing)`
3. curve: `@sign(val) * std.math.pow(f32, @abs(val), cfg.curve)`
4. scale: `* cfg.sensitivity_x/y * GYRO_SCALE` (0.001)
5. invert: `if cfg.invert_x then dx = -dx`
6. sub-pixel accumulation: `accum += scaled; delta = @trunc(accum); accum -= delta`

Phase 2a state: `mode="off"` → `process()` returns `GyroOutput{ .rel_x=0, .rel_y=0, .joy_x=null, .joy_y=null }` without suppressing any axis.

---

### StickProcessor (`src/core/stick.zig`)

```zig
pub const StickConfig = struct {
    mode: []const u8 = "gamepad",   // "gamepad" | "mouse" | "scroll"
    deadzone: i16 = 128,
    sensitivity: f32 = 1.0,
    suppress_gamepad: bool = false,
};

pub const StickOutput = struct {
    rel_x: i32 = 0,    // mouse mode: REL_X
    rel_y: i32 = 0,    // mouse mode: REL_Y
    wheel: i32 = 0,    // scroll mode: REL_WHEEL
    hwheel: i32 = 0,   // scroll mode: REL_HWHEEL
};

pub const StickProcessor = struct {
    mouse_accum_x: f32 = 0,
    mouse_accum_y: f32 = 0,
    scroll_accum: f32 = 0,

    pub fn process(
        self: *StickProcessor,
        cfg: *const StickConfig,
        axis_x: i16,
        axis_y: i16,
        dt_ms: u32,
    ) StickOutput;
};
```

- mouse mode: `rel = axis * cfg.sensitivity * dt_ms / 16` (16 ms normalisation, research §5.1)
- scroll mode: `accum += axis * SCROLL_SCALE * cfg.sensitivity; step = @trunc(accum); accum -= step`
- gamepad mode: returns zero `StickOutput`; `suppress_gamepad` has no effect

Phase 2a state: `mode="gamepad"` → `process()` returns zeroed `StickOutput`; axis values pass through unchanged.

---

## 7-Step Suppress/Inject Pipeline

`Mapper.apply()` executes these steps in order each frame.

```
[1] applyDelta(self.state, delta)
    Merge incoming delta fields into self.state (null fields = keep previous value).

[2] layer.processLayerTriggers(self.state, self.timer_fd)
    For each LayerConfig in declaration order:
      Hold: trigger press → PENDING (arm timerfd); timeout → ACTIVE; release → tap or exit
      Toggle: trigger release → add/remove from toggled set; clear tap_hold on Toggle activate
    Mutual exclusion: if getActive() != null and trigger != active layer's trigger → skip

[3] mode processing (Phase 2b stub)
    DPad arrows: suppress DPad bits; inject KEY_UP/DOWN/LEFT/RIGHT to aux (T10)
    GyroProcessor.process() stub → zero output; no suppress
    StickProcessor.process() stub → zero output; no suppress

[4] processBaseRemaps(self)
    For each rule in config.remap:
      suppressed_buttons |= src_mask
      inject target (see RemapTarget below)

[5] processLayerRemaps(self)
    If getActive() != null:
      For each rule in active_layer.remap:
        suppressed_buttons |= src_mask
        inject target (overrides step [4] for same button)

[6] assemble emit_state
    emit_state.buttons = (self.state.buttons & ~suppressed_buttons) | injected_buttons
    Suppressed axes zeroed.
    Aux event list accumulated from steps [3]–[5].

[7] differential
    Apply same suppressed_buttons/injected_buttons mask to self.prev before comparison.
    Generate uinput events for changed fields only.
    self.prev = self.state  (raw, before masking — masking is recomputed each frame)
```

Suppress/inject priority rules (from `engineering/mapper.md`):
- **suppress**: OR-accumulate; once set cannot be cleared by a later step — `suppressed |= new_bit`
- **inject**: last-write wins — step [5] layer remap overrides step [4] base remap for same button

prev-frame masking rationale (D6): if button B is pressed in frame N-1 and a layer activates in frame N suppressing B, the differential must see B as "was suppressed before, still suppressed" (no change) rather than "was pressed, now suppressed" (spurious release). Applying current-frame masks to `prev` before diffing achieves this.

---

## RemapTarget Resolution

```zig
pub const RemapTarget = union(enum) {
    key: u16,
    mouse_button: u16,
    gamepad_button: ButtonId,
    disabled,
};
```

Injection behaviour:
- `key` / `mouse_button`: append `AuxEvent` with current pressed state
- `gamepad_button`: set/clear corresponding bit in `injected_buttons`
- `disabled`: suppress source only; no inject

Tap event injection (Hold mode, quick release):
- `gamepad_button` tap: inject press bit this frame; force release bit next frame
- `key` / `mouse_button` tap: emit press + release as back-to-back `AuxEvent` pairs in the same aux event batch

---

## Layer Activation State Machine

### Hold mode

```
IDLE ──[trigger pressed]──────────────────► PENDING  (arm timerfd)
PENDING ──[timerfd expired]───────────────► ACTIVE   (layer_activated = true)
PENDING ──[trigger released, tap != null]─► IDLE + emit tap event  (disarm timerfd)
PENDING ──[trigger released, tap == null]─► IDLE     (disarm timerfd)
ACTIVE  ──[trigger released]──────────────► IDLE
```

Two simultaneous Hold triggers: mutual exclusion — second trigger's press is ignored while any layer is ACTIVE or another is PENDING.

### Toggle mode

```
release(trigger):
  if toggled.contains(layer.name):
    toggled.remove(layer.name)
  else if getActive() == null:
    toggled.put(layer.name)
    tap_hold = null; disarm timerfd  // clears any concurrent Hold PENDING state
```

### timerfd integration (`src/event_loop.zig` / `src/main.zig`)

Phase 1 reserved a timerfd slot in `pollfds[MAX_FDS]` without creating the fd. Phase 2a activates it:

```zig
// EventLoop.init() additions:
const timer_fd = try std.posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true, .NONBLOCK = true });
loop.pollfds[loop.fd_count] = .{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 };
loop.fd_count += 1;
loop.timer_fd = timer_fd;

// arm (one-shot):
pub fn armTimer(fd: std.posix.fd_t, timeout_ms: u32) !void  // sets itimerspec; it_interval = 0

// disarm:
pub fn disarmTimer(fd: std.posix.fd_t) !void                 // sets itimerspec to zero

// ppoll dispatch: timer_fd ready → read 8 bytes → mapper.onTimerExpired()
```

`EventLoop.run()` gains a `mapper: *Mapper` parameter. `timer_fd` is stored in `Mapper` during `init()` and used internally by `apply()`; it is not passed as a parameter each frame. When timerfd fires, `mapper.onTimerExpired()` is called before the next regular frame.

---

## AuxDevice EV_REL Extension (`src/io/uinput.zig`)

Capability registration appended to `AuxDevice.create()` after existing `EV_KEY` setup:

```zig
try ioctlInt(fd, UI_SET_EVBIT, c.EV_REL);
for ([_]u16{ c.REL_X, c.REL_Y, c.REL_WHEEL, c.REL_HWHEEL }) |code| {
    try ioctlInt(fd, UI_SET_RELBIT, @intCast(code));
}
```

`AuxDevice.emitAux()` gains a `rel` branch: send `EV_REL` event only when `value != 0`; each aux event batch ends with a single `SYN_REPORT`.

Existing `EV_KEY` / `mouse_button` handling is unchanged.

---

## DPad Arrows Mode (`src/core/mapper.zig`, step [3])

```zig
pub const DpadConfig = struct {
    mode: []const u8 = "gamepad",  // "gamepad" | "arrows"
    suppress_gamepad: bool = false,
};

fn processDpad(
    dpad_x: i8,
    dpad_y: i8,
    prev_dpad_x: i8,
    prev_dpad_y: i8,
    cfg: *const DpadConfig,
    aux: *AuxEventList,
    suppressed_buttons: *u32,
) void;
```

`arrows` mode logic:
- Suppress DPad: if `suppress_gamepad` → suppress ABS_HAT0X/Y (hat type) or BTN_DPAD_* bits (buttons type)
- Edge detection on (dpad_x, dpad_y) against prev values to emit KEY_UP/DOWN/LEFT/RIGHT press/release
- DPad is a level signal; track previous value to avoid duplicate press/release events

`effectiveDpad()` checks active layer for a `dpad` override before falling back to `config.dpad` (Phase 2b field; Phase 2a uses base config only).

---

## Layer Override Inheritance

Each configuration domain (remap, gyro, stick_left, stick_right, dpad) overrides independently:

```zig
fn effectiveRemap(self: *const Mapper) ?*const toml.HashMap([]const u8) {
    if (self.layer.getActive(self.config.layer orelse &.{})) |l| {
        if (l.remap) |*r| return r;
    }
    return if (self.config.remap) |*r| r else null;
}
```

Layer remap overrides individual buttons; buttons not present in the active layer's remap fall through to the base remap.

---

## Build Changes

- Remove `src/core/remap.zig` module from `build.zig`; add `src/core/mapper.zig`, `src/core/layer.zig`, `src/core/gyro.zig`, `src/core/stick.zig`
- `src/main.zig` call site: replace `Remap` initialisation with `Mapper.init(config, allocator)`; pass `mapper` (not `timer_fd`) to `EventLoop.run()`
- New integration test file: `src/test/integration/phase2a.zig` (L1 CI tests + L2 `error.SkipZigTest` guards)
