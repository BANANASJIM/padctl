# Flydigi Vader 4 Pro

**VID:PID** `0x37d7:0x3001`

**Vendor** flydigi

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `extended` (32 bytes, interface 0)

Match: byte[0] = `0x04`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `right_y` | 22 | `u8` | scale(-32768, 32767), negate |
| `accel_y` | 13 | `i16le` | — |
| `gyro_z` | 29 | `i16le` | — |
| `gyro_x` | 26 | `i16le` | — |
| `accel_z` | 15 | `i16le` | — |
| `accel_x` | 11 | `i16le` | — |
| `left_x` | 17 | `u8` | scale(-32768, 32767) |
| `rt` | 24 | `u8` | — |
| `right_x` | 21 | `u8` | scale(-32768, 32767) |
| `lt` | 23 | `u8` | — |
| `left_y` | 19 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 7, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 3 |
| `M1` | 2 |
| `LT` | 27 |
| `RT` | 26 |
| `B` | 18 |
| `LS` | 25 |
| `RS` | 24 |
| `X` | 31 |
| `LB` | 29 |
| `Home` | 8 |
| `Select` | 9 |
| `A` | 19 |
| `RB` | 28 |
| `M4` | 1 |
| `M3` | 0 |
| `Y` | 16 |
| `Start` | 30 |

## Output Capabilities

uinput device name: **Flydigi Vader 4 Pro** | VID `0x37d7` | PID `0x3001`

### Axes

| Field | Code | Min | Max | Fuzz | Flat |
|-------|------|-----|-----|------|------|
| `lt` | `ABS_Z` | 0 | 255 | 0 | 0 |
| `left_x` | `ABS_X` | -32768 | 32767 | 16 | 128 |
| `rt` | `ABS_RZ` | 0 | 255 | 0 | 0 |
| `right_x` | `ABS_RX` | -32768 | 32767 | 16 | 128 |
| `left_y` | `ABS_Y` | -32768 | 32767 | 16 | 128 |
| `right_y` | `ABS_RY` | -32768 | 32767 | 16 | 128 |

### Buttons

| Button | Event Code |
|--------|------------|
| `M2` | `BTN_TRIGGER_HAPPY2` |
| `LT` | `BTN_TL2` |
| `M1` | `BTN_TRIGGER_HAPPY1` |
| `RT` | `BTN_TR2` |
| `B` | `BTN_EAST` |
| `LS` | `BTN_THUMBL` |
| `RS` | `BTN_THUMBR` |
| `X` | `BTN_WEST` |
| `LB` | `BTN_TL` |
| `RB` | `BTN_TR` |
| `A` | `BTN_SOUTH` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `Start` | `BTN_START` |
| `Y` | `BTN_NORTH` |
| `M3` | `BTN_TRIGGER_HAPPY3` |
| `M4` | `BTN_TRIGGER_HAPPY4` |

