# Getting Started

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

This copies the binary, systemd service, device configs, and udev rules into `/usr`. It also runs `systemctl daemon-reload` and `udevadm trigger` automatically.

Custom prefix (e.g. for packaging):

```sh
sudo ./zig-out/bin/padctl install --prefix /usr --destdir "$DESTDIR"
```

## Verify

```sh
padctl scan
```

Lists all connected HID devices and shows whether a matching device config was found for each.

## Run as Service

```sh
sudo systemctl enable --now padctl.service
```

The service runs padctl in daemon mode, scanning all config directories (user, system, and builtin) with automatic hotplug support.

Check the daemon is running:

```sh
padctl status
```

## Run Manually

```sh
# Single config
sudo padctl --config /usr/share/padctl/devices/sony/dualsense.toml

# All configs in a directory
sudo padctl --config-dir /usr/share/padctl/devices/
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

## udev Permissions

padctl needs access to `/dev/hidraw*` and `/dev/uinput`. The `padctl install` command generates and installs udev rules automatically from device configs.

If you need to regenerate rules after adding custom device configs:

```sh
sudo padctl install
```

The udev rules use `TAG+="uaccess"` to grant the logged-in user access to supported devices without requiring root.
