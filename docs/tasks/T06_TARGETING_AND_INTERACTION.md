# T06 统一目标预览与蓄力交互

## 目标

建立所有工具、种子和普通物品共享的 CellState preview、光标预览和蓄力状态机。此任务先证明目标选择一致性，不提交具体翻地/收获效果。

## 依赖

- T04、T05 completed。

## 交付范围

- `scripts/actors/interaction_cursor.gd`：作为 Player 交互组件统一负责交互状态、目标计算与预览绘制，直接读取 PlayerState，具体使用逻辑由 Item/Tool 运行时类型实现。
- `scenes/world/interaction_cursor.tscn` 与脚本。
- Player 场景持有唯一的 `InteractionCursor`，并直接把 active ItemStack 和当前 BaseMap 交给它。
- targeting/charge 单元与集成测试。

## 实现要求

1. 状态机严格为 idle -> charging -> committed/cancelled -> idle；一次 release 只触发一次 commit signal。
2. Cursor 从 PlayerState 读取 facing、cell、active stack 数量和体力；charge level 由 Cursor 管理，BaseMap revision 在 begin 时保存为事务快照。目标起点和扩展方向完全由角色朝向确定，不读取鼠标位置。
3. `InteractionCursor` 直接维护有序 `Array[CellState]` 预览视图；体力、数量、阻挡和地图边界由 Cursor 判断，结果使用 CellState.InteractionFlag 标记 VALID/INVALID/ENTITY，不再创建重复的目标数据类型。
4. Cursor 完整渲染同一 preview 返回的 CellState；VALID、INVALID 与 ENTITY 使用不同颜色/形状反馈，地图外 cell 不进入 preview。
5. charge level 按数据配置升级并限制最大级；目标范围遵循参考的单格、3x1、3x3、9x3、9x9 语义，不超地图或可用数量。
6. commit 接受已经显示的 preview token/result，并重新校验资源版本；不得悄悄重新选择另一批目标。
7. cancel、UI 打开、地图切换、active source/选中格变化、失去焦点都会清理 cursor 和 charging 状态，不消费物品/体力。
8. 不在 InteractionCursor 写锄头/种子/斧头名称判断；通过 ItemMeta.use_kind 分发。

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
- 已建立统一的 `InteractionCursor`；Player 直接控制 Cursor，Cursor 负责蓄力状态、目标计算和 preview 绘制，具体提交逻辑归 Item/Tool 运行时类型。
- Player 通过 `use_held` 按下/释放驱动 `idle -> charging -> committed/cancelled -> idle`；重复 release 不会重复提交。
- `ToolMeta.charge_levels` 配置单格、3x1、3x3、9x3、9x9 目标尺寸；目标顺序由 facing 和前方距离稳定生成，SEED 目标按 stack amount 截断。
- `BaseMap.interaction_revision` 用于 preview token 版本校验；地图版本变化时 commit 失败且不发出提交事实。
- `InteractionCursor` 由 Player 场景持有，切换 cabin、farm、field 时继续复用；它使用 top-level 变换，并直接用 preview 返回的 CellState 绘制目标格和实体标记。
- 本阶段不修改地块、不扣体力、不消费物品、不生成掉落；`interaction_committed` 只报告已验证的目标集合。
- 自动化：73 tests passed；Player/Cursor 所有权、Cursor 世界坐标稳定性、三张地图不重复持有 Cursor 的场景契约和主场景启动通过。
