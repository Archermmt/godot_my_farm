extends SceneTree

const MAIN_PATH := "res://scenes/app/main.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load(MAIN_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Variant = main.get_node("UILayer/InventoryInterface")
	ui._open_panel()
	ui.focus_container = &"itembar"
	ui.focus_index = 0
	ui._refresh_all()
