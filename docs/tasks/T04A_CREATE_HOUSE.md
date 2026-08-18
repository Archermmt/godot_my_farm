# T04A 创造房屋

## 目标

建立可复用的 House 节点并挂载到 farm。Player 在同一地图内从门进入房屋，屋顶隐藏、相机拉近；离开时恢复，不发生场景切换。

## 依赖

- T04 completed。

## 交付范围

- `scenes/world/house.tscn` 与 `scripts/world/house.gd`。
- House 内集中管理 FloorLayer、WallLayer、RoofLayer 三个 TileMapLayer、门洞碰撞、室内检测区和家具。
- Player 室内相机 API、室内状态事件，以及 farm 中的 House 实例。

## 实现要求

1. House 是可独立实例化并挂到任意 BaseMap 的 Node2D；不得使用 MapManager 切换地图。
2. 地板、墙和屋顶必须使用 TileMapLayer 绘制；House 自有 TileMaps 保持 identity transform，但不加入 BaseMap.cell_flags。
3. 墙体碰撞完整包围建筑，只在明确的 Door 开口留出通道，Player 不能穿墙进入。
4. Door 与 FloorLayer 使用相同地面绘制层级，不得用高 `z_index` 覆盖进入或离开房屋的 Player。
4. InteriorArea 只响应 FarmPlayer。进入时隐藏 RoofLayer，离开时恢复；退出树时必须恢复 Player 的室内相机状态。
5. Player 提供稳定的 `set_house_interior(active, zoom)` API，以 Tween 切换 Camera2D.zoom；House 不直接查找或改写 Player 的 Camera2D 子节点。
6. 室内包含床、电视、壁炉等可见家具节点；家具不得堵住门口通道。
7. 室内状态经 EventBus 通知天气光照和天气特效；室内不显示雨雪，离开后立即恢复当前天气表现。
8. 新游戏从 farm 的室外 default 点开始，屋顶可见且相机保持室外缩放；只有 Player 从门进入 InteriorArea 后才启动屋顶隐藏、室内光照和相机变焦。wake 点只用于日结。

## 自动化验收

- farm 包含 House 实例；House 的 FloorLayer、WallLayer、RoofLayer 均有序列化 tile。
- WallCollision 在门口留有可通行缺口，床、电视、壁炉节点存在。
- 模拟 Player 进入/离开时 RoofLayer 可见性和 Camera2D.zoom 正确切换，当前 map_id 不变且不发出 map_changed。
- House 被释放或 Player 离开时相机、屋顶与室内天气状态均恢复。
- 新游戏 Player 位于 House 外部，`is_inside_house()` 为 false，RoofLayer 可见，Camera2D.zoom 为室外值。

## godot-ai 验收

在 farm 从门进入房屋，截图屋顶隐藏与室内家具；验证相机平滑拉近。随后从门离开，截图屋顶和相机恢复。全程 current_map_id 保持 farm，日志无碰撞穿透、重复信号或 orphan。

## 完成记录

- 状态：completed（2026-08-17）。
- 下一任务：T05 背包、Toolbar、Itembar 与手持物。
