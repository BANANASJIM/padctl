# Gardener Report: Phase 10 Wave 5 — Generic Device Mapping (T19-T23)

## Cross-Check Summary

### interpreter.zig — Visibility Verification

Design (T19c) requires the following to be exported as `pub`:

| Symbol | Current Visibility | Needs `pub` | Status |
|--------|-------------------|-------------|--------|
| `FieldType` | private (line 14) | yes | confirmed |
| `parseFieldType` | private (line 16) | yes | confirmed |
| `readFieldByTag` | private (line 31) | yes | confirmed |
| `CompiledTransformChain` | private (line 152) | yes | confirmed |
| `compileTransformChain` | private (line 158) | yes | confirmed |
| `runTransformChain` | private (line 201) | yes | confirmed |
| `extractBits` | already `pub` (line 48) | no | OK |
| `signExtend` | already `pub` (line 61) | no | OK |

Design (T21b/c) requires:

| Symbol | Current Visibility | Needs `pub` | Status |
|--------|-------------------|-------------|--------|
| `matchCompiled` | private method on `Interpreter` (line 412) | yes | confirmed |
| `verifyChecksumCompiled` | private standalone fn (line 433) | yes | confirmed |

### device.zig — Structure Verification

| Check | Status |
|-------|--------|
| `DeviceInfo` has no `mode` field | confirmed — T20a addition needed |
| `OutputConfig` has no `mapping` field | confirmed — T20b addition needed |
| `validate()` always validates `button_group.map` against `ButtonId` (line 238) | confirmed — T20d skip needed for generic |

### input_codes.zig — Event Code Tables

| Check | Status |
|-------|--------|
| `resolveAbsCode` exists (line 280) | OK |
| `resolveBtnCode` exists (line 287) | OK |
| `resolveKeyCode` exists (line 266) | OK |
| `resolveEventCode` does not exist | confirmed — T20c addition needed |
| `ABS_WHEEL` in `abs_table` | OK (line 18) |
| `ABS_GAS` in `abs_table` | OK (line 19) |
| `ABS_BRAKE` in `abs_table` | OK (line 20) |
| `ABS_RZ` in `abs_table` | OK (line 15) |
| `BTN_0` in `btn_table` | OK (line 55) |
| `BTN_1` in `btn_table` | OK (line 56) |
| `BTN_GEAR_UP` in `btn_table` | **MISSING** |
| `BTN_GEAR_DOWN` in `btn_table` | **MISSING** |

### uinput.zig — Infrastructure Verification

| Check | Status |
|-------|--------|
| `ioctlInt` exists (line 30) | OK — private, generic code in same file can use it |
| `ioctlPtr` exists (line 39) | OK — private, same |
| UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT constants imported | OK (lines 13-16) |
| UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY imported | OK (lines 19-22) |
| `OutputDevice` vtable exists | OK — generic path is separate, no vtable conflict |

### event_loop.zig — Integration Point

| Check | Status |
|-------|--------|
| `EventLoopContext` struct exists (line 56) | OK |
| No `generic_state` or `generic_output` fields | confirmed — T21a addition needed |
| `maybe_delta` computation at line 321 | confirmed — generic branch inserts before this |
| `processReport` called at line 332 | confirmed — generic path replaces this for generic devices |

### src/core/generic.zig

File does not exist — T19a will create it. Confirmed.

## Document Consistency

| Check | Result |
|-------|--------|
| brief.md references match design.md scope | OK |
| design.md file list matches actual source structure | OK |
| tasks.md breakdown matches design.md sections | OK |
| test-plan.md test points cover all design sections | OK |
| T1/T2 (done) listed as dependencies — confirmed done | OK |
| Out-of-scope boundary (remap/layer/gyro, REL_*, WASM, FF, touchpad) well-defined | OK |
| D1-D8 design decisions internally consistent | OK |
| P1/P2/P3/P8 references in brief.md match principles.md | OK |

## Warnings

**[W1] BTN_GEAR_UP/BTN_GEAR_DOWN missing from `btn_table`**

The example TOML (`devices/example/generic-wheel.toml`) uses `BTN_GEAR_UP` and
`BTN_GEAR_DOWN` event codes. These are valid Linux kernel codes (defined in
`linux/input-event-codes.h` as 0x151 and 0x150), but they are NOT present in
`src/config/input_codes.zig`'s `btn_table`. The `resolveEventCode` function
(T20c) delegates to `resolveBtnCode`, which performs a linear scan of `btn_table`.

**Impact**: The example TOML will fail validation at T20d (unknown event code)
unless `btn_table` is extended.

**Fix**: Add `BTN_GEAR_UP` and `BTN_GEAR_DOWN` to `btn_table` in `input_codes.zig`
as a prerequisite step within T20c. This is a 2-line addition. The design.md
tasks.md should note this dependency.

## Verdict

**PASS with 1 WARNING** — W1 must be addressed during implementation (add 2
entries to `btn_table`). No structural or consistency issues found.
