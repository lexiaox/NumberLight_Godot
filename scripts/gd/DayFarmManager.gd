# DayFarmManager.gd — 白天农场场景全局管理器
extends Node2D

@export var canvas_modulate: CanvasModulate

const DAY_COLOR = Color(1.0, 0.96, 0.88, 1.0)

func _ready():
    apply_day_lighting()
    start_ambient_particles()

func apply_day_lighting():
    if canvas_modulate:
        canvas_modulate.color = DAY_COLOR

func start_ambient_particles():
    var container = get_node_or_null("Particles")
    if not container: return
    for child in container.get_children():
        if child is GPUParticles2D:
            child.emitting = true
            child.restart()
