# T11 时间、天气、状态、睡眠与光照

## 目标

完成日历推进、季节天气、时钟 HUD、体力/生命/金币状态、深夜/耗尽换日、回小屋起床、作物成长和室内外天光调度。

## 依赖

- T09、T10 completed。

## 交付范围

- 完善 GameManager 内的时间控制与 CalendarState。
- 脚本型 `CalendarManager` Autoload：从 `GameConfig` 读取配置，负责每日天气选择和全局 CanvasModulate 天光。
- Inspector 可配置的 `SeasonMeta`：每个 `SeasonType` 一份，记录天气选择权重和天光色调。
- 常驻“游戏状态 + 人物状态”显示面板：同一面板显示日期、时间、季节、天气、生命、体力、金币和手持状态，并随运行时状态实时更新。
- time/weather 单元和集成测试。
- clear、cloudy、rain、storm、snow 天气图标及状态面板图标显示。
- clear、cloudy 天气在地图地面显示可配置的云影；cloudy 使用更大的云影数量、尺寸和透明度。
- rain、storm 天气使用独立可编辑的雷电场景，间歇性显示闪电并对当前视口进行短暂全屏闪白；室内和天气效果停止时不触发。

## 实现要求

1. 现实时间按配置倍率转换为游戏分钟；HUD 每 5 游戏分钟刷新，但底层时间精确到分钟。
2. year/month/day/week_day/hour/minute 边界依次推进，30 天/月、12 月/年；CalendarState 按每三个月一个季节直接计算 `SeasonType`；测试大 delta。
3. 到 23:00 只发起一次 end-day。体力或生命归零也请求同一协调流程，不能递归/重复加天。
4. 换日顺序遵循架构：记录 previous -> iris 收缩至全黑 -> MapManager 加载 farm 并定位 House wake 点 -> 日历推进到次日 06:00 -> crop/generator/NPC、cell/weather 与贴图更新 -> Player 恢复 -> iris 展开。
5. 工具/播种/采集使用统一 PlayerState.consume_energy；不足时行动原子失败。Food Item 可恢复体力但不超过上限。
6. inventory、scene_transition 等 pause reason 阻止时间 tick；解除顺序正确。
7. `CalendarManager` 根节点使用 CanvasModulate，统一拥有早晨、中午、傍晚、夜间天光颜色；室内使用中和混合，时间跳跃后直接采样正确状态，不从旧时段补间。
8. 每天开始时仅从当前 `SeasonMeta` 的天气权重中按正权重随机选择一次天气；配置必须覆盖四季和 12 个月，重复季节、重复月份、空候选和非正权重在启动时拒绝。
9. 天气抽取使用 world seed、日期和可配置 salt，保证同一存档日期重复加载得到同一天气；当日天气不复制进 CalendarState。
10. `weather_changed` 只通知天气事实；地图和 HUD 查询 CalendarManager，禁止各自重复选择天气。CalendarManager 不搜索业务场景树。
11. 受控推进时间只在 debug feature/test fixture 开启，不作为发行快捷键。
12. `GameConfig.weather_icons` 使用天气 ID 到 Texture2D 的 Dictionary，覆盖所有 SeasonMeta 候选天气；状态面板通过 CalendarManager 查询当前图标，不以天气文字代替。
13. 换日必须使用以 Player 屏幕位置为圆心的 iris 转场：圆形可见区先收缩至全黑，全黑后才推进 game/map/cell/weather 状态并刷新贴图；Player 返回 farm House 的床边 `wake` 点且室内状态稳定后，再以新位置为圆心展开黑幕。转场期间锁定输入并暂停时间，重复换日请求不能叠加。

## 自动化验收

- 分钟跨小时/日/月/年、星期和季节边界；大 delta 不漏事件。
- 多个 end-day 请求同帧只推进一天。
- 已浇作物成长一次，未浇不成长；Player 恢复且 06:00 在 farm House。
- 工具体力恰好/不足、Food 上限。
- pause reason 叠加；加载 18:00 时光照直接正确，不从早晨补间。
- 四季配置均有候选、12 个月均有唯一季节归属且权重独立；同 seed/日期结果稳定，不会跨季节选中候选。
- 天气色调参与室外天光；进入 House 后同一时间颜色更接近中性白且雨雪隐藏；HUD 随天气信号更新。
- 晴天/阴天云影可见且阴天覆盖更大；雨天/暴雨间歇性闪电，闪电时场景短暂变亮，窗口尺寸变化不裁切闪屏。
- 每个候选天气都有非空图标；天气变化后 HUD WeatherIcon 实时切换且无旧图残留。
- 换日请求发出后、iris 完全闭合前日期与地块不变；黑屏期间完成状态切换，展开时 Player 已位于床边且时间为 06:00。IrisOverlay 使用独立 ShaderMaterial，不与普通地图淡入淡出共用材质。

## godot-ai 验收

运行时观察早晨/中午/傍晚/夜间四个受控时间截图；从 22:55 推进到换日，截取 iris 收缩中、全黑、床边展开中三个阶段，检查 farm House、06:00、天气字段、天光色调、状态条和作物阶段。连续跳过数日确认每日只选择一次天气且符合当前季节候选。日志确认 day_advanced/weather_changed 各自只发生一次，game/editor 无错误。

## 不做

- 不实现降雪粒子、地面积雪、天气音频、天气对作物的加成、季节作物限制或睡觉确认 UI；降雨粒子由 T12 的 EffectManager 负责。
- 不加入可由玩家滥用的发行时间作弊键。

## 完成记录

STATUS 记录时间倍率、季节天气权重、day/weather 事件计数、run_id 和四时段/次日截图；总表 T11 completed。

任务完成标准包含生成并配置全部候选天气图标，以及状态面板实际渲染图标的自动化和截图证据。
