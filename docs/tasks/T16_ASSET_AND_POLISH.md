# T16 正式资源、可读性与许可清单

## 目标

用风格一致、来源清楚的原创/获授权资源替换开发占位，完成像素裁切、导入、动画、声音混音、地图地标和 UI 可读性精修，不改变已经验证的玩法。

## 依赖

- T15 completed。

## 用户门

开始前提出一份资源方案：本地原创绘制/程序化生成、用户提供、免费许可资源或付费生成。任何付费 API/服务调用前必须得到用户明确同意。没有付费授权时采用本地原创方案继续，不复制参考仓库资源。

## 交付范围

- Player、2 NPC、6 工具、种子/作物阶段、草/石/树/树桩/掉落、三地图 tiles/building、UI 和 effects 的一致资源。
- 音乐、环境音和核心 SFX，或明确的原创最小替代。
- `assets/licenses/ASSETS.md` 逐项清单、源文件与导入配置。
- 视觉回归截图和资产 smoke tests。

## 实现要求

1. 先固定 style sheet：tile size、轮廓、透视、调色板角色、光源方向、角色/对象基准尺寸、UI 字体和 icon grid。
2. 每个资源记录文件、用途、来源 URL/生成方法、作者/模型、许可证、修改和成本；不明许可资源不得进入发行资产。
3. 贴图按 pixel art 设置 nearest、无不必要 mipmap，透明边缘无颜色污染；sprite sheet 裁切尺寸和 pivot 一致。
4. Player/NPC 的 idle/walk/run/tool 状态不缺方向；工具和手持物对齐，不遮脸/穿身体。
5. 作物每阶段可一眼区分；dug/watered/valid/invalid 在明暗和形状上可读。
6. farm/field/cabin 有清楚地标和出口，不靠大段帮助文字解释路线。
7. UI 与世界使用互补但非单色的 palette；文字对比和字号满足两视口，无容器溢出。
8. 音量经 bus 平衡，脚步不压过反馈，循环音频无明显爆点；缺音频时不报错。
9. 每次批量导入后先 reimport/scan，再运行 asset smoke scene 检查所有引用可加载。

## 自动化验收

- Catalog 中每个 icon、stage texture 和 audio 引用均可加载；运行时 Scene 引用由对应工厂单独验证，不进入 Meta。
- SpriteFrames 必需 animation/direction 存在，帧数/尺寸/pivot 合法。
- 资源清单覆盖 `assets/` 中所有发行文件，无未登记外部资源。
- 不包含 Unity `.meta/.prefab/.unity` 或参考仓库 GUID/Material。
- 全量测试仍通过，状态 snapshot 与 T15 基线兼容。

## godot-ai 验收

逐张地图、四时段、Player/NPC 动画、6 工具、作物阶段、采集效果、Player 头顶 Toolbar/Itembar、背包三容器焦点和 HUD 当前手持状态在两视口截图。检查 pixel blur、错误裁切、透明边、y-sort、遮挡、文字和地标；连续键盘移动/工具输入验证动画不是静态截图假象。

## 不做

- 不因资源接入改变碰撞/状态规则，必要 collider 调整需重新跑相关测试。
- 不生成与已知商业作品角色/地图过度相似的资源。

## 完成记录

STATUS 记录用户批准方案、总成本、license 清单、资源 smoke 结果、run_id 和视觉对照；总表 T16 completed。
