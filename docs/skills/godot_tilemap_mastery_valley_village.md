# Valley Village 的 TileMap Skill 使用记录

本文记录 Valley Village 场景如何使用 `godot-tilemap-mastery` 和购买的 `farm_rpg_tiny` 资源包，供后续继续创建 TileSet/TileMap 场景时复用。本版以 `scenes/maps/valley_village/reference.png` 为构图参考，用购买包素材重建春季山脚牧场的草地、山坡、河流、瀑布、谷仓和耕地；参考图仅用于布局和视觉验收，不作为运行时背景纹理。

## 1. Skill 位置与职责

本次使用的 skill 位于：

`/Users/tongmeng/.codex/skills/godot-tilemap-mastery/SKILL.md`

使用时先完整读取 `SKILL.md`，再按任务需要读取 `references/` 中的深度配方。skill 自带的 `scripts/` 是参考实现和运行时辅助脚本，不是游戏发布依赖；本场景最终只保存 Godot 场景文件（含其 atlas 注册）和购买包原始资源引用。

| 内容 | 用途 |
| --- | --- |
| `SKILL.md` | TileMapLayer、TileSet、terrain、批量写入和分层的总路由 |
| `references/tileset-editor-setup.md` | atlas、terrain、physics 和 custom data 的编辑器配置 |
| `references/runtime-tile-patterns.md` | terrain connect、pattern 和运行时 TileMap API |
| `references/expert-tilemap-architectures.md` | 分层、Y-sort、pattern 和大地图结构 |
| `scripts/terrain_autotile.gd`、`terrain_path_painter.gd` | terrain 区域和路径的批量绘制参考 |
| `scripts/tile_pattern_stamper.gd` | 房屋、桥梁等多格 prefab 的盖章参考 |
| `scripts/tilemap_chunking.gd`、`procedural_chunk_batcher.gd` | 大地图分块和批量更新参考 |

安装或迁移到另一台机器时，应把 skill 安装到 Codex 的 skills 目录，再通过 skill catalog 选择它；不要把整个 skill 目录复制进游戏的 `addons/`，也不要把临时生成脚本作为运行时依赖。

## 2. 购买资源盘点

资源根目录为 `assets/art/extern/farm_rpg_tiny`，署名为 `EmanuelleDev`。TileSet atlas 以 16 px 为网格，场景直接引用原始 PNG：

| TileSet source | 原始资源 | 用途 |
| ---: | --- | --- |
| 0 | `Tileset/Tileset Grass Spring.png` | 春季草地填充与 grass terrain |
| 1 | `Tileset/Water tile.png` | 河流水面填充 |
| 2 | `Tileset/Tileset Grass Water Spring.png` | 草水岸线过渡 |
| 3 | `Tileset/Tileset Grass Cliff Tileset Spring.png` | 北侧山坡/悬崖 |
| 4 | `Tileset/ALL props seasons.png` | 春季花草等装饰 tile |
| 5 | `Tileset/Spring Waterfall.png` | 动态瀑布 |
| 6 | `Tileset/Path tiles.png` | 村路与桥面辅助 tile |
| 7 | `Tileset/Tilled Soil and wet soil.png` | 农田耕地 |

房屋、井、树和木栅栏也直接引用购买包中的 PNG。场景内嵌的 TileSet 只注册这些购买 atlas，运行时不加载导出的 atlas、外部生成的 `.tres` 或参考图；临时检查/构建脚本也不属于地图运行时依赖。参考图只放在场景目录中供人工对照，不能挂到 `Sprite2D` 或背景节点上。

## 3. 场景分层与 terrain

场景文件为 `scenes/maps/valley_village/valley_village.tscn`。`ValleyVillage/TileMaps` 使用独立的 `TileMapLayer`：

`GroundLayer`、`MountainLayer`、`WaterLayer`、`ShoreLayer`、`FieldLayer`、`PathLayer`、`BridgeLayer`、`WaterfallLayer` 和 `HillsideFlowerLayer`。

TileSet terrain set 保留 `spring_grass` 与 `spring_water` 两个语义名称；Ground 的内部草地 tile `(9, 2)` 写入 `spring_grass` metadata，WaterLayer 使用购买水面 atlas 的明确格子。大面积区域遵循 `set_cells_terrain_connect()` 的批量工作流，避免对数千格逐格调用 `set_cell()`；少量桥、岸线、路径和农田格才使用带真实 `source_id` 的精确放置。

Ground 使用购买 atlas 的纯内部草地 tile `(9, 2)`，该 16x16 区域没有透明或边缘像素，适合整面填充。水陆边界保持独立的 `ShoreLayer`，这样岸线透明像素不会污染 Ground 的 terrain 自动拼接。`MountainLayer` 承担北侧山坡，`FieldLayer` 承担耕地，`HillsideFlowerLayer` 承担坡地花草；地图中没有单独的隐藏碰撞层。

## 4. 动态 TileSet 瀑布

瀑布必须是 TileSet 动画，而不是节点动画。`WaterfallLayer` 放置 source `5` 的 `(0, 0)` tile；该 atlas tile 跨 4x4 个 16 px 格子，即一个 64x64 帧。购买的 `Spring Waterfall.png` 横向包含 8 帧，因此 TileSetAtlasSource 配置为：

```text
texture_region_size = Vector2i(16, 16)
size_in_atlas = Vector2i(4, 4)
animation_columns = 8
animation_speed = 7.0
animation_frame_0..7/duration = 1.0
```

Godot 会在 TileMapLayer 渲染这个 atlas tile 时自动推进帧。最终场景中 `AnimatedSprite2D` 数量必须为 0；不要为瀑布再添加 Sprite、AnimationPlayer 或手写计时器。

## 5. 与 godot-ai 的配合流程

1. 用 `session_manage(op="list")` 和 `editor_manage(op="state")` 确认 Godot 版本、活动 session、当前场景和 readiness。
2. 文本或外部构建完成后，用 `scene_open(path, force_reload=true)` 让编辑器重新读取磁盘版本。不要让 godot-ai 和外部补丁同时修改同一个 `.tscn`。
3. 用 `scene_get_hierarchy` 检查 `TileMaps` 下的九个 TileMapLayer，以及 `FarmStructures`、`RanchProps`、`SpringTreeLine` 等装饰节点；用 `tileset_manage` 读取 atlas tile 坐标或图像。
4. 需要小范围编辑时用 `tilemap_manage`，传入明确的 `source_id`、atlas 坐标和地图坐标。大面积地形仍应在 Godot API 中使用 terrain connect 或 pattern，不要通过工具循环调用单格写入。
5. 用 `editor_screenshot(source="viewport_2d")` 检查编辑器画面；用 `project_run(mode="current", autosave=false)` 启动当前场景，再用 `editor_screenshot(source="game")` 检查运行画面。
6. 用 `logs_read(source="editor")` 和 `logs_read(source="game")` 读取错误。运行结束后用 `project_manage(op="stop")` 停止测试进程。

## 6. 交付前检查

- 场景只引用 `assets/art/extern/farm_rpg_tiny` 的购买资源，不引用自制 atlas 或背景图。
- 构图验收要对照 `scenes/maps/valley_village/reference.png`；它是验收输入，不是场景资源依赖。
- Ground 的大面积草地使用 terrain metadata 与批量连接工作流；Water、Shore 的水面和岸线保持独立语义层，并直接使用购买 atlas 的明确格子。
- 所有 `set_cell()` 调用都使用真实 source ID，并且只用于少量精确格。
- `WaterfallLayer` 使用 `size_in_atlas=4x4`、8 个 duration 为 `1.0` 的动画帧、`animation_columns=8`、`animation_speed=7.0`。
- `rg "AnimatedSprite2D" scenes/maps/valley_village/valley_village.tscn` 无结果。
- headless 加载场景后，Ground、Water、Waterfall 的 cell 数量非零，瀑布动画列数为 8，速度为 7.0。
- 不在场景中绘制人物、动物或 NPC；这些属于地图之外的运行时实体。
