# Razer Wolverine V3 Pro (PC Tournament Mode)

**VID:PID** `0x1532:0x0a4c`

**Vendor** razer

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | vendor | — | — |

Logical interface `0` selects the physical USB interface by class/subclass/protocol `0xff/0x5d/0x01`. Its interrupt endpoints are resolved from the active alternate.

## Report: `xbox360` (20 bytes, interface 0)

Match: byte[0] = `0x00`, `0x14`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `lt` | 4 | `u8` | — |
| `left_x` | 6 | `i16le` | — |
| `rt` | 5 | `u8` | — |
| `right_x` | 10 | `i16le` | — |
| `left_y` | 8 | `i16le` | negate |
| `right_y` | 12 | `i16le` | negate |

### Button Map

Source: offset 2, size 2 byte(s)

| Button | Bit Index |
|--------|-----------|
| `DPadUp` | 0 |
| `DPadRight` | 3 |
| `B` | 13 |
| `DPadDown` | 1 |
| `DPadLeft` | 2 |
| `LS` | 6 |
| `RS` | 7 |
| `X` | 14 |
| `LB` | 8 |
| `RB` | 9 |
| `Select` | 5 |
| `Home` | 10 |
| `A` | 12 |
| `Start` | 4 |
| `Y` | 15 |

## Output Capabilities

uinput device name: **Xbox 360 Controller** | VID `0x045e` | PID `0x028e`

### Axes

| Field | Code | Min | Max | Fuzz | Flat |
|-------|------|-----|-----|------|------|
| `rt` | `ABS_RZ` | 0 | 255 | 0 | 0 |
| `left_x` | `ABS_X` | -32768 | 32767 | 16 | 128 |
| `right_x` | `ABS_RX` | -32768 | 32767 | 16 | 128 |
| `left_y` | `ABS_Y` | -32768 | 32767 | 16 | 128 |
| `right_y` | `ABS_RY` | -32768 | 32767 | 16 | 128 |
| `lt` | `ABS_Z` | 0 | 255 | 0 | 0 |

### Buttons

| Button | Event Code |
|--------|------------|
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
| `B` | `BTN_EAST` |

