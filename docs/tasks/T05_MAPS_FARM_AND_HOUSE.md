# T05 地图、网格、场景切换与房屋

## 目标

创建 farm、field、beach 三张可探索地图，建立统一 TileMapLayer/BaseMap 坐标系统，并通过 ScenePort 和 MapManager 实现持久 Player 的淡入淡出切换。

## 依赖

- T04 completed。

## 交付范围

- `scenes/maps/farm/farm.tscn`、`field/field.tscn`、`beach/beach.tscn`，每张地图通过根节点下唯一的 `TileMaps` 容器集中管理自己的 TileMapLayer。
- `scenes/world/house.tscn` 与 `scripts/world/house.gd`，作为可复用的 farm 内房屋节点。
- `scenes/world/scene_port.tscn`。
- `scripts/world/base_map.gd`、`map_cell.gd`、`entity/entity.gd`、`scene_port.gd`，完善 MapManager。
- 原创占位 TileSet/tiles、地图 registry、地图切换集成测试。

## 实现要求

1. 三地图视觉和边界明显不同且尺寸大于单屏探索范围；farm 有大面积农地、道路与水塘，field 有山坡、资源区和不规则小径，beach 有沙滩与逐行变化的不规则海岸线。
2. TileMapLayer 直接挂在地图根节点的 `TileMaps` 容器下；TileMaps 保持 identity transform，Farm、Field、Beach 全部直接使用 BaseMap，并校验 tile size/transform/origin 对齐。
3. `cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 将每层全部 used cells 映射为可组合的静态 CellState；MapCell 持有 CellState、绑定 CellState 并负责运行时行为。
4. 静态地图 cell 必须绘制并序列化在 `.tscn` 中；Dug/Watered 投影层初始为空，只根据 CellState 的动态 flag 增删贴图，不得作为第二份状态权威。
5. 提供 world_to_cell、cell_to_world_center、get_cell_state、is_walkable、get_cells_in_rect 等 typed API。
6. ScenePort 通过 map_id/spawn_id 请求 MapManager；重复进入只提交一次。
7. MapManager 完成事务式锁输入/时间、写回当前 MapState、fade、替换 MapHost、恢复目标状态、放置 Player、解锁。
8. Camera limits 在地图 ready 时注入 Player Camera。转场第一帧不显示地图外空白。
9. 地图往返始终只有一个 Player、一个 HUD 和一组 Autoload；失败加载保留原地图。

## 自动化验收

- 三地图关键 world/cell 往返转换一致。
- 所有农事层对齐；每个 configured flag layer 的全部 used cells 都投影到 MapCell，同坐标的多个 flag 可组合。
- MapManager 忽略重复请求，失败时锁能释放且原地图仍存在。
- farm -> field -> beach -> field 后 Player instance 唯一、位置为目标 spawn。
- 三张地图均至少为 48x32 cells；field 的 HillLayer 与曲折 RoadLayer、beach 的 WaterLayer 与不规则 CoastLayer 均包含序列化 cell。

## 房屋实现要求

1. House 是可独立实例化并挂到任意 BaseMap 的 Node2D；不得使用 MapManager 切换地图。
2. 地板、墙和屋顶使用 House 自有 TileMapLayer，保持 identity transform，不加入 BaseMap.cell_flags。
3. 墙体碰撞只在明确的 Door 开口留出通道；Door 与 FloorLayer 同属地面层，不遮挡 Player。
4. InteriorArea 只响应 FarmPlayer；进入时隐藏 RoofLayer、放大相机并广播室内状态，离开时恢复。退出树时必须恢复。
5. 室内包含床、电视、壁炉等家具；家具不堵门，并通过统一交互协议接入 T15。
6. 新游戏从 farm 室外 default 点开始；只有穿过门进入 InteriorArea 后才触发室内逻辑。

## godot-ai 验收

用 input_sequence 让 Player 走入每个 ScenePort，完成 farm/field/beach 往返。每张地图截图一张，检查探索尺寸、field 山坡/小径、beach 海岸线、淡入结束、相机、碰撞和唯一 Player；日志无 orphan/重复 signal/缺 spawn。

## 不做

- 不实现翻地、浇水、环境随机生成或地图动态对象恢复细节。
- 不复制参考 Unity 地图或 TileSet。

## 完成记录

- 状态：completed（2026-08-17，Asia/Shanghai；探索地图与房屋前置结构修订）。
- 地图 registry：farm、field、beach 全部使用 BaseMap；房屋是 farm 内的可复用节点，不注册为独立地图。
- `BaseMap` 提供公共坐标、MapCell 索引、layer-status dictionary、范围、地图 Item 入口和层对齐 API；地图子类不再声明 Rect2i 区域配置。MapCell 是每格的运行时领域对象，不是场景转发组件。
- MapManager 已实现初始地图加载、输入/时间锁、Tween 淡入淡出、MapHost 替换、失败保留原地图和重复请求拒绝；ScenePort 只提交一次请求。
- 自动化：三张地图均包含序列化 `tile_map_data`，map transition fixture 完成 `farm -> field -> beach`，往返过程中 Player 数量始终为 1。
- 视觉验收目标：farm 房屋与农地、field 山坡/曲折小径、beach 不规则海岸线。
- 下一任务：T06 背包、Toolbar、Itembar 与手持物。
