class_name HarvestableItem
extends Item

var harvestable_state: HarvestableState = null
var harvestable_meta: HarvestableMeta = null


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if not item_state is HarvestableState or not item_meta is HarvestableMeta:
		return ERR_INVALID_PARAMETER
	var bind_error := super.bind_state(item_state, item_meta)
	if bind_error != OK:
		return bind_error
	harvestable_state = item_state as HarvestableState
	harvestable_meta = item_meta as HarvestableMeta
	return OK
