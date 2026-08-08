# T07 翻地与浇水

## 目标

实现锄头和水壶的真实网格事务，使目标预览、FarmCellState、Dug/Watered TileMapLayer、体力与反馈保持一致。

## 依赖

- T06 completed。

## 交付范围

- 完成 `GridToolAction` 及 hoe/water 配置。
- `FarmSystem` 增加 till/water transaction 和状态投影。
- Dug/Watered 占位 tiles 与音画事件。
- 工具事务单元/集成测试。

## 实现要求

1. Hoe 仅作用于 static diggable、未 dug、无 occupant 的格；重复翻地为明确无效。
2. WaterCan 仅作用于 dug 格；写入当前绝对 day index 的 `watered_on_day`。同日重复浇水不重复耗体力。
3. 多格行动先收集全部有效目标，再计算体力；体力不足时整次失败，地块和体力都不变。
4. 成功事务顺序：状态提交 -> TileMap 投影 -> 体力扣除 -> facts signal -> audio/effect。投影失败必须报告并可由状态重建。
5. action 返回结构化结果：changed cells、skipped reasons、stamina spent；UI 不解析日志判断结果。
6. MapState 写回并恢复后，dug/watered 表现与状态一致。
7. Cursor preview 的 valid 条件复用 FarmSystem 的查询规则，不能另写一套。

## 自动化验收

- 可挖/不可挖/已有占用/重复操作。
- 单格和多格的 changed 数、体力消耗、signal 次数。
- 体力恰好、少 1、为 0 三种边界，失败时状态深度等价。
- watered_on_day round-trip，另一天查询不再视为当天浇水但历史值保留。
- 从 FarmCellState 重建 TileMap 的 used cells 与状态一致。

## godot-ai 验收

在 farm 使用短按和蓄力 hoe/water，截图原始、翻地、浇水三状态及无效区域。运行时读取 cell snapshot 和 Player energy；切到 cabin 再返回，确认表现未丢。日志无 TileSet/坐标错误。

## 不做

- 不播种、不推进作物成长。
- 不实现水壶容量/补水；参考基线未要求该闭环。

## 完成记录

STATUS 记录地块坐标快照、体力前后、往返恢复、run_id 和截图；总表 T07 completed。

