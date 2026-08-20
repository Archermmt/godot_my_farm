# Godot 与 GDScript 技术规则

本文所有“必须/禁止”均为硬性约束。任务卡没有明确授权时不得偏离。

## 1. 工具链

- 项目基线为 Godot **4.7 stable 标准构建**，不是 .NET/Mono 构建；godot-ai 3.0.7 要求 Godot 4.5+，因此不得降回 4.3/4.4。
- T01 必须先记录实际 `godot --version`；`project.godot` 中版本敏感设置以安装版本为准，不凭记忆硬编码。
- 游戏代码全部使用 GDScript 2.0。禁止 `.cs`、`.csproj`、`.sln` 和 C# 插件。
- 运行时不得依赖 godot-ai；它只用于开发、编辑器操作、验证和截图。
- 不增加第三方运行时/测试插件，除非用户明确批准并记录原因；T15 已明确允许使用 Dialogic 等对话插件，并要求通过适配层隔离插件 API。

## 2. 目录和命名

目标目录结构见 [02_ARCHITECTURE.md](./02_ARCHITECTURE.md)。通用命名：

- 文件和目录：`snake_case`。
- GDScript 类：`PascalCase`，跨文件需要类型名时使用 `class_name`。
- 节点：`PascalCase`，同一场景内名称稳定；需要脚本引用的节点设置为唯一名称。
- 变量、方法、信号和 InputMap action：`snake_case`。
- 常量：`UPPER_SNAKE_CASE`。
- Resource ID：稳定的英文 `StringName`，例如 `&"hoe"`、`&"parsnip"`；显示文本与 ID 分离。
- 配置 Dictionary 已经表达数据类别时，key 不重复类别前缀；例如 `npc_schedules` 使用 `fisher`、`villager`、`ranger`，不使用 `schedule_fisher`。
- 信号使用完成事实命名，例如 `item_added`、`day_advanced`，请求型事件以 `request_` 开头。

## 3. GDScript 编码规则

- 缩进使用 Tab，文件为 UTF-8，行尾 LF。
- 新代码尽量静态类型化；函数参数和返回值必须标注类型，领域数组/字典在可行时使用 typed collection。
- 对 `load()`、`instantiate()`、`Dictionary.get()`、JSON、数组/字典索引以及返回 `Variant` 的数学 API，使用显式类型或普通 `=`。不得让 `:=` 推断不稳定的 Variant 类型。
- 资源加载明确标注：`var scene: PackedScene = load(path) as PackedScene`，并处理 `null`。
- 不使用字符串拼接构造 NodePath 来代替明确依赖。
- 不用 `get_node("../../..")`、全树搜索或硬编码绝对场景路径连接核心系统。场景内使用 `@export`/`@onready`/唯一名称，跨场景使用注入、信号或 Autoload API。
- 公有 API、序列化格式和复杂不变量写简短注释；显而易见的逐行注释禁止。
- `_process()`、`_physics_process()` 中不得每帧分配大数组、扫描全场景树或加载资源。
- 物理移动只在 `_physics_process(delta)` 中通过 `CharacterBody2D.move_and_slide()`；普通动画/UI 可在 `_process`。
- 所有速度和计时依赖 `delta`。阻尼使用帧率无关公式，不使用每帧固定乘数。
- 节点连接信号时避免重复连接；生命周期短的对象在退出树时不得留下悬空 Callable。
- 禁止用静态全局可变变量代替明确的数据所有者。
- 角色 leaf scene 默认只在根节点挂一个角色脚本。输入、移动、朝向、角色动画状态和该角色专属交互应优先集中实现，不得仅按概念职责拆成多个只服务同一角色的小组件。
- 角色逻辑只有在至少两个角色类型真实复用、具有独立生命周期，或需要可替换实现时才拆分脚本；拆分前必须在对应任务卡说明复用对象和边界。子节点可以组织碰撞、Sprite、挂点和相机，但不得为了转发根脚本调用而额外挂脚本。
- 可由开发者调节的角色、UI、特效和过场动画必须使用 Godot 标准 `AnimationPlayer`/`AnimationLibrary` 资源管理；脚本只选择动画名称并调用 `play()`、`stop()` 或 `seek()`，不得直接写 `Sprite2D.frame`、维护动画帧计数器或用 `_process` 手写动画时钟。
- 纯程序化的位移、淡入淡出、弹性和数值过渡使用 `Tween`；当动画需要在 Animation 面板中编辑时，不得用 Tween 取代 AnimationPlayer。
- 每张地图根节点下必须有且只有一个名为 `TileMaps` 的 Node2D，所有 TileMapLayer 都必须作为它的直接子节点集中管理；动态 Item、静态装饰、碰撞、出生点和传送口仍与 TileMaps 在地图根下并列。TileMaps 必须保持零位移、零旋转和单位缩放，不得用额外 Grid/LayerGroup 节点继续分层包装。
- 地面道路等可行走 TileMapLayer 必须保持在角色渲染层级之下；TileMaps 内同级 layer 可通过节点顺序叠加，但不得使用高于 `ActorHost` 的 `z_index` 覆盖 Player。资源、边界和前景装饰需要遮挡角色时必须明确标注其前景层级。
- 与某个组件强耦合的功能不需要独立成类；地图统一使用 `BaseMap` 负责坐标、边界、MapCell/Item 运行时索引和地图 Item host 路由。MapCell 是每个格子的运行时行为对象；地图场景不创建无额外行为的根脚本。
- `map_id`、`Dictionary[Vector2i, MapCell]`、`cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 以及 `items_host / harvestables_host / plants_host` 放在 BaseMap。地图尺寸必须通过 `get_map_size()` 从 BASE layer 的 used rect 获取，tile 尺寸必须通过 `get_tile_size()` 从 BASE layer 的 TileSet 获取，不得保存为属性或在地图场景中重复配置。不得增加 farm/field/beach 专属地图类或 crop 专属 host API。
- 房屋等地图内建筑使用可复用 Node2D 场景挂载到地图，室内外切换不得伪装成地图切换。建筑自己的 Floor/Wall/Roof TileMapLayer 只负责表现和建筑碰撞，不加入 BaseMap.cell_flags；Player 只能穿过明确门洞进入，进入时由建筑请求 Player 相机 API 并广播室内状态，建筑不得直接控制 Camera2D 深层节点。
- 地面、道路、墙体、水域、静态资源区等开发者需要编辑的 TileMap cell 必须使用 Godot TileMap 编辑器绘制并序列化在对应 `.tscn` 中。运行脚本不得 `clear()` 后重建静态地图，也不得用启动时代码替代场景内的 `tile_map_data`。
- DUG、WATERED、item_ids 等可存档数据只保存在 CellState/ItemState DTO 中；DUG 和 WATERED 必须使用 CellState.CellFlag，不得增加重复字段。CellState.InteractionFlag 只描述一次 preview 的 VALID/INVALID/ENTITY 表现，不得写入 `to_dict()` 或地图权威 CellState。MapCell/Item 绑定并操作对应 DTO。不得再创建 Dug/Watered TileMapLayer 或其他重复状态投影。

## 4. 场景规则

- 场景按职责拆为可独立运行/实例化的 leaf scene，再由 parent scene 组合。
- 运行逻辑只存在脚本；`.tscn` 保存节点、资源引用和配置，不保存业务数据快照。
- 使用 `PackedScene` 实例组合 Player、WorldItem、Plant、NPC 和 UI；不要把实例展开复制到父场景。
- godot-ai 可用时优先用其 scene/node/resource 工具进行语义化场景修改，避免手写 `.tscn` 的 sub-resource ID、UID 和连接段。
- 通过工具生成/修改场景后必须 `scene_save`，然后重新读取 hierarchy 验证节点没有静默丢失。
- 不直接编辑 `.godot/`、`.uid`、导入缓存或编辑器用户设置。
- 主场景始终可运行；调试专用场景放入 `tests/fixtures/` 或 `dev/`，不得改成发行主场景。

## 5. Node 与 Resource 的边界

- Node 负责生命周期、输入、场景表现和 Godot 对象交互。
- Resource 负责静态 Meta 数据，例如物品、作物阶段、掉落表、NPC 日程和音频配置。
- Resource 或 RefCounted 状态对象负责单个实例的可变数据，例如物品堆、地块状态和存档 DTO；需要作为 Inspector 模板编辑时使用 Resource。
- `ItemMeta` 及其 `ToolMeta`、`HarvestableMeta`、`PlantMeta` 子类统一放在 `scripts/data/item/`；`DataCatalog.items: Dictionary[StringName, ItemMeta]` 是唯一 Item Meta 配置集合和 ID 命名空间，字典 key 必须与 `ItemMeta.id` 一致。PlantMeta 继承 HarvestableMeta：所有 Plant 都可收获，但石头等 Harvestable 不属于 Plant。
- `SeedMeta` 继承 ItemMeta，并通过唯一的 `plant_id` 单向引用 PlantMeta；PlantMeta 不保存反向 seed ID。Seed 构造时从 DataCatalog 解析并缓存 PlantMeta，执行 use 时不得遍历 Catalog 查找关联。
- 物品使用、工具作用、播种、采集和放置逻辑由对应 Item/Tool 运行时类型实现；不得为这些类别再建立只做转发或 action_id 标记的 UseAction/GridToolAction/SeedAction 等空策略层。
- Meta 只用于一份类型定义被多个 State/运行时实例共享的场景，例如同种 Item 的贴图、价格、成长阶段和掉落规则。唯一 Runtime Object 不得仅因含有静态初始值就增加 Meta；不得把运行时可变数据写回 Meta，也不得把 Meta 字段复制进存档 State。
- Player 使用 `PlayerState -> FarmPlayer`，不建立 PlayerMeta。`GameConfig.player_state_template` 是 Inspector 可编辑的新游戏 State 模板，直接包含出生信息、初始属性以及 BackpackState 的容量、命名槽位和 BackpackSlot；新游戏从模板深复制，读档完全从快照恢复，不依赖当前模板。
- Cell 使用 `CellState -> MapCell`，不建立 CellMeta。地图 TileMapLayer 可重建的 BASE/DIGGABLE 等静态 flag 直接保存在当前 MapCell.static_flags；只有 DUG/WATERED、item_ids 等动态数据进入 CellState 和存档。
- State 只保存每个实例的可变数据。`ItemState.meta_id` 是 ItemState 到 `ItemMeta.id` 的唯一连接；不得再保存静态类别或其他可从 Meta 获得的字段。序列化中的 `state_type` 只用于恢复具体 State 子类，不得代替 meta_id 或承载业务类别判断。
- Resource 之间使用稳定 ID 关联，避免整个运行时状态通过循环 Resource 引用序列化。
- 运行时工厂负责选择并实例化 Item Scene；业务系统不得散落字符串路径加载，Meta 不得保存 `PackedScene` 或其他运行时节点结构信息。
- 普通 Item、Plant 和 Harvestable 分别使用一个通用运行时场景，BaseMap 根据 State/Meta 子类选择。只有碰撞体、节点结构或运行时组件确实不同的 Item 才建立专用 Scene，并在运行时工厂中显式注册；不得为仅贴图或数值不同的 Item 建立重复场景。
- Item 的图标、数值和阶段配置属于 Meta（例如 `icon_texture`、成长周期、阶段贴图、最大生命）；通用场景只负责公共节点结构、碰撞和视觉组件。一个 Meta 对应一种明确的运行时根节点类型，Plant、Harvestable 和普通 Item 不得共用同一个 Meta 充当不同运行时类型。
- Item Meta 默认直接内嵌在 `data/game_config.tres` 的 `items` Dictionary 中，包括 Plant、Harvestable、Tool、Seed 和普通 Item；仅当某个 Resource 需要被多个配置直接引用或具有独立文件生命周期时才拆成单独 `.tres`。PlantStage、HarvestableStage 和掉落项等父对象私有数据继续内嵌，不为每个 item 建立特例资源文件。State 只保存运行时变化值，场景中不得增加 `State` 节点承载 Meta 配置。

### 5.1 Meta、State 与 Runtime Object 构建规范

新增领域对象前必须分别判断“静态定义是否共享”“实例变化是否需要持久化”“是否存在运行时行为”，不得机械地为每个类型同时建立 Meta、State 和 Runtime Object。

1. 多个同类实例共享一份不可变类型定义时才建立 Meta。Meta 使用 Resource，通过稳定 ID 被 Catalog 索引；贴图、价格、阶段、规则和类型能力放在 Meta，不保存某个实例的当前值。
2. 数据会随单个实例变化，并且需要跨场景卸载、快照或存档继续存在时才建立 State。State 是纯 DTO，只保存权威可变数据和关联 ID；除校验、复制及序列化外不承担业务判断、场景操作或信号连接。
3. 对象需要生命周期、行为、场景表现、输入、碰撞或 Godot API 交互时建立 Runtime Object。业务判断和运行时操作放在 Runtime Object；它读取绑定的 State，并在需要共享类型定义时通过 ID 解析 Meta。
4. 某个配置只属于场景中的唯一 Runtime Object，且不被多个实例共享时，不建立 Meta。配置直接使用该 Node 的导出属性保存在场景中，例如每张地图唯一的 `ItemsGenerator`。
5. 为了在 Inspector 中编辑嵌套数组而使用的 Resource 只是结构化值对象，不自动成为 Meta。例如 `ItemsGeneratorCandidate` 的所有权属于 `ItemsGenerator.candidates`，没有 Catalog ID、独立 State 或独立运行时生命周期。
6. 新游戏默认值可以使用 State Resource 模板，但模板不等于 Meta。模板只用于深复制出新的 State；读档不得依赖当前模板内容。

允许的组合只有实际职责需要的层：

```text
共享定义 + 持久实例 + 运行行为：Meta -> State -> Runtime Object
持久实例 + 运行行为：         State -> Runtime Object
仅运行行为和场景配置：       Runtime Object
仅共享静态数据：             Meta / 配置 Resource
```

当前项目示例：

- `ItemMeta -> ItemState -> Item`：同一种 Item 定义被许多世界实例共享，实例状态需要保存，Item 节点负责运行行为。
- `PlayerState -> FarmPlayer`：只有一个玩家实例，不需要 PlayerMeta；默认值来自 State 模板。
- `CellState -> MapCell`：Cell 静态能力可从 TileMapLayer 重建，不需要 CellMeta；动态地块信息需要保存。
- `ItemsGenerator`：每张地图只有一个场景组件，配置直接保存在节点上；只有初始化标记和 epoch 进入 MapState。

禁止为了目录对称、命名统一或未来可能复用而预先增加空 Meta/State 层。只有出现真实的共享定义或持久化需求后才能引入对应层，并同时更新本文档中的所有权说明。

## 6. Autoload 规则

只允许以下全局服务，增加新 Autoload 必须先更新架构文档：

- 包含业务判断、状态变更或流程协调的 Autoload 必须使用 manager 命名：文件以 `_manager.gd` 结尾，Autoload 单例名以 `Manager` 结尾，脚本类型以 `ManagerService` 结尾。
- 只有纯全局 holder、只读定义索引或事件总线可以使用职责名，不强制 manager 后缀；这类 Autoload 不得逐步混入业务操作。职责扩展到业务逻辑时必须同步改名。

1. `EventBus`：只声明跨模块信号，不持有领域状态。
2. `DataCatalog`：只读定义索引和启动校验。
3. `GameManager`：全局游戏状态、时间控制、整体快照和存档入口的唯一管理者；背包容器归 `PlayerState` 所有。
4. `MapManager`：地图切换、出生点和淡入淡出协调。
5. `CalendarManager`：按 SeasonMeta 定义的月份归属、季节和日期选择天气，并作为全局 CanvasModulate 唯一控制天光颜色。
6. `AudioManager`：音频总线和池化播放。
7. `EffectManager`：实例化并管理动作、环境和天气特效；特效场景由稳定 ID 配置，具体 host 在播放时解析。

Autoload 不得通过全树搜索抓取当前 Player/Farm/UI。需要场景对象时由场景在 `_ready` 注册并在 `_exit_tree` 注销，或通过信号传递一次性命令。
- Autoload 是全局唯一节点。Autoload 之间以及场景 Node 使用全局名直接访问，不得把 `EventBus`、`DataCatalog`、`GameManager`、`MapManager`、`CalendarManager` 或 `AudioManager` 作为构造函数/方法参数逐层传递，也不得建立 `_catalog_service` 等重复缓存字段。
- State/DTO 不访问或持有 Autoload。需要 Catalog 参与的初始化、校验和创建逻辑由 GameManager、BaseMap 等运行时所有者完成，避免 State 脚本与 Autoload 形成资源加载循环。
- RefCounted 领域行为对象原则上不访问 EventBus、MapManager 或 AudioManager，应返回结构化结果，由 Player、BaseMap 等运行时 Node 提交状态并发出事实信号和反馈。只读 Catalog 关联可以在对象创建时通过全局 Catalog 解析。
- Autoload 默认直接注册 `.gd` 脚本。没有固定子节点结构的 Manager 不得为 Inspector 配置增加空壳 `.tscn`；只有确实需要持久节点层级、预建子节点或编辑器空间布局时才使用场景型 Autoload。
- `data/game_config.tres` 是所有 Autoload 初始配置的唯一 Inspector 入口；Manager 直接持有同一 `GameConfig`，不得把配置字段复制到节点导出属性。存档或玩家设置会改变的值必须使用独立运行时字段，例如 `initial_time_scale` 只初始化 `GameManager.time_scale`，由 `CalendarManager` 推进时间，读档只覆盖运行时值。
- `GameConfig` 中“稳定 ID -> 控制对象/Resource”集合优先使用类型化 `Dictionary`；key 必须直接说明该项控制的对象。只有顺序本身有业务意义，或元素没有稳定 key 时才使用 `Array`。
- Config Dictionary 是配置和 ID 查询的唯一数据源，不得再建立与它完全同构的 `_definitions`、`_items` 等私有副本。允许保留不同查询维度的派生索引、对象池、冷却记录和其他运行时状态，例如 CalendarManager 的 month -> SeasonMeta 索引。
- Dictionary key 已能完整表达身份，且 Resource 不会脱离所属 Manager 单独流转时，Resource 不重复保存 ID，例如 AudioDefinition 和 EffectDefinition。Resource 离开 Manager 后仍需自描述时保留内部 ID，例如 ItemMeta、NpcSchedule 和 SeasonMeta，并在启动时强制校验内部 ID 与 Dictionary key 一致。
- DataCatalog、AudioManager、EffectManager、CalendarManager、GameManager 和 MapManager 均读取同一个 `GameConfig`；不再为各 Manager 增加同构配置 Resource 或场景副本。SeasonMeta 中的月份归属属于配置，CalendarState 只保存同步后的派生 `season_id`。

## 7. 事件与数据所有权

- 每份可变数据只有一个权威写入者。例如金币与背包由 `PlayerState` 写，`GameManager` 只持有整体玩家状态，UI 只订阅；cell 行为直接通过 MapCell 修改，地图 Item 节点通过 BaseMap 的分类 host 挂载。
- Signal 用于通知和跨模块请求，不作为无类型的数据总线。参数必须有稳定类型和清楚语义。
- 所有信号声明必须集中在 `EventBus`；领域服务、地图根节点和场景组件不得自行声明信号变量。模块内部需要通知时也通过 `EventBus` 的稳定事实信号，避免信号所有权分散。
- 同一模块内部优先直接方法调用；不要把所有调用都绕到 `EventBus`。
- 需要原子性的行为采用“校验 -> 计算变化 -> 提交 -> 发出事实事件”。体力、种子、地块和产出不能只提交一半。
- UI 不直接修改领域字典；UI 调用公开命令并根据信号刷新。

## 8. 网格与坐标

- 全部农事状态以 `Vector2i` 地图坐标为主键，禁止用像素位置或字符串作为运行时主键。
- 坐标转换只由 BaseMap 通过 cell_flags 中唯一的 BASE TileMapLayer 提供：世界坐标 -> layer local -> map，以及 map -> local -> world。
- 所有农事层共享同一 tile size、transform 和 origin；T04 必须加入对齐检查。

### 8.1 Map、Cell、Item 核心关系

运行时对象关系：

```text
BaseMap
├── cells: Dictionary[Vector2i, MapCell]
│   └── MapCell -> 绑定同坐标 CellState
├── items: Dictionary[StringName, Item]
│   ├── ItemMeta -> ItemState -> Item
│   ├── HarvestableMeta -> HarvestableState -> Harvestable
│   └── PlantMeta -> PlantState -> Plant
├── items_host: Node2D
├── harvestables_host: Node2D
└── plants_host: Node2D
    └── BaseMap 按 ItemMeta 的真实子类选择对应 host
```

持久化状态关系：

```text
GameManager
├── player: PlayerState
│   └── backpack_state: BackpackState
├── maps: Dictionary[StringName, MapState]
│   └── MapState
│       ├── cells: Dictionary[Vector2i, CellState]
│       └── items: Dictionary[StringName, ItemState]
└── npcs: Dictionary[StringName, NpcState]
```

`PlayerState` 只持有一个 `BackpackState`；所有玩家容器快照统一写入 `snapshot["player"]["backpack"]`，由 BackpackState 负责容器状态事务与序列化。

`BackpackState` 是玩家背包唯一的统一数据模型：`slots` 使用 `Dictionary[StringName, BackpackSlot]` 保存命名槽位，`toolbar` 和 `itembar` 只保存槽位 ID 数组，容量与选择状态也由它统一记录。`BackpackSlot` 只保存 `slot_id`、`item_id`、`amount` 等数据，不持有运行时 Item/Node；PlayerBackpack 负责把槽位解析为可复用的 Tool/Seed runtime object，并提供 add/remove/switch 业务入口。

Itembar 和 inventory 中的 stack 耗尽后必须保持稳定顺序向前压缩，toolbar 不压缩。Tool 只能进入 toolbar 或 inventory，不得进入 itembar；拾取物优先填充 itembar，放不下的部分再进入 inventory。手动交换槽位只执行用户指定的交换，不触发自动压缩。

每个 Catalog ItemMeta 必须配置非空 `icon_texture`。Inventory/Toolbar/Itembar Slot 和状态面板手持物直接显示该 Texture2D，只允许额外显示数量角标，不得用名称或字母缩写代替物品图标；空 Slot/空手必须清除旧 Texture。

- `BaseMap` 是当前已加载地图的运行时根和协调者，唯一管理 MapCell/Item 运行时对象、坐标转换、静态 flag 重建、地图 Item 事务和 host 路由。
- 动态 DUG/WATERED cell 的表现必须使用贴图图块：每张地图在 TileMaps 下预置空的 DugLayer/WateredLayer，BaseMap 根据 CellState flags 向对应层设置或清除 atlas tile；两层必须与 BaseLayer 使用相同地面 `z_index`，不得遮挡 Player 或 Item。禁止使用运行时投影节点、draw_rect 或颜色矩形代替地块状态贴图。
- `MapState` 是地图卸载后仍存在的纯数据容器，只保存 CellState/ItemState DTO 和生成标记，不实现耕种、占用、Item 增删移动或场景操作。
- MapState 不得合并进 BaseMap。GameManager 必须能在地图场景未实例化时创建、保存和恢复所有 MapState；地图切换释放 BaseMap 时不得影响未加载地图的 cells/items。
- `MapCell.static_flags` 保存 BASE、DIGGABLE、DROPABLE、ROAD、BLOCKED、RESOURCE、INTERIOR 等由地图层重建的能力；`CellState` 是无业务方法的 DTO，只保存 cell、DUG/WATERED 动态 flags 与 item_ids。MapCell 绑定同坐标 CellState 并组合两类 flag 完成运行时判断，static_flags 不写入存档。
- `ItemState` 是 State 基类，保存 instance_id、meta_id、cell、random_seed、flags 等所有地图 Item 共有的可变字段。CellState.item_ids 同时保存格子归属，用于一致性校验和按格查询；BaseMap 移动 Item 时必须同步更新两者。
- `Item` 是运行时 Node2D 基类，并同时绑定 ItemState 和通过 meta_id 解析出的 ItemMeta。Harvestable 下转为 HarvestableState/HarvestableMeta，Plant 继承 Harvestable 并进一步下转为 PlantState/PlantMeta；专属逻辑只访问对应的强类型组合。instance_id 在整张 MapState 内唯一，ItemState.cell 与 CellState.item_ids 必须保持一致。
- Item 子类不得为同一对象重复缓存 `harvestable_state/harvestable_meta/plant_state/plant_meta/tool_meta` 等字段；权威引用只有 Item.state 和 Item.meta，子类通过无状态的强类型访问方法下转。Seed.plant_meta 是由 SeedMeta.plant_id 解析出的另一个关联对象，不属于重复引用，可以在初始化时缓存。
- `Item` 不得持有 BaseMap 或直接修改地图。可拾取 Item 只负责向玩家移动并标记已拾取；BaseMap 在明确的读取/结算入口中统一负责 cell 同步、MapState/CellState 更新和删除已拾取节点。
- 拾取范围归 Player 所有：圆形查询半径、命中距离和吸附速度直接定义为 Player 的 Inspector 属性，不建立 PickupRange、Area2D 或物理 monitoring 子节点。Player 根据 `pickup_radius` 调用 `BaseMap.pickup_items_in_radius()`；Map 只返回范围内的普通可拾取 Item，不调用 Player 或 Item 的拾取行为。
- 地图掉落使用普通 `ItemState -> Item`，是否可拾取只由 `ItemMeta.can_pickup` 定义，不建立 Pickup 专用运行时类或 State。每个地图掉落实例只代表一个物品，稳定 instance ID 与所在 cell 仍写入 ItemState/CellState 以保证 MapState 完整恢复；可拾取 Item 不算作播种或放置时的格子占用者。吸附移动、距离加速、Itembar 优先入包和命中判断全部由 Player 执行；成功入包后 Player 调用 `BaseMap.remove_item()`，由 Map 统一删除运行时节点、MapState.items 与 CellState.item_ids 引用。
- 采集规则由 ToolMeta.damage、HarvestableMeta.required_tool/max_health/drops/depleted_replacement_id、HarvestableStage 和 PlantStage.drops 配置；掉落项统一使用 `HarvestableDrop`。Tool 只产出 ToolOutcome，Player 根据结果扣体力并发反馈。HarvestableStage 以 min_health 选择受损阶段贴图，apply_tool 修改 health 后由 Harvestable 显式刷新 StageVisual，不在纯 DTO State 上绑定信号。普通受击使用短白闪；对象耗尽后先变白，再通过本地 ShaderMaterial 逐渐分解，动画完成后释放。对象耗尽和替换由 BaseMap 以单次事务处理，树通过 depleted_replacement_id 转为树桩，重复提交旧 instance ID 不得再次掉落。
- Item State 代码统一放在 `scripts/state/item/`，BackpackState/BackpackSlot 放在 `scripts/state/inventory/`，运行时 Item 代码放在与 `scripts/world/` 同级的 `scripts/items/`，不得放回 `scripts/world/entity/`。BackpackSlot 使用 item_id 引用 Meta，不把地图 Node 放进背包。
- `MapState.items` 和 `MapState.cells` 是存档数据所有者；`BaseMap.items` 和 `BaseMap.cells` 是当前地图运行时对象所有者。所有同步和关系校验由 BaseMap 负责。
- `NpcState` 的唯一所有者是 `GameManager.npcs`，其 `map_id/cell` 表示 NPC 当前所在地图和格子。NPC 是 Actor，不是 Item，不得写入 MapState.items 或通过 Item host 路由。
- 创建地图 Item 的事务顺序固定为：BaseMap 校验目标 MapCell/status -> 用 meta_id 从 DataCatalog 解析 ItemMeta -> 校验 Meta/State 子类匹配 -> 写入 ItemState 和 CellState.item_ids -> 创建对应 Item 子类 -> 同时绑定强类型 State/Meta -> 按 Meta 真实子类挂载 host。类型不匹配、解析、创建或挂载失败时必须回滚 DTO。
- 移动地图 Item 必须通过 BaseMap.move_item() 原子地修改源/目标 CellState.item_ids、ItemState.cell 和 Item 节点位置；失败时不得留下双重归属。
- 删除地图 Item 必须通过 BaseMap.remove_item() 同时删除 CellState 引用、MapState.items DTO 和运行时 Item，再结算掉落/事件。
- 地图卸载时释放 BaseMap、MapCell 和地图 Item；MapState、CellState、ItemState、NpcState 继续由 GameManager 持有。地图恢复时由 BaseMap 重新创建并绑定运行时对象。

### 8.2 环境生成与恢复

- farm/field 场景各自挂载唯一的 `ItemsGenerator` 子节点，候选、数量、安全半径和 seed salt 直接使用节点导出属性配置；不得为单张地图的唯一 Generator 再建立 Meta 层，也不得在 BaseMap 或 GameManager 中硬编码对象 ID、坐标或数量。
- Generator 的 `Dictionary[StringName, ItemsGeneratorCandidate]` 用 Resource 表达 Inspector 中的结构化候选值，Dictionary key 是 Catalog Item ID，Candidate 不是 Meta 或独立运行时对象。候选可以引用 `HarvestableMeta`，或 `can_pickup=true` 的普通 ItemMeta；前者创建对应 Harvestable/Plant State，后者创建 ItemState。固定数量使用 min/max，密度模式使用 density；配置错误必须在写入 MapState 前失败。
- RNG seed 只由 world seed、map_id、generation_epoch 和 seed_salt 派生。候选格先按坐标稳定排序再随机抽取，确保同一初始状态跨加载得到相同布局。
- BaseMap 调用 Generator 时必须传入 `get_map_size()`；每个 Candidate 自己用 `Array[CellState.CellFlag] required_flags` 描述生成条件，Generator 不保存全局 required/forbidden flags。生成格必须位于地图边界内、具备该 Candidate 的全部 required_flags、没有占用，并避开 SpawnPoints/Ports 周围 safe_radius。每个候选都有有限尝试上限，并将 requested/spawned/attempts/skipped/error 写入 summary。
- 首次生成只允许在 `MapState.generator_initialized == false` 时发生。生成对象通过 `BaseMap.add_item_state()` 同步 MapState、CellState、运行时 Item 和分类 host，不得绕过地图事务直接挂节点。
- `ItemsGenerator.generate()` 不得接收、读取或修改 MapState。BaseMap 在调用前读取 `generator_initialized`，只把生成所需的 `generation_epoch` 数值传入，并在成功返回后更新 MapState；Generator 从 MapCell 查询当前占用。
- 生成实例 ID 使用 map、epoch、meta_id 和稳定序号；`ItemState.flags` 保存 `generated` 标签。手工对象和生成对象使用同一 ItemState/Item 体系，不建立专用生成对象层次。
- 地图往返只从 MapState 恢复，不重新运行初始生成。启用每日再生时递增 generation_epoch 并只追加本代合法对象，不清空或重建已有对象。

### 8.3 Cell Status 与坐标规则

- `BaseMap` 在 ready 时为地图边界内每个坐标创建一个 MapCell，并在 configure_state 时绑定 `MapState.cells` 中同坐标的 CellState。调用方通过 `get_cell()` 取得运行时对象。
- `CellState.CellFlag` 是统一的位标记枚举：BASE、DIGGABLE、DROPABLE、ROAD、BLOCKED、RESOURCE、INTERIOR、GENERATE 只用于 MapCell.static_flags，DUG、WATERED 只用于 CellState.flags。BASE 表示地图唯一的基础/坐标层，其 used cells 默认可行走；GENERATE 表示允许场景生成器放置候选物的区域。
- BaseMap 的 `cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 是静态 cell flag 的唯一配置入口。每个 entry 表示该 TileMapLayer 的每个 used cell 都获得对应 flag；同一坐标出现在多个 layer 时按位 OR 叠加到 MapCell.static_flags。
- farm/field 必须在 `TileMaps/GenerateLayer` 中显式绘制 GENERATE 区域。该层隐藏显示，不得覆盖 ROAD、BLOCKED 或房屋、水塘等物理阻挡；生成范围的调整通过编辑该层完成，不得在 Generator 中重复维护 forbidden 区域。
- flag cell 集合必须直接绘制并序列化在对应 TileMapLayer 中；禁止用 Rect2i、Polygon、节点名称推断或启动时代码生成固定形状。只用于配置的 flag mask layer 可以不可见，但必须拥有 tile_map_data，并与坐标层保持 tile size、transform 和 origin 对齐。
- 每张地图必须且只能配置一个 BASE layer；坐标转换、地图边界参考和基础可行走查询都由该 dictionary entry 决定。BLOCKED 是行为否决状态，可以与 BASE/DROPABLE 等同时存在；`is_walkable()`、`is_dropable()` 等查询必须显式排除 BLOCKED。
- `MapState.cells: Dictionary[Vector2i, CellState]` 和 `MapState.items: Dictionary[StringName, ItemState]` 保存卸载地图的数据；不得保存 Node。
- 地图 Item 不保存额外的运行时类型枚举。`BaseMap.add_item()` 直接根据 `PlantMeta / HarvestableMeta / ItemMeta` 的真实类层级选择 `plants_host / harvestables_host / items_host`；ToolMeta 不允许创建为地图 Item。
- MapCell 通过绑定 CellState.item_ids 查询占用；Item DTO 从 MapState.items 查询，地图 Item 节点从 BaseMap.items 查询。
- BaseMap 的 Item 工厂必须通过 ItemState.meta_id 解析 Meta，校验对应 State 子类，并显式创建匹配的 Item 子类；例如 PlantMeta/PlantState 对应 Plant。由于 Plant 继承 Harvestable，工厂判断顺序必须先 Plant、后 Harvestable。不得根据 ID 文本、节点名或脚本路径推断类型，也不得接受交叉组合。
- ItemState 及其子类放在 scripts/state/item/，BackpackState/BackpackSlot 放在 scripts/state/inventory/，CellState 放在 scripts/state/；Item 基类和运行时子类放在与 world 同级的 scripts/items/。
- 浇水使用 `CellState.CellFlag.WATERED`；日推进逻辑消费前一天的浇水状态后清除该 flag。
- 雨或暴风雨开始、雨天载入地图、以及雨天使用 Hoe 新增 DUG 时，BaseMap 必须给对应 DUG cell 添加 WATERED 并重建 WateredLayer；CalendarManager 只选择天气和发出事实信号，不直接修改地图状态。
- `GameConfig.weather_icons: Dictionary[StringName, Texture2D]` 必须覆盖所有 SeasonMeta 中出现的天气 ID。状态面板通过 CalendarManager 查询当前天气图标并实时切换，不保存第二份天气贴图映射，也不用天气文字代替图标。
- Hoe/WateringCan 的多格操作由运行时 `Tool` 统一执行：先用 MapCell 查询收集有效格，再整批校验体力，最后原子修改 CellState。Tool/Seed 不提供反复 new/free 的静态 `perform` 入口；Player 通过自身 `PlayerBackpack` 复用当前背包中可用的 Tool/Seed 运行时对象，只有对应 BackpackSlot 消失时才从 Backpack 删除。`SeedOutcome` 与 `ToolOutcome` 是两个独立结果类型，不建立只有少量公共字段的 ItemOutcome；`CellToolOutcome` 和 `ItemToolOutcome` 继承 ToolOutcome，分别承载 cell 投影结果与采集对象结果。所有 Outcome 一类一文件，统一放在 `scripts/items/outcome/`；UI 不从日志推断结果。
- 一次 Tool 事务只消耗一次 `base_stamina_cost`；蓄力只扩大目标范围，不得将消耗乘以有效格数量，否则最大蓄力范围可能在满体力时也无法使用。
- MapCell 的工具行为统一通过 `tool_rejection_reason(tool_kind)` 和 `use_tool(tool_kind)`，不得为 Hoe/WateringCan 保留重复的 till/water 方法。Tool 不持有或修改 PlayerState；Player 根据成功的 ToolOutcome.stamina_spent 更新体力，EffectArea 直接读取 PlayerState 但不修改其体力。
- InteractionContext 不再作为中间快照类型；EffectArea.begin 直接接收 PlayerState、BaseMap 和 PlayerBackpack 提供的 Tool/Seed 运行时对象，并在内部保存 BaseMap interaction_revision 快照。`use_held` release 是 Player 的动作：Player 从 EffectArea 读取 preview cells 后调用 Tool/Seed.use、扣体力/数量并发出反馈；EffectArea 只维护蓄力状态、目标集合和预览绘制。
- Player 专属交互组件脚本与 player.gd 一并放在 scripts/actors/；不得为 EffectArea 单独保留 scripts/interaction/ 目录。
- DUG/WATERED 的运行时表现由 BaseMap 从 CellState 重建到地图预置的空 `DugLayer`/`WateredLayer`；表现层不拥有状态，也不把 tile 数据写回 State。
- 对角移动允许时做归一化；NPC 对角寻路不得穿过两个相邻阻挡格的夹角。

## 9. 输入和交互

- 所有玩家输入必须注册到 InputMap；业务脚本只调用 `Input.is_action_*`。
- 必需 action：`move_left/right/up/down`、`walk_modifier`、`use_held`、`drop`、`drop_held`、`toolbar_previous/toolbar_next`、`itembar_previous/itembar_next`、`inventory_toggle`、`inventory_swap`、`inventory_confirm`、`cancel`、`quick_save`、`quick_load`、`skip_day`。`drop` 是当前丢弃入口，`drop_held` 保留为兼容别名；两者都只允许 `ItemMeta.dropable` 的物品丢到面向的可放置格，每次一个并同步背包 slot。`skip_day` 是开发期换日入口，由 `CalendarManager` 推进 CalendarState 并发出 `day_advanced`。
- 正式玩法的选择、使用、丢下和背包整理必须可由纯键盘完成；业务逻辑不得读取鼠标位置、鼠标按钮或 drag/drop 事件。方向目标来自 Player facing，UI 导航来自语义化方向 action。
- Toolbar 只管理工具，Itembar 只管理可选择非工具物品，Inventory 管理普通存储。三者交换必须经过类型校验和原子状态 API；UI 不得直接改数组。
- Player 只有一个 `active_hand_source` 和一个 active BackpackSlot。切换 Toolbar 或 Itembar 会替换当前手持来源，不允许工具与物品同时激活、同时显示或同时提交行动。
- 新游戏初始化时 `active_hand_source` 必须为 `NONE`，Toolbar/Itembar 的库存仍正常装载；玩家主动选择栏位后才开始持有和显示对应 BackpackSlot。
- UI 打开或场景切换时，通过明确的输入模式锁定世界交互；不能只靠某个节点恰好先消费事件。
- 蓄力以状态机实现：idle -> charging -> committed/cancelled；释放 `use_held` 后只提交一次。
- 范围型交互由 `ToolMeta.charge_levels` 和 `SeedMeta.charge_levels` 配置：Hoe、WateringCan、Sickle、Basket 使用 1x1、3x1、3x3、9x3、9x9 五档；Seed 使用 1x1、3x1、3x3、9x3 四档。Pickaxe、Axe 始终使用 1x1 范围，蓄力等级只选择 `damage_multipliers`，不得扩大 preview。蓄力期间 Player 保持原 facing 并连续移动；EffectArea 只在玩家世界坐标跨过 cell 边界时，随 PlayerState.cell 重新生成 preview，不进行连续像素级 preview 位移。Player 头顶必须显示蓄力 ProgressBar，颜色随 level 从浅黄渐变到深绿，并在 release/cancel 后隐藏。
- 工具等级由静态 `ToolMeta` 表示：不同等级的工具使用不同 item id 和不同 ToolMeta，可分别配置贴图、动画、`charge_levels` 与 `damage_multipliers`。不再保存动态 `ToolState`；工具的可用档位完全由当前 ToolMeta 的配置决定。
- 目标预览和实际执行必须调用同一个 targeting 结果，避免显示有效但执行不同格。
- 调试输入放在 `debug` feature flag 后，导出发行版默认关闭。

## 10. 像素、美术和 UI

- T01 选择并记录基准视口、拉伸模式、像素吸附和贴图过滤；整个项目保持一致。
- 像素贴图默认 nearest filtering，不启用会造成边缘渗色的 mipmap。
- 角色、目标格、地块和世界对象使用整数尺寸/位置策略；Camera2D 缩放使用稳定整数倍。
- 世界内容在 Node2D/CanvasItem 层；HUD 在独立 CanvasLayer。UI 不跟随世界相机缩放。
- 画面排序通过 `y_sort_enabled`、明确 `z_index` 和层级约定实现，禁止每帧按名字修改排序。所有地图生成物与 Player 必须接入同一个嵌套 y-sort 域：`World/MapHost/BaseMap/MapItems/entity host` 和 `World/ActorHost` 的链路都开启 y-sort，item/runtime node 以所在 cell 中心作为排序原点。
- Control 使用 anchors/containers 构建响应式布局，固定格式控件有明确最小尺寸；文本不得截断、互相覆盖或超出窗口。
- 每个图标按钮有 tooltip；颜色反馈不能是唯一反馈，需配合形状/图标/文本状态。

## 11. 存档

- 存档为 `user://saves/slot_0.json`，根节点包含 `schema_version`、`game_version`、`saved_at`、`player`、`inventory`、`time`、`maps`。
- 所有自定义状态实现 `to_dict()` 和显式的 `from_dict()`/factory；不得直接 `var_to_str` 保存对象图。
- Vector 使用 `{ "x": ..., "y": ... }`，枚举和资源引用保存稳定 ID，不保存 NodePath、instance ID 或资源 UID。
- 加载按“读取 -> JSON/模式校验 -> 迁移 -> 构造临时状态 -> 整体替换”执行；失败时保留当前游戏。
- 保存先写临时文件，成功后替换正式文件；不得让崩溃留下半个 JSON。
- 未知字段忽略，缺省字段提供明确默认；版本不兼容要显示错误并保留原文件。

## 12. 错误处理与日志

- 开发期对不变量使用 `assert`；用户输入、缺失存档和可恢复资源问题使用返回值、`push_warning`/`push_error` 和 UI 提示。
- 日志带模块前缀，如 `[BaseMap]`、`[MapCell]`，不得在每帧循环刷屏。
- 不吞掉 Godot `Error` 返回值。文件、资源保存和场景切换失败都必须处理。
- godot-ai 写脚本后必须检查该次响应的 `diagnostics`；不能只依赖后续 game log。
- 任务结束时 editor log 与本次 game run log 都必须检查。

## 13. 测试与提交质量

- 纯逻辑优先放在不依赖场景树的类中，使用 `tests/test_runner.gd` headless 验证。
- 测试必须断言最终值和类型，不以“节点数大于 0”代替实际行为验证。
- 随机生成使用可注入 seed；测试固定 seed，发行运行可随机。
- 每个任务至少有一个失败路径测试或验收，例如无体力、无种子、无效地块、满背包、损坏存档。
- 禁止为了通过测试加入只在测试路径生效的业务分支。
- 每次只改任务卡允许的模块；必要的跨模块改变先更新任务卡和架构文档。
