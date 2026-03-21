# Phase 9a T2: Test Plan — DualSense IMU Calibration WASM Plugin

Each test maps to a success criterion in `brief.md`.

## Test Fixture

Synthetic Feature Report 0x05 (41 bytes) with deterministic calibration values.

Reference values (from Linux kernel `hid-playstation.c` typical controller data):
```
gyro_pitch_bias  = 0       (offset 1)
gyro_yaw_bias    = 0       (offset 3)
gyro_roll_bias   = 0       (offset 5)
gyro_pitch_plus  = 8323    (offset 7)
gyro_pitch_minus = -8324   (offset 9)
gyro_yaw_plus    = 8249    (offset 11)
gyro_yaw_minus   = -8249   (offset 13)
gyro_roll_plus   = 8459    (offset 15)
gyro_roll_minus  = -8460   (offset 17)
gyro_speed_plus  = 582     (offset 19)
gyro_speed_minus = -582    (offset 21)
accel_x_plus     = 8218    (offset 23)
accel_x_minus    = -8108   (offset 25)
accel_y_plus     = 8218    (offset 27)
accel_y_minus    = -8098   (offset 29)
accel_z_plus     = 8344    (offset 31)
accel_z_minus    = -7968   (offset 33)
```

Expected computed parameters:
```
Gyro pitch: bias=0, numer=(582+(-582))*1024=0... (see note)
```

Note: Actual gyro_speed values from real controllers are positive. The test fixture should use
realistic values where `gyro_speed_plus > 0` and `gyro_speed_minus > 0`, e.g., `speed_plus=1164`,
`speed_minus=1164`. The implementer should compute expected outputs from the reference formula and
hard-code them in the test.

---

## TP1: `process_calibration` parses and stores parameters

- [ ] Load `sony_imu_calibration.wasm` via `Wasm3Plugin`
- [ ] Pass synthetic Feature Report 0x05 (41 bytes) to `processCalibration`
- [ ] Retrieve state via `HostContext.getState("c")`
- [ ] Assert: returned length == 72 bytes
- [ ] Deserialize 18 i32 values
- [ ] Assert each parameter set (bias, sens_numer, sens_denom) matches expected:
  - Gyro pitch: `bias=0`, `sens_numer=speed_2x*1024`, `sens_denom=pitch_plus-pitch_minus`
  - Gyro yaw: same formula with yaw values
  - Gyro roll: same formula with roll values
  - Accel X: `bias=x_plus-(x_plus-x_minus)/2`, `sens_numer=16384`, `sens_denom=x_plus-x_minus`
  - Accel Y: same formula with Y values
  - Accel Z: same formula with Z values
- Validates: T2a `process_calibration` implementation

## TP2: `process_report` applies calibration correctly

- [ ] Load plugin and call `processCalibration` with test fixture (TP1 setup)
- [ ] Set up `HostContext.get_config_fn` to return `"16"` for key `"imu_offset"`
- [ ] Construct raw input report (64 bytes) with known raw IMU values:
  - `gyro_x=1000` at offset 16, `gyro_y=-500` at offset 18, `gyro_z=200` at offset 20
  - `accel_x=4096` at offset 22, `accel_y=-2048` at offset 24, `accel_z=8192` at offset 26
- [ ] Call `processReport(raw, out)`
- [ ] Assert: result is `.override`
- [ ] Compute expected calibrated values using the formula:
  - `calibrated_gyro = raw * sens_numer / sens_denom`
  - `calibrated_accel = (raw - bias) * sens_numer / sens_denom`
- [ ] Assert: each calibrated i16le value at the corresponding offset in `out` matches expected
- [ ] Assert: non-IMU bytes (offsets 0-15, 28-63) in `out` are identical to `raw`
- Validates: T2a `process_report` implementation, T2d correctness

## TP3: Zero-denominator fallback

- [ ] Construct Feature Report 0x05 where `gyro_pitch_plus == gyro_pitch_minus` (sens_denom = 0
  for pitch axis)
- [ ] Call `processCalibration`
- [ ] Retrieve state, deserialize gyro_pitch parameters
- [ ] Assert: `bias=0`, `sens_numer=2097152`, `sens_denom=32767`
- [ ] Construct raw report with `gyro_x=1000`
- [ ] Call `processReport`; read calibrated gyro_x from output
- [ ] Assert: calibrated value == `1000 * 2097152 / 32767` (clamped to i16 if overflow)
- [ ] Repeat for accel axis with `accel_x_plus == accel_x_minus`:
  - Assert: `bias=0`, `sens_numer=32768`, `sens_denom=32767`
- Validates: brief.md zero-denominator criterion

## TP4: DualShock 4 compatibility

- [ ] Construct 37-byte Feature Report with DS4 calibration values (same layout as DualSense
  bytes 1-34, shorter reserved section)
- [ ] Call `processCalibration(buf, 37)`
- [ ] Retrieve state, deserialize parameters
- [ ] Assert: all 18 parameter values match expected (identical formula to DualSense)
- [ ] Call `processReport` with a raw report using DS4 IMU offsets
  - Set `get_config("imu_offset")` to return the DS4-specific offset
- [ ] Assert: calibrated IMU values are correct
- Validates: brief.md DualShock 4 compatibility criterion

## Regression Guard

- [ ] TP5: All existing wasm3_backend tests (8 tests) pass unchanged
- [ ] TP6: All HostContext tests (7 tests) pass unchanged
- [ ] TP7: All MockPlugin tests (8 tests) pass unchanged
