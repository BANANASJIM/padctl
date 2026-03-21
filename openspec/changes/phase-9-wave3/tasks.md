# Tasks: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

Branch: `feat/phase-9-wave3`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T8 first (command templates, zero code changes). T9 depends on T8.
Within each task, sub-steps are sequential.

---

## T8: Adaptive Trigger Command Templates

### T8a: Add command templates to dualsense.toml

- [ ] Add 4 command entries to `devices/sony/dualsense.toml` after existing `[commands.led]`:
  ```toml
  [commands.adaptive_trigger_off]
  interface = 3
  template = "02 0c 00 ..."  # 63 bytes, valid_flag0=0x0c, mode bytes = 0x00

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
  Full templates in `design.md`. Each is a 63-byte USB output report with `valid_flag0 = 0x0c`
  (bits 2+3 = enable right+left trigger effects).

- [ ] Add comments documenting the DualSense adaptive trigger byte layout:
  ```toml
  # Adaptive trigger output report byte layout:
  # byte 1 = valid_flag0: bit2=right trigger, bit3=left trigger (0x0c = both)
  # bytes 11-21 = right trigger: [mode, param0, param1, ...]
  # bytes 22-32 = left trigger:  [mode, param0, param1, ...]
  # Modes: 0x00=Off, 0x01=Feedback, 0x02=Weapon, 0x06=Vibration
  ```

### T8b: Verify existing tests still pass

- [ ] Existing `dualsense.toml` parse tests in `device.zig` must pass:
  - `"load devices/sony/dualsense.toml succeeds"` — name, vid, pid, report count
  - `"dualsense.toml commands count"` — update expected count from 2 to 6
  - `"dualsense.toml report field count"` — unchanged (16 fields)
  - `"dualsense.toml output axes and buttons count"` — unchanged

---

## T9: Mapping Config Adaptive Trigger Section

### T9a: AdaptiveTriggerConfig structs

- [ ] Add to `src/config/mapping.zig`:
  ```zig
  pub const AdaptiveTriggerParamConfig = struct {
      position: ?i64 = null,
      strength: ?i64 = null,
      start: ?i64 = null,
      end: ?i64 = null,
      amplitude: ?i64 = null,
      frequency: ?i64 = null,
  };

  pub const AdaptiveTriggerConfig = struct {
      mode: []const u8 = "off",
      left: ?AdaptiveTriggerParamConfig = null,
      right: ?AdaptiveTriggerParamConfig = null,
  };
  ```

- [ ] Add `adaptive_trigger: ?AdaptiveTriggerConfig = null` to `MappingConfig`

- [ ] Add `adaptive_trigger: ?AdaptiveTriggerConfig = null` to `LayerConfig`

### T9b: Validation

- [ ] Add `validateAdaptiveTrigger` function:
  ```zig
  const valid_at_modes = [_][]const u8{ "off", "feedback", "weapon", "vibration" };

  fn validateAdaptiveTrigger(at: *const AdaptiveTriggerConfig) !void {
      for (valid_at_modes) |v| {
          if (std.mem.eql(u8, at.mode, v)) return;
      }
      return error.InvalidConfig;
  }
  ```

- [ ] Call from `validate()`:
  - If `cfg.adaptive_trigger` is non-null, call `validateAdaptiveTrigger`
  - In the layer loop, if `layer.adaptive_trigger` is non-null, call `validateAdaptiveTrigger`

### T9c: Event loop integration

- [ ] Add `buildAdaptiveTriggerParams` to `src/event_loop.zig`:
  - Maps `AdaptiveTriggerParamConfig` left/right fields to `Param` array with `l_`/`r_` prefixes
  - Default param values to 0 when null (mode "off" uses no params; others have defaults)

- [ ] Add `applyAdaptiveTrigger` to `src/event_loop.zig`:
  - Concatenate `"adaptive_trigger_"` + `mode` to form command name
  - Look up command in `device_config.commands`
  - Build params array from mapping left/right
  - Call `fillTemplate` + device write
  - Follow existing rumble routing pattern (lines 201-214)

- [ ] Call `applyAdaptiveTrigger` at startup (after device open, before poll loop)

- [ ] Call `applyAdaptiveTrigger` on config reload (SIGHUP / inotify path)

- [ ] Call `applyAdaptiveTrigger` on layer activation/deactivation:
  - Layer with `adaptive_trigger`: apply layer's config
  - Layer deactivation: restore base `mapping.adaptive_trigger` (or send "off" if none)

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/roadmap.md` Phase 9 Wave 3 status
