extends Node

const UIFont = preload("res://scripts/ui/UIFont.gd")

enum ToastKind { INFO, SUCCESS, WARNING }

@onready var _objective_label: Label = get_tree().current_scene.get_node_or_null("UI/TopBar/ObjectiveLabel")
@onready var _selected_item_label: Label = get_tree().current_scene.get_node_or_null("UI/BottomBar/SelectedItemLabel")
@onready var _interaction_hint_label: Label = get_tree().current_scene.get_node_or_null("UI/BottomBar/InteractionHintLabel")
@onready var _toast_label: Label = get_tree().current_scene.get_node_or_null("UI/ToastLabel")

var _toast_timer: float = 0.0

func _ready() -> void:
	UIFont.apply_to_subtree(get_tree().current_scene.get_node_or_null("UI"))
	set_objective("前往箱子")
	set_selected_item_name("未选择")
	set_interaction_hint("移动：WASD  互动：E  切换道具：左右方向键")
	if _toast_label:
		_toast_label.visible = false

func _process(delta: float) -> void:
	if _toast_timer <= 0.0:
		return
	_toast_timer -= delta
	if _toast_timer <= 0.0 and _toast_label:
		_toast_label.visible = false

func set_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = "当前目标：%s" % text

func set_selected_item_name(text: String) -> void:
	if _selected_item_label:
		_selected_item_label.text = "当前道具：%s" % text

func set_interaction_hint(text: String) -> void:
	if _interaction_hint_label:
		_interaction_hint_label.text = text

func clear_interaction_hint() -> void:
	set_interaction_hint("")

func show_toast(text: String, kind: int = ToastKind.INFO, duration: float = 2.0) -> void:
	if not _toast_label:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_timer = duration
	match kind:
		ToastKind.SUCCESS:
			_toast_label.modulate = Color(0.92, 1.0, 0.82)
		ToastKind.WARNING:
			_toast_label.modulate = Color(1.0, 0.9, 0.72)
		_:
			_toast_label.modulate = Color(0.9, 0.96, 1.0)
