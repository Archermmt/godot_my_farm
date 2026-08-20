# T04 玩家移动、相机与动画状态

## 目标

创建持久 Player leaf scene，在最小碰撞测试场景中实现参考成品一致的默认跑步、Shift 慢走、四方向朝向和稳定 Camera2D 跟随。

## 依赖

- T02 completed。

## 交付范围

- `scenes/actors/player/player.tscn`。
- 单一 `scripts/actors/player.gd` 根控制器；不为输入、移动和表现分别创建只服务 Player 的脚本组件。
- `AnimationPlayer` 与 `AnimationLibrary` 资源；角色脚本只切换动画名称，不直接控制 Sprite frame。
- Main 在 ActorHost 实例化唯一 Player。
- 原创占位 player sprite/animation；移动 fixture。
- Player movement 单元/集成测试。

## 实现要求

1. 根节点 CharacterBody2D，具有清楚的 CollisionShape2D、Visual、Hands、Camera2D 和交互挂点。
2. Player 根脚本只通过 InputMap 读取输入；默认速度为 run，按住 walk_modifier 降速。具体值由 exported config 控制。
3. 对角输入归一化。朝向选择规则与参考一致：水平输入优先，再按 y；视觉只有 left/right/up/down。
4. Player 根脚本只在 physics process 设置 velocity 并 move_and_slide；不能直接改 position 绕过碰撞。
5. `AnimationPlayer` 管理 idle/walk/run 与四向动画；占位帧也要能看出朝向与走/跑差异。脚本不得直接设置 `Sprite2D.frame` 或手写动画计时器。
6. Camera2D current、像素稳定、有地图 limits 接口；移动时不出现亚像素抖动或显示地图外空白。
7. 输入锁定 API 支持 reason，场景切换/UI 后续可叠加使用。
8. Main 重载/地图替换不得创建第二个 Player。

## 自动化验收

- 输入向量归一化；walk speed < run speed；无输入 velocity 归零。
- 朝向在对角/停止时稳定，不来回跳。
- 碰撞 fixture 中连续移动不能穿过 StaticBody2D。
- 两个 input lock reason 叠加/解除行为正确。

## godot-ai 验收

用 input_sequence 验证右、左、上、下、对角、walk_modifier，并读取运行 Player 位置/状态。截图至少包含四方向和撞墙结果；game/editor logs 无物理或动画错误。

## 不做

- 不实现背包、工具、农田和正式角色美术。
- 不直接加入物理键调试分支。

## 完成记录

STATUS 记录速度、输入序列、位置断言、run_id 和截图；总表 T04 completed。
