# Device Config Guide

This guide covers writing a padctl TOML device config from your HID capture analysis. For how to capture and analyze HID reports, see the [Reverse Engineering Guide](reverse-engineering.md).

Adding a new device requires only **one file**: `devices/<vendor>/<device>.toml`. No source code changes needed.

## TOML Config Structure

With your analysis complete, translate it to padctl format:

```toml
[device]
name = "Acme Gamepad Pro"
vid = 0x1234
pid = 0x5678

[[device.interface]]
id = 0                    # from HID_PHYS output
class = "hid"

[[report]]
name = "usb"
interface = 0
size = 64                 # report byte count

[report.match]
offset = 0
expect = [0x01]           # report ID

[report.fields]
left_x  = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
left_y  = { offset = 2, type = "u8", transform = "scale(-32768, 32767), negate" }
right_x = { offset = 3, type = "u8", transform = "scale(-32768, 32767)" }
right_y = { offset = 4, type = "u8", transform = "scale(-32768, 32767), negate" }
lt      = { offset = 5, type = "u8" }
rt      = { offset = 6, type = "u8" }

[report.button_group]
source = { offset = 8, size = 3 }
map = { X = 4, A = 5, B = 6, Y = 7, LB = 8, RB = 9, LT = 10, RT = 11, Select = 12, Start = 13, LS = 14, RS = 15, Home = 16 }

[output]
name = "Acme Gamepad Pro"
vid = 0x1234
pid = 0x5678

[output.axes]
left_x  = { code = "ABS_X",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
left_y  = { code = "ABS_Y",  min = -32768, max = 32767, fuzz = 16, flat = 128 }
right_x = { code = "ABS_RX", min = -32768, max = 32767, fuzz = 16, flat = 128 }
right_y = { code = "ABS_RY", min = -32768, max = 32767, fuzz = 16, flat = 128 }
lt      = { code = "ABS_Z",  min = 0, max = 255 }
rt      = { code = "ABS_RZ", min = 0, max = 255 }

[output.buttons]
A      = "BTN_SOUTH"
B      = "BTN_EAST"
X      = "BTN_WEST"
Y      = "BTN_NORTH"
LB     = "BTN_TL"
RB     = "BTN_TR"
Select = "BTN_SELECT"
Start  = "BTN_START"
Home   = "BTN_MODE"
LS     = "BTN_THUMBL"
RS     = "BTN_THUMBR"

[output.dpad]
type = "hat"
```

## Key Decisions

**Y axis negate:** HID reports almost always use +Y = down. padctl convention negates Y axes. Always add `negate` to Y axis transforms.

**Axis type and transform:**

| Raw type | Transform needed |
|----------|-----------------|
| `u8` centered at 0x80 | `scale(-32768, 32767)` |
| `i8` centered at 0 | `scale(-32768, 32767)` |
| `i16le` centered at 0 | none (already full range) |
| `u8` trigger (0-255) | none |

**Output emulation:** For maximum game compatibility, emulate Xbox Elite Series 2 (`vid = 0x045e, pid = 0x0b00`). See `devices/flydigi/vader5.toml` for an example. If the device is well-known (like DualSense), use its real VID/PID.

## Multiple Report Types

Some gamepads send different report IDs for different data:
- Report `0x01` = buttons and axes
- Report `0x02` = touchpad data
- Report `0x11` = IMU data

Each needs its own `[[report]]` block. Use `[report.match]` to disambiguate:

```toml
[[report]]
name = "gamepad"
interface = 0
size = 32
[report.match]
offset = 0
expect = [0x01]

[[report]]
name = "imu"
interface = 0
size = 16
[report.match]
offset = 0
expect = [0x02]
```

## Bluetooth vs USB

The same device often has different report formats over Bluetooth:
- **Extra header byte(s)**: all USB offsets shift by 1 or 2 (see DualSense BT: +1 offset)
- **Different report ID**: DualSense USB = `0x01`, BT extended = `0x31`
- **Checksum appended**: DualSense BT has CRC32 at the end, USB does not
- **Different report size**: DualSense USB = 64 bytes, BT = 78 bytes

You need separate `[[report]]` blocks for each. See `devices/sony/dualsense.toml` for a dual USB/BT config.

## Test and Iterate

```bash
# Parse check — does the config load without errors?
padctl-debug devices/vendor/model.toml

# Live test — run padctl and verify with evtest
padctl --config devices/vendor/model.toml &
evtest /dev/input/eventNN
```

What to verify:
- Each axis moves full range (min to max) and centers correctly
- No axis is inverted (push right = positive value)
- Every button triggers the correct event
- D-pad works in all 8 directions
- Triggers ramp smoothly from 0 to max

Common issues:
- **Axis inverted**: add or remove `negate` in the transform
- **Axis stuck at 0**: wrong offset — recheck your capture analysis
- **Wrong buttons fire**: bit index is off — recount from the button_group source offset
- **Garbage data**: wrong report ID or wrong interface

## Validation and Submission

1. **Validate** locally:

   ```
   zig build && ./zig-out/bin/padctl --validate devices/<vendor>/<model>.toml
   ```

   Exit 0 = valid. Exit 1 = validation errors. Exit 2 = file not found or parse failure.

2. **Test**: Run `zig build test` — the test framework auto-discovers all `.toml` files in `devices/`.

3. **Submit**: Open a pull request. CI runs the same auto-discovery tests automatically.

## Directory Layout

```
devices/
├── 8bitdo/        8BitDo (Ultimate Controller)
├── flydigi/       Flydigi (Vader 4 Pro, Vader 5 Pro)
├── hori/          HORI (Horipad Steam)
├── lenovo/        Lenovo (Legion Go, Legion Go S)
├── microsoft/     Microsoft (Xbox Elite Series 2)
├── nintendo/      Nintendo (Switch Pro Controller)
├── sony/          Sony (DualSense, DualShock 4, DualShock 4 v2)
└── valve/         Valve (Steam Deck)
```

Add a new vendor directory if the manufacturer is not listed.
