# Reviewer Report — Phase 9a OpenSpec

## Findings

| # | Severity | Finding |
|---|----------|---------|
| 1 | [ADVISORY] | tasks.md T1e line 100: `m3_GetResultsI(fn_ptr)` — wasm3 C API 中不存在此函数。正确 API 为 `m3_GetResults(fn_ptr, count, &results)`，返回值通过 `void**` 数组获取。实现者需查阅 pinned commit 的 `wasm3.h` 确认签名。 |
| 2 | [ADVISORY] | tasks.md T1e lines 113-115: `processReport` 返回值 1 时需"construct `GamepadStateDelta` from out buffer"，但 design.md 和 tasks.md 均未定义 output buffer → `GamepadStateDelta` 的反序列化格式。`GamepadStateDelta` 含 15 个混合类型字段（i16/u8/i8/u32，全 optional），需要明确二进制布局（例如 packed struct 直接 memcpy，或约定固定偏移）。建议实现时在 `wasm3_backend.zig` 中定义 `WasmGamepadOutput` packed struct 并文档化其内存布局。 |
| 3 | [ADVISORY] | design.md line 37: C 编译参数 `"-Dd_m3HasWASI=0"` — wasm3 不同版本使用不同宏名（`d_m3HasWASI` vs `d_m3HasWASI`）。gardener report 已标记此问题。实现者 vendor 代码后需检查 pinned commit `79d412ea` 的头文件确认正确宏名。 |
| 4 | [ADVISORY] | test-plan.md: 无测试覆盖 host function 的 OOB 指针校验路径。design.md line 108 明确要求"Bounds-check failure logs a warning and returns -1"，但 TP1-TP8 中无测试验证恶意 `ptr+len > mem_size` 场景。建议追加一个 test fixture（或在 echo_plugin 中构造越界参数）验证 OOB 返回 -1 而非 crash。 |
| 5 | [ADVISORY] | design.md line 126: conditional compilation 使用 `@hasDecl(@import("root"), "wasm3_backend")` 检测 wasm3 是否可用。在 Zig 中 `@import("root")` 在测试上下文中可能不包含 build.zig 注入的 module import。建议实现时改用 `@import("build_options")` 或 `comptime { _ = @import("wasm3_backend"); }` + `@hasDecl` 的更可靠检测方式，视 build.zig 实际注入方式而定。 |
| 6 | [ADVISORY] | tasks.md T1a: 枚举了 17 个 `.c` 文件，包含 `m3_api_wasi.c` 和 `m3_api_uvwasi.c`。既然 `-Dd_m3HasWASI=0` 禁用 WASI，这两个文件可能编译为空（内部有 `#ifdef` 守卫），但仍会产生编译开销。可以考虑排除它们以保持清洁，或确认 wasm3 的编译守卫确实让它们变为 no-op。非阻塞，仅清洁度建议。 |

## Gardener Errors Verification

gardener-report.md 中报告 2 个有效 ERROR（第 3 个经复查降级为 INFO）：

1. **7th host function `get_report_field` 已修复** — design.md host function 表现在正确列出 6 个函数（device_read, device_write, log, get_config, set_state, get_state），与 `host.zig` 完全一致。tasks.md T1d 也列出 6 个 callback。`get_report_field` 已从所有文件中移除。
2. **C file count mismatch 已修复** — brief.md line 15 不再提及具体 C 文件数量。design.md line 7 现在写 "17 files + headers"，与 tasks.md T1a 的 17 文件枚举列表一致。

两个 ERROR 均已正确修复。

## Principle Compliance

| Principle | Verdict | Notes |
|-----------|---------|-------|
| P5 — 单二进制 | PASS | wasm3 通过 `addCSourceFiles` 静态链接进二进制，零运行时依赖。ADR-005 明确认可 vendored C 方式。`-Dwasm=false` 提供无 WASM 退路。 |
| P7 — WASM 逃生舱 | PASS | Phase 9a 正是实现 P7 的核心任务。3 hook ABI（init_device / process_calibration / process_report）与 ADR-005 设计一致。缺失 export 时静默降级为 TOML 模式。 |
| P9 — 独立可测 | PASS | MockPlugin 保留不变（TP13-TP15 回归保护）。Wasm3Plugin 通过 vtable 接口集成，不影响现有 mock 测试。新增 8 个单元测试使用预编译 .wasm fixture，不依赖内核设备。 |

## Completeness Assessment

- design.md → tasks.md 覆盖完整：T1a (vendor) → T1b (build) → T1c (struct) → T1d (host binding) → T1e (3 methods + trap rate limiting)，顺序合理
- T2 (DualSense plugin) 和 T3 (SDK docs) 正确标记为 deferred，依赖关系清晰
- test-plan.md 16 个测试点覆盖了 load/error/init/missing-export/echo-roundtrip/trap/rate-limit/lifecycle/build-flags/regression，覆盖面充足
- brief.md success criteria 与 test-plan.md 验证项一一对应

## Feasibility Assessment

- wasm3 `@cImport` 集成在 Zig 中已有先例，技术可行
- 所有任务无外部阻塞依赖
- WAT → WASM 离线编译 + 提交二进制的策略避免了构建工具链依赖

## Verdict

**PASS**

## Summary

0 blocking, 6 advisory
