# Mapping Config Reference

An optional `--mapping` TOML file overrides the default button/axis pass-through with remapping, gyro mouse, stick modes, layers, and macros.

## Top-level Fields

```toml
name = "fps"
trigger_threshold = 100
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | — | Mapping profile name. Used by `padctl switch <name>` and `default_mapping` in user config to identify this profile. |
| `trigger_threshold` | integer (0–255) | null | Threshold for synthesizing digital `LT` / `RT` button events from the analog trigger axes. **Top-level only** — placing this inside `[[layer]]` is silently ignored. See below. |
| `chord_index` | integer (0–255) | null | Selector index used by the in-controller `[chord_switch]` quick-switch. The value is matched against the position of `[chord_switch].selectors`: `chord_index = i+1` activates when `selectors[i]` is pressed. Set `chord_index = 0` (or omit) to leave a mapping unselectable via chord. See [Diagnostic Logging — Chord switch](diagnostic-logging.md#chord-switch-issue-183) for the full setup. |

## Validation behaviour

`padctl daemon` runs a post-parse linter on every mapping TOML file at startup. Unknown keys produce warnings to stderr with line numbers and section context:

```
config: unknown key 'trigger_threshold' inside [layer] (line 42) — typo or misplaced field?
config: unknown key 'typo_field' at top-level (line 7) — typo or misplaced field?
```

The linter is fail-open: warnings only, the daemon still starts. This surfaces common mistakes such as placing `trigger_threshold` inside a `[[layer]]` block instead of at the top level (also surfaces preceding silent rewrites — see [Diagnostic logging](diagnostic-logging.md#schema-rewrite)).

<a id="trigger_threshold"></a>
### trigger_threshold — analog triggers as digital buttons

padctl models `LT` and `RT` as analog axes (ABS_Z / ABS_RZ) by default. To bind them to keys or mouse buttons in `[remap]`, declare a threshold:

```toml
trigger_threshold = 100   # 0–255, shared by both LT and RT

[remap]
LT = "KEY_LEFTSHIFT"
RT = "mouse_right"
```

Axis value above threshold → synthesizes `LT` / `RT` button press. Value at or below threshold → release. Once declared, `LT` and `RT` behave like any other face button for `[remap]` sources and `[[layer]]` `trigger` fields.

**Threshold tuning:**

| Value | Feel |
|-------|------|
| 50–80 | Light touch triggers |
| 100–120 | Click-like feel (recommended starting point) |
| 160+ | Deliberate press only |

Use `padctl dump enable` to observe raw LT / RT axis readings and dial in the threshold. See [Diagnostic Logging](diagnostic-logging.md).

**Jitter:** If the axis hovers around the threshold and produces rapid press/release bursts, raise the threshold by 10–20.

Without `trigger_threshold`, `LT` / `RT` emit analog axis events only and do not participate in `[remap]` or layer trigger matching.

## `[remap]`

Top-level button remapping (active when no layer overrides). Keys are ButtonId names, values are target button names, `KEY_*` codes, `mouse_left`/`mouse_right`/`mouse_middle`/`mouse_side`/`mouse_forward`/`mouse_back`, `disabled`, or `macro:<name>`.

```toml
[remap]
M1 = "KEY_F13"
M2 = "mouse_side"
M3 = "disabled"
A = "B"
M4 = "macro:dodge_roll"
```

## `[gyro]`

Global gyro-to-mouse configuration.

```toml
[gyro]
mode = "mouse"
activate = "LS"
sensitivity = 2.0
deadzone = 300
smoothing = 0.4
curve = 1.0
invert_y = true
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `mode` | string | `"off"` | `"off"` or `"mouse"` |
| `activate` | string | — | Button name to hold for activation (e.g. `"LS"`, `"hold_RB"`) |
| `sensitivity` | float | — | Overall sensitivity multiplier |
| `sensitivity_x` | float | — | X-axis sensitivity override |
| `sensitivity_y` | float | — | Y-axis sensitivity override |
| `deadzone` | integer | — | Raw gyro deadzone threshold |
| `smoothing` | float | — | Smoothing factor (0–1) |
| `curve` | float | — | Acceleration curve exponent |
| `max_val` | float | — | Maximum output value cap |
| `invert_x` | bool | — | Invert X axis |
| `invert_y` | bool | — | Invert Y axis |

## `[stick.left]` / `[stick.right]`

Per-stick mode configuration.

```toml
[stick.left]
mode = "gamepad"
deadzone = 128
sensitivity = 1.0

[stick.right]
mode = "mouse"
sensitivity = 2.5
deadzone = 100
suppress_gamepad = true
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `mode` | string | `"gamepad"` | `"gamepad"`, `"mouse"`, or `"scroll"` |
| `deadzone` | integer | — | Stick deadzone threshold |
| `sensitivity` | float | — | Sensitivity multiplier |
| `suppress_gamepad` | bool | — | Suppress gamepad axis output when in mouse/scroll mode |

## `[dpad]`

D-pad mode configuration.

```toml
[dpad]
mode = "gamepad"
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `mode` | string | `"gamepad"` | `"gamepad"` or `"arrows"` (emits arrow keys) |
| `suppress_gamepad` | bool | — | Suppress gamepad d-pad output when in arrows mode |

## `[[layer]]`

Each layer defines an activation condition and overrides for remap, gyro, sticks, and d-pad. Layers are evaluated in declaration order.

```toml
[[layer]]
name = "fps"
trigger = "LM"
activation = "hold"
tap = "mouse_side"
hold_timeout = 200
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Unique layer identifier |
| `trigger` | string | yes | Button name that activates this layer |
| `activation` | string | no | `"hold"` (default) or `"toggle"` |
| `tap` | string | no | Button/key emitted on short press (when using hold activation). May be a `ButtonId`, `KEY_*`, `mouse_*`, or `disabled`. **Cannot be `macro:<name>`** — the layer tap dispatch path does not run macros, so `tap = "macro:foo"` is rejected at validate time (`error.LayerTapCannotBeMacro`). Use `macro:<name>` from `[remap]` / `[layer.remap]` instead. |
| `hold_timeout` | integer | no | Hold detection threshold in ms (1–5000) |

### `[layer.remap]`

Per-layer button remapping. Same syntax as top-level `[remap]`.

```toml
[layer.remap]
RT = "mouse_left"
A = "KEY_R"
```

### `[layer.gyro]`

Per-layer gyro override. Same fields as `[gyro]`.

```toml
[layer.gyro]
mode = "mouse"
sensitivity = 8.0
deadzone = 40
smoothing = 0.4
invert_y = true
```

### `[layer.stick_left]` / `[layer.stick_right]`

Per-layer stick overrides. Same fields as `[stick.left]`/`[stick.right]`.

```toml
[layer.stick_right]
mode = "mouse"
sensitivity = 2.5
deadzone = 100
suppress_gamepad = true
```

### `[layer.dpad]`

Per-layer d-pad override. Same fields as `[dpad]`.

```toml
[layer.dpad]
mode = "arrows"
suppress_gamepad = true
```

### `[layer.adaptive_trigger]`

Per-layer adaptive trigger override. Same fields as top-level `[adaptive_trigger]`.

## `[adaptive_trigger]`

DualSense adaptive trigger configuration.

```toml
[adaptive_trigger]
mode = "feedback"

[adaptive_trigger.left]
position = 70
strength = 200

[adaptive_trigger.right]
position = 40
strength = 180
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `mode` | string | `"off"` | `"off"`, `"feedback"`, `"weapon"`, or `"vibration"` |
| `command_prefix` | string | `"adaptive_trigger_"` | Command template prefix in device config |

### `[adaptive_trigger.left]` / `[adaptive_trigger.right]`

| Field | Type | Description |
|-------|------|-------------|
| `position` | integer | Trigger position threshold |
| `strength` | integer | Resistance strength |
| `start` | integer | Start position (weapon mode) |
| `end` | integer | End position (weapon mode) |
| `amplitude` | integer | Vibration amplitude |
| `frequency` | integer | Vibration frequency |

## `[[macro]]`

Named sequences of input steps bound via `macro:<name>` in remap values.

```toml
[[macro]]
name = "dodge_roll"
steps = [
    { tap = "B" },
    { delay = 50 },
    { tap = "LEFT" },
]

[[macro]]
name = "shift_hold"
steps = [
    { down = "KEY_LEFTSHIFT" },
    "pause_for_release",
    { up = "KEY_LEFTSHIFT" },
]
```

Step types:

| Step | Description |
|------|-------------|
| `{ tap = "KEY" }` | Press and release a key |
| `{ down = "KEY" }` | Press and hold a key |
| `{ up = "KEY" }` | Release a key |
| `{ delay = N }` | Wait N milliseconds |
| `"pause_for_release"` | Wait until the trigger button is released |

Macro fields:

| Field | Description |
|-------|-------------|
| `name` | Identifier referenced from remap as `macro:<name>` |
| `steps` | Ordered step list |
| `repeat_delay_ms` | Optional. While the trigger button is held, restart the macro `N` ms after the previous run finishes. Releasing the trigger lets the current iteration finish naturally and stops further restarts. Omit for single-shot (legacy) behaviour. |

```toml
# Turbo: spam A while RM is held, 50 ms between presses.
[[macro]]
name = "spam_a"
repeat_delay_ms = 50
steps = [{ tap = "A" }]

# Combo: XYX every 100 ms while held.
[[macro]]
name = "xyx_combo"
repeat_delay_ms = 100
steps = [
    { tap = "X" },
    { delay = 30 },
    { tap = "Y" },
    { delay = 30 },
    { tap = "X" },
]
```

Bind a macro in remap: `M1 = "macro:dodge_roll"`
