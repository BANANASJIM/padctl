# tests/wasm/

WebAssembly test fixtures for the wasm3 backend (`src/wasm/wasm3_backend.zig`).

- `*.wat` — WebAssembly text-format source (the source of truth).
- `*.wasm` — compiled binary, committed so `@embedFile` works without a wasm
  toolchain in CI / the build.

## Rebuilding

After editing any `*.wat`, recompile its `*.wasm` with `wat2wasm` from
[wabt](https://github.com/WebAssembly/wabt):

```sh
wat2wasm tests/wasm/echo_plugin.wat -o tests/wasm/echo_plugin.wasm
wat2wasm tests/wasm/no_exports.wat  -o tests/wasm/no_exports.wasm
wat2wasm tests/wasm/trap_plugin.wat -o tests/wasm/trap_plugin.wasm
```

Output is deterministic for a given wabt version (verified reproducible with
`wat2wasm 1.0.39`: a fresh compile is byte-identical to the committed binary).

## Fixtures

| File | Exports | Used by |
|------|---------|---------|
| `echo_plugin.wat` | `init_device`, `process_calibration`, `process_report` (echoes input → output via `memory.copy`) | echo round-trip / initDevice / lifecycle / calibration tests |
| `no_exports.wat` | `memory` only — no plugin functions | issue #214 defensive load() path (missing-export must not crash) |
| `trap_plugin.wat` | `process_report` only, body `unreachable` | trap handling + trap rate-limit auto-unload tests |

## Note on issue #214

The original `skip_wasm3_runtime_tests` gate blamed a stale `echo_plugin.wasm`
missing `init_device`. That was a misdiagnosis: the committed `.wasm` is in
sync with its `.wat` (re-verify with the commands above). The real crash was
wasm3's third-party C being subject to the project's `.sanitize_c = .trap`
UBSan-trap, which SIGILLs on wasm3's intentional UB-prone interpreter/compiler
patterns at first lazy function compile. Fixed in `build.zig` by exempting only
the vendored wasm3 translation units (`-fno-sanitize=undefined`), plus
defensive `m3_FindFunction` return-value handling in `load()`.
