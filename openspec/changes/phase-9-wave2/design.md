# Design: Phase 9 Wave 2 — bits DSL + Touchpad (T4/T5/T6/T7)

## Files

| File | Role |
|------|------|
| `src/core/interpreter.zig` | Add `extractBits` function, `CompiledBitsField` variant, touchpad FieldTag entries |
| `src/config/device.zig` | Add `BitsFieldConfig` struct, extend `FieldConfig` to support `bits` variant, validation |
| `src/core/state.zig` | Add touchpad fields to `GamepadState` and `GamepadStateDelta` |
| `src/io/uinput.zig` | Add `TouchpadDevice` struct with multitouch uinput capabilities |
| `devices/valve/steam-deck.toml` | Add touchpad field mappings and `[output.touchpad]` section |

---

## T4: bits DSL Extension

### extractBits Pure Function

Per ADR-009, add a single pure function to `interpreter.zig`:

```zig
fn extractBits(raw: []const u8, byte_offset: u16, start_bit: u3, bit_count: u6) u32
```

Algorithm:
1. Compute bytes needed: `needed = (start_bit + bit_count + 7) / 8` (at most 4)
2. Read `needed` bytes from `raw[byte_offset..]` into a `u32` in little-endian order
3. Right-shift by `start_bit`
4. Mask to `bit_count` bits: `result & ((1 << bit_count) - 1)`

For signed fields, the caller performs sign extension:

```zig
fn signExtend(val: u32, bit_count: u6) i32 {
    const shift: u5 = @intCast(32 - bit_count);
    return @as(i32, @bitCast(val << shift)) >> shift;
}
```

Properties:
- Pure function, no side effects, no device-specific logic (P2)
- Layer 0 testable (P9)
- LSB0 bit numbering, little-endian byte assembly (ADR-009)
- Max 32 bits across max 4 bytes (ADR-009)

### Config Parser: BitsFieldConfig

Extend `device.zig` to parse the `bits = [byte_offset, start_bit, len]` syntax:

```zig
pub const BitsFieldConfig = struct {
    bits: []const i64,        // [byte_offset, start_bit, bit_length]
    type: ?[]const u8 = null, // "unsigned" (default) or "signed"
    transform: ?[]const u8 = null,
};
```

`FieldConfig` becomes a tagged union (or the existing struct gains an optional `bits` field):

```zig
pub const FieldConfig = struct {
    offset: ?i64 = null,
    type: ?[]const u8 = null,
    bits: ?[]const i64 = null,    // NEW: [byte_offset, start_bit, bit_length]
    bits_type: ?[]const u8 = null, // NEW: "unsigned" | "signed"
    transform: ?[]const u8 = null,
};
```

A field uses either `offset + type` (existing) or `bits` (new), never both. Validation enforces
mutual exclusivity.

### Config Validation (extended)

Add to `validate()` in `device.zig`:

- If `bits` is present:
  - `bits.len == 3`
  - `bits[0] >= 0` (byte_offset)
  - `bits[1] >= 0 and bits[1] <= 7` (start_bit)
  - `bits[2] >= 1 and bits[2] <= 32` (bit_length)
  - `bits[0] + ceil((bits[1] + bits[2]) / 8) <= report.size` (bounds check)
  - `bits_type` is null, `"unsigned"`, or `"signed"`
- If `bits` is present, `offset` and `type` must be null (mutual exclusivity)
- If `offset` is present, `bits` must be null

### CompiledField Extension

`CompiledField` in `interpreter.zig` gains a bits variant:

```zig
const CompiledField = struct {
    tag: FieldTag,
    mode: union(enum) {
        standard: struct {
            type_tag: FieldType,
            offset: usize,
        },
        bits: struct {
            byte_offset: u16,
            start_bit: u3,
            bit_count: u6,
            is_signed: bool,
        },
    },
    transforms: CompiledTransformChain,
    has_transform: bool,
};
```

`extractAndFillCompiled` switches on `mode`:
- `.standard` -> existing `readFieldByTag` path
- `.bits` -> calls `extractBits`, then optionally `signExtend`

---

## T5: Interpreter Touchpad Field Tags

### GamepadState Extension

Add to `state.zig`:

```zig
pub const GamepadState = struct {
    // ... existing fields ...
    touch0_x: i16 = 0,
    touch0_y: i16 = 0,
    touch1_x: i16 = 0,
    touch1_y: i16 = 0,
    touch0_active: bool = false,
    touch1_active: bool = false,
};
```

Corresponding nullable fields in `GamepadStateDelta`:

```zig
pub const GamepadStateDelta = struct {
    // ... existing fields ...
    touch0_x: ?i16 = null,
    touch0_y: ?i16 = null,
    touch1_x: ?i16 = null,
    touch1_y: ?i16 = null,
    touch0_active: ?bool = null,
    touch1_active: ?bool = null,
};
```

Update `diff()` and `applyDelta()` to include the new fields.

### FieldTag Extension

Add touchpad variants to `FieldTag` enum and wire into `parseFieldTag` / `applyFieldTag`:

```zig
const FieldTag = enum {
    // ... existing ...
    touch0_x,
    touch0_y,
    touch1_x,
    touch1_y,
    touch0_active,
    touch1_active,
    unknown,
};
```

`parseFieldTag`:
- `"touch0_x"` -> `.touch0_x`
- `"touch0_y"` -> `.touch0_y`
- `"touch1_x"` -> `.touch1_x`
- `"touch1_y"` -> `.touch1_y`
- `"touch0_active"` / `"touch0_contact"` -> `.touch0_active` (contact byte: bit7=inactive)
- `"touch1_active"` / `"touch1_contact"` -> `.touch1_active`

`applyFieldTag`:
- `.touch0_x` -> `delta.touch0_x = @truncate(val)`
- `.touch0_active` -> `delta.touch0_active = (val & 0x80) == 0` (DualSense: bit7=0 means active)

For `touch0_active`/`touch1_active`, the mapping `(val & 0x80) == 0` is DualSense-specific.
To keep the interpreter generic (P2), the contact-to-active conversion should be done via
`transform`. The `touch0_contact` field maps to `.touch0_active` FieldTag, and a new
`active_low_bit7` transform handles the inversion:

Alternative (preferred for P2 compliance): treat `touch0_active` as a standard boolean field.
The TOML declares it with `bits = [33, 7, 1]` and the interpreter stores `val == 0` as active.
This uses pure bits DSL without device-specific logic in the interpreter.

### Design Decision: Active Flag Mapping

The `touch0_active` field can be declared two ways:

1. **Via bits DSL** (preferred): `touch0_active = { bits = [33, 7, 1], transform = "negate" }`
   - bit7=1 means inactive; `negate` flips it; interpreter sees `0` or `1`
   - No device-specific logic in interpreter (P2)

2. **Via contact byte**: `touch0_contact = { offset = 33, type = "u8" }` with interpreter doing `(val & 0x80) == 0`
   - Puts device knowledge in interpreter; violates P2

Decision: Option 1. The TOML author knows the protocol; the interpreter stays generic.

---

## T6: uinput Touchpad Virtual Device

### Third Output Device

Per P8, all output device creation params must be declared in TOML. The touchpad device is a
third uinput device alongside the main gamepad and aux mouse/keyboard.

### OutputConfig Extension

Add `touchpad` section to `OutputConfig`:

```zig
pub const TouchpadConfig = struct {
    name: ?[]const u8 = null,
    x_min: i64 = 0,
    x_max: i64 = 0,
    y_min: i64 = 0,
    y_max: i64 = 0,
    max_slots: ?i64 = null, // default 2 (dual-touch)
};

pub const OutputConfig = struct {
    // ... existing fields ...
    touchpad: ?TouchpadConfig = null,
};
```

### TOML Syntax

```toml
[output.touchpad]
name = "padctl Touchpad"
x_min = -32768
x_max = 32767
y_min = -32768
y_max = 32767
max_slots = 2
```

All parameters declared in device config (P8). `max_slots` defaults to 2 (dual-touch, covers
DualSense and Steam Deck).

### TouchpadDevice Struct

New struct in `uinput.zig`:

```zig
pub const TouchpadDevice = struct {
    fd: std.posix.fd_t,
    prev_slots: [MAX_TOUCH_SLOTS]TouchSlot,
    max_slots: u8,

    const MAX_TOUCH_SLOTS = 4;
    const TouchSlot = struct {
        x: i32 = 0,
        y: i32 = 0,
        active: bool = false,
    };
};
```

### uinput Registration

`TouchpadDevice.create(cfg: *const TouchpadConfig)`:

1. `UI_SET_EVBIT(EV_ABS)` + `UI_SET_EVBIT(EV_KEY)`
2. Register ABS capabilities:
   - `ABS_MT_SLOT` (min=0, max=max_slots-1)
   - `ABS_MT_TRACKING_ID` (min=0, max=65535)
   - `ABS_MT_POSITION_X` (min=x_min, max=x_max)
   - `ABS_MT_POSITION_Y` (min=y_min, max=y_max)
3. `UI_SET_KEYBIT(BTN_TOUCH)`
4. `UI_SET_PROPBIT(INPUT_PROP_POINTER)` (identify as touchpad, not touchscreen)
5. `UI_DEV_SETUP` with name, `BUS_VIRTUAL`, no VID/PID
6. `UI_DEV_CREATE`

### Touchpad Event Emission

`TouchpadDevice.emit(state: GamepadState)`:

For each touch slot (0..max_slots):
1. Compare current vs previous active/x/y
2. If state changed:
   - Emit `EV_ABS, ABS_MT_SLOT, slot_index`
   - If newly active: emit `ABS_MT_TRACKING_ID, <monotonic_id++>`
   - If newly inactive: emit `ABS_MT_TRACKING_ID, -1`
   - If active: emit `ABS_MT_POSITION_X, x` and `ABS_MT_POSITION_Y, y`
3. Emit `BTN_TOUCH` = `1` if any slot active, `0` if none
4. `SYN_REPORT`

Differential: only emit changed slots (same principle as gamepad ABS diff).

### TouchpadOutputDevice vtable

```zig
pub const TouchpadOutputDevice = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        emit_touch: *const fn (ptr: *anyopaque, state: state.GamepadState) anyerror!void,
        close: *const fn (ptr: *anyopaque) void,
    };
};
```

`main.zig` event loop: after `OutputDevice.emit(state)`, if touchpad device exists,
call `TouchpadOutputDevice.emit_touch(state)`.

---

## T7: Steam Deck Touchpad Complete TOML

### Current State

`devices/valve/steam-deck.toml` already declares:
- `left_pad_x = { offset = 16, type = "i16le" }` (byte-aligned, no bits DSL needed)
- `left_pad_y = { offset = 18, type = "i16le" }`
- `right_pad_x = { offset = 20, type = "i16le" }`
- `right_pad_y = { offset = 22, type = "i16le" }`
- Button group includes bits for L3_touch (bit 19) and R3_touch (bit 20) at byte 10

### Changes

1. Rename `left_pad_x/y` -> `touch0_x/y`, `right_pad_x/y` -> `touch1_x/y` so interpreter
   maps them to touchpad FieldTag variants:

```toml
[report.fields]
# ... existing sticks, triggers, IMU ...
touch0_x = { offset = 16, type = "i16le" }
touch0_y = { offset = 18, type = "i16le" }
touch1_x = { offset = 20, type = "i16le" }
touch1_y = { offset = 22, type = "i16le" }
```

2. Add touch active fields via bits DSL from the button bitfield.
   Steam Deck byte 10 bit3 = L3_touch (left pad touched), bit4 = R3_touch (right pad touched):

```toml
touch0_active = { bits = [10, 3, 1] }
touch1_active = { bits = [10, 4, 1] }
```

These are single-bit fields within one byte (no cross-byte needed), but use the same `bits`
DSL for consistency.

3. Add touchpad output section:

```toml
[output.touchpad]
name = "Valve Steam Deck Touchpad"
x_min = -32768
x_max = 32767
y_min = -32768
y_max = 32767
max_slots = 2
```

4. Remove the comment "interpreter does not yet map trackpad fields to GamepadState (deferred)".

### DualSense Touchpad (out of scope, documented for future reference)

DualSense touchpad fields will use `bits` DSL in a future update:

```toml
touch0_x = { bits = [34, 0, 12] }
touch0_y = { bits = [35, 4, 12] }
touch0_active = { bits = [33, 7, 1], transform = "negate" }
touch1_x = { bits = [38, 0, 12] }
touch1_y = { bits = [39, 4, 12] }
touch1_active = { bits = [37, 7, 1], transform = "negate" }
```

This is not part of T7 scope (Steam Deck only).

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | `bits` as optional field in `FieldConfig`, not a tagged union | zig-toml parser maps TOML tables to flat structs; tagged unions require custom parsing. Optional fields with mutual exclusivity validation is simpler. |
| D2 | Sign extension at interpreter call site, not inside `extractBits` | `extractBits` returns `u32`; signedness is a caller concern. Keeps the pure function simple. |
| D3 | Touchpad as third uinput device, not folded into gamepad | Linux input subsystem expects touchpads as separate devices (INPUT_PROP_POINTER). Games/desktop distinguish by device capabilities. |
| D4 | `[output.touchpad]` in device config, not separate config | P8: output device shape is protocol-determined (stable), not user preference (variable). P6: device config scope. |
| D5 | `touch0_active` via `bits` DSL, not interpreter-hardcoded | P2: interpreter has no device-specific logic. Protocol knowledge stays in TOML. |
| D6 | Steam Deck touch active from button bitfield bits, not separate bytes | Steam Deck protocol: L3_touch/R3_touch are button bits, not separate fields. Reuse existing button byte range via `bits` DSL. |
| D7 | `TouchpadOutputDevice` vtable, not direct `TouchpadDevice` coupling | P9: Layer 1 tests inject `MockTouchpadOutput`, no `/dev/uinput` dependency. |
