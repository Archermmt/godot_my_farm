# 总体技术架构

## 1. 架构目标

本架构保留参考成品的核心设计：持久玩家和全局系统承载跨地图状态，地图场景只负责当前空间，网格层统一承载环境能力，物品行为通过共享基类和工具类别复用，时间事件驱动作物、光照、玩家和 NPC。

Godot 实现同时修正 Unity 原型中职责过宽、场景树搜索和内存临时存档的问题：静态定义、运行时状态和场景表现严格分离，每份状态有唯一所有者，并提供版本化磁盘存档。

## 2. 分层

```text
输入与表现层
InputMap / HUD / InventoryUI / Cursor / Animation / Audio / Effects
                         |
                         v
场景领域层
Player / FarmSystem / InteractionController / WorldItem / NPC / ScenePort
                         |
                         v
应用服务层
SceneRouter / TimeManager / ItemFactory / SaveManager / AudioManager
                         |
                         v
状态与定义层
GameState / MapState / FarmCellState / InventoryState / DataCatalog / *.tres
```

依赖只能向下。下层通过返回值或 `EventBus` 的事实信号通知上层，不得反向引用 HUD、Player 或具体地图节点。

## 3. 目标目录

```text
res://
├── project.godot
├── assets/
│   ├── art/
│   │   ├── characters/
│   │   ├── crops/
│   │   ├── items/
│   │   ├── tiles/
│   │   ├── ui/
│   │   └── effects/
│   ├── audio/{music,ambient,sfx}/
│   ├── fonts/
│   └── licenses/
├── data/
│   ├── items/
│   ├── crops/
│   ├── drop_tables/
│   ├── npc_schedules/
│   └── catalogs/
├── scenes/
│   ├── app/main.tscn
│   ├── actors/{player,npcs}/
│   ├── maps/{farm,field,cabin}/
│   ├── world/
│   │   ├── farm_system.tscn
│   │   ├── interaction_cursor.tscn
│   │   ├── scene_port.tscn
│   │   ├── pickups/
│   │   └── harvestables/
│   ├── ui/{hud,inventory,tooltips,transition}/
│   └── effects/
├── scripts/
│   ├── autoload/
│   ├── data/
│   ├── state/
│   ├── actors/
│   ├── world/
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
3. `GameState` 创建新游戏状态，或由 `SaveManager` 整体替换为验证后的存档状态。
4. `Main` 实例化持久 Player、HUD，向 SceneRouter 注册 `MapHost`、Player 和 TransitionOverlay。
5. `SceneRouter` 加载状态中的当前地图，地图注册 FarmSystem、ScenePort 和出生点。
6. SceneRouter 恢复地图动态状态并将 Player 放到出生点，完成淡入后解除输入和时间暂停。

## 5. Autoload 职责

### 5.1 EventBus

只存跨模块信号。建议的最小集合：

```gdscript
signal map_change_requested(map_id: StringName, spawn_id: StringName)
signal map_will_change(from_id: StringName, to_id: StringName)
signal map_changed(map_id: StringName)
signal time_advanced(unit: int, before: Dictionary, delta: int)
signal day_advanced(previous_day: int, current_day: int)
signal inventory_changed(owner_id: StringName)
signal selected_item_changed(item_id: StringName, amount: int)
signal player_stats_changed()
signal interaction_committed(action_id: StringName, cells: Array[Vector2i])
signal save_completed(slot: int)
signal load_completed(slot: int)
```

单地图内部的目标光标刷新、作物受击等信号留在本地节点，不进入全局总线。

### 5.2 DataCatalog

- 扫描明确配置的 catalog Resource，不做运行时目录猜测。
- 建立 `StringName -> ItemDefinition/CropDefinition/DropTable/NpcSchedule` 只读索引。
- 启动时检查 ID 唯一、场景/贴图引用存在、种子与作物互相匹配、掉落数量合法。
- 提供 `get_item(id)` 等窄 API，未知 ID 返回 `null` 并记录错误。

### 5.3 GameState

唯一持有：

- `PlayerState`：当前位置的地图/出生信息、生命、体力、上限、金币。
- `InventoryState`：背包、快捷栏、当前选择。
- `Dictionary[StringName, MapState]`：每张地图的地块动态状态、生成物、NPC 状态。
- 新游戏种子、当前存档槽和游戏版本元数据。

GameState 不实例化节点、不加载 PackedScene、不渲染 UI。

### 5.4 TimeManager

- 持有 `CalendarState`，按倍率将现实秒转换为游戏分钟。
- 时间暂停使用 reason token/set，例如 `scene_transition`、`inventory`、`dialogue`，避免多个系统互相覆盖布尔值。
- 按跨越的边界依次发出 minute/hour/day/month/year 事件。
- 午夜规则只由一个流程推进，禁止 Player 和 TimeManager 同时递归触发换日。

### 5.5 SceneRouter

- 维护地图 ID 到 PackedScene 的显式表。
- 地图切换事务：锁输入/时间 -> 发出 will_change -> 当前地图写回 MapState -> 淡出 -> 替换 MapHost 子节点 -> 恢复目标地图 -> 放置玩家 -> changed -> 淡入 -> 解锁。
- 忽略重复切图请求；加载失败时保留原地图并解锁。
- ScenePort 只发出请求，不自行 free 或加载场景。

### 5.6 SaveManager

- 对 GameState 和 TimeManager 的纯字典快照进行版本化保存。
- 负责 I/O、模式校验、迁移、临时文件替换和错误报告。
- 加载成功后调用 GameState 的整体替换 API，再由 SceneRouter 重建当前地图。

### 5.7 AudioManager

- 管理 Music/Ambient/SFX/UI bus 和复用的 AudioStreamPlayer 池。
- 通过稳定音频事件 ID 查定义，不允许领域代码到处硬编码资源路径。
- 地图切换交叉淡化环境音；重复脚步声有最小触发间隔。

## 6. 静态定义模型

### 6.1 ItemDefinition

建议字段：

```text
id: StringName
display_name: String
description: String
item_type: enum
icon: Texture2D
world_scene: PackedScene
held_scene: PackedScene
stack_limit: int
buy_price: int
sell_price: int
use_kind: enum
tool_kind: enum
base_stamina_cost: int
animation_tags: Array[StringName]
```

`use_kind` 决定送往 GridToolAction、HarvestToolAction、SeedAction、FoodAction 或 DropAction。`tool_kind` 用于可采集对象匹配。数据中不保存 Callable。

### 6.2 CropDefinition

```text
id / seed_item_id / produce_item_id
crop_scene
stages: Array[GrowthStageDefinition]
requires_water: bool
harvest_tool: enum
harvest_drop_table_id
```

每个 GrowthStageDefinition 包含开始成长日、表现资源、生命值、状态标签和可选掉落表。树木与普通障碍物可复用 `HarvestableDefinition`，而不是假装都是 Crop。

### 6.3 DropTable

每项包含 item ID、min/max、权重/概率。随机数生成器从世界 seed 与对象稳定 ID 派生；测试可注入固定 seed。

### 6.4 NpcSchedule

每个日程事件包含适用季节/月/星期、开始分钟、持续时间、地图 ID、目标出生点或格子、行为 ID。无匹配日程时使用明确 fallback，不随机消失。

## 7. 运行时状态模型

### 7.1 InventoryState

`ItemStack` 只保存 `item_id` 和 `amount`。背包与快捷栏是固定长度 `Array[ItemStack]`；拖拽交换、合并、拆分和增减都通过 InventoryState API 完成，并在一次事务后发一个变化事件。

不在背包中保存 WorldItem Node、Texture 或 ItemDefinition 副本。

### 7.2 FarmCellState

```text
cell: Vector2i               # 字典 key，序列化时写 x/y
base_flags: int              # 来自地图，通常不进动态存档
dug: bool
watered_on_day: int
occupant_id: String          # 世界实体稳定实例 ID，可为空
crop: CropState?             # crop_id、growth_days、health、随机种子
```

`FarmSystem` 是当前地图中该状态的唯一写入者。TileMapLayer 和 Sprite 只是投影，可随时由状态重建。

### 7.3 MapState

```text
map_id
farm_cells
spawned_entities             # instance_id -> WorldEntityState
npcs                         # npc_id -> NpcState
generator_initialized
```

地图卸载前从当前节点同步；地图加载时先建静态场景，再应用 MapState。手工放置的静态装饰不写入存档。

## 8. 场景领域组件

### 8.1 Player

- `player.gd` 挂在 CharacterBody2D 根节点，集中处理 InputMap、移动碰撞、输入锁、朝向、角色动画状态、相机边界和角色专属交互。
- Visual、Hands、CollisionShape2D、InteractionOrigin 和 Camera2D 是无业务脚本的结构/表现节点，由 `player.gd` 直接引用。
- 不为同一个 Player 按 Input/Motor/Visual/Interaction 的概念名称建立一组只被 Player 使用的转发组件。只有产生跨角色复用或独立生命周期后才提取共享脚本。
- Player 不直接修改 FarmCellState、背包字典或时间；通过领域 API 请求。

### 8.2 FarmSystem

包含共享对齐的 TileMapLayer：

```text
FarmSystem (Node2D)
├── BaseLayer (TileMapLayer)
├── DugLayer (TileMapLayer)
├── WateredLayer (TileMapLayer)
├── CropRoot (Node2D, y_sort_enabled)
├── EntityRoot (Node2D, y_sort_enabled)
└── InteractionCursor (Node2D)
```

职责：坐标转换、查询静态/动态地块、恢复投影、提交翻地/浇水/种植、实体占用和范围排序。它不读取物理鼠标输入。

### 8.3 Targeting 与行动

统一链路：

```text
选中 ItemStack
 -> 构建 InteractionContext(player, pointer, facing, charge, amount)
 -> 对应 UseAction.preview(context)
 -> Array[TargetCandidate]（有序、含有效原因）
 -> Cursor 渲染同一结果
 -> UseAction.commit(context, preview_result)
 -> 校验体力/数量仍足够
 -> 原子修改 FarmSystem/GameState
 -> EventBus 事实事件 + 音画反馈
```

范围顺序必须确定：从起始格开始，按面向方向的行列顺序扩展。预览不得重新随机；提交使用预览中已确定的对象 ID。

### 8.4 WorldItem 层次

Godot 不要求复制 C# 的每层继承，但保留等价职责：

```text
WorldEntity (Node2D)
├── PickupEntity (Area2D)
└── HarvestableEntity (StaticBody2D/Area2D)
    ├── PlantEntity
    │   └── CropEntity
    ├── TreeEntity
    └── ObstacleEntity
```

共享行为优先组合为 Health/Harvest/Drop/Pickup 组件，避免深继承。Tree 的倒向和 stump 转换可以是 TreeEntity 专属策略。

### 8.5 NPC

- `NpcScheduleController` 根据 TimeManager 选择当前/下个日程。
- `NpcNavigator` 使用 Godot 内建 `AStarGrid2D`，从 FarmSystem 的阻挡和道路权重构建网格。
- NPC 跨地图时把状态写入 GameState；只有位于当前地图的 NPC 需要可见实例。
- 日程状态以游戏分钟为基准，加载存档后直接重建到正确位置，不要求重放所有历史路径。

## 9. 关键时序

### 9.1 工具使用

```text
secondary pressed -> InteractionController enters charging
time held -> charge level changes -> preview refreshes
secondary released -> verify selected stack + stamina + targets
-> commit action -> update state -> play animation/audio/effect
-> consume stamina/items -> return idle
```

取消、打开 UI、切场景、失去有效物品时必须进入 cancelled，清除光标且不消费资源。

### 9.2 换日

```text
TimeManager reaches day boundary
-> snapshot previous day
-> advance calendar once
-> day_advanced(previous, current)
-> CropSystem: previous day watered ? growth_days += 1
-> generators/NPC schedules update
-> PlayerState reset health/energy
-> SceneRouter sends player to cabin wake spawn
-> UI and light refresh
```

作物判断 `watered_on_day == previous_day`，无需全图清理 watered bool。

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
  "player": {"map_id": "cabin", "position": {"x": 16, "y": -16}, "health": 100, "energy": 100, "money": 500},
  "inventory": {"selected_hotbar": 0, "hotbar": [], "backpack": []},
  "maps": {
    "farm": {"farm_cells": [], "spawned_entities": [], "npcs": []}
  }
}
```

动态地块建议序列化为数组条目而不是 `"x,y"` 字符串字典，便于模式校验和未来扩展。

## 11. 依赖边界检查

完成任一任务后快速检查：

- UI 是否写了领域状态？若是，改为调用命令。
- Autoload 是否搜索场景树？若是，改为注册/注入。
- Node 是否被写入 JSON？若是，改为稳定 ID 和 DTO。
- TileMapLayer 是否被当作权威状态？若是，改为从 FarmCellState 投影。
- preview 与 commit 是否重复计算目标？若是，复用同一结果。
- 地图切换是否会创建第二个 Player/TimeManager？若是，修正主场景边界。
