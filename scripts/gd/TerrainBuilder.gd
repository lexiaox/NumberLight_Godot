@tool
extends Node

@export var build_on_ready: bool = true
@export var clear_and_rebuild: bool = false

func _ready() -> void:
	if build_on_ready:
		build_terrain()

func _process(_delta: float) -> void:
	if clear_and_rebuild:
		clear_and_rebuild = false
		_clear_all_layers()
		build_terrain()

func build_terrain() -> void:
	var layers := _get_tile_layers()
	if layers.is_empty():
		push_error("TerrainBuilder: no TileMap nodes found!")
		return

	print("TerrainBuilder: found %d TileMap layers" % layers.size())

	# The current DayFarm scene keeps its terrain data on 3 TileMap nodes.
	# Water and fence visuals are handled by Sprite2D decorations, so there is
	# nothing else to rebuild here on startup.
	for layer in layers:
		if layer is TileMap and layer.tile_set == null:
			push_warning("TerrainBuilder: TileMap '%s' has no TileSet assigned." % layer.name)

func _get_tile_layers() -> Array:
	var result: Array = []
	var parent_node := get_parent()
	if not parent_node:
		return result

	for child in parent_node.get_children():
		if child is TileMap:
			result.append(child)

	return result

func _clear_all_layers() -> void:
	for layer in _get_tile_layers():
		if layer is TileMap:
			layer.clear()
