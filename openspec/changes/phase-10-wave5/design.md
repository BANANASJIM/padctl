# Design: Phase 10 Wave 5 — Generic Device Mapping (T19-T23)

## Files

| File | Role |
|------|------|
| `src/core/generic.zig` | T19: `GenericFieldSlot`, `GenericDeviceState`, `extractGenericFields`, `emitGeneric` |
| `src/config/device.zig` | T20: `MappingEntry`, `mode` field on `DeviceInfo`, `mapping` field on `OutputConfig` |
| `src/config/input_codes.zig` | T20: `resolveEventCode` unified resolver (ABS/BTN prefix dispatch) |
| `src/io/uinput.zig` | T22: `GenericUinputDevice` — generic device creation + emit |
| `src/event_loop.zig` | T21: generic branch in `run()` loop |
| `devices/example/generic-wheel.toml` | T23: example device config |
| `build.zig` | Register new test file if needed |

---

## T19: GenericFieldSlot + GenericDeviceState

### Problem

The interpreter pipeline is tightly coupled to `GamepadStateDelta` via `FieldTag` enum
and `applyFieldTag()`. Non-gamepad fields have no FieldTag and are silently dropped.

### Solution

Create `src/core/generic.zig` with a fixed-array state representation that maps field
index to event code at config-load time.

```zig
pub const MAX_GENERIC_FIELDS = 32;

pub const GenericFieldSlot = struct {
    event_type: u16,    // EV_ABS / EV_KEY
    event_code: u16,    // ABS_WHEEL / BTN_GEAR_UP / ...
    range_min: i32,
    range_max: i32,
    is_button: bool,    // true = value != 0 -> 1
    // compiled field extraction params (copied from CompiledField)
    mode: enum { standard, bits },
    type_tag: @import("interpreter.zig").FieldType,
    offset: usize,
    byte_offset: u16,
    start_bit: u3,
    bit_count: u6,
    is_signed: bool,
    transforms: @import("interpreter.zig").CompiledTransformChain,
    has_transform: bool,
};

pub const GenericDeviceState = struct {
    slots: [MAX_GENERIC_FIELDS]GenericFieldSlot,
    values: [MAX_GENERIC_FIELDS]i32,
    prev_values: [MAX_GENERIC_FIELDS]i32,
    count: u8,
};
```

**Key design decisions:**

- **Flat array, no HashMap** — field name matching happens once at config load; runtime
  uses only integer indices. Zero allocations, zero string comparisons in the hot path.
- **Extraction params embedded in slot** — each `GenericFieldSlot` carries its own
  extraction parameters (offset/type/bits/transform), avoiding a separate `CompiledField`
  indirection. The extraction functions (`readFieldByTag`, `extractBits`,
  `runTransformChain`) are called directly using these params.
- **`prev_values` for differential emit** — same pattern as `UinputDevice.prev` for
  gamepad, but stored as a flat i32 array.

### Shared infrastructure

The following interpreter functions must be exported as `pub` (if not already):

- `readFieldByTag` — byte extraction by type tag
- `extractBits` (already pub) — sub-byte field extraction
- `signExtend` (already pub) — sign extension for bits mode
- `runTransformChain` — transform chain execution
- `compileTransformChain` — transform chain compilation
- `FieldType`, `parseFieldType` — type tag enum + parser
- `CompiledTransformChain` — transform chain struct

These are pure functions with no gamepad semantic dependency.

### extractGenericFields function

```zig
pub fn extractGenericFields(state: *GenericDeviceState, raw: []const u8) void {
    for (state.slots[0..state.count], 0..state.count) |*slot, i| {
        var val: i64 = switch (slot.mode) {
            .standard => interpreter.readFieldByTag(raw, slot.offset, slot.type_tag),
            .bits => blk: {
                const raw_val = interpreter.extractBits(raw, slot.byte_offset, slot.start_bit, slot.bit_count);
                break :blk if (slot.is_signed) @as(i64, interpreter.signExtend(raw_val, slot.bit_count)) else @as(i64, raw_val);
            },
        };
        if (slot.has_transform) val = interpreter.runTransformChain(val, &slot.transforms);
        state.values[i] = if (slot.is_button)
            @intCast(@intFromBool(val != 0))
        else
            @intCast(std.math.clamp(val, slot.range_min, slot.range_max));
    }
}
```

---

## T20: Config Parser — mode + [output.mapping]

### Problem

`DeviceConfig` has no `mode` field. `OutputConfig` has no `mapping` section. There is no
way to declare generic field-to-event-code mappings in TOML.

### Solution

#### T20a: Add mode to DeviceInfo

```zig
pub const DeviceInfo = struct {
    name: []const u8,
    vid: i64,
    pid: i64,
    interface: []const InterfaceConfig,
    init: ?InitConfig = null,
    mode: ?[]const u8 = null,  // "gamepad" (default) | "generic"
};
```

All existing TOMLs omit `mode` -> defaults to null -> treated as `"gamepad"`.

#### T20b: Add MappingEntry and mapping to OutputConfig

```zig
pub const MappingEntry = struct {
    event: []const u8,          // "ABS_WHEEL", "BTN_GEAR_UP"
    range: ?[]const i64 = null, // [min, max] — required for ABS, ignored for BTN
    fuzz: ?i64 = null,
    flat: ?i64 = null,
    res: ?i64 = null,
};

pub const OutputConfig = struct {
    // ... existing fields ...
    mapping: ?toml.HashMap(MappingEntry) = null,
};
```

#### T20c: Add resolveEventCode to input_codes.zig

**Prerequisite**: Add `BTN_GEAR_UP` (0x151) and `BTN_GEAR_DOWN` (0x150) to
`btn_table` in `input_codes.zig`. These are valid Linux kernel codes used by the
example TOML but currently absent from the lookup table.

A unified resolver that dispatches by event name prefix:

```zig
pub const ResolvedEvent = struct {
    event_type: u16,  // EV_ABS or EV_KEY
    event_code: u16,
};

pub fn resolveEventCode(name: []const u8) error{UnknownEventCode}!ResolvedEvent {
    if (std.mem.startsWith(u8, name, "ABS_")) {
        return .{ .event_type = c.EV_ABS, .event_code = resolveAbsCode(name) catch return error.UnknownEventCode };
    }
    if (std.mem.startsWith(u8, name, "BTN_") or std.mem.startsWith(u8, name, "KEY_")) {
        return .{ .event_type = c.EV_KEY, .event_code = resolveBtnCode(name) catch return error.UnknownEventCode };
    }
    return error.UnknownEventCode;
}
```

#### T20d: Validation for generic mode

In `validate()`, add a branch for generic mode:

- If `mode == "generic"`:
  - `output.mapping` must be non-null
  - Every key in `[output.mapping]` must have a corresponding field name in some
    `[report.fields]` or `[report.button_group.map]`
  - Every `event` string must resolve via `resolveEventCode`
  - ABS events must have `range` with exactly 2 elements
  - BTN/KEY events must not have `range`
- If `mode == "generic"`, `button_group.map` keys are NOT validated against `ButtonId`
  enum (they are arbitrary field names)

---

## T21: Generic Emit Path in event_loop

### Problem

`EventLoop.run()` always produces `GamepadStateDelta` and emits via
`OutputDevice.emit(GamepadState)`. Generic devices have no `GamepadState`.

### Solution

Add a generic branch at the top of the device-fd processing block in `run()`.

#### T21a: Extend EventLoopContext

```zig
pub const EventLoopContext = struct {
    // ... existing fields ...
    generic_state: ?*GenericDeviceState = null,
    generic_output: ?*GenericUinputDevice = null,
};
```

#### T21b: Generic branch in run()

In the inner loop where `maybe_delta` is computed and applied, add a check before
the existing gamepad path:

```zig
if (ctx.generic_state) |gs| {
    // Generic path: match report, extract fields, emit directly
    if (ctx.interpreter.matchReport(interface_id, buf[0..n])) |cr| {
        if (raw.len >= @as(usize, @intCast(cr.src.size))) {
            verifyChecksumCompiled(cr, buf[0..n]) catch continue;
            generic.extractGenericFields(gs, buf[0..n]);
            if (ctx.generic_output) |go| go.emitGeneric(gs) catch {};
        }
    }
} else {
    // Existing gamepad path (unchanged)
    const maybe_delta = ...;
    // ...
}
```

#### T21c: Export matchCompiled from Interpreter

The `matchCompiled` method is currently private. Export it as `pub fn matchReport`
so the generic path can reuse report matching + checksum verification without
duplicating the logic. Also export `verifyChecksumCompiled` as pub.

---

## T22: Generic Uinput Device Creation

### Problem

`UinputDevice.create()` registers capabilities based on `[output.axes]` and
`[output.buttons]` with gamepad-specific AxisStateField mapping. Generic devices
declare capabilities via `[output.mapping]`.

### Solution

Create `GenericUinputDevice` in `src/io/uinput.zig` (or `src/core/generic.zig`).

```zig
pub const GenericUinputDevice = struct {
    fd: std.posix.fd_t,

    pub fn create(cfg: *const device.OutputConfig, state: *GenericDeviceState) !GenericUinputDevice {
        const mapping = cfg.mapping orelse return error.NoMapping;
        const fd = try std.posix.open("/dev/uinput", .{ .ACCMODE = .RDWR, .NONBLOCK = true }, 0);
        errdefer std.posix.close(fd);

        var has_abs = false;
        var has_key = false;
        var slot_count: u8 = 0;

        // Pass 1: resolve event codes, register capabilities, build slots
        var it = mapping.map.iterator();
        while (it.next()) |entry| {
            if (slot_count >= generic.MAX_GENERIC_FIELDS) break;
            const me = entry.value_ptr.*;
            const resolved = try input_codes.resolveEventCode(me.event);

            if (resolved.event_type == c.EV_ABS) {
                if (!has_abs) { try ioctlInt(fd, UI_SET_EVBIT, c.EV_ABS); has_abs = true; }
                try ioctlInt(fd, UI_SET_ABSBIT, @intCast(resolved.event_code));
            } else {
                if (!has_key) { try ioctlInt(fd, UI_SET_EVBIT, c.EV_KEY); has_key = true; }
                try ioctlInt(fd, UI_SET_KEYBIT, @intCast(resolved.event_code));
            }

            state.slots[slot_count].event_type = resolved.event_type;
            state.slots[slot_count].event_code = resolved.event_code;
            state.slots[slot_count].is_button = (resolved.event_type == c.EV_KEY);
            if (me.range) |r| {
                state.slots[slot_count].range_min = @intCast(r[0]);
                state.slots[slot_count].range_max = @intCast(r[1]);
            }
            slot_count += 1;
        }
        state.count = slot_count;

        // UI_DEV_SETUP
        var setup = std.mem.zeroes(c.uinput_setup);
        // ... name/vid/pid from cfg ...
        try ioctlPtr(fd, UI_DEV_SETUP, @intFromPtr(&setup));

        // UI_ABS_SETUP for each ABS slot
        for (state.slots[0..slot_count]) |slot| {
            if (slot.event_type != c.EV_ABS) continue;
            var abs_setup = std.mem.zeroes(c.uinput_abs_setup);
            abs_setup.code = slot.event_code;
            abs_setup.absinfo.minimum = slot.range_min;
            abs_setup.absinfo.maximum = slot.range_max;
            try ioctlPtr(fd, UI_ABS_SETUP, @intFromPtr(&abs_setup));
        }

        try ioctlPtr(fd, UI_DEV_CREATE, 0);
        return .{ .fd = fd };
    }

    pub fn emitGeneric(self: *GenericUinputDevice, state: *GenericDeviceState) !void {
        var events: [generic.MAX_GENERIC_FIELDS + 1]c.input_event = undefined;
        var n: usize = 0;

        for (0..state.count) |i| {
            if (state.values[i] != state.prev_values[i]) {
                events[n] = .{
                    .type = state.slots[i].event_type,
                    .code = state.slots[i].event_code,
                    .value = state.values[i],
                    .time = std.mem.zeroes(c.timeval),
                };
                n += 1;
            }
        }

        if (n > 0) {
            events[n] = .{ .type = c.EV_SYN, .code = c.SYN_REPORT, .value = 0, .time = std.mem.zeroes(c.timeval) };
            n += 1;
            _ = try std.posix.write(self.fd, std.mem.sliceAsBytes(events[0..n]));
        }
        state.prev_values = state.values;
    }

    pub fn close(self: *GenericUinputDevice) void {
        _ = std.os.linux.ioctl(self.fd, UI_DEV_DESTROY, 0);
        std.posix.close(self.fd);
    }
};
```

This reuses `ioctlInt`, `ioctlPtr`, `UI_*` constants, and `input_codes.resolveEventCode`.
The emit logic follows the same differential pattern as `UinputDevice.emit()` but
iterates a flat array instead of enum-based struct fields.

---

## T23: Example Device TOML

### Problem

No reference exists for generic mode TOML syntax.

### Solution

Create `devices/example/generic-wheel.toml` — a fictional racing wheel demonstrating
all generic mode features:

```toml
[device]
name = "Example Racing Wheel"
vid = 0x044f
pid = 0xb66e
mode = "generic"

[[device.interface]]
id = 0
class = "hid"

[[report]]
name = "main"
interface = 0
size = 12

[report.fields]
wheel_angle = { offset = 0, type = "i16le" }
gas_pedal   = { offset = 2, type = "u8", transform = "negate" }
brake_pedal = { offset = 3, type = "u8" }
clutch      = { offset = 4, type = "u8" }

[report.button_group]
source = { offset = 5, size = 1 }
map = { gear_up = 0, gear_down = 1, paddle_left = 2, paddle_right = 3 }

[output]
name = "Example Racing Wheel"
vid = 0x044f
pid = 0xb66e

[output.mapping]
wheel_angle  = { event = "ABS_WHEEL",      range = [-32768, 32767] }
gas_pedal    = { event = "ABS_GAS",         range = [0, 255] }
brake_pedal  = { event = "ABS_BRAKE",       range = [0, 255] }
clutch       = { event = "ABS_RZ",          range = [0, 255] }
gear_up      = { event = "BTN_GEAR_UP" }
gear_down    = { event = "BTN_GEAR_DOWN" }
paddle_left  = { event = "BTN_0" }
paddle_right = { event = "BTN_1" }
```

This serves as documentation and as a parse/validate test target for the auto-device
test infrastructure.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Explicit `mode = "generic"` field, not auto-detect from `[output.mapping]` | P3 progressive complexity — gamepad users never see generic concepts. Avoids ambiguity if gamepad TOML also has custom mapping. |
| D2 | Flat i32 array for values, not HashMap | Zero allocation, zero string ops at runtime. Field-to-slot mapping resolved once at config load. Same philosophy as `CompiledField`. |
| D3 | Extraction params embedded in `GenericFieldSlot` | Avoids a second parallel array or indirection. Each slot is self-contained for extraction + emit. |
| D4 | No remap/layer for generic mode | Research R3 — non-gamepad devices handle remapping in-game or via TOML profile variants. Remap can be added later via slot-index mapping if needed. |
| D5 | Generic path in `src/core/generic.zig`, not inlined in interpreter.zig | Keeps interpreter.zig focused on gamepad semantics. Generic logic is a parallel module sharing the same extraction primitives. |
| D6 | `resolveEventCode` dispatches by prefix | ABS_/BTN_/KEY_ prefix is unambiguous. Reuses existing `resolveAbsCode`/`resolveBtnCode` tables. |
| D7 | `button_group.map` keys skip ButtonId validation in generic mode | Generic mode uses arbitrary field names — they match `[output.mapping]` keys, not the ButtonId enum. |
| D8 | Example in `devices/example/` not `devices/thrustmaster/` | Example is fictional. Real devices go in vendor directories. Example is auto-discovered by test infrastructure. |
