# Device Config Reference

Device configs are TOML files in `devices/<vendor>/<model>.toml`.

## `[device]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable device name |
| `vid` | integer | yes | USB vendor ID (hex literal ok: `0x054c`) |
| `pid` | integer | yes | USB product ID |

### `[[device.interface]]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | yes | USB interface number |
| `class` | string | yes | `"hid"` or `"vendor"` |
| `ep_in` | integer | no | IN endpoint number |
| `ep_out` | integer | no | OUT endpoint number |

### `[device.init]`

Optional initialization sequence sent after open.

| Field | Type | Description |
|-------|------|-------------|
| `commands` | string[] | Hex byte strings sent in order |
| `response_prefix` | integer[] | Expected response prefix bytes |

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
```

| Field | Type | Values |
|-------|------|--------|
| `offset` | integer | Byte offset in report |
| `type` | string | `u8` `i8` `u16le` `i16le` `u16be` `i16be` `u32le` `i32le` `u32be` `i32be` |
| `transform` | string | Comma-separated chain: `scale(min,max)` `negate` `abs` `clamp` `deadzone` `lookup` |

### `[report.button_group]`

Maps a contiguous byte range to named buttons via bit index.

```toml
[report.button_group]
source = { offset = 8, size = 3 }
map = { A = 0, B = 1, X = 3, Y = 4 }
```

### `[report.checksum]`

Optional integrity check on the report.

| Field | Type | Description |
|-------|------|-------------|
| `algo` | string | `crc32` `crc8` `xor` `none` |
| `range` | integer[2] | `[start, end]` byte range to checksum |
| `expect.offset` | integer | Where the checksum is stored in the report |
| `expect.type` | string | Storage type of the checksum field |

## `[commands.<name>]`

Output command templates (rumble, LED, etc.).

```toml
[commands.rumble]
interface = 3
template = "02 01 00 {weak:u8} {strong:u8} 00 ..."
```

## `[output]`

Declares the uinput device emitted by padctl.

| Field | Type | Description |
|-------|------|-------------|
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
```
