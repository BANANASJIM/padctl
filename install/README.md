# Installation

## Recommended: `padctl install`

```sh
sudo padctl install
```

Installs binary, systemd service, udev rules, and device configs in one step.

Options:

```sh
sudo padctl install --prefix /usr --destdir /tmp/staging  # package builds
```

After installation, enable the daemon:

```sh
systemctl enable --now padctl.service
```

## Manual installation

```sh
cp padctl padctl-capture padctl-debug /usr/bin/
cp padctl.service /usr/lib/systemd/system/
cp 99-padctl.rules /usr/lib/udev/rules.d/
cp -r devices/ /usr/share/padctl/devices/
systemctl daemon-reload
udevadm control --reload-rules && udevadm trigger
```
