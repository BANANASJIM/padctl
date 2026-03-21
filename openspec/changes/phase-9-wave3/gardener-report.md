# Gardener Report: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

Date: 2026-03-21

## SEM-6: Cross-Reference Check

| Ref in OpenSpec | Target | Status |
|-----------------|--------|--------|
| `src/core/command.zig` (fillTemplate, Param) | exists | OK |
| `src/config/device.zig` (CommandConfig) | exists, struct at line 74-77 | OK |
| `src/config/mapping.zig` (MappingConfig) | exists, struct at line 50-58 | OK |
| `devices/sony/dualsense.toml` | exists, has `[commands.rumble]` + `[commands.led]` | OK |
| `src/event_loop.zig` (line 201-214, rumble command resolution pattern) | exists, actual range is lines 200-222 | OK (minor offset) |
| `planning/phase-9.md` | not verified (docs-repo) | — |
| `review/reviewer-phase9-principles.md` | not verified (docs-repo) | — |
| `design/principles.md` | not verified here (docs-repo) | — |

All code-repo cross-references resolve correctly.

## TECH: Code Assumptions vs Reality

### TECH-1 [BLOCKING] — Template byte count mismatch

**OpenSpec claim**: "full 63-byte output reports" (design.md line 31), "each is a 63-byte USB output report" (tasks.md line 35), test plan TP5 "all templates produce exactly 63 bytes".

**Reality**: The existing `dualsense.toml` rumble template has **68 tokens** (= 68 bytes output). The LED template has **63 tokens**. The DualSense USB output report is typically described as Report ID 0x02 + 63 data bytes, but the existing rumble template already uses 68 bytes.

More critically, the **proposed templates have inconsistent token counts**:
- `adaptive_trigger_off`: **63 tokens** (63 bytes)
- `adaptive_trigger_feedback`: **64 tokens** (64 bytes)
- `adaptive_trigger_weapon`: **65 tokens** (65 bytes)
- `adaptive_trigger_vibration`: **65 tokens** (65 bytes)

The feedback/weapon/vibration templates include placeholders that each produce 1 byte (`:u8`), so the total byte count equals the token count. These templates should all produce the **same byte count** since they represent the same monolithic output report (design decision D1). The off template has fewer tokens than the parameterized ones because the placeholders in feedback/weapon/vibration add extra tokens but the padding 00's were not reduced to compensate.

**Fix required**: All 4 adaptive trigger templates must have the same token count, and that count must match the actual DualSense output report size. The templates need to be recounted and zero-padded/truncated to be consistent. Also clarify what the correct total byte count is (63? 64? 68?) by reconciling with the existing rumble/LED templates.

### TECH-2 [WARNING] — Param.value encoding for u8 output

**OpenSpec claim** (design.md, event loop section): `buildAdaptiveTriggerParams` maps mapping left/right params to `Param` array.

**Reality**: In `command.zig` line 35, the u8 output is `@intCast(pval >> 8)`, meaning `Param.value` (which is `u16`) stores the value in the **high byte**. To produce output byte value `40`, the `Param.value` must be `40 << 8 = 0x2800`. This is inherited from Linux FF where `strong`/`weak` are native 16-bit values and the high byte maps to the 8-bit motor value.

The design does not document this bit-shift requirement. `AdaptiveTriggerParamConfig` uses `?i64` fields (e.g., `position = 70`), and `buildAdaptiveTriggerParams` must convert `70` to `Param{ .value = 70 << 8 }` to produce the correct output byte. Without this, `position = 70` would produce byte value `0` (`70 >> 8 = 0`).

**Fix required**: design.md must specify that `buildAdaptiveTriggerParams` left-shifts i64 values by 8 bits and truncates to u16 before storing in `Param.value`. Alternatively, the implementation could add a new param type that doesn't require the shift, but that would be a larger change.

### TECH-3 [INFO] — EventLoopContext lacks MappingConfig access

The design proposes `applyAdaptiveTrigger(ctx, at_cfg)` where `at_cfg` is passed directly. This is fine architecturally, but the current `EventLoopContext` has no `mapping_config` field — adaptive trigger config would need to be extracted before calling. The design's pseudocode shows this correctly (parameter is `*const AdaptiveTriggerConfig`, not the full mapping config).

No fix required — the design handles this correctly by passing the config directly.

### TECH-4 [INFO] — CommandConfig struct compatibility

`CommandConfig` (device.zig line 74-77) has exactly `interface: i64` and `template: []const u8`. The OpenSpec correctly states no struct changes are needed for T8. Confirmed.

### TECH-5 [INFO] — MappingConfig struct extension

Current `MappingConfig` (mapping.zig line 50-58) has: `name`, `remap`, `gyro`, `stick`, `dpad`, `layer`, `macro`. Adding `adaptive_trigger: ?AdaptiveTriggerConfig = null` is additive and backward-compatible (optional field with null default). Same for `LayerConfig` (line 37-48). Confirmed compatible.

### TECH-6 [WARNING] — Validation function location

The design places `validateAdaptiveTrigger` in `mapping.zig` and calls it from `validate()`. Currently `mapping.zig` has a `validate()` function (line 93) that checks layers. The proposed integration point is correct. However, the current `validate()` does not iterate layers for gyro/stick/dpad validation — it only checks activation mode, hold_timeout, duplicate names, and macro references. Adding adaptive trigger validation to the layer loop is consistent but the design should note this is the first per-layer output-config validation (all current layer validation is input-side).

## DC1: Path Validity

| Path | Exists | Notes |
|------|--------|-------|
| `devices/sony/dualsense.toml` | Yes | |
| `src/core/command.zig` | Yes | |
| `src/config/device.zig` | Yes | |
| `src/config/mapping.zig` | Yes | |
| `src/event_loop.zig` | Yes | |

All paths valid.

## Summary

| ID | Severity | Issue |
|----|----------|-------|
| TECH-1 | BLOCKING | Template byte counts inconsistent (63/64/65) and don't match existing rumble template (68). Must reconcile. |
| TECH-2 | WARNING | Param.value u8 encoding requires `<< 8` shift, not documented in design. |
| TECH-3 | INFO | EventLoopContext mapping access handled correctly via direct parameter. |
| TECH-4 | INFO | CommandConfig struct compatible, no changes needed. |
| TECH-5 | INFO | MappingConfig extension is additive and backward-compatible. |
| TECH-6 | WARNING | First per-layer output-config validation; design should note this. |

**Verdict**: 1 BLOCKING issue (TECH-1) must be resolved before implementation.
