# Design: Phase 9a T2 — DualSense IMU Calibration WASM Plugin

## Files

| File | Role |
|------|------|
| `plugins/sony_imu_calibration.c` | C source implementing `process_calibration` + `process_report` |
| `plugins/sony_imu_calibration.wasm` | Compiled WASM binary (~2KB) |
| `devices/sony/dualsense.toml` | Add `[wasm]` section referencing the plugin |

## Architecture

### Plugin Lifecycle

The host orchestrates the calibration flow. The plugin is purely computational — no I/O calls.

```
Host                                    Plugin (WASM)
─────                                   ─────────────
1. Open device, load plugin
2. Read Feature Report 0x05 (41 bytes)
3. Call process_calibration(buf, 41) ──► process_calibration:
                                          parse 17 i16le values from buf
                                          compute 6 axis parameter sets
                                          set_state("c", 72 bytes) ──► HostContext.state_map
4. Per input frame:
   Call process_report(raw, out) ──────► process_report:
                                          get_state("c") ──► retrieve 72 bytes
                                          read raw gyro (offsets 16-20) and accel (offsets 22-26)
                                          apply calibration formula per axis
                                          copy raw to out, overwrite IMU fields
                                          return 0 (override)
```

### Feature Report 0x05 Layout

41 bytes total. Byte 0 = report_id (0x05). Bytes 1-34 = 17 i16le calibration values.
Bytes 35-40 = reserved.

```
Offset  Field               Used in
1-2     gyro_pitch_bias     (not used at runtime — kernel sets bias=0)
3-4     gyro_yaw_bias       (not used)
5-6     gyro_roll_bias      (not used)
7-8     gyro_pitch_plus     gyro pitch sens_denom
9-10    gyro_pitch_minus    gyro pitch sens_denom
11-12   gyro_yaw_plus       gyro yaw sens_denom
13-14   gyro_yaw_minus      gyro yaw sens_denom
15-16   gyro_roll_plus      gyro roll sens_denom
17-18   gyro_roll_minus     gyro roll sens_denom
19-20   gyro_speed_plus     gyro sens_numer (all axes)
21-22   gyro_speed_minus    gyro sens_numer (all axes)
23-24   accel_x_plus        accel X bias + sens_denom
25-26   accel_x_minus       accel X bias + sens_denom
27-28   accel_y_plus        accel Y bias + sens_denom
29-30   accel_y_minus       accel Y bias + sens_denom
31-32   accel_z_plus        accel Z bias + sens_denom
33-34   accel_z_minus       accel Z bias + sens_denom
```

### Calibration Parameter Computation (in `process_calibration`)

Constants (matching Linux kernel `hid-playstation.c`):
```c
#define GYRO_RES_PER_DEG_S  1024
#define ACC_RES_PER_G       8192
```

**Gyroscope (each axis — pitch/yaw/roll):**
```
speed_2x   = gyro_speed_plus + gyro_speed_minus
sens_numer = speed_2x * GYRO_RES_PER_DEG_S
sens_denom = gyro_axis_plus - gyro_axis_minus
bias       = 0
```

**Accelerometer (each axis — X/Y/Z):**
```
range      = accel_axis_plus - accel_axis_minus
sens_numer = 2 * ACC_RES_PER_G
sens_denom = range
bias       = accel_axis_plus - range / 2
```

**Zero-denominator fallback:** If `sens_denom == 0` for any axis:
```
Gyro:  bias=0,  sens_numer=2097152  (2048 * 1024),  sens_denom=32767
Accel: bias=0,  sens_numer=32768    (4 * 8192),     sens_denom=32767
```

### Calibration State Serialization

6 parameter sets, each containing 3 x i32 (bias, sens_numer, sens_denom).
Order: gyro_pitch, gyro_yaw, gyro_roll, accel_x, accel_y, accel_z.
Total: 18 x i32 = 72 bytes, stored via `set_state("c", data, 72)`.

Layout in memory (little-endian i32):
```
Offset  Field
0       gyro_pitch.bias
4       gyro_pitch.sens_numer
8       gyro_pitch.sens_denom
12      gyro_yaw.bias
16      gyro_yaw.sens_numer
20      gyro_yaw.sens_denom
24      gyro_roll.bias
28      gyro_roll.sens_numer
32      gyro_roll.sens_denom
36      accel_x.bias
40      accel_x.sens_numer
44      accel_x.sens_denom
48      accel_y.bias
52      accel_y.sens_numer
56      accel_y.sens_denom
60      accel_z.bias
64      accel_z.sens_numer
68      accel_z.sens_denom
```

State key `"c"` is intentionally short — WASM linear memory is constrained and the key is accessed
every frame.

### Per-Frame Calibration Formula (in `process_report`)

Input: raw report bytes (64 bytes USB, 78 bytes BT).
Output: copy of raw report with 6 IMU fields overwritten.

IMU field offsets in USB report (report ID 0x01):
```
gyro_x=16, gyro_y=18, gyro_z=20
accel_x=22, accel_y=24, accel_z=26
```

The plugin reads the IMU field offsets from config via `get_config("imu_offset")` to support both
USB and BT report formats. If `get_config` fails, defaults to USB offsets (16).

For each axis:
```c
// Gyroscope (bias = 0):
calibrated = (int32_t)raw * sens_numer / sens_denom;

// Accelerometer:
calibrated = ((int32_t)raw - bias) * sens_numer / sens_denom;
```

The result is clamped to i16 range [-32768, 32767] and written back as i16le.

The plugin copies the entire raw report to the output buffer first, then overwrites only the 6 IMU
fields. All non-IMU data (sticks, buttons, triggers, touchpad) passes through unchanged.

### DualShock 4 Compatibility

DualShock 4 uses the same calibration algorithm, constants, and field layout (bytes 1-34 identical).
Differences:
- Feature Report ID: USB=0x02, BT=0x05 (vs DualSense: always 0x05)
- Report size: 37 bytes (vs 41) — only reserved bytes differ
- IMU field offsets in input report may differ

The host handles report ID selection via TOML config (`calibration_reports`). The plugin receives
pre-read bytes via `process_calibration` and only parses bytes 1-34, making it format-agnostic.
IMU offsets come from `get_config`, so the same WASM binary works for both controllers.

### TOML Config Changes

Add to `devices/sony/dualsense.toml`:
```toml
[wasm]
plugin = "plugins/sony_imu_calibration.wasm"
calibration_reports = [0x05]

[wasm.overrides]
process_report = true
```

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Host reads Feature Report, not plugin | Separation of concerns: host handles I/O + CRC, plugin does math only |
| D2 | Single plugin for DualSense + DualShock 4 | Identical algorithm; layout compatible to byte 34 |
| D3 | State key `"c"` (1 byte) | Minimize per-frame overhead in WASM linear memory ops |
| D4 | Copy full report, overwrite IMU fields | Non-IMU data passes through unchanged; simplest correct approach |
| D5 | IMU offsets from `get_config` | Supports USB vs BT offset differences without plugin changes |
| D6 | Fallback defaults on zero denominator | Matches kernel behavior; produces ~1:1 mapping (usable but uncalibrated) |
| D7 | C source (not WAT) | Readable, maintainable; `padctl_plugin.h` SDK already exists |
