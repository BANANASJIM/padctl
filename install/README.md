# Installation

## Service files

Copy service files to the systemd unit directory and reload:

```sh
cp padctl.service padctl@.service /etc/systemd/system/
systemctl daemon-reload
```

Enable the daemon mode service (multi-device, uses netlink hotplug):

```sh
systemctl enable --now padctl.service
```

Or enable the per-device template service (udev-triggered):

```sh
systemctl enable padctl@flydigi-vader5.service
```

## udev rules

Copy the rules file and reload:

```sh
cp 99-padctl.rules /etc/udev/rules.d/
udevadm control --reload-rules
```

On next device plug-in, udev triggers `padctl@<name>.service` automatically.

## Modes

| Mode | Service | Trigger |
|------|---------|---------|
| Daemon (multi-device) | `padctl.service` | starts at boot, manages all devices via netlink |
| Per-device | `padctl@.service` | udev starts one instance per device |

Use one mode at a time — do not run both simultaneously.
