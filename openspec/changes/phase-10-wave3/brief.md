# Brief: Phase 10 Wave 3 — Generative Tests (T12-T16)

## Why

The test suite relies on hardcoded device paths (5 out of 12 TOML files), manually
constructed byte arrays, and fixed test values. Seven device configs have zero test
coverage, transform boundary behavior is only spot-checked, and the state round-trip
invariant is verified with 4 hand-written cases.

This wave replaces hardcoded test data with tests auto-generated from device configs
and mathematical properties, achieving automatic coverage of all current and future
device files with zero maintenance cost.

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T12 | `auto_device_test.zig` — Dir.walk discovers all `devices/**/*.toml`, runs 11 standard checks per device | T3 (done) |
| T13 | Export `parseFieldTag` as `pub` in `interpreter.zig`, test every field name in every device maps to known FieldTag | none |
| T14 | State round-trip property test — `generateRandomDelta` + verify `applyDelta(a, diff(b, a)) == b` for 1000+ pairs | none |
| T15 | Transform boundary exhaustion — comptime arrays of {0, 1, -1, MAX, MIN, midpoint} for negate/abs/scale/clamp/deadzone | none |
| T16 | Fuzz expansion — one fuzz entry per device config (Dir.walk + Interpreter per config + fuzz processReport) | T12 |

## Success Criteria

- All 12+ device configs automatically discovered and validated by `zig build test`
- Every field name in every device TOML maps to a known FieldTag (not `.unknown`),
  except documented ignore-list entries
- State round-trip invariant `applyDelta(a, diff(b, a)) == b` holds for 1000+ random pairs
- All 5 transforms tested at 6 boundary values each (30 boundary assertions minimum)
- Fuzz processReport covers all device configs (not just vader5)
- Zero hardcoded device path arrays remain in the new test file

## Out of Scope

- Wave 4 tasks (T17-T18: deleting legacy hardcoded paths, CONTRIBUTING.md)
- Wave 5 tasks (T19-T23: generic device mapping)
- Modifying existing hand-written E2E tests (they test business logic, not config correctness)
- Mapper/layer/gyro property tests (different test domain, Phase 10+ scope)

## References

- Phase plan: `planning/phase-10.md` (docs-repo, Wave 3)
- Research: `research/调研-标准化自动测试生成.md` (docs-repo)
- Research: `research/调研-生成式测试框架.md` (docs-repo)
- Design principles: `design/principles.md` (docs-repo, P1, P9)
- Source: `src/core/interpreter.zig`, `src/core/state.zig`, `src/config/device.zig`
