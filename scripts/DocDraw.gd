extends RefCounted
## Shared character renderer.
## Loaded via: const DocDraw := preload("res://scripts/DocDraw.gd")
##
## Standing / menu / medics  -> front-facing pose (_draw_front)
## Walking (o.t >= 0)         -> right-facing side profile with a real walk
##                               cycle (_draw_side): legs scissor front/back,
##                               arms swing opposite, body in profile.
## Feet rest at y = 0, character is ~92 units tall, symmetric around x = 0.

const SKIN_M := Color("#c9855f")
const SKIN_F := Color("#d79a73")


static func character(ci: CanvasItem, pos: Vector2, avatar: String, o: Dictionary = {}) -> void:
	var female := avatar == "femaleDoctor" or avatar == "femaleNurse"
	var nurse := avatar == "maleNurse" or avatar == "femaleNurse"
	var female_doctor := avatar == "femaleDoctor"
	var p := {
		"female": female, "nurse": nurse, "female_doctor": female_doctor,
		"skin": SKIN_F if female else SKIN_M,
		"skin2": Color("#b86b4d") if female else Color("#9a5538"),
		"hair": Color("#1d1418") if female_doctor else (Color("#2a1712") if female else Color("#2b1a12")),
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
	var sw := sin(t)          # >0: near leg forward, far leg back
	var bob := absf(sin(t)) * 1.4
	ci.draw_set_transform(pos + Vector2(0, -bob) * sc, 0.0, Vector2(sc, sc))

	var skin: Color = p["skin"]
	var hair: Color = p["hair"]
	var main: Color = p["main"]
	var shade: Color = p["shade"]
	var pants: Color = p["pants"]
	var nurse: bool = p["nurse"]
	var female: bool = p["female"]
	var hip := Vector2(0.5, -32.0)

	# far arm (behind torso), swings with far leg (= +sw side up front)
	_arm_side(ci, Vector2(1.5, -59), 9.0 * sw, shade.darkened(0.12), p["skin2"])
	# far leg (behind), foot goes back when near goes forward
	_leg_side(ci, hip, -9.5 * sw, maxf(0.0, -sw) * 4.0, pants.darkened(0.16), Color("#0a0a0d"))

	# torso in profile (chest faces right)
	var lean := 1.5
	var torso := PackedVector2Array([
		Vector2(-4.5 + lean, -62), Vector2(5.0 + lean, -62),
		Vector2(6.0, -47), Vector2(5.2, -33), Vector2(-4.2, -33), Vector2(-5.0, -47)])
	ci.draw_colored_polygon(torso, main)
	# back shading strip
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, -47), Vector2(-4.5 + lean, -62), Vector2(-1.5 + lean, -62),
		Vector2(-1.8, -33), Vector2(-4.2, -33)]), shade)
	if not nurse:
		# coat opening line + button badge on the chest (right side)
		ci.draw_line(Vector2(3.0 + lean, -61), Vector2(4.2, -34), p["trim"], 1.1)
		_crescent(ci, Vector2(4.6, -50), 2.6, Color("#f4d35e"), main.lerp(shade, 0.4))
	else:
		_crescent(ci, Vector2(3.6, -50), 2.4, Color("#e63946"), Color.WHITE)

	# near leg (in front of torso), foot forward when sw>0
	_leg_side(ci, hip, 9.5 * sw, maxf(0.0, sw) * 4.0, pants, Color("#141418"))

	# near arm (front of torso) swings opposite to near leg
	var sleeve: Color = main if not nurse else main
	_arm_side(ci, Vector2(2.5, -59), -9.0 * sw, sleeve, skin)

	# stethoscope hanging on the chest (doctors)
	if not nurse:
		ci.draw_polyline(_bez(Vector2(1.0, -60.5), Vector2(-1.5, -55), Vector2(-1.0, -49), Vector2(1.2, -46)), p["steth"], 1.5)
		ci.draw_polyline(_bez(Vector2(3.5, -60.5), Vector2(5.5, -55), Vector2(5.0, -49), Vector2(3.0, -46)), p["steth"], 1.5)
		ci.draw_circle(Vector2(1.6, -45.5), 1.7, p["disk"])

	_head_side(ci, p)
	ci.draw_set_transform_matrix(Transform2D())


static func _leg_side(ci: CanvasItem, hip: Vector2, foot_x: float, lift: float, col: Color, shoe: Color) -> void:
	var foot := Vector2(hip.x + foot_x, -lift)
	# knee bends forward (+x); shin roughly vertical toward the foot
	var knee := Vector2(hip.x + foot_x * 0.5 + 2.2, (hip.y - lift) * 0.5 - 1.0)
	_qcurve(ci, hip, knee, foot, col, 6.2)
	# shoe points forward (to the right)
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
	var cx := 1.5

	# neck (into the collar and up under the jaw)
	ci.draw_rect(Rect2(cx - 2.4, -70, 4.8, 9.0), skin)

	# hair behind head (back of the skull, biased left)
	_ellipse(ci, Vector2(cx - 1.5, -78), 8.6, 9.2, hair)
	# long hair down the back for females
	if female:
		var back := PackedVector2Array([
			Vector2(cx - 8.5, -82), Vector2(cx - 10.0, -70),
			Vector2(cx - 9.0, -57), Vector2(cx - 5.5, -57),
			Vector2(cx - 5.8, -70), Vector2(cx - 6.5, -80)])
		ci.draw_colored_polygon(back, hair)

	# face (profile, pushed right); nose bump on the right edge
	_ellipse(ci, Vector2(cx + 1.5, -77.5), 7.4, 8.2, skin)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 8.4, -79.0), Vector2(cx + 10.6, -76.8), Vector2(cx + 8.2, -75.2)]), skin)
	# ear
	ci.draw_circle(Vector2(cx - 2.5, -76.5), 1.5, p["skin2"])

	# fringe / top hair over the forehead
	_ellipse(ci, Vector2(cx + 0.5, -84.0), 7.6, 2.8, hair)
	if not female:
		# short side hair down to the ear
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6.8, -83), Vector2(cx - 7.4, -74),
			Vector2(cx - 4.5, -74), Vector2(cx - 4.8, -82)]), hair)

	# nurse cap
	if nurse:
		_ellipse(ci, Vector2(cx, -86.0), 6.8, 1.9, Color.WHITE)
		_ellipse(ci, Vector2(cx - 0.5, -88.0), 5.6, 2.8, Color.WHITE)
		_crescent(ci, Vector2(cx, -88.0), 2.0, Color("#e63946"), Color.WHITE)

	# one eye + brow (facing right)
	_ellipse(ci, Vector2(cx + 4.2, -78.3), 1.7, 2.1, Color.WHITE)
	var iris := Color("#5a351a") if female else Color("#3a2110")
	ci.draw_circle(Vector2(cx + 4.9, -78.1), 1.05, iris)
	ci.draw_circle(Vector2(cx + 4.5, -78.7), 0.35, Color.WHITE)
	var brow := Color("#bf8a22") if female and not female_doctor else hair
	_qcurve(ci, Vector2(cx + 2.6, -81.6), Vector2(cx + 4.4, -82.4), Vector2(cx + 6.2, -81.4), brow, 1.0)
	# mouth just left of the nose
	var mouth := Color("#d64f6f") if female else Color("#7a2e10")
	_qcurve(ci, Vector2(cx + 6.0, -73.2), Vector2(cx + 7.4, -72.6), Vector2(cx + 8.4, -73.4), mouth, 1.2)


# ============================ FRONT POSE (standing) ============================

static func _draw_front(ci: CanvasItem, pos: Vector2, sc: float, p: Dictionary, dead: bool) -> void:
	var female: bool = p["female"]
	var nurse: bool = p["nurse"]
	var female_doctor: bool = p["female_doctor"]
	var skin: Color = p["skin"]
	var skin2: Color = p["skin2"]
	var hair: Color = p["hair"]
	var main: Color = p["main"]
	var shade: Color = p["shade"]
	var trim: Color = p["trim"]
	var pants: Color = p["pants"]

	ci.draw_set_transform(pos, 0.0, Vector2(sc, sc))

	# legs + shoes
	_qcurve(ci, Vector2(3.4, -33), Vector2(4.4, -17), Vector2(5.0, -1.5), pants, 6.2)
	_ellipse(ci, Vector2(6.0, -1), 5.4, 2.5, Color("#101014"))
	_qcurve(ci, Vector2(-3.4, -33), Vector2(-4.4, -17), Vector2(-5.0, -1.5), pants, 6.6)
	_ellipse(ci, Vector2(-6.0, -1), 5.7, 2.7, Color("#050508"))

	# neck
	ci.draw_rect(Rect2(-2.6, -70, 5.2, 8.5), skin)
	ci.draw_rect(Rect2(-2.6, -64, 5.2, 2.0), skin2)

	# torso
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
	_ellipse(ci, Vector2(0, -79 if not female_doctor else -79), 9.3 if not female else 9.5, 10.0 if not female else 10.4, hair)
	# ears + face
	_ellipse(ci, Vector2(-8.0, -77.5), 1.6, 2.4, skin)
	_ellipse(ci, Vector2(8.0, -77.5), 1.6, 2.4, skin)
	_ellipse(ci, Vector2(0, -77.5), 7.8, 8.4, skin)

	# hairstyle over the face
	if female_doctor:
		_ellipse(ci, Vector2(0, -84.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.8, -82), Vector2(-9.6, -72), Vector2(-8.2, -66),
			Vector2(-5.9, -68), Vector2(-6.8, -76), Vector2(-6.8, -82)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.8, -82), Vector2(9.6, -72), Vector2(8.2, -66),
			Vector2(5.9, -68), Vector2(6.8, -76), Vector2(6.8, -82)]), hair)
	elif female:
		_ellipse(ci, Vector2(0, -84.2), 7.9, 3.0, hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-8.6, -81), Vector2(-9.8, -70), Vector2(-8.6, -57),
			Vector2(-5.8, -57), Vector2(-6.6, -70), Vector2(-6.7, -79)]), hair)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(8.6, -81), Vector2(9.8, -70), Vector2(8.6, -57),
			Vector2(5.8, -57), Vector2(6.6, -70), Vector2(6.7, -79)]), hair)
	else:
		_ellipse(ci, Vector2(0.6, -84.4), 7.6, 2.6, hair)

	if nurse:
		_ellipse(ci, Vector2(0, -86.0), 7.4, 1.9, Color.WHITE)
		_ellipse(ci, Vector2(0, -88.0), 6.4, 3.0, Color.WHITE)
		_crescent(ci, Vector2(0.6, -88.0), 2.1, Color("#e63946"), Color.WHITE)

	# face features
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
	if female:
		_ellipse(ci, Vector2(-5.1, -74.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
		_ellipse(ci, Vector2(5.1, -74.4), 1.5, 0.9, Color(0.9, 0.45, 0.45, 0.35))
	var mouth := Color("#7a1d1d") if dead else (Color("#d64f6f") if female else Color("#7a2e10"))
	if dead:
		ci.draw_line(Vector2(-2.2, -71.4), Vector2(2.2, -71.4), mouth, 1.3)
	else:
		_qcurve(ci, Vector2(-2.4, -72.2), Vector2(0, -70.6), Vector2(2.4, -72.2), mouth, 1.3)

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
