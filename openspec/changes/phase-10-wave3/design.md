# Design: Phase 10 Wave 3 — Generative Tests (T12-T16)

## Files

| File | Role |
|------|------|
| `src/test/auto_device_test.zig` | T12: runtime Dir.walk + 11 standard checks; T13: FieldTag coverage; T16: per-device fuzz |
| `src/core/interpreter.zig` | T13: export `parseFieldTag` as `pub` |
| `src/core/state.zig` | T14: add `generateRandomDelta` helper + round-trip test |
| `src/test/transform_boundary_test.zig` | T15: comptime boundary exhaustion for all transforms |
| `build.zig` | Ensure new test files are included in test step |

---

## T12: auto_device_test.zig — Dir.walk + 11 Standard Checks

### Problem

`validate_e2e_test.zig` hardcodes 5 device paths in an array. 7 of 12 device configs
have zero test coverage. Adding a new device TOML requires manually updating the array.

### Solution

Create `src/test/auto_device_test.zig` with a single `collectTomlPaths` helper that
calls `std.fs.cwd().openDir("devices", .{ .iterate = true })` + `dir.walk(allocator)`
to discover all `.toml` files at runtime. The test step CWD is already the project root.

One top-level test iterates all discovered paths and runs 11 checks per device:

```zig
fn collectTomlPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths = std.ArrayList([]const u8).init(allocator);
    var dir = try std.fs.cwd().openDir("devices", .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".toml")) continue;
        try paths.append(try std.fmt.allocPrint(allocator, "devices/{s}", .{entry.path}));
    }
    return paths;
}
```

#### 11 Standard Checks

| # | Check | Logic |
|---|-------|-------|
| 1 | Parse | `device.parseFile(allocator, path)` succeeds (includes `validate()`) |
| 2 | Name non-empty | `cfg.device.name.len > 0` |
| 3 | Report count | `cfg.report.len >= 1` |
| 4 | Field -> FieldTag | Every field name in `report.fields` maps to `parseFieldTag(name) != .unknown` (or in ignore list). Delegated to T13 check. |
| 5 | Button -> ButtonId | Every key in `button_group.map` passes `std.meta.stringToEnum(ButtonId, name) != null` |
| 6 | Match filter accept | For reports with `match` and no `checksum`: construct frame with match bytes at correct offset, verify `processReport` returns non-null |
| 7 | Match filter reject | Construct frame with match bytes modified (+1 on first byte), verify `processReport` returns null |
| 8 | Frame size | Construct frame shorter than `report.size`, verify `processReport` returns null |
| 9 | Checksum correct | For reports with `checksum`: construct frame, compute correct checksum per algo/range/seed, write to expect offset. Verify no `ChecksumMismatch` |
| 10 | Checksum incorrect | Same frame with checksum byte flipped. Verify `processReport` returns `ChecksumMismatch` |
| 11 | No-transform round-trip | For each field without `transform` and without `bits`: write known value at field offset, run `processReport`, verify delta contains that value at the corresponding FieldTag |

Checks 9-10 require computing checksums (sum8/xor/crc32) from config parameters.
The interpreter already has `verifyChecksumCompiled` internally; the test computes the
expected checksum independently using `std.hash.Crc32` / manual sum8/xor to provide
cross-validation.

Checks 6-7 and 9-11 construct synthetic frames. The frame buffer is zero-initialized
with `report.size` length, then match bytes are written at `match.offset`.

The test asserts `paths.items.len >= 12` as a guard against empty discovery (wrong CWD).

---

## T13: parseFieldTag pub Export + FieldTag Coverage

### Problem

`parseFieldTag` is `fn` (file-private) in `interpreter.zig`. The auto-test cannot call
it to verify that every TOML field name maps to a known `FieldTag`.

### Solution

#### T13a: Change visibility

In `src/core/interpreter.zig`, change:

```zig
fn parseFieldTag(name: []const u8) FieldTag {
```

to:

```zig
pub fn parseFieldTag(name: []const u8) FieldTag {
```

Also export `FieldTag`:

```zig
pub const FieldTag = enum {
```

No behavioral change. The function body and all call sites remain identical.

#### T13b: FieldTag coverage test

In `auto_device_test.zig`, add a test that iterates every discovered TOML, then for
each report with fields, verifies every field name maps to a known FieldTag:

```zig
test "auto: all field names map to known FieldTag" {
    // ...collectTomlPaths...
    const ignored = [_][]const u8{
        "sensor_timestamp",
        "touch0_contact", "touch1_contact",
    };
    for (paths.items) |path| {
        const parsed = try device.parseFile(allocator, path);
        defer parsed.deinit();
        for (parsed.value.report) |report| {
            const fields = report.fields orelse continue;
            var it = fields.map.iterator();
            while (it.next()) |entry| {
                const name = entry.key_ptr.*;
                if (isIgnored(name, &ignored)) continue;
                const tag = interpreter.parseFieldTag(name);
                // Fail with device path + field name for debugging
                if (tag == .unknown) return error.UnknownFieldTag;
            }
        }
    }
}
```

The ignore list contains field names that intentionally map to `.unknown` because they
carry metadata (sensor_timestamp) or are handled by button_group (touch*_contact).
The ignore list is maintained in the test file — adding a new `.unknown` field to a
device TOML requires either adding it to `parseFieldTag` or to this ignore list.

---

## T14: State Round-Trip Property Test

### Problem

`GamepadState.diff` and `applyDelta` have only 4 hand-written test cases. The core
invariant `applyDelta(a, diff(b, a)) == b` is not systematically verified.

### Solution

Add a test in `src/core/state.zig` (co-located with the tested code):

#### T14a: generateRandomDelta helper

```zig
fn generateRandomDelta(rng: std.Random) GamepadStateDelta {
    var d = GamepadStateDelta{};
    if (rng.boolean()) d.ax = @bitCast(rng.int(u16));
    if (rng.boolean()) d.ay = @bitCast(rng.int(u16));
    if (rng.boolean()) d.rx = @bitCast(rng.int(u16));
    if (rng.boolean()) d.ry = @bitCast(rng.int(u16));
    if (rng.boolean()) d.lt = rng.int(u8);
    if (rng.boolean()) d.rt = rng.int(u8);
    if (rng.boolean()) d.dpad_x = @bitCast(rng.int(u8));
    if (rng.boolean()) d.dpad_y = @bitCast(rng.int(u8));
    if (rng.boolean()) d.buttons = rng.int(u32);
    if (rng.boolean()) d.gyro_x = @bitCast(rng.int(u16));
    if (rng.boolean()) d.gyro_y = @bitCast(rng.int(u16));
    if (rng.boolean()) d.gyro_z = @bitCast(rng.int(u16));
    if (rng.boolean()) d.accel_x = @bitCast(rng.int(u16));
    if (rng.boolean()) d.accel_y = @bitCast(rng.int(u16));
    if (rng.boolean()) d.accel_z = @bitCast(rng.int(u16));
    if (rng.boolean()) d.touch0_x = @bitCast(rng.int(u16));
    if (rng.boolean()) d.touch0_y = @bitCast(rng.int(u16));
    if (rng.boolean()) d.touch1_x = @bitCast(rng.int(u16));
    if (rng.boolean()) d.touch1_y = @bitCast(rng.int(u16));
    if (rng.boolean()) d.touch0_active = rng.boolean();
    if (rng.boolean()) d.touch1_active = rng.boolean();
    if (rng.boolean()) d.battery_level = rng.int(u8);
    return d;
}
```

#### T14b: Round-trip test

```zig
test "property: applyDelta(a, diff(b, a)) == b" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (0..1000) |_| {
        var a = GamepadState{};
        a.applyDelta(generateRandomDelta(rng));
        var b = GamepadState{};
        b.applyDelta(generateRandomDelta(rng));
        const d = b.diff(a);
        var result = a;
        result.applyDelta(d);
        inline for (std.meta.fields(GamepadState)) |f| {
            try std.testing.expectEqual(@field(b, f.name), @field(result, f.name));
        }
    }
}
```

Uses `std.Random.DefaultPrng` with fixed seed for deterministic CI runs. 1000 iterations
provides strong confidence; each iteration tests 22 fields simultaneously.

Also add a self-diff invariant test:

```zig
test "property: diff(s, s) produces all-null delta" {
    var prng = std.Random.DefaultPrng.init(99);
    const rng = prng.random();
    for (0..1000) |_| {
        var s = GamepadState{};
        s.applyDelta(generateRandomDelta(rng));
        const d = s.diff(s);
        inline for (std.meta.fields(GamepadStateDelta)) |f| {
            try std.testing.expectEqual(@as(f.type, null), @field(d, f.name));
        }
    }
}
```

---

## T15: Transform Boundary Exhaustion

### Problem

Transform tests use 1-2 values each. Boundary behavior (0, extremes, midpoints) is
untested. `negate(minInt(i16))` overflow, `abs(minInt(i16))` saturation, `scale(0, 0)`
degenerate case, and `deadzone` at threshold edges have no coverage.

### Solution

Create `src/test/transform_boundary_test.zig` with comptime arrays of boundary values
and inline loops. Each transform is tested against a minimal TOML config containing
a single field with that transform applied.

#### Boundary value set

```zig
const boundary_i16 = [_]i16{ 0, 1, -1, std.math.maxInt(i16), std.math.minInt(i16), 16384 };
```

Six values covering: zero, unit positive, unit negative, maximum, minimum, midpoint.

#### Per-transform test structure

Each test:
1. Constructs a minimal TOML with one field using the target transform
2. Parses config, creates Interpreter
3. Iterates boundary values via `inline for`
4. Writes each value into a synthetic frame at the field offset
5. Calls `processReport`, extracts delta
6. Asserts delta matches the mathematically expected output

#### Expected transform formulas

| Transform | Input `v` | Expected Output |
|-----------|-----------|-----------------|
| negate | `v` | `-v` (i64 arithmetic, then truncated to i16 by applyFieldTag) |
| abs | `v` | `if (v == minInt(i64)) maxInt(i64) else @abs(v)` |
| scale(a, b) | `v` (type max = 32767 for i16le) | `v * (b - a) / type_max + a` |
| clamp(lo, hi) | `v` | `std.math.clamp(v, lo, hi)` |
| deadzone(t) | `v` | `if (@abs(v) < t) 0 else v` |

#### Transform chain combinations

Also test common chains with boundary values:

| Chain | TOML | Property |
|-------|------|----------|
| `negate, abs` | `transform = "negate, abs"` | `output == abs(v)` for all v |
| `abs, clamp(0, 16384)` | `transform = "abs, clamp(0, 16384)"` | `0 <= output <= 16384` |
| `deadzone(1000), scale(-32768, 32767)` | `transform = "deadzone(1000), scale(-32768, 32767)"` | within-deadzone inputs produce scaled 0 |

---

## T16: Fuzz Expansion to All Device Configs

### Problem

The existing fuzz test in `interpreter.zig` only covers `vader5_toml` (an inline TOML
snippet). 11 other device configs have zero fuzz coverage. Each device has different
field layouts, checksums, and match patterns — they exercise different interpreter paths.

### Solution

In `auto_device_test.zig`, add a fuzz test that iterates all discovered device TOMLs:

```zig
test "fuzz: processReport on all device configs" {
    const allocator = std.testing.allocator;
    var paths = try collectTomlPaths(allocator);
    defer { for (paths.items) |p| allocator.free(p); paths.deinit(); }
    try std.testing.expect(paths.items.len >= 12);

    for (paths.items) |path| {
        const parsed = device.parseFile(allocator, path) catch continue;
        defer parsed.deinit();
        const interp = interpreter.Interpreter.init(&parsed.value);

        // Fuzz entry: random bytes as report input
        try std.testing.fuzz(.{ .interp = interp }, struct {
            const Context = @This();
            interp: interpreter.Interpreter,
            fn run(ctx: Context, input: []const u8) !void {
                for (0..4) |if_id| {
                    _ = ctx.interp.processReport(@intCast(if_id), input) catch {};
                }
            }
        }.run, .{});
    }
}
```

**Note on `std.testing.fuzz` behavior**:
- In normal `zig build test` mode, each fuzz entry runs once with empty/seed input.
  This serves as a smoke test confirming no panic on empty input for every config.
- In `zig build test --fuzz` mode, the fuzzer runs continuously with coverage-guided
  mutation. Each device config gets independent fuzz coverage.
- Crash inputs are saved in `.zig-cache/f/` and replayed as regression tests on
  subsequent `zig build test` runs.

The fuzz context captures `Interpreter` by value (it is a stack-sized struct with
compiled report data, no heap allocations). This avoids lifetime issues with the
`parsed` result.

**Important**: The actual `std.testing.fuzz` API signature may require adapting
the context passing pattern to match Zig's current API. The implementer should
consult `std.testing.fuzz` docs and adapt the closure/context mechanism accordingly.
The invariant being tested is: `processReport(any_interface, any_bytes)` must not
panic for any device config.

---

## Key Design Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Runtime Dir.walk, not comptime @embedFile | Zig comptime cannot enumerate directories. Runtime scan matches the production `parseFile` path. Zero maintenance on new device addition. |
| D2 | Single auto_device_test.zig file for T12/T13/T16 | All share `collectTomlPaths`. Avoids duplicating the directory-scan logic. |
| D3 | Round-trip test in state.zig, not a separate file | Co-located with `diff`/`applyDelta` definitions. Follows existing test organization pattern. |
| D4 | Transform boundary test in separate file | `interpreter.zig` already has ~500 lines of tests. Separate file keeps it manageable. |
| D5 | Fixed PRNG seed (42/99) for state round-trip | Deterministic CI — same random pairs every run. Seed value is arbitrary. |
| D6 | `paths.items.len >= 12` minimum guard | Prevents silent pass when CWD is wrong and Dir.walk finds 0 files. 12 matches current device count. |
| D7 | FieldTag ignore list maintained in test file | Ignore-listed names (sensor_timestamp, touch*_contact) are metadata fields that intentionally map to `.unknown`. Adding new ignored fields is explicit and reviewable. |
