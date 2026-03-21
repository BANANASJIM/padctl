# Phase 3 Design: Capture Tool, Debug TUI, Netlink Hotplug, systemd

## Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|-----------|-----------|
| D1 | capture output format | hid-recorder compatible (`R:`/`E:` lines) | Interoperates with existing HID toolchain; enables offline re-analysis |
| D2 | button detection algorithm | XOR baseline diff + even toggle_count + time-window correlation | No HID descriptor required; vendor descriptors unreliable; pure statistics sufficient |
| D3 | TUI library | libvaxis (primary); direct ANSI escape (fallback) | libvaxis Widget system mature; event loop integrates hidraw fd; fallback if binary size unacceptable |
| D4 | debug TUI parse logic | call `interpreter.processReport()` directly | Zero code duplication; behaviour identical to main daemon |
| D5 | netlink multicast group | GROUP_KERNEL (1) | No udevd dependency; minimal footprint |
| D6 | netlink fd ownership | Supervisor (not DeviceInstance) | Hotplug is a Supervisor-level concern; DeviceInstance knows nothing about device enumeration |
| D7 | respawn strategy | netlink `add` replaces exponential-backoff polling | Kernel-event-driven; Bluetooth reconnect covered by hidraw POLLHUP → netlink re-add |
| D8 | systemd deployment | template service `padctl@.service` + `BindsTo` | One instance per device; systemd auto-stops on device removal |
| D9 | log output | stderr + `<N>` prefix | Zero dependency; journald auto-recognises severity level |
| D10 | build targets | `zig build capture` / `zig build debug` as independent binaries | Not mixed with main daemon; deploy on demand |

## Architecture

### padctl-capture: Four-Phase Pipeline

```
Phase 1 — Device discovery
  enumerate /dev/hidraw*
  HIDIOCGRAWINFO → VID/PID
  HIDIOCGRAWNAME → device name
  HIDIOCGRDESC   → report descriptor (binary, for reference)

Phase 2 — Interactive recording
  prompt user to operate each control
  ppoll hidraw fd → record {timestamp_us, bytes[]}
  terminate on Ctrl-C or --duration elapsed
  output: hid-recorder format (R: descriptor line, E: event lines)

Phase 3 — Auto-analysis
  report size detection: frame length frequency
  magic bytes: find invariant prefix bytes across all frames
  button detection: XOR per frame vs baseline; bit positions with
    toggle_count >= 2, even (press+release pairs), single-bit
    change per time window → high-confidence button candidates
  axis detection: adjacent two-byte pairs as i16le candidates;
    value range -32767..32767 → i16le; 0..255 → u8;
    Y-axis negate detection (decreasing value on upward push)

Phase 4 — TOML skeleton generation
  [device] VID/PID/name
  [[report]] size + magic match
  [report.fields] detected axes (offset + type + transform)
  [report.button_group] detected buttons (offset + bit index)
  unrecognised bytes annotated: # unknown: offset N
```

CLI:
```
padctl-capture [--device /dev/hidrawN] [--duration 30s] [--output device.toml]
```

### padctl-debug TUI

Layout (80×24 terminal):

```
┌─ Sticks ──────────┬─ Triggers ─┬─ Buttons ──────────┐
│  [LX: -1234]      │ LT ████░░  │ [A] [B] [X] [Y]   │
│  ·····←☉→·····    │ RT ██████  │ [LB] [RB]          │
│  ···········      │            │ [SEL] [START]       │
│  [RX:  5678]      ├─ DPad ────┤ [L3] [R3]           │
│                   │    ↑       │ [C][Z][M1-M4]       │
│                   │  ← · →    │                     │
│                   │    ↓       │                     │
├─ Gyro ────────────┴────────────┴─ IMU ───────────────┤
│ X: ████████░░░░  +2345         AX: +4012             │
│ Y: ░░░░████████  -1234         AY: -0128             │
│ Z: ░░░░██████░░  +0567         AZ: +4096             │
├─ Raw Hex ──────────────────────────────────────────────┤
│ 5a a5 ef f0 12 ab cd 00 11 22 33 44 55 66 77 88 ... │
└─ [Q]uit  [T]est mode  [R]aw toggle ──────────────────┘
```

Key properties:
- Loads device config TOML; calls `interpreter.processReport()` — no separate parse logic
- 16 ms refresh cap (60 fps); actual rate follows device report rate
- Raw hex dump highlights recognised fields vs unknown bytes
- `[T]` toggles test mode (sends enable/disable command); `[Q]` quits

TUI implementation choice:
- Primary: libvaxis (vxfw Widget system + event loop + hidraw fd integration)
- Fallback: direct ANSI escape (`ESC[row;colH` + termios raw mode) if libvaxis weight unacceptable

### netlink KOBJECT_UEVENT Hotplug

Socket setup:
```
fd = socket(AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC | SOCK_NONBLOCK,
            NETLINK_KOBJECT_UEVENT)
bind: nl_groups = 1  (MONITOR_GROUP_KERNEL)
```

uevent message format: NUL-separated key=value pairs; first line is `action@devpath`.
Maximum size: 2048 bytes (`UEVENT_BUFFER_SIZE`).

Parse + dispatch:
1. Extract `action` from first line.
2. Scan key=value pairs for `SUBSYSTEM` and `DEVNAME`.
3. Non-hidraw subsystem → discard.
4. `ACTION=add` → `Supervisor.attach(devname)`.
5. `ACTION=remove` → `Supervisor.detach(devname)`.

Supervisor ppoll fd set (after Phase 3):
```
stop_fd      — signalfd: SIGTERM + SIGINT
hup_fd       — signalfd: SIGHUP
netlink_fd   — KOBJECT_UEVENT add/remove
```
(DeviceInstance threads each hold their own hidraw fd set.)

### Supervisor attach / detach

```zig
pub fn attach(self: *Supervisor, devname: []const u8) !void
    // read VID/PID from /dev/{devname} via HIDIOCGRAWINFO
    // find matching DeviceConfig by VID/PID
    // read physical path (HIDIOCGRAWPHYS) for dedup key
    // if physical path already in instances → ignore (race guard)
    // create DeviceInstance → spawn thread

pub fn detach(self: *Supervisor, devname: []const u8) void
    // find DeviceInstance by devname
    // if not found → return (no panic)
    // DeviceInstance.stop() → join → free
```

Bluetooth disconnect path:
- `hidraw fd POLLHUP` → DeviceInstance self-cleans (detach).
- Bluetooth reconnect → kernel emits `add` uevent → `Supervisor.attach`.
- No polling required; no exponential backoff for netlink-driven reconnect.

### systemd Template Service

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

`dist/udev/80-padctl.rules` — per VID:PID rules:
- `TAG+="systemd"` — required for systemd to process `SYSTEMD_WANTS`
- `ENV{SYSTEMD_WANTS}="padctl@%k.service"` — triggers service on device arrival
- `MODE="0660", GROUP="input"` — non-root access for `input` group members
- `%k` = kernel device name (e.g. `hidraw3`)
- No `RUN` directive — udev kills forked long-running processes after event handling

## Data Flow

### capture pipeline

```
hidraw fd  →  frame buffer  →  analyser  →  skeleton generator  →  TOML file
                 ↑
         hid-recorder format (R:/E: lines) written concurrently to stdout/log
```

### debug TUI

```
hidraw fd  →  raw bytes  →  interpreter.processReport()  →  GamepadState
                                                                  ↓
                                                        vxfw render / ANSI draw
```

### hotplug

```
kernel  →  netlink_fd POLLIN  →  Supervisor recv  →  parse uevent
                                                          ↓
                                             attach(devname) / detach(devname)
                                                          ↓
                                               DeviceInstance thread spawn/join
```

## Edge Cases

| Case | Handling |
|------|----------|
| Duplicate `add` uevent for same physical path | `attach` checks physical path map; second call is a no-op |
| `detach` for unknown devname | Returns without panic; no error log (spurious remove events possible) |
| `attach` with no matching config | Ignored silently; not an error |
| netlink socket buffer overflow (burst events) | `SOCK_NONBLOCK`; drain in a loop until `EAGAIN` each ppoll cycle |
| capture: all frames identical (device idle) | Analysis reports zero button candidates; TOML skeleton generated with only magic bytes |
| capture: multiple report sizes (multi-report device) | Each size gets its own `[[report]]` block |
| debug: config references fields not in current report | Fields shown as `--`; no crash |
| systemd `BindsTo`: device removed mid-run | systemd sends SIGTERM → padctl exits cleanly via signalfd |
