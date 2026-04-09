# padctl

**Universal Linux gamepad compatibility layer**

> **This project is very much a work in progress.** Feedback, bug reports, and feature requests are welcome — please [open an issue](https://github.com/BANANASJIM/padctl/issues)!

![CI](https://github.com/BANANASJIM/padctl/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-LGPL--2.1--or--later-blue)

## What is padctl

padctl is a userspace daemon that maps vendor-specific USB/HID gamepad reports to standard Linux input events via uinput. Device support is driven entirely by declarative TOML configs — no kernel patches, no custom drivers.

## Features

- **Declarative device configs** — add new devices with a `.toml` file, no recompilation
- **Layer system** — hold/toggle/tap-hold layers with independent remaps, gyro, and stick modes
- **Gyro mouse** — gyro-to-mouse with sensitivity, deadzone, smoothing, and curve controls
- **Stick mouse/scroll** — left or right stick as mouse or scroll wheel
- **Macros** — named key sequences bound to any button
- **Exclusive device grab** — grabs the hidraw/evdev node so the original device is hidden from other processes while padctl is running
- **Multi-device + hotplug** — automatic device detection and per-device threads via netlink
- **Hot-reload** — `SIGHUP` re-reads configs without restart, diffed per physical device
- **Force feedback** — FF_RUMBLE passthrough from uinput to physical device with userspace auto-stop timer (compensates for uinput not using the kernel's ff-memless driver)
- **Runtime mapping switch** — `padctl switch <name>` changes profiles without restart
- **Persistent mapping** — `padctl install --mapping <name>` writes a device binding to `/etc/padctl/config.toml` that auto-applies on every boot
- **User config** — `~/.config/padctl/config.toml` for per-device default mappings (system fallback: `/etc/padctl/config.toml`)
- **CLI tools** — `padctl status`, `padctl devices`, `padctl list-mappings`, `padctl config init/edit/test`

## Architecture

```text
+----------------------------+
| Physical Device (USB / BT) |
+----------------------------+
              |
      +-------+-------+
      |               |
      v               v
+----------------+  +-------------------+
| HID / hidraw   |  | Vendor / libusb   |
| io/hidraw.zig  |  | io/usbraw.zig     |
+----------------+  +-------------------+
       \              /
        \            /
         v          v
      +--------------------+
      | DeviceIO (unified) |
      +--------------------+
                |
                v
      +--------------------+
      | main loop (ppoll)  |
      +--------------------+
                |
      +---------+---------+
      |                   |
      v                   v
+------------------+  +------------------+
| config/device.zig|  | io/hotplug.zig   |
| devices/*.toml   |  | udev monitor     |
+------------------+  +------------------+
          |
          v
+-----------------------------------------+
| [input rules] -> interpreter -> state   |
| [output]     -> OutputConfig            |
+-----------------------------------------+
                      |
                      v
           +----------------------+
           | mapper (layer/remap) |
           +----------------------+
                |            |
                v            v
      +----------------+  +------------------+
      | gamepad output |  | generic output   |
      | uinput + aux   |  | generic + touch  |
      +----------------+  +------------------+
```

## Supported Devices

Ships with configs for **12 devices** across 8 vendors:

**Sony** (3) · **Nintendo** (1) · **Microsoft** (1) · **Valve** (1) · **8BitDo** (1) · **Flydigi** (2) · **HORI** (1) · **Lenovo** (2)

[Full device list with feature matrix →](https://bananasjim.github.io/padctl/devices/)

## Installation

### Arch Linux (AUR)

```sh
yay -S padctl-bin   # prebuilt binary
yay -S padctl-git   # build from source
```

### Debian / Ubuntu

```sh
curl -fLO https://github.com/BANANASJIM/padctl/releases/latest/download/padctl_0.1.0_amd64.deb
sudo dpkg -i padctl_0.1.0_amd64.deb
```

For arm64, replace `amd64` with `arm64`.

### From Source

See [Quick Start](#quick-start) below. For other distros, see [CONTRIBUTING.md](CONTRIBUTING.md#packaging).

## Quick Start

```sh
zig build                                    # build from source
sudo zig-out/bin/padctl install              # install binary, configs, udev rules, systemd service
sudo systemctl enable --now padctl.service   # start daemon with hotplug support
padctl config init                           # create ~/.config/padctl/config.toml interactively
padctl status                                # check daemon and detected devices
padctl switch <name>                         # switch mapping profile without restart
```

See the [getting started guide](https://bananasjim.github.io/padctl/getting-started.html) for detailed setup.

## CLI Reference

| Command | Description |
|---------|-------------|
| `padctl status` | Show daemon state and active devices |
| `padctl devices` | List detected HID/USB devices |
| `padctl list-mappings` | Show available mapping profiles |
| `padctl switch <name>` | Switch to a named mapping profile |
| `padctl config init` | Create user config interactively |
| `padctl config edit` | Open user config in `$EDITOR` |
| `padctl config test` | Validate config without applying |
| `padctl scan` | Re-scan for connected devices |

## Build

**Requirements:** Zig 0.15+, libusb-1.0

```sh
zig build              # build all binaries
zig build test         # run unit tests
zig build check-all    # all checks (test + safe + fmt)
```

| Flag | Default | Effect |
|------|---------|--------|
| `-Dlibusb=false` | `true` | Disable libusb linkage (hidraw-only) |
| `-Dwasm=false` | `true` | Disable WASM plugin runtime |

## Bazzite / Immutable Distros

On immutable distributions (Bazzite, Fedora Atomic, etc.) where `/usr` is read-only, use the bootstrap script for a complete one-command setup:

```sh
curl -fsSL https://raw.githubusercontent.com/BANANASJIM/padctl/main/scripts/bazzite-setup.sh \
  | bash -s -- --mapping vader5
```

Replace `vader5` with the mapping for your controller, or omit `--mapping` to install without a mapping. When run locally (`bash scripts/bazzite-setup.sh`), the script prompts for mapping selection interactively.

See the [Bazzite / Immutable Distros guide](docs/src/immutable-install.md) for full details on what the install does, the `--immutable` flag, security notes, and mapping management.

> **Tested on:** Bazzite (Fedora Atomic / ostree). Other immutable distros may work but are untested.

## Documentation

Full documentation: [bananasjim.github.io/padctl](https://bananasjim.github.io/padctl/)

- [Getting started](https://bananasjim.github.io/padctl/getting-started.html)
- [Device config reference](https://bananasjim.github.io/padctl/device-config.html)
- [Mapping config reference](https://bananasjim.github.io/padctl/mapping-config.html)
- [Supported devices](https://bananasjim.github.io/padctl/devices/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding device configs or contributing code.

## License

LGPL-2.1-or-later — see [LICENSE](LICENSE).
