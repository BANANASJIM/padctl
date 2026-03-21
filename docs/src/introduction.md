# padctl

**padctl** maps gamepad HID reports to Linux uinput events using a declarative TOML device config.

## Overview

- **TOML device config** — describe report layout, field offsets, button groups, and output capabilities without writing code.
- **padctl-capture** — record HID traffic and generate a TOML skeleton automatically.
- **padctl --validate** — static config checker for CI and community contributions.
- **padctl --doc-gen** — generate device reference pages from TOML.

## Source

[https://github.com/jim-z/padctl](https://github.com/jim-z/padctl)
