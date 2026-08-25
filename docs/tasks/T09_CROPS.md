# T09 播种、成长与作物阶段

## 目标

实现 SeedMeta/Seed 种子行动、PlantMeta/PlantState/Plant、生命阶段投影和基于前一日浇水的成长，使“翻地 -> 播种 -> 浇水 -> 次日成长”成为可验证闭环。

## 依赖

- T07 completed。

## 交付范围

- `scenes/items/plants/plant.tscn` 与 `scripts/items/plant.gd`。
- 在具体 Item 使用逻辑中完成播种，并接入 PlantMeta 阶段结构。
- 欧洲防风草至少 4 个可区分的原创占位阶段。
- crop/seed 单元和集成测试。

## 实现要求

1. Seed 只能作用于 dug、无 occupant/crop 的格；每个成功目标消耗 1 个对应种子。
2. 多格播种目标数不能超过 Itembar active slot 数；预览已截断，commit 后数量和实际 crop 数严格一致。
3. 每个地图 Item 有稳定 instance ID；MapState.items 以 ItemState 基类持有只含可变数据和 meta_id 的 PlantState，CellState.item_ids 保存引用；BaseMap 只接受 PlantMeta/PlantState 组合并重建 Plant。
4. stage 由 `growth_days` 和递增 day threshold 数据计算；Item 不硬编码具体天数/图像。
5. day_advanced 只在 cell 带 `CellState.CellFlag.WATERED` 时增长一次，结算后清除 WATERED。重复同一事件必须幂等。
6. 未浇水、刚播种但未浇水、浇水后跨日、加载中间阶段都要有确定行为。
7. `MapItems/Plants` y-sort 和格中心对齐；阶段变化不能改变占用或出现一帧空白。
8. 成熟状态提供 harvestable 能力接口，具体产出在 T09。
9. 每种 Seed 和对应 Plant/Produce 必须生成可区分图标并配置到 ItemMeta；Seed 图标在 Itembar/HUD 中实际显示。

## 自动化验收

- 无效格、无种子、数量不足、合法多格播种。
- 每个阶段阈值前后和最终成熟状态。
- 未浇水不成长；前一日浇水增长 1；同一 day event 重放不重复增长。
- seed/crop/farm/map round-trip 后阶段和实例 ID 一致。
- Plant free 后从 state 重建，节点数和占用不重复。
- Seed/Plant/Produce 的 ItemMeta 图标全部非空，不同作物可通过图标区分。

## godot-ai 验收

通过真实键盘输入从 Toolbar 选择工具、从 Itembar 选择种子，完成翻地、多格播种和浇水；使用受控测试入口推进一天，截图至少三个阶段。检查种子数量、ItemState 和 `MapItems/Plants` 节点数；map 往返后仍一致，日志清洁。

## 不做

- 不实现成熟产出、树木或随机作物。
- 不添加季节死亡、连作或施肥。

## 完成记录

STATUS 记录作物定义阈值、day/浇水快照、种子数量、run_id 和阶段截图；总表 T09 completed。
