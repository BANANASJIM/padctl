# Reviewer Report: Phase 10 Wave 2 — Code Quality Fixes (T6-T11)

## 审查范围

- `openspec/changes/phase-10-wave2/brief.md`
- `openspec/changes/phase-10-wave2/design.md`
- `openspec/changes/phase-10-wave2/tasks.md`
- `openspec/changes/phase-10-wave2/test-plan.md`
- `openspec/changes/phase-10-wave2/gardener-report.md`

## 原则合规性

### P5 — Single Static Binary

- COMPLIANT。全部 6 个 task 均为纯代码重构/清理，不引入任何新依赖。EFD 常量整合、inline `@import` 清理、死代码删除均在已有模块内进行。

### P9 — All Modules Independently Testable

- COMPLIANT。`teardownManaged` 和 `doReload` 提取不改变外部接口，`initForTest` 路径不受影响。VTable 错误集收窄使类型检查更严格但不破坏现有 `catch` 用法。T11 errdefer 修复无需新 mock — 可通过 testing allocator 验证 map 回滚。

## Gardener 修复验证

gardener-report.md 报告 3 个 WARNING，均已在 `139edb3` (S: fix Wave 2 OpenSpec gardener warnings) 中修复：

- [x] **W1 (T6 detach 行数不匹配)**: design.md T6 现已注明 detach 当前仅 4 行拆卸 + devname 泄漏说明；test-plan.md 新增 TP2a 验证 detach 后 devname 释放。
- [x] **W2 (T9 TouchpadOutputDevice 缺失 task)**: tasks.md 新增 T9e 覆盖 `TouchpadOutputDevice.VTable.emit_touch` 错误集收窄。原 T9e (mock) 顺延为 T9f。
- [x] **W3 (test-plan 缺口)**: TP2a (detach devname 泄漏) 和 TP15a (TouchpadOutputDevice vtable) 均已补齐。

3 个 NOTE (comptime 断言精度、EmitError posix 映射、spawnInstance phys_key vs phys_copy) 为实现注意事项，非阻塞，无需文档修改。

## 完整性评估

### brief.md

- [x] Why/Scope/Success Criteria/Out of Scope/References 齐全
- [x] 6 个 task 独立无依赖，scope 清晰
- [x] Success Criteria 与 design.md 每项 Solution 对应

### design.md

- [x] T6: 4 处调用点逐一列出，`teardownManaged` 签名含 devname 释放，detach 泄漏问题已标注
- [x] T7: `doReload` 提取方案清晰，`continue` → `return` 语义转换有说明
- [x] T8: SAFETY 注释 + comptime 断言双重防护，方案保守合理
- [x] T9: 精确错误集 `EmitError` / `PollFfError` 定义明确，三个 VTable (Output/Aux/Touchpad) 均覆盖
- [x] T10: EFD 常量、inline @import、死代码三个子项均有具体行号和替换方案
- [x] T11: errdefer 展开顺序分析正确 (fetchRemove → free phys_copy → free dev_copy)
- [x] 6 个设计决策 (D1-D6) 均有 rationale

### tasks.md

- [x] T6a-T6b、T7a-T7b、T8a-T8b、T9a-T9f、T10a-T10e、T11a 步骤具体
- [x] 代码片段可直接参考，无歧义
- [x] T9e (TouchpadOutputDevice) 已补齐，与 design.md 一致

### test-plan.md

- [x] 35 个测试点 (TP1-TP35) 覆盖: teardownManaged 4 处调用 + detach devname 泄漏 (TP1-TP4, TP2a)、doReload 两路径 + error 降级 (TP5-TP7)、deltaFromBytes 安全性 + comptime (TP8-TP10)、精确错误集 5 个验证点 + TouchpadOutputDevice (TP11-TP15a)、EFD/import/moveTo (TP16-TP26)、errdefer 回滚 (TP27-TP29)、回归 (TP30-TP35)
- [x] TP2a 和 TP15a 填补了 gardener 发现的覆盖缺口
- [x] 回归测试覆盖全部受影响模块 (supervisor, wasm3_backend, uinput, event_loop, render)

## 发现

无新发现。所有 gardener WARNING 已修复，NOTE 项为实现阶段注意事项。

## 判定

**PASS** — 无 BLOCKING 问题。P5/P9 合规，四份文档完整一致，gardener 三项 WARNING 全部修复并验证，测试覆盖充分。可进入实现。
