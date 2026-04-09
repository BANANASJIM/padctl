# Device Config Reference

Device configs are TOML files in `devices/<vendor>/<model>.toml`.

## `[device]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable device name |
| `vid` | integer | yes | USB vendor ID (hex literal ok: `0x054c`) |
| `pid` | integer | yes | USB product ID |
| `mode` | string | no | Device mode identifier |

### `[[device.interface]]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | yes | USB interface number |
| `class` | string | yes | `"hid"` or `"vendor"` |
| `ep_in` | integer | no | IN endpoint number |
| `ep_out` | integer | no | OUT endpoint number |

### `[device.init]`

Optional initialization sequence sent after device open.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `commands` | string[] | yes | Hex byte strings sent in order |
| `response_prefix` | integer[] | yes | Expected response prefix bytes |
| `enable` | string | no | Hex byte string sent to activate extended mode (e.g. BT mode switch) |
| `disable` | string | no | Hex byte string sent on shutdown |
| `interface` | integer | no | Interface to send init commands on |
| `report_size` | integer | no | Expected report size after init |

## `[[report]]`

Describes one incoming HID report.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Report name (unique within device) |
| `interface` | integer | yes | Which interface this report arrives on |
| `size` | integer | yes | Report byte length |

### `[report.match]`

Disambiguates reports when multiple share an interface.

| Field | Type | Description |
|-------|------|-------------|
| `offset` | integer | Byte position to inspect |
| `expect` | integer[] | Expected bytes at that offset |

### `[report.fields]`

Inline table mapping field names to their layout:

```toml
[report.fields]
left_x = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
gyro_x = { offset = 16, type = "i16le" }
battery_level = { bits = [53, 0, 4] }
```

| Field | Type | Description |
|-------|------|-------------|
| `offset` | integer | Byte offset in report |
| `type` | string | Data type (see below) |
| `bits` | integer[3] | Sub-byte extraction: `[byte_offset, bit_offset, bit_count]` |
| `transform` | string | Comma-separated transform chain |

Use `offset` + `type` for whole-byte fields. Use `bits` for sub-byte bit extraction (e.g. a 4-bit battery level packed within a byte).

> **Note:** When using `bits`, the `type` field must be `null`, `"unsigned"`, or `"signed"` — standard type strings like `"u8"` or `"i16le"` are not valid.

#### Data Types

`u8` `i8` `u16le` `i16le` `u16be` `i16be` `u32le` `i32le` `u32be` `i32be`

#### Transform DSL

Transforms are applied left-to-right as a comma-separated chain:

| Transform | Description |
|-----------|-------------|
| `scale(min, max)` | Linearly scale the raw value to the target range |
| `negate` | Negate the value (multiply by -1) |
| `abs` | Take the absolute value |
| `clamp` | Clamp to the output axis range |
| `deadzone` | Apply deadzone filtering |

Example: `transform = "scale(-32768, 32767), negate"` — scales a u8 (0–255) to -32768..32767, then negates the result.

### `[report.button_group]`

Maps a contiguous byte range to named buttons via bit index.

```toml
[report.button_group]
source = { offset = 8, size = 3 }
map = { A = 5, B = 6, X = 4, Y = 7, LB = 8, RB = 9 }
```

Button names must be valid `ButtonId` values:

`A` `B` `X` `Y` `LB` `RB` `LT` `RT` `Start` `Select` `Home` `Capture` `LS` `RS` `DPadUp` `DPadDown` `DPadLeft` `DPadRight` `M1` `M2` `M3` `M4` `Paddle1` `Paddle2` `Paddle3` `Paddle4` `TouchPad` `Mic` `C` `Z` `LM` `RM` `O`

### `[report.checksum]`

Optional integrity check on the report.

| Field | Type | Description |
|-------|------|-------------|
| `algo` | string | `crc32` `sum8` `xor` |
| `range` | integer[2] | `[start, end]` byte range to checksum |
| `seed` | integer | Initial seed value prepended to CRC calculation (e.g. `0xa1` for DualSense BT) |
| `expect.offset` | integer | Where the checksum is stored in the report |
| `expect.type` | string | Storage type of the checksum field |

## `[commands.<name>]`

Output command templates (rumble, LED, adaptive triggers, etc.). Template placeholders use `{name:type}` syntax.

```toml
[commands.rumble]
interface = 3
template = "02 01 00 {weak:u8} {strong:u8} 00 ..."
```

### Adaptive Trigger Commands

DualSense-style adaptive triggers use a naming convention of `adaptive_trigger_<mode>`:

```toml
[commands.adaptive_trigger_off]
interface = 3
template = "02 0c 00 ..."

[commands.adaptive_trigger_feedback]
interface = 3
template = "02 0c 00 ... 01 {r_position:u8} {r_strength:u8} ... 01 {l_position:u8} {l_strength:u8} ..."

[commands.adaptive_trigger_weapon]
interface = 3
template = "02 0c 00 ... 02 {r_start:u8} {r_end:u8} {r_strength:u8} ... 02 {l_start:u8} {l_end:u8} {l_strength:u8} ..."

[commands.adaptive_trigger_vibration]
interface = 3
template = "02 0c 00 ... 06 {r_position:u8} {r_amplitude:u8} {r_frequency:u8} ... 06 {l_position:u8} {l_amplitude:u8} {l_frequency:u8} ..."
```

## `[output]`

Declares the uinput device emitted by padctl.

| Field | Type | Description |
|-------|------|-------------|
| `emulate` | string | Preset emulation profile |
| `name` | string | uinput device name |
| `vid` | integer | Emulated vendor ID |
| `pid` | integer | Emulated product ID |

### `[output.axes]`

```toml
[output.axes]
left_x = { code = "ABS_X", min = -32768, max = 32767, fuzz = 16, flat = 128 }
```

### `[output.buttons]`

```toml
[output.buttons]
A = "BTN_SOUTH"
B = "BTN_EAST"
```

### `[output.dpad]`

```toml
[output.dpad]
type = "hat"   # or "buttons"
```

### `[output.force_feedback]`

```toml
[output.force_feedback]
type = "rumble"
max_effects = 16
auto_stop = true     # default; set false to disable userspace auto-stop
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | string | — | Force-feedback type: `"rumble"` |
| `max_effects` | int | 16 | Maximum number of concurrent FF effect slots |
| `auto_stop` | bool | `true` | Enable userspace rumble auto-stop. When `true`, padctl emits a stop frame to the HID device after each effect's `replay.length` elapses — compensating for the fact that uinput does not use the kernel's `ff-memless` auto-stop timer. Set to `false` only for devices whose firmware handles auto-stop internally. |

### `[output.aux]`

Auxiliary output device (mouse or keyboard).

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"mouse"` or `"keyboard"` |
| `name` | string | uinput device name |
| `keyboard` | bool | Create keyboard capability |
| `buttons` | table | Button-to-event mapping |

### `[output.touchpad]`

Touchpad output device.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | uinput device name |
| `x_min` / `x_max` | integer | X axis range |
| `y_min` / `y_max` | integer | Y axis range |
| `max_slots` | integer | Maximum multitouch slots |

## `[wasm]`

WASM plugin for stateful/custom protocols (Phase 4+).

| Field | Type | Description |
|-------|------|-------------|
| `plugin` | string | Path to `.wasm` plugin file |

### `[wasm.overrides]`

| Field | Type | Description |
|-------|------|-------------|
| `process_report` | bool | Plugin handles report processing |
