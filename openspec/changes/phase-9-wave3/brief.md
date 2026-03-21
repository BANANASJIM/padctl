# Brief: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

## Why

DualSense adaptive triggers support four modes (Off, Feedback, Weapon, Vibration), each requiring
a mode-specific byte sequence sent via USB/BT output report. Currently `devices/sony/dualsense.toml`
only defines `commands.rumble` and `commands.led`. There is no way to declare adaptive trigger
command templates or reference them from mapping config.

The existing `fillTemplate` + `Param` system in `src/core/command.zig` already handles
parameterized byte templates — it accepts hex literals and `{name:type}` placeholders, resolves
params at runtime, and produces the output byte buffer. Adaptive trigger templates fit this
system exactly: each mode is a named command with `{side:u8}`, `{position:u8}`, `{strength:u8}`
etc. as parameters.

This wave adds:
1. Named adaptive trigger command templates to `dualsense.toml` `[commands]` section (T8)
2. `[adaptive_trigger]` section in mapping config for users to select mode + params per side (T9)
3. Event loop integration: on startup/config-reload, resolve mapping → command → fillTemplate → write

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T8 | Add `commands.adaptive_trigger_*` templates to `dualsense.toml` | Phase 8 complete |
| T9 | Add `[adaptive_trigger]` section to mapping config, mapper resolves template name → command | T8 |

## Success Criteria

- `dualsense.toml` contains 4 adaptive trigger command templates (off/feedback/weapon/vibration)
- `fillTemplate` produces correct DualSense output bytes for each mode
- Mapping config `[adaptive_trigger]` parses with mode name + params per side
- Event loop resolves mapping mode → command template → filled bytes → device write
- Existing rumble/LED commands unaffected
- `zig build test` passes all new + existing tests (Layer 0+1, zero privileges)

## Out of Scope

- Runtime parameter passing (T10 deleted — VIOLATION P5/P8)
- Per-game automatic profile switching (T18 deleted — VIOLATION P5)
- Adaptive trigger modes beyond Off/Feedback/Weapon/Vibration (DualSense only supports these 4)
- DualShock 4 (no adaptive trigger hardware)

## References

- Phase plan: `planning/phase-9.md` (docs-repo, Wave 3, T8/T9)
- Principles review: `review/reviewer-phase9-principles.md` (T8 TENSION P1/P3/P6, T9 TENSION P6)
- Design principles: `design/principles.md` (P1, P3, P6)
- Existing command system: `src/core/command.zig` (fillTemplate, Param)
- Device config parser: `src/config/device.zig` (CommandConfig)
- Mapping config parser: `src/config/mapping.zig` (MappingConfig)
- DualSense TOML: `devices/sony/dualsense.toml`
- Event loop FF routing: `src/event_loop.zig` (line 201-214, rumble command resolution pattern)
