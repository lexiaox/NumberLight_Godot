class_name GameState
extends Node

static var is_modal_ui_open: bool = false

static var anomaly_entry_unlocked: bool = false
static var investigated_anomaly_core: bool = false
static var viewed_maintenance_clue: bool = false
static var first_subarea_unlocked: bool = false
static var investigated_northbank_sluice: bool = false
static var pending_anomaly_report: bool = false
static var reported_northbank_sluice: bool = false

static var pending_farm_spawn: String = ""
static var pending_notice: String = ""

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

static func queue_farm_return(spawn_key: String, notice: String = "") -> void:
	pending_farm_spawn = spawn_key
	pending_notice = notice

static func take_pending_notice() -> String:
	var text := pending_notice
	pending_notice = ""
	return text
