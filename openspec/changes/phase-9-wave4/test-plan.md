# Phase 9 Wave 4: Test Plan — BT Device Expansion (T11/T12/T13)

Each test maps to a success criterion in `brief.md`.

## Unit Tests: DualSense BT Init (T11, in `src/init.zig`)

- [ ] TP1: **DualSense init config parses from TOML** — parse `devices/sony/dualsense.toml`,
  verify `device.init` is non-null, `commands` is empty, `response_prefix = [0x31]`,
  `enable` is a 63-byte hex string starting with `"02 00"`.

- [ ] TP2: **runInitSequence with empty commands sends only enable** — construct `InitConfig`
  with `commands = &.{}`, `response_prefix = &.{0x31}`, `enable = "02 00 00 ..."`. Mock
  device returns response `[0x31, ...]`. Verify mock received exactly 63 bytes starting
  with `0x02, 0x00`. No other writes (empty commands array skipped).

- [ ] TP3: **runInitSequence retries until BT extended report arrives** — mock returns
  simple report `[0x01, ...]` for first 5 reads, then extended report `[0x31, ...]`.
  `runInitSequence` succeeds (retry mechanism handles initial simple reports).

- [ ] TP4: **runInitSequence fails after max retries** — mock always returns `[0x01, ...]`
  (never switches to extended mode). `runInitSequence` returns `error.InitFailed` after
  10 retries.

## Unit Tests: DualShock 4 Config Parse (T12, in `src/config/device.zig`)

- [ ] TP5: **dualshock4.toml parses successfully** — parse `devices/sony/dualshock4.toml`,
  verify `device.name == "Sony DualShock 4"`, `device.vid == 0x054c`, `device.pid == 0x05c4`.

- [ ] TP6: **dualshock4.toml has 2 reports (usb + bt)** — `report.len == 2`.
  Report 0: name="usb", size=64, match.expect=[0x01].
  Report 1: name="bt", size=78, match.expect=[0x11].

- [ ] TP7: **dualshock4.toml USB report fields** — USB report has fields: left_x (offset 1),
  left_y (offset 2), right_x (offset 3), right_y (offset 4), lt (offset 9), rt (offset 10),
  gyro_x (offset 14, type i16le), battery_raw (offset 30).

- [ ] TP8: **dualshock4.toml BT report fields have +2 offset** — BT report field offsets
  are USB offsets + 2: left_x (offset 3), lt (offset 11), gyro_x (offset 16).

- [ ] TP9: **dualshock4.toml BT checksum config** — BT report has checksum: algo="crc32",
  range=[0,74], seed=0xa1, expect.offset=74, expect.type="u32le".

- [ ] TP10: **dualshock4.toml commands count = 2** — `commands.map.count() == 2`
  (rumble + led).

- [ ] TP11: **dualshock4.toml output config** — axes count = 6, buttons count = 12,
  dpad.type = "hat", force_feedback.type = "rumble".

- [ ] TP12: **dualshock4-v2.toml parses with correct PID** — verify
  `device.pid == 0x09cc`, all other fields identical to v1.

- [ ] TP13: **dualshock4.toml init config** — `device.init` is non-null,
  `commands` is empty, `response_prefix = [0x11]`, `enable` starts with `"05 ff"`.

## Unit Tests: Switch Pro WASM Config (T13, in `src/config/device.zig`)

- [ ] TP14: **switch-pro.toml wasm section parses** — parse `devices/nintendo/switch-pro.toml`,
  verify `wasm` is non-null, `wasm.plugin == "plugins/nintendo_switch_pro.wasm"`,
  `wasm.overrides.process_report == true`.

- [ ] TP15: **switch-pro.toml output axes use full range** — all 4 stick axes have
  min=-32768, max=32767 (calibrated range from WASM plugin).

## Unit Tests: Switch Pro WASM Plugin (T13, in plugin test harness)

- [ ] TP16: **sub-command packet counter increments** — call the sub-command builder
  4 times. Verify byte 1 of each output report is 0x0, 0x1, 0x2, 0x3.

- [ ] TP17: **sub-command packet counter wraps at 0xF** — call 17 times. Byte 1 of
  the 17th call is 0x0 (wraps from 0xF to 0x0).

- [ ] TP18: **init_device sends correct sub-command sequence** — mock device captures
  all writes during init. Verify:
  - Write 1: sub-command 0x03 at byte 10 (set input mode), param byte 11 = 0x30
  - Write 2: sub-command 0x40 at byte 10 (enable IMU), param byte 11 = 0x01
  - Write 3: sub-command 0x48 at byte 10 (enable vibration), param byte 11 = 0x01
  - Write 4: sub-command 0x10 at byte 10 (SPI read), address bytes at 11-14 = 0x8010

- [ ] TP19: **stick calibration applies correctly** — given known calibration data
  (center=2048, min_delta=512, max_delta=512), raw value 2048 maps to 0 (center),
  raw value 2560 maps to 32767 (max), raw value 1536 maps to -32768 (min).

- [ ] TP20: **12-bit stick extraction from packed bytes** — given bytes
  `[0x00, 0x08, 0x80]` (left stick packed format), extracted left_x = 0x800 (2048),
  left_y = 0x800 (2048).

## Integration Tests

- [ ] TP21: **DualSense BT round-trip: init -> extended report parse** — construct
  mock device that returns simple report until output write, then returns extended report.
  Run init sequence, then read report. Verify report matches BT `[[report]]` block
  (match = [0x31], fields at BT offsets).

- [ ] TP22: **DS4 USB report parse end-to-end** — construct mock device with a DS4 USB
  input report byte buffer. Parse with DS4 config. Verify extracted stick/trigger/IMU
  values match expected values at documented offsets.

## Regression Guard

- [ ] TP23: All existing `init.zig` tests pass unchanged
- [ ] TP24: All existing `device.zig` tests pass unchanged
- [ ] TP25: All existing `dualsense.toml` parse tests pass (report count, field count, etc.)
- [ ] TP26: All existing `switch-pro.toml` parse tests pass
- [ ] TP27: All existing WASM integration tests pass (T1/T2 from Wave 1)
- [ ] TP28: All fuzz tests pass unchanged
