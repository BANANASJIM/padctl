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

Or use the interactive creator:

```sh
padctl config init
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
padctl switch          # re-applies the last-switched mapping from user config
```

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

Available button names: `A`, `B`, `X`, `Y`, `LB`, `RB`, `LT`, `RT`, `Start`, `Select`, `LS`, `RS`, `M1`, `M2`, `M3`, `M4`, `LM`, `RM`, `C`, `Z`

### Gyroscope (`[gyro]`)

Translates gyroscope motion to mouse movement. Off by default.

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
