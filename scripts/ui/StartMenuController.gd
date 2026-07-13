extends Control

const FARM_SCENE_PATH := "res://scenes/farm/DayFarm.tscn"

@onready var _start_button: Button = $CenterPanel/Layout/StartButton

func _ready() -> void:
	if _start_button:
		_start_button.pressed.connect(_enter_game)
		_start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_enter_game()

func _enter_game() -> void:
	get_tree().change_scene_to_file(FARM_SCENE_PATH)
