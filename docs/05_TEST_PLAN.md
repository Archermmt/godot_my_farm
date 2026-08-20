# 测试与验收计划

## 1. 质量门

每张任务卡按四层质量门验证：

1. **脚本/资源门**：Godot 能解析脚本和加载资源，编辑器 diagnostics 为零。
2. **领域逻辑门**：不依赖画面的纯 GDScript 测试通过，包含成功与失败路径。
3. **运行行为门**：真实主场景运行，通过输入序列完成任务指定行为，game/editor log 无错误。
4. **视觉门**：运行帧截图证明画面正确；动态任务验证开始、过程和结果状态。

只通过前一层不能跳过后一层。

## 2. 自动化测试结构

不引入第三方测试框架。T01 创建可从命令行运行的 `tests/test_runner.gd`，它扩展 `SceneTree`，加载测试套件、统计断言并以非零 exit code 表示失败。

目标命令：

```bash
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --import
godot --headless --path . --quit
```

若安装命令名是 `godot4` 或应用绝对路径，T01 记录到 STATUS，不在脚本里硬编码。

测试规则：

- 每个 `test_*` 至少一个断言；环境不满足时显式 skip 并说明原因。
- 比较存储后的实际类型和值，例如 JSON 恢复后 Vector2i、BackpackSlot amount、PlantState meta_id/growth_days。
- 随机行为固定 seed，并断言边界与确定结果。
- 测试结束清理 `user://` 下测试专用文件，不能覆盖真实 `slot_0.json`。
- 测试套件之间不共享可变 Autoload 状态；每个套件 reset 或构造独立实例。

## 3. 单元测试矩阵

| 模块 | 必测成功路径 | 必测失败/边界 |
|---|---|---|
| DataCatalog | ID 索引和交叉引用 | 重复 ID、缺失 crop/drop 引用 |
| BackpackState | 命名槽位、堆叠、交换、合并、移除 | 满包、不足数量、越界 slot |
| PlayerState | 体力/生命/金币上下限 | 负数和超过上限 |
| CellState/MapCell | DTO round-trip、status、翻地、浇水日、item_ids | 不可挖、重复 ID、坐标不匹配、占用冲突 |
| Targeting | 各蓄力范围和稳定顺序 | 地图边缘、阻挡、可用目标不足 |
| Action transaction | 体力/物品/地块一起提交 | 任一条件失败时全部不变 |
| ItemMeta/ItemState/Item | State 子类恢复、Meta/State/Item 强类型绑定、BaseMap 工厂、浇水后跨天成长 | 未知 meta_id、未知 state_type、Meta/State/host 不匹配、重复 ID |
| Harvest/HarvestableDrop | 工具匹配、生命、掉落 | 错工具、未死亡无掉落、min/max |
| GameManager 时间 | 分钟跨小时/日/月/年 | 大 delta、暂停 reason 叠加 |
| NpcSchedule | 季节/星期过滤和 fallback | 无匹配、跨午夜、加载中间时刻 |
| GameManager 存档 DTO | round-trip 等价 | 坏 JSON、未知版本、缺字段 |

## 4. 集成测试场景

### I01 Player 与 BaseMap

在 fixture map 中移动到指定格，验证世界坐标/map 坐标一致、碰撞阻挡、光标与面向方向匹配。

### I02 工具原子提交

装备锄头/水壶，以固定蓄力作用 1 格和多格；断言地块状态、体力、音画事件次数。体力不足时断言全部地块不变。

### I03 种植到收获

翻地、播种、浇水、推进多日、收获；检查种子数量、ItemState 阶段、产物、MapState DTO 和 BaseMap 运行时节点。

### I04 掉落到背包

破坏固定对象，生成固定掉落，Player 进入吸附半径；检查世界 Item 移除和 BackpackSlot 增加。满包时 Item 保留。

### I05 地图往返

修改 farm 状态 -> 经 ScenePort 到 field/beach -> 返回 farm；检查 Player 唯一、地块/Item 状态未重置，GameManager.npcs 中的 NPC 跨图位置正确且当前地图实例唯一，输入和时间锁已释放。

### I06 换日

设置 22:55 -> 推进到 23:00/换日流程；检查只加一天、回小屋、起床 06:00、体力恢复、已浇作物只成长一次。

### I07 NPC 日程

固定日期和 seed，推进到两个日程点；检查 NPC 路径不穿阻挡、在目标时刻附近到达，并能切换地图状态。

### I08 存档恢复

建立包含地块、作物、掉落、背包、时间、Player 和 NPC 的状态 -> 保存 -> 清空/重建 -> 加载；断言深度等价并运行当前地图。

## 5. godot-ai 端到端场景

每个 E2E 使用 InputMap action，不使用物理键值。动作时序用 `game_manage(op="input_sequence")` 固定 frame，并在序列后检查没有 action 遗留 pressed。

| E2E | 行为 | 可视检查 |
|---|---|---|
| E01 启动 | 从主场景进入小屋 | 非空、Player/HUD/时钟可见、无错误 |
| E02 移动和碰撞 | 四方向、对角、Shift 慢走、撞墙 | 动画/朝向正确，无抖动/穿墙 |
| E03 Toolbar/Itembar | 纯键盘切换 6 工具和种子 | Player 头顶对应 bar 高亮唯一、HUD/Hands 匹配、同一时间只有一个 active stack |
| E04 农事 | 翻地、播种、浇水 | 三种光标、TileMap 对齐、行动反馈明确 |
| E05 蓄力 | 按住到多级再释放 | 范围逐级扩大，只提交一次 |
| E06 采集 | 斧/镐/镰刀作用匹配对象 | 错工具无效，正确工具有受击/掉落/吸附 |
| E07 背包 | 打开、方向焦点、两段式按键交换、关闭 | 三容器类型约束、数量守恒、输入锁、tooltip 完整、无重叠、无鼠标事件 |
| E08 转场 | farm/field/beach 往返 | 淡出入、无闪帧/重复 Player、状态保留 |
| E09 换日成长 | 睡前到次日 | 光照/时钟变化，回小屋，作物阶段变化 |
| E10 NPC | 观察两个时间点 | NPC 可见、路径合理、无穿障碍 |
| E11 保存读取 | 改状态、保存、再加载 | 提示明确，恢复后场景与 UI 同步 |

## 6. 视觉验收视口

基础设计视口为 `640x360`，默认窗口 `1280x720` 整数放大。至少验证：

- `1280x720`：默认桌面窗口和最终证明画面。
- `960x540`：较小 16:9 窗口，检查容器和文字。
- 如果支持窗口自由缩放，再验证一个非整数窗口，确认 letterbox/缩放策略不会裁掉 UI。

截图需要人工/视觉检查：

- Camera2D 不显示场景外空白。
- TileMapLayer、光标、作物和掉落以同一格对齐。
- Player/NPC/树木 y-sort 正确，没有跨层突然遮挡。
- nearest filtering 生效，移动停止帧没有模糊边缘。
- HUD、Player 头顶 Toolbar/Itembar、背包三容器焦点、tooltip、转场层次正确，文字不截断。
- 状态颜色有足够对比，有效/无效目标不只靠色相区分。

## 7. 性能与稳定性

首版目标：默认地图和 100 个动态 Item 下，开发机保持稳定 60 FPS。验收时通过 editor monitor 或 Godot profiler 观察：

- 每帧没有全树搜索和资源加载。
- 空闲状态日志不持续增长。
- 地图往返 20 次后 Player、HUD、GameManager 时间状态和信号订阅数量不增长。
- 同一格重复无效操作 100 次不创建隐藏节点或重复音频播放器。
- 存档 10 次始终可读，临时文件不累积。

## 8. 最终证明

T17 输出 15-20 秒连续证明片段或等价的连续截图序列，至少包含：键盘移动 -> Toolbar/Itembar 选择 -> 翻地/播种/浇水 -> 采集掉落 -> 方向焦点背包交换 -> 转场/换日后的成长结果。

录制前固定 seed 和起始存档，删除所有 debug overlay，使用真实主场景。录制后必须回看，确认不是空帧、卡死、单帧循环、UI 遮挡或音画严重不同步。证明文件路径和运行日志写入 `STATUS.md`。
