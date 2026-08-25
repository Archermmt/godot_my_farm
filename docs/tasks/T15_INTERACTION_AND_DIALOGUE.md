# T15 场景物件、NPC 交互与对话气泡

## 目标

在 T14 的 NPC 移动和 T16 的持久化之间，建立统一的面对面交互流程。玩家可以与房屋内的床、电视等场景物件交互，也可以与 NPC 交互并进入可推进的对话。这里的“场景物件”是地图中已实例化的家具或设施，不是背包中的 `Item`。交互目标由独立场景中的 `InteractionArea` 与玩家 `EffectArea` 的进入/离开事件发现；对话期间角色停止移动，直到对话结束或被取消。

本任务参考 GDQuest Open RPG 的对话流程，正式实现前必须先安装并启用与当前 Godot 版本兼容的 Dialogic 插件。对话内容放在可编辑的 `DialogicTimeline` 资源中，触发脚本通过适配层调用 `Dialogic.start_timeline()`，并监听 `timeline_ended` 等信号；文本气泡、姓名、头像和推进状态由 Dialogic 的布局与会话系统负责。本项目仍保留 `Player -> InteractManager -> interaction target` 的目标选择、GameManager 的状态边界以及插件适配层，NPC 或家具不得直接依赖 Dialogic API。

参考代码：

- [DialogicGameHandler.gd](https://github.com/gdquest-demos/godot-open-rpg/blob/main/addons/dialogic/Core/DialogicGameHandler.gd)：全局对话状态、timeline/event 索引、`state_changed`、`timeline_started`、`timeline_ended` 信号。
- [opening_cutscene.gd](https://github.com/gdquest-demos/godot-open-rpg/blob/main/overworld/maps/opening_cutscene.gd)：触发方启动 timeline，等待 `timeline_ended` 后继续场景流程。
- [conversation_encounter.gd](https://github.com/gdquest-demos/godot-open-rpg/blob/main/overworld/maps/town/conversation_encounter.gd)：地图中的 encounter 只负责发现参与者和触发对话，不承担气泡绘制。
- [conversation_template.gd](https://github.com/gdquest-demos/godot-open-rpg/blob/main/src/field/cutscenes/templates/conversations/conversation_template.gd)：通过场景事件启动 timeline，并监听对话信号。
- [Dialogic text bubble 场景](https://github.com/gdquest-demos/godot-open-rpg/blob/main/addons/dialogic/Modules/DefaultLayoutParts/Base_TextBubble/text_bubble_base.tscn)：气泡、姓名和头像等呈现组件属于可替换的 UI 场景，不由 NPC 逻辑直接绘制。

从参考实现提炼出的调用链为：

```text
玩家输入/地图 encounter
  -> 触发对象选择 dialogue timeline
  -> Dialogic.start_timeline(timeline)
  -> 对话服务切换状态并驱动可替换的气泡 UI
  -> 玩家跳过揭示、推进文本或选择简单选项
  -> timeline_ended
  -> 触发方继续后续流程并恢复角色控制
```

本项目对应为 `Player -> InteractManager -> Dialogic adapter -> Dialogic timeline/layout`。触发对象只提供 dialogue key 或 timeline id；InteractManager 独占交互上下文、Player 锁和全局会话边界；Dialogic 负责 timeline、气泡和输入推进。这样床、电视和 NPC 共用同一流程，同时不让任何场景物件依赖具体 UI 或插件 API。

## 依赖

- T05、T11、T13、T14 completed。
- 已安装并启用兼容当前 Godot 版本的 Dialogic 插件。

## Dialogic 安装

1. 从官方仓库获取 Dialogic 2：<https://github.com/dialogic-godot/dialogic>。
2. 将仓库中的 `addons/dialogic` 目录复制到项目的 `res://addons/dialogic/`，确认插件入口文件为 `res://addons/dialogic/plugin.cfg`。如果使用命令行，可执行：

   ```bash
   git clone --depth 1 https://github.com/dialogic-godot/dialogic.git /tmp/dialogic
   cp -R /tmp/dialogic/addons/dialogic /path/to/project/addons/dialogic
   ```

   `res://` 仅表示项目根目录，命令行中应替换为实际项目路径。
3. 在 Godot 的 `Project -> Project Settings -> Plugins` 中启用 `Dialogic`。启用后项目应自动注册 `Dialogic` autoload；如果没有自动注册，在 `Autoload` 中添加 `res://addons/dialogic/Core/DialogicGameHandler.gd`，名称为 `Dialogic`。
   项目将 Dialogic 的输入动作配置为已有的 `interact`，不再额外创建 `dialogic_default_action`，避免插件输入轮询产生不存在动作的运行时错误。
4. 在 Dialogic 编辑器中创建 Timeline、角色和 Layout。项目的 Timeline 放在 `res://data/dialogue/`，由 `dialogue_id` 映射到对应的 `.dtl` 文件。
5. Dialogic 2 当前要求 Godot 4.5 或更高版本。本项目固定使用已验证的上游提交 `fd0fa22c335c72583b89b35699f9fb19dd1b4eae`；升级插件时需要重新验证 `InteractManager` 的 API 适配层。

## 实现策略

先安装 Dialogic，并在插件编辑器中创建 NPC、电视和床所需的 Timelines。项目通过 `InteractManager` 适配层把 `dialogue_id`、目标节点、Player 锁和结束信号接入 Dialogic；NPC、床和电视只调用项目内部的交互接口，不直接调用插件 API。不得再维护一套功能重复的自研对话会话和气泡 fallback。

## 交付范围

- 新的 `interact` 输入动作；对话推进和取消输入沿用明确的独立动作，不复用 `use_held`。
- 统一的交互目标协议，覆盖 `FarmNpc`、床、电视等 `Node2D` 场景物件。目标负责提供交互条件和执行结果，不直接操作 Player 的输入状态。
- 玩家按 facing 方向查询最近的一个目标；查询范围使用当前地图的 cell/碰撞信息，不能通过连续世界坐标误选目标。
- Dialogic Timeline 和角色/布局资源负责静态文本、speaker、头像、显示速度和简单选项；项目只保存 timeline id 与目标映射，不把 Dialogic 运行时对象写入 NpcState。
- Dialogic 默认布局或项目配置的 Dialogic layout 至少显示 speaker、文本和推进提示，并支持逐字显示、跳过、下一行和关闭；Choice 的当前焦点项必须通过清晰的边框标记并轻微放大，避免无法分辨“是/否”选择。
- Bed 交互请求 CalendarManager 执行睡眠/换日流程；电视显示一段短对话或当天信息；NPC 显示对应 NPC 的对话。交互目标不得直接修改 GameManager 的内部字段。

## 架构要求

### 1. 目标与查询

1. 目标必须是当前地图中已实例化的运行时对象，或由 BaseMap 根据目标 cell 返回的对象；不能让 Player 反向遍历全局所有 NPC/Item。
2. `EffectArea` 同时提供工具/种子预览和交互范围传感器；它只转发目标进入/离开事件并更新 `InteractManager`，不负责创建气泡或执行对话业务。
3. 目标查询按以下顺序处理：计算 player 当前 cell 前方的首个 cell，从 BaseMap/当前场景收集该 cell 上的交互目标，按目标优先级和距离选出一个目标，在目标不可用时返回原因但不打开气泡。
4. NPC、家具和设备可以共享同一交互协议，但其业务行为保留在各自 runtime object 中。不要为每一种目标创建只转发调用的 controller。

### 2. 交互协议

目标至少提供以下能力：

- `interaction_prompt() -> String`，供 UI 显示可选提示；
- `interact(player) -> void`，目标自己执行交互或通过 `InteractManager` 发起对应 Timeline；

Player 负责输入并调用 `InteractManager`；目标负责自身业务；InteractManager 负责交互目标、Player 锁、Dialogic 会话边界和 UI 适配；GameManager 只在需要持久化或全局状态变化时接收结果。

### 3. 对话数据与会话

- Dialogic Timeline 资源表达 dialogue id、speaker、文本、头像、简单 choice 和结束行为；床通过 Dialogic 的“是/否”选项确认是否睡觉，选项按钮使用左右方向键切换、`interact` 确认。
- `DataCatalog` 或 `InteractManager` 只维护项目 dialogue id 到 Dialogic Timeline 的映射，并在启动时检查缺失 Timeline、重复 id 和无效目标。
- 不把台词硬编码到 Player、FarmNpc、House 或 UI 脚本；不把整段对话写入 NpcState。
- InteractManager 只允许一个活动会话，使用 Dialogic 的会话状态和结束信号；并发 begin 必须返回 busy。
- 会话开始时保存触发目标和 player 的交互上下文；会话结束时发出 `dialogue_started`、`line_changed`、`dialogue_ended` 或等价信号，并释放 player 的 interaction lock。
- 床的 Timeline 使用两个 Choice 分支；`InteractManager` 监听 `Choices.choice_selected`，只把选项数据传回床的回调，床根据 `sleep=yes` 请求换日，不能由 Dialogic 或管理器直接写入日历状态。
- 对话打开期间禁止移动、工具蓄力、播种、拾取、drop、地图切换和换日；暂停/加载请求必须拒绝或排队，不得破坏当前会话。

### 4. 气泡呈现

- 气泡由 Dialogic layout 场景实例化和销毁；NPC/家具不直接持有 UI 节点。
- NPC、床、电视、壁炉等可交互对象必须是独立场景，并在场景内部拥有 `InteractionArea`；对象不直接持有气泡节点。
- 气泡锚点由 speaker 的 world position 或屏幕安全区域计算，不能被摄像机边界裁掉；玩家与 NPC 对话时气泡跟随 speaker。
- 文本揭示必须可被一次推进输入跳过；文本完整后再次输入推进下一行；最后一行输入关闭。
- UI 必须提供关闭/取消路径，并在目标被销毁、地图切换或会话异常时自动关闭。
- 对话音效、打字音效和打开/关闭特效通过 AudioManager/EffectManager 请求，UI 不直接访问资源路径。

## 场景物件交互验收

1. 玩家在 farm 的 house 内面对床按 `interact`，出现“是否睡觉”的 Dialogic 选择；左右方向键可以在“是/否”之间切换，按 `interact` 确认后，只有选择“是”才沿用 T10 的换日转场，选择“否”则不改变时间。
2. 玩家面对电视按 `interact`，打开至少两行可推进的电视信息对话，逐字显示、跳过和关闭均正常。
3. 玩家面对壁炉或其他家具时，未配置 dialogue 的目标给出明确不可交互结果，不产生空气泡或错误日志。
4. 交互目标不在 facing cell、被墙阻挡、超出范围或玩家处于工具 hold 状态时，按键不会误触发。
5. 玩家 `EffectArea` 进入目标 `InteractionArea` 时显示范围提示气泡，离开时只隐藏对应气泡；多个目标重叠时不得残留旧目标提示。

## NPC 交互验收场景

1. 玩家在 NPC 相邻 cell 面向 NPC 按 `interact`，打开该 NPC 的 Dialogic Timeline；NPC 位置、动画和 schedule 不被修改。
2. 连续按键可完成逐字揭示 -> 下一行 -> 关闭；对话期间 player 和 NPC 不穿插移动，不重复创建会话。
3. 两个 NPC 同时在附近时，只选择 facing 方向最近且可交互的目标；转身后目标随之改变。
4. NPC 跨地图或被 MapManager 卸载时，活动对话安全结束并恢复 player 控制；不残留旧地图 UI 或 signal 连接。

## 自动化验收

- DataCatalog 对话 definition 的重复 key、缺失 speaker、空文本和错误节点引用校验。
- 目标查询的 facing、cell 边界、阻挡、优先级和多个目标选择。
- InteractManager 与 Dialogic 的状态转换、逐字揭示跳过、推进、取消、busy 和异常清理。
- Timeline 到床/电视/NPC 行为的映射；对话期间输入被正确锁定，结束后只释放一次。
- 地图切换、目标销毁、换日请求和加载请求与活动对话的竞态测试。
- Dialogic 插件适配层的行为契约测试：相同 timeline id、输入序列、Player lock 和 `timeline_ended` 信号结果一致。

## godot-ai / 手动验收

- 在 farm house 内分别与床、电视和家具交互，截图记录提示、气泡逐字显示、完整文本和关闭后的状态。
- 在 farm、field 至少各与一名 NPC 交互，截图记录不同 speaker 的气泡位置，输入序列证明转身后目标选择变化。
- 读取日志确认不存在重复 `dialogue_started`、悬挂 signal、旧地图 UI 或 player lock 未释放；运行结束后检查 editor/game log。

## 不做

- 不做好感度、任务树、婚恋、商店、条件分支/复杂 choice effect 或语音配音；床的确认/取消二选一不在此限制内。
- 不重复实现 Dialogic 已提供的 Timeline 编辑器、会话状态机或气泡布局；项目必须通过适配层复用 Dialogic。
- 不把 InteractManager 变成 GameManager 的业务逻辑；GameManager 只接收需要保存或触发全局状态变化的结果。

## 完成记录

STATUS 记录 Dialogic Timeline 数量、床/电视/NPC 验收摘要、输入序列、截图路径、run_id 和遗留风险；总表 T15 completed 后 T16 才可进入 `in_progress`。
