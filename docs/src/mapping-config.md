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
| `trigger_threshold` | integer (0–255) | null | 模拟 trigger 数字化阈值。见下方说明。 |

### `trigger_threshold` — 把模拟 trigger 当按钮用

padctl 默认把 LT / RT 建模为模拟轴（ABS_Z / ABS_RZ）。若要在 `[remap]` 里把它们绑到键位，或在 `[[macro]]` 步骤里把 `LT` / `RT` 当 target，需要先声明一个阈值：

```toml
trigger_threshold = 100   # 0–255，LT 和 RT 共用同一值
```

超过阈值 → 合成为 `LT` / `RT` 按钮 press；低于或等于阈值 → release。声明后 `LT` / `RT` 与普通面按钮语义一致，可直接用在 `[remap]` 和 `[[macro]]` 里：

```toml
trigger_threshold = 100

[remap]
LT = "KEY_LEFTSHIFT"
RT = "mouse_right"

[[macro]]
name  = "scope_shot"
steps = [
    { down = "RT" },
    { delay = 80 },
    { up   = "RT" },
]
```

**选值指南：**

| 值 | 使用场景 |
|----|---------|
| 50–80 | 轻按即触发 |
| 100–120 | 常见"点击感"，推荐起点 |
| 160+ | 深按才触发 |

用 `padctl dump enable` 观察 LT / RT 的实际轴读数，可以精确确定合适的阈值。见 [Diagnostic Logging](diagnostic-logging.md)。

**抖动问题：** 若边界处出现 press / release 抖动，把阈值调高 10–20 即可消除。

未声明 `trigger_threshold` 时，`LT` / `RT` 只作为模拟轴输出，不参与 `[remap]` 和 `[[macro]]` 的按钮匹配。

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
| `tap` | string | no | Button/key emitted on short press (when using hold activation) |
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

Bind a macro in remap: `M1 = "macro:dodge_roll"`
