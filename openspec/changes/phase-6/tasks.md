# Tasks: Phase 6 — Install CLI, XDG Paths, InputPlumber Devices, COPR, Config UX

Branch: `feat/phase-6`
Commit: (leave blank — filled after implementation)

## Execution plan

Wave 0 (T1/T2/T3) parallel; Wave 1 (T4–T8) after Wave 0, T6 after T5; Wave 2 (T9–T12) after
Wave 1, T9 after T4; T13 after all.

---

## Wave 0 — CLI subcommands

### T1: `padctl install` subcommand

- [ ] Create `src/cli/install.zig`
  - [ ] Assert UID=0; exit 1 with `"sudo padctl install"` message otherwise
  - [ ] Copy binary to `$DESTDIR$PREFIX/bin/padctl`
  - [ ] Write embedded `padctl.service` string to `$DESTDIR$PREFIX/lib/systemd/system/padctl.service`
  - [ ] Copy `devices/*.toml` to `$DESTDIR$PREFIX/share/padctl/devices/`
  - [ ] Read installed TOML VID/PID; generate `99-padctl.rules` to `$DESTDIR$PREFIX/lib/udev/rules.d/`
  - [ ] If `DESTDIR=""`: run `systemctl daemon-reload` + `udevadm control --reload-rules && udevadm trigger`
  - [ ] Print install summary with all installed paths
- [ ] Register `install` subcommand in `src/main.zig`
- [ ] Update `install/padctl.service`: add `PIDFile=/run/padctl.pid`, add `--pid-file /run/padctl.pid` to `ExecStart`
- [ ] Delete `install/padctl@.service`
- [ ] Update `install/README.md` to recommend `padctl install`

### T2: `padctl scan` subcommand

- [ ] Create `src/cli/scan.zig`
  - [ ] Enumerate `/dev/hidraw*` via `HIDIOCGRAWINFO` (VID/PID/name)
  - [ ] Deduplicate multi-interface devices via `HIDIOCGRAWPHYS`
  - [ ] Match VID/PID against `--config-dir` (or XDG paths after T4 merges)
  - [ ] Print formatted report (device / VID:PID / matched TOML or "no matching config")
  - [ ] Print summary line; exit 0 even with unknown devices
- [ ] Register `scan` subcommand in `src/main.zig`

### T3: `padctl reload` subcommand

- [ ] Create `src/cli/reload.zig`
  - [ ] PID resolution: `--pid` arg → `/run/padctl.pid` → `pgrep -x padctl`
  - [ ] Send SIGHUP; wait 500ms; confirm process alive via `ps -p`
  - [ ] Print `"Reloaded."` on success; exit 1 with `"padctl daemon not running"` if PID not found
- [ ] Register `reload` subcommand in `src/main.zig`
- [ ] Implement `--pid-file` flag in `src/main.zig` (write PID on daemon start)

---

## Wave 1 — XDG paths, device TOMLs, release, COPR

### T4: XDG three-layer config paths

- [ ] Create `src/config/paths.zig`
  - [ ] `userConfigDir(allocator)` — `$XDG_CONFIG_HOME/padctl` or `~/.config/padctl`
  - [ ] `systemConfigDir()` — `/etc/padctl`
  - [ ] `dataDir()` — `/usr/share/padctl`
  - [ ] `searchDeviceConfigs(allocator, out)` — merge three layers, user > system > builtin
  - [ ] `searchMappingConfig(allocator, device_name)` — return first match by priority
- [ ] Modify `src/main.zig`: bare invocation (no `--config`/`--config-dir`) calls `searchDeviceConfigs`
- [ ] Explicit `--config`/`--config-dir` flags still take priority over XDG

### T5: InputPlumber Rust→TOML transcription guide

- [ ] Create `docs/contributing/device-toml-from-inputplumber.md`
  - [ ] Byte offset direct mapping (`bytes = "N"` → `offset = N`)
  - [ ] Bit numbering conversion: MSB0 → LSB0: `lsb_bit = (byte_offset * 8 + 7) - msb_bit`
  - [ ] Type mapping table: `u8`, `i16 + endian="lsb"` → `i16le`, single-bit bool → `bits = [byte, lsb_start, 1]`
  - [ ] Enum field handling: extract variants → TOML lookup table
  - [ ] License note: protocol facts not copyright-protected; never copy Rust source or comments verbatim
- [ ] Acceptance: perform trial transcription of Legion Go S; validate with `padctl --validate`

### T6: Batch device TOML generation

- [ ] Create `devices/lenovo/legion-go-s.toml` (VID 0x1a86, PID 0xe310/0xe311)
  - Gamepad report id=0x06 (32B): sticks i8 center=0 (LX:4, LY:5, RX:6, RY:7); triggers u8 (LT:8, RT:9); buttons 4B (10–13)
  - IMU report id=0x05 (9B)
  - Rumble output id=0x04 (9B): `{0x04, 0x00, 0x00, 0x00, L:u8, R:u8, 0x00, 0x00, 0x00}`
- [ ] Create `devices/hori/horipad-steam.toml` (VID 0x0f0d, PID 0x0196/0x01ab)
  - BT input report id=0x07 (287B): sticks u8 center=128 (LX:4, LY:5, RX:6, RY:7); triggers u8 (LT:8, RT:9)
  - Gyro bytes 12–23: yaw i16le(12), roll i16le(14), pitch i16le(16) + accel 3×i16le(18–23)
  - Battery byte 24: bit7=charging, bits3–0=charge_percent (×10%)
- [ ] Create `devices/flydigi/vader4-pro.toml` (VID 0x04b4, PID 0x2412)
  - Input report id=0x04 (32B); stick/trigger offsets match vader5 family
  - Gyro Y split-bytes: low=byte18, high=byte20 (use `split_bytes` field)
  - `init_sequence` adapted from `devices/flydigi/vader5.toml` with updated product_id byte
- [ ] Create `devices/microsoft/xbox-xpad.toml`
  - DInput mode report id=0x11 (16B): sticks/triggers 6×u16le (offset 2–13); buttons bits (14–15)
  - XBox Series mode report id=0x01 (17B): extended ButtonState byte 16
- [ ] All four TOML files pass `padctl --validate`

### T7: Release pipeline improvements

- [ ] Add `cliff.toml` (conventional commits: feat/fix/doc/perf/refactor groups)
- [ ] Refactor `.github/workflows/release.yml`
  - Build job: upload binary as artifact
  - Checksum job: download artifact; run `sha256sum`; upload `SHA256SUMS.txt` alongside `.tar.gz`
  - Add `orhun/git-cliff-action@v3` step (`--latest --strip header`); write `CHANGELOG.md`
  - `gh release create` uses `--notes-file CHANGELOG.md`
  - Add `update-aur` job (depends: build + checksum)
    - Update `PKGBUILD` pkgver + sha256sums
    - Use `archlinux-downgrade/aur-publish-action@v1`; requires `AUR_SSH_KEY` secret
- [ ] Update `contrib/aur/padctl-bin/PKGBUILD`: add `padctl-capture` and `padctl-debug` to package

### T8: COPR packaging

- [ ] Create `contrib/copr/padctl.spec`
  - `BuildRequires: zig >= 0.15`  <!-- primary strategy: build from source -->
  - Fallback (when zig unavailable in COPR buildroot): precompiled binary copy per D5; add comment `# fallback: copy precompiled binary` above the relevant `%build` block
  - `%build`: `zig build -Doptimize=ReleaseSafe --prefix %{buildroot}%{_prefix}` (or binary copy for SRPM path)
  - `%files`: binary + padctl-capture + padctl-debug + service + udev rules + `/usr/share/padctl/`
- [ ] Create `contrib/copr/README.md` (COPR setup steps for maintainers; Bazzite install command)
- [ ] `rpmlint contrib/copr/padctl.spec` passes with no errors

---

## Wave 2 — Config UX, scroll, gyro, CI

### T9: `padctl config` subcommands (depends T4)

- [ ] Create `src/cli/config/list.zig`
  - Scan XDG three-layer devices/ + mappings/; detect daemon via `/run/padctl.pid`; annotate `[running]`
- [ ] Create `src/cli/config/init.zig`
  - Invoke scan logic; interactive: select device → output preset → mapping template
  - Write `~/.config/padctl/mappings/<device-name>.toml`; run `padctl --validate`
- [ ] Create `src/cli/config/edit.zig`
  - Locate TOML via XDG priority (user-layer writable); open `$VISUAL > $EDITOR > vi`; validate on exit
- [ ] Create `src/cli/config/test.zig`
  - Load mapping (no uinput); read hidraw input; print mapped events live until Ctrl-C
- [ ] Register `config` subcommand group in `src/main.zig`

### T10: Horizontal scroll (`REL_HWHEEL`)

- [ ] In `src/stick_processor.zig` `processScrollMode`: add `scroll_accum_h` accumulation from `axis_x`
- [ ] Emit `AuxEvent{ .scroll_h = delta }` when threshold crossed
- [ ] Ensure `AuxDevice` registers `REL_HWHEEL` in `EV_REL` capabilities at creation time

### T11: Gyro curve normalization

- [ ] Rewrite `apply_curve()` in `src/gyro_processor.zig`:
  ```
  normalized = clamp((abs(raw) - deadzone) / (GYRO_MAX - deadzone), 0.0, 1.0)
  curved     = pow(normalized, curve)
  result     = copysign(curved * (GYRO_MAX - deadzone) + deadzone, raw)
  ```
- [ ] Guard division-by-zero: when `GYRO_MAX == deadzone`, return 0
- [ ] Add unit tests: `curve=2.0, deadzone=1000, GYRO_MAX=32767` matches vader5 reference ±1 LSB; `curve=1.0` output unchanged from prior linear path

### T12: CI cross-compile + Zig version unification

- [ ] Restructure `.github/workflows/ci.yml` into three parallel jobs: `lint`, `test`, `cross-compile`
  - `cross-compile` matrix: `[x86_64-linux-musl, aarch64-linux-musl]`
  - `zig build -Dtarget=${{ matrix.target }} -Dlibusb=false -Doptimize=ReleaseSafe`
- [ ] Pin Zig to `0.15.2` via `mlugg/setup-zig@v2` in both `ci.yml` and `release.yml`
- [ ] Fix `flake.nix`: remove hardcoded `x86_64-linux-musl` target; use system-native

---

## Wave 3 — End-to-end validation

### T13: End-to-end validation (depends all)

**CI (automated, no hardware):**
- [ ] `zig build test` — full regression including Wave 0–2 unit tests
- [ ] `padctl install --destdir /tmp/test-root --prefix /usr` — verify directory structure
- [ ] `padctl scan --config-dir /tmp/test-root/usr/share/padctl` — VID/PID match logic via unit test
- [ ] `padctl --validate devices/lenovo/legion-go-s.toml` — new TOML passes validation

**Manual (hardware required, CI skipped):**
- [ ] `padctl scan` with Vader 5 Pro connected — confirms matching TOML path in output
- [ ] Rumble test with supporting app — Force Feedback functional
- [ ] `padctl config list` — shows device and mapping list
- [ ] `padctl reload` with daemon running — SIGHUP triggered, "Reloaded." printed

---

## Post-merge wrap-up

- [ ] Archive this OpenSpec
- [ ] Update `planning/roadmap.md` Phase 6 status
