extends CharacterBody2D

const GameState = preload("res://scripts/gd/GameState.gd")

@export var speed: float = 210.0
@export var display_scale: float = 0.2
@export var width_slim_factor: float = 0.8
@export var animation_fps: float = 10.0

enum Facing { DOWN, UP, LEFT, RIGHT }

const FRAMES_DIR = "res://assets/sprites/character/player/frames/"
const ANIM_NAMES = ["down", "up", "left", "right"]
const RUN_FRAME_COUNT = 8

var _current_facing: int = Facing.DOWN
var _animated_sprite: AnimatedSprite2D
var _camera: Camera2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	create_animated_sprite()
	create_collision_shape()
	ensure_camera()

func create_animated_sprite() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedSprite"
	_animated_sprite.centered = true
	_animated_sprite.scale = Vector2(display_scale * width_slim_factor, display_scale)
	var frames := SpriteFrames.new()
	for dir in ANIM_NAMES:
		var idle_name: String = "idle_" + dir
		var idle_tex := load(FRAMES_DIR + "idle_" + dir + "_0.png") as Texture2D
		if idle_tex:
			frames.add_animation(idle_name)
			frames.add_frame(idle_name, idle_tex)
		var run_name: String = "run_" + dir
		frames.add_animation(run_name)
		frames.set_animation_loop(run_name, true)
		frames.set_animation_speed(run_name, animation_fps)
		for i in range(RUN_FRAME_COUNT):
			var frame_tex := load(FRAMES_DIR + "run_" + dir + "_" + str(i) + ".png") as Texture2D
			if frame_tex:
				frames.add_frame(run_name, frame_tex)
	_animated_sprite.sprite_frames = frames
	_animated_sprite.play("idle_down")
	add_child(_animated_sprite)

func create_collision_shape() -> void:
	var shape := RectangleShape2D.new()
	var width := 246.0 * display_scale * width_slim_factor * 0.4
	var height := 432.0 * display_scale * 0.2
	shape.size = Vector2(width, height)

	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 432.0 * display_scale * 0.35)
	add_child(collision)

func ensure_camera() -> void:
	_camera = get_node_or_null("Camera2D")
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "Camera2D"
		_camera.enabled = true
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 6.0
		add_child(_camera)
	_camera.make_current()

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
	update_animation(direction)

func read_input() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("up"):
		direction.y -= 1.0
	if Input.is_action_pressed("down"):
		direction.y += 1.0
	if Input.is_action_pressed("left"):
		direction.x -= 1.0
	if Input.is_action_pressed("right"):
		direction.x += 1.0
	return direction

func update_animation(direction: Vector2) -> void:
	if _animated_sprite == null:
		return
	var moving := direction.length() > 0.01
	var prefix := "run" if moving else "idle"
	if moving:
		if absf(direction.y) >= absf(direction.x):
			_current_facing = Facing.UP if direction.y < 0.0 else Facing.DOWN
		else:
			_current_facing = Facing.LEFT if direction.x < 0.0 else Facing.RIGHT
	var anim_name: String = prefix + "_" + ANIM_NAMES[_current_facing]
	if _animated_sprite.animation != anim_name and _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.play(anim_name)

func get_foot_world_position() -> Vector2:
	return global_position + Vector2(0, 432.0 * display_scale * 0.35)
