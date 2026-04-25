# Tasks: Phase 13 Wave 6 — HID PID force feedback passthrough (T1-T7)

Branch: `feat/phase-13-wave-6-pidff`
Commit: (leave blank — filled after implementation)

## Execution Plan

Dependency DAG:

```
T5 ──┬──> T1 ──┐
     │         ├──> T6 ──> T7
     └──> T2 ──┘          (real hardware,
              T3 ──> T4 ──┘ doc-only deliverable
                            for canary TOMLs +
                            CI workflow)
```

- **T5** (schema) is the structural prerequisite — all other tasks read
  the new `ForceFeedbackConfig` shape.
- **T1** (PID descriptor) and **T2** (VID/PID cloning) consume T5's
  schema; can run in parallel after T5.
- **T3** (UHID_OUTPUT handler) is independent of T1/T2/T5 — pure
  read-side plumbing on `src/io/uhid.zig`. Can run in parallel from
  the start.
- **T4** (FfbForwarder) depends on T3 (uses `OutputReport` type).
- **T6** (Layer 1 e2e) depends on T1 + T2 + T3 + T4 (full stack
  integration).
- **T7** (real hardware + CI workflow) depends on T1 + T2 + T5 + T6
  AND Wave 5 hardware regression matrix completion (out-of-band).

Recommended order: **T5 → (T1 + T2 + T3 parallel) → T4 → T6 → T7**.
PR cadence: 3-4 PRs serial:

- PR-A: T5 + T3 (~120 + 120 LoC schema + read-side plumbing)
- PR-B: T1 + T2 (~250 + 150 LoC descriptor + cloning + udev)
- PR-C: T4 + T6 (~250 + 200 LoC forwarder + e2e)
- PR-D: T7 (doc-only — canary TOMLs + CI workflow + manual test plan)

## LoC Budget

| Task | LoC (code + test) |
|------|-------------------|
| T1 | ~250 |
| T2 | ~150 |
| T3 | ~120 |
| T4 | ~250 |
| T5 | ~120 |
| T6 | ~200 |
| T7 | ~doc only (~50 LoC YAML + per-wheel TOML) |
| **Total** | **~1090 + docs** |

## Behaviour Contracts (must hold per task)

- After **T5** merges (no T1-T4 yet): `[output.force_feedback]` parses,
  validate matrix enforced, but no runtime path uses the field. All
  existing tests green.
- After **T1** merges (no T2-T4 yet): `buildForPid` callable with golden
  test green; `validateMandatoryReports` rejects synthetic incomplete
  descriptor. No `DeviceInstance.init` call site uses it yet.
- After **T2** merges (T5 + T1 in place): `clone_vid_pid` flips primary
  card VID/PID at construction; udev rule emission test green; default
  `false` zero-regression.
- After **T3** merges: `pollOutputReport` parses synthetic UHID_OUTPUT
  bytes; callback wiring compiles. No `FfbForwarder` yet.
- After **T4** merges: `FfbForwarder` writes to pipe2 in unit test; rate
  counter accurate; EAGAIN/EACCES/ENODEV classification covered.
- After **T6** merges: full Layer 1 e2e (`wave6_pidff_e2e_test.zig`) green;
  3 PID report classes round-trip byte-equal; failure-mode tests pass.
- T7 is post-merge / external — Wave 6 in code-repo is *complete* when
  PR-A through PR-C land; T7 deliverables (canary TOML + CI workflow)
  follow once at least one wheel is hardware-tested.

---

## T1: PID descriptor builder

Files: `src/io/uhid_descriptor.zig`

### T1a: Add `buildForPid` skeleton

- [ ] In `src/io/uhid_descriptor.zig`, after `buildForImu` (Wave 3,
  ~line 167), add:
  ```zig
  pub fn buildForPid(
      allocator: std.mem.Allocator,
      cfg: device.OutputConfig,
      ffb_cfg: device.ForceFeedbackConfig,
  ) BuildError![]u8 { ... }
  ```
- [ ] Reuse existing axis/button emit helpers from `buildFromOutput`
  (extract them to private `emitAxes` / `emitButtons` if not already).
- [ ] After axis/button blocks, emit Usage Page Physical Interface
  Device (`0x05 0x0F`) marker.

### T1b: Emit all 12 PID mandatory reports

- [ ] Set Effect Report (ID 1) — Effect Type usage 0x25, Duration 0x50,
  Sample Period 0x54, Gain 0x52, Trigger Button 0x53, Axes Enable 0x55,
  Direction X 0x56, Direction Y 0x57. Layout matches USB PID 1.01 §4.1.
- [ ] Set Envelope Report (ID 2) — Attack Level 0x5B, Fade Level 0x5E,
  Attack Time 0x5C, Fade Time 0x5D.
- [ ] Set Condition Report (ID 3) — Center Point Offset 0x60,
  Positive Coefficient 0x61, Negative Coefficient 0x62, Positive Saturation
  0x63, Negative Saturation 0x64, Dead Band 0x65.
- [ ] Set Periodic Report (ID 4) — Magnitude 0x70, Offset 0x71, Phase 0x72,
  Period 0x73.
- [ ] Set Constant Force Report (ID 5) — Magnitude 0x70.
- [ ] Set Ramp Force Report (ID 6) — Ramp Start 0x75, Ramp End 0x76.
- [ ] Effect Operation Report (ID 10) — Operation 0x78 (Start 0x79 / Start
  Solo 0x7A / Stop 0x7B), Loop Count 0x7C.
- [ ] Device Control Report (ID 11) — Disable 0x97, Enable 0x98, Stop 0x99,
  Reset 0x9A, Pause 0x9B, Continue 0x9C.
- [ ] Device Gain Report (ID 12) — Gain 0x7E.
- [ ] Create New Effect feature Report (ID 13) — Effect Type 0xAB.
- [ ] Block Load feature Report (ID 14) — Effect Block Index 0xAE,
  Block Load Status 0xAC, RAM Pool Available 0xAB (Result).
- [ ] PID Pool feature Report (ID 15) — RAM Pool Size 0x80,
  Simultaneous Effects Max 0x83, Device Managed Pool 0xA9,
  Shared Parameter Blocks 0xAA.

Implementer pins exact byte sequences against `hid-tools` canonical
PID descriptor and against probe Run 2's working descriptor (Moza R5
case). Report-ID byte sequencing follows USB HID 1.11 §6.2.2.

### T1c: `validateMandatoryReports`

- [ ] Add private function:
  ```zig
  fn validateMandatoryReports(descriptor: []const u8) BuildError!void {
      const REQUIRED = [_]u8{ 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15 };
      var seen: [16]bool = .{false} ** 16;
      var i: usize = 0;
      while (i < descriptor.len) {
          // walk descriptor item-by-item; on `0x85 NN` short-form item,
          // record seen[NN] = true. Long-form (rare) handled per HID 1.11.
          // ...
      }
      for (REQUIRED) |id| {
          if (!seen[id]) return error.IncompletePidDescriptor;
      }
  }
  ```
- [ ] Add `IncompletePidDescriptor` to `BuildError` set.
- [ ] Call at end of `buildForPid` before returning the slice.

### T1d: Golden-byte test

- [ ] In `src/io/uhid_descriptor.zig` test block, add:
  - **`test "buildForPid: 12 mandatory reports present"`** — call
    `buildForPid` with a Moza-R5-style fixture (vid=0x11FF, pid=0x1211,
    one axis, no buttons), assert `validateMandatoryReports(result)`
    returns success.
  - **`test "buildForPid: matches reference Moza R5 descriptor (golden)"`**
    — inline `const EXPECTED = [_]u8{ ... };` byte array; assert
    `std.mem.eql(u8, result, EXPECTED)`. The implementer pins the
    bytes from the first run, after manually verifying against probe
    Run 2's descriptor.
  - **`test "buildForPid: synthetic incomplete descriptor → IncompletePidDescriptor"`**
    — directly call `validateMandatoryReports` on a hand-crafted
    8-of-12 descriptor; assert error.

### T1e: Defensive byte-count check

- [ ] Assert `descriptor.len <= HID_MAX_DESCRIPTOR_SIZE` (4096); add
  test for stress case (all 12 reports + max axes/buttons).

### T1f: Build + test gate

- [ ] `zig build test` passes. No regression in `buildFromOutput` /
  `buildForImu` golden tests (Wave 2 / Wave 3 sentinels).

---

## T2: VID/PID cloning + udev

Files: `src/config/device.zig`, `src/device_instance.zig`,
`src/cli/install.zig`, `src/test/install_udev_test.zig`

### T2a: Read `clone_vid_pid` in `DeviceInstance`

Note: T5 lands the field. T2 only reads it.

- [ ] In `src/device_instance.zig` (the Wave 3 `if (use_uhid)` block at
  the routing switch), determine effective vendor/product:
  ```zig
  const ffb_cfg = out_cfg.force_feedback orelse device.ForceFeedbackConfig{};
  const effective_vid: u16 = if (ffb_cfg.clone_vid_pid)
      @intCast(cfg.device.vid)
  else
      0xFADE;   // padctl daemon identity
  const effective_pid: u16 = if (ffb_cfg.clone_vid_pid)
      @intCast(cfg.device.pid)
  else
      0xC001;
  ```
  (Constants `0xFADE` / `0xC001` come from the existing primary-card
  identity; verify by grep `FADE` in `src/io/`.)
- [ ] Pass `effective_vid` / `effective_pid` to
  `UhidDevice.init(.{ .vendor = effective_vid, .product = effective_pid, ... })`.
- [ ] IMU card unchanged — IMU continues with `FADE:C002`.

### T2b: Validate in `device.zig`

- [ ] In `validate(cfg)` (already extended by T5), assert that
  `clone_vid_pid = true` requires `cfg.device.vid != 0` AND
  `cfg.device.pid != 0`. If either is zero/missing →
  `error.InvalidConfig` (cloning meaningless without source values).

### T2c: udev rule emission

- [ ] In `src/cli/install.zig` (rule-generation function — grep for the
  Wave 4 `KERNELS=="uhid"` line, ~line 802), iterate all loaded
  `DeviceConfig`s, collect unique `(vid, pid)` pairs where
  `force_feedback.?.clone_vid_pid == true`.
- [ ] For each unique pair, emit one additional rule:
  ```
  KERNELS=="uhid", SUBSYSTEM=="input", ENV{ID_VENDOR_ID}=="<vid:04x>", ENV{ID_MODEL_ID}=="<pid:04x>", TAG+="uaccess"
  ```
- [ ] Order: emit AFTER the existing wildcard `KERNELS=="uhid"` rule
  (specific rules after general; per udev rule semantics, both apply).

### T2d: Tests

- [ ] In `src/config/device.zig` test block, add
  **`test "validate: clone_vid_pid=true requires non-zero device.vid/pid"`**.
- [ ] In `src/test/install_udev_test.zig` (or wherever Wave 4's udev
  golden tests live), add
  **`test "install: clone_vid_pid=true emits per-VID/PID udev rule"`** —
  parse a TOML with `clone_vid_pid = true`, run rule generator, assert
  output contains the expected line for that VID/PID.
- [ ] Negative test: `clone_vid_pid = false` produces NO per-VID/PID rule.

### T2e: Build + test gate

- [ ] `zig build test` green; existing install tests green.

---

## T3: `UHID_OUTPUT` event handler

Files: `src/io/uhid.zig`, `src/io/uhid_types.zig`, `src/event_loop.zig`

### T3a: Extend `uhid_types.zig`

- [ ] Add `UhidOutputReq` struct mirroring kernel `struct uhid_output_req`:
  ```zig
  pub const UhidOutputReq = extern struct {
      size: u16,
      rtype: u8,
      data: [UHID_DATA_MAX]u8,
  };
  ```
- [ ] Extend the `UhidEvent` enum with `UHID_OUTPUT = 6` if not already
  present (Wave 1 PR #127 may have added it; verify).
- [ ] Add public `OutputReport`:
  ```zig
  pub const OutputReport = struct {
      report_id: u8,
      data: []const u8,    // borrows the caller's read buffer
  };
  ```

### T3b: `pollOutputReport` on `UhidDevice`

- [ ] In `src/io/uhid.zig`, add:
  ```zig
  pub fn pollOutputReport(self: *UhidDevice, buf: []u8) !?OutputReport {
      // posix.read(self.fd, buf) catch |err| switch (err) {
      //     error.WouldBlock => return null,
      //     ...
      // };
      // const event_type = buf[0];   // first byte is uhid_event.type
      // if (event_type != @intFromEnum(UhidEvent.UHID_OUTPUT)) return null;
      // const req = @as(*const UhidOutputReq, @ptrCast(@alignCast(&buf[4])));
      // return OutputReport{
      //     .report_id = req.data[0],
      //     .data = req.data[0..req.size],
      // };
  }
  ```
- [ ] Caller (`event_loop.zig`) drains by calling `pollOutputReport` in
  a loop until it returns `null` (WouldBlock or non-OUTPUT event).

### T3c: Output-callback wiring

- [ ] Add to `UhidDevice`:
  ```zig
  output_cb: ?*const fn (ctx: *anyopaque, report: OutputReport) void = null,
  output_ctx: ?*anyopaque = null,

  pub fn setOutputCallback(
      self: *UhidDevice,
      cb: *const fn (ctx: *anyopaque, report: OutputReport) void,
      ctx: *anyopaque,
  ) void {
      self.output_cb = cb;
      self.output_ctx = ctx;
  }
  ```
- [ ] `event_loop.zig`'s drain loop invokes the callback if set:
  ```zig
  while (try uhid_dev.pollOutputReport(buf)) |report| {
      if (uhid_dev.output_cb) |cb| {
          cb(uhid_dev.output_ctx.?, report);
      }
  }
  ```

### T3d: Layer 0 unit test

- [ ] In `src/io/uhid.zig` test block, add
  **`test "pollOutputReport: parses UHID_OUTPUT bytes"`**:
  - Create pipe2 pair; write a hand-crafted `UHID_OUTPUT` event to the
    write-end (event_type byte = 6, then `UhidOutputReq` with size=4,
    data = `{0x0A, 0x01, 0x02, 0x03}`).
  - `posix.read` from read-end into buf, call `pollOutputReport(buf)`.
  - Assert returned report has `report_id == 0x0A`, `data` byte-equal to
    `{0x0A, 0x01, 0x02, 0x03}`.
- [ ] Add **`test "pollOutputReport: non-UHID_OUTPUT event returns null"`**.

### T3e: Build + test gate

- [ ] `zig build test` green.

---

## T4: `FfbForwarder`

Files: `src/io/ffb_forwarder.zig` (new), `src/supervisor.zig`,
`src/io/hidraw.zig`, `build.zig`

### T4a: New module `src/io/ffb_forwarder.zig`

- [ ] Create file with:
  ```zig
  pub const FfbForwarder = struct {
      physical_fd: posix.fd_t,
      state: enum { active, disabled } = .active,
      writes_total: u64 = 0,
      drops_eagain: u64 = 0,
      last_log_ns: i64 = 0,

      pub fn init(physical_fd: posix.fd_t) FfbForwarder {
          return .{ .physical_fd = physical_fd };
      }

      pub fn forward(self: *FfbForwarder, report: OutputReport) void {
          if (self.state == .disabled) return;
          _ = posix.write(self.physical_fd, report.data) catch |err| switch (err) {
              error.WouldBlock => { self.drops_eagain += 1; return; },
              error.AccessDenied, error.PermissionDenied => {
                  std.log.warn("ffb forwarder: hidraw write EACCES, disabling", .{});
                  self.state = .disabled; return;
              },
              error.NoDevice => {
                  std.log.warn("ffb forwarder: hidraw ENODEV, disabling", .{});
                  self.state = .disabled; return;
              },
              else => return,
          };
          self.writes_total += 1;
      }

      pub fn deinit(self: *FfbForwarder) void { _ = self; }
  };
  ```
- [ ] Add `OutputReport` import from `src/io/uhid.zig`.

### T4b: Supervisor integration

- [ ] In `src/supervisor.zig` `attachInstance` (where `physical_hidraw_fd`
  is opened), after the fd is available and `UhidDevice.init` has
  succeeded:
  ```zig
  var fwd = FfbForwarder.init(physical_hidraw_fd);
  uhid_dev.setOutputCallback(forwarderCallback, &fwd);
  ```
- [ ] `forwarderCallback` is a thin static wrapper:
  ```zig
  fn forwarderCallback(ctx: *anyopaque, report: OutputReport) void {
      const self = @as(*FfbForwarder, @ptrCast(@alignCast(ctx)));
      self.forward(report);
  }
  ```
- [ ] Lifetime: `FfbForwarder` lives in the `ManagedInstance` struct
  alongside `physical_hidraw_fd`. Detach order:
  1. `uhid_dev.setOutputCallback(null, null)` (clear)
  2. `uhid_dev.close()`
  3. `posix.close(physical_hidraw_fd)` (existing)
  4. `fwd.deinit()` (no-op, but keeps the symbol there for future)

### T4c: Layer 0 unit test

- [ ] In `src/io/ffb_forwarder.zig` test block, add:
  - **`test "FfbForwarder: forwards report bytes byte-faithfully"`** —
    pipe2; `init(pipe[1])`; `forward({.report_id=0x01, .data=&[_]u8{0x01,0x02,0x03}})`;
    `posix.read(pipe[0])` → assert bytes equal.
  - **`test "FfbForwarder: counts writes_total"`** — call forward N
    times, assert counter.
  - **`test "FfbForwarder: EAGAIN increments drops_eagain"`** — stuff
    pipe to capacity (writes 64KB+ of dummy bytes), call forward, assert
    `drops_eagain == 1`.
  - **`test "FfbForwarder: closed fd → state=disabled"`** —
    `posix.close(pipe[1])` BEFORE forward, call forward, assert
    `state == .disabled`. (The close races with write; some platforms
    may return EBADF instead of ENODEV — accept either, but the state
    transition must happen.)

### T4d: Register in `build.zig`

- [ ] Add `src/io/ffb_forwarder.zig` to test step.

### T4e: Build + test gate

- [ ] `zig build test` green.

---

## T5: `[output.force_feedback]` schema

Files: `src/config/device.zig`

### T5a: Add `ForceFeedbackConfig` struct

- [ ] In `src/config/device.zig`, near `ImuConfig`, add:
  ```zig
  pub const ForceFeedbackConfig = struct {
      backend:       []const u8 = "uinput",   // "uinput" | "uhid"
      kind:          []const u8 = "rumble",   // "rumble" | "pid"
      clone_vid_pid: bool       = false,
  };
  ```

### T5b: Add `force_feedback` field to `OutputConfig`

- [ ] In `OutputConfig` (Wave 3 line ~141-153), add as a tail field:
  ```zig
  force_feedback: ?ForceFeedbackConfig = null,
  ```

### T5c: Validate matrix

In `validate(cfg)` (`src/config/device.zig:221`+), after the IMU validate
block (Wave 3), add:

- [ ] If `out.force_feedback` is null → fall through (legal pre-Wave-6
  default).
- [ ] If `backend = "uinput"` + `kind = "rumble"` → legal (explicit form
  of default).
- [ ] If `backend = "uinput"` + `kind = "pid"` →
  `error.InvalidConfig` (PID needs UHID).
- [ ] If `backend = "uhid"` + `kind = "rumble"` →
  `error.InvalidConfig` (Wave 5+ scope; not Wave 6).
- [ ] If `backend = "uhid"` + `kind = "pid"`:
  - Require `out.imu` is present (primary card must be on UHID via
    Wave 3 routing). If absent → `error.InvalidConfig`.
  - Legal otherwise.
- [ ] Any unknown backend / kind string → `error.InvalidConfig`.

### T5d: Validate tests

- [ ] In `src/config/device.zig` test block, add 6 cases:
  - **`test "validate: force_feedback absent (default) is legal"`**
  - **`test "validate: backend=uinput + kind=rumble is legal"`**
  - **`test "validate: backend=uinput + kind=pid is error.InvalidConfig"`**
  - **`test "validate: backend=uhid + kind=rumble is error.InvalidConfig"`**
  - **`test "validate: backend=uhid + kind=pid + [output.imu] absent is error.InvalidConfig"`**
  - **`test "validate: backend=uhid + kind=pid + [output.imu] present is legal"`**

### T5e: TOML round-trip parser test

- [ ] **`test "force_feedback: TOML round-trip"`** — parse:
  ```
  [output.imu]
  backend = "uhid"
  [output.force_feedback]
  backend       = "uhid"
  kind          = "pid"
  clone_vid_pid = true
  ```
  Verify `cfg.output.?.force_feedback.?.backend == "uhid"`,
  `cfg.output.?.force_feedback.?.kind == "pid"`,
  `cfg.output.?.force_feedback.?.clone_vid_pid == true`.

### T5f: Build + test gate

- [ ] `zig build test` green.

---

## T6: Layer 1 e2e

Files: `src/test/wave6_pidff_e2e_test.zig` (new),
`src/test/harness/uhid_simulator.zig`, `build.zig`

### T6a: Extend `UhidSimulator` with `injectOutput`

- [ ] In `src/test/harness/uhid_simulator.zig`, add:
  ```zig
  pub fn injectOutput(
      self: *UhidSimulator,
      report_id: u8,
      payload: []const u8,
  ) !void {
      // hand-craft struct uhid_event with type = UHID_OUTPUT,
      // payload.output.size = payload.len,
      // payload.output.data[0] = report_id,
      // payload.output.data[1..] = payload,
      // posix.write(self.uhid_fd_writer_side, &event_bytes)
  }
  ```
- [ ] If the simulator doesn't currently expose a write-side fd to its
  own `/dev/uhid`, plumb one (the simulator opens `/dev/uhid`; the same
  fd is the channel kernel uses both directions).

### T6b: New file `src/test/wave6_pidff_e2e_test.zig`

- [ ] Imports:
  ```zig
  const std = @import("std");
  const posix = std.posix;
  const testing = std.testing;
  const DeviceInstance = @import("../device_instance.zig").DeviceInstance;
  const UhidSimulator = @import("harness/uhid_simulator.zig").UhidSimulator;
  const FfbForwarder = @import("../io/ffb_forwarder.zig").FfbForwarder;
  ```

### T6c: Test 1 — happy path round-trip

- [ ] **`test "wave6: PID round-trip — Set Effect / Effect Operation / Device Control"`**:
  ```
  1. Build DeviceConfig: [device].vid=0x11FF, [device].pid=0x1211 (Moza R5);
     [output.imu].backend = "uhid"; [output.force_feedback].backend = "uhid",
     kind = "pid", clone_vid_pid = true.
  2. Open simulator (provides /dev/uhid endpoint padctl reads from).
  3. Open posix.pipe2 for "physical hidraw" — pass write-end as
     test_physical_hidraw_fd to DeviceInstance.init.
  4. DeviceInstance.init(... phys_key="sim", uniq_counter=&ctr ...).
  5. Drain UHID_CREATE2 from simulator side; verify vendor=0x11FF,
     product=0x1211 (cloned).
  6. simulator.injectOutput(report_id=1, payload=<13 bytes>).
  7. Run event_loop one tick (ppoll dispatch).
  8. posix.read(physical_hidraw_pipe.read_end) → assert bytes byte-equal
     to injected payload.
  9. Repeat for report_id=10 (Effect Operation, ~3 bytes).
  10. Repeat for report_id=11 (Device Control, ~1 byte).
  11. Assert FfbForwarder.writes_total == 3, drops_eagain == 0.
  ```

### T6d: Test 2 — incomplete descriptor rejection

- [ ] **`test "wave6: incomplete PID descriptor → error.IncompletePidDescriptor"`**:
  Construct a builder fixture that intentionally omits one of the 12
  reports (use a mock `buildForPidIncomplete` test helper or directly
  invoke `validateMandatoryReports` on a 11-of-12 byte sequence).
  Assert error.

### T6e: Test 3 — EAGAIN drop counter

- [ ] **`test "wave6: physical hidraw EAGAIN → drops_eagain incremented"`**:
  Fill the test pipe to capacity before injecting an output, then inject;
  assert `forwarder.drops_eagain >= 1` and no panic.

### T6f: Test 4 — disabled state on close

- [ ] **`test "wave6: physical hidraw close → forwarder disabled"`**:
  After successful round-trip, close the physical hidraw write-end,
  inject another output, run tick, assert `forwarder.state == .disabled`.

### T6g: Register in `build.zig`

- [ ] Add `src/test/wave6_pidff_e2e_test.zig` to test step.

### T6h: Build + test gate

- [ ] `zig build test` green.
- [ ] `PADCTL_TEST_REQUIRE_UHID=1 zig build test` green (Layer 1 should
  not require Layer 2 escalation; if a test path needs `/dev/uhid`, the
  Wave-3-pattern soft-gate applies).

---

## T7: Real-hardware matrix + Phase B CI workflow

Files: `devices/<wheel>.toml` (one or more canary opt-in),
`.github/workflows/wave6-pidff-probe.yml` (new)

### T7a: Per-device canary TOML

- [ ] At least one of:
  - `devices/ardor-silverstone.toml`
  - `devices/moza-r5.toml`
  - `devices/logitech-g29.toml`
  - `devices/thrustmaster-tmx.toml`

  Each declares:
  ```toml
  [device]
  name = "<wheel name>"
  vid  = <wheel vid>
  pid  = <wheel pid>

  [output.imu]
  backend = "uhid"

  [output.force_feedback]
  backend       = "uhid"
  kind          = "pid"
  clone_vid_pid = true

  [output]
  # ...wheel button + axis mapping (see existing devices/*.toml conventions)...
  ```
- [ ] Hardware tester runs `padctl install` + plugs wheel + runs
  `fftest /dev/input/eventN` per the manual test plan in
  `design.md §T7b`.

### T7b: Manual test plan (in PR description)

- [ ] Documented evidence per AC8-1 .. AC8-3:
  - `dmesg` line showing `hid-(universal-)pidff` or vendor driver bind
  - `cat /sys/class/input/event*/device/capabilities/ff` non-zero
  - `fftest` execution log
  - `usbmon` capture (optional but encouraged)

### T7c: Phase B CI workflow

- [ ] New file `.github/workflows/wave6-pidff-probe.yml`:
  ```yaml
  name: wave6-pidff-probe
  on:
    schedule:
      - cron: '0 6 * * 1'
    workflow_dispatch:
  jobs:
    probe-5-15:
      runs-on: ubuntu-22.04
      steps:
        - uses: actions/checkout@v4
        - run: |
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
            pip3 install hid-tools
        - run: sudo modprobe uhid
        - run: |
            sudo PROBE_VID=0x046d PROBE_PID=0xc24f PROBE_NAME="G29 probe" \
              python3 tools/wave6-probe/pidff_probe.py | tee probe-5-15.log
        - run: grep -q '"BUSTYPE_ACCEPTED": true' probe-5-15.log
        - uses: actions/upload-artifact@v4
          with:
            name: probe-5-15.log
            path: probe-5-15.log
  ```
- [ ] First scheduled run: maintainer monitors. Failure forces Stage 3
  fallback to Option (a) on 5.15.

### T7d: Update Wave 6 wave-plan + roadmap

- [ ] Out-of-band docs-repo PR (D: prefix): mark Wave 6 exit conditions
  AC8-1 .. AC8-6 in `engineering/phase-13-wave-plan.md` per actual
  T7 evidence collected.

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec via `openplan-archive --yes` (after PR-D
  lands).
- [ ] Update `planning/phase-13.md` (docs-repo) +
  `engineering/phase-13-wave-plan.md` (Wave 6 status checkboxes → done).
- [ ] PR body for each (PR-A through PR-D) includes:
  - Link to `decisions/015-uhid-imu-migration.md@92caade` Stage 3 exit
    conditions
  - Link to `tools/wave6-probe/RESEARCH-REPORT.md` for empirical basis
  - Local-run log for Layer 1 e2e (`zig build test` EXIT=0)
  - For PR-D: `fftest` evidence (T7b) and CI workflow first-run log
  - Release-note draft mentioning `[output.force_feedback]` schema +
    VID/PID cloning behaviour + `clone_vid_pid` opt-in + 5.15 known-good
    matrix
