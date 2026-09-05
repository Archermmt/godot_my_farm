# 总体技术架构

## 1. 架构目标

本架构保留参考成品的核心设计：持久玩家和全局系统承载跨地图状态，地图场景只负责当前空间，网格层统一承载环境能力，物品行为通过共享基类和工具类别复用，时间事件驱动作物、光照、玩家和 NPC。

Godot 实现同时修正 Unity 原型中职责过宽、场景树搜索和内存临时存档的问题：静态定义、运行时状态和场景表现严格分离，每份状态有唯一所有者，并提供版本化磁盘存档。

## 2. 分层

```text
输入与表现层
InputMap / HUD / ToolbarUI / ItembarUI / InventoryUI / InteractArea / Animation / Audio / Effects
                         |
                         v
场景领域层
Player / BaseMap / MapCell / Item / InteractionController / NPC / ScenePort
                         |
                         v
应用服务层
MapManager / ItemFactory / AudioManager
                         |
                         v
状态与定义层
GameManager / MapState / CellState / ItemState / BackpackState / DataCatalog / *.tres
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
│   └── npc_schedules/
├── scenes/
│   ├── autoload/{data_catalog,game_manager,map_manager,calendar_manager,audio_manager}.tscn
│   ├── app/main.tscn
│   ├── actors/{player,npcs}/
│   ├── maps/{farm,field,beach}/
│   ├── items/{plants,pickups,harvestables}/
│   ├── world/
│   │   ├── interact_area.tscn
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
│   │   ├── plant.gd
│   │   └── harvestable.gd
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
│   ├── MapHost (Node2D)             # 当前 farm/field/beach 实例
│   ├── ActorHost (Node2D)
│   │   └── Player (CharacterBody2D) # 切地图时保持
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
4. `Main` 实例化持久 Player、HUD，向 MapManager 注册 `MapHost`、Player 和 TransitionOverlay。
5. `MapManager` 加载状态中的当前地图；每张地图由自己的根脚本注册 TileMapLayer、ScenePort、出生点和地图 Item 容器。
6. MapManager 恢复地图动态状态并将 Player 放到出生点，完成淡入后解除输入和时间暂停。

## 5. Autoload 职责

### 5.1 EventBus

所有信号声明和跨模块事实事件都集中存放在 `EventBus`。建议的最小集合：

```gdscript
signal map_change_requested(map_id: StringName, spawn_id: StringName)
signal map_changed(map_id: StringName)
signal map_change_failed(map_id: StringName, error: Error)
signal time_advanced(unit: int, before: Dictionary, delta: int)
signal day_advanced(previous_day: int, current_day: int)
signal inventory_changed(owner_id: StringName)
signal selected_item_changed(item_id: StringName, amount: int)
signal cells_tool_used(tool_kind: ToolMeta.ToolKind, cells: Array[Vector2i], energy_spent: int)
signal request_tool_feedback(event_id: StringName, cells: Array[Vector2i])
signal save_completed(slot: int)
signal load_completed(slot: int)
```

目标光标刷新、作物受击等也不得在组件中声明新的信号；需要通知其他模块时扩展 `EventBus`，纯同步逻辑使用直接方法调用。

### 5.2 DataCatalog

- 脚本型 Autoload 从 `data/game_config.tres` 读取 `items: Dictionary[StringName, ItemMeta]` 和 `npc_schedules: Dictionary[StringName, NpcSchedule]`；Config 是唯一配置源，不建立场景副本、运行时目录猜测或同构私有索引。
- Autoload 通过项目注册的全局名直接访问，不作为参数传递，也不在 Player、BaseMap、ScenePort 等节点中建立重复服务字段。State/DTO 不访问或保存 Autoload；需要 Catalog 的初始化校验由 GameManager、BaseMap 等运行时所有者完成，以避免脚本资源循环。Tool 等 RefCounted 领域对象不访问 EventBus 或 AudioManager，只返回 `ToolOutcome`，由 Player 统一发出工具事实和反馈。
- Item、NPC 日程、Audio、Effect 和 Season 定义在 `GameConfig` Inspector 中使用类型化 Dictionary 配置，key 分别是 Item ID、日程 ID、音频事件 ID、特效 ID 和季节 ID。Dictionary 同时是校验后的唯一 ID 查询源；ItemMeta、NpcSchedule 和 SeasonMeta 的内部 ID 必须与 key 一致，Effect 直接使用 PackedScene 映射。
- `GameConfig` 仅承载 Autoload 共享的全局规则与 Catalog。Player 的移动、拾取、相机等局部行为参数保存在 Player 场景；地图和 Generator 的局部参数保存在各自场景。Main 是 Composition Root，只注册 Host、绑定 PlayerState、加载初始地图并控制启动/错误遮罩，不作为第三个业务配置源。
- 启动时检查 ID 唯一、场景/贴图引用存在、种子与作物互相匹配、掉落数量合法。
- 提供 `get_item(id)` 等窄 API，未知 ID 返回 `null` 并记录错误。

### 5.2.1 ItemManager

`ItemManager` 是所有 Item runtime object 的统一创建入口。Map 根据 `ItemState + ItemMeta` 请求它创建并绑定到对应 host，PlayerBackpack 根据 `ItemMeta` 请求它创建并绑定到自身；其他系统不得直接调用 `Tool.new`、`Seed.new` 或 Item 场景的 `instantiate`。Manager 通过 `Dictionary[ItemMeta, StringName]` 保存类型名称，并为同一 parent 下的实例生成不重复的 Node name；ItemState 中已有 `unique_id` 时优先使用该 ID。

### 5.3 GameManager

唯一持有：

- `PlayerState` 和 `BackpackState` 不整体导出到 `GameConfig`。`GameConfig` 的 `Player`、`Backpack` 分类只暴露新游戏所需的配置字段；GameManager 根据这些字段创建独立运行时 State，存档只写入 State 的动态数据。
- `PlayerState`：当前位置的地图/出生信息、生命、体力、上限和金币。
- `BackpackState`：独立保存玩家容器、选择状态和当前唯一手持来源（NONE/TOOLBAR/ITEMBAR）。
- `Dictionary[StringName, MapState]`：每张地图的 cell 动态状态及其格内 Item 状态。
- `Dictionary[StringName, NpcState]`：跨地图 NPC 的全局状态；`map_id/cell` 表示当前位置。
- 新游戏种子、当前存档槽和游戏版本元数据。

GameManager 不实例化节点、不加载 PackedScene、不渲染 UI。
`GameManager` 不提供玩家容器的代理 API；运行时命令由 `FarmPlayer` 通过自身 `PlayerBackpack` 访问绑定的 `BackpackState`，UI 通过已注册 Player 读取和修改容器。
新游戏由 `GameManager` 根据 GameConfig 的 Player/Backpack 参数分别创建 PlayerState 与 BackpackState，再使用 DataCatalog 校验容器 Item；读档也分别恢复两份状态，State 本身不承担 Inspector 配置职责。

### 5.4 GameManager 的时间与存档职责

- GameManager 不持有或修改时间状态；通过 CalendarManager 的只读接口读取 CalendarState、天气和时间倍率。时间运行状态及 reason-based pause set 由 CalendarManager 独立维护。
- 时间暂停使用 reason token/set，例如 `scene_transition`、`inventory`、`dialogue`，避免多个系统互相覆盖布尔值。
- `snapshot()` 保存游戏领域状态，`time_snapshot()` 保存时间状态，`build_snapshot()` 组合完整存档 DTO。
- `replace_build_snapshot()` 负责验证并整体恢复游戏与时间状态；`save_slot()`/`load_slot()` 是统一存档入口。
- 午夜规则只由 CalendarManager 的时间流程推进并发出 `day_advanced`；GameManager 仅响应事件处理玩家、NPC 等游戏业务。

### 5.5 MapManager

- 维护地图 ID 到 PackedScene 的显式表。
- 地图切换事务：锁输入/时间 -> 发出 will_change -> 当前地图写回 MapState -> 淡出 -> 替换 MapHost 子节点 -> 恢复目标地图 -> 放置玩家 -> changed -> 淡入 -> 解锁。
- 忽略重复切图请求；加载失败时保留原地图并解锁。
- ScenePort 只发出请求，不自行 free 或加载场景。

### 5.6 CalendarManager

- 脚本型 Autoload 直接实例化全局唯一 CanvasModulate；Main 和各地图不得再建立第二个 DayCycle/CanvasModulate 天光控制器。
- `SeasonMeta` 是 Inspector 配置条目，每个 `SeasonType` 一份，包含天气权重和天气天光色调；GameConfig 使用 `SeasonType -> SeasonMeta` 字典配置四季。
- CalendarState 创建时接收 SeasonMeta 字典，并按每三个月一个季节计算 `SeasonType` 和对应 Meta；存档只保存可变日期，不保存重复的字符串季节 ID。
- 每日天气由 world seed、日期和 salt 确定性加权选择，同一天恢复时不漂移；`weather_changed` 只发布选择结果。
- CalendarManager 结合当前时间直接采样天光；House 通过室内事件请求中和混合并暂停雨雪表现，HUD 和未来天气表现查询该全局服务，不复制当前天气权威值。

### 5.7 AudioManager

- 管理 Music/Ambient/SFX/UI bus 和复用的 AudioStreamPlayer 池。
- 通过稳定音频事件 ID 查定义，不允许领域代码到处硬编码资源路径。
- 地图切换交叉淡化环境音；重复脚步声有最小触发间隔。

## 6. 静态定义模型

### 6.1 Meta、State 与 Runtime Object 选择模型

三层表示不同维度，不是固定继承模板：

| 层 | 建立条件 | 所有内容 | 不得包含 |
|---|---|---|---|
| Meta | 一份静态类型定义被多个实例共享 | ID、贴图、价格、阶段、规则、类型能力 | 当前生命、坐标、成长进度、Node |
| State | 单个实例的变化需要跨卸载或存档保留 | 当前值、稳定实例 ID、关联 Meta ID | Texture、PackedScene、Node、运行时判断 |
| Runtime Object | 需要行为、生命周期或 Godot 集成 | 业务方法、表现、碰撞、输入、State/Meta 绑定 | 第二份权威持久数据 |

构建时先判断共享性，再判断持久化，最后判断运行行为：

```text
静态定义是否被多个实例共享？
├── 是：建立 Meta，并由稳定 ID/Catalog 管理
└── 否：配置放到唯一 Runtime Object 或 State 模板

单个实例变化是否需要跨卸载/存档？
├── 是：建立 State
└── 否：不建立 State

是否需要生命周期、行为或 Godot API？
├── 是：建立 Runtime Object
└── 否：保持为纯数据 Resource/DTO
```

因此项目同时存在四种合法关系：

```text
ItemMeta -> ItemState -> Item       # 共享定义、持久实例、运行行为
PlayerState -> FarmPlayer           # 唯一类型、持久实例、运行行为
CellState -> MapCell                # 场景重建静态能力，保存动态实例
ItemGenerator                      # 唯一场景组件，配置和行为同属节点
```

`ItemGeneratorCandidate` 虽然是 Resource，但只是 `ItemGenerator` 为 Inspector 数组使用的结构化值，不属于 Meta；`GameConfig` 的 Player/Backpack 参数只是新游戏配置，也不属于 PlayerMeta。Resource 是 Godot 的存储形式，Meta 是数据职责，两者不得等同判断。

### 6.2 ItemMeta

所有 Item Meta 共用 `DataCatalog.items` 配置集合和同一个 ID 命名空间。共同字段：

```text
id: StringName
display_name: String
description: String
item_type: enum
stack_limit: int
buy_price: int
sell_price: int
```

物品行为通过 `ItemMeta` 的具体子类分发：`SeedMeta` 对应种植行为，`ToolMeta` 对应工具行为，不再保存与类层级重复的行为枚举。`ToolMeta` 额外保存 `tool_kind` 和 `base_energy_cost`；`tool_kind` 用于区分共享 `ToolMeta` 的具体工具行为、可采集对象匹配和作用目标类型。数据中不保存 Callable。

### 6.3 HarvestableMeta 与 PlantMeta

```text
id / plant_id (SeedMeta)
stages: Array[HarvestableStage]
requires_water: bool
required_tool: enum
health: int
drops: Array[HarvestableDrop]
```

HarvestableMeta 表示具有生命/耐久、可被工具作用并产生掉落的地图 Item。普通 Harvestable 通过 `HarvestableStage.min_health/texture/visual_offset` 配置健康、受损等阶段；受击修改 HarvestableState.health 后由运行时 Item 显式刷新贴图。PlantMeta 继承 HarvestableMeta并提供成长阶段与浇水需求；农田种植与野外生成只由配置和创建来源区分，不再建立 Crop 类型。SeedMeta 继承 ItemMeta，以 `plant_id` 单向引用对应 PlantMeta；PlantMeta 不反向保存种子 ID。Seed 初始化时通过 Catalog 解析并缓存 PlantMeta，use 阶段不得扫描 Catalog。每个 `PlantStage` 配置成长阈值、贴图、视觉偏移、生命、标签和掉落表，并由 `DataCatalogService.validate_definitions()` 校验。普通 Item、Plant 和 Harvestable 分别使用通用场景，BaseMap 根据 State/Meta 子类选择；特殊节点结构由独立 Scene 和运行时工厂负责，Meta 不保存 Scene 引用。贴图、阶段和数值均在 Meta Inspector 中配置。

Plant、Harvestable、Tool、Seed 和普通 Item 的 Meta 统一内嵌在 `data/game_config.tres` 的 Item Dictionary。开发者在一个 Inspector 入口编辑 stages、成长天数、生命阈值、贴图和 `Array[HarvestableDrop]`；只有需要跨 Config 直接复用或独立交付的 Resource 才拆文件。State 不保存这些静态定义，只记录当前成长天数、当前生命等运行时值。

### 6.4 HarvestableDrop

每项包含 item ID、min/max、权重/概率。随机数生成器从世界 seed 与对象稳定 ID 派生；测试可注入固定 seed。

### 6.5 NpcSchedule

每个日程事件包含适用季节/月/星期、开始分钟、持续时间、地图 ID、目标出生点或格子、行为 ID。无匹配日程时使用明确 fallback，不随机消失。

## 7. 运行时状态模型

### 7.1 Backpack、Toolbar、Itembar 与唯一手持状态

`BackpackState` 使用 `Dictionary[StringName, BackpackSlot]` 保存命名槽位；Toolbar、Itembar 和 MainSpace 使用槽位 ID 数组组织固定栏位，`selected_ids` 保存各栏当前选中槽位。BackpackState 只负责数据访问、布局校验、统计和序列化；Toolbar 只接受工具、Itembar 只接受可选择非工具物品、MainSpace 接受可存储物品，以及跨容器交换、合并、拆分、增减、选择和耗尽压缩，全部由 PlayerBackpack 的运行时 API 执行。

Toolbar 与 Itembar 通过 `selected_ids` 保存当前选中槽位；BackpackState 保存一个 `active_hand_source`。任何 bar 选择操作都会把 active source 切到该 bar，Hands、HUD 和 InteractArea 始终读取同一个 active BackpackSlot，禁止双持。PlayerBackpack 将 slot 的 item_id 解析为可缓存的 Tool/Seed runtime object。

InventoryPanel 使用唯一键盘 focus 和两段式交换：方向 action 移动焦点，第一次 `inventory_swap` 标记源格，第二次在目标格提交 swap/merge；`cancel` 先撤销待交换状态。UI 不实现鼠标点击、drag data 或 drop handler。

不在背包中保存 WorldItem Node、Texture 或 ItemMeta 副本。

### 7.2 MapCell

`BaseMap` 为边界内每个坐标创建 MapCell，并以 `Dictionary[Vector2i, MapCell]` 持有。configure_state 后每个 MapCell 绑定 MapState.cells 中同坐标的 CellState。MapCell 是行走、耕种、浇水、放置和占用的运行时入口；静态 flag 从 authored TileMapLayer 叠加重建，只存在于运行时，不写入 DTO。

MapCell 不继承 Node，不持有 TileMapLayer 或 Item 节点。它只通过绑定的 CellState 读写数据，所有业务判断保留在 MapCell。

### 7.3 CellState 与 ItemState

```text
cell: Vector2i               # 字典 key，序列化时写 x/y
status: int                  # 当前地图配置的格子能力
flags: int (包含 DUG、WATERED)
item_ids: Array[StringName]   # 同格地图 Item 稳定 ID 引用
```

MapState 分别持有 CellState 和 ItemState。两个 State 都是无运行时操作的 DTO；MapCell/Item 绑定 DTO 后提供行为与场景表现。TileMapLayer 和 Sprite 只是投影。

ItemState 是 State 基类，保存 unique_id、meta_id、cell、flags 等共有可变数据；CellState.item_ids 保存同一归属以支持按格查询，BaseMap 保证两者同步。HarvestableState 增加 health；PlantState 继承 HarvestableState，只增加用于防止同日重复成长的 last_growth_day。各 State 仍是纯 DTO，不复制 item_type、plant_id 等 Meta 字段。

`meta_id` 是 State 到 Meta 的唯一连接。DataCatalog 用它从自身只读索引解析共享 ItemMeta；`state_type` 只作为 JSON 恢复 ItemState 子类的序列化判别字段。BaseMap 通过 ItemManager 创建运行时 Item，并根据 Meta 的 `item_type` 选择 host。一个 ItemMeta 可以同时被多个 ItemState 和 BackpackSlot 引用，保存时只写 ID，不复制或序列化 `.tres` Meta。

```text
静态信息              动态实例信息             运行时主体
ItemMeta          -> ItemState          -> Item
HarvestableMeta   -> HarvestableState   -> Harvestable
PlantMeta         -> PlantState         -> Plant
```

### 7.4 MapState

```text
map_id
cells                        # Vector2i -> CellState
items                        # unique_id -> ItemState
generator_initialized
generation_epoch
```

MapState 只保存 cells/items DTO，不持有 NPC，也不实现 Item 事务或场景操作。地图加载时 BaseMap 绑定 CellState，通过 ItemState.meta_id 解析 Meta 后创建运行时 Item。手工放置的静态装饰不写入存档。

MapState 与 BaseMap 不合并：MapState 是可在无场景树时创建和反序列化的纯数据容器，BaseMap 是随地图切换实例化和释放的 Node2D，并拥有当前地图的 MapCell/Item 运行时对象。

NPC 的持久化唯一所有者是 `GameManager.npcs`。NpcState 自带 `map_id/cell`，跨地图时直接更新这两个字段；仅为当前地图实例化 Actor 节点。NPC 不是 Item，不进入 MapState.items 或 BaseMap 的 Item host。

## 8. 场景领域组件

### 8.1 Player

- `player.gd` 挂在 CharacterBody2D 根节点，集中处理 InputMap、移动碰撞、输入锁、朝向、动画选择、相机边界和角色专属交互。
- Visual、Hands、CollisionShape2D、InteractionOrigin 和 Camera2D 是无业务脚本的结构/表现节点；Player 持有唯一的 `InteractArea`，InteractArea 使用 top-level 变换在世界坐标中绘制格子预览，不继承 Player 的连续像素位移。`AnimationPlayer` 直接引用 `Visual/Sprite`，动画帧和时间存放在 `AnimationLibrary` 资源中。
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

`BaseMap` 负责所有地图的身份、坐标转换、边界、MapCell/Item 运行时字典、状态绑定、map_layers、分类 Item host 和 TileMapLayer 对齐。`get_map_size()` 从 BASE layer 的 used rect 获取地图尺寸，`get_tile_size()` 从 BASE layer 的 TileSet 获取 tile 尺寸；每个 map layer 由 flag key 直接索引，key 可使用组合 flags；三张地图都直接挂 BaseMap。

Ground/Base、Road、Resource、Boundary、Floor、Wall 和不可见 flag mask 等静态 layer 的 cells 直接保存在地图 `.tscn` 中。BaseMap 启动时只读取 used cells 并叠加 flag；DugLayer/WateredLayer 在场景中预置为空层，运行时不创建新的 TileMapLayer。

每张可生成地图直接挂载一个 `ItemGenerator` 子节点。该节点通过导出属性保存本地图的 candidates 和 seed_salt，不建立只被这个节点使用的 GenerationMeta，也不重复配置地图尺寸或 regions。`ItemGeneratorCandidate` 只是为了在 Inspector 中编辑结构化数组而存在的 Resource 值。BaseMap 恢复 CellState/ItemState 后，只有 `generator_initialized=false` 时才调用 `generate(map)`；Generator 通过 BaseMap 获取地图尺寸、map_id、generation_epoch 和运行时 MapCell，通过 GameConfig 获取 world seed，不接收或修改 MapState。Generator 根据这些信息和 seed_salt 派生确定 RNG，再通过 `ItemManager.create_from_id()` 和 `BaseMap.add_item()` 提交。BaseMap 在生成成功后更新 MapState。生成结果直接成为普通 MapState 数据，后续地图切换只恢复，不维护第二份 generator 状态。

Item 是运行时 Node2D 基类，同时绑定 ItemState 和 ItemMeta。BaseMap 通过 ItemState.meta_id 查询 DataCatalog，由 ItemManager 创建 Item、Harvestable 或 Plant，再按 `ItemMeta.item_type` 挂入 `item_hosts` 配置的节点。运行时子类保存下转后的强类型引用，专属逻辑不从基类 State 猜测字段。

与某个地图强耦合的网格和地图 Item 生命周期统一放在地图根脚本中，不再抽出 `MapGrid` 或独立 ItemManager。Farm/Field/Cabin 将各自的 Ground/Base/Road/Resource/Boundary 或 Floor/Wall 统一作为 `TileMaps` 的直接子节点，不创建无额外行为的地图脚本，也不得在 TileMaps 内继续添加包装层。

### 8.3 Targeting 与行动

统一链路：

```text
唯一 active BackpackSlot（Toolbar 或 Itembar）
 -> PlayerBackpack 返回复用的 Tool/Seed 运行时对象
 -> InteractArea.begin(PlayerState, map, item/tool)
 -> InteractArea 计算目标、维护蓄力状态并绘制 preview
 -> Array[CellState]（有序预览视图，InteractionFlag 标记 VALID/INVALID/ENTITY）
 -> Player 在 use_held release 时读取 preview cells，并调用具体 Item/Tool.use
 -> 校验体力/数量仍足够
 -> 原子修改 MapCell/GameManager
 -> EventBus 事实事件 + 音画反馈
```

Hoe 和 WateringCan 使用运行时 `Tool` 执行多格事务，并返回 `CellToolOutcome`。Tool 只调用 MapCell 的 `tool_rejection_reason(tool_kind)` 和 `use_tool(tool_kind)`，InteractArea preview 复用同一查询入口。Player 场景持有 `PlayerBackpack` 子节点，按独立的 `BackpackState` 复用 Tool/Seed 对象；选择或使用物品不会反复临时创建对象，只有对应 BackpackSlot 从玩家容器中消失时才释放缓存。InteractArea.begin 直接接收 PlayerState、BackpackState、BaseMap 和该 Tool/Seed 对象，从中读取 cell、facing、active slot、energy 与 charge_levels；地图 revision 在 InteractArea 内部从 BaseMap 保存为事务快照。`use_held` release 不在 InteractArea 内执行，Player 先从 InteractArea 读取 preview cells，再调用 Tool/Seed.use、消费体力或种子并发出反馈。Tool 只接收快照体力值并在 Outcome 中返回 `energy_spent`，由 Player 在成功提交后修改 PlayerState。成功后 BaseMap 增加 interaction revision，并把 DUG/WATERED 从 CellState 重建到地图预置的空 TileMapLayer；表现层不拥有状态，删除或加载地图后都可重建。

`SeedOutcome` 与 `ToolOutcome` 相互独立，各自直接保存 error、effect_cells 和本领域信息，不建立 ItemOutcome。ToolOutcome 保存 tool_kind、skipped_reasons 和 energy_spent；`CellToolOutcome` 增加 projection_error，`ItemToolOutcome` 增加命中、销毁、掉落和树倒方向。四个全局类型各自使用独立脚本，统一放在 `scripts/item/outcome/`，不得用单文件内部类削弱类型定位。播种事务创建的植物实例 ID 仅在 `Seed.use()` 内作为失败回滚的局部数据，不暴露给 Outcome 消费者；需要查询植物时通过 effect cell 和 MapCell 的 item_ids 获取。

工具等级由不同的 ToolMeta item 表示。每个工具 item 可以独立配置贴图、动画、作用范围和伤害档位；BackpackSlot 只保存 item_id 与数量，PlayerBackpack 根据 item_id 复用对应 Tool runtime，不再绑定或持久化 ToolState。

范围顺序必须确定：从起始格开始，按面向方向的行列顺序扩展。预览不得重新随机；提交使用预览中已确定的对象 ID。

### 8.4 Item 层次

Godot 不要求复制 C# 的每层继承，但保留等价职责：

```text
Item (Node2D)
└── Harvestable
    └── Plant
```

普通 Item 是否可拾取由 ItemMeta.can_pickup 决定，不建立 PickupItem 子类。Harvestable 处理 health、受损阶段和掉落，Plant 在其上增加成长阶段；Tree -> Stump 等差异由 Meta 配置，不为每种资源建立运行时子类。

### 8.5 NPC

- GameManager 根据 CalendarState 更新 NpcState 的当前事件、目标地图和目标格；FarmNpc 只读取自身 NpcState 执行移动与动画。
- NPC 场景内使用 Godot 原生 `NavigationAgent2D` 导航，`FarmNpc` 根据当前日程目标设置 `target_position`；地图导航数据不可用时使用目标点直线移动作为运行时兜底。
- NPC 跨地图时把状态写入 GameManager；只有位于当前地图的 NPC 需要可见实例。
- 日程状态以游戏分钟为基准，加载存档后直接重建到正确位置，不要求重放所有历史路径。

## 9. 关键时序

### 9.1 工具使用

```text
use_held pressed -> InteractionController enters charging
time held -> charge level changes -> preview refreshes
use_held released -> verify active slot + energy + targets
-> commit action -> update state -> play animation/audio/effect
-> consume energy/items -> return idle
```

取消、打开 UI、切场景、失去有效物品时必须进入 cancelled，清除光标且不消费资源。

### 9.2 换日

```text
GameManager reaches day boundary
-> snapshot previous day
-> advance calendar once
-> day_advanced(previous, current)
-> PlantSystem: previous day watered ? health += 1
-> generators/NPC schedules update
-> PlayerState reset health/energy
-> MapManager sends player to farm wake spawn inside the House
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
  "player": {"map_id": "farm", "position": {"x": 464, "y": 240}, "health": 100, "energy": 100, "money": 500},
  "backpack": {"active_hand_source": "none", "selected_ids": {"toolbar": "toolbar_0", "itembar": "itembar_0"}, "main_space": [], "toolbar": [], "itembar": []},
  "maps": [
    {"map_id": "farm", "generator_initialized": false, "generation_epoch": 0, "cells": [], "items": []}
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
- Autoload 是否搜索业务场景树？若是，让场景对象注册自身；Autoload 之间则直接使用全局名，不做参数转发。
- Node 是否被写入 JSON？若是，改为稳定 ID 和 DTO。
- 是否出现绕过 MapCell 的平行坐标字典？若是，合并到 `BaseMap.cells` 和 MapCell API。
- TileMapLayer 是否被当作动态权威状态？若是，改为从 MapCell 投影。
- preview 与 commit 是否重复计算目标？若是，复用同一结果。
- 地图切换是否会创建第二个 Player 或重置 GameManager 时间状态？若是，修正主场景边界。
