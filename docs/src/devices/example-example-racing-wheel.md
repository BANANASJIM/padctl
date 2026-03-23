# Example Racing Wheel

**VID:PID** `0x044f:0xb66e`

**Vendor** example

## Interfaces

| ID | Class | EP IN | EP OUT |
|----|-------|-------|--------|
| 0 | hid | — | — |

## Report: `main` (12 bytes, interface 0)

### Fields

| Name | Offset | Type | Transform |
|------|--------|------|-----------|
| `gas_pedal` | 2 | `u8` | negate |
| `clutch` | 4 | `u8` | — |
| `wheel_angle` | 0 | `i16le` | — |
| `brake_pedal` | 3 | `u8` | — |

### Button Map

Source: offset 5, size 1 byte(s)

| Button | Bit Index |
|--------|-----------|
| `gear_down` | 1 |
| `paddle_right` | 3 |
| `gear_up` | 0 |
| `paddle_left` | 2 |

## Output Capabilities

uinput device name: **Example Racing Wheel** | VID `0x044f` | PID `0xb66e`

