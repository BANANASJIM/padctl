# Gardener Report: Phase 9a T2 — DualSense IMU Calibration WASM Plugin

## 检查范围

交叉校验 OpenSpec 4 文件（brief/design/tasks/test-plan）与代码实现的一致性。

重点对照：
- `src/wasm/wasm3_backend.zig` — WASM 后端实现
- `src/wasm/host.zig` — HostContext 方法
- `src/wasm/runtime.zig` — WasmPlugin vtable 定义
- `sdk/wasm/padctl_plugin.h` — C SDK 头文件

## 结论

**PASS** — OpenSpec 与实现一致，无阻塞问题。

## 详细检查

### 1. Host API 导入函数对齐

| OpenSpec 引用 | wasm3_backend.zig 链接 | SDK 头文件声明 | host.zig 方法 | 状态 |
|--------------|----------------------|--------------|-------------|------|
| `set_state(key, key_len, val, val_len)` | `hostSetState` — `"v(iiii)"` (L169) | `set_state(key, key_len, val, val_len)` | `setState(key, val)` (L66) | OK |
| `get_state(key, key_len, out, out_len)` | `hostGetState` — `"i(iiii)"` (L170) | `get_state(key, key_len, out, out_len)` | `getState(key)` (L87) | OK |
| `get_config(key, key_len, out, out_len)` | `hostGetConfig` — `"i(iiii)"` (L168) | `get_config(key, key_len, out, out_len)` | `getConfig(key, out)` (L57) | OK |
| `device_read` | `hostDeviceRead` — `"i(iii)"` (L165) | `device_read(report_id, buf, len)` | `deviceRead(report_id, buf)` (L36) | OK（T2 不使用） |
| `device_write` | `hostDeviceWrite` — `"i(ii)"` (L166) | `device_write(buf, len)` | `deviceWrite(buf)` (L42) | OK（T2 不使用） |
| `log` | `hostLog` — `"v(iii)"` (L167) | `padctl_log(level, msg, len)` | `log(level, msg)` (L48) | OK |

### 2. VTable 方法路径

| OpenSpec 生命周期步骤 | vtable 方法 | wasm3_backend.zig 行为 | 状态 |
|-------------------|-----------|----------------------|------|
| Host 调用 `process_calibration(buf, len)` | `processCalibration` (L93-100) | 拷贝 buf 到 WASM 内存，调用导出函数 | OK |
| Host 每帧调用 `process_report(raw, out)` | `processReport` (L103-127) | 拷贝 raw 到 WASM，调用导出，`ret >= 0` → `.override` | OK |
| 返回值语义：`>= 0` = override, `< 0` = drop | `processReport` (L121-126) | 与 SDK 头文件注释一致 | OK |

### 3. State 存储约束

- `HostContext.max_value_size = 4096`，T2 state 大小 72 字节 — 远低于上限 ✓
- `HostContext.max_entries = 256`，T2 仅用 1 个 key `"c"` — 远低于上限 ✓

### 4. WASM 导出函数名称

| OpenSpec 定义 | wasm3_backend.zig `m3_FindFunction` | SDK 头文件 | 状态 |
|-------------|-------------------------------------|-----------|------|
| `process_calibration` | `"process_calibration"` (L78) | `void process_calibration(...)` | OK |
| `process_report` | `"process_report"` (L79) | `int32_t process_report(...)` | OK |
| `init_device`（T2 不使用） | `"init_device"` (L77) | `int32_t init_device(void)` | OK |

### 5. OpenSpec 内部一致性

- brief.md 成功标准 ↔ test-plan.md 测试项：TP1-TP4 覆盖全部 4 条成功标准 ✓
- design.md 校准公式 ↔ tasks.md T2a 实现步骤：公式参数完全对应 ✓
- design.md TOML 变更 ↔ tasks.md T2c：`[wasm]` section 格式一致 ✓
- test-plan.md 回归测试 TP5-TP7：要求现有 wasm3/host/mock 测试不受影响 ✓

### 6. 建议（非阻塞）

- test-plan.md L33 `gyro_speed_minus = -582` 与 L36-37 的说明存在矛盾（说明指出 "real controllers are positive"）。建议实现时使用 L37 推荐的 `speed_plus=1164, speed_minus=1164`，忽略 L33 的负值示例。test-plan.md 自身已在 Note 中标注此问题，无需修改。
