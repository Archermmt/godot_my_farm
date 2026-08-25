代码整理顺序：(data,effects)->state->autoload->items->world->actors->ui->app


23. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/data/item/harvestable_stage.gd
看一下这个stage和plant_stage是不是可以合并？他们都表示harvestable某一个阶段的信息，看看是不是都可以合并到harvestable_stage，可以考虑plant不用days决定阶段而是用health，这样就喝harvestable stage的决定方式统一了，plant growth可以变成health增加

24. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/plant.gd
_refresh_stage_visual 变成复用基类的refresh_visual，plant_state和plant_meta改成复用基类的get_state和get_meta，stage_index和current_stage可以合并到harvestable里面

25. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/seed.gd
_init换成_new传入state

26. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/outcome
考虑这些outcome是否可以统一成一个outcome.gd：1.不需要记录error了，2.只需要记录cells和items信息，cells是影响到了哪些cell，是array<vector2>,items是作用到了哪些item，是dict<StringName, ItemState>来表示item被使用工具之后的不同状态，例如destroyed，hurt，planted，dropped等，ItemState可以加上用于记录item当前各种状态的参数（phase，类型是ItemMeta.ItemPhase）。用这两个信息可以覆盖现有的所有outcome信息

28. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/seed.gd
if target_cells.size() > available_count: 判断太简单了，有可能target_cells中又一些被占用了，应该是下面的的循环过程进行计数，超过available_count就break

29. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/seed.gd
if not map.check_cell(cell, BaseMap.CellCondition.PLANTABLE) 这里改成用cell.plantable() 来检查吧，这种cell应该负责的逻辑不要放在map里面

30. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/items/tool.gd
targets_cells 改成 is_cell_tool，名字比较直观
