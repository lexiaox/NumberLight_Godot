extends Node

@export var collision_scale: float = 1.0

const OBSTACLE_PROFILES = {
	"Tree": {"w": 0.40, "h": 0.25, "y": 0.35},
	"Fence": {"w": 1.05, "h": 1.10, "y": 0.00},
	"Farmhouse": {"w": 1.00, "h": 1.05, "y": 0.02},
	"Barn": {"w": 1.00, "h": 1.05, "y": 0.02},
	"Well": {"w": 0.95, "h": 0.90, "y": 0.05},
	"WaterPool": {"w": 1.05, "h": 1.05, "y": 0.02},
	"Chest": {"w": 1.05, "h": 1.00, "y": 0.05},
	"Signboard": {"w": 0.85, "h": 0.80, "y": 0.10},
	"Rock": {"w": 1.05, "h": 1.00, "y": 0.03},
	"Scarecrow": {"w": 0.50, "h": 0.30, "y": 0.30}
}

const KNOWN_CONTENT_RECTS = {
	"1306x1204": Rect2i(145, 106, 1067, 891),
	"1254x1254": Rect2i(230, 232, 795, 779),
	"582x588": Rect2i(95, 70, 416, 407),
	"635x733": Rect2i(94, 66, 416, 623),
	"1774x887": Rect2i(159, 316, 1460, 298),
	"1402x1122": Rect2i(271, 170, 848, 773),
	"32x64": Rect2i(4, 8, 24, 55),
	"32x32": Rect2i(0, 6, 32, 22),
	"70x128": Rect2i(0, 0, 70, 128),
	"86x116": Rect2i(0, 0, 86, 116),
	"54x100": Rect2i(0, 0, 54, 100)
}

func _ready() -> void:
	scan_and_add_collision(get_tree().current_scene)

func scan_and_add_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			continue
		if child is Sprite2D:
			try_add_collision(child)
		scan_and_add_collision(child)

func get_content_rect(tex: Texture2D) -> Rect2i:
	var tex_size := tex.get_size()
	var key := "%dx%d" % [int(tex_size.x), int(tex_size.y)]
	if KNOWN_CONTENT_RECTS.has(key):
		return KNOWN_CONTENT_RECTS[key]
	var img := tex.get_image()
	if img:
		var rect := img.get_used_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			return rect
	return Rect2i(0, 0, int(tex_size.x), int(tex_size.y))

func try_add_collision(sprite: Sprite2D) -> bool:
	for child in sprite.get_children():
		if child is StaticBody2D:
			return false

	var profile = null
	var sprite_name := sprite.name
	for prefix in OBSTACLE_PROFILES:
		if sprite_name.begins_with(prefix):
			profile = OBSTACLE_PROFILES[prefix]
			break
	if profile == null:
		return false

	var tex := sprite.texture
	if tex == null:
		return false

	var tex_size := tex.get_size()
	var used_rect := get_content_rect(tex)
	var cw := float(used_rect.size.x)
	var ch := float(used_rect.size.y)
	var cx_off := (used_rect.position.x + cw / 2.0) - tex_size.x / 2.0
	var cy_off := (used_rect.position.y + ch / 2.0) - tex_size.y / 2.0

	var sx := sprite.scale.x
	var sy := sprite.scale.y
	var off_x := cx_off * sx
	var off_y := cy_off * sy
	var col_w: float = cw * sx * profile.w * collision_scale
	var col_h: float = ch * sy * profile.h * collision_scale
	var col_x := off_x
	var col_y: float = off_y + ch * sy * profile.y

	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 2
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = Vector2(col_w, col_h)

	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col_shape.position = Vector2(col_x, col_y)
	body.add_child(col_shape)
	sprite.add_child(body)
	return true
