# Godot 与 GDScript 技术规则

本文所有“必须/禁止”均为硬性约束。任务卡没有明确授权时不得偏离。

## 1. 工具链

- 项目基线为 Godot **4.7 stable 标准构建**，不是 .NET/Mono 构建；godot-ai 3.0.7 要求 Godot 4.5+，因此不得降回 4.3/4.4。
- T00 必须先记录实际 `godot --version`；`project.godot` 中版本敏感设置以安装版本为准，不凭记忆硬编码。
- 游戏代码全部使用 GDScript 2.0。禁止 `.cs`、`.csproj`、`.sln` 和 C# 插件。
- 运行时不得依赖 godot-ai；它只用于开发、编辑器操作、验证和截图。
- 不增加第三方运行时/测试插件，除非用户明确批准并记录原因。

## 2. 目录和命名

目标目录结构见 [02_ARCHITECTURE.md](./02_ARCHITECTURE.md)。通用命名：

- 文件和目录：`snake_case`。
- GDScript 类：`PascalCase`，跨文件需要类型名时使用 `class_name`。
- 节点：`PascalCase`，同一场景内名称稳定；需要脚本引用的节点设置为唯一名称。
- 变量、方法、信号和 InputMap action：`snake_case`。
- 常量：`UPPER_SNAKE_CASE`。
- Resource ID：稳定的英文 `StringName`，例如 `&"tool_hoe"`、`&"crop_parsnip"`；显示文本与 ID 分离。
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
- 地图场景必须像 cabin 一样在根节点下按职责并列组织 TileMapLayer、动态实体、静态装饰、碰撞、出生点和传送口。地图根脚本直接管理自己的 TileMapLayer，不再增加只用于包裹 TileMapLayer 的 Grid 节点。
- 地面道路等可行走 TileMapLayer 必须保持在角色渲染层级之下；同级地面层可通过节点顺序叠加，但不得使用高于 `ActorHost` 的 `z_index` 覆盖 Player。资源、边界和前景装饰需要遮挡角色时必须明确标注其前景层级。
- 与某个组件强耦合的功能不需要独立成类；地图统一使用 `BaseMap` 负责坐标、边界、MapCell/Entity 运行时索引和实体 host 路由。MapCell 是每个格子的运行时行为对象；地图场景不创建无额外行为的根脚本。
- `map_id`、尺寸、`Dictionary[Vector2i, MapCell]`、`cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 和 `entity_hosts: Dictionary[Node2D, EntityState.EntityType]` 放在 BaseMap。不得增加 farm/field/cabin 专属地图类或 crop 专属 host API。
- 地面、道路、墙体、水域、静态资源区等开发者需要编辑的 TileMap cell 必须使用 Godot TileMap 编辑器绘制并序列化在对应 `.tscn` 中。运行脚本不得 `clear()` 后重建静态地图，也不得用启动时代码替代场景内的 `tile_map_data`。
- dug、watered、entity_ids 等可存档数据只保存在 CellState/EntityState DTO 中；MapCell/Entity 绑定并操作对应 DTO。不得再创建 Dug/Watered TileMapLayer 或其他重复状态投影。

## 4. 场景规则

- 场景按职责拆为可独立运行/实例化的 leaf scene，再由 parent scene 组合。
- 运行逻辑只存在脚本；`.tscn` 保存节点、资源引用和配置，不保存业务数据快照。
- 使用 `PackedScene` 实例组合 Player、WorldItem、Crop、NPC 和 UI；不要把实例展开复制到父场景。
- godot-ai 可用时优先用其 scene/node/resource 工具进行语义化场景修改，避免手写 `.tscn` 的 sub-resource ID、UID 和连接段。
- 通过工具生成/修改场景后必须 `scene_save`，然后重新读取 hierarchy 验证节点没有静默丢失。
- 不直接编辑 `.godot/`、`.uid`、导入缓存或编辑器用户设置。
- 主场景始终可运行；调试专用场景放入 `tests/fixtures/` 或 `dev/`，不得改成发行主场景。

## 5. Node 与 Resource 的边界

- Node 负责生命周期、输入、场景表现和 Godot 对象交互。
- Resource 负责静态定义数据，例如物品、作物阶段、掉落表、NPC 日程和音频配置。
- RefCounted/纯 GDScript 状态对象负责运行时数据，例如物品堆、地块状态和存档 DTO。
- 不把运行时可变数量写回 `.tres` 定义资源；加载后的定义视为只读。
- Resource 之间使用稳定 ID 关联，避免整个运行时状态通过循环 Resource 引用序列化。
- 工厂负责 `ItemDefinition -> PackedScene` 实例化；业务系统不得散落字符串路径加载。

## 6. Autoload 规则

只允许以下全局服务，增加新 Autoload 必须先更新架构文档：

1. `EventBus`：只声明跨模块信号，不持有领域状态。
2. `DataCatalog`：只读定义索引和启动校验。
3. `GameState`：玩家状态、背包和各地图动态状态的唯一所有者。
4. `TimeManager`：游戏日历、倍率、暂停和时间推进。
5. `SceneManager`：地图切换、出生点和淡入淡出协调。
6. `SaveManager`：版本化存取与迁移，不直接操作场景表现。
7. `AudioManager`：音频总线和池化播放。

Autoload 不得通过全树搜索抓取当前 Player/Farm/UI。需要场景对象时由场景在 `_ready` 注册并在 `_exit_tree` 注销，或通过信号传递一次性命令。

## 7. 事件与数据所有权

- 每份可变数据只有一个权威写入者。例如金币与背包由 GameState 写，UI 只订阅；cell 行为直接通过 MapCell 修改，实体节点通过 BaseMap.entity_hosts 挂载。
- Signal 用于通知和跨模块请求，不作为无类型的数据总线。参数必须有稳定类型和清楚语义。
- 所有信号声明必须集中在 `EventBus`；领域服务、地图根节点和场景组件不得自行声明信号变量。模块内部需要通知时也通过 `EventBus` 的稳定事实信号，避免信号所有权分散。
- 同一模块内部优先直接方法调用；不要把所有调用都绕到 `EventBus`。
- 需要原子性的行为采用“校验 -> 计算变化 -> 提交 -> 发出事实事件”。体力、种子、地块和产出不能只提交一半。
- UI 不直接修改领域字典；UI 调用公开命令并根据信号刷新。

## 8. 网格与坐标

- 全部农事状态以 `Vector2i` 地图坐标为主键，禁止用像素位置或字符串作为运行时主键。
- 坐标转换只由 BaseMap 通过 cell_flags 中唯一的 BASE TileMapLayer 提供：世界坐标 -> layer local -> map，以及 map -> local -> world。
- 所有农事层共享同一 tile size、transform 和 origin；T04 必须加入对齐检查。

### 8.1 Map、Cell、Entity 核心关系

运行时对象关系：

```text
BaseMap
├── cells: Dictionary[Vector2i, MapCell]
│   └── MapCell -> 绑定同坐标 CellState
├── entities: Dictionary[StringName, Entity]
│   └── Entity -> 绑定同 ID EntityState
└── entity_hosts: Dictionary[Node2D, EntityState.EntityType]
    └── host -> 挂载该 Type 的 Entity
```

持久化状态关系：

```text
GameState
├── maps: Dictionary[StringName, MapState]
│   └── MapState
│       ├── cells: Dictionary[Vector2i, CellState]
│       └── entities: Dictionary[StringName, EntityState]
└── npcs: Dictionary[StringName, NpcState]
```

- `BaseMap` 是当前已加载地图的运行时根和协调者，唯一管理 MapCell/Entity 运行时对象、坐标转换、静态 flag 重建、实体事务和 host 路由。
- `MapState` 是地图卸载后仍存在的纯数据容器，只保存 CellState/EntityState DTO 和生成标记，不实现耕种、占用、实体增删移动或场景操作。
- MapState 不得合并进 BaseMap。GameState 必须能在地图场景未实例化时创建、保存和恢复所有 MapState；地图切换释放 BaseMap 时不得影响未加载地图的 cells/entities。
- `CellState` 是无业务方法的 DTO，保存 cell、flags、dug、watered_on_day、entity_ids，并声明存档使用的 `CellFlag`。MapCell 绑定同坐标 CellState，并提供 flag 查询、dig、water、drop/occupancy 等行为。
- `EntityState` 是不继承的扁平 DTO，保存 instance_id、definition_id、type、cell、health、random_seed、flags 及当前实体类型需要的状态字段。不得为 crop、pickup、harvestable 建立 EntityState 子类。
- `Entity` 是运行时 Node2D 基类并绑定 EntityState；BaseMap 根据 EntityState.type 创建 CropEntity 或其他 Entity 子类。instance_id 在整张 MapState 内唯一，EntityState.cell 必须指向包含其 ID 的 CellState。
- `MapState.entities` 和 `MapState.cells` 是存档数据所有者；`BaseMap.entities` 和 `BaseMap.cells` 是运行时对象所有者。所有同步和关系校验由 BaseMap 负责。
- `NpcState` 的唯一所有者是 `GameState.npcs`，其 `map_id/cell` 表示 NPC 当前所在地图和格子。NPC 可跨地图活动，因此不得写入 MapState.entities。
- 仅实例化 `NpcState.map_id` 等于当前地图的 NPC；NPC 运行时 Entity 必须设为 `EntityState.EntityType.NPC` 并通过 BaseMap.add_entity() 挂入当前地图配置的 NPC host。NPC 状态仍由 GameState.npcs 持有。
- 创建实体的事务顺序固定为：BaseMap 校验目标 MapCell/status -> 写入 EntityState 和 CellState.entity_ids -> 根据 type 创建 Entity -> 绑定 DTO -> 挂载 host。创建或挂载失败时必须回滚 DTO。
- 移动实体必须通过 BaseMap.move_entity() 原子地修改源/目标 CellState.entity_ids、EntityState.cell 和 Entity 节点位置；失败时不得留下双重归属。
- 删除实体必须通过 BaseMap.remove_entity() 同时删除 CellState 引用、MapState.entities DTO 和运行时 Entity，再结算掉落/事件。
- 地图卸载时释放 BaseMap、MapCell 和 Entity；MapState、CellState、EntityState、NpcState 继续由 GameState 持有。地图恢复时由 BaseMap 重新创建并绑定运行时对象。

### 8.2 Cell Status 与坐标规则

- `BaseMap` 在 ready 时为地图边界内每个坐标创建一个 MapCell，并在 configure_state 时绑定 `MapState.cells` 中同坐标的 CellState。调用方通过 `get_cell()` 取得运行时对象。
- `CellState.CellFlag` 是可保存、可组合的位标记，至少包含 BASE、DIGGABLE、DROPABLE、ROAD、BLOCKED、RESOURCE、INTERIOR。BASE 表示地图唯一的基础/坐标层，其 used cells 默认可行走。
- BaseMap 的 `cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 是静态 cell flag 的唯一配置入口。每个 entry 表示该 TileMapLayer 的每个 used cell 都获得对应 flag；同一坐标出现在多个 layer 时按位 OR 叠加。
- flag cell 集合必须直接绘制并序列化在对应 TileMapLayer 中；禁止用 Rect2i、Polygon、节点名称推断或启动时代码生成固定形状。只用于配置的 flag mask layer 可以不可见，但必须拥有 tile_map_data，并与坐标层保持 tile size、transform 和 origin 对齐。
- 每张地图必须且只能配置一个 BASE layer；坐标转换、地图边界参考和基础可行走查询都由该 dictionary entry 决定。BLOCKED 是行为否决状态，可以与 BASE/DROPABLE 等同时存在；`is_walkable()`、`is_dropable()` 等查询必须显式排除 BLOCKED。
- `MapState.cells: Dictionary[Vector2i, CellState]` 和 `MapState.entities: Dictionary[StringName, EntityState]` 保存卸载地图的数据；不得保存 Node。
- `EntityState.EntityType` 是存档中的实体类别；Entity 是所有地图实体节点的运行时基类，只消费该类别。BaseMap.entity_hosts 的每个 host 只能对应一个唯一 EntityType；add_entity() 按 Entity.type 路由。
- MapCell 通过绑定 CellState.entity_ids 查询占用；实体 DTO 从 MapState.entities 查询，实体节点从 BaseMap.entities 查询。
- BaseMap 的实体工厂必须根据 EntityState.type 显式创建真实 Entity 子类，例如 CropEntity；不得根据 definition_id、节点名或脚本路径推断类型。
- EntityState 及 CellState 放在 scripts/state/；Entity 基类和运行时子类放在 scripts/world/entity/。
- 浇水使用 `watered_on_day: int`，而不是每天遍历清零布尔值。
- 对角移动允许时做归一化；NPC 对角寻路不得穿过两个相邻阻挡格的夹角。

## 9. 输入和交互

- 所有玩家输入必须注册到 InputMap；业务脚本只调用 `Input.is_action_*`。
- 必需 action：`move_left/right/up/down`、`walk_modifier`、`primary_action`、`secondary_action`、`inventory_toggle`、`cancel`、`hotbar_1..hotbar_10`、`quick_save`、`quick_load`。
- UI 打开或场景切换时，通过明确的输入模式锁定世界交互；不能只靠某个节点恰好先消费事件。
- 蓄力以状态机实现：idle -> charging -> committed/cancelled；释放鼠标后只提交一次。
- 目标预览和实际执行必须调用同一个 targeting 结果，避免显示有效但执行不同格。
- 调试输入放在 `debug` feature flag 后，导出发行版默认关闭。

## 10. 像素、美术和 UI

- T00 选择并记录基准视口、拉伸模式、像素吸附和贴图过滤；整个项目保持一致。
- 像素贴图默认 nearest filtering，不启用会造成边缘渗色的 mipmap。
- 角色、目标格、地块和世界对象使用整数尺寸/位置策略；Camera2D 缩放使用稳定整数倍。
- 世界内容在 Node2D/CanvasItem 层；HUD 在独立 CanvasLayer。UI 不跟随世界相机缩放。
- 画面排序通过 `y_sort_enabled`、明确 `z_index` 和层级约定实现，禁止每帧按名字修改排序。
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
