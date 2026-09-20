# T14 NPC 日程与跨地图导航

## 目标

实现至少三个 NPC 的数据驱动日程、当前地图路径移动和跨地图状态迁移，复现参考项目 NPC 原型的可见能力；新游戏 06:00 时 farm、field、beach 各有一个 NPC。

## 依赖

- T05、T11、T12 completed。

## 交付范围

- `scenes/actors/npcs/npc.tscn` 及原创占位角色。
- GameManager 根据 CalendarState 更新 NpcState 的日程目标；`FarmNpc` 自身负责移动、动画和目标刷新，NPC 场景挂载 Godot 原生 `NavigationAgent2D` 与 `AnimationPlayer`。
- 按 NPC 分组的 NpcSchedule Resource、地图 NPC portal graph 和独立 NPC 场景。
- schedule/path/map transition 单元与集成测试。

## 实现要求

1. Schedule 条目可按季节/月/星期过滤，含开始分钟、地图、目标世界位置和 behavior ID；同一 NPC 按开始时间选择最近的有效条目。
2. 到达目标后在以目标位置为中心的 wander_zone 内随机移动，等待时间不超过 wander_interval。
3. 当前地图导航使用 NPC 场景内的 Godot `NavigationAgent2D`；FarmNpc 不建立额外 navigator/controller 业务类。
4. 对角移动不可切阻挡拐角；NPC 使用 delta 移动、稳定朝向和 walk/idle 状态。
5. 日程时间到达时构建路径；游戏加载到事件中段时允许放置到可解释的估计位置，不要求重放全天每帧。
6. 跨地图通过 portal graph 更新 NpcState；仅当前地图实例可见，离场状态不丢且不需要隐藏的物理节点持续运行。
7. GameManager.npcs 以 npc_id 保持全局唯一；MapManager 仅重建 NpcState.map_id 对应当前地图的 NPC Actor。NPC 不使用 ItemState、MapState.items 或 BaseMap 的 Item host；地图往返和 save/load 不重复实例。
8. 路径不可达时 NPC 留在最近安全位置、记录一次 warning，并在下一日程/地图变化时重试，不死循环。

## 自动化验收

- 季节/星期过滤、按开始时间选择、目标位置和 wander_zone。
- NPC 场景原生 NavigationAgent2D、移动动画和不可达终止。
- `GameConfig.npc_schedules` 按 NPC id 分组，schedule id 在各组内唯一。
- 固定时间点计算相同 NPC map/target_position；地图切换实例唯一。
- 时间大步跳过多个事件时落到当前有效事件，不依次播放过时动作。
- 20 次地图往返和两次换日无重复 NPC/signal。

## godot-ai 验收

在两个受控时间点观察三名 NPC，用 input_sequence 跟随/阻挡测试路径，并触发至少一次 NPC 跨地图。新游戏开始后分别进入 farm、field、beach，确认每张地图恰有一名 NPC；截图每名 NPC 的两种位置，读取 NpcState map/cell/schedule ID，日志无 path spam 或穿障碍。

## 不做

- 不实现对话、好感、任务、表情或复杂群体避障。
- 不手写新的 A* 搜索算法。

## 完成记录

STATUS 记录 NPC IDs、schedule 摘要、路径断言、跨图结果、run_id 和截图；总表 T14 completed。
