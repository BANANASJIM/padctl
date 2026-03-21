# Reviewer Report: Phase 10 Wave 3 (T12-T16)

reviewer: RG1
cross-ref: `gardener-report.md`, `brief.md`, `design.md`, `tasks.md`, `test-plan.md`

## 1. 完整性

### brief → design 覆盖

| brief 目标 | design 对应 | 状态 |
|-----------|------------|------|
| 12+ 设备自动发现 | T12 collectTomlPaths + `>= 12` guard | 完整 |
| 所有字段名映射到已知 FieldTag | T13 parseFieldTag pub + ignore list | 完整（gardener 已修复 ignore list） |
| diff/applyDelta round-trip 1000+ 对 | T14 generateRandomDelta + 固定种子 | 完整 |
| 5 个 transform x 6 boundary = 30+ 断言 | T15 boundary_i16 数组 + inline for | 完整 |
| 全设备 fuzz coverage | T16 循环 fuzz | 部分（见下文） |
| 零硬编码设备路径 | T12 Dir.walk | 完整 |

### design → tasks 覆盖

所有 design 中描述的子任务在 tasks.md 中均有对应 checkbox。任务分解粒度合理:
- T12: 7 个子任务 (a-g)
- T13: 2 个子任务 (a-b)
- T14: 3 个子任务 (a-c)
- T15: 8 个子任务 (a-h)
- T16: 2 个子任务 (a-b)

### test-plan 覆盖

test-plan.md 包含 30 个验证点 (TP1-TP30)，覆盖所有 5 个任务及回归保护。每个 TP 都可在 `zig build test` 输出中验证。

## 2. P9 合规性 (All Modules Independently Testable)

| 要求 | 评估 |
|------|------|
| 所有测试通过 `zig build test` 运行 | **合规** — T12/T13/T16 在 auto_device_test.zig, T14 在 state.zig, T15 在 transform_boundary_test.zig, 均为标准 Zig test |
| 不依赖 root 权限 | **合规** — Dir.walk 读取 devices/ 目录 + parseFile 是纯文件 I/O，不涉及 hidraw/uinput |
| 不依赖外部硬件 | **合规** — 全部使用 synthetic frames 和 TOML 解析 |
| I/O 边界通过 vtable | **合规** — 本 wave 不涉及 I/O 层，仅测试 config 解析和 interpreter 逻辑 |
| 零特权 Layer 0+1 | **合规** |

## 3. 可行性评估

### T12: 可行 — 无阻塞风险

- `std.fs.cwd().openDir` + `dir.walk` 是标准 Zig API
- `zig build test` CWD 已验证为项目根目录（现有 `parseFile("devices/...")` 测试通过）
- 11 个 check 逻辑直接，每个都有现有代码模式可参考

### T13: 可行 — 最简改动

- `fn` → `pub fn` 和 `const` → `pub const` 各改一行
- 不影响现有调用（内部调用不受 pub 影响）
- ignore list 已由 gardener 修复完整

### T14: 可行 — 纯逻辑测试

- `generateRandomDelta` 用 `@bitCast` 生成类型正确的随机值
- 固定种子保证 CI 确定性
- `inline for (std.meta.fields(...))` 是标准反射模式，代码库中无先例但在 Zig 中常用

### T15: 可行 — 需注意 interpreter 内部行为

- transform 测试需要构造完整 TOML → parseString → Interpreter → processReport 流程
- 预期值计算需要理解 `runTransformChain` 的 i64 中间精度和 `applyFieldTag` 的 `@truncate` 行为
- `negate(-32768)` 在 i64 算术下为 32768，`@truncate` 到 i16 为 -32768 — design 已正确说明

### [NON-BLOCKING] T16: 可行但 fuzz 循环有设计缺陷

- **普通 `zig build test`**: 循环正常工作，每个设备 smoke-test 一次
- **`zig build test --fuzz`**: `testing.fuzz` 在第一个设备上无限运行，后续设备不会被 fuzz
- 这不阻塞实现，因为:
  1. 普通模式下已覆盖 "no panic on empty input" 目标
  2. implementer 可选择拆分为独立 test 或接受当前行为
  3. design 已注明 API 适配要求
- fuzz API 代码示例使用了非标准 context 模式（`.{ .interp = interp }` + 嵌套类型），与代码库现有模式（直接传值 + `struct { fn run(ctx: T, ...) }.run`）不一致。implementer 应参考 `interpreter.zig:1312` 的模式

## 4. 遗留问题（非阻塞）

| # | 问题 | 严重度 | 说明 |
|---|------|--------|------|
| 1 | T16 fuzz 循环在 --fuzz 模式下只覆盖第一个设备 | 低 | 普通模式足够；--fuzz 是可选优化 |
| 2 | T16 代码示例 API 模式与代码库不一致 | 低 | design 已注明适配要求 |
| 3 | brief "Seven device configs have zero test coverage" 有歧义 | 信息 | 指的是 validate_e2e_test 中的覆盖，不算错误 |

## 5. 判定

**PASS — 无 BLOCKING 问题**

所有 5 个任务 (T12-T16) 设计完整、技术可行、符合 P9。
gardener 发现的 ignore list 缺陷已内联修复。
T16 fuzz 循环缺陷为非阻塞性的实现细节，implementer 可在实现时调整。
可以进入实现阶段。
