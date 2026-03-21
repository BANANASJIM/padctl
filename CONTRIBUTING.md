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
├── sony/          Sony (DualSense, DualShock)
├── nintendo/      Nintendo (Switch Pro, Joy-Con)
├── 8bitdo/        8BitDo
├── microsoft/     Microsoft Xbox
└── flydigi/       Flydigi
```

Add a new vendor directory if the manufacturer is not listed.
