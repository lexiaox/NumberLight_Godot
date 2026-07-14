extends Node2D

const GameState = preload("res://scripts/gd/GameState.gd")
const UIFont = preload("res://scripts/ui/UIFont.gd")

const FARM_SCENE_PATH := "res://scenes/farm/DayFarm.tscn"
const NORTH_BANK_SCENE_PATH := "res://scenes/anomaly/NorthBankTrail.tscn"
const MAIN_WELL_SCENE_PATH := "res://scenes/anomaly/MainWellOuterRing.tscn"
const SEALED_CONDUIT_SCENE_PATH := "res://scenes/anomaly/SealedConduit.tscn"
const PROTOCOL_JUNCTION_SCENE_PATH := "res://scenes/anomaly/ProtocolJunction.tscn"

enum Stage {
	INVESTIGATE_CORE,
	CHECK_CLUE,
	ENTER_NORTHBANK,
	ENTER_MAIN_WELL,
	ENTER_SEALED_CONDUIT,
	ENTER_PROTOCOL_JUNCTION,
	RETURN_FARM,
	COMPLETE
}

var _stage: int = Stage.INVESTIGATE_CORE
var _player: CharacterBody2D
var _core: Node2D
var _clue: Node2D
var _sub_area_entrance: Node2D
var _sub_area_interact_point: Node2D
var _exit_marker: Sprite2D
var _objective_label: Label
var _hint_label: Label
var _toast_label: Label
var _world_marker_label: Label
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _body_label: Label
var _entry_label: Label
var _dialog_lines: Array[String] = []
var _dialog_callback: Callable = Callable()

func _ready() -> void:
	_player = get_node_or_null("Player")
	_core = get_node_or_null("Decorations/AnomalyCore")
	_clue = get_node_or_null("Decorations/MaintenanceClue")
	_sub_area_entrance = get_node_or_null("Decorations/SubAreaEntrance")
	_sub_area_interact_point = get_node_or_null("Decorations/SubAreaEntrance/InteractPoint")
	_exit_marker = get_node_or_null("Decorations/ExitMarker")
	_objective_label = get_node_or_null("UI/TopBar/ObjectiveLabel")
	_hint_label = get_node_or_null("UI/BottomBar/HintLabel")
	_toast_label = get_node_or_null("UI/ToastLabel")
	_world_marker_label = get_node_or_null("UI/WorldMarkerLabel")
	_dialogue_panel = get_node_or_null("UI/DialoguePanel")
	_speaker_label = get_node_or_null("UI/DialoguePanel/Margin/VBox/SpeakerLabel")
	_body_label = get_node_or_null("UI/DialoguePanel/Margin/VBox/BodyLabel")
	_entry_label = get_node_or_null("Decorations/SubAreaEntrance/EntryLabel")
	UIFont.apply_to_subtree(get_node_or_null("UI"))
	UIFont.apply_to_subtree(_entry_label)
	if _dialogue_panel:
		_dialogue_panel.visible = false
	if _toast_label:
		_toast_label.visible = false
	refresh_stage()
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

func refresh_stage() -> void:
	if GameState.reported_protocol_junction:
		_stage = Stage.COMPLETE
	elif GameState.investigated_protocol_junction:
		_stage = Stage.RETURN_FARM
	elif GameState.fourth_subarea_unlocked:
		_stage = Stage.ENTER_PROTOCOL_JUNCTION
	elif GameState.investigated_sealed_conduit:
		_stage = Stage.RETURN_FARM
	elif GameState.third_subarea_unlocked:
		_stage = Stage.ENTER_SEALED_CONDUIT
	elif GameState.investigated_main_well_outer_ring:
		_stage = Stage.RETURN_FARM
	elif GameState.second_subarea_unlocked:
		_stage = Stage.ENTER_MAIN_WELL
	elif GameState.investigated_northbank_sluice:
		_stage = Stage.RETURN_FARM
	elif GameState.first_subarea_unlocked:
		_stage = Stage.ENTER_NORTHBANK
	elif GameState.viewed_maintenance_clue:
		_stage = Stage.ENTER_NORTHBANK
	elif GameState.investigated_anomaly_core:
		_stage = Stage.CHECK_CLUE
	else:
		_stage = Stage.INVESTIGATE_CORE

func is_dialogue_open() -> bool:
	return _dialogue_panel != null and _dialogue_panel.visible

func handle_interaction() -> void:
	var player_point: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if _stage == Stage.INVESTIGATE_CORE and is_near(_core, player_point, 110.0):
		inspect_core()
		return
	if (_stage == Stage.CHECK_CLUE or _is_any_entry_stage(_stage)) and is_near(_clue, player_point, 100.0):
		inspect_clue()
		return
	if _is_any_entry_stage(_stage) and is_near(get_subarea_target(), player_point, 120.0):
		inspect_sub_area_entrance()
		return
	if is_near(_exit_marker, player_point, 96.0):
		return_to_farm()

func inspect_core() -> void:
	if GameState.investigated_anomaly_core:
		show_toast("光棱核心仍在不稳定地震动。", false)
		return
	GameState.investigated_anomaly_core = true
	refresh_stage()
	start_dialogue("异常核心", [
		"这枚光棱核心的能量流动异常，像是被强行改写过。",
		"附近应该还留着维护记录，先去查看左上方的线索。"
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
	GameState.first_subarea_unlocked = true
	refresh_stage()
	start_dialogue("维护记录", [
		"记录板写着：北侧链路出现了明显的能量偏移，异常痕迹沿北岸导流槽继续向前延伸。",
		"先从右上方入口进入北岸副区，把那里的锚点线索查清楚。"
	], Callable())
	show_toast("新目标：进入北岸导流槽副区。", true)
	update_labels()

func inspect_sub_area_entrance() -> void:
	match _stage:
		Stage.ENTER_NORTHBANK:
			start_dialogue("北岸导流槽入口", [
				"这条入口通往北岸导流槽，维护记录提到的能量偏移就是从这里继续延伸的。",
				"进去调查锚点痕迹，确认光棱碎片的后续去向。"
			], func():
				get_tree().change_scene_to_file(NORTH_BANK_SCENE_PATH)
			)
		Stage.ENTER_MAIN_WELL:
			start_dialogue("主井外环入口", [
				"父亲提到的下一段线索就在主井外环。",
				"进去确认外环转运节点是否也被异常侵蚀。"
			], func():
				get_tree().change_scene_to_file(MAIN_WELL_SCENE_PATH)
			)
		Stage.ENTER_SEALED_CONDUIT:
			start_dialogue("封闭线路入口", [
				"这一段封闭线路原本负责阻断侧向能量回流。",
				"进去确认封锁结构是否已经被异常渗透。"
			], func():
				get_tree().change_scene_to_file(SEALED_CONDUIT_SCENE_PATH)
			)
		Stage.ENTER_PROTOCOL_JUNCTION:
			start_dialogue("协议汇流节点入口", [
				"更深处的协议汇流节点还在持续放大异常回响。",
				"进去确认异常是否已经接上深层设施的主交换位。"
			], func():
				get_tree().change_scene_to_file(PROTOCOL_JUNCTION_SCENE_PATH)
			)

func return_to_farm() -> void:
	match _stage:
		Stage.RETURN_FARM:
			GameState.queue_farm_return("anomaly_return", "你已完成当前副区调查，返回农场汇报。")
			get_tree().change_scene_to_file(FARM_SCENE_PATH)
		Stage.COMPLETE:
			GameState.queue_farm_return("anomaly_return", "当前异常章节已经完成，返回农场。")
			get_tree().change_scene_to_file(FARM_SCENE_PATH)
		_:
			show_toast("先完成当前调查，再返回农场。", false)

func update_labels() -> void:
	if _entry_label:
		_entry_label.text = _get_entry_name()
	match _stage:
		Stage.INVESTIGATE_CORE:
			set_objective("当前目标：调查异常核心")
		Stage.CHECK_CLUE:
			set_objective("当前目标：查看维护线索")
		Stage.ENTER_NORTHBANK:
			set_objective("当前目标：进入北岸导流槽")
		Stage.ENTER_MAIN_WELL:
			set_objective("当前目标：进入主井外环")
		Stage.ENTER_SEALED_CONDUIT:
			set_objective("当前目标：进入封闭线路")
		Stage.ENTER_PROTOCOL_JUNCTION:
			set_objective("当前目标：进入协议汇流节点")
		Stage.RETURN_FARM:
			set_objective("当前目标：返回农场汇报")
		Stage.COMPLETE:
			set_objective("当前目标：本章调查已完成")

func update_hint() -> void:
	if is_dialogue_open():
		set_hint("对话中：按 E 继续")
		return
	var player_point: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if _stage == Stage.INVESTIGATE_CORE and is_near(_core, player_point, 110.0):
		set_hint("按 E 调查光棱核心")
		return
	if (_stage == Stage.CHECK_CLUE or _is_any_entry_stage(_stage)) and is_near(_clue, player_point, 100.0):
		set_hint("按 E 查看维护线索")
		return
	if _is_any_entry_stage(_stage) and is_near(get_subarea_target(), player_point, 120.0):
		set_hint("按 E 进入%s" % _get_entry_name())
		return
	if (_stage == Stage.RETURN_FARM or _stage == Stage.COMPLETE) and is_near(_exit_marker, player_point, 96.0):
		set_hint("按 E 返回农场")
		return
	match _stage:
		Stage.INVESTIGATE_CORE:
			set_hint("前往中央平台调查光棱核心")
		Stage.CHECK_CLUE:
			set_hint("去左上侧查看维护记录")
		Stage.ENTER_NORTHBANK:
			set_hint("前往右上入口，进入北岸导流槽")
		Stage.ENTER_MAIN_WELL:
			set_hint("前往右上入口，进入主井外环")
		Stage.ENTER_SEALED_CONDUIT:
			set_hint("前往右上入口，进入封闭线路")
		Stage.ENTER_PROTOCOL_JUNCTION:
			set_hint("前往右上入口，进入协议汇流节点")
		Stage.RETURN_FARM:
			set_hint("调查完成，沿原路返回农场")
		Stage.COMPLETE:
			set_hint("本章已完成，可返回农场或继续观察异常区")

func update_world_marker() -> void:
	if _world_marker_label == null:
		return
	var target: Node2D = null
	match _stage:
		Stage.INVESTIGATE_CORE:
			target = _core
		Stage.CHECK_CLUE:
			target = _clue
		Stage.ENTER_NORTHBANK, Stage.ENTER_MAIN_WELL, Stage.ENTER_SEALED_CONDUIT, Stage.ENTER_PROTOCOL_JUNCTION:
			target = get_subarea_target()
		Stage.RETURN_FARM, Stage.COMPLETE:
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

func get_subarea_target() -> Node2D:
	return _sub_area_interact_point if _sub_area_interact_point != null else _sub_area_entrance

func _get_entry_name() -> String:
	match _stage:
		Stage.ENTER_MAIN_WELL:
			return "主井外环"
		Stage.ENTER_SEALED_CONDUIT:
			return "封闭线路"
		Stage.ENTER_PROTOCOL_JUNCTION:
			return "协议汇流节点"
		_:
			return "北岸导流槽"

func _is_any_entry_stage(stage: int) -> bool:
	return stage == Stage.ENTER_NORTHBANK or stage == Stage.ENTER_MAIN_WELL or stage == Stage.ENTER_SEALED_CONDUIT or stage == Stage.ENTER_PROTOCOL_JUNCTION

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
