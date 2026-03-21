# Phase 9 Wave 3: Test Plan — Adaptive Trigger (T8/T9)

Each test maps to a success criterion in `brief.md`.

## Unit Tests: Command Templates (in `src/core/command.zig`)

- [ ] TP1: **adaptive_trigger_off template produces correct bytes** —
  `fillTemplate(allocator, off_template, &.{})` where `off_template` is the 63-byte
  off template from `dualsense.toml`. Result byte 0 = `0x02` (report ID),
  byte 1 = `0x0c` (valid_flag0, bits 2+3 set), byte 11 = `0x00` (right mode = off),
  byte 22 = `0x00` (left mode = off). Total length = 63 bytes.

- [ ] TP2: **adaptive_trigger_feedback fills position/strength** —
  `fillTemplate(allocator, feedback_template, &params)` with params:
  `r_position=40, r_strength=180, l_position=70, l_strength=200`.
  Result: byte 11 = `0x01` (feedback mode), byte 12 = 40, byte 13 = 180,
  byte 22 = `0x01`, byte 23 = 70, byte 24 = 200.

- [ ] TP3: **adaptive_trigger_weapon fills start/end/strength** —
  `fillTemplate(allocator, weapon_template, &params)` with params:
  `r_start=40, r_end=160, r_strength=180, l_start=30, l_end=140, l_strength=200`.
  Result: byte 11 = `0x02`, byte 12 = 40, byte 13 = 160, byte 14 = 180,
  byte 22 = `0x02`, byte 23 = 30, byte 24 = 140, byte 25 = 200.

- [ ] TP4: **adaptive_trigger_vibration fills position/amplitude/frequency** —
  `fillTemplate(allocator, vibration_template, &params)` with params:
  `r_position=10, r_amplitude=255, r_frequency=30, l_position=10, l_amplitude=200, l_frequency=25`.
  Result: byte 11 = `0x06`, byte 12 = 10, byte 13 = 255, byte 14 = 30,
  byte 22 = `0x06`, byte 23 = 10, byte 24 = 200, byte 25 = 25.

- [ ] TP5: **all templates produce exactly 63 bytes** — for each of the 4 templates,
  `fillTemplate` result length = 63.

## Unit Tests: Device Config Parse (in `src/config/device.zig`)

- [ ] TP6: **dualsense.toml commands count = 6** — parse `devices/sony/dualsense.toml`,
  `commands.map.count() == 6` (rumble + led + 4 adaptive trigger commands).

- [ ] TP7: **adaptive trigger command templates accessible by name** — after parsing,
  `commands.map.get("adaptive_trigger_feedback")` returns non-null `CommandConfig`
  with `interface == 3` and non-empty `template`.

- [ ] TP8: **existing report/output parsing unaffected** — report count = 2,
  field count = 16 (usb report), axes = 6, buttons = 13. Same values as before.

## Unit Tests: Mapping Config Parse (in `src/config/mapping.zig`)

- [ ] TP9: **adaptive_trigger section parses** — TOML input:
  ```toml
  [adaptive_trigger]
  mode = "feedback"
  [adaptive_trigger.left]
  position = 70
  strength = 200
  [adaptive_trigger.right]
  position = 40
  strength = 180
  ```
  Result: `cfg.adaptive_trigger != null`, `cfg.adaptive_trigger.mode == "feedback"`,
  `cfg.adaptive_trigger.left.position == 70`, `cfg.adaptive_trigger.right.strength == 180`.

- [ ] TP10: **adaptive_trigger default mode = "off"** — TOML with
  `[adaptive_trigger]` section but no `mode` field. Result: `cfg.adaptive_trigger.mode == "off"`.

- [ ] TP11: **adaptive_trigger absent = null** — TOML without `[adaptive_trigger]`.
  Result: `cfg.adaptive_trigger == null`.

- [ ] TP12: **adaptive_trigger in layer** — TOML:
  ```toml
  [[layer]]
  name = "racing"
  trigger = "LB"
  [layer.adaptive_trigger]
  mode = "vibration"
  [layer.adaptive_trigger.left]
  position = 10
  amplitude = 200
  frequency = 30
  ```
  Result: `layers[0].adaptive_trigger.mode == "vibration"`,
  `layers[0].adaptive_trigger.left.amplitude == 200`.

## Unit Tests: Mapping Config Validation (in `src/config/mapping.zig`)

- [ ] TP13: **valid mode names pass validation** — for each of "off", "feedback", "weapon",
  "vibration": config with that mode validates without error.

- [ ] TP14: **invalid mode name returns error** — config with `mode = "turbo"`.
  `validate()` returns `error.InvalidConfig`.

- [ ] TP15: **invalid mode in layer returns error** — layer with
  `[layer.adaptive_trigger] mode = "invalid"`. `validate()` returns `error.InvalidConfig`.

## Integration Tests: Resolution Pipeline (in `src/event_loop.zig`)

- [ ] TP16: **round-trip: mapping → command → bytes** — construct `EventLoopContext` with:
  - Device config from `dualsense.toml` (parsed)
  - Mapping config with `[adaptive_trigger] mode = "feedback"`, left position=70, strength=200,
    right position=40, strength=180
  - Mock `DeviceIO` that captures write calls
  Call `applyAdaptiveTrigger`. Verify mock received 63-byte write with correct mode bytes
  and param values at expected offsets.

- [ ] TP17: **mode "off" sends off template** — mapping with `mode = "off"` or absent
  adaptive_trigger. `applyAdaptiveTrigger` sends the off template (mode bytes = 0x00).

- [ ] TP18: **unknown command name = silent skip** — mapping with `mode = "feedback"` but
  device config has no `commands.adaptive_trigger_feedback`. `applyAdaptiveTrigger` does
  not crash, does not write.

## Regression Guard

- [ ] TP19: All existing `event_loop.zig` tests pass (FF routing, rumble, etc.)
- [ ] TP20: All existing `mapping.zig` tests pass (layers, gyro, macro, etc.)
- [ ] TP21: All existing `device.zig` tests pass (field validation, bits, etc.)
- [ ] TP22: All existing `command.zig` tests pass (hex, u8, u16le, u16be, errors)
- [ ] TP23: All fuzz tests pass unchanged
