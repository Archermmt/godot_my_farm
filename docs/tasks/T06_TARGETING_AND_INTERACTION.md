# T06 统一目标预览与蓄力交互

## 目标

建立所有工具、种子和普通物品共享的 CellState preview、光标预览和蓄力状态机。此任务先证明目标选择一致性，不提交具体翻地/收获效果。

## 依赖

- T04、T05 completed。

## 交付范围

- `scripts/actors/effect_area.gd`：作为 Player 交互组件统一负责交互状态、目标计算与预览绘制，直接读取 PlayerState，具体使用逻辑由 Player 在 release 时调用 Item/Tool 运行时类型实现。
- `scripts/actors/backpack.gd`：Player 子节点，按当前玩家容器复用 Tool/Seed 运行时对象，避免每次交互临时创建。
- `scenes/world/effect_area.tscn` 与脚本。
- Player 场景持有唯一的 `EffectArea`，并直接把 active BackpackSlot 和当前 BaseMap 交给它。
- targeting/charge 单元与集成测试。

## 实现要求

1. 状态机严格为 idle -> charging -> committed/cancelled -> idle；一次 release 只由 Player 提交一次动作和 commit signal，EffectArea 不执行 Tool/Seed.use。
2. EffectArea 从 PlayerState 读取 facing、cell、active stack 数量和体力；charge level 由 EffectArea 管理，BaseMap revision 在 begin 时保存为事务快照。目标起点和扩展方向完全由角色朝向确定，不读取鼠标位置。
3. `EffectArea` 直接维护有序 `Array[CellState]` 预览视图；体力、数量、阻挡和地图边界由 EffectArea 判断，结果使用 CellState.InteractionFlag 标记 VALID/INVALID/ENTITY，不再创建重复的目标数据类型。
4. EffectArea 完整渲染同一 preview 返回的 CellState；VALID、INVALID 与 ENTITY 使用不同颜色/形状反馈，地图外 cell 不进入 preview。
5. charge level 按数据配置升级并限制最大级；目标范围遵循参考的单格、3x1、3x3、9x3、9x9 语义，不超地图或可用数量。
6. commit 接受已经显示的 preview token/result，并重新校验资源版本；不得悄悄重新选择另一批目标。
7. cancel、UI 打开、地图切换、active source/选中格变化、失去焦点都会清理 cursor 和 charging 状态，不消费物品/体力。
8. 不在 EffectArea 写锄头/种子/斧头名称判断；通过 `ToolMeta` / `SeedMeta` 子类和 `ToolKind` 分发。

## 自动化验收

- 固定地图中心/边缘和四个朝向的范围顺序正确、结果稳定。
- holding frame 达阈值时 level 只增加一次，release 只提交一次。
- active stack 数量不足时 preview 截断；零数量或无体力时 preview 为空，由调用层提供操作反馈。
- preview 后地图状态版本变化时 commit 失败且无资源消费。
- 所有取消来源都回到 idle 且 cursor 清空。

## godot-ai 验收

仅用键盘从 Toolbar 选择锄头占位，分别短按和多级长按 `use_held`；改变 Player facing 后在地图中心/边缘截图范围变化。用 input_sequence 确认 frame 时序，检查 `actions_pressed_at_end` 为空、commit 信号计数正确，日志无重复连接。

## 不做

- 不修改地块、消耗体力或生成掉落。
- 不为各工具复制独立 cursor 逻辑。
- 不读取鼠标位置或鼠标按键，不允许 pointer 覆盖角色朝向目标。

## 完成记录

- 状态：completed（2026-08-11）。
- 已建立统一的 `EffectArea`；Player 直接控制 EffectArea，EffectArea 负责蓄力状态、目标计算和 preview 绘制，具体提交逻辑由 Player 调用 Backpack 中复用的 Item/Tool 运行时对象。
- Player 通过 `use_held` 按下/释放驱动 `idle -> charging -> committed/cancelled -> idle`；重复 release 不会重复提交。
- `ToolMeta.charge_levels` 和 `SeedMeta.charge_levels` 分别配置目标尺寸；Hoe、WateringCan、Sickle、Basket 默认五档，Pickaxe、Axe 默认三档（1x1、3x1、3x3），Seed 使用四档（1x1、3x1、3x3、9x3）。目标顺序由 facing 和前方距离稳定生成，SEED 目标按 stack amount 标记超量格为 invalid。
- 蓄力期间 Player 保持 facing 不变并进行连续移动；玩家世界坐标跨过地图 cell 边界后更新 PlayerState.cell，EffectArea 按 cell 尺寸离散重建预览。
- `BaseMap.interaction_revision` 用于 preview token 版本校验；地图版本变化时 commit 失败且不发出提交事实。
- `EffectArea` 由 Player 场景持有，切换 cabin、farm、field 时继续复用；它使用 top-level 变换，并直接用 preview 返回的 CellState 绘制目标格和实体标记。
- 交互释放后的工具/种子逻辑由 `Player._release_interaction()` 直接完成；EffectArea 只负责目标区域预览和释放状态，不执行物品使用逻辑。
- 自动化：73 tests passed；Player/EffectArea 所有权、EffectArea 世界坐标稳定性、三张地图不重复持有 EffectArea 的场景契约和主场景启动通过。
