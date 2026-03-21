# Brief: Phase 9 Wave 4 — BT Device Expansion (T11/T12/T13)

## Why

padctl currently supports DualSense USB fully and BT input report parsing (added in Phase 7),
but the BT mode activation sequence is missing — the controller stays in simple mode (10 bytes,
no IMU/touchpad) until an output report is sent. DualShock 4 BT and Switch Pro BT have no TOML
files at all.

This wave completes BT device coverage for three Sony/Nintendo controllers:

1. **T11 (DualSense BT init)**: Phase 7 added the BT `[[report]]` block with `match = [0x31]`
   and CRC32 checksum. The missing piece is the BT mode activation — sending an output report
   to switch from simple mode (Report ID 0x01, 10 bytes) to extended mode (Report ID 0x31,
   78 bytes). This is a stateless one-shot write, expressible via `[device.init]` DSL with an
   `enable` command. No WASM needed.

2. **T12 (DualShock 4 BT)**: New `devices/sony/dualshock4.toml` covering both USB (Report ID
   0x01, 64 bytes) and BT (Report ID 0x11, 78 bytes). DS4 protocol is structurally similar to
   DualSense but with different offsets and no adaptive triggers. Pure TOML, zero code (P1).

3. **T13 (Switch Pro BT WASM)**: Switch Pro's sub-command protocol requires stateful
   request-response communication with a global incrementing packet counter, SPI flash
   calibration reads, and HD Rumble encoding. This is a textbook P7 WASM escape hatch use case.
   The WASM plugin handles init (mode switch + IMU enable + vibration enable + SPI calibration
   read), while the TOML declares the standard input report (0x30) parsing and output device.

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T11 | DualSense BT init sequence (`[device.init]` enable command) | Phase 8 complete |
| T12 | DualShock 4 BT (new `devices/sony/dualshock4.toml`, zero code) | Phase 8 complete |
| T13 | Switch Pro BT WASM plugin (sub-command protocol, SPI calibration, HD Rumble) | T1 (wasm3 integration) |

## Success Criteria

- DualSense BT mode activation via `[device.init]` enable command — controller switches from
  simple to extended report mode
- `devices/sony/dualshock4.toml` passes `--validate` with USB and BT reports, buttons, axes,
  IMU fields, and CRC32 checksum (BT only)
- Switch Pro WASM plugin successfully performs init sequence (set input mode 0x30, enable IMU,
  enable vibration) via sub-command protocol
- Switch Pro TOML correctly parses standard input report 0x30 (buttons, sticks)
- All existing tests pass unchanged
- `zig build test` passes (Layer 0+1, zero privileges)

## Out of Scope

- DualSense BT output report CRC32 calculation (engine-level feature, not per-device)
- DualSense BT seq_tag incrementing (engine-level feature, not per-device)
- Switch Pro NFC/IR sub-commands (Report ID 0x31 mode, specialized hardware)
- Switch Pro full 12-bit stick resolution (requires cross-byte bitfield, Phase 2 DSL)
- DualShock 4 touchpad (same 12-bit cross-byte extraction as DualSense, deferred)
- 8BitDo DS4-compatible controllers (T12 TOML should work if they implement DS4 protocol)

## References

- Phase plan: `planning/phase-9.md` (docs-repo, Wave 4, T11/T12/T13)
- Principles review: `review/reviewer-phase9-principles.md` (T11 TENSION P1/P7, T12 COMPLIANT, T13 COMPLIANT P7)
- Design principles: `design/principles.md` (P1, P7, P9)
- DualSense protocol research: `research/调研-DualSense协议与DSL覆盖率.md` (BT mode, init, CRC32)
- DSL expressiveness analysis: `research/调研-DSL表达力与完备性分析.md` (Switch Pro sub-command protocol)
- WASM ADR: `decisions/005-wasm-plugin-runtime.md` (three-hook ABI)
- Existing DualSense TOML: `devices/sony/dualsense.toml` (USB + BT reports, commands)
- Existing Switch Pro TOML: `devices/nintendo/switch-pro.toml` (BT standard report only)
- Init sequence handler: `src/init.zig` (runInitSequence, InitConfig)
