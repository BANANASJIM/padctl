# Tasks: Phase 10 Wave 4 — Community Zero-Conflict (T17-T18)

Branch: `test/phase-10-wave4`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T17 first (code change), then T18 (docs update). T18 depends on T17 being done
so the documentation accurately describes the current state.

---

## T17: Replace Hardcoded Path Arrays with Dir.walk

### T17a: Add collectTomlPaths to validate_e2e_test.zig

- [ ] Add `collectTomlPaths(allocator)` and `freeTomlPaths(allocator, paths)`
  functions (same implementation as `auto_device_test.zig`)

### T17b: Replace all_device_paths in validate_e2e_test.zig

- [ ] Delete `all_device_paths` const array
- [ ] Update test "E2E validate: all 5 device configs produce 0 errors":
  - Use `collectTomlPaths`, assert `paths.items.len >= 12`
  - Rename to "E2E validate: all device configs produce 0 errors"

### T17c: Replace device_paths in validate_e2e_test.zig

- [ ] Delete `device_paths` const array
- [ ] Update tests in section 5 (validate: all device TOMLs...):
  - Use `collectTomlPaths` in each test
  - Remove "5" from test names if present

### T17d: Replace paths in cli_e2e_test.zig

- [ ] Delete inline `paths` const array in "scan matching" test
- [ ] Add `collectTomlPaths`/`freeTomlPaths` functions
- [ ] Update test "scan matching: all 5 device files parse for vid/pid lookup":
  - Use `collectTomlPaths`, assert `paths.items.len >= 12`
  - Rename to "scan matching: all device files parse for vid/pid lookup"

### T17e: Verify

- [ ] `zig build test` passes — all E2E tests discover and validate 12+ devices
- [ ] No hardcoded device path arrays remain in either file

---

## T18: CONTRIBUTING.md Update

### T18a: Update contribution steps

- [ ] In "添加新设备支持" section, update step 3 to clarify that `zig build test`
  automatically discovers and validates all device TOMLs via Dir.walk
- [ ] Add explicit note: "不需要修改任何源代码文件或测试文件"

### T18b: Add CI auto-validation explanation

- [ ] Add brief subsection explaining what CI auto-checks:
  - TOML parse + semantic validation
  - FieldTag and ButtonId coverage
  - VID/PID validity

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/phase-10.md` T17-T18 status checkboxes
