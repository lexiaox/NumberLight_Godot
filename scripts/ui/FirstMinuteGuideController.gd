extends Node

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")
const UIFont = preload("res://scripts/ui/UIFont.gd")

enum GuideStep {
	MOVE,
	OPEN_CHEST,
	TAKE_ITEMS,
	ENTER_FIELD,
	SELECT_SEED,
	PLANT_CROP,
	FILL_WATER,
	WATER_CROP,
	WAIT_MATURE,
	SELECT_SCISSORS,
	HARVEST_CROP,
	TALK_FATHER,
	TALK_SISTER,
	INSPECT_SIGNBOARD,
	RETURN_FATHER,
	ENTER_ANOMALY,
	REPORT_NORTHBANK,
	REPORT_MAIN_WELL,
	REPORT_SEALED_CONDUIT,
	REPORT_PROTOCOL_JUNCTION,
	FREE_ROAM
}

var _step: int = GuideStep.MOVE
var _player
var _chest
var _inventory
var _zone_manager
var _crop_system
var _hud
var _well
var _well_interact_point
var _signboard
var _father_npc
var _sister_npc
var _task_panel: PanelContainer
var _task_title_label: Label
var _task_body_label: Label
var _marker_label: Label
var _dialog_panel: PanelContainer
var _dialog_speaker_label: Label
var _dialog_body_label: Label
var _dialog_lines: Array[String] = []
var _dialog_on_complete: Callable = Callable()
var _last_player_position := Vector2.ZERO
var _moved_distance: float = 0.0

func _ready() -> void:
	var scene = get_tree().current_scene
	_player = scene.get_node_or_null("Player")
	_chest = scene.get_node_or_null("Chest")
	_inventory = scene.get_node_or_null("UI/BottomBar/Toolbar")
	_zone_manager = scene.get_node_or_null("FarmZoneManager")
	_crop_system = scene.get_node_or_null("CropSystem")
	_hud = scene.get_node_or_null("UI/HUD")
	_well = scene.get_node_or_null("Decorations/Well")
	_well_interact_point = scene.get_node_or_null("Decorations/Well/InteractPoint")
	_signboard = scene.get_node_or_null("Decorations/Signboard")
	_father_npc = _find_sprite_by_texture_path("character/father")
	_sister_npc = _find_sprite_by_texture_path("character/sister")
	_last_player_position = _player.global_position if _player else Vector2.ZERO

	if GameState.pending_protocol_junction_report and not GameState.reported_protocol_junction:
		_step = GuideStep.REPORT_PROTOCOL_JUNCTION
	elif GameState.pending_sealed_conduit_report and not GameState.reported_sealed_conduit:
		_step = GuideStep.REPORT_SEALED_CONDUIT
	elif GameState.pending_main_well_report and not GameState.reported_main_well_outer_ring:
		_step = GuideStep.REPORT_MAIN_WELL
	elif GameState.pending_anomaly_report and not GameState.reported_northbank_sluice:
		_step = GuideStep.REPORT_NORTHBANK
	elif GameState.anomaly_entry_unlocked:
		_step = GuideStep.ENTER_ANOMALY

	call_deferred("_initialize_ui")
	call_deferred("_ensure_camera")

func _process(_delta: float) -> void:
	if _player == null or _inventory == null or _hud == null:
		return
	if is_dialogue_open():
		update_world_marker()
		return
	_update_movement_progress()
	advance_passive_steps()
	refresh_guide_text()
	update_world_marker()

func is_dialogue_open() -> bool:
	return _dialog_panel != null and _dialog_panel.visible

func is_anomaly_entry_ready() -> bool:
	return _step == GuideStep.ENTER_ANOMALY and GameState.anomaly_entry_unlocked

func get_story_interaction_hint(player_foot: Vector2, selected_item: int) -> String:
	match _step:
		GuideStep.OPEN_CHEST, GuideStep.TAKE_ITEMS:
			return "按 E 打开箱子并取出物品" if _is_near(_chest, player_foot, 92.0) else "前往箱子"
		GuideStep.TALK_FATHER:
			return "按 E 与父亲交谈" if _is_near(_father_npc, player_foot, 92.0) else "前往父亲身边"
		GuideStep.TALK_SISTER:
			return "按 E 与姐姐交谈" if _is_near(_sister_npc, player_foot, 92.0) else "前往姐姐身边"
		GuideStep.INSPECT_SIGNBOARD:
			return "按 E 查看界碑" if _is_near(_signboard, player_foot, 96.0) else "前往异常区入口"
		GuideStep.RETURN_FATHER:
			return "按 E 向父亲汇报" if _is_near(_father_npc, player_foot, 92.0) else "回去找父亲"
		GuideStep.ENTER_ANOMALY:
			return "按 E 进入异常区" if _is_near(_signboard, player_foot, 96.0) else "前往异常区入口"
		GuideStep.REPORT_NORTHBANK:
			return "按 E 向父亲汇报北岸线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
		GuideStep.REPORT_MAIN_WELL:
			return "按 E 向父亲汇报主井外环线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
		GuideStep.REPORT_SEALED_CONDUIT:
			return "按 E 向父亲汇报封闭线路线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
		GuideStep.REPORT_PROTOCOL_JUNCTION:
			return "按 E 向父亲汇报协议汇流节点线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
		GuideStep.FILL_WATER:
			if _is_near(_well_interact_point if _well_interact_point else _well, player_foot, 90.0):
				return "切换空水壶后按 E 装水" if selected_item != ItemDatabase.WATERING_CAN_EMPTY else "按 E 装水"
		GuideStep.SELECT_SEED, GuideStep.PLANT_CROP, GuideStep.WATER_CROP, GuideStep.SELECT_SCISSORS, GuideStep.HARVEST_CROP:
			if not _zone_manager.get_current_zone().is_empty():
				return "站到农田里按 E 互动"
	return ""

func try_handle_story_interaction(player_foot: Vector2, _selected_item: int) -> bool:
	if is_dialogue_open():
		advance_dialogue()
		return true

	match _step:
		GuideStep.TALK_FATHER:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"你已经把第一株作物照料好了。",
					"继续去和姐姐聊聊，她会告诉你农场最近的异常。"
				], func(): _set_step(GuideStep.TALK_SISTER))
				return true
		GuideStep.TALK_SISTER:
			if _is_near(_sister_npc, player_foot, 92.0):
				_start_dialogue("姐姐", [
					"池塘那边最近总有奇怪的蓝光。",
					"你先去看看入口界碑，再回来告诉父亲。"
				], func(): _set_step(GuideStep.INSPECT_SIGNBOARD))
				return true
		GuideStep.INSPECT_SIGNBOARD:
			if _is_near(_signboard, player_foot, 96.0):
				GameState.show_notice("你记下了界碑上的异常调查路线。")
				_set_step(GuideStep.RETURN_FATHER)
				return true
		GuideStep.RETURN_FATHER:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"很好，农场这边的准备已经完成。",
					"接下来你可以去异常区入口，继续推进调查。"
				], func():
					GameState.anomaly_entry_unlocked = true
					_set_step(GuideStep.ENTER_ANOMALY)
				)
				return true
		GuideStep.REPORT_NORTHBANK:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"北岸导流槽的锚点果然留着人为拆卸的痕迹。",
					"下一步去主井外环，那里应该还能接上更深的异常链路。"
				], func():
					GameState.pending_anomaly_report = false
					GameState.reported_northbank_sluice = true
					GameState.second_subarea_unlocked = true
					_set_step(GuideStep.ENTER_ANOMALY)
				)
				return true
		GuideStep.REPORT_MAIN_WELL:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"主井外环的转运节点也被异常侵蚀了，说明问题已经不只是在边缘扰动。",
					"下一步去封闭线路，确认异常是不是已经开始绕开主井外环向侧向链路蔓延。"
				], func():
					GameState.pending_main_well_report = false
					GameState.reported_main_well_outer_ring = true
					GameState.third_subarea_unlocked = true
					_set_step(GuideStep.ENTER_ANOMALY)
				)
				return true
		GuideStep.REPORT_SEALED_CONDUIT:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"封闭线路也出现了异常渗透，说明这套旧设施的外围封锁已经开始失效。",
					"继续深入吧，去协议汇流节点确认异常是不是已经接管了更核心的协议通道。"
				], func():
					GameState.pending_sealed_conduit_report = false
					GameState.reported_sealed_conduit = true
					GameState.fourth_subarea_unlocked = true
					_set_step(GuideStep.ENTER_ANOMALY)
				)
				return true
		GuideStep.REPORT_PROTOCOL_JUNCTION:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"协议汇流节点也被异常接触到了，这说明它已经摸到了深层设施的主交换位。",
					"这一章先收到这里。接下来我们要围绕更深层的控制设施做准备。"
				], func():
					GameState.pending_protocol_junction_report = false
					GameState.reported_protocol_junction = true
					_set_step(GuideStep.FREE_ROAM)
				)
				return true
	return false

func _initialize_ui() -> void:
	var ui = get_tree().current_scene.get_node_or_null("UI")
	if ui == null:
		return

	_task_panel = PanelContainer.new()
	_task_panel.name = "GuideTaskPanel"
	_task_panel.visible = false
	ui.add_child(_task_panel)

	_task_title_label = Label.new()
	_task_body_label = Label.new()

	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "GuideDialoguePanel"
	_dialog_panel.visible = false
	_dialog_panel.offset_left = 150
	_dialog_panel.offset_top = 472
	_dialog_panel.offset_right = 1130
	_dialog_panel.offset_bottom = 682
	ui.add_child(_dialog_panel)

	var dialog_margin := MarginContainer.new()
	dialog_margin.add_theme_constant_override("margin_left", 20)
	dialog_margin.add_theme_constant_override("margin_right", 20)
	dialog_margin.add_theme_constant_override("margin_top", 20)
	dialog_margin.add_theme_constant_override("margin_bottom", 20)
	_dialog_panel.add_child(dialog_margin)

	var dialog_box := VBoxContainer.new()
	dialog_box.add_theme_constant_override("separation", 10)
	dialog_margin.add_child(dialog_box)

	_dialog_speaker_label = Label.new()
	_dialog_speaker_label.add_theme_font_size_override("font_size", 20)
	dialog_box.add_child(_dialog_speaker_label)

	_dialog_body_label = Label.new()
	_dialog_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body_label.custom_minimum_size = Vector2(0, 108)
	dialog_box.add_child(_dialog_body_label)

	var continue_label := Label.new()
	continue_label.text = "按 E 继续"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialog_box.add_child(continue_label)

	_marker_label = Label.new()
	_marker_label.name = "GuideMarker"
	_marker_label.text = "▼"
	_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker_label.visible = false
	_marker_label.add_theme_font_size_override("font_size", 28)
	_marker_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_marker_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_marker_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_marker_label)

	UIFont.apply_to_subtree(_dialog_panel)
	UIFont.apply_to_subtree(_marker_label)
	refresh_guide_text()

func _ensure_camera() -> void:
	if _player and _player.has_method("ensure_camera"):
		_player.ensure_camera()

func _update_movement_progress() -> void:
	if _player == null or _step != GuideStep.MOVE:
		return
	_moved_distance += _player.global_position.distance_to(_last_player_position)
	_last_player_position = _player.global_position
	if _moved_distance >= 56.0:
		_set_step(GuideStep.OPEN_CHEST)

func advance_passive_steps() -> void:
	var zone: Dictionary = _zone_manager.get_current_zone() if _zone_manager else {}
	var selected_item: int = _inventory.get_selected_item()
	match _step:
		GuideStep.OPEN_CHEST:
			if _chest and _chest.is_ui_open():
				_set_step(GuideStep.TAKE_ITEMS)
		GuideStep.TAKE_ITEMS:
			if _inventory.contains_item(ItemDatabase.SEED_GEM) and _inventory.contains_item(ItemDatabase.WATERING_CAN_EMPTY) and _inventory.contains_item(ItemDatabase.SCISSORS):
				_set_step(GuideStep.ENTER_FIELD)
		GuideStep.ENTER_FIELD:
			if not zone.is_empty():
				_set_step(GuideStep.SELECT_SEED)
		GuideStep.SELECT_SEED:
			if selected_item == ItemDatabase.SEED_GEM or selected_item == ItemDatabase.SEED_VINE:
				_set_step(GuideStep.PLANT_CROP)
		GuideStep.PLANT_CROP:
			if not zone.is_empty() and _crop_system.find_crop_at_zone(str(zone.name)) != null:
				_set_step(GuideStep.FILL_WATER)
		GuideStep.FILL_WATER:
			if selected_item == ItemDatabase.WATERING_CAN_FULL:
				_set_step(GuideStep.WATER_CROP)
		GuideStep.WATER_CROP:
			var crop = _crop_system.find_crop_at_zone(str(zone.name)) if not zone.is_empty() else null
			if crop != null and crop.was_watered:
				_set_step(GuideStep.WAIT_MATURE)
		GuideStep.WAIT_MATURE:
			var mature_crop = _find_any_mature_crop()
			if mature_crop != null:
				_set_step(GuideStep.SELECT_SCISSORS)
		GuideStep.SELECT_SCISSORS:
			if selected_item == ItemDatabase.SCISSORS:
				_set_step(GuideStep.HARVEST_CROP)
		GuideStep.HARVEST_CROP:
			if _inventory.contains_item(ItemDatabase.GEM) or _inventory.get_item_count(ItemDatabase.SEED_VINE) >= 2:
				_set_step(GuideStep.TALK_FATHER)

func refresh_guide_text() -> void:
	if _hud == null:
		return
	var text := _get_step_text(_step)
	_hud.set_objective(text.objective)
	var selected_item: int = _inventory.get_selected_item() if _inventory else ItemDatabase.NONE
	_hud.set_selected_item_name(ItemDatabase.get_item_name(selected_item) if selected_item != ItemDatabase.NONE else "未选择")

func update_world_marker() -> void:
	if _marker_label == null:
		return
	var target = _get_current_target()
	if target == null or _step == GuideStep.FREE_ROAM:
		_marker_label.visible = false
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	var viewport_position: Vector2 = target.global_position
	if camera != null:
		viewport_position = target.global_position - camera.get_screen_center_position() + get_viewport().get_visible_rect().size / 2.0
	var bob_offset := sin(Time.get_ticks_msec() / 180.0) * 4.0
	_marker_label.position = viewport_position + Vector2(-14, -72 + bob_offset)
	_marker_label.visible = true

func _get_current_target():
	match _step:
		GuideStep.OPEN_CHEST, GuideStep.TAKE_ITEMS:
			return _chest
		GuideStep.FILL_WATER:
			return _well_interact_point if _well_interact_point else _well
		GuideStep.TALK_FATHER, GuideStep.RETURN_FATHER, GuideStep.REPORT_NORTHBANK, GuideStep.REPORT_MAIN_WELL, GuideStep.REPORT_SEALED_CONDUIT, GuideStep.REPORT_PROTOCOL_JUNCTION:
			return _father_npc
		GuideStep.TALK_SISTER:
			return _sister_npc
		GuideStep.INSPECT_SIGNBOARD, GuideStep.ENTER_ANOMALY:
			return _signboard
	return null

func _get_step_text(step: int) -> Dictionary:
	match step:
		GuideStep.MOVE:
			return {"title": "第一步", "body": "先移动角色，熟悉操作。", "objective": "先移动一圈"}
		GuideStep.OPEN_CHEST:
			return {"title": "第二步", "body": "走到箱子旁边，按 E 打开。", "objective": "前往箱子"}
		GuideStep.TAKE_ITEMS:
			return {"title": "第三步", "body": "从箱子里取出种子、空水壶、剪刀和火把。", "objective": "从箱子取出工具"}
		GuideStep.ENTER_FIELD:
			return {"title": "第四步", "body": "站到农田格子里。", "objective": "前往农田"}
		GuideStep.SELECT_SEED:
			return {"title": "第五步", "body": "切换到种子。", "objective": "选择种子"}
		GuideStep.PLANT_CROP:
			return {"title": "第六步", "body": "站在农田里按 E 播种。", "objective": "播种"}
		GuideStep.FILL_WATER:
			return {"title": "第七步", "body": "切换空水壶，去井边装水。", "objective": "去井边装水"}
		GuideStep.WATER_CROP:
			return {"title": "第八步", "body": "回到作物旁边按 E 浇水。", "objective": "回到作物旁浇水"}
		GuideStep.WAIT_MATURE:
			return {"title": "第九步", "body": "等待作物成熟。", "objective": "等待作物成熟"}
		GuideStep.SELECT_SCISSORS:
			return {"title": "第十步", "body": "切换到剪刀。", "objective": "选择剪刀"}
		GuideStep.HARVEST_CROP:
			return {"title": "第十一步", "body": "对成熟作物按 E 收获。", "objective": "收获作物"}
		GuideStep.TALK_FATHER:
			return {"title": "第十二步", "body": "收获后去找父亲。", "objective": "与父亲交谈"}
		GuideStep.TALK_SISTER:
			return {"title": "第十三步", "body": "再去和姐姐聊聊异常情况。", "objective": "与姐姐交谈"}
		GuideStep.INSPECT_SIGNBOARD:
			return {"title": "第十四步", "body": "去异常区入口界碑查看调查路线。", "objective": "查看异常区入口"}
		GuideStep.RETURN_FATHER:
			return {"title": "第十五步", "body": "把界碑上的信息告诉父亲。", "objective": "返回父亲身边汇报"}
		GuideStep.ENTER_ANOMALY:
			if GameState.fourth_subarea_unlocked and not GameState.reported_protocol_junction:
				return {"title": "第四章推进", "body": "封闭线路线索已经汇报完成，重新进入异常区，前往协议汇流节点。", "objective": "进入异常区调查协议汇流节点"}
			if GameState.third_subarea_unlocked and not GameState.reported_sealed_conduit:
				return {"title": "第三章推进", "body": "主井外环线索已经汇报完成，重新进入异常区，前往封闭线路。", "objective": "进入异常区调查封闭线路"}
			if GameState.second_subarea_unlocked and not GameState.reported_main_well_outer_ring:
				return {"title": "第二章推进", "body": "北岸线索已经汇报完成，重新进入异常区，前往主井外环。", "objective": "进入异常区调查主井外环"}
			return {"title": "异常调查", "body": "农场准备完成，可以前往异常区继续推进主线。", "objective": "进入异常区"}
		GuideStep.REPORT_NORTHBANK:
			return {"title": "阶段汇报", "body": "你已带回北岸导流槽的调查结果，先去向父亲汇报。", "objective": "向父亲汇报北岸线索"}
		GuideStep.REPORT_MAIN_WELL:
			return {"title": "第二章汇报", "body": "你已带回主井外环的调查结果，返回农场向父亲汇报。", "objective": "向父亲汇报主井外环线索"}
		GuideStep.REPORT_SEALED_CONDUIT:
			return {"title": "第三章汇报", "body": "你已带回封闭线路的调查结果，返回农场向父亲汇报。", "objective": "向父亲汇报封闭线路线索"}
		GuideStep.REPORT_PROTOCOL_JUNCTION:
			return {"title": "第四章汇报", "body": "你已带回协议汇流节点的调查结果，返回农场向父亲汇报。", "objective": "向父亲汇报协议汇流节点线索"}
		GuideStep.FREE_ROAM:
			return {"title": "第四章完成", "body": "协议汇流节点章节已经收口，可以自由活动或继续准备下一段主线。", "objective": "自由探索"}
	return {"title": "", "body": "", "objective": ""}

func _set_step(step: int) -> void:
	if _step == step:
		return
	_step = step
	refresh_guide_text()
	var text := _get_step_text(step)
	if _hud and step != GuideStep.FREE_ROAM:
		_hud.show_toast("下一目标：%s" % text.objective, 0, 2.1)
	elif _hud:
		_hud.show_toast("第四章完成：协议汇流节点已汇报。", 1, 2.2)

func _find_any_mature_crop():
	for crop in _crop_system._crops:
		if crop.state == _crop_system.CropState.MATURE:
			return crop
	return null

func _start_dialogue(speaker: String, lines: Array[String], on_complete: Callable) -> void:
	_dialog_lines = lines.duplicate()
	_dialog_on_complete = on_complete
	_dialog_speaker_label.text = speaker
	_dialog_panel.visible = true
	GameState.is_modal_ui_open = true
	_show_dialogue_line()

func advance_dialogue() -> void:
	if _dialog_lines.is_empty():
		return
	_dialog_lines.remove_at(0)
	if not _dialog_lines.is_empty():
		_show_dialogue_line()
		return
	_dialog_panel.visible = false
	GameState.is_modal_ui_open = false
	if _dialog_on_complete.is_valid():
		_dialog_on_complete.call()
	_dialog_on_complete = Callable()

func _show_dialogue_line() -> void:
	if _dialog_body_label and not _dialog_lines.is_empty():
		_dialog_body_label.text = _dialog_lines[0]

func _find_sprite_by_texture_path(path_part: String):
	for sprite in _get_all_sprites(get_tree().current_scene):
		var path: String = sprite.texture.resource_path if sprite.texture else ""
		if path_part in path:
			return sprite
	return null

func _get_all_sprites(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child is Sprite2D:
			result.append(child)
		result.append_array(_get_all_sprites(child))
	return result

func _is_near(node: Node2D, point: Vector2, distance: float) -> bool:
	return node != null and node.global_position.distance_to(point) <= distance
