# Phase 10 Wave 3: Test Plan — Generative Tests (T12-T16)

These are meta-tests: they verify that the generative test infrastructure itself
works correctly. Each maps to a success criterion in `brief.md`.

## T12: Auto Device Test Discovery

- [ ] TP1: **Discovery count** — `collectTomlPaths` discovers >= 12 device TOML files.
  The assertion `paths.items.len >= 12` in the test acts as a guard against CWD errors
  or empty directory traversal.

- [ ] TP2: **All configs parse** — `device.parseFile` succeeds for every discovered path.
  No parse or validation errors on any real device TOML.

- [ ] TP3: **All device names non-empty** — `cfg.device.name.len > 0` for every config.

- [ ] TP4: **All configs have at least one report** — `cfg.report.len >= 1`.

- [ ] TP5: **All button names valid** — for every `button_group.map` key in every report,
  `std.meta.stringToEnum(ButtonId, name) != null`.

- [ ] TP6: **Match filter accept works** — for each report with match bytes (no checksum),
  a synthetic frame with correct match bytes produces a non-null processReport result.

- [ ] TP7: **Match filter reject works** — same frame with modified match byte produces null.

- [ ] TP8: **Short frame rejected** — frame shorter than `report.size` returns null.

- [ ] TP9: **Checksum correct passes** — for each report with checksum, independently
  computed checksum passes verification (no `ChecksumMismatch`).

- [ ] TP10: **Checksum incorrect fails** — flipped checksum byte triggers
  `error.ChecksumMismatch`.

- [ ] TP11: **No-transform round-trip** — for fields without transform/bits, writing a
  known value at offset and reading it back via processReport yields the same value in
  the delta.

## T13: FieldTag Coverage

- [ ] TP12: **parseFieldTag is pub** — `auto_device_test.zig` compiles and calls
  `interpreter.parseFieldTag(name)` without error. This proves the export succeeded.

- [ ] TP13: **All field names map to known FieldTag** — every field name in every device
  TOML either maps to a non-unknown FieldTag or is in the documented ignore list. No
  field silently maps to `.unknown` without being in the ignore list.

- [ ] TP14: **Ignore list is minimal** — the ignore list only contains names that
  genuinely should map to `.unknown` (sensor_timestamp, touch*_contact). Verify no
  production field names accidentally appear in the ignore list.

## T14: State Round-Trip

- [ ] TP15: **Round-trip invariant holds** — `applyDelta(a, diff(b, a)) == b` for all
  1000 random (a, b) pairs. If any field mismatch occurs, the test reports which field
  and iteration number.

- [ ] TP16: **Self-diff is empty** — `diff(s, s)` produces a delta where all 22 optional
  fields are null, for 1000 random states.

- [ ] TP17: **Deterministic** — running the test twice produces identical results (fixed
  PRNG seed).

## T15: Transform Boundaries

- [ ] TP18: **Negate all boundaries** — 6 boundary values for negate transform all produce
  correct output. Specifically: `negate(0) == 0`, `negate(1) == -1`, `negate(-1) == 1`,
  `negate(32767) == -32767`, `negate(-32768)` behavior is consistent with i64 negate
  then @truncate to i16.

- [ ] TP19: **Abs all boundaries** — `abs(0) == 0`, `abs(1) == 1`, `abs(-1) == 1`,
  `abs(32767) == 32767`, `abs(-32768) == 32767` (saturation), `abs(16384) == 16384`.

- [ ] TP20: **Scale all boundaries** — `scale(-32768, 32767)` with i16le field produces
  mathematically correct output for all 6 boundary values. `scale(0, 0)` produces 0
  for all inputs.

- [ ] TP21: **Clamp all boundaries** — `clamp(-16384, 16384)` clamps values outside
  [-16384, 16384] and passes through values inside the range.

- [ ] TP22: **Deadzone threshold** — `deadzone(1000)` zeroes inputs with `|v| < 1000`,
  passes through inputs at and above threshold. Specifically: `deadzone(0) == 0`,
  `deadzone(999) == 0`, `deadzone(1000) == 1000`, `deadzone(-999) == 0`,
  `deadzone(-1000) == -1000`.

- [ ] TP23: **Transform chains** — `negate, abs` produces `|v|` for all boundary values.
  `abs, clamp(0, 16384)` output is always in [0, 16384].

## T16: Fuzz Expansion

- [ ] TP24: **Fuzz covers all configs** — the fuzz test loop iterates >= 12 device configs.
  Each config creates a valid Interpreter.

- [ ] TP25: **No panic on empty input** — in normal test mode (single-run), processReport
  with empty bytes does not panic for any device config.

- [ ] TP26: **No panic on zero-filled input** — processReport with zero-filled frame of
  any size does not panic for any device config.

## Regression Guard

- [ ] TP27: All existing `interpreter.zig` tests pass (parseFieldTag visibility change
  does not break internal callers)
- [ ] TP28: All existing `state.zig` tests pass
- [ ] TP29: All existing `device.zig` tests pass
- [ ] TP30: Full `zig build test` passes (all modules, Layer 0+1)
