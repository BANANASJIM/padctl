# Tasks: Phase 9 Wave 2 — bits DSL + Touchpad (T4/T5/T6/T7)

Branch: `feat/phase-9-wave2`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T4 first (bits DSL is foundation). T5 depends on T4. T6 depends on T5. T7 depends on T4+T6.
Within each task, sub-steps are sequential.

---

## T4: bits DSL Extension

### T4a: extractBits pure function

- [ ] Add `extractBits` to `src/core/interpreter.zig`:
  ```zig
  fn extractBits(raw: []const u8, byte_offset: u16, start_bit: u3, bit_count: u6) u32
  ```
  - Compute `needed_bytes = (@as(u8, start_bit) + @as(u8, bit_count) + 7) / 8`
  - Read `needed_bytes` from `raw[byte_offset..]` into `u32` little-endian:
    ```zig
    var val: u32 = 0;
    for (0..needed_bytes) |i| {
        val |= @as(u32, raw[byte_offset + i]) << @intCast(i * 8);
    }
    ```
  - Shift and mask: `(val >> start_bit) & (((@as(u32, 1) << bit_count) - 1))`
  - Handle `bit_count == 32` edge case: mask is `0xFFFFFFFF` (shift by 32 is UB in Zig u32)

- [ ] Add `signExtend` helper:
  ```zig
  fn signExtend(val: u32, bit_count: u6) i32 {
      const shift: u5 = @intCast(32 - @as(u8, bit_count));
      return @as(i32, @bitCast(val << shift)) >> shift;
  }
  ```

### T4b: Config parser bits variant

- [ ] In `src/config/device.zig`, add optional `bits` and `bits_type` to `FieldConfig`:
  ```zig
  pub const FieldConfig = struct {
      offset: ?i64 = null,        // existing, now optional
      type: ?[]const u8 = null,   // existing, now optional
      bits: ?[]const i64 = null,
      bits_type: ?[]const u8 = null,
      transform: ?[]const u8 = null,
  };
  ```
  Note: `offset` and `type` become optional (nullable). Existing TOML files that always
  provide both are unaffected — zig-toml treats present values as non-null.

- [ ] Update `validate()` to handle `bits` fields:
  - If `field.bits != null`:
    - Assert `field.bits.len == 3`, else `error.InvalidConfig`
    - Assert `field.offset == null and field.type == null`, else `error.InvalidConfig`
    - Validate `bits[1]` in [0,7], `bits[2]` in [1,32]
    - Bounds check: `bits[0] + ceil((bits[1] + bits[2]) / 8) <= report.size`
    - If `field.bits_type != null`: must be `"unsigned"` or `"signed"`
  - If `field.bits == null`:
    - Assert `field.offset != null and field.type != null`, else `error.InvalidConfig`
    - Existing validation (fieldTypeSize, offset bounds)

- [ ] Update `fieldTypeSize` usage: skip for `bits` fields (no byte-aligned type)

### T4c: CompiledField extension

- [ ] Refactor `CompiledField` in `interpreter.zig` to support both modes:
  ```zig
  const CompiledField = struct {
      tag: FieldTag,
      mode: enum { standard, bits },
      // standard mode
      type_tag: FieldType,
      offset: usize,
      // bits mode
      byte_offset: u16,
      start_bit: u3,
      bit_count: u6,
      is_signed: bool,
      // common
      transforms: CompiledTransformChain,
      has_transform: bool,
  };
  ```
  Using flat fields with a mode tag avoids union complexity. Unused fields are zero-initialized.

- [ ] Update `compileReport` to populate `CompiledField` from config:
  - If `field.bits != null`:
    - `mode = .bits`
    - `byte_offset = @intCast(field.bits[0])`
    - `start_bit = @intCast(field.bits[1])`
    - `bit_count = @intCast(field.bits[2])`
    - `is_signed = if (field.bits_type) |t| std.mem.eql(u8, t, "signed") else false`
    - `type_tag` unused, set to `.u8` (default)
  - Else: existing `offset + type` path, `mode = .standard`

- [ ] Update `extractAndFillCompiled` to dispatch on `mode`:
  ```zig
  var val: i64 = switch (cf.mode) {
      .standard => readFieldByTag(raw, cf.offset, cf.type_tag),
      .bits => blk: {
          const raw_val = extractBits(raw, cf.byte_offset, cf.start_bit, cf.bit_count);
          break :blk if (cf.is_signed)
              @as(i64, signExtend(raw_val, cf.bit_count))
          else
              @as(i64, raw_val);
      },
  };
  ```

---

## T5: Interpreter Touchpad Field Tags

### T5a: GamepadState touchpad fields

- [ ] Add to `GamepadState` in `src/core/state.zig`:
  ```zig
  touch0_x: i16 = 0,
  touch0_y: i16 = 0,
  touch1_x: i16 = 0,
  touch1_y: i16 = 0,
  touch0_active: bool = false,
  touch1_active: bool = false,
  ```

- [ ] Add corresponding optionals to `GamepadStateDelta`:
  ```zig
  touch0_x: ?i16 = null,
  touch0_y: ?i16 = null,
  touch1_x: ?i16 = null,
  touch1_y: ?i16 = null,
  touch0_active: ?bool = null,
  touch1_active: ?bool = null,
  ```

- [ ] Update `diff()`: add comparisons for all 6 new fields
- [ ] Update `applyDelta()`: add assignments for all 6 new fields

### T5b: FieldTag touchpad variants

- [ ] Add to `FieldTag` enum in `interpreter.zig`:
  ```
  touch0_x, touch0_y, touch1_x, touch1_y, touch0_active, touch1_active
  ```

- [ ] Update `parseFieldTag`:
  - `"touch0_x"` -> `.touch0_x`
  - `"touch0_y"` -> `.touch0_y`
  - `"touch1_x"` -> `.touch1_x`
  - `"touch1_y"` -> `.touch1_y`
  - `"touch0_active"` -> `.touch0_active`
  - `"touch1_active"` -> `.touch1_active`

- [ ] Update `applyFieldTag`:
  - `.touch0_x` -> `delta.touch0_x = @truncate(val)`
  - `.touch0_y` -> `delta.touch0_y = @truncate(val)`
  - `.touch1_x` -> `delta.touch1_x = @truncate(val)`
  - `.touch1_y` -> `delta.touch1_y = @truncate(val)`
  - `.touch0_active` -> `delta.touch0_active = val != 0`
  - `.touch1_active` -> `delta.touch1_active = val != 0`

---

## T6: uinput Touchpad Virtual Device

### T6a: TouchpadConfig

- [ ] Add `TouchpadConfig` struct to `src/config/device.zig`:
  ```zig
  pub const TouchpadConfig = struct {
      name: ?[]const u8 = null,
      x_min: i64 = 0,
      x_max: i64 = 0,
      y_min: i64 = 0,
      y_max: i64 = 0,
      max_slots: ?i64 = null,
  };
  ```

- [ ] Add `touchpad: ?TouchpadConfig = null` to `OutputConfig`

### T6b: TouchpadDevice struct

- [ ] Add `TouchpadDevice` to `src/io/uinput.zig`:
  ```zig
  pub const TouchpadDevice = struct {
      fd: std.posix.fd_t,
      prev_slots: [MAX_TOUCH_SLOTS]TouchSlot = [_]TouchSlot{.{}} ** MAX_TOUCH_SLOTS,
      max_slots: u8,
      next_tracking_id: i32 = 0,

      const MAX_TOUCH_SLOTS = 4;
      const TouchSlot = struct {
          x: i32 = 0,
          y: i32 = 0,
          active: bool = false,
      };
  };
  ```

- [ ] Implement `TouchpadDevice.create(cfg: *const TouchpadConfig)`:
  - Open `/dev/uinput` with `O_RDWR | O_NONBLOCK`
  - `UI_SET_EVBIT(EV_ABS)`, `UI_SET_EVBIT(EV_KEY)`
  - `UI_SET_ABSBIT` for `ABS_MT_SLOT`, `ABS_MT_TRACKING_ID`, `ABS_MT_POSITION_X`, `ABS_MT_POSITION_Y`
  - `UI_SET_KEYBIT(BTN_TOUCH)`
  - `UI_ABS_SETUP` for each ABS with appropriate min/max/fuzz/flat
  - `uinput_setup` with name, `BUS_VIRTUAL`
  - `UI_DEV_CREATE`

- [ ] Implement `TouchpadDevice.emit(state: GamepadState)`:
  - Build events array (max 32 events: 4 slots * 5 events/slot + BTN_TOUCH + SYN)
  - Slot 0: `state.touch0_x`, `state.touch0_y`, `state.touch0_active`
  - Slot 1: `state.touch1_x`, `state.touch1_y`, `state.touch1_active`
  - For each slot, compare with `prev_slots[i]`:
    - If changed: emit `ABS_MT_SLOT = i`
    - If newly active: emit `ABS_MT_TRACKING_ID = next_tracking_id++`
    - If newly inactive: emit `ABS_MT_TRACKING_ID = -1`
    - If active and position changed: emit `ABS_MT_POSITION_X`, `ABS_MT_POSITION_Y`
  - Emit `BTN_TOUCH = (any_active ? 1 : 0)` if changed from previous
  - Emit `SYN_REPORT` if any events were written
  - Update `prev_slots`

- [ ] Implement `TouchpadDevice.close()`: `UI_DEV_DESTROY`, `posix.close(fd)`

### T6c: TouchpadOutputDevice vtable

- [ ] Define `TouchpadOutputDevice` vtable in `uinput.zig`:
  ```zig
  pub const TouchpadOutputDevice = struct {
      ptr: *anyopaque,
      vtable: *const VTable,
      pub const VTable = struct {
          emit_touch: *const fn (ptr: *anyopaque, s: state.GamepadState) anyerror!void,
          close: *const fn (ptr: *anyopaque) void,
      };
      pub fn emitTouch(self: TouchpadOutputDevice, s: state.GamepadState) !void { ... }
      pub fn close(self: TouchpadOutputDevice) void { ... }
  };
  ```

- [ ] Add vtable const and wrapper functions to `TouchpadDevice`

### T6d: main.zig integration

- [ ] In `main.zig`: after creating `UinputDevice`, check `cfg.output.touchpad`:
  - If non-null: create `TouchpadDevice`, get `TouchpadOutputDevice`
  - In event loop: after `output.emit(state)`, call `touchpad.emitTouch(state)` if present

---

## T7: Steam Deck Touchpad TOML

### T7a: Update field names

- [ ] In `devices/valve/steam-deck.toml`, rename trackpad fields:
  - `left_pad_x` -> `touch0_x`
  - `left_pad_y` -> `touch0_y`
  - `right_pad_x` -> `touch1_x`
  - `right_pad_y` -> `touch1_y`

### T7b: Add touch active fields

- [ ] Add bits DSL fields for touch active state:
  ```toml
  touch0_active = { bits = [10, 3, 1] }
  touch1_active = { bits = [10, 4, 1] }
  ```
  Byte 10 bit3 = L3_touch (left pad contact), bit4 = R3_touch (right pad contact).
  Value 1 = finger touching, maps directly to `touch0_active = true`.

- [ ] Remove L3_touch/R3_touch from `button_group.map` (they are now touchpad active flags,
  not buttons). If they should remain as buttons too, keep them in button_group and also
  declare as bits fields -- the interpreter processes both independently.

### T7c: Add touchpad output section

- [ ] Add to `devices/valve/steam-deck.toml`:
  ```toml
  [output.touchpad]
  name = "Valve Steam Deck Touchpad"
  x_min = -32768
  x_max = 32767
  y_min = -32768
  y_max = 32767
  max_slots = 2
  ```

### T7d: Cleanup

- [ ] Remove the comment: `# NOTE: interpreter does not yet map trackpad fields to GamepadState (deferred)`
- [ ] Remove or uncomment force sensor fields (remain commented, deferred to WASM)
- [ ] Verify: `zig build test` loads and validates the updated TOML

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/roadmap.md` Phase 9 Wave 2 status
