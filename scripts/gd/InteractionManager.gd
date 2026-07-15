extends Node

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

const ANOMALY_SCENE_PATH := "res://scenes/anomaly/AnomalyZone.tscn"

@export var well_interact_range: float = 84.0
@export var stele_interact_range: float = 92.0

var _crop_system
var _zone_manager
var _chest
var _inventory
var _player: CharacterBody2D
var _well_interact_point: Node2D
var _stele_interact_point: Node2D
var _hud
var _guide_controller

func _ready() -> void:
	_crop_system = get_tree().current_scene.get_node_or_null("CropSystem")
	_zone_manager = get_tree().current_scene.get_node_or_null("FarmZoneManager")
	_inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
	_chest = get_tree().current_scene.get_node_or_null("Chest")
	_player = get_tree().current_scene.get_node_or_null("Player")
	_well_interact_point = get_tree().current_scene.get_node_or_null("Decorations/Well/InteractPoint")
	_stele_interact_point = get_tree().current_scene.get_node_or_null("Decorations/Signboard/InteractPoint")
	_hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	_guide_controller = get_tree().current_scene.get_node_or_null("UI/GuideController")

func _process(_delta: float) -> void:
	if _player != null and _inventory != null:
		update_interaction_hint(get_player_foot_position())

	if not Input.is_action_just_pressed("interact") or _player == null or _inventory == null:
		return

	var player_foot := get_player_foot_position()
	var selected_item: int = _inventory.get_selected_item()

	if _guide_controller and _guide_controller.has_method("try_handle_story_interaction"):
		if _guide_controller.try_handle_story_interaction(player_foot, selected_item):
			return

	if _chest != null and _chest.is_ui_open():
		_chest.try_take_selected_item()
		return

	var chest_available: bool = _chest != null and _chest.can_interact_from(player_foot)
	var well_available := can_interact_with_well(player_foot)

	if chest_available and should_focus_chest(player_foot, well_available):
		_chest.open_chest()
		return

	if selected_item == ItemDatabase.WATERING_CAN_EMPTY and well_available:
		_inventory.replace_selected_item(ItemDatabase.WATERING_CAN_FULL)
		GameState.show_notice("已经从水井装满水")
		return

	if can_inspect_stele(player_foot):
		if _guide_controller and _guide_controller.has_method("is_anomaly_entry_ready") and _guide_controller.is_anomaly_entry_ready():
			get_tree().change_scene_to_file(ANOMALY_SCENE_PATH)
		else:
			GameState.show_notice("这里是异常区入口界碑，完成农场引导后即可进入异常调查区域。")
		return

	if _zone_manager == null or _crop_system == null:
		return

	if _zone_manager.get_current_zone().is_empty():
		if selected_item == ItemDatabase.WATERING_CAN_EMPTY:
			GameState.show_notice("靠近水井后才能装水")
		elif selected_item != ItemDatabase.NONE:
			GameState.show_notice("请先站到农田格子里")
		return

	if selected_item == ItemDatabase.SEED_GEM or selected_item == ItemDatabase.SEED_VINE:
		_crop_system.try_plant()
		return
	if selected_item == ItemDatabase.WATERING_CAN_FULL:
		_crop_system.try_water()
		return
	if selected_item == ItemDatabase.SCISSORS:
		_crop_system.try_harvest()
		return
	if selected_item == ItemDatabase.NONE:
		GameState.show_notice("请先选择一个道具")
		return

	GameState.show_notice("这里不能使用 %s" % ItemDatabase.get_item_name(selected_item))

func get_player_foot_position() -> Vector2:
	return _player.get_foot_world_position() if _player.has_method("get_foot_world_position") else _player.global_position

func can_interact_with_well(player_position: Vector2) -> bool:
	return _well_interact_point != null and player_position.distance_to(_well_interact_point.global_position) <= well_interact_range

func can_inspect_stele(player_position: Vector2) -> bool:
	return _stele_interact_point != null and player_position.distance_to(_stele_interact_point.global_position) <= stele_interact_range

func should_focus_chest(player_position: Vector2, well_available: bool) -> bool:
	if not well_available or _chest == null or _well_interact_point == null:
		return true
	var chest_distance: float = _chest.get_interact_distance(player_position)
	var well_distance := player_position.distance_to(_well_interact_point.global_position)
	return chest_distance <= well_distance

func update_interaction_hint(player_position: Vector2) -> void:
	if _hud == null:
		return

	if _guide_controller and _guide_controller.has_method("is_dialogue_open") and _guide_controller.is_dialogue_open():
		_hud.set_interaction_hint("对话中：按 E 继续")
		return

	if _chest != null and _chest.is_ui_open():
		_hud.set_interaction_hint("箱子已打开：按 E 取出，按 Esc 关闭")
		return

	if _guide_controller and _guide_controller.has_method("get_story_interaction_hint"):
		var story_hint = _guide_controller.get_story_interaction_hint(player_position, _inventory.get_selected_item())
		if not str(story_hint).is_empty():
			_hud.set_interaction_hint(story_hint)
			return

	if can_inspect_stele(player_position):
		_hud.set_interaction_hint("靠近界碑：按 E 查看异常区入口")
		return

	if _chest != null and _chest.can_interact_from(player_position):
		_hud.set_interaction_hint("靠近箱子：按 E 打开")
		return

	if can_interact_with_well(player_position):
		if _inventory.get_selected_item() == ItemDatabase.WATERING_CAN_EMPTY:
			_hud.set_interaction_hint("靠近水井：按 E 装水")
		else:
			_hud.set_interaction_hint("切换到空水壶后按 E 装水")
		return

	var current_zone: Dictionary = _zone_manager.get_current_zone() if _zone_manager else {}
	if not current_zone.is_empty():
		var selected_item: int = _inventory.get_selected_item()
		if selected_item == ItemDatabase.SEED_GEM or selected_item == ItemDatabase.SEED_VINE:
			_hud.set_interaction_hint("站在农田里：按 E 播种")
		elif selected_item == ItemDatabase.WATERING_CAN_FULL:
			_hud.set_interaction_hint("对作物按 E 浇水")
		elif selected_item == ItemDatabase.SCISSORS:
			_hud.set_interaction_hint("对成熟作物按 E 收获")
		else:
			_hud.set_interaction_hint("切换合适道具后按 E 互动")
		return

	_hud.clear_interaction_hint()
