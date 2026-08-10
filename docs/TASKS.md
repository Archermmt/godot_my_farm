# 开发任务总表

## 1. 执行规则

- 严格按任务编号推进；只有表中依赖全部完成，任务才能进入 `in_progress`。
- 同一时刻最多一张任务为 `in_progress`。
- 开始任务时更新本表和 [STATUS.md](./STATUS.md)；完成时附上测试、run_id 和视觉证据。
- “代码已写”不等于完成。每张卡的自动化、运行、日志和截图验收全部通过后才标 `completed`。
- 如果环境/用户决策阻塞，只把任务标 `blocked` 并记录精确条件；不要跳过依赖继续下游。
- 修复当前任务引入的问题属于当前任务；新增玩法放入后续任务或先更新文档，不在实现中暗自扩 scope。

状态值：`pending`、`in_progress`、`blocked`、`completed`。

## 2. 任务表

| ID | 任务 | 依赖 | 阶段 | 状态 |
|---|---|---|---|---|
| T00 | [工具链与项目骨架](./tasks/T00_PROJECT_FOUNDATION.md) | - | A 基础 | completed |
| T01 | [定义与运行状态模型](./tasks/T01_DATA_AND_STATE.md) | T00 | A 基础 | completed |
| T02 | [Autoload 与应用启动](./tasks/T02_APP_SERVICES.md) | T01 | A 基础 | completed |
| T03 | [玩家移动、相机与动画状态](./tasks/T03_PLAYER_MOVEMENT.md) | T02 | B 核心切片 | completed |
| T04 | [地图、网格与场景切换](./tasks/T04_MAPS_AND_FARM_GRID.md) | T03 | B 核心切片 | completed |
| T05 | [背包、Toolbar、Itembar 与手持物](./tasks/T05_INVENTORY_TOOLBAR_ITEMBAR.md) | T03 | B 核心切片 | completed |
| T06 | [统一目标预览与蓄力交互](./tasks/T06_TARGETING_AND_INTERACTION.md) | T04, T05 | B 核心切片 | pending |
| T07 | [翻地与浇水](./tasks/T07_TILL_AND_WATER.md) | T06 | B 核心切片 | pending |
| T08 | [播种、成长与作物阶段](./tasks/T08_CROPS.md) | T07 | B 核心切片 | pending |
| T09 | [采集对象、掉落与拾取](./tasks/T09_HARVEST_AND_PICKUP.md) | T06, T08 | B 核心切片 | pending |
| T10 | [时间、状态、睡眠与光照](./tasks/T10_TIME_AND_DAY_CYCLE.md) | T08, T09 | C 活世界 | pending |
| T11 | [环境生成与地图状态恢复](./tasks/T11_WORLD_GENERATION.md) | T09, T10 | C 活世界 | pending |
| T12 | [HUD、背包界面、音频与特效](./tasks/T12_PRESENTATION.md) | T05, T09, T10 | C 活世界 | pending |
| T13 | [NPC 日程与跨地图导航](./tasks/T13_NPC_SCHEDULE.md) | T04, T10, T11 | C 活世界 | pending |
| T14 | [版本化保存与读取](./tasks/T14_SAVE_AND_LOAD.md) | T11, T13 | D 完整性 | pending |
| T15 | [完整流程集成与稳定性](./tasks/T15_INTEGRATION.md) | T12, T14 | D 完整性 | pending |
| T16 | [正式资源、可读性与许可清单](./tasks/T16_ASSET_AND_POLISH.md) | T15 | D 完整性 | pending |
| T17 | [发布检查与运行证明](./tasks/T17_RELEASE_PROOF.md) | T16 | D 完整性 | pending |

## 3. 里程碑

### M1 可运行架构（T00-T02）

主场景启动、Autoload 初始化、数据 catalog 校验、纯逻辑测试可执行。没有农事玩法，但工程结构和错误通道可靠。

### M2 核心农事闭环（T03-T09）

玩家可以在单张农场地图移动，用键盘管理 Toolbar、Itembar 和背包，翻地、播种、浇水、跨测试日成长、收获/破坏对象并拾取掉落。

### M3 活世界（T10-T13）

时间、光照、体力/睡眠、多地图、环境状态和 NPC 日程形成连续世界；UI、音频和反馈可清楚表达所有核心行动。

### M4 完整可交付版本（T14-T17）

状态可持久保存，首日流程可连续完成，资源许可明确，稳定性验收通过，并输出真实运行证明。

## 4. 用户决策点

- T00：如果没有 Godot/godot-ai，需安装或由用户提供可执行文件/已连接编辑器。
- T16：外部或付费资源生成前必须确认成本、许可和风格；用户拒绝付费时使用原创本地制作方案，不阻塞代码完整性。
- 任何任务需要改变 [00_GAME_DESIGN.md](./00_GAME_DESIGN.md) 的首版范围时，先向用户说明影响并更新文档。
