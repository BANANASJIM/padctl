# Brief: Phase 13 Wave 3 — supervisor → UhidDevice routing (T1-T5)

## Why

ADR-015 (accepted, 2026-04-13) decided to migrate SDL-visible output devices
(primary gamepad + IMU) from uinput to UHID so that two-card `EVIOCGUNIQ`
pairing — which uinput cannot satisfy because its kernel driver never assigns
`dev->uniq` — unblocks SDL `GetSensor()` and Steam sensor companion detection.
Waves 1/2/4 have landed the vtable, descriptor builder, systemd authorization
and CI uniq-pairing gate; nothing yet instantiates `UhidDevice` from
`supervisor.zig` / `device_instance.zig`.

Wave 3 is the routing wave: introduce TOML-driven backend selection so that
`[output.imu].backend = "uhid"` causes both the primary pad and the IMU to be
materialized as `UhidDevice`. Default remains `"uinput"` — a zero-regression
path for every existing `devices/*.toml`.

Closing this wave unblocks:

- **issue #81** (SDL IMU sensor pairing) — AC1 local-only SDL validation plus
  AC4 `EVIOCGUNIQ` CI-equivalent test now exercise a real `DeviceInstance`
  routing path, not hand-built `UHID_CREATE2` payloads
- **issue #82** (wheel HID PID FFB) — Wave 6 prerequisite; routing is the
  architectural seam that lets Stage 3 add a `hid-pidff`-bound PID collection
- **Wave 5** full-device regression matrix — Wave 5 can only flip canary
  TOMLs once routing exists

## Scope

| Task | Summary | File (primary) | LoC |
|------|---------|----------------|-----|
| T1 | `ImuConfig` struct + `OutputConfig.imu` field + `validate` rule (`backend="uinput"` + `[output.imu]` present → `error.InvalidConfig`) + unit tests | `src/config/device.zig` | ~60 |
| T2 | `UinputDevice.initBoxed(alloc, cfg) !*UinputDevice` heap-alloc wrapper so owner union holds pointers uniformly | `src/io/uinput.zig` | ~30 |
| T3 | `DeviceInstance` owner union + `primary_output` / `imu_output` refactor — behaviour-identical when `backend="uinput"` (existing tests green) | `src/device_instance.zig` | ~120 |
| T4 | `buildUniq` pure function + new `src/io/uniq.zig` + Layer 0 test; supervisor routing switch (`UhidDevice.init` vs `UinputDevice.initBoxed`) | `src/io/uniq.zig` (new), `src/device_instance.zig`, `src/supervisor.zig` | ~150 |
| T5 | `UhidDescriptorBuilder.buildForImu` + golden-file test; event-loop IMU emit dispatch; Layer 1 `supervisor_uhid_routing_test.zig` (new); extend Layer 2 `uhid_uniq_pairing_test.zig` to exercise real `DeviceInstance` | `src/io/uhid_descriptor.zig`, `src/event_loop.zig`, `src/test/supervisor_uhid_routing_test.zig` (new), `src/test/uhid_uniq_pairing_test.zig` | ~200 |

Dependency graph: `T1 → T4`, `T2 → T3 → T4 → T5`. T1 + T2 parallel.
Total: one PR, 5 commits, ~560 LoC including tests.

## Success Criteria

- `[output.imu].backend = "uhid"` causes both primary pad and IMU to be
  instantiated as `UhidDevice`; both share byte-identical uniq strings
  (`padctl/<device-id>-<instance>` format)
- `[output.imu].backend = "uinput"` is the default; with the field absent,
  every existing `devices/*.toml` behaves byte-identically to pre-Wave-3
- `validate` rejects the illegal combination `backend = "uinput"` +
  `[output.imu]` present with `error.InvalidConfig`
- `zig build test` (Layer 0+1) passes with zero privileges, zero `/dev/uhid`
  access, no regressions in any existing test
- `PADCTL_TEST_REQUIRE_UHID=1 zig build test` (Layer 2, local/CI gated)
  exercises a real `DeviceInstance` — not raw `UHID_CREATE2` payloads — and
  asserts primary + IMU `EVIOCGUNIQ` are `std.mem.eql`

## Out of Scope

- rumble / aux / touchpad backend switching (Wave 6+)
- `devices/*.toml` canary opt-in (separate PR at the start of Wave 5)
- CLI flag for backend override (deliberately excluded — TOML only)
- Issue #126 Steam Deck lizard-mode real-hardware verification (Wave 5)
- ADR-015 Stage 2 / Stage 3 content (PID, `hid-pidff` bustype empiricism)
- `UhidDevice.pollFf` stub replacement (rumble through UHID is Wave 6)

## References

- Engineering plan: `engineering/phase-13-wave-plan.md@35c9c36` (docs-repo, §Wave 3)
- Design decision: `decisions/015-uhid-imu-migration.md@92caade` (docs-repo, ADR-015 accepted)
- Crystallised scope: `_agent/state/needs-snapshot.md@41f9bde` (docs-repo)
- Final review: `review/reviewer-phase-14.md@6286a4e` (ACCEPT, 0 BLOCKING)
- Design principles: `design/principles.md` P1, P8, P9 (docs-repo)
- Predecessor waves: PR #127 (Wave 1), PR #132 (Wave 2), PR #140 (Wave 4),
  PR #154/#155 (B2/B3 CI + test hygiene), PR #157 (B4 `applyTarget`)

## Dependencies Satisfied

- Wave 1 (`src/io/uhid.zig` vtable + simulator harness) — PR #127 merged
- Wave 2 (`UhidDescriptorBuilder.buildFromOutput`) — PR #132 merged
- Wave 4 (`/dev/uhid` systemd `DeviceAllow` + udev + audit 6 HIGH) — PR #140 merged
- B2 (`PADCTL_TEST_REQUIRE_UHID=1` CI auto-set) — PR #154 merged
- B3 (`sendCreate` uniq byte-pin tests) — PR #155 merged
- B4 (`applyTarget` dispatch extraction) — PR #157 merged
- B5 (`InstallPlan` struct extraction) — PR #156 merged
