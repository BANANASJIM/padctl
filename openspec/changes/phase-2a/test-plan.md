# Test Plan: Phase 2a — Layer System + Suppress/Inject Pipeline

Layer labels: **L0** = pure functions, always CI; **L1** = mock fd/vtable, always CI; **L2** = UHID + real uinput, local manual.

---

## 1. MappingConfig / LayerConfig Parsing (L0)

### 1.1 Valid two-layer config parses in declaration order

Input TOML:
```toml
[[layer]]
name = "aim"
trigger = "LT"
activation = "hold"
tap = "LT"
hold_timeout = 150

[[layer]]
name = "fn"
trigger = "Select"
activation = "toggle"

[layer.remap]
A = "KEY_F1"
```

Expected: `config.layer` has length 2; `layer[0].name = "aim"`, `layer[1].name = "fn"`; `layer[0].hold_timeout = 150`; `layer[1].remap["A"] = "KEY_F1"`.

### 1.2 Missing trigger field

Input: `[[layer]]` block without `trigger`. Expected: `error.InvalidConfig`.

### 1.3 Invalid activation value

Input: `activation = "latch"`. Expected: `error.InvalidConfig`.

### 1.4 hold_timeout out of range

Input: `hold_timeout = 0`. Expected: `error.InvalidConfig`.
Input: `hold_timeout = 5001`. Expected: `error.InvalidConfig`.

### 1.5 Duplicate layer name

Two `[[layer]]` blocks with `name = "aim"`. Expected: `error.InvalidConfig`.

### 1.6 Tap field with mouse target

Input: `tap = "mouse_left"`. Expected: `layer.tap` resolves to `RemapTarget.mouse_button`.

---

## 2. LayerState / TapHoldState (L0)

### 2.1 getActive() with no active layers

Fresh `LayerState` with `tap_hold = null` and empty `toggled`. Expected: `getActive()` returns `null`.

### 2.2 Hold-ACTIVE layer returned before toggled layer

Set `tap_hold = .{ .layer_name = "aim", .layer_activated = true }` and `toggled.put("fn")`. Two configs declared: aim first, fn second. Expected: `getActive()` returns the `aim` config.

### 2.3 Toggle priority follows declaration order

`toggled` contains both `"fn"` and `"aim"`. Configs declared: `aim` first, `fn` second. Expected: `getActive()` returns `aim`.

### 2.4 Toggle layer activation and deactivation

- Call `processLayerTriggers` with Select released (prev pressed, current released)
- Expected: `toggled` contains `"fn"`, `getActive()` returns fn config
- Call again with Select released again
- Expected: `toggled` is empty, `getActive()` returns `null`

---

## 3. Tap-Hold State Machine (L0/L1)

### 3.1 Quick release → tap event (L0)

- Call `onTriggerPress("aim", ...)`
- Call `onTriggerRelease("aim", ...)` before `onTimerExpired()`
- Expected: returns `RemapTarget` for tap (LT); `tap_hold = null`

### 3.2 Timeout → layer activates (L1 mock timerfd)

- Call `onTriggerPress("aim", timer_fd, 200)`
- Simulate timerfd ready: call `onTimerExpired()`
- Expected: `tap_hold.layer_activated = true`; `getActive()` returns aim config

### 3.3 Release after activation → no tap (L1)

- Press + timerfd expire → ACTIVE
- Call `onTriggerRelease("aim", ...)`
- Expected: returns `null` (no tap); `tap_hold = null`

### 3.4 Toggle activation clears tap_hold (L0)

- Set `tap_hold = .{ .layer_name = "aim", .layer_activated = false }` (PENDING)
- Process Toggle trigger release for "fn"
- Expected: `tap_hold = null`; timerfd disarmed (verify via mock)

### 3.5 Mutual exclusion — Hold trigger ignored while another layer active (L0)

- Activate aim layer (ACTIVE)
- Attempt `onTriggerPress("fn", ...)`
- Expected: `tap_hold` still points to aim; fn not entered

### 3.6 Timer fires after early release — stale timer is no-op (L0)

- Press aim trigger → PENDING; release aim trigger (tap_hold cleared)
- Call `onTimerExpired()`
- Expected: no state change; no crash

---

## 4. Layer Activation / Deactivation (L0)

### 4.1 Hold: press → timeout → active → release → inactive

Full cycle as per state machine diagram. Verify `getActive()` returns aim during ACTIVE; returns `null` after release.

### 4.2 Toggle: release → on; second release → off

Select trigger: press then release. Verify fn layer in `toggled`. Press then release again. Verify `toggled` empty.

### 4.3 Mutual exclusion: aim active, fn trigger ignored

Aim layer ACTIVE; press fn trigger. Expected: fn layer does not appear in `toggled`, `tap_hold` unchanged.

### 4.4 Declaration order: aim before fn, both toggled → aim wins

Both in `toggled`; aim declared first. Expected: `getActive()` returns aim.

---

## 5. Suppress/Inject Pipeline (L0)

### 5.1 Base remap: M1 → KEY_F13

Config: `remap = { "M1": "KEY_F13" }`. Frame: M1 pressed. Expected:
- `OutputEvents.gamepad.buttons` has M1 bit clear
- `OutputEvents.aux` contains `AuxEvent.key{ .code = KEY_F13, .pressed = true }`

### 5.2 Base remap: disabled — source suppressed, no inject

Config: `remap = { "M2": "disabled" }`. Frame: M2 pressed. Expected:
- M2 bit clear in `gamepad.buttons`
- `aux` is empty

### 5.3 Layer remap overrides base remap for same button (step [5] > step [4])

Config: base `remap = { "RB": "KEY_F1" }`, layer aim `remap = { "RB": "mouse_left" }`. Aim layer active. Expected:
- `aux` contains `mouse_button{ .code = BTN_LEFT, .pressed = true }` (not KEY_F1)
- RB bit clear in `gamepad.buttons`

### 5.4 Remap to gamepad_button: A → B

Config: `remap = { "A": "B" }`. Frame: A pressed. Expected: A bit clear, B bit set in `gamepad.buttons`; `aux` empty.

### 5.5 Layer remap only: button not in layer remap falls through to base remap

Config: base `remap = { "X": "KEY_SPACE" }`, layer aim `remap = { "RB": "mouse_left" }`. Aim layer active, X pressed. Expected: `aux` contains KEY_SPACE for X (base remap applies since X is not in layer remap).

### 5.6 7-step order: step [5] inject takes precedence even when step [4] ran first

Same button suppressed in step [4] and step [5]. Verify final inject target comes from step [5].

---

## 6. prev-Frame Suppress/Inject (L1)

### 6.1 Layer activates mid-frame: no spurious release event for already-held button

Setup: button B pressed in prev frame (prev.buttons has B bit set). Layer activates in current frame suppressing B.
Expected: differential sees B as suppressed in both prev and current → no release event generated for B.

### 6.2 Layer deactivates: suppressed button resumes correctly

Setup: B suppressed while layer active; layer deactivates. Expected: differential generates B press event if B is still held in hardware.

### 6.3 Raw prev is stored (unmasked), masks recomputed each frame

After two frames with different active layers, verify that `self.prev` always holds the raw hardware state, and the correct mask is applied fresh each frame before differential.

---

## 7. AuxDevice EV_REL (L1)

### 7.1 AuxDevice creation registers EV_REL capability

Mock uinput ioctl sequence. Expected: `UI_SET_EVBIT(EV_REL)` called; `UI_SET_RELBIT` called for REL_X, REL_Y, REL_WHEEL, REL_HWHEEL.

### 7.2 emitAux with rel event sends EV_REL

Call `emitAux(&[_]AuxEvent{ .{ .rel = .{ .code = REL_X, .value = 5 } } })`. Expected: one `EV_REL` event with correct code/value followed by `SYN_REPORT` in write buffer.

### 7.3 rel value = 0 is not sent

Call `emitAux` with `rel.value = 0`. Expected: no `EV_REL` event written; `SYN_REPORT` not written.

### 7.4 Mixed key + rel batch ends with single SYN_REPORT

Call `emitAux` with one `key` event and one `rel` event. Expected: two event writes followed by exactly one `SYN_REPORT`.

### 7.5 Existing EV_KEY behaviour unchanged

Emit `key` and `mouse_button` events. Expected: behaviour identical to Phase 1.

---

## 8. DPad Arrows Mode (L0/L1)

### 8.1 Arrows mode: DPad up press → KEY_UP press (L0)

Config: `dpad.mode = "arrows"`. Frame: `dpad_y = -1` (prev: 0). Expected: `aux` contains `key{ .code = KEY_UP, .pressed = true }`.

### 8.2 Arrows mode: DPad up release → KEY_UP release (L0)

Frame: `dpad_y = 0` (prev: -1). Expected: `aux` contains `key{ .code = KEY_UP, .pressed = false }`.

### 8.3 suppress_gamepad suppresses original DPad bits (L0)

Config: `dpad.mode = "arrows"`, `suppress_gamepad = true`. Expected: DPad bits absent from `gamepad.buttons` (hat type: ABS_HAT0X/Y zeroed; button type: BTN_DPAD_* bits cleared).

### 8.4 Gamepad mode: DPad passes through unchanged (L0)

Config: `dpad.mode = "gamepad"`. Frame: `dpad_y = -1`. Expected: no aux KEY events; `gamepad.dpad_y = -1` in output.

### 8.5 Layer override: base gamepad, layer arrows (L1)

Base config: `dpad.mode = "gamepad"`. Layer aim config: `dpad.mode = "arrows"`. Expected: before layer activation, DPad passes through; after aim layer activates, KEY_UP/DOWN/LEFT/RIGHT injected.

---

## 9. GyroProcessor Skeleton (L0)

### 9.1 mode=off returns zero output

`GyroProcessor.process()` with `mode="off"` and non-zero gyro input. Expected: `GyroOutput{ .rel_x=0, .rel_y=0, .joy_x=null, .joy_y=null }`.

### 9.2 Deadzone suppresses small inputs

`mode="mouse"`, `deadzone=100`. Input: `gx=50` (below deadzone). Expected: `rel_x=0`.

### 9.3 EMA with smoothing=0.0 is direct pass-through

`smoothing=0.0`: each call produces output purely from current input with no history.

### 9.4 Sub-pixel accumulator: small values accumulate to integer step

Feed `gx=10` for 10 frames (with appropriate scale). Expected: cumulative `rel_x` steps match expected integer truncation.

### 9.5 Curve exponent=2.0 produces squared output

Input above deadzone with `curve=2.0`. Verify output ≈ `input^2 * scale` (numeric tolerance ±1 due to accumulation).

---

## 10. StickProcessor Skeleton (L0)

### 10.1 mode=gamepad returns zero StickOutput

`StickProcessor.process()` with `mode="gamepad"` and non-zero axis. Expected: `StickOutput{ .rel_x=0, .rel_y=0, .wheel=0, .hwheel=0 }`.

### 10.2 dt_ms=0 returns zero output regardless of mode

`mode="mouse"`, `dt_ms=0`, non-zero axis. Expected: `rel_x=0, rel_y=0`.

### 10.3 Scroll accumulator persists across frames

`mode="scroll"`, small axis value. Feed same value across N frames. Expected: `REL_WHEEL` output appears only once enough accumulates for integer truncation.

### 10.4 Deadzone: axis below cfg.deadzone returns zero

`deadzone=128`, axis=100 (below). Expected: `rel_x=0`.

---

## 11. timerfd Integration (L1)

### 11.1 Arm → ppoll ready → read 8 bytes without blocking

Use real timerfd: arm with 10 ms, wait via ppoll (100 ms timeout), verify ready, read 8 bytes without `EAGAIN`.

### 11.2 Disarm → ppoll does not trigger

Arm timerfd, immediately disarm, ppoll with 50 ms timeout. Expected: timeout; timerfd slot not ready.

### 11.3 EventLoop fd_count increments correctly for timerfd slot

After `EventLoop.init()` with timerfd, `fd_count = 3` (signalfd + stop_pipe + timerfd). `ppoll(pollfds[0..fd_count])` does not crash.

---

## 12. End-to-End Integration (L1/L2)

### 12.1 Hold layer + layer remap (L1)

Inject LT press → call `onTimerExpired()` → inject RB press. Expected: `OutputEvents.aux` contains `mouse_left` press. Inject LT release → inject RB press. Expected: `OutputEvents.gamepad.buttons` has RB bit set (base layer, no remap active).

### 12.2 Tap shortcut (L1)

Inject LT press → inject LT release (before timeout). Expected: tap event (LT press + release) in `aux` output.

### 12.3 Toggle layer cycle (L1)

Inject Select release → verify fn layer active; inject A press → verify `KEY_F1` in `aux`. Inject Select release again → fn layer inactive; inject A press → verify A bit in `gamepad.buttons` (no aux KEY event).

### 12.4 prev-frame differential correctness (L1)

Pre-condition: button B held (in `prev.buttons`). Frame: Hold trigger press + `onTimerExpired()`. Expected: no spurious B release event in `OutputEvents`; B appears suppressed (not present in `gamepad.buttons`).

### 12.5 DPad arrows full cycle (L1)

Base config `mode="arrows"`, `suppress_gamepad=true`. Inject `dpad_y = -1` → verify `KEY_UP` press in `aux`, DPad suppressed. Inject `dpad_y = 0` → verify `KEY_UP` release.

### 12.6 Full hardware test with UHID (L2, manual)

`zig build test-e2e` (guarded: skips when `/dev/uhid` absent):
- Inject IF1 HID report with LT held
- Wait > 200 ms
- Inject RB press
- Observe `evtest` output on padctl-aux: `BTN_LEFT` press
- Release LT → observe RB restores to native gamepad output
