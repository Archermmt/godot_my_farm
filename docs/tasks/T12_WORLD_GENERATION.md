# T12 环境生成与地图状态恢复

## 目标

实现参考成品的 Generator/ItemManager 等价能力：按区域和标签生成环境对象，并在地图切换、换日和重建后保持稳定、不重复、不丢失。

## 依赖

- T10、T11 completed。

## 交付范围

- `scripts/world/item_generator.gd`、地图 Generator 子节点与候选值 Resource。
- farm/field 的生成区域、候选定义和稳定 spawn ID。
- MapState snapshot/restore 完整链路。
- generation/map persistence 测试。

## 实现要求

1. `candidates` 使用 Item ID 到 Candidate 的 Dictionary；每个 Candidate 自己配置 required flags、数量/密度和最小距离。farm/field 通过隐藏的 GenerateLayer 标记生成区域，道路、房屋、水塘等物理阻挡不带 GENERATE。
2. RNG 由 new-game seed + map ID + generation epoch 派生；同一初始状态结果可重现。
3. 只在 `generator_initialized=false` 时执行初始生成；地图往返不能再次叠加。
4. 生成前检查格子可放置、无占用、无 ScenePort/Player spawn/静态障碍；失败候选有最大尝试次数。
5. 每个生成 Item 有稳定 instance ID 和 meta_id；ItemState 基类保存共有状态，HarvestableState/PlantState 分别保存 health 或成长进度等专属实例状态，手工静态 Item 与生成 Item 区分。
6. 地图卸载前 BaseMap 将 cell/item 状态写回 MapState；恢复时由 ItemFactory 创建一次并注册占用。NPC 状态不进入 MapState。
7. 被采集对象保持消失，未拾取掉落保持存在，树桩/作物阶段保持；地图切换不推进时间。
8. 换日再生若启用，使用明确配置与 generation epoch，只补允许对象，不重置整图。

## 自动化验收

- 固定 seed 生成坐标/类型一致，不同 seed 有差异且都满足约束。
- 地图往返 20 次 Item ID 集合和数量不增长。
- 采集一个、留下一个 Pickup、改变一个 Plant/Tree 后往返，全部状态准确恢复。
- 满地图/无合法候选时有限退出并给出 summary，不死循环。
- ScenePort/spawn 周围安全区无生成物。

## godot-ai 验收

截取 farm/field 首次生成画面，采集/留下掉落后往返，再截恢复画面。运行时对比 item IDs/count；进行多次快速往返并检查节点/信号/性能 monitor 不增长，日志无重复 ID/占用冲突。

## 不做

- 不实现复杂生态、季节生成表或地图编辑器 UI。
- 不通过删除整个地图 Item 容器简化状态保存。

## 完成记录

STATUS 记录 seed、初始/恢复 Item 摘要、20 次往返结果、run_id 和截图；总表 T12 completed。

2026-08-14 实现记录：

- farm/field 已分别挂载可编辑的 `ItemGenerator` 子节点，候选为 tree/rock/grass；固定 seed 由 world seed、map ID、generation epoch 与 salt 派生。
- MapState 新增并序列化 `generation_epoch`；首次加载后设置 `generator_initialized`，地图恢复不再生成。启用 `regenerate_daily` 时只追加新 epoch 对象。
- 自动化覆盖同 seed、不同 seed、Candidate required flags、GenerateLayer、安全区、满地图有限退出、生成标签、状态深恢复以及 20 次恢复不增殖。
- 原生 runner：107 tests / 4811 assertions；Godot 资源扫描和 `git diff --check` 通过。
- godot-ai session `godot-my-farm@c274`：farm seed `12031992` 生成 23/23，field 生成 41/44（3 个受最小距离约束跳过）；两张 1280x720 实时截图 `stale_frame=false`，运行错误为空。
