# T04 地图、网格与场景切换

## 目标

创建 farm、field、cabin 三张原创占位地图，建立统一 TileMapLayer/BaseMap 坐标系统，并通过 ScenePort 和 SceneManager 实现持久 Player 的淡入淡出切换。

## 依赖

- T03 completed。

## 交付范围

- `scenes/maps/farm/farm.tscn`、`field/field.tscn`、`cabin/cabin.tscn`，每张地图直接管理自己的 TileMapLayer 层级。
- `scenes/world/scene_port.tscn`。
- `scripts/world/base_map.gd`、`map_cell.gd`、`entity/entity.gd`、`scene_port.gd`，完善 SceneManager。
- 原创占位 TileSet/tiles、地图 registry、地图切换集成测试。

## 实现要求

1. 三地图视觉和边界明显不同；至少 farm 有可挖区/道路/阻挡区，field 有资源区，cabin 有床和出口占位。
2. TileMapLayer 直接挂在地图根节点；Farm、Field、Cabin 全部直接使用 BaseMap，并校验 tile size/transform/origin 对齐。
3. `cell_flags: Dictionary[TileMapLayer, CellState.CellFlag]` 将每层全部 used cells 映射为可组合 flag；MapCell 绑定 CellState 并负责运行时行为。
4. 静态地图 cell 必须绘制并序列化在 `.tscn` 中；不得创建 Dug/Watered 等动态状态 TileMapLayer。
5. 提供 world_to_cell、cell_to_world_center、get_cell_state、is_walkable、get_cells_in_rect 等 typed API。
6. ScenePort 通过 map_id/spawn_id 请求 SceneManager；重复进入只提交一次。
7. SceneManager 完成事务式锁输入/时间、写回当前 MapState、fade、替换 MapHost、恢复目标状态、放置 Player、解锁。
8. Camera limits 在地图 ready 时注入 Player Camera。转场第一帧不显示地图外空白。
9. 地图往返始终只有一个 Player、一个 HUD 和一组 Autoload；失败加载保留原地图。

## 自动化验收

- 三地图关键 world/cell 往返转换一致。
- 所有农事层对齐；每个 configured flag layer 的全部 used cells 都投影到 MapCell，同坐标的多个 flag 可组合。
- SceneManager 忽略重复请求，失败时锁能释放且原地图仍存在。
- farm -> cabin -> farm 后 Player instance 唯一、位置为目标 spawn。

## godot-ai 验收

用 input_sequence 让 Player 走入每个 ScenePort，完成 farm/field/cabin 往返。每张地图截图一张，检查淡入结束、相机、TileMap、碰撞和唯一 Player；日志无 orphan/重复 signal/缺 spawn。

## 不做

- 不实现翻地、浇水、环境随机生成或地图动态对象恢复细节。
- 不复制参考 Unity 地图或 TileSet。

## 完成记录

- 状态：completed（2026-08-09，Asia/Shanghai；地图层级规则修订）。
- 地图 registry：farm、field、cabin 全部使用 BaseMap；item_hosts 按 ItemMeta.WorldType 配置 Plants/Harvestables/Items 等节点，ItemState 不保存重复类型。
- `BaseMap` 提供公共坐标、MapCell 索引、layer-status dictionary、范围、地图 Item 入口和层对齐 API；地图子类不再声明 Rect2i 区域配置。MapCell 是每格的运行时领域对象，不是场景转发组件。
- SceneManager 已实现初始地图加载、输入/时间锁、Tween 淡入淡出、MapHost 替换、失败保留原地图和重复请求拒绝；ScenePort 只提交一次请求。
- 自动化：`49 tests / 307 assertions`；三张地图均包含序列化 `tile_map_data`，map transition fixture 完成 `cabin -> farm -> cabin`，往返后 Player 数量为 1。
- 视觉证据：`screenshots/t04/cabin.png`、`screenshots/t04/farm.png`、`screenshots/t04/field.png`，均为 1280x720 Godot framebuffer。
- 下一任务：T05 背包、Toolbar、Itembar 与手持物。
