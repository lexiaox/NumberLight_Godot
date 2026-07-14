# DayFarmManager.gd - 白天农场场景全局管理
extends Node2D

const GameState = preload("res://scripts/gd/GameState.gd")

@export var canvas_modulate: CanvasModulate

const DAY_COLOR = Color(1.0, 0.96, 0.88, 1.0)

func _ready() -> void:
	apply_day_lighting()
	start_ambient_particles()
	restore_return_spawn()
	show_pending_notice()

func apply_day_lighting() -> void:
	if canvas_modulate:
		canvas_modulate.color = DAY_COLOR

func start_ambient_particles() -> void:
	var container = get_node_or_null("Particles")
	if not container:
		return
	for child in container.get_children():
		if child is GPUParticles2D:
			child.emitting = true
			child.restart()

func restore_return_spawn() -> void:
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		return
	if GameState.pending_farm_spawn == "anomaly_return":
		var spawn := get_node_or_null("Decorations/Signboard/InteractPoint") as Node2D
		if spawn != null:
			player.global_position = spawn.global_position + Vector2(-120, 40)
	elif GameState.pending_farm_spawn == "farm_start":
		player.global_position = Vector2(300, 500)
	GameState.pending_farm_spawn = ""

func show_pending_notice() -> void:
	var notice := GameState.take_pending_notice()
	if not notice.is_empty():
		GameState.show_notice(notice, 2.2)

