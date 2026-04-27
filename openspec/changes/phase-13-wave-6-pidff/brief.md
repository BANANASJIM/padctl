# Brief: Phase 13 Wave 6 — HID PID force feedback passthrough (T1-T7)

## Why

ADR-015 (`decisions/015-uhid-imu-migration.md@92caade`) Stage 3 closes
issue #82 (racing wheel HID PID FFB through padctl): padctl's UHID virtual
device emits a HID descriptor that includes a complete PID output collection,
kernel `hid-universal-pidff` (or kernel-5.15 vendor drivers
`hid-lg4ff` / `hid-tmff` / `hid-sony`) binds via modalias, the kernel writes
FFB output reports through `UHID_OUTPUT` events, and padctl forwards each
report byte-for-byte to the physical wheel's hidraw fd. No FFB remapping,
no payload mutation — pure passthrough.

Stage 3's single ADR-level entry blocker — "does kernel `hid-pidff` accept
`bus = BUS_USB` on a virtual UHID device?" — was empirically resolved by the
2026-04-24 probe (`research/wave6-pidff-probe@TBD-on-merge`):
kernel 6.18.9 `hid-universal-pidff` binds via the `hid:b0003g*v...p...`
modalias on a UHID device with `bus = BUS_USB`; kernel 5.15 source has no
bustype filter in the `hid_pidff_init` callers (`hid-lg4ff`/`hid-tmff`/
`hid-sony`), and the bind path is even simpler there. Stage 3 path is viable.

Wave 6 also closes two probe-discovered constraints downstream of bustype:

1. **Descriptor completeness**: `pidff_find_reports()` requires the 8 kernel-mandatory
   PID reports (`PID_REQUIRED_REPORTS 8`: IDs 1, 7, 10, 11, 12, 13, 14, 15).
   Missing any → `-ENODEV` → `Error initialising force feedback` → on kernel 6.18
   a NULL deref OOPS in `hid_hw_open+0x71` (probe Run 2). Wave 6's descriptor
   builder ships all 8 mandatory reports plus 5 optional ones.
2. **VID/PID cloning**: padctl's default UHID VID/PID `FADE:C00x` is not in
   the `hid-universal-pidff` alias table. Without the wheel's real VID/PID,
   kernel falls through to `hid-generic` and FFB never initialises. Wave 6
   adds `[output.force_feedback].clone_vid_pid` opt-in.

Closing this wave unblocks:

- **issue #82** (HID PID FFB on Logitech G29 / Moza R5 / Cammus / Thrustmaster
  TMX / Ardor Silverstone) — Stage 3 AC8-1 .. AC8-5 covered by T1-T6, AC8-6
  (Phase B 5.15 CI re-verification) by T7
- **ADR-015 Stage 3 / Phase 13 close-out** — last remaining wave per
  `engineering/phase-13-wave-plan.md@fb1a3d6` parallelism overview section

## Scope

| Task | Summary | File (primary) | LoC |
|------|---------|----------------|-----|
| T1 | `UhidDescriptorBuilder.buildForPid` — PID output collection, 8 kernel-mandatory + 5 optional reports, defensive 8-mandatory validator, byte-exact golden test | `src/io/uhid_descriptor.zig` | ~250 |
| T2 | VID/PID cloning — `OutputConfig.force_feedback.clone_vid_pid` opt-in; primary UHID card vendor/product overridden from `[device]` when true; udev rules emit per-cloned-VID/PID match | `src/config/device.zig`, `src/device_instance.zig`, `src/cli/install.zig` | ~150 |
| T3 | `UHID_OUTPUT` event handler — `src/io/uhid.zig` adds `pollOutputReport()` + `onOutputReport(report_id, payload)` callback; payload-parse unit tests | `src/io/uhid.zig`, `src/io/uhid_types.zig` | ~120 |
| T4 | `FfbForwarder` — write FFB bytes to physical hidraw fd, EAGAIN/EACCES/ENODEV classification, rate ceiling + dropped-packet counter | `src/io/ffb_forwarder.zig` (new), `src/supervisor.zig`, `src/io/hidraw.zig` | ~250 |
| T5 | `[output.force_feedback]` schema — `backend: "uinput"\|"uhid"` (default `"uinput"`), `kind: "rumble"\|"pid"` (default `"rumble"`), `clone_vid_pid: bool` (default `false`), validate matrix | `src/config/device.zig` | ~120 |
| T6 | Layer 1 e2e — extend `UhidSimulator` (write-side capture + injectable `UHID_OUTPUT`); new `wave6_pidff_e2e_test.zig` round-trips Set Effect / Effect Operation / Device Control | `src/test/wave6_pidff_e2e_test.zig` (new), `src/test/harness/uhid_simulator.zig` | ~200 |
| T7 | Real-hardware matrix + Phase B CI workflow — at least one of (Logitech G29, Moza R5, Thrustmaster TMX, Ardor Silverstone) on kernel 5.15 + 6.x, `fftest` `FF_CONSTANT/SPRING/DAMPER`; `.github/workflows/wave6-pidff-probe.yml` weekly cron | `devices/*.toml` (canary opt-in), `.github/workflows/wave6-pidff-probe.yml` | ~doc-only |

Dependency graph: `T1 → T6`, `T2 → T6`, `T5 → T1, T2`, `T3 → T4 → T6`,
`T1+T2+T5+T6 → T7`. T1 / T3 parallel after T5; T2 + T5 parallel.
Total: ~1090 LoC (code + Layer 0+1 tests). PR cadence: 3-4 PRs serial
(T1+T3 / T2+T5 / T4+T6 / T7 doc-only).

Note: revised upward from the engineering plan's rough estimate
(~300-500 LoC) per detailed sub-task breakdown. The plan estimate
predates the explicit T4 `FfbForwarder` module and the T5 schema
validate matrix tests.

## Success Criteria

- `[output.force_feedback].backend = "uhid"` + `kind = "pid"` causes the
  primary UHID card to ship a complete 12-report PID descriptor; kernel
  `hid-universal-pidff` (or kernel-5.15 vendor driver) binds via modalias
- `[output.force_feedback].clone_vid_pid = true` causes the primary UHID
  card's `vendor` / `product` fields to inherit from `[device].vid` /
  `[device].pid` (and `install` emits matching udev rules)
- `UHID_OUTPUT` events from kernel are routed to `FfbForwarder` and
  byte-faithfully written to the physical device's hidraw fd
- Default `[output.force_feedback].backend = "uinput"` is zero-regression
  for every existing `devices/*.toml` (rumble path bit-identical)
- `zig build test` Layer 0+1 passes with zero privileges, zero `/dev/uhid`
  access, no regressions in any existing test
- `PADCTL_TEST_REQUIRE_UHID=1 zig build test` Layer 1 e2e (T6) round-trips
  `UHID_CREATE2 → UHID_OUTPUT → hidraw write` with byte equality on at
  least three PID report classes (Set Effect, Effect Operation, Device
  Control)
- T7 manual matrix: at least one PID-compatible wheel on at least one
  kernel-version path produces `EVIOCGBIT(EV_FF) != 0` on the padctl
  evdev node, plus a tester-perceived FFB effect under `fftest`

## Out of Scope

- FFB remapping / filtering / curve shaping (ADR-015 Stage 3 §"Option (a)"
  explicitly forbids — padctl is byte-faithful only)
- Mixed devices (rumble + PID FFB on the same card) — degrade to Option (a)
  `block_kernel_drivers` + record deviation; not implemented in T1-T7
- Vendor-specialised drivers beyond the `hid-universal-pidff` default path —
  `hid-lg4ff` / `hid-tmff` / `hid-sony` matrix entries via T7 only as
  opportunistic kernel-5.15 verification, not a guaranteed multi-driver
  abstraction
- Steam / Proton-specific FFB quirks — outside padctl
- FF_RUMBLE-only devices on `backend = "uhid"` — Wave 5 / a future wave; in
  Wave 6 the existing rumble path (`backend = "uinput"`) remains canonical
- Legal / branding policy review of VID/PID cloning — documented in
  design.md §VID/PID cloning rationale; release-note copy is a maintainer
  task, not part of T1-T7

## References

- Engineering plan: `engineering/phase-13-wave-plan.md@fb1a3d6` (docs-repo,
  Wave 6 section, lines 197-294)
- Design decision: `decisions/015-uhid-imu-migration.md@92caade` (docs-repo,
  ADR-015 Stage 3 + Unresolved-Items section)
- Probe research: `tools/wave6-probe/RESEARCH-REPORT.md` (code-repo
  `research/wave6-pidff-probe` worktree, 2026-04-24)
- Predecessor waves: PR #127 (Wave 1 vtable), PR #132 (Wave 2 descriptor
  builder), PR #140 (Wave 4 systemd authorization + audit), PR #154/#155/
  #156/#157 (B2-B5 hardening), PR #159/#160 (Wave 3 routing + udev rule)

## Dependencies Satisfied

- Wave 1 (`src/io/uhid.zig` vtable + `UhidSimulator`) — PR #127 merged
- Wave 2 (`UhidDescriptorBuilder.buildFromOutput`) — PR #132 merged
- Wave 3 (`supervisor → UhidDevice` routing, owner union, IMU emit) —
  PR #159/#160 merged on main `5951834`
- Wave 4 (`/dev/uhid` `DeviceAllow` + udev `KERNELS=="uhid"` + audit) —
  PR #140 merged
- Probe (`tools/wave6-probe/RESEARCH-REPORT.md`) — `research/wave6-pidff-probe`
  worktree, ADR-015 Stage 3 entry condition empirically met

## Dependencies Outstanding (entry condition for T7 only)

- **Wave 5 hardware regression matrix** — `backend = "uhid"` rumble parity on
  Flydigi Vader 2/3/4/5, DualSense passthrough, Steam Deck. Wave 5 is a
  Wave-3-driven canary opt-in across `devices/*.toml`; T1-T6 do not depend
  on it (default `backend = "uinput"` keeps all existing TOMLs on the
  proven path), but T7's per-device opt-in canary cannot ship until Wave 5
  has cleared rumble parity for the underlying TOML
- **Probe PR merge** — `research/wave6-pidff-probe` PR into code-repo main.
  Wave 6 cites the probe as authority; merging it pins the SHA referenced
  in design.md
- **At least one PID-compatible wheel** physically accessible to maintainer
  or external tester (Ardor Silverstone 11FF:F045, Moza R5 11FF:1211,
  Logitech G29 046D:C24F, or Thrustmaster TMX). Without hardware, T7 cannot
  produce AC8-3 evidence
