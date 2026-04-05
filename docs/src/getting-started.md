# Getting Started

## Install via Package Manager

### Arch Linux (AUR)

```sh
yay -S padctl-git
```

A prebuilt binary package (`padctl-bin`) is also available in the AUR.

## Prerequisites

- **Zig 0.15+** (build from source)
- **Linux kernel ≥ 5.10** (uinput + hidraw support)
- **libusb-1.0** (system package, optional — pass `-Dlibusb=false` to build without)
- A HID gamepad accessible via `/dev/hidraw*`

## Build from Source

```sh
git clone https://github.com/BANANASJIM/padctl
cd padctl
zig build -Doptimize=ReleaseSafe
```

Optional build flags:

- `-Dlibusb=false` — disable libusb linkage (uses hidraw-only path)
- `-Dwasm=false` — disable WASM plugin runtime

## Install

```sh
sudo ./zig-out/bin/padctl install
```

This copies the binary, systemd service, device configs, and udev rules into `/usr`. It also runs `systemctl daemon-reload` and `udevadm trigger` automatically, and removes any legacy udev rules left by previous installs.

Custom prefix (e.g. for packaging):

```sh
sudo ./zig-out/bin/padctl install --prefix /usr --destdir "$DESTDIR"
```

### Additional Services

`padctl install` also sets up the following on all systems:

- **`padctl-resume.service`** — Restarts padctl after sleep/hibernate so USB devices reconnect cleanly.
- **`padctl-reconnect`** — A hotplug script triggered by udev when a controller is plugged in. It starts the daemon if not running, restarts it if failed, and re-applies the active mapping.
- **Driver conflict rules** — Auto-generated udev rules that unbind conflicting kernel drivers (e.g., `xpad`) from devices that padctl manages. Configured per-device via `block_kernel_drivers` in device TOML configs.

### Install a Mapping

To install a mapping config to `/etc/padctl/mappings/` during install:

```sh
sudo ./zig-out/bin/padctl install --mapping vader5
```

The `--mapping` flag is repeatable. Use `--force-mapping` to overwrite existing mappings.

> **Bazzite / immutable distros:** See the [Bazzite / Immutable Distros guide](immutable-install.md) for special installation steps.

## Verify

```sh
padctl scan
```

Lists all connected HID devices and shows whether a matching device config was found for each.

## Run as Service

```sh
systemctl --user enable --now padctl.service
```

The service runs padctl in daemon mode, scanning all config directories (user, system, and builtin) with automatic hotplug support. udev rules grant access via `uaccess` — no `sudo` needed for the logged-in user.

Check the daemon is running:

```sh
padctl status
```

## Run Manually

Bare invocation — padctl auto-discovers configs via XDG paths:

```sh
padctl
```

Or target specific configs:

```sh
# Single config
padctl --config /usr/share/padctl/devices/sony/dualsense.toml

# All configs in a directory
padctl --config-dir /usr/share/padctl/devices/
```

## Validate a Config

```sh
padctl --validate devices/sony/dualsense.toml
```

Exit 0 = valid. Exit 1 = validation errors printed to stderr. Exit 2 = file not found or parse failure.

## Generate Device Docs

```sh
padctl --doc-gen --config devices/sony/dualsense.toml
```

## User Config

padctl reads `~/.config/padctl/config.toml` to set per-device defaults:

```toml
[[device]]
name = "Flydigi Vader 5 Pro"
default_mapping = "fps"
```

On daemon start, padctl matches the connected device name and loads the named mapping profile automatically from `~/.config/padctl/mappings/fps.toml`.

## CLI Reference

```sh
padctl switch <name> [--device <id>]       # switch mapping at runtime
padctl status [--socket <path>]            # show daemon status
padctl devices [--socket <path>]           # list connected devices
padctl list-mappings [--config-dir <dir>]  # list available mapping profiles
padctl reload [--pid <pid>]                # send SIGHUP to reload configs
padctl config list                         # show XDG config search paths
padctl config init [--device] [--preset]   # interactive mapping creator
padctl config edit [name]                  # open mapping in $VISUAL/$EDITOR
padctl config test [--config] [--mapping]  # live input preview
```

## udev Permissions

padctl needs access to `/dev/hidraw*` and `/dev/uinput`. The `padctl install` command generates and installs udev rules automatically from device configs.

If you need to regenerate rules after adding custom device configs:

```sh
sudo padctl install
```

The udev rules use `TAG+="uaccess"` to grant the logged-in user access to supported devices without requiring root.
