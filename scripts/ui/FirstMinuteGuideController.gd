extends Node

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

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

	if GameState.pending_main_well_report and not GameState.reported_main_well_outer_ring:
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
			return "按 E 打开箱子并取出工具" if _is_near(_chest, player_foot, 92.0) else "前往箱子"
		GuideStep.TALK_FATHER:
			return "按 E 与父亲交谈" if _is_near(_father_npc, player_foot, 92.0) else "前往父亲身边"
		GuideStep.TALK_SISTER:
			return "按 E 与姐姐交谈" if _is_near(_sister_npc, player_foot, 92.0) else "前往姐姐身边"
		GuideStep.INSPECT_SIGNBOARD:
			return "按 E 查看界碑" if _is_near(_signboard, player_foot, 96.0) else "前往异常区入口界碑"
		GuideStep.RETURN_FATHER:
			return "按 E 向父亲汇报" if _is_near(_father_npc, player_foot, 92.0) else "回去找父亲"
		GuideStep.ENTER_ANOMALY:
			return "按 E 进入异常区" if _is_near(_signboard, player_foot, 96.0) else "前往异常区入口"
		GuideStep.REPORT_NORTHBANK:
			return "按 E 向父亲汇报北岸线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
		GuideStep.REPORT_MAIN_WELL:
			return "按 E 向父亲汇报主井外环线索" if _is_near(_father_npc, player_foot, 92.0) else "返回父亲身边汇报"
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
					"继续和姐姐聊聊，她会告诉你农场最近的异常。"
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
					"接下来你可以去异常区入口继续调查。"
				], func():
					GameState.anomaly_entry_unlocked = true
					_set_step(GuideStep.ENTER_ANOMALY)
				)
				return true
		GuideStep.REPORT_NORTHBANK:
			if _is_near(_father_npc, player_foot, 92.0):
				_start_dialogue("父亲", [
					"北岸导流槽的锚点果然留着人为拆卸的痕迹。",
					"下一步去主井外环，那里应该能接上更深的异常链路。"
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
					"主井外环的转运节点也被异常侵蚀了，说明问题已经不只是边缘扰动。",
					"这一章先收口到这里，后面我们再继续追查更深处的设施。"
				], func():
					GameState.pending_main_well_report = false
					GameState.reported_main_well_outer_ring = true
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
	_task_panel.offset_left = 18
	_task_panel.offset_top = 60
	_task_panel.offset_right = 388
	_task_panel.offset_bottom = 166
	ui.add_child(_task_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_task_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_task_title_label = Label.new()
	_task_title_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_task_title_label)

	_task_body_label = Label.new()
	_task_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_task_body_label)

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
	_marker_label.text = "目标"
	_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker_label.visible = false
	_marker_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(_marker_label)
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
	if _task_title_label:
		_task_title_label.text = text.title
	if _task_body_label:
		_task_body_label.text = text.body
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
		viewport_position = target.global_position - camera.get_screen_center_position() + get_viewport().get_visible_rect().size / 2.0 + Vector2(0, -54)
	_marker_label.position = viewport_position - Vector2(18, 34)
	_marker_label.visible = true

func _get_current_target():
	match _step:
		GuideStep.OPEN_CHEST, GuideStep.TAKE_ITEMS:
			return _chest
		GuideStep.FILL_WATER:
			return _well_interact_point if _well_interact_point else _well
		GuideStep.TALK_FATHER, GuideStep.RETURN_FATHER, GuideStep.REPORT_NORTHBANK, GuideStep.REPORT_MAIN_WELL:
			return _father_npc
		GuideStep.TALK_SISTER:
			return _sister_npc
		GuideStep.INSPECT_SIGNBOARD, GuideStep.ENTER_ANOMALY:
			return _signboard
	return null

func _get_step_text(step: int) -> Dictionary:
	match step:
		GuideStep.MOVE:
			return {"title": "第一步", "body": "先移动角色，熟悉操作。", "objective": "当前目标：先移动一圈"}
		GuideStep.OPEN_CHEST:
			return {"title": "第二步", "body": "走到箱子旁边，按 E 打开。", "objective": "当前目标：前往箱子"}
		GuideStep.TAKE_ITEMS:
			return {"title": "第三步", "body": "从箱子里取出种子、空水壶、剪刀和火把。", "objective": "当前目标：从箱子取出工具"}
		GuideStep.ENTER_FIELD:
			return {"title": "第四步", "body": "站到农田格子里。", "objective": "当前目标：前往农田"}
		GuideStep.SELECT_SEED:
			return {"title": "第五步", "body": "切换到种子。", "objective": "当前目标：选择种子"}
		GuideStep.PLANT_CROP:
			return {"title": "第六步", "body": "站在农田里按 E 播种。", "objective": "当前目标：播种"}
		GuideStep.FILL_WATER:
			return {"title": "第七步", "body": "切换空水壶，去井边装水。", "objective": "当前目标：去井边装水"}
		GuideStep.WATER_CROP:
			return {"title": "第八步", "body": "回到作物旁边按 E 浇水。", "objective": "当前目标：回到作物旁浇水"}
		GuideStep.WAIT_MATURE:
			return {"title": "第九步", "body": "等待作物成熟。", "objective": "当前目标：等待作物成熟"}
		GuideStep.SELECT_SCISSORS:
			return {"title": "第十步", "body": "切换到剪刀。", "objective": "当前目标：选择剪刀"}
		GuideStep.HARVEST_CROP:
			return {"title": "第十一步", "body": "对成熟作物按 E 收获。", "objective": "当前目标：收获作物"}
		GuideStep.TALK_FATHER:
			return {"title": "第十二步", "body": "收获后去找父亲。", "objective": "当前目标：与父亲交谈"}
		GuideStep.TALK_SISTER:
			return {"title": "第十三步", "body": "再去和姐姐聊聊异常情况。", "objective": "当前目标：与姐姐交谈"}
		GuideStep.INSPECT_SIGNBOARD:
			return {"title": "第十四步", "body": "去异常区入口界碑查看调查路线。", "objective": "当前目标：查看异常区入口"}
		GuideStep.RETURN_FATHER:
			return {"title": "第十五步", "body": "把界碑上的信息告诉父亲。", "objective": "当前目标：返回父亲身边汇报"}
		GuideStep.ENTER_ANOMALY:
			if GameState.second_subarea_unlocked and not GameState.reported_main_well_outer_ring:
				return {"title": "第二章推进", "body": "北岸线索已经汇报完成，重新进入异常区，前往主井外环。", "objective": "当前目标：进入异常区调查主井外环"}
			return {"title": "异常调查", "body": "农场准备完成，可以前往异常区继续推进主线。", "objective": "当前目标：进入异常区"}
		GuideStep.REPORT_NORTHBANK:
			return {"title": "阶段汇报", "body": "你已带回北岸导流槽的调查结果，先去向父亲汇报。", "objective": "当前目标：向父亲汇报北岸线索"}
		GuideStep.REPORT_MAIN_WELL:
			return {"title": "阶段汇报", "body": "你已带回主井外环的调查结果，返回农场向父亲汇报。", "objective": "当前目标：向父亲汇报主井外环线索"}
		GuideStep.FREE_ROAM:
			return {"title": "第二章完成", "body": "主井外环章节已经收口，可以自由活动或继续准备下一段主线。", "objective": "当前目标：自由探索"}
	return {"title": "", "body": "", "objective": ""}

func _set_step(step: int) -> void:
	if _step == step:
		return
	_step = step
	refresh_guide_text()
	var text := _get_step_text(step)
	if _hud and step != GuideStep.FREE_ROAM:
		_hud.show_toast("下一目标：%s" % text.objective.replace("当前目标：", ""), 0, 2.1)
	elif _hud:
		_hud.show_toast("第二章完成：主井外环已汇报。", 1, 2.2)

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
