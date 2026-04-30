# Design: Phase 13 Wave 6 — HID PID force feedback passthrough (T1-T7)

## Files

| File | Role |
|------|------|
| `src/io/uhid_descriptor.zig` | T1: `UhidDescriptorBuilder.buildForPid` + 8-mandatory-report validator + golden-byte tests |
| `src/config/device.zig` | T5: `[output.force_feedback]` schema (`backend`, `kind`, `clone_vid_pid`); T2: `clone_vid_pid` accessor + validate; T1: descriptor selection by `kind` |
| `src/device_instance.zig` | T2: VID/PID override on primary UHID card when `clone_vid_pid = true`; T3/T4: plumb `FfbForwarder` into instance lifetime; T1: descriptor selection (`buildForPid` vs `buildFromOutput`) |
| `src/cli/install.zig` | T2: emit udev rule per cloned VID/PID for `KERNELS=="uhid"` + `ENV{ID_VENDOR_ID}=="...", ENV{ID_MODEL_ID}=="..."` so the cloned device gets `uaccess` |
| `src/io/uhid.zig` | T3: `UHID_OUTPUT` event subscription, `pollOutputReport(buf) !?OutputReport` API, `onOutputReport` callback wiring |
| `src/io/uhid_types.zig` | T3: `UhidOutputEvent` struct (mirror of `struct uhid_output_req`), `OutputReport { id, data }` |
| `src/io/ffb_forwarder.zig` (new) | T4: `FfbForwarder.init` / `forward` / `deinit`; rate counter; back-pressure / EAGAIN classification |
| `src/io/hidraw.zig` | T4: writer-side helper for non-blocking write with EAGAIN retry budget |
| `src/supervisor.zig` | T4: hold `FfbForwarder` lifetime tied to `physical_hidraw` fd grab; coordinate fd lifecycle with input-grab path |
| `src/event_loop.zig` | T3: register UHID-output epoll fd; per-frame `pollOutputReport` drain into `FfbForwarder.forward` |
| `src/test/wave6_pidff_e2e_test.zig` (new) | T6: Layer 1 e2e — UHID_CREATE2 with PID descriptor + simulated `UHID_OUTPUT` injection + assert byte-equal hidraw write |
| `src/test/harness/uhid_simulator.zig` | T6: extend with `injectOutput(report_id, payload)` and write-side capture (already partially in place from Wave 3) |
| `tools/wave6-probe/` | T7: reuse probe scripts; pidff_probe.py becomes part of the canary check matrix |
| `.github/workflows/wave6-pidff-probe.yml` (new) | T7: weekly Mon 06:00 UTC cron on `ubuntu-22.04` runner, runs `pidff_probe.py` against `046D:C24F` (G29 / `hid-lg4ff`); fails on `BUSTYPE_ACCEPTED=false` |
| `devices/*.toml` (canary opt-in) | T7: per-wheel TOML files declaring `[output.force_feedback]` with `backend = "uhid", kind = "pid", clone_vid_pid = true` |
| `build.zig` | Register `src/io/ffb_forwarder.zig` + `src/test/wave6_pidff_e2e_test.zig` in test step |

---

## Hard Constraints (from ADR-015 Stage 3, non-negotiable)

Source: `decisions/015-uhid-imu-migration.md@92caade`:37-99 + Wave-6 additions
in `engineering/phase-13-wave-plan.md@fb1a3d6`:225-234.

1. **Bustype = `BUS_USB`**. `UhidCreate2Req.bus` MUST be `BUS_USB` (`0x03`).
   probe Run 2 (kernel 6.18.9) confirmed `hid-universal-pidff` binds via
   modalias `hid:b0003g*v....p....`. Kernel 5.15 has no bustype filter in
   the direct `hid_pidff_init` callers (`hid-lg4ff` / `hid-tmff` /
   `hid-sony`); same setting works on both.
2. **Descriptor completeness**: when `kind = "pid"`, the descriptor MUST
   contain the 8 reports that `pidff_find_reports()` treats as mandatory
   (kernel `#define PID_REQUIRED_REPORTS 8`, usages 0x21 Set Effect,
   0x77 Effect Operation, 0x96 Device Control, 0x7d Device Gain, 0xab
   Create New Effect, 0x89 Block Load, 0x7f PID Pool, 0x90 Block Free).
   Four additional reports (Set Envelope, Set Condition, Set Periodic,
   Set Constant Force, Set Ramp Force) are emitted but are not gating.
   `pidff_find_reports()` returns `-ENODEV` on any missing mandatory
   report; downstream `evdev_open()` then triggers a NULL deref OOPS in
   `hid_hw_open+0x71` (probe Run 2 evidence). T1 ships a defensive
   build-time validator that fails closed.
3. **VID/PID cloning required for `hid-universal-pidff`**. The driver's
   alias table (kernel 6.18 `modinfo hid-universal-pidff`) covers Hori
   `11FF`, Logitech wheel sub-PIDs `2433:F300-F306`, Hitachi `045B:58F9/
   5968/59D7`, Moza `346E:00xx`, Cammus `3416:0301-0302`, etc. padctl's
   default UHID `FADE:C00x` is not in the table — kernel falls through to
   `hid-generic` which never calls `hid_pidff_init`. `clone_vid_pid = true`
   replaces the primary UHID card's `vendor` / `product` with the values
   from `[device].vid` / `[device].pid`, which already match the wheel.
4. **Input grab survives FFB forwarding window**. Forwarding writes go to
   the physical hidraw fd; that fd MUST stay open and writable for the
   entire lifetime of the UHID card. Existing supervisor input-grab
   (PR #127's `physical_hidraw_fd` field) covers this; T4 adds `FfbForwarder`
   as a borrower, not an owner — supervisor remains the lifecycle root.
5. **Default zero-regression**. `[output.force_feedback].backend = "uinput"`
   (default, all existing TOMLs) keeps the rumble path byte-for-byte
   identical to pre-Wave-6. The new path activates ONLY when both
   `[output].backend = "uhid"` (Wave 3 routing already in place via
   `[output.imu].backend`) AND `[output.force_feedback].backend = "uhid"` +
   `kind = "pid"` are set.
6. **Byte-faithful FFB passthrough**. padctl never modifies the bytes
   coming out of `UHID_OUTPUT`. The `payload.data[0..payload.size]` slice
   is `posix.write`-d to the physical hidraw fd unchanged. ADR-015
   Option (a) explicitly forbids any FFB remapping / filtering / curve
   transformation in padctl.

Violating any of these at implementation time fails the spec.

---

## Behavioural Parity Contract

### When `[output.force_feedback]` is absent OR `backend = "uinput"`

Zero diff vs pre-Wave-6:

- `UinputDevice.create` / `pollFf` / FF_UPLOAD / FF_ERASE flow unchanged
- `supervisor.zig` rumble grab/release timing unchanged
- The `FfbForwarder` is never instantiated, no extra epoll fd, no extra
  hidraw write
- Every existing `full_pipeline_e2e_test.zig`, `uhid_all_devices_test.zig`,
  `supervisor_uhid_grace_integration_test.zig` golden test passes unchanged

### When `[output.force_feedback].backend = "uhid"` + `kind = "pid"`

- Primary UHID card emits a PID descriptor (T1) instead of the rumble
  descriptor — kernel binds `hid-universal-pidff` (or vendor driver), not
  `hid-input` rumble path
- `UinputDevice.pollFf` is NOT called (no uinput rumble device on this
  primary path); FFB output flows entirely through UHID
- Mixed (rumble + PID on same card) is invalid — Wave 6 is `pidff_only`.
  T5 validate rejects `[output.force_feedback].kind = "pid"` combined with
  any rumble request

### Evidence sentinel

Regression sentinel after T1-T6 land: every existing test plus
`wave6_pidff_e2e_test.zig` green; every existing `devices/*.toml` in CI
golden suite produces byte-identical descriptors to pre-Wave-6 (T1's
`buildForPid` is a NEW path — it does NOT alter `buildFromOutput`).

---

## Architecture: end-to-end FFB flow

```
                                  user-space (padctl)
                                  ───────────────────
   [game / SDL / wine] ─FFB API─> /dev/input/eventN  (padctl UHID evdev node)
                                              │
                                              ▼
   kernel hid-universal-pidff converts FFB API call into PID output report
   (e.g. Set Effect 0x01, Effect Operation 0x0A, Device Control 0x06)
                                              │
                                              ▼
   kernel UHID writes UHID_OUTPUT event to /dev/uhid fd for padctl
                                              │
                                              ▼
   padctl event_loop's epoll wakes; UhidDevice.pollOutputReport drains the
   event into a (report_id, data[]) tuple → FfbForwarder.forward
                                              │
                                              ▼
   FfbForwarder writes raw bytes to physical_hidraw_fd (already grabbed by
   supervisor as part of input-grab lifecycle)
                                              │
                                              ▼
   physical wheel firmware applies the FFB effect

                                              ▲
                              physical wheel hardware
                              ──────────────────────
```

Two key seams:

- **`/dev/uhid` write-end → padctl read-end**: kernel writes
  `struct uhid_event` (type `UHID_OUTPUT`) to `/dev/uhid`; padctl `read()`
  drains it. This is symmetric to how padctl writes `UHID_CREATE2` /
  `UHID_INPUT2` on the same fd. Wave 1 (PR #127) already wired the read
  side for `UHID_START`/`UHID_STOP`; T3 extends to `UHID_OUTPUT`.
- **padctl write → physical hidraw**: `physical_hidraw_fd` is opened by
  `Supervisor.attachInstance` at bind time and closed at unbind. T4's
  `FfbForwarder` borrows the fd (does not own).

---

## VID/PID cloning rationale

### Why cloning is required (not optional)

`hid-universal-pidff`'s module alias table (probe RESEARCH-REPORT §4.2,
verified via `modinfo` on host kernel 6.18.9):

```
hid:b0003g*v000011FFp00002141  (Hori Wingman)
hid:b0003g*v000011FFp00001211  (Moza R5)
hid:b0003g*v000011FFp00001112  (...)
hid:b0003g*v000011FFp00001212
hid:b0003g*v000011FFp00003245
hid:b0003g*v00002433p0000F300  (Logitech wheel base sub-PIDs)
hid:b0003g*v00002433p0000F301
hid:b0003g*v00002433p0000F303
hid:b0003g*v00002433p0000F306
hid:b0003g*v0000045Bp000058F9  (Hitachi/Renesas wheel MCU)
hid:b0003g*v0000045Bp00005968
hid:b0003g*v0000045Bp000059D7
hid:b0003g*v00000483p0000A355  (STMicro wheel MCU)
hid:b0003g*v00003416p00000301  (Cammus)
hid:b0003g*v00003416p00000302
hid:b0003g*v0000346Ep00000000-16 (Moza, VRS, Asetek, Tian Yi)
```

padctl's existing UHID VID/PID `FADE:C001` (padctl-main) and `FADE:C002`
(padctl-imu, Wave 3) are NOT in this table. probe Run 1 (`11FF:F045`,
also not in the alias table) demonstrated this: `hid-generic` took the
device, no FFB init at all. probe Run 2 with `11FF:1211` (Moza R5, IS in
the alias table) showed the bind succeeded.

### Implementation: `clone_vid_pid` flag

`OutputConfig.force_feedback.clone_vid_pid: bool = false`. When `true`:

- Primary UHID card's `UhidCreate2Req.vendor` ← `cfg.device.vid`
- Primary UHID card's `UhidCreate2Req.product` ← `cfg.device.pid`
- IMU UHID card (Wave 3) is unaffected — IMU continues to use `FADE:C002`
  and is invisible to `hid-universal-pidff` regardless

Default `false` preserves existing behaviour (`FADE:C001`) for any device
that does NOT need PID FFB — the only callers that flip it to `true` are
PID-capable wheel TOMLs (T7 canary opt-in).

### udev rule emission (T2)

When `install` regenerates udev rules and detects at least one TOML with
`clone_vid_pid = true`, it emits one extra rule per (cloned-vid, cloned-pid)
pair:

```
KERNELS=="uhid", SUBSYSTEM=="input", ENV{ID_VENDOR_ID}=="11ff", ENV{ID_MODEL_ID}=="1211", TAG+="uaccess"
```

This is an additive rule — the Wave 4 `KERNELS=="uhid", MODE="0666"`
remains. The cloned-VID/PID rule is just so that the existing user-session
hidraw-handling (`uaccess`) keeps working when the kernel reports the
cloned VID/PID instead of `FADE:C001`.

### Legal / branding note

probe RESEARCH-REPORT §4.3 documents that VID/PID cloning is a structural
requirement of `hid-universal-pidff`'s modalias-based binding, not a
padctl design choice. InputPlumber and inputtino (also using UHID for FFB)
follow the identical pattern (e.g. inputtino clones Sony's VID for
DualShock emulation). `clone_vid_pid` defaults to `false` — users
explicitly opt in per device. Release-note copy explaining this is a
maintainer task; T7's canary TOMLs ship with the flag set in production
form.

---

## T1: PID descriptor builder

### Problem

`UhidDescriptorBuilder.buildFromOutput` (Wave 2, PR #132) emits a rumble-only
descriptor (FF_RUMBLE inside an `OUTPUT` collection). For `kind = "pid"`,
the kernel needs a HID Physical Interface Device collection with all 12
PID mandatory reports. No existing Wave 1-3 code emits this shape.

### Solution

New public function:

```zig
pub fn buildForPid(
    allocator: std.mem.Allocator,
    cfg: device.OutputConfig,         // existing — for axis/button reports
    ffb_cfg: device.ForceFeedbackConfig,
) BuildError![]u8;
```

Descriptor layout (top-to-bottom byte stream):

| Block | Bytes | Note |
|-------|-------|------|
| Generic Desktop Joystick application collection | preamble | unchanged from `buildFromOutput` for axes + buttons |
| Axes / buttons / hat (existing) | from `cfg` | reused builder helpers |
| **PID output collection start** (`0x05 0x0F` Usage Page Physical Interface Device) | — | new |
| Set Effect Report (ID 1, ~13 bytes payload) | **kernel-mandatory** | Effect Type, Duration, Sample Period, Gain, Trigger Button, Axes Enable, Direction X, Direction Y |
| Set Envelope Report (ID 2, ~7 bytes payload) | optional (emitted) | Attack Level, Fade Level, Attack Time, Fade Time |
| Set Condition Report (ID 3, ~9 bytes payload) | optional (emitted) | Center Point Offset, Positive Coefficient, Negative Coefficient, Positive Saturation, Negative Saturation, Dead Band |
| Set Periodic Report (ID 4, ~11 bytes payload) | optional (emitted) | Magnitude, Offset, Phase, Period |
| Set Constant Force Report (ID 5, ~3 bytes payload) | optional (emitted) | Magnitude |
| Set Ramp Force Report (ID 6, ~5 bytes payload) | optional (emitted) | Ramp Start, Ramp End |
| Block Free Report (ID 7, ~1 byte payload) | **kernel-mandatory** | Effect Block Index |
| Effect Operation Report (ID 10, ~3 bytes payload) | **kernel-mandatory** | Operation (Start / Start Solo / Stop), Loop Count |
| Device Control Report (ID 11, ~1 byte payload) | **kernel-mandatory** | Disable / Enable / Stop / Reset / Pause / Continue |
| Device Gain Report (ID 12, ~1 byte payload) | **kernel-mandatory** | Gain |
| **PID feature collection** | — | feature reports below |
| Create New Effect Report (ID 13, feature) | **kernel-mandatory** | Effect Type |
| Block Load Report (ID 14, feature) | **kernel-mandatory** | Effect Block Index, Block Load Status, RAM Pool Available |
| PID Pool Report (ID 15, feature) | **kernel-mandatory** | RAM Pool Size, Simultaneous Effects Max, Device Managed Pool, Shared Parameter Blocks |

Kernel-mandatory = required by `pidff_find_reports` (`PID_REQUIRED_REPORTS 8`); report IDs 1, 7, 10, 11, 12, 13, 14, 15.
Optional = emitted by `buildForPid` but not validated by the kernel gate; omitting them would still bind.

Byte counts above are illustrative (probe pidff_probe.py uses a similar
layout). Implementer pins exact byte sequences against `hid-tools`
canonical output and against the implementer-derived 8-mandatory-report PID
descriptor (validated on first real-hardware run when
`hid-universal-pidff` binds without `Error initialising force
feedback`); the golden test pins the byte sequence once produced.

### 8-of-8 mandatory validator

After byte emission, before returning, T1 runs:

```zig
// Per drivers/hid/usbhid/hid-pidff.c pidff_reports[0..PID_REQUIRED_REPORTS].
// Report IDs map to usages: 1→0x21, 7→0x90, 10→0x77, 11→0x96, 12→0x7d,
// 13→0xab, 14→0x89, 15→0x7f.
const REQUIRED_REPORTS = [_]u8{ 1, 7, 10, 11, 12, 13, 14, 15 };
fn validateMandatoryReports(descriptor: []const u8) !void {
    var seen: [16]bool = .{false} ** 16;
    // walk descriptor bytes, record every Report ID (0x85 prefix)
    // for any required id not seen → return error.IncompletePidDescriptor
}
```

This is fail-closed at build time: the daemon refuses to instantiate a
PID UHID card with an incomplete descriptor, so the kernel OOPS path
observed in probe Run 2 cannot be triggered by padctl.

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/uhid_descriptor.zig` | `buildFromOutput` only | adds `buildForPid` + `validateMandatoryReports` + golden tests |
| `src/io/uhid_descriptor.zig` test block | rumble + IMU goldens | adds `test "buildForPid: 8 mandatory PID reports present per kernel pidff_find_reports"` + `test "buildForPid: matches reference PID descriptor (Moza R5)"` (byte sequence implementer-pinned from first successful real-hardware run; NOT from the probe — see probe evidence scope below) |

---

## T2: VID/PID cloning

### Problem

`UhidDevice.init` always reads `vendor` / `product` from
`UhidCreateOptions`, which currently inherits from `cfg.device.vid` /
`cfg.device.pid` for primary UHID cards (Wave 3 routing). Wave 6 needs
this to be conditional on `[output.force_feedback].clone_vid_pid` so that
non-PID devices keep `FADE:C001` (current behaviour) and PID devices
inherit the wheel's real VID/PID.

Wait — looking at Wave 3 design.md line 344-345 carefully:

```
.vid = @intCast(cfg.device.vid),
.pid = @intCast(cfg.device.pid),
```

Wave 3 already passes `cfg.device.vid` / `cfg.device.pid` to the primary
UHID card. So today, padctl's primary UHID card already inherits the
wheel's VID/PID, NOT `FADE:C001`. The `FADE:C00x` defaults documented in
ADR-015 Unresolved-Items section are the IMU card (Wave 3 IMU defaults to `FADE:C002`)
and the legacy aspirational design — primary card has been wheel-VID/PID
since Wave 3 routing.

This means T2 has a much smaller surface than originally framed: the only
addition is **the explicit `clone_vid_pid` flag as user opt-in / opt-out**,
plus the udev rule emission. The runtime effect is already in place.

### Revised solution

`OutputConfig.force_feedback.clone_vid_pid: bool = false` is interpreted as:

- `false` (default) — primary UHID card vendor/product = `FADE:C001`
  (i.e. opt-OUT of the Wave-3-incidental cloning, restoring the
  ADR-015 legacy defaults for non-PID devices)
- `true` — primary UHID card vendor/product = `cfg.device.vid` /
  `cfg.device.pid` (current Wave 3 behaviour, kept for PID devices)

This inverts: rather than introducing cloning as new, T2 makes the existing
Wave 3 behaviour user-controllable. Default `false` is safer for non-PID
devices (Flydigi Vader, DualSense, Steam Deck — they don't need to
masquerade as themselves, and `FADE:C001` keeps the daemon's identity
visible in `lsusb`).

For Wave 5's hardware regression matrix (Flydigi/DualSense/Steam Deck),
the canary TOML opt-in to `[output.force_feedback].clone_vid_pid = false`
preserves daemon identity. Wave 5 PRs will need to set this explicitly
since the Wave 3 default was incidentally `true` — see "Wave 5 coordination"
below.

#### Wave 5 coordination (out-of-band)

Wave 5's canary opt-ins on existing TOMLs are still in-flight as of
PR #160. Wave 6 T2 lands the schema field; Wave 5 PRs that flip
`backend = "uhid"` per device must additionally set
`[output.force_feedback].clone_vid_pid` to whatever value preserves the
wheel-3 incumbent behaviour for that device (i.e. `true` for any device
that today benefits from showing its real VID/PID, `false` otherwise).
This is a documentation note for Wave 5 PR authors — not a Wave 6 code
deliverable.

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/config/device.zig` | no `force_feedback` block | T5 adds the block; T2 adds `clone_vid_pid: bool = false` field + validate hook |
| `src/device_instance.zig` | unconditional `cfg.device.vid` / `cfg.device.pid` on UHID create options | branch on `ffb_cfg.clone_vid_pid`: `true` → keep wheel VID/PID; `false` → use `FADE:C001` constant |
| `src/cli/install.zig` | one `KERNELS=="uhid"` udev rule | when at least one TOML has `clone_vid_pid = true`, emit one additive rule per cloned (vid, pid) pair |
| `src/test/install_udev_test.zig` | no PID rules | adds golden assertion: `clone_vid_pid = true` produces the per-VID/PID rule |

---

## T3: `UHID_OUTPUT` event handler

### Problem

`src/io/uhid.zig` (Wave 1, PR #127) handles read events from `/dev/uhid`
for `UHID_START` and `UHID_STOP` (kernel telling padctl when an evdev
client opens / closes). It does NOT handle `UHID_OUTPUT` (kernel writing
FFB report bytes for padctl to forward).

### Solution

Extend `src/io/uhid.zig` with output-report read path:

```zig
pub const OutputReport = struct {
    report_id: u8,
    data: []const u8,    // borrows the read buffer; valid only until next read
};

pub fn pollOutputReport(self: *UhidDevice, buf: []u8) !?OutputReport {
    // posix.read(self.fd, buf)
    // if event.type == UHID_OUTPUT:
    //   return OutputReport{
    //       .report_id = event.payload.output.data[0],
    //       .data = event.payload.output.data[0..event.payload.output.size],
    //   };
    // else: handle UHID_START / UHID_STOP / UHID_OPEN / UHID_CLOSE per existing flow,
    //       return null
}
```

`pollOutputReport` is called from `event_loop.zig`'s ppoll dispatch when
the UHID fd's read-side fires. The single-buffer design avoids per-event
allocation; the caller (`FfbForwarder.forward`) must consume the slice
synchronously before the next `pollOutputReport` call.

### `src/io/uhid_types.zig` additions

```zig
pub const UhidOutputReq = extern struct {
    size: u16,
    rtype: u8,                 // UHID_OUTPUT_REPORT_TYPE_OUTPUT = 1
    data: [UHID_DATA_MAX]u8,   // first byte is report ID
};
```

(`UHID_DATA_MAX` is 4096 per kernel `linux/uhid.h`. Real PID output reports
are < 32 bytes — a 4 KiB buffer is wasteful but matches the kernel ABI;
we accept it and don't pre-truncate.)

### Callback wiring

`UhidDevice` already has the fd; `event_loop.zig` already has the epoll
fd registration (Wave 1). T3 adds:

- A `setOutputCallback(fn(*FfbForwarder, OutputReport) void, ctx: *FfbForwarder)`
  on `UhidDevice` — called by `DeviceInstance.init` when a `FfbForwarder`
  is constructed
- `event_loop.zig`'s per-frame dispatch calls `uhid_dev.pollOutputReport(buf)`
  in a loop (drain) and forwards each report via the registered callback

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/uhid.zig` | no output-report API | adds `pollOutputReport`, `setOutputCallback` |
| `src/io/uhid_types.zig` | `UhidCreate2Req`, `UhidInput2Req`, `UhidEvent` enum | adds `UhidOutputReq`, extends `UhidEvent` enum with `UHID_OUTPUT = 6` |
| `src/event_loop.zig` | UHID fd reads consumed only `START`/`STOP` | drain loop also handles `UHID_OUTPUT`, dispatches to callback |
| `src/io/uhid.zig` test block | no output tests | adds `test "pollOutputReport: parses UHID_OUTPUT bytes"` (using pipe2 fixture, hand-written event bytes) |

---

## T4: `FfbForwarder` — physical hidraw write

### Problem

When `pollOutputReport` returns an `OutputReport`, padctl must write its
bytes to the physical wheel's hidraw fd. The fd is owned by `Supervisor`
(`physical_hidraw` field, set during input-grab). The forwarder must:

- Be byte-faithful (no transformation)
- Handle `EAGAIN` (kernel buffer full) — short retry budget, then drop
- Handle `EACCES` (lost write permission, hidraw revoked) — disable
  forwarding for this lifetime, log once
- Handle `ENODEV` (device unplugged) — disable, log once, supervisor
  unbind handles cleanup
- Track rate (writes/sec) for diagnostics

### Solution

New file `src/io/ffb_forwarder.zig`:

```zig
pub const FfbForwarder = struct {
    physical_fd: posix.fd_t,           // borrowed; Supervisor owns
    state: enum { active, disabled } = .active,
    writes_total: u64 = 0,
    drops_eagain: u64 = 0,
    last_rate_log_ns: i64 = 0,

    pub fn init(physical_fd: posix.fd_t) FfbForwarder { ... }

    pub fn forward(self: *FfbForwarder, report: OutputReport) void {
        if (self.state == .disabled) return;
        // Build full byte buffer: report.report_id followed by report.data[1..]
        // (note: kernel UHID payload already contains report_id at data[0])
        const written = posix.write(self.physical_fd, report.data) catch |err| switch (err) {
            error.WouldBlock => { self.drops_eagain += 1; return; },
            error.AccessDenied, error.PermissionDenied => {
                std.log.warn("ffb forwarder: hidraw write EACCES, disabling", .{});
                self.state = .disabled;
                return;
            },
            error.NoDevice => {
                std.log.warn("ffb forwarder: hidraw ENODEV, disabling", .{});
                self.state = .disabled;
                return;
            },
            else => return, // log + drop
        };
        self.writes_total += 1;
        // (rate-log throttle, ~1 line per second when rate > threshold)
    }

    pub fn deinit(self: *FfbForwarder) void {
        // no-op: physical_fd is Supervisor-owned, not closed here
        _ = self;
    }
};
```

### Lifecycle in `Supervisor`

- `attachInstance` opens `physical_hidraw_fd` (existing) → constructs
  `FfbForwarder.init(physical_hidraw_fd)` → registers callback on the
  primary `UhidDevice`
- `detachInstance` clears the callback BEFORE closing `physical_hidraw_fd`
  to avoid a use-after-close window (hidraw fd is invalid after this
  point; any in-flight `pollOutputReport` returns null)
- Order: callback-clear → `UhidDevice.close` → `posix.close(physical_hidraw_fd)`

### Rate budget (back-pressure)

If `writes_total - last_writes` exceeds 200 reports in a 100ms window,
log a warning and continue. PID FFB rates from real wheels typically
peak at 100-250 Hz (Logitech G29 docs cite 100Hz nominal, transient
500Hz spikes during effect transitions). 200/100ms = 2000Hz is a
generous ceiling; real saturation triggers should be rare. T4 stops
short of dedicated worker threads — that is Wave 6 follow-up (R4).

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/io/ffb_forwarder.zig` (new) | — | full module + Layer 0 unit tests (using pipe2 as physical_fd, write count assertions) |
| `src/supervisor.zig` | no FFB forwarder | constructs/destroys `FfbForwarder` tied to `physical_hidraw_fd` lifetime |
| `src/io/hidraw.zig` | no helpers | optional thin wrapper if existing write helpers don't expose EAGAIN distinctly |
| `build.zig` | no `ffb_forwarder.zig` | register in test step |

---

## T5: `[output.force_feedback]` schema

### Problem

`OutputConfig` (Wave 3) has `imu: ?ImuConfig` but no `force_feedback`
sub-table. Wave 6 needs to express `kind = "pid"` opt-in, the `backend`
selector, and the `clone_vid_pid` flag from T2.

### Solution

```zig
pub const ForceFeedbackKind = enum { rumble, pid };
pub const ForceFeedbackBackend = enum { uinput, uhid };

pub const ForceFeedbackConfig = struct {
    backend: []const u8 = "uinput",   // "uinput" | "uhid"
    kind:    []const u8 = "rumble",   // "rumble" | "pid"
    clone_vid_pid: bool = false,
};

pub const OutputConfig = struct {
    // ...existing fields including imu...
    force_feedback: ?ForceFeedbackConfig = null,
};
```

### Validate matrix

Applied inside `validate(cfg)` after IMU validation:

| `force_feedback` | `backend` | `kind` | Outcome |
|------------------|-----------|--------|---------|
| absent | (n/a) | (n/a) | Legal. Pre-Wave-6 path (rumble via `UinputDevice`). |
| present | `"uinput"` | `"rumble"` | Legal (explicit form of legacy default). |
| present | `"uinput"` | `"pid"` | `error.InvalidConfig` (PID requires UHID for kernel pidff binding). |
| present | `"uhid"` | `"rumble"` | `error.InvalidConfig` (rumble through UHID is Wave 5+, not Wave 6 scope). |
| present | `"uhid"` | `"pid"` | Legal. **Requires `[output.imu]` present** so primary card is on UHID backend (Wave 3 routing). If `[output.imu]` absent → `error.InvalidConfig`. |
| present | other / other | — | `error.InvalidConfig` (fail closed). |

The `[output.imu]` requirement: padctl's primary UHID card path is gated
by `[output.imu].backend = "uhid"` per Wave 3 design. PID FFB is on the
primary card. A wheel TOML therefore must declare `[output.imu]` even if
the wheel has no IMU — it's the routing switch, not a hardware claim.
Since wheels typically lack IMU hardware, the IMU output is functionally
inert. The IMU UHID card will still be created (and consume a fd plus
~12KB of state), but its descriptor is harmless and SDL will identify
it as a sensor companion that nothing reads. Acceptable cost for not
introducing a separate routing knob.

(A cleaner alternative — promoting `[output].backend = "uhid"` as a
device-wide selector independent of `[output.imu]` — is intentionally
deferred. It would touch Wave 3's settled design and is not justified
for one wave's worth of cleanliness.)

Note: this `[output.imu]` overloading as a routing flag for non-IMU
wheels is a known design compromise. Wave 6 keeps it to avoid
invalidating Wave 3's settled design. A cleaner alternative —
promoting `[output].backend = "uhid"` as a device-wide selector — is
intentionally deferred to a post-Wave-6 cleanup; if a maintainer adds
many wheel TOMLs and the overloading becomes a friction point, the
deferred fix should be reconsidered. (No deviations/ entry in
docs-repo at this point — the compromise is contained in this single
Wave 6 design decision.)

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/config/device.zig` | `OutputConfig` has no `force_feedback` | adds `force_feedback: ?ForceFeedbackConfig = null` + struct definition |
| `src/config/device.zig` (validate) | no FFB validation | adds matrix above with `error.InvalidConfig` |
| `src/config/device.zig` (test block) | no FFB tests | adds 6 cases per matrix row + 1 round-trip `[output.force_feedback]` TOML parse |

---

## T6: Layer 1 e2e

### Problem

Wave 1's `UhidSimulator` is an input-side harness — it produces a virtual
HID device that padctl reads from. T6 needs it (or an equivalent) to also
simulate `UHID_OUTPUT` events flowing kernel → padctl, then capture
padctl's onward writes to the physical hidraw fd.

### Solution

Two seams:

1. **Inject side**: extend `UhidSimulator` (or wrap it) so a test can do
   `simulator.injectOutput(report_id, payload[])` which writes a
   `UHID_OUTPUT` event to the same `/dev/uhid` write-end `padctl` reads
   from. Implementation: hand-craft a `struct uhid_event` with type
   `UHID_OUTPUT` and `posix.write` it to the simulator's UHID fd
2. **Capture side**: replace the wheel's physical hidraw fd in
   `Supervisor` with a `posix.pipe2` write-end (as in Wave 3 Layer 1
   pattern). Test reads from the read-end, asserts byte equality with
   the injected payload

### Test sequence (`wave6_pidff_e2e_test.zig`):

```
1. Build DeviceConfig: backend="uhid", kind="pid", clone_vid_pid=true,
   [device].vid=0x11FF, [device].pid=0x1211 (Moza R5)
2. Open simulator's /dev/uhid read-end + writer-side pipe2 for "physical hidraw"
3. DeviceInstance.init with test seam fds (test_primary_uhid_fd,
   test_physical_hidraw_fd)
4. Decode UHID_CREATE2 from simulator side; assert vendor=0x11FF,
   product=0x1211 (cloned), descriptor passes validateMandatoryReports
5. simulator.injectOutput(report_id=1, payload=<Set Effect bytes>)
6. Run event_loop one tick
7. posix.read(physical_hidraw_pipe.read_end) → expect bytes byte-equal
   to the injected payload
8. Repeat for report_id=10 (Effect Operation), report_id=11 (Device Control)
9. Assert FfbForwarder.writes_total == 3, drops_eagain == 0
```

### Failure-mode tests

- `wave6_pidff_e2e_test.zig` test 2: incomplete descriptor →
  `DeviceInstance.init` returns `error.IncompletePidDescriptor` (T1
  validator)
- test 3: physical hidraw fd `EAGAIN` (writer-side pipe full) → forwarder
  increments `drops_eagain`, no panic
- test 4: physical hidraw fd closed mid-flight → forwarder transitions
  to `disabled`, logs once

### Files affected

| File | Before | After |
|------|--------|-------|
| `src/test/wave6_pidff_e2e_test.zig` (new) | — | 4 Layer 1 tests as above |
| `src/test/harness/uhid_simulator.zig` | input side only | adds `injectOutput(report_id, payload)` helper |
| `build.zig` | — | register new test in test step |

---

## T7: Real-hardware matrix + Phase B CI

### Problem

Layer 0+1 tests prove descriptor correctness and event plumbing but
cannot prove a physical wheel actually reacts to FFB. ADR-015 Stage 3
exit conditions AC8-1 .. AC8-3 require physical-hardware evidence on at
least one wheel. AC8-6 requires a recurring CI signal that kernel 5.15
behaviour hasn't regressed.

### Solution

#### T7a: Per-device canary opt-in TOML

`devices/ardor-silverstone.toml` (or moza-r5 / g29 / tmx — whichever the
maintainer or external tester has hardware for):

```toml
[device]
name = "Ardor Silverstone Wheel"
vid  = 0x11FF
pid  = 0x1211   # if testing Moza R5; or 0xF045 for Silverstone, etc.

[output]
# ...wheel button + axis mapping (existing TOML conventions)...

[output.imu]
backend = "uhid"   # required for Wave 3 routing to engage UHID

[output.force_feedback]
backend       = "uhid"
kind          = "pid"
clone_vid_pid = true
```

#### T7b: Manual test plan (one wheel × one kernel minimum)

For each (wheel, kernel-version) cell:

1. `padctl install` → systemd user service running, udev rules emitted,
   `/dev/uhid` `DeviceAllow` in unit
2. Plug wheel → padctl detects, binds, creates UHID + IMU + (Wave 6)
   PID UHID card
3. `dmesg | grep -E 'hid-(universal-)?pidff|hid-lg4ff|hid-tmff'` →
   expect bind line `hid-universal-pidff 0003:11FF:1211.NNNN: input,hidrawN: ...`
   (or vendor-driver equivalent)
4. `cat /sys/class/input/event*/device/capabilities/ff` on the padctl
   evdev node → expect non-zero bitmap (FF_CONSTANT bit or FF_SPRING bit)
5. `fftest /dev/input/eventN` → run "Constant Force", "Spring", "Damper"
   programs → tester reports subjective force in steering wheel
6. `usbmon` capture during step 5 → confirm OUT URB bytes match the
   `[output.force_feedback]` configuration

#### T7c: Phase B CI workflow (`.github/workflows/wave6-pidff-probe.yml`)

```yaml
name: wave6-pidff-probe
on:
  schedule:
    - cron: '0 6 * * 1'   # weekly Monday 06:00 UTC
  workflow_dispatch:
jobs:
  probe-5-15:
    runs-on: ubuntu-22.04   # kernel 5.15 LTS
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
        with: { name: probe-5-15.log, path: probe-5-15.log }
```

Cost: one runner-minute weekly. Failure (e.g. `BUSTYPE_ACCEPTED=false`)
generates a workflow-failure notification — actionable signal that
kernel 5.15 LTS behaviour has changed.

(probe RESEARCH-REPORT §6 is the source for this YAML; T7 is its
formal landing in code-repo `.github/workflows/`.)

### Files affected

| File | Before | After |
|------|--------|-------|
| `devices/<wheel>.toml` (canary opt-in, one or more) | — | new TOML(s) per wheel actually tested |
| `.github/workflows/wave6-pidff-probe.yml` (new) | — | weekly cron probe |
| Manual test plan (PR description) | — | maintainer / tester runs T7b, paste log into PR |

---

## Risk Register (R1-R6, expanded with mitigations)

| # | Risk | Probability | Mitigation | Owner |
|---|------|-------------|------------|-------|
| R1 | Incomplete PID descriptor → `pidff_find_reports -ENODEV` → kernel OOPS in `hid_hw_open+0x71` (probe Run 2 evidence: 7-of-8 mandatory reports caused FFB init failure + kernel NULL-deref) | Low (T1 validator catches) | T1 `validateMandatoryReports` runs at `buildForPid` time, not at runtime; `error.IncompletePidDescriptor` aborts daemon before `UHID_CREATE2`. Golden-byte test compares against an implementer-pinned descriptor; the byte sequence is recorded after first real-hardware run when kernel logs show successful FFB initialization (no `pidff_find_reports -ENODEV` and no kernel OOPS). First-real-hardware run includes `dmesg -w` review. | T1 implementer |
| R2 | VID/PID cloning legal/branding pushback | Low | Documented as kernel-driven structural requirement (probe RESEARCH-REPORT §4.3); `clone_vid_pid` defaults to `false` and is per-device opt-in; release-note copy explains. InputPlumber and inputtino set the precedent. | T2 implementer + maintainer release notes |
| R3 | `hid-universal-pidff` vs vendor-specific drivers (`hid-lg4ff`, `hid-tmff`) compatibility matrix | Medium | T7 first round covers `hid-universal-pidff` only (default 6.x path). Vendor-driver paths (kernel-5.15 G29 via `hid-lg4ff`) are opportunistic — Phase B CI workflow exercises G29 on 5.15. Mismatched-driver TOMLs deferred to Wave 6 follow-up. | T7 implementer |
| R4 | `UHID_OUTPUT` rate (peak ~500Hz on aggressive FFB) saturating event loop | Medium | T3 design uses single drain loop, no per-event allocation. T4 tracks `drops_eagain` and rate; if observed `> 200 Hz` sustained, dedicated worker thread proposed for Wave 6 follow-up. T6 e2e test asserts 3 reports/tick handled cleanly. | T3 + T4 implementers |
| R5 | Kernel OOPS observed in probe Run 2 is upstream-reportable bug | N/A — padctl avoids the path | T1's complete descriptor avoids triggering the path. If maintainer wants to file upstream, separate work outside Phase 13. | maintainer (out-of-scope) |
| R6 | kernel 5.15 LTS lacks `hid-universal-pidff` (upstreamed in 6.12) | Known | T7's Phase B CI uses Logitech G29 VID/PID (`046D:C24F`), which binds to `hid-lg4ff` on 5.15 — that driver also calls `hid_pidff_init` and exposes the same kernel pidff machinery. If 5.15 + G29 fails on CI, fallback is Option (a) for 5.15 (block_kernel_drivers excludes hid-pidff/hid-lg4ff for that environment), and Wave 6 is declared 6.x-only. | T7 implementer + maintainer |

---

## Open Questions (implementer's call, not blocking spec acceptance)

These are documented per the engineering plan's Open-Questions section
(implementer's call) — the spec does NOT pre-decide them; the implementer chooses based on
runtime measurement and reviewer feedback during PR review:

1. **Drain budget per ppoll tick** — should `pollOutputReport` drain all
   pending events before returning to the dispatcher, or one per tick?
   Plan: drain all per tick to minimise latency; if R4 saturation
   manifests, switch to bounded drain
2. **`writes_total` / `drops_eagain` exposure** — log-only (current
   default), or a future `padctl status` IPC command? Plan: log-only in
   Wave 6; IPC is a Phase 13 follow-on
3. **`clone_vid_pid` interaction with hidraw `KERNELS=="uhid"` udev rule**
   — does the existing Wave 4 rule cover the cloned-VID/PID case? Need
   a Layer 2 host check; if not, T2 must emit additive rules
4. **PID descriptor variation across wheel classes** — Logitech G29's
   PID layout differs subtly from Moza R5's. Initial T1 implementation
   ships one canonical descriptor (Moza R5 reference, probe Run 2);
   any per-wheel quirks discovered during T7 hardware testing fold back
   into T1 as parameterised options
5. **`error.IncompletePidDescriptor` vs `error.InvalidConfig`** — should
   the validator's failure surface be a config-level error or a build-time
   error? Plan: build-time (`BuildError`); the descriptor is generated
   from config but the failure is structural, not user-correctable

---

## Honest footnote on kernel coverage

The probe (`tools/wave6-probe/RESEARCH-REPORT.md`) verified
`hid-universal-pidff` modalias binding on **kernel 6.18.9** (Arch host) ONLY.
Kernel 5.15 is supported by **two pieces of indirect evidence**, not
empirical test:

1. `hid-pidff.c` source on `linux-stable` v5.15 has no bustype filter
2. `hid-pidff` direct callers on 5.15 (`hid-lg4ff`, `hid-tmff`,
   `hid-sony`) match by VID/PID, not bustype

This is sufficient to start Wave 6 (no architectural blocker) but
**T7's Phase B CI workflow is the empirical proof for 5.15** — until
that workflow runs and reports `BUSTYPE_ACCEPTED=true`, the 5.15 path is
"believed-viable, not verified". A failing first run is the single
concrete event that would force Stage 3 to Option (a) on 5.15
specifically.

For kernel versions outside the 5.15 / 6.x range tested (e.g. 4.x, 7.x
when it ships), padctl makes no claim; T7 hardware matrix is the only
evidence base.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | `[output.force_feedback]` is a separate sub-table from `[output.imu]` | IMU and FFB are orthogonal capabilities; even though Wave 6 happens to require both UHID-backed (since PID is on the primary card and primary is gated by IMU), conflating them in TOML would lock future redesign. |
| D2 | `kind = "pid"` requires `backend = "uhid"`; `kind = "rumble"` allows either | Rumble has TWO valid backends (legacy uinput, future Wave 5 UHID); PID has only one (UHID). Validate matrix encodes this. |
| D3 | `clone_vid_pid` default `false` (NOT `true`) | Default `false` keeps non-PID devices on `FADE:C001` daemon-identity. Wave 5 PRs that flip backends explicitly choose `true` per device. Less surprising than implicit cloning. |
| D4 | 8-mandatory-report validator at build time, not runtime | Probe Run 2 demonstrated kernel OOPS on incomplete descriptor; making this a build-time `BuildError` instead of a runtime `error.UhidCreateFailed` removes the entire failure mode by construction. The kernel requires exactly 8 mandatory reports (`PID_REQUIRED_REPORTS 8`); 4 others are emitted but are not gating. |
| D5 | `FfbForwarder` borrows physical hidraw fd, doesn't own | Supervisor already owns the fd through input-grab lifetime; introducing a second owner creates close-ordering hazards. Forwarder is a pass-through, lifetime ≤ supervisor's fd lifetime. |
| D6 | Single `OutputReport` slice borrowed from read buffer (no copy) | `pollOutputReport` returns a view into `buf`. Caller (`FfbForwarder.forward`) consumes synchronously. Avoids per-event allocation in the hot path. |
| D7 | Drain-all per ppoll tick (initial implementation) | Lower latency than bounded drain. If R4 saturation manifests, swap to bounded loop with no other code changes. |
| D8 | Phase B CI workflow uses Logitech G29 VID/PID on `ubuntu-22.04` | G29 binds to `hid-lg4ff` on 5.15 (no `hid-universal-pidff` yet); G29 is the most-likely available 5.15 path. Failing this run is the single concrete signal forcing 5.15 → Option (a). |
| D9 | T1's golden test pins an implementer-derived PID descriptor (8 mandatory + 5 optional reports) for one wheel class | The byte sequence is recorded after the first real-hardware run shows successful `hid-universal-pidff` FFB init (no OOPS, no `pidff_find_reports -ENODEV`). Probe Run 2 provides evidence for bustype acceptance + driver binding ONLY — it does NOT supply a working descriptor (Run 2's 7-of-8 mandatory report descriptor caused FFB init failure). New device classes added later via T7 may diverge — per-class goldens added as needed. |
| D10 | No FFB transformation in padctl (byte-faithful only) | ADR-015 Option (a) hard constraint. Any transformation would need a separate ADR and re-opening of the Stage 3 decision — out of Wave 6 scope. |
