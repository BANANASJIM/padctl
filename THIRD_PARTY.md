# Third-Party Software

This file records third-party runtime dependencies and vendored test material.
padctl binaries statically link the C libraries below; the hhd material is
explicitly test-only.

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

## hhd DualSense Edge USB test fixtures

- License: LGPL-2.1-or-later
- Source: https://github.com/hhd-dev/hhd (commit
  `58f430b766be8b463a991ca70bcfd8540f937ac0`)
- Source path: `src/hhd/controller/virtual/dualsense/const.py`
- Vendored scope: the USB descriptor and feature-report byte fixtures under
  `src/test/fixtures/dualsense_edge_usb/`; these are test data and are not
  linked into padctl release binaries.
- Detailed attribution, transformations, immutable links, and hashes:
  `src/test/fixtures/dualsense_edge_usb/PROVENANCE.md`.

The compatible-rumble fixtures in that directory are padctl-authored synthetic
vectors. SDL and Linux are fixed behavior oracles for those vectors; no SDL or
Linux source code or fixture bytes are vendored.
