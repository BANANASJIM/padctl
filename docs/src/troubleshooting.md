# Troubleshooting

Run `padctl doctor` first and paste its output in bug reports. It checks the
daemon socket, the systemd service state, kernel driver bindings, and every
supported device in one pass, and prints next-step hints. The manual flows
below remain as fallback when `doctor` is unavailable or inconclusive.

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

`padctl doctor` resolves the daemon's real device config directories and lists
every device TOML it finds — prefer it over a hardcoded path, because the
install prefix differs by platform (ostree/immutable distros install under
`/usr/local/share/padctl/devices`, not `/usr/share/padctl/devices`):

```sh
padctl doctor
```

To inspect a specific config manually, validate it from the directory doctor
reported, e.g.:

```sh
padctl --validate /usr/share/padctl/devices/sony/dualsense.toml
```

If doctor finds zero device TOMLs, reinstall the current package.
If your device is not listed, capture it and open a device-config contribution.

---

## Mapping target is invalid for symbol keys such as comma or dot

**Symptoms:**

- On v0.1.20 or earlier, `padctl config test <mapping>` rejects symbol
  targets such as `KEY_COMMA` or `KEY_DOT`.
- Bare or lowercase spellings such as `comma`, `dot`, `KEY_comma`, or
  `KEY_dot` are rejected on every version.
- You want to bind a button such as `RM` or `LM` to punctuation.

**Fix:** use the Linux evdev `KEY_*` name and run v0.1.21 or later:

```toml
[remap]
RM = "KEY_COMMA"
LM = "KEY_DOT"
C  = "KEY_KPSLASH"
Z  = "KEY_KPASTERISK"
```

Supported symbol targets include `KEY_COMMA`, `KEY_DOT`, `KEY_SLASH`,
`KEY_BACKSLASH`, `KEY_SEMICOLON`, `KEY_APOSTROPHE`, `KEY_LEFTBRACE`,
`KEY_RIGHTBRACE`, `KEY_GRAVE`, `KEY_KPSLASH`, `KEY_KPASTERISK`,
`KEY_KPMINUS`, `KEY_KPPLUS`, `KEY_KPENTER`, `KEY_KPDOT`, and `KEY_KP0`
through `KEY_KP9`.

Lowercase names and bare punctuation names are not accepted; padctl follows the
kernel event-code names so config files remain unambiguous.

Reference: issue #470.

---

## Vader 5 still appears as Xbox Elite 2 after adding `output.emulate`

**Symptoms:**

- You copied `devices/flydigi/vader5.toml` from `/usr/share` or
  `/usr/local/share` into `~/.config/padctl/devices/` and added
  `emulate = "dualsense-edge"`, but Steam Input still shows Xbox Elite 2.
- You added `output.emulate` or `output_profile` to a mapping file and nothing
  changed.

**Fix:** inspect and select a device-declared output profile:

```sh
padctl output-profile list --device "Flydigi Vader 5 Pro"
padctl output-profile select dualsense-edge --device "Flydigi Vader 5 Pro"
```

If `dualsense-edge-native` is missing from the list, an older Vader TOML under
`~/.config/padctl/devices/` is shadowing the packaged config. Update that copy
from the same padctl release or remove it so the packaged config is visible,
then run the list command again.

The CLI saves the same per-device setting shown below. A running user daemon
normally notices the atomic config update and reconnects the virtual device:

```toml
# ~/.config/padctl/config.toml
version = 1

[[device]]
name = "Flydigi Vader 5 Pro"
default_mapping = "vader5"
output_profile = "dualsense-edge"
```

Then restart or reload the daemon:

```sh
padctl reload
# or
systemctl --user restart padctl.service
```

`output_profile` is a per-device startup choice, not a mapping option. The
Vader 5 builtin device config keeps Xbox Elite 2 as the default and exposes
`dualsense-edge` plus `dualsense-edge-native` as opt-in profiles. Do not create
a second Vader 5 device TOML with the same physical VID/PID unless you are
intentionally replacing the installed config; the higher-priority XDG config
owns that physical identity.

If your service was installed with a system fallback and has no `HOME`, put the
same `[[device]]` entry in `/etc/padctl/config.toml` or use the documented
persist flow. `padctl doctor` shows which config paths the daemon can read.

Choose between:

- `dualsense-edge`: the unchanged generic uinput identity/layout profile with
  `-32768..32767` sticks. It does not speak the native DualSense HID protocol.
- `dualsense-edge-native`: wired USB-only native Edge UHID with `0..255` axes,
  Fn buttons/paddles, two C/Z touch contacts and click, and accelerometer/gyro
  in the same UHID report. Compatible SDL HIDAPI rumble is forwarded to the
  Vader `[commands.rumble]` path.

The native profile has no separate IMU companion, though Vader's auxiliary
mouse may still coexist. Bluetooth, private configuration reports,
audio/speaker endpoints, and adaptive triggers are not implemented. If stick
precision is the priority, keep the 16-bit generic profile.

Reference: issue #471.

---

## Vader 5 rumble stays on, disconnects, or controls lag during vibration

**Symptoms:**

- The controller continues vibrating after a short rumble burst.
- Vader 5 controls lag or stop responding while rumble is active.
- Logs show a device disconnect/reconnect while rumble was recently active.

**Current behavior:** v0.1.20 and later explicitly quiesce physical rumble after
device init and after hotplug/rebind, so a fresh hidraw fd receives a neutral
rumble frame even if the old fd disappeared before the teardown-time stop could
reach hardware. Persistent non-disconnect rumble write failures are now logged
and dropped without stopping the input loop; only a real disconnect tears down
the device instance.

**Collect evidence if it still reproduces:**

```sh
padctl dump enable
# reproduce the stuck or lagging rumble
padctl dump export --period 1h -o rumble.log
padctl dump disable
padctl doctor > doctor.txt
```

Attach both files to the issue. Useful log signals are `HID_WRITE`, `FF_PLAY`,
`FF_STOP`, `SCHED`, `DISCONNECT`, and `retry limit exceeded`. A clean report
should include whether the controller was already on before boot, whether it was
on the dock, and which game/action produced the vibration pattern.

Reference: issue #65 remains open for hardware verification.

---

## Kernel driver or another mapper still owns the controller

**Symptoms:**

- The physical controller continues to appear directly in games while padctl is running.
- padctl cannot exclusively grab the device, or duplicate inputs appear.
- Xbox-compatible devices still bind to `xpad` even though their device TOML sets
  `block_kernel_drivers`.

**Package-manager install fix:**

```sh
systemctl --user daemon-reload
systemctl --user enable --now padctl.service
sudo udevadm control --reload-rules
```

Then unplug and replug the controller. The driver-block udev rule unbinds the
kernel driver only while a padctl daemon is running (its control socket exists),
so no extra setup step is needed — and a stopped daemon means the kernel driver
keeps the device.

**Source install fix:**

```sh
sudo padctl install
systemctl --user restart padctl.service
```

Then unplug and replug the controller. For devices with `block_kernel_drivers`,
the source installer installs the udev rules and also tries to unbind already
attached matching devices during install. Do not use `sudo padctl install` as
the normal fix for AUR or `.deb` installs because it rewrites files that the
package manager owns.

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
