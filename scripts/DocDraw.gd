extends RefCounted
## Shared character renderer (in-game player, menu previews, hospital medics).
## Loaded via: const DocDraw := preload("res://scripts/DocDraw.gd")
## Proportions ~1:5.5 head:body, symmetric around x=0, feet at y=0.
## opts: t (walk phase; <0 = standing), dead, scale, steth, coat

const SKIN_M := Color("#c9855f")
const SKIN_F := Color("#d79a73")


static func character(ci: CanvasItem, pos: Vector2, avatar: String, o: Dictionary = {}) -> void:
	var t: float = o.get("t", -1.0)
	var walking := t >= 0.0
	t = maxf(0.0, t)
	var dead: bool = o.get("dead", false)
	var female := avatar == "femaleDoctor" or avatar == "femaleNurse"
	var nurse := avatar == "maleNurse" or avatar == "femaleNurse"
	var female_doctor := avatar == "femaleDoctor"
	var stride := sin(t) if walking else 0.0
	var bob := absf(sin(t)) * 1.5 if walking else 0.0
	var sc: float = o.get("scale", 1.0) * (0.94 if female else 1.0)

	var skin := SKIN_F if female else SKIN_M
	var skin2 := Color("#b86b4d") if female else Color("#9a5538")
	var hair: Color
	if female_doctor: hair = Color("#1d1418")
	elif female: hair = Color("#2a1712")
	else: hair = Color("#2b1a12")
	var main := Color("#23a6a8") if nurse else Color("#f7f8fb")
	var shade := Color("#157a86") if nurse else Color("#dfe3ea")
	if o.get("coat", "default") == "mintCoat" and not nurse:
		main = Color("#dffbf1")
		shade = Color("#7dd3c7")
	var trim := Color(1, 1, 1, 0.9) if nurse else Color("#c9ced8")
	var pants := Color("#12606a") if nurse else Color("#234a84")
	var gold_steth: bool = o.get("steth", "default") == "goldSteth"
	var steth := Color("#f4d35e") if gold_steth else Color("#20344f")
	var disk := Color("#f6c453") if gold_steth else Color("#6b8daf")

	ci.draw_set_transform(pos + Vector2(0, -bob * sc), 0.0, Vector2(sc, sc))

	# --- legs (rear then front) + shoes ---
	var rear := -stride
	var front := stride
	_qcurve(ci, Vector2(3.4, -33), Vector2(4.4 + rear * 3, -17), Vector2(5 + rear * 7, -1.5), pants, 6.2)
	_ellipse(ci, Vector2(6 + rear * 7, -1), 5.4, 2.5, Color("#101014"))
	_qcurve(ci, Vector2(-3.4, -33), Vector2(-4.4 + front * 3, -17), Vector2(-5 + front * 7, -1.5), pants, 6.6)
	_ellipse(ci, Vector2(-6 + front * 7, -1), 5.7, 2.7, Color("#050508"))

	# --- neck (under the collar and chin) ---
	ci.draw_rect(Rect2(-2.6, -70, 5.2, 8.5), skin)
	ci.draw_rect(Rect2(-2.6, -64, 5.2, 2.0), skin2)  # soft shadow under chin

	# --- torso ---
	var pts := PackedVector2Array([
		Vector2(-10.2, -63), Vector2(10.2, -63), Vector2(9.2, -47),
		Vector2(8.6, -32), Vector2(-8.6, -32), Vector2(-9.2, -47)])
	ci.draw_polygon(pts, PackedColorArray([main, main, main.lerp(shade, 0.55), shade, shade, main.lerp(shade, 0.55)]))
	ci.draw_line(Vector2(-4, -63), Vector2(0, -57), trim, 1.2)
	ci.draw_line(Vector2(0, -57), Vector2(4, -63), trim, 1.2)
	ci.draw_line(Vector2(0, -57), Vector2(0, -33), trim, 1.2)
	if not nurse:
		_crescent(ci, Vector2(5.2, -52), 3.0, Color("#f4d35e"), main.lerp(shade, 0.4))
	else:
		_crescent(ci, Vector2(5.2, -52), 2.6, Color("#e63946"), Color.WHITE)

	# --- arms over torso (swing opposite to legs) ---
	var arm_l := stride * 4.0
	var arm_r := -stride * 4.0
	_qcurve(ci, Vector2(-8.2, -60), Vector2(-9.8, -48), Vector2(-8.8 + arm_l, -37), shade, 5.2)
	ci.draw_circle(Vector2(-8.8 + arm_l, -36.5), 2.1, skin)
	_qcurve(ci, Vector2(8.2, -60), Vector2(9.8, -48), Vector2(8.8 + arm_r, -37), main, 5.2)
	ci.draw_circle(Vector2(8.8 + arm_r, -36.5), 2.1, skin)

	# --- stethoscope (doctors only) ---
	if not nurse:
		_qcurve(ci, Vector2(-4, -63.5), Vector2(0, -60.5), Vector2(4, -63.5), steth, 1.6)
		ci.draw_polyline(_bez(Vector2(4, -62), Vector2(7, -56), Vector2(7, -50), Vector2(4.5, -46.5)), steth, 1.6)
		ci.draw_polyline(_bez(Vector2(-4, -62), Vector2(-7, -56), Vector2(-7, -50), Vector2(-4.5, -46.5)), steth, 1.6)
		ci.draw_circle(Vector2(4.5, -46), 1.9, disk)
		ci.draw_arc(Vector2(-4.5, -45.5), 2.6, 0, TAU, 14, Color("#8a8f98"), 1.2)

	# --- hair behind the head (gives a clean rim around the scalp) ---
	if female_doctor:
		_ellipse(ci, Vector2(0, -79), 9.6, 10.4, hair)
	elif female:
		_ellipse(ci, Vector2(0, -79.5), 9.3, 10.0, hair)
	else:
		_ellipse(ci, Vector2(0, -79.5), 9.0, 9.8, hair)

	# --- ears, face ---
	_ellipse(ci, Vector2(-8.0, -77.5), 1.6, 2.4, skin)
	_ellipse(ci, Vector2(8.0, -77.5), 1.6, 2.4, skin)
	_ellipse(ci, Vector2(0, -77.5), 7.8, 8.4, skin)

	# --- hairstyle over the face ---
	if female_doctor:
		# bob cut: fringe + side curtains down to the jaw
		_ellipse(ci, Vector2(0, -84.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.8, -82), Vector2(-9.6, -72), Vector2(-8.2, -66),
			Vector2(-5.9, -68), Vector2(-6.8, -76), Vector2(-6.8, -82)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.8, -82), Vector2(9.6, -72), Vector2(8.2, -66),
			Vector2(5.9, -68), Vector2(6.8, -76), Vector2(6.8, -82)]), hair)
	elif female:
		# long hair: fringe + strands flowing over the shoulders
		_ellipse(ci, Vector2(0, -84.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.6, -81), Vector2(-9.8, -70), Vector2(-8.6, -57),
			Vector2(-5.8, -57), Vector2(-6.6, -70), Vector2(-6.7, -79)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.6, -81), Vector2(9.8, -70), Vector2(8.6, -57),
			Vector2(5.8, -57), Vector2(6.6, -70), Vector2(6.7, -79)]), hair)
	else:
		# short crop: soft fringe line
		_ellipse(ci, Vector2(0.6, -84.4), 7.6, 2.6, hair)

	# --- nurse cap (over hair) ---
	if nurse:
		_ellipse(ci, Vector2(0, -86.0), 7.4, 1.9, Color.WHITE)
		_ellipse(ci, Vector2(0, -88.0), 6.4, 3.0, Color.WHITE)
		_crescent(ci, Vector2(0.6, -88.0), 2.1, Color("#e63946"), Color.WHITE)

	# --- facial features (symmetric around x=0) ---
	_ellipse(ci, Vector2(-3.1, -78.2), 2.0, 2.3, Color.WHITE)
	_ellipse(ci, Vector2(3.1, -78.2), 2.0, 2.3, Color.WHITE)
	var iris := Color("#5a351a") if female else Color("#3a2110")
	ci.draw_circle(Vector2(-3.1, -78.0), 1.05, iris)
	ci.draw_circle(Vector2(3.1, -78.0), 1.05, iris)
	ci.draw_circle(Vector2(-3.5, -78.6), 0.35, Color.WHITE)
	ci.draw_circle(Vector2(2.7, -78.6), 0.35, Color.WHITE)
	var brow := Color("#bf8a22") if female and not female_doctor else hair
	_qcurve(ci, Vector2(-4.9, -81.4), Vector2(-3.1, -82.3), Vector2(-1.3, -81.4), brow, 1.0)
	_qcurve(ci, Vector2(1.3, -81.4), Vector2(3.1, -82.3), Vector2(4.9, -81.4), brow, 1.0)
	ci.draw_line(Vector2(0.2, -77.0), Vector2(0.9, -74.8), skin2, 1.0)
	if female:
		_ellipse(ci, Vector2(-5.1, -74.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
		_ellipse(ci, Vector2(5.1, -74.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
	var mouth := Color("#7a1d1d") if dead else (Color("#d64f6f") if female else Color("#7a2e10"))
	if dead:
		ci.draw_line(Vector2(-2.2, -71.4), Vector2(2.2, -71.4), mouth, 1.3)
	else:
		_qcurve(ci, Vector2(-2.4, -72.2), Vector2(0, -70.6), Vector2(2.4, -72.2), mouth, 1.3)

	ci.draw_set_transform_matrix(Transform2D())


# --- helpers ---

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _qcurve(ci: CanvasItem, p0: Vector2, p1: Vector2, p2: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	ci.draw_polyline(pts, col, width)
	ci.draw_circle(p0, width / 2, col)
	ci.draw_circle(p2, width / 2, col)


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return pts


static func _crescent(ci: CanvasItem, c: Vector2, r: float, col: Color, cut: Color) -> void:
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(r * 0.42, -r * 0.08), r * 0.88, cut)
