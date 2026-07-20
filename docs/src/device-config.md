# Device Config Reference

Device configs are TOML files in `devices/<vendor>/<model>.toml`.

## `[device]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable device name |
| `vid` | integer | yes | USB vendor ID (hex literal ok: `0x054c`) |
| `pid` | integer | yes | USB product ID |
| `mode` | string | no | Device mode identifier |
| `block_kernel_drivers` | string[] | no | Kernel driver names to unbind via udev, e.g. `block_kernel_drivers = ["xpad"]`. The generated rule only detaches the kernel driver while a padctl daemon is running (its control socket exists), so a stopped daemon leaves the device to the kernel driver. When `padctl install` runs as root, it also walks `/sys/bus/usb/drivers/<driver>/unbind` for matching VID:PID pairs immediately. |

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
| `commands` | string[] | no | Hex byte strings sent in order |
| `response_prefix` | integer[] | no | Expected response prefix bytes. It may be omitted when command-prefix correlation alone identifies replies. |
| `response_command_prefix_len` | integer | no | Also require the response to match the first N bytes of the command just sent. Before each correlated command, a bounded best-effort drain reduces stale-response risk; this is not a transport transaction barrier. Use this when unsolicited input reports share `response_prefix` with command replies. |
| `enable` | string | no | Hex byte string sent to activate extended mode (e.g. BT mode switch) |
| `disable` | string | no | Reserved shutdown hex command. It is parsed but the current runtime does not send it yet. |
| `interface` | integer | no | Interface to send init commands on |
| `report_size` | integer | no | Expected report size after init |
| `require_response` | bool | no | When `true`, `commands` or `enable` and at least one ACK criterion are required; failure to receive a response matching every configured criterion fails init/re-init instead of continuing. Use for devices whose input reports are valid only after an acknowledged mode switch. |
| `feature_report` | integer[] | no | HID feature report sent via `HIDIOCSFEATURE` immediately after `commands`. Encoded as a list of byte values (0–255); `byte[0]` is the report ID. |

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

| Field | Type | Description |
|-------|------|-------------|
| `source.offset` | integer | Starting byte offset within the report |
| `source.size` | integer | Group width in bytes; must be `1..=8` (the interpreter packs the group into a u64; values above 8 are skipped at parse time with a warning logged to stderr and the report group falls back to all buttons unmapped) |
| `map` | table | `Button = bit_index`. Bit indexes must satisfy `0 <= bit_index < size * 8`. |

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
| `default_profile` | string | Optional name for the default `[output]` profile |
| `name` | string | uinput device name |
| `vid` | integer | Emulated vendor ID |
| `pid` | integer | Emulated product ID |

Built-in `emulate` profiles:

| Profile | VID:PID | Notes |
|---------|---------|-------|
| `xbox-360` | `045e:028e` | Standard Xbox 360 layout |
| `xbox-elite2` | `045e:0b00` | Xbox Elite Series 2 identity |
| `dualsense` | `054c:0ce6` | DualSense identity with touchpad and mic buttons |
| `dualsense-edge` | `054c:0df2` | DualSense Edge identity, high-resolution stick ranges, and `M1`-`M4` mapped to `BTN_TRIGGER_HAPPY1`-`BTN_TRIGGER_HAPPY4` |
| `switch-pro` | `057e:2009` | Nintendo Switch Pro layout |

`emulate` fills only missing `[output]` fields. Explicit `vid`, `pid`, `name`,
`[output.axes]`, or `[output.buttons]` entries remain authoritative, so a device
can use a preset identity without losing device-specific stick ranges or extra
button layout.

These profiles define the virtual gamepad identity and generic evdev/HID button
layout. They do not synthesize vendor-specific HIDAPI reports such as native
DualSense gyro, adaptive trigger, or touchpad packet formats.

For `dualsense-edge`, the preset is an output identity and layout preset. It is
useful when a client keys behavior from VID/PID and generic button layout, but
it is not a complete DualSense Edge firmware clone. If a physical controller has
higher-resolution sticks than the preset defaults, keep explicit
`[output.axes]` entries in the device TOML; explicit axis ranges override the
preset and prevent accidental precision loss.

### Output profiles

Device configs may declare named output profiles under `[output.profiles.<name>]`.
The default `[output]` remains active unless the user selects a profile in
`config.toml`:

```toml
# ~/.config/padctl/config.toml
version = 1

[[device]]
name = "Flydigi Vader 5 Pro"
default_mapping = "vader5"
output_profile = "dualsense-edge"
```

Profiles overlay the default `[output]`: fields declared by the profile replace
the default, and fields omitted by the profile inherit the default. When a
profile sets `emulate`, the preset first fills that profile's missing
VID/PID/name/buttons/axes, then the result overlays `[output]`. Unknown profile
names are ignored with a warning and the default output stays active.

Vader 5 exposes two opt-in DualSense Edge choices. List or select them without
hand-editing `config.toml`:

```sh
padctl output-profile list --device "Flydigi Vader 5 Pro"
padctl output-profile select dualsense-edge-native --device "Flydigi Vader 5 Pro"
```

| Profile | Output path | Stick range | Native features |
|---------|-------------|-------------|-----------------|
| `dualsense-edge` | generic uinput identity/layout | `-32768..32767` | no native HID protocol; preserves 16-bit stick resolution |
| `dualsense-edge-native` | wired USB DualSense Edge UHID | `0..255` | SDL HIDAPI buttons, touch, accelerometer/gyro, and compatible rumble |

The native profile uses one Edge UHID for gamepad input, two synthesized C/Z
touch contacts and click, and motion sensors; it does not create a separate IMU
companion. Vader's inherited auxiliary mouse may still coexist. The 8-bit axes
are an intentional property of the native USB report. Use `dualsense-edge` when
16-bit stick resolution matters more than native HIDAPI recognition.

The native scope is deliberately narrow: USB only. Bluetooth, private
configuration reports, audio/speaker endpoints, and adaptive triggers are not
implemented.

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

Two backends are supported: legacy rumble via uinput (default), and HID PID
passthrough via UHID for devices whose firmware speaks the
[USB HID PID class spec](https://www.usb.org/document-library/device-class-definition-pid-10)
directly (most racing wheels).

#### Rumble (uinput, default)

```toml
[output.force_feedback]
type = "rumble"
max_effects = 16
auto_stop = true     # default; set false to disable userspace auto-stop
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | string | `"rumble"` | Force-feedback type. `"rumble"` is the only legacy value. |
| `max_effects` | int | 16 | Maximum number of concurrent FF effect slots |
| `auto_stop` | bool | `true` | Enable userspace rumble auto-stop. When `true`, padctl emits a stop frame to the HID device after each effect's `replay.length` elapses — compensating for the fact that uinput does not use the kernel's `ff-memless` auto-stop timer. Set to `false` only for devices whose firmware handles auto-stop internally. |
| `backend` | string | `"uinput"` | `"uinput"` (rumble) or `"uhid"` (PID passthrough — see below). |
| `kind` | string | `"rumble"` | `"rumble"` or `"pid"`. |

For `protocol = "dualsense-edge-usb"`, `type = "rumble"` also names the
physical command used by the native compatible-rumble path. SDL HIDAPI report
`0x02` output is decoded by the UHID pump and forwarded through the same
`[commands.rumble]` formatter; it does not use uinput FF or HID PID effects.

#### HID PID passthrough (UHID, racing wheels)

For devices that already implement HID PID effects in firmware (constant
force, spring, damper, friction, sine periodic, etc.), padctl can publish a
UHID node with the device's own PID descriptor and forward `UHID_OUTPUT`
events back to the physical wheel. The kernel's `hid-pidff` driver then
exposes the standard evdev FF interface to games and SDL — no userspace
effect synthesis.

Phase 13 Wave 6 introduced this path; closes issue #82 (Moza, Logitech G-series,
Thrustmaster T-series, Fanatec ClubSport).

```toml
[output.force_feedback]
backend       = "uhid"
kind          = "pid"
clone_vid_pid = true   # publish the UHID node with the wheel's real VID/PID
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `backend` | string | `"uinput"` | Set to `"uhid"` for PID passthrough. |
| `kind` | string | `"rumble"` | Set to `"pid"` for PID passthrough. |
| `clone_vid_pid` | bool | `false` | When `true`, the emitted UHID node uses `[device].vid` / `[device].pid` so games and `hid-pidff` recognize the wheel by its real identifiers. Requires non-zero VID and PID in `[device]`. |

**Validation matrix** — the parser rejects illegal combinations at config load:

| `backend` | `kind` | Result |
|-----------|--------|--------|
| `"uinput"` | `"rumble"` | OK (default; legacy uinput rumble) |
| `"uinput"` | `"pid"` | rejected |
| `"uhid"`   | `"rumble"` | rejected |
| `"uhid"`   | `"pid"` | OK — also requires `[output.imu]` to be declared (UHID routing gate) |

`clone_vid_pid = true` requires `[device].vid` and `[device].pid` to be non-zero.

> **Kernel requirement:** the `hid-pidff` driver must be loaded, and the
> `hid-universal-pidff` quirk module is recommended for non-Logitech wheels.
> See the [Bazzite / Immutable Distros guide](immutable-install.md) for
> distro-specific notes.

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

### `[output.imu]`

IMU (accelerometer + gyroscope) output via a separate UHID node for generic
output protocols. When declared, padctl creates a second UHID device that
shares the same `uniq` as the primary gamepad output, enabling SDL3 to pair the
IMU sensor with the controller automatically (ADR-015 UHID IMU migration; see
PR #159). Native `dualsense-edge-usb` is different: its single gamepad report
already carries motion sensors, and the validator rejects a companion
`[output.imu]`.

> **Validation rule:** when `[output.imu]` is present, `backend` must be `"uhid"`. The validator rejects `"uinput"` per ADR-015 — UHID is the only supported backend for IMU output. Omitting `[output.imu]` entirely keeps the legacy uinput-primary path.

> **Distinction from `[output.aux]`:** `[output.imu]` is the gamepad's accelerometer/gyroscope UHID node; `[output.aux]` is a secondary uinput device for mouse/keyboard remapping. They serve different purposes and can coexist.

See ADR-015 for the design rationale. This section enables SDL3-visible sensor pairing on Steam games.

> **Force feedback limitation:** enabling `[output.imu] backend="uhid"` places the primary gamepad on the UHID backend. On current kernels, evdev force feedback is unavailable for UHID devices unless the kernel's `hid-universal-pidff` module recognises the device VID/PID — generic UHID nodes get `capabilities/ff=0`. Wine/Lutris evdev rumble will not work in this mode. Rumble via SDL or Steam (HIDAPI path) is unaffected.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `backend` | string | no | `"uhid"` | Must be `"uhid"`; only legal value (validator rejects `"uinput"`) |
| `name` | string | no | — | UHID device name shown to userspace |
| `vid` | integer | no | inherits from `[device].vid` | Emulated vendor ID |
| `pid` | integer | no | inherits from `[device].pid` | Emulated product ID |
| `accel_range` | int[2] | no | `[-32768, 32767]` | Accelerometer output range `[min, max]` |
| `gyro_range` | int[2] | no | `[-32768, 32767]` | Gyroscope output range `[min, max]` |

Example:

```toml
[output.imu]
backend = "uhid"
name = "vader5_imu"
vid = 0x11ff
pid = 0x1211
accel_range = [-16384, 16384]
gyro_range = [-32768, 32767]
```

## `[wasm]`

WASM plugin for stateful/custom protocols (Phase 4+).

| Field | Type | Description |
|-------|------|-------------|
| `plugin` | string | Path to `.wasm` plugin file |

### `[wasm.overrides]`

| Field | Type | Description |
|-------|------|-------------|
| `process_report` | bool | Plugin handles report processing |
