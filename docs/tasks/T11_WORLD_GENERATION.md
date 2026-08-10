# T11 环境生成与地图状态恢复

## 目标

实现参考成品的 Generator/ItemManager 等价能力：按区域和标签生成环境对象，并在地图切换、换日和重建后保持稳定、不重复、不丢失。

## 依赖

- T09、T10 completed。

## 交付范围

- `scripts/world/world_generator.gd` 与生成配置 Resource。
- farm/field 的生成区域、候选定义和稳定 spawn ID。
- MapState snapshot/restore 完整链路。
- generation/map persistence 测试。

## 实现要求

1. 生成配置包含地图、允许区域/static flags、对象候选、数量/密度、最小距离和 seed salt。
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

STATUS 记录 seed、初始/恢复 Item 摘要、20 次往返结果、run_id 和截图；总表 T11 completed。
