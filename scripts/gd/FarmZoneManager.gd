extends Node

@export var zone_tile_w: int = 3
@export var zone_tile_h: int = 3
@export var left_field_col: int = 5
@export var right_field_col: int = 16
@export var field_row_start: int = 8
@export var tile_pixel_size: int = 32

var _zones: Array = []
var _current_zone: Dictionary = {}
var _player: CharacterBody2D
var _zone_label: Label

func _ready() -> void:
	_player = get_tree().current_scene.get_node_or_null("Player")
	_zone_label = get_tree().current_scene.get_node_or_null("UI/TopBar/ZoneLabel")
	create_zones()
	update_zone_label()

func _process(_delta: float) -> void:
	var zone = get_current_zone()
	if zone != _current_zone:
		_current_zone = zone
		update_zone_label()

func create_zones() -> void:
	_zones.clear()
	_create_field_zones("L", left_field_col)
	_create_field_zones("R", right_field_col)

func _create_field_zones(prefix: String, start_col: int) -> void:
	for row_block in range(2):
		for col_block in range(3):
			var zone_num: int = row_block * 3 + col_block + 1
			var zone_name: String = "%s%d" % [prefix, zone_num]
			var col: int = start_col + col_block * zone_tile_w
			var row: int = field_row_start + row_block * zone_tile_h
			var x: int = col * tile_pixel_size
			var y: int = row * tile_pixel_size
			var width: int = zone_tile_w * tile_pixel_size
			var height: int = zone_tile_h * tile_pixel_size
			_zones.append({
				"name": zone_name,
				"bounds": Rect2(x, y, width, height),
				"planted_crop": null,
				"is_tilled": false
			})

func get_current_zone() -> Dictionary:
	if not _player:
		return {}
	var pos: Vector2 = _player.position
	for zone in _zones:
		var bounds: Rect2 = zone.get("bounds", Rect2())
		if bounds.has_point(pos):
			return zone
	return {}

func plant_crop(zone_name: String, crop_name: String) -> bool:
	for zone in _zones:
		if str(zone.get("name", "")) == zone_name:
			if zone.get("planted_crop", null) != null:
				return false
			zone["planted_crop"] = crop_name
			zone["is_tilled"] = true
			return true
	return false

func can_interact_with_zone(zone_name: String) -> bool:
	var current: Dictionary = get_current_zone()
	return not current.is_empty() and str(current.get("name", "")) == zone_name

func clear_crop(zone_name: String) -> void:
	for zone in _zones:
		if str(zone.get("name", "")) == zone_name:
			zone["planted_crop"] = null

func get_all_zones() -> Array:
	return _zones

func update_zone_label() -> void:
	if not _zone_label:
		return
	if not _current_zone.is_empty():
		_zone_label.text = "Zone: %s" % str(_current_zone.get("name", ""))
	else:
		_zone_label.text = "Zone: Outside Field"
