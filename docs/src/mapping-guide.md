# Mapping Configuration Guide

## Overview

A mapping config controls how padctl translates physical inputs to virtual outputs. It is separate from the device config:

- **Device config** (`devices/*.toml`) — describes the hardware HID protocol. Stable, community-maintained. You usually don't touch this.
- **Mapping config** (`~/.config/padctl/mappings/*.toml`) — your personal preferences: remapped buttons, gyro mouse, layers, macros.

Without a mapping config, padctl passes all inputs through unchanged as a standard gamepad.

## Quick Start

### Create a mapping

Use the interactive creator:

```sh
mkdir -p ~/.config/padctl/mappings/
padctl config init --preset xbox-360
```

Or, from a source checkout, copy the repository example and edit it:

```sh
cp config/example-mapping.toml ~/.config/padctl/mappings/my-config.toml
$EDITOR ~/.config/padctl/mappings/my-config.toml
```

### XDG Search Paths

padctl searches for mapping profiles in this order (first match wins):

1. `~/.config/padctl/mappings/` — user overrides
2. `/etc/padctl/mappings/` — system-wide profiles
3. `/usr/share/padctl/mappings/` — builtin profiles

### Apply a mapping

Switch the active mapping at runtime:

```sh
padctl switch fps
```

Every switch automatically saves your choice to `~/.config/padctl/config.toml`, so you can restore it later with a bare switch:

```sh
padctl switch          # re-applies default_mapping from config.toml for the connected device
```

Bare `padctl switch` queries the running daemon for the connected device name, then looks up `default_mapping` in `config.toml` (user path first, then `/etc/padctl/config.toml`). If no entry is found it exits with `error: no default_mapping in config.toml for device "<name>"`.

### Persist across reboots (`--persist`)

By default, `padctl switch` only saves to your user config (`~/.config/padctl/config.toml`). The systemd daemon cannot read this at boot because `HOME` is not set in its service environment. To make the mapping survive reboots:

```sh
padctl switch fps --persist
```

This will:
1. Apply the mapping at runtime (same as without `--persist`)
2. Save to your user config (same as without `--persist`)
3. Prompt for confirmation, then ask for your sudo password
4. Copy the mapping file to `/etc/padctl/mappings/`
5. Copy your user config to `/etc/padctl/config.toml`

The daemon reads `/etc/padctl/` at boot, so the mapping auto-applies on every reboot without manual intervention.

**Limitations:**

- `--persist` is not yet supported with `--device` (multi-controller setups). In multi-device sessions, auto-save and bare `padctl switch` resolve against the first connected device. Use `padctl install --mapping <name>` for explicit per-device persistence in multi-controller setups.
- A future version may persist by default, but this behavior is uncertain and subject to change.

### Config file precedence

The daemon checks these paths in order when resolving default mappings:

1. `~/.config/padctl/config.toml` — user overrides (highest priority, only available when `HOME` is set)
2. `/etc/padctl/config.toml` — system-wide defaults (written by `padctl install --mapping` or `padctl switch --persist`)

```toml
version = 1

[[device]]
name = "Flydigi Vader 5 Pro"
default_mapping = "fps"
```

If you installed with `padctl install --mapping vader5`, the system config is already written for you.

### Manual run

Or pass a mapping directly when running padctl manually:

```sh
padctl --mapping ~/.config/padctl/mappings/my-config.toml
```

### Validate

Mapping configs are validated at daemon startup. Errors are written to the journal:

```sh
journalctl --user -u padctl.service -n 30
```

Mapping configs can also be validated with `padctl --validate`; the flag auto-detects device vs mapping schema by scanning for a `[device]` table.

## Configuration Sections

### Button Remapping (`[remap]`)

Keys are button names; values are the target action.

```toml
[remap]
A  = "B"              # swap A and B
M1 = "KEY_F13"        # back paddle → keyboard key
M2 = "mouse_left"     # grip button → mouse left click
M3 = "disabled"       # silence an unused button
M4 = "macro:dodge_roll"  # run a macro (defined below)
LM = "mouse_side"
RM = "RS"
```

Available target types:

| Value | Effect |
|-------|--------|
| `"A"`, `"B"`, `"LB"`, … | Remap to another gamepad button |
| `"KEY_*"` | Emit a Linux keyboard key (e.g. `"KEY_F13"`, `"KEY_LEFTSHIFT"`) |
| `"mouse_left"` / `"mouse_right"` / `"mouse_middle"` / `"mouse_side"` / `"mouse_extra"` | Emit a mouse button |
| `"mouse_forward"` / `"mouse_back"` | Emit mouse forward/back (button 4/5) |
| `"disabled"` | Suppress the button entirely |
| `"macro:<name>"` | Run a named macro sequence |

> **Note:** `BTN_*` values (e.g. `"BTN_SOUTH"`) are routed to the virtual **mouse** device, not the gamepad. To remap to a gamepad button use a friendly `ButtonId` name (`"A"`, `"Select"`, etc.) instead.

Available button names: `A`, `B`, `X`, `Y`, `LB`, `RB`, `LT`, `RT`, `Start`, `Select`, `Home`, `Capture`, `LS`, `RS`, `DPadUp`, `DPadDown`, `DPadLeft`, `DPadRight`, `M1`, `M2`, `M3`, `M4`, `Paddle1`, `Paddle2`, `Paddle3`, `Paddle4`, `TouchPad`, `Mic`, `C`, `Z`, `LM`, `RM`, `O`

#### Tap / hold / double-press on one button

Bind separate actions to a short press, a long press, and a double press of the
same button by using an inline table instead of a string:

```toml
[remap]
A  = { tap = "KEY_X", hold = "KEY_Y", double = "KEY_Z" }
B  = { tap = "B", hold = "KEY_LEFTSHIFT" }           # tap passes B through, hold = shift
RB = { tap = "RB", hold = "KEY_TAB", hold_ms = 400, double_ms = 200 }
```

- `tap` fires on release (short press), `hold` fires once held past `hold_ms`
  (default 300 ms), `double` fires on a second press within `double_ms` (default
  250 ms) of the first release.
- At least one leg is required; absent legs do nothing. Legs are single targets
  only — `macro:<name>` and chord arrays are not allowed inside a gesture.
- Works the same in `[layer.remap]`.
- Trade-off: when `double` is set, `tap` is delayed until the double-press
  window closes (the only way to tell a single press from the first of a
  double). Omit `double` to keep `tap` instant. Plain string and chord remaps
  are unchanged and never add latency.

### Gyroscope (`[gyro]`)

Translates gyroscope motion to mouse movement or a virtual stick. Off by default.

```toml
[gyro]
mode        = "mouse"
activate    = "LS"      # hold left stick click to enable gyro
sensitivity = 2.0
deadzone    = 300       # raw gyro units; filters small wobble
smoothing   = 0.4       # 0–1; higher = smoother but more latency
invert_y    = true
```

Omit `activate` to have gyro always active when mode is `"mouse"`.

`activate` accepts a bare button name (`"LS"`) or the `hold_<BTN>` form (`"hold_RB"`) — both behave identically. For analog triggers (`LT`/`RT`) you must also declare `trigger_threshold` at the top level, otherwise the trigger axis is never converted to a button press and the gyro gate never fires.

#### Joystick mode

Set `mode = "joystick"` to route the gyro signal to a virtual stick axis instead of mouse events. Use `target` to choose which stick receives the output:

```toml
[gyro]
mode   = "joystick"
target = "right_stick"   # "right_stick" (default) or "left_stick"
deadzone    = 200
sensitivity = 1.5
smoothing   = 0.3
```

This is useful for games that read the right stick for camera control but do not natively support gyro input. In the default `response = "rate"` mode, the usual gyro fields (`sensitivity`, `deadzone`, `smoothing`, `curve`, `invert_x`, `invert_y`) apply in joystick mode the same way as in mouse mode.

For racing games, `response = "tilt"` maps controller tilt to an absolute stick
position instead of treating gyro motion like stick velocity. `degrees_full`
controls how far the controller must be tilted for full stick deflection, and
`axis_x` / `axis_y` choose which motion axis drives each virtual stick axis:

```toml
[gyro]
mode = "joystick"
response = "tilt"
target = "left_stick"
axis_x = "roll"          # steer by rolling the controller left/right
axis_y = "none"          # leave the Y stick axis unchanged
degrees_full = 35.0      # +/-35 degrees maps to full stick deflection
smoothing = 0.2
```

`response = "tilt"` uses the accelerometer to estimate `roll` and `pitch`, so
it gives a stable absolute stick position without gyro integration drift. `yaw`
does not have an absolute tilt estimate and resolves to neutral in tilt mode.
When `response = "tilt"`, the default X source is `roll`; in the default
`response = "rate"` mode, X still uses `yaw`. If a device has not reported a
non-zero accelerometer vector yet, tilt mode leaves the physical stick axes
unchanged for that frame. In tilt mode, `deadzone` is applied after converting
tilt to virtual stick output rather than to raw gyro units.

#### Blending gyro with the physical stick (`blend_stick`)

By default, gyro joystick output **replaces** the physical stick value while gyro is active. Set `blend_stick = true` to **add** the gyro signal on top of the physical stick instead:

```toml
[gyro]
mode        = "joystick"
target      = "right_stick"
activate    = "LS"
sensitivity = 1.5
deadzone    = 200
smoothing   = 0.3
blend_stick = true          # add gyro onto physical stick instead of replacing it
```

This lets the physical stick handle coarse movement while the gyro provides fine aim adjustment simultaneously — useful for aim-assist workflows. The combined value is clamped to the valid axis range (`-32767..32767`).

> **Note:** when the physical stick is already at full deflection (±32767), the gyro contribution is clamped out entirely. `blend_stick` has no effect when `mode = "mouse"`.

### Sticks (`[stick.left]` / `[stick.right]`)

Three modes:

- `"gamepad"` (default) — pass through as normal gamepad axes
- `"mouse"` — stick controls the cursor
- `"scroll"` — stick controls scroll wheel

```toml
[stick.right]
mode             = "mouse"
sensitivity      = 2.5
deadzone         = 100
suppress_gamepad = true   # prevent duplicate gamepad axis events
```

Use `suppress_gamepad = true` with `"mouse"` or `"scroll"` to avoid sending both gamepad axes and mouse/scroll events simultaneously.

### D-pad (`[dpad]`)

```toml
[dpad]
mode             = "arrows"  # emit arrow key events
suppress_gamepad = true
```

Default is `"gamepad"`. Set to `"arrows"` to make the d-pad behave as arrow keys (useful for desktop navigation).

### Layers (`[[layer]]`)

Layers are the most powerful feature. A layer is a context-sensitive override: while active, its remap/gyro/stick/dpad settings replace the base config.

Three activation modes:

- `"hold"` — active while the trigger button is held
- `"toggle"` — press once to enter, press again to exit
- `"hold_toggle"` — short press fires `tap`; holding past `hold_timeout` toggles the layer on or off

The `tap` + `hold_timeout` combination lets a button do double duty: if released before `hold_timeout` ms, it fires `tap` instead of activating the layer.

```toml
# "aim" layer: hold LM to enable gyro + mouse aim
[[layer]]
name         = "aim"
trigger      = "LM"
activation   = "hold"
hold_timeout = 200        # ms; short press fires tap action
tap          = "mouse_side"

[layer.gyro]
mode        = "mouse"
sensitivity = 2.0
smoothing   = 0.3

[layer.stick_right]
mode             = "mouse"
sensitivity      = 1.0
suppress_gamepad = true

[layer.remap]
RB = "mouse_left"
RT = "mouse_right"
```

Layer sub-configs can also be written inline (equivalent):

```toml
[[layer]]
name         = "aim"
trigger      = "LM"
activation   = "hold"
hold_timeout = 200
tap          = "mouse_side"
gyro         = { mode = "mouse", sensitivity = 2.0, smoothing = 0.3 }
stick_right  = { mode = "mouse", sensitivity = 1.0, suppress_gamepad = true }
remap        = { RB = "mouse_left", RT = "mouse_right" }
```

Toggle example — F-key row on Select:

```toml
[[layer]]
name       = "fn"
trigger    = "Select"
activation = "toggle"

[layer.remap]
A = "KEY_F1"
B = "KEY_F2"
X = "KEY_F3"
Y = "KEY_F4"
```

Hold-to-toggle example — hold LM to keep a racing layer enabled, hold it again
to disable it. A short press still emits `tap`:

```toml
[[layer]]
name         = "race"
trigger      = "LM"
activation   = "hold_toggle"
hold_timeout = 300
tap          = "LM"

[layer.gyro]
mode = "joystick"
response = "tilt"
target = "left_stick"
axis_x = "roll"
axis_y = "none"
degrees_full = 35.0
```

Layers are evaluated in declaration order. Only one layer is active at a time.

### Macros (`[[macro]]`)

Named sequences bound via `macro:<name>` in remap values.

```toml
[[macro]]
name  = "dodge_roll"
steps = [
    { tap = "B" },
    { delay = 50 },
    { tap = "LEFT" },
]

[[macro]]
name  = "shift_hold"
steps = [
    { down = "KEY_LEFTSHIFT" },
    "pause_for_release",
    { up = "KEY_LEFTSHIFT" },
]
```

| Step | Description |
|------|-------------|
| `{ tap = "KEY" }` | Press and release |
| `{ down = "KEY" }` | Press and hold |
| `{ up = "KEY" }` | Release |
| `{ delay = N }` | Wait N milliseconds |
| `"pause_for_release"` | Wait until the trigger button is released |

Bind in remap: `M1 = "macro:dodge_roll"`

> **Warning:** `hold_timeout` belongs on the `[[layer]]` block, not `[[macro]]`.
> A `hold_timeout` value under `[[macro]]` is not recognized and the schema
> linter will warn about it; the layer continues to use the default 200 ms.
> To make a hold layer fire quickly, put `hold_timeout = 50` (or your chosen
> value, 1–5000 ms) on the `[[layer]]` block itself.

#### Repeat-while-held — turbo / combo (`repeat_delay_ms`)

Add `repeat_delay_ms = N` to a `[[macro]]` block to make the macro restart while
the trigger button is held. Releasing the trigger lets the current iteration
finish naturally and stops further restarts. Omit the field for legacy
single-shot behaviour.

```toml
# Spam A while RM held: tap, wait 50 ms, tap again, ...
[[macro]]
name = "spam_a"
repeat_delay_ms = 50
steps = [{ tap = "A" }]

[remap]
RM = "macro:spam_a"
```

### Trigger Threshold — analog LT / RT as digital buttons {#trigger-threshold}

> **Warning:** `trigger_threshold` must be at the top level of the mapping file.
> Placing it inside `[[layer]]` is silently ignored.
> To use `LT` / `RT` as remap source keys or layer triggers, set this field once
> at the top of your mapping file, outside any layer block.

LT / RT are analog axes by default and cannot be used directly as `[remap]` source keys. Once `trigger_threshold` is declared, padctl synthesizes digital button events from the axis values each frame, making them available for `[remap]` and layer triggers:

```toml
trigger_threshold = 100   # 0–255, shared by LT and RT

[remap]
LT = "KEY_LEFTSHIFT"      # axis > 100 → synthesize LT press → emit Shift
RT = "mouse_right"        # axis > 100 → synthesize RT press → emit right click
```

See [Mapping Config Reference — trigger_threshold](mapping-config.md#trigger_threshold) for the full field description.

LT / RT also work as `down` / `up` targets inside `[[macro]]` — press and release the virtual trigger from any macro step:

```toml
[remap]
M1 = "macro:aim_burst"

[[macro]]
name = "aim_burst"
steps = [
    { down = "LT" },
    { delay = 80 },
    { up = "LT" },
]
```

### Adaptive Trigger (`[adaptive_trigger]`) — DualSense only

Configures the resistance profile of the DualSense L2/R2 triggers. See [Mapping Config Reference](mapping-config.md#adaptive_trigger) for full field tables.

### In-controller Chord Switch (`[chord_switch]`)

Hold a set of modifier buttons, then tap a selector button to switch the active mapping without touching a CLI. This is configured in `~/.config/padctl/config.toml` (not in a mapping file), and each selectable mapping file declares `chord_index = N`:

```toml
# ~/.config/padctl/config.toml
[chord_switch]
modifier  = ["LM", "RM"]
selectors = ["A", "B", "X", "Y"]
hold_ms   = 120
```

```toml
# ~/.config/padctl/mappings/desktop.toml
chord_index = 1   # LM+RM → tap A → switch to this mapping
```

See [Mapping Config Reference — chord_switch](mapping-config.md#chord_switch--in-controller-mapping-switch) for full field tables and a runnable example.

## Full Example

A copy-paste-ready example covering every major feature is included in the repository at [`examples/mappings/comprehensive.toml`](https://github.com/BANANASJIM/padctl/blob/main/examples/mappings/comprehensive.toml). It covers base remaps, hold/toggle/hold-toggle layers, macros, stick modes, and gyro.

## Reference

Full field tables and all accepted values: [Mapping Config Reference](mapping-config.md)
