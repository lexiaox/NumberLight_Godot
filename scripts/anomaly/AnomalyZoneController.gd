extends Node2D

const GameState = preload("res://scripts/gd/GameState.gd")

const FARM_SCENE_PATH := "res://scenes/farm/DayFarm.tscn"

enum Stage {
	INVESTIGATE_CORE,
	CHECK_CLUE,
	RETURN_FARM
}

var _stage: int = Stage.INVESTIGATE_CORE
var _player: CharacterBody2D
var _core: Node2D
var _clue: Node2D
var _sub_area_entrance: Node2D
var _exit_marker: Sprite2D
var _objective_label: Label
var _hint_label: Label
var _toast_label: Label
var _world_marker_label: Label
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _body_label: Label
var _dialog_lines: Array[String] = []
var _dialog_callback: Callable = Callable()

func _ready() -> void:
	_player = get_node_or_null("Player")
	_core = get_node_or_null("Decorations/AnomalyCore")
	_clue = get_node_or_null("Decorations/MaintenanceClue")
	_sub_area_entrance = get_node_or_null("Decorations/SubAreaEntrance")
	_exit_marker = get_node_or_null("Decorations/ExitMarker")
	_objective_label = get_node_or_null("UI/TopBar/ObjectiveLabel")
	_hint_label = get_node_or_null("UI/BottomBar/HintLabel")
	_toast_label = get_node_or_null("UI/ToastLabel")
	_world_marker_label = get_node_or_null("UI/WorldMarkerLabel")
	_dialogue_panel = get_node_or_null("UI/DialoguePanel")
	_speaker_label = get_node_or_null("UI/DialoguePanel/Margin/VBox/SpeakerLabel")
	_body_label = get_node_or_null("UI/DialoguePanel/Margin/VBox/BodyLabel")
	if _dialogue_panel:
		_dialogue_panel.visible = false
	if _toast_label:
		_toast_label.visible = false
	if GameState.viewed_maintenance_clue:
		_stage = Stage.RETURN_FARM
	elif GameState.investigated_anomaly_core:
		_stage = Stage.CHECK_CLUE
	update_labels()

func _process(_delta: float) -> void:
	if _player == null:
		return
	update_world_marker()
	update_hint()
	if not Input.is_action_just_pressed("interact"):
		return
	if is_dialogue_open():
		advance_dialogue()
		return
	handle_interaction()

func is_dialogue_open() -> bool:
	return _dialogue_panel != null and _dialogue_panel.visible

func handle_interaction() -> void:
	var player_point: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if is_near(_core, player_point, 110.0):
		inspect_core()
		return
	if is_near(_clue, player_point, 100.0):
		inspect_clue()
		return
	if is_near(_sub_area_entrance, player_point, 120.0):
		inspect_sub_area_entrance()
		return
	if is_near(_exit_marker, player_point, 96.0):
		return_to_farm()

func inspect_core() -> void:
	if GameState.investigated_anomaly_core:
		show_toast("光棱核心仍在不稳定地震动。", false)
		return
	GameState.investigated_anomaly_core = true
	_stage = Stage.CHECK_CLUE
	start_dialogue("异常核心", [
		"这枚光棱核心的能量流动异常，像是被强行改写过。",
		"附近应该还留有维护记录，先去查看旁边的线索。"
	], Callable())
	show_toast("已记录核心异常。", true)
	update_labels()

func inspect_clue() -> void:
	if not GameState.investigated_anomaly_core:
		show_toast("先调查中央的光棱核心。", false)
		return
	if GameState.viewed_maintenance_clue:
		show_toast("这份维护线索已经看过了。", false)
		return
	GameState.viewed_maintenance_clue = true
	GameState.anomaly_entry_unlocked = true
	_stage = Stage.RETURN_FARM
	start_dialogue("维护记录", [
		"记录板写着：北侧链路与深层设施之间出现了协议偏移。",
		"先把这条线索带回农场，和父亲、姐姐汇报情况。"
	], Callable())
	show_toast("获得新线索：返回农场汇报。", true)
	update_labels()

func inspect_sub_area_entrance() -> void:
	if not GameState.viewed_maintenance_clue:
		show_toast("深层入口尚未准备好，先完成当前调查。", false)
		return
	show_toast("网页版下一步会从这里继续进入深层副区。", false, 2.2)

func return_to_farm() -> void:
	GameState.queue_farm_return("anomaly_return", "你已带着异常区线索返回农场。")
	get_tree().change_scene_to_file(FARM_SCENE_PATH)

func update_labels() -> void:
	match _stage:
		Stage.INVESTIGATE_CORE:
			set_objective("当前目标：调查异常核心")
		Stage.CHECK_CLUE:
			set_objective("当前目标：查看维护线索")
		Stage.RETURN_FARM:
			set_objective("当前目标：返回农场汇报")

func update_hint() -> void:
	if is_dialogue_open():
		set_hint("对话中：按 E 继续")
		return
	var player_point: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if is_near(_core, player_point, 110.0):
		set_hint("按 E 调查光棱核心")
		return
	if is_near(_clue, player_point, 100.0):
		set_hint("按 E 查看维护线索")
		return
	if is_near(_sub_area_entrance, player_point, 120.0):
		set_hint("按 E 查看深层入口")
		return
	if is_near(_exit_marker, player_point, 96.0):
		set_hint("按 E 返回农场")
		return
	match _stage:
		Stage.INVESTIGATE_CORE:
			set_hint("前往中央平台调查光棱核心")
		Stage.CHECK_CLUE:
			set_hint("去左上侧查看维护记录和工具残片")
		Stage.RETURN_FARM:
			set_hint("沿原路返回农场汇报")

func update_world_marker() -> void:
	if _world_marker_label == null:
		return
	var target: Node2D = null
	match _stage:
		Stage.INVESTIGATE_CORE:
			target = _core
		Stage.CHECK_CLUE:
			target = _clue
		Stage.RETURN_FARM:
			target = _exit_marker
	if target == null:
		_world_marker_label.visible = false
		return
	var camera := get_viewport().get_camera_2d()
	var viewport_position := target.global_position
	if camera != null:
		viewport_position = target.global_position - camera.get_screen_center_position() + get_viewport().get_visible_rect().size / 2.0 + Vector2(0, -56)
	_world_marker_label.position = viewport_position - Vector2(90, 28)
	_world_marker_label.text = "目标"
	_world_marker_label.visible = true

func start_dialogue(speaker: String, lines: Array[String], on_complete: Callable) -> void:
	if _dialogue_panel == null or _speaker_label == null or _body_label == null:
		return
	_dialog_lines = lines.duplicate()
	_dialog_callback = on_complete
	_speaker_label.text = speaker
	_dialogue_panel.visible = true
	GameState.is_modal_ui_open = true
	show_dialogue_line()

func advance_dialogue() -> void:
	if _dialog_lines.is_empty():
		return
	_dialog_lines.remove_at(0)
	if not _dialog_lines.is_empty():
		show_dialogue_line()
		return
	_dialogue_panel.visible = false
	GameState.is_modal_ui_open = false
	if _dialog_callback.is_valid():
		_dialog_callback.call()
	_dialog_callback = Callable()

func show_dialogue_line() -> void:
	if not _dialog_lines.is_empty():
		_body_label.text = _dialog_lines[0]

func set_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = text

func set_hint(text: String) -> void:
	if _hint_label:
		_hint_label.text = text

func show_toast(text: String, success: bool, duration: float = 2.0) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate = Color(0.92, 1.0, 0.82) if success else Color(0.92, 0.97, 1.0)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if _toast_label:
			_toast_label.visible = false
	)

func is_near(node: Node2D, point: Vector2, distance: float) -> bool:
	return node != null and node.global_position.distance_to(point) <= distance
