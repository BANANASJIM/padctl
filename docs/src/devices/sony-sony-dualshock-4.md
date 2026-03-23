# Sony DualShock 4

**VID:PID** `0x054c:0x05c4`

**Vendor** sony

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `usb` (64 bytes, interface 0)

Match: byte[0] = `0x01`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `touch1_contact` | 37 | `u8` | — |
| `accel_x` | 20 | `i16le` | — |
| `left_x` | 1 | `u8` | scale(-32768, 32767) |
| `touch0_contact` | 33 | `u8` | — |
| `lt` | 9 | `u8` | — |
| `accel_y` | 22 | `i16le` | — |
| `accel_z` | 24 | `i16le` | — |
| `gyro_z` | 18 | `i16le` | — |
| `gyro_x` | 14 | `i16le` | — |
| `battery_level` | bits[30,0,4] | `unsigned` | — |
| `right_x` | 3 | `u8` | scale(-32768, 32767) |
| `rt` | 10 | `u8` | — |
| `gyro_y` | 16 | `i16le` | — |
| `left_y` | 2 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 4 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 5, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `LT` | 10 |
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

## Report: `bt` (78 bytes, interface 0)

Match: byte[0] = `0x11`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `touch1_contact` | 39 | `u8` | — |
| `accel_x` | 22 | `i16le` | — |
| `left_x` | 3 | `u8` | scale(-32768, 32767) |
| `touch0_contact` | 35 | `u8` | — |
| `lt` | 11 | `u8` | — |
| `accel_y` | 24 | `i16le` | — |
| `accel_z` | 26 | `i16le` | — |
| `gyro_z` | 20 | `i16le` | — |
| `gyro_x` | 16 | `i16le` | — |
| `battery_level` | bits[32,0,4] | `unsigned` | — |
| `right_x` | 5 | `u8` | scale(-32768, 32767) |
| `rt` | 12 | `u8` | — |
| `gyro_y` | 18 | `i16le` | — |
| `left_y` | 4 | `u8` | scale(-32768, 32767), negate |
| `right_y` | 6 | `u8` | scale(-32768, 32767), negate |

### Button Map

Source: offset 7, size 3 byte(s)

| Button | Bit Index |
|--------|-----------|
| `LT` | 10 |
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
| `led` | 0 | `05 ff 00 00 00 00 {r:u8} {g:u8} {b:u8} 00 00 00 00 00 00 00 ...` |
| `rumble` | 0 | `05 ff 00 00 {weak:u8} {strong:u8} 00 00 00 00 00 00 00 00 00...` |

## Output Capabilities

uinput device name: **Sony DualShock 4** | VID `0x054c` | PID `0x05c4`

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
| `B` | `BTN_EAST` |
| `LB` | `BTN_TL` |
| `RB` | `BTN_TR` |
| `A` | `BTN_SOUTH` |
| `Select` | `BTN_SELECT` |
| `Home` | `BTN_MODE` |
| `Start` | `BTN_START` |
| `Y` | `BTN_NORTH` |
| `TouchPad` | `BTN_TOUCH` |

**Force feedback**: type=`rumble`, max_effects=16

