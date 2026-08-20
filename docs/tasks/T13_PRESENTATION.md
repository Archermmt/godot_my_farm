# T13 HUD、背包界面、音频与特效

## 目标

把已有系统提升为可读、可操作的完整界面，并为移动、工具、采集、拾取、转场和时间提供一致音画反馈。功能状态仍由领域层拥有。

## 依赖

- T06、T10、T11 completed。

## 交付范围

- 完善 HUD、Clock、PlayerStatus、Toolbar、Itembar、Player 头顶选择提示、InventoryPanel、Tooltip、Toast、TransitionOverlay。
- Theme Resource 与 UI layout。
- AudioDefinition/catalog、AudioManager pool 和地图 ambient/music 切换。
- 收获、破坏、树倒、拾取、浇水等轻量 effect scenes，以及割草草叶、砍树木屑、砸石石屑、雨线与地面涟漪粒子场景。
- UI、音频节流和 effect 生命周期测试。

## 实现要求

1. HUD 显示生命、体力、金币、日期/星期/季节/时间；变化由 GameManager signal 驱动。
2. Toolbar、Itembar、背包、tooltip 延续 T05 数据边界，完善纯键盘 focus、待交换、disabled/invalid 和唯一 active source 反馈。
3. Panel 打开时世界输入与时间按设计暂停，Escape 先取消待交换、再关闭最上层 panel；过场层阻止 UI/world 输入穿透。
4. Theme 在 `640x360` 和 `960x540` 保持文字完整；不得出现嵌套装饰卡片、过度圆角或遮挡世界的巨型标题。
5. Player 头顶 Toolbar/Itembar 提示使用固定尺寸，在选择后短暂显示且不遮挡角色；HUD 的当前手持状态常驻可读。Tooltip/详情区域 clamp 在安全区内。
6. AudioManager 使用 Music/Ambient/SFX/UI bus 和可复用 player pool；脚步/碰撞等高频音效节流，地图 ambient 平滑切换。
7. 每个 action result 映射一次对应反馈；失败使用轻量 invalid 反馈，不播放成功声音。
8. Effect 有最大生命周期并自动回收/销毁；多格工具可合并反馈，避免几十个 AudioStreamPlayer/粒子同时创建。
9. 所有占位音画资源原创或许可明确，来源先记入 `assets/licenses/ASSETS.md`。
10. `cut`、`chop`、`mine` 和雨天表现必须使用独立、可在 Inspector 编辑的粒子场景；天气粒子由 EffectManager 随 weather/map 生命周期创建和回收，室内不生成降雨。

## 自动化验收

- HUD 在状态/时间 signal 后更新且无重复订阅。
- 打开/关闭/转场的 input/pause reason 叠加正确。
- Tooltip 四角布局在两视口内；最长测试文案不截断。
- 连续触发 100 次脚步和 50 次多格 action，audio/effect 实例数有上限并最终回落。
- 失败 action 不触发成功音效/特效。
- Cut/Chop/Mine 定义分别加载草叶/木屑/石屑粒子场景；rain/storm 加载一份持续雨天场景，且该场景同时包含雨线和涟漪粒子系统。

## godot-ai 验收

仅用键盘完整走过移动、Toolbar/Itembar 切换、采集、拾取、背包焦点交换、地图转场和四个时段。截默认/小窗口 HUD、Player 头顶两种 bar 提示、背包三容器焦点与 tooltip、夜间画面；读取 monitor 和日志，确认无 UI overflow、audio pool exhaustion 或残留 effects。

## 不做

- 不加入商店、对话 UI 或正式剧情。
- 不用 UI 脚本直接修领域状态来让数值“看起来正确”。

## 完成记录

- 2026-08-14 完成。HUD、背包、共享 Theme、Toast、转场输入阻断、昼夜 CanvasModulate、Player 头顶选择提示和手持状态均已接入。
- AudioManager 使用 18 条 AudioDefinition、Music/Ambient/SFX/UI 四类 bus 与有界 player pool；地图切换同时交叉淡化 ambient/music，高频脚步按事件节流。
- 通用工具反馈按一次 action 合并为一个 ActionEffect，最多保留 8 个并自动淡出；失败只显示 invalid toast/音效，不产生成功特效。
- Cut、Chop 和 Mine 已分别切换为可编辑的草叶、木屑、石屑 CPUParticles2D 场景；rain/storm 由 EffectManager 在室外地图挂载持续雨线与地面涟漪场景，天气或地图变化时自动替换/回收。
- 自动化为 123 tests / 5247 assertions；资源导入、主场景 smoke、粒子场景结构和 EffectManager 配置均通过验证。
