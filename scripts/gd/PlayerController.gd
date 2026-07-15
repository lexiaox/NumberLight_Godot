extends CharacterBody2D

const GameState = preload("res://scripts/gd/GameState.gd")
const ItemDatabase = preload("res://scripts/gd/ItemDatabase.gd")

@export var speed: float = 200.0
@export var display_scale: float = 0.2
@export var width_slim_factor: float = 0.8
@export var animation_fps: float = 10.0

enum Facing { DOWN, UP, LEFT, RIGHT }

var _current_facing: int = Facing.DOWN
var _animated_sprite: AnimatedSprite2D
var _hand_item: Sprite2D
var _inventory
var _last_held_item_id: int = 0
var _camera: Camera2D
var _world_bounds: Rect2 = Rect2()

const FRAMES_DIR = "res://assets/sprites/character/player/frames/"
const ANIM_NAMES = ["down", "up", "left", "right"]
const RUN_FRAME_COUNT = 8

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	_inventory = get_tree().current_scene.get_node_or_null("UI/BottomBar/Toolbar")
	create_animated_sprite()
	create_collision_shape()
	create_hand_item()
	ensure_camera()
	configure_world_bounds()

func create_animated_sprite() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedSprite"
	_animated_sprite.centered = true
	_animated_sprite.scale = Vector2(display_scale * width_slim_factor, display_scale)
	var sf := SpriteFrames.new()
	for dir in ANIM_NAMES:
		var idle_name: String = "idle_" + dir
		var idle_path: String = FRAMES_DIR + "idle_" + dir + "_0.png"
		var idle_tex: Texture2D = load(idle_path)
		if idle_tex:
			sf.add_animation(idle_name)
			sf.add_frame(idle_name, idle_tex)
		var run_name: String = "run_" + dir
		sf.add_animation(run_name)
		sf.set_animation_loop(run_name, true)
		sf.set_animation_speed(run_name, animation_fps)
		for i in range(RUN_FRAME_COUNT):
			var frame_path: String = FRAMES_DIR + "run_" + dir + "_" + str(i) + ".png"
			var frame_tex: Texture2D = load(frame_path)
			if frame_tex:
				sf.add_frame(run_name, frame_tex)
	_animated_sprite.sprite_frames = sf
	_animated_sprite.animation = "idle_down"
	add_child(_animated_sprite)
	_animated_sprite.play("idle_down")

func create_collision_shape() -> void:
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape"
	var fw := 246.0 * display_scale * width_slim_factor
	var fh := 432.0 * display_scale
	var rect := RectangleShape2D.new()
	rect.size = Vector2(fw * 0.4, fh * 0.2)
	cs.shape = rect
	cs.position = Vector2(0, fh * 0.35)
	add_child(cs)

func create_hand_item() -> void:
	_hand_item = Sprite2D.new()
	_hand_item.name = "HandItem"
	_hand_item.centered = true
	_hand_item.scale = Vector2(0.72, 0.72)
	_hand_item.z_index = 11
	_hand_item.visible = false
	add_child(_hand_item)

func ensure_camera() -> void:
	_camera = get_node_or_null("Camera2D")
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "Camera2D"
		_camera.enabled = true
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 6.0
		_camera.zoom = Vector2.ONE
		add_child(_camera)
	_camera.make_current()

func configure_world_bounds() -> void:
	var tilemaps := []
	_collect_tilemaps(get_tree().current_scene, tilemaps)
	var merged := Rect2()
	var has_bounds := false
	for tile_map: TileMap in tilemaps:
		var map_rect := _get_tilemap_world_rect(tile_map)
		if map_rect.size == Vector2.ZERO:
			continue
		merged = map_rect if not has_bounds else merged.merge(map_rect)
		has_bounds = true
	if not has_bounds:
		_world_bounds = Rect2(0, 0, 1280, 720)
	else:
		_world_bounds = merged.grow(24.0)

func _collect_tilemaps(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is TileMap:
			result.append(child)
		_collect_tilemaps(child, result)

func _get_tilemap_world_rect(tile_map: TileMap) -> Rect2:
	var used_rect: Rect2i = tile_map.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2()
	var tile_size := Vector2(32, 32)
	if tile_map.tile_set:
		tile_size = Vector2(tile_map.tile_set.tile_size)
	var top_left := tile_map.to_global(Vector2(used_rect.position) * tile_size)
	var bottom_right := tile_map.to_global(Vector2(used_rect.position + used_rect.size) * tile_size)
	return Rect2(top_left, bottom_right - top_left)

func _physics_process(_delta: float) -> void:
	if GameState.is_modal_ui_open:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO)
		return
	var direction := read_input()
	if direction.length() > 1.0:
		direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()
	_clamp_to_world_bounds()
	update_animation(direction)
	update_hand_item()
	update_hand_item_position()

func _clamp_to_world_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	var half_width := 18.0
	var foot_margin_top := 40.0
	var foot_margin_bottom := 8.0
	global_position.x = clampf(global_position.x, _world_bounds.position.x + half_width, _world_bounds.end.x - half_width)
	global_position.y = clampf(global_position.y, _world_bounds.position.y + foot_margin_top, _world_bounds.end.y - foot_margin_bottom)

func read_input() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_action_pressed("up"):
		d.y -= 1
	if Input.is_action_pressed("down"):
		d.y += 1
	if Input.is_action_pressed("left"):
		d.x -= 1
	if Input.is_action_pressed("right"):
		d.x += 1
	return d

func update_animation(direction: Vector2) -> void:
	if not _animated_sprite:
		return
	var is_moving := direction.length() > 0.01
	var prefix := "run" if is_moving else "idle"
	var new_facing := _current_facing
	if is_moving:
		if absf(direction.y) >= absf(direction.x):
			new_facing = Facing.UP if direction.y < 0 else Facing.DOWN
		else:
			new_facing = Facing.LEFT if direction.x < 0 else Facing.RIGHT
		_current_facing = new_facing
	var anim_name: String = prefix + "_" + ANIM_NAMES[new_facing]
	if _animated_sprite.animation != anim_name and _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.play(anim_name)

func update_hand_item() -> void:
	if not _hand_item or not _inventory:
		return
	var held_id: int = _inventory.get_selected_item()
	if held_id == _last_held_item_id:
		return
	_last_held_item_id = held_id
	if held_id == ItemDatabase.NONE:
		_hand_item.visible = false
		return
	var icon: Texture2D = ItemDatabase.get_icon(held_id)
	if icon:
		_hand_item.texture = icon
		_hand_item.visible = true
	else:
		_hand_item.visible = false

func update_hand_item_position() -> void:
	if not _hand_item or not _hand_item.visible:
		return
	var pw := 246.0 * display_scale * width_slim_factor
	var ph := 432.0 * display_scale
	match _current_facing:
		Facing.DOWN:
			_hand_item.position = Vector2(pw * 0.24, ph * 0.16)
			_hand_item.rotation_degrees = 14.0
			_hand_item.z_index = 11
			_hand_item.flip_h = false
		Facing.UP:
			_hand_item.position = Vector2(pw * 0.18, ph * 0.02)
			_hand_item.rotation_degrees = -22.0
			_hand_item.z_index = 3
			_hand_item.flip_h = false
		Facing.LEFT:
			_hand_item.position = Vector2(-pw * 0.28, ph * 0.10)
			_hand_item.rotation_degrees = -8.0
			_hand_item.z_index = 10
			_hand_item.flip_h = true
		Facing.RIGHT:
			_hand_item.position = Vector2(pw * 0.28, ph * 0.10)
			_hand_item.rotation_degrees = 8.0
			_hand_item.z_index = 10
			_hand_item.flip_h = false

func get_foot_world_position() -> Vector2:
	var ph := 432.0 * display_scale
	return global_position + Vector2(0, ph * 0.35)
