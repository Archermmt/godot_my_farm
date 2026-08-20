# T10 采集对象、掉落与拾取

## 目标

完成镰刀、篮子、镐、斧作用于作物/草/石头/树木的具体 Tool 行为，并实现确定掉落、吸附拾取、满包保留和树桩转换。

## 依赖

- T06、T08 completed。

## 交付范围

- Harvestable/Pickup/Tree/Obstacle/Plant 组件或等价场景。
- 完成具体 Tool、Harvestable、HarvestableDrop、ItemFactory 和 EffectHost 最小链路。
- 原创占位草、石头、树、树桩、木/石/草/作物掉落。
- harvest/drop/pickup 单元与集成测试。

## 实现要求

1. Harvestable 当前 stage 定义生命、允许 tool_kind、掉落表和受击反馈；错工具 preview/commit 均无效。
2. 伤害与蓄力规则由工具配置计算；对象生命归零后只结算一次掉落，并通过 BaseMap 同时删除运行时 Item、ItemState 和所属 CellState.item_ids 引用。
3. 内嵌 HarvestableDrop 使用可注入 RNG，min <= amount <= max；同一个死亡事务不因重试重复掉落。
4. 成熟 Plant 用 Basket/指定工具收获，产出进入背包或生成 Pickup；格子占用清理，是否保留 dug 状态按数据规则明确。
5. Tree 根据 Player 相对 x 确定倒向；成熟树死亡生成 stump，stump 可再次用斧处理。动画期间禁止二次命中结算。
6. Pickup 使用 Area2D 探测 Player，在追踪半径内以 delta 平滑吸附；距离为 0 时不得除零。
7. 拾取先尝试 BackpackState.add_item；全部成功才移除世界节点，部分/满包时剩余数量保留并停止吞物。
8. 世界 Item 都有稳定 instance ID，可写入 MapState 并恢复。
9. 工具成功作用于 Harvestable 时，其 StageVisual 使用 Shader 短暂变为纯白后恢复原色，作为明确的命中反馈；每个实例必须拥有独立 ShaderMaterial，禁止一次命中导致同类 Item 同时闪白。错误工具或被拒绝的目标不得播放闪白。
10. 本任务引入的 Harvestable、掉落材料、Food 和剩余 Tool 必须生成并配置 ItemMeta 图标；可拾取物进入背包后使用同一图标显示。
11. Player 蓄力时在头顶显示 ProgressBar；颜色随 level 从浅黄渐变到深绿，释放、取消或交互失效后立即隐藏。可用档位由当前 ToolMeta 的范围或伤害配置决定。
12. Hoe、WateringCan、Sickle、Basket 的蓄力扩大作用范围；Pickaxe、Axe 始终只作用于面前 1x1 格，蓄力改为提高单次伤害，默认三档为基础伤害的 1x/2x/3x。

## 自动化验收

- 每类目标的正确/错误工具、伤害、生命和掉落范围。
- 对同一死亡结果重复 commit 不产生第二份掉落。
- 固定 seed 得到稳定掉落；不同 seed 仍在边界内。
- Pickup 距离为 0、正常吸附、满包、部分堆叠。
- Tree -> stump -> 清除完整状态和占用变化。
- 成熟 Plant 收获后 seed/produce/格子数量守恒。
- 正确工具命中后 Shader 的闪白参数立即置为 1 并自动回落到 0；错误工具不改变参数，两个 Harvestable 实例不共享命中参数。
- 所有 Catalog ItemMeta 的 icon_texture 非空；拾取前后的世界物品、背包 Slot 和手持 HUD 使用同一 Meta 图标来源。
- 蓄力条在 hold 开始时出现，进度和颜色随等级变化，并在 release/cancel 后隐藏。
- Pickaxe、Axe 最大蓄力 preview 仍只有面前一个格子，但对目标分别造成配置的三档伤害；其他工具最大蓄力仍按配置扩大范围。

## godot-ai 验收

仅用 Toolbar 键盘 action 依次选择镰刀/镐/斧/篮子，先用错工具再用正确工具作用草、石、树和成熟作物。截图确认正确命中时只有目标 Item 闪白、错误工具不闪白。再从 Itembar 选择可丢下物品并用 `drop_held` 放到面向格。截图受击、掉落、吸附、树倒/树桩；读取背包变化。制造满包后验证 Pickup 留在世界，日志无除零/已释放实例错误。

## 不做

- 不实现正式粒子、完整音频混音或复杂树倒物理。
- 不增加战斗武器。
- 不通过鼠标选择目标或丢下物品。

## 完成记录

STATUS 记录固定 seed、各掉落、满包结果、run_id 和关键截图；总表 T10 completed。
