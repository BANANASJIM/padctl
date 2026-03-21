# Tasks: Phase 10 Wave 3 — Generative Tests (T12-T16)

Branch: `test/phase-10-wave3`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T13 has no dependency and can start immediately.
T12 depends on T3 (done). T14 and T15 are independent.
T16 depends on T12 (reuses `collectTomlPaths` and test file).

Recommended order: T13 -> T12 -> T14 + T15 (parallel) -> T16.

---

## T12: auto_device_test.zig — Dir.walk + 11 Standard Checks

### T12a: Create test file with collectTomlPaths helper

- [ ] Create `src/test/auto_device_test.zig`
- [ ] Implement `collectTomlPaths(allocator)` — open `devices/` via `std.fs.cwd()`,
  walk recursively, collect all `.toml` paths with `"devices/"` prefix

### T12b: Implement check 1-3 (parse, name, report count)

- [ ] Test `"auto: all device configs parse and validate"`:
  - For each path: `device.parseFile(allocator, path)` succeeds
  - `cfg.device.name.len > 0`
  - `cfg.report.len >= 1`
  - Assert `paths.items.len >= 12`

### T12c: Implement check 5 (button -> ButtonId)

- [ ] For each report with `button_group`, iterate `bg.map.map.iterator()`,
  verify `std.meta.stringToEnum(state.ButtonId, name) != null`

### T12d: Implement check 6-8 (match filter + frame size)

- [ ] Check 6: construct zero-filled frame of `report.size` bytes, write match
  bytes at `match.offset`, call `processReport` — expect non-null (skip if
  report has checksum, since synthetic frame lacks valid checksum)
- [ ] Check 7: same frame but first match byte incremented by 1 — expect null
- [ ] Check 8: construct frame of `report.size - 1` bytes — expect null

### T12e: Implement check 9-10 (checksum correct/incorrect)

- [ ] For reports with `checksum`: construct frame with match bytes, compute
  correct checksum over `range[0]..range[1]` using the declared `algo`:
  - `sum8`: byte sum + seed, truncated to u8
  - `xor`: byte XOR + seed
  - `crc32`: `std.hash.Crc32.hash()` over range, write as declared type
- [ ] Write correct checksum at `expect.offset` — verify no error
- [ ] Write incorrect checksum (flip one bit) — verify `error.ChecksumMismatch`

### T12f: Implement check 11 (no-transform round-trip)

- [ ] For each field without `transform` and without `bits`: write a known
  test value at `field.offset` based on `field.type`:
  - `u8`: 0x42, `i8`: 0x42, `i16le`/`u16le`: 0x1234, `i16be`/`u16be`: 0x1234,
    `i32le`/`u32le`: 0x12345678, `i32be`/`u32be`: 0x12345678
- [ ] Call `processReport`, verify the delta field (via `parseFieldTag` -> FieldTag)
  matches the written value
- [ ] Skip fields that map to `.unknown` FieldTag (metadata fields)
- [ ] Skip reports with checksum (synthetic frame cannot have valid checksum
  for arbitrary field values)

### T12g: Register in build.zig

- [ ] Add `auto_device_test.zig` to the test step in `build.zig`

---

## T13: parseFieldTag pub Export + FieldTag Coverage

### T13a: Export parseFieldTag and FieldTag

- [ ] In `src/core/interpreter.zig`, change `fn parseFieldTag` to `pub fn parseFieldTag`
- [ ] Change `const FieldTag` to `pub const FieldTag`
- [ ] Verify no compilation errors (function is already used only internally;
  adding `pub` has no side effects)

### T13b: Add FieldTag coverage test in auto_device_test.zig

- [ ] Add test `"auto: all field names map to known FieldTag"`:
  - Define ignore list: `sensor_timestamp`, `touch0_contact`, `touch1_contact`,
    `left_x_raw`, `left_y_raw`, `right_x_raw`, `right_y_raw`
  - For each device path -> each report -> each field name:
    - Skip if name is in ignore list
    - Assert `interpreter.parseFieldTag(name) != .unknown`
    - On failure, print device path + field name for diagnostics

---

## T14: State Round-Trip Property Test

### T14a: Add generateRandomDelta helper

- [ ] In `src/core/state.zig`, add test-only function `generateRandomDelta(rng)`
  - Each of 22 optional fields set with 50% probability
  - Integer fields: `@bitCast(rng.int(uN))` for appropriate unsigned type
  - Bool fields: `rng.boolean()`

### T14b: Add round-trip test

- [ ] Add test `"property: applyDelta(a, diff(b, a)) == b"`:
  - `std.Random.DefaultPrng.init(42)` for deterministic seed
  - 1000 iterations
  - Construct two random states from zero + `generateRandomDelta`
  - `diff(b, a)` -> `applyDelta(a, d)` -> assert equals `b`
  - Use `inline for (std.meta.fields(GamepadState))` for field-by-field comparison

### T14c: Add self-diff invariant test

- [ ] Add test `"property: diff(s, s) produces all-null delta"`:
  - 1000 iterations with seed 99
  - Construct random state, diff against itself
  - Assert all delta fields are null via `inline for`

---

## T15: Transform Boundary Exhaustion

### T15a: Create transform_boundary_test.zig

- [ ] Create `src/test/transform_boundary_test.zig`
- [ ] Define boundary value array:
  ```zig
  const boundary_i16 = [_]i16{ 0, 1, -1, std.math.maxInt(i16), std.math.minInt(i16), 16384 };
  ```

### T15b: Negate boundary test

- [ ] Construct minimal TOML with `transform = "negate"` on an i16le field
- [ ] `inline for (boundary_i16)`: write value, processReport, verify delta == negated value
- [ ] Expected: `negate(v)` == `-v` truncated to i16 (note: `negate(-32768)` in i64
  is `32768`, which truncates to `-32768` in i16 — this is the expected Zig behavior
  for `@truncate`)

### T15c: Abs boundary test

- [ ] Construct minimal TOML with `transform = "abs"`
- [ ] `inline for (boundary_i16)`: verify delta == `@abs(v)` with minInt saturation
- [ ] Expected: `abs(-32768)` -> `32767` (clamped in `runTransformChain` before @abs)

### T15d: Scale boundary test

- [ ] Construct minimal TOML with `transform = "scale(-32768, 32767)"`
- [ ] `inline for (boundary_i16)`: verify delta matches `v * (b-a) / type_max + a`
- [ ] Test degenerate case `scale(0, 0)`: all inputs produce 0

### T15e: Clamp boundary test

- [ ] Construct minimal TOML with `transform = "clamp(-16384, 16384)"`
- [ ] `inline for (boundary_i16)`: verify delta == `clamp(v, -16384, 16384)`
- [ ] minInt/maxInt should be clamped to -16384/16384 respectively

### T15f: Deadzone boundary test

- [ ] Construct minimal TOML with `transform = "deadzone(1000)"`
- [ ] Test values: `{0, 999, 1000, 1001, -999, -1000, -1001}`
- [ ] Expected: values with `|v| < 1000` -> 0, others unchanged

### T15g: Transform chain combination tests

- [ ] `negate, abs`: verify `output == abs(v)` for all boundary values
- [ ] `abs, clamp(0, 16384)`: verify `0 <= output <= 16384`
- [ ] `deadzone(1000), scale(-32768, 32767)`: verify dead inputs produce scaled-zero

### T15h: Register in build.zig

- [ ] Add `transform_boundary_test.zig` to the test step in `build.zig`

---

## T16: Fuzz Expansion to All Device Configs

### T16a: Add per-device fuzz test in auto_device_test.zig

- [ ] Add test `"fuzz: processReport on all device configs"`:
  - Reuse `collectTomlPaths`
  - For each device: `parseFile` -> `Interpreter.init` -> fuzz `processReport`
    with random bytes across all interface IDs (0..3)
  - Capture `Interpreter` by value in fuzz context (stack-sized, no heap refs)
  - Adapt context passing to match actual `std.testing.fuzz` API

### T16b: Verify fuzz behavior in normal test mode

- [ ] `zig build test` runs each fuzz entry once (smoke test)
- [ ] No panic on empty/zero input for any device config

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/phase-10.md` T12-T16 status checkboxes
