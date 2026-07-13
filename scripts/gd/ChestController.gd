extends Sprite2D

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

@export var interact_range: float = 92.0

var _contents: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var _opened_once: bool = false
var _ui_visible: bool = false
var _player: CharacterBody2D
var _inventory
var _interact_point: Node2D
var _player_near: bool = false
var _chest_ui: Control
var _grid_slots: Array = []
var _grid_cursor: Panel
var _grid_index: int = 0
var _pulse_time: float = 0.0
var _tex_closed: Texture2D
var _tex_opened: Texture2D

func _ready() -> void:
	_player = get_tree().current_scene.get_node_or_null("Player")
	_inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
	_interact_point = get_node_or_null("InteractPoint")
	_tex_closed = load("res://assets/sprites/items/chest_closed.png")
	_tex_opened = load("res://assets/sprites/items/chest_opened.png")
	if _tex_closed:
		texture = _tex_closed
	call_deferred("build_chest_ui")

func _process(delta: float) -> void:
	update_player_distance()
	if _ui_visible and Input.is_key_pressed(KEY_ESCAPE):
		close_chest()
	if _ui_visible and not _player_near:
		close_chest()
		GameState.show_notice("离箱子太远，已自动关闭")
	if _ui_visible:
		handle_grid_navigation()
		_pulse_time += delta
		if _grid_cursor:
			var pulse := 0.75 + 0.25 * sin(_pulse_time * 4.0)
			_grid_cursor.modulate = Color(1, 1, 1, pulse)

func is_ui_open() -> bool:
	return _ui_visible

func is_player_near() -> bool:
	return _player_near

func get_interact_distance(from_position: Vector2) -> float:
	return from_position.distance_to(get_interact_world_position())

func can_interact_from(from_position: Vector2) -> bool:
	return get_interact_distance(from_position) <= interact_range

func open_chest() -> bool:
	if not _player_near:
		return false
	populate_starter_items_if_needed()
	if _tex_opened:
		texture = _tex_opened
	_ui_visible = true
	GameState.is_modal_ui_open = true
	_grid_index = 0
	if _inventory:
		_inventory.set_cursor_visible(false)
	refresh_grid()
	if _chest_ui:
		_chest_ui.visible = true
	call_deferred("update_grid_cursor")
	GameState.show_notice("已打开箱子")
	return true

func close_chest() -> void:
	if _tex_closed:
		texture = _tex_closed
	_ui_visible = false
	GameState.is_modal_ui_open = false
	if _inventory:
		_inventory.set_cursor_visible(true)
	if _chest_ui:
		_chest_ui.visible = false

func try_take_selected_item() -> bool:
	if not _ui_visible or _grid_index < 0 or _grid_index >= _contents.size():
		return false
	var item_id := _contents[_grid_index]
	if item_id == ItemDatabase.NONE:
		GameState.show_notice("这个格子是空的")
		return false
	if not _inventory or not _inventory.add_item(item_id, 1):
		GameState.show_notice("背包已满，无法取出更多物品")
		return false
	_contents[_grid_index] = ItemDatabase.NONE
	refresh_grid()
	GameState.show_notice("获得：%s" % ItemDatabase.get_item_name(item_id))
	return true

func populate_starter_items_if_needed() -> void:
	if _opened_once:
		return
	_contents[0] = ItemDatabase.SCISSORS
	_contents[1] = ItemDatabase.WATERING_CAN_EMPTY
	_contents[2] = ItemDatabase.SEED_GEM
	_contents[3] = ItemDatabase.TORCH
	_opened_once = true

func update_player_distance() -> void:
	if _player == null:
		_player_near = false
		return
	var player_point: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	_player_near = player_point.distance_to(get_interact_world_position()) <= interact_range

func get_interact_world_position() -> Vector2:
	return _interact_point.global_position if _interact_point else global_position

func handle_grid_navigation() -> void:
	var old_index := _grid_index
	if Input.is_action_just_pressed("inv_left"):
		_grid_index = (_grid_index + 8) % 9
	elif Input.is_action_just_pressed("inv_right"):
		_grid_index = (_grid_index + 1) % 9
	elif Input.is_action_just_pressed("up"):
		_grid_index = (_grid_index + 6) % 9
	elif Input.is_action_just_pressed("down"):
		_grid_index = (_grid_index + 3) % 9
	if old_index != _grid_index:
		call_deferred("update_grid_cursor")

func build_chest_ui() -> void:
	var ui = get_tree().current_scene.get_node_or_null("UI")
	_chest_ui = Control.new()
	_chest_ui.name = "ChestUI"
	_chest_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_ui.visible = false

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_ui.add_child(overlay)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(280, 340)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	panel_style.border_color = Color(0.8, 0.65, 0.3, 1)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "箱子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	var slot_bg := load("res://assets/tiles/ui_slot.png")
	for i in range(9):
		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = slot_bg
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)
		grid.add_child(slot)
		_grid_slots.append(slot)

	var hint := Label.new()
	hint.text = "方向键移动  E 取出  Esc 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)

	_chest_ui.add_child(panel)

	_grid_cursor = Panel.new()
	_grid_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_cursor.z_index = 10
	var cursor_style := StyleBoxFlat.new()
	cursor_style.bg_color = Color(1, 0.85, 0.15, 0)
	cursor_style.border_color = Color(1, 0.9, 0.25, 1)
	cursor_style.border_width_left = 3
	cursor_style.border_width_right = 3
	cursor_style.border_width_top = 3
	cursor_style.border_width_bottom = 3
	cursor_style.corner_radius_top_left = 6
	cursor_style.corner_radius_top_right = 6
	cursor_style.corner_radius_bottom_left = 6
	cursor_style.corner_radius_bottom_right = 6
	_grid_cursor.add_theme_stylebox_override("panel", cursor_style)
	panel.add_child(_grid_cursor)

	if ui:
		ui.add_child(_chest_ui)
	else:
		get_tree().current_scene.add_child(_chest_ui)

func refresh_grid() -> void:
	for i in range(_grid_slots.size()):
		var icon = _grid_slots[i].get_node_or_null("Icon")
		if icon == null:
			continue
		var item_id := _contents[i]
		if item_id == ItemDatabase.NONE:
			icon.texture = null
			icon.visible = false
		else:
			icon.texture = ItemDatabase.get_icon(item_id)
			icon.visible = true

func update_grid_cursor() -> void:
	if _grid_cursor == null or _grid_index < 0 or _grid_index >= _grid_slots.size():
		return
	var slot = _grid_slots[_grid_index]
	if slot == null or slot.size == Vector2.ZERO:
		call_deferred("update_grid_cursor")
		return
	var padding := 4.0
	_grid_cursor.global_position = slot.global_position - Vector2(padding, padding)
	_grid_cursor.size = slot.size + Vector2(padding * 2.0, padding * 2.0)
