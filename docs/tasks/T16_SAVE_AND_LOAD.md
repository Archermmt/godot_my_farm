# T16 版本化保存与读取

## 目标

把 Player、Inventory、Toolbar、Itembar、唯一手持来源、时间、全部 MapState、作物、动态 Item 和 NPC 写入版本化单槽 JSON，并能在运行中安全读取和重建当前地图。

## 依赖

- T12、T14、T15 completed。

## 交付范围

- 完成 GameManager 存档入口、所有状态 DTO 和 schema migration 框架。
- `user://saves/slot_0.json` 原子写入、备份/错误提示。
- quick_save/quick_load action 接入，默认 UI toast。
- save/load 单元、集成和损坏文件测试。

## 实现要求

1. 根结构遵循 [../02_ARCHITECTURE.md](../02_ARCHITECTURE.md)，`schema_version=1`，包含 saved_at/game_version。
2. 保存前要求当前 BaseMap 将 cells/items 同步到对应 MapState，NPC 将位置同步到全局 GameManager.npcs；snapshot 为深副本。
3. 写入同目录临时文件，flush/close 成功后再替换正式文件；已有正式文件可保留一个 `.bak`。
4. 保存期间阻止重复保存；失败发结构化错误和 UI 提示，不声称成功。
5. 读取流程为 parse -> schema validate -> migrate -> 构造临时状态 -> deep validate -> 整体 replace。任何失败都保留当前运行状态。
6. 未知字段忽略、缺省字段有明确策略；高于支持版本拒绝加载且不覆盖原文件。
7. 加载成功后 MapManager 按存档 map/spawn/position 重建，HUD/光照/Toolbar/Itembar/active hand/NPC 同步；Player/Autoload 不重复。
8. quick_load 在无存档时只提示；场景 transition/interaction transaction 中拒绝或排队，不并发破坏状态。
9. 测试使用独立 `user://tests/...` 路径或注入存储，不覆盖用户 slot_0。

## 自动化验收

- 包含每类状态的 save -> clear -> load 深度等价。
- JSON 类型正确，没有 NodePath、instance ID、UID、Texture 或 `Vector2(...)` 字符串。
- 损坏 JSON、截断文件、缺字段、未知字段、旧版本迁移、未来版本拒绝。
- 模拟临时写失败，正式文件仍可读；连续保存 10 次临时文件不累积。
- 加载失败前后的 GameManager 深度等价；加载成功后 Player/Map/NPC instance 唯一。

## godot-ai 验收

通过真实操作改变农田、作物、采集物、背包、时间、地图和 NPC，然后 quick_save；继续破坏状态后 quick_load。截图保存提示、改变后、恢复后，读取关键 snapshot 对比；重启项目再 load，确认磁盘持久化。检查两次 run 的 editor/game logs。

## 不做

- 不做多槽 UI、云同步、压缩或加密。
- 不直接序列化 Node/Resource 对象图。

## 完成记录

已完成 schema v1 单槽 JSON、原子写入与 `.bak` 备份、未来版本/损坏文件拒绝、加载失败原子回滚、quick_save/quick_load 快捷键与提示。GameManager 负责所有文件读写，MapManager 负责按存档中的 map/spawn 重建当前地图，并同步 Player/NPC 实例。自动化测试覆盖 round-trip、未来版本、损坏 JSON 和状态不变性。
