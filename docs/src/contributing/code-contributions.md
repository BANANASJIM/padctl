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
