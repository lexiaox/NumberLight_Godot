class_name ItemDatabase
extends Node

const NONE := 0
const HOE := 1
const SCISSORS := 2
const TORCH := 4
const SEED_GEM := 5
const SEED_VINE := 6
const GEM := 7
const WATERING_CAN_EMPTY := 9
const WATERING_CAN_FULL := 10
const WATERING_CAN := WATERING_CAN_EMPTY
const VINE_FRUIT := SEED_VINE

enum ItemType { NONE, TOOL, SEED, DROP }

static var _registry := {
	HOE: {"id": HOE, "name": "Hoe", "icon": "res://assets/sprites/icons/icon_hoe.png", "type": ItemType.TOOL},
	SCISSORS: {"id": SCISSORS, "name": "Scissors", "icon": "res://assets/sprites/icons/icon_scissors.png", "type": ItemType.TOOL},
	TORCH: {"id": TORCH, "name": "Torch", "icon": "res://assets/sprites/icons/icon_torch.png", "type": ItemType.TOOL},
	SEED_GEM: {"id": SEED_GEM, "name": "Gem Seed", "icon": "res://assets/sprites/icons/icon_seed_gem.png", "type": ItemType.SEED},
	SEED_VINE: {"id": SEED_VINE, "name": "Vine Seed", "icon": "res://assets/sprites/icons/icon_seed_vine.png", "type": ItemType.SEED},
	GEM: {"id": GEM, "name": "Gem Flower", "icon": "res://assets/sprites/icons/icon_gem.png", "type": ItemType.DROP},
	WATERING_CAN_EMPTY: {"id": WATERING_CAN_EMPTY, "name": "Empty Can", "icon": "res://assets/sprites/icons/icon_watering_empty.png", "type": ItemType.TOOL},
	WATERING_CAN_FULL: {"id": WATERING_CAN_FULL, "name": "Full Can", "icon": "res://assets/sprites/icons/icon_watering_full.png", "type": ItemType.TOOL}
}

static var _icon_cache := {}

static func get_def(item_id: int) -> Dictionary:
	return _registry.get(item_id, {})

static func get_item_name(item_id: int) -> String:
	var item_def := get_def(item_id)
	return str(item_def.get("name", ""))

static func get_type(item_id: int) -> int:
	var item_def := get_def(item_id)
	return int(item_def.get("type", ItemType.NONE))

static func get_icon(item_id: int) -> Texture2D:
	if item_id == NONE:
		return null
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]

	var item_def := get_def(item_id)
	if item_def.is_empty():
		return null

	var texture := load(str(item_def.get("icon", ""))) as Texture2D
	if texture:
		_icon_cache[item_id] = texture
	return texture

static func is_watering_can(item_id: int) -> bool:
	return item_id == WATERING_CAN_EMPTY or item_id == WATERING_CAN_FULL
