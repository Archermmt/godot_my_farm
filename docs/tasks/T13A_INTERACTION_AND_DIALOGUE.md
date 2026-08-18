# T13A 场景物件、NPC 交互与对话气泡

## 目标

在 T13 的 NPC 移动和 T14 的持久化之间，建立统一的面对面交互流程。玩家可以与房屋内的床、电视等场景物件交互，也可以与 NPC 交互并进入可推进的对话。这里的“场景物件”是地图中已实例化的家具或设施，不是背包中的 `Item`。交互目标由玩家当前地图、位置和 facing 决定；对话期间角色停止移动，直到对话结束或被取消。

本任务参考 GDQuest Open RPG 的对话流程，但不要求引入 Dialogic 插件。参考项目将对话内容放在可编辑的 `DialogicTimeline` 资源中，触发脚本只调用 `Dialogic.start_timeline()`，通过 `timeline_ended` 等信号等待结束；文本气泡由可替换的默认布局场景实例化，系统内部区分 `IDLE`、文本揭示和等待输入等状态。本项目采用相同的职责分离，用自己的轻量实现保持当前 DataCatalog、GameManager 和 UI 结构。

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

本项目对应为 `Player -> interaction target -> DialogueController -> dialogue bubble scene`。触发对象只返回 dialogue key；控制器独占会话状态并发信号；气泡只负责呈现和输入反馈。这样床、电视和 NPC 共用同一流程，同时不让任何场景物件依赖具体 UI。

## 依赖

- T04、T04A、T10、T12、T13 completed。

## 交付范围

- 新的 `interact` 输入动作；对话推进和取消输入沿用明确的独立动作，不复用 `use_held`。
- 统一的交互目标协议，覆盖 `FarmNpc`、床、电视等 `Node2D` 场景物件。目标负责提供交互条件和执行结果，不直接操作 Player 的输入状态。
- 玩家按 facing 方向查询最近的一个目标；查询范围使用当前地图的 cell/碰撞信息，不能通过连续世界坐标误选目标。
- 对话数据资源和对话运行时会话控制器。静态文本、speaker、头像、显示速度、简单选项等放在可编辑 Resource 中，由 DataCatalog 统一索引；当前行、revealing、等待输入、行号和打开状态属于运行时控制器/UI，不写入 NpcState。
- 一个可编辑的对话气泡场景，至少显示 speaker、文本和推进提示；支持逐字显示、再次按键立即显示完整文本、下一行和关闭。
- Bed 交互请求 CalendarManager 执行睡眠/换日流程；电视显示一段短对话或当天信息；NPC 显示对应 NPC 的对话。交互目标不得直接修改 GameManager 的内部字段。

## 架构要求

### 1. 目标与查询

1. 目标必须是当前地图中已实例化的运行时对象，或由 BaseMap 根据目标 cell 返回的对象；不能让 Player 反向遍历全局所有 NPC/Item。
2. EffectArea 继续只负责工具/种子作用区域；普通交互使用独立的 facing-cell 查询，不把对话逻辑塞入 EffectArea。
3. 目标查询按以下顺序处理：计算 player 当前 cell 前方的首个 cell，从 BaseMap/当前场景收集该 cell 上的交互目标，按目标优先级和距离选出一个目标，在目标不可用时返回原因但不打开气泡。
4. NPC、家具和设备可以共享同一交互协议，但其业务行为保留在各自 runtime object 中。不要为每一种目标创建只转发调用的 controller。

### 2. 交互协议

目标至少提供以下能力：

- `interaction_rejection_reason(player_state) -> StringName` 或等价的单一拒绝原因查询；空值表示允许交互，不再额外维护重复的 `can_interact()`；
- `interaction_prompt() -> String`，供 UI 显示可选提示；
- `interact(player) -> InteractionResult`，返回 `NONE`、`DIALOGUE`、`SLEEP` 等明确结果；
- 若结果为对话，返回对话 definition/key，而不是直接创建 UI。

Player 负责输入、朝向目标、调用目标并消费结果；目标负责自身业务；DialogueController 负责对话会话和 UI；GameManager 只在需要持久化或全局状态变化时接收结果。

### 3. 对话数据与会话

- `DialogueDefinition`/`DialogueLine` 使用 Resource 表达静态内容，包含 dialogue id、speaker id/name、文本、头像 key、可选的简单 choice 和结束行为。本任务只要求床的确认/取消等二选一分支；它属于交互确认，不扩展为带条件和副作用编排的复杂对话树。
- DataCatalog 以 Dictionary 按 dialogue id 索引 definition，加载时检查重复 id、空 speaker、无效下一节点和缺失资源。
- 不把台词硬编码到 Player、FarmNpc、House 或 UI 脚本；不把整段对话写入 NpcState。
- DialogueController 只允许一个活动会话，维护 `IDLE`、`REVEALING_TEXT`、`WAITING_INPUT`、`CHOOSING`、`CLOSING` 状态，并发 begin 必须返回 busy。
- 会话开始时保存触发目标和 player 的交互上下文；会话结束时发出 `dialogue_started`、`line_changed`、`dialogue_ended` 或等价信号，并释放 player 的 interaction lock。
- 对话打开期间禁止移动、工具蓄力、播种、拾取、drop、地图切换和换日；暂停/加载请求必须拒绝或排队，不得破坏当前会话。

### 4. 气泡呈现

- 气泡是独立可编辑场景，由 DialogueController 实例化和销毁；NPC/家具不直接持有 UI 节点。
- 气泡锚点由 speaker 的 world position 或屏幕安全区域计算，不能被摄像机边界裁掉；玩家与 NPC 对话时气泡跟随 speaker。
- 文本揭示必须可被一次推进输入跳过；文本完整后再次输入推进下一行；最后一行输入关闭。
- UI 必须提供关闭/取消路径，并在目标被销毁、地图切换或会话异常时自动关闭。
- 对话音效、打字音效和打开/关闭特效通过 AudioManager/EffectManager 请求，UI 不直接访问资源路径。

## 场景物件交互验收

1. 玩家在 farm 的 house 内面对床按 `interact`，出现提示并触发睡眠请求；确认后沿用 T10 的换日转场，取消则不改变时间。
2. 玩家面对电视按 `interact`，打开至少两行可推进的电视信息对话，逐字显示、跳过和关闭均正常。
3. 玩家面对壁炉或其他家具时，未配置 dialogue 的目标给出明确不可交互结果，不产生空气泡或错误日志。
4. 交互目标不在 facing cell、被墙阻挡、超出范围或玩家处于工具 hold 状态时，按键不会误触发。

## NPC 交互验收场景

1. 玩家在 NPC 相邻 cell 面向 NPC 按 `interact`，打开该 NPC 的 dialogue definition；NPC 位置、动画和 schedule 不被修改。
2. 连续按键可完成逐字揭示 -> 下一行 -> 关闭；对话期间 player 和 NPC 不穿插移动，不重复创建会话。
3. 两个 NPC 同时在附近时，只选择 facing 方向最近且可交互的目标；转身后目标随之改变。
4. NPC 跨地图或被 MapManager 卸载时，活动对话安全结束并恢复 player 控制；不残留旧地图 UI 或 signal 连接。

## 自动化验收

- DataCatalog 对话 definition 的重复 key、缺失 speaker、空文本和错误节点引用校验。
- 目标查询的 facing、cell 边界、阻挡、优先级和多个目标选择。
- DialogueController 的状态转换、逐字揭示跳过、推进、取消、busy 和异常清理。
- 交互结果到床/电视/NPC 行为的映射；对话期间输入被正确锁定，结束后只释放一次。
- 地图切换、目标销毁、换日请求和加载请求与活动对话的竞态测试。

## godot-ai / 手动验收

- 在 farm house 内分别与床、电视和家具交互，截图记录提示、气泡逐字显示、完整文本和关闭后的状态。
- 在 farm、field 至少各与一名 NPC 交互，截图记录不同 speaker 的气泡位置，输入序列证明转身后目标选择变化。
- 读取日志确认不存在重复 `dialogue_started`、悬挂 signal、旧地图 UI 或 player lock 未释放；运行结束后检查 editor/game log。

## 不做

- 不做好感度、任务树、婚恋、商店、条件分支/复杂 choice effect 或语音配音；床的确认/取消二选一不在此限制内。
- 不要求完整复刻 Dialogic 编辑器；只实现本任务所需的 Resource 数据和可编辑气泡场景。
- 不把 DialogueController 变成 GameManager 的业务逻辑；GameManager 只接收需要保存或触发全局状态变化的结果。

## 完成记录

STATUS 记录 dialogue definition 数量、床/电视/NPC 验收摘要、输入序列、截图路径、run_id 和遗留风险；总表 T13A completed 后 T14 才可进入 `in_progress`。
