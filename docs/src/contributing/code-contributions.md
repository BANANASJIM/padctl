# Code Contributions

## Workflow

1. Fork the repository and create a feature branch
2. Make your changes
3. Run all checks before submitting
4. Open a pull request

## Code Style

All Zig code must pass `zig fmt`:

```sh
zig build check-fmt
```

## Testing

```sh
# Run all tests (Layer 0+1, no privileges required)
zig build test

# Run all checks (test + tsan + safe + fmt)
zig build check-all
```

## Build Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-Dlibusb=false` | `true` | Disable libusb-1.0 linkage (hidraw-only path) |
| `-Dwasm=false` | `true` | Disable WASM plugin runtime |
| `-Dtest-coverage=true` | `false` | Run tests with kcov coverage |

## CI Auto-Validation

`zig build test` automatically validates every device TOML in the repository:

- **TOML parse + semantic validation**: syntax correctness, field value legality
- **FieldTag coverage**: all field names map to known FieldTag values
- **ButtonId coverage**: all button_group keys are valid ButtonId enum values
- **VID/PID validity**: all device configs contain valid VID/PID

## Test Fixtures Are Single-Source

Files in `devices/` and `examples/mappings/` are the canonical source of
truth for both the user-facing manual and the e2e test suite. End-to-end
tests under `src/test/*_e2e_test.zig` MUST consume these fixtures via
`device_mod.parseFile(...)` (or `@embedFile` for non-TOML payloads) rather
than declaring an inline TOML literal.

Inline literals drift away from the canonical files over time: a field
gets renamed, a transform is added, or a fixture grows a new
`[output.imu]` block, and the inline copy keeps testing the old shape.
PR #193 began retiring inline `vader5_toml` literals after exactly this
drift was observed (the inline copy had `gyro_y` / `gyro_z` swapped
relative to `devices/flydigi/vader5.toml`). The last remaining inline copy
in `interpreter_e2e_test.zig` was removed in PR #209; no inline device
literals remain in the test suite.

When you add a new e2e test, prefer one of these patterns:

```zig
// device-config-driven test
const parsed = try device_mod.parseFile(allocator, "devices/flydigi/vader5.toml");

// mapping-config-driven test
const parsed = try mapping_mod.parseFile(allocator, "examples/mappings/comprehensive.toml");
```

If the test genuinely needs a config shape that no shipped fixture
provides, add a new fixture under `src/test/fixtures/` and consume it via
`@embedFile` — do not paste the TOML into the test source.
