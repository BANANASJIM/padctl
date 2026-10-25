# GameSir G7 Pro Amazon (wired)

**VID:PID** `0x3537:0x10ba`

**Vendor** gamesir

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | vendor | 130 | 2 |

## Session Maintenance

Interface 0; `0f000002f200` padded to 64 bytes; sequence byte 2 starts at 1 and cycles 1–255 (zero skipped).

The first 3 completed packets use a 50 ms interval before the next packet; subsequent intervals are 450 ms. Timing starts from write completion, without catch-up bursts. Three consecutive write failures end the session.

## Report: `telemetry` (64 bytes, interface 0)

Match: byte[3] = `0x3c`, `0xe0`

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `dpad` | bits[55,0,4] | `unsigned` | — |
| `right_y` | 8 | `u8` | scale(-32768, 32767) |
| `left_x` | 5 | `u8` | scale(-32768, 32767) |
| `rt` | 13 | `u8` | — |
| `right_x` | 7 | `u8` | scale(-32768, 32767) |
| `lt` | 12 | `u8` | — |
| `left_y` | 6 | `u8` | scale(-32768, 32767) |

### Button Map

Source: offset 55, size 4 byte(s)

| Button | Bit Index |
|--------|-----------|
| `Capture` | 17 |
| `M2` | 20 |
| `M1` | 19 |
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
| `M3` | 24 |
| `M4` | 25 |

## Output Capabilities

uinput device name: **Xbox Elite Series 2 GameSir** | VID `0x045e` | PID `0x0b00`

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
| `Capture` | `BTN_MISC` |
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
| `M4` | `BTN_TRIGGER_HAPPY4` |

