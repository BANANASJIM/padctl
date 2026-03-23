# 8BitDo Ultimate Controller

**VID:PID** `0x2dc8:0x6003`

**Vendor** 8bitdo

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `usb` (64 bytes, interface 0)

Match: byte[0] = `0x01`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `lt` | 9 | `u8` | — |
| `left_x` | 1 | `i16le` | — |
| `rt` | 10 | `u8` | — |
| `right_x` | 5 | `i16le` | — |
| `left_y` | 3 | `i16le` | negate |
| `right_y` | 7 | `i16le` | negate |

### Button Map

Source: offset 11, size 2 byte(s)

| Button | Bit Index |
|--------|-----------|
| `LS` | 9 |
| `RS` | 10 |
| `X` | 2 |
| `LB` | 4 |
| `RB` | 5 |
| `A` | 0 |
| `Select` | 6 |
| `Home` | 8 |
| `Start` | 7 |
| `Y` | 3 |
| `B` | 1 |

## Output Capabilities

uinput device name: **8BitDo Ultimate Controller** | VID `0x2dc8` | PID `0x6003`

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
| `B` | `BTN_EAST` |

