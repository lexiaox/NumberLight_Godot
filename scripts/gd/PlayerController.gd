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

func create_animated_sprite() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedSprite"
	_animated_sprite.centered = true
	_animated_sprite.scale = Vector2(display_scale * width_slim_factor, display_scale)
	var sf: SpriteFrames = SpriteFrames.new()
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

func create_collision_shape() -> void:
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape"
	var fw: float = 246.0 * display_scale * width_slim_factor
	var fh: float = 432.0 * display_scale
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(fw * 0.4, fh * 0.2)
	cs.shape = rect
	cs.position = Vector2(0, fh * 0.35)
	add_child(cs)

func create_hand_item() -> void:
	_hand_item = Sprite2D.new()
	_hand_item.name = "HandItem"
	_hand_item.centered = true
	_hand_item.scale = Vector2(1.2, 1.2)
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

func _physics_process(_delta: float) -> void:
	if GameState.is_modal_ui_open:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO)
		return
	var direction: Vector2 = read_input()
	if direction.length() > 1.0:
		direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)
	update_hand_item()
	update_hand_item_position()

func read_input() -> Vector2:
	var d: Vector2 = Vector2.ZERO
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
	var is_moving: bool = direction.length() > 0.01
	var prefix: String = "run" if is_moving else "idle"
	var new_facing: int = _current_facing
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
	var pw: float = 246.0 * display_scale * width_slim_factor
	var ph: float = 432.0 * display_scale
	match _current_facing:
		Facing.DOWN:
			_hand_item.position = Vector2(pw * 0.35, ph * 0.2)
			_hand_item.flip_h = false
		Facing.UP:
			_hand_item.position = Vector2(pw * 0.35, -ph * 0.05)
			_hand_item.flip_h = false
		Facing.LEFT:
			_hand_item.position = Vector2(-pw * 0.35, ph * 0.15)
			_hand_item.flip_h = true
		Facing.RIGHT:
			_hand_item.position = Vector2(pw * 0.35, ph * 0.15)
			_hand_item.flip_h = false

func get_foot_world_position() -> Vector2:
	var ph: float = 432.0 * display_scale
	return global_position + Vector2(0, ph * 0.35)
