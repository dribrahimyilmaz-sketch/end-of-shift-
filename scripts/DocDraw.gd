extends RefCounted
## Shared character renderer.
## Loaded via: const DocDraw := preload("res://scripts/DocDraw.gd")
##
## Standing / menu / medics  -> front-facing pose (_draw_front)
## Walking (o.t >= 0)         -> right-facing side profile with a real walk
##                               cycle (legs scissor, arms swing, nose leads).
## Feet rest at y = 0, head centred near y = -74 (short neck), symmetric.

const SKIN_M := Color("#c9855f")
const SKIN_F := Color("#d79a73")
const HCY := -74.0  # head centre Y (short neck)


static func character(ci: CanvasItem, pos: Vector2, avatar: String, o: Dictionary = {}) -> void:
	var female := avatar == "femaleDoctor" or avatar == "femaleNurse"
	var nurse := avatar == "maleNurse" or avatar == "femaleNurse"
	var female_doctor := avatar == "femaleDoctor"
	var hair: Color = Color("#241a24") if female_doctor else (Color("#2a1712") if female else Color("#241811"))
	var p := {
		"female": female, "nurse": nurse, "female_doctor": female_doctor, "male": not female,
		"skin": SKIN_F if female else SKIN_M,
		"skin2": Color("#b86b4d") if female else Color("#9a5538"),
		"hair": hair,
		"hair_hi": hair.lightened(0.22),
		"main": Color("#23a6a8") if nurse else Color("#f7f8fb"),
		"shade": Color("#157a86") if nurse else Color("#dfe3ea"),
		"trim": Color(1, 1, 1, 0.9) if nurse else Color("#c9ced8"),
		"pants": Color("#12606a") if nurse else Color("#234a84"),
	}
	if o.get("coat", "default") == "mintCoat" and not nurse:
		p["main"] = Color("#dffbf1")
		p["shade"] = Color("#7dd3c7")
	var gold_steth: bool = o.get("steth", "default") == "goldSteth"
	p["steth"] = Color("#f4d35e") if gold_steth else Color("#20344f")
	p["disk"] = Color("#f6c453") if gold_steth else Color("#6b8daf")

	var t: float = o.get("t", -1.0)
	var sc: float = o.get("scale", 1.0) * (0.94 if female else 1.0)
	if t >= 0.0:
		_draw_side(ci, pos, sc, p, t)
	else:
		_draw_front(ci, pos, sc, p, o.get("dead", false))


# ============================ SIDE WALK (faces right) ============================

static func _draw_side(ci: CanvasItem, pos: Vector2, sc: float, p: Dictionary, t: float) -> void:
	var sw := sin(t)
	var bob := absf(sin(t)) * 1.4
	ci.draw_set_transform(pos + Vector2(0, -bob) * sc, 0.0, Vector2(sc, sc))

	var main: Color = p["main"]
	var shade: Color = p["shade"]
	var pants: Color = p["pants"]
	var nurse: bool = p["nurse"]
	var hip := Vector2(0.5, -32.0)

	_arm_side(ci, Vector2(1.5, -59), 9.0 * sw, shade.darkened(0.12), p["skin2"])
	_leg_side(ci, hip, -9.5 * sw, maxf(0.0, -sw) * 4.0, pants.darkened(0.16), Color("#0a0a0d"))

	var lean := 1.5
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-4.5 + lean, -62), Vector2(5.0 + lean, -62),
		Vector2(6.0, -47), Vector2(5.2, -33), Vector2(-4.2, -33), Vector2(-5.0, -47)]), main)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, -47), Vector2(-4.5 + lean, -62), Vector2(-1.5 + lean, -62),
		Vector2(-1.8, -33), Vector2(-4.2, -33)]), shade)
	if not nurse:
		ci.draw_line(Vector2(3.0 + lean, -61), Vector2(4.2, -34), p["trim"], 1.1)
		_crescent(ci, Vector2(4.6, -50), 2.6, Color("#f4d35e"), main.lerp(shade, 0.4))
	else:
		_crescent(ci, Vector2(3.6, -50), 2.4, Color("#e63946"), Color.WHITE)

	_leg_side(ci, hip, 9.5 * sw, maxf(0.0, sw) * 4.0, pants, Color("#141418"))
	_arm_side(ci, Vector2(2.5, -59), -9.0 * sw, main, p["skin"])

	if not nurse:
		ci.draw_polyline(_bez(Vector2(1.0, -60.5), Vector2(-1.5, -55), Vector2(-1.0, -49), Vector2(1.2, -46)), p["steth"], 1.5)
		ci.draw_polyline(_bez(Vector2(3.5, -60.5), Vector2(5.5, -55), Vector2(5.0, -49), Vector2(3.0, -46)), p["steth"], 1.5)
		ci.draw_circle(Vector2(1.6, -45.5), 1.7, p["disk"])

	_head_side(ci, p)
	ci.draw_set_transform_matrix(Transform2D())


static func _leg_side(ci: CanvasItem, hip: Vector2, foot_x: float, lift: float, col: Color, shoe: Color) -> void:
	var foot := Vector2(hip.x + foot_x, -lift)
	var knee := Vector2(hip.x + foot_x * 0.5 + 2.2, (hip.y - lift) * 0.5 - 1.0)
	_qcurve(ci, hip, knee, foot, col, 6.2)
	_ellipse(ci, foot + Vector2(2.2, 0.2), 4.8, 2.3, shoe)


static func _arm_side(ci: CanvasItem, shoulder: Vector2, hand_x: float, sleeve: Color, skin: Color) -> void:
	var hand := Vector2(shoulder.x + hand_x, -36.5)
	var elbow := Vector2(shoulder.x + hand_x * 0.45 + 0.5, -48.0)
	_qcurve(ci, shoulder, elbow, hand, sleeve, 5.0)
	ci.draw_circle(hand, 2.1, skin)


static func _head_side(ci: CanvasItem, p: Dictionary) -> void:
	var skin: Color = p["skin"]
	var hair: Color = p["hair"]
	var female: bool = p["female"]
	var female_doctor: bool = p["female_doctor"]
	var nurse: bool = p["nurse"]
	var male: bool = p["male"]
	var cx := 1.5
	var cy := HCY

	# short neck (into collar, under jaw)
	ci.draw_rect(Rect2(cx - 2.3, cy + 6.5, 4.6, 7.5), skin)

	# hair behind the skull
	_ellipse(ci, Vector2(cx - 1.6, cy - 1.4), 8.4, 8.9, hair)
	if female:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 8.3, cy - 4), Vector2(cx - 9.6, cy + 8),
			Vector2(cx - 8.6, cy + 21), Vector2(cx - 5.2, cy + 21),
			Vector2(cx - 5.6, cy + 8), Vector2(cx - 6.3, cy - 2)]), hair)

	# face (profile) + nose bump on the right
	_ellipse(ci, Vector2(cx + 1.6, cy), 7.2, 7.9, skin)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 8.3, cy - 1.2), Vector2(cx + 10.4, cy + 1.0), Vector2(cx + 8.1, cy + 2.6)]), skin)
	ci.draw_circle(Vector2(cx - 2.4, cy + 1.2), 1.4, p["skin2"])  # ear

	# light beard / stubble for males (jaw + sideburn + moustache)
	if male:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 4.5, cy + 2), Vector2(cx + 6.5, cy + 3.5),
			Vector2(cx + 7.6, cy + 6.0), Vector2(cx + 4.0, cy + 8.4),
			Vector2(cx - 3.0, cy + 7.6), Vector2(cx - 5.0, cy + 5)]), Color(hair, 0.30))
		_qcurve(ci, Vector2(cx + 4.4, cy + 4.4), Vector2(cx + 6.2, cy + 4.0), Vector2(cx + 7.8, cy + 4.6), Color(hair, 0.5), 1.4)

	# hairline / top hair
	_ellipse(ci, Vector2(cx + 0.4, cy - 6.3), 7.4, 2.9, hair)
	_ellipse(ci, Vector2(cx - 2.0, cy - 6.8), 3.0, 1.2, Color(p["hair_hi"], 0.6))
	if male:
		# sideburn down to the ear
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6.6, cy - 5), Vector2(cx - 7.0, cy + 2),
			Vector2(cx - 4.4, cy + 2), Vector2(cx - 4.6, cy - 4)]), hair)

	if nurse:
		_ellipse(ci, Vector2(cx, cy - 8.0), 6.6, 1.9, Color.WHITE)
		_ellipse(ci, Vector2(cx - 0.5, cy - 10.0), 5.4, 2.7, Color.WHITE)
		_crescent(ci, Vector2(cx, cy - 10.0), 2.0, Color("#e63946"), Color.WHITE)

	# one eye + brow facing right
	_ellipse(ci, Vector2(cx + 4.2, cy - 0.3), 1.7, 2.0, Color.WHITE)
	var iris := Color("#5a351a") if female else Color("#3a2110")
	ci.draw_circle(Vector2(cx + 4.9, cy - 0.1), 1.05, iris)
	ci.draw_circle(Vector2(cx + 4.5, cy - 0.7), 0.32, Color.WHITE)
	var brow := Color("#bf8a22") if female and not female_doctor else hair
	_qcurve(ci, Vector2(cx + 2.6, cy - 3.6), Vector2(cx + 4.4, cy - 4.3), Vector2(cx + 6.2, cy - 3.4), brow, 1.1)
	var mouth := Color("#d64f6f") if female else Color("#7a2e10")
	_qcurve(ci, Vector2(cx + 6.0, cy + 4.6), Vector2(cx + 7.3, cy + 5.1), Vector2(cx + 8.3, cy + 4.4), mouth, 1.2)


# ============================ FRONT POSE (standing) ============================

static func _draw_front(ci: CanvasItem, pos: Vector2, sc: float, p: Dictionary, dead: bool) -> void:
	var female: bool = p["female"]
	var nurse: bool = p["nurse"]
	var female_doctor: bool = p["female_doctor"]
	var male: bool = p["male"]
	var skin: Color = p["skin"]
	var skin2: Color = p["skin2"]
	var hair: Color = p["hair"]
	var main: Color = p["main"]
	var shade: Color = p["shade"]
	var trim: Color = p["trim"]
	var pants: Color = p["pants"]
	var cy := HCY

	ci.draw_set_transform(pos, 0.0, Vector2(sc, sc))

	# legs + shoes
	_qcurve(ci, Vector2(3.4, -33), Vector2(4.4, -17), Vector2(5.0, -1.5), pants, 6.2)
	_ellipse(ci, Vector2(6.0, -1), 5.4, 2.5, Color("#101014"))
	_qcurve(ci, Vector2(-3.4, -33), Vector2(-4.4, -17), Vector2(-5.0, -1.5), pants, 6.6)
	_ellipse(ci, Vector2(-6.0, -1), 5.7, 2.7, Color("#050508"))

	# short neck
	ci.draw_rect(Rect2(-2.3, cy + 6, 4.6, 8.0), skin)
	ci.draw_rect(Rect2(-2.3, cy + 7.4, 4.6, 1.6), skin2)

	# torso
	ci.draw_polygon(PackedVector2Array([
		Vector2(-10.2, -63), Vector2(10.2, -63), Vector2(9.2, -47),
		Vector2(8.6, -32), Vector2(-8.6, -32), Vector2(-9.2, -47)]),
		PackedColorArray([main, main, main.lerp(shade, 0.55), shade, shade, main.lerp(shade, 0.55)]))
	ci.draw_line(Vector2(-4, -63), Vector2(0, -57), trim, 1.2)
	ci.draw_line(Vector2(0, -57), Vector2(4, -63), trim, 1.2)
	ci.draw_line(Vector2(0, -57), Vector2(0, -33), trim, 1.2)
	if not nurse:
		_crescent(ci, Vector2(5.2, -52), 3.0, Color("#f4d35e"), main.lerp(shade, 0.4))
	else:
		_crescent(ci, Vector2(5.2, -52), 2.6, Color("#e63946"), Color.WHITE)

	# arms
	_qcurve(ci, Vector2(-8.2, -60), Vector2(-9.8, -48), Vector2(-8.8, -37), shade, 5.2)
	ci.draw_circle(Vector2(-8.8, -36.5), 2.1, skin)
	_qcurve(ci, Vector2(8.2, -60), Vector2(9.8, -48), Vector2(8.8, -37), main, 5.2)
	ci.draw_circle(Vector2(8.8, -36.5), 2.1, skin)

	# stethoscope
	if not nurse:
		_qcurve(ci, Vector2(-4, -63.5), Vector2(0, -60.5), Vector2(4, -63.5), p["steth"], 1.6)
		ci.draw_polyline(_bez(Vector2(4, -62), Vector2(7, -56), Vector2(7, -50), Vector2(4.5, -46.5)), p["steth"], 1.6)
		ci.draw_polyline(_bez(Vector2(-4, -62), Vector2(-7, -56), Vector2(-7, -50), Vector2(-4.5, -46.5)), p["steth"], 1.6)
		ci.draw_circle(Vector2(4.5, -46), 1.9, p["disk"])
		ci.draw_arc(Vector2(-4.5, -45.5), 2.6, 0, TAU, 14, Color("#8a8f98"), 1.2)

	# hair behind
	_ellipse(ci, Vector2(0, cy - 1.6), 9.1, 9.4, hair)
	# ears + face
	_ellipse(ci, Vector2(-7.8, cy + 0.4), 1.6, 2.3, skin)
	_ellipse(ci, Vector2(7.8, cy + 0.4), 1.6, 2.3, skin)
	_ellipse(ci, Vector2(0, cy), 7.7, 8.1, skin)

	# light beard / stubble for males
	if male:
		_ellipse(ci, Vector2(0, cy + 4.6), 6.9, 3.7, Color(hair, 0.26))
		# moustache hint
		_qcurve(ci, Vector2(-2.4, cy + 4.8), Vector2(0, cy + 4.2), Vector2(2.4, cy + 4.8), Color(hair, 0.5), 1.5)

	# hairstyle over the forehead
	if female_doctor:
		_ellipse(ci, Vector2(0, cy - 6.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.8, cy - 4), Vector2(-9.6, cy + 6), Vector2(-8.2, cy + 12),
			Vector2(-5.9, cy + 10), Vector2(-6.8, cy + 2), Vector2(-6.8, cy - 4)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.8, cy - 4), Vector2(9.6, cy + 6), Vector2(8.2, cy + 12),
			Vector2(5.9, cy + 10), Vector2(6.8, cy + 2), Vector2(6.8, cy - 4)]), hair)
		_ellipse(ci, Vector2(-2.6, cy - 6.6), 3.4, 1.3, Color(p["hair_hi"], 0.55))
	elif female:
		_ellipse(ci, Vector2(0, cy - 6.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.6, cy - 3), Vector2(-9.8, cy + 8), Vector2(-8.6, cy + 21),
			Vector2(-5.8, cy + 21), Vector2(-6.6, cy + 8), Vector2(-6.7, cy - 1)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.6, cy - 3), Vector2(9.8, cy + 8), Vector2(8.6, cy + 21),
			Vector2(5.8, cy + 21), Vector2(6.6, cy + 8), Vector2(6.7, cy - 1)]), hair)
		_ellipse(ci, Vector2(-2.6, cy - 6.6), 3.4, 1.3, Color(p["hair_hi"], 0.55))
	else:
		# short male crop: hairline + sideburns + highlight
		_ellipse(ci, Vector2(0.3, cy - 6.4), 7.7, 2.9, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-7.5, cy - 5), Vector2(-8.0, cy + 1.5), Vector2(-6.2, cy + 1.5), Vector2(-6.0, cy - 4.5)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(7.5, cy - 5), Vector2(8.0, cy + 1.5), Vector2(6.2, cy + 1.5), Vector2(6.0, cy - 4.5)]), hair)
		_ellipse(ci, Vector2(-2.4, cy - 6.8), 3.2, 1.2, Color(p["hair_hi"], 0.6))

	if nurse:
		_ellipse(ci, Vector2(0, cy - 8.0), 7.4, 1.9, Color.WHITE)
		_ellipse(ci, Vector2(0, cy - 10.0), 6.4, 3.0, Color.WHITE)
		_crescent(ci, Vector2(0.6, cy - 10.0), 2.1, Color("#e63946"), Color.WHITE)

	# face features
	_ellipse(ci, Vector2(-3.0, cy - 1.2), 1.9, 2.2, Color.WHITE)
	_ellipse(ci, Vector2(3.0, cy - 1.2), 1.9, 2.2, Color.WHITE)
	var iris := Color("#5a351a") if female else Color("#3a2110")
	ci.draw_circle(Vector2(-3.0, cy - 1.0), 1.05, iris)
	ci.draw_circle(Vector2(3.0, cy - 1.0), 1.05, iris)
	ci.draw_circle(Vector2(-3.4, cy - 1.6), 0.32, Color.WHITE)
	ci.draw_circle(Vector2(2.6, cy - 1.6), 0.32, Color.WHITE)
	var brow := Color("#bf8a22") if female and not female_doctor else hair
	_qcurve(ci, Vector2(-4.8, cy - 4.2), Vector2(-3.0, cy - 5.1), Vector2(-1.3, cy - 4.2), brow, 1.1)
	_qcurve(ci, Vector2(1.3, cy - 4.2), Vector2(3.0, cy - 5.1), Vector2(4.8, cy - 4.2), brow, 1.1)
	ci.draw_line(Vector2(0.2, cy + 1.0), Vector2(0.9, cy + 3.0), skin2, 1.0)
	if female:
		_ellipse(ci, Vector2(-5.0, cy + 3.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
		_ellipse(ci, Vector2(5.0, cy + 3.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
	var mouth := Color("#7a1d1d") if dead else (Color("#d64f6f") if female else Color("#7a2e10"))
	if dead:
		ci.draw_line(Vector2(-2.2, cy + 6.4), Vector2(2.2, cy + 6.4), mouth, 1.3)
	else:
		_qcurve(ci, Vector2(-2.4, cy + 5.8), Vector2(0, cy + 7.4), Vector2(2.4, cy + 5.8), mouth, 1.3)

	ci.draw_set_transform_matrix(Transform2D())


# ============================ helpers ============================

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
