# 开发状态

## 当前状态

- 阶段：M2 核心农事闭环。
- 当前任务：[T05 背包、快捷栏与手持物](./tasks/T05_INVENTORY_AND_HOTBAR.md)（pending）。
- 下一任务：[T05 背包、快捷栏与手持物](./tasks/T05_INVENTORY_AND_HOTBAR.md)。
- 参考基线：`Archermmt/my_farm@bd808154b479f87efc4fc06ff42c683d7db351bc`。

## 已验证能力

- 已完成参考 Unity/C# 项目的代码级职责分析。
- 已固定 GDScript、Godot 场景/状态边界、任务依赖和验收流程。
- T01 已建立静态定义、纯 DTO 状态和序列化校验链路；MapState、CellState、EntityState 等状态对象不持有 Node、Texture、PackedScene、Callable 或 NodePath。
- 核心 catalog 包含 12 个物品、1 种作物/4 个成长阶段、3 个采集物、4 张掉落表/4 个 entry、1 份 NPC 日程/1 个 event，共 30 个 Resource 记录。
- InventoryState 支持固定容量、堆叠、添加/移除、交换、合并、跨容器交换和选择；失败路径保持事务前状态。
- 所有存档状态提供纯 Dictionary `to_dict()` 与显式严格 factory，Vector2i 和 StringName 经 JSON round-trip 后恢复原类型。
- T02 已接入 7 个游戏 Autoload，顺序为 EventBus -> DataCatalog -> GameState -> TimeManager -> SceneManager -> SaveManager -> AudioManager；godot-ai 的 `_mcp_game_helper` 是开发期附加服务，不属于游戏服务。
- DataCatalog 使用显式 `core_catalog.tres`，GameState 新游戏提供 6 个工具、15 个欧洲防风草种子、cabin/wake 起点、生命/体力/金币和三张空 MapState。
- TimeManager 支持 start/stop、多个 pause reason 和安全 reset；SceneManager host 注入、SaveManager snapshot、AudioManager 播放 API 在未到对应任务时返回明确 `ERR_UNAVAILABLE`。
- T03 已建立唯一持久 Player leaf scene：CharacterBody2D、Capsule 碰撞、四向 Visual、Hands、InteractionOrigin 与 Camera2D；Main 只在 ActorHost 实例化一个 Player，并由 SceneManager 拒绝重复注册。
- `player.gd` 单一根控制器集中处理 InputMap、多 reason 输入锁、对角归一化、移动碰撞、朝向、动画选择和 Camera2D limits；默认跑速 96、Shift 慢走 48，斜向朝向水平优先。Visual、Hands、碰撞、交互挂点和相机子节点不再挂角色业务脚本。
- Player 动画已改为 `AnimationPlayer` + `player_animations.tres`，包含 12 个可编辑的 idle/walk/run 四向动画；运行脚本不再设置 Sprite frame、维护动画相位或手写动画时钟。
- 原创占位角色图为 144x128、4 行 x 6 帧；T04 已接入原创占位 TileMap 和地图层，资源许可记录在 `assets/licenses/ASSETS.md`，T16 再完成正式美术替换与整体 polish。
- T03 重构：按单脚本角色规则合并 PlayerInput、PlayerMotor、PlayerVisual 到 `scripts/actors/player.gd`；旧脚本和场景组件已删除，Visual 仅保留无脚本 Sprite 容器，并新增场景契约防回退断言。
- T04 已建立 farm、field、cabin 三张独立地图，全部直接使用 BaseMap；MapState 保存 CellState/EntityState DTO，BaseMap 管理 MapCell/Entity 运行时对象并按 EntityState.type 路由 host；ScenePort/SceneManager 支持持久 Player 的事务式往返切换。

## 环境记录

- Godot：`/Users/tongmeng/Desktop/Godot.app/Contents/MacOS/Godot`，版本 `4.7.stable.official.5b4e0cb0f`，universal arm64/x86_64，已签名并 notarized。
- CLI：`/opt/homebrew/bin/godot` 指向上述已验证可执行文件。
- godot-ai：本地源码 `/Users/tongmeng/Desktop/codes/godot-ai`，提交 `d602a78322c66a24969f37f261e0364465cff464`，插件版本 `3.0.7`。
- Python 启动器：`/opt/homebrew/bin/uv`，版本 `0.9.22`。
- Codex 客户端：godot-ai `client_manage` 已写入 `~/.codex/config.toml` 并读回 `configured`；原配置备份为 `~/.codex/config.toml.pre-godot-ai-t00.bak`。

## 最近一次验证

- 日期：2026-08-08（Asia/Shanghai）。
- T04 地图回归：runner 为 49 tests / 314 assertions；三张地图的静态 cells 已序列化进 `.tscn`，编辑器可直接查看修改。layer alignment、world/cell round-trip、farm static flags、动态地块投影、地图根节点直接管理 TileMapLayer 与实体入口契约均通过。场景 fixture `cabin -> farm -> cabin` 通过，往返后 Player=1。
- T04 视觉：`screenshots/t04/cabin.png`、`screenshots/t04/farm.png`、`screenshots/t04/field.png` 均为 1280x720 Godot framebuffer；分别可见 cabin 床/家具、farm 道路/可耕区/水域、field 道路/资源林地。
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
- T01 catalog fixture：godot-ai run `r1899847-4`，`autosave=false`；输出 `catalog valid | items=12 crops=1 harvestables=3 drops=4 schedules=1`，正常自行退出。
- T01 主场景回归：godot-ai run `r1925183-5`，状态 `live`、`helper_live=true`、`current_run_errors=[]`；游戏日志正常输出 `[T00] project ready`。
- T01 diagnostics：首次 editor scan 分两轮注册 20 个互相依赖的 `class_name`；第二轮后 global class count 68，fixture 和主场景的增量 editor/game errors 均为 0，无 class_name 冲突或循环 preload。
- T00 自动化：`godot --headless --path . --import`、原生 test runner、`godot --headless --path . --quit` 全部 exit 0；runner 为 1 test / 2 assertions。
- T00 项目：主场景以 Compatibility/OpenGL 启动，日志输出 `[T00] project ready`，InputMap 21 个 action 均有绑定。
- T00 godot-ai：session `godot-my-farm@eae2`，plugin/server 均为 3.0.7，43 tools；hierarchy 31 nodes；run `r94834-1` 状态 live、helper_live=true，editor errors 0，game errors 0。
- T00 视觉：`screenshots/t00/godot_ai_game.png`（640x360 原生 framebuffer）和 `screenshots/t00/runtime_1280x720.png`（1280x720 实际运行帧）均已人工检查，非空、无裁切/重叠/模糊。
- 文档：27 个 Markdown 文件均为单一 H1、代码围栏成对、相对链接可解析。
- 任务：T00-T17 共 18 张任务卡与总表一一对应，依赖按拓扑顺序排列。
- 基线：已核对 my_farm、Godogen 和 godot-ai 的固定提交 ID，以及 GDScript/C# 技术边界。

## 已知问题

- 当前 Codex 进程启动时未加载新 MCP 配置，因此 T00 通过官方 FastMCP Client 调用了同一服务；下一次新任务/客户端重载后会直接暴露 godot-ai tools。
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
