# Troubleshooting

Common runtime failures that have generated repeat issue reports, with diagnostics and workarounds.

---

## `padctl status` says it cannot connect to the daemon

**Symptoms:**

- `padctl status` exits non-zero or reports that the daemon socket is unreachable.
- `padctl switch <name>` cannot apply a mapping.

**Check the user service:**

```sh
systemctl --user status padctl.service
journalctl --user -u padctl.service -n 80
```

**Common causes:**

- `padctl install` was run with `--no-enable` or `--no-start`.
- `padctl install` was run as root without `SUDO_USER`, so it could not locate the real user's systemd user manager.
- The user has not logged in since install, or headless boot needs linger.

**Fix:**

```sh
systemctl --user daemon-reload
systemctl --user enable --now padctl.service
```

For headless setups or boot-before-login:

```sh
sudo loginctl enable-linger $USER
```

---

## Permission denied opening `hidraw`, `uinput`, or `uhid`

**Symptoms:**

- The daemon starts but logs `PermissionDenied`, `AccessDenied`, or open failures
  for `/dev/hidraw*`, `/dev/uinput`, or `/dev/uhid`.
- `padctl scan` sees the controller but the daemon cannot manage it.

**Fix:**

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger
systemctl --user restart padctl.service
```

Then unplug and replug the controller. Graphical sessions normally receive access
through `TAG+="uaccess"` ACLs. SSH/headless sessions may also need input-group
membership:

```sh
sudo usermod -aG input $USER
```

Log out and back in after changing groups.

---

## Controller is visible but no matching config is found

**Symptoms:**

- `padctl scan` lists the HID device but says no config matched.
- The daemon log says no devices were found in config dirs.

**Check installed configs:**

```sh
find /usr/share/padctl/devices -name '*.toml' | sort
padctl --validate /usr/share/padctl/devices/sony/dualsense.toml
```

If `/usr/share/padctl/devices` is missing or empty, reinstall the current package.
If your device is not listed, capture it and open a device-config contribution.

---

## Kernel driver or another mapper still owns the controller

**Symptoms:**

- The physical controller continues to appear directly in games while padctl is running.
- padctl cannot exclusively grab the device, or duplicate inputs appear.
- Xbox-compatible devices still bind to `xpad` even though their device TOML sets
  `block_kernel_drivers`.

**Fix:**

```sh
sudo padctl install
sudo udevadm trigger
systemctl --user restart padctl.service
```

Then unplug and replug the controller. For devices with `block_kernel_drivers`,
the installer writes driver-block udev rules and also tries to unbind already
attached matching devices during install.

---

## `padctl install` warns "source 'devices/' directory not found"

**Symptoms:**

- `padctl install` prints a warning about a missing `devices/` directory.
- After install, `padctl scan` or the daemon log reports "no devices found in config dirs".
- The daemon starts but no controller is recognized.

**Root cause:** pre-v0.1.5 `.deb` packages stripped one directory level from the `devices/` tree
during packaging, leaving device TOML files absent from the installed prefix (issue #216).
Fixed in v0.1.5+.

**Workaround:** upgrade to v0.1.5 or later.

**Verify the fix:**

```sh
dpkg -L padctl | grep 'devices/'
```

The output should list multiple `.toml` files under `/usr/share/padctl/devices/<vendor>/`.
If the list is empty, the old package is still installed — re-download and reinstall.

---

## User service exits with `status=218/CAPABILITIES` on Ubuntu 26.04 / systemd 257+

**Fixed in v0.1.6.** If you are running an older release, use the workaround below.

**Symptoms:**

- `systemctl --user status padctl.service` shows:
  ```
  Failed at step CAPABILITIES spawning /usr/bin/padctl: Operation not permitted
  Main process exited, code=exited, status=218/CAPABILITIES
  ```
- The daemon never starts; `padctl status` returns `cannot connect to padctl daemon`.
- The restart counter climbs in `journalctl --user -u padctl.service`.

**Root cause (pre-v0.1.6):** the user service unit declared `LockPersonality=true`,
`ProtectClock=true`, and `NoNewPrivileges=true`. systemd 257+ enforces these options more
strictly on user instances; the kernel rejects the capability adjustments required to apply
them, killing the process before it starts.

**Workaround (pre-v0.1.6 only):** install a drop-in that clears the three offending directives:

```sh
mkdir -p ~/.config/systemd/user/padctl.service.d
cat > ~/.config/systemd/user/padctl.service.d/no-cap-lockdown.conf <<'EOF'
[Service]
LockPersonality=
ProtectClock=
NoNewPrivileges=
EOF
systemctl --user daemon-reload
systemctl --user restart padctl
```

Assigning an empty value to a systemd directive resets it to the default (unset). The functional
and security impact is small: the daemon runs as your user with no privileged operations, so
removing these three flags does not expand what it can do.

Reference: [issue #216](https://github.com/BANANASJIM/padctl/issues/216)

---

## Build fails on Arch Linux: `relocation R_X86_64_PC64 against symbol ...`

**Symptoms:**

- `zig build` fails during linking:
  ```
  relocation R_X86_64_PC64 against symbol '__libc_start_main' can not be used when making a PIE object
  ```
  or similar `R_X86_64_PC64` / `.sframe section is unsupported` errors.
- Affects Arch Linux with glibc 2.43 or later.

**Root cause:** glibc 2.43+ adds `.sframe` sections to `crt1.o` startup objects that Zig 0.15.x's
linker does not handle. This is an upstream Zig limitation, not a padctl bug.

**Workaround:** build against the musl static target:

```sh
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
```

The resulting binary is fully static and works on any Linux distribution regardless of glibc
version. This is the same target used for official padctl release tarballs.

Alternatively, build inside the canonical Docker image (`./scripts/padctl-docker build`,
Debian bookworm + glibc 2.36) for a reproducible build environment.

Reference: [issue #147](https://github.com/BANANASJIM/padctl/issues/147)
