# Phase 2a Brief: Mapping Core — Layer System + Suppress/Inject Pipeline

## Why

Phase 1 delivers a pass-through gamepad forwarder: `Remap.apply()` does simple
button substitution by directly mutating `GamepadState`, with no concept of
layers or suppress/inject separation.

Phase 2a transforms padctl into a **programmable input device**. Users can:
- Hold a trigger to activate a remapping layer (e.g., hold LT → aim layer,
  RB becomes mouse_left)
- Toggle layers with a single button release (fn layer: A→F1, B→F2)
- Quick-tap a hold-trigger to emit a tap event instead of activating the layer
- Route DPad directions to keyboard arrow keys

The key architectural shift: `Remap` (in-place mutation) is replaced by
`Mapper` (explicit suppress/inject masks + layer state machine). This separation
is required for correct prev-frame diffing across layer transitions, and is the
foundation for Phase 2b gyro/stick modes.

## Scope: T1–T11

| Task | Summary |
|------|---------|
| T1 | Extend `MappingConfig` with `[[layer]]` ordered-array TOML parsing |
| T2 | Runtime data structures: `LayerState`, `TapHoldState` (data only, no logic) |
| T3 | Activate Phase 1's reserved timerfd slot in `EventLoop` |
| T4 | Tap-hold state machine (Default strategy: timeout → hold, early release → tap) |
| T5 | Layer activation/deactivation logic (Hold/Toggle, mutual exclusion ADR-004) |
| T6 | `Mapper` struct: 7-step suppress/inject pipeline, replaces `Remap` |
| T7 | Extend `AuxDevice` with `EV_REL` capability (REL_X/Y/WHEEL/HWHEEL) |
| T8 | `GyroProcessor` skeleton (`core/gyro.zig`): full interface, Phase 2b pipeline stub |
| T9 | `StickProcessor` skeleton (`core/stick.zig`): full interface, Phase 2b pipeline stub |
| T10 | DPad arrows mode: suppress DPad + inject KEY_UP/DOWN/LEFT/RIGHT |
| T11 | End-to-end validation: layer switching, prev-frame diff correctness |

## Success Criteria

- Layer hold mode: trigger held ≥ hold_timeout (200 ms default) activates
  layer; layer remap in effect while held; trigger release deactivates
- Layer toggle mode: trigger release toggles layer on/off; layer remap
  correctly overrides base layer
- Tap-hold: release within 200 ms sends tap event (L0 time injection); timeout
  expiry, then trigger release sends no tap
- timerfd precise timing: hold_timeout fires even with no other input events
  (L1 mock timerfd fd-ready)
- Mutual exclusion (ADR-004): second layer trigger silently ignored while a
  layer is active; declaration order determines priority
- suppress/inject 7-step order correct: layer remap inject overrides base remap
  inject for same button (L0)
- prev-frame suppress/inject correct: layer-switch frame produces no spurious
  button diff (L1)
- Four remap targets: `key`/`mouse_button` → AuxDevice, `gamepad_button` →
  main device mask, `disabled` → suppress only
- `AuxDevice` registers `EV_REL` (REL_X/Y/WHEEL/HWHEEL); `AuxEvent.rel` emits
  correctly
- DPad arrows mode: direction press/release injected to AuxDevice;
  suppress_gamepad suppresses original DPad
- `GyroProcessor`/`StickProcessor` interfaces fully declared; `mode="off"` /
  `mode="gamepad"` stubs return zero (Phase 2b integration ready)
- `zig build test` (Layer 0+1) all pass; CI-runnable
