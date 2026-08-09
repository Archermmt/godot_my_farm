# T02 Autoload 与应用启动

## 目标

实现架构规定的 Autoload 骨架、DataCatalog 启动校验、GameState 新游戏初始化和 Main 注入链路，使应用服务可以在没有具体农场内容时可靠启动与重置。

## 依赖

- T01 completed。

## 交付范围

- `scripts/autoload/`：event_bus、data_catalog、game_state、time_manager、scene_manager、save_manager、audio_manager。
- `scripts/app/main.gd`：注册 MapHost/ActorHost/UILayer 等场景依赖。
- `project.godot`：仅按架构顺序注册 7 个 Autoload。
- `tests/unit/` 与 `tests/integration/`：服务启动、reset、暂停 reason、catalog 查找。

## 实现要求

1. EventBus 只声明已确认的 typed signals，不持有状态。
2. DataCatalog 从显式 catalog Resource 加载定义，建立只读索引并在启动时校验；未知 ID 返回 null 并输出有上下文的错误。
3. GameState 提供 `new_game(seed)`、整体 snapshot/replace/reset；新游戏含 6 个工具、初始种子、生命/体力/金币和 cabin 起点。
4. TimeManager 先实现 CalendarState、倍率、start/stop 和 reason-based pause；完整换日行为留 T10。
5. SceneManager/SaveManager/AudioManager 提供可调用但未实现内容的安全窄 API；不允许空方法假装成功，应返回明确 Error/Result。
6. Main 显式注册 host 和 overlay；Autoload 不搜索场景树。
7. Autoload 初始化顺序严格为 EventBus -> DataCatalog -> GameState -> TimeManager -> SceneManager -> SaveManager -> AudioManager。
8. 启动校验失败时停止进入游戏逻辑，画面显示开发期错误摘要，日志包含具体定义。

## 自动化验收

- 正常 catalog 启动并能按 ID 查到定义。
- 坏 catalog 阻止启动，错误可定位。
- new_game 两次不会累积物品/信号；相同 seed 初始状态相同。
- 两个 pause reason 叠加时，解除一个不会恢复时间；全部解除才恢复。
- snapshot 修改副本不反向改变 GameState。

## godot-ai 验收

1. autoload_manage list 读回 7 个服务及正确顺序。
2. project_run `live`，启动摘要显示 catalog 和新游戏状态。
3. 读取 editor/game logs，无重复 Autoload、循环依赖、空定义或未处理错误。
4. 截图证明启动错误占位已替换为正常的应用状态摘要。

## 不做

- SceneManager 不加载正式地图；SaveManager 不写磁盘；AudioManager 不需要正式音频。
- 不增加第 8 个 Autoload。

## 完成记录

STATUS 记录 Autoload 列表、测试结果、run_id、日志和截图；总表 T02 completed。
