# Phase 3 Brief: Capture Tool, Debug TUI, Netlink Hotplug, systemd

## What

Deliver four capabilities that together reduce new device onboarding to "no code, no docs" and make padctl production-system-ready:

1. **padctl-capture** — interactive hidraw recorder that auto-detects magic bytes, button bit-toggles, and axes, then emits a device config TOML skeleton.
2. **padctl-debug TUI** — real-time visualiser (sticks, triggers, buttons, gyro/IMU, raw hex) driven by the existing `interpreter.processReport()` with zero duplicated parse logic.
3. **netlink KOBJECT_UEVENT hotplug** — Supervisor-owned netlink socket; kernel-driven `add`/`remove` replaces the exponential-backoff reconnect polling introduced in Phase 2c.
4. **systemd template service + udev rules** — `padctl@.service` bound to the device unit, VID:PID-matched udev rules that set `SYSTEMD_WANTS` on device arrival.

## Why

Phase 2c delivered multi-device Supervisor and per-device threading. Phase 3 closes the two remaining gaps: tooling (capture, debug) that lets anyone adapt a new controller without reading the protocol, and system integration (netlink, systemd) that lets padctl run unattended in production.

## Scope

| Area | Files |
|------|-------|
| Capture tool | `src/tools/capture.zig` (new), `build.zig` (extend) |
| Debug TUI | `src/tools/debug.zig` (new), `build.zig` (extend) |
| netlink hotplug | `src/io/netlink.zig` (new), `src/supervisor.zig` (extend) |
| Supervisor attach/detach | `src/supervisor.zig` (extend), `src/io/hidraw.zig` (extend) |
| systemd / udev dist files | `dist/systemd/padctl@.service` (new), `dist/udev/80-padctl.rules` (new) |
| Phase 3 tests | `src/test/phase3_test.zig` (new) |

## Out of Scope

- Output DSL emulate extensions (VID/PID substitution, custom capabilities) — deferred
- `gyro.activate` toggle semantics — Phase 3/4 evaluation
- `padctl install` subcommand (copy service/udev files) — T3 provides templates; CLI convenience deferred
- inotify automatic config-change detection — Phase 4 (SIGHUP sufficient)
- Full HID report descriptor parsing — Phase 4 (vendor descriptors unreliable; statistical algorithm takes priority)

## Success Criteria

- `padctl-capture` records 30 s → correctly identifies magic bytes + ≥ 2 button bits + ≥ 2 axes (L2)
- Generated TOML skeleton parses without error via `device config parser` (L1)
- `padctl-debug` loads `flydigi-vader5.toml` → live display of stick coordinates, buttons, gyro (L2)
- `padctl-debug` reuses `interpreter.processReport()`; zero duplicated parse code (code review)
- `padctl@.service` passes `systemd-analyze verify` (L0)
- `80-padctl.rules` passes `udevadm verify` (L0)
- netlink `add` uevent → Supervisor correctly attaches DeviceInstance (L1)
- netlink `remove` uevent → Supervisor correctly detaches and joins (L1)
- 5-cycle plug/unplug → no fd or memory leak, validated via L1 mock (L1)
- `zig build test` (L0 + L1) all pass, CI-runnable
