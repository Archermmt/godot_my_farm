# 可复用的农场游戏架构原则

本文总结本项目已经验证的设计，并抽象成适用于种田、采集、建造、NPC 日程和换日循环类游戏的通用原则。它不是某个功能的实现说明，而是新增系统前应先遵守的架构约束。

## 1. 先确定数据所有权，再决定类的数量

一个对象是否需要 Meta、State 和 Runtime Object，不由目录对称决定，而由三个问题决定：

1. 是否有多个实例共享的静态定义？有才建立 Meta。
2. 是否有单实例可变数据需要跨场景、换日或存档？有才建立 State。
3. 是否需要生命周期、节点、碰撞、动画、输入或 Godot API？有才建立 Runtime Object。

典型关系如下：

```text
共享静态定义 + 持久实例 + 运行行为：Meta -> State -> Runtime Object
持久实例 + 运行行为：             State -> Runtime Object
只有场景行为：                    Runtime Object
只有共享配置：                    Meta / Resource
```

- Meta 是只读规则：名称、图标、价格、成长阶段、掉落、工具伤害和能力标签。
- State 是纯 DTO：当前生命、位置、flags、槽位、时间、目标和稳定 ID。State 不连接信号、不访问 Autoload、不操作 Node。
- Runtime Object 是行为层：读取 State 和 Meta，处理生命周期、表现、输入、碰撞和提交结果。
- 不把 Meta 字段复制到 State，也不把 State 的运行时变化写回 Meta。
- 唯一实例不因为“以后可能复用”而强行增加 Meta；只有真实共享定义出现时再引入。

## 2. 配置、运行时和存档必须分开

`GameConfig` 是新游戏的配置入口，负责全局规则、Catalog、玩家初始值、背包容量、地图生成和天气等静态设置。它不是存档，也不能被运行时当作可变状态使用。

运行时对象在场景中创建后，通过 State 恢复实例数据：

```text
新游戏：GameConfig -> setup/create State -> Runtime Object
读档：   save Dictionary -> from_dict -> from_state -> Runtime Object
```

推荐职责：

- `_ready()`：获取节点、连接信号、建立不依赖存档的静态关系。
- `setup()`：只用于新游戏配置初始化；加载游戏不重复调用。
- `from_state()`：把已存在的 State 应用到运行时对象。
- `to_state()`：在卸载地图、切换场景或保存前，把当前运行值写回 State。
- `to_dict()/from_dict()`：只负责 DTO 的严格序列化和反序列化。

不要在 `_ready()` 中覆盖存档数据，也不要让 `GameManager` 拆解并复制 Player、Backpack、Map 或 Calendar 的内部字段。每个领域对象负责自己的 State 转换，GameManager 只组合顶层快照。

## 3. Autoload 只做全局协调，不做所有业务

全局服务必须有清晰的唯一职责：

- `DataCatalog`：只读 Meta 索引、ID 查询和启动校验。
- `GameManager`：玩家、地图状态、NPC 状态、快照、保存/加载入口。
- `MapManager`：地图实例切换、地图加载/卸载、出生点和过渡动画。
- `CalendarManager`：时间、日期、季节、天气和换日信号。
- `AudioManager`：音频总线、池化和播放。
- `EffectManager`：动作和环境特效实例化。
- `EventBus`：跨模块事实信号，不持有领域状态。

Autoload 不应通过全树搜索寻找 Player、UI 或当前地图，也不应把所有子系统逻辑集中到 GameManager。需要场景对象时由场景注册，或通过明确的信号/方法调用传递。

## 4. 保存和加载是领域对象自己的责任

GameManager 的快照只记录稳定的顶层键，例如：

```text
game_version
current_slot
player
calendar_manager
map_manager
item_manager
map_states
npc_states
```

保存流程：

1. 请求各 Manager/Runtime Object 输出自己的 `to_dict()` 或 `to_state()`。
2. GameManager 组合快照并写入 JSON。
3. 不额外复制 `player.backpack`、`map.cells` 等子对象字段。

加载流程：

1. 解析并校验版本和顶层结构。
2. 由各 Manager 的 `from_dict()` 恢复自己的 State。
3. MapManager 根据当前地图状态创建 BaseMap，再由 BaseMap `from_state()` 恢复 Item 和 Cell。
4. Runtime Object 从对应 State 恢复表现和行为，不重新运行新游戏初始化。

地图切换时，当前地图先 `to_state()` 并释放节点；目标地图再从已有 MapState `from_state()`。不存在状态时才创建新的空状态。生成器必须使用 `generated/generator_initialized` 一类标记避免读档后重复生成。

## 5. 地图状态使用稀疏 Cell

大型地图不应把每个普通格子的完整运行时状态都写入存档。静态信息从 TileMapLayer 重建，只有发生操作的格子才进入 `MapState.cells`：

- 翻地：DUG
- 浇水：WATERED
- 被阻挡：BLOCKED
- 有不可拾取实体：`item_ids`
- 其他确实需要跨日或读档保留的 flags

查询普通格子时，先从静态 `map_layers` 判断基础能力，再检查稀疏 State 是否包含坐标和动态 flag。没有记录不代表错误，而是代表“没有额外状态”。

`MapCell` 是 CellState 的运行时行为对象；`CellState` 只保存坐标、持久化 flags 和必要的 item 引用。不要为 BASE、DUG、WATERED 等状态再维护第二套重复字典或投影节点。

## 6. Cell 与 Item 的绑定原则

只有状态受格子影响、且必须在换日或读档时按格子查询的 Item 才绑定到 `CellState.item_ids`：

- Plant、Seed 产生的 Plant
- Tree、Stone、Grass、Stump 等不可拾取/阻挡实体
- 其他会改变格子占用或阻止耕作的实体

地图上散落、可被拾取的 Wood、Fiber、掉落物不绑定 Cell；它们只存在于 `MapState.items` 和运行时 Item 列表中。

创建和删除 Item 必须由 BaseMap 统一完成：

```text
校验 Cell -> 创建 ItemState -> 写入 MapState.items
-> 必要时写入 CellState.item_ids/BLOCKED
-> ItemManager 创建 Runtime Object -> 挂载到正确 host
```

删除时反向执行并清理引用。阻挡 Item 被采集后，只有当该格不再有其他阻挡 Item 时才移除 BLOCKED。

## 7. 坐标和地图边界只有一个来源

BaseMap 的 BASE TileMapLayer 是唯一坐标转换来源：

```text
world position -> BASE layer local -> Vector2i cell
Vector2i cell -> BASE layer local -> world position
```

不要在 Player、Item、NPC 或 Generator 中重复计算 tile size、origin 或像素倍率。State 保存精确的世界位置时，仍由 BaseMap 负责把它转换成 cell 进行占用和可行走检查。

## 8. 生成、工具和交互采用事务式提交

生成或工具操作都遵循：

```text
校验 -> 计算结果 -> 提交 State/地图变化 -> 创建/删除节点 -> 发出事实信号
```

失败必须回滚，不允许只扣体力、只删节点或只写一半 CellState。工具预览使用无副作用的检查；真正使用时才提交伤害、翻地、浇水、种植、掉落和能量消耗。

工具分层建议：

- `CellTool`：作用于格子，处理耕地、浇水、播种等。
- `ItemTool`：作用于 Harvestable，处理 axe、pickaxe、sickle 等。
- `Tool` 基类只管理蓄力、等级、能量和通用反馈；具体效果由子类实现。

范围显示、碰撞区域、黄色目标点必须与实际作用对象共享同一份 target/tool 集合，避免“看得见但不能用”或“能用但没有标记”。

## 9. NPC 与日程设计

NPC 是 Actor，不是地图 Item。NPC 的 State 由 GameManager 持有，地图切换时由 MapManager 按 `map_id` 加载/卸载。

一个 schedule 只描述一个时间节点：

- `start_minute`
- `map_id`
- `target_position`
- `behavior_id`
- 日期过滤条件
- `wander_zone` 和 `wander_interval`

NPC 的外貌、动画、碰撞和专属节点属于 NPC 自己的独立 `.tscn`，不要放进 schedule。到达 schedule 目标后，在以目标点为中心的 `wander_zone` 内随机选择位置，并按 `wander_interval` 等待后继续移动。

## 10. 新系统设计检查清单

新增一个农场对象或系统前，依次回答：

1. 哪些数据是共享静态定义，哪些是实例变化？
2. 哪个 State 是唯一权威，谁负责写入？
3. Runtime Object 是否真的需要独立生命周期？
4. 新游戏和读档分别调用哪些初始化入口？
5. 地图卸载后哪些数据必须继续存在？
6. Cell 是否真的需要记录，还是可由 TileMap/flags 推导？
7. Item 是否影响 Cell；若可拾取，是否应该解除 Cell 耦合？
8. 哪个 Manager 负责流程，哪个对象负责领域规则？
9. 操作失败如何回滚，成功后发出哪个事实信号？
10. 是否存在重复字段、重复索引、重复场景或重复状态投影？

如果这些问题无法明确回答，应先整理数据所有权和生命周期，再开始写脚本或场景。
