# T00 工具链与项目骨架

## 目标

建立可被 Godot 标准版、GDScript、命令行测试和 godot-ai 共同操作的最小工程。结束时主场景显示非空占位画面，脚本诊断、运行日志和截图链路都已证明可用。

## 依赖

- 无。

## 交付范围

- 创建 `project.godot`、`.gitignore`、`.editorconfig`。
- 创建 `scenes/app/main.tscn` 及最小 `scripts/app/main.gd`。
- 创建 `tests/test_runner.gd` 和一条 runner 自检测试。
- 创建任务所需的最小目录，不创建空的完整目录树。
- 初始化 [../STATUS.md](../STATUS.md) 为实际工程状态。

## 实现要求

1. 探测并记录 Godot 可执行文件和精确版本；本项目固定使用 Godot 4.7 stable 标准版。
2. 配置主场景、`640x360` 设计视口、`1280x720` 默认窗口、CanvasItems stretch、整数缩放/像素吸附和 nearest 默认过滤。
3. 配置渲染器时以实际机器兼容为准；选择与理由写入 STATUS。
4. 注册 [../01_TECHNICAL_RULES.md](../01_TECHNICAL_RULES.md) 的 InputMap actions，包括 10 个 hotbar action；不要在脚本里读物理键。
5. Main 至少包含 World、MapHost、ActorHost、EffectHost、UILayer、TransitionOverlay 的稳定骨架；用清楚色块显示“工程已启动”，不是空画面。
6. 建立原生 headless test runner：能发现测试、报告断言总数、失败时 exit 非零；runner 自测不能静默通过零断言。
7. 安装/连接 godot-ai，记录目标 `session_id`、project_path 和版本。插件文件是否纳入仓库按 godot-ai 安装说明处理。
8. `.gitignore` 排除 `.godot/`、日志、临时录制帧和平台产物，但保留需要交付的截图/最终证明。

## 自动化验收

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --quit
```

- runner 自测至少 1 个断言且通过。
- import/quit 没有 parse error、缺资源或主场景错误。

## godot-ai 验收

1. editor_state 显示正确 project_path、版本和 ready。
2. scene_get_hierarchy 读回 Main 骨架，节点未丢失。
3. project_run 返回 game_status `live`。
4. editor/game logs 无错误。
5. editor_screenshot(source=`game`, max_resolution=`0`) 返回非空的 `640x360` 基础 framebuffer，骨架色块和启动文字完整可见；另用实际窗口/movie writer 验证 `1280x720` 整数放大画面。

## 不做

- 不创建领域 Autoload、Player、TileSet 或正式 UI。
- 不引入第三方插件或参考项目资产。

## 完成记录

在 STATUS 写入 Godot 命令路径/版本、godot-ai session、三条命令结果、run_id 和截图绝对路径，然后将总表 T00 标为 completed。
