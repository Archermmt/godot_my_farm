# T04 地图、网格与场景切换

## 目标

创建 farm、field、cabin 三张原创占位地图，建立统一 TileMapLayer/FarmSystem 坐标系统，并通过 ScenePort 和 SceneRouter 实现持久 Player 的淡入淡出切换。

## 依赖

- T03 completed。

## 交付范围

- `scenes/maps/farm/farm.tscn`、`field/field.tscn`、`cabin/cabin.tscn`。
- `scenes/world/farm_system.tscn`、`scene_port.tscn`。
- `scripts/world/farm_system.gd`、`scene_port.gd`，完善 SceneRouter。
- 原创占位 TileSet/tiles、地图 registry、地图切换集成测试。

## 实现要求

1. 三地图视觉和边界明显不同；至少 farm 有可挖区/道路/阻挡区，field 有资源区，cabin 有床和出口占位。
2. FarmSystem 包含 Base/Dug/Watered TileMapLayer、CropRoot、EntityRoot、Cursor 挂点，并校验 tile size/transform/origin 对齐。
3. 静态 flags 来自地图数据；动态 FarmCellState 由 FarmSystem 查询/修改，TileMapLayer 不作为唯一权威。
4. 提供 world_to_cell、cell_to_world_center、get_cell_state、is_walkable、get_cells_in_rect 等 typed API。
5. ScenePort 通过 map_id/spawn_id 请求 SceneRouter；重复进入只提交一次。
6. SceneRouter 完成事务式锁输入/时间、写回当前 MapState、fade、替换 MapHost、恢复目标状态、放置 Player、解锁。
7. Camera limits 在地图 ready 时注入 Player Camera。转场第一帧不显示地图外空白。
8. 地图往返始终只有一个 Player、一个 HUD 和一组 Autoload；失败加载保留原地图。

## 自动化验收

- 三地图关键 world/cell 往返转换一致。
- 所有农事层对齐；地图边界和 static flag 查询正确。
- SceneRouter 忽略重复请求，失败时锁能释放且原地图仍存在。
- farm -> cabin -> farm 后 Player instance 唯一、位置为目标 spawn。

## godot-ai 验收

用 input_sequence 让 Player 走入每个 ScenePort，完成 farm/field/cabin 往返。每张地图截图一张，检查淡入结束、相机、TileMap、碰撞和唯一 Player；日志无 orphan/重复 signal/缺 spawn。

## 不做

- 不实现翻地、浇水、环境随机生成或地图动态对象恢复细节。
- 不复制参考 Unity 地图或 TileSet。

## 完成记录

STATUS 记录地图 registry、往返输入序列、实例数量、run_id 和 3 张截图；总表 T04 completed。

