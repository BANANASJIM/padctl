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

- [x] In `src/config/device.zig`, near existing `FfConfig` / `AuxConfig`
  declarations, add `pub const ImuConfig = struct { backend: []const u8 = "uinput", name: ?[]const u8 = null, vid: ?i64 = null, pid: ?i64 = null, accel_range: ?[2]i64 = null, gyro_range: ?[2]i64 = null };`
- [x] Verify no compilation error — field defaults + types must parse under
  existing `zig-toml` bindings.

### T1b: Add `imu` field to `OutputConfig`

- [x] In `src/config/device.zig:141-153` `OutputConfig`, add
  `imu: ?ImuConfig = null,` as the last field.
- [x] `zig build` passes.

### T1c: Extend `validate` with IMU backend rules

- [x] In `src/config/device.zig:221` `pub fn validate`, at the end of the
  per-report loop, add a top-level `if (cfg.output) |out|` block:
  - If `out.imu` is `null`: legal, no action (fall through to the rest of
    validate — do NOT use a bare `return;` here, which would skip any
    subsequent generic-mode checks tacked onto the end of `validate`).
  - If `out.imu.?.backend == "uhid"`: legal.
  - If `out.imu.?.backend == "uinput"`: return `error.InvalidConfig`
    (ADR-015 forbids "uinput primary + IMU present").
  - Else (unknown backend string): return `error.InvalidConfig`.
- [x] No new error variant needed — reuse `error.InvalidConfig`.

### T1d: Validate tests

- [x] In `src/config/device.zig` test block, add 4 cases:
  - **`test "validate: ImuConfig default (absent) is legal"`** — pre-Wave-3 fixture round-trips.
  - **`test "validate: backend=uhid + [output.imu] present is legal"`** — succeeds.
  - **`test "validate: backend=uinput + [output.imu] present is error.InvalidConfig"`** — asserts the error.
  - **`test "validate: backend=unknown is error.InvalidConfig"`** — asserts fail-closed.
- [x] `zig build test` passes all 4.

### T1e: TOML round-trip parser test

- [x] Round-trip test: parse a TOML fragment with
  `[output.imu]\nbackend = "uhid"\nname = "Pad IMU"\n`, verify
  `cfg.output.?.imu.?.backend == "uhid"` and `cfg.output.?.imu.?.name.? == "Pad IMU"`.

---

## T2: `UinputDevice.initBoxed` heap-alloc wrapper

Files: `src/io/uinput.zig`

### T2a: Add `initBoxed` function

- [x] In `src/io/uinput.zig` near `pub fn create` (around line 137), add:
  ```zig
  pub fn initBoxed(allocator: std.mem.Allocator, cfg: *const device.OutputConfig) !*UinputDevice {
      const p = try allocator.create(UinputDevice);
      errdefer allocator.destroy(p);
      p.* = try UinputDevice.create(cfg);
      return p;
  }
  ```
- [x] Verify compile: `zig build` green.

### T2b: Layer 0 test for `initBoxed`

- [x] In the existing `UinputDevice` test block (mocked allocator), add
  **`test "initBoxed: heap-allocates and returns owning pointer"`**:
  - Use `std.testing.allocator`.
  - Call `initBoxed` with a mock `OutputConfig` (reuse existing mock fixtures).
  - Assert returned pointer is non-null.
  - `defer p.close()` + `defer allocator.destroy(p)`.
  - Verify no leaks (testing allocator's leak check).
- [x] `zig build test` passes.

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

- [ ] `src/device_instance.zig:422,506,573` — replace `.uinput_dev = null,`
  with `.owner = .none, .primary_output = null, .imu_output = null,`
  (T4d adds `.imu_dev = null, .imu_name_owned = null,` to the same literals
  once those fields exist — this can be done in T3g preemptively with
  `// T4d: add .imu_dev/.imu_name_owned once fields land` comments, or in T4d
  proper; either ordering compiles cleanly as long as all three checkbox
  steps land before `zig build test` runs).
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
  fn hash16(bytes: []const u8) u16 { /* FNV-1a-32 then @truncate to u16 */ }
  fn normalizeDeviceId(buf: []u8, name: []const u8) []u8 { ... }
  ```
- [ ] Implement `normalizeDeviceId`: lowercase ASCII, non-alphanum → `-`,
  collapse consecutive `-`, trim leading/trailing `-`, clip to 32 bytes.
- [ ] Implement `hash16`: FNV-1a 32-bit (offset basis `0x811c9dc5`, prime
  `0x01000193`) using Zig wrapping multiply `*%=`, then `@truncate` to `u16`.
  The algorithm is pinned in `design.md §"Cross-cutting: uniq format"` — do
  not substitute another hash.
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
- [ ] `test "buildUniq: non-ASCII → '-'"` — input with non-ASCII bytes (e.g.
  `"Pad \xe4\xb8\xad"`) → normalized id contains only ASCII alphanum + `-`.
- [ ] `test "hash16: known-answer vector"` — run the implemented
  `hash16("padctl/vader-5-pro-0000:00:14.0-1.3")` once, paste the observed
  `u16` value into the test as the golden known-answer constant, and commit.
  This is "implementer pins first-run output as the golden" — the spec does
  NOT supply a hand-computed expected value because the reviewer could not
  verify one against the specified FNV-1a-32-then-truncate algorithm. From
  the commit forward, any algorithm change (parameter tweak, fold strategy,
  non-wrapping multiply) flips this test red.

### T4c: Register in build

- [ ] Add `src/io/uniq.zig` to the test step in `build.zig`.

### T4d: Add `imu_dev` + `imu_name_owned` fields + extend deinit

- [ ] Add to `DeviceInstance`:
  ```zig
  imu_dev:        ?*uhid_mod.UhidDevice = null,
  imu_name_owned: ?[]const u8           = null,   // allocator-owned backing for imu_dev.name
  ```
- [ ] In `deinit` (see T3e block), before the `switch (self.owner)`, tear
  down the IMU card in this exact order (close the device FIRST, free the
  name string SECOND — `UhidDevice.name` is owned-by-caller per
  `src/io/uhid.zig:218`, so freeing before `close` would dangle the pointer
  while `UHID_DESTROY` is in flight):
  ```zig
  if (self.imu_dev) |p| {
      p.close();
      self.allocator.destroy(p);
  }
  if (self.imu_name_owned) |n| {
      self.allocator.free(n);
  }
  ```
- [ ] Update all test-fixture `DeviceInstance` literals (T3g sites) to include
  `.imu_dev = null, .imu_name_owned = null,`.

### T4e: Thread `phys_key` + `uniq_counter` into `DeviceInstance.init`

- [ ] Change signature to:
  ```zig
  pub fn init(
      allocator: std.mem.Allocator,
      cfg: *const device.DeviceConfig,
      init_mapping: ...,
      phys_key: ?[]const u8,
      uniq_counter: *u16,
  ) !DeviceInstance
  ```
  (the exact `init_mapping` type is unchanged from its current form — only
  the two new parameters are added at the tail, no reorder.)
- [ ] Update every caller — **5 sites total**, all must be touched in this
  subtask:
  1. `src/supervisor.zig` site 1 (~line 1510, `spawnInstance` inline call):
     pass `m.phys_key` and `&self.daemon_uniq_counter`.
  2. `src/supervisor.zig` site 2 (~line 2000, `attachWithInstance` / rebind
     call): same pair of arguments.
  3. `src/main.zig` (~line 1021): pass `null` for `phys_key` and a pointer
     to a stack-local `var main_uniq_counter: u16 = 1;` for `uniq_counter`.
     The one-shot daemon path has a single device; the counter's value
     never matters, but the parameter must be valid.
  4. `src/test/supervisor_uhid_grace_integration_test.zig:~80`: pass `null`
     and `&local_counter` where `local_counter` is a stack-local `u16 = 1`.
  5. `src/test/supervisor_uhid_grace_integration_test.zig:~138`: same.

### T4f: Add `daemon_uniq_counter` to `Supervisor`

- [ ] Field `daemon_uniq_counter: u16 = 1,` in `Supervisor` struct.
- [ ] Pass `&self.daemon_uniq_counter` at every `DeviceInstance.init` call
  site inside `supervisor.zig` (T4e sites 1+2). No threading through
  intermediary functions needed — the supervisor holds the storage and the
  init call sites have direct `self` access.
- [ ] Increment is performed INSIDE `DeviceInstance.init`'s `if (use_uhid)`
  block (per design.md §4d), not at the call site — exactly once per
  null-`phys_key` construction. Test by calling `DeviceInstance.init`
  twice with `phys_key == null` and asserting the counter advanced by 2.

### T4g: Replace unconditional `UinputDevice.initBoxed` with backend switch

- [ ] In `src/device_instance.zig:136-148`, wrap the construction in:
  ```zig
  const imu_cfg_opt = if (out_cfg.imu) |imu| imu else null;
  const use_uhid = if (imu_cfg_opt) |imu_cfg| std.mem.eql(u8, imu_cfg.backend, "uhid") else false;

  if (use_uhid) {
      // T4g1: build shared uniq. `uniq_counter` is the `*u16` parameter
      // threaded in from T4e. Snapshot once before calling buildUniq,
      // then bump ONLY if the counter branch was taken (phys_key == null).
      const counter_snapshot: u16 = uniq_counter.*;
      const uniq_z = try uniq_mod.buildUniq(allocator, cfg.device.name, phys_key, counter_snapshot);
      defer allocator.free(uniq_z);
      if (phys_key == null) uniq_counter.* += 1;

      // T4g2: primary UHID card
      const descriptor = try uhid_descriptor.UhidDescriptorBuilder.buildFromOutput(allocator, out_cfg.*);
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

### T4h: Layer 1 smoke — (subsumed by T5f)

- [ ] Per the T1 validate rules, the only legal `backend = "uhid"` shape
  REQUIRES `[output.imu]` present (both primary + IMU). `backend = "uhid"`
  without `[output.imu]` is not expressible — it would simply be
  `[output.imu] = none`, which is the uinput-default path. Therefore no
  standalone "primary UHID only" smoke test is needed; the full routing
  fixture in T5f (shared pipe pair, both cards asserted) is the canonical
  coverage. This subtask has no deliverable — it exists as a sequencing
  breadcrumb noting that the smoke intent is satisfied by T5f test 1.

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
  to add the IMU card. Note the `imu_name_alloc` lifetime handling: it is
  allocator-owned AND becomes the `name` backing for `UhidDevice`, which
  documents `name` as owned-by-caller (`src/io/uhid.zig:218`). The allocation
  is therefore NOT freed at block exit — it is stored on `DeviceInstance`
  (`imu_name_owned`, per T4d) and freed in `deinit` strictly AFTER the
  matching `imu.close()`. A `defer allocator.free(imu_name_alloc)` here would
  dangle the stored pointer on the happy path and is forbidden.
  ```zig
  if (imu_cfg_opt) |imu_cfg| {
      const imu_desc = try uhid_descriptor.UhidDescriptorBuilder.buildForImu(allocator, imu_cfg);
      defer allocator.free(imu_desc);

      // Owned name backing — lives on DeviceInstance, not freed here.
      const imu_name_alloc: []const u8 = if (imu_cfg.name) |n|
          try allocator.dupe(u8, n)
      else
          try std.fmt.allocPrint(allocator, "{s} IMU", .{cfg.device.name});
      errdefer allocator.free(imu_name_alloc);     // only fires if init below errors

      const imu = try uhid_mod.UhidDevice.init(allocator, .{
          .name = imu_name_alloc,
          .uniq = std.mem.sliceTo(uniq_z, 0),
          .vid = @intCast(imu_cfg.vid orelse cfg.device.vid),
          .pid = @intCast(imu_cfg.pid orelse cfg.device.pid),
          .descriptor = imu_desc,
          .output = null,
      });
      errdefer { imu.close(); allocator.destroy(imu); }
      imu_dev_ptr  = imu;
      imu_name_ptr = imu_name_alloc;               // plumbed into the struct literal below
      imu_output   = imu.outputDevice();
  }
  ```
- [ ] At the `DeviceInstance` struct literal (~line 213, updated by T3d), add:
  ```
  .imu_dev        = imu_dev_ptr,
  .imu_name_owned = imu_name_ptr,
  .imu_output     = imu_output,
  ```

### T5d: Event-loop IMU emit dispatch

- [ ] Add an `EventLoopContext` field `imu_output: ?uinput.OutputDevice = null`.
- [ ] `src/event_loop.zig` has **two** `ctx.output.emit(state)` call sites per
  frame: the mapper path (~line 668) and the passthrough / `synthesizeDpadAxes`
  branch (~line 678). Add the IMU emit block **after BOTH** primary-emit calls
  (grep `ctx\.output\.emit` to locate the authoritative current line numbers —
  spec-writer's numbers are from base `8adfc19` and may drift):
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

Fixture: `UhidDevice.initWithFd` + `posix.pipe2` — NOT `UhidSimulator`.
`UhidSimulator` is an input-side harness (opens `/dev/uhid` to produce a
virtual HID node that padctl reads from) and has no mechanism to intercept
write-side `UHID_CREATE2` events emitted by `DeviceInstance.init →
UhidDevice.init`. The pattern used below matches the existing inline tests
in `src/io/uhid.zig` and the PR #155 tests.

- [ ] New file, imports:
  ```zig
  const std      = @import("std");
  const posix    = std.posix;
  const testing  = std.testing;
  const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
  const uhid_mod = @import("../io/uhid.zig");
  ```
  (do NOT import `harness/uhid_simulator.zig` — wrong direction of capture.)
- [ ] Add a test-only seam on `DeviceInstance.init` so the two `UhidDevice`
  constructions inside the routing switch bind to caller-supplied fds
  instead of opening `/dev/uhid`. Two equivalent options:
  - **Option A (preferred)**: a `DeviceInstance.InitOptions` struct with
    optional `test_primary_uhid_fd: ?posix.fd_t = null` and
    `test_imu_uhid_fd: ?posix.fd_t = null`. The routing switch prefers
    `UhidDevice.initWithFd` when the option is non-null, `UhidDevice.init`
    otherwise. Production call sites pass `.{}`.
  - **Option B**: a compile-time-injected `pub var uhidOpenFn: fn() !posix.fd_t`
    module variable that tests override before calling `init`. More Zig-idiomatic
    but requires reentrant test ordering discipline — prefer A unless Option
    A adds an unacceptable field count.
- [ ] **`test "routing: backend=uhid creates primary + IMU, shared uniq"`**:
  ```
  var primary_fds: [2]posix.fd_t = undefined;
  var imu_fds:     [2]posix.fd_t = undefined;
  try posix.pipe2(&primary_fds, .{ .NONBLOCK = true });
  try posix.pipe2(&imu_fds,     .{ .NONBLOCK = true });
  defer for ([_]posix.fd_t{ primary_fds[0], imu_fds[0] }) |fd|
      posix.close(fd);
  // primary_fds[1] / imu_fds[1] are given to UhidDevice and closed by it.
  ```
  - Minimal `DeviceConfig` with `[output.imu].backend = "uhid"` + stub
    `phys_key = "sim-phys-0001"`.
  - Call `DeviceInstance.init` with `test_primary_uhid_fd = primary_fds[1]`
    and `test_imu_uhid_fd = imu_fds[1]`; pass `"sim-phys-0001"` for
    `phys_key`, and `&local_counter` for `uniq_counter`.
  - `posix.read(primary_fds[0], &buf)` → decode the `UhidCreate2Event`
    payload, extract `payload.uniq`.
  - `posix.read(imu_fds[0], &buf)` → decode the IMU side.
  - Assert `std.mem.eql(u8, primary_uniq, imu_uniq)`.
  - Assert `std.mem.startsWith(u8, primary_uniq, "padctl/")`.
- [ ] **`test "routing: backend=uinput (default) emits no UHID event"`** —
  regression guard. Build config with no `[output.imu]`, pass null fds,
  after `DeviceInstance.init` returns, no pipe reads are attempted (both
  fds stay open but the routing never wrote).
- [ ] **`test "routing: backend=uinput + [output.imu] present → error.InvalidConfig"`** —
  validate path sanity (covers T1d from a different angle).
- [ ] **`test "routing: primary descriptor has EV_KEY, IMU descriptor does not"`** —
  decode both captured `UhidCreate2Event`s from the pipes, scan the
  `payload.rd_data[0..payload.rd_size]` bytes for Usage Page Button
  (`0x05 0x09`); assert present on primary, absent on IMU.
- [ ] **`test "routing: deinit emits UHID_DESTROY per card"`** — after
  `DeviceInstance.init` and the CREATE2 reads, call `deinit`, then read
  again from each pipe; decode 2 `UHID_DESTROY` events (one per card).

### T5g: Extend `src/test/uhid_uniq_pairing_test.zig` (Layer 2)

- [ ] Add **`test "routing: real DeviceInstance produces paired uniq (requires /dev/uhid)"`**:
  - Honour existing `PADCTL_TEST_REQUIRE_UHID=1` gate helper (line 41).
  - Skip-or-fail per gate.
  - Construct same `DeviceConfig` as T5f test 1 but pass no pipe-fd overrides
    (`test_primary_uhid_fd = null`, `test_imu_uhid_fd = null`) so the
    routing switch goes through real `/dev/uhid` open.
  - Pass stack-local `var local_counter: u16 = 1;` + `&local_counter` for
    `uniq_counter`, and a real fixture `phys_key = "sim-phys-0001"` (or a
    test-generated string).
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
