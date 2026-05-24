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

Top-level button remapping (active when no layer overrides). Keys are ButtonId names, values are target button names, `KEY_*` codes, `mouse_left`/`mouse_right`/`mouse_middle`/`mouse_side`/`mouse_extra`/`mouse_forward`/`mouse_back`, `disabled`, or `macro:<name>`.

> **Note:** `BTN_*` values (e.g. `"BTN_SOUTH"`) are routed to the virtual **mouse** device, not the gamepad. To target a gamepad button use a friendly `ButtonId` name (`"A"`, `"Select"`, etc.) instead.

```toml
[remap]
M1 = "KEY_F13"
M2 = "mouse_side"
M3 = "disabled"
A = "B"
M4 = "macro:dodge_roll"
```

Array values (e.g. `M1 = ["KEY_LEFTMETA", "KEY_1"]`) are parsed and resolved as chord targets (2–4 keys) but are not yet dispatched — chord output is planned for a future release.

### Gesture bindings (tap / hold / double-press)

A `[remap]` value may also be an inline table that binds different actions to
short press, long press, and double press of the same button:

```toml
[remap]
A  = { tap = "KEY_X", hold = "KEY_Y", double = "KEY_Z" }
B  = { tap = "B", hold = "KEY_LEFTSHIFT" }
Y  = { tap = "Y", double = "KEY_F" }
RB = { tap = "RB", hold = "KEY_TAB", hold_ms = 400, double_ms = 200 }
```

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `tap` | string | — | Action for a short press (fired on release). |
| `hold` | string | — | Action fired once the button is held past `hold_ms`. |
| `double` | string | — | Action fired when a second press starts within `double_ms` of the first release. |
| `hold_ms` | integer (1–5000) | 300 | Hold threshold in milliseconds. |
| `double_ms` | integer (1–5000) | 250 | Double-press window in milliseconds. |

At least one of `tap` / `hold` / `double` must be set. Each leg is a single
target (`ButtonId`, `KEY_*`, `mouse_*`, or `disabled`); `macro:<name>` and chord
arrays are not allowed inside a gesture. An empty table `{}` or an unknown key
is rejected at parse time; out-of-range thresholds and a base-`[remap]` gesture
key that collides with a `[[layer]]` `trigger` are rejected at validate time.
Absent legs simply do nothing.

Latency trade-off: when `double` is set, `tap` cannot fire until the
double-press window has elapsed (the engine must wait to see whether a second
press arrives). Without `double`, `tap` fires immediately on release with zero
added latency. Plain string and chord-array remap forms are unaffected and
incur no extra latency.

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
| `mode` | string | `"off"` | `"off"`, `"mouse"`, or `"joystick"`. In `"joystick"` mode the processed gyro signal is routed to a virtual stick axis instead of mouse `REL_X/Y` events. |
| `target` | string | `"right_stick"` | `"right_stick"` or `"left_stick"`. Selects which stick axis receives the gyro output. Only used when `mode = "joystick"`. |
| `response` | string | `"rate"` | `"rate"` keeps the existing gyro-rate behavior. `"tilt"` maps controller tilt to an absolute virtual stick position and is valid only with `mode = "joystick"`. |
| `axis_x` | string | `"yaw"` / `"roll"` | Source for virtual stick X: `"yaw"`, `"pitch"`, `"roll"`, or `"none"`. Defaults to `"yaw"` in `"rate"` response and `"roll"` in `"tilt"` response. In `"tilt"` response, `roll` and `pitch` are estimated from accelerometer data; `yaw` resolves to neutral. |
| `axis_y` | string | `"pitch"` | Source for virtual stick Y: `"yaw"`, `"pitch"`, `"roll"`, or `"none"`. |
| `degrees_full` | float | `35.0` | In `"tilt"` response, the absolute tilt angle that maps to full stick deflection. Must be greater than `0` and no more than `180`. |
| `activate` | string | — | Gate button: bare name (`"LS"`) or `hold_<BTN>` form (`"hold_RB"`) — both are equivalent. For analog triggers (`LT`/`RT`), also set `trigger_threshold`. Omit for always-active. |
| `sensitivity` | float | — | Overall sensitivity multiplier |
| `sensitivity_x` | float | — | X-axis sensitivity override |
| `sensitivity_y` | float | — | Y-axis sensitivity override |
| `deadzone` | integer | — | Raw gyro deadzone threshold in `"rate"` response. In `"tilt"` response this is an output stick deadzone after angle conversion. |
| `smoothing` | float | — | Smoothing factor (0–1) |
| `curve` | float | — | Acceleration curve exponent |
| `max_val` | float | — | Maximum output value cap |
| `invert_x` | bool | — | Invert X axis |
| `invert_y` | bool | — | Invert Y axis |
| `blend_stick` | bool | `false` | When `true`, gyro joystick output is **added** to the physical stick value (`clamp(physical + gyro, -32767..32767)`) instead of replacing it. Only applies when `mode = "joystick"`. Ignored for `mode = "mouse"`. |

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
| `activation` | string | no | `"hold"` (default), `"toggle"`, or `"hold_toggle"`. `hold_toggle` starts like `hold`, but holding past `hold_timeout` toggles the layer sticky on/off instead of making it momentary. |
| `tap` | string | no | Button/key emitted on short press (when using `hold` or `hold_toggle` activation). May be a `ButtonId`, `KEY_*`, `mouse_*`, or `disabled`. **Cannot be `macro:<name>`** — the layer tap dispatch path does not run macros, so `tap = "macro:foo"` is rejected at validate time (`error.LayerTapCannotBeMacro`). Use `macro:<name>` from `[remap]` / `[layer.remap]` instead. |
| `hold_timeout` | integer | no | Hold detection threshold in ms (1–5000); default 200 |

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

```toml
[layer.adaptive_trigger]
mode = "weapon"

[layer.adaptive_trigger.left]
start    = 30
end      = 120
strength = 200
```

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

## `[chord_switch]` — in-controller mapping switch

`[chord_switch]` lives in **`~/.config/padctl/config.toml`** (the user config), **not** in a mapping file. It lets you switch the active mapping without touching a CLI: hold a modifier combination, then tap a selector button.

```toml
# ~/.config/padctl/config.toml
version = 1

[chord_switch]
modifier  = ["LM", "RM"]        # hold ALL of these to arm
selectors = ["A", "B", "X", "Y"] # tap one (while modifier held) to switch
hold_ms   = 120                  # debounce window in ms (default 80)
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `modifier` | array of ButtonId | — | All listed buttons must be held simultaneously to arm chord-switch mode. Missing or empty disables the feature. |
| `selectors` | array of ButtonId | — | Selector at index `i` (0-based) activates the mapping that declares `chord_index = i+1`. Missing or empty disables the feature. |
| `hold_ms` | integer | `80` | Debounce window in milliseconds. Selector edges received within this window after the modifier first becomes fully held are ignored. Raise if you get accidental switches when pressing modifier and selector nearly simultaneously. |

**`chord_index`** is declared per mapping file (not in `config.toml`):

```toml
# ~/.config/padctl/mappings/desktop.toml
chord_index = 1   # tap A (selectors[0]) while holding LM+RM → switch here
```

Selector `selectors[i]` maps to `chord_index = i+1`. Mappings that do not declare `chord_index` are not reachable via chord. Range is 1–255; duplicate `chord_index` values across files are resolved by lexicographic mapping name order (first match wins).

While the modifier is held, all selector buttons are suppressed from the output device so they do not fire their remapped actions.

A runnable example is at [`examples/configs/chord-switch.toml`](https://github.com/BANANASJIM/padctl/blob/main/examples/configs/chord-switch.toml).
