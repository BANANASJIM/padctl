# Device TOML from InputPlumber Rust Structs

This guide explains how to convert an [InputPlumber](https://github.com/ShadowBlip/InputPlumber) device driver (Rust packed struct) into a padctl `devices/<vendor>/<model>.toml`.

## License Note

InputPlumber is GPL-3.0.  Protocol facts — byte offsets, field types, VID/PID, bit positions — are not copyrightable (Feist v. Rural, 1991).  You may use them freely.  **Do not copy Rust source code or comment text verbatim.**

---

## 1. Overview of the Mapping

InputPlumber describes HID reports as Rust packed structs annotated with `#[packed_field(...)]`.  padctl describes them as TOML tables.  The two representations carry the same information but differ in:

| Concern | InputPlumber | padctl |
|---------|-------------|--------|
| Byte offset | `bytes = "N"` or `bytes = "N..=M"` | `offset = N` |
| Integer type | Rust type + `endian = "lsb"` | `type = "u8" / "i16le" / …` |
| Bit numbering | MSB0 (bit 0 = most-significant bit) | LSB0 (bit 0 = least-significant bit) |
| Buttons | individual fields or bitfield enums | `[report.button_group]` with LSB0 indices |
| Multi-report device | multiple struct definitions | multiple `[[report]]` blocks |

---

## 2. MSB0 → LSB0 Bit Number Conversion

InputPlumber uses `bit_numbering = "msb0"` throughout.  padctl `button_group` indices are LSB0 within the source byte window.

**Same-byte formula:**

```
lsb_bit = 7 - msb_bit          (within one byte, msb_bit in 0..=7)
```

**Multi-byte group formula** (source window of N bytes, read as a LE integer):

```
lsb_bit = (msb_bit / 8) * 8 + (7 - (msb_bit % 8))
```

Where `msb_bit` is the zero-based bit position in InputPlumber's flat MSB0 numbering across the struct.

**Example:**

InputPlumber MSB0 layout for a 2-byte button field starting at offset 0:

| Button | MSB0 bit | byte | bit-in-byte | LSB0 index |
|--------|----------|------|-------------|------------|
| DPadRight | 0 | 0 | 7 | 7 |
| DPadLeft  | 1 | 0 | 6 | 6 |
| DPadDown  | 2 | 0 | 5 | 5 |
| DPadUp    | 3 | 0 | 4 | 4 |
| L3        | 4 | 0 | 3 | 3 |
| R3        | 5 | 0 | 2 | 2 |
| QuickAccess | 6 | 0 | 1 | 1 |
| Legion    | 7 | 0 | 0 | 0 |
| A         | 8 | 1 | 7 | 15 |
| B         | 9 | 1 | 6 | 14 |
| X         | 10 | 1 | 5 | 13 |
| Y         | 11 | 1 | 4 | 12 |
| LB        | 12 | 1 | 3 | 11 |
| RB        | 13 | 1 | 2 | 10 |
| LT_dig    | 14 | 1 | 1 | 9 |
| RT_dig    | 15 | 1 | 0 | 8 |

---

## 3. Step-by-Step Process

### Step 1 — Find the Rust driver

Look in `src/drivers/<device>/` in the InputPlumber repo.  The main file is usually `hid_report.rs` or `report.rs`.  Find the struct annotated with:

```rust
#[packed_struct(bit_numbering = "msb0", size_bytes = "N")]
pub struct InputState { … }
```

### Step 2 — Extract VID / PID

Check the device's `mod.rs` or the YAML files in `rootfs/usr/share/inputplumber/devices/`.  Look for `vendor_id` / `product_id` fields.  Use these as `vid` and `pid` in `[device]`.

### Step 3 — Map interfaces

Look at how the driver opens the device (USB interface numbers, hidraw).  Declare one `[[device.interface]]` per interface used.  `class = "hid"` for hidraw; `class = "vendor"` for raw USB bulk transfers.

### Step 4 — Convert each report struct to `[[report]]`

For each struct:

1. Set `size` to `size_bytes` from the annotation.
2. Set `interface` to the interface that delivers this report.
3. If the device sends multiple report IDs on one interface, add `[report.match]` with `offset = 0` and `expect = [report_id]`.
4. For each `#[packed_field(bytes = "N")]` scalar field: write `field_name = { offset = N, type = "..." }`.
5. For each `#[packed_field(bytes = "N..=M", endian = "lsb")]` multi-byte field: write `offset = N, type = "i16le"` (or the appropriate width).
6. Collect all button/boolean fields into `[report.button_group]` (see below).

### Step 5 — Convert button bitfields

Gather all single-bit boolean fields and enum-based button fields into one `[report.button_group]`:

```toml
[report.button_group]
source = { offset = <first_byte>, size = <byte_count> }
map = { ButtonName = <lsb_index>, … }
```

Apply the MSB0 → LSB0 formula from §2 to each bit position.

### Step 6 — Add output report / rumble command

Find the output struct (look for `set_rumble`, `rumble`, or `output_report` in the driver).  Translate the fixed bytes and variable fields into a `[commands.rumble]` template string.

### Step 7 — Declare `[output]`

Choose an emulation target (Xbox Elite Series 2 is a safe default for games that auto-configure XInput).  Map the padctl logical field names to Linux input event codes.

---

## 4. Type Mapping Reference

| Rust type (InputPlumber) | `packed_field` attributes | padctl `type` |
|--------------------------|--------------------------|---------------|
| `u8` | `bytes = "N"` | `"u8"` |
| `i8` | `bytes = "N"` | `"i8"` |
| `u16` | `bytes = "N..=N+1", endian = "lsb"` | `"u16le"` |
| `i16` | `bytes = "N..=N+1", endian = "lsb"` | `"i16le"` |
| `u16` | `bytes = "N..=N+1", endian = "msb"` | `"u16be"` |
| `bool` / single-bit | `bits = "M"` | button_group entry |
| enum (button directions) | `bits = "M..=N"` | needs lookup or button_group per variant |

### Axis transform patterns

| Hardware range | padctl transform |
|---------------|-----------------|
| u8, center = 0x80 | `transform = "scale(-32768, 32767)"` |
| i8, center = 0 | scale is identity for ±128 range; apply `transform = "scale(-32768, 32767)"` to normalise to ±32767 |
| u8, 0 = released (trigger) | `type = "u8"` (no transform; output axis `min=0, max=255`) |

---

## 5. Full Walkthrough: Legion Go S

**Source:** InputPlumber `src/drivers/lego/legion_go_s/`
**VID:** `0x1a86`  **PID (XInput):** `0xe310`  **PID (DInput):** `0xe311`

The device exposes three HID interfaces:
- Interface 2 — touchpad report (report_id `0x02`, 10B)
- Interface 5 — IMU report (report_id `0x01` accel / `0x02` gyro, 9B)
- Interface 6 — gamepad report (report_id `0x06`, 32B) + rumble output (report_id `0x04`, 9B)

This walkthrough covers the gamepad interface (interface 6) only, which is sufficient for a functional padctl config.

### 5.1 Gamepad input report (32B, report_id 0x06)

InputPlumber struct layout (abridged):

```rust
#[packed_struct(bit_numbering = "msb0", size_bytes = "32")]
pub struct GamepadInputDataReport {
    // bytes 0–1: 16 button bits (MSB0 order)
    #[packed_field(bits = "0")]  pub dpad_right:    bool,   // MSB0 0
    #[packed_field(bits = "1")]  pub dpad_left:     bool,   // MSB0 1
    #[packed_field(bits = "2")]  pub dpad_down:     bool,   // MSB0 2
    #[packed_field(bits = "3")]  pub dpad_up:       bool,   // MSB0 3
    #[packed_field(bits = "4")]  pub btn_l3:        bool,   // MSB0 4
    #[packed_field(bits = "5")]  pub btn_r3:        bool,   // MSB0 5
    #[packed_field(bits = "6")]  pub quick_access:  bool,   // MSB0 6
    #[packed_field(bits = "7")]  pub btn_legion:    bool,   // MSB0 7
    #[packed_field(bits = "8")]  pub btn_a:         bool,   // MSB0 8
    #[packed_field(bits = "9")]  pub btn_b:         bool,   // MSB0 9
    #[packed_field(bits = "10")] pub btn_x:         bool,   // MSB0 10
    #[packed_field(bits = "11")] pub btn_y:         bool,   // MSB0 11
    #[packed_field(bits = "12")] pub btn_lb:        bool,   // MSB0 12
    #[packed_field(bits = "13")] pub btn_rb:        bool,   // MSB0 13
    #[packed_field(bits = "14")] pub lt_digital:    bool,   // MSB0 14
    #[packed_field(bits = "15")] pub rt_digital:    bool,   // MSB0 15
    // bytes 2–3: more buttons
    #[packed_field(bits = "16")] pub btn_view:      bool,   // MSB0 16
    #[packed_field(bits = "17")] pub btn_menu:      bool,   // MSB0 17
    #[packed_field(bits = "18")] pub btn_y2:        bool,   // MSB0 18
    #[packed_field(bits = "19")] pub btn_y1:        bool,   // MSB0 19
    // bytes 4–7: analog sticks (i8, center = 0)
    #[packed_field(bytes = "4")]  pub left_stick_x:  i8,
    #[packed_field(bytes = "5")]  pub left_stick_y:  i8,
    #[packed_field(bytes = "6")]  pub right_stick_x: i8,
    #[packed_field(bytes = "7")]  pub right_stick_y: i8,
    // bytes 12–13: analog triggers (u8, 0 = released)
    #[packed_field(bytes = "12")] pub left_trigger:  u8,
    #[packed_field(bytes = "13")] pub right_trigger: u8,
}
```

**Converting sticks** — `i8` centered at 0, range −128..127.  Scale to −32768..32767:

```toml
left_x  = { offset = 4, type = "i8", transform = "scale(-32768, 32767)" }
left_y  = { offset = 5, type = "i8", transform = "scale(-32768, 32767), negate" }
right_x = { offset = 6, type = "i8", transform = "scale(-32768, 32767)" }
right_y = { offset = 7, type = "i8", transform = "scale(-32768, 32767), negate" }
```

Y axes are negated because InputPlumber raw values have +Y = down; uinput convention has +Y = down for ABS_Y but games expect +Y = up, so we match the DualSense convention.

**Converting buttons** — apply the multi-byte formula:

```
lsb_bit = (msb_bit / 8) * 8 + (7 - msb_bit % 8)
```

padctl `button_group` map keys must be valid `ButtonId` names (`A, B, X, Y, LB, RB, LT, RT, Start, Select, Home, Capture, LS, RS, DPadUp, DPadDown, DPadLeft, DPadRight, M1–M4, Paddle1–4, TouchPad, Mic`).  Device-specific buttons without a standard equivalent use `M1`/`M2`/`M3`/`M4`.

| Device button | ButtonId | MSB0 | lsb_bit |
|---------------|----------|------|---------|
| DPadRight | DPadRight | 0 | 7 |
| DPadLeft | DPadLeft | 1 | 6 |
| DPadDown | DPadDown | 2 | 5 |
| DPadUp | DPadUp | 3 | 4 |
| L3 (stick click) | LS | 4 | 3 |
| R3 (stick click) | RS | 5 | 2 |
| QuickAccess | M1 | 6 | 1 |
| Legion | Home | 7 | 0 |
| A | A | 8 | 15 |
| B | B | 9 | 14 |
| X | X | 10 | 13 |
| Y | Y | 11 | 12 |
| LB | LB | 12 | 11 |
| RB | RB | 13 | 10 |
| LT digital | LT | 14 | 9 |
| RT digital | RT | 15 | 8 |
| View | Select | 16 | 23 |
| Menu | Start | 17 | 22 |
| Y2 | M3 | 18 | 21 |
| Y1 | M2 | 19 | 20 |

The source window covers bytes 0–3 (size = 4):

```toml
[report.button_group]
source = { offset = 0, size = 4 }
map = { DPadRight = 7, DPadLeft = 6, DPadDown = 5, DPadUp = 4, LS = 3, RS = 2, M1 = 1, Home = 0, A = 15, B = 14, X = 13, Y = 12, LB = 11, RB = 10, LT = 9, RT = 8, Select = 23, Start = 22, M2 = 20, M3 = 21 }
```

### 5.2 Rumble output (9B, report_id 0x04)

From InputPlumber's output handler:

```
bytes: 0x04  0x00  0x08  0x00  <L_motor:u8>  <R_motor:u8>  0x00  0x00  0x00
```

```toml
[commands.rumble]
interface = 6
template = "04 00 08 00 {strong:u8} {weak:u8} 00 00 00"
```

### 5.3 Resulting TOML

See `devices/lenovo/legion-go-s.toml` in this repository for the complete file produced by applying this walkthrough.

---

## 6. Common Pitfalls

### Big-endian bit order (MSB0)

Every InputPlumber struct uses `bit_numbering = "msb0"`.  Forgetting to convert produces buttons that trigger on wrong inputs.  Always apply the formula — do not copy bit numbers directly.

### packed_struct padding bytes

When `size_bytes` is larger than the sum of declared fields, the remaining bytes are padding.  You can ignore them in padctl (just don't declare fields for those offsets).

### Multiple report IDs on one interface

If a device sends reports with different IDs on the same interface, each needs its own `[[report]]` block with a `[report.match]` that checks `offset = 0` (the report ID byte) against the expected value.  Without `match`, padctl would try to parse every incoming buffer with every report definition.

### Split / non-contiguous fields

Some devices store a single logical value across non-adjacent bytes (e.g., Flydigi Vader 4 Pro gyro_y: low byte at offset 18, high byte at offset 20).  padctl does not have a `split_bytes` field; these require a custom WASM plugin or a firmware mode switch that provides a contiguous layout.

### Endianness of multi-byte scalars

InputPlumber always annotates multi-byte fields with `endian = "lsb"` (little-endian) or `endian = "msb"` (big-endian).  The default in Rust `packed_struct` is big-endian when no `endian` is specified.  Use `"i16be"` / `"u16be"` for those.

### Analog stick center value

InputPlumber devices use either `i8` (center = 0) or `u8` (center = 0x80 = 128).  A `u8` stick needs `transform = "scale(-32768, 32767)"` to map 0→−32768 and 255→32767.  An `i8` stick at center = 0 also benefits from `scale(-32768, 32767)` to fill the full ±32767 axis range expected by uinput.
