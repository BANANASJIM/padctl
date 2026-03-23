# Xbox Elite Series 2

**VID:PID** `0x045e:0x0b00`

**Vendor** microsoft

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `usb` (64 bytes, interface 0)

Match: byte[0] = `0x01`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `lt` | 9 | `u16le` | scale(0, 255) |
| `left_x` | 1 | `i16le` | — |
| `rt` | 11 | `u16le` | scale(0, 255) |
| `right_x` | 5 | `i16le` | — |
| `left_y` | 3 | `i16le` | negate |
| `right_y` | 7 | `i16le` | negate |

### Button Map

Source: offset 13, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 1 |
| `M1` | 0 |
| `B` | 9 |
| `LS` | 16 |
| `RS` | 17 |
| `X` | 10 |
| `LB` | 12 |
| `A` | 8 |
| `RB` | 13 |
| `Select` | 14 |
| `Home` | 18 |
| `Start` | 15 |
| `M4` | 3 |
| `M3` | 2 |
| `Y` | 11 |

## Commands

| Name | Interface | Template |
|------|-----------|----------|
| `rumble` | 0 | `09 00 00 09 00 0f {strong:u8} {weak:u8} {left_trigger:u8} {r...` |

## Output Capabilities

uinput device name: **Xbox Elite Series 2** | VID `0x045e` | PID `0x0b00`

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
| `M1` | `BTN_TRIGGER_HAPPY1` |
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

**Force feedback**: type=`rumble`, max_effects=4

