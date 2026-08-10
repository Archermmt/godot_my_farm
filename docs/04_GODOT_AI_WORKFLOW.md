# godot-ai 开发工作流

## 1. 定位

godot-ai 是开发期 MCP 辅助工具：Codex 通过它读取 Godot 编辑器状态、创建/修改场景和 GDScript、运行游戏、注入输入、读取日志并截取运行画面。它不进入发行包，也不替代项目自身测试。

本流程参考本机 `/Users/tongmeng/Desktop/codes/godot-ai` 的提交 `d602a78322c66a24969f37f261e0364465cff464`。工具升级后若名称或参数改变，以该仓库的 `docs/TOOLS.md` 为准，并同步更新本文。

## 2. 前置条件

T01 在任何场景写入前确认：

1. 安装 Godot 4.7 stable 标准版并可从命令行运行。
2. 按 godot-ai 自身 README 安装 `addons/godot_ai` 并在当前项目启用插件。
3. 编辑器打开的 `project_path` 必须是本项目绝对路径，不能指向参考仓库或其他 worktree。
4. godot-ai 服务器只绑定 loopback；不要暴露其编辑器控制端口。
5. `session_manage(op="list")` 只存在一个目标时激活它；多会话时用 `session_activate` 或每次传 `session_id`。

若当前环境没有 Godot 或 godot-ai 会话，允许先完成不依赖编辑器的文档/纯脚本工作，但任何需要场景或运行验收的任务必须报告阻塞，不能伪造完成记录。

## 3. 每次任务的标准工具顺序

### 3.1 确认会话和状态

1. `session_manage(op="list")`：确认项目名、路径、Godot/plugin/server 版本。
2. `session_activate`：激活准确的 session。
3. `editor_state`：确认 readiness、当前 scene、play state 和 game liveness。
4. 如果正在运行，先 `project_manage(op="stop")`，再做场景写入。

不要只根据项目名选择会话；同名目录可能有多个编辑器实例。

### 3.2 先读后写

- 场景：`scene_get_hierarchy`、`node_get_properties`。
- 脚本：优先 `godot://script/...` 资源或 `script_manage(op="read")`。
- 文件搜索：`filesystem_manage(op="search")`。
- InputMap：`input_map_manage(op="list")`。
- Autoload：`autoload_manage(op="list")`。
- 不确定 Godot API 时：`api_manage(op="get_class")` 指定需要的 sections，不猜属性和枚举。

每次修改前确认节点路径、脚本内容和现有用户改动。不要基于旧的 hierarchy 盲写。

### 3.3 写脚本

- 新脚本使用 `script_create`；局部修改优先 `script_patch` 的锚点编辑。
- 每次响应都检查 `diagnostics`、`diagnostics_status` 和错误提示。尤其在 headless 会话中，脚本解析错误可能不会进入普通 game log。
- `script_create`/`script_patch` 直接写磁盘且不可 undo。路径和内容必须在调用前确认。
- 多文件脚手架允许先完成同一解析闭包，再 `filesystem_manage(op="scan")`；随后立即清理所有 diagnostics。
- 不用 `filesystem_manage(op="write_text")` 绕开 GDScript 的专用诊断通道。

### 3.4 创建和修改场景

- 新 scene 用 `scene_manage(op="create")`，leaf scene 先于 parent scene。
- 高频节点操作使用 `node_create`、`node_set_property`；一组互相依赖的节点用 `batch_execute` 原子完成。
- `batch_execute.commands[].command` 使用插件底层命令名，例如 `create_node`、`set_property`，不是 MCP tool 名。
- 连接信号用 `signal_manage`，设置输入用 `input_map_manage`，Autoload 用 `autoload_manage`。
- PackedScene 实例必须保持实例关系，不展开并重设其后代 owner。
- 修改完成调用 `scene_save`；再用 `scene_get_hierarchy` 和关键节点 `node_get_properties` 读回验证。

场景内存修改在 `scene_save` 前不一定落盘。`project_run` 默认 autosave，可能把临时 smoke 修改写入正式 scene；临时测试必须传 `autosave=False` 或使用专用 fixture scene。

### 3.5 扫描和静态验证

1. `filesystem_manage(op="scan")` 等待编辑器发现新文件。
2. 检查本次脚本写入 diagnostics。
3. `logs_read(source="editor", include_details=true)` 清理 parse、reload、资源和 Debugger 错误。
4. 可运行时执行项目自身 headless 测试；godot-ai 插件的 `test_run` 是插件开发测试，不代替本游戏 `tests/test_runner.gd`。

### 3.6 运行

1. `project_run` 启动主场景。
2. 检查响应中的 `game_status`：目标是 `live`。`launching` 需短暂重查；`break` 必须 stop、修复再启动；`not_live` 查看 editor diagnostics。
3. `logs_read(source="game")` 只读取当前 run；保存返回的 `run_id`，不要把旧 run 当成新结果。
4. 同时检查 `logs_read(source="editor", include_details=true)`，因为启动期脚本错误可能不在 game log。

### 3.7 输入与状态检查

- 简单操作使用 `game_manage(op="input_action")`。
- 蓄力、移动到触发器、多键组合和连续交互必须用 `game_manage(op="input_sequence")`，按 frame 安排 press/release，避免网络往返造成时序漂移。
- 序列结束检查 `actions_pressed_at_end`，释放仍按住的 action。
- 用 `game_manage(op="get_scene_tree")` 和 `get_node_info` 读取运行时状态；对领域结果优先依赖项目 HUD/测试探针或公开只读调试快照，不执行任意写状态的 eval。
- `editor_manage(op="game_eval")` 只用于诊断，不能作为验收通过的唯一依据。

### 3.8 视觉验收

- `editor_screenshot(source="game")` 截运行帧，不用编辑器 2D viewport 代替游戏画面。
- 每个可见任务至少截默认窗口；UI/布局任务再验证小窗口。
- 检查：画面非空、相机正确、像素无模糊、TileMap 对齐、地图 Item 排序、光标可读、UI 无遮挡/溢出、文字完整。
- 需要验证移动、蓄力、掉落吸附、转场或 NPC 路径时，先用 input_sequence 到达关键帧，再分别截图；单张静态图不能证明完整时序。

### 3.9 停止和记录

1. `project_manage(op="stop")`，确认 editor_state 已停止。
2. 再读一次 editor/game logs，确认停止/退出没有新错误。
3. 记录 session、run_id、测试结果、截图绝对路径和验收结论到 `docs/STATUS.md`。
4. 检查磁盘变更，确保没有临时脚本、错误主场景、`.godot` 缓存或插件运行产物进入任务范围。

## 4. 常用领域工具

| 目的 | godot-ai 工具 |
|---|---|
| 编辑器/会话 | `editor_state`、`session_activate`、`session_manage` |
| 场景 | `scene_get_hierarchy`、`scene_open`、`scene_save`、`scene_manage` |
| 节点 | `node_create`、`node_set_property`、`node_get_properties`、`node_find`、`node_manage` |
| GDScript | `script_create`、`script_attach`、`script_patch`、`script_manage` |
| 文件/资源 | `filesystem_manage`、`resource_manage` |
| 输入/Autoload/信号 | `input_map_manage`、`autoload_manage`、`signal_manage` |
| TileMap | `tilemap_manage`、`tileset_manage` |
| UI/主题/动画 | `ui_manage`、`theme_manage`、`animation_manage` |
| 运行与诊断 | `project_run`、`project_manage`、`logs_read` |
| 运行输入与检查 | `game_manage` |
| 画面证明 | `editor_screenshot` |

rollup 工具的标准调用结构为：

```json
{
  "op": "verb_name",
  "params": {"verb_specific": "value"},
  "session_id": "optional-project@id"
}
```

`session_id` 位于顶层，不能放进 `params`。

## 5. godot-ai 与直接文件编辑的边界

- `.gd`、`.md`、`.json` 等文本允许使用本地补丁工具，但修改 `.gd` 后仍必须让 Godot 扫描并检查解析诊断。
- `.tscn`、`.tres`、TileSet、Animation、Theme 和节点 signal connection 优先通过 godot-ai/Godot API 编辑。
- 大批量纯数据 `.tres` 若工具效率不足，可用 Godot `@tool` 导入脚本生成；生成脚本必须可重复、先写临时输出并验证资源可加载。
- 不在同一时刻从文件补丁和 godot-ai 修改同一个 scene/resource；先保存/重读，避免覆盖编辑器内存状态。
- 编辑器处于 `playing` 或 `importing` 时不强行场景写入，按 readiness 提示处理。

## 6. 故障处理

| 状态 | 处理 |
|---|---|
| 无 session | 确认插件启用、服务启动、项目路径正确；不能继续场景验收 |
| `EDITOR_IMPORTING` | 等待工具内建 readiness hold；超时后重查，不重复并发写 |
| `EDITOR_PLAYING` | stop 后再写 scene/resource |
| `game_status=break` | stop，读 editor detail，修脚本，scan，再 run |
| 脚本 response 有 diagnostics | 立即定位本文件；不能等到任务末尾 |
| screenshot 空白 | 确认 game `live`、Camera2D current、主场景与可见层，再重截 |
| scene 修改丢失 | 检查是否 scene_save、是否写了错误 session/scene、是否被外部文件覆盖 |
| 多个同名项目 | 通过绝对 `project_path` 选 session，每次写显式带 session_id |

## 7. Godogen 原则在本项目的落地

- 参考 Godogen 提交 `05cebffc8b10c5817e8a3db495b82e7b6004ab84`。其上游 Godot guide 使用 C#/.NET 与构建期 C# scene builder；这些做法与本项目硬约束冲突，明确不采用。本项目场景由 Godot 编辑器/godot-ai 维护，运行代码只用 GDScript。
- `docs/STATUS.md` 保留跨上下文的真实进度，但规范仍以本目录为准。
- 先建立可运行的垂直切片，再扩内容；每一阶段都有实际游戏画面。
- 以运行游戏判断结果，不以“文件已创建/脚本无报错”判断。
- 最终用户尚未亲自看过完整流程时，制作并回看 15-20 秒证明片段；片段必须展示行为推进，不是静止或循环同一帧。
