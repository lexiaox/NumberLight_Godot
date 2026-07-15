extends Node

const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")
const FarmHUD = preload("res://scripts/gd/FarmHUD.gd")
const UIFont = preload("res://scripts/ui/UIFont.gd")

enum CropType { NONE, GEM_FLOWER, VINE }
enum CropState { SEEDLING, GROWING, MATURE, THIRSTY, WITHERED }

var _crops: Array = []
var _zone_manager
var _day_night
var _inventory
var _hud

const GEM_STAGE_DURATION := 3.0
const GEM_TOTAL_STAGES := 2
const GEM_THIRST_TIME := 1.0
const GEM_WITHER_TIME := 3.0
const VINE_GROW_TIME := 6.0

var _tex_gem_normal: Texture2D
var _tex_gem_thirsty: Texture2D
var _tex_gem_withered: Texture2D
var _tex_vine: Texture2D

const GEM_BASE_SCALE := 0.23
const VINE_SCALE := 0.047

func _ready() -> void:
	_zone_manager = get_tree().current_scene.get_node_or_null("FarmZoneManager")
	_day_night = get_tree().current_scene.get_node_or_null("DayLighting")
	_inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
	_hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	_tex_gem_normal = load("res://assets/sprites/crops/gem_flower_normal.png")
	_tex_gem_thirsty = load("res://assets/sprites/crops/gem_flower_thirsty.png")
	_tex_gem_withered = load("res://assets/sprites/crops/gem_flower_withered.png")
	_tex_vine = load("res://assets/sprites/crops/vine_seedling.png")

func _process(delta: float) -> void:
	update_crops(delta)

func update_crops(delta_sec: float) -> void:
	if _day_night == null:
		return
	var hours_per_sec := 24.0 / maxf(_day_night.day_duration, 0.001)
	var dh := delta_sec * hours_per_sec
	for i in range(_crops.size() - 1, -1, -1):
		var crop = _crops[i]
		if crop.state == CropState.WITHERED:
			continue
		if crop.type == CropType.GEM_FLOWER:
			update_gem_flower(crop, dh)
		else:
			update_vine(crop, dh)

func update_gem_flower(crop, dh: float) -> void:
	if crop.state == CropState.MATURE:
		return
	crop.thirst_timer += dh
	if not crop.was_watered:
		crop.total_thirst_time += dh
		if crop.thirst_timer >= GEM_THIRST_TIME and crop.state != CropState.THIRSTY:
			crop.state = CropState.THIRSTY
			update_crop_visual(crop)
			_hud.show_toast("宝石花缺水了", FarmHUD.ToastKind.WARNING)
		if crop.total_thirst_time >= GEM_WITHER_TIME:
			crop.state = CropState.WITHERED
			update_crop_visual(crop)
			_hud.show_toast("宝石花已经枯萎", FarmHUD.ToastKind.WARNING)
			return
	if crop.was_watered and crop.state != CropState.THIRSTY:
		crop.growth_timer += dh
		if crop.growth_timer >= GEM_STAGE_DURATION:
			crop.growth_timer = 0.0
			crop.growth_stage += 1
			crop.was_watered = false
			crop.thirst_timer = 0.0
			crop.total_thirst_time = 0.0
			if crop.growth_stage >= GEM_TOTAL_STAGES:
				crop.state = CropState.MATURE
				crop.was_watered = true
				update_crop_visual(crop)
				show_mature_label(crop)
				_hud.show_toast("作物成熟，可收获", FarmHUD.ToastKind.SUCCESS)
			else:
				crop.state = CropState.GROWING
				update_crop_visual(crop)

func update_vine(crop, dh: float) -> void:
	if crop.state == CropState.MATURE:
		return
	crop.growth_timer += dh
	if crop.growth_timer >= VINE_GROW_TIME:
		crop.state = CropState.MATURE
		show_mature_label(crop)
		_hud.show_toast("晨露藤成熟，可收获", FarmHUD.ToastKind.SUCCESS)

func try_plant() -> bool:
	if _inventory == null or _zone_manager == null:
		return false
	var selected: int = _inventory.get_selected_item()
	if selected != ItemDatabase.SEED_GEM and selected != ItemDatabase.SEED_VINE:
		return false
	var zone: Dictionary = _zone_manager.get_current_zone()
	if zone.is_empty():
		_hud.show_toast("请先站到农田格子里", FarmHUD.ToastKind.WARNING)
		return false
	if find_crop_at_zone(zone.name):
		_hud.show_toast("这块地已经有作物了", FarmHUD.ToastKind.WARNING)
		return false
	var crop_type := CropType.GEM_FLOWER if selected == ItemDatabase.SEED_GEM else CropType.VINE
	var crop = {
		"type": crop_type,
		"state": CropState.SEEDLING,
		"zone_name": zone.name,
		"position": zone.bounds.get_center(),
		"growth_timer": 0.0,
		"thirst_timer": 0.0,
		"total_thirst_time": 0.0,
		"was_watered": crop_type == CropType.VINE,
		"growth_stage": 0,
		"sprite": null,
		"mature_label": null
	}
	create_crop_sprite(crop)
	_crops.append(crop)
	_inventory.remove_item()
	_hud.show_toast("种植成功", FarmHUD.ToastKind.SUCCESS)
	return true

func try_water() -> bool:
	if _inventory == null or _zone_manager == null:
		return false
	if _inventory.get_selected_item() != ItemDatabase.WATERING_CAN_FULL:
		return false
	var zone: Dictionary = _zone_manager.get_current_zone()
	if zone.is_empty():
		_hud.show_toast("这里没有可以浇水的作物", FarmHUD.ToastKind.WARNING)
		return false
	var crop = find_crop_at_zone(zone.name)
	if crop == null or crop.type == CropType.VINE:
		_hud.show_toast("这里没有可以浇水的作物", FarmHUD.ToastKind.WARNING)
		return false
	if crop.state != CropState.THIRSTY:
		_hud.show_toast("当前作物不需要浇水", FarmHUD.ToastKind.WARNING)
		return false
	crop.was_watered = true
	crop.thirst_timer = 0.0
	crop.state = CropState.SEEDLING if crop.growth_stage == 0 else CropState.GROWING
	update_crop_visual(crop)
	_inventory.replace_selected_item(ItemDatabase.WATERING_CAN_EMPTY)
	_hud.show_toast("浇水成功", FarmHUD.ToastKind.SUCCESS)
	return true

func try_harvest() -> bool:
	if _inventory == null or _zone_manager == null:
		return false
	if _inventory.get_selected_item() != ItemDatabase.SCISSORS:
		return false
	var zone: Dictionary = _zone_manager.get_current_zone()
	if zone.is_empty():
		_hud.show_toast("当前格子没有可收获的作物", FarmHUD.ToastKind.WARNING)
		return false
	var crop = find_crop_at_zone(zone.name)
	if crop == null or crop.state != CropState.MATURE:
		_hud.show_toast("当前格子没有可收获的作物", FarmHUD.ToastKind.WARNING)
		return false
	var drop_id := ItemDatabase.GEM if crop.type == CropType.GEM_FLOWER else ItemDatabase.SEED_VINE
	var drop_count := 1 if crop.type == CropType.GEM_FLOWER else 2
	if not _inventory.add_item(drop_id, drop_count):
		_hud.show_toast("背包已满，无法收获", FarmHUD.ToastKind.WARNING)
		return false
	if crop.sprite:
		crop.sprite.queue_free()
	if crop.mature_label:
		crop.mature_label.queue_free()
	_crops.erase(crop)
	_zone_manager.clear_crop(zone.name)
	_hud.show_toast("收获成功：%d x %s" % [drop_count, ItemDatabase.get_item_name(drop_id)], FarmHUD.ToastKind.SUCCESS)
	return true

func find_crop_at_zone(zone_name: String):
	for crop in _crops:
		if crop.zone_name == zone_name:
			return crop
	return null

func can_water_zone(zone_name: String) -> bool:
	var crop = find_crop_at_zone(zone_name)
	return crop != null and crop.type == CropType.GEM_FLOWER and crop.state == CropState.THIRSTY

func can_harvest_zone(zone_name: String) -> bool:
	var crop = find_crop_at_zone(zone_name)
	return crop != null and crop.state == CropState.MATURE

func create_crop_sprite(crop) -> void:
	var sprite := Sprite2D.new()
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
	if decorations:
		decorations.add_child(sprite)
	else:
		get_tree().current_scene.add_child(sprite)
	crop.sprite = sprite

func update_crop_visual(crop) -> void:
	if crop.sprite == null or crop.type != CropType.GEM_FLOWER:
		return
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
			var scale_factor := 0.45 if crop.growth_stage == 0 else 0.7
			crop.sprite.scale = Vector2(GEM_BASE_SCALE * scale_factor, GEM_BASE_SCALE * scale_factor)
		CropState.WITHERED:
			crop.sprite.texture = _tex_gem_withered
			crop.sprite.scale = Vector2(GEM_BASE_SCALE, GEM_BASE_SCALE)

func show_mature_label(crop) -> void:
	if crop.mature_label:
		crop.mature_label.queue_free()
	var label := Label.new()
	label.text = "可收获"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = crop.position + Vector2(-28, -68)
	label.z_index = 20
	label.add_theme_font_override("font", UIFont.get_font())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	get_tree().current_scene.add_child(label)
	crop.mature_label = label
