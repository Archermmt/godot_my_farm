# T17 完整流程集成与稳定性

状态：completed。自动化基线为 41 tests / 384 assertions；主场景实际启动、编辑器扫描和 `git diff --check` 均通过。

## 目标

在当前重构后的架构上，把“新游戏第一天”作为一条真实可操作的回归路径，清理跨模块生命周期、输入、状态和存档问题，并建立可重复的稳定性检查。T17 不重新引入已删除的 `InteractManager`、`PlayerState`、旧版 `ToolOutcome` 或鼠标交互模型。

## 依赖

- T13、T16 已完成。

## 当前架构基线

- `Main` 是 Composition Root，只负责启动 `DataCatalog`、`CalendarManager`、`GameManager`、`MapManager` 和 `EffectManager`，并注册唯一 Player/Host。
- `GameManager` 持有 Player、`map_states`、`npc_states`、NPC runtime objects 和存档入口；`CalendarManager` 独立持有时间/天气。
- Player 的唯一 active item 来自 `PlayerBackpack`；Toolbar 选择工具，Itembar 选择种子/篮子等非工具物品。
- `Tool` 是所有工具的运行时基类，`CellTool`、`ItemTool`、`Hoe`、`WateringCan`、`Seed`、`Basket` 等子类实现 `_use_impl()`；蓄力由 Tool 统一管理。
- 目标预览由 Tool 自己绘制：CellTool 绘制 target cells，ItemTool 绘制 `ToolArea` 和可采集物标记。
- 工具返回 `ApplyResult`，其中包含 `cells`、`items` 和 `energy_spent`；Player 在成功提交后统一扣除体力。
- 地图动态状态由 `MapState`/`CellState`/`ItemState` 持有，运行时对象由 `BaseMap`、`MapManager` 和 `ItemManager` 恢复。
- 对话由 Interactable 直接调用 Dialogic；Dialogic 的布局通过项目目录下的 Style/override 定制，插件目录保持只读。

## 集成子任务

### T17.1 第一日键盘闭环

- 新游戏启动在 farm/default，初始 Player、背包、地图 Item 和 NPC 数量稳定。
- 仅使用 InputMap action 完成：移动 -> Toolbar 工具 -> 翻地 -> Itembar 种子 -> 播种 -> 水壶浇水 -> 采集 -> 背包整理。
- 工具成功使用后体力按当前 ToolLevel 消耗；统一通过 `ApplyResult.energy_spent` 由 Player 扣除。
- ToolArea 取消后隐藏并禁用碰撞；CellTool 与 ItemTool 场景具有明确生命周期，地图切换时清理运行时对象。

### T17.2 时间与成长闭环

- 两次换日只推进一次；Player/farm wake 由 MapManager 处理。
- `day_advanced`、地图状态和天气状态保持一致。
- NPC schedule、wander timer、导航和跨地图加载不会产生重复 NPC、重复 signal 或 orphan Node。

### T17.3 地图与导航稳定性

- farm、field 往返 20 次，Player、NPC、MapHost 和 Item 数量不增长。
- 非法传送保留原地图并解除输入/时间锁；合法 farm/field 往返恢复 spawn。
- NPC 目标点投影到当前 NavigationRegion2D；不可达目标不会被吸附到不可达位置。

### T17.4 存档回归

- 玩家状态、背包、地图状态和 NPC 状态保存后加载一致；工具状态由现有工具事务测试覆盖。
- 连续 10 次 save、连续 2 次 load、空槽位 load 和损坏 JSON 都返回明确错误，不破坏当前运行状态。
- `snapshot` 只记录当前架构的 `game_version`、`current_slot`、`player`、`map_manager`、`calendar_manager`、`item_manager`、`map_states`、`npc_states`。

### T17.5 背包与输入边界

- Toolbar/Itembar 选择、非法交换和丢弃边界保持原子性。
- UI、对话、地图转场和换日均使用 reason token，任何退出路径都清理锁。
- 100 次无效 action 不修改状态、不重复播放音效、不产生日志刷屏。

### T17.6 测试和代码清理

- 所有当前 `tests/unit` 和 `tests/integration` 脚本都能解析；测试只调用当前公开业务 API。
- 删除或修正只存在于旧版本的测试调用和 `.gd-E` 备份，测试不依赖鼠标、Debug 指令或已删除 Autoload。
- 扫描非 `addons` 的 GDScript，清理旧架构名词和旧测试 fixture；不修改插件源码。

### T17.7 运行与性能证明

- `godot --headless --path . --editor --quit`、主场景启动和测试 runner 均可完成，项目代码无新增 error/warning。
- 20 次地图转场、10 次保存、100 个动态 Item 和 2 次换日压力检查通过。
- 记录测试命令、测试数量、失败路径、遗留风险和视觉验收证据。

## 自动化验收

- 原生 test runner 全部通过，零 skip；测试失败记录测试方法和断言根因。
- 第一日 fixture 连续执行两次，`GameManager.snapshot()` 的领域状态摘要一致。
- 20 次地图往返、100 次无效 action、10 次 save、2 次换日和 100 Item 压力检查通过。
- editor import、headless quit 和实际主场景运行均无项目脚本错误或新增 warning。

## 不做

- 不新增商店、畜牧或教程系统。
- 不恢复 `InteractManager`、`PlayerState.cell`、旧版 `base_energy_cost` 或旧版 `ToolOutcome`。
- 不通过吞 warning、减少验收步骤或修改 `addons/` 来掩盖问题。
