# 总体技术架构

## 1. 架构目标

本架构保留参考成品的核心设计：持久玩家和全局系统承载跨地图状态，地图场景只负责当前空间，网格层统一承载环境能力，物品行为通过共享基类和工具类别复用，时间事件驱动作物、光照、玩家和 NPC。

Godot 实现同时修正 Unity 原型中职责过宽、场景树搜索和内存临时存档的问题：静态定义、运行时状态和场景表现严格分离，每份状态有唯一所有者，并提供版本化磁盘存档。

## 2. 分层

```text
输入与表现层
InputMap / HUD / ToolbarUI / ItembarUI / InventoryUI / Cursor / Animation / Audio / Effects
                         |
                         v
场景领域层
Player / BaseMap / MapCell / Item / InteractionController / NPC / ScenePort
                         |
                         v
应用服务层
SceneManager / ItemFactory / AudioManager
                         |
                         v
状态与定义层
GameManager / MapState / CellState / ItemState / InventoryState / DataCatalog / *.tres
```

依赖只能向下。下层通过返回值或 `EventBus` 的事实信号通知上层，不得反向引用 HUD、Player 或具体地图节点。

## 3. 目标目录

```text
res://
├── project.godot
├── assets/
│   ├── art/
│   │   ├── characters/
│   │   ├── plants/
│   │   ├── items/
│   │   ├── tiles/
│   │   ├── ui/
│   │   └── effects/
│   ├── audio/{music,ambient,sfx}/
│   ├── fonts/
│   └── licenses/
├── data/
│   ├── items/
│   ├── plants/
│   ├── drop_tables/
│   ├── npc_schedules/
│   └── catalogs/
├── scenes/
│   ├── app/main.tscn
│   ├── actors/{player,npcs}/
│   ├── maps/{farm,field,cabin}/
│   ├── items/{plants,pickups,harvestables}/
│   ├── world/
│   │   ├── interaction_cursor.tscn
│   │   ├── scene_port.tscn
│   ├── ui/{hud,inventory,tooltips,transition}/
│   └── effects/
├── scripts/
│   ├── autoload/
│   ├── data/
│   │   └── item/{item_meta,tool_meta,harvestable_meta,plant_meta}.gd
│   ├── state/
│   │   └── item/{item_state,harvestable_state,plant_state}.gd
│   ├── actors/
│   ├── items/
│   │   ├── item.gd
│   │   ├── plant_item.gd
│   │   └── harvestable_item.gd
│   ├── world/
│   │   ├── base_map.gd
│   │   ├── map_cell.gd
│   │   └── scene_port.gd
│   ├── interaction/
│   ├── ui/
│   └── utilities/
├── tests/
│   ├── test_runner.gd
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── screenshots/           # 验收证据，必要时用 .gdignore
└── docs/
```

目录只在对应任务第一次需要时创建，不预先生成空目录树。

## 4. 主场景与生命周期

`scenes/app/main.tscn` 是唯一发行主场景：

```text
Main (Node)
├── World (Node2D)
│   ├── MapHost (Node2D)             # 当前 farm/field/cabin 实例
│   ├── ActorHost (Node2D)
│   │   └── Player (CharacterBody2D) # 切地图时保持
│   └── EffectHost (Node2D)
├── UILayer (CanvasLayer)
│   ├── HUD
│   ├── InventoryPanel
│   ├── ToastLayer
│   └── TransitionOverlay
└── DevHooks (Node)                   # debug feature flag 下才启用
```

启动顺序：

1. Autoload 按 [01_TECHNICAL_RULES.md](./01_TECHNICAL_RULES.md) 的顺序初始化。
2. `DataCatalog` 加载并校验所有定义 ID 和交叉引用；失败则停止进入游戏并输出明确错误。
3. `GameManager` 创建新游戏状态，或由自身存档 API 整体替换为验证后的存档状态。
4. `Main` 实例化持久 Player、HUD，向 SceneManager 注册 `MapHost`、Player 和 TransitionOverlay。
5. `SceneManager` 加载状态中的当前地图；每张地图由自己的根脚本注册 TileMapLayer、ScenePort、出生点和地图 Item 容器。
6. SceneManager 恢复地图动态状态并将 Player 放到出生点，完成淡入后解除输入和时间暂停。

## 5. Autoload 职责

### 5.1 EventBus

所有信号声明和跨模块事实事件都集中存放在 `EventBus`。建议的最小集合：

```gdscript
signal map_change_requested(map_id: StringName, spawn_id: StringName)
signal map_will_change(from_id: StringName, to_id: StringName)
signal map_changed(map_id: StringName)
signal map_change_failed(map_id: StringName, error: Error)
signal time_advanced(unit: int, before: Dictionary, delta: int)
signal day_advanced(previous_day: int, current_day: int)
signal inventory_changed(owner_id: StringName)
signal selected_item_changed(item_id: StringName, amount: int)
signal interaction_committed(action_id: StringName, cells: Array[Vector2i])
signal cells_tool_used(tool_kind: ToolMeta.ToolKind, cells: Array[Vector2i], stamina_spent: int)
signal request_tool_feedback(event_id: StringName, cells: Array[Vector2i])
signal save_completed(slot: int)
signal load_completed(slot: int)
```

目标光标刷新、作物受击等也不得在组件中声明新的信号；需要通知其他模块时扩展 `EventBus`，纯同步逻辑使用直接方法调用。

### 5.2 DataCatalog

- 扫描明确配置的 catalog Resource，不做运行时目录猜测。
- Autoload 依赖在初始化时显式注入并缓存；Player、BaseMap、ScenePort 等场景 Node 只在入口解析一次。Tool 等 RefCounted 领域对象不访问 SceneTree、EventBus 或 AudioManager，只返回 `ToolUseResult`，由 Player 统一发出工具事实和反馈。
- 建立 `StringName -> ItemMeta/PlantMeta/DropTable/NpcSchedule` 只读索引。
- 启动时检查 ID 唯一、场景/贴图引用存在、种子与作物互相匹配、掉落数量合法。
- 提供 `get_item(id)` 等窄 API，未知 ID 返回 `null` 并记录错误。

### 5.3 GameManager

唯一持有：

- `PlayerState`：当前位置的地图/出生信息、生命、体力、上限、金币，以及其归属的 `InventoryState`、`ToolbarState`、`ItembarState`。
- `PlayerState.active_hand_source`：当前唯一手持来源（NONE/TOOLBAR/ITEMBAR）。
- `Dictionary[StringName, MapState]`：每张地图的 cell 动态状态及其格内 Item 状态。
- `Dictionary[StringName, NpcState]`：跨地图 NPC 的全局状态；`map_id/cell` 表示当前位置。
- 新游戏种子、当前存档槽和游戏版本元数据。

GameManager 不实例化节点、不加载 PackedScene、不渲染 UI。
`GameManager` 不提供玩家容器的代理 API；运行时命令由 `FarmPlayer` 调用自身绑定的 `PlayerState`，UI 通过已注册 Player 读取和修改容器。

### 5.4 GameManager 的时间与存档职责

- 持有 `CalendarState`、时间倍率、运行状态和 reason-based pause set。
- 时间暂停使用 reason token/set，例如 `scene_transition`、`inventory`、`dialogue`，避免多个系统互相覆盖布尔值。
- `snapshot()` 保存游戏领域状态，`time_snapshot()` 保存时间状态，`build_snapshot()` 组合完整存档 DTO。
- `replace_build_snapshot()` 负责验证并整体恢复游戏与时间状态；`save_slot()`/`load_slot()` 是统一存档入口。
- 午夜规则只由 GameManager 的时间流程推进，禁止 Player 和其他服务重复递归触发换日。

### 5.5 SceneManager

- 维护地图 ID 到 PackedScene 的显式表。
- 地图切换事务：锁输入/时间 -> 发出 will_change -> 当前地图写回 MapState -> 淡出 -> 替换 MapHost 子节点 -> 恢复目标地图 -> 放置玩家 -> changed -> 淡入 -> 解锁。
- 忽略重复切图请求；加载失败时保留原地图并解锁。
- ScenePort 只发出请求，不自行 free 或加载场景。

### 5.6 AudioManager

- 管理 Music/Ambient/SFX/UI bus 和复用的 AudioStreamPlayer 池。
- 通过稳定音频事件 ID 查定义，不允许领域代码到处硬编码资源路径。
- 地图切换交叉淡化环境音；重复脚步声有最小触发间隔。

## 6. 静态定义模型

### 6.1 ItemMeta

所有 Item Meta 共用 `GameCatalog.items` 集合和同一个 ID 命名空间。共同字段：

```text
id: StringName
display_name: String
description: String
item_type: enum
stack_limit: int
buy_price: int
sell_price: int
use_kind: enum
```

`use_kind` 只用于选择对应的 Item/Tool 运行时行为；不为 grid/harvest/seed/drop 额外建立 Action 类。`ToolMeta` 继承 ItemMeta，并额外保存 `tool_kind` 和 `base_stamina_cost`，供具体 Tool 行为、可采集对象匹配及 Toolbar 类型校验。数据中不保存 Callable。

### 6.2 HarvestableMeta 与 PlantMeta

```text
id / seed_item_id
stages: Array[PlantStageMeta]
requires_water: bool
required_tool: enum
max_health: int
drop_table_id
```

HarvestableMeta 表示具有生命/耐久、可被工具作用并产生掉落的地图 Item。PlantMeta 继承 HarvestableMeta，额外提供成长阶段、浇水需求和可选 seed_item_id；农田种植与野外生成只由配置和创建来源区分，不再建立 Crop 类型。seed_item_id 为空表示不能由玩家播种。每个 `PlantStageMeta` 配置成长阈值、贴图、视觉偏移、生命、标签和掉落表，并由 CatalogValidator 校验；普通单格植物共享 `plant.tscn`，阶段贴图通过 Inspector 在 catalog 中替换。

### 6.3 DropTable

每项包含 item ID、min/max、权重/概率。随机数生成器从世界 seed 与对象稳定 ID 派生；测试可注入固定 seed。

### 6.4 NpcSchedule

每个日程事件包含适用季节/月/星期、开始分钟、持续时间、地图 ID、目标出生点或格子、行为 ID。无匹配日程时使用明确 fallback，不随机消失。

## 7. 运行时状态模型

### 7.1 Inventory、Toolbar、Itembar 与唯一手持状态

`ItemStack` 只保存 `item_id` 和 `amount`。Inventory、Toolbar 和 Itembar 都使用固定长度槽位，但有不同接收规则：Toolbar 只接受工具，Itembar 只接受可选择非工具物品，Inventory 接受可存储物品。跨容器交换、合并、拆分和增减都通过原子状态 API 完成，并在一次事务后发一个变化事件。

Toolbar 与 Itembar 各自保存 selected index；PlayerState 只保存一个 `active_hand_source`。任何 bar 选择操作都会把 active source 切到该 bar，Hands、HUD 和 InteractionController 始终读取同一个 active ItemStack，禁止双持。

InventoryPanel 使用唯一键盘 focus 和两段式交换：方向 action 移动焦点，第一次 `inventory_swap` 标记源格，第二次在目标格提交 swap/merge；`cancel` 先撤销待交换状态。UI 不实现鼠标点击、drag data 或 drop handler。

不在背包中保存 WorldItem Node、Texture 或 ItemMeta 副本。

### 7.2 MapCell

`BaseMap` 为边界内每个坐标创建 MapCell，并以 `Dictionary[Vector2i, MapCell]` 持有。configure_state 后每个 MapCell 绑定 MapState.cells 中同坐标的 CellState。MapCell 是行走、耕种、浇水、放置和占用的运行时入口；静态 flag 从 authored TileMapLayer 叠加重建并写入 DTO。

MapCell 不继承 Node，不持有 TileMapLayer 或 Item 节点。它只通过绑定的 CellState 读写数据，所有业务判断保留在 MapCell。

### 7.3 CellState 与 ItemState

```text
cell: Vector2i               # 字典 key，序列化时写 x/y
status: int                  # 当前地图配置的格子能力
flags: int (包含 DUG、WATERED)
item_ids: Array[StringName]   # 同格地图 Item 稳定 ID 引用
```

MapState 分别持有 CellState 和 ItemState。两个 State 都是无运行时操作的 DTO；MapCell/Item 绑定 DTO 后提供行为与场景表现。TileMapLayer 和 Sprite 只是投影。

ItemState 是 State 基类，只保存 instance_id、meta_id、cell、random_seed、flags 等共有可变数据。HarvestableState 增加 health；PlantState 继承 HarvestableState，再增加 growth_days、planted_on_day。各 State 仍是纯 DTO，不复制 item_type、seed_item_id 等 Meta 字段。

`meta_id` 是 State 到 Meta 的唯一连接。DataCatalog 用它从 `GameCatalog.items` 解析共享只读 ItemMeta；`state_type` 只作为 JSON 恢复 ItemState 子类的序列化判别字段。BaseMap 必须验证 ItemMeta/ItemState 子类匹配，再创建对应运行时 Item 并根据 `ItemMeta.world_type()` 选择 host。一个 ItemMeta 可以同时被多个同类 ItemState 和 ItemStack 引用，保存时只写 ID，不复制或序列化 `.tres` Meta。

```text
静态信息              动态实例信息             运行时主体
ItemMeta          -> ItemState          -> Item
HarvestableMeta   -> HarvestableState   -> HarvestableItem
PlantMeta         -> PlantState         -> PlantItem
```

### 7.4 MapState

```text
map_id
cells                        # Vector2i -> CellState
items                        # instance_id -> ItemState
generator_initialized
```

MapState 只保存 cells/items DTO，不持有 NPC，也不实现 Item 事务或场景操作。地图加载时 BaseMap 绑定 CellState，通过 ItemState.meta_id 解析 Meta 后创建运行时 Item。手工放置的静态装饰不写入存档。

MapState 与 BaseMap 不合并：MapState 是可在无场景树时创建和反序列化的纯数据容器，BaseMap 是随地图切换实例化和释放的 Node2D，并拥有当前地图的 MapCell/Item 运行时对象。

NPC 的持久化唯一所有者是 `GameManager.npcs`。NpcState 自带 `map_id/cell`，跨地图时直接更新这两个字段；仅为当前地图实例化 Actor 节点。NPC 不是 Item，不进入 MapState.items 或 BaseMap.item_hosts。

## 8. 场景领域组件

### 8.1 Player

- `player.gd` 挂在 CharacterBody2D 根节点，集中处理 InputMap、移动碰撞、输入锁、朝向、动画选择、相机边界和角色专属交互。
- Visual、Hands、CollisionShape2D、InteractionOrigin 和 Camera2D 是无业务脚本的结构/表现节点；Player 持有唯一的 `InteractionCursor`，Cursor 使用 top-level 变换在世界坐标中绘制格子预览，不继承 Player 的连续像素位移。`AnimationPlayer` 直接引用 `Visual/Sprite`，动画帧和时间存放在 `AnimationLibrary` 资源中。
- 不为同一个 Player 按 Input/Motor/Visual/Interaction 的概念名称建立一组只被 Player 使用的转发组件。只有产生跨角色复用或独立生命周期后才提取共享脚本。
- Player 不直接修改 CellState.item_ids、MapState.items、背包字典或时间；通过 BaseMap/MapCell/PlayerState/GameManager 领域 API 请求。

### 8.2 BaseMap、MapCell 与地图 Item

地图根场景使用统一的 `TileMaps` 容器集中管理所有 TileMapLayer：

```text
Farm (BaseMap)
├── TileMaps (Node2D, identity transform)
│   ├── BaseLayer (TileMapLayer)
│   ├── DiggableLayer (TileMapLayer, status mask)
│   ├── DropableLayer (TileMapLayer, status mask)
│   ├── RoadStatusLayer (TileMapLayer, status mask)
│   ├── ResourceStatusLayer (TileMapLayer, status mask)
│   └── BoundaryStatusLayer (TileMapLayer, status mask)
├── MapItems (Node2D)
│   ├── Plants (Node2D, y_sort_enabled)
│   └── Items (Node2D, y_sort_enabled)
├── Landmarks
├── StaticCollision
├── SpawnPoints
└── Ports
```

`BaseMap` 负责所有地图的身份、坐标转换、边界、MapCell/Item 运行时字典、状态绑定、cell_flags、item_hosts 和 TileMapLayer 对齐。`get_map_size()` 从 BASE layer 的 used rect 获取地图尺寸，`get_tile_size()` 从 BASE layer 的 TileSet 获取 tile 尺寸；每个 flag layer 只映射一个 CellState.CellFlag，同坐标通过多个 layer 组合 flag；三张地图都直接挂 BaseMap。

Ground/Base、Road、Resource、Boundary、Floor、Wall 和不可见 flag mask 等静态 layer 的 cells 直接保存在地图 `.tscn` 中。BaseMap 启动时只读取 used cells 并叠加 flag，不创建动态状态 TileMapLayer。

Item 是运行时 Node2D 基类，同时绑定 ItemState 和 ItemMeta。BaseMap 通过 ItemState.meta_id 查询 DataCatalog，验证 Meta/State 子类组合后创建 Item、HarvestableItem 或 PlantItem，再按 `ItemMeta.world_type()` 通过 item_hosts 挂入对应 host。运行时子类保存下转后的强类型引用，专属逻辑不从基类 State 猜测字段。

与某个地图强耦合的网格和地图 Item 生命周期统一放在地图根脚本中，不再抽出 `MapGrid` 或独立 ItemManager。Farm/Field/Cabin 将各自的 Ground/Base/Road/Resource/Boundary 或 Floor/Wall 统一作为 `TileMaps` 的直接子节点，不创建无额外行为的地图脚本，也不得在 TileMaps 内继续添加包装层。

### 8.3 Targeting 与行动

统一链路：

```text
唯一 active ItemStack（Toolbar 或 Itembar）
 -> InteractionCursor.begin(PlayerState, map, item/tool)
 -> InteractionCursor 计算目标、维护蓄力状态并绘制 preview
 -> Array[CellState]（有序预览视图，InteractionFlag 标记 VALID/INVALID/ENTITY）
 -> 具体 Item/Tool 提交 preview_result
 -> 校验体力/数量仍足够
 -> 原子修改 MapCell/GameManager
 -> EventBus 事实事件 + 音画反馈
```

Hoe 和 WateringCan 使用运行时 `Tool` 执行多格事务，并返回 `ToolUseResult`。Tool 只调用 MapCell 的 `tool_rejection_reason(tool_kind)` 和 `use_tool(tool_kind)`，Cursor preview 复用同一查询入口。InteractionCursor.begin 直接接收 PlayerState，从中读取 cell、facing、active stack 和 stamina；地图 revision 在 Cursor 内部从 BaseMap 保存为事务快照。Tool 只接收快照体力值并在结果中返回 `stamina_spent`，由 Player 在成功提交后修改 PlayerState。成功后 BaseMap 增加 interaction revision 并让 `CellStateProjection` 从 MapCell 重绘；投影不拥有状态，删除或加载地图后都可从 CellState 重建。

所有可使用物品的结果 DTO 继承 `ItemUseResult`，基类保存通用的 `error` 和 `effect_cells`；`ToolUseResult` 额外保存工具类型、跳过原因、体力和投影错误，`SeedUseResult` 额外保存种子 ID 和新建的植物实例 ID。Player/InteractionCursor 根据具体子类读取专属结果，基类不包含工具或种植业务字段。

范围顺序必须确定：从起始格开始，按面向方向的行列顺序扩展。预览不得重新随机；提交使用预览中已确定的对象 ID。

### 8.4 WorldItem 层次

Godot 不要求复制 C# 的每层继承，但保留等价职责：

```text
Item (Node2D)
├── PickupItem (Area2D)
└── HarvestableItem (StaticBody2D/Area2D)
    ├── PlantItem
    ├── TreeWorldItem
    └── ObstacleItem
```

共享行为优先组合为 Health/Harvest/Drop/Pickup 组件，避免深继承。Tree 的倒向和 stump 转换可以是 TreeWorldItem 专属策略。

### 8.5 NPC

- `NpcScheduleController` 根据 GameManager 的 CalendarState 选择当前/下个日程。
- `NpcNavigator` 使用 Godot 内建 `AStarGrid2D`，从当前 BaseMap 的阻挡和道路权重构建网格。
- NPC 跨地图时把状态写入 GameManager；只有位于当前地图的 NPC 需要可见实例。
- 日程状态以游戏分钟为基准，加载存档后直接重建到正确位置，不要求重放所有历史路径。

## 9. 关键时序

### 9.1 工具使用

```text
use_held pressed -> InteractionController enters charging
time held -> charge level changes -> preview refreshes
use_held released -> verify active stack + stamina + targets
-> commit action -> update state -> play animation/audio/effect
-> consume stamina/items -> return idle
```

取消、打开 UI、切场景、失去有效物品时必须进入 cancelled，清除光标且不消费资源。

### 9.2 换日

```text
GameManager reaches day boundary
-> snapshot previous day
-> advance calendar once
-> day_advanced(previous, current)
-> PlantSystem: previous day watered ? growth_days += 1
-> generators/NPC schedules update
-> PlayerState reset health/energy
-> SceneManager sends player to cabin wake spawn
-> UI and light refresh
```

作物在 day_advanced 时读取 `CellState.CellFlag.WATERED`，完成当日生长结算后清除该 flag。

### 9.3 场景切换

场景切换期间 `scene_transition` 暂停 reason 和 world input lock 同时生效。写回失败不得释放当前地图。地图 ready 后先恢复状态，再放置玩家，避免第一帧碰撞或镜头跳跃。

## 10. 存档模式

示例仅定义结构，实际版本从 1 开始：

```json
{
  "schema_version": 1,
  "game_version": "0.1.0",
  "saved_at": "ISO-8601",
  "time": {"year": 1, "month": 0, "day": 0, "hour": 6, "minute": 0},
  "player": {"map_id": "cabin", "position": {"x": 16, "y": -16}, "health": 100, "energy": 100, "money": 500, "active_hand_source": "none"},
  "inventory": {"slots": []},
  "toolbar": {"selected_index": 0, "slots": []},
  "itembar": {"selected_index": 0, "slots": []},
  "maps": [
    {"map_id": "farm", "generator_initialized": false, "cells": [], "items": []}
  ],
  "npcs": [
    {"npc_id": "npc_villager", "map_id": "farm", "cell": {"x": 12, "y": 8}}
  ]
}
```

动态地块建议序列化为数组条目而不是 `"x,y"` 字符串字典，便于模式校验和未来扩展。

## 11. 依赖边界检查

完成任一任务后快速检查：

- UI 是否写了领域状态？若是，改为调用命令。
- Autoload 是否搜索场景树？若是，改为注册/注入。
- Node 是否被写入 JSON？若是，改为稳定 ID 和 DTO。
- 是否出现绕过 MapCell 的平行坐标字典？若是，合并到 `BaseMap.cells` 和 MapCell API。
- TileMapLayer 是否被当作动态权威状态？若是，改为从 MapCell 投影。
- preview 与 commit 是否重复计算目标？若是，复用同一结果。
- 地图切换是否会创建第二个 Player 或重置 GameManager 时间状态？若是，修正主场景边界。
