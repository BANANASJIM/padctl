# Phase 3 Test Plan

## Test Layers

| Layer | Description | CI |
|-------|-------------|-----|
| L0 | Pure functions / static files — no fd, no kernel | Yes |
| L1 | Mock fd / injected bytes — no `/dev/hidraw`, no real hardware | Yes |
| L2 | Real devices — physical controller, `/dev/uinput` available | Manual only |

All L0 + L1 tests live under `zig build test` and must pass in CI.

---

## T1: padctl-capture (L1)

### Magic byte detection

| # | Input | Expected |
|---|-------|----------|
| 1 | 100 frames; bytes 0-2 always `0x5a 0xa5 0xef`; rest vary | magic: `[{0, 0x5a}, {1, 0xa5}, {2, 0xef}]` |
| 2 | Frames with byte 0 varying across all values | byte 0 not in magic list |
| 3 | Single-frame recording | no magic bytes reported (insufficient baseline) |

### Button detection

| # | Input | Expected |
|---|-------|----------|
| 4 | Bit 3 of byte 11 toggles 6 times (3 press + 3 release) | button candidate at byte 11 bit 3, confidence high |
| 5 | Bit toggles only 1 time (odd count — press without release) | not reported as high-confidence button |
| 6 | Four bits change simultaneously in one frame | multi-bit change; axis suspicion flag set; button confidence lowered |
| 7 | No bit ever changes across all frames | zero button candidates |

### Axis detection

| # | Input | Expected |
|---|-------|----------|
| 8 | Bytes 3-4 as i16le, range -32468..32102 | axis candidate: offset 3, type i16le |
| 9 | Byte 8, range 0..255 monotonic | axis candidate: offset 8, type u8 |
| 10 | Bytes 5-6 as i16le, values decrease as user pushes up | transform = "negate" suggested |
| 11 | Bytes 3-4 with range 0..10 (minimal variation) | not reported as axis |

### TOML skeleton

| # | Input | Expected |
|---|-------|----------|
| 12 | AnalysisResult with 1 magic, 2 buttons, 2 axes | emitted TOML contains `[[report]]`, `[report.fields]`, `[report.button_group]`; parses without error |
| 13 | Frames of two distinct sizes (16 and 32 bytes) | two `[[report]]` blocks emitted |
| 14 | Bytes with no detected pattern | annotated `# unknown: offset N` in TOML comment |

---

## T2: padctl-debug TUI (L1)

### Render correctness

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Inject report with LX = -1234 | rendered output contains string `-1234` in Sticks region |
| 2 | Inject report with button A pressed | `[A]` rendered as highlighted (inverse or colour) |
| 3 | Inject report with LT = 50% | trigger bar shows approximately half-filled |
| 4 | Inject report with gyro X = +2345 | gyro X bar and value rendered correctly |

### Layout bounds

| # | Scenario | Expected |
|---|----------|----------|
| 5 | Layout calculation at 80×24 | Sticks, Triggers, Buttons, Gyro, IMU, Raw Hex regions all within bounds; no region overflows |
| 6 | Layout calculation at 132×43 (wide terminal) | no region overflows; regions scale or remain fixed-size |

### Key input

| # | Scenario | Expected |
|---|----------|----------|
| 7 | Key `Q` received | exit path triggered; loop terminates |
| 8 | Key `T` received | test-mode toggle invoked |
| 9 | Key `R` received | raw hex display toggled |

### No code duplication

| # | Criterion | Pass condition |
|---|-----------|----------------|
| 10 | Code review | `debug.zig` contains no HID byte parsing logic; all interpretation delegated to `interpreter.processReport()` |

---

## T3: systemd Service + udev Rules (L0)

| # | Check | Expected |
|---|-------|----------|
| 1 | `systemd-analyze verify dist/systemd/padctl@.service` | exit code 0; no errors |
| 2 | `udevadm verify dist/udev/80-padctl.rules` | exit code 0; no errors |
| 3 | Service file contains `BindsTo=dev-%i.device` | present (grep check) |
| 4 | Service file contains `NoNewPrivileges=yes` | present (grep check) |
| 5 | udev rule has `TAG+="systemd"` | present (grep check) |
| 6 | udev rule has `ENV{SYSTEMD_WANTS}` | present (grep check) |
| 7 | udev rule has no `RUN` directive | absent (negative grep check) |

---

## T4: netlink KOBJECT_UEVENT (L1)

### uevent parsing

| # | Input | Expected |
|---|-------|----------|
| 1 | `add@/devices/.../hidraw/hidraw3\0SUBSYSTEM=hidraw\0DEVNAME=hidraw3\0` | `{action: add, devname: "hidraw3", subsystem: "hidraw"}` |
| 2 | `remove@/devices/.../hidraw/hidraw3\0SUBSYSTEM=hidraw\0DEVNAME=hidraw3\0` | `{action: remove, devname: "hidraw3"}` |
| 3 | `add@/devices/.../input/input7\0SUBSYSTEM=input\0` | `{action: add, subsystem: "input"}` — non-hidraw |
| 4 | Message with no `DEVNAME` key | `devname: null` |
| 5 | Message with no `SUBSYSTEM` key | `subsystem: null` |

### Supervisor integration

| # | Scenario | Expected |
|---|----------|----------|
| 6 | hidraw `add` uevent delivered via mock fd | `Supervisor.attach("hidraw3")` called once |
| 7 | hidraw `remove` uevent delivered | `Supervisor.detach("hidraw3")` called once |
| 8 | Non-hidraw `add` uevent | neither `attach` nor `detach` called |
| 9 | 4 events in single recv burst | all 4 processed; ppoll re-entered normally after drain |
| 10 | netlink fd readable; `recv` returns `EAGAIN` on second call | drain loop exits; no infinite loop |

---

## T5: Multi-device Lifecycle (L1)

### attach / detach correctness

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `attach("hidraw3")` with matching config | one DeviceInstance created; thread spawned |
| 2 | `attach("hidraw3")` called again (duplicate add) | second call is no-op; still only one instance |
| 3 | `detach("hidraw3")` for running instance | `DeviceInstance.stop()` called; thread joined; instance freed |
| 4 | `detach("hidraw99")` for unknown devname | returns without panic |
| 5 | `attach` with no config matching VID/PID | returns without creating instance; no error |
| 6 | `attach("hidraw3")` → `detach("hidraw3")` → `attach("hidraw3")` | third call creates a new instance normally |

### Concurrent devices

| # | Scenario | Expected |
|---|----------|----------|
| 7 | `attach("hidraw3")` + `attach("hidraw4")` (different configs) | two independent threads; each holds its own fd set |
| 8 | Event injected into instance A's mock fd | instance B state unchanged |
| 9 | `detach("hidraw3")` while hidraw4 running | hidraw4 instance unaffected; continues processing |

### Leak check

| # | Scenario | Expected |
|---|----------|----------|
| 10 | attach → detach cycled 5 times for same devname | fd count constant; no allocation growth (tracked via mock allocator count) |

---

## T6: End-to-end Integration (L0/L1/L2)

### CI suite (L0/L1)

| # | Scenario | Expected |
|---|----------|----------|
| 1 | All T1 analyser tests (L1) | pass |
| 2 | All T2 layout + key tests (L1) | pass |
| 3 | All T3 static file checks (L0) | pass |
| 4 | All T4 netlink parse + integration tests (L1) | pass |
| 5 | All T5 lifecycle tests (L1) | pass |
| 6 | `zig build test` exits 0 | all L0 + L1 cases pass |

### Manual validation (L2, local device required)

| # | Scenario | Pass Condition |
|---|----------|----------------|
| 7 | `padctl-capture --duration 30s` on real controller | ≥ 2 button bits + ≥ 2 axes identified; generated TOML parses via `device config parser` |
| 8 | `padctl-debug --config devices/flydigi-vader5.toml` | stick coordinates, button states, gyro values update in real time |
| 9 | `padctl --config-dir devices/` running; plug USB device | device attached automatically; log shows attach message |
| 10 | Unplug USB device while daemon running | device detached; log shows detach; daemon keeps running |
| 11 | Re-plug same device | re-attaches normally; no crash |
| 12 | Install `padctl@.service` + `80-padctl.rules`; plug known VID:PID device | `padctl@hidrawN.service` starts automatically; `journalctl -u` shows log output |

L2 tests use `error.SkipZigTest` guard when no real hidraw device is present.
