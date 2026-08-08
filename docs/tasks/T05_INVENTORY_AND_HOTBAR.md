# T05 背包、快捷栏与手持物

## 目标

把 T01 的 InventoryState 接入 Player 和最小 UI，实现 10 格快捷栏选择、背包打开/关闭、堆叠与拖拽交换，以及选中物品的手持占位表现。

## 依赖

- T03 completed。

## 交付范围

- `scenes/ui/hotbar.tscn`、`inventory_panel.tscn`、`inventory_slot.tscn`、`item_tooltip.tscn`。
- `scripts/ui/` 对应控制脚本；Player Hands/held item presenter。
- Main UILayer 实例化 UI 并绑定 GameState 信号。
- inventory UI 集成测试。

## 实现要求

1. UI 只通过 InventoryState API 改数据；Slot Control 不持有权威 ItemStack 副本。
2. 10 格 hotbar 支持 action `hotbar_1..10` 与点击；高亮始终唯一，空格可选但手中为空。
3. 背包打开使用 `inventory` input/time lock reason，关闭/cancel 精确解除；世界移动和交互被锁，UI 输入仍可用。
4. 拖拽支持交换、同物品合并和无效目标回滚；不得丢失或复制数量。
5. Tooltip 显示名称、类型、说明、数量、价格字段，保持在视口内。
6. Hands 根据 ItemDefinition 的 held_scene/icon 更新；切换时释放旧实例或复用 cache，但不能累计隐藏节点。
7. Hotbar 根据 Player viewport y 在顶/底切换，带迟滞阈值避免边界抖动。
8. GameState new_game 的 6 工具与种子在 UI 中可见，UI 重建不重复添加物品。

## 自动化验收

- UI 操作后 InventoryState 与显示一致；drag merge/swap/rollback 数量守恒。
- 打开背包后 Player velocity 为零，关闭后恢复；两个 lock reason 不互相提前解除。
- 连续切换 100 次手持物，Hands 子节点数量保持稳定。
- Tooltip 在四角 slot 上不越出 `640x360` 设计视口。

## godot-ai 验收

用 action 输入切换 6 个工具和种子，打开背包并用鼠标拖拽至少两格，再关闭。截图包含底部/顶部 hotbar、背包和 tooltip；运行时读取 selected index 和数量，日志无 Control 越界/空引用。

## 不做

- 不实现物品使用、农田光标、商店或丢弃到世界。
- 不制作正式 UI 美术。

## 完成记录

STATUS 记录拖拽前后数量、lock 验证、run_id 和各 UI 截图；总表 T05 completed。

