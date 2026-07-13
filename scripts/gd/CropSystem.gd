# CropSystem.gd — 作物种植系统
extends Node

const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

enum CropType { NONE, GEM_FLOWER, VINE }
enum CropState { SEEDLING, GROWING, MATURE, THIRSTY, WITHERED }

var _crops: Array = []
var _zone_manager
var _day_night
var _inventory

const GEM_STAGE_DURATION = 3.0
const GEM_TOTAL_STAGES = 2
const GEM_THIRST_TIME = 1.0
const GEM_WITHER_TIME = 3.0
const VINE_GROW_TIME = 6.0

var _tex_gem_normal: Texture2D
var _tex_gem_thirsty: Texture2D
var _tex_gem_withered: Texture2D
var _tex_vine: Texture2D

const GEM_BASE_SCALE = 0.23
const VINE_SCALE = 0.047

func _ready():
    _zone_manager = get_tree().current_scene.get_node_or_null("FarmZoneManager")
    _day_night = get_tree().current_scene.get_node_or_null("DayLighting")
    _inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
    _tex_gem_normal = load("res://assets/sprites/crops/宝石花-常态.png")
    _tex_gem_thirsty = load("res://assets/sprites/crops/宝石花-缺水.png")
    _tex_gem_withered = load("res://assets/sprites/crops/宝石花-枯萎.png")
    _tex_vine = load("res://assets/sprites/crops/藤曼-初生.png")

func _process(delta):
    update_crops(delta)

func update_crops(delta_sec: float):
    if not _day_night: return
    var hours_per_sec = 24.0 / _day_night.day_duration
    var dh = delta_sec * hours_per_sec
    for i in range(_crops.size() - 1, -1, -1):
        var crop = _crops[i]
        if crop.state == CropState.WITHERED: continue
        if crop.type == CropType.GEM_FLOWER: update_gem_flower(crop, dh)
        else: update_vine(crop, dh)

func update_gem_flower(crop, dh: float):
    if crop.state == CropState.MATURE: return
    crop.thirst_timer += dh
    if not crop.was_watered:
        crop.total_thirst_time += dh
        if crop.thirst_timer >= GEM_THIRST_TIME and crop.state != CropState.THIRSTY:
            crop.state = CropState.THIRSTY; update_crop_visual(crop)
        if crop.total_thirst_time >= GEM_WITHER_TIME:
            crop.state = CropState.WITHERED; update_crop_visual(crop); return
    if crop.was_watered and crop.state != CropState.THIRSTY:
        crop.growth_timer += dh
        if crop.growth_timer >= GEM_STAGE_DURATION:
            crop.growth_timer = 0; crop.growth_stage += 1
            crop.was_watered = false; crop.thirst_timer = 0; crop.total_thirst_time = 0
            if crop.growth_stage >= GEM_TOTAL_STAGES:
                crop.state = CropState.MATURE; crop.was_watered = true
                update_crop_visual(crop); show_mature_label(crop)
            else:
                crop.state = CropState.GROWING; update_crop_visual(crop)

func update_vine(crop, dh: float):
    if crop.state == CropState.MATURE: return
    crop.growth_timer += dh
    if crop.growth_timer >= VINE_GROW_TIME:
        crop.state = CropState.MATURE; show_mature_label(crop)

func try_plant() -> bool:
    if not _inventory or not _zone_manager: return false
    var selected = _inventory.get_selected_item()
    if selected != ItemDatabase.SEED_GEM and selected != ItemDatabase.SEED_VINE: return false
    var zone = _zone_manager.get_current_zone()
    if not zone: return false
    if find_crop_at_zone(zone.name): return false
    var crop_type = CropType.GEM_FLOWER if selected == ItemDatabase.SEED_GEM else CropType.VINE
    var crop = {
        "type": crop_type, "state": CropState.SEEDLING, "zone_name": zone.name,
        "position": zone.bounds.get_center(), "growth_timer": 0.0, "thirst_timer": 0.0,
        "total_thirst_time": 0.0, "was_watered": crop_type == CropType.VINE,
        "growth_stage": 0, "sprite": null, "mature_label": null
    }
    create_crop_sprite(crop)
    _crops.append(crop)
    _inventory.remove_item()
    return true

func try_water() -> bool:
    if not _inventory or not _zone_manager: return false
    if _inventory.get_selected_item() != ItemDatabase.WATERING_CAN_FULL: return false
    var zone = _zone_manager.get_current_zone()
    if not zone: return false
    var crop = find_crop_at_zone(zone.name)
    if not crop or crop.type == CropType.VINE: return false
    if crop.state != CropState.THIRSTY: return false
    crop.was_watered = true; crop.thirst_timer = 0
    crop.state = CropState.SEEDLING if crop.growth_stage == 0 else CropState.GROWING
    update_crop_visual(crop)
    _inventory.replace_selected_item(ItemDatabase.WATERING_CAN_EMPTY)
    return true

func try_harvest() -> bool:
    if not _inventory or not _zone_manager: return false
    if _inventory.get_selected_item() != ItemDatabase.SCISSORS: return false
    var zone = _zone_manager.get_current_zone()
    if not zone: return false
    var crop = find_crop_at_zone(zone.name)
    if not crop or crop.state != CropState.MATURE: return false
    var drop_id = ItemDatabase.GEM if crop.type == CropType.GEM_FLOWER else ItemDatabase.SEED_VINE
    var drop_count = 1 if crop.type == CropType.GEM_FLOWER else 2
    if crop.sprite: crop.sprite.queue_free()
    if crop.mature_label: crop.mature_label.queue_free()
    _crops.erase(crop)
    _inventory.add_item(drop_id, drop_count)
    _zone_manager.clear_crop(zone.name)
    return true

func find_crop_at_zone(zone_name: String):
    for c in _crops:
        if c.zone_name == zone_name: return c
    return null

func create_crop_sprite(crop):
    var sprite = Sprite2D.new()
    sprite.name = "Crop_" + crop.zone_name
    sprite.position = crop.position
    sprite.z_index = 7
    if crop.type == CropType.GEM_FLOWER:
        sprite.texture = _tex_gem_normal
        sprite.scale = Vector2(GEM_BASE_SCALE * 0.45, GEM_BASE_SCALE * 0.45)
    else:
        sprite.texture = _tex_vine
        sprite.scale = Vector2(VINE_SCALE, VINE_SCALE)
    var decorations = get_tree().current_scene.get_node_or_null("Decorations")
    if decorations: decorations.add_child(sprite)
    else: get_tree().current_scene.add_child(sprite)
    crop.sprite = sprite

func update_crop_visual(crop):
    if not crop.sprite: return
    if crop.type == CropType.GEM_FLOWER:
        match crop.state:
            CropState.SEEDLING:
                crop.sprite.texture = _tex_gem_normal
                crop.sprite.scale = Vector2(GEM_BASE_SCALE * 0.45, GEM_BASE_SCALE * 0.45)
            CropState.GROWING:
                crop.sprite.texture = _tex_gem_normal
                crop.sprite.scale = Vector2(GEM_BASE_SCALE * 0.7, GEM_BASE_SCALE * 0.7)
            CropState.MATURE:
                crop.sprite.texture = _tex_gem_normal
                crop.sprite.scale = Vector2(GEM_BASE_SCALE, GEM_BASE_SCALE)
            CropState.THIRSTY:
                crop.sprite.texture = _tex_gem_thirsty
                var ts = 0.45 if crop.growth_stage == 0 else (0.7 if crop.growth_stage == 1 else 1.0)
                crop.sprite.scale = Vector2(GEM_BASE_SCALE * ts, GEM_BASE_SCALE * ts)
            CropState.WITHERED:
                crop.sprite.texture = _tex_gem_withered
                crop.sprite.scale = Vector2(GEM_BASE_SCALE, GEM_BASE_SCALE)

func show_mature_label(crop):
    var label = Label.new()
    label.text = "成熟"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var crop_height = 48.0
    label.position = crop.position + Vector2(-20, -crop_height - 20)
    label.z_index = 20
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 4)
    var root = get_tree().current_scene
    root.add_child(label)
    crop.mature_label = label
