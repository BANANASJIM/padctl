# Gardener Report: Phase 9 Wave 2 — bits DSL + Touchpad

> Date: 2026-03-21

## Summary

Cross-checked `brief.md`, `design.md`, `tasks.md`, `test-plan.md` against ADR-009, current
code (`interpreter.zig`, `device.zig`, `uinput.zig`, `state.zig`), and device TOML files.
Found 7 issues: 2 BLOCKING, 5 WARNING.

---

## [BLOCKING] B1: `bits_type` vs ADR-009 `type` field naming conflict

ADR-009 specifies `type = "unsigned" | "signed"` alongside `bits`:

```toml
touch0_x = { bits = [34, 0, 12], type = "unsigned" }
```

OpenSpec design.md (line 64-65) and tasks.md (T4b) introduce a **new field name** `bits_type`
instead of reusing `type`. This creates an incompatibility with ADR-009's specified syntax.

The motivation for renaming is sound (current `FieldConfig.type` is non-optional `[]const u8`
used for byte-aligned types like `"i16le"`; making it carry double meaning is ambiguous). But
the deviation from the accepted ADR needs to be either:

1. Documented as a deliberate deviation with rationale, or
2. ADR-009 updated to reflect `bits_type` naming (requires ADR amendment).

**Currently neither is done.** An implementer following ADR-009 will use `type`, conflicting
with the OpenSpec's `bits_type`.

**Files:** `design.md` lines 53/65, `tasks.md` T4b, ADR-009 line 30-31.

## [BLOCKING] B2: FieldConfig `offset`/`type` must become optional — breaking change understated

Current code (`src/config/device.zig` line 35-38):

```zig
pub const FieldConfig = struct {
    offset: i64,
    type: []const u8,
    transform: ?[]const u8 = null,
};
```

Both `offset` and `type` are **non-optional**. The OpenSpec correctly identifies they must
become optional (`?i64` and `?[]const u8`), but tasks.md T4b note "Existing TOML files that
always provide both are unaffected" understates the impact:

- `validate()` (line 192) calls `fieldTypeSize(field.type)` unconditionally on **every** field.
  With `type` now optional (`?[]const u8`), this call must be guarded. The task mentions
  "Update `fieldTypeSize` usage: skip for `bits` fields" but does not mention the **existing**
  `validate()` code path at line 192 which dereferences `field.type` without null check.
- The zig-toml parser behavior for optional vs non-optional struct fields must be verified.
  If `FieldConfig.type` becomes `?[]const u8`, existing TOML entries like `{ offset = 3, type = "i16le" }`
  must still parse correctly. This is likely fine (zig-toml promotes present values to non-null),
  but is an assumption not verified in the test plan.

**Recommendation:** Add a test case (e.g. between TP13 and TP14) that parses an existing
`offset + type` field after the struct change, confirming backward compatibility.

---

## [WARNING] W1: `CompiledField` design inconsistency between design.md and tasks.md

Design.md (lines 93-108) specifies `CompiledField.mode` as a **tagged union**:

```zig
mode: union(enum) { standard: struct { ... }, bits: struct { ... } },
```

Tasks.md (T4c, lines 72-88) specifies it as **flat fields with a mode enum tag**:

```zig
mode: enum { standard, bits },
// flat fields for both modes
type_tag: FieldType,
offset: usize,
byte_offset: u16,
...
```

Decision D1 in design.md rationale table says "not a tagged union" for `FieldConfig` (config
parsing), but `CompiledField` is a **separate internal struct** where unions are fine (no TOML
parsing involved). The two documents disagree on the implementation approach for `CompiledField`.

**Recommendation:** Align design.md and tasks.md. The flat-fields approach in tasks.md is
simpler and adequate; update design.md to match.

## [WARNING] W2: `UI_SET_PROPBIT` not in ioctl_constants.zig

Design.md T6 (line 277) specifies:

```
UI_SET_PROPBIT(INPUT_PROP_POINTER)
```

Current `src/io/ioctl_constants.zig` does not define `UI_SET_PROPBIT`. The ioctl number is
`_IOW('U', 110, int)`. This constant must be added as a prerequisite for T6b, but is not
listed in the tasks.

**Recommendation:** Add a sub-step in T6b to define `UI_SET_PROPBIT` in `ioctl_constants.zig`.

## [WARNING] W3: Steam Deck button bits — L3_touch is bit 19, not bit 3 of byte 10

Design.md T7 (line 341-342) and tasks.md T7b (line 269) state:

```
Steam Deck byte 10 bit3 = L3_touch
```

But Steam Deck uses a 4-byte button_group (bytes 8-15), so byte 10 bit 3 is **button bit 19**
in the 32-bit bitfield (confirmed by `steam-deck.toml` line 56-57 comment and button_group
map). The `bits` DSL uses **absolute byte offset + local bit**, so
`touch0_active = { bits = [10, 3, 1] }` is correct (byte 10, bit 3 within that byte).

However, the existing `button_group.map` does NOT contain `L3_touch` or `R3_touch` entries --
they are mentioned in the header comment (line 56) but **not mapped** in the actual
`button_group.map` (line 60). This means T7b's instruction to "Remove L3_touch/R3_touch from
`button_group.map`" (tasks.md line 275-277) references entries that don't exist.

**Recommendation:** Remove the "remove from button_group.map" instruction from T7b. The
entries are not in the map. Only add the new `bits` fields.

## [WARNING] W4: TP5 test case describes a scenario rejected at config validation

Test-plan.md TP5 (lines 22-24) describes testing `extractBits` with `start_bit=1, bit_count=32`
which requires 5 bytes. The ADR-009 limits to 4 bytes maximum. TP5 acknowledges this
("This should be caught at config validation, not at runtime") but still describes it as an
`extractBits` runtime test.

If config validation correctly rejects `start_bit + bit_count` configurations requiring >4 bytes,
this test case can never occur via normal code paths. The test should either:

1. Be a config validation test (asserting rejection), or
2. Be removed from the `extractBits` unit test section.

**Recommendation:** Move TP5 to the config validation section (after TP16) and rewrite it
as a bounds-check validation test.

## [WARNING] W5: `negate` transform used for DualSense touch_active (out-of-scope section)

Design.md T7 out-of-scope DualSense example (lines 370-375) uses:

```toml
touch0_active = { bits = [33, 7, 1], transform = "negate" }
```

The `negate` transform applies `-val`, turning `1` into `-1` and `0` into `0`. For a boolean
field where `applyFieldTag` does `val != 0`, both `1` and `-1` evaluate to `true`. This means
`negate` does NOT invert the boolean -- an active_low bit (`1` = inactive) would still map to
`true`.

The correct transform should produce `0` from `1` and `1` from `0`. None of the existing
transforms (`negate`, `abs`, `scale`, `clamp`, `deadzone`) perform boolean inversion.

This is out-of-scope for Wave 2, but the design decision section (D5, lines 190-200) references
this pattern as the "preferred" approach for P2 compliance. A new transform (e.g.
`invert_bool` or `not`) may be needed, or the active flag logic needs rethinking.

**Recommendation:** Add a note in design.md acknowledging this limitation. DualSense
`touch0_active` handling will need either a new `not` transform or a different approach.

---

## DC1: Path Validity

| Path | Status |
|------|--------|
| `src/core/interpreter.zig` | exists |
| `src/config/device.zig` | exists |
| `src/core/state.zig` | exists |
| `src/io/uinput.zig` | exists |
| `devices/valve/steam-deck.toml` | exists |
| `devices/sony/dualsense.toml` | exists |
| `decisions/009-bits-dsl-syntax.md` (docs-repo) | exists |

## SEM-6: Cross-Reference Check

| Reference | Valid |
|-----------|-------|
| brief.md -> ADR-009 | yes |
| brief.md -> `planning/phase-9.md` | not verified (docs-repo) |
| brief.md -> `design/principles.md` | not verified (docs-repo) |
| brief.md -> `engineering/output.md` | not verified (docs-repo) |
| design.md -> ADR-009 | yes, with B1 naming mismatch |
| test-plan.md -> brief.md success criteria | aligned |

## SEM-10: Tasks Match Design

| Task | Design Section | Match |
|------|---------------|-------|
| T4a (extractBits) | design T4 extractBits | aligned |
| T4b (config parser) | design T4 BitsFieldConfig | aligned (B1 aside) |
| T4c (CompiledField) | design T4 CompiledField | W1 inconsistency |
| T5a (GamepadState) | design T5 GamepadState | aligned |
| T5b (FieldTag) | design T5 FieldTag | aligned |
| T6a (TouchpadConfig) | design T6 OutputConfig | aligned |
| T6b (TouchpadDevice) | design T6 TouchpadDevice | aligned (W2 aside) |
| T6c (vtable) | design T6 TouchpadOutputDevice | aligned |
| T6d (main.zig) | design T6 event loop | aligned |
| T7a-d (Steam Deck) | design T7 | aligned (W3 aside) |

## TECH: Code Assumptions

| Assumption | Status |
|------------|--------|
| `FieldConfig.offset` is non-optional `i64` | **correct** -- must change to `?i64` (B2) |
| `FieldConfig.type` is non-optional `[]const u8` | **correct** -- must change to `?[]const u8` (B2) |
| `FieldTag` has `.unknown` variant | **correct** (line 61) |
| `CompiledField` has `tag`, `type_tag`, `offset`, `transforms`, `has_transform` | **correct** (line 202-208) |
| `applyFieldTag` ignores `.unknown` | **correct** (line 94) |
| `OutputDevice` vtable pattern: `ptr + vtable` | **correct** (line 55-76) |
| `AuxOutputDevice` is second vtable | **correct** (line 80-96) |
| `GamepadState` has no touchpad fields | **correct** -- must add (T5) |
| `UinputDevice.emit` reads `GamepadState` fields directly | **correct** -- touchpad needs separate device |
| `steam-deck.toml` has `left_pad_x/y`, `right_pad_x/y` | **correct** (lines 45-48) |
| `steam-deck.toml` button_group has no L3_touch/R3_touch | **correct** (W3) |
