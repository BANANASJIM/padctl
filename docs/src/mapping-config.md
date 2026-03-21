# Mapping Config Reference

An optional `--mapping` TOML file overrides the default button/axis pass-through with remapping layers.

## Overview

```toml
[[layer]]
name = "default"

[layer.buttons]
A = "B"
B = "A"

[layer.sticks.left]
swap_axes = true
```

## `[[layer]]`

Each layer has a name and an activation condition (default layer is always active).

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Layer identifier |
| `hold` | string | Button held to activate this layer |

## `[layer.buttons]`

Remaps button names as declared in `[report.button_group]`. Values are target button names.

```toml
[layer.buttons]
LB = "LT"
RB = "RT"
```

## `[layer.sticks]`

Per-stick configuration.

```toml
[layer.sticks.left]
deadzone = 0.10
swap_axes = false
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `deadzone` | float | `0.0` | Circular deadzone radius (0–1) |
| `swap_axes` | bool | `false` | Swap X and Y |
| `invert_x` | bool | `false` | Negate X axis |
| `invert_y` | bool | `false` | Negate Y axis |

## `[layer.macros]`

Sequences of actions bound to button combos.

```toml
[layer.macros.taunt]
trigger = ["Select", "A"]
actions = [{ press = "Home", duration_ms = 100 }]
```
