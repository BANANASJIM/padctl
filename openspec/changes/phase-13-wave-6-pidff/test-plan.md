# Test Plan: Phase 13 Wave 6 — HID PID force feedback passthrough (T1-T7)

Three test layers per ADR-015
(`decisions/015-uhid-imu-migration.md@92caade`) and the engineering plan's
test-layer matrix (`engineering/phase-13-wave-plan.md@fb1a3d6` §Wave 6):

- **Layer 0** — pure functions, zero fd, zero privilege (`zig build test`)
- **Layer 1** — in-process fixture using `posix.pipe2` + `UhidSimulator`
  to capture write-side events and inject `UHID_OUTPUT`; zero-privilege,
  CI main line
- **Layer 2** — real `/dev/uhid` open + real wheel hardware; soft gate
  via `PADCTL_TEST_REQUIRE_UHID=1`; Phase B CI workflow runs the probe
  script on `ubuntu-22.04` (kernel 5.15) weekly

All Layer 0+1 tests MUST pass on CI `ubuntu-22.04` with zero privileges.
Layer 2 is soft-gated per the Wave 1 / Wave 4 / Wave 3 pattern (PR #127,
PR #140, PR #154 B2, PR #160).

## Layer 0: Pure Unit

### T1 — `UhidDescriptorBuilder.buildForPid`

- [ ] **TP1**: `buildForPid(alloc, cfg_with_one_axis, ffb_cfg{kind=pid})`
  returns a non-empty descriptor; `validateMandatoryReports(result)`
  returns success (12 reports present).
- [ ] **TP2**: Output bytes are byte-equal to an inline golden reference
  (Moza R5 case, pinned by implementer on first successful real-hardware
  run when kernel logs show `hid-universal-pidff` FFB init without
  `Error initialising force feedback`). Probe Run 2 evidence covers
  bustype acceptance + driver binding ONLY — it does not supply a
  working descriptor (probe Run 2's 7-of-12 descriptor caused FFB init
  failure + kernel NULL-deref; the implementer must build a complete
  12-report descriptor per USB HID PID 1.01 §4.x).
- [ ] **TP3**: `validateMandatoryReports` on a hand-crafted 11-of-12
  descriptor (one report ID stripped) returns
  `error.IncompletePidDescriptor`.
- [ ] **TP4**: Output descriptor length ≤ `HID_MAX_DESCRIPTOR_SIZE` (4096)
  for the maximum-axis-count + 12-PID-report stress case.
- [ ] **TP5**: Descriptor contains all 12 mandatory `0x85 NN` Report ID
  prefixes — direct byte scan asserts presence of each NN ∈
  `{ 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15 }`.

### T5 — `[output.force_feedback]` schema validate

- [ ] **TP6**: `validate(cfg)` returns success when
  `cfg.output.force_feedback == null` (default / pre-Wave-6 path).
- [ ] **TP7**: `validate(cfg)` returns success when
  `force_feedback.backend = "uinput"` + `kind = "rumble"`.
- [ ] **TP8**: `validate(cfg)` returns `error.InvalidConfig` when
  `backend = "uinput"` + `kind = "pid"` (PID requires UHID).
- [ ] **TP9**: `validate(cfg)` returns `error.InvalidConfig` when
  `backend = "uhid"` + `kind = "rumble"` (Wave 5+ scope, not Wave 6).
- [ ] **TP10**: `validate(cfg)` returns `error.InvalidConfig` when
  `backend = "uhid"` + `kind = "pid"` + `[output.imu]` absent
  (primary-card UHID routing requires Wave 3's `[output.imu]`).
- [ ] **TP11**: `validate(cfg)` returns success when
  `backend = "uhid"` + `kind = "pid"` + `[output.imu]` present.
- [ ] **TP12**: `validate(cfg)` returns `error.InvalidConfig` for unknown
  `backend` or `kind` strings (fail-closed).
- [ ] **TP13**: `validate(cfg)` returns `error.InvalidConfig` when
  `clone_vid_pid = true` AND `cfg.device.vid == 0` (cloning meaningless).
- [ ] **TP14**: TOML round-trip: parsing
  ```
  [output.imu]
  backend = "uhid"
  [output.force_feedback]
  backend       = "uhid"
  kind          = "pid"
  clone_vid_pid = true
  ```
  produces matching field values on `cfg.output.?.force_feedback.?`.
- [ ] **TP15**: TOML round-trip: missing `[output.force_feedback]` leaves
  `cfg.output.?.force_feedback == null`.

### T3 — `pollOutputReport` parser

- [ ] **TP16**: Hand-crafted UHID_OUTPUT event bytes written to a pipe2
  write-end, `pollOutputReport(buf)` from read-end returns an
  `OutputReport` with `report_id == <expected>` and `data` byte-equal
  to the injected payload.
- [ ] **TP17**: Non-`UHID_OUTPUT` event bytes (e.g. `UHID_START` =
  type 4) → `pollOutputReport` returns `null`.
- [ ] **TP18**: Empty (zero-byte) `UhidOutputReq.size = 0` → `data` slice
  is empty, `report_id` byte read defensively (or returns null with
  documented behaviour).

### T4 — `FfbForwarder`

- [ ] **TP19**: `forward(report)` writes `report.data` byte-equal to a
  pipe2 write-end; `posix.read(read_end)` confirms.
- [ ] **TP20**: `writes_total` increments by 1 per successful forward.
- [ ] **TP21**: `forward` on a full pipe (kernel buffer at capacity) →
  `drops_eagain += 1`, `state` unchanged (still `.active`).
- [ ] **TP22**: `forward` after the write-side fd is closed (or after
  receiving EACCES/ENODEV from kernel) → `state = .disabled`, subsequent
  forwards no-op.
- [ ] **TP23**: After `state = .disabled`, `forward` does NOT increment
  `drops_eagain` and does NOT call `posix.write`.

### T2 — `clone_vid_pid` runtime effect (unit-level)

- [ ] **TP24**: With `clone_vid_pid = true`, the `UhidCreateOptions`
  passed to `UhidDevice.init` for the primary card has
  `vendor == cfg.device.vid` and `product == cfg.device.pid`.
- [ ] **TP25**: With `clone_vid_pid = false`, the same options have
  `vendor == 0xFADE` and `product == 0xC001` (or the established
  daemon-identity constants).
- [ ] **TP26**: IMU card vendor/product unchanged regardless of
  `clone_vid_pid` value (always `FADE:C002`).

### T2 — install udev rule emission

- [ ] **TP27**: Install rule generator with one TOML having
  `clone_vid_pid = true` (vid=0x11FF, pid=0x1211) emits one
  `KERNELS=="uhid", ... ENV{ID_VENDOR_ID}=="11ff", ENV{ID_MODEL_ID}=="1211", TAG+="uaccess"`
  rule, in addition to the existing wildcard rule.
- [ ] **TP28**: Multiple TOMLs with same (vid, pid) → emits exactly one
  per-VID/PID rule (deduplication).
- [ ] **TP29**: TOML with `clone_vid_pid = false` does NOT emit a
  per-VID/PID rule.

## Layer 1: Simulator + pipe2 (CI main line)

Fixture: `UhidSimulator` (extended with `injectOutput`) on the kernel
side; `posix.pipe2` for the "physical hidraw" channel; test seam fds
threaded into `DeviceInstance.init` via `InitOptions` (mirrors Wave 3
`test_primary_uhid_fd` pattern).

### T6 — `wave6_pidff_e2e_test.zig` (new)

- [ ] **TP30**: **`test "wave6: PID round-trip — Set Effect / Effect Operation / Device Control"`**:
  - Build `DeviceConfig` with `[device].vid = 0x11FF, .pid = 0x1211`,
    `[output.imu].backend = "uhid"`,
    `[output.force_feedback].backend = "uhid", kind = "pid",
     clone_vid_pid = true`
  - Open simulator and pipe2 for physical-hidraw write-side
  - `DeviceInstance.init` with test seam fds
  - Decode `UHID_CREATE2` from simulator side; assert vendor/product
    match cloned wheel VID/PID
  - `simulator.injectOutput(report_id = 1, payload = <13 bytes>)`
  - Run event_loop one tick
  - `posix.read(physical_hidraw_pipe.read_end)` → bytes byte-equal to
    payload
  - Repeat for report_id = 10 (~3 bytes), report_id = 11 (~1 byte)
  - Assert `FfbForwarder.writes_total == 3`
- [ ] **TP31**: **`test "wave6: incomplete PID descriptor → IncompletePidDescriptor"`**:
  - Construct an explicitly-broken descriptor (use a test-only helper
    that emits 11 of 12 reports) and pass through
    `validateMandatoryReports`; assert
    `error.IncompletePidDescriptor`.
- [ ] **TP32**: **`test "wave6: physical hidraw EAGAIN → drops_eagain"`**:
  - Pre-fill the physical hidraw pipe to capacity (write a dummy
    64KB block).
  - `simulator.injectOutput` once; run event_loop tick.
  - Assert `forwarder.drops_eagain >= 1`.
- [ ] **TP33**: **`test "wave6: physical hidraw close → forwarder disabled"`**:
  - Successful round-trip first.
  - `posix.close(physical_hidraw_pipe.write_end)`.
  - `simulator.injectOutput` once; run event_loop tick.
  - Assert `forwarder.state == .disabled`.
- [ ] **TP34**: **`test "wave6: clone_vid_pid=false uses daemon identity"`**:
  - Same fixture but `clone_vid_pid = false`; assert decoded
    `UHID_CREATE2` carries `vendor = 0xFADE`, `product = 0xC001`.

### T3/T4 integration sentinels

- [ ] **TP35**: Existing `supervisor_uhid_grace_integration_test.zig`
  passes unchanged — Wave 6 changes do not alter the rebind/grace
  lifetime path.
- [ ] **TP36**: Existing `full_pipeline_e2e_test.zig` passes unchanged
  — Wave 6 default-off path is byte-diff-zero against pre-Wave-6.

## Layer 2: Real hardware + Phase B CI

### T7 — Real wheel hardware (manual)

For at least one of (Logitech G29, Moza R5, Thrustmaster TMX, Ardor
Silverstone):

- [ ] **TP37**: AC8-1 — kernel binds `hid-universal-pidff` (or
  `hid-lg4ff` / `hid-tmff` on 5.15 + appropriate VID/PID) to the
  padctl UHID card.
  Evidence: `dmesg | grep -E 'hid-(universal-)?pidff|hid-lg4ff|hid-tmff'`
  shows bind line with `padctl/<uniq>` suffix.
- [ ] **TP38**: AC8-2 — `cat /sys/class/input/event*/device/capabilities/ff`
  on the padctl evdev node returns a non-zero bitmap (at least one of
  `FF_CONSTANT`, `FF_SPRING`, `FF_DAMPER`, `FF_PERIODIC` bits set).
- [ ] **TP39**: AC8-3 — `fftest /dev/input/eventN`:
  - Run "Constant Force" → tester reports felt force in wheel
  - Run "Spring" → tester reports centring force
  - Run "Damper" → tester reports damping
  At least one of three required.
- [ ] **TP40**: AC8-4 — kernel 6.x environment (local Arch / Ubuntu 24.04
  / Fedora 40+) AND kernel 5.15 environment (Phase B CI workflow OR
  ubuntu-22.04 host with G29 binding `hid-lg4ff`). Both produce
  TP37 + TP38 + TP39 evidence.
- [ ] **TP41**: AC8-5 — every Wave 5 device TOML in
  `backend = "uinput"` default path produces byte-identical rumble
  behaviour vs pre-Wave-6 (Wave 5 hardware regression matrix
  evidence).

### T7c — Phase B CI workflow

- [ ] **TP42**: AC8-6 —
  `.github/workflows/wave6-pidff-probe.yml` runs weekly on
  `ubuntu-22.04` (kernel 5.15) using G29 VID/PID
  (`PROBE_VID=0x046d PROBE_PID=0xc24f`); first run reports
  `BUSTYPE_ACCEPTED=true` and uploads `probe-5-15.log` artifact.
- [ ] **TP43**: Workflow failure (any week reporting
  `BUSTYPE_ACCEPTED=false`) escalates to maintainer — actionable signal
  that 5.15 behaviour has regressed.

## Regression Sentinels

With `[output.force_feedback]` absent (every existing
`devices/*.toml`), the entire suite must be byte-diff-zero against
pre-Wave-6:

- [ ] **TP44**: `zig build test` total pass count unchanged; no test
  changes status from pass to skip (or vice versa).
- [ ] **TP45**: `full_pipeline_e2e_test.zig` — green.
- [ ] **TP46**: `steam_deck_uhid_e2e_test.zig` — green (no descriptor
  change for existing configs).
- [ ] **TP47**: `uhid_all_devices_test.zig` — green (Wave 2 golden
  suite untouched; T1's `buildForPid` is a NEW path, does not alter
  `buildFromOutput`).
- [ ] **TP48**: `supervisor_uhid_grace_integration_test.zig` — green.
- [ ] **TP49**: `supervisor_uhid_routing_test.zig` (Wave 3) — green.
- [ ] **TP50**: `uhid_uniq_pairing_test.zig` (Wave 4 + Wave 3 ext) —
  green (gated by `PADCTL_TEST_REQUIRE_UHID=1` on Layer 2 only).

## ADR-015 Stage 3 Acceptance-Criteria Mapping

One row per ADR-015 Stage 3 exit condition
(`decisions/015-uhid-imu-migration.md@92caade`:39-41) plus the
Wave-6 Exit-Conditions expansion in `engineering/phase-13-wave-plan.md@fb1a3d6`:272-279:

| AC | Criterion | Covered by | Status after Wave 6 |
|----|-----------|------------|---------------------|
| AC8-1 | Target wheel binds `hid-universal-pidff` (or vendor driver) on padctl UHID | TP37 (Layer 2) | Satisfied per real-hardware run |
| AC8-2 | `EVIOCGBIT(EV_FF)` returns non-zero on padctl evdev node | TP38 (Layer 2) | Satisfied per real-hardware run |
| AC8-3 | `FF_CONSTANT` / `FF_SPRING` / `FF_DAMPER` (≥1) produces observable force on physical wheel | TP39 (Layer 2 — `fftest` + tester) | Satisfied per real-hardware run |
| AC8-4 | Both kernel 6.x AND kernel 5.15 environments covered | TP37+TP38+TP39 across two environments OR via Phase B CI workflow first run | Partial — kernel 6.x via local, kernel 5.15 via TP42 (CI) |
| AC8-5 | Wave 5 device TOMLs zero rumble regression on default path | TP41 (Wave 5 hardware matrix) + TP44 (default-off zero-diff) | Wave-5-prerequisite — Wave 6 passes through |
| AC8-6 | Phase B CI workflow merged | TP42 + TP43 | Satisfied on PR-D merge |

Stage 3 entry condition was the bustype gate, empirically resolved by
the 2026-04-24 probe (`research/wave6-pidff-probe`) and not retested
inside Wave 6.

## CI Integration

Two existing workflow files plus one new file:

- `e2e.yml` (existing) — Layer 0+1 default, runs Wave 6's Layer 0
  (TP1-TP29) and Layer 1 (TP30-TP36) on every push. No change required;
  new tests register through `build.zig` and run inside `zig build
  test` automatically.
- `install-flow.yml` (existing, PR #154 B2) — install + uninstall
  invariants; T2's udev rule changes are validated here (TP27-TP29).
- `wave6-pidff-probe.yml` (new, T7c) — Phase B 5.15 verification,
  weekly cron + workflow_dispatch. TP42 + TP43 live here.

## Test Execution Summary

| Layer | Command | Host requirement |
|-------|---------|------------------|
| 0 | `zig build test` | None (CI default `ubuntu-22.04`) |
| 1 | `zig build test` (same step) | None — uses pipe2 + simulator |
| 2 | `PADCTL_TEST_REQUIRE_UHID=1 zig build test` | `/dev/uhid` accessible |
| Real-hardware (T7) | manual: `padctl install` + plug wheel + `fftest /dev/input/eventN` | physical PID wheel |
| CI 5.15 probe | `wave6-pidff-probe.yml` weekly | `ubuntu-22.04` runner |

Final gate before each PR (PR-A through PR-D) merges:

1. Layer 0+1 green on CI (mandatory)
2. Layer 2 green on maintainer's local host (log pasted into PR
   description) for any PR that touches `src/io/uhid.zig` or
   `src/device_instance.zig` lifecycle
3. Sentinels (TP44-TP50) green → zero behavioural regression for the
   default-off path
4. PR-D additionally: T7 hardware evidence (TP37-TP39 logs) AND first
   `wave6-pidff-probe.yml` workflow run reporting
   `BUSTYPE_ACCEPTED=true`
