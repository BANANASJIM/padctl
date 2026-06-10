# Third-Party Software

padctl binaries statically link the following third-party C libraries.

## libusb 1.0.26

- License: LGPL-2.1-or-later
- Source: https://github.com/libusb/libusb
- Packaging: https://github.com/allyourcodebase/libusb (tag `v1.0.26-zig`,
  commit `363c73885e5b04384bd4702605c613e67da45797`)
- Pulled in via `build.zig.zon` and compiled statically into every release
  build (musl, no system libusb at build or run time).

## wasm3

- License: MIT
- Source: https://github.com/wasm3/wasm3 (commit
  `79d412ea5fcf92f0efe658d52827a0e0a96ff442`)
- Vendored under `third_party/wasm3/`.
