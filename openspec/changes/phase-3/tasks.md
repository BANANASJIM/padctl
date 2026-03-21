# Phase 3 Tasks

## Dependency Graph

```
Wave 0 (parallel, no deps):
  T1  padctl-capture — hidraw recorder + auto-analysis + TOML skeleton
  T2  padctl-debug TUI — real-time visualiser, reuses interpreter
  T3  systemd service + udev rules templates (static files)

Wave 1 (depends on Phase 2c Supervisor):
  T4  netlink KOBJECT_UEVENT hotplug — socket + uevent parse + Supervisor integration

Wave 2 (integration):
  T5  multi-device lifecycle — Supervisor attach/detach, dedup, respawn replacement
  T6  end-to-end validation — capture → config → debug → daemon + hotplug
```

> Layer column: L0 = pure functions / static files, always CI; L1 = mock fd, always CI; L2 = real device, local manual only.

---

## T1: padctl-capture

**Files**: `src/tools/capture.zig` (new), `build.zig` (extend with `capture` target)

**Changes**:

Four-phase pipeline as a single binary. Phase 1 and 2 require real fd; Phase 3 and 4 are pure functions testable in L1.

Phase 3 analyser interface:

```zig
pub const AnalysisResult = struct {
    report_size: u16,
    magic: []const MagicByte,   // {offset, value}
    buttons: []const ButtonCandidate, // {byte_offset, bit, toggle_count, confidence}
    axes: []const AxisCandidate,      // {offset, type, transform, value_range}
};

pub fn analyse(frames: []const Frame, allocator: std.mem.Allocator) !AnalysisResult
```

Phase 4 TOML emitter:

```zig
pub fn emitToml(result: AnalysisResult, info: DeviceInfo, writer: anytype) !void
```

CLI:
```
padctl-capture [--device /dev/hidrawN] [--duration 30s] [--output device.toml]
```

**Tests (L1)**:
- Inject pre-recorded frame sequence → magic bytes detected correctly
- 6 toggles on bit 3 of byte 11 (3 press + 3 release) → button marked high-confidence
- Two-byte pair with range -32767..32767 → identified as i16le axis
- Generated TOML skeleton is syntactically valid; `device config parser` parses without error
- Multiple report sizes in frame set → separate `[[report]]` blocks emitted

---

## T2: padctl-debug TUI

**Files**: `src/tools/debug.zig` (new), `build.zig` (extend with `debug` target)

**Changes**:

Loads device config TOML, opens hidraw fd, calls `interpreter.processReport()` on each raw report, renders current `GamepadState` to terminal at ≤ 60 fps.

Core loop:

```zig
// ppoll: hidraw_fd (POLLIN) + stdin_fd (POLLIN, key input) + timer_fd (16 ms refresh)
// on hidraw POLLIN: read report → interpreter.processReport() → update state
// on timer expiry: re-render
// on key Q: exit; key T: toggle test mode; key R: toggle raw hex
```

TUI rendering: libvaxis (primary). If libvaxis dependency rejected at review, fall back to direct ANSI escape with termios raw mode — no behaviour change, only rendering backend changes.

**Tests (L1)**:
- Inject known report bytes → rendered output contains correct coordinate values (string match)
- Layout functions: at 80×24 each region has correct coordinates and does not overflow
- `[Q]` key event → exit path triggered
- Interpreter called with exact raw bytes received; no additional parsing in debug.zig

---

## T3: systemd Service + udev Rules

**Files**: `dist/systemd/padctl@.service` (new), `dist/udev/80-padctl.rules` (new)

**Changes**:

Static distribution files only; no code changes.

`dist/systemd/padctl@.service`:
```ini
[Unit]
Description=padctl gamepad daemon (%i)
After=local-fs.target
BindsTo=dev-%i.device
After=dev-%i.device

[Service]
Type=simple
ExecStart=/usr/bin/padctl --device /dev/%i
Restart=on-failure
RestartSec=2s
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
DeviceAllow=/dev/%i rw
DeviceAllow=/dev/uinput rw
SupplementaryGroups=input

[Install]
WantedBy=multi-user.target
```

`dist/udev/80-padctl.rules` — one rule per supported VID:PID:
```
ACTION=="add", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="37d7", ATTRS{idProduct}=="2401", \
  TAG+="systemd", ENV{SYSTEMD_WANTS}="padctl@%k.service", \
  MODE="0660", GROUP="input"
```

**Tests (L0)**:
- `systemd-analyze verify dist/systemd/padctl@.service` exits 0
- `udevadm verify dist/udev/80-padctl.rules` exits 0

---

## T4: netlink KOBJECT_UEVENT Hotplug

**Files**: `src/io/netlink.zig` (new), `src/supervisor.zig` (extend)

**Changes**:

`src/io/netlink.zig` — socket lifecycle + parse:

```zig
pub fn openNetlinkUevent() !posix.fd_t
    // socket(AF_NETLINK, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_KOBJECT_UEVENT)
    // bind: nl_groups = 1

pub const UeventAction = enum { add, remove, other };

pub const Uevent = struct {
    action: UeventAction,
    devname: ?[]const u8,  // null if DEVNAME absent
    subsystem: ?[]const u8,
};

pub fn parseUevent(buf: []const u8) Uevent
```

`src/supervisor.zig` additions:

```zig
netlink_fd: posix.fd_t,

// called in ppoll loop when netlink_fd POLLIN
fn drainNetlink(self: *Supervisor) void
    // recv loop until EAGAIN
    // parse each message
    // hidraw add   → self.attach(devname)
    // hidraw remove → self.detach(devname)
    // other → discard
```

Supervisor `run()` ppoll fd set gains `netlink_fd`.

**Tests (L1)**:
- Inject `add@.../hidraw/hidraw3\0SUBSYSTEM=hidraw\0DEVNAME=hidraw3\0` → `attach("hidraw3")` called
- Inject `remove` message → `detach("hidraw3")` called
- Non-hidraw subsystem message → no attach/detach call
- Burst of 4 messages in one recv cycle → all 4 processed before returning to ppoll

---

## T5: Multi-device Lifecycle

**Files**: `src/supervisor.zig` (extend), `src/io/hidraw.zig` (extend)

**Changes**:

Complete `attach` and `detach` implementations:

```zig
pub fn attach(self: *Supervisor, devname: []const u8) !void
    // open /dev/{devname}
    // HIDIOCGRAWINFO → VID/PID
    // find DeviceConfig matching VID/PID; if none → return (not an error)
    // HIDIOCGRAWPHYS → physical path (dedup key)
    // if physical path already tracked → return (duplicate add guard)
    // DeviceInstance.init() → Thread.spawn(DeviceInstance.run)
    // store in instances map keyed by physical path; also by devname for detach

pub fn detach(self: *Supervisor, devname: []const u8) void
    // look up instance by devname
    // if not found → return
    // DeviceInstance.stop() → join → free
    // remove from instances map
```

Phase 2c exponential-backoff respawn is retired for netlink-driven reconnect: when a DeviceInstance exits due to device disconnect, Supervisor does not schedule respawn — the next `attach` call arrives via netlink `add` uevent.

**Tests (L1)**:
- Same devname `attach` twice (duplicate add uevent) → only one instance created
- `detach` unknown devname → no panic, no error
- `attach` → `detach` → `attach` same devname → second instance correctly created (new object)
- Two different devnames `attach` simultaneously → two independent threads, no state sharing

---

## T6: End-to-end Validation

**Files**: `src/test/phase3_test.zig` (new)

**L0 + L1 scenarios** (all run under `zig build test`):

- Analyser unit tests (T1): magic bytes, button detection, axis detection, TOML emit
- TUI layout unit tests (T2): region coordinates at 80×24
- netlink parse unit tests (T4): uevent format, hidraw filter, burst drain
- Supervisor attach/detach lifecycle tests (T5): dedup, double-attach, attach-detach-attach

**L2 scenarios** (manual, local device required, guarded by `error.SkipZigTest`):

- `padctl-capture` records 30 s → identifies ≥ 2 buttons + ≥ 2 axes → generated TOML parses cleanly
- `padctl-debug` loads real config → live display updates on controller input
- `padctl` running with `--config-dir` → plug USB device → netlink auto-attaches → unplug → auto-detaches
- Install `dist/systemd/padctl@.service` + `dist/udev/80-padctl.rules` → plug device → service auto-starts → `journalctl -u padctl@hidrawN` shows log output
