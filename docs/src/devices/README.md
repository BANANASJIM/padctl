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

The GameSir G7 Pro Amazon wired (`3537:10ba`) telemetry configuration is
experimental and has not been tested on hardware here. It requires libusb and
an explicit `--config` invocation: this identity lacks the hidraw anchor needed
by automatic discovery. Other variants, receiver modes, rumble and IMU output
are outside this configuration. Confirm stick direction/centering and button
mapping on the exact hardware before relying on it. The reference reader also
queries profile and firmware every two seconds; this candidate sends only the
F2 heartbeat. Its necessity and sufficiency for telemetry remain unverified.
