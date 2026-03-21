# Brief: Phase 10 Wave 4 — Community Zero-Conflict (T17-T18)

## Why

E2E test files (`validate_e2e_test.zig`, `cli_e2e_test.zig`) contain hardcoded
device path arrays. Two contributors adding devices in parallel will conflict on
these arrays. Additionally, `CONTRIBUTING.md` does not clearly state the zero-code
contribution guarantee.

Wave 3 (T12) introduced `collectTomlPaths` via Dir.walk in `auto_device_test.zig`.
This wave applies the same pattern to the remaining E2E tests, then documents the
workflow in CONTRIBUTING.md.

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T17 | Replace hardcoded path arrays in `validate_e2e_test.zig` and `cli_e2e_test.zig` with Dir.walk | T12 (done) |
| T18 | Update `CONTRIBUTING.md` — clarify "add device = add ONE TOML file, zero code changes, CI auto-validates" | T17 |

## Success Criteria

- Zero hardcoded device path arrays in `validate_e2e_test.zig` and `cli_e2e_test.zig`
- All `devices/**/*.toml` automatically discovered and validated by these tests
- `CONTRIBUTING.md` clearly states the zero-code contribution model
- All existing E2E tests still pass

## Out of Scope

- Wave 5 tasks (T19-T23: generic device mapping)
- Modifying device-specific E2E tests (emulate preset, docgen, parseFile per-device)
  — these test specific business logic with known values, not config correctness
- Changes to `src/tools/validate.zig`, `src/config/device.zig`, or
  `src/core/interpreter.zig` individual device tests (low-conflict, test specific logic)

## References

- Phase plan: `planning/phase-10.md` (docs-repo, Wave 4)
- Research: `research/调研-社区贡献无冲突模型.md` (docs-repo)
- Design principles: `design/principles.md` (docs-repo, P1)
- Wave 3 spec: `openspec/changes/phase-10-wave3/` (collectTomlPaths pattern)
