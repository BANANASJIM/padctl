# Gardener Report — Phase 9a OpenSpec

| Severity | Check | File | Finding |
|----------|-------|------|---------|
| ERROR | TECH | design.md:90, tasks.md:79 | design.md lists 7 host functions, tasks.md lists 7 callbacks, but `host.zig` only has 6 methods — `get_report_field` / `getReportField` does not exist in code. host.zig line 2 comment also says "6 functions". Design adds a 7th without noting it is new code to be created. |
| ERROR | SEM-10 | tasks.md:17-19, design.md:7, brief.md:14 | T1a lists 17 `.c` files to copy, but brief.md says "12 files" and design.md says "12 `.c` files". Count mismatch: either the file list in tasks.md is wrong or the "12" count in brief.md/design.md is wrong. |
| ERROR | SEM-6 | test-plan.md:74, runtime.zig | TP13 claims "8 existing MockPlugin tests in `src/wasm/runtime.zig`". Actual count is 8 — correct. However TP14 claims "4 tests in `src/test/wasm_e2e_test.zig`" — actual count is 4. TP15 claims "7 tests in `src/wasm/host.zig`" — actual count is 7. All 3 counts verified correct. (No error — included for audit trail.) |
| WARNING | DC1 | design.md:13-15 | `src/test/fixtures/echo_plugin.wasm`, `no_exports.wasm`, `trap_plugin.wasm` — directory `src/test/fixtures/` does not exist. These are to-be-created but not explicitly marked as such. |
| WARNING | DC1 | design.md:10 | `src/wasm/wasm3_backend.zig` — does not exist yet; to-be-created. Not explicitly marked. |
| WARNING | DC1 | brief.md:38 | `decisions/005-wasm-plugin-runtime.md` — `decisions/` directory does not exist in the code repo. This is a docs-repo path cross-referenced from code-repo OpenSpec; should use an absolute path or note it lives in docs-repo. |
| WARNING | DC1 | brief.md:43 | `openspec/changes/phase-7/` — exists in code repo, OK. |
| WARNING | TECH | design.md:100 | `env.get_report_field` listed with HostContext Method `(new: read parsed field by ID)` — this is the only host function with no existing `HostContext` method. tasks.md T1d line 91 lists `hostGetReportField` callback but there is no corresponding `HostContext` method to delegate to. Implementation will need to either add a method to `HostContext` or handle it entirely within the callback. This dependency is not captured in any task. |
| WARNING | SEM-10 | tasks.md:74 | T1c says "Define `const vtable = WasmPlugin.VTable{ ... }` with all 6 function pointers" — but the VTable has 6 fields, while T1d registers 7 host functions. The "6 function pointers" is correct for VTable (load, initDevice, processCalibration, processReport, unload, destroy), but could cause confusion with the "7 host functions" count. |
| WARNING | TECH | design.md:37 | build.zig integration says compile flags include `"-Dd_m3HasWASI=0"`, but tasks.md T1b line 32 also includes this. Verify this flag name is correct for the pinned wasm3 commit (some versions use `d_m3HasWASI`, others `M3_HAS_WASI`). Not verifiable without wasm3 source. |
| INFO | TECH | build.zig | Current build.zig structure is compatible with proposed changes: `exe_mod`, `src_mod`, `unit_mod`, `tsan_mod` all exist and accept `addImport`. `linkLibC()` already called on all relevant targets. No structural obstacles. |
| INFO | TECH | runtime.zig | VTable definition has 6 method pointers: `load`, `initDevice`, `processCalibration`, `processReport`, `unload`, `destroy`. design.md Wasm3Plugin struct and vtable description matches these 6 signatures correctly. |
| INFO | SEM-6 | test-plan.md | TP1-TP8 map cleanly to T1c/T1d/T1e tasks. TP9-TP12 map to T1b. TP13-TP15 are regression guards. All cross-references consistent. |

## Summary

3 errors, 6 warnings

### Error Details

1. **7th host function `get_report_field` not in code**: design.md and tasks.md reference `env.get_report_field` with callback `hostGetReportField`, but `host.zig` has no `getReportField` method. Either add a task to implement it in `host.zig`, or remove it from the Phase 9a scope (defer to a later phase).

2. **C file count mismatch**: T1a in tasks.md enumerates 17 `.c` files but brief.md and design.md both say "12 `.c` files". Need to reconcile — either update the count to 17 or trim the file list.

3. *(Row marked ERROR but verified correct on re-check — downgraded to INFO in narrative. Test counts TP13/TP14/TP15 are all accurate.)*

Effective: **2 errors, 6 warnings**.
