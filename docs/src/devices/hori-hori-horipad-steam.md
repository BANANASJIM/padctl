# HORI Horipad Steam

**VID:PID** `0x0f0d:0x00c5`

**Vendor** hori

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `bt` (287 bytes, interface 0)

Match: byte[0] = `0x07`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `left_y` | 2 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 4 | `u8` | scale(-32768, 32767), negate |
| `accel_x` | 22 | `i16le` | — |
| `gyro_z` | 16 | `i16le` | — |
| `gyro_x` | 12 | `i16le` | — |
| `gyro_y` | 14 | `i16le` | — |
| `accel_z` | 18 | `i16le` | — |
| `accel_y` | 20 | `i16le` | — |
| `left_x` | 1 | `u8` | scale(-32768, 32767) |
| `rt` | 8 | `u8` | — |
| `lt` | 9 | `u8` | — |
| `right_x` | 3 | `u8` | scale(-32768, 32767) |

### Button Map

Source: offset 5, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 20 |
| `LT` | 11 |
| `M1` | 14 |
| `RT` | 10 |
| `B` | 2 |
| `LS` | 22 |
| `RS` | 21 |
| `X` | 0 |
| `LB` | 13 |
| `A` | 3 |
| `Select` | 9 |
| `RB` | 12 |
| `Home` | 23 |
| `Start` | 8 |
| `Y` | 15 |
| `M4` | 16 |
| `M3` | 17 |

## Output Capabilities

uinput device name: **HORI Horipad Steam** | VID `0x0f0d` | PID `0x00c5`

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

