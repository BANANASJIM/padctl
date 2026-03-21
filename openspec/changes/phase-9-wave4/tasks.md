# Tasks: Phase 9 Wave 4 — BT Device Expansion (T11/T12/T13)

Branch: `feat/phase-9-wave4`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T11 and T12 are independent (parallel). T13 depends on T1 (wasm3 integration from Wave 1).
Within each task, sub-steps are sequential.

---

## T11: DualSense BT Init Sequence

### T11a: Add [device.init] to dualsense.toml

- [ ] Add `[device.init]` section to `devices/sony/dualsense.toml`:
  ```toml
  [device.init]
  commands = []
  response_prefix = [0x31]
  enable = "02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
  ```
  Uses USB-format output report (Report ID 0x02, 63 bytes all zeros) to trigger BT mode
  switch without requiring BT CRC32 support.

- [ ] Add comment explaining BT mode activation:
  ```toml
  # BT mode activation: sending any output report switches from simple mode
  # (Report ID 0x01, 10 bytes) to extended mode (Report ID 0x31, 78 bytes).
  # USB-format output report is accepted over BT and avoids CRC32 requirement.
  ```

### T11b: Verify init sequence runs correctly

- [ ] Existing `runInitSequence` in `src/init.zig` handles this config:
  - Empty `commands` array: no handshake commands to send
  - `enable = "02 00..."`: sends 63-byte USB output report
  - `response_prefix = [0x31]`: waits for BT extended report
  - Up to 10 retries at 5ms intervals

- [ ] Verify existing `init.zig` tests still pass unchanged

---

## T12: DualShock 4 BT

### T12a: Create dualshock4.toml

- [ ] Create `devices/sony/dualshock4.toml` with:
  - `[device]` section: name, VID `0x054c`, PID `0x05c4`
  - `[[device.interface]]`: id=0, class="hid"
  - `[device.init]`: BT mode activation (Report ID 0x05, 32-byte output report)
  - USB `[[report]]`: name="usb", size=64, match=[0x01], fields for sticks/triggers/IMU/battery
  - BT `[[report]]`: name="bt", size=78, match=[0x11], fields with +2 offset, CRC32 checksum
  - `[commands.rumble]`: Report ID 0x05, 32 bytes
  - `[commands.led]`: Report ID 0x05, 32 bytes with R/G/B at bytes 6/7/8
  - `[output]`: axes, buttons, dpad, force_feedback

- [ ] Verify field offsets against `hid-sony.c` source:
  - USB: sticks at 1-4, buttons at 5-7, triggers at 9-10, IMU at 14-25
  - BT: all offsets +2 from USB

### T12b: Create dualshock4-v2.toml

- [ ] Copy `dualshock4.toml` to `dualshock4-v2.toml`
- [ ] Change `pid = 0x09cc` and `name = "Sony DualShock 4 v2"`
- [ ] Change output section `pid = 0x09cc` and `name`

### T12c: Validate TOML files

- [ ] Both files pass `--validate` (config parser succeeds)
- [ ] Field types match protocol: u8 for sticks/triggers, i16le for IMU
- [ ] Button group bit indices match DS4 button layout
- [ ] CRC32 checksum config matches DS4 BT protocol (seed 0xa1, range [0, 74])

---

## T13: Switch Pro BT WASM Plugin

### T13a: Update switch-pro.toml

- [ ] Add `[wasm]` section:
  ```toml
  [wasm]
  plugin = "plugins/nintendo_switch_pro.wasm"

  [wasm.overrides]
  process_report = true
  ```

- [ ] Update `[output]` to full capabilities:
  ```toml
  [output.axes]
  left_x  = { code = "ABS_X",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
  left_y  = { code = "ABS_Y",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
  right_x = { code = "ABS_RX", min = -32768, max = 32767, fuzz = 16, flat = 128 }
  right_y = { code = "ABS_RY", min = -32768, max = 32767, fuzz = 16, flat = 128 }
  ```
  WASM plugin provides calibrated 12-bit->16-bit stick values, so output range is full
  -32768..32767 (not raw 0..255).

### T13b: Implement WASM plugin

- [ ] Create `plugins/nintendo_switch_pro/` source directory

- [ ] Implement sub-command output report builder:
  - Global packet counter (0x0-0xF wrapping)
  - Rumble data (neutral fill: `00 01 40 40 00 01 40 40`)
  - Sub-command ID + parameters at byte 10+

- [ ] Implement `init_device()` export:
  1. Send sub-command 0x03 (set input report mode = 0x30)
  2. Wait for ACK response
  3. Send sub-command 0x40 (enable IMU, param = 0x01)
  4. Wait for ACK response
  5. Send sub-command 0x48 (enable vibration, param = 0x01)
  6. Wait for ACK response
  7. Send sub-command 0x10 (SPI read, addr = 0x8010, len = 0x16) for user stick calibration
  8. Parse response or fall back to factory calibration at 0x603D

- [ ] Implement `process_calibration()` export:
  - Parse stick calibration data (center, min delta, max delta per axis)
  - Store in WASM linear memory for use in `process_report`

- [ ] Implement `process_report()` export:
  - Extract 12-bit stick values from bytes 6-11 (cross-byte packed)
  - Apply stick calibration: `(raw - center) * 32767 / max_delta`
  - Pass button bytes through unchanged (TOML button_group handles these)
  - Write calibrated values to output buffer

### T13c: Compile WASM plugin

- [ ] Write C source implementing the three exports
- [ ] Compile with `clang --target=wasm32 -nostdlib` to produce `.wasm` binary
- [ ] Verify binary size < 20KB (simple arithmetic, no stdlib)
- [ ] Place binary at `plugins/nintendo_switch_pro.wasm`

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/roadmap.md` Phase 9 Wave 4 status
