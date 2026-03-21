# Tasks: Phase 10 Wave 5 — Generic Device Mapping (T19-T23)

Branch: `feat/phase-10-wave5`
Commit: (leave blank -- filled after implementation)

## Execution Plan

T19 has no unfinished dependencies (T1/T2 done). T20 depends on T19.
T21 and T22 both depend on T20 and can be done in parallel.
T23 depends on T20+T21+T22.

Recommended order: T19 -> T20 -> T21 + T22 (parallel) -> T23.

---

## T19: GenericFieldSlot + GenericDeviceState

### T19a: Create src/core/generic.zig

- [ ] Create `src/core/generic.zig`
- [ ] Define `MAX_GENERIC_FIELDS = 32`
- [ ] Define `GenericFieldSlot` struct with: `event_type: u16`, `event_code: u16`,
  `range_min: i32`, `range_max: i32`, `is_button: bool`, plus extraction params
  (`mode`, `type_tag`, `offset`, `byte_offset`, `start_bit`, `bit_count`,
  `is_signed`, `transforms`, `has_transform`)

### T19b: Define GenericDeviceState

- [ ] Define `GenericDeviceState` struct with: `slots: [MAX_GENERIC_FIELDS]GenericFieldSlot`,
  `values: [MAX_GENERIC_FIELDS]i32`, `prev_values: [MAX_GENERIC_FIELDS]i32`, `count: u8`

### T19c: Export shared interpreter primitives

- [ ] In `src/core/interpreter.zig`, export as `pub`:
  - `FieldType` enum
  - `parseFieldType` function
  - `readFieldByTag` function
  - `runTransformChain` function
  - `compileTransformChain` function
  - `CompiledTransformChain` struct
- [ ] Verify no compilation errors — these are pure functions, adding `pub` has no
  side effects

### T19d: Implement extractGenericFields

- [ ] In `src/core/generic.zig`, implement `extractGenericFields(state, raw)`:
  - For each slot `0..state.count`:
    - Extract value via `readFieldByTag` (standard mode) or `extractBits` + `signExtend`
      (bits mode)
    - Apply transform chain if `has_transform`
    - For buttons: `@intFromBool(val != 0)`
    - For axes: `std.math.clamp(val, range_min, range_max)`
    - Write to `state.values[i]`

### T19e: Unit tests for GenericDeviceState

- [ ] Test: constructing a GenericDeviceState with 2 slots, manually setting extraction
  params, calling extractGenericFields with a synthetic byte buffer, verifying values
- [ ] Test: button slot produces 0/1 from raw value
- [ ] Test: axis slot clamps to range

---

## T20: Config Parser — mode + [output.mapping]

### T20a: Add mode field to DeviceInfo

- [ ] In `src/config/device.zig`, add `mode: ?[]const u8 = null` to `DeviceInfo`

### T20b: Add MappingEntry and mapping to OutputConfig

- [ ] Define `MappingEntry` struct: `event: []const u8`, `range: ?[]const i64 = null`,
  `fuzz: ?i64 = null`, `flat: ?i64 = null`, `res: ?i64 = null`
- [ ] Add `mapping: ?toml.HashMap(MappingEntry) = null` to `OutputConfig`

### T20c: Add resolveEventCode to input_codes.zig

- [ ] Add `BTN_GEAR_UP` and `BTN_GEAR_DOWN` to `btn_table` (missing from current table)
- [ ] Define `ResolvedEvent` struct: `event_type: u16`, `event_code: u16`
- [ ] Implement `resolveEventCode(name)`: dispatch by `ABS_`/`BTN_`/`KEY_` prefix
  to existing `resolveAbsCode`/`resolveBtnCode`
- [ ] Test: `resolveEventCode("ABS_WHEEL")` returns `{ EV_ABS, ABS_WHEEL }`
- [ ] Test: `resolveEventCode("BTN_GEAR_UP")` returns `{ EV_KEY, BTN_GEAR_UP }`
- [ ] Test: `resolveEventCode("INVALID")` returns error

### T20d: Validation for generic mode

- [ ] In `validate()`, when `cfg.device.mode` equals `"generic"`:
  - Skip `ButtonId` validation for `button_group.map` keys
  - Verify `output.mapping` is non-null
  - For each mapping entry: verify `resolveEventCode(event)` succeeds
  - For ABS entries: verify `range` is non-null and has exactly 2 elements
  - For BTN/KEY entries: verify `range` is null (optional: warn but don't error)
- [ ] Test: valid generic TOML parses without error
- [ ] Test: generic TOML missing `[output.mapping]` returns error
- [ ] Test: generic TOML with unknown event code returns error
- [ ] Test: generic TOML with ABS event missing range returns error

### T20e: Compile generic slots from config

- [ ] Implement `compileGenericState(config, mapping)` in `src/core/generic.zig`:
  - For each `[output.mapping]` entry, find matching field name in `[report.fields]`
    or `[report.button_group.map]`
  - Compile extraction params (offset/type/bits/transform) into `GenericFieldSlot`
  - Resolve event code via `resolveEventCode`
  - Set `is_button` from event type prefix
  - Return populated `GenericDeviceState`
- [ ] Test: compile from a test config, verify slot count and event codes

---

## T21: Generic Emit Path in event_loop

### T21a: Extend EventLoopContext

- [ ] Add `generic_state: ?*GenericDeviceState = null` to `EventLoopContext`
- [ ] Add `generic_output: ?*GenericUinputDevice = null` to `EventLoopContext`
  (use forward import from `generic.zig` or `uinput.zig`)

### T21b: Export matchCompiled from Interpreter

- [ ] Rename `matchCompiled` to `matchReport` (or add pub wrapper)
- [ ] Export as `pub fn matchReport(self, interface_id, raw) ?*const CompiledReport`
- [ ] Export `verifyChecksumCompiled` as pub (or add pub wrapper)

### T21c: Add generic branch in run()

- [ ] In the device-fd read loop, before the existing `maybe_delta` computation,
  check `if (ctx.generic_state) |gs|`
- [ ] If generic: call `interpreter.matchReport` -> `verifyChecksumCompiled` ->
  `generic.extractGenericFields` -> `generic_output.emitGeneric`
- [ ] `else`: existing gamepad path (unchanged)
- [ ] No mapper/remap/layer/touchpad/aux for generic path

---

## T22: Generic Uinput Device Creation

### T22a: Implement GenericUinputDevice

- [ ] Create `GenericUinputDevice` struct in `src/io/uinput.zig` (or `src/core/generic.zig`)
  with `fd: std.posix.fd_t`
- [ ] Implement `create(cfg, state)`:
  - Iterate `[output.mapping]` entries
  - Resolve event codes via `resolveEventCode`
  - Register EV_ABS/EV_KEY capabilities via existing `ioctlInt`
  - UI_DEV_SETUP with name/vid/pid from `[output]`
  - UI_ABS_SETUP for each ABS slot using range/fuzz/flat/res from MappingEntry
  - UI_DEV_CREATE
- [ ] Implement `emitGeneric(state)`:
  - Differential emit: compare `values[i]` vs `prev_values[i]`
  - Build `input_event` array, append SYN_REPORT, write
  - Copy values to prev_values
- [ ] Implement `close()`: UI_DEV_DESTROY + close fd

### T22b: Integration with supervisor

- [ ] In the code path where `UinputDevice.create` is called (supervisor or main),
  check `config.device.mode`:
  - If `"generic"`: create `GenericDeviceState`, compile slots, create `GenericUinputDevice`
  - If null or `"gamepad"`: existing path

---

## T23: Example Device TOML

### T23a: Create devices/example/generic-wheel.toml

- [ ] Create `devices/example/generic-wheel.toml` with:
  - `mode = "generic"`
  - At least 4 axis fields (wheel_angle, gas, brake, clutch)
  - At least 4 button fields via button_group
  - `[output.mapping]` with ABS_WHEEL, ABS_GAS, ABS_BRAKE, ABS_RZ, BTN_GEAR_UP,
    BTN_GEAR_DOWN, BTN_0, BTN_1

### T23b: Verify auto-test discovery

- [ ] Confirm `auto_device_test.zig` (from Wave 3) discovers and parses this file
- [ ] Confirm generic-mode validation passes for this file

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/phase-10.md` T19-T23 status checkboxes
