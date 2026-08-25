# 开发状态

## 当前状态

- 阶段：M3 活世界。
- 当前任务：[T15 场景物件、NPC 交互与对话气泡](./tasks/T15_INTERACTION_AND_DIALOGUE.md)（completed）。
- T11-T16 已完成时间、季节天气、状态显示、日结、环境生成、统一界面、音频与动作反馈、NPC 日程导航、场景物件/NPC 交互与对话，以及版本化保存与读取。
- 参考基线：`Archermmt/my_farm@bd808154b479f87efc4fc06ff42c683d7db351bc`。

## 已验证能力

- 已完成参考 Unity/C# 项目的代码级职责分析。
- 已固定 GDScript、Godot 场景/状态边界、任务依赖和验收流程。
- T01 已建立静态定义、纯 DTO 状态和序列化校验链路；MapState、CellState、ItemState 等状态对象不持有 Node、Texture、PackedScene、Callable 或 NodePath。
- 核心 catalog 包含 23 个物品、3 种作物/各 4 个成长阶段、4 个普通采集物、3 份 NPC 日程/7 个 event。
- BackpackState/BackpackSlot 支持命名槽位、堆叠、添加/移除、交换、合并、跨容器交换和选择；失败路径保持事务前状态。
- 所有存档状态提供纯 Dictionary `to_dict()` 与显式严格 factory，Vector2i 和 StringName 经 JSON round-trip 后恢复原类型。
- 已接入 7 个游戏 Autoload，顺序为 EventBus -> DataCatalog -> GameManager -> MapManager -> CalendarManager -> EffectManager -> AudioManager；除无配置的 EventBus 外均直接读取共享 `data/game_config.tres`，不保留空壳 Autoload 场景。
- `GameConfig` 集中内嵌 23 个 ItemMeta、3 份 NpcSchedule、默认 PlayerState、四季、音频和特效定义；GameManager 新游戏提供 6 个工具、欧洲防风草/南瓜/土豆种子、farm/default 室外起点、生命/体力/金币和三张空 MapState；新游戏 06:00 时 farm、field、beach 各有一名 NPC；`N` 键可开发期跳过一天，日结使用 farm/wake。
- GameManager 支持 start/stop、多个 pause reason、时间快照和统一存档入口；MapManager 管理 host 与转场输入阻断；CalendarManager 使用 Config 中的 SeasonMeta 确定月份归属、每日天气和全局 CanvasModulate；AudioManager 使用 Config 中的 18 个 AudioDefinition，通过四类 bus 和受限 player pool 播放音频，并随地图交叉淡化 ambient/music。
- T03 已建立唯一持久 Player leaf scene：CharacterBody2D、Capsule 碰撞、四向 Visual、Hands、InteractionOrigin 与 Camera2D；Main 只在 ActorHost 实例化一个 Player，并由 MapManager 拒绝重复注册。
- `player.gd` 单一根控制器集中处理 InputMap、多 reason 输入锁、对角归一化、移动碰撞、朝向、动画选择和 Camera2D limits；默认跑速 96、Shift 慢走 48，斜向朝向水平优先。Visual、Hands、碰撞、交互挂点和相机子节点不再挂角色业务脚本。
- Player 动画已改为 `AnimationPlayer` + `player_animations.tres`，包含 12 个可编辑的 idle/walk/run 四向动画；运行脚本不再设置 Sprite frame、维护动画相位或手写动画时钟。
- 原创占位角色图为 144x128、4 行 x 6 帧；T04 已接入原创占位 TileMap 和地图层，资源许可记录在 `assets/licenses/ASSETS.md`，T16 再完成正式美术替换与整体 polish。
- T03 重构：按单脚本角色规则合并 PlayerInput、PlayerMotor、PlayerVisual 到 `scripts/actors/player.gd`；旧脚本和场景组件已删除，Visual 仅保留无脚本 Sprite 容器，并新增场景契约防回退断言。
- T05 已建立 farm、field、beach 三张大尺寸探索地图，全部直接使用 BaseMap；field 包含山坡与不规则小径，beach 包含不规则海岸线。House 作为可复用节点挂入 farm，通过门洞、屋顶显隐和 Player 相机 API 实现同图室内外切换。
- T05-T17 已改为纯键盘交互规划：Toolbar 管理工具、Itembar 管理可选择非工具物品，Player 只有一个 active hand；背包使用方向焦点和两段式交换键，不再支持鼠标选择、使用、丢下或拖拽。
- T05 已完成统一 `BackpackState`/`BackpackSlot` 数据模型：命名槽位由 Dictionary 保存，Toolbar/Itembar 通过槽位 ID 数组组织，Backpack 提供 add/remove/switch API；InventoryState/ToolbarState/ItembarState/ItemStack 已删除。Q/E 和 Z/C 循环选择并切换唯一 active hand；Player 复用一个 HeldVisual，头顶短暂显示当前栏位，HUD 常驻显示手持来源和物品。
- 背包通过 P 打开，方向键/WASD 移动唯一焦点，X 标记并交换/合并，F 将栏位设为手持；工具与非工具类型约束、非法交换原子回滚及 `inventory` input/time lock 均已接入。
- T06 已建立统一 `EffectArea`；Player 场景持有并直接控制唯一的 EffectArea，EffectArea 从 PlayerState 读取交互输入状态，统一维护蓄力、计算并绘制 CellState preview，但不执行 release 动作。Player 通过子节点 PlayerBackpack 复用当前背包中的 Tool/Seed 运行时对象，释放 `use_held` 时由 Player 调用对象 use、扣体力/数量并发反馈。EffectArea 使用 top-level 变换保持世界格坐标稳定。`ToolMeta.charge_levels` 支持 1、3x1、3x3、9x3、9x9 目标形状。
- T07 已实现运行时 `Tool` 与结构化 `ToolOutcome`。Hoe/WateringCan 复用 MapCell 查询规则，每次事务固定扣除一次工具体力并原子写入 DUG/WATERED；重复操作不耗体力。BaseMap 使用无状态 `CellStateProjection` 绘制并可从 MapState 恢复，不创建动态 TileMapLayer。Farm 的 DIGGABLE 静态层使用专用图块，与不可耕地面明确区分。
- T09 已接通 Sickle/Basket/Pickaxe/Axe 到 Harvestable：工具验证、伤害、固定单次体力消耗、成熟 Plant 收获、确定 RNG 掉落、Tree -> Stump -> 清除和旧 instance ID 防重复结算均由结构化结果与 BaseMap 事务完成。
- T11 环境生成实现已完成：farm/field 各自挂载可在 Inspector 配置的 ItemsGenerator 子节点，以 world seed/map/epoch/salt 确定生成 tree/rock/grass，避开静态否决格和 SpawnPoints/Ports 安全区，并通过 BaseMap 事务写入普通 ItemState。MapState 保存 generation_epoch/initialized，地图恢复不重复生成。
- 可拾取物使用普通 ItemState/Item，资格由 ItemMeta.can_pickup 决定；BaseMap 按 Player 的 `pickup_radius` 返回候选，Item 必须在场景中预置 PickupArea，Area2D 信号和 Item 内部 trace Timer 共同控制追踪，Player 负责吸附、接触拾取、Itembar 优先入包并在成功后请求 Map 删除。Player 场景统一配置 trace_delay（drop=1 秒、harvestable=0.5 秒、generate=0）和指数 pickup_speed_curve。可拾取 Item 保留 CellState 引用但不阻塞播种/放置，`drop_held` 先创建世界 Item 再扣 Itembar。
- EffectManager 已作为脚本型全局服务注册，效果定义在 `data/game_config.tres` 中通过 Inspector 配置；调用方传入动态 host，动作反馈、碎屑、雨雪等效果不再依赖 Main 场景中的固定 EffectHost。
- 新游戏 farm 的 MapState 固定包含草、石、树和成熟欧洲防风草各一份，供 T09 键盘验收；运行节点统一挂入 BaseMap 的分类 Item host。

## 环境记录

- Godot：`/Users/tongmeng/Desktop/Godot.app/Contents/MacOS/Godot`，版本 `4.7.stable.official.5b4e0cb0f`，universal arm64/x86_64，已签名并 notarized。
- CLI：`/opt/homebrew/bin/godot` 指向上述已验证可执行文件。
- godot-ai：本地源码 `/Users/tongmeng/Desktop/codes/godot-ai`，提交 `d602a78322c66a24969f37f261e0364465cff464`，插件版本 `3.0.7`。
- Python 启动器：`/opt/homebrew/bin/uv`，版本 `0.9.22`。
- Codex 客户端：godot-ai `client_manage` 已写入 `~/.codex/config.toml` 并读回 `configured`；原配置备份为 `~/.codex/config.toml.pre-godot-ai-t00.bak`。

## 最近一次验证

- 日期：2026-08-17（Asia/Shanghai）。
- House 启动修复：清除 farm/field/beach 中 PackedScene 实例的重复子节点覆盖；新游戏固定从 farm/default 室外开始，House 在 MapManager 完成地图配置后才启用 InteriorArea，避免加载中间帧误触发相机 Tween。地图 fixture 验证初始屋顶可见/zoom=1.0，穿门进入后屋顶隐藏/zoom=1.5，离开恢复，并继续完成 farm -> field -> beach；原生 runner 为 127 tests / 19783 assertions。
- 日期：2026-08-17（Asia/Shanghai）。
- T05 探索地图与房屋：farm 48x34、field 56x38、beach 58x38；field 曲折道路跨越多个行坐标，beach 海岸线逐行变化。House 使用独立 Floor/Wall/Roof TileMapLayer、门洞墙体碰撞、InteriorArea、床/电视/壁炉，并在同一 farm 内驱动屋顶、Camera2D zoom、室内天光和天气特效显隐。旧室内独立地图已从 registry 和场景中移除；日结回到 farm/wake。资源 import、主场景 smoke、地图 fixture `farm -> field -> beach`、`git diff --check` 均通过；原生 runner 为 127 tests / 19773 assertions。
- 日期：2026-08-16（Asia/Shanghai）。
- Autoload 配置统一：所有 Manager 初始数据集中到 `data/game_config.tres`；Item/Season/Audio/Effect/NPC 定义和 PlayerState 模板以内嵌 Resource 编辑。6 个无固定子节点的 Manager 改为脚本 Autoload，删除空壳场景、7 个单项 Item Meta 文件和独立 PlayerState 模板；Config Dictionary 是唯一配置/查询源，仅保留月份索引、对象池和冷却记录等派生运行时数据。资源导入、主场景 smoke 和 `git diff --check` 通过，原生 runner 为 123 tests / 5275 assertions。
- T10 天气扩展：CalendarManager 作为第 6 个游戏 Autoload 接管全局 CanvasModulate；4 个 SeasonMeta 覆盖四季和 12 个月且每季默认天气权重合计 100。原生 runner 为 121 tests / 5227 assertions，覆盖配置拒绝、季节隔离、同 seed/日期确定性、换日单次 weather_changed、天气天光色调、室内中和和 HUD 文字边界；资源 import、主场景 smoke 与 `git diff --check` 通过。
- 日期：2026-08-14（Asia/Shanghai）。
- T12 自动化：资源 import、原生 runner、主场景冒烟和 `git diff --check` 均通过；AudioManager 定义 Dictionary 含 18 个事件，Music/Ambient/SFX/UI pool 上限分别为 2/2/10/4；连续 100 次脚步保持单事件最多 1 个实例，连续 50 次多格反馈保持最多 8 个 effect。
- T12 godot-ai：session `godot-my-farm@c274`，run `r121844889-5`，`helper_live=true`、运行错误为空，game log 仅包含正常启动信息；640x360 UI 读回 HUD 为 165x72，背包为 `(20,24)` / `600x312`，全部文字完整。实时 framebuffer 为 1920x1080、`stale_frame=false`；640x360 与 960x540 布局、夜间 CanvasModulate、Player 头顶固定提示已逐项检查，无重叠或残留 effect。
- T11 自动化：原生 runner 为 107 tests / 4811 assertions；覆盖 farm/field 配置、seed 确定性、格子 flag、安全区、生成标签、无合法格有限退出、完整状态恢复和 20 次地图恢复不增殖。Godot 资源扫描、主场景运行和 `git diff --check` 通过。
- T11 godot-ai：session `godot-my-farm@c274`；farm 生成 23/23，field 生成 41/44（3 个受最小距离约束跳过），运行错误为空；farm/field 1280x720 framebuffer 均为实时非空画面，`stale_frame=false`。
- 日期：2026-08-11（Asia/Shanghai）。
- T07 自动化：原生 runner 为 82 tests / 4340 assertions；覆盖可用性与跳过原因、体力 0/少 1/恰好边界、9x9 最大蓄力固定单次消耗、多格原子性、可耕地专用 tile、事实/反馈信号、EffectArea 委托、WATERED 清除以及 farm MapState JSON 往返和投影重建。资源 import、主场景启动和 `git diff --check` 均通过。
- 日期：2026-08-10（Asia/Shanghai）。
- T05 自动化：资源 import、runner、键盘背包 fixture、地图往返 fixture、玩家碰撞 fixture、主场景 quit 和 `git diff --check` 全部 exit 0；runner 为 63 tests / 3936 assertions。
- T05 键盘流程：`InventoryKeyboardTest` 验证 Toolbar/Itembar 切换、Player 头顶提示、唯一 HeldVisual、空栏清手、非法 tool -> Itembar 回滚、Toolbar/Itembar -> Inventory 交换以及锁释放，输出 `PASS | toolbar/itembar/head-ui/swap/locks`。
- T05 视觉：`screenshots/t05/inventory.png` 为 1280x720 Godot framebuffer；6 格 Toolbar、10 格 Itembar、20 格 Inventory、焦点高亮、物品详情和手持 HUD 完整可见，无裁切或重叠。
- 日期：2026-08-08（Asia/Shanghai）。
- T05 地图回归：farm 48x34、field 56x38、beach 58x38，静态 cells 均序列化进 `.tscn`。House 包含 TileMap 地板/墙/屋顶、门洞碰撞、床、电视和壁炉，进入/离开在同一 farm 内切换屋顶、相机和室内天气状态。
- T03 AnimationPlayer 回归：runner 为 44 tests / 256 assertions；import、runner、碰撞 fixture、主场景 quit 全部 exit 0。godot-ai session `godot-my-farm@9455`，run `r7840807-7`，`AnimationPlayer.current_animation` 经实机读回为 `idle_down` -> `idle_right` -> `idle_left`，输入序列的 `actions_pressed_at_end=[]`，game run `current_run_errors=[]`、editor errors 0；截图为 `screenshots/t03/animation_player.png`（1920x1080，stale_frame=false）。
- T03 单脚本重构回归：runner 为 44 tests / 250 assertions；import、runner、碰撞 fixture、主场景 quit 全部 exit 0。godot-ai session `godot-my-farm@9455`，run `r6133040-6`，fixture live/helper_live=true，运行层级无 PlayerInput/PlayerMotor，输入序列右移 30 帧到 x=504.00，actions_pressed_at_end=[]，截图 `screenshots/t03/single_script_player.png`（1920x1080，stale_frame=false）。
- T03 自动化：`godot --headless --path . --import`、原生 test runner、碰撞 fixture、`godot --headless --path . --quit` 全部 exit 0；runner 为 44 tests / 250 assertions，碰撞从 x=480.00 停在 x=594.00（wall limit 594.10）。
- T03 godot-ai：session `godot-my-farm@9455`，run `r4355557-5`，fixture 状态 `live`、`helper_live=true`；game log 只有 helper 注册信息，editor errors 0。右/左/上/下、对角和 walk_modifier 均由 `input_sequence` 驱动且每组 `actions_pressed_at_end=[]`；30 帧跑步位移约 24 px、慢走约 12 px，2:1 比例成立；右下对角保持 `facing=right`。
- T03 视觉：`screenshots/t03/facing_right.png`、`facing_left.png`、`facing_up.png`、`facing_down.png` 和 `collision_right.png` 均为 640x360 实时 framebuffer，`stale_frame=false`；角色四向可辨、像素清晰、HUD 无裁切，撞墙画面中 Player 紧贴红色 StaticBody2D 且未穿透。补充证据为 `diagonal_down_right.png` 与 `walk_right.png`。
- T03 godot-ai 工具链：PyPI `godot-ai==3.0.7` 服务端尚未暴露本地插件已有的 `input_sequence` op；验收时切换为 `/Users/tongmeng/Desktop/codes/godot-ai@d602a78` 本地 Python 源码服务，编辑器和运行游戏保持连接，未修改运行时项目依赖。
- T02 自动化：`godot --headless --path . --import`、原生 test runner、`godot --headless --path . --quit` 全部 exit 0；runner 为 37 tests / 204 assertions。
- T02 godot-ai：session `godot-my-farm@9455`，autoload list 读回 7 个游戏服务且顺序正确（总数 8 含开发 helper）；run `r359758-4` 状态 `live`、`helper_live=true`、`current_run_errors=[]`，editor/game 增量日志均为空。
- T02 视觉：`screenshots/t02/app_services_ready.png`（640x360 game framebuffer）显示 APPLICATION READY、catalog、新游戏状态、7/7 services 和 hosts registered；文字无裁切或越界。
- T01 自动化：`godot --headless --path . --import`、原生 test runner、`godot --headless --path . --quit` 全部 exit 0；runner 为 23 tests / 108 assertions。
- T01 catalog fixture：godot-ai run `r1899847-4`，`autosave=false`；catalog 已迁移为 PlantMeta 继承 HarvestableMeta；当前核心数据为 plants=1、harvestables=4（包含 Plant）。
- T02 主场景回归：godot-ai run `r1925183-5`，状态 `live`、`helper_live=true`、`current_run_errors=[]`；游戏日志正常输出项目启动信息。
- T01 diagnostics：首次 editor scan 分两轮注册 20 个互相依赖的 `class_name`；第二轮后 global class count 68，fixture 和主场景的增量 editor/game errors 均为 0，无 class_name 冲突或循环 preload。
- T01 自动化：`godot --headless --path . --import`、原生 test runner、`godot --headless --path . --quit` 全部 exit 0；runner 为 1 test / 2 assertions。
- T01 项目：主场景以 Compatibility/OpenGL 启动，InputMap 21 个 action 均有绑定。
- T01 godot-ai：session `godot-my-farm@eae2`，plugin/server 均为 3.0.7，43 tools；hierarchy 31 nodes；run `r94834-1` 状态 live、helper_live=true，editor errors 0，game errors 0。
- T01 视觉：`screenshots/t00/godot_ai_game.png`（640x360 原生 framebuffer）和 `screenshots/t00/runtime_1280x720.png`（1280x720 实际运行帧）均已人工检查，非空、无裁切/重叠/模糊。
- 文档：29 个 Markdown 文件均为单一 H1、代码围栏成对、相对链接可解析。
- 任务：T01-T19 共 19 张任务卡与总表一一对应，依赖按拓扑顺序排列；地图与房屋、NPC 日程与交互对话分别合并到 T05、T15。
- 基线：已核对 my_farm、Godogen 和 godot-ai 的固定提交 ID，以及 GDScript/C# 技术边界。

## 已知问题

- 当前 Codex 进程启动时未加载新 MCP 配置，因此 T01 通过官方 FastMCP Client 调用了同一服务；下一次新任务/客户端重载后会直接暴露 godot-ai tools。
- PyPI `godot-ai==3.0.7` 的 Python tool schema 落后于当前本地源码，缺少 `game_manage(input_sequence)`；需要帧序列验收时继续使用已记录提交的本地源码服务，或在上游发布包含该 op 的版本后升级。
- Godot 4.7 的 dummy headless renderer 在 `--headless --write-movie` 下崩溃；规定的 headless import/test/quit 均正常，视觉录制使用非 headless movie writer 或 godot-ai game screenshot。
- 正式美术/音频来源尚未决定，T16 前必须确认许可和生成成本。

## 任务交接模板

每完成一张任务卡，替换/更新以下内容：

```text
当前任务：Txx（completed/blocked）
改动摘要：
自动化验证：命令 + 通过/失败数量
godot-ai：session_id + run_id + editor/game log 结论
视觉证据：绝对路径 + 画面说明
已知问题：
下一任务：
```
