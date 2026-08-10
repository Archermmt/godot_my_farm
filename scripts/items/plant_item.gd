class_name PlantItem
extends HarvestableItem

var plant_state: PlantState = null
var plant_meta: PlantMeta = null


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if not item_state is PlantState or not item_meta is PlantMeta:
		return ERR_INVALID_PARAMETER
	var bind_error := super.bind_state(item_state, item_meta)
	if bind_error != OK:
		return bind_error
	plant_state = item_state as PlantState
	plant_meta = item_meta as PlantMeta
	return OK
