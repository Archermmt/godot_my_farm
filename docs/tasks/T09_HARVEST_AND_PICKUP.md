# T09 采集对象、掉落与拾取

## 目标

完成镰刀、篮子、镐、斧作用于作物/草/石头/树木的统一 HarvestToolAction，并实现确定掉落、吸附拾取、满包保留和树桩转换。

## 依赖

- T06、T08 completed。

## 交付范围

- Harvestable/Pickup/Tree/Obstacle/Plant 组件或等价场景。
- 完成 HarvestToolAction、DropTable、ItemFactory 和 EffectHost 最小链路。
- 原创占位草、石头、树、树桩、木/石/草/作物掉落。
- harvest/drop/pickup 单元与集成测试。

## 实现要求

1. Harvestable 当前 stage 定义生命、允许 tool_kind、掉落表和受击反馈；错工具 preview/commit 均无效。
2. 伤害与蓄力规则由工具配置计算；对象生命归零后只结算一次掉落并从所属 CellState.entities 释放占用。
3. DropTable 用可注入 RNG，min <= amount <= max；同一个死亡事务不因重试重复掉落。
4. 成熟 Crop 用 Basket/指定工具收获，产出进入背包或生成 Pickup；格子占用清理，是否保留 dug 状态按数据规则明确。
5. Tree 根据 Player 相对 x 确定倒向；成熟树死亡生成 stump，stump 可再次用斧处理。动画期间禁止二次命中结算。
6. Pickup 使用 Area2D 探测 Player，在追踪半径内以 delta 平滑吸附；距离为 0 时不得除零。
7. 拾取先尝试 InventoryState.add；全部成功才移除世界节点，部分/满包时剩余数量保留并停止吞物。
8. 世界实体都有稳定 instance ID，可写入 MapState 并恢复。

## 自动化验收

- 每类目标的正确/错误工具、伤害、生命和掉落范围。
- 对同一死亡结果重复 commit 不产生第二份掉落。
- 固定 seed 得到稳定掉落；不同 seed 仍在边界内。
- Pickup 距离为 0、正常吸附、满包、部分堆叠。
- Tree -> stump -> 清除完整状态和占用变化。
- 成熟 Crop 收获后 seed/produce/格子数量守恒。

## godot-ai 验收

依次选择镰刀/镐/斧/篮子，先用错工具再用正确工具作用草、石、树和成熟作物。截图受击、掉落、吸附、树倒/树桩；读取背包变化。制造满包后验证 Pickup 留在世界，日志无除零/已释放实例错误。

## 不做

- 不实现正式粒子、完整音频混音或复杂树倒物理。
- 不增加战斗武器。

## 完成记录

STATUS 记录固定 seed、各掉落、满包结果、run_id 和关键截图；总表 T09 completed。
