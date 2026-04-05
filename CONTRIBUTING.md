# Contributing a Device Config

Adding a new device requires only **one file**: `devices/<vendor>/<device>.toml`.
No source code changes needed — no test files, no registration, no build system edits.

## Steps

1. **Capture**: Run `padctl-capture` against the target device to produce a TOML skeleton.

   ```
   sudo ./zig-out/bin/padctl-capture /dev/hidraw0 > devices/<vendor>/<model>.toml
   ```

2. **Complete**: Fill in field names, button names, transform chains, and the `[output]` section.
   See existing configs in `devices/` for reference.

3. **Validate**: Run locally before submitting:

   ```
   zig build && ./zig-out/bin/padctl --validate devices/<vendor>/<model>.toml
   ```

   Exit 0 = valid. Exit 1 = validation errors (fix them). Exit 2 = file not found or parse failure.

4. **Test**: Run `zig build test` to confirm all tests pass. The test framework uses
   `Dir.walk("devices/")` to auto-discover all `.toml` files — your new config is
   automatically included without any manual registration.

5. **Submit**: Open a pull request. CI runs the same auto-discovery tests automatically.
   Once the validator reports zero errors and a maintainer approves, the config is merged.

## CI Auto-Validation

`zig build test` automatically validates every device TOML in the repository:

- **TOML parse + semantic validation**: syntax correctness, field value legality
- **FieldTag coverage**: all field names map to known FieldTag values
- **ButtonId coverage**: all button_group keys are valid ButtonId enum values
- **VID/PID validity**: all device configs contain valid VID/PID

## Directory Layout

```
devices/
├── 8bitdo/        8BitDo (Ultimate Controller)
├── flydigi/       Flydigi (Vader 4 Pro, Vader 5 Pro)
├── hori/          HORI (Horipad Steam)
├── lenovo/        Lenovo (Legion Go, Legion Go S)
├── microsoft/     Microsoft (Xbox Elite Series 2)
├── nintendo/      Nintendo (Switch Pro Controller)
├── sony/          Sony (DualSense, DualShock 4, DualShock 4 v2)
└── valve/         Valve (Steam Deck)
```

Add a new vendor directory if the manufacturer is not listed.

## Packaging

Pre-built and source package recipes live in `contrib/`:

| Directory | Contents |
|-----------|----------|
| `contrib/aur/` | AUR `PKGBUILD` (`padctl-git`, source build) and `padctl-bin` (prebuilt binary) |
| `contrib/copr/` | RPM spec for Fedora/COPR (`padctl.spec`) |

**Release workflow:** push a `v*.*.*` tag to trigger release builds for all package targets.

## Code Contributions

### Workflow

1. Fork the repository and create a feature branch
2. Make your changes
3. Run all checks before submitting
4. Open a pull request

To enable repository git hooks locally:

```sh
git config core.hooksPath hooks
```

With hooks enabled, `pre-push` runs `zig build test-tsan` before push.

### Code Style

All Zig code must pass `zig fmt`:

```sh
zig build check-fmt
```

### Testing

```sh
# Run all tests (Layer 0+1, no privileges required)
zig build test

# Run all checks (test + tsan + safe + fmt)
zig build check-all
```

### Build Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-Dlibusb=false` | `true` | Disable libusb-1.0 linkage (hidraw-only path) |
| `-Dwasm=false` | `true` | Disable WASM plugin runtime |
| `-Dtest-coverage=true` | `false` | Run tests with kcov coverage |
