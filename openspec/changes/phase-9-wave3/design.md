# Design: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

## Files

| File | Role |
|------|------|
| `devices/sony/dualsense.toml` | Add 4 adaptive trigger command templates to `[commands]` |
| `src/config/mapping.zig` | Add `AdaptiveTriggerConfig` struct, extend `MappingConfig` |
| `src/event_loop.zig` | Resolve adaptive trigger mapping → command → fillTemplate → write |

---

## T8: Adaptive Trigger Command Templates

### DualSense Adaptive Trigger Protocol

DualSense output report (USB Report ID 0x02, 63 bytes) uses bytes 22-32 for right trigger
and bytes 33-43 for left trigger adaptive settings. The mode byte determines which subsequent
bytes are interpreted.

However, the DualSense output report is a **single monolithic report** — all fields
(rumble, LED, adaptive triggers) share the same 63-byte buffer. The `valid_flag0` (byte 1)
and `valid_flag1` (byte 2) select which subsystems are active.

For adaptive triggers, `valid_flag0` bit 2 (`0x04`) enables right trigger, bit 3 (`0x08`)
enables left trigger. The mode/params occupy fixed byte offsets within the output report.

### Command Template Design

Each adaptive trigger mode gets a separate named command in `[commands]`. The templates
are full 63-byte output reports with the appropriate `valid_flag0` bits set and mode bytes
at the correct offsets.

DualSense adaptive trigger byte layout (USB output report):
- Byte 1: `valid_flag0` — bit 2 = right trigger effect, bit 3 = left trigger effect
- Byte 2: `valid_flag1` — 0x00 (no LED/other changes)
- Bytes 11-21: right trigger effect (byte 11 = mode, bytes 12-21 = params)
- Bytes 22-32: left trigger effect (byte 22 = mode, bytes 23-32 = params)

Mode bytes:
- `0x00` = Off
- `0x01` = Feedback (continuous resistance)
- `0x02` = Weapon (click point)
- `0x06` = Vibration

Since a single output report sets **both** triggers simultaneously, the command templates
include params for both sides. This avoids needing two separate writes (which would cause
the second write to overwrite the first side's settings).

```toml
# Adaptive trigger: Off (both triggers)
[commands.adaptive_trigger_off]
interface = 3
template = "02 0c 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

# Adaptive trigger: Feedback — continuous resistance from position with given strength
# Right: mode at byte 11, position at byte 12, strength at byte 13
# Left:  mode at byte 22, position at byte 23, strength at byte 24
[commands.adaptive_trigger_feedback]
interface = 3
template = "02 0c 00 00 00 00 00 00 00 00 00 01 {r_position:u8} {r_strength:u8} 00 00 00 00 00 00 00 00 01 {l_position:u8} {l_strength:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

# Adaptive trigger: Weapon — click at position with given strength, releases after end_position
# Right: mode at byte 11, start at byte 12, end at byte 13, strength at byte 14
# Left:  mode at byte 22, start at byte 23, end at byte 24, strength at byte 25
[commands.adaptive_trigger_weapon]
interface = 3
template = "02 0c 00 00 00 00 00 00 00 00 00 02 {r_start:u8} {r_end:u8} {r_strength:u8} 00 00 00 00 00 00 00 02 {l_start:u8} {l_end:u8} {l_strength:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

# Adaptive trigger: Vibration — motor vibration effect
# Right: mode at byte 11, position at byte 12, amplitude at byte 13, frequency at byte 14
# Left:  mode at byte 22, position at byte 23, amplitude at byte 24, frequency at byte 25
[commands.adaptive_trigger_vibration]
interface = 3
template = "02 0c 00 00 00 00 00 00 00 00 00 06 {r_position:u8} {r_amplitude:u8} {r_frequency:u8} 00 00 00 00 00 00 00 06 {l_position:u8} {l_amplitude:u8} {l_frequency:u8} 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
```

### P6 Compliance

These templates belong in device config (P6): they describe the DualSense USB protocol byte
layout — this is device-specific protocol knowledge, not user preference. The mapping config
(T9) only references mode **names**, never raw bytes.

### No New Code for T8

The `CommandConfig` struct already supports `interface: i64` + `template: []const u8`.
The `fillTemplate` function already handles `{name:u8}` placeholders. Adding new `[commands.*]`
entries to the TOML is purely declarative — no parser or command engine changes required.

---

## T9: Mapping Config Adaptive Trigger Section

### AdaptiveTriggerConfig

Add to `src/config/mapping.zig`:

```zig
pub const AdaptiveTriggerParamConfig = struct {
    position: ?i64 = null,
    strength: ?i64 = null,
    start: ?i64 = null,
    end: ?i64 = null,     // weapon mode: end position
    amplitude: ?i64 = null,
    frequency: ?i64 = null,
};

pub const AdaptiveTriggerConfig = struct {
    mode: []const u8 = "off",
    left: ?AdaptiveTriggerParamConfig = null,
    right: ?AdaptiveTriggerParamConfig = null,
};
```

Add to `MappingConfig`:

```zig
pub const MappingConfig = struct {
    // ... existing fields ...
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
};
```

### TOML Syntax

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

The `mode` field selects which `commands.adaptive_trigger_<mode>` template to use from
the device config. Valid values: `"off"`, `"feedback"`, `"weapon"`, `"vibration"`.

Both sides use the same mode (the DualSense output report sets both triggers in one write).
Per-side params allow different strength/position values for left vs right.

### Per-Layer Override

The `LayerConfig` struct also gains `adaptive_trigger`:

```zig
pub const LayerConfig = struct {
    // ... existing fields ...
    adaptive_trigger: ?AdaptiveTriggerConfig = null,
};
```

This allows layer-specific trigger profiles (e.g., racing layer with strong feedback,
FPS layer with weapon mode).

### Validation

Add to `validate()` in `mapping.zig`:

```zig
fn validateAdaptiveTrigger(at: *const AdaptiveTriggerConfig) !void {
    const valid_modes = [_][]const u8{ "off", "feedback", "weapon", "vibration" };
    for (valid_modes) |v| {
        if (std.mem.eql(u8, at.mode, v)) return;
    }
    return error.InvalidConfig;
}
```

Call from `validate()` for both root-level and per-layer `adaptive_trigger` fields.

### P6 Compliance

The mapping config contains only:
- Mode name (string referencing a command template name)
- Numeric params (position, strength, etc.)

No raw byte sequences, no protocol offsets, no HID report structure knowledge.
This is purely user preference data (P6).

---

## Event Loop Integration

### Resolution Flow

On startup and config reload, the event loop resolves adaptive trigger settings:

```
mapping.adaptive_trigger.mode = "feedback"
    → lookup device_config.commands["adaptive_trigger_feedback"]
    → CommandConfig { interface = 3, template = "02 0c ..." }
    → build Param array from mapping left/right params
    → fillTemplate(allocator, template, params)
    → device.write(bytes)
```

### Implementation

Add to `event_loop.zig`, after device init and before entering the poll loop:

```zig
fn applyAdaptiveTrigger(
    ctx: *EventLoopContext,
    at_cfg: *const AdaptiveTriggerConfig,
) void {
    const alloc = ctx.allocator orelse return;
    const dcfg = ctx.device_config orelse return;
    const cmds = dcfg.commands orelse return;

    const cmd_name = buildCommandName(at_cfg.mode) orelse return;
    const cmd = cmds.map.get(cmd_name) orelse return;

    var params_buf: [12]Param = undefined;
    const params = buildAdaptiveTriggerParams(&params_buf, at_cfg);

    if (fillTemplate(alloc, cmd.template, params)) |bytes| {
        defer alloc.free(bytes);
        const iface_idx: usize = @intCast(cmd.interface);
        if (iface_idx < ctx.devices.len) {
            ctx.devices[iface_idx].write(bytes) catch {};
        }
    } else |_| {}
}
```

`buildCommandName` prepends `"adaptive_trigger_"` to the mode string and returns a
stack-allocated name. `buildAdaptiveTriggerParams` maps left/right params to the
`r_*` and `l_*` placeholder names used in the templates.

### Trigger Points

1. **Startup**: after device open, before entering poll loop
2. **Config reload**: after re-parsing mapping config (inotify or SIGHUP)
3. **Layer switch**: when entering/leaving a layer with `adaptive_trigger` override

This follows the existing pattern: adaptive trigger is a one-shot configuration command
(like LED color), not a continuous per-frame operation (like rumble). The command is sent
once when the mode changes.

### Layer Integration

When a layer with `adaptive_trigger` override activates:
- Send the layer's adaptive trigger command
When the layer deactivates:
- Restore the base layer's adaptive trigger (or "off" if base has none)

This is analogous to how layer gyro/stick overrides work: the layer temporarily
replaces the base config.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Both triggers set in one command template (not per-side) | DualSense output report is monolithic — one write sets both sides. Per-side templates would require two writes, with the second overwriting the first. |
| D2 | Mode name in mapping, byte template in device config | P6: protocol bytes are device knowledge (stable), mode selection is user preference (variable). |
| D3 | No new command engine code for T8 | Existing `CommandConfig` + `fillTemplate` + `Param` system handles adaptive trigger templates identically to rumble/LED. Zero code change for T8. |
| D4 | `adaptive_trigger` as top-level mapping section, not inside `[remap]` | Adaptive trigger is an output device configuration, not a button remapping. Separate section is semantically clearer. |
| D5 | Validation checks mode name against known set | Prevents typos from silently failing. Valid set is closed (DualSense hardware defines exactly 4 modes). |
| D6 | One-shot send on mode change, not per-frame | Adaptive trigger is a configuration command, not continuous output. Sending every frame wastes USB bandwidth and has no effect. |
| D7 | Per-layer override follows existing layer pattern | Consistent with gyro/stick/dpad layer overrides — layer activates, override applies; layer deactivates, base restores. |
| D8 | Param struct uses optional fields, not tagged union per mode | Different modes use different param subsets. Optional fields avoid mode-specific structs while the validation function checks that required params for the selected mode are present. |
