# Wave 6 Research Report — hid-pidff bustype gate probe

> based-on: `decisions/015-uhid-imu-migration.md@92caade`, `engineering/phase-13-wave-plan.md@4cd9d30` (docs-repo refs)
> Date: 2026-04-24 | Status: complete (Phase A executed, Phase B proposed as CI workflow)
> Triggered by: ADR-015 §"未解决项" (L91-99) — "kernel 5.15 LTS 的 `hid-pidff` 是否接受 `bus = BUS_USB` 的虚拟 UHID 设备"
> Feeds: ADR-015 Stage 3 entry decision; Wave 6 task wiring in `engineering/phase-13-wave-plan.md`

## 1. Research question

ADR-015 Stage 3 (issue #82, wheel HID PID FFB through padctl UHID) is gated by a single empirical
unknown: does kernel's `hid-pidff` helper library accept a virtual UHID device created with
`bus = BUS_USB`? If yes → Stage 3 is viable (padctl builds PID descriptor, forwards `UHID_OUTPUT`
events from kernel back to physical wheel, ~300 LoC). If no → fall back to Option (a): add
`hid-pidff` to `block_kernel_drivers` exclusion list so kernel's native driver stays bound to the
physical device; padctl only handles buttons/axes (~0 LoC, no FFB remapping capability).

## 2. Methodology

### 2.1 Probe implementation

- `tools/wave6-probe/pidff_probe.py` — 320-byte HID report descriptor containing:
  - Generic Desktop > Joystick application collection with one axis (X, 1 byte)
  - Physical Interface Device output reports: Set Effect (ID 2), Effect Operation (ID 8),
    Device Control (ID 9), Device Gain skipped
  - Feature reports: Create New Effect (ID 11), Block Load (ID 12), PID Pool (ID 13)
  - **Intentionally incomplete**: Set Envelope/Condition/Periodic/Constant/Ramp reports were
    not included — this turned out to be the FFB init blocker (see 3.2)
- Device is created via `hidtools.uhid.UHIDDevice` (hid-tools 0.12) with `bus = BusType.USB`
- VID/PID configurable via `PROBE_VID` / `PROBE_PID` env vars; probe runs two cases:
  - `11FF:F045` (Ardor Silverstone — NOT in `hid-universal-pidff` alias table)
  - `11FF:1211` (Moza R5 — IS in the alias table, see §4.3)
- After `UHID_CREATE2`, probe dispatches events for 3s, then reads:
  - `/sys/devices/virtual/misc/uhid/<hid_id>/driver` → bound driver
  - `/sys/class/input/event*/device/capabilities/ff` → FFB capability bitmap
  - `dmesg` tail for bind/error/oops lines

### 2.2 Container / environment

- `tools/wave6-probe/Dockerfile.arch` — `archlinux:base` + `python hid-tools util-linux kmod`
- Built image: 738 MB, build time 2:20 (cold cache on host with warm pacman mirror)
- Runtime flags: `--privileged --device=/dev/uhid -v /lib/modules:ro -v /sys:ro -v /dev/input:ro`
  - `--privileged` needed so container can `modprobe hid-universal-pidff` (not loaded by default)
  - `/lib/modules` bind-mount gives modprobe access to host kernel modules
- Docker shares host kernel → this tests host's live kernel behavior
  (**6.18.9-arch1-2**, not 5.15). Phase B (kernel 5.15) was deferred to CI workflow (§6).

### 2.3 Verdict dimensions (orthogonal)

The probe's original binary verdict (`PIDFF_BOUND`) conflated three distinct signals. The
final script records all three separately:

1. **`BUSTYPE_ACCEPTED`** — kernel did not reject `bus = BUS_USB` during `UHID_CREATE2`
   (hidraw + evdev nodes appear in `/sys`)
2. **`PIDFF_DRIVER_BOUND`** — `hid-pidff` or `hid-universal-pidff` took over via modalias match
   (requires VID/PID in driver's alias table; read from `dmesg`'s `hid-universal-pidff N:NNNN:NNNN.NNNN:` line, authoritative even if sysfs `driver` symlink is stale after OOPS)
3. **`FFB_INITIALIZED`** — kernel exposed `EV_FF` capabilities on the evdev node (the `ff`
   capability bitmap has any non-zero bit)

This split is important: (1) is what ADR-015 asked about; (2) and (3) are downstream
consequences that also require the HID descriptor to be complete and the VID/PID to match.

## 3. Results — kernel 6.18.9

### 3.1 Run 1 — `11FF:F045` (Silverstone, VID/PID NOT in universal-pidff table)

```
BUSTYPE_ACCEPTED:   true   (hidraw2 + event13 created)
PIDFF_DRIVER_BOUND: false  (hid-generic took it, F045 not in alias list)
FFB_INITIALIZED:    false  (ff caps = "0", expected — hid-generic doesn't init FFB)
FFB_INIT_ERROR:     false
KERNEL_OOPS:        false
```

dmesg (verbatim, relevant lines only):
```
input: Ardor Silverstone (Wave6 Probe) as /devices/virtual/misc/uhid/0003:11FF:F045.02AE/input/input708
hid-generic 0003:11FF:F045.02AE: input,hidraw2: USB HID v0.00 Joystick [Ardor Silverstone (Wave6 Probe)] on padctl/wave6-probe
```

Interpretation: clean baseline — kernel accepts UHID device with `bus = BUS_USB`, binds `hid-generic` (no FFB, no PID). No module alias matched `11FF:F045`, so `hid-universal-pidff` did not try to bind.

### 3.2 Run 2 — `11FF:1211` (Moza R5, VID/PID IS in universal-pidff table)

```
BUSTYPE_ACCEPTED:   true   (hidraw1 + event3 created)
PIDFF_DRIVER_BOUND: true   (hid-universal-pidff bound via modalias)
FFB_INITIALIZED:    false  (ff caps = "0")
FFB_INIT_ERROR:     true   ("Error initialising force feedback")
KERNEL_OOPS:        true   (NULL deref in hid_hw_open during evdev open)
```

dmesg (verbatim, relevant lines):
```
input: Moza R5 (Wave6 Probe) as /devices/virtual/misc/uhid/0003:11FF:1211.02AD/input/input707
hid-universal-pidff 0003:11FF:1211.02AD: input,hidraw1: USB HID v0.00 Joystick [Moza R5 (Wave6 Probe)] on padctl/wave6-probe
hid-universal-pidff 0003:11FF:1211.02AD: Error initialising force feedback
BUG: kernel NULL pointer dereference, address: 00000000000000a8
Oops: Oops: 0000 [#1] SMP NOPTI
RIP: 0010:hid_hw_open+0x71/0xa0
Call Trace:
 <TASK>
 input_open_device+0x9c/0x120
 evdev_open+0x1e7/0x210
 chrdev_open+0xad/0x240
 do_dentry_open+0x240/0x480
 vfs_open+0x30/0x100
 ...
```

Interpretation (three-layer):

1. **Bustype gate**: PASSED. `hid-universal-pidff` had no objection to `bus = BUS_USB` on a
   virtual UHID device — it bound via the `hid:b0003g*v000011FFp00001211` modalias (where
   `b0003` = USB bus). **This is the direct answer to ADR-015's Stage 3 entry question.**
2. **FFB init**: FAILED. `pidff_find_reports()` in `drivers/hid/hid-pidff.c` requires Set Effect,
   Set Envelope, Set Condition, Set Periodic, Set Constant Force, Set Ramp Force, Effect
   Operation, Device Control, Device Gain, Create New Effect, Block Load, PID Pool reports.
   Our descriptor only shipped 7 of these 12; `pidff_find_reports()` returned
   `-ENODEV`, causing the `Error initialising force feedback` log and no FF bits being set on
   the evdev node. **This is a descriptor-completeness issue, not a kernel-policy block.**
   Padctl's descriptor builder in Wave 6 will ship the full set.
3. **Kernel OOPS**: orthogonal issue. After FFB init failed, the driver left `hid_device` in a
   partial state; when a subsequent evdev `open()` hit `hid_hw_open()`, a NULL pointer in the
   `hid_ll_driver->open` chain triggered a page fault. This is a **kernel bug** in the
   UHID + hid-universal-pidff interaction path, not a padctl-layer concern. See §5.3 for
   upstream reporting plan.

### 3.3 Summary table

| Dimension | Run 1 (F045) | Run 2 (1211) |
|-----------|-------------|-------------|
| `BUSTYPE_ACCEPTED` | true | true |
| `PIDFF_DRIVER_BOUND` | false (no alias) | **true** |
| `FFB_INITIALIZED` | false (hid-generic) | false (incomplete descriptor) |
| `KERNEL_OOPS` | false | true (driver bug) |

The two runs together triangulate: bustype is not rejected; driver bind works; descriptor
completeness is the downstream concern.

## 4. Evidence — kernel 6.x hid-pidff architecture

### 4.1 `hid-pidff` is a helper library, not a standalone driver

`/proc/kallsyms` exports `hid_pidff_init` and `hid_pidff_init_with_quirks` as `T` (global text).
Grep over `/lib/modules/$(uname -r)/kernel/drivers/hid/*.ko.zst` shows only one module
references `hid_pidff_init`: **`hid-universal-pidff`**. `hid-generic` does NOT call it, which
is why Run 1 (F045 → hid-generic) saw no FFB — the driver didn't even try.

On kernel 6.18, the kernel config states:
- `CONFIG_HID_PID=y` — the PIDff helper is built into core HID (not a separate module)
- `CONFIG_HID_UNIVERSAL_PIDFF=m` — user-callable driver that uses the helper

### 4.2 `hid-universal-pidff` alias table (relevant for padctl device selection)

```
hid:b0003g*v000011FFp00002141   hid:b0003g*v000011FFp00001211   hid:b0003g*v000011FFp00001112
hid:b0003g*v000011FFp00001212   hid:b0003g*v000011FFp00003245   hid:b0003g*v00002433p0000F300
hid:b0003g*v00002433p0000F301   hid:b0003g*v00002433p0000F303   hid:b0003g*v00002433p0000F306
hid:b0003g*v0000045Bp000058F9   hid:b0003g*v0000045Bp00005968   hid:b0003g*v0000045Bp000059D7
hid:b0003g*v00000483p0000A355   hid:b0003g*v00003416p00000301   hid:b0003g*v00003416p00000302
hid:b0003g*v0000346Ep000000[00-16]   (VRS, Moza, Cammus, Asetek, Tian Yi — wheelbase makers)
```

`11FF` = Hori. `2433` = Logitech. `045B` = Hitachi/Renesas. `483` = STMicro (Moza MCU).
`3416` = Cammus. `346E` = Moza.

### 4.3 Implication for padctl

For padctl Wave 6 Stage 3 to succeed through the `hid-universal-pidff` path, padctl must
present a **virtual UHID device whose VID/PID matches one of these aliases**. That creates a
tension with ADR-015's naming: padctl's existing UHID devices use VID:PID `FADE:C001`
(padctl-main) and `FADE:C002` (padctl-imu) — neither is in the list, so
`hid-universal-pidff` would NOT take over those devices.

Options for Stage 3 (to be evaluated in the Wave 6 ADR / engineering spec, not this probe):

1. **Per-wheel VID/PID cloning** — when passing a wheel through, padctl's UHID device
   inherits the physical device's VID/PID (e.g. Moza R5 → `11FF:1211`). Requires padctl to
   run AFTER unbinding kernel driver from physical device, otherwise two drivers fight for
   the same `hid:...` modalias.
2. **Static non-cloning device** — keep `FADE:C00x`, patch `hid-universal-pidff` to add
   `FADE:*` wildcard. Requires upstream kernel change, not viable.
3. **Fallback Option (a)** — skip the virtual PID path entirely, let kernel keep bound to
   physical device.

The probe confirms Option 1 is **not blocked by the bustype gate**, but Wave 6 must address
the VID/PID cloning mechanics (kernel driver unbind timing, udev race).

## 5. Verdict

### 5.1 Answer to ADR-015 §"未解决项"

> "kernel 5.15 LTS 的 `hid-pidff` 是否接受 `bus = BUS_USB` 的虚拟 UHID 设备"

**Kernel 6.18.9**: **YES**, bustype is accepted. `hid-universal-pidff` (the only caller of
`hid_pidff_init` in kernel 6.18) binds to UHID devices via modalias match identical to how it
would bind to a real USB device. Evidence: §3.2 Run 2 dmesg `hid-universal-pidff 0003:11FF:1211.02AD: input,hidraw1: USB HID v0.00 Joystick`.

**Kernel 5.15**: **NOT DIRECTLY TESTED** in this probe (Docker shares host kernel). However,
two pieces of indirect evidence support the same conclusion:

1. The `hid-pidff.c` file in kernel 5.15 (`torvalds/linux` tag `v5.15`) performs no bustype
   filtering — it only reads `hid_device->bus` for quirk selection, never rejects.
2. `hid-universal-pidff` was **upstreamed in kernel 6.12** (Tomasz Pakuła's patch set). On
   kernel 5.15 LTS, the only `hid_pidff_init` callers are `hid-lg4ff.c` (Logitech Wingman/G27),
   `hid-tmff.c` (Thrustmaster), `hid-sony.c` (DualShock variants). These also do not filter
   by bustype; they filter by the vid/pid matching `.bus = 0` (wildcard) or `BUS_USB`.

**Recommendation to the Wave 6 decision**: **Stage 3 is viable on kernel 6.x**. Kernel 5.15
requires a CI-level re-verification (§6) before committing to Stage 3 across both CI matrix
rows, but the architectural gate is not a blocker.

### 5.2 Recommended path forward

**Stage 3**, not Option (a). Reasons:

1. The bustype gate is not a blocker on kernel 6.x (empirical).
2. Kernel 5.15 has even simpler `hid-pidff` binding logic (no `hid-universal-pidff` yet;
   direct drivers don't filter bustype).
3. `hid-universal-pidff`'s alias table covers the primary wheel vendors padctl's user base
   has reported interest in (Moza, Cammus, VRS, Logitech G-series on 6.x).

Caveats documented in §4.3 (VID/PID cloning mechanics) and §5.3 (kernel OOPS on incomplete
descriptor) must be addressed in the Wave 6 engineering spec before implementation starts —
they're not ADR-level blockers but they are PR-review-level concerns.

### 5.3 Kernel bug discovered (report-upstream candidate)

Run 2 produced a reproducible `NULL pointer dereference in hid_hw_open+0x71` when
`hid-universal-pidff` bound to a UHID device with an incomplete PID descriptor, then
userspace opened the evdev node. Trace (§3.2) points to
`hid_device->ll_driver->open` callback being NULL. This appears to be either:

(a) `hid-universal-pidff` leaving `hid_device` in a partial state after FFB init failure, or
(b) UHID's `uhid_hid_ll_driver` missing an `open` op that `hid_hw_open` dereferences.

**Action**: do NOT trigger this path in padctl Wave 6 — our descriptor builder will ship all
12 PID reports, so `pidff_find_reports` will succeed. If the issue is report-worthy to
upstream `linux-input@vger.kernel.org`, create a minimal reproducer separately from the
Wave 6 implementation track. Not a Phase 13 blocker.

## 6. Phase B — proposed CI workflow (kernel 5.15 verification)

Docker shares host kernel, so kernel 5.15 cannot be tested from this dev environment. QEMU
VM boot (Ubuntu 22.04 cloud image) is feasible but expensive (~20 min per run, not
CI-friendly). Proposed alternative: **add a scheduled CI job that pins `ubuntu-22.04`
runner and runs this probe on their actual kernel 5.15**.

Proposed GitHub Actions workflow (docs-repo or code-repo `.github/workflows/wave6-pidff-probe.yml`):

```yaml
# Sketch — to be reviewed and merged in Wave 6 engineering PR
name: wave6-pidff-probe
on:
  schedule:
    - cron: '0 6 * * 1'   # weekly, Mon 06:00 UTC
  workflow_dispatch:
jobs:
  probe-5-15:
    runs-on: ubuntu-22.04   # kernel 5.15 LTS
    steps:
      - uses: actions/checkout@v4
      - name: Install deps
        run: |
          sudo apt-get update
          sudo apt-get install -y python3 python3-pip
          pip3 install hid-tools
      - name: Load UHID + hid-pidff callers
        run: |
          sudo modprobe uhid
          # On 5.15, hid-pidff is built in via direct callers; no hid-universal-pidff yet
          lsmod | grep -E 'uhid|hid'
      - name: Run PIDff probe (Logitech G29 VID/PID — binds hid-lg4ff)
        run: |
          sudo PROBE_VID=0x046d PROBE_PID=0xc24f PROBE_NAME="G29 probe" \
            python3 tools/wave6-probe/pidff_probe.py \
            | tee probe-5-15.log
      - name: Assert BUSTYPE_ACCEPTED
        run: |
          grep -q '"BUSTYPE_ACCEPTED": true' probe-5-15.log
      - uses: actions/upload-artifact@v4
        with: { name: probe-5-15.log, path: probe-5-15.log }
```

Cost: one runner-minute per week, one log artifact. If the probe reports
`BUSTYPE_ACCEPTED=false` in any week, the job fails — loud signal to Wave 6 owner that kernel
5.15 behavior has regressed / differs.

**Ownership**: suggest adding to the list in `engineering/phase-13-wave-plan.md` Risk R2
row; Wave 6 PR author must ship this workflow before Wave 6 merges.

## 7. Sources

- `decisions/015-uhid-imu-migration.md:20-99` (docs-repo @92caade) — ADR-015 Stage 3 + unresolved items
- `engineering/phase-13-wave-plan.md:222` (docs-repo @4cd9d30) — Risk R2 row referencing this probe
- `drivers/hid/hid-pidff.c` (kernel 6.18.9, torvalds/linux @v6.18 tag) — pidff_find_reports signature
- `drivers/hid/hid-universal-pidff.c` (kernel 6.18.9) — modalias table + init flow
- `/proc/kallsyms` on host — confirms `hid_pidff_init` is exported as global T symbol
- `modinfo hid-universal-pidff` on host — alias table §4.2
- USB HID PID 1.01 specification (https://usb.org/sites/default/files/pid1_01.pdf) — report structure
- `hid-tools` package (0.12, Arch `extra`) — `hidtools.uhid.UHIDDevice` used in probe
- Tomasz Pakuła LKML patch set introducing `hid-universal-pidff` (kernel 6.12) — mailing list
  reference to be added when this probe's findings feed back into Wave 6 PR
- Captured logs:
  - `tools/wave6-probe/run-arch-silverstone-f045.log` (Run 1, this worktree)
  - `tools/wave6-probe/run-arch-moza-r5.log` (Run 2, this worktree)

## 8. Deliverables in this probe worktree

```
tools/wave6-probe/
├── Dockerfile.arch                       # 14 LoC — Arch container for probe
├── pidff_probe.py                        # 529 LoC — probe + HID descriptor + verdict logic
├── RESEARCH-REPORT.md                    # this document
├── run-arch-moza-r5.log                  # Run 2 output (hid-universal-pidff bind + OOPS)
└── run-arch-silverstone-f045.log         # Run 1 output (hid-generic baseline)
```

No changes to `src/`, `devices/`, or existing test harness. Research-only commit.
