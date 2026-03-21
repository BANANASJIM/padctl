# Design: Phase 10 Wave 4 — Community Zero-Conflict (T17-T18)

## Files

| File | Role |
|------|------|
| `src/test/validate_e2e_test.zig` | T17: replace two hardcoded path arrays with Dir.walk |
| `src/test/cli_e2e_test.zig` | T17: replace one hardcoded path array with Dir.walk |
| `CONTRIBUTING.md` | T18: update contribution workflow documentation |

---

## T17: Replace Hardcoded Path Arrays with Dir.walk

### Problem

Three hardcoded device path arrays exist across two files:

**`validate_e2e_test.zig`**:
- `all_device_paths` (line 14) — used by "E2E validate: all 5 device configs produce 0 errors"
- `device_paths` (line 221) — used by three section-5 validate tests

**`cli_e2e_test.zig`**:
- `paths` (line 167) — used by "scan matching: all 5 device files parse for vid/pid lookup"

All three arrays contain the same 5 devices. 7+ newer devices have zero coverage.
Parallel PRs adding devices would conflict on these arrays.

### Solution

Reuse the same `collectTomlPaths` + `freeTomlPaths` pattern from T12's
`auto_device_test.zig`. Import the helper or duplicate it (it is ~30 lines).

**Option A (preferred)**: Extract `collectTomlPaths`/`freeTomlPaths` into a shared
test utility, or simply duplicate the function in each file (test code duplication
is acceptable for isolation).

**Option B**: Import from `auto_device_test.zig` via `@import("auto_device_test.zig")`.
This creates a test-file dependency; acceptable since both are test-only.

The implementer should choose based on what compiles cleanly.

#### validate_e2e_test.zig changes

1. Delete `all_device_paths` array (line 14-20)
2. Delete `device_paths` array (line 221-227)
3. Add `collectTomlPaths`/`freeTomlPaths` (same pattern as `auto_device_test.zig`)
4. Update test "E2E validate: all 5 device configs produce 0 errors":
   - Call `collectTomlPaths(allocator)`, assert `>= 12`
   - Iterate discovered paths instead of `all_device_paths`
   - Rename test to "E2E validate: all device configs produce 0 errors"
5. Update tests "validate: all device TOMLs produce 0 errors",
   "validate: all device TOMLs have non-empty name",
   "validate: all device TOMLs have at least one report":
   - Same pattern: `collectTomlPaths` instead of `device_paths`

**Keep unchanged**: Section 2-4 tests (emulate presets, docgen, parseFile per-device).
These test specific device behavior with known expected values (VID/PID, preset
fields, section headings). They are not candidates for Dir.walk — they validate
business logic, not config correctness.

#### cli_e2e_test.zig changes

1. Delete inline `paths` array (line 167-173)
2. Add `collectTomlPaths`/`freeTomlPaths`
3. Update test "scan matching: all 5 device files parse for vid/pid lookup":
   - Call `collectTomlPaths(allocator)`, assert `>= 12`
   - Iterate discovered paths instead of `paths`
   - Rename test to "scan matching: all device files parse for vid/pid lookup"

---

## T18: CONTRIBUTING.md Update

### Problem

Current `CONTRIBUTING.md` says "添加新设备只需创建一个 TOML 配置文件" but:
- Step 3 says `zig build test` without explaining why it works automatically
- Does not mention that CI auto-discovers and validates all device configs
- Does not mention "zero code changes" explicitly

### Solution

Update the "添加新设备支持" section:

1. Clarify step 3: after T17, `zig build test` automatically discovers and validates
   all `devices/**/*.toml` — no test file modifications needed
2. Add explicit statement: "不需要修改任何源代码文件或测试文件"
3. Add a "CI 自动验证" subsection explaining that Dir.walk-based tests cover:
   - TOML syntax and semantic validation
   - FieldTag coverage
   - ButtonId validity
   - VID/PID parseability

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Duplicate `collectTomlPaths` rather than shared import | Test file isolation — each E2E test file is self-contained. 30 lines of duplication is acceptable. |
| D2 | Keep device-specific tests unchanged | Emulate preset, docgen, and parseFile-per-device tests verify specific expected values that cannot be auto-generated from Dir.walk. |
| D3 | Minimum count guard `>= 12` | Same as T12 — prevents silent pass on wrong CWD. |
