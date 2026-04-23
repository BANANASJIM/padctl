# Tasks: Phase 13 Wave 3 — supervisor → UhidDevice routing (T1-T5)

Branch: `feat/phase-13-wave-3-uhid-routing`
Commit: (leave blank -- filled after implementation)

## Execution Plan

Dependency DAG:

```
T1 ──┐
     ├──> T4 ──> T5
T2 ──> T3 ──┘
```

- **T1** and **T2** have no predecessors — can start in parallel.
- **T3** depends on T2 (needs `UinputDevice.initBoxed`).
- **T4** depends on T1 + T3 (needs `ImuConfig` + owner union).
- **T5** depends on T4 (needs routing switch producing paired UHID cards).

Recommended order: **T1 + T2 parallel → T3 → T4 → T5**. One PR, 5 commits
(matches Wave 1 PR #127 / Wave 2 PR #132 rhythm).

## LoC Budget

| Task | LoC (code + test) |
|------|-------------------|
| T1 | ~60 |
| T2 | ~30 |
| T3 | ~120 |
| T4 | ~150 |
| T5 | ~200 |
| **Total** | **~560** |

## Behaviour Contracts (must hold per task)

- After **T3** merges (without T4 applied): `zig build test` passes with zero
  diff to pre-Wave-3 test output. The refactor is lifetime-only.
- After **T4** merges (without T5 IMU descriptor yet): `backend = "uhid"`
  path builds a primary `UhidDevice`; IMU card construction is skipped until
  `buildForImu` lands in T5. Test covers primary-only path.
- After **T5** merges: `supervisor_uhid_routing_test.zig` (Layer 1) green;
  `PADCTL_TEST_REQUIRE_UHID=1 zig build test` (Layer 2) green on a host with
  `/dev/uhid`.

---

## T1: `ImuConfig` struct + `OutputConfig.imu` field + validate rule

Files: `src/config/device.zig`

### T1a: Add `ImuConfig` struct

- [ ] In `src/config/device.zig`, near existing `FfConfig` / `AuxConfig`
  declarations, add `pub const ImuConfig = struct { backend: []const u8 = "uinput", name: ?[]const u8 = null, vid: ?i64 = null, pid: ?i64 = null, accel_range: ?[2]i64 = null, gyro_range: ?[2]i64 = null };`
- [ ] Verify no compilation error — field defaults + types must parse under
  existing `zig-toml` bindings.

### T1b: Add `imu` field to `OutputConfig`

- [ ] In `src/config/device.zig:141-153` `OutputConfig`, add
  `imu: ?ImuConfig = null,` as the last field.
- [ ] `zig build` passes.

### T1c: Extend `validate` with IMU backend rules

- [ ] In `src/config/device.zig:221` `pub fn validate`, at the end of the
  per-report loop, add a top-level `if (cfg.output) |out|` block:
  - If `out.imu` is `null`: legal, return early.
  - If `out.imu.?.backend == "uhid"`: legal.
  - If `out.imu.?.backend == "uinput"`: return `error.InvalidConfig`
    (ADR-015 forbids "uinput primary + IMU present").
  - Else (unknown backend string): return `error.InvalidConfig`.
- [ ] No new error variant needed — reuse `error.InvalidConfig`.

### T1d: Validate tests

- [ ] In `src/config/device.zig` test block, add 4 cases:
  - **`test "validate: ImuConfig default (absent) is legal"`** — pre-Wave-3 fixture round-trips.
  - **`test "validate: backend=uhid + [output.imu] present is legal"`** — succeeds.
  - **`test "validate: backend=uinput + [output.imu] present is error.InvalidConfig"`** — asserts the error.
  - **`test "validate: backend=unknown is error.InvalidConfig"`** — asserts fail-closed.
- [ ] `zig build test` passes all 4.

### T1e: TOML round-trip parser test

- [ ] Round-trip test: parse a TOML fragment with
  `[output.imu]\nbackend = "uhid"\nname = "Pad IMU"\n`, verify
  `cfg.output.?.imu.?.backend == "uhid"` and `cfg.output.?.imu.?.name.? == "Pad IMU"`.

---

## T2: `UinputDevice.initBoxed` heap-alloc wrapper

Files: `src/io/uinput.zig`

### T2a: Add `initBoxed` function

- [ ] In `src/io/uinput.zig` near `pub fn create` (around line 137), add:
  ```zig
  pub fn initBoxed(allocator: std.mem.Allocator, cfg: *const device.OutputConfig) !*UinputDevice {
      const p = try allocator.create(UinputDevice);
      errdefer allocator.destroy(p);
      p.* = try UinputDevice.create(cfg);
      return p;
  }
  ```
- [ ] Verify compile: `zig build` green.

### T2b: Layer 0 test for `initBoxed`

- [ ] In the existing `UinputDevice` test block (mocked allocator), add
  **`test "initBoxed: heap-allocates and returns owning pointer"`**:
  - Use `std.testing.allocator`.
  - Call `initBoxed` with a mock `OutputConfig` (reuse existing mock fixtures).
  - Assert returned pointer is non-null.
  - `defer p.close()` + `defer allocator.destroy(p)`.
  - Verify no leaks (testing allocator's leak check).
- [ ] `zig build test` passes.

---

## T3: `DeviceInstance` owner union + `primary_output` / `imu_output` refactor

Files: `src/device_instance.zig`, `src/supervisor.zig`

### T3a: Define `Owner` union inside `DeviceInstance`

- [ ] In `src/device_instance.zig` near line 76 (before `pub const DeviceInstance`),
  add:
  ```zig
  const Owner = union(enum) {
      none,
      uinput: *UinputDevice,
      uhid:   *uhid_mod.UhidDevice,
  };
  ```
  (import `uhid_mod = @import("io/uhid.zig");` at the top of the file.)

### T3b: Replace `uinput_dev` field with `owner` + two outputs

- [ ] In `src/device_instance.zig:82`, delete `uinput_dev: ?UinputDevice,`.
- [ ] Add `owner: Owner = .none,`
- [ ] Add `primary_output: ?uinput.OutputDevice = null,`
- [ ] Add `imu_output: ?uinput.OutputDevice = null,` (populated in T4; T3 leaves null)
- [ ] `zig build` will fail until T3c-T3g are done; that is expected.

### T3c: Update constructor path (~line 136-148)

- [ ] Replace `var uinput_dev: ?UinputDevice = null; ... uinput_dev = try UinputDevice.create(out_cfg);`
  with:
  ```zig
  const uinput_ptr = try UinputDevice.initBoxed(allocator, out_cfg);
  errdefer { uinput_ptr.close(); allocator.destroy(uinput_ptr); }
  uinput_ptr.log_tag = cfg.device.name;
  ```
- [ ] Replace line 151-152 `loop.addUinputFf(uinput_dev.?.pollFfFd())` with
  `loop.addUinputFf(uinput_ptr.pollFfFd())`.
- [ ] T3 does NOT yet branch on `[output.imu].backend` — that is T4.
  Default unconditionally to the uinput pointer path so behaviour is unchanged.

### T3d: Update `DeviceInstance` struct literal at line 213

- [ ] Replace `.uinput_dev = uinput_dev,` with:
  ```zig
  .owner = .{ .uinput = uinput_ptr },
  .primary_output = uinput_ptr.outputDevice(),
  .imu_output = null,
  ```

### T3e: Update destructor at line 226

- [ ] Replace `if (self.uinput_dev) |*u| u.close();` with:
  ```zig
  switch (self.owner) {
      .none => {},
      .uinput => |p| { p.close(); self.allocator.destroy(p); },
      .uhid   => |p| { p.close(); self.allocator.destroy(p); },
  }
  ```

### T3f: Update emit call at line 255

- [ ] Replace `const output = if (self.uinput_dev) |*u| u.outputDevice() else nullOutput();`
  with `const output = self.primary_output orelse nullOutput();`.

### T3g: Update test fixtures and second supervisor construction

- [ ] `src/device_instance.zig:422,506,573` — replace `.uinput_dev = null,` with
  `.owner = .none, .primary_output = null, .imu_output = null,`
- [ ] `src/device_instance.zig:651-653` — update the test that asserts
  `inst.uinput_dev == null` to assert `inst.owner == .none`.
- [ ] `src/supervisor.zig:2079` — same replacement.

### T3h: CI green — regression gate

- [ ] `zig build test` passes with zero new failures.
- [ ] Run `supervisor_uhid_grace_integration_test.zig` — must stay green
  (sentinel for rebind/grace lifetime).
- [ ] Run `full_pipeline_e2e_test.zig` — must stay green (sentinel for
  end-to-end uinput path).

---

## T4: `buildUniq` pure function + supervisor routing switch

Files: `src/io/uniq.zig` (new), `src/device_instance.zig`, `src/supervisor.zig`, `build.zig`

### T4a: Create `src/io/uniq.zig`

- [ ] New file with:
  ```zig
  pub const MAX_UNIQ_LEN = 64;
  pub fn buildUniq(allocator, device_name, phys_key, counter) ![:0]u8 { ... }
  fn fnv16(bytes: []const u8) u16 { /* FNV-1a 16-bit */ }
  fn normalizeDeviceId(buf: []u8, name: []const u8) []u8 { ... }
  ```
- [ ] Implement `normalizeDeviceId`: lowercase ASCII, non-alphanum → `-`,
  collapse consecutive `-`, trim leading/trailing `-`, clip to 32 bytes.
- [ ] Implement `fnv16`: FNV-1a offset `0x811c`, prime `0x01000193`, 16-bit
  truncation.
- [ ] Implement `buildUniq`: format
  `"padctl/{device_id}-{instance}"` with NUL terminator, assert output
  length < `MAX_UNIQ_LEN`.

### T4b: Layer 0 unit tests in `src/io/uniq.zig`

- [ ] `test "buildUniq: with phys_key produces stable hash"` — input
  `"Flydigi Vader 3 Pro"` + `"usb-0000:00:14.0-3/input0"` → uniq contains
  `"padctl/flydigi-vader-3-pro-"` followed by exactly 4 lowercase hex digits.
- [ ] `test "buildUniq: null phys_key uses counter fallback"` — counter 1 →
  uniq ends with `-ctr0001`.
- [ ] `test "buildUniq: idempotent on same inputs"` — two calls produce
  byte-identical `[:0]u8`.
- [ ] `test "buildUniq: output ≤ 64 bytes including NUL"` — stress with a
  60-byte device name to confirm truncation.
- [ ] `test "buildUniq: non-ASCII → '-'"` — input `"Pad 中文"` → normalized
  id contains only ASCII alphanum + `-`.
- [ ] `test "fnv16: known-answer vector"` — pin at least one known FNV-1a
  16-bit output (e.g. `"abc"` → known value) to prevent silent hash changes.

### T4c: Register in build

- [ ] Add `src/io/uniq.zig` to the test step in `build.zig`.

### T4d: Add `imu_dev` field + extend deinit

- [ ] Add `imu_dev: ?*uhid_mod.UhidDevice = null,` to `DeviceInstance`.
- [ ] In `deinit` (see T3e block), before the `switch (self.owner)`, add
  `if (self.imu_dev) |p| { p.close(); self.allocator.destroy(p); }`.
- [ ] Update all test-fixture `DeviceInstance` literals (T3g sites) to include
  `.imu_dev = null,`.

### T4e: Thread `phys_key` into `DeviceInstance.init`

- [ ] Change signature to
  `pub fn init(allocator, cfg, init_mapping, phys_key: ?[]const u8) !DeviceInstance`.
- [ ] Update every caller:
  - `src/supervisor.zig` (each `DeviceInstance.init` call — grep for
    `DeviceInstance.init(` — 3-5 sites) passes `m.phys_key`.
  - Test callers (3+ sites) pass `null` or a literal fixture.

### T4f: Add `daemon_uniq_counter` to `Supervisor`

- [ ] Field `daemon_uniq_counter: u16 = 1,` in `Supervisor` struct.
- [ ] Thread it into `spawnInstance` / `attachWithInstance` and then into
  `DeviceInstance.init` calls so `buildUniq` can use it as fallback.
- [ ] Increment after each fallback use (only when `phys_key` is null).

### T4g: Replace unconditional `UinputDevice.initBoxed` with backend switch

- [ ] In `src/device_instance.zig:136-148`, wrap the construction in:
  ```zig
  const imu_cfg_opt = if (out_cfg.imu) |imu| imu else null;
  const use_uhid = if (imu_cfg_opt) |imu_cfg| std.mem.eql(u8, imu_cfg.backend, "uhid") else false;

  if (use_uhid) {
      // T4g1: build shared uniq
      const uniq_z = try uniq_mod.buildUniq(allocator, cfg.device.name, phys_key, daemon_counter);
      defer allocator.free(uniq_z);

      // T4g2: primary UHID card
      const descriptor = try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg);
      defer allocator.free(descriptor);
      const primary = try uhid_mod.UhidDevice.init(allocator, .{
          .name = cfg.device.name,
          .uniq = std.mem.sliceTo(uniq_z, 0),
          .vid = @intCast(cfg.device.vid),
          .pid = @intCast(cfg.device.pid),
          .descriptor = descriptor,
          .output = out_cfg.*,
      });
      errdefer { primary.close(); allocator.destroy(primary); }
      // T5 will add the IMU card construction here.
      owner = .{ .uhid = primary };
      primary_output = primary.outputDevice();
  } else {
      const p = try UinputDevice.initBoxed(allocator, out_cfg);
      errdefer { p.close(); allocator.destroy(p); }
      p.log_tag = cfg.device.name;
      owner = .{ .uinput = p };
      primary_output = p.outputDevice();
  }
  ```

### T4h: Layer 1 smoke — primary UHID only

- [ ] Add a small sanity test in `src/test/supervisor_uhid_routing_test.zig`
  (the file is *created* in T5, but this smoke test can land early as a stub
  file — or folded into T5c). If landed early: assert
  `DeviceInstance.init` with `backend="uhid"` + no `[output.imu]` subsection
  creates exactly 1 `UHID_CREATE2` via `UhidSimulator`.

### T4i: CI green

- [ ] `zig build test` passes.
- [ ] With `[output.imu].backend = "uhid"` fixture: primary UHID card built,
  no IMU card (that is T5).
- [ ] With default / `"uinput"`: existing behaviour byte-identical.

---

## T5: IMU descriptor + emit dispatch + Layer 1/2 tests

Files: `src/io/uhid_descriptor.zig`, `src/event_loop.zig`,
`src/device_instance.zig`, `src/test/supervisor_uhid_routing_test.zig` (new),
`src/test/uhid_uniq_pairing_test.zig`, `build.zig`

### T5a: `UhidDescriptorBuilder.buildForImu`

- [ ] In `src/io/uhid_descriptor.zig` after `buildFromOutput` (~line 167), add:
  ```zig
  pub fn buildForImu(
      allocator: std.mem.Allocator,
      imu_cfg: device.ImuConfig,
  ) BuildError![]u8 { ... }
  ```
- [ ] Emit HID report descriptor: Usage Page Sensor (0x20),
  `INPUT_PROP_ACCELEROMETER`, Motion Accelerator X/Y/Z (Usage 0x0473/0x0474/0x0475),
  Motion Gyrometer X/Y/Z (Usage 0x0476/0x0477/0x0478). No `EV_KEY`. No sticks.
  Logical range from `imu_cfg.accel_range` / `imu_cfg.gyro_range` (fallback
  `{-32768, 32767}`).

### T5b: Golden-file test for IMU descriptor

- [ ] In `src/io/uhid_descriptor.zig` test block, add
  **`test "buildForImu: default ranges → golden descriptor bytes"`**:
  - Construct `ImuConfig{}` (all defaults).
  - Call `buildForImu`.
  - Assert byte-exact equality with an inline `const EXPECTED = [_]u8{ ... };`
    golden reference.
  - Byte count check: assert `descriptor.len <= HID_MAX_DESCRIPTOR_SIZE`.
- [ ] Second test **`test "buildForImu: custom ranges alter logical min/max bytes"`**
  — override ranges, verify descriptor bytes at the range offsets change as
  expected.
- [ ] Third test **`test "buildForImu: descriptor contains no EV_KEY byte"`**
  — scan descriptor for Usage Page Button (0x09) and assert absence.

### T5c: IMU card construction in T4g block

- [ ] Extend the `if (use_uhid)` block in `src/device_instance.zig` (from T4g)
  to add the IMU card:
  ```zig
  if (imu_cfg_opt) |imu_cfg| {
      const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg);
      defer allocator.free(imu_desc);
      const imu_name_owned = if (imu_cfg.name) |n| try allocator.dupe(u8, n)
                             else try std.fmt.allocPrint(allocator, "{s} IMU", .{cfg.device.name});
      defer allocator.free(imu_name_owned);
      const imu = try uhid_mod.UhidDevice.init(allocator, .{
          .name = imu_name_owned,
          .uniq = std.mem.sliceTo(uniq_z, 0),
          .vid = @intCast(imu_cfg.vid orelse cfg.device.vid),
          .pid = @intCast(imu_cfg.pid orelse cfg.device.pid),
          .descriptor = imu_desc,
          .output = null,
      });
      errdefer { imu.close(); allocator.destroy(imu); }
      imu_dev_ptr = imu;
      imu_output = imu.outputDevice();
  }
  ```

### T5d: Event-loop IMU emit dispatch

- [ ] Locate the per-frame dispatch in `src/event_loop.zig` where
  `primary_output.emit(state)` is called.
- [ ] Add an `EventLoopContext` field `imu_output: ?uinput.OutputDevice = null`.
- [ ] After the primary emit, add:
  ```zig
  if (ctx.imu_output) |imu_out| {
      imu_out.emit(state) catch |err| std.log.warn("imu emit failed: {}", .{err});
  }
  ```
- [ ] `DeviceInstance.emit` (the call site currently reading `primary_output`)
  passes `self.imu_output` through to the loop context.

### T5e: `rumble` + `backend="uhid"` warn

- [ ] In the `if (use_uhid)` block, after constructing the primary UHID card,
  check `if (out_cfg.force_feedback != null) std.log.warn("rumble not supported in uhid backend until Wave 6", .{});`
- [ ] Emit exactly once per `DeviceInstance.init`, not per emit.

### T5f: Create `src/test/supervisor_uhid_routing_test.zig` (Layer 1)

- [ ] New file, imports: `const std = @import("std"); const testing = std.testing; const DeviceInstance = @import("../device_instance.zig").DeviceInstance; const UhidSimulator = @import("harness/uhid_simulator.zig").UhidSimulator;`
- [ ] **`test "routing: backend=uhid creates primary + IMU, shared uniq"`**:
  - Set up `UhidSimulator` to capture `/dev/uhid` writes.
  - Minimal `DeviceConfig` with `[output.imu].backend = "uhid"` and stub
    `phys_key = "sim-phys-0001"`.
  - `DeviceInstance.init(allocator, &cfg, null, "sim-phys-0001")`.
  - Assert simulator observed exactly 2 `UHID_CREATE2` events.
  - Extract both uniq strings; assert `std.mem.eql(u8, a, b)`.
  - Assert uniq starts with `"padctl/"`.
- [ ] **`test "routing: backend=uinput (default) produces zero UHID events"`** —
  regression guard.
- [ ] **`test "routing: backend=uinput + [output.imu] present → error.InvalidConfig"`** —
  validate path sanity (covers T1d from a different angle).
- [ ] **`test "routing: primary descriptor has EV_KEY, IMU descriptor does not"`** —
  scan the 2 captured descriptors.

### T5g: Extend `src/test/uhid_uniq_pairing_test.zig` (Layer 2)

- [ ] Add **`test "routing: real DeviceInstance produces paired uniq (requires /dev/uhid)"`**:
  - Honour existing `PADCTL_TEST_REQUIRE_UHID=1` gate helper (line 41).
  - Skip-or-fail per gate.
  - Construct same `DeviceConfig` as T5f test 1.
  - `DeviceInstance.init(...)` — real `/dev/uhid` open.
  - Poll sysfs for the 2 evdev nodes kernel created under `/dev/input/eventN`
    with matching vid/pid + `padctl/` uniq prefix.
  - `ioctl(EVIOCGUNIQ)` on both; assert equal via `std.mem.eql`.
  - Teardown via `DeviceInstance.deinit`.

### T5h: Register new test in build.zig

- [ ] Add `src/test/supervisor_uhid_routing_test.zig` to the test step.

### T5i: Final CI green

- [ ] `zig build test` passes (Layer 0+1, zero-priv).
- [ ] `PADCTL_TEST_REQUIRE_UHID=1 zig build test` passes locally (Layer 2).
- [ ] Run full suite sentinels:
  - `full_pipeline_e2e_test.zig` — green
  - `supervisor_uhid_grace_integration_test.zig` — green
  - `steam_deck_uhid_e2e_test.zig` — green
  - `uhid_all_devices_test.zig` — green (no descriptor regression)

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec via `openplan-archive --yes`.
- [ ] Update `planning/phase-13.md` (docs-repo) / `engineering/phase-13-wave-plan.md`
  Wave 3 status checkboxes → done.
- [ ] PR body includes:
  - Link to `decisions/015-uhid-imu-migration.md@92caade` + exit-condition
    table (AC1 pending Wave 5 local, AC2/AC4 met by Layer 1+2 tests).
  - Local-run log for Layer 2 (`PADCTL_TEST_REQUIRE_UHID=1 zig build test`
    EXIT=0).
  - Explicit note: **no** `devices/*.toml` changed; canary is Wave 5.
  - Release-note draft covering 4 items: `[output.imu].backend` field, VID/PID
    change on `"uhid"` opt-in, rumble unsupported, rollback steps.
