# Brief: Phase 10 Wave 2 — Code Quality Fixes (T6-T11)

## Why

Six-dimensional audit identified code quality issues across supervisor, WASM backend, uinput
vtable, and event_loop: duplicated teardown/reload logic (DRY violation), unsafe `@bitCast`
deserialization, imprecise `anyerror` in vtable signatures, scattered EFD constants, inline
`@import` in function bodies, dead code, and a missing `errdefer` rollback on allocation failure.

These are all localized, independent fixes with no cross-dependency. Each improves
maintainability, safety, or error precision without changing external behavior.

## Scope

| Task | Description | Dependencies |
|------|-------------|-------------|
| T6 | Supervisor `teardownManaged()` DRY extraction (4x duplicate teardown) | none |
| T7 | Supervisor `doReload()` DRY extraction (2x duplicate reload) | none |
| T8 | WASM `deltaFromBytes` `@bitCast` safety audit | none |
| T9 | `OutputDevice.VTable` `anyerror` -> precise `EmitError` / `PollFfError` | none |
| T10 | EFD constants -> `ioctl_constants.zig`, inline `@import` fix, dead `moveTo` removal | none |
| T11 | Supervisor `attachWithInstance` `errdefer` rollback for `devname_map.put` | none |

## Success Criteria

- Supervisor teardown logic exists in exactly one private function; `deinit`, `detach`,
  `reload`, and `stopAll` all call it
- Supervisor reload logic (SIGHUP + debounce) exists in exactly one private function
- `deltaFromBytes` either uses field-by-field extraction or has a `// SAFETY:` comment
  documenting the `@bitCast` preconditions
- `OutputDevice.VTable.emit` and `poll_ff` use named error sets, not `anyerror`
- `EFD_CLOEXEC` / `EFD_NONBLOCK` defined once in `ioctl_constants.zig`, used by
  `event_loop.zig` and `supervisor.zig`
- No inline `@import` in function bodies or struct field type annotations in `event_loop.zig`
- `render.zig` `moveTo` function removed (dead code)
- `attachWithInstance` rolls back `devname_map` entry if `spawnInstance` fails
- `zig build test` passes all existing tests (no behavioral changes)

## Out of Scope

- Wave 1 tasks (T1-T5: architecture fixes — already complete)
- Wave 3/4 tasks (generative testing, community contribution model)
- Any new features or API changes

## References

- Phase plan: `planning/phase-10.md` (docs-repo, Wave 2)
- Design principles: `design/principles.md` (docs-repo, P9)
- Audit source: `_agent/state/needs-snapshot.md` (docs-repo)
- Source files: `src/supervisor.zig`, `src/wasm/wasm3_backend.zig`, `src/io/uinput.zig`,
  `src/event_loop.zig`, `src/debug/render.zig`, `src/io/ioctl_constants.zig`
