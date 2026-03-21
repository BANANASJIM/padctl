# Tasks: Phase 9a T2 — DualSense IMU Calibration WASM Plugin

Branch: `feat/phase-9a`
Depends on: Phase 9a T1 (wasm3 backend) merged and verified.

## Execution plan

T2a → T2b → T2c → T2d sequential.

---

## T2a: Write `plugins/sony_imu_calibration.c`

- [ ] Create `plugins/sony_imu_calibration.c` (~105 lines)
- [ ] `#include "sdk/wasm/padctl_plugin.h"` for host function declarations
- [ ] Define constants:
  ```c
  #define GYRO_RES_PER_DEG_S  1024
  #define ACC_RES_PER_G       8192
  #define CALIB_STATE_SIZE    72   // 18 x i32
  ```
- [ ] Implement helper `read_i16le(const uint8_t *p)` — read i16 little-endian from byte pointer
- [ ] Implement `process_calibration(const void *buf, int32_t len)`:
  - Guard: `if (len < 35) return;` (need bytes 1-34)
  - Parse 17 i16le values from offsets 1-34
  - Compute gyro parameters (3 axes):
    - `speed_2x = gyro_speed_plus + gyro_speed_minus`
    - `sens_numer = speed_2x * GYRO_RES_PER_DEG_S`
    - `sens_denom = axis_plus - axis_minus`
    - `bias = 0`
    - If `sens_denom == 0`: fallback `sens_numer=2097152, sens_denom=32767`
  - Compute accel parameters (3 axes):
    - `range = axis_plus - axis_minus`
    - `sens_numer = 2 * ACC_RES_PER_G`
    - `sens_denom = range`
    - `bias = axis_plus - range / 2`
    - If `sens_denom == 0`: fallback `bias=0, sens_numer=32768, sens_denom=32767`
  - Serialize 18 i32 values to 72-byte buffer (little-endian)
  - Call `set_state("c", 1, calib_buf, 72)`
- [ ] Implement `process_report(const void *raw, int32_t raw_len, void *out, int32_t out_len)`:
  - Guard: `if (raw_len < 28 || out_len < raw_len) return -1;`
  - Call `get_state("c", 1, calib_buf, 72)` — if returns != 72, return -1 (no calibration data)
  - Deserialize 18 i32 values from `calib_buf`
  - Copy raw to out: `memcpy(out, raw, raw_len)` (use `__builtin_memcpy`)
  - Determine IMU base offset: call `get_config("imu_offset", 10, offset_buf, 4)`, parse as int;
    default to 16 if `get_config` fails
  - Read 6 raw i16le values from `out + imu_offset` (gyro x/y/z at +0/+2/+4, accel x/y/z at +6/+8/+10)
  - Apply calibration per axis:
    - Gyro: `calibrated = raw_val * sens_numer / sens_denom`
    - Accel: `calibrated = (raw_val - bias) * sens_numer / sens_denom`
  - Clamp each result to [-32768, 32767]
  - Write 6 calibrated i16le values back to `out + imu_offset`
  - Return 0 (override)
- [ ] No global mutable state — all state flows through `set_state` / `get_state`

## T2b: Compile to WASM

- [ ] Compile command:
  ```bash
  clang --target=wasm32 -nostdlib -O2 \
    -Wl,--no-entry -Wl,--export=process_calibration -Wl,--export=process_report \
    -I. plugins/sony_imu_calibration.c -o plugins/sony_imu_calibration.wasm
  ```
- [ ] Verify: `wasm-objdump -x plugins/sony_imu_calibration.wasm` shows exports
  `process_calibration` and `process_report`, imports `env.set_state`, `env.get_state`,
  `env.get_config`
- [ ] Verify: binary size < 4KB
- [ ] Commit both `.c` source and `.wasm` binary

## T2c: Update `devices/sony/dualsense.toml`

- [ ] Add `[wasm]` section at end of file:
  ```toml
  [wasm]
  plugin = "plugins/sony_imu_calibration.wasm"
  calibration_reports = [0x05]

  [wasm.overrides]
  process_report = true
  ```
- [ ] Verify TOML parses without error

## T2d: Unit test

- [ ] Create test in `tests/wasm/test_sony_imu_calibration.zig` (or add to existing test file)
- [ ] Test fixture: construct synthetic Feature Report 0x05 (41 bytes) with known calibration values
  - Use values from Linux kernel test or from a real DualSense controller dump
  - Example: `gyro_pitch_plus=8323, gyro_pitch_minus=-8324, gyro_speed_plus=582, gyro_speed_minus=-582`
- [ ] Test `process_calibration`:
  - Load `sony_imu_calibration.wasm`
  - Set up `HostContext` with mock `get_config` returning `"16"` for `imu_offset`
  - Call `processCalibration(feature_report_bytes)`
  - Verify `getState("c")` returns 72 bytes
  - Deserialize and verify each parameter set matches expected values
- [ ] Test `process_report`:
  - After calibration, construct raw input report with known raw IMU values
  - Call `processReport(raw, out)`
  - Verify calibrated IMU values in `out` match expected values computed by hand
  - Verify non-IMU bytes in `out` are unchanged from `raw`
- [ ] Test zero-denominator fallback:
  - Construct Feature Report where `gyro_pitch_plus == gyro_pitch_minus` (denom = 0)
  - Call `processCalibration` + `processReport`
  - Verify fallback values used (near 1:1 mapping)
- [ ] Test DualShock 4 compatibility:
  - Construct 37-byte Feature Report with DS4-style calibration values (same byte layout 1-34)
  - Call `processCalibration(buf, 37)` — should parse identically

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update Phase 9a T2 status in `openspec/changes/phase-9a/tasks.md`
