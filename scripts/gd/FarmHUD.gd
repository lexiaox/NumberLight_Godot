extends Node

@onready var _objective_label: Label = get_tree().current_scene.get_node_or_null("UI/TopBar/ObjectiveLabel")
@onready var _selected_item_label: Label = get_tree().current_scene.get_node_or_null("UI/BottomBar/SelectedItemLabel")
@onready var _interaction_hint_label: Label = get_tree().current_scene.get_node_or_null("UI/BottomBar/InteractionHintLabel")
@onready var _toast_label: Label = get_tree().current_scene.get_node_or_null("UI/ToastLabel")

var _toast_timer: float = 0.0

func _ready() -> void:
	set_objective("Objective: Open the chest")
	set_selected_item_name("Empty Hands")
	set_interaction_hint("Move: WASD  Interact: E  Switch: Left/Right")
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
		_objective_label.text = text

func set_selected_item_name(text: String) -> void:
	if _selected_item_label:
		_selected_item_label.text = "Selected: %s" % text

func set_interaction_hint(text: String) -> void:
	if _interaction_hint_label:
		_interaction_hint_label.text = text

func show_toast(text: String, duration: float = 2.0) -> void:
	if not _toast_label:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_timer = duration
