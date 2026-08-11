# T10 时间、状态、睡眠与光照

## 目标

完成日历推进、时钟 HUD、体力/生命/金币状态、深夜/耗尽换日、回小屋起床、作物成长和室内外光照调度。

## 依赖

- T08、T09 completed。

## 交付范围

- 完善 GameManager 内的时间控制与 CalendarState。
- `scripts/world/day_cycle_controller.gd` 或等价应用协调器。
- Clock/PlayerStatus 最小 HUD；LightSchedule Resource 与地图光照节点。
- time/day-cycle 单元和集成测试。

## 实现要求

1. 现实时间按配置倍率转换为游戏分钟；HUD 每 5 游戏分钟刷新，但底层时间精确到分钟。
2. year/month/day/week_day/hour/minute 边界依次推进，30 天/月、12 月/年，季节从 month 派生；测试大 delta。
3. 到 23:00 只发起一次 end-day。体力或生命归零也请求同一协调流程，不能递归/重复加天。
4. 换日顺序遵循架构：记录 previous -> 日历加一天 -> crop/generator/NPC 更新 -> Player 恢复 -> SceneManager 到 cabin -> 06:00 醒来。
5. 工具/播种/采集使用统一 PlayerState.consume_energy；不足时行动原子失败。Food Item 可恢复体力但不超过上限。
6. inventory、scene_transition 等 pause reason 阻止时间 tick；解除顺序正确。
7. LightSchedule 数据定义时段颜色/能量，室外用 CanvasModulate/Light2D，室内使用独立 profile；时间跳跃后直接采样正确状态。
8. 受控推进时间只在 debug feature/test fixture 开启，不作为发行快捷键。

## 自动化验收

- 分钟跨小时/日/月/年、星期和季节边界；大 delta 不漏事件。
- 多个 end-day 请求同帧只推进一天。
- 已浇作物成长一次，未浇不成长；Player 恢复且 06:00 在 cabin。
- 工具体力恰好/不足、Food 上限。
- pause reason 叠加；加载 18:00 时光照直接正确，不从早晨补间。

## godot-ai 验收

运行时观察早晨/中午/傍晚/夜间四个受控时间截图；从 22:55 推进到换日，检查 cabin、06:00、状态条和作物阶段。日志确认 day_advanced 只一次，game/editor 无错误。

## 不做

- 不实现天气、季节作物限制或睡觉确认 UI。
- 不加入可由玩家滥用的发行时间作弊键。

## 完成记录

STATUS 记录时间倍率、边界测试、day 事件计数、run_id 和四时段/次日截图；总表 T10 completed。
