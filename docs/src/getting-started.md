# Getting Started

## Prerequisites

- Linux kernel ≥ 5.10 (uinput + hidraw)
- A HID gamepad accessible via `/dev/hidraw*`

## Installation

### Arch Linux (AUR)

```sh
yay -S padctl
# or prebuilt binary:
yay -S padctl-bin
```

### From Source

```sh
git clone https://github.com/jim-z/padctl
cd padctl
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/padctl /usr/local/bin/
```

## Basic Usage

Point padctl at a device config and run:

```sh
sudo padctl --config devices/sony/dualsense.toml
```

For automatic multi-device discovery:

```sh
sudo padctl --config-dir /etc/padctl/devices/
```

## Validating a Config

```sh
padctl --validate devices/sony/dualsense.toml
```

Exit 0 = valid. Exit 1 = validation errors printed to stderr.

## Generating Device Docs

```sh
padctl --doc-gen devices/sony/dualsense.toml
# writes docs/src/devices/sony-dualsense.md
```

## systemd Service

```sh
# per-device instance
sudo systemctl enable --now padctl@dualsense
```

## udev Rule

Install `99-padctl.rules` to grant non-root access to `/dev/hidraw*`:

```sh
sudo cp install/99-padctl.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```
