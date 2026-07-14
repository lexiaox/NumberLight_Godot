extends Node2D

const GameState = preload("res://scripts/gd/GameState.gd")

const FARM_SCENE_PATH := "res://scenes/farm/DayFarm.tscn"

var _player: CharacterBody2D
var _seal_node: Node2D
var _exit_marker: Sprite2D
var _objective_label: Label
var _hint_label: Label
var _toast_label: Label
var _dialogue_panel: PanelContainer
var _dialogue_speaker: Label
var _dialogue_body: Label
var _dialogue_lines: Array[String] = []
var _dialogue_on_complete: Callable = Callable()

func _ready() -> void:
	_player = get_node_or_null("Player")
	_seal_node = get_node_or_null("Decorations/SealNode")
	_exit_marker = get_node_or_null("Decorations/ExitMarker")
	_objective_label = get_node_or_null("UI/TopBar/ObjectiveLabel")
	_hint_label = get_node_or_null("UI/BottomBar/HintLabel")
	_toast_label = get_node_or_null("UI/ToastLabel")
	_dialogue_panel = get_node_or_null("UI/DialoguePanel")
	_dialogue_speaker = get_node_or_null("UI/DialoguePanel/Margin/VBox/SpeakerLabel")
	_dialogue_body = get_node_or_null("UI/DialoguePanel/Margin/VBox/BodyLabel")
	GameState.is_modal_ui_open = false
	if _dialogue_panel:
		_dialogue_panel.visible = false
	if _toast_label:
		_toast_label.visible = false
	update_labels()

func _process(_delta: float) -> void:
	if _player == null:
		return
	update_hint()
	if not Input.is_action_just_pressed("interact"):
		return
	if is_dialogue_open():
		advance_dialogue()
		return
	var foot: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if is_near(_seal_node, foot, 132.0):
		inspect_seal_node()
		return
	if is_near(_exit_marker, foot, 108.0):
		return_to_farm()

func is_dialogue_open() -> bool:
	return _dialogue_panel != null and _dialogue_panel.visible

func inspect_seal_node() -> void:
	if GameState.investigated_sealed_conduit:
		show_toast("封闭线路节点已经记录完成。", false)
		return
	start_dialogue("封闭线路", [
		"这段封闭线路的隔离节点已经被异常能量从缝隙中渗透进去了。",
		"原本用于阻断回流的封锁结构没有完全失效，但已经开始出现明显漏口。",
		"先把这条线索带回农场，和父亲汇报当前进展。"
	], func():
		GameState.investigated_sealed_conduit = true
		GameState.pending_sealed_conduit_report = true
		update_labels()
		show_toast("已记录封闭线路线索。", true)
	)

func return_to_farm() -> void:
	if not GameState.investigated_sealed_conduit:
		show_toast("先调查封闭线路节点，再返回农场。", false)
		return
	GameState.queue_farm_return("anomaly_return", "你已从封闭线路带回新的异常线索。")
	get_tree().change_scene_to_file(FARM_SCENE_PATH)

func update_labels() -> void:
	if GameState.investigated_sealed_conduit:
		set_objective("当前目标：返回农场汇报")
	else:
		set_objective("当前目标：调查封闭线路节点")

func update_hint() -> void:
	if is_dialogue_open():
		set_hint("对话中：按 E 继续")
		return
	var foot: Vector2 = _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position
	if is_near(_seal_node, foot, 132.0):
		set_hint("按 E 调查封闭线路节点")
		return
	if is_near(_exit_marker, foot, 108.0):
		set_hint("按 E 返回农场")
		return
	if GameState.investigated_sealed_conduit:
		set_hint("沿原路返回农场，把线索带给父亲")
	else:
		set_hint("继续向前，调查封闭线路的隔离节点")

func start_dialogue(speaker: String, lines: Array[String], on_complete: Callable) -> void:
	if _dialogue_panel == null or _dialogue_speaker == null or _dialogue_body == null:
		return
	_dialogue_lines = lines.duplicate()
	_dialogue_on_complete = on_complete
	_dialogue_speaker.text = speaker
	_dialogue_panel.visible = true
	GameState.is_modal_ui_open = true
	show_dialogue_line()

func advance_dialogue() -> void:
	if _dialogue_lines.is_empty():
		return
	_dialogue_lines.remove_at(0)
	if not _dialogue_lines.is_empty():
		show_dialogue_line()
		return
	_dialogue_panel.visible = false
	GameState.is_modal_ui_open = false
	if _dialogue_on_complete.is_valid():
		_dialogue_on_complete.call()
	_dialogue_on_complete = Callable()

func show_dialogue_line() -> void:
	if not _dialogue_lines.is_empty():
		_dialogue_body.text = _dialogue_lines[0]

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
