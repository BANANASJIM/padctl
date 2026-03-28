# Lean Formal Model — Scope and Exclusions

## What is modeled

- **Interpreter**: byte-level field reading, bit extraction, sign extension, checksum
  verification (sum8/xor/crc32 with optional seed), report matching, hat decode, button
  group decode
- **Transform**: negate (with minInt guard), abs, scale (tdiv semantics), clamp, deadzone
- **State**: GamepadState, delta application, diff round-trip, dpad axis synthesis
- **Mapper**: layer FSM (tap-hold + toggle), button remap (gamepad/key/mouse/disabled/macro),
  dpad modes (gamepad/arrows) with button-bit suppression, button assembly invariant,
  full apply pipeline with suppress/inject/prev-frame masking, tap event emission,
  gyro activation boolean, stick suppress flag, macro trigger-on-rising-edge and
  cancel-on-layer-change
- **Properties**: 25 proven theorems covering transforms, state, interpreter, and mapper

## What is excluded and why

### Gyro float math
The actual gyro processing involves EMA smoothing, sensitivity curves, and REL_X/REL_Y
computation — all floating-point intensive. The Lean model captures only the boolean
activation gate (`checkGyroActivate`) and the reset flag (`gyroReset` on layer change).
**Reason**: Lean 4 has no efficient native float; modeling IEEE 754 semantics would add
complexity with no practical verification benefit. The activation logic is the part with
correctness-critical branching.

### Stick float math
Mouse/scroll mode stick processing involves sensitivity, acceleration curves, and
sub-pixel accumulation. The model captures only the suppress flag
(`checkStickSuppressGamepad`) which determines whether gamepad axes are zeroed.
**Reason**: Same as gyro — float-heavy path with trivial control flow.

### Macro player FSM internals (partial)
The model includes the full step dispatch (stepMacro with tap/down/up/delay/pauseForRelease),
timer expiration, trigger release notification, and cancel-with-pending-releases.
**Excluded**: timing accuracy (real-time deadlines) and the looping continuation behavior
(Zig loops synchronous steps; Lean steps once).
**Reason**: The correctness-critical invariants (step ordering, cancel releases all held keys)
are fully modeled. Real-time deadlines and loop iteration are OS/runtime concerns.

### Output device (uinput) creation
All uinput fd management, capability registration, and SYN_REPORT framing.
**Reason**: OS syscall layer, not algorithmic.

### USB/hidraw I/O
Device enumeration, poll loop, report reading.
**Reason**: OS I/O layer.

### TOML parsing
Config file parsing and validation.
**Reason**: Uses standard library parser, not custom logic.
