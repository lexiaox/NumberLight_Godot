extends Node

const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

@onready var _hud := get_parent().get_node_or_null("HUD")
@onready var _inventory := get_parent().get_node_or_null("BottomBar/Toolbar")
@onready var _zone_manager := get_tree().current_scene.get_node_or_null("FarmZoneManager")

func _ready() -> void:
	call_deferred("_refresh")

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if not _hud:
		return

	var selected_id := 0
	if _inventory and _inventory.has_method("get_selected_item"):
		selected_id = _inventory.get_selected_item()
	_hud.set_selected_item_name(ItemDatabase.get_item_name(selected_id) if selected_id != 0 else "Empty Hands")

	var objective := "Objective: Open the chest"
	var hint := "Move close to the chest and press E"

	if _inventory_has(ItemDatabase.SEED_GEM) or _inventory_has(ItemDatabase.SEED_VINE):
		objective = "Objective: Plant seeds in the field"
		hint = "Select seeds and press E on a farm tile"

	if selected_id == ItemDatabase.WATERING_CAN_EMPTY:
		objective = "Objective: Fill water at the well"
		hint = "Hold the empty can and press E near the well"
	elif selected_id == ItemDatabase.WATERING_CAN_FULL:
		objective = "Objective: Water the crop"
		hint = "Stand on the planted tile and press E"
	elif selected_id == ItemDatabase.SCISSORS:
		objective = "Objective: Harvest when mature"
		hint = "Switch to scissors and press E on a mature crop"

	if _zone_manager and _zone_manager.get_current_zone():
		if selected_id == ItemDatabase.SEED_GEM or selected_id == ItemDatabase.SEED_VINE:
			hint = "Press E here to plant"
		elif selected_id == ItemDatabase.WATERING_CAN_FULL:
			hint = "Press E here to water"

	_hud.set_objective(objective)
	_hud.set_interaction_hint(hint)

func _inventory_has(item_id: int) -> bool:
	if not _inventory:
		return false
	var item_array = _inventory.get("_items")
	return item_array is Array and item_id in item_array
