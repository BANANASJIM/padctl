# Sony DualSense

**VID:PID** `0x054c:0x0ce6`

**Vendor** sony

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 3 | hid | — | — |

## Report: `usb` (64 bytes, interface 3)

Match: byte[0] = `0x01`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `touch1_contact` | 37 | `u8` | — |
| `accel_x` | 22 | `i16le` | — |
| `sensor_timestamp` | 28 | `u32le` | — |
| `left_x` | 1 | `u8` | scale(-32768, 32767) |
| `touch0_contact` | 33 | `u8` | — |
| `lt` | 5 | `u8` | — |
| `accel_y` | 24 | `i16le` | — |
| `accel_z` | 26 | `i16le` | — |
| `gyro_z` | 20 | `i16le` | — |
| `gyro_y` | 18 | `i16le` | — |
| `battery_level` | bits[53,0,4] | `unsigned` | — |
| `right_x` | 3 | `u8` | scale(-32768, 32767) |
| `gyro_x` | 16 | `i16le` | — |
| `rt` | 6 | `u8` | — |
| `left_y` | 2 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 4 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 8, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `LT` | 10 |
| `Mic` | 18 |
| `RT` | 11 |
| `B` | 6 |
| `LS` | 14 |
| `RS` | 15 |
| `X` | 4 |
| `LB` | 8 |
| `RB` | 9 |
| `A` | 5 |
| `Select` | 12 |
| `Home` | 16 |
| `Start` | 13 |
| `Y` | 7 |
| `TouchPad` | 17 |

## Report: `bt` (78 bytes, interface 3)

Match: byte[0] = `0x31`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `touch1_contact` | 38 | `u8` | — |
| `accel_x` | 23 | `i16le` | — |
| `sensor_timestamp` | 29 | `u32le` | — |
| `left_x` | 2 | `u8` | scale(-32768, 32767) |
| `touch0_contact` | 34 | `u8` | — |
| `lt` | 6 | `u8` | — |
| `accel_y` | 25 | `i16le` | — |
| `accel_z` | 27 | `i16le` | — |
| `gyro_z` | 21 | `i16le` | — |
| `gyro_y` | 19 | `i16le` | — |
| `battery_level` | bits[54,0,4] | `unsigned` | — |
| `right_x` | 4 | `u8` | scale(-32768, 32767) |
| `gyro_x` | 17 | `i16le` | — |
| `rt` | 7 | `u8` | — |
| `left_y` | 3 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 5 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 9, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `LT` | 10 |
| `Mic` | 18 |
| `RT` | 11 |
| `B` | 6 |
| `LS` | 14 |
| `RS` | 15 |
| `X` | 4 |
| `LB` | 8 |
| `RB` | 9 |
| `A` | 5 |
| `Select` | 12 |
| `Home` | 16 |
| `Start` | 13 |
| `Y` | 7 |
| `TouchPad` | 17 |

## Commands

| Name | Interface | Template |
|------|-----------|----------|
| `led` | 3 | `02 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ...` |
| `rumble` | 3 | `02 01 00 {weak:u8} {strong:u8} 00 00 00 00 00 00 00 00 00 00...` |
| `adaptive_trigger_feedback` | 3 | `02 0c 00 00 00 00 00 00 00 00 00 01 {r_position:u8} {r_stren...` |
| `adaptive_trigger_vibration` | 3 | `02 0c 00 00 00 00 00 00 00 00 00 06 {r_position:u8} {r_ampli...` |
| `adaptive_trigger_weapon` | 3 | `02 0c 00 00 00 00 00 00 00 00 00 02 {r_start:u8} {r_end:u8} ...` |
| `adaptive_trigger_off` | 3 | `02 0c 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ...` |

## Output Capabilities

uinput device name: **Sony DualSense** | VID `0x054c` | PID `0x0ce6`

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
| `Mic` | `BTN_MISC` |
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
| `TouchPad` | `BTN_TOUCH` |

**Force feedback**: type=`rumble`, max_effects=16

