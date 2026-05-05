# Troubleshooting

Common runtime failures that have generated repeat issue reports, with diagnostics and workarounds.

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

**Symptoms:**

- `systemctl --user status padctl.service` shows:
  ```
  Failed at step CAPABILITIES spawning /usr/bin/padctl: Operation not permitted
  Main process exited, code=exited, status=218/CAPABILITIES
  ```
- The daemon never starts; `padctl status` returns `cannot connect to padctl daemon`.
- The restart counter climbs in `journalctl --user -u padctl.service`.

**Root cause:** the user service unit declares `LockPersonality=true`, `ProtectClock=true`, and
`NoNewPrivileges=true`. systemd 257+ enforces these options more strictly on user instances; the
kernel rejects the capability adjustments required to apply them, killing the process before it
starts.

**Workaround:** install a drop-in that clears the three offending directives:

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

Reference: [issue #220](https://github.com/BANANASJIM/padctl/issues/220)

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

Alternatively, use the provided `Dockerfile.wave5` (Debian bookworm + Zig 0.15.2, glibc 2.36)
for reproducible builds.

Reference: [issue #147](https://github.com/BANANASJIM/padctl/issues/147)
