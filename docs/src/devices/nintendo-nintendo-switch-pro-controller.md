# Nintendo Switch Pro Controller

**VID:PID** `0x057e:0x2009`

**Vendor** nintendo

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `bt_standard` (49 bytes, interface 0)

Match: byte[0] = `0x30`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `left_y_raw` | 7 | `u8` | — |
| `right_x_raw` | 9 | `u8` | — |
| `right_y_raw` | 10 | `u8` | — |
| `left_x_raw` | 6 | `u8` | — |

### Button Map

Source: offset 3, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `Capture` | 13 |
| `LT` | 23 |
| `DPadUp` | 17 |
| `RT` | 7 |
| `DPadRight` | 18 |
| `B` | 2 |
| `LS` | 11 |
| `RS` | 10 |
| `X` | 1 |
| `DPadDown` | 16 |
| `DPadLeft` | 19 |
| `LB` | 22 |
| `RB` | 6 |
| `A` | 3 |
| `Select` | 8 |
| `Home` | 12 |
| `Start` | 9 |
| `Y` | 0 |

## Output Capabilities

uinput device name: **Nintendo Switch Pro Controller** | VID `0x057e` | PID `0x2009`

### Axes

| Field | Code | Min | Max | Fuzz | Flat |
|-------|------|-----|-----|------|------|
| `left_x` | `ABS_X` | -32768 | 32767 | 16 | 128 |
| `right_x` | `ABS_RX` | -32768 | 32767 | 16 | 128 |
| `left_y` | `ABS_Y` | -32768 | 32767 | 16 | 128 |
| `right_y` | `ABS_RY` | -32768 | 32767 | 16 | 128 |

### Buttons

| Button | Event Code |
|--------|------------|
| `Capture` | `BTN_MISC` |
| `LT` | `BTN_TL2` |
| `RT` | `BTN_TR2` |
| `B` | `BTN_SOUTH` |
| `LS` | `BTN_THUMBL` |
| `RS` | `BTN_THUMBR` |
| `X` | `BTN_NORTH` |
| `LB` | `BTN_TL` |
| `RB` | `BTN_TR` |
| `A` | `BTN_EAST` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `Start` | `BTN_START` |
| `Y` | `BTN_WEST` |

