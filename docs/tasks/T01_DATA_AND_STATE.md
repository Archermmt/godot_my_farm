# T01 定义与运行状态模型

## 目标

实现不依赖具体场景表现的静态定义 Resource 与运行时状态对象，为物品、背包、地块、作物、地图、玩家和存档建立唯一数据模型。

## 依赖

- T00 completed。

## 交付范围

- `scripts/data/item/`：ItemMeta、ToolMeta、HarvestableMeta、PlantMeta、PlantStageMeta；`scripts/data/`：DropTable/entry、NpcSchedule/event。PlantStageMeta 是可由 Inspector 编辑的阶段 Resource，集中配置阶段贴图和阈值。
- `scripts/state/item/`：ItemState、HarvestableState、PlantState；`scripts/state/inventory/`：ItemStack、InventoryState、ToolbarState、ItembarState；`scripts/state/`：PlayerState、CalendarState、CellState、NpcState、MapState；`scripts/items/` 保存运行时 Item、HarvestableItem 和 PlantItem，与 `scripts/world/` 同级；`scripts/world/` 保存 BaseMap 与 MapCell。
- `data/`：最小测试 catalog，包括 6 个工具、欧洲防风草种子/作物、木材、石头、草、食物占位定义。
- `tests/unit/`：catalog/state/round-trip 测试。

## 实现要求

1. 所有定义继承 Resource，字段类型明确；运行中视为只读。
2. 所有 ID 为稳定 StringName，显示名独立；交叉引用用 ID 或直接静态 Resource，不用文件名推断。
3. ItemStack/InventoryState 完成堆叠、添加、移除、交换、合并、容量和选择 API；调用失败不改变部分状态。
4. PlayerState 对生命、体力、金币做范围保护。
5. PlayerState 是 InventoryState、ToolbarState 和 ItembarState 的唯一状态所有者；GameManager 只持有整体 PlayerState，快照将三个容器嵌套在 `player` 字典内。
6. MapState 只持有 CellState/ItemState DTO，不提供运行时事务；ItemState 子类只保存对应 Meta 类型的专属可变数据，并用 meta_id 连接共享 Meta。BaseMap 校验 Meta/State 子类组合，绑定强类型 State/Meta，创建对应 Item 子类并管理运行时 cells/items。
7. 所有需存档状态实现纯 Dictionary `to_dict()` 和严格 factory；Vector/ID 按技术规则序列化。
8. 定义校验函数能发现重复/空 ID、非法 stack、负价格、错误掉落范围、非递增成长阶段和缺交叉引用。
9. 不在状态对象中保存 Node、Texture、PackedScene instance 或 Callable。

## 自动化验收

- 测试 ItemStack 添加到 stack limit、溢出到空格、满包退回、移除不足、跨容器交换和选择。
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

STATUS 记录定义数量、单元测试通过/失败数和 diagnostics 结论；总表 T01 completed。
