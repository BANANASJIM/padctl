# Issue #65 rumble trace fixtures

These are normalized, de-identified vectors derived from public diagnostics
attached to issue #65. Wall time is replaced with `trace-derived`, monotonic
time is rebased to T0 nanoseconds, and only the `FF_EVENT`/`HID_WRITE` fields
needed by the tests are retained. Host paths, process IDs, topology, and
unrelated log content are omitted.

## `daniel_60hz_stop.log`

- Issue comment: <https://github.com/BANANASJIM/padctl/issues/65#issuecomment-5013818944>
- Attachment: <https://github.com/user-attachments/files/30159607/rumble.log>
- Original SHA-256: `e80a47a849ef563dcaafb9da5764fc777dd84d4c2155dbde7763b8f0e8863139`
- Derived fixture SHA-256: `10a1927af5cd6a3267fe5ff8ef97ac2e37ded0b648a099e13a26dcc38ac8aa56`
- Reporter version: padctl 0.1.23 (`padctl-bin`); the attachment does not
  identify an exact commit
- Extraction: original lines 435-486, retaining only `FF_EVENT` and
  `HID_WRITE`, then applying the de-identification transform above
- Evidence shape: one-to-one 60 Hz decay followed by an explicit STOP and zero
  HID frame

## `daniel_strong_only_stop.log`

- Source, attachment, and original SHA-256: same as `daniel_60hz_stop.log`
- Derived fixture SHA-256: `8680694396b548f80db1dd47bdc9cbecf1df4444838c59579920546b9a10055b`
- Extraction: original lines 359-386, retaining only `FF_EVENT` and
  `HID_WRITE`, then applying the de-identification transform above
- Evidence shape: strong-only decay, which independently pins the encoder's
  strong/weak byte placement before the final STOP

## `dreadtusk_throttled_stop.log`

- Issue comment: <https://github.com/BANANASJIM/padctl/issues/65#issuecomment-4903267303>
- Attachment: <https://github.com/user-attachments/files/29742918/rumble.pt1.txt>
- Original SHA-256: `322e6ac5b5604ee511a669f7a7bee36d947c795a83f3df5a05a97477ac0b9766`
- Derived fixture SHA-256: `f753ca29922966450d38678142e49cbbda3b010524f56b141a402b9be41a4e6b`
- Reporter version: `padctl-git`; the attachment does not identify an exact
  commit
- Extraction: original lines 43214-43335, retaining only `FF_EVENT` and
  `HID_WRITE`, then applying the de-identification transform above
- Evidence shape: roughly 1-2 ms logical FF updates, latest-wins logged
  `HID_WRITE` intents at the 10 ms throttle boundary, then a recorded STOP/zero
  frame 9.18ms after the preceding non-zero logged `HID_WRITE` intent

The parser accepts the same `HID_WRITE` field format used by the MIT-licensed
[`rumble-replay`](https://github.com/shakespear-dev/vader5pro-linux-tools/tree/main/tools/rumble-replay)
tool, but no source code from that project is copied here.

These fixtures characterize the attached field traces and guard the shipped
encoder contract. They are not a #65 hardware reproduction and do not prove USB
transfer completion or physical motor state; those require a real-device run
with transport capture and an external physical oracle.
