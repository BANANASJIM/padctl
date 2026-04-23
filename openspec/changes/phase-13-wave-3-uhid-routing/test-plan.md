# Test Plan: Phase 13 Wave 3 — supervisor → UhidDevice routing (T1-T5)

Three test layers per ADR-015 (`decisions/015-uhid-imu-migration.md@92caade`)
and the engineering plan's test matrix
(`engineering/phase-13-wave-plan.md@35c9c36` §Wave 3 test-layer matrix):

- **Layer 0** — pure functions, zero fd, zero privilege (`zig build test`).
- **Layer 1** — in-process fixture using `UhidDevice.initWithFd` +
  `posix.pipe2` pairs to capture the raw `UHID_CREATE2` / `UHID_DESTROY`
  event bytes written by the routing switch; still zero-privilege, runs on
  CI main line. `UhidSimulator` is NOT used here — it is an input-side
  harness that produces a virtual HID node, not a write-capture interceptor.
- **Layer 2** — real `/dev/uhid` open + `EVIOCGUNIQ` ioctls; soft gate via
  `PADCTL_TEST_REQUIRE_UHID=1` env var (local + CI host with UHID available).

All Layer 0+1 tests MUST pass on CI `ubuntu-22.04` with zero privileges. Layer 2
is soft-gated per the Wave 1 / Wave 4 pattern (PR #127, PR #140, PR #154 B2).

## Layer 0: Pure Unit

### T1 — `ImuConfig` / `OutputConfig` / validate

- [ ] **TP1**: `validate(cfg)` returns without error when `cfg.output.imu == null`
  (default / old TOML path).
- [ ] **TP2**: `validate(cfg)` returns without error when
  `cfg.output.imu.?.backend == "uhid"`.
- [ ] **TP3**: `validate(cfg)` returns `error.InvalidConfig` when
  `cfg.output.imu` is present AND `backend == "uinput"` (ADR-015 hard constraint).
- [ ] **TP4**: `validate(cfg)` returns `error.InvalidConfig` for any unknown
  backend string (e.g. `"xyz"`) — fail closed.
- [ ] **TP5**: TOML round-trip: parsing
  ```
  [output.imu]
  backend = "uhid"
  name    = "Pad IMU"
  ```
  produces `cfg.output.?.imu.?.backend == "uhid"` and `cfg.output.?.imu.?.name.? == "Pad IMU"`.
- [ ] **TP6**: TOML round-trip: missing `[output.imu]` section leaves
  `cfg.output.?.imu == null`.

### T2 — `UinputDevice.initBoxed`

- [ ] **TP7**: `initBoxed(testing.allocator, cfg)` returns non-null pointer;
  `std.testing.allocator` (leak-checking) reports zero leaks after
  `p.close()` + `allocator.destroy(p)`.
- [ ] **TP8**: `initBoxed` returns `error.OutOfMemory` when the allocator is
  exhausted (tested via `std.testing.FailingAllocator`).

### T4 — `buildUniq` pure function

- [ ] **TP9**: `buildUniq(alloc, "Flydigi Vader 3 Pro", "usb-0000:00:14.0-3/input0", 0)`
  output matches regex `^padctl/flydigi-vader-3-pro-[0-9a-f]{4}$` and is
  NUL-terminated (`[:0]u8`).
- [ ] **TP10**: `buildUniq(alloc, "DualSense", null, 1)` ends with `-ctr0001`.
- [ ] **TP11**: Two invocations with the same `(device_name, phys_key)` produce
  byte-identical output (`std.mem.eql`).
- [ ] **TP12**: Output length (incl NUL) is ≤ `MAX_UNIQ_LEN` (64) for every
  test input; stress with a 60-byte device name.
- [ ] **TP13**: Non-ASCII normalization — a device name containing non-ASCII
  bytes (e.g. `"Pad \xe4\xb8\xad"`) produces a device-id containing only ASCII
  alphanum and `-`.
- [ ] **TP14**: FNV-16 known-answer vector — `fnv16("abc")` returns the pinned
  reference value (protects against silent hash changes).
- [ ] **TP15**: Counter fallback advances — `buildUniq(alloc, n, null, 1)` and
  `buildUniq(alloc, n, null, 2)` differ at the counter substring.

### T5 — `UhidDescriptorBuilder.buildForImu`

- [ ] **TP16**: Default `ImuConfig{}` → descriptor bytes match an inline
  golden reference byte-exactly.
- [ ] **TP17**: Custom `accel_range = .{ -16384, 16384 }` — descriptor bytes
  at the known logical-min/max offsets match the override.
- [ ] **TP18**: Output descriptor length ≤ `HID_MAX_DESCRIPTOR_SIZE`.
- [ ] **TP19**: Descriptor contains NO `EV_KEY`-equivalent bytes — scan for
  Usage Page Button (0x09 01) and assert absence (ADR-015 §Alternatives
  hard constraint).
- [ ] **TP20**: Descriptor contains `INPUT_PROP_ACCELEROMETER` usage
  declaration.

## Layer 1: Simulator (CI main line)

### T3 — Refactor regression sentinels

- [ ] **TP21**: After T3 merges (no T4 routing yet), `full_pipeline_e2e_test.zig`
  passes unchanged. Diff against pre-Wave-3 test output: empty.
- [ ] **TP22**: `supervisor_uhid_grace_integration_test.zig` passes unchanged
  (covers rebind/grace lifetime through the refactored owner union).
- [ ] **TP23**: Every existing Layer 1 test in `src/test/*.zig` passes — the
  owner-union rewrite is behaviour-transparent.

### T5 — `src/test/supervisor_uhid_routing_test.zig` (new)

Fixture: two `posix.pipe2(.{ .NONBLOCK = true })` pairs; the write-ends are
injected as `test_primary_uhid_fd` / `test_imu_uhid_fd` into
`DeviceInstance.init` (see T5f seam). After construction, the read-ends
carry one `UhidCreate2Event` each (and one `UHID_DESTROY` each after
`deinit`). Decoding is byte-structured `UhidCreate2Event` memcpy, matching
the pattern in the existing `src/io/uhid.zig` inline tests.

- [ ] **TP24**: `DeviceInstance.init` with `[output.imu].backend = "uhid"` +
  fixture `phys_key = "sim-phys-0001"`: exactly one `UHID_CREATE2` event is
  readable from each pipe read-end (total 2).
- [ ] **TP25**: Both decoded `UHID_CREATE2` payloads carry byte-identical
  `payload.uniq` (`std.mem.eql`).
- [ ] **TP26**: Decoded uniq begins with `"padctl/"` followed by the
  normalized device name.
- [ ] **TP27**: `DeviceInstance.init` with `backend = "uinput"` (default): no
  bytes readable from either pipe (neither write-end was injected; routing
  goes through `UinputDevice.initBoxed` only).
- [ ] **TP28**: `DeviceInstance.init` with `backend = "uinput"` + `[output.imu]`
  present: returns `error.InvalidConfig` (cross-check of T1's validate).
- [ ] **TP29**: Primary `payload.rd_data[0..rd_size]` contains Usage Page
  Button bytes (`0x05 0x09`); IMU `rd_data` does not (scan both decoded
  events).
- [ ] **TP30**: `DeviceInstance.deinit` tears down both UHID cards — one
  `UHID_DESTROY` event readable from each pipe read-end (total 2) after
  `deinit` returns.

## Layer 2: Real `/dev/uhid` (soft gate)

### T5 — Extension to `src/test/uhid_uniq_pairing_test.zig`

Gate: `PADCTL_TEST_REQUIRE_UHID=1 zig build test`. Without the env var, the
test skips; with it, any failure is hard.

- [ ] **TP31**: **`test "routing: real DeviceInstance produces paired uniq
  (requires /dev/uhid)"`** — construct `DeviceConfig` with
  `[output.imu].backend = "uhid"`, call real `DeviceInstance.init`, poll sysfs
  for the two evdev nodes kernel created, `ioctl(EVIOCGUNIQ)` on both, assert
  `std.mem.eql`. Closes ADR-015 Stage 1 AC4 against production routing code.
- [ ] **TP32**: Existing Wave 4 hand-built `UHID_CREATE2` test (pre-existing)
  still green under the same gate — no regression.

## Regression Sentinels (every layer)

With `backend = "uinput"` default (the only state any existing
`devices/*.toml` produces), the entire suite must be byte-diff-zero against
pre-Wave-3:

- [ ] **TP33**: `zig build test` total pass count unchanged; no test changes
  status from pass to skip (or vice versa).
- [ ] **TP34**: `full_pipeline_e2e_test.zig` — green.
- [ ] **TP35**: `steam_deck_uhid_e2e_test.zig` — green (no descriptor change
  for existing configs).
- [ ] **TP36**: `uhid_all_devices_test.zig` — green (Wave 2 golden suite
  untouched).
- [ ] **TP37**: `supervisor_uhid_grace_integration_test.zig` — green.

## ADR-015 Acceptance-Criteria Mapping

One row per ADR-015 Stage 1 exit condition
(`decisions/015-uhid-imu-migration.md@92caade`:24-28):

| AC | Criterion | Covered by | Status after Wave 3 |
|----|-----------|------------|---------------------|
| AC1 | SDL `testcontroller` / Steam sensor panel identifies IMU (**local-only, requires X11/Wayland**) | Manual validation in Wave 5 canary; Wave 3 PR description logs local run | Pending Wave 5 — Wave 3 produces the code capability |
| AC2 | `zig build test` contains a `EVIOCGUNIQ` + `std.mem.eql` CI-equivalent signal | TP31 (Layer 2, real `DeviceInstance`) + TP25 (Layer 1, pipe-captured payload) | Satisfied — Wave 4 base extended to real routing path |
| AC3 | **Rumble paths on real hardware do not regress** (ADR-015 Stage 1 exit condition 3 — manual, per-device real-hardware matrix, local-only) | N/A at Layer 0/1/2 in Wave 3; closed by Wave 5 canary testing against the real-device matrix | **Wave 5 prerequisite — Wave 3 passes through**. Wave 3 does not touch rumble paths (ffb poll, `UinputDevice.pollFf`), so no regression is introduced, but the ADR's "real hardware verified" bar is only met by Wave 5's manual runs. Do not mark Satisfied. |
| AC4 | `zig build test` contains new `UhidDevice` unit tests + descriptor golden-file tests | TP16-TP20 (`buildForImu` golden); TP9-TP15 (`buildUniq` unit) | Satisfied |
| — | Descriptor-builder regression (Wave 2 `buildFromOutput` golden-file CI coverage remains green for every existing `devices/*.toml`) | TP36 (`uhid_all_devices_test.zig`) + TP33 (zero-diff regression sentinel) | Satisfied — Wave 3 does not change Wave 2's descriptor output. **Not a remap of AC3**; this is a separate descriptor-only guardrail for T5a's new `buildForImu` not to disturb `buildFromOutput`. |

Additional Wave 3-specific acceptance:

| Criterion | Covered by |
|-----------|------------|
| Default `backend = "uinput"` is zero-regression | TP21-TP23, TP33-TP37 |
| `backend = "uhid"` spawns 2 UHID cards with shared uniq | TP24-TP26, TP29-TP30, TP31 |
| Illegal `"uinput"` + `[output.imu]` combination rejected | TP3, TP28 |
| IMU descriptor has no `EV_KEY` (SDL `GuessDeviceClass`) | TP19, TP29 |

## Test Execution Summary

| Layer | Command | Host requirement |
|-------|---------|------------------|
| 0 + 1 | `zig build test` | None (CI default `ubuntu-22.04`) |
| 2 | `PADCTL_TEST_REQUIRE_UHID=1 zig build test` | `/dev/uhid` present + `CAP_SYS_ADMIN` or `sg input` membership |

Final gate before merge:

1. Layer 0+1 green on CI (mandatory).
2. Layer 2 green on maintainer's local host (log pasted into PR description).
3. Sentinels (TP33-TP37) green → zero behavioural regression for the
   `backend = "uinput"` default path.
