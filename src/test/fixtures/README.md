# `src/test/fixtures/`

Test-time fixtures that exercise the production code. Each fixture either:

- pins a byte-exact binary payload the production code must emit or parse, OR
- provides a parameterised generator (`.zig`) that drives repeatable test scenarios.

## Fixtures

### `golden/steam_deck_hid_descriptor.bin`

HID 1.11 report descriptor bytes that `UhidDescriptorBuilder.buildFromOutput`
must produce when fed `devices/valve/steam-deck.toml`.

**Caveat — self-reference risk**: the .bin was originally emitted by the
builder itself and checked in. A byte-exact golden-file test against it is
therefore a tautology: the builder compared to its own output. This is
disclosed in the audit's H5 finding.

**Guardrails that defeat the tautology**:

1. `steam_deck_hid_descriptor.annotated.txt` — human-auditable byte-by-byte
   decomposition into HID 1.11 items. A reviewer can manually cross-check
   every byte against the spec without trusting the builder.

2. Structural invariant test in `src/io/uhid_descriptor.zig`:
   `golden invariants: Steam Deck HID descriptor parses as balanced HID 1.11
   item stream` — parses the .bin as short items and asserts:
   - Prologue is `Usage Page (Generic Desktop) + Usage (Game Pad) + Collection (Application)`
   - Collection opens match Collection closes (balanced `A1 ... C0`)
   - Exactly two Report IDs appear (input = 1, rumble output = 2)
   - Sum of `Report Size × Report Count` across Input items is a multiple of 8
     (byte-aligned aggregate — kernel rejects unaligned)

   These invariants would catch any builder corruption that drifted from
   the HID spec (unbalanced collections, missing report ID, unaligned
   aggregates) even if the golden .bin itself were wrong.

### `steam_deck_reports.zig`

Synthetic Steam Deck 0x09 input-report generator. Drives end-to-end tests
against `devices/valve/steam-deck.toml` with a lizard-mode state machine
that mirrors the firmware-suppressed pre-unlock behaviour.

The vendor/product IDs used here (`DECK_VID` / `DECK_PID`) are **synthetic**,
not Valve's real `0x28de/0x1205`. This prevents the test harness from
accidentally picking up a real Steam Deck plugged into the developer's
machine — see the audit's H6 finding.

## How to regenerate `steam_deck_hid_descriptor.bin`

Do **not** regenerate by running the builder — that re-introduces the
tautology. If the descriptor needs to change legitimately (TOML schema
update, new field, bug fix), the correct procedure is:

1. Update the builder and/or TOML.
2. Update `steam_deck_hid_descriptor.annotated.txt` **by hand** with the
   new expected items, reading the HID 1.11 spec.
3. Write out the new .bin by copying the annotated bytes — the .txt is
   the source of truth, the .bin is derived.
4. Run `zig build test`; the structural invariant test must still pass,
   and `descriptor: matches golden fixture for Steam Deck output` will
   catch a builder/.bin mismatch.

An alternative reference source would be a `hidrd-decode` round-trip of
a real Steam Deck descriptor captured from `sysfs` — this is a valuable
cross-check to add in a later audit pass but out of scope for H5.
