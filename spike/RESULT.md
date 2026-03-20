# T0 TOML Spike Result

Library: sam701/zig-toml (main branch, v0.3.0)

## Verdict: PASS — zig-toml is viable for padctl DSL

All four spike criteria passed against `test-vader5.toml`.

---

## Check Results

### CHECK 1: `[[report]]` array of tables + nested sub-tables — PASS

`[[report]]` maps to `[]const Report` in Zig. Per-report nested tables (`[report.fields]`,
`[report.match]`, `[report.button_group]`, `[report.checksum]`) map to struct fields. Two
reports parsed correctly with all sub-tables intact.

### CHECK 2: Hex integer literals (`0x37d7`, `[0x5a, 0xa5, 0xef]`) — PASS

`integer.zig` delegates to `std.fmt.parseInt(..., 0)` which accepts `0x` / `0o` / `0b`
prefixes. All hex VID/PID values and hex byte arrays in the TOML parsed correctly to `i64`.

### CHECK 3: `[commands.rumble]` / `[commands.led]` dynamic key names — PASS

`toml.HashMap(Command)` via the `tomlIntoStruct` hook captures arbitrary key names into a
`std.StringHashMap`. Both `rumble` and `led` entries resolved correctly.

### CHECK 4: Optional nested table (`[report.checksum]` present in report 0, absent in report 1) — PASS

`?Checksum = null` field: struct_mapping sets `null` when the sub-table is absent. No
special handling needed.

---

## Notes for T2

- Direct struct mapping works for the full DSL; no manual Value-tree traversal needed.
- `toml.HashMap(T)` is the correct type for any `[parent.dynamic_key]` section.
- Fields with optional sub-tables use `?SubStruct = null`; struct_mapping handles missing
  sub-tables automatically.
- Hex arrays (`[0x5a, 0xa5]`) must be typed `[]const i64` (TOML has no u8 type).
  Conversion to `[]u8` must be done in application code after parsing.
- `button_group.map` uses `HashMap(i64)` because TOML inline-table values are integers.
- `output.buttons` (string values) uses `HashMap([]const u8)`.
- `build.zig.zon` requires `.fingerprint` field on this zig master version.
