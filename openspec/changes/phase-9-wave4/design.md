# Design: Phase 9 Wave 4 — BT Device Expansion (T11/T12/T13)

## Files

| File | Role |
|------|------|
| `devices/sony/dualsense.toml` | Add `[device.init]` enable command for BT mode activation |
| `devices/sony/dualshock4.toml` | New file: DS4 USB + BT reports, commands, output |
| `devices/nintendo/switch-pro.toml` | Add `[wasm]` section, update output with full capabilities |
| `plugins/nintendo_switch_pro.wasm` | New WASM plugin: sub-command init, SPI calibration, HD Rumble |

---

## T11: DualSense BT Init Sequence

### Analysis: Stateful or Declarative?

Per reviewer note (T11 TENSION P1/P7): "must determine if stateful or declarative."

The DualSense BT mode activation is **not stateful**. Per research (`调研-DualSense协议与DSL覆盖率.md` section 6):

> DualSense does not need an explicit init handshake. BT mode: sending any output report
> switches from simple mode (10 bytes) to extended mode (78 bytes).

This is a one-shot fire-and-forget write with no response validation needed. The existing
`[device.init]` DSL with `enable` field handles this exactly — `runInitSequence` in
`src/init.zig` writes the enable command bytes and optionally waits for a response prefix.
For DualSense BT, we send a minimal output report and do not need to verify a response
(the controller silently switches modes).

### Implementation

Add `[device.init]` to `devices/sony/dualsense.toml`:

```toml
[device.init]
commands = []
response_prefix = [0x31]
enable = "31 10 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
```

Breakdown of the enable command:
- Byte 0: `0x31` — BT output report ID
- Byte 1: `0x10` — flags (HasHID bit set, seq_tag=0 for init)
- Byte 2: `0x10` — tag magic value (required by DualSense BT protocol)
- Bytes 3-73: all zeros (no rumble, no LED, no adaptive trigger changes)
- Bytes 74-77: CRC32 placeholder — the engine's output CRC32 support must fill this

**Alternative (simpler)**: if BT output CRC32 is not yet engine-supported, use a USB-format
output report as the trigger instead. Any write to the HID OUT endpoint triggers mode switch:

```toml
[device.init]
commands = []
response_prefix = [0x31]
enable = "02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
```

This sends a USB-format output report (Report ID 0x02, 63 bytes, all zeros = no-op) over BT.
The DualSense BT stack accepts USB-format output reports and still triggers the mode switch.
This avoids the CRC32 requirement entirely.

### Decision: Use USB-format output for BT init

The USB-format approach (Report ID 0x02, 63 zero bytes) is simpler and avoids CRC32 dependency.
Per `hid-playstation.c`, the DualSense firmware accepts USB output reports over BT and triggers
mode switch regardless of report format.

### runInitSequence Behavior

`runInitSequence` with `commands = []` and `enable = "02 00..."`:
1. Skips the empty commands array (no handshake needed)
2. Sends the enable command
3. Waits for a response with prefix `[0x31]` (BT extended report ID) up to 10 retries

This confirms mode switch succeeded. If the device is already in USB mode (not BT), the init
still succeeds — USB mode doesn't have a mode switch concept, and `response_prefix = [0x01]`
would match the USB report immediately.

### Conditional Init

The `[device.init]` section runs for both USB and BT connections. For USB, the enable command
is harmless (a no-op output report). For BT, it triggers extended mode. No conditional logic
needed — the same init works for both transport modes.

---

## T12: DualShock 4 BT

### Protocol Summary

DualShock 4 (VID `0x054c`, PID `0x05c4` v1 / `0x09cc` v2) uses a protocol structurally
similar to DualSense with key differences:

**USB Input Report (Report ID 0x01, 64 bytes):**

| Offset | Size | Field | Type |
|--------|------|-------|------|
| 0 | 1 | Report ID | 0x01 |
| 1 | 1 | left_x | u8 |
| 2 | 1 | left_y | u8 |
| 3 | 1 | right_x | u8 |
| 4 | 1 | right_y | u8 |
| 5 | 4 | buttons[4] | bitfield |
| 9 | 1 | L2 trigger | u8 |
| 10 | 1 | R2 trigger | u8 |
| 11 | 2 | timestamp | u16le |
| 13 | 1 | battery | u8 |
| 14 | 2 | gyro_x | i16le |
| 16 | 2 | gyro_y | i16le |
| 18 | 2 | gyro_z | i16le |
| 20 | 2 | accel_x | i16le |
| 22 | 2 | accel_y | i16le |
| 24 | 2 | accel_z | i16le |
| 30 | 1 | battery_level | u8 |
| 33 | 4 | touch0 | packed |
| 37 | 4 | touch1 | packed |

**Button layout** (bytes 5-7): D-Pad hat4 in bits [3:0], buttons in remaining bits.
Same hat8 encoding as DualSense.

**BT Input Report (Report ID 0x11, 78 bytes):**

Same field layout as USB, but all offsets shift +2 (BT header: 1 byte report ID + 1 byte
protocol byte). CRC32 at bytes 74-77, seed `0xa1`.

### TOML Design

New file `devices/sony/dualshock4.toml`. Structure mirrors `dualsense.toml`:

```toml
[device]
name = "Sony DualShock 4"
vid = 0x054c
pid = 0x05c4

[[device.interface]]
id = 0
class = "hid"

# USB input (Report ID 0x01, 64 bytes)
[[report]]
name = "usb"
interface = 0
size = 64

[report.match]
offset = 0
expect = [0x01]

[report.fields]
left_x  = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
left_y  = { offset = 2, type = "u8", transform = "scale(-32768, 32767), negate" }
right_x = { offset = 3, type = "u8", transform = "scale(-32768, 32767)" }
right_y = { offset = 4, type = "u8", transform = "scale(-32768, 32767), negate" }
lt      = { offset = 9, type = "u8" }
rt      = { offset = 10, type = "u8" }
gyro_x  = { offset = 14, type = "i16le" }
gyro_y  = { offset = 16, type = "i16le" }
gyro_z  = { offset = 18, type = "i16le" }
accel_x = { offset = 20, type = "i16le" }
accel_y = { offset = 22, type = "i16le" }
accel_z = { offset = 24, type = "i16le" }
touch0_contact = { offset = 33, type = "u8" }
touch1_contact = { offset = 37, type = "u8" }
battery_raw    = { offset = 30, type = "u8" }

[report.button_group]
source = { offset = 5, size = 3 }
map = { X = 4, A = 5, B = 6, Y = 7, LB = 8, RB = 9, LT = 10, RT = 11, Select = 12, Start = 13, LS = 14, RS = 15, Home = 16, TouchPad = 17 }

# BT input (Report ID 0x11, 78 bytes)
[[report]]
name = "bt"
interface = 0
size = 78

[report.match]
offset = 0
expect = [0x11]

[report.fields]
left_x  = { offset = 3, type = "u8", transform = "scale(-32768, 32767)" }
left_y  = { offset = 4, type = "u8", transform = "scale(-32768, 32767), negate" }
right_x = { offset = 5, type = "u8", transform = "scale(-32768, 32767)" }
right_y = { offset = 6, type = "u8", transform = "scale(-32768, 32767), negate" }
lt      = { offset = 11, type = "u8" }
rt      = { offset = 12, type = "u8" }
gyro_x  = { offset = 16, type = "i16le" }
gyro_y  = { offset = 18, type = "i16le" }
gyro_z  = { offset = 20, type = "i16le" }
accel_x = { offset = 22, type = "i16le" }
accel_y = { offset = 24, type = "i16le" }
accel_z = { offset = 26, type = "i16le" }
touch0_contact = { offset = 35, type = "u8" }
touch1_contact = { offset = 39, type = "u8" }
battery_raw    = { offset = 32, type = "u8" }

[report.button_group]
source = { offset = 7, size = 3 }
map = { X = 4, A = 5, B = 6, Y = 7, LB = 8, RB = 9, LT = 10, RT = 11, Select = 12, Start = 13, LS = 14, RS = 15, Home = 16, TouchPad = 17 }

[report.checksum]
algo = "crc32"
range = [0, 74]
seed = 0xa1
expect = { offset = 74, type = "u32le" }
```

### BT Init for DS4

DS4 BT mode activation is identical in principle to DualSense — sending an output report
triggers extended mode. Use the same `[device.init]` pattern:

```toml
[device.init]
commands = []
response_prefix = [0x11]
enable = "05 ff 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
```

DS4 USB output report is Report ID 0x05, 32 bytes. An all-zero payload is a no-op that
triggers BT extended mode.

### Output + Commands

```toml
[commands.rumble]
interface = 0
template = "05 ff 00 00 {weak:u8} {strong:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

[commands.led]
interface = 0
template = "05 ff 00 00 00 00 {r:u8} {g:u8} {b:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

[output]
name = "Sony DualShock 4"
vid = 0x054c
pid = 0x05c4

[output.axes]
left_x  = { code = "ABS_X",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
left_y  = { code = "ABS_Y",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
right_x = { code = "ABS_RX", min = -32768, max = 32767, fuzz = 16, flat = 128 }
right_y = { code = "ABS_RY", min = -32768, max = 32767, fuzz = 16, flat = 128 }
lt      = { code = "ABS_Z",  min = 0, max = 255 }
rt      = { code = "ABS_RZ", min = 0, max = 255 }

[output.buttons]
A        = "BTN_SOUTH"
B        = "BTN_EAST"
X        = "BTN_WEST"
Y        = "BTN_NORTH"
LB       = "BTN_TL"
RB       = "BTN_TR"
Select   = "BTN_SELECT"
Start    = "BTN_START"
Home     = "BTN_MODE"
LS       = "BTN_THUMBL"
RS       = "BTN_THUMBR"
TouchPad = "BTN_TOUCH"

[output.dpad]
type = "hat"

[output.force_feedback]
type = "rumble"
max_effects = 16
```

### DS4 v2 Support

DS4 v2 (PID `0x09cc`) uses identical protocol. Support via a second TOML file
(`devices/sony/dualshock4-v2.toml`) with only `pid` changed, or via future multi-PID
support in the device matching system. For this wave, create the v1 TOML; v2 is a copy
with `pid = 0x09cc`.

### P1 Compliance

T12 is pure TOML — no code changes. Adding a new device = creating a `.toml` file.
This is the core P1 promise.

---

## T13: Switch Pro BT WASM Plugin

### Why WASM is Required

Switch Pro Controller's sub-command protocol is a stateful request-response system
(`调研-DSL表达力与完備性分析.md` section 1.2):

1. **Global incrementing packet counter** (0x0-0xF wrapping) — every output report must
   carry the current counter value. This is runtime state that TOML cannot express.

2. **Sub-command request-response** — output report contains rumble data + sub-command ID +
   parameters. The controller responds with an input report containing the sub-command
   reply. Init requires sequential sub-commands: set input mode (0x03), enable IMU (0x40),
   enable vibration (0x48).

3. **SPI flash calibration read** (sub-command 0x10) — reads calibration data from the
   controller's SPI flash at specific addresses. User calibration at 0x8010, factory
   calibration at 0x603D. Each read is a request-response with address and length parameters.

4. **HD Rumble encoding** — Nintendo's rumble format encodes frequency and amplitude as
   a non-linear packed byte sequence, not simple `{strong:u8} {weak:u8}`.

All four characteristics require runtime state or computation that is fundamentally
beyond declarative TOML. This is the textbook P7 escape hatch use case.

### WASM Plugin Design

Plugin: `plugins/nintendo_switch_pro.wasm`

Uses the three-hook ABI from `decisions/005-wasm-plugin-runtime.md`:

**`init_device()`**:
1. Set input report mode to standard (0x30) via sub-command 0x03
2. Enable IMU via sub-command 0x40
3. Enable vibration via sub-command 0x48
4. Read user calibration data from SPI flash 0x8010 (sub-command 0x10)
5. Fall back to factory calibration at 0x603D if user calibration is empty (all 0xFF)

Each step uses the sub-command output report format:
```
byte 0:  0x01 (output report ID for rumble + sub-command)
byte 1:  global_counter (0x0-0xF, incremented each report)
bytes 2-9:  rumble data (neutral: 00 01 40 40 00 01 40 40)
byte 10: sub-command ID
bytes 11-48: sub-command parameters
```

**`process_calibration(ptr, len)`**:
- Receives raw SPI flash calibration data
- Parses stick calibration (center/min/max for each axis)
- Parses IMU calibration (sensitivity coefficients, offsets)
- Stores calibration parameters in WASM linear memory

**`process_report(raw_ptr, raw_len, out_ptr, out_len)`**:
- Applies stick calibration: raw 12-bit values -> calibrated -32768..32767 range
- Applies IMU calibration if enabled
- Outputs calibrated GamepadState

### TOML Design

Update `devices/nintendo/switch-pro.toml`:

```toml
[wasm]
plugin = "plugins/nintendo_switch_pro.wasm"

[wasm.overrides]
process_report = true
```

The existing `[[report]]` block for standard input report 0x30 remains as documentation
and for the TOML validator, but `process_report = true` means the WASM plugin handles
actual report interpretation instead of the declarative interpreter.

The existing button/stick field declarations serve as fallback if the WASM plugin is
unavailable (graceful degradation: raw 8-bit sticks instead of calibrated 12-bit).

### What Stays in TOML

- `[device]` — VID/PID/interface for device matching
- `[[report]]` — report structure for validation and fallback
- `[output]` — uinput virtual device creation (P8)
- `[report.button_group]` — button mapping (used by WASM as reference)

### What Moves to WASM

- Init sub-command sequence (mode switch, IMU enable, vibration enable)
- SPI flash calibration read and parsing
- 12-bit stick value extraction and calibration application
- IMU calibration application
- HD Rumble output encoding

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | DualSense BT init uses USB-format output report (0x02) | Avoids BT CRC32 dependency. DS firmware accepts USB-format reports over BT and still triggers mode switch. |
| D2 | DualSense BT init is declarative, not WASM | Mode activation is a single stateless write + response check, fitting `[device.init]` exactly. No state machine, no multi-step handshake. |
| D3 | DS4 uses separate TOML per PID variant | Simple and explicit. Future multi-PID matching is out of scope for this wave. |
| D4 | DS4 button map uses Xbox-compatible names | Consistent with DualSense TOML: A/B/X/Y instead of Cross/Circle/Square/Triangle. Output layer handles actual button code mapping. |
| D5 | Switch Pro uses WASM for all init + calibration + report processing | Sub-command protocol with incrementing counter is inherently stateful. Partial TOML + partial WASM would create split responsibility — WASM takes full ownership of the stateful parts. |
| D6 | Switch Pro TOML retains `[[report]]` and `[output]` | TOML still handles device matching and uinput creation (P1/P8). Only report interpretation is delegated to WASM. |
| D7 | Switch Pro stick fields stay as raw u8 in TOML | Full 12-bit extraction requires cross-byte bitfield (Phase 2 DSL) or WASM. WASM handles it; TOML provides 8-bit fallback for graceful degradation. |
