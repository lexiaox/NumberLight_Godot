# InventoryController.gd — 物品栏（背包）+ 光标 + 键盘导航
extends HBoxContainer

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

@export var slot_count: int = 6

var _items: Array[int] = []
var _counts: Array[int] = []
var _slot_bgs: Array = []
var _item_icons: Array = []
var _count_labels: Array = []
var _selected_index: int = 0
var _normal_tex: Texture2D
var _selected_tex: Texture2D
var _cursor: Panel
var _pulse_time: float = 0.0
var _cursor_visible: bool = true
const CURSOR_PADDING: float = 5.0

func _ready():
    _normal_tex = load("res://assets/tiles/ui_slot.png")
    _selected_tex = load("res://assets/tiles/ui_slot_selected.png")
    for i in range(slot_count):
        _items.append(0); _counts.append(0)
    build_slots()
    highlight_slot(0)
    call_deferred("create_cursor")

func build_slots():
    for i in range(slot_count):
        var node_name = "Slot%d" % (i + 1)
        var bg = get_node_or_null(node_name)
        if not bg:
            bg = TextureRect.new()
            bg.name = node_name
            bg.custom_minimum_size = Vector2(48, 48)
            bg.layout_mode = 2
            add_child(bg)
        bg.texture = _normal_tex
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _slot_bgs.append(bg)

        var center = CenterContainer.new()
        center.name = "IconCenter"
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        center.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(center)

        var icon = TextureRect.new()
        icon.name = "Icon"
        icon.custom_minimum_size = Vector2(40, 40)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon.visible = false
        center.add_child(icon)
        _item_icons.append(icon)

        var label = Label.new()
        label.name = "Count"
        label.offset_left = 28; label.offset_top = 28
        label.offset_right = 50; label.offset_bottom = 50
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        label.add_theme_font_size_override("font_size", 10)
        label.add_theme_color_override("font_outline_color", Color.BLACK)
        label.add_theme_constant_override("outline_size", 3)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(label)
        _count_labels.append(label)

func _process(delta):
    if not GameState.is_modal_ui_open:
        if Input.is_action_just_pressed("inv_left"):
            if _selected_index > 0:
                unhighlight_slot(_selected_index)
                _selected_index -= 1
                highlight_slot(_selected_index)
                update_cursor_position()
        elif Input.is_action_just_pressed("inv_right"):
            if _selected_index < slot_count - 1:
                unhighlight_slot(_selected_index)
                _selected_index += 1
                highlight_slot(_selected_index)
                update_cursor_position()

    if _cursor and _cursor_visible:
        _pulse_time += delta
        var pulse = 0.75 + 0.25 * sin(_pulse_time * 4.0)
        _cursor.modulate = Color(1, 1, 1, pulse)

func create_cursor():
    _cursor = Panel.new()
    _cursor.name = "SelectionCursor"
    var style = StyleBoxFlat.new()
    style.bg_color = Color(1, 0.85, 0.15, 0)
    style.border_color = Color(1, 0.9, 0.25, 1)
    style.border_width_left = 3; style.border_width_right = 3
    style.border_width_top = 3; style.border_width_bottom = 3
    style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
    _cursor.add_theme_stylebox_override("panel", style)
    _cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cursor.z_index = 10

    var parent = get_parent()
    if parent is Control: parent.add_child(_cursor)
    else: add_child(_cursor)
    update_cursor_position()

func update_cursor_position():
    if not _cursor or _selected_index < 0 or _selected_index >= slot_count: return
    var slot = _slot_bgs[_selected_index]
    if not slot: return
    if slot.size == Vector2.ZERO:
        call_deferred("update_cursor_position"); return
    _cursor.global_position = slot.global_position - Vector2(CURSOR_PADDING, CURSOR_PADDING)
    _cursor.size = slot.size + Vector2(CURSOR_PADDING * 2, CURSOR_PADDING * 2)

func set_cursor_visible(visible: bool):
    _cursor_visible = visible
    if _cursor: _cursor.visible = visible

func add_item(item_id: int, count: int = 1) -> bool:
    if item_id == 0: return false
    for i in range(slot_count):
        if _items[i] == item_id:
            _counts[i] += count; refresh_slot(i); return true
    for i in range(slot_count):
        if _items[i] == 0:
            _items[i] = item_id; _counts[i] = count; refresh_slot(i); return true
    return false

func remove_item(slot_index: int = -1, count: int = 1) -> bool:
    if slot_index < 0: slot_index = _selected_index
    if slot_index < 0 or slot_index >= slot_count: return false
    if _items[slot_index] == 0: return false
    _counts[slot_index] -= count
    if _counts[slot_index] <= 0:
        _items[slot_index] = 0; _counts[slot_index] = 0
    refresh_slot(slot_index)
    return true

func replace_selected_item(new_item_id: int):
    if _selected_index < 0 or _selected_index >= slot_count: return
    if _items[_selected_index] == 0: return
    _items[_selected_index] = new_item_id
    refresh_slot(_selected_index)

func get_selected_item() -> int:
    if _selected_index < 0 or _selected_index >= slot_count: return 0
    return _items[_selected_index]

func get_selected_index() -> int: return _selected_index

func refresh_slot(i: int):
    if i < 0 or i >= slot_count: return
    var id = _items[i]
    var icon = _item_icons[i]
    var label = _count_labels[i]
    if id == 0:
        icon.texture = null; icon.visible = false; label.text = ""
    else:
        icon.texture = ItemDatabase.get_icon(id); icon.visible = true
        label.text = str(_counts[i]) if _counts[i] > 1 else ""

func highlight_slot(index: int):
    if index >= 0 and index < slot_count and _slot_bgs[index] and _selected_tex:
        _slot_bgs[index].texture = _selected_tex

func unhighlight_slot(index: int):
    if index >= 0 and index < slot_count and _slot_bgs[index] and _normal_tex:
        _slot_bgs[index].texture = _normal_tex
