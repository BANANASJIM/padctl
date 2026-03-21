# Gardener Report: Phase 10 Wave 3 (T12-T16)

cross-ref: `src/core/interpreter.zig`, `src/core/state.zig`, `src/config/device.zig`, `devices/**/*.toml`

## SEM-6: 语义准确性

### 设备数量

- brief.md: "5 out of 12 TOML files" — **准确**
  - 现有测试覆盖 5 个设备: vader5, dualsense, ultimate, xbox-elite, switch-pro
  - `devices/` 目录实际包含 **12** 个 `.toml` 文件
  - design.md 中 `paths.items.len >= 12` guard 与实际数量一致

### parseFieldTag 可见性

- design.md T13a 称 `parseFieldTag` 为 `fn`（file-private）— **准确**
  - `interpreter.zig:92`: `fn parseFieldTag(name: []const u8) FieldTag`
- design.md T13a 称 `FieldTag` 为 `const`（file-private）— **准确**
  - `interpreter.zig:69`: `const FieldTag = enum {`

### FieldTag 枚举成员

- design.md 未列出完整枚举，但代码示例中使用了 `.unknown` — **准确**
  - `FieldTag` 共 20 个成员: ax, ay, rx, ry, lt, rt, gyro_x/y/z, accel_x/y/z, touch0_x/y, touch1_x/y, touch0_active, touch1_active, battery_level, unknown

### GamepadStateDelta 字段

- design.md T14a 称 "22 optional fields" — **准确**
  - `state.zig:111-133`: 22 个 `?T` 字段

### parseFile API

- design.md 使用 `device.parseFile(allocator, path)` — **准确**
  - `device.zig:270`: `pub fn parseFile(allocator: std.mem.Allocator, path: []const u8) !ParseResult`

## DC1: 文档一致性

### [WARNING] FieldTag ignore list 不完整

- design.md T13b ignore list: `sensor_timestamp`, `touch0_contact`, `touch1_contact`
- **遗漏**: `left_x_raw`, `left_y_raw`, `right_x_raw`, `right_y_raw`
  - 这四个字段出现在 `devices/nintendo/switch-pro.toml:28-31`
  - 它们在 `parseFieldTag` 中会映射到 `.unknown`
  - 若不加入 ignore list 或 `parseFieldTag`，T13b 测试会在 switch-pro.toml 上失败
- tasks.md T13b 同样遗漏了这四个字段名
- **修复建议**: 将 `left_x_raw`, `left_y_raw`, `right_x_raw`, `right_y_raw` 加入 ignore list

### [WARNING] brief.md 设备覆盖描述需更新

- brief.md: "Seven device configs have zero test coverage"
- 实际: 12 - 5 = 7，但这里说的是 `validate_e2e_test.zig` 中的路径数量
- 另有 `interpreter.zig` 和 `interpreter_e2e_test.zig` 中也包含 dualsense 和 vader5 的测试
- 描述不算错误，但"zero test coverage"略有歧义——更准确的说法是"没有出现在 validate_e2e_test 设备列表中"
- **非阻塞**，可保留原文

## TECH: 技术准确性

### [WARNING] T16 fuzz API 模式与代码库不一致

- design.md T16 使用 `.{ .interp = interp }` 作为 fuzz context，并定义嵌套 `Context` 类型
- 代码库实际模式（`interpreter.zig:1312`）: `testing.fuzz(interp, struct { fn run(ctx: Interpreter, ...) }.run, .{})`
- design.md 自身已注明 "The actual std.testing.fuzz API signature may require adapting"
- **不阻塞实现**，因为 design 已给出免责声明，但代码示例可能误导 implementer

### [WARNING] T16 fuzz 循环问题

- design.md 在 `for (paths.items)` 循环中调用 `std.testing.fuzz`
- 在 `--fuzz` 模式下，`testing.fuzz` 会无限循环运行，第一个设备之后的设备永远不会被 fuzz
- 在普通 `zig build test` 模式下无问题（每个 fuzz 入口只运行一次）
- design 已在 Note 中部分承认此行为，但未明确提出解决方案
- **建议**: implementer 应将每个设备的 fuzz 作为独立 test case（如 `test "fuzz: vader5"` 等），或接受普通模式下的 smoke-test-only 覆盖

### Interpreter.init 参数

- design.md 使用 `interpreter.Interpreter.init(&parsed.value)` — **准确**
  - `interpreter.zig:389`: `pub fn init(config: *const DeviceConfig) Interpreter`
  - Interpreter 是值类型（栈大小结构体），无堆分配 — design 描述准确

### std.ArrayList 命名

- design.md 使用 `std.ArrayList([]const u8)` — **准确**，与代码库用法一致

## 总结

| 级别 | 数量 | 说明 |
|------|------|------|
| ERROR | 0 | — |
| WARNING | 4 | ignore list 不完整, brief 歧义, fuzz API 模式, fuzz 循环 |
| INFO | 0 | — |

**需要修复后再进入 reviewer**:
1. design.md T13b + tasks.md T13b: ignore list 增加 `left_x_raw`, `left_y_raw`, `right_x_raw`, `right_y_raw`
