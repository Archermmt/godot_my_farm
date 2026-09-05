代码整理顺序：(data,effects)->state->item->world->autoload->actors->ui->app

1. 思考state存在的必要性：目前state主要作用是信息的保存/加载，这个直接用runtime obj to_dict/from_dict就能实现，使用state只是想减少保存与加载的时间，这种保存与加载一般发生在save/load和map切换的时候，考虑：1.除了用json保存/加载以外有没有更加高效的信息保存形式；2.如果用state保存的话，是不是切换地图之后还需要内存中保留大量非激活地图的信息？这样以来运行过程中会造成内存负担越来越重，state的设计到底是好是坏？

2. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/autoload/game_manager.gd
npc_assignment不用了，需要的信息直接从NpcScheduleEvent获取

3. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/autoload/game_manager.gd
npc自己负责自己的schedule逻辑吧，game_manager只需要在切换地图的时候对npc进行enable和disable就行，同时calender_manager增加advanced_hour信号，npc通过这个信号刷新自己的schedule，并通过当前的map决定自己是否应该enable/disable，现在game_manager管理npc逻辑太多了

4. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/state/npc_state.gd
NPCState不需要记录cell，而是应该记录postion

5. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/autoload/interact_manager.gd
current_player不需要保存，全局只有一个player，可以通过GameManger.player获取

6. /Users/tongmeng/Desktop/codes/godot_my_farm/scripts/autoload/interact_manager.gd
_timeline_for_id 和 _dialogue_id 内连;begin 函数不需要传入player和target了，player是全局的，target也已经记录在current_target里面了，dialogic做成memeber吧，_ready的时候获取，不需要每次都重新拿了
