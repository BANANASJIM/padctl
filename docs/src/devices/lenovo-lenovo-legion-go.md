# Lenovo Legion Go

**VID:PID** `0x17ef:0x6182`

**Vendor** lenovo

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `xinput` (60 bytes, interface 0)

Match: byte[0] = `0x04`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `lt` | 22 | `u8` | — |
| `left_x` | 14 | `u8` | scale(-32768, 32767) |
| `rt` | 23 | `u8` | — |
| `right_x` | 16 | `u8` | scale(-32768, 32767) |
| `left_y` | 15 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 17 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 18, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 20 |
| `M1` | 1 |
| `LT` | 14 |
| `DPadUp` | 4 |
| `DPadRight` | 7 |
| `RT` | 15 |
| `B` | 9 |
| `LS` | 2 |
| `RS` | 3 |
| `DPadDown` | 5 |
| `DPadLeft` | 6 |
| `X` | 10 |
| `LB` | 12 |
| `Home` | 0 |
| `A` | 8 |
| `RB` | 13 |
| `Select` | 22 |
| `Start` | 23 |
| `Y` | 11 |
| `M3` | 21 |

## Output Capabilities

uinput device name: **Lenovo Legion Go** | VID `0x17ef` | PID `0x6182`

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

