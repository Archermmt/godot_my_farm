# T08 播种、成长与作物阶段

## 目标

实现种子行动、CropEntity/CropEntityState、生命阶段投影和基于前一日浇水的成长，使“翻地 -> 播种 -> 浇水 -> 次日成长”成为可验证闭环。

## 依赖

- T07 completed。

## 交付范围

- `scenes/world/harvestables/crop.tscn` 与 `scripts/world/crop_entity.gd`。
- 完成 SeedAction、CropDefinition/GrowthStageDefinition 使用链路。
- 欧洲防风草至少 4 个可区分的原创占位阶段。
- crop/seed 单元和集成测试。

## 实现要求

1. Seed 只能作用于 dug、无 occupant/crop 的格；每个成功目标消耗 1 个对应种子。
2. 多格播种目标数不能超过选中 stack 数；预览已截断，commit 后数量和实际 crop 数严格一致。
3. 每个 crop 有稳定 instance ID，所属 CellState.entities 保存 CropEntityState；MapState 只协调跨 cell 事务，节点可由状态重建。
4. stage 由 `growth_days` 和递增 day threshold 数据计算；Entity 不硬编码具体天数/图像。
5. day_advanced 使用 previous/current day，只在 `watered_on_day == previous_day` 时增长一次。重复同一事件必须幂等。
6. 未浇水、刚播种但未浇水、浇水后跨日、加载中间阶段都要有确定行为。
7. `MapEntities/Crops` y-sort 和格中心对齐；阶段变化不能改变占用或出现一帧空白。
8. 成熟状态提供 harvestable 能力接口，具体产出在 T09。

## 自动化验收

- 无效格、无种子、数量不足、合法多格播种。
- 每个阶段阈值前后和最终成熟状态。
- 未浇水不成长；前一日浇水增长 1；同一 day event 重放不重复增长。
- seed/crop/farm/map round-trip 后阶段和实例 ID 一致。
- Crop Entity free 后从 state 重建，节点数和占用不重复。

## godot-ai 验收

通过真实输入翻地、选择种子、多格播种、浇水；使用受控测试入口推进一天，截图至少三个阶段。检查种子数量、CropEntityState 和 `MapEntities/Crops` 节点数；map 往返后仍一致，日志清洁。

## 不做

- 不实现成熟产出、树木或随机作物。
- 不添加季节死亡、连作或施肥。

## 完成记录

STATUS 记录作物定义阈值、day/浇水快照、种子数量、run_id 和阶段截图；总表 T08 completed。
