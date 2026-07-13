# InteractionManager.gd — E键统一交互管理器
extends Node

const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

var _crop_system
var _zone_manager
var _chest
var _inventory
var _player: CharacterBody2D
var _well: Sprite2D
const WELL_RANGE = 80.0

func _ready():
    _crop_system = get_tree().current_scene.get_node_or_null("CropSystem")
    _zone_manager = get_tree().current_scene.get_node_or_null("FarmZoneManager")
    _inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
    _chest = get_tree().current_scene.get_node_or_null("Chest")
    _player = get_tree().current_scene.get_node_or_null("Player")
    _well = get_tree().current_scene.get_node_or_null("Decorations/Well")

func _process(_delta):
    if not Input.is_action_just_pressed("interact"): return
    if _chest and (_chest.is_ui_open() or _chest.is_player_near()): return
    if not _inventory or not _player: return
    var selected = _inventory.get_selected_item()

    if selected == ItemDatabase.WATERING_CAN_EMPTY:
        if try_fill_watering_can(): return

    if not _crop_system or not _zone_manager: return
    if not _zone_manager.get_current_zone(): return

    var success = false
    if selected == ItemDatabase.SEED_GEM or selected == ItemDatabase.SEED_VINE:
        success = _crop_system.try_plant()
    elif selected == ItemDatabase.WATERING_CAN_FULL:
        success = _crop_system.try_water()
    elif selected == ItemDatabase.SCISSORS:
        success = _crop_system.try_harvest()

func try_fill_watering_can() -> bool:
    if not _well or not _player: return false
    if _player.global_position.distance_to(_well.global_position) > WELL_RANGE: return false
    _inventory.replace_selected_item(ItemDatabase.WATERING_CAN_FULL)
    return true
