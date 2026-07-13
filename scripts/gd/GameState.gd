class_name GameState
extends Node

static var is_modal_ui_open: bool = false

static func show_notice(text: String, duration: float = 1.8) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var hud = tree.current_scene.get_node_or_null("UI/HUD")
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, 0, duration)

static func warn(text: String) -> void:
	push_warning(text)

static func error(text: String) -> void:
	push_error(text)
