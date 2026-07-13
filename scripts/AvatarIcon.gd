extends Control
## Avatar preview button — renders the shared DocDraw character.

const DocDraw := preload("res://scripts/DocDraw.gd")

signal picked(avatar: String)

var avatar := "maleDoctor"
var selected := false


func _init() -> void:
	custom_minimum_size = Vector2(58, 64)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		picked.emit(avatar)
		accept_event()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.29, 0.87, 0.5, 0.18) if selected else Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(12)
	sb.border_color = Color("#4ade80") if selected else Color(1, 1, 1, 0.18)
	sb.set_border_width_all(2 if selected else 1)
	sb.draw(get_canvas_item(), r)
	# character is ~92 units tall; fit it inside the card with padding
	var sc := (size.y - 12.0) / 92.0
	DocDraw.character(self, Vector2(size.x / 2, size.y - 6), avatar, {"scale": sc})
