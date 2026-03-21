# Reviewer Report: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

Date: 2026-03-21

## Verdict: FAIL

1 BLOCKING issue from gardener report (TECH-1) remains unresolved. Additional BLOCKING issue found (R2).

---

## Completeness

| Criterion | Status | Notes |
|-----------|--------|-------|
| brief.md scope clear | OK | T8/T9 well-defined, out-of-scope items justified |
| design.md covers all tasks | OK | T8 templates, T9 structs, event loop integration |
| tasks.md actionable steps | OK | Sequential sub-steps with code snippets |
| test-plan.md coverage | PARTIAL | See R2, R3 below |
| Gardener report present | OK | 1 BLOCKING, 2 WARNING, 3 INFO |

## Feasibility

### T8 (Command Templates)

Design correctly identifies that no code changes are needed — adding TOML entries to `dualsense.toml` is purely declarative. The existing `CommandConfig` struct and `fillTemplate` function handle the new templates without modification.

However, the templates themselves are incorrect (gardener TECH-1). The byte counts are inconsistent across the 4 templates, and none match the existing rumble template's 68-byte size. This must be fixed before implementation.

### T9 (Mapping Config)

The proposed `AdaptiveTriggerConfig` and `AdaptiveTriggerParamConfig` structs are well-designed. Using optional fields with null defaults is consistent with existing patterns in `mapping.zig` (see `GyroConfig`, `StickConfig`). The TOML parser will handle the new structs without parser changes (same pattern as existing config structs).

The validation function is straightforward. The mode whitelist approach is appropriate for a closed set of hardware-defined modes.

### Event Loop Integration

The `applyAdaptiveTrigger` function follows the established rumble routing pattern (event_loop.zig lines 200-222). The design correctly identifies three trigger points (startup, config reload, layer switch).

The `buildAdaptiveTriggerParams` function needs the `<< 8` shift for `Param.value` encoding (gardener TECH-2). This is a documentation gap, not a design flaw — the implementation would discover this during testing against `fillTemplate`.

## P6 Compliance (Device/Mapping Separation)

| Aspect | Device Config | Mapping Config | P6 Status |
|--------|--------------|----------------|-----------|
| Byte templates | `[commands.adaptive_trigger_*]` | — | OK |
| Mode selection | — | `mode = "feedback"` | OK |
| Numeric params | — | `position = 70`, `strength = 200` | OK |
| Protocol offsets | In template hex literals | Never exposed | OK |
| Interface ID | `interface = 3` | Never referenced | OK |

P6 is fully respected. Device config contains protocol knowledge (byte layout, report ID, valid_flag0 bitmask, mode byte values). Mapping config contains only user preferences (which mode, what numeric params). The boundary is clean.

Design decision D2 ("mode name in mapping, byte template in device config") and D4 ("adaptive_trigger as top-level section, not inside [remap]") both reinforce P6.

## Test Coverage

### R1 [OK] — Unit test coverage is comprehensive

TP1-TP5 cover all 4 template modes. TP6-TP8 cover device config parsing. TP9-TP15 cover mapping config parsing and validation. TP16-TP18 cover integration. TP19-TP23 cover regression.

### R2 [BLOCKING] — Test plan TP1-TP5 assume wrong byte counts

TP5 states "all templates produce exactly 63 bytes". Given TECH-1 (templates have 63/64/65 tokens), the test assertions are wrong before the templates are even fixed. The test plan must be updated after the template byte count issue is resolved.

Additionally, TP2-TP4 assert specific byte offsets (e.g., "byte 12 = 40"), but these offsets depend on the corrected templates. The test plan cannot be finalized until TECH-1 is resolved.

### R3 [WARNING] — Missing negative test for required params

The test plan validates mode names (TP13-TP15) but does not test what happens when a mode requires params that are missing. For example, `mode = "feedback"` with no `left` or `right` section — `buildAdaptiveTriggerParams` would default all values to 0, which is valid but might not be the user's intent. Consider adding a test or at least documenting this "defaults to 0" behavior.

### R4 [WARNING] — No BT output report template

The design only covers USB output reports (Report ID 0x02, interface 3). DualSense Bluetooth output reports use Report ID 0x31 with a different header structure and CRC32 checksum. The design acknowledges this implicitly by only defining USB templates, but does not explicitly state "BT adaptive trigger support is out of scope for this wave." This should be stated explicitly in `brief.md` out-of-scope section to prevent confusion.

## Design Quality

- D1 (both triggers in one command): correct, matches DualSense hardware behavior
- D3 (no new engine code for T8): verified, CommandConfig + fillTemplate sufficient
- D5 (mode name validation): appropriate for closed hardware mode set
- D6 (one-shot send): correct, adaptive trigger is configuration not continuous output
- D7 (per-layer override): consistent with existing layer pattern (gyro, stick, dpad)
- D8 (optional fields vs tagged union): pragmatic, avoids type proliferation

## Issues Summary

| ID | Severity | Issue |
|----|----------|-------|
| TECH-1 | BLOCKING | Template byte counts inconsistent and don't match existing templates |
| R2 | BLOCKING | Test plan byte count assertions depend on unresolved TECH-1 |
| TECH-2 | WARNING | Param.value `<< 8` encoding not documented |
| R3 | WARNING | No negative test for missing required params per mode |
| R4 | WARNING | BT output report not explicitly out-of-scoped |
| TECH-6 | WARNING | First per-layer output-config validation (noted, not blocking) |

## Required Actions Before PASS

1. Fix all 4 adaptive trigger templates to have identical, correct byte count matching actual DualSense report size
2. Reconcile byte count with existing rumble template (68 tokens) and LED template (63 tokens)
3. Update test plan TP1-TP5 byte offset assertions to match corrected templates
4. Document `Param.value << 8` encoding requirement in `buildAdaptiveTriggerParams`
5. Add explicit BT out-of-scope note to brief.md
