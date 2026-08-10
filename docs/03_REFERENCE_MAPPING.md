# `Archermmt/my_farm` 参考映射

## 1. 参考快照

- 仓库：[https://github.com/Archermmt/my_farm](https://github.com/Archermmt/my_farm)
- 分析提交：`bd808154b479f87efc4fc06ff42c683d7db351bc`
- 提交说明：`NPC testing`
- 本机只读副本：`/Users/tongmeng/Desktop/codes/my_farm`
- 原技术栈：Unity 6、C#、URP 2D、Tilemap、Input System/uGUI。

该提交是本项目玩法与职责的核心事实来源。它不是 Godot 项目，因此所有 Unity API 和资产组织必须经过本文件的映射，不能直接复制。

## 2. 已确认的参考行为

代码级分析确认参考提交包含：

- `PlayerScene` 作为启动场景，Player 和管理器持久存在；Farm/Field/Cabin 以 additive scene 切换。
- 默认跑步、Shift 慢走、鼠标决定方向、右键蓄力/释放、`P` 打开背包。
- 工具：Hoe、WaterCan、Scythe、Basket、Pickaxe、Axe。
- 工具和种子按照蓄力等级扩大 3x1、3x3、9x3、9x9 等范围。
- FieldGrid + 多个 FieldLayer 组合 Diggable/Dug/Watered/Obstacle/Path 等标签。
- 物品基类、可拾取物、可采集物、植物、作物、树、障碍物的行为层次。
- 作物只有在 Watered 地块上跨天成长；生命阶段决定图像、生命、工具和掉落。
- 掉落物感应 Player 后吸附拾取；背包支持堆叠、拖拽交换、选择与说明。
- 年/月/日/星期/小时/分钟推进，月映射季节；23 点触发换日并回小屋恢复状态。
- 场景端口、淡入淡出、每地图动态 item 的内存保存与恢复。
- 环境对象生成器、采集音效/特效、环境光时段表。
- NPC 事件日程、路径节点、道路权重和跨场景移动原型。

## 3. Unity 到 Godot 映射表

| Unity 参考 | 职责 | Godot/GDScript 目标 |
|---|---|---|
| `EventHandler` static events | 跨系统事件 | `EventBus` Autoload typed signals |
| `Singleton<T>` | 持久服务 | 窄职责 Autoload；场景对象用注册/注入 |
| `ItemData [Serializable]` | 物品静态定义 | `ItemMeta extends Resource` + `.tres` |
| Prefab + `Resources.Load` | 物品/效果实例化 | `PackedScene` 直接引用 + `ItemFactory` |
| `Item` | 物品通用状态/交互 | ItemMeta + held/world scene 组件 |
| `Tool` | 体力和蓄力 | `UseAction`/`ToolAction` 策略 |
| `GridTool` | 网格行动 | `GridToolAction` + MapCell transaction |
| `ItemTool` | 对对象行动 | `HarvestToolAction` + Harvestable component |
| `Seed` | 种植范围和消耗 | `SeedAction` + PlantMeta |
| `Harvestable/LifePeriod` | 阶段、生命、掉落 | `HarvestableMeta`/GrowthStage + component |
| `Plant/Crop` | 地块植物与浇水成长 | `PlantMeta` + PlantState + PlantItem + day_advanced |
| `TreeBase/TreeTrunk` | 斧击、倒向、树桩 | `HarvestableMeta` + TreeWorldItem 专属状态/动画策略 |
| `Pickable` | 吸附拾取 | `PickupItem (Area2D)` |
| `FieldGrid` | 单格标签与地图 Item | MapCell/CellState + BaseMap/MapState items |
| `FieldLayer` | Tilemap 标签/保存 | `BaseMap.cell_flags` + MapCell |
| `FieldManager` | 网格、光标、工具执行 | `BaseMap` + TargetingService + InteractionController |
| `Cursor` | 有效/无效目标反馈 | `InteractionCursor` scene |
| `Generator` | 随机环境对象 | seeded `WorldGenerator` + MapState |
| `BaseInventory/Container/Slot` | 背包数据和 UI 混合 | `InventoryState` 与 InventoryUI 分离 |
| `ToolBar` | 快捷栏选择 | 分离的 `ToolbarUI`（工具）+ `ItembarUI`（非工具物品）+ Player 头顶选择提示 |
| `Player` | 输入、移动、持物、交互 | 单一 `player.gd` 根控制器 + 无业务脚本的表现/挂点子节点 |
| `PlayerStatus` | 生命/体力/金币与 UI | PlayerState + HUD 投影 |
| `EnvManager/Clock` | 时间推进和显示 | GameManager.CalendarState + ClockUI |
| `SceneController` | additive scene/淡入淡出 | persistent Main + SceneManager + MapHost |
| `ScenePort` | 地图触发器 | Area2D `ScenePort` 请求 SceneManager |
| `ItemManager` | 定义索引、工厂、地图 item 内存 | DataCatalog + ItemFactory + MapState |
| `GameLight` | 时段光照 | CanvasModulate/Light2D + LightSchedule Resource |
| `AudioManager/Sound` | 音频查找与播放 | AudioManager pool + AudioDefinition |
| `EffectManager` | 特效工厂 | EffectHost + effect PackedScene pool |
| `NPC` 自建路径 | 日程、寻路、跨场景 | NpcScheduleController + built-in AStarGrid2D |

## 4. 必须保留的架构意图

### 4.1 同一套地块查询驱动所有行动

参考代码的 `FieldManager.CheckItem()` 让工具、种子和普通物品共享网格范围与 Cursor。Godot 版必须维持统一 preview/commit 链路，不能为锄头、种子和斧头各写一套目标坐标逻辑；目标由 Player facing 计算，不再读取鼠标位置。

### 4.2 工具类别与目标能力匹配

参考代码由 `ToolType` 与每个 LifePeriod 的 harvest data 决定有效工具和产出。Godot 版由 `tool_kind`、HarvestableMeta 和 DropTable 实现，不把对象名写进工具脚本。

### 4.3 生命阶段是数据

成长日、图像、生命和掉落必须来自 Resource 数据，不能把“第 3 天换 sprite”硬编码在 PlantItem。

### 4.4 玩家跨地图保持，地图动态状态恢复

Godot 主场景中的 Player 不随 MapHost 被替换。地图卸载前写回 MapState 的 cells/items；NPC 状态持续保存在 GameManager.npcs。再次进入时恢复作物、掉落、被砍树木，并按 NpcState.map_id 恢复当前地图 NPC；不能重新生成成初始地图。

### 4.5 时间事件驱动而非对象轮询

植物、玩家状态、NPC 和光照订阅统一时间变化；Plant 不在每帧读取时钟判断成长。

## 5. 有意改进而不是照抄的部分

| 参考原型情况 | Godot 版决定 | 原因 |
|---|---|---|
| Manager 经常按 tag/名称搜索场景树 | 显式注册、导出引用、窄 API | 防止换场景时绑定错误，便于测试 |
| ItemData、行为、Prefab 路径部分靠名称约定 | Resource 直接引用 PackedScene，稳定 ID 索引 | 重命名安全，可在启动时校验 |
| FieldLayer 同时承载表现、标签和存档 | CellState/ItemState 持久化，MapCell/Item 运行，TileMapLayer 仅投影 | 存档、测试与重建更可靠 |
| Inventory Slot 同时持有数据和 UI | InventoryState 与 Control 分离 | UI 销毁不丢状态，便于存档 |
| 工具应用可能跨多个对象逐个修改 | 先完整校验，再原子提交 | 避免体力/数量不足时只执行一半 |
| Scene item 状态仅在进程内缓存 | MapState + 单槽版本化存档 | 支持真正退出/读取 |
| NPC 手写路径搜索 | Godot `AStarGrid2D` | 使用内建成熟实现并保留道路 penalty |
| 多个系统用 freeze bool | reason-based pause/input lock | 防止 UI、过场、工具互相提前解锁 |
| 鼠标定向、右键蓄力、拖拽背包 | 纯键盘 facing 目标、use/drop action、方向焦点与交换键 | 满足当前项目的键盘优先交互要求，并便于后续手柄映射 |

## 6. 不应从参考项目推断的功能

分析提交没有可作为完成基线的商店交易、正式对话、任务/好感、畜牧、烹饪或战斗系统。`ItemData` 有 price/value、PlayerStatus 有 money，并不代表商店闭环已存在。任务列表不得把这些能力标成复刻必需。

同样，参考项目中的家具类型、NPC 代码和部分物品资源属于预留/原型，不代表所有 UI 或内容已发布级完成。Godot 首版只要求 [00_GAME_DESIGN.md](./00_GAME_DESIGN.md) 明确列出的可验证能力。

## 7. 参考使用纪律

- 开发任务需要行为细节时，先查看本映射，再只读对应 C# 文件。
- 不从参考仓库复制代码块后做语法替换；基于职责重新实现。
- 不复制 Unity `.unity`、`.prefab`、`.meta`、GUID、Material 或 Animator Controller。
- 美术/音频需单独确认许可证。即使用户拥有仓库，也默认用原创占位资源，直到授权明确。
- 参考仓库之后发生变化时，不自动漂移；先更新本文件的固定提交和差异说明。
