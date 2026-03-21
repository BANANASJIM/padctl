# Brief: Phase 9a T2 — DualSense IMU Calibration WASM Plugin

## Why

DualSense (and DualShock 4) IMU data is raw and uncalibrated by default. Each controller ships with
per-unit factory calibration data stored in Feature Report 0x05 (41 bytes, 17 i16le values). Without
applying this calibration, gyroscope readings drift (~1-2 deg/s at rest) and accelerometer values
lack proper normalization. This makes motion-based features unreliable.

IMU calibration is inherently a multi-step stateful computation — read calibration report, parse
values, compute per-axis parameters, apply per-frame transform — which cannot be expressed in the
declarative TOML DSL (P7 escape hatch). A WASM plugin is the correct mechanism.

## Problem Scope

- Single C plugin `plugins/sony_imu_calibration.c` (~105 lines)
- Compiled to `plugins/sony_imu_calibration.wasm` via `clang --target=wasm32`
- Implements two WASM exports: `process_calibration` (parse + store params) and `process_report`
  (apply calibration per frame)
- Host reads Feature Report 0x05 and passes it to `process_calibration` — plugin does not call
  `device_read` directly
- Calibration parameters persisted via `set_state` / `get_state` (72 bytes: 18 x i32)
- One plugin serves both DualSense and DualShock 4 (identical calibration algorithm and constants)

## Success Criteria

- `process_calibration` correctly parses a known Feature Report 0x05 payload and stores 6 axis
  calibration parameter sets (bias, sens_numer, sens_denom) via `set_state`
- `process_report` applies calibration formula to raw IMU values and writes corrected values to the
  output buffer; verified against expected output computed from the Linux kernel reference
  implementation (`hid-playstation.c`)
- Zero-denominator edge case: falls back to default values (gyro: 2097152/32767, accel: 32768/32767)
  instead of dividing by zero
- DualShock 4 compatibility: same plugin produces correct results for DS4 calibration data
- `devices/sony/dualsense.toml` updated with `[wasm]` section referencing the plugin

## Out of Scope

- Bluetooth CRC validation of Feature Report (host responsibility)
- DualShock 4 TOML config update (separate task, different report ID per transport mode)
- Timestamp calibration (different formula, not IMU)
- Execution timeout watchdog (separate infrastructure task)

## References

- Research: `research/调研-DualSense-Feature-Report-0x05-校准.md` (docs-repo)
- Host API: `src/wasm/host.zig` (HostContext), `src/wasm/wasm3_backend.zig` (Wasm3Plugin)
- SDK header: `sdk/wasm/padctl_plugin.h`
- Device config: `devices/sony/dualsense.toml`
- Linux kernel: `hid-playstation.c` — `dualsense_get_calibration_data()`, `dualsense_parse_report()`
- ADR: `decisions/005-wasm-plugin-runtime.md`
- Phase 9a T1 OpenSpec: `openspec/changes/phase-9a/`
