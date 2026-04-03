# padctl

**padctl** maps gamepad HID reports to Linux uinput events using a declarative TOML device config.

## Overview

- **TOML device config** — describe report layout, field offsets, button groups, and output capabilities without writing code.
- **User mapping config** (`~/.config/padctl/`) — personal button remaps, gyro mouse, layers, and macros; separate from device configs.
- **XDG auto-discovery** — daemon finds device and mapping configs across user, system, and builtin directories automatically.
- **Runtime mapping switch** — `padctl switch <name>` swaps the active mapping without restarting the daemon.
- **padctl-capture** — record HID traffic and generate a TOML skeleton automatically.
- **padctl --validate** — static config checker for CI and community contributions.
- **padctl --doc-gen** — generate device reference pages from TOML.

## Source

[https://github.com/BANANASJIM/padctl](https://github.com/BANANASJIM/padctl)
