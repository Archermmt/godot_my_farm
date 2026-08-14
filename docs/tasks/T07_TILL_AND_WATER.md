# T07 翻地与浇水

## 目标

实现锄头和水壶的真实网格事务，使目标预览、MapCell、体力与反馈保持一致。

## 依赖

- T06 completed。

## 交付范围

- 在具体 Tool 运行时类型中完成 hoe/water 行为及配置。
- `MapCell` 增加 till/water transaction。
- 翻地与浇水音画事件，不创建状态 TileMapLayer。
- 工具事务单元/集成测试。

## 实现要求

1. Hoe 仅作用于 static diggable、没有 DUG flag、无 occupant 的格；成功后写入 `CellState.CellFlag.DUG`，重复翻地为明确无效。
2. WaterCan 仅作用于带 DUG flag 的格；成功后写入 `CellState.CellFlag.WATERED`。同日重复浇水不重复耗体力。
3. 多格行动先收集全部有效目标，再计算体力；体力不足时整次失败，地块和体力都不变。
4. 成功事务顺序：状态提交 -> 无状态视觉投影 -> 体力扣除 -> facts signal -> audio/effect。投影失败必须报告并可由状态重建。
5. Tool 返回结构化结果：`effect_cells`、skipped reasons、stamina spent；UI 不解析日志判断结果。
6. MapState 写回并恢复后，dug/watered 表现与状态一致。
7. Cursor preview 的 valid 条件复用 MapCell 的查询规则，不能另写一套。

## 自动化验收

- 可挖/不可挖/已有占用/重复操作。
- 单格和多格的 changed 数、体力消耗、signal 次数。
- 体力恰好、少 1、为 0 三种边界，失败时状态深度等价。
- DUG/WATERED flags round-trip；日推进完成生长结算后清除 WATERED。
- 从 MapCell 绑定的 CellState 重建动态表现且状态一致。

## godot-ai 验收

在 farm 使用短按和蓄力 hoe/water，截图原始、翻地、浇水三状态及无效区域。运行时读取 cell snapshot 和 Player energy；切到 cabin 再返回，确认表现未丢。日志无 TileSet/坐标错误。

## 不做

- 不播种、不推进作物成长。
- 不实现水壶容量/补水；参考基线未要求该闭环。

## 完成记录

- 状态：completed（2026-08-11）。
- 新增运行时 `Tool` 与结构化 `ToolOutcome`；Hoe/WateringCan 按 ToolMeta 配置执行，工具事务不进入 Cursor，Player 只根据 Outcome 扣除体力。
- MapCell 的 till/water 查询同时供 preview 与 commit 使用；重复翻地、重复浇水、占用、非可耕地和未翻地均返回稳定的 skipped reason。
- 多格事务先收集有效格，每次事务固定消耗一次 `base_stamina_cost`；蓄力扩大范围不按格重复收费。体力不足时 flags、revision 和 stamina 全部不变。
- 成功顺序为 CellState 修改、BaseMap projection/revision、PlayerState stamina、事实信号、AudioManager/效果请求；投影错误单独写入 result 并发出事实。
- BaseMap 通过无状态 `CellStateProjection` 绘制 DUG/WATERED，不建立动态 TileMapLayer；MapState JSON 往返后可直接重建。
- `clear_watered()` 供 T08 在作物生长结算完成后调用，确保读取前一天 WATERED 后再清除。
- 自动化：82 tests / 4340 assertions；包含 9x9 最大蓄力固定单次消耗和可耕地专用 tile 场景契约。资源 import、主场景启动和 `git diff --check` 通过。
