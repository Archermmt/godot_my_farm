# T02 定义与运行状态模型

## 目标

实现不依赖具体场景表现的静态定义 Resource 与运行时状态对象，为物品、背包、地块、作物、地图、玩家和存档建立唯一数据模型。

## 依赖

- T01 completed。

## 交付范围

- `scripts/data/item/`：ItemMeta、ToolMeta、HarvestableMeta、PlantMeta、HarvestableStage、HarvestableDrop；`scripts/data/`：NpcSchedule/event。Meta 仅用于被多个实例共享的类型定义。
- `scripts/state/item/`：ItemState、HarvestableState、PlantState；`scripts/state/inventory/`：BackpackState、BackpackSlot；`scripts/state/`：PlayerState、CalendarState、CellState、NpcState、MapState；`scripts/item/` 保存运行时 Item、Harvestable 和 Plant，与 `scripts/world/` 同级；`scripts/world/` 保存 BaseMap 与 MapCell。
- `DataCatalog` 配置：最小测试定义集合，包括 6 个工具、欧洲防风草种子/作物、木材、石头、草、食物占位定义。
- `tests/unit/`：catalog/state/round-trip 测试。

## 实现要求

1. 所有定义继承 Resource，字段类型明确；运行中视为只读。
2. 所有 ID 为稳定 StringName，显示名独立；交叉引用用 ID 或直接静态 Resource，不用文件名推断。
3. BackpackState/BackpackSlot 完成命名槽位、堆叠、添加、移除、交换、合并、容量和选择 API；调用失败不改变部分状态。
4. PlayerState 对生命、体力、金币做范围保护。
5. PlayerState 只保存人物自身状态；BackpackState 由 GameManager 独立持有，快照使用顶层 `backpack` 字段。
6. PlayerState、BackpackState 和 BackpackSlot 是运行时数据 Resource，字段不使用 `@export`；`GameConfig` 不导出完整 State，而是在 `Player`、`Backpack` 分类下暴露出生信息、行为参数、容量和初始槽位。GameManager 根据这些参数创建新游戏 State，读档只恢复快照数据。Player 和 Cell 等唯一运行时类型不建立 Meta。
7. MapState 只持有 CellState/ItemState DTO，不提供运行时事务；ItemState 子类只保存对应 Meta 类型的专属可变数据，并用 meta_id 连接共享 Meta。所有 ItemState 保存当前 health，ItemMeta 保存 health 上限。BaseMap 校验 Meta/State 子类组合，创建对应 Item 子类；Item 基类提供统一的 State/Meta 访问和耗尽判断，子类只负责强类型 downcast。
8. 所有需存档状态实现纯 Dictionary `to_dict()` 和严格 factory；Vector/ID 按技术规则序列化。
9. 定义校验函数能发现重复/空 ID、非法 slot、负价格、错误掉落范围、非递增成长阶段和缺交叉引用。
10. 不在状态对象中保存 Node、Texture、PackedScene instance 或 Callable。

## 自动化验收

- 测试 BackpackSlot 添加到 slot limit、溢出到空格、满包退回、移除不足、跨容器交换和选择。
- 测试 PlayerState 上下限。
- 测试 Farm/Plant/MapState 深度 round-trip，并断言恢复后的 Vector2i/StringName/数值类型。
- 测试每一种无效定义，确认校验失败且消息包含 ID/字段。

## godot-ai 验收

- 每个新增 GDScript 的 create/patch response diagnostics 为零。
- filesystem scan 后 editor log 无 class_name 冲突或循环 preload。
- 可建立临时 fixture scene 加载 catalog，运行打印一条校验成功摘要；使用 autosave=False，不污染主场景。

## 不做

- 不注册 DataCatalog Autoload，不创建真实 WorldItem/Player/UI。
- 不实现作物成长或工具行为。

## 完成记录

STATUS 记录定义数量、单元测试通过/失败数和 diagnostics 结论；总表 T02 completed。
