# Reference Tables

Quick reference for writing padctl device configs.

## Type Mapping

| Common HID representation | padctl `type` |
|--------------------------|---------------|
| unsigned byte | `"u8"` |
| signed byte | `"i8"` |
| 16-bit unsigned, little-endian | `"u16le"` |
| 16-bit signed, little-endian | `"i16le"` |
| 16-bit unsigned, big-endian | `"u16be"` |
| 16-bit signed, big-endian | `"i16be"` |
| single bit (boolean) | button_group entry |
| multi-bit enum (e.g. hat switch) | button_group per variant or hat field |

## Axis Transform

| Raw type | Transform needed |
|----------|-----------------|
| `u8` centered at 0x80 | `scale(-32768, 32767)` |
| `i8` centered at 0 | `scale(-32768, 32767)` |
| `i16le` centered at 0 | none (already full range) |
| `u8` trigger (0-255) | none |

## Linux Input Event Codes

| padctl button | Linux code | Notes |
|---------------|-----------|-------|
| A | `BTN_SOUTH` | Cross on PlayStation |
| B | `BTN_EAST` | Circle on PlayStation |
| X | `BTN_WEST` | Square on PlayStation |
| Y | `BTN_NORTH` | Triangle on PlayStation |
| LB | `BTN_TL` | L1 |
| RB | `BTN_TR` | R1 |
| Select | `BTN_SELECT` | Share/Create/View |
| Start | `BTN_START` | Options/Menu |
| Home | `BTN_MODE` | PS/Xbox/Guide |
| LS | `BTN_THUMBL` | L3 (stick click) |
| RS | `BTN_THUMBR` | R3 (stick click) |
| M1-M4 | `BTN_TRIGGER_HAPPY1-4` | Back paddles / extra buttons |

## MSB0 to LSB0 Bit Conversion

Some HID documentation and driver source code number bits in MSB0 order (bit 0 = most-significant bit). padctl `button_group` indices use LSB0 (bit 0 = least-significant bit).

**Single byte:**

```
lsb_bit = 7 - msb_bit          (msb_bit in 0..=7)
```

**Multi-byte group** (source window of N bytes):

```
lsb_bit = (msb_bit / 8) * 8 + (7 - (msb_bit % 8))
```

Example — a 2-byte button field starting at offset 0:

| Button | MSB0 bit | byte | bit-in-byte | LSB0 index |
|--------|----------|------|-------------|------------|
| DPadRight | 0 | 0 | 7 | 7 |
| DPadLeft  | 1 | 0 | 6 | 6 |
| DPadDown  | 2 | 0 | 5 | 5 |
| DPadUp    | 3 | 0 | 4 | 4 |
| L3        | 4 | 0 | 3 | 3 |
| R3        | 5 | 0 | 2 | 2 |
| Btn6      | 6 | 0 | 1 | 1 |
| Btn7      | 7 | 0 | 0 | 0 |
| A         | 8 | 1 | 7 | 15 |
| B         | 9 | 1 | 6 | 14 |
| X         | 10 | 1 | 5 | 13 |
| Y         | 11 | 1 | 4 | 12 |
| LB        | 12 | 1 | 3 | 11 |
| RB        | 13 | 1 | 2 | 10 |
| LT        | 14 | 1 | 1 | 9 |
| RT        | 15 | 1 | 0 | 8 |

## Common Pitfalls

- **MSB0 vs LSB0 bit order** — many HID reference drivers use MSB0 bit numbering. Copying bit indices directly without converting will cause buttons to trigger on wrong inputs. Always apply the conversion formula.
- **Padding bytes** — if the report is larger than the sum of declared fields, the extra bytes are padding. Do not declare fields for those offsets.
- **Multiple report IDs on one interface** — each report ID needs its own `[[report]]` block with a `[report.match]` section. Without `match`, padctl tries to parse every incoming buffer with every report definition.
- **Split / non-contiguous fields** — some devices store a single logical value across non-adjacent bytes (e.g., gyro_y with low byte at offset 18 and high byte at offset 20). padctl does not support split fields; these require a WASM plugin or a firmware mode that provides a contiguous layout.
- **Endianness of multi-byte scalars** — when referencing driver source code, check whether multi-byte fields are little-endian or big-endian. The default in many packed-struct frameworks is big-endian. Use `"i16be"` / `"u16be"` for big-endian fields.
- **Analog stick center value** — devices use either `u8` (center = 0x80) or `i8` (center = 0). Both benefit from `transform = "scale(-32768, 32767)"` to fill the full axis range expected by uinput.
