# Phase 10 Wave 4: Test Plan — Community Zero-Conflict (T17-T18)

## T17: Dir.walk Replacement

- [ ] TP1: **Discovery count** — both `validate_e2e_test.zig` and `cli_e2e_test.zig`
  discover >= 12 device TOML files via Dir.walk.

- [ ] TP2: **All configs validate** — "E2E validate: all device configs produce 0 errors"
  passes for every discovered TOML (not just the original 5).

- [ ] TP3: **All configs have valid metadata** — non-empty name, >= 1 report, valid
  VID/PID for every discovered device.

- [ ] TP4: **No hardcoded arrays** — grep for `all_device_paths`, `device_paths`, and
  `const paths = [_][]const u8{` in both test files returns zero matches.

- [ ] TP5: **Device-specific tests unchanged** — emulate preset tests, docgen tests,
  and per-device parseFile tests still pass with their original expected values.

## T18: CONTRIBUTING.md

- [ ] TP6: **Zero-code claim accurate** — CONTRIBUTING.md states that adding a device
  requires no source code or test file modifications.

- [ ] TP7: **CI auto-validation documented** — CONTRIBUTING.md mentions that CI
  automatically discovers and validates all device TOMLs.

## Regression Guard

- [ ] TP8: Full `zig build test` passes (all modules, Layer 0+1)
- [ ] TP9: All existing device-specific E2E tests pass unchanged
