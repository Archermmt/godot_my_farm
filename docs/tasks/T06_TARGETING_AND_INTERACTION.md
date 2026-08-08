# T06 统一目标预览与蓄力交互

## 目标

建立所有工具、种子和普通物品共享的 InteractionContext、TargetCandidate、UseAction、光标预览和蓄力状态机。此任务先证明目标选择一致性，不提交具体翻地/收获效果。

## 依赖

- T04、T05 completed。

## 交付范围

- `scripts/interaction/`：context、candidate、targeting_service、use_action 基类/协议、grid/harvest/seed/drop action 骨架。
- `scenes/world/interaction_cursor.tscn` 与脚本。
- `PlayerInteractionController` 接入 selected ItemStack、FarmSystem 和 Hands。
- targeting/charge 单元与集成测试。

## 实现要求

1. 状态机严格为 idle -> charging -> committed/cancelled -> idle；一次 release 只触发一次 commit signal。
2. 鼠标/面向方向、Player cell、charge level、选中数量、体力和当前 FarmSystem 组成不可变 InteractionContext 快照。
3. preview 返回有序 TargetCandidate，每项包含 cell、可选 entity ID、valid 和 reason code。
4. Cursor 完整渲染同一 preview 结果：有效格、有效对象、无效目标在形状/图标和颜色上均可区分。
5. charge level 按数据配置升级并限制最大级；目标范围遵循参考的单格、3x1、3x3、9x3、9x9 语义，不超地图或可用数量。
6. commit 接受已经显示的 preview token/result，并重新校验资源版本；不得悄悄重新选择另一批目标。
7. cancel、UI 打开、地图切换、选中物品变化、失去焦点都会清理 cursor 和 charging 状态，不消费物品/体力。
8. 不在 InteractionController 写锄头/种子/斧头名称判断；通过 ItemDefinition.use_kind 分发。

## 自动化验收

- 固定地图中心/边缘和四个朝向的范围顺序正确、结果稳定。
- holding frame 达阈值时 level 只增加一次，release 只提交一次。
- 选中数量不足时 preview 截断；零数量或无体力给出明确 invalid reason。
- preview 后地图状态版本变化时 commit 失败且无资源消费。
- 所有取消来源都回到 idle 且 cursor 清空。

## godot-ai 验收

选择锄头占位，分别短按和多级长按 secondary_action；在地图中心/边缘截图范围变化。用 input_sequence 确认 frame 时序，检查 `actions_pressed_at_end` 为空、commit 信号计数正确，日志无重复连接。

## 不做

- 不修改地块、消耗体力或生成掉落。
- 不为各工具复制独立 cursor 逻辑。

## 完成记录

STATUS 记录各 level 的目标数量/顺序、取消测试、run_id 和范围截图；总表 T06 completed。

