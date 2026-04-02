# Mapping Configuration Guide

## Overview

A mapping config controls how padctl translates physical inputs to virtual outputs. It is separate from the device config:

- **Device config** (`devices/*.toml`) — describes the hardware HID protocol. Stable, community-maintained. You usually don't touch this.
- **Mapping config** (`~/.config/padctl/mappings/*.toml`) — your personal preferences: remapped buttons, gyro mouse, layers, macros.

Without a mapping config, padctl passes all inputs through unchanged as a standard gamepad.

## Quick Start

### Create a mapping

Copy the example and edit it:

```sh
mkdir -p ~/.config/padctl/mappings/
cp /usr/share/padctl/config/example-mapping.toml ~/.config/padctl/mappings/my-config.toml
$EDITOR ~/.config/padctl/mappings/my-config.toml
```

### Apply a mapping

Pass it directly when running padctl:

```sh
padctl --mapping ~/.config/padctl/mappings/my-config.toml
```

Or add it to the systemd service override:

```sh
systemctl --user edit padctl.service
# Add: Environment=PADCTL_MAPPING=/home/you/.config/padctl/mappings/my-config.toml
```

### Validate

Mapping configs are validated at daemon startup. Errors are written to the journal:

```sh
journalctl -u padctl.service -n 30
```

Note: `padctl --validate` is for device configs only.

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
RM = "R3"
```

Available target types:

| Value | Effect |
|-------|--------|
| `"A"`, `"B"`, `"LB"`, … | Remap to another gamepad button |
| `"KEY_*"` | Emit a Linux keyboard key (e.g. `"KEY_F13"`, `"KEY_LEFTSHIFT"`) |
| `"mouse_left"` / `"mouse_right"` / `"mouse_middle"` / `"mouse_side"` / `"mouse_extra"` | Emit a mouse button |
| `"disabled"` | Suppress the button entirely |
| `"macro:<name>"` | Run a named macro sequence |

Available button names: `A`, `B`, `X`, `Y`, `LB`, `RB`, `LT`, `RT`, `Start`, `Select`, `L3`, `R3`, `M1`, `M2`, `M3`, `M4`, `LM`, `RM`, `C`, `Z`

### Gyroscope (`[gyro]`)

Translates gyroscope motion to mouse movement. Off by default.

```toml
[gyro]
mode        = "mouse"
activate    = "L3"      # hold L3 to enable gyro
sensitivity = 2.0
deadzone    = 300       # raw gyro units; filters small wobble
smoothing   = 0.4       # 0–1; higher = smoother but more latency
invert_y    = true
```

Omit `activate` to have gyro always active when mode is `"mouse"`.

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

Two activation modes:

- `"hold"` — active while the trigger button is held
- `"toggle"` — press once to enter, press again to exit

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

### Adaptive Trigger (`[adaptive_trigger]`) — DualSense only

Configures the resistance profile of the DualSense L2/R2 triggers. See [Mapping Config Reference](mapping-config.md#adaptive_trigger) for full field tables.

## Full Example

See [`config/example-mapping.toml`](https://github.com/BANANASJIM/padctl/blob/main/config/example-mapping.toml) in the repository for a complete working config covering base remaps, two layers (hold + toggle), and macros.

## Reference

Full field tables and all accepted values: [Mapping Config Reference](mapping-config.md)
