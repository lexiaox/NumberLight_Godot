# ChestController.gd — 箱子交互 + 九宫格UI
extends Sprite2D

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

@export var interact_range: float = 90.0

var _contents: Array[int] = []
var _opened: bool = false
var _ui_visible: bool = false
var _player: CharacterBody2D
var _inventory
var _player_near: bool = false
var _chest_ui: Control
var _grid_slots: Array = []
var _grid_cursor: Panel
var _grid_index: int = 0
var _pulse_time: float = 0.0
var _tex_closed: Texture2D
var _tex_opened: Texture2D

func _ready():
    _player = get_tree().current_scene.get_node_or_null("Player")
    _inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
    _tex_closed = load("res://assets/sprites/items/箱子-关闭.png")
    _tex_opened = load("res://assets/sprites/items/箱子-打开.png")
    if _tex_closed: texture = _tex_closed
    for i in range(9): _contents.append(0)
    call_deferred("build_chest_ui")

func _process(delta):
    if _player:
        _player_near = _player.global_position.distance_to(global_position) <= interact_range

    if Input.is_action_just_pressed("interact"):
        if _ui_visible: try_take_item()
        elif _player_near: open_chest()

    if _ui_visible and Input.is_key_pressed(KEY_ESCAPE): close_chest()
    if _ui_visible and not _player_near: close_chest()

    if _ui_visible:
        handle_grid_navigation()
        _pulse_time += delta
        if _grid_cursor:
            var pulse = 0.75 + 0.25 * sin(_pulse_time * 4.0)
            _grid_cursor.modulate = Color(1, 1, 1, pulse)

func open_chest():
    if not _opened:
        _contents[0] = ItemDatabase.HOE; _contents[1] = ItemDatabase.TORCH
        _contents[2] = ItemDatabase.SCISSORS; _contents[3] = ItemDatabase.WATERING_CAN_EMPTY
        _contents[4] = ItemDatabase.SEED_GEM; _contents[5] = ItemDatabase.SEED_VINE
        _opened = true
    if _tex_opened: texture = _tex_opened
    _ui_visible = true; GameState.is_modal_ui_open = true; _grid_index = 0
    if _inventory: _inventory.set_cursor_visible(false)
    refresh_grid()
    if _chest_ui: _chest_ui.visible = true
    call_deferred("update_grid_cursor")

func close_chest():
    if _tex_closed: texture = _tex_closed
    _ui_visible = false; GameState.is_modal_ui_open = false
    if _inventory: _inventory.set_cursor_visible(true)
    if _chest_ui: _chest_ui.visible = false

func try_take_item():
    if _grid_index < 0 or _grid_index >= 9: return
    var id = _contents[_grid_index]
    if id == 0: return
    if _inventory and _inventory.add_item(id, 1):
        _contents[_grid_index] = 0; refresh_grid()

func handle_grid_navigation():
    var old = _grid_index
    if Input.is_action_just_pressed("inv_left"): _grid_index = (_grid_index + 8) % 9
    elif Input.is_action_just_pressed("inv_right"): _grid_index = (_grid_index + 1) % 9
    elif Input.is_action_just_pressed("up"): _grid_index = (_grid_index + 6) % 9
    elif Input.is_action_just_pressed("down"): _grid_index = (_grid_index + 3) % 9
    if old != _grid_index: call_deferred("update_grid_cursor")

func build_chest_ui():
    var ui = get_tree().current_scene.get_node_or_null("UI")
    _chest_ui = Control.new(); _chest_ui.name = "ChestUI"
    _chest_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    _chest_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var overlay = ColorRect.new()
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0, 0, 0, 0.4); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _chest_ui.add_child(overlay)

    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(280, 340)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    var ps = StyleBoxFlat.new()
    ps.bg_color = Color(0.12, 0.10, 0.08, 0.95)
    ps.border_color = Color(0.8, 0.65, 0.3, 1)
    ps.border_width_left = 3; ps.border_width_right = 3
    ps.border_width_top = 3; ps.border_width_bottom = 3
    ps.corner_radius_top_left = 12; ps.corner_radius_top_right = 12
    ps.corner_radius_bottom_left = 12; ps.corner_radius_bottom_right = 12
    ps.content_margin_left = 16; ps.content_margin_right = 16
    ps.content_margin_top = 16; ps.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", ps)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 12)
    panel.add_child(vbox)

    var title = Label.new(); title.text = "箱子"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
    vbox.add_child(title)

    var grid_container = GridContainer.new(); grid_container.columns = 3
    grid_container.add_theme_constant_override("h_separation", 8)
    grid_container.add_theme_constant_override("v_separation", 8)
    grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(grid_container)

    var slot_bg_tex = load("res://assets/tiles/ui_slot.png")
    for i in range(9):
        var slot = TextureRect.new()
        slot.custom_minimum_size = Vector2(56, 56)
        slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        slot.texture = slot_bg_tex
        var icon = TextureRect.new(); icon.name = "Icon"
        icon.set_anchors_preset(Control.PRESET_FULL_RECT)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; icon.visible = false
        slot.add_child(icon)
        grid_container.add_child(slot)
        _grid_slots.append(slot)

    var hint = Label.new()
    hint.text = "↑↓←→ 移动  E 取出  Esc 关闭"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 11)
    hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    vbox.add_child(hint)

    _chest_ui.add_child(panel)

    _grid_cursor = Panel.new()
    var cs = StyleBoxFlat.new()
    cs.bg_color = Color(1, 0.85, 0.15, 0); cs.border_color = Color(1, 0.9, 0.25, 1)
    cs.border_width_left = 3; cs.border_width_right = 3
    cs.border_width_top = 3; cs.border_width_bottom = 3
    cs.corner_radius_top_left = 6; cs.corner_radius_top_right = 6
    cs.corner_radius_bottom_left = 6; cs.corner_radius_bottom_right = 6
    _grid_cursor.add_theme_stylebox_override("panel", cs)
    _grid_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE; _grid_cursor.z_index = 10
    panel.add_child(_grid_cursor)

    if ui: ui.add_child(_chest_ui)
    else: get_tree().current_scene.add_child(_chest_ui)
    _chest_ui.visible = false

func refresh_grid():
    for i in range(9):
        var icon = _grid_slots[i].get_node_or_null("Icon")
        if not icon: continue
        var id = _contents[i]
        if id == 0: icon.texture = null; icon.visible = false
        else: icon.texture = ItemDatabase.get_icon(id); icon.visible = true

func update_grid_cursor():
    if not _grid_cursor or _grid_index < 0 or _grid_index >= 9: return
    var slot = _grid_slots[_grid_index]
    if not slot or not slot.is_inside_tree(): return
    if slot.size == Vector2.ZERO: call_deferred("update_grid_cursor"); return
    var pad = 4.0
    _grid_cursor.global_position = slot.global_position - Vector2(pad, pad)
    _grid_cursor.size = slot.size + Vector2(pad * 2, pad * 2)

func is_ui_open() -> bool: return _ui_visible
func is_player_near() -> bool: return _player_near
