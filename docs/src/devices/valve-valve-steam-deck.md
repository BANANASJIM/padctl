# Valve Steam Deck

**VID:PID** `0x28de:0x1205`

**Vendor** valve

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `main` (64 bytes, interface 0)

Match: byte[1] = `0x09`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `touch1_y` | 22 | `i16le` | — |
| `touch0_y` | 18 | `i16le` | — |
| `accel_x` | 24 | `i16le` | — |
| `touch0_x` | 16 | `i16le` | — |
| `left_x` | 48 | `i16le` | — |
| `lt` | 44 | `u16le` | scale(0, 255) |
| `touch1_x` | 20 | `i16le` | — |
| `touch1_active` | bits[10,4,1] | `unsigned` | — |
| `touch0_active` | bits[10,3,1] | `unsigned` | — |
| `accel_y` | 26 | `i16le` | — |
| `accel_z` | 28 | `i16le` | — |
| `gyro_z` | 34 | `i16le` | — |
| `gyro_x` | 30 | `i16le` | — |
| `gyro_y` | 32 | `i16le` | — |
| `right_x` | 52 | `i16le` | — |
| `rt` | 46 | `u16le` | scale(0, 255) |
| `left_y` | 50 | `i16le` | negate |
| `right_y` | 54 | `i16le` | negate |

### Button Map

Source: offset 8, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 13 |
| `LT` | 1 |
| `M1` | 12 |
| `DPadUp` | 8 |
| `RT` | 0 |
| `DPadRight` | 9 |
| `B` | 5 |
| `LS` | 3 |
| `RS` | 2 |
| `X` | 6 |
| `DPadLeft` | 10 |
| `DPadDown` | 11 |
| `A` | 7 |
| `Home` | 17 |
| `Select` | 18 |
| `M4` | 15 |
| `Y` | 4 |
| `M3` | 14 |
| `Start` | 16 |

## Commands

| Name | Interface | Template |
|------|-----------|----------|
| `rumble` | 0 | `8f 00 {strong:u8} 00 00 10 00 01 00...` |

## Output Capabilities

uinput device name: **Valve Steam Deck** | VID `0x28de` | PID `0x1205`

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
| `A` | `BTN_SOUTH` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `Start` | `BTN_START` |
| `Y` | `BTN_NORTH` |
| `M3` | `BTN_TRIGGER_HAPPY3` |
| `M4` | `BTN_TRIGGER_HAPPY4` |

**Force feedback**: type=`rumble`, max_effects=4

