# Third-Party Software

This file records third-party runtime dependencies and vendored test material.
padctl binaries statically link the C libraries below; the hhd material is
explicitly test-only.

## libusb 1.0.30

- License: LGPL-2.1-or-later
- Source: https://github.com/libusb/libusb
- Source archive: https://github.com/libusb/libusb/archive/refs/tags/v1.0.30.tar.gz
- Linux build configuration: `tools/build_libusb.zig` and
  `third_party/libusb/config.h` (netlink hotplug, no libudev).
- Pulled in via `build.zig.zon` and compiled statically into every release
  build (musl, no system libusb at build or run time).
- Includes the upstream CVE-2026-23679 descriptor parser fix. The malformed
  endpoint regression in `tests/libusb_descriptor_security.c` uses the input
  from libusb's `tests/fuzz/corpus/descriptor_parsers/regression_bug_a_endpoint_null.bin`.

## wasm3 0.9.0

- License: MIT
- Source: https://github.com/wasm3/wasm3 (commit
  `0cd38327f0c721e75172f4f1eeb55854dc0517af`)
- Vendored under `third_party/wasm3/`.
- Includes upstream module validation (PR #572); padctl compiles and validates
  every plugin function during loading, before exposing plugin callbacks.
- OSV-2021-689 remains open upstream with no published fixed revision; load
  only plugins from trusted sources.

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
