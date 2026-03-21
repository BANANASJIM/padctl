# Reviewer Report v2: Phase 9 Wave 3 — Adaptive Trigger (T8/T9)

Date: 2026-03-21

## Verdict: PASS

v1 提出 2 个 BLOCKING (TECH-1, R2) + 4 个 WARNING (TECH-2, R3, R4, TECH-6)。全部已修复，逐项验证如下。

---

## BLOCKING 修复验证

### TECH-1 [RESOLVED] — 模板字节数一致性

逐 token 计数确认（含 placeholder，每个 `{name:u8}` 产出 1 byte）：

| Template | Hex tokens | Placeholders | Total tokens = Output bytes |
|----------|-----------|-------------|----------------------------|
| adaptive_trigger_off | 63 | 0 | 63 |
| adaptive_trigger_feedback | 59 | 4 | 63 |
| adaptive_trigger_weapon | 57 | 6 | 63 |
| adaptive_trigger_vibration | 57 | 6 | 63 |

关键字节偏移验证（所有 4 个模板）：
- byte 0 = `0x02` (Report ID)
- byte 1 = `0x0c` (valid_flag0, bit2+3)
- byte 11 = right trigger mode (`0x00` / `0x01` / `0x02` / `0x06`)
- byte 22 = left trigger mode（与 byte 11 对应）
- feedback: byte 12 = r_position, byte 13 = r_strength, byte 23 = l_position, byte 24 = l_strength
- weapon: bytes 12-14 = r_start/r_end/r_strength, bytes 23-25 = l_start/l_end/l_strength
- vibration: bytes 12-14 = r_position/r_amplitude/r_frequency, bytes 23-25 = l_position/l_amplitude/l_frequency

### R2 [RESOLVED] — 测试计划断言与修正后模板一致

TP1-TP5 断言逐条核对：

- TP1 (off): byte 0=0x02, byte 1=0x0c, byte 11=0x00, byte 22=0x00, length=63 — 与模板一致
- TP2 (feedback): byte 11=0x01, byte 12=40, byte 13=180, byte 22=0x01, byte 23=70, byte 24=200, length=63 — 偏移与模板 placeholder 位置匹配，参数使用 `<< 8` 编码
- TP3 (weapon): byte 11=0x02, bytes 12-14 = 40/160/180, byte 22=0x02, bytes 23-25 = 30/140/200, length=63 — 匹配
- TP4 (vibration): byte 11=0x06, bytes 12-14 = 10/255/30, byte 22=0x06, bytes 23-25 = 10/200/25, length=63 — 匹配
- TP5: 4 个模板均 63 tokens → 63 bytes — 已确认

TP2-TP4 现在指定 `<< 8` 编码（与 TECH-2 修复一致）。

---

## WARNING 修复验证

### TECH-2 [RESOLVED] — Param.value 编码已文档化

`design.md` event loop 部分新增 **Param.value encoding** 段落，包含：
- `fillTemplate` 通过 `Param.value >> 8` 提取 u8 输出字节
- `buildAdaptiveTriggerParams` 必须左移 8 位、截断为 u16
- 具体示例：`position = 70` → `Param{ .value = 70 << 8 }` → output byte 70

### R3 [RESOLVED] — 缺失参数负测试已添加

`test-plan.md` 新增 TP15b：`mode = "feedback"` 无 `left`/`right` 段，验证 `buildAdaptiveTriggerParams` 产出全零参数、输出 63 字节格式正确。

### R4 [RESOLVED] — BT 显式排除

`brief.md` out-of-scope 新增条目："Bluetooth output report (Report ID 0x31) — BT has a different header structure and requires CRC32; this wave covers USB output (Report ID 0x02) only"。

### TECH-6 [RESOLVED] — Per-layer 验证先例已注明

`design.md` validation 部分注明此为 `mapping.zig` 中首个 per-layer output-config 验证，建立后续同类检查的先例。

---

## 再检查：完整性

| Criterion | Status |
|-----------|--------|
| brief.md 范围清晰、out-of-scope 完整 | OK |
| design.md 覆盖 T8 模板 + T9 结构/验证/事件循环 | OK |
| tasks.md 可执行步骤 + 代码片段 | OK |
| test-plan.md 覆盖 TP1-TP23 + TP15b | OK |
| Gardener BLOCKING 已解决 | OK |
| Reviewer v1 BLOCKING 已解决 | OK |
| 所有 WARNING 已处理 | OK |

## 再检查：P6 合规

与 v1 一致 — P6 完全满足。设备配置保存协议字节（模板、Report ID、valid_flag0、mode byte 值），映射配置仅含模式名称和数值参数。无交叉污染。

## 遗留事项

无。OpenSpec 可进入实施阶段。
