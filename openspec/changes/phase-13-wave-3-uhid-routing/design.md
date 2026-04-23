# Design: Phase 13 Wave 3 — supervisor → UhidDevice routing (T1-T5)

## Files

| File | Role |
|------|------|
| `src/config/device.zig` | T1: `ImuConfig` struct, `OutputConfig.imu` field, validate rule, validate tests |
| `src/io/uinput.zig` | T2: `UinputDevice.initBoxed` heap-alloc wrapper |
| `src/device_instance.zig` | T3: owner union + `primary_output` / `imu_output`; T4: routing switch at construction; T5: IMU emit call site |
| `src/supervisor.zig` | T3/T4: align second `DeviceInstance` construction (~line 2079) with new layout |
| `src/io/uniq.zig` (new) | T4: `buildUniq` pure function + Layer 0 unit test block |
| `src/io/uhid_descriptor.zig` | T5: `UhidDescriptorBuilder.buildForImu` + IMU golden-file test |
| `src/event_loop.zig` | T5: IMU emit dispatch (call `imu_output.emit` from the gamepad-state update path) |
| `src/test/supervisor_uhid_routing_test.zig` (new) | T5: Layer 1 `UhidSimulator` routing assertion |
| `src/test/uhid_uniq_pairing_test.zig` | T5: extend to exercise real `DeviceInstance`, not hand-built `UHID_CREATE2` |
| `build.zig` | Register new `uniq.zig` and `supervisor_uhid_routing_test.zig` in the test step |

---

## Hard Constraints (from ADR-015 Stage 1, non-negotiable)

Source: `decisions/015-uhid-imu-migration.md@92caade`:20-28, §Alternatives.

1. **Shared uniq string** — primary and IMU UHID devices MUST write byte-identical
   `uhid_create2_req.uniq`. Format: `"padctl/<device-id>-<instance>"`.
2. **No "uinput primary + UHID IMU"** — when IMU backend is `"uhid"`, primary pad
   MUST also be `"uhid"`. The Alternatives table explicitly rejects the split
   because uinput's `EVIOCGUNIQ` is always `-ENOENT`, so SDL `strcmp` would fail
   on the primary side even if the IMU side carried a uniq.
3. **No `EV_KEY` in IMU descriptor** — SDL `GuessDeviceClass()` treats any device
   advertising `EV_KEY` as a gamepad, not a sensor. IMU descriptor carries only
   `INPUT_PROP_ACCELEROMETER` + abs axes.
4. **Default `backend = "uinput"`** — existing `devices/*.toml` with no `[output.imu]`
   section see zero behaviour change.
5. **Layer 0+1 tests run zero-privilege** in `zig build test`. Layer 2 is a soft
   gate via `PADCTL_TEST_REQUIRE_UHID=1`.

Violating any of these at implementation time fails the spec.

---

## Behavioural Parity Contract

When `[output.imu]` is absent (old TOML) OR `[output.imu].backend = "uinput"`:
the post-Wave-3 codepath MUST be byte-equivalent to pre-Wave-3 in
**every** observable dimension:

- `UinputDevice.create` still runs with the same `OutputConfig`
- emit ordering, FF poll interface, vtable close semantics unchanged
- `supervisor.Supervisor.spawnInstance` lifetime, `devname_map` entries,
  phys_key flow all identical
- `zig build test` suite passes with no diff in test output

The only code difference on the uinput path is that the struct is now
heap-allocated (`UinputDevice.initBoxed`) and stored in `owner: .uinput = ptr`
instead of inline `uinput_dev: ?UinputDevice`. This is a lifetime-ownership
refactor, not a behavioural change; T3 exists specifically to land this
refactor with CI green *before* T4 introduces the backend switch.

Regression sentinel: `full_pipeline_e2e_test.zig`, `supervisor_uhid_grace_integration_test.zig`,
and every Layer 0 TOML golden test must pass unchanged at the end of T3.

---

## T1: `ImuConfig` + `OutputConfig.imu` + validate

### Problem

`src/config/device.zig:141-153` `OutputConfig` has no knob for IMU backend
selection. The current TOML grammar cannot express "spawn a second SDL-visible
sensor device" — `[output.aux]` exists only for keyboard/mouse-style companion
devices that do not need uniq pairing.

### Solution

Add a nested TOML section mapped to a new `ImuConfig` struct, and extend
`validate` to reject the one illegal combination.

```zig
pub const ImuConfig = struct {
    backend: []const u8 = "uinput",       // "uinput" (default) | "uhid"
    name: ?[]const u8 = null,             // override for IMU uhid name; fallback "<device.name> IMU"
    vid: ?i64 = null,                     // optional override; defaults to primary vid
    pid: ?i64 = null,                     // optional override; defaults to primary pid
    // Wave-5 placeholders, not used in Wave 3:
    accel_range: ?[2]i64 = null,
    gyro_range: ?[2]i64 = null,
};

pub const OutputConfig = struct {
    // ...existing fields...
    imu: ?ImuConfig = null,               // T1 new field
};
```

### Validate rule (extended case table)

Applied inside `pub fn validate(cfg: *const DeviceConfig) !void` at
`src/config/device.zig:221`, using the existing `error.InvalidConfig` convention
(no new error variant introduced):

| `[output.imu]` | `backend` | Behaviour |
|----------------|-----------|-----------|
| absent | (n/a) | Legal. Pre-Wave-3 path. Primary pad uses `UinputDevice`. |
| present | `"uinput"` | **`error.InvalidConfig`** (ADR-015 §Alternatives rejects this combination). |
| present | `"uhid"` | Legal. Primary + IMU both instantiate as `UhidDevice`. |
| present | other string | `error.InvalidConfig` (unknown backend; fail closed). |

### Error surface

- No new variant. Reuses `error.InvalidConfig` from the existing error set at
  `device.zig:232,241-294`. Aligns with ADR-015 T9 discipline (no `anyerror`
  introduced in hot path).

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/config/device.zig:141-153` | `OutputConfig` has no `imu` field | adds `imu: ?ImuConfig = null` |
| `src/config/device.zig` (near existing structs) | no `ImuConfig` | adds `pub const ImuConfig = struct { ... }` |
| `src/config/device.zig:221-...` | `validate` does not inspect `output.imu` | adds rule table above |
| `src/config/device.zig` test block | no IMU validate tests | adds 4 round-trip + validate cases |

---

## T2: `UinputDevice.initBoxed` heap-alloc wrapper

### Problem

`UinputDevice` is a value type. `UinputDevice.create` returns
`UinputDevice` by value (`src/io/uinput.zig:137`). `UhidDevice.init` returns
`*UhidDevice` (heap-allocated via `allocator.create`, `src/io/uhid.zig:232`).
A single owner union over pointers cannot hold both shapes uniformly.

### Solution

Add a thin wrapper:

```zig
pub fn initBoxed(allocator: std.mem.Allocator, cfg: *const device.OutputConfig) !*UinputDevice {
    const p = try allocator.create(UinputDevice);
    errdefer allocator.destroy(p);
    p.* = try UinputDevice.create(cfg);
    return p;
}
```

`close()` remains instance-scoped; callers responsible for `allocator.destroy(p)`
after `p.close()`. This matches the exact ownership protocol already in
`UhidDevice` per its `init` doc comment at `src/io/uhid.zig:227-231`:
> *"caller owns the returned `*UhidDevice`. `close()` tears the kernel device
> down but does not free the struct — callers hold it in an arena or free it
> via `allocator.destroy(dev)` explicitly."*

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/uinput.zig` (near `pub fn create`) | value-only ctor | adds `pub fn initBoxed` |

### Error surface

Reuses the error set of `UinputDevice.create` plus `error.OutOfMemory` from
`allocator.create`. Both already part of the caller's existing error set.

---

## T3: `DeviceInstance` owner union + `primary_output` / `imu_output`

### Problem

`src/device_instance.zig:82` has `uinput_dev: ?UinputDevice` — a value-type
field hardwired to uinput. Four call sites reference this field directly (see
table below). No clean seam exists for a second backend.

### Solution

Replace `uinput_dev` with an owner union + two `OutputDevice` vtable handles:

```zig
const Owner = union(enum) {
    none,
    uinput: *UinputDevice,   // heap-allocated via UinputDevice.initBoxed
    uhid:   *UhidDevice,     // heap-allocated via UhidDevice.init (existing)
};

pub const DeviceInstance = struct {
    // ...existing fields unchanged: allocator, devices, loop, interp, mapper, aux_dev, ...
    owner: Owner = .none,
    primary_output: ?uinput.OutputDevice = null,  // always == owner-side vtable when owner != .none
    imu_output:     ?uinput.OutputDevice = null,  // T4 populates when backend == "uhid" + ImuConfig present
    // uinput_dev: ?UinputDevice  REMOVED
    // (rebuild_aux_calls, pending_mapping etc unchanged)
};
```

Invariant: `primary_output` is `null` iff `owner == .none`. Wave 3 never
constructs `primary_output` without a matching `owner` slot. T4 fills the
switch; T3 only rewires existing call sites.

### Files affected — call-site migration table

| File:Line | Before | After |
|-----------|--------|-------|
| `src/device_instance.zig:82` | `uinput_dev: ?UinputDevice` | `owner: Owner = .none`, `primary_output: ?OutputDevice = null`, `imu_output: ?OutputDevice = null` |
| `src/device_instance.zig:136-148` | `var uinput_dev: ?UinputDevice = null; ... uinput_dev = try UinputDevice.create(out_cfg);` | T3: wrap with `UinputDevice.initBoxed` + assign to `owner = .{ .uinput = ptr }`. T4: branch on `out_cfg.imu.?.backend`. |
| `src/device_instance.zig:149` | `uinput_dev.?.log_tag = cfg.device.name;` | `owner.uinput.log_tag = cfg.device.name;` |
| `src/device_instance.zig:151-152` | `errdefer uinput_dev.?.close(); try loop.addUinputFf(uinput_dev.?.pollFfFd());` | `errdefer owner.uinput.close(); try loop.addUinputFf(owner.uinput.pollFfFd());` |
| `src/device_instance.zig:213` | `.uinput_dev = uinput_dev,` | `.owner = owner, .primary_output = primary_out, .imu_output = imu_out,` |
| `src/device_instance.zig:226` | `if (self.uinput_dev) |*u| u.close();` | `switch (self.owner) { .none => {}, .uinput => \|p\| { p.close(); self.allocator.destroy(p); }, .uhid => \|p\| { p.close(); self.allocator.destroy(p); } }` |
| `src/device_instance.zig:255` | `const output = if (self.uinput_dev) \|*u\| u.outputDevice() else nullOutput();` | `const output = self.primary_output orelse nullOutput();` |
| `src/device_instance.zig:422,506,573,651,653` (test fixtures, `.uinput_dev = null`) | initialize stub | `.owner = .none, .primary_output = null, .imu_output = null,` |
| `src/supervisor.zig:2079` | `.uinput_dev = null,` | `.owner = .none, .primary_output = null, .imu_output = null,` |

### Behaviour contract for T3

After T3 merges, **with no T4 routing change yet applied**, every existing test
must pass unchanged. `backend` defaults still produce a heap-allocated
`UinputDevice` via `initBoxed`, `primary_output` is set to
`owner.uinput.outputDevice()`, and emit/close semantics are unchanged modulo
pointer indirection.

### Error surface

`initBoxed` returns `error.OutOfMemory` on top of `UinputDevice.create`'s
existing set; caller (`DeviceInstance.init`) already returns `!DeviceInstance`,
so the error set widens by exactly one variant.

---

## T4: `buildUniq` pure function + supervisor routing switch

### Problem

No pure, testable uniq-builder exists. Wave 4's `uhid_uniq_pairing_test.zig`
hand-constructs `UHID_CREATE2` payloads; this does not prove that a real
`DeviceInstance` would produce byte-identical uniq strings on both cards.

Additionally, `DeviceInstance.init` still constructs `UinputDevice` unconditionally;
the `[output.imu].backend` field from T1 is ignored.

### Solution

#### 4a. New `src/io/uniq.zig`

```zig
const std = @import("std");

pub const MAX_UNIQ_LEN = 64;  // matches ADR-015 AC4 expected maxima

/// Build the shared uniq string for a padctl UHID device.
///
/// Layout: `"padctl/<device-id>-<instance>"`, NUL-terminated, at most 64 bytes
/// including terminator (`UHID_CREATE2_UNIQ` is a fixed 64-byte buffer).
///
/// - `device_name`: `cfg.device.name`. Normalized: lowercase, spaces + non-alphanum
///   → `-`, collapse consecutive `-`, trim `-`, truncate to 32 bytes.
/// - `phys_key`: `readPhysFromSysfs` output for the physical device; when non-null,
///   instance = FNV-16 hash as 4-digit lowercase hex.
/// - `counter`: used only when `phys_key` is null (virtual devices, bluetooth
///   without sysfs path). Monotonic within daemon lifetime, starts at 1.
///
/// Returns a NUL-terminated slice owned by the caller; pass to
/// `std.mem.sliceTo(ptr, 0)` before use as a Zig slice.
pub fn buildUniq(
    allocator: std.mem.Allocator,
    device_name: []const u8,
    phys_key: ?[]const u8,
    counter: u16,
) std.mem.Allocator.Error![:0]u8 {
    // 1. normalize device_name → device_id (lowercase, non-alphanum→'-', collapse, trim, clip 32)
    // 2. instance = if (phys_key) |p| fnv16hex(p) else fmt("ctr{:04x}", counter)
    // 3. render "padctl/{device_id}-{instance}" into allocator-owned buffer with NUL terminator
    // 4. assert buf.len < MAX_UNIQ_LEN
}

fn fnv16(bytes: []const u8) u16 { /* FNV-1a 16-bit */ }
```

Layer 0 tests in the same file:

| Test | Input | Expected output |
|------|-------|-----------------|
| `buildUniq: phys_key present` | `"Flydigi Vader 3 Pro"`, `"usb-0000:00:14.0-3/input0"`, `0` | `"padctl/flydigi-vader-3-pro-<4hex>"` |
| `buildUniq: phys_key null, counter=1` | `"DualSense"`, `null`, `1` | `"padctl/dualsense-ctr0001"` |
| `buildUniq: idempotent for same phys_key` | two calls same inputs | byte-identical output |
| `buildUniq: length bound` | any inputs | result (incl NUL) ≤ 64 bytes |
| `buildUniq: ASCII clamp` | `"Pad with 中文"` | `"padctl/pad-with-..."` (non-ASCII → `-`) |

#### 4b. Supervisor/DeviceInstance routing switch

At `src/device_instance.zig:136-148`, replace the unconditional
`UinputDevice.initBoxed` with:

```zig
const imu_cfg_opt: ?device.ImuConfig = if (out_cfg.imu) |imu| imu else null;
const use_uhid = blk: {
    const imu_cfg = imu_cfg_opt orelse break :blk false;
    if (std.mem.eql(u8, imu_cfg.backend, "uhid")) break :blk true;
    break :blk false;  // "uinput" or other (T1 validate blocks "other")
};

var owner: Owner = .none;
var primary_out: ?uinput.OutputDevice = null;
var imu_out: ?uinput.OutputDevice = null;

if (use_uhid) {
    const uniq = try uniq_mod.buildUniq(allocator, cfg.device.name, phys_key_opt, daemon_counter);
    defer allocator.free(uniq);

    // Primary pad UHID card
    const primary_descriptor = try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg);
    defer allocator.free(primary_descriptor);
    const primary_uhid = try uhid.UhidDevice.init(allocator, .{
        .name = cfg.device.name,
        .uniq = uniq,
        .vid = @intCast(cfg.device.vid),
        .pid = @intCast(cfg.device.pid),
        .descriptor = primary_descriptor,
        .output = out_cfg.*,
    });
    errdefer { primary_uhid.close(); allocator.destroy(primary_uhid); }
    owner = .{ .uhid = primary_uhid };
    primary_out = primary_uhid.outputDevice();

    // IMU companion UHID card (T5 builds the descriptor via buildForImu)
    if (imu_cfg_opt) |imu_cfg| {
        const imu_descriptor = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg);
        defer allocator.free(imu_descriptor);
        const imu_name = imu_cfg.name orelse try std.fmt.allocPrint(allocator, "{s} IMU", .{cfg.device.name});
        const imu_uhid = try uhid.UhidDevice.init(allocator, .{
            .name = imu_name,
            .uniq = uniq,                  // SAME string — ADR-015 hard constraint
            .vid = @intCast(imu_cfg.vid orelse cfg.device.vid),
            .pid = @intCast(imu_cfg.pid orelse cfg.device.pid),
            .descriptor = imu_descriptor,
            .output = null,                // IMU descriptor is built separately, not from OutputConfig
        });
        // NOTE: T3 owner union holds ONE primary; IMU's *UhidDevice lifetime is
        // managed by a second field `imu_dev: ?*UhidDevice` added here.
        imu_out = imu_uhid.outputDevice();
    }
} else {
    const p = try uinput.UinputDevice.initBoxed(allocator, out_cfg);
    errdefer { p.close(); allocator.destroy(p); }
    owner = .{ .uinput = p };
    primary_out = p.outputDevice();
    // imu_out stays null — uinput backend has no IMU card.
}
```

#### 4c. `DeviceInstance` gains `imu_dev: ?*UhidDevice`

T4 adds a second pointer field (the owner union covers only the primary).
Rationale: the owner union models "one primary output per instance" and should
not grow to accommodate the companion IMU card. Teardown:

```zig
pub fn deinit(self: *DeviceInstance) void {
    // ... existing aux/touchpad teardown ...
    if (self.imu_dev) |p| { p.close(); self.allocator.destroy(p); }
    switch (self.owner) {
        .none => {},
        .uinput => |p| { p.close(); self.allocator.destroy(p); },
        .uhid   => |p| { p.close(); self.allocator.destroy(p); },
    }
}
```

#### 4d. `phys_key` wiring

`phys_key` is already owned by `Supervisor.ManagedInstance` at
`src/supervisor.zig:30,46` and passed to `spawnInstance`. T4 extends
`DeviceInstance.init` to accept an optional `phys_key: ?[]const u8` parameter
(callers in `supervisor.zig` have it; `main.zig` / test callers may pass null).

Fallback counter: new `Supervisor` field `daemon_uniq_counter: u16 = 1`,
incremented each time `DeviceInstance.init` consumes a null `phys_key`.

### Uniq format — honest footnote

The engineering plan (line 55) writes the format as
`"padctl/<device-id>-<instance>"`. There is no pre-existing "device-instance-id"
scheme in the codebase to match against: the existing `devname_map` is a
`devname → phys_key` map (`src/supervisor.zig:159`), not a device-id map.

Wave 3 therefore defines the convention fresh from the engineering plan:

- `device-id` = normalized `cfg.device.name` (lowercase, non-alphanum → `-`,
  collapsed, trimmed, truncated to 32 bytes)
- `instance` = FNV-16(phys_key) rendered as 4-digit hex, or `ctr{:04x}`
  fallback

This is internally consistent with the plan and with ADR-015 §20 (uniq must be
byte-identical between the two cards), but is NOT cross-validated against any
existing id scheme because none exists. If Wave 5 canary testing reveals that
Steam's per-device mapping storage is sensitive to uniq stability across
daemon restarts, a future ADR may pin `instance` to a sysfs-stable value
(current `phys_key` already provides this).

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/uniq.zig` (new) | — | `buildUniq` + `fnv16` + 5 Layer 0 tests |
| `src/device_instance.zig:136-148` | unconditional `UinputDevice.create` | backend switch (above) |
| `src/device_instance.zig` (fields) | no `imu_dev` | adds `imu_dev: ?*UhidDevice = null` |
| `src/device_instance.zig` (deinit) | — | teardown imu_dev before primary owner |
| `src/device_instance.zig` (init signature) | `init(alloc, cfg, init_mapping)` | `init(alloc, cfg, init_mapping, phys_key: ?[]const u8)` (callers updated) |
| `src/supervisor.zig` | — | adds `daemon_uniq_counter: u16 = 1`; threads through `spawnInstance`/`attachWithInstance` |
| `build.zig` | — | register `src/io/uniq.zig` in test step |

### Error surface

New errors: `error.OutOfMemory` (already ubiquitous), `error.UhidCreateFailed`
(already in `UhidDevice.InitError`), `error.DescriptorTooLarge` (already in
`UhidDevice.InitError`). **No `anyerror` introduced.** `DeviceInstance.init`
already returns `!DeviceInstance`; the error set widens only with variants
the caller transitively already handles.

---

## T5: IMU descriptor builder + emit dispatch + tests

### Problem

The `UhidDescriptorBuilder` (`src/io/uhid_descriptor.zig`) has only
`buildFromOutput` (Wave 2). No IMU descriptor exists; no emit path carries IMU
state through the `OutputDevice` vtable; `supervisor_uhid_routing_test.zig` and
the expanded `uhid_uniq_pairing_test.zig` have no fixture to exercise.

### Solution

#### 5a. `UhidDescriptorBuilder.buildForImu`

New public function:

```zig
pub fn buildForImu(
    allocator: std.mem.Allocator,
    imu_cfg: device.ImuConfig,
) BuildError![]u8;
```

HID report descriptor bytes emitted:

| Block | Usage | Logical range | Report size |
|-------|-------|---------------|-------------|
| Usage Page Sensor (0x20) | — | — | — |
| `INPUT_PROP_ACCELEROMETER` | — | — | — |
| Usage Motion Accelerator X/Y/Z (0x0473/0x0474/0x0475) | `ABS_X/Y/Z` | `imu_cfg.accel_range` or `{-32768, 32767}` | 2 bytes × 3 |
| Usage Motion Gyrometer X/Y/Z (0x0476/0x0477/0x0478) | `ABS_RX/RY/RZ` | `imu_cfg.gyro_range` or `{-32768, 32767}` | 2 bytes × 3 |
| **No `EV_KEY`**, **no `EV_ABS` stick axes** | — | — | — |

Byte-exact golden-file test added in the `src/io/uhid_descriptor.zig` test
block, matching the style of Wave 2's `buildFromOutput` tests. The golden
reference is committed alongside the test (inline byte array, not external
file) so the test remains hermetic.

#### 5b. Event-loop IMU emit dispatch

The engineering plan identifies `src/event_loop.zig` as the emit site. Current
structure: `EventLoop.run` calls into the interpreter, which produces a
`GamepadState`, which is emitted by a single `OutputDevice.emit(state)`. Wave 3
adds a parallel call for IMU fields only:

```zig
// inside the per-frame dispatch (where primary_output.emit(state) is already called):
if (ctx.imu_output) |imu_dev| {
    // IMU emit takes the same GamepadState; UhidDevice's encoder for the IMU
    // descriptor ignores non-IMU fields and reads accel_x/y/z + gyro_x/y/z only.
    try imu_dev.emit(state);
}
```

`imu_output` is plumbed into `EventLoopContext` (existing struct) as a new
optional field. When null (uinput backend), the conditional is dead-code
eliminated.

**No new IMU state struct.** `GamepadState` already carries `accel_x/y/z` and
`gyro_x/y/z` (see `src/core/state.zig`). `UhidDevice.encodeReport` (PR #140,
descriptor-driven) reads whichever fields its bound descriptor references —
the IMU descriptor references only the 6 IMU axes, so passing the full
`GamepadState` is a no-op for non-IMU fields.

#### 5c. Layer 1 `src/test/supervisor_uhid_routing_test.zig` (new)

Fixture: in-process `UhidSimulator` (already exists per Wave 1) intercepts
`/dev/uhid` writes. Test flow:

1. Build a minimal `DeviceConfig` with `[output.imu].backend = "uhid"`.
2. Call `DeviceInstance.init(allocator, &cfg, null, phys_key_fixture)`.
3. Assert simulator observed exactly 2 `UHID_CREATE2` events.
4. Assert both events carry byte-identical `uniq` (`std.mem.eql`).
5. Assert uniq starts with `"padctl/"` + normalized device name.
6. Assert primary descriptor contains `EV_KEY` bits; IMU descriptor does not.

Second test in same file: `backend = "uinput"` → zero `UHID_CREATE2` events
(regression guard).

Third test: `backend = "uinput"` + `[output.imu]` present → `DeviceInstance.init`
returns `error.InvalidConfig` (T1 validate path sanity check).

#### 5d. Extend Layer 2 `src/test/uhid_uniq_pairing_test.zig`

Current state (PR #140, extended by PR #154/#155): test hand-constructs
`UHID_CREATE2` payloads, opens two `/dev/uhid` nodes, reads `EVIOCGUNIQ` from
both, asserts equality. `PADCTL_TEST_REQUIRE_UHID=1` promotes skip to hard
fail.

Wave 3 addition: new test case in the same file:

```
test "routing: real DeviceInstance produces paired uniq (requires /dev/uhid)" { ... }
```

- Construct the same minimal `DeviceConfig` as 5c's Layer 1 test.
- Call `DeviceInstance.init` — this goes through the actual routing switch.
- Locate the two evdev nodes kernel created under `/dev/input/eventN` (poll
  sysfs for devices matching the created vid/pid + `padctl/` uniq prefix).
- `ioctl(EVIOCGUNIQ)` on both. `std.mem.eql`. Assert.
- Re-uses the `PADCTL_TEST_REQUIRE_UHID=1` gate helper introduced at line 41.

This closes ADR-015 Stage 1 AC4 against the real routing code, not against
synthetic test payloads.

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/uhid_descriptor.zig:167+` | only `buildFromOutput` | adds `buildForImu` + golden-file test |
| `src/event_loop.zig` | emits primary only | adds conditional `imu_output.emit(state)` |
| `src/test/supervisor_uhid_routing_test.zig` (new) | — | 3 Layer 1 tests |
| `src/test/uhid_uniq_pairing_test.zig` | Layer 2 hand-built payloads only | adds one real-`DeviceInstance` case |
| `build.zig` | — | register `supervisor_uhid_routing_test.zig` in test step |

### Error surface

`buildForImu` returns `BuildError` (existing set from `buildFromOutput`). No
new variants.

---

## Cross-cutting: uniq format

Resolved here once, referenced from T4/T5:

```
"padctl/<device-id>-<instance>"
where:
  device-id = normalize(cfg.device.name):
              lowercase,
              non-alphanum → '-',
              collapse consecutive '-',
              trim leading/trailing '-',
              truncate to 32 bytes.
  instance  = if phys_key:  lowercase-hex FNV-16(phys_key), 4 digits
              else:         "ctr" + lowercase-hex(daemon_counter, 4 digits)
  total     ≤ 63 bytes + NUL terminator (fits UHID_CREATE2_UNIQ 64-byte field)
```

Examples:

- `cfg.device.name = "Flydigi Vader 3 Pro"`, `phys_key = "usb-0000:00:14.0-3/input0"` →
  FNV-16 = `0xA7C2` → uniq = `"padctl/flydigi-vader-3-pro-a7c2"`
- `cfg.device.name = "DualSense"`, `phys_key = null`, `counter = 1` →
  uniq = `"padctl/dualsense-ctr0001"`

Both primary and IMU cards receive the **same string literal** — built once,
passed to both `UhidDevice.init` calls. See T4 section 4b above.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | `ImuConfig.backend` is a string, not an enum | TOML parser produces `[]const u8`; string-matching in `validate` keeps schema open for Wave 6+ (e.g. `"uhid+pid"`) without churn. Unknown backend values fail in validate. |
| D2 | `UinputDevice.initBoxed` wraps `create`, does not replace it | Keeps `create` as the single construction path; `initBoxed` is purely a lifetime adapter. Less diff, easier review, zero behaviour change to existing callers of `create`. |
| D3 | `imu_dev: ?*UhidDevice` as a second field, NOT a variant in `Owner` union | `Owner` models "one primary output per instance". Stretching it to 4 cases (none/uinput/uhid/uhid+imu) muddies the invariant. A plain optional is clearer for a paired companion device. |
| D4 | `buildUniq` in a new `src/io/uniq.zig`, not inline in `uhid.zig` | P9 (All Modules Independently Testable). Pure function, zero dependency on `std.posix`, runs Layer 0 with zero privileges. Matches the file-per-pure-concern pattern already seen in `src/io/uhid_descriptor.zig`. |
| D5 | FNV-16 hash over `phys_key`, not full sysfs path | `phys_key` already captures device identity via `readPhysFromSysfs`. FNV-16 fits the 64-byte uniq budget with room to spare. 16-bit collision probability within a single daemon instance is negligible (< 2^-16 per boot). |
| D6 | Counter fallback when `phys_key` is null | Virtual / Bluetooth devices may return null phys. A monotonic counter preserves within-boot uniqueness. Counter is not stable across daemon restarts, but Wave 3 only requires intra-boot pairing (ADR-015 AC4). |
| D7 | IMU descriptor carries only sensor axes, no `EV_KEY`, no sticks | ADR-015 §Alternatives hard constraint — SDL `GuessDeviceClass` checks `EV_KEY` bit to disambiguate gamepad vs sensor. |
| D8 | Reuse `GamepadState` for IMU emit, no separate `ImuState` | `GamepadState` already holds accel/gyro fields. `UhidDevice.encodeReport` is descriptor-driven (PR #140) and ignores fields not referenced by its bound descriptor. Adding a parallel state type would duplicate dirty-axis tracking. |
| D9 | `[output.imu]` present + `backend = "uinput"` → `error.InvalidConfig` | ADR-015 §Alternatives explicitly rejects this combination. Fail-loud at config parse is strictly better than silent fallback. |
| D10 | Default behaviour unchanged when `[output.imu]` absent | Zero-regression path for every existing `devices/*.toml`. T3 refactor plus T4 branch default together preserve behaviour bit-exactly. |
