# Flydigi Vader 5 Pro

**VID:PID** `0x37d7:0x2401`

**Vendor** flydigi

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 1 | hid | — | — |

## Report: `extended` (32 bytes, interface 1)

Match: byte[0] = `0x5a`, `0xa5`, `0xef`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `left_y` | 5 | `i16le` | negate |
| `right_y` | 9 | `i16le` | negate |
| `accel_x` | 23 | `i16le` | — |
| `gyro_z` | 21 | `i16le` | — |
| `gyro_x` | 17 | `i16le` | — |
| `gyro_y` | 19 | `i16le` | — |
| `accel_z` | 27 | `i16le` | — |
| `accel_y` | 25 | `i16le` | — |
| `left_x` | 3 | `i16le` | — |
| `rt` | 16 | `u8` | — |
| `lt` | 15 | `u8` | — |
| `right_x` | 7 | `i16le` | — |

### Button Map

Source: offset 11, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `M2` | 19 |
| `M4` | 21 |
| `M1` | 18 |
| `DPadUp` | 0 |
| `DPadRight` | 1 |
| `RM` | 23 |
| `LM` | 22 |
| `B` | 5 |
| `DPadDown` | 2 |
| `DPadLeft` | 3 |
| `X` | 7 |
| `LS` | 14 |
| `RS` | 15 |
| `LB` | 10 |
| `A` | 4 |
| `Select` | 6 |
| `RB` | 11 |
| `C` | 16 |
| `Z` | 17 |
| `Home` | 27 |
| `Start` | 9 |
| `O` | 24 |
| `Y` | 8 |
| `M3` | 20 |

## Commands

| Name | Interface | Template |
|------|-----------|----------|
| `rumble` | 1 | `5aa5 1206 {strong:u8} {weak:u8} 0000 0000...` |

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
| `M4` | `BTN_TRIGGER_HAPPY4` |
| `M1` | `BTN_TRIGGER_HAPPY1` |
| `RM` | `BTN_TRIGGER_HAPPY8` |
| `LM` | `BTN_TRIGGER_HAPPY7` |
| `B` | `BTN_EAST` |
| `LS` | `BTN_THUMBL` |
| `RS` | `BTN_THUMBR` |
| `X` | `BTN_NORTH` |
| `Z` | `BTN_TRIGGER_HAPPY6` |
| `LB` | `BTN_TL` |
| `RB` | `BTN_TR` |
| `A` | `BTN_SOUTH` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `C` | `BTN_TRIGGER_HAPPY5` |
| `Start` | `BTN_START` |
| `O` | `BTN_TRIGGER_HAPPY9` |
| `Y` | `BTN_WEST` |
| `M3` | `BTN_TRIGGER_HAPPY3` |

**Force feedback**: type=`rumble`, max_effects=16

