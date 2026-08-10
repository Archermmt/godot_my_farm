# T05 背包、Toolbar、Itembar 与手持物

## 目标

把 T01 的物品容器接入 Player 和最小 UI，建立纯键盘控制的 Toolbar、Itembar、背包焦点交换和唯一手持物表现。

## 依赖

- T03 completed。

## 交付范围

- `scenes/ui/inventory_interface.tscn`、`inventory_slot.tscn`、`item_tooltip.tscn`。Toolbar/Itembar 是独立状态容器，但显示节点由 InventoryInterface 直接持有和统一控制，不建立只有展示包装作用的独立场景。
- Toolbar、Itembar、Inventory 的状态/API 与对应 UI 控制脚本。
- Player 头顶选择提示、Hands/held item presenter 和 HUD 当前手持状态。
- Main UILayer 实例化 UI；容器状态由 PlayerState 持有，Player 负责把状态变化转成 EventBus/UI 事实信号。
- 纯键盘选择、焦点交换和唯一手持状态集成测试。

## 实现要求

1. Inventory、Toolbar、Itembar 都只通过状态 API 修改 ItemStack；Slot Control 不持有权威副本。
2. Toolbar 只接受 `ItemMeta.item_type == TOOL` 的工具，Itembar 只接受种子、食物、材料等可选择非工具物品；非法跨栏交换必须拒绝并保持原状态。
3. `toolbar_previous/toolbar_next` 与 `itembar_previous/itembar_next` 循环改变各自高亮。最近操作的 bar 成为唯一 active source；切换 Toolbar 时手持工具，切换 Itembar 时手持物品，同一时间绝不同时持有两者。
4. 每次切换在 Player 头顶短暂显示对应 Toolbar 或 Itembar，并高亮当前格；提示自动隐藏，但选中状态持续存在。HUD 常驻显示当前手持来源、图标、名称和数量。
5. 空格可被高亮；若 active slot 为空，Player 手中为空，使用/丢下输入返回明确无效结果。
6. 背包打开使用 `inventory` input/time lock reason，世界移动和交互停止，键盘 UI 输入仍可用。关闭/cancel 精确解除，不能影响其他 lock reason。
7. 背包界面同时展示 Inventory、Toolbar、Itembar。方向输入在格子间移动唯一焦点；按 `inventory_swap` 标记源格，再移动并再次按键完成 swap/merge。取消键先取消待交换状态，再关闭面板。
8. 交换操作必须原子执行，支持不同物品交换、同物品合并和无效目标回滚；不得通过鼠标点击、拖拽或拖放修改任何容器。
9. Tooltip/详情面板跟随当前键盘焦点，显示名称、类型、说明、数量和价格字段，并保持在设计视口内。
10. Hands 根据唯一 active ItemStack 的 ItemMeta held_scene/icon 更新；连续切换时释放旧实例或复用 cache，不得累计隐藏节点。
11. GameManager.new_game 通过 PlayerState 初始化 6 个工具、种子和空 Inventory；UI 重建不得重复添加物品。
12. 默认键盘映射沿用 project.godot：Q/E 切 Toolbar，Z/C 切 Itembar，P 打开背包，WASD/方向 action 移动焦点，X 执行交换，F 确认，Escape 取消；业务代码只读取 action 名。

## 自动化验收

- Toolbar/Itembar 循环选择、独立 selected index 和唯一 active source 正确；连续交替 100 次从未出现双持。
- 头顶选择提示显示正确 bar、高亮正确格并按时隐藏；HUD 手持状态与 Hands 一致。
- 方向焦点跨 Inventory/Toolbar/Itembar 边界稳定；swap/merge/rollback 数量守恒，工具/物品类型约束生效。
- 打开背包后 Player velocity 为零，关闭后恢复；多个 lock reason 不互相提前解除。
- 连续切换 100 次手持物，Hands 子节点数量保持稳定。
- 全流程不注入鼠标事件；所有操作仅由 InputMap action 驱动。

## godot-ai 验收

用键盘 action 循环选择 6 个工具和种子，分别截取 Player 头顶 Toolbar/Itembar 高亮与 HUD 手持状态。打开背包，仅用方向 action 和 `inventory_swap` 在三类容器之间完成合法交换、合并和一次非法回滚，再关闭；读取 active source、selected index 和数量，日志无 Control 越界/空引用。

## 不做

- 不实现物品使用、农田光标、商店或丢弃到世界。
- 不支持鼠标点击、拖拽、拖放或鼠标决定选择。
- 不制作正式 UI 美术。

## 完成记录

- 状态：completed（2026-08-10）。
- PlayerState 建立并持有 20 格 Inventory、6 格 Toolbar 和 10 格 Itembar；Toolbar 仅接收工具，Itembar 仅接收可使用的非工具物品。
- Q/E 与 Z/C 循环选择对应栏位，最近操作的栏位成为唯一 active hand；Player 复用单个 HeldVisual，并短暂显示头顶选择提示。
- 背包使用方向焦点、X 两段式 swap/merge 和 F 设为手持；非法跨栏交换原子回滚，未实现鼠标点击或拖放路径。
- `inventory` input/time lock 经 fixture 验证可独立申请和解除，不影响其他 reason。
- 自动化：63 tests / 3936 assertions；InventoryKeyboardTest、MapTransitionTest、PlayerCollisionTest、主场景启动与 `git diff --check` 全部通过。
- 视觉证据：`screenshots/t05/inventory.png`（1280x720 实际 Godot framebuffer），6/10/20 格容器、键盘焦点、详情和手持 HUD 均无裁切。
- 下一任务：T06 统一目标预览与蓄力交互。
