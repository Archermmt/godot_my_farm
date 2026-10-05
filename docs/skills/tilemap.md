# Tilemap 生成 Skill 横评与组合使用指南

本文基于三场独立 bake-off 的结论：[`test_tile_pixel/report.md`](test_tile_pixel/report.md)（像素级还原参考截图）、[`test_tile_img/report.md`](test_tile_img/report.md)（风格转译真实照片）、[`test_tile_prompt/report.md`](test_tile_prompt/report.md)（纯文字意境，无参考图）。三场测试用同一套已购素材包 `farm_rpg_tiny`，分别装了 `godot-tilemap`（awesome-gamedev-agent-skills, 1199★）、`godot-tilemap-mastery`（GD-Agentic-Skills, 767★）、`tileset`+`reviewer/tilemap`（GodotMaker, 548★）三个 skill 各跑一遍。

结论先给：**没有单一 skill 在三种场景下都最优**，最好的用法是组合，而不是三选一。下文先给整体特点，再给"一句话 + 一份资产包 → 一个场景"这个具体场景下的推荐管线。

---

## 一、三个 skill 的整体特点

### 1. `godot-tilemap`（awesome-gamedev-agent-skills）

纯 markdown（SKILL.md + references），**无任何可执行脚本，零依赖**。内容是 Godot 4.x TileMapLayer 标准工作流文档：TileSet 构建、terrain set/peering bits、图层职责划分建议。

三场成绩：pixel 综合 6.0（色彩校准最准，MAE/覆盖率两项指标最佳，但结构偏简单）；img 综合 7（三者中游，色调与天空渐变处理最好，但村舍/奶牛摆放偏网格化重复）；prompt 综合 8.0（氛围温暖，但小溪硬直角边界、地面杂色被暖光染成色块）。

**特点**：稳定、可预测、无第三方脚本风险，但**完全没有地形边缘自动混合能力**——它指导 agent "应该分层"，却不提供任何工具去正确处理水陆/地形边界，边缘生硬是它在三场里的共同短板。适合作为**轻量默认选项**或**低成本二次校验**，不适合需要精细地形过渡的场景。

### 2. `godot-tilemap-mastery`（GD-Agentic-Skills）

markdown + **13 个可调用 GDScript 工具**（`terrain_autotile.gd`、`tile_pattern_stamper.gd`、`tilemap_chunking.gd`、`tilemap_data_manager.gd` 等），是三者中唯一自带可执行辅助脚本的方案。

三场成绩：pixel 综合 6.5（并列最高，细节还原最好，唯一正确识别出素材"草→水岸线透明像素叠加"需要独立 Shore 层）；img 综合 5.5（**三者最低**——森林大片同类地形时退化成逐格随机二选一，产生棋盘格瑕疵，agent 自己承认没调用自带的地形自动拼接）；prompt 综合 8.6（**三者最高**——溪流/小径用角点混合(blob-mask)算法正确处理，构图最有意图）。

**特点**：**天花板最高，方差也最大**。它的边缘处理能力（terrain autotile / blob-mask）是三者里唯一能把地形边界做自然的，但效果完全取决于 agent 有没有在当前场景里"想起来"主动调用这些脚本——img 任务的翻车证明了这一点。另外 `tile_pattern_stamper.gd` 存在一个**实测发现的真实锚点坐标 bug**（pixel 任务里导致误放的流水瓦片列、房屋屋顶选错变体）。**必须显式要求它调用自己的地形自动拼接工具，并对 stamper 输出做人工/程序复核**，否则大片同类地形会退化成随机拼贴。

### 3. GodotMaker（`tileset` + `reviewer/tilemap`）

两个独立阶段：`tileset` skill 负责**生成新的 TileSet 资源**（读 `ASSET_REQUEST.json`，指定 autotile 档位，由 provider 画图产出新图集）；`reviewer/tilemap` 是生成后质检 checklist + gotchas。

三场成绩：pixel 综合 5.5（**三者最低**，MAE/RMS 两项指标最差，细节最简单，但唯一一次就完整交付无需重跑）；img 综合 8（**三者最高**，场景尺度最大 60×36、建筑变体最丰富、混种秋林色彩过渡最自然，且是三者中**最省**的一个，20.4 min/59 次工具调用）；prompt 综合 7.3（垫底，但代价极其悬殊——326.7 分钟/5.4 小时、431 次工具调用、743 个 LLM 轮次，是 mastery 的 10 倍耗时）。

**关键发现（技能范围错配）**：`tileset` skill 的正文明确写着 *"A TileSet is a reusable tile library; creating or painting a TileMap is outside this skill."* 也就是说，"用已购素材包铺一个 TileMap"这件事**本来就不在它的设计范围内**。它在 img 任务表现最好，不是因为这个 skill 突然会铺图了，而是因为**参考照片给了它一个明确的构图/色彩目标**，此时 `reviewer/tilemap` 的自查环节（y-sort、碰撞体核对）能发挥真实价值；一旦**没有参考图**（prompt 任务），agent 等于在没有任何铺图 skill 指导的情况下反复试错，直接烧穿 5 小时。

**特点**：`reviewer/tilemap` 的 QA checklist 本身**在三场里全部证明有效且成本很低**（只是复核，不是重新生成），value 与是否有参考图无关；但 `tileset` skill 不该被当作铺图技能使用——它更适合"从零生成新素材"这类完全不同的任务。

---

## 二、跨三场的成绩总览

| Skill | pixel（像素还原） | img（风格转译） | prompt（纯文字构图） |
|---|---|---|---|
| `godot-tilemap` | 6.0 | 7 | 8.0 |
| `godot-tilemap-mastery` | **6.5**（并列最高） | 5.5（最低） | **8.6**（最高） |
| GodotMaker（tileset+reviewer） | 5.5（最低） | **8**（最高） | 7.3（最低，代价最悬殊） |

规律很清楚：**有具体参照物（像素级截图、真实照片）时，GodotMaker 的整体流程质量能打平甚至反超；完全没有参照物、纯靠文字构图决策时，`godot-tilemap-mastery` 明显最强，GodotMaker 反而是代价最悬殊的短板。**

---

## 三、"一句话 + 一份资产包 → 一个游戏场景" 的推荐管线

这个场景等价于 `test_tile_prompt` 的设定：**没有参考图，只有文字描述**。基于上面的结论，推荐如下管线：

### 阶段 0：素材盘点（轻量，可选）

用 `godot-tilemap` 的纯文档指引（`references/tileset-and-terrains.md`）快速扫一遍资产包：有哪些 atlas source、`texture_region_size` 是多少、哪些贴图是可自动拼接的地形（草/水/悬崖），哪些是一次性装饰性 stamp（房屋/教堂/路灯）。这一步零依赖、零风险，能避免后续步骤猜错图集参数。

### 阶段 1：主作者 —— `godot-tilemap-mastery`

由它主导实际铺图，理由：三场里构图质量最高、唯一具备真正好用的地形边缘混合能力。但**必须显式约束**两点，对应它已实测暴露的两个失败模式：

1. **强制要求对任何大片同类地形（森林、草地、水域）调用它自带的地形自动拼接/连接脚本**（如 `terrain_autotile.gd` 的 `set_cells_terrain_connect` 类接口），而不是让 agent 用逐格随机二选一去"手工"铺——img 任务的棋盘格瑕疵正是后者导致的。
2. **对 `tile_pattern_stamper.gd` 的输出做强制复核**（渲染预览 + 抽样核对坐标），不要盲信一次盖章结果——pixel 任务里已实测到它的锚点坐标计算 bug，会导致误放的瀑布瓦片、选错的屋顶变体。
3. 任何水陆边界都应遵循它已证明奏效的做法：单独拆一层 Shore/岸线过渡层，而不是把透明叠加像素混进 Ground 层。

### 阶段 2：轻量校验（可选，不建议整场重跑）

不需要再花一次完整预算去跑 `godot-tilemap` 做第二个独立场景——两个全量并行方案的成本是单个方案的两倍，而 prompt 任务的数据显示"多花工具调用不必然换来更好效果"（`godot-tilemap` 自己那次重跑就是反例：134 分钟、262 次工具调用，成品仍不及 mastery）。更划算的做法是：**把 `godot-tilemap` 的图层划分/peering-bit 约定当成一份检查清单**，让阶段 1 的同一个 agent 在收尾前用它自查一遍分层是否合理，而不是另起一次生成。只有当预算充足、想要两个候选场景挑更好的一个时，才值得让 `godot-tilemap` 也跑一次完整方案。

### 阶段 3：终审 —— GodotMaker 的 `reviewer/tilemap`（必做，不装 `tileset`）

无论阶段 1 由谁生成，最后都跑一遍 `reviewer/tilemap` 的 `checklist.md` + `gotchas.md` 做**作者无关**的质检：y-sort 作用域是否只开在需要的图层、碰撞体设置、图层顺序等。这一步在三场测试里**全部证明有效且成本很低**（只是复核已有场景，不重新生成），与是否有参考图无关。

**明确不要**为这个场景装 GodotMaker 的 `tileset` skill——它的定位是"生成新 TileSet 资源"，官方文档自己说明"铺图不在它的范围内"，prompt 任务里误用它导致 5.4 小时、85M token 的异常消耗，正是这个管线要避免复现的坑。

### 管线总结图

```
文字描述 + 资产包
   │
   ▼
[阶段0] godot-tilemap 文档 → 素材盘点（可选，零成本）
   │
   ▼
[阶段1] godot-tilemap-mastery 主导铺图
         ├─ 强制调用自带地形自动拼接（防棋盘格）
         ├─ 人工复核 stamper 输出（防锚点 bug）
         └─ 水陆边界拆 Shore 层
   │
   ▼
[阶段2] （可选）用 godot-tilemap 的分层约定自查，而非另起一次生成
   │
   ▼
[阶段3] GodotMaker 的 reviewer/tilemap checklist 终审（不装 tileset）
   │
   ▼
可在编辑器继续手工微调的成品场景
```

预期成本量级：主要开销集中在阶段 1（mastery 单独跑一次的量级，prompt 任务里干净重跑只need 30.6 分钟/83 次工具调用），阶段 3 只是一次复核，成本很低。相比误用 GodotMaker `tileset` 单干可能导致的 5+ 小时失控，这条管线的总耗时应该在 1 小时以内。

---

## 四、边界情况：如果之后有参考图（截图或照片）

以上管线是针对"纯文字、无参考图"设计的。如果场景换成**有一张具体参考图**（像素级截图或风格参考照片），结论会反过来：

- **有明确像素目标**（如 UI 截图）：`godot-tilemap-mastery` 仍是首选（pixel 任务综合分并列最高），但阶段 3 的终审同样必要——它的细节 bug（stamper 锚点、瓦片变体选错）在这种任务里一样会出现。
- **有风格参考照片、追求艺术转译而非像素匹配**：GodotMaker 的 `tileset`+`reviewer` 组合反而是三者最优且最省（img 任务综合 8 分、最快 20.4 分钟）——因为参考图给了它明确的构图/色彩目标，`tileset` 的"生成新资源"逻辑此时不再是短板，`reviewer` 的自查环节能发挥完整价值。此时可以把 GodotMaker 全套请回主作者的位置，`godot-tilemap-mastery` 反而要小心它在大片连续地形上的棋盘格风险。

一句话：**有没有参考图，决定了 GodotMaker 的 `tileset` 是"帮手"还是"陷阱"**——本文的推荐管线专门针对没有参考图的场景排除了它。
