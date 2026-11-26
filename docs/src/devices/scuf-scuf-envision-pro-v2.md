# SCUF Envision Pro V2

**VID:PID** `0x1b1c:0x3a08`

**Vendor** scuf

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 3 | hid | — | — |

## Report: `main` (16 bytes, interface 3)

Match: byte[0] = `0x06`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `dpad` | bits[11,4,4] | `unsigned` | — |
| `right_y` | 7 | `i16le` | — |
| `left_x` | 1 | `i16le` | — |
| `rt` | bits[10,2,10] | `unsigned` | scale(0, 255) |
| `right_x` | 5 | `i16le` | — |
| `lt` | bits[9,0,10] | `unsigned` | scale(0, 255) |
| `left_y` | 3 | `i16le` | — |

### Button Map

Source: offset 12, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 20 |
| `M4` | 22 |
| `M1` | 19 |
| `RM` | 24 |
| `LM` | 23 |
| `B` | 1 |
| `LS` | 8 |
| `RS` | 9 |
| `X` | 2 |
| `Z` | 13 |
| `LB` | 4 |
| `RB` | 5 |
| `A` | 0 |
| `Select` | 6 |
| `Home` | 11 |
| `C` | 12 |
| `Start` | 7 |
| `O` | 14 |
| `Y` | 3 |
| `M3` | 21 |

## Output Capabilities

uinput device name: **SCUF Envision Pro V2** | VID `0x045e` | PID `0x0b00`

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
| `M2` | `BTN_TRIGGER_HAPPY7` |
| `M1` | `BTN_TRIGGER_HAPPY8` |
| `RM` | `BTN_TRIGGER_HAPPY12` |
| `LM` | `BTN_TRIGGER_HAPPY11` |
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
| `M3` | `BTN_TRIGGER_HAPPY6` |
| `M4` | `BTN_TRIGGER_HAPPY5` |

