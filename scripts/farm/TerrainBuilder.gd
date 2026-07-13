@tool
extends Node

@export var build_on_ready: bool = false
@export var clear_and_rebuild: bool = false

func _ready() -> void:
	if Engine.is_editor_hint() and build_on_ready:
		_rebuild_if_needed()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and clear_and_rebuild:
		clear_and_rebuild = false
		_rebuild_if_needed()

func _rebuild_if_needed() -> void:
	# 当前场景已经直接保存了 TileMap 数据。
	# Web/GDScript 版本先不做运行时重建，只保留一个安全占位实现，
	# 避免旧的 TileMapLayer 脚本在 DayFarm(TileMap) 上报错。
	pass
