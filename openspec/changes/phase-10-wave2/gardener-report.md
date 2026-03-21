# Gardener Report: Phase 10 Wave 2

审查范围: `brief.md`, `design.md`, `tasks.md`, `test-plan.md`
交叉验证对象: `src/supervisor.zig`, `src/wasm/wasm3_backend.zig`, `src/io/uinput.zig`,
`src/event_loop.zig`, `src/debug/render.zig`, `src/io/ioctl_constants.zig`

---

## SEM-6 (语义准确性)

### T6: teardownManaged — WARNING

design.md 称 detach 中有 "5-line block" 需要替换, 但实际 `detach` 函数 (L206-209)
只有 4 行拆卸操作, 缺少 `if (m.devname) |dn| self.allocator.free(dn)`.

对比其余三处 (`deinit` L163-168, `reload` L265-269, `stopAll` L233-237) 均包含
devname 释放行, 唯独 detach 没有. 这意味着当前 detach 可能存在 devname 内存泄漏
(当 `m.devname != null` 时). 提取 `teardownManaged` 会隐式修复此 bug, 但 OpenSpec
未明确标注这一差异, 也未在 test-plan 中对此行为做回归验证.

**建议**: design.md T6 部分应注明 detach 当前仅 4 行, 提取后会补上 devname 释放;
test-plan 应增加: "detach 后 devname 内存确认释放 (allocator 无泄漏)".

其余三处 (`deinit`, `reload`, `stopAll`) 拆卸代码与 design.md 描述完全一致.

### T7: doReload — OK

SIGHUP handler (`pollfds[1]`, L367-375) 与 debounce handler (`pollfds[4]`, L390-403)
的 reload 逻辑确认完全重复. pollfds 索引与 design.md 描述一致.

### T8: deltaFromBytes @bitCast — OK

`wasm3_backend.zig` L331: `d = @bitCast(bytes.*)` 确认存在.
函数签名和结构体与 design.md "Current Code" 一致 (L327-333).

### T9: anyerror VTable — WARNING

`OutputDevice.VTable` L61-62 确认使用 `anyerror`. `AuxOutputDevice.VTable` L86
确认使用 `anyerror`. `TouchpadOutputDevice.VTable` L483 确认使用 `anyerror`.

design.md 正文提到 "Also apply the same pattern to `AuxOutputDevice.VTable` and
`TouchpadOutputDevice.VTable`", 但 tasks.md 只有 T9d 覆盖了 `AuxOutputDevice`,
没有对应 `TouchpadOutputDevice` 的 task 条目. 实施者可能遗漏 TouchpadOutputDevice.

**建议**: tasks.md 增加 T9f: "Change `TouchpadOutputDevice.VTable.emit_touch` return
type from `anyerror!void` to `EmitError!void` (or `TouchEmitError`)", 并在 test-plan
中增加对应验证项.

### T10a: EFD 常量 — OK

`supervisor.zig` L135-136 和 `event_loop.zig` L152-153 均定义了本地
`EFD_CLOEXEC`/`EFD_NONBLOCK`. `ioctl_constants.zig` 确认尚无这两个常量.
与 design.md 描述完全一致.

### T10b: inline @import — OK

`event_loop.zig` 确认存在以下 inline `@import`:
- L56: `output: @import("io/uinput.zig").OutputDevice`
- L58: `aux_output: ?@import("io/uinput.zig").AuxOutputDevice`
- L59: `touchpad_output: ?@import("io/uinput.zig").TouchpadOutputDevice`
- L319: `?@import("core/interpreter.zig").GamepadStateDelta`
- 测试区块 L404, L427, L431: 多处 inline `@import`

design.md 行号与实际源码一致.

### T10c: dead moveTo — OK

`render.zig` L17-19 定义 `fn moveTo`, L214 `_ = moveTo;` 压制未使用警告.
函数体内无任何调用点, 确认为死代码. 与 design.md 描述一致.

### T11: attachWithInstance errdefer — OK

`supervisor.zig` L191-192:
```
try self.devname_map.put(dev_copy, phys_copy);
try self.spawnInstance(phys_key, instance);
```
确认 `put` 之后无 errdefer, `spawnInstance` 失败会导致 map 条目残留.
design.md 的 errdefer 堆栈分析 (反序展开: fetchRemove -> free phys_copy -> free dev_copy)
逻辑正确.

---

## DC1 (文档一致性)

### brief.md vs design.md — OK

所有 6 个 task 的范围、成功标准、文件列表在 brief 和 design 间一致.

### design.md vs tasks.md — WARNING

如上所述, design.md 提到 `TouchpadOutputDevice` 但 tasks.md 缺少对应条目.

### tasks.md vs test-plan.md — WARNING

- T6 detach 的行为差异 (4 行 vs 5 行) 未在 test-plan 中体现.
- T9 test-plan (TP11-TP15) 未覆盖 `TouchpadOutputDevice` 的 anyerror 修改.

### 引用 refs — OK

所有文件路径引用均可在代码仓库中确认存在.

---

## TECH (技术准确性)

### T8 comptime 断言有效性 — NOTE

design.md 提出的 comptime 断言:
```zig
std.debug.assert(@sizeOf(GamepadStateDelta) == @bitSizeOf(GamepadStateDelta) / 8);
```
此断言可检测 struct 总体有无 padding, 但无法检测字段间的 padding.
对于含 `?bool` + `?i16` 混合排列的 struct, 字段间可能存在对齐 padding
而总大小恰好等于 bitSize/8. 不过作为轻量级防护已足够, 非阻塞问题.

### T9 EmitError 覆盖范围 — NOTE

`UinputDevice.emit` 内部调用 `std.posix.write`, 其错误集远大于
`{WriteFailed, DeviceGone}`. 实施时需 `catch` 所有 posix 错误并映射到这两个
变体, 否则编译失败. design.md T9c 提及此点 ("Map posix write errors to
EmitError.WriteFailed or EmitError.DeviceGone"), 但 tasks.md T9c 描述较简略.
不算阻塞, 实施者应注意.

### T11 spawnInstance 参数 — NOTE

design.md T11 "Current Code" 中写 `try self.spawnInstance(phys_key, instance)`,
源码确认一致 (L192). 但注意这里传入的是原始 `phys_key` 参数而非 `phys_copy`,
`spawnInstance` 内部会再做一次 `dupe`. 这是现有行为, 非本次修改引入, 不影响
errdefer 的正确性.

---

## 总结

| 检查项 | 状态 |
|--------|------|
| SEM-6: T6 detach 行数不匹配 | WARNING |
| SEM-6: T9 TouchpadOutputDevice 缺失 task | WARNING |
| DC1: tasks.md vs design.md TouchpadOutputDevice 缺失 | WARNING |
| DC1: test-plan 缺 detach devname 泄漏验证 | WARNING |
| TECH: comptime 断言精度 | NOTE |
| TECH: EmitError posix 映射 | NOTE |
| TECH: spawnInstance phys_key vs phys_copy | NOTE |
| 其余所有项 | OK |

无 BLOCKING 问题. 三项 WARNING 建议在实施前修订 tasks.md 和 test-plan.md.
