extends Node

@export var DayMusic: AudioStream
@export var NightMusic: AudioStream
@export var MusicVolumeDb: float = -16.0

var _player: AudioStreamPlayer
var _day_lighting: CanvasModulate
var _current_stream: AudioStream

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = MusicVolumeDb
	add_child(_player)
	_day_lighting = get_tree().current_scene.get_node_or_null("DayLighting")
	_update_music(true)

func _process(_delta: float) -> void:
	_update_music(false)

func _update_music(force: bool) -> void:
	var next_stream: AudioStream = DayMusic
	if _day_lighting and _day_lighting.has_method("get_current_time"):
		var hour: float = _day_lighting.get_current_time()
		if hour >= 18.0 or hour < 6.0:
			next_stream = NightMusic if NightMusic else DayMusic

	if next_stream == _current_stream and not force:
		return

	_current_stream = next_stream
	if _current_stream == null:
		return

	_player.stream = _current_stream
	_player.play()
