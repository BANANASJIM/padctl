# Installing padctl on Bazzite / Immutable Linux

This guide covers installing padctl on immutable Linux distributions where `/usr` is read-only (Bazzite, Fedora Atomic, Universal Blue, etc.).

## Quick Install

Run the bootstrap script — it handles everything automatically:

```sh
curl -fsSL https://raw.githubusercontent.com/BANANASJIM/padctl/main/scripts/bazzite-setup.sh \
  | bash -s -- --mapping vader5
```

Replace `vader5` with the mapping for your controller, or omit `--mapping` to install without a mapping. Available mappings are in the `mappings/` directory.

When run locally (not via `curl`), the script prompts for mapping selection interactively if `--mapping` is not provided:

```sh
bash scripts/bazzite-setup.sh
```

What the script does:

1. **Detects** immutable OS (checks for ostree or read-only `/usr`)
2. **Installs dependencies** via Homebrew (Zig compiler, libusb) — no system reboot needed
3. **Clones and builds** padctl from source with `ReleaseSafe` optimization
4. **Installs** the daemon, systemd services, udev rules, and reconnect scripts
5. **Persists** the selected mapping as a device binding in `/etc/padctl/config.toml` (auto-applies on every boot)
6. **Applies** the mapping to the current session
7. **Verifies** the installation

Safe to re-run for updates — it rebuilds and reinstalls while preserving your mapping configs in `~/.config/padctl/mappings/`.

### Script Options

| Flag | Description |
|------|-------------|
| `--mapping <name>` | Install a mapping and auto-apply on boot |
| `--repo-url <url>` | Use a fork or alternative repo URL |
| `--branch <name>` | Clone/checkout a specific branch |
| `<path>` | Use an existing local repo instead of cloning |

## What the Install Does

### Why `/usr` is a Problem

On immutable distros, `/usr` is a read-only filesystem overlay. The standard `padctl install` places systemd service files and udev rules under `/usr/lib/`, which works on regular Linux but fails silently on immutable systems — the files exist but systemd can't resolve them through symlinks during boot.

### How `--immutable` Fixes It

The `padctl install --immutable` flag changes where system files are placed:

| File | Standard (`/usr`) | Immutable (`--immutable`) |
|------|-------------------|---------------------------|
| Binaries | `/usr/bin/` | `/usr/local/bin/` |
| Service file | `/usr/lib/systemd/system/` | `/etc/systemd/system/` |
| Service drop-in | *(not created)* | `/etc/systemd/system/padctl.service.d/immutable.conf` |
| Resume service | `/usr/lib/systemd/system/` | `/etc/systemd/system/` |
| udev rules | `/usr/lib/udev/rules.d/` | `/etc/udev/rules.d/` |
| Device configs | `/usr/share/padctl/devices/` | `/usr/local/share/padctl/devices/` |

Files in `/etc/` persist across system updates on immutable distros.

### The `immutable.conf` Drop-in

The immutable install creates a systemd drop-in override with these changes:

| Directive | Purpose |
|-----------|---------|
| `DeviceAllow=` | Resets device allowlist to permit all device access (see security note below) |
| `ProtectHome=read-only` | Allows reading user mapping configs from `~/.config/padctl/mappings/` |
| `TimeoutStopSec=3` | Short stop timeout for processes stuck in uninterruptible I/O |
| `KillMode=mixed` | SIGTERM to main process + SIGKILL to stuck worker threads |

**Security note on `DeviceAllow=`:** The base service restricts device access to `hidraw`, `uinput`, and `input` devices. The immutable drop-in clears this allowlist because libusb needs USB bus nodes (`/dev/bus/usb/`) for vendor-specific control transfers (init commands, rumble, LED control). The specific `char-usb_device` cgroup class was tested and does not provide sufficient access. Standard (non-immutable) installs are not affected and retain the restrictive allowlist.

## Managing Mappings

Mapping configs can live in two places:

| Location | Priority | Editable without sudo |
|----------|----------|-----------------------|
| `~/.config/padctl/mappings/` | First (highest) | Yes |
| `/etc/padctl/mappings/` | Second | No (requires sudo) |

`padctl switch <name>` searches `~/.config/` first, so you can customize mappings without root:

```sh
# Edit your personal mapping
nano ~/.config/padctl/mappings/vader5.toml

# Apply changes immediately (no sudo needed)
padctl switch vader5
```

The `/etc/padctl/mappings/` copy is used as a fallback by the hotplug reconnect script (which runs as root).

### Auto-apply on boot

When you install with `--mapping`, the installer writes a device binding to `/etc/padctl/config.toml`:

```toml
version = 1

[[device]]
name = "Flydigi Vader 5 Pro"
default_mapping = "vader5"
```

The daemon reads this file at startup and auto-applies the mapping — no manual `padctl switch` needed after reboot. User-level overrides in `~/.config/padctl/config.toml` take priority when available.

You can also persist a mapping change after switching at runtime:

```sh
padctl switch vader5 --persist
```

This copies your user mapping and config to `/etc/padctl/` via sudo, so the change survives reboots without re-running the installer.

## Uninstalling

```sh
sudo padctl uninstall --immutable --prefix /usr/local --mapping vader5
```

This removes all installed files including the `/etc/` service files and the specified mapping. User configs in `~/.config/padctl/` are never touched.
