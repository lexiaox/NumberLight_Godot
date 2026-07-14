extends RefCounted

const FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

static var _font: FontFile

static func get_font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
	return _font

static func apply_to_subtree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		_apply_to_control(root)
	for child in root.get_children():
		apply_to_subtree(child)

static func _apply_to_control(control: Control) -> void:
	var font := get_font()
	if font == null:
		return
	control.add_theme_font_override("font", font)
