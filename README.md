# padctl

Universal Linux gamepad compatibility layer.

padctl maps vendor-specific USB/HID reports from gamepads to standard Linux input events via uinput, using declarative TOML device configs — no kernel patches, no custom drivers.

## Architecture

```
┌─────────────────────────────────┐
│  Mapping config (TOML)          │  remap / layers / gyro / macros
│  Device config  (TOML)          │  report layout, field offsets, transforms
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  padctl daemon (userspace)      │
│                                 │
│  Supervisor ──► DeviceInstance  │  one thread per physical device
│      │              │           │
│   netlink         HidrawDevice  │  reads /dev/hidrawN
│  (hotplug)        Interpreter   │  applies field mappings + transforms
│                   Mapper/Layer  │  applies mapping config
│                   MacroPlayer   │  plays back timed key sequences
└────────────────┬────────────────┘
                 │
                 ▼
        /dev/uinput  →  standard evdev gamepad / mouse / keyboard
```

## Features

- **Declarative TOML config** — add or modify device support without recompiling
- **Layer system** — hold/toggle/tap-hold layers per mapping config; each layer can override remaps, gyro mode, and stick mode independently
- **Gyro mouse** — map gyro axes to REL_X/REL_Y with configurable sensitivity, deadzone, smoothing, and curve; activate on a button hold
- **Stick mouse/scroll** — left or right stick in `mouse` or `scroll` mode with dt-based accumulation
- **Macros** — named sequences of tap/down/up/delay steps bound to any button
- **Multi-device** — `--config-dir` globs all *.toml, deduplicates by physical path, runs each device in its own thread
- **Hot-reload** — SIGHUP re-reads configs without restarting; diffed per physical device (new devices spawned, removed devices stopped, unchanged devices untouched)
- **Hotplug** — netlink `UEVENT` listener adds/removes devices at runtime
- **Force feedback** — FF_RUMBLE passthrough: uinput receives game vibration commands and forwards them to the physical device via HID output reports
- **12 device configs** — ships with configs for Sony, Nintendo, Microsoft, Valve, 8BitDo, Flydigi, HORI, and Lenovo devices

## Quick Start

### Install

```sh
sudo padctl install
```

This copies the binary, systemd service, device configs, and udev rules into `/usr`. Runs `systemctl daemon-reload` and `udevadm trigger` automatically.

Custom prefix (e.g. for packaging):

```sh
sudo padctl install --prefix /usr --destdir "$DESTDIR"
```

### Scan

```sh
padctl scan
```

Lists all connected HID devices and whether a device config was found for each.

### Run

```sh
# Daemon mode — manages all matched devices, handles hotplug
sudo systemctl enable --now padctl.service

# Or run directly with a single config
sudo padctl --config /usr/share/padctl/devices/sony/dualsense.toml
```

## CLI Subcommands

| Subcommand | Description |
|---|---|
| `install [--prefix] [--destdir]` | Install binary, service, udev rules, device configs |
| `scan [--config-dir <dir>]` | List connected HID devices and config match status |
| `reload [--pid <pid>]` | Send SIGHUP to running daemon (triggers hot-reload) |
| `config list` | List device and mapping configs found in XDG search paths |
| `config init [--device] [--preset]` | Interactively create a mapping in `~/.config/padctl/mappings/` |
| `config edit [name]` | Open mapping in `$VISUAL`/`$EDITOR`; validates on exit |
| `config test [--config] [--mapping]` | Live input preview (Ctrl-C to exit) |
| `--validate <path> [...]` | Validate one or more device config files; exit 0/1/2 |
| `--doc-gen --config <path> [--output <dir>]` | Generate Markdown device reference from config(s) |

## XDG Config Paths

padctl follows the XDG Base Directory spec. On bare invocation it searches for device configs in priority order:

| Priority | Path |
|---|---|
| 1 (user) | `$XDG_CONFIG_HOME/padctl/devices/` or `~/.config/padctl/devices/` |
| 2 (system) | `/etc/padctl/devices/` |
| 3 (builtin) | `/usr/share/padctl/devices/` |

The same three-tier search applies to mapping configs (`devices/` → `mappings/`).

User-level configs always take precedence. Place personal overrides in `~/.config/padctl/`.

## Supported Devices

| Vendor | Model | Config | Gyro | FF |
|---|---|---|---|---|
| Sony | DualSense (PS5) | `devices/sony/dualsense.toml` | yes | yes |
| Sony | DualShock 4 | `devices/sony/dualshock4.toml` | yes | yes |
| Sony | DualShock 4 v2 | `devices/sony/dualshock4-v2.toml` | yes | yes |
| Nintendo | Switch Pro Controller | `devices/nintendo/switch-pro.toml` | — | — |
| Microsoft | Xbox Elite Series 2 | `devices/microsoft/xbox-elite.toml` | — | yes |
| Valve | Steam Deck | `devices/valve/steam-deck.toml` | yes | yes |
| 8BitDo | Ultimate Controller | `devices/8bitdo/ultimate.toml` | — | — |
| Flydigi | Vader 5 Pro | `devices/flydigi/vader5.toml` | yes | yes |
| Flydigi | Vader 4 Pro | `devices/flydigi/vader4-pro.toml` | yes | — |
| HORI | Horipad Steam | `devices/hori/horipad-steam.toml` | yes | — |
| Lenovo | Legion Go | `devices/lenovo/legion-go.toml` | — | — |
| Lenovo | Legion Go S | `devices/lenovo/legion-go-s.toml` | — | yes |

## Device Config Example

```toml
[device]
name = "Sony DualSense"
vid = 0x054c
pid = 0x0ce6

[[device.interface]]
id = 3
class = "hid"

[[report]]
name = "usb"
interface = 3
size = 64

[report.match]
offset = 0
expect = [0x01]

[report.fields]
left_x  = { offset = 1, type = "u8", transform = "scale(-32768, 32767)" }
left_y  = { offset = 2, type = "u8", transform = "scale(-32768, 32767), negate" }
lt      = { offset = 5, type = "u8" }
cross   = { bits = [8, 4, 1] }
gyro_x  = { offset = 16, type = "i16le" }
```

## Mapping Config Example

```toml
name = "fps"

[gyro]
mode = "mouse"
activate = "L3"
sensitivity = 2.0
deadzone = 300

[[layer]]
name = "shift"
trigger = "R1"
activation = "hold"
tap = "R1"

[layer.remap]
south = "KEY_SPACE"

[[macro]]
name = "rush"
steps = [
  { tap = "KEY_W" },
  { delay = 50 },
  { tap = "KEY_W" },
]
```

## Building from Source

**Requirements:** Zig 0.15+, libusb-1.0 (system package)

```sh
zig build
# outputs: zig-out/bin/padctl  zig-out/bin/padctl-capture  zig-out/bin/padctl-debug
```

Build flags:

| Flag | Default | Description |
|------|---------|-------------|
| `-Dlibusb=false` | `true` | Disable libusb-1.0 linkage (hidraw-only path) |
| `-Dwasm=false` | `true` | Disable WASM plugin runtime |

Testing:

```sh
zig build test              # unit tests (Layer 0+1, no privileges)
zig build check-fmt         # verify code formatting
zig build check-all         # all checks (test + tsan + safe + fmt)
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a device config or contribute code.

## License

LGPL-2.1-or-later — see [LICENSE](LICENSE).
