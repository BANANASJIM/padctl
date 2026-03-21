# Brief: Phase 9 Wave 2 — bits DSL + Touchpad (T4/T5/T6/T7)

## Why

DualSense touchpad coordinates are 12-bit values packed across byte boundaries (e.g. touch0_x
spans byte[34] bits 0-11 into byte[35]). The current DSL only supports byte-aligned field
extraction (`offset + type`) and single-bit button groups. Without cross-byte bit-field support,
touchpad X/Y can only be expressed via `u16le + mask + shift` workarounds — violating P3
(simple bit-field extraction should not require expression composition).

Steam Deck has byte-aligned touchpad fields (i16le), but currently these map to `unknown` FieldTag
and are silently discarded by the interpreter. Neither device produces touchpad uinput events.

This wave adds:
1. Cross-byte `bits` DSL extraction (the general mechanism)
2. Touchpad fields in GamepadState (the data model)
3. Touchpad uinput virtual device (the output path)
4. Steam Deck complete touchpad TOML (the first consumer)

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T4 | `bits` DSL extension — `extractBits` pure function, config parser `bits` variant | ADR-009 (accepted) |
| T5 | Interpreter touchpad field tags — GamepadState touch fields, FieldTag variants | T4 |
| T6 | uinput touchpad virtual device — third output device, EV_ABS multitouch | T5 |
| T7 | Steam Deck touchpad complete TOML — dual touchpad using existing i16le fields + new touch state | T4, T6 |

## Success Criteria

- `extractBits` passes unit tests for: single-byte, cross-byte 12-bit, cross-4-byte 32-bit,
  signed extension, start_bit=7 edge case, zero-length rejection
- DualSense touchpad 12-bit coordinates expressible via `bits = [34, 0, 12]` in TOML
- GamepadState contains touch0_x/y, touch1_x/y (i16), touch0_active/touch1_active (bool)
- Touchpad uinput device emits ABS_MT_POSITION_X/Y + ABS_MT_SLOT + ABS_MT_TRACKING_ID events
- Steam Deck TOML loads and validates with touchpad fields
- `zig build test` passes all new + existing tests (Layer 0+1, zero privileges)

## Out of Scope

- DualSense touchpad TOML update (requires `bits` fields for 12-bit X/Y — separate follow-up)
- Touchpad gesture recognition (tap, swipe, pinch — mapping config concern)
- Pressure/force zones (Steam Deck left_pad_force/right_pad_force — deferred to WASM)
- Switch Pro 12-bit packed stick format (Wave 4 T13)

## References

- ADR: `decisions/009-bits-dsl-syntax.md` (docs-repo)
- Phase plan: `planning/phase-9.md` (docs-repo, Wave 2)
- Design principles: `design/principles.md` (docs-repo, P1/P2/P3/P8/P9)
- Output spec: `engineering/output.md` (docs-repo)
- Existing code: `src/core/interpreter.zig`, `src/config/device.zig`, `src/io/uinput.zig`
- Existing TOML: `devices/valve/steam-deck.toml`, `devices/sony/dualsense.toml`
- InputPlumber research: `research/调研-InputPlumber协议数据复用.md` (docs-repo)
