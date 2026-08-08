# T12 HUD、背包界面、音频与特效

## 目标

把已有系统提升为可读、可操作的完整界面，并为移动、工具、采集、拾取、转场和时间提供一致音画反馈。功能状态仍由领域层拥有。

## 依赖

- T05、T09、T10 completed。

## 交付范围

- 完善 HUD、Clock、PlayerStatus、Hotbar、InventoryPanel、Tooltip、Toast、TransitionOverlay。
- Theme Resource 与 UI layout。
- AudioDefinition/catalog、AudioManager pool 和地图 ambient/music 切换。
- 收获、破坏、树倒、拾取、浇水等轻量 effect scenes。
- UI、音频节流和 effect 生命周期测试。

## 实现要求

1. HUD 显示生命、体力、金币、日期/星期/季节/时间；变化由 GameState/TimeManager signal 驱动。
2. Hotbar、背包、tooltip 延续 T05 数据边界，增加完整键鼠状态、focus、disabled/invalid 反馈。
3. Panel 打开时世界输入与时间按设计暂停，Escape 关闭最上层 panel；过场层阻止 UI/world 点击穿透。
4. Theme 在 `640x360` 和 `960x540` 保持文字完整；不得出现嵌套装饰卡片、过度圆角或遮挡世界的巨型标题。
5. Hotbar 自动换边有迟滞且动画不改变布局尺寸；Tooltip clamp 在安全区内。
6. AudioManager 使用 Music/Ambient/SFX/UI bus 和可复用 player pool；脚步/碰撞等高频音效节流，地图 ambient 平滑切换。
7. 每个 action result 映射一次对应反馈；失败使用轻量 invalid 反馈，不播放成功声音。
8. Effect 有最大生命周期并自动回收/销毁；多格工具可合并反馈，避免几十个 AudioStreamPlayer/粒子同时创建。
9. 所有占位音画资源原创或许可明确，来源先记入 `assets/licenses/ASSETS.md`。

## 自动化验收

- HUD 在状态/时间 signal 后更新且无重复订阅。
- 打开/关闭/转场的 input/pause reason 叠加正确。
- Tooltip 四角布局在两视口内；最长测试文案不截断。
- 连续触发 100 次脚步和 50 次多格 action，audio/effect 实例数有上限并最终回落。
- 失败 action 不触发成功音效/特效。

## godot-ai 验收

完整走过移动、工具、采集、拾取、背包、地图转场和四个时段。截默认/小窗口 HUD、hotbar 顶底、背包 tooltip、夜间画面；读取 monitor 和日志，确认无 UI overflow、audio pool exhaustion 或残留 effects。

## 不做

- 不加入商店、对话 UI 或正式剧情。
- 不用 UI 脚本直接修领域状态来让数值“看起来正确”。

## 完成记录

STATUS 记录视口截图、音频/特效实例峰值、run_id 和日志；总表 T12 completed。

