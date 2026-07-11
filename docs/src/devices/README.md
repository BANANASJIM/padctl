# Device Reference

Device reference pages are generated from production TOML configs via
`padctl --doc-gen`. This section lists supported device families; compatibility
variants may share one generated page, and fixtures under `devices/example/` are
for parser/CI coverage rather than user support claims.

Build padctl, then regenerate one page with:

```sh
./zig-out/bin/padctl --doc-gen --config devices/flydigi/vader5.toml --output docs/src/devices
```

To regenerate every production page, use the same one-file-at-a-time loop as
the documentation workflow:

```sh
find devices -type f -name '*.toml' -print | sort | while IFS= read -r f; do
    ./zig-out/bin/padctl --doc-gen --config "$f" --output docs/src/devices
done
```
