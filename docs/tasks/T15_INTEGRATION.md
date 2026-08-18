# T15 完整流程集成与稳定性

## 目标

以 [../00_GAME_DESIGN.md](../00_GAME_DESIGN.md) 的首日闭环为主线整合全部系统，修复跨模块状态、输入、信号和生命周期问题，并完成压力与回归检查。

## 依赖

- T12、T14 completed。

## 交付范围

- 完整新游戏初始布局/物品/出生点与可完成的首日路径。
- [../05_TEST_PLAN.md](../05_TEST_PLAN.md) I01-I08、E01-E11 的自动化/可复现脚本或记录。
- 稳定性、性能、回归修复；`tests/fixtures/first_day_state.json` 等确定 fixture。
- 更新游戏内必要的状态提示，不增加教程长文。

## 实现要求

1. 新游戏无需 Debug 指令或鼠标即可完成：起床 -> farm -> Toolbar 选工具 -> 翻地 -> Itembar 选种子 -> 播种 -> Toolbar 选水壶 -> 浇水 -> 采集 -> 键盘整理背包 -> 次日成长 -> 成熟收获 -> NPC 观察 -> save/load。

2. 整个首日流程只注入键盘 InputMap action；选择、使用、丢下、Toolbar/Itembar 切换及三容器交换不得依赖鼠标事件。
3. 初始 seed、种子、体力、地图资源和作物成长天数平衡到 10-15 分钟开发验收可完成；正式时间倍率仍可配置。
4. UI panel、工具 charging、MapManager 和 GameManager 时间锁定不会死锁或提前解除。
5. preview、commit、音画反馈和存档状态对每种行为一致；错误工具、无体力、满包、无存档都有清楚反馈。
6. 地图切换、换日、save/load 过程中没有重复 Player/HUD/NPC、重复 signal、orphan Node 或未停止 tween/audio。
7. 清除所有临时 debug key、测试 label、无用 placeholder summary；必要 DevHooks 默认关闭。
8. 性能满足 Test Plan：100 动态 Item 稳定，20 次转场无增长，日志空闲不刷屏。
9. 修复严格限制在回归根因，不借整合任务重写稳定模块；架构改变先更新文档。

## 自动化验收

- 全部 unit/integration test 通过，零 skip 或每个 skip 有已批准环境原因。
- first-day fixture E2E 可重复执行两次，状态摘要一致。
- 20 次地图往返、100 次无效 action、10 次 save、2 次换日和 100 Item 压力测试通过。
- project import/headless quit 无错误，editor/game logs 无新增错误/警告。

## godot-ai 验收

使用一组 frame-timed action sequence 完成首日闭环，分段记录 run_id 和关键 state snapshot。截图覆盖 E01-E11；检查两种视口、性能 monitor、editor/game logs。任何仅靠 game_eval 修改状态的路径不算通过。

## 不做

- 不加入商店、对话、畜牧等新系统。
- 不以减少验收步骤或吞 warning 的方式“修复”问题。

## 完成记录

STATUS 写完整回归表、失败路径、性能数据、run_id 和截图索引；总表 T15 completed。
