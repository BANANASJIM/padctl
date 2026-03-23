# Lenovo Legion Go S

**VID:PID** `0x1a86:0xe310`

**Vendor** lenovo

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 6 | hid | — | — |

## Report: `gamepad` (32 bytes, interface 6)

Match: byte[0] = `0x06`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `lt` | 12 | `u8` | — |
| `left_x` | 4 | `i8` | scale(-32768, 32767) |
| `rt` | 13 | `u8` | — |
| `right_x` | 6 | `i8` | scale(-32768, 32767) |
| `left_y` | 5 | `i8` | scale(-32768, 32767), negate |
| `right_y` | 7 | `i8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 0, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 20 |
| `M1` | 1 |
| `LT` | 9 |
| `DPadUp` | 4 |
| `DPadRight` | 7 |
| `RT` | 8 |
| `B` | 14 |
| `LS` | 3 |
| `RS` | 2 |
| `DPadDown` | 5 |
| `DPadLeft` | 6 |
| `X` | 13 |
| `LB` | 11 |
| `Home` | 0 |
| `RB` | 10 |
| `A` | 15 |
| `Select` | 23 |
| `Start` | 22 |
| `Y` | 12 |
| `M3` | 21 |

## Commands

| Name | Interface | Template |
|------|-----------|----------|
| `rumble` | 6 | `04 00 08 00 {strong:u8} {weak:u8} 00 00 00...` |

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
| `X` | `BTN_NORTH` |
| `LB` | `BTN_TL` |
| `RB` | `BTN_TR` |
| `A` | `BTN_SOUTH` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `Start` | `BTN_START` |
| `Y` | `BTN_WEST` |
| `M3` | `BTN_TRIGGER_HAPPY3` |

**Force feedback**: type=`rumble`, max_effects=16

