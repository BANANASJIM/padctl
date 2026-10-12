# Device Reference

Device reference pages are generated from production TOML configs via
`padctl --doc-gen`. This section lists supported device families; compatibility
variants may share one generated page, and fixtures under `devices/example/` are
for parser/CI coverage rather than user support claims.

The original Razer Wolverine V3 Pro PC Tournament mode (`1532:0a4c`) config is
a source-backed bringup candidate. It has not been tested on hardware here and
requires an explicit launch:

```sh
padctl --config devices/razer/wolverine-v3-pro-pc.toml
```

Use PC Tournament mode before launching. This candidate covers standard controls;
it does not advertise independent extra buttons, rumble, Xbox/GIP mode (`0a3f`)
or the different Wolverine V3 Pro 8K PC. Pure vendor USB devices are not yet
automatically discovered by the service. Confirm cold attach, descriptor
selection, full axis travel, button positions and duplicate-input suppression on
the actual controller before treating this candidate as validated support.

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
