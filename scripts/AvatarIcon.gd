extends Control
## Avatar preview button — port of drawAvatarPreviews() from the HTML game.

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


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _crescent(c: Vector2, r: float, col: Color, cut: Color) -> void:
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.42, -r * 0.08), r * 0.88, cut)


func _bfill(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.29, 0.87, 0.5, 0.18) if selected else Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(12)
	sb.border_color = Color("#4ade80") if selected else Color(1, 1, 1, 0.18)
	sb.set_border_width_all(2 if selected else 1)
	sb.draw(get_canvas_item(), r)

	var female := avatar == "femaleDoctor" or avatar == "femaleNurse"
	var nurse := avatar == "maleNurse" or avatar == "femaleNurse"
	var female_doctor := avatar == "femaleDoctor"
	var skin := Color("#d79a73") if female else Color("#c9855f")
	var hair: Color
	if female_doctor: hair = Color("#151015")
	elif female: hair = Color("#2a1712")
	else: hair = Color("#2b1a12")
	var main := Color("#23a6a8") if nurse else Color("#f7f8fb")
	var shade := Color("#157a86") if nurse else Color("#dfe3ea")
	var pants := Color("#12606a") if nurse else Color("#234a84")

	var sc := (size.y / 64.0) * 0.58 * (0.96 if female else 1.0)
	draw_set_transform(Vector2(size.x / 2 - 2, size.y - 5), 0, Vector2(sc, sc))
	# legs
	draw_line(Vector2(-4, -28), Vector2(-8, 0), pants, 6)
	draw_line(Vector2(4, -28), Vector2(8, 0), pants, 6)
	# torso
	draw_polygon(PackedVector2Array([Vector2(-10, -29), Vector2(10, -29), Vector2(11, -45), Vector2(8, -62), Vector2(-8, -62), Vector2(-11, -45)]),
		PackedColorArray([shade, shade, main.lerp(shade, 0.5), main, main, main.lerp(shade, 0.5)]))
	if not nurse:
		_crescent(Vector2(5, -47), 3.5, Color("#f4d35e"), shade)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -65), Vector2(0, -70), Vector2(5, -65)]), Color.WHITE)
		_crescent(Vector2(1, -67), 2.4, Color("#e63946"), Color.WHITE)
	# arms
	draw_line(Vector2(-7, -58), Vector2(-13, -38), shade, 5)
	draw_line(Vector2(7, -58), Vector2(13, -38), shade, 5)
	# head (neck reaches up into the head ellipse so there is no gap)
	draw_rect(Rect2(-1, -72, 6, 11), skin)
	_ellipse(Vector2(4, -79), 9 if female else 10.5, 11 if female else 11.5, skin)
	# hair
	if female_doctor:
		_bfill(Vector2(-9, -87), Vector2(-15, -80), Vector2(-13, -69), Vector2(-8, -61), hair)
		_bfill(Vector2(9, -87), Vector2(15, -80), Vector2(13, -69), Vector2(9, -61), hair)
		_ellipse(Vector2(3, -89), 12, 6, hair)
	elif female:
		_bfill(Vector2(-7, -88), Vector2(-15, -80), Vector2(-13, -64), Vector2(-9, -52), hair)
		_bfill(Vector2(8, -88), Vector2(17, -80), Vector2(15, -64), Vector2(11, -52), hair)
		_ellipse(Vector2(3, -89), 12, 6, hair)
	else:
		_ellipse(Vector2(3, -88), 12, 7, hair)
		draw_circle(Vector2(-4, -82), 6, hair)
	if nurse:
		_ellipse(Vector2(3, -91), 10, 3.5, Color.WHITE)
		_crescent(Vector2(4, -91), 2.2, Color("#e63946"), Color.WHITE)
	# face
	_ellipse(Vector2(1, -81), 2.2, 2.6, Color.WHITE)
	_ellipse(Vector2(8, -81), 2.4, 2.6, Color.WHITE)
	draw_circle(Vector2(1.4, -81), 1, Color("#2d1b10"))
	draw_circle(Vector2(8.3, -81), 1, Color("#2d1b10"))
	var mouth := Color("#d64f6f") if female else Color("#7a2e10")
	draw_line(Vector2(2, -72), Vector2(5, -70.8), mouth, 1.2)
	draw_line(Vector2(5, -70.8), Vector2(8, -72), mouth, 1.2)
	draw_set_transform_matrix(Transform2D())
