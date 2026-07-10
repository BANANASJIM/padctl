# DualSense Edge USB fixture provenance

These fixtures cover only the wired USB personality of a Sony DualSense Edge
controller (`054c:0df2`). They contain no Bluetooth descriptor, Bluetooth CRC,
private configuration report, or hardware capture.

## Imported hhd bytes

- Project: [hhd](https://github.com/hhd-dev/hhd)
- Immutable commit: [`58f430b766be8b463a991ca70bcfd8540f937ac0`](https://github.com/hhd-dev/hhd/tree/58f430b766be8b463a991ca70bcfd8540f937ac0)
- Source path: [`src/hhd/controller/virtual/dualsense/const.py`](https://github.com/hhd-dev/hhd/blob/58f430b766be8b463a991ca70bcfd8540f937ac0/src/hhd/controller/virtual/dualsense/const.py)
- License declaration: [`pyproject.toml`](https://github.com/hhd-dev/hhd/blob/58f430b766be8b463a991ca70bcfd8540f937ac0/pyproject.toml), `LGPL-2.1-or-later`
- License text: [`LICENSE`](https://github.com/hhd-dev/hhd/blob/58f430b766be8b463a991ca70bcfd8540f937ac0/LICENSE)

The transformation is a byte-for-byte serialization of these Python `bytes`
constants. No value is added, removed, padded, signed, or captured from
hardware:

| Local fixture | Source expression | Length | SHA-256 |
|---|---|---:|---|
| `descriptor.bin` | `DS5_EDGE_DESCRIPTOR_USB` | 389 | `962368681aeeecaf4c384c37458fa98a7e58de2905aafad8ee0b81986ee50891` |
| `feature_05.bin` | `DS5_EDGE_STOCK_REPORTS[0x05]` | 41 | `4528e5d961dd54633c9b61c780802037eb88817e0d10042531c92726f96b540c` |
| `feature_09.bin` | `DS5_EDGE_STOCK_REPORTS[0x09]` | 20 | `5ce718554d3fb7937651d134162ab4d25539dc53dacfeb0a78e503325bfe44fb` |
| `feature_20.bin` | `DS5_EDGE_STOCK_REPORTS[0x20]` | 64 | `214ac66af99f5b87928c273493602c6e57ba2ab7f62c09c19228ee4060ecaa0e` |

The feature fixtures include their report-id byte. They are the unmodified USB
forms, so no Bluetooth feature CRC is appended. `feature_09.bin` retains hhd's
stock test MAC; production identity substitution is separate codec behavior and
does not change this provenance fixture.

## Synthetic compatible-rumble vectors

The two output fixtures are padctl-authored synthetic vectors, not copied from
hhd, SDL, Linux, a GPL project, or a physical controller. Starting with an
all-zero byte array of the named length, apply the same five assignments:

```text
byte[0]  = 0x02  # USB output report id
byte[1]  = 0x02  # SDL flag disabling audio haptics
byte[3]  = 0x3c  # right / weak motor; deliberately asymmetric
byte[4]  = 0xa5  # left / strong motor; deliberately asymmetric
byte[39] = 0x04  # improved compatible-vibration flag
```

| Local fixture | Authored form | Length | SHA-256 |
|---|---|---:|---|
| `output_compat_48.bin` | SDL USB write form | 48 | `d25aab53105bf555a982900df2351efcd0ca9f9857f467ab5cd96a984bf8beb7` |
| `output_compat_63.bin` | Linux `hid-playstation` accepted short form | 63 | `ba4e3b6f590e90c70c610a9a30e67976c0f6779287447c87e9d06baf24ae399a` |

The fixed third-party sources below are behavior and layout oracles only. No
source code or byte sequence was copied from them:

- SDL commit [`f653c5e91c2a3594edd63677cabeae2d71317727`](https://github.com/libsdl-org/SDL/blob/f653c5e91c2a3594edd63677cabeae2d71317727/src/joystick/hidapi/SDL_hidapi_ps5.c), path `src/joystick/hidapi/SDL_hidapi_ps5.c`: USB write size and compatible-rumble flags/motor fields.
- Linux commit [`a635d6748234582ea287c5ffeae28b9b23f91c7e`](https://github.com/torvalds/linux/blob/a635d6748234582ea287c5ffeae28b9b23f91c7e/drivers/hid/hid-playstation.c), path `drivers/hid/hid-playstation.c`: USB output layout, accepted short size, flags, and motor ordering.

The 63-byte vector is generated at that length directly. It is not the 48-byte
vector padded to satisfy the descriptor's declared report count; both are
independently named accepted wire forms even though their first 48 bytes are
intentionally equal.

## Reproduction

Check out the immutable hhd commit, verify `git rev-parse HEAD` is exactly
`58f430b766be8b463a991ca70bcfd8540f937ac0`, set `PYTHONPATH` to that
checkout's `src` directory, and run the following from the padctl repository
root:

```python
from pathlib import Path
from hhd.controller.virtual.dualsense.const import (
    DS5_EDGE_DESCRIPTOR_USB,
    DS5_EDGE_STOCK_REPORTS,
)

out = Path("src/test/fixtures/dualsense_edge_usb")
(out / "descriptor.bin").write_bytes(DS5_EDGE_DESCRIPTOR_USB)
(out / "feature_05.bin").write_bytes(DS5_EDGE_STOCK_REPORTS[0x05])
(out / "feature_09.bin").write_bytes(DS5_EDGE_STOCK_REPORTS[0x09])
(out / "feature_20.bin").write_bytes(DS5_EDGE_STOCK_REPORTS[0x20])

for length, name in (
    (48, "output_compat_48.bin"),
    (63, "output_compat_63.bin"),
):
    data = bytearray(length)
    data[0] = 0x02
    data[1] = 0x02
    data[3] = 0x3C
    data[4] = 0xA5
    data[39] = 0x04
    (out / name).write_bytes(data)
```

Finally run:

```sh
wc -c src/test/fixtures/dualsense_edge_usb/*.bin
sha256sum src/test/fixtures/dualsense_edge_usb/*.bin
zig build test -Dtest-filter="DualSense Edge USB fixtures"
```

The registered Zig test independently pins all six lengths and hashes and also
asserts the complete synthetic output byte layout.
