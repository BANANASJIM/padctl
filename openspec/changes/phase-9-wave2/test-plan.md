# Phase 9 Wave 2: Test Plan — bits DSL + Touchpad (T4/T5/T6/T7)

Each test maps to a success criterion in `brief.md`.

## Unit Tests: extractBits (in `src/core/interpreter.zig`)

- [ ] TP1: **single-byte extraction** — `raw = [0b11010110]`, `extractBits(raw, 0, 2, 3)`
  extracts bits[2..4] = `0b101` = 5. Validates basic single-byte bit extraction.

- [ ] TP2: **12-bit cross-byte (DualSense touch0_x)** — `raw[34] = 0xAB, raw[35] = 0x0C`,
  `extractBits(raw, 34, 0, 12)` = `0x0CAB & 0xFFF` = `0xCAB`. Validates the primary use case
  from ADR-009.

- [ ] TP3: **12-bit cross-byte with start_bit offset (DualSense touch0_y)** —
  `raw[35] = 0xF0, raw[36] = 0x12`, `extractBits(raw, 35, 4, 12)` = assembles
  `0x12F0`, shifts right 4 = `0x012F`. Validates start_bit + cross-byte.

- [ ] TP4: **32-bit cross-4-byte** — `raw = [0x01, 0x02, 0x03, 0x04, 0x05]`,
  `extractBits(raw, 0, 0, 32)` = `0x04030201`. Validates maximum bit_count.

- [ ] TP5: **32-bit with start_bit=1 spanning 5 bytes** — `raw = [0xFF; 5]`,
  `extractBits(raw, 0, 1, 32)` reads 5 bytes, shifts right 1, masks 32 bits = `0xFFFFFFFF`.
  Validates max span (start_bit + bit_count requires ceil((1+32)/8) = 5 bytes, but ADR-009
  limits to 4 bytes). This should be caught at config validation, not at runtime.

- [ ] TP6: **signed extension 12-bit** — raw value `0xFFF` (12 bits all 1),
  `signExtend(0xFFF, 12)` = `-1`. Validates sign extension for negative values.

- [ ] TP7: **signed extension positive** — raw value `0x7FF` (12 bits, MSB=0),
  `signExtend(0x7FF, 12)` = `2047`. Validates sign extension preserves positive values.

- [ ] TP8: **start_bit=7, bit_count=1** — `raw = [0x80]`,
  `extractBits(raw, 0, 7, 1)` = `1`. Validates edge case at byte boundary.

- [ ] TP9: **bit_count=1, start_bit=0** — `raw = [0x01]`,
  `extractBits(raw, 0, 0, 1)` = `1`. `raw = [0xFE]`, same call = `0`.

- [ ] TP10: **4-bit sub-byte (DualSense battery)** — `raw[53] = 0xA7`,
  `extractBits(raw, 53, 0, 4)` = `0x7` (low nibble),
  `extractBits(raw, 53, 4, 4)` = `0xA` (high nibble).

## Unit Tests: Config Validation (in `src/config/device.zig`)

- [ ] TP11: **bits field parses and validates** — TOML with
  `touch0_x = { bits = [34, 0, 12] }` in a report of size 64. Parses without error.

- [ ] TP12: **bits field out of bounds** — TOML with `f = { bits = [62, 0, 24] }` in
  report size 64. `62 + ceil((0+24)/8) = 65 > 64`. Returns `error.InvalidConfig`.

- [ ] TP13: **bits and offset mutually exclusive** — TOML with
  `f = { offset = 10, type = "u8", bits = [10, 0, 8] }`. Returns `error.InvalidConfig`.

- [ ] TP14: **bits invalid start_bit** — `f = { bits = [0, 8, 4] }` (start_bit=8 > 7).
  Returns `error.InvalidConfig`.

- [ ] TP15: **bits invalid bit_length=0** — `f = { bits = [0, 0, 0] }`.
  Returns `error.InvalidConfig`.

- [ ] TP16: **bits invalid bit_length=33** — `f = { bits = [0, 0, 33] }`.
  Returns `error.InvalidConfig`.

- [ ] TP17: **bits with signed type** — `f = { bits = [0, 0, 12], bits_type = "signed" }`.
  Parses and validates without error.

- [ ] TP18: **bits with invalid type** — `f = { bits = [0, 0, 12], bits_type = "float" }`.
  Returns `error.InvalidConfig`.

## Unit Tests: Interpreter Touchpad Fields (in `src/core/interpreter.zig`)

- [ ] TP19: **bits field round-trip** — Construct a config with
  `touch0_x = { bits = [2, 0, 12] }`, raw = `[0x00, 0x00, 0xAB, 0x0C, ...]`,
  `processReport` returns `delta.touch0_x == 0x0CAB & 0xFFF`.

- [ ] TP20: **signed bits field** — Config with `f = { bits = [0, 0, 12], bits_type = "signed" }`,
  raw value = `0xFFF`. Returned value = `-1` (sign-extended).

- [ ] TP21: **touch active field** — Config with `touch0_active = { bits = [10, 3, 1] }`,
  raw byte[10] = `0x08` (bit 3 set). `delta.touch0_active == true`.

- [ ] TP22: **touch active field inactive** — Same config, raw byte[10] = `0x00`.
  `delta.touch0_active == false`.

- [ ] TP23: **mixed standard + bits fields** — Config with both
  `left_x = { offset = 3, type = "i16le" }` and `touch0_x = { bits = [16, 0, 16] }`.
  Both extracted correctly from same raw buffer.

## Unit Tests: GamepadState Touchpad (in `src/core/state.zig`)

- [ ] TP24: **diff detects touch field changes** — prev `touch0_x = 0`, curr `touch0_x = 100`.
  `diff()` returns `delta.touch0_x = 100`.

- [ ] TP25: **applyDelta sets touch fields** — Apply `delta.touch0_active = true` to default
  state. `state.touch0_active == true`.

- [ ] TP26: **diff unchanged touch fields are null** — Same touch0_x in prev and curr.
  `delta.touch0_x == null`.

## Integration Tests: Touchpad Pipeline

- [ ] TP27: **Steam Deck TOML loads with touchpad fields** — Parse
  `devices/valve/steam-deck.toml` with updated touchpad fields and `[output.touchpad]`.
  Validates without error.

- [ ] TP28: **Steam Deck interpreter extracts touchpad** — Load updated Steam Deck config,
  construct raw report with known trackpad X/Y values at offsets 16-23 and touch active bits
  at byte 10. `processReport` returns delta with correct `touch0_x/y`, `touch1_x/y`,
  `touch0_active`, `touch1_active`.

- [ ] TP29: **existing tests unbroken** — All pre-existing tests in `interpreter.zig`,
  `device.zig`, `state.zig`, `uinput.zig` pass without modification.
  Validates: P9 regression guard.

## Regression Guard

- [ ] TP30: Vader 5 TOML tests pass unchanged (existing `offset + type` path unaffected)
- [ ] TP31: DualSense TOML tests pass unchanged (touch0_contact as u8 still works)
- [ ] TP32: All fuzz tests pass unchanged

## Manual Tests (not required for merge)

- [ ] TP33: With real Steam Deck hardware, verify touchpad events appear in
  `evtest /dev/input/eventX` for the padctl touchpad device
- [ ] TP34: Verify multitouch: two fingers on right pad produce slot 0 and slot 1 events
