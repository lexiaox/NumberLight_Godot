extends CanvasModulate

@export var day_duration: float = 120.0
@export var start_time: float = 6.0
@export var update_time_label: bool = true

var _current_time: float = 6.0
var _day_count: int = 1
var _time_label: Label
var _date_label: Label

const TIME_COLORS: Array = [
	[0.0, 0.25, 0.28, 0.45],
	[5.0, 0.45, 0.42, 0.58],
	[6.0, 0.85, 0.70, 0.60],
	[8.0, 1.0, 0.98, 0.92],
	[12.0, 1.0, 1.0, 0.98],
	[16.0, 1.0, 0.95, 0.85],
	[18.0, 0.95, 0.65, 0.40],
	[20.0, 0.50, 0.45, 0.65],
	[22.0, 0.30, 0.33, 0.52],
	[24.0, 0.25, 0.28, 0.45]
]

func _ready() -> void:
	_current_time = start_time
	color = get_color_at_time(_current_time)
	_find_ui_labels()
	_update_ui()

func _process(delta: float) -> void:
	var hours_per_sec: float = 24.0 / maxf(day_duration, 1.0)
	_current_time += hours_per_sec * delta
	if _current_time >= 24.0:
		_current_time -= 24.0
		_day_count += 1
	color = get_color_at_time(_current_time)
	if update_time_label:
		_update_ui()

func get_color_at_time(hour: float) -> Color:
	for i in range(TIME_COLORS.size() - 1):
		var a: Array = TIME_COLORS[i]
		var b: Array = TIME_COLORS[i + 1]
		if hour >= float(a[0]) and hour < float(b[0]):
			var t: float = (hour - float(a[0])) / (float(b[0]) - float(a[0]))
			return Color(
				lerpf(float(a[1]), float(b[1]), t),
				lerpf(float(a[2]), float(b[2]), t),
				lerpf(float(a[3]), float(b[3]), t),
				1.0
			)
	return Color(0.3, 0.33, 0.52, 1.0)

func _find_ui_labels() -> void:
	var root: Node = get_tree().current_scene
	_time_label = root.get_node_or_null("UI/TopBar/TimeLabel")
	_date_label = root.get_node_or_null("UI/TopBar/DateLabel")

func _update_ui() -> void:
	if _time_label:
		_time_label.text = format_time(_current_time)
	if _date_label:
		_date_label.text = "第 %d 天" % _day_count

func format_time(hour: float) -> String:
	var whole_hour: int = int(hour)
	var minute: int = int((hour - whole_hour) * 60.0)
	var period: String = "AM" if whole_hour < 12 else "PM"
	var display_hour: int = whole_hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, minute, period]

func get_current_time() -> float:
	return _current_time

func get_day_count() -> int:
	return _day_count
