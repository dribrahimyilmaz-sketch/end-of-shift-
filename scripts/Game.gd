extends Node2D
## End of Shift — GDScript port of the HTML5 canvas game.
## One node draws the whole game each frame (like the original canvas loop).

const DocDraw := preload("res://scripts/DocDraw.gd")

const SKIES_HEX := {
	"dawn": ["#1a0533", "#6b2d6b", "#f4845f", "#ffd166"],
	"morning": ["#3a7bd5", "#63b3ed", "#bee3f8", "#e8f4fd"],
	"noon": ["#1a6fc4", "#2980b9", "#5dade2", "#aed6f1"],
	"dusk": ["#0d0221", "#4a1942", "#c0392b", "#e67e22"],
	"night": ["#0d0b1e", "#0d0b1e", "#1a1a3e", "#1a1a3e"],
}
const GND_HEX := {
	"dawn": ["#2d1b4e", "#1a0e2e"],
	"morning": ["#2d4a7a", "#19283f"],
	"noon": ["#1e5ba8", "#0d2d5e"],
	"dusk": ["#4a1942", "#1a0a2e"],
	"night": ["#1a1a3e", "#060408"],
}
const TLIST := ["morning", "noon", "dusk", "night", "dawn"]
const WLIST := ["clear", "clear", "cloudy", "rainy", "snowy"]

const GOLD := Color("#e9c46a")
const GREEN := Color("#4ade80")
const RED := Color("#e63946")

var F: Font = ThemeDB.fallback_font

var w := 800.0
var h := 550.0
var gr := 357.0

# Game state
var scn := ""  # "", HOSPITAL, WALKOUT, GAME, HOUSEIN, DUEL, FLASH
var state := ""
var score := 0
var lives := 3
var combo := 0
var cam_x := 0.0
var t_cam_x := 0.0
var stick_len := 0.0
var stick_ang := 0.0
var plats: Array = []
var ci := 0
var pl := {"x": 0.0, "y": 0.0, "vy": 0.0}
var floats: Array = []
var elapsed := 0.0
var gtimer := 0.0
var perf := false
var lvl := 1
var lp := 0
var pc := 0
var sky_a := "morning"
var sky_b := "morning"
var sky_t := 1.0
var clouds: Array = []
var rain: Array = []
var snow: Array = []
var gone := false
var pressing := false
var scene_t := 0.0
var intro_doc_x := 0.0
var burst_wx := 0.0
var burst_y := 0.0
var burst_t := 0.0
var leaderboard: Array = []
var show_leaderboard := false
var admin_start_level := 1

var _skies := {}
var _gnd := {}

@onready var menu: Control = $UI/Menu


func _ready() -> void:
	for k in SKIES_HEX:
		var arr: Array = []
		for c in SKIES_HEX[k]:
			arr.append(Color(c))
		_skies[k] = arr
	for k in GND_HEX:
		var arr: Array = []
		for c in GND_HEX[k]:
			arr.append(Color(c))
		_gnd[k] = arr
	var t := Timer.new()
	t.wait_time = 15.0
	t.autostart = true
	t.timeout.connect(_ping_active)
	add_child(t)


func _ping_active() -> void:
	if Meta.player_name != "" and not Meta.is_admin():
		SB.ping_active(Meta.player_name, Meta.session_id)


func refresh_leaderboard() -> void:
	var room := Meta.current_room
	var data: Array = await SB.get_leaderboard(room)
	leaderboard = data


func open_leaderboard() -> void:
	show_leaderboard = true
	leaderboard = await SB.get_leaderboard(Meta.current_room)


func back_to_menu() -> void:
	scn = ""
	pressing = false
	menu.open_menu()


func is_admin() -> bool:
	return Meta.is_admin()


# --- Difficulty / platforms ---

func diff() -> float:
	return minf((lvl - 1 + lp / 10.0) / 8.0, 1.0)


func gspd() -> float: return 240 + diff() * 120
func fspd() -> float: return 180 + diff() * 120
func wspd() -> float: return 180 + diff() * 220


func mk_plat(ax: float, last: bool) -> Dictionary:
	var d := diff()
	var gap := 65 + d * 70 + randf() * (75 - d * 35)
	pc += 1
	var wid: float
	if pc % (2 + randi() % 2) == 0:
		var r := randf()
		if r < 0.25: wid = 14 + randf() * 10
		elif r < 0.55: wid = 26 + randf() * 18
		elif r < 0.8: wid = 44 + randf() * 28
		else: wid = 72 + randf() * 38
		wid = maxf(14.0, wid - d * 28)
	else:
		wid = maxf(14.0, 110 - d * 68 + (randf() - 0.3) * 28)
	return {"x": ax + gap, "w": wid, "last": last}


func build_lvl() -> void:
	var l: Dictionary = plats[plats.size() - 1]
	var x: float = l["x"] + l["w"]
	for i in 10:
		plats.append(mk_plat(x, i == 9))
		x = plats[plats.size() - 1]["x"] + plats[plats.size() - 1]["w"]


func mk_clouds() -> void:
	clouds = []
	for i in 6:
		clouds.append({"wx": randf() * 2000.0, "wy": 30 + randf() * gr * 0.4,
			"spd": 15 + randf() * 20, "w": 60 + randf() * 80, "a": 0.5 + randf() * 0.4})


func mk_rain() -> void:
	rain = []
	for i in 100:
		rain.append({"x": randf() * w, "y": randf() * gr, "spd": 400 + randf() * 200, "l": 10 + randf() * 10})


func mk_snow() -> void:
	snow = []
	for i in 70:
		snow.append({"x": randf() * w, "y": randf() * gr, "r": 1.5 + randf() * 2,
			"spd": 40 + randf() * 55, "dr": (randf() - 0.5) * 18})


func start_game(start_lvl: int = 1) -> void:
	Meta.reset_daily_if_needed()
	refresh_leaderboard()
	scn = "HOSPITAL"
	scene_t = 0.0
	intro_doc_x = 0.0
	state = "WAITING"
	score = 0
	lives = 3
	combo = 0
	cam_x = 0.0
	t_cam_x = 0.0
	elapsed = 0.0
	gtimer = 0.0
	perf = false
	pressing = false
	stick_len = 0.0
	stick_ang = 0.0
	gone = false
	floats = []
	lvl = clampi(start_lvl, 1, 99)
	lp = 0
	pc = 0
	burst_t = 0.0
	sky_a = TLIST[lvl % TLIST.size()]
	sky_b = sky_a
	sky_t = 1.0
	plats = [{"x": 40.0, "w": 130.0, "last": false}]
	build_lvl()
	ci = 0
	var p0: Dictionary = plats[0]
	pl = {"x": p0["x"] + p0["w"] - 24.0, "y": gr, "vy": 0.0}
	mk_clouds()
	mk_rain()
	mk_snow()


# --- Helpers ---

func scx(wx: float) -> float:
	return wx - cam_x


func piv_x() -> float:
	return plats[ci]["x"] + plats[ci]["w"]


func end_x() -> float:
	return piv_x() + stick_len * sin(deg_to_rad(stick_ang))


func quality() -> String:
	var ex := end_x()
	if ci + 1 >= plats.size():
		return "miss"
	var np: Dictionary = plats[ci + 1]
	if ex < np["x"] or ex > np["x"] + np["w"]:
		return "miss"
	return "perf" if absf(ex - (np["x"] + np["w"] / 2.0)) < np["w"] / 6.0 else "good"


func add_float(t: String, wx: float, wy: float, col: Color) -> void:
	floats.append({"txt": t, "wx": wx, "y": wy, "col": col, "life": 1.1})


func update_badges() -> void:
	if score > 0: Meta.unlock_badge("First Shift")
	if combo >= 10: Meta.unlock_badge("Perfect 10")
	if lvl >= 20: Meta.unlock_badge("Level 20 Doctor")
	if sky_a == "night" or sky_b == "night": Meta.unlock_badge("Night Survivor")


func share_challenge() -> void:
	if Meta.current_room == "":
		var code := "SHIFT" + _rand_code(4)
		Meta.set_room(code)
		Meta.remember_room(code, "My Shift Room")
	var text := "I scored %d in End of Shift. Can you beat me? Room code: %s" % [score, Meta.current_room]
	DisplayServer.clipboard_set(text)
	add_float("Challenge copied!", pl["x"], gr - 90, GREEN)


func _rand_code(n: int) -> String:
	const CH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	for i in n:
		out += CH[randi() % CH.length()]
	return out


# --- Update loop ---

func _process(dt: float) -> void:
	var vs := get_viewport_rect().size
	w = vs.x
	h = vs.y
	gr = floorf(h * 0.65)
	_update(minf(dt, 0.1))
	queue_redraw()


func _update(dt: float) -> void:
	if scn == "":
		return
	if scn == "HOSPITAL":
		scene_t += dt
		return
	if scn == "WALKOUT":
		scene_t += dt
		intro_doc_x += 150 * dt
		if scene_t > 1.8:
			scn = "GAME"
		return
	if scn == "HOUSEIN":
		scene_t += dt
		if scene_t > 1.5:
			scn = "DUEL" if lvl == 10 else "FLASH"
			scene_t = 0.0
		return
	if scn == "DUEL":
		scene_t += dt
		if scene_t > 10.0:
			scn = "FLASH"
			scene_t = 0.0
		return
	if scn == "FLASH":
		scene_t += dt
		if scene_t > 0.8:
			lp = 0
			var next_lvl := lvl + 1
			if next_lvl >= 4:
				lives += 1
			Meta.daily["levels"] = int(Meta.daily.get("levels", 0)) + 1
			Meta.daily["bestLevel"] = maxi(int(Meta.daily.get("bestLevel", 1)), next_lvl)
			lvl = next_lvl
			update_badges()
			Meta.save()
			Sfx.lvl()
			sky_b = TLIST[lvl % TLIST.size()]
			sky_t = 0.0
			build_lvl()
			gone = false
			stick_len = 0.0
			stick_ang = 0.0
			scn = "GAME"
			state = "WAITING"
		return

	elapsed += dt
	sky_t = minf(1.0, sky_t + dt * 0.4)
	if sky_t >= 1.0:
		sky_a = sky_b
	var wth: String = WLIST[lvl % WLIST.size()]
	for c in clouds:
		c["wx"] += c["spd"] * dt
		if c["wx"] - cam_x * 0.3 > w + 100:
			c["wx"] -= w + 300
	if wth == "rainy":
		for r in rain:
			r["y"] += r["spd"] * dt
			r["x"] += 40 * dt
			if r["y"] > gr:
				r["y"] = -10
				r["x"] = randf() * w
	if wth == "snowy":
		for s in snow:
			s["y"] += s["spd"] * dt
			s["x"] += s["dr"] * dt
			if s["y"] > gr:
				s["y"] = -5
				s["x"] = randf() * w

	if state == "GROWING":
		stick_len += gspd() * dt
		gtimer += dt
		if gtimer > 0.067:
			Sfx.grow()
			gtimer = 0.0
	if state == "FALLING":
		stick_ang += fspd() * dt
		if stick_ang >= 90.0:
			stick_ang = 90.0
			Sfx.fall()
			var q := quality()
			if q == "miss":
				combo = 0
				state = "DEAD"
			else:
				state = "WALKING"
				gone = false
				if q == "perf":
					perf = true
					combo += 1
					Meta.daily["perfects"] = int(Meta.daily.get("perfects", 0)) + 1
					Meta.save()
					Sfx.perfect()
					add_float("PERFECT x%d!" % combo if combo > 1 else "PERFECT!", end_x(), gr - 60, Color("#f4e04d"))
				else:
					combo = 0
					Sfx.land()
			pl["vy"] = 0.0
	if state == "WALKING":
		pl["x"] += wspd() * dt
		if ci + 1 >= plats.size():
			state = "WAITING"
			return
		var np: Dictionary = plats[ci + 1]
		if pl["x"] >= np["x"] + np["w"] - 24:
			pl["x"] = np["x"] + np["w"] - 24
			ci += 1
			gone = true
			stick_len = 0.0
			stick_ang = 0.0
			var wp := perf
			var pts := (1 + mini(combo, 5)) if wp else 1
			score += pts
			perf = false
			Sfx.score()
			Meta.save_hi(score)
			update_badges()
			add_float("+%d COMBO" % pts if wp and combo > 1 else "+%d" % pts, pl["x"] + 12, pl["y"] - 60, GOLD)
			lp += 1
			if lp >= 10:
				scn = "HOUSEIN"
				scene_t = 0.0
				intro_doc_x = scx(pl["x"]) + 12
				return
			if lp == 5:
				var idx := TLIST.find(sky_a)
				sky_b = TLIST[(idx + 1) % TLIST.size()]
				sky_t = 0.0
			while plats.size() <= ci + 6:
				var l: Dictionary = plats[plats.size() - 1]
				plats.append(mk_plat(l["x"] + l["w"], false))
			gone = false
			gtimer = 0.0
			state = "GROWING" if pressing else "WAITING"
	if state == "WAITING" or state == "GROWING" or state == "FALLING":
		var p: Dictionary = plats[ci]
		t_cam_x = maxf(0.0, p["x"] + p["w"] - w * 0.35)
		cam_x += (t_cam_x - cam_x) * (1.0 - pow(1.0 - 0.08, dt * 60.0))
	if state == "DEAD":
		pl["vy"] += 2160 * dt
		pl["y"] += pl["vy"] * dt
		pl["x"] += 120 * dt
		if is_admin() and pl["y"] > h + 80:
			Sfx.fail()
			Meta.save_hi(score)
			var ni := mini(ci + 1, plats.size() - 1)
			var p: Dictionary = plats[ni] if ni < plats.size() else plats[ci]
			ci = ni
			pl["x"] = p["x"] + p["w"] - 24
			pl["y"] = gr
			pl["vy"] = 0.0
			cam_x = maxf(0.0, p["x"] + p["w"] - w * 0.35)
			t_cam_x = cam_x
			stick_len = 0.0
			stick_ang = 0.0
			gone = false
			gtimer = 0.0
			pressing = false
			state = "WAITING"
			return
		if not is_admin() and pl["y"] >= h - 24:
			burst_wx = pl["x"]
			burst_y = h - 24
			burst_t = 0.0
			state = "BURST"
			Sfx.fail()
			Meta.save_hi(score)
			return
	if state == "BURST":
		burst_t += dt
		if burst_t > 1.5:
			lives -= 1
			Sfx.fail()
			Meta.save_hi(score)
			if lives <= 0:
				state = "GAME_OVER"
				if score > 0 and not is_admin():
					Meta.add_coins(score)
				update_badges()
				_game_over_net()
			else:
				lp = 0
				var si := (lvl - 1) * 10
				ci = clampi(si, 0, plats.size() - 1)
				var p: Dictionary = plats[ci]
				pl["x"] = p["x"] + p["w"] - 24
				pl["y"] = gr
				pl["vy"] = 0.0
				cam_x = maxf(0.0, p["x"] + p["w"] - w * 0.35)
				t_cam_x = cam_x
				stick_len = 0.0
				stick_ang = 0.0
				gone = false
				state = "WAITING"
	for f in floats:
		f["y"] -= 55 * dt
		f["life"] -= dt
	floats = floats.filter(func(f): return f["life"] > 0)


func _game_over_net() -> void:
	if Meta.player_name != "" and score > 0:
		await SB.save_score(Meta.player_name, score, lvl, Meta.current_room)
	leaderboard = await SB.get_leaderboard(Meta.current_room)


# --- Input ---

func _unhandled_input(e: InputEvent) -> void:
	if menu.visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_on_s(e.position)
		else:
			_on_e()
	elif e is InputEventKey and (e.keycode == KEY_SPACE or e.keycode == KEY_RIGHT):
		if e.pressed and not e.echo:
			_on_s(Vector2(-99999, -99999))
		elif not e.pressed:
			_on_e()


func _on_s(p: Vector2) -> void:
	var cx2 := p.x
	var cy2 := p.y
	if show_leaderboard:
		var bw := 140.0
		var bx := w / 2 - bw / 2
		var by := h - 60.0
		if cx2 > bx and cx2 < bx + bw and cy2 > by and cy2 < by + 36:
			show_leaderboard = false
			if scn == "":
				menu.open_menu()
		return
	if scn == "HOSPITAL" and cx2 > w - 50 and cx2 < w - 14 and cy2 > 54 and cy2 < 84:
		back_to_menu()
		return
	if scn == "HOSPITAL" and is_admin():
		var px := w - 154.0
		var py := gr * 0.54
		if cx2 > px + 12 and cx2 < px + 42 and cy2 > py + 30 and cy2 < py + 60:
			admin_start_level = maxi(1, admin_start_level - 1)
			return
		if cx2 > px + 92 and cx2 < px + 122 and cy2 > py + 30 and cy2 < py + 60:
			admin_start_level = mini(99, admin_start_level + 1)
			return
	var re_x := 90.0 if w < 520 else 108.0
	if scn == "GAME" and state != "GAME_OVER" and cx2 > re_x and cx2 < re_x + 30 and cy2 > 14 and cy2 < 44:
		start_game(admin_start_level)
		return
	if scn == "HOSPITAL":
		if is_admin() and lvl != admin_start_level:
			start_game(admin_start_level)
		scn = "WALKOUT"
		scene_t = 0.0
		intro_doc_x = 80.0
		return
	if scn == "WALKOUT" or scn == "HOUSEIN" or scn == "DUEL" or scn == "FLASH":
		return
	if state == "GAME_OVER":
		var oy := h / 2 - 150.0
		if cx2 > w / 2 - 80 and cx2 < w / 2 + 80 and cy2 > oy + 178 and cy2 < oy + 214:
			open_leaderboard()
			return
		if cx2 > w / 2 - 90 and cx2 < w / 2 + 90 and cy2 > oy + 222 and cy2 < oy + 256:
			share_challenge()
			return
		start_game()
		return
	if state == "BURST":
		return
	if state == "WAITING" and not pressing:
		pressing = true
		state = "GROWING"
	else:
		pressing = true


func _on_e() -> void:
	pressing = false
	if state == "GROWING":
		gtimer = 0.0
		state = "FALLING"


# ============================ DRAWING ============================

func vgrad(r: Rect2, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var y1: float = r.position.y + r.size.y * stops[i][0]
		var y2: float = r.position.y + r.size.y * stops[i + 1][0]
		var c1: Color = stops[i][1]
		var c2: Color = stops[i + 1][1]
		draw_polygon(PackedVector2Array([Vector2(r.position.x, y1), Vector2(r.end.x, y1),
			Vector2(r.end.x, y2), Vector2(r.position.x, y2)]),
			PackedColorArray([c1, c1, c2, c2]))


func hgrad(r: Rect2, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var x1: float = r.position.x + r.size.x * stops[i][0]
		var x2: float = r.position.x + r.size.x * stops[i + 1][0]
		var c1: Color = stops[i][1]
		var c2: Color = stops[i + 1][1]
		draw_polygon(PackedVector2Array([Vector2(x1, r.position.y), Vector2(x2, r.position.y),
			Vector2(x2, r.end.y), Vector2(x1, r.end.y)]),
			PackedColorArray([c1, c2, c2, c1]))


func rrect(r: Rect2, rad: float, fill: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(rad))
	sb.draw(get_canvas_item(), r)


func rrect_line(r: Rect2, rad: float, col: Color, width: float = 1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(int(rad))
	sb.border_color = col
	sb.set_border_width_all(int(ceilf(width)))
	sb.draw(get_canvas_item(), r)


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func txt_c(s: String, x: float, y: float, size: int, col: Color) -> void:
	draw_string(F, Vector2(x - 600, y), s, HORIZONTAL_ALIGNMENT_CENTER, 1200, size, col)


func txt_l(s: String, x: float, y: float, size: int, col: Color) -> void:
	draw_string(F, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func txt_r(s: String, x: float, y: float, size: int, col: Color) -> void:
	draw_string(F, Vector2(x - 1200, y), s, HORIZONTAL_ALIGNMENT_RIGHT, 1200, size, col)


func txt_w(s: String, size: int) -> float:
	return F.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func qcurve(p0: Vector2, p1: Vector2, p2: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	draw_polyline(pts, col, width)
	draw_circle(p0, width / 2, col)
	draw_circle(p2, width / 2, col)


func bcurve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return pts


func draw_heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.35, -s * 0.2), s * 0.42, col)
	draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.42, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.74, 0.0), c + Vector2(s * 0.74, 0.0), c + Vector2(0, s * 0.8)]), col)


func draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, col)


func crescent(c: Vector2, r: float, col: Color, cut: Color) -> void:
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.42, -r * 0.08), r * 0.88, cut)


func _draw() -> void:
	if show_leaderboard:
		draw_leaderboard_full()
		return
	if scn == "":
		return
	if scn == "HOSPITAL":
		draw_hospital(scene_t)
		return
	if scn == "WALKOUT":
		draw_walkout(scene_t)
		return
	if scn == "HOUSEIN":
		draw_house_in(scene_t)
		return
	if scn == "DUEL":
		draw_duel(scene_t)
		return
	if scn == "FLASH":
		draw_flash(scene_t)
		return
	draw_bg()
	draw_plats()
	draw_stick()
	draw_trail()
	if state == "BURST":
		draw_burst()
	else:
		var dx := scx(pl["x"]) + (-8.0 if state == "WAITING" or state == "GROWING" else 12.0)
		draw_doc(dx, pl["y"] if state == "DEAD" else gr, state == "WALKING", state == "DEAD")
	draw_hud()
	draw_hint()
	draw_go()
	draw_floats()  # after the game-over panel so "Challenge copied!" stays visible


func sky_cols() -> Array:
	var a: Array = _skies[sky_a]
	var b: Array = _skies[sky_b]
	var out: Array = []
	for i in 4:
		out.append((a[i] as Color).lerp(b[i], sky_t))
	return out


func gnd_cols() -> Array:
	var a: Array = _gnd[sky_a]
	var b: Array = _gnd[sky_b]
	return [(a[0] as Color).lerp(b[0], sky_t), (a[1] as Color).lerp(b[1], sky_t)]


func draw_bg() -> void:
	var sc := sky_cols()
	vgrad(Rect2(0, 0, w, gr), [[0.0, sc[0]], [0.4, sc[1]], [0.75, sc[2]], [1.0, sc[3]]])
	if Meta.active_item.get("bg", "default") == "nightGlow":
		draw_rect(Rect2(0, 0, w, gr), Color(GREEN, 0.08))
		for i in 18:
			draw_circle(Vector2(fmod(i * 73 + elapsed * 12, w), 30 + (i % 5) * 24), 1.2 + (i % 3) * 0.6, Color("#f4e04d", 0.45))
	var gc := gnd_cols()
	vgrad(Rect2(0, gr, w, h - gr), [[0.0, gc[0]], [1.0, gc[1]]])
	if sky_a == "night" or sky_b == "night":
		var al := 0.9 if sky_a == "night" else sky_t * 0.9
		draw_circle(Vector2(w - 65, 55), 26, Color("#fffde7", al))
		draw_circle(Vector2(w - 53, 50), 22, Color(sc[0], al))
	if sky_a != "night":
		var sy := gr * 0.8 if (sky_a == "dawn" or sky_a == "dusk") else gr * 0.18
		var sxp := w - 70.0 if sky_a == "dusk" else 70.0
		var scol := Color("#f4845f") if (sky_a == "dawn" or sky_a == "dusk") else Color("#ffe066")
		draw_circle(Vector2(sxp, sy), 22, Color(scol, 0.85))
		draw_circle(Vector2(sxp, sy), 36, Color(scol, 0.18))
	var wth: String = WLIST[lvl % WLIST.size()]
	if wth != "clear":
		for c in clouds:
			var cx: float = fposmod(c["wx"] - cam_x * 0.3, w + 200.0)
			var a: float = c["a"] * 0.7
			ellipse(Vector2(cx, c["wy"]), c["w"], c["w"] * 0.38, Color("#eef4ff", a))
			ellipse(Vector2(cx - c["w"] * 0.3, c["wy"] + 5), c["w"] * 0.55, c["w"] * 0.3, Color("#eef4ff", a))
	if wth == "rainy":
		for r in rain:
			draw_line(Vector2(r["x"], r["y"]), Vector2(r["x"] + 4, r["y"] + r["l"]), Color(0.59, 0.75, 1.0, 0.55), 1.0)
	if wth == "snowy":
		for s in snow:
			draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(0.9, 0.96, 1.0, 0.85))


func draw_plats() -> void:
	var night := sky_a == "night"
	for i in plats.size():
		var p: Dictionary = plats[i]
		var x := scx(p["x"])
		var pw: float = p["w"]
		if x + pw < -10 or x > w + 10:
			continue
		var t_h: float = h - gr + 30
		draw_rect(Rect2(x + 4, gr + 4, pw, t_h), Color(0, 0, 0, 0.25))
		hgrad(Rect2(x, gr, pw, t_h), [[0.0, Color("#1b2e4a")], [0.5, Color("#2c4a72")], [1.0, Color("#0f1e35")]])
		var fh := 14.0
		var wc := maxi(1, int((pw - 4) / 10))
		var ww := maxf(4.0, floorf((pw - 4) / wc) - 3)
		var f := 0
		while f * fh < t_h - 4:
			for c2 in wc:
				var lit := ((i * 31 + f * 7 + c2 * 13) % 5) != 0
				var wcol: Color
				if lit and night: wcol = Color(1, 0.9, 0.47, 0.6)
				elif lit: wcol = Color(0.7, 0.86, 1.0, 0.25)
				else: wcol = Color(0.04, 0.08, 0.16, 0.6)
				draw_rect(Rect2(x + 3 + c2 * ((pw - 4) / wc), gr + f * fh + 3, ww, fh - 4), wcol)
			f += 1
		vgrad(Rect2(x, gr - 6, pw, 8), [[0.0, Color("#7ab8e8")], [1.0, Color("#2c6ba0")]])
		draw_rect(Rect2(x, gr - 6, pw, 2), Color(1, 1, 1, 0.3))
		if pw > 40:
			var ax := x + pw / 2
			draw_line(Vector2(ax, gr - 6), Vector2(ax, gr - 20), Color(0.59, 0.7, 0.86, 0.6), 1.5)
			draw_circle(Vector2(ax, gr - 21), 2.5, Color(0.9, 0.31, 0.31, 0.85))
		if i == ci + 1:
			var mx := x + pw / 2
			var zw := maxf(8.0, pw / 3)
			draw_rect(Rect2(mx - zw / 2, gr - 6, zw, 8), Color(0.96, 0.88, 0.3, 0.22))
			draw_dashed_line(Vector2(mx, gr - 20), Vector2(mx, gr - 6), Color(1, 0.86, 0.2, 0.9), 1.5, 3.0)
			draw_circle(Vector2(mx, gr - 22), 4, Color("#ffe133"))
		if p["last"] and i > ci:
			var hx := x + pw / 2
			var hy := gr - 6.0
			draw_rect(Rect2(hx - 13, hy - 24, 26, 24), Color("#e07b39"))
			draw_rect(Rect2(hx - 5, hy - 14, 10, 14), Color("#5c3317"))
			draw_rect(Rect2(hx + 3, hy - 22, 7, 6), Color("#87ceeb"))
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 16, hy - 24), Vector2(hx, hy - 40), Vector2(hx + 16, hy - 24)]), Color("#c0392b"))
	# gap decorations
	var gc := gnd_cols()
	var nightish := sky_a == "night" or sky_b == "night"
	for i in plats.size():
		if i == 0:
			continue
		var p: Dictionary = plats[i]
		var prev: Dictionary = plats[i - 1]
		var gx1 := scx(prev["x"] + prev["w"])
		var gx2 := scx(p["x"])
		if gx2 <= gx1 or gx2 < -10 or gx1 > w + 10:
			continue
		var gw := gx2 - gx1
		draw_rect(Rect2(gx1, gr, gw, h - gr), gc[0])
		var sil_base := h - 28.0
		if i % 2 == 0:
			for b in [{"ox": 10, "bw": 20, "bh": 38}, {"ox": 40, "bw": 14, "bh": 52}, {"ox": 65, "bw": 24, "bh": 34}, {"ox": 110, "bw": 16, "bh": 48}]:
				var bx3: float = gx1 + (b["ox"] / 200.0) * gw
				var bw3: float = b["bw"] * gw / 200.0
				var by3: float = sil_base - b["bh"] * 0.5
				if bx3 > gx2 or bx3 + bw3 < gx1:
					continue
				draw_rect(Rect2(bx3, by3, bw3, h - by3), Color(0.07, 0.09, 0.16, 0.75))
				if nightish and bw3 > 6:
					for wr in 2:
						for wc in 2:
							if (int(b["ox"]) + wr * wc * 7) % 3 == 0:
								continue
							draw_rect(Rect2(bx3 + 2 + wc * (bw3 / 2 - 2), by3 + 4 + wr * 8, bw3 / 2 - 4, 4), Color(1, 0.9, 0.39, 0.4))
		if i % 3 == 1:
			# mosque silhouette
			var cx2 := gx1 + gw * 0.5
			var cam_w := minf(gw * 0.68, 58.0)
			var cam_h := cam_w * 0.8
			var dome_col := Color(0.12, 0.14, 0.24, 0.9)
			draw_circle_arc_fill(Vector2(cx2, sil_base - cam_h * 0.5), cam_w * 0.3, dome_col)
			draw_rect(Rect2(cx2 - cam_w * 0.3, sil_base - cam_h * 0.5, cam_w * 0.6, h - (sil_base - cam_h * 0.5)), dome_col)
			var mw := cam_w * 0.08
			var mh := cam_h * 1.18
			var lx_m := cx2 - cam_w * 0.44
			var rx_m := cx2 + cam_w * 0.36
			var top_y := sil_base - mh - cam_h * 0.2
			for mx in [lx_m, rx_m]:
				draw_rect(Rect2(mx, sil_base - mh, mw, h - (sil_base - mh)), dome_col)
				draw_colored_polygon(PackedVector2Array([Vector2(mx, sil_base - mh), Vector2(mx + mw / 2, top_y), Vector2(mx + mw, sil_base - mh)]), dome_col)
			if nightish:
				qcurve(Vector2(lx_m + mw / 2, top_y + 15), Vector2(cx2, top_y + 25), Vector2(rx_m + mw / 2, top_y + 15), Color(1, 0.91, 0.47, 0.85), 1.0)
				txt_c("Allah is the greatest", cx2, top_y - 3, int(clampf(gw / 16.0, 5, 8)), Color(1, 0.91, 0.47, 0.95))
		if gw > 30:
			# street lamp
			var lx := gx1 + gw * 0.25
			var lbase := h - 10.0
			draw_rect(Rect2(lx - 1.5, lbase - 38, 3, 38), Color(0.31, 0.31, 0.35, 0.85))
			draw_rect(Rect2(lx - 1.5, lbase - 38, 8, 3), Color(0.31, 0.31, 0.35, 0.85))
			if nightish:
				var flicker := sin(elapsed * 4 + lx) * 0.15 + 0.85
				draw_circle(Vector2(lx + 3, lbase - 37), 4, Color(1, 0.94, 0.59, 0.9 * flicker))
				draw_circle(Vector2(lx + 3, lbase - 37), 14, Color(1, 0.94, 0.59, 0.12 * flicker))
				draw_colored_polygon(PackedVector2Array([Vector2(lx + 3, lbase - 37), Vector2(lx - 18, lbase), Vector2(lx + 24, lbase)]), Color(1, 0.94, 0.59, 0.08 * flicker))
			else:
				draw_circle(Vector2(lx + 3, lbase - 37), 3, Color(0.78, 0.78, 0.7, 0.7))
		if gw > 50:
			# passing car
			var car_x := gx1 + fmod(elapsed * 40 + i * 120, maxf(1.0, gw + 80)) - 20
			if car_x > gx1 - 5 and car_x < gx2 + 5:
				var car_y := h - 28.0
				draw_rect(Rect2(car_x, car_y - 10, 28, 10), Color(0.23, 0.31, 0.47, 0.9))
				draw_rect(Rect2(car_x + 3, car_y - 16, 16, 7), Color(0.31, 0.39, 0.59, 0.8))
				draw_circle(Vector2(car_x + 5, car_y), 4, Color(0.1, 0.1, 0.1))
				draw_circle(Vector2(car_x + 21, car_y), 4, Color(0.1, 0.1, 0.1))
				draw_circle(Vector2(car_x + 27, car_y - 5), 2, Color(1, 0.94, 0.59, 0.9) if nightish else Color(1, 1, 0.78, 0.4))
		if gw > 60:
			# pedestrian
			var person_x := gx1 + fmod(elapsed * 25 + i * 80, maxf(1.0, gw + 40))
			if person_x > gx1 and person_x < gx2:
				var p_y := h - 18.0
				var pw2 := sin(elapsed * 8 + i) * 1.5
				var pcol := Color(0.16, 0.17, 0.24, 0.9)
				draw_rect(Rect2(person_x - 2, p_y - 12, 4, 8), pcol)
				draw_circle(Vector2(person_x, p_y - 14), 2.5, pcol)
				draw_line(Vector2(person_x - 1, p_y - 4), Vector2(person_x - 2 + pw2, p_y), pcol, 1.5)
				draw_line(Vector2(person_x + 1, p_y - 4), Vector2(person_x + 2 - pw2, p_y), pcol, 1.5)
		if gw > 40 and i % 3 == 2:
			# tree silhouette
			var seed_v := (i * 7919) % 100
			var tx := gx1 + gw * 0.3 + (seed_v / 100.0) * gw * 0.4
			var tbase_y := h - 10.0
			draw_rect(Rect2(tx - 2, tbase_y - 40, 4, 40), Color(0.08, 0.09, 0.16, 0.5))
			draw_circle(Vector2(tx, tbase_y - 50), 12, Color(0.08, 0.09, 0.16, 0.35))
			draw_circle(Vector2(tx - 8, tbase_y - 44), 10, Color(0.08, 0.09, 0.16, 0.28))
			draw_circle(Vector2(tx + 8, tbase_y - 44), 10, Color(0.08, 0.09, 0.16, 0.28))
			draw_circle(Vector2(tx, tbase_y - 58), 8, Color(0.08, 0.09, 0.16, 0.22))


func draw_circle_arc_fill(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func draw_stick() -> void:
	if stick_len <= 0 or gone:
		return
	var px := scx(piv_x())
	var a := deg_to_rad(stick_ang)
	draw_set_transform(Vector2(px, gr), a, Vector2.ONE)
	var len := stick_len
	var bw := 8.0
	draw_line(Vector2(2, 2), Vector2(2, -len), Color(0, 0, 0, 0.2), bw + 2)
	draw_line(Vector2(-bw / 2, 0), Vector2(-bw / 2, -len), GOLD, 3)
	draw_line(Vector2(bw / 2, 0), Vector2(bw / 2, -len), GOLD, 3)
	var seg_h := 10.0
	var segs := int(len / seg_h)
	for s in segs:
		var y1 := -s * seg_h
		var y2 := -(s + 1) * seg_h
		var col := Color("#1a1a1a") if s % 2 == 0 else Color("#c8a020")
		draw_line(Vector2(-bw / 2, y1), Vector2(bw / 2, y2), col, 1.5)
		draw_line(Vector2(bw / 2, y1), Vector2(-bw / 2, y2), col, 1.5)
	for s in segs + 1:
		draw_line(Vector2(-bw / 2, -s * seg_h), Vector2(bw / 2, -s * seg_h), Color("#1a1a1a"), 2)
	draw_line(Vector2(-bw / 2 + 1, 0), Vector2(-bw / 2 + 1, -len), Color(1, 0.94, 0.59, 0.4), 1)
	draw_set_transform_matrix(Transform2D())


func draw_doc(cx: float, cy: float, walking: bool, dead: bool, extra_scale: float = 1.0) -> void:
	var t := elapsed * (7.2 if w < 520 else 8.4) if walking else -1.0
	DocDraw.character(self, Vector2(cx, cy), Meta.avatar, {
		"t": t, "dead": dead, "scale": extra_scale,
		"steth": Meta.active_item.get("steth", "default"),
		"coat": Meta.active_item.get("coat", "default"),
	})


func draw_hospital(t: float) -> void:
	vgrad(Rect2(0, 0, w, gr), [[0.0, Color("#87ceeb")], [1.0, Color("#c8e6f5")]])
	for cl in [[w * 0.62, 38.0], [w * 0.8, 22.0], [w * 0.93, 48.0]]:
		var ccol := Color(1, 1, 1, 0.88)
		ellipse(Vector2(cl[0], cl[1]), 28, 13, ccol)
		ellipse(Vector2(cl[0] - 18, cl[1] + 5), 18, 10, ccol)
		ellipse(Vector2(cl[0] + 18, cl[1] + 5), 18, 10, ccol)
	draw_rect(Rect2(0, gr, w, h - gr), Color("#7a8a78"))
	draw_rect(Rect2(0, gr, w, 7), Color("#6a7a68"))
	var i := 0.0
	while i < w:
		draw_rect(Rect2(i, gr + 18, 20, 4), Color("#f0c030"))
		i += 36
	draw_circle(Vector2(w * 0.38, gr + 36), 30, Color("#6a8a62"))
	draw_arc(Vector2(w * 0.38, gr + 36), 34, 0, TAU, 32, Color("#f0c030"), 2)
	for k in 8:
		var a := (k / 8.0) * TAU
		var kx := w * 0.38 + cos(a) * 46
		var ky := gr + 36 + sin(a) * 24
		draw_rect(Rect2(kx - 2, ky - 9, 4, 10), RED)
		draw_rect(Rect2(kx - 2, ky - 6, 4, 3), Color.WHITE)
	var bx := 15.0
	var bw := w * 0.68
	var bh := gr * 0.88
	var by := gr - bh
	draw_rect(Rect2(bx + 5, by + 5, bw, bh), Color(0, 0, 0, 0.1))
	draw_rect(Rect2(bx, by, bw, bh), Color("#f2f2ee"))
	draw_rect(Rect2(bx, by, bw, 10), Color("#e0e0dc"))
	for r in 5:
		for c in 8:
			var px := bx + 18 + c * ((bw - 36) / 8)
			var py := by + 18 + r * ((bh - 40) / 5)
			if px + 36 > bx + bw - 8:
				continue
			var lit := ((r * 5 + c * 3) % 4) != 3
			draw_rect(Rect2(px, py, 36, 22), Color(0.78, 0.88, 0.96, 0.82) if lit else Color(0.47, 0.58, 0.66, 0.5))
			if lit:
				draw_rect(Rect2(px, py, 18, 22), Color(1, 1, 1, 0.28))
			draw_rect(Rect2(px, py, 36, 22), Color(0.63, 0.73, 0.8, 0.65), false, 1)
	var sx := bx
	var sw := bw * 0.34
	var sh := bh * 0.5
	var sy := gr - sh
	draw_rect(Rect2(sx, sy, sw, sh), Color("#eaeae6"))
	var band_h := sh * 0.26
	draw_rect(Rect2(sx + 8, sy + 8, sw - 16, band_h), Color(0.63, 0.78, 0.88, 0.6))
	# "ACİL SERVİS" lives inside the blue band; hospital name right below it,
	# both above the sliding door so nothing gets covered.
	var acil_size := 20
	while txt_w("ACİL SERVİS", acil_size) > sw - 70 and acil_size > 10:
		acil_size -= 1
	txt_l("ACİL SERVİS", sx + 16, sy + 8 + band_h * 0.7, acil_size, Color("#cc1122"))
	var kou_size := 9
	while txt_w("KOCAELİ ÜNİVERSİTESİ HASTANESİ", kou_size) > sw - 24 and kou_size > 6:
		kou_size -= 1
	txt_l("KOCAELİ ÜNİVERSİTESİ HASTANESİ", sx + 16, sy + 8 + band_h + 16, kou_size, Color("#777777"))
	var hcx := sx + sw - 28
	var hcy := sy + 24
	draw_circle(Vector2(hcx, hcy), 16, RED)
	draw_circle(Vector2(hcx + 5, hcy - 2), 13, Color("#eaeae6"))
	var sign_x := bx + sw
	var sign_y := by + 6
	var sign_w := bw - sw - 6
	draw_rect(Rect2(sign_x, sign_y, sign_w, 22), Color("#1565c0"))
	var sign_text := "KOÜ ED" if w < 430 else ("KOÜ EMERGENCY" if w < 560 else "KOÜ EMERGENCY DEPARTMENT")
	var sign_size := 8 if w < 560 else 10
	while txt_w(sign_text, sign_size) > sign_w - 14 and sign_size > 6:
		sign_size -= 1
	txt_l(sign_text, sign_x + 6, by + 21, sign_size, Color.WHITE)
	var dx := sx + sw * 0.12
	var dw := sw * 0.68
	var dh := sh * 0.37
	var dy := gr - dh
	draw_rect(Rect2(dx - 4, dy - 4, dw + 8, dh + 4), Color("#a02818"))
	var slide := absf(sin(t * 1.5)) * 5
	draw_rect(Rect2(dx, dy, dw / 2 - slide, dh), Color(0.7, 0.88, 0.96, 0.4))
	draw_rect(Rect2(dx + dw / 2 + slide, dy, dw / 2 - slide, dh), Color(0.7, 0.88, 0.96, 0.4))
	draw_rect(Rect2(dx + dw / 2 - slide, dy, slide * 2, dh), Color("#050510"))
	draw_rect(Rect2(dx - 4, dy - 20, dw + 8, 17), RED)
	txt_c("ACİL / ED", dx + dw / 2, dy - 8, 10, Color.WHITE)
	# ambulance
	var ax := w * 0.5
	var ay := gr - 64
	draw_rect(Rect2(ax, ay, 170, 52), Color("#f8f8f8"))
	draw_rect(Rect2(ax, ay, 170, 52), Color("#cccccc"), false, 1)
	draw_rect(Rect2(ax, ay + 17, 170, 13), RED)
	txt_c("AMBULANS", ax + 85, ay + 27, 9, Color.WHITE)
	draw_circle(Vector2(ax + 32, ay + 10), 11, RED)
	draw_circle(Vector2(ax + 36, ay + 8), 9, Color("#f8f8f8"))
	draw_rect(Rect2(ax + 118, ay + 4, 46, 22), Color(0.7, 0.88, 0.96, 0.6))
	draw_rect(Rect2(ax + 118, ay + 4, 46, 22), Color("#aaaaaa"), false, 1)
	draw_circle(Vector2(ax + 163, ay + 8), 7, Color(1, 0.16, 0.16, 0.95) if sin(t * 8) > 0 else Color(0, 0.31, 0.86, 0.95))
	draw_circle(Vector2(ax + 32, ay + 52), 13, Color("#1a1a1a"))
	draw_circle(Vector2(ax + 136, ay + 52), 13, Color("#1a1a1a"))
	draw_circle(Vector2(ax + 32, ay + 52), 6, Color("#555555"))
	draw_circle(Vector2(ax + 136, ay + 52), 6, Color("#555555"))
	draw_rect(Rect2(ax, ay, 18, 52), Color("#e0e0e0"))
	draw_rect(Rect2(ax, ay, 18, 52), Color("#aaaaaa"), false, 1)
	# stretcher with patient + two paramedics (shared character renderer)
	var sed_x := ax - 78
	var base_y := gr - 2.0
	draw_line(Vector2(sed_x, base_y - 16), Vector2(sed_x + 56, base_y - 16), Color("#9aa0a6"), 2.5)
	draw_line(Vector2(sed_x + 12, base_y - 15), Vector2(sed_x + 8, base_y - 2), Color("#8a9096"), 2)
	draw_line(Vector2(sed_x + 44, base_y - 15), Vector2(sed_x + 48, base_y - 2), Color("#8a9096"), 2)
	draw_circle(Vector2(sed_x + 8, base_y - 1), 2.6, Color("#2c2f33"))
	draw_circle(Vector2(sed_x + 48, base_y - 1), 2.6, Color("#2c2f33"))
	rrect(Rect2(sed_x + 1, base_y - 22, 54, 6), 3, Color("#e8ecef"))
	rrect(Rect2(sed_x + 6, base_y - 27, 34, 7), 3, Color("#4a90d9"))
	ellipse(Vector2(sed_x + 47, base_y - 24), 4.5, 2.2, Color("#f5f7f9"))
	draw_circle(Vector2(sed_x + 46, base_y - 26), 3.6, Color("#e7b08c"))
	ellipse(Vector2(sed_x + 46, base_y - 29), 3.4, 1.6, Color("#3a2416"))
	DocDraw.character(self, Vector2(sed_x - 10, base_y), "maleNurse", {"scale": 0.52})
	DocDraw.character(self, Vector2(sed_x + 66, base_y), "femaleNurse", {"scale": 0.52})
	for tx in [w * 0.78, w * 0.87, w * 0.95]:
		draw_rect(Rect2(tx - 2, gr - 32, 4, 32), Color("#5a3820"))
		draw_circle(Vector2(tx, gr - 40), 11, Color("#4a8a40"))
		draw_circle(Vector2(tx - 7, gr - 34), 8, Color("#4a8a40"))
		draw_circle(Vector2(tx + 7, gr - 34), 8, Color("#4a8a40"))
	# title bar
	draw_rect(Rect2(0, 0, w, 44), Color(0, 0, 0, 0.52))
	txt_c("END OF SHIFT", w / 2, 30, 24, GOLD)
	# back button
	rrect(Rect2(w - 50, 54, 36, 30), 9, Color(0, 0, 0, 0.72))
	rrect_line(Rect2(w - 50, 54, 36, 30), 9, GOLD, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(w - 40, 69), Vector2(w - 28, 62), Vector2(w - 28, 76)]), Color.WHITE)
	if Meta.hi > 0:
		rrect(Rect2(w - 132, gr * 0.42, 112, 34), 12, Color(0, 0, 0, 0.46))
		rrect_line(Rect2(w - 132, gr * 0.42, 112, 34), 12, Color(GOLD, 0.42), 1)
		txt_c("Best: %d" % Meta.hi, w - 76, gr * 0.42 + 22, 12, Color(GOLD, 0.9))
	if is_admin():
		var px := w - 154
		var py := gr * 0.54
		rrect(Rect2(px, py, 134, 82), 12, Color(0, 0, 0, 0.62))
		rrect_line(Rect2(px, py, 134, 82), 12, Color(GREEN, 0.55), 1)
		txt_c("ADMIN START", px + 67, py + 18, 12, GREEN)
		rrect(Rect2(px + 12, py + 30, 30, 30), 9, Color(1, 1, 1, 0.12))
		rrect(Rect2(px + 92, py + 30, 30, 30), 9, Color(1, 1, 1, 0.12))
		txt_c("-", px + 27, py + 52, 22, Color.WHITE)
		txt_c("+", px + 107, py + 52, 22, Color.WHITE)
		txt_c("Lv %d" % admin_start_level, px + 67, py + 52, 18, GOLD)
	if sin(t * 3) > 0:
		txt_c("Tap to start", w / 2, h - 18, 15, Color(1, 1, 1, 0.9))


func draw_walkout(t: float) -> void:
	vgrad(Rect2(0, 0, w, gr), [[0.0, Color("#1a0533")], [0.5, Color("#6b2d6b")], [1.0, Color("#f4845f")]])
	draw_rect(Rect2(0, gr, w, h - gr), Color("#1a0a2e"))
	draw_circle(Vector2(w * 0.7, gr * 0.6), 22, Color("#ffd166", 0.8))
	draw_rect(Rect2(20, gr - 100, 50, 100), Color("#a02818"))
	draw_rect(Rect2(25, gr - 95, 40, 95), Color("#050510"))
	vgrad(Rect2(0, gr, w, h - gr), [[0.0, Color("#2c4a72")], [1.0, Color("#0f1e35")]])
	draw_doc(intro_doc_x, gr, true, false)
	if t > 1.4:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, minf(1.0, (t - 1.4) * 2.5)))


func draw_house_in(t: float) -> void:
	draw_bg()
	draw_plats()
	var p: Dictionary = plats[ci]
	var hx: float = scx(p["x"]) + p["w"] / 2
	draw_set_transform(Vector2(hx, gr - 6), 0, Vector2.ONE)
	draw_rect(Rect2(-15, -26, 30, 26), Color("#e07b39"))
	var dop := minf(1.0, t * 1.2)
	draw_rect(Rect2(-5, -16, 10, 16), Color("#050510"))
	draw_rect(Rect2(-5, -16, 10 * (1 - dop), 16), Color("#3a1f0e"))
	draw_rect(Rect2(4, -24, 7, 6), Color("#87ceeb"))
	draw_rect(Rect2(4, -24, 7, 6), Color("#5c3317"), false, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -26), Vector2(0, -42), Vector2(18, -26)]), Color("#c0392b"))
	draw_rect(Rect2(-12, -22, 24, 6), Color.WHITE)
	txt_c("HOME", 0, -17, 5, Color("#1565c0"))
	draw_set_transform_matrix(Transform2D())
	var walk_t := minf(1.0, t / 0.9)
	var doc_x: float = intro_doc_x + (scx(p["x"]) + p["w"] / 2 - intro_doc_x) * walk_t
	var doc_scale := maxf(0.1, 1 - (walk_t - 0.8) * 4) if walk_t > 0.8 else 1.0
	var doc_alpha := maxf(0.0, 1 - (walk_t - 0.85) * 6) if walk_t > 0.85 else 1.0
	if doc_alpha > 0.15:
		draw_doc(doc_x, gr, true, false, doc_scale)
	if t > 1.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, minf(1.0, (t - 1.0) * 2.5)))


func draw_flash(t: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color.WHITE)
	txt_c("LEVEL %d" % (lvl + 1), w / 2, h / 2, 32, Color("#1565c0"))
	if lvl + 1 >= 4:
		txt_c("EXTRA LIFE EARNED!", w / 2, h / 2 + 34, 16, GREEN)
	if t > 0.4:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, maxf(0.0, 1 - (t - 0.4) * 3)))


func draw_fighter(x: float, y: float, flip: bool, label: String, win: bool, t: float, mode: String = "fight") -> void:
	var line_col := Color("#101827")
	var sxv := -1.0 if flip else 1.0
	var xf := Transform2D(0, Vector2(sxv, 1.0), 0, Vector2(x, y))
	if mode == "fallen":
		xf = xf * Transform2D(PI / 2.4, Vector2.ONE, 0, Vector2(0, 4))
	draw_set_transform_matrix(xf)
	var walk := sin(t * 8) * 3
	var arm := sin(t * 10) * 5
	draw_arc(Vector2(0, -42), 9, 0, TAU, 20, line_col, 4)
	draw_line(Vector2(0, -33), Vector2(0, -10), line_col, 4)
	if mode == "fallen":
		draw_line(Vector2(0, -25), Vector2(17, -19), line_col, 4)
		draw_line(Vector2(0, -24), Vector2(-15, -18), line_col, 4)
		draw_line(Vector2(0, -10), Vector2(-10, 8), line_col, 4)
		draw_line(Vector2(0, -10), Vector2(10, 8), line_col, 4)
		draw_set_transform_matrix(Transform2D())
		txt_c(label, x, y - 18, 14, Color.WHITE)
		return
	if mode == "cheer":
		draw_line(Vector2(0, -25), Vector2(18, -45), line_col, 4)
		draw_line(Vector2(0, -24), Vector2(-18, -45), line_col, 4)
		draw_line(Vector2(18, -45), Vector2(32, -58), Color("#d8dee9"), 3)
	else:
		draw_line(Vector2(0, -25), Vector2(18, -19 + arm), line_col, 4)
		draw_line(Vector2(18, -19 + arm), Vector2(38, -34 + sin(t * 12) * 8), Color("#d8dee9"), 3)
		draw_line(Vector2(0, -24), Vector2(-13, -16 - arm * 0.2), line_col, 4)
	draw_line(Vector2(0, -10), Vector2(-10 + walk, 8), line_col, 4)
	draw_line(Vector2(0, -10), Vector2(10 - walk, 8), line_col, 4)
	draw_set_transform_matrix(Transform2D())
	txt_c(label, x, y - 64, 14, GREEN if win else Color.WHITE)


func draw_duel(t: float) -> void:
	var p := minf(1.0, t / 10.0)
	var hit := floorf(t * 2.2)
	var left_x := w * 0.34 + sin(t * 5) * 10
	var right_x := w * 0.66 - sin(t * 4.7) * 8
	var base := h * 0.68
	vgrad(Rect2(0, 0, w, h), [[0.0, Color("#0b3a7a")], [1.0, Color("#061833")]])
	for i in 8:
		draw_rect(Rect2(fmod(i * 97 + t * 25, w + 80) - 40, 0, 2, h), Color(1, 1, 1, 0.12))
	txt_c("LEVEL 10 DUEL", w / 2, 46, 22, GOLD)
	draw_fighter(left_x, base, false, Meta.player_name if Meta.player_name != "" else "YOU", p > 0.82, t, "cheer" if p > 0.82 else "fight")
	draw_fighter(right_x, base, true, "MP", false, t + 0.7, "fallen" if p > 0.82 else "fight")
	for i in 12:
		var burst := fmod(hit + i, 5.0)
		var side := -1.0 if i % 2 == 1 else 1.0
		var bx := w / 2 + sin(hit + i) * 30
		var by := base - 36 + cos(i * 2) * 16
		draw_circle(Vector2(bx + side * burst * 5, by - burst * 3), 2.5 + burst * 0.7, Color(0.9, 0.16, 0.22, maxf(0.0, 0.75 - burst * 0.12)))
	if p > 0.82:
		draw_rect(Rect2(0, 0, w, h), Color(GREEN, 0.16))
		txt_c("YOU WIN!", w / 2, h * 0.28, 28, GREEN)
	txt_c("%ds" % maxi(0, 10 - int(t)), w / 2, h - 24, 13, Color(1, 1, 1, 0.75))


func draw_floats() -> void:
	for f in floats:
		var col: Color = f["col"]
		txt_c(f["txt"], scx(f["wx"]), f["y"], 17, Color(col, minf(1.0, f["life"] * 2.5)))


func draw_hud() -> void:
	var compact := w < 520
	var score_w := 70.0 if compact else 86.0
	var re_x := 90.0 if compact else 108.0
	rrect(Rect2(14, 14, score_w, 30), 12, Color(0.03, 0.04, 0.08, 0.48))
	rrect_line(Rect2(14, 14, score_w, 30), 12, Color(GOLD, 0.25), 1)
	draw_star(Vector2(14 + score_w / 2 - txt_w(str(score), 15 if not compact else 13) / 2 - 9, 29), 7, Color("#f4d35e"))
	txt_c(str(score), 14 + score_w / 2 + 7, 35, 13 if compact else 15, GOLD)
	if combo > 1 and state != "GAME_OVER":
		var cw := 76.0 if compact else 88.0
		rrect(Rect2(14, 48, cw, 22), 8, Color(0, 0, 0, 0.72))
		rrect_line(Rect2(14, 48, cw, 22), 8, Color(0.96, 0.88, 0.3, 0.42), 1)
		txt_c("COMBO x%d" % combo, 14 + cw / 2, 63, 10 if compact else 11, Color("#f4e04d"))
	if state != "GAME_OVER":
		rrect(Rect2(re_x, 14, 30, 30), 10, Color(0.03, 0.04, 0.08, 0.48))
		rrect_line(Rect2(re_x, 14, 30, 30), 10, Color(1, 1, 1, 0.18), 1)
		# restart arrow
		draw_arc(Vector2(re_x + 15, 29), 8, -PI * 0.25, PI * 1.35, 16, Color(1, 1, 1, 0.86), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(re_x + 18, 20), Vector2(re_x + 25, 22), Vector2(re_x + 20, 27)]), Color(1, 1, 1, 0.86))
	rrect(Rect2(w / 2 - 62, 14, 124, 40), 14, Color(0.03, 0.04, 0.08, 0.5))
	rrect_line(Rect2(w / 2 - 62, 14, 124, 40), 14, Color(GREEN, 0.22), 1)
	txt_c("LV %d" % lvl, w / 2, 30, 12, GREEN)
	var bx2 := w / 2 - 46
	rrect(Rect2(bx2, 38, 92, 6), 4, Color(1, 1, 1, 0.16))
	if lp > 0:
		rrect(Rect2(bx2, 38, (lp / 10.0) * 92, 6), 4, Color(lp / 10.0, 0.78 * (1 - lp / 10.0), 0.16))
	txt_c("%d/10" % lp, w / 2, 51, 9, Color(1, 1, 1, 0.56))
	var lpw := 110.0
	var lpx := w - lpw - 14
	rrect(Rect2(lpx, 14, lpw, 36), 14, Color(0.03, 0.04, 0.08, 0.5))
	rrect_line(Rect2(lpx, 14, lpw, 36), 14, Color(1, 1, 1, 0.16), 1)
	if is_admin():
		txt_c("∞", lpx + lpw / 2, 40, 24, RED)
	else:
		var count := maxi(0, lives)
		var fs := clampf(84.0 / maxf(1.0, count), 10, 22)
		var gap := minf(18.0, (lpw - 24) / (count - 1)) if count > 1 else 0.0
		var start := lpx + lpw / 2 - gap * (count - 1) / 2
		for i in count:
			draw_heart(Vector2(start + i * gap, 30), fs * 0.55, RED)
	draw_weather_icon()
	draw_live_leaderboard()


func draw_weather_icon() -> void:
	var wth: String = WLIST[lvl % WLIST.size()]
	if wth == "clear":
		return
	var c := Vector2(w - 30, h - 26)
	var ccol := Color(0.93, 0.95, 1.0, 0.85)
	draw_circle(c + Vector2(-7, 2), 6, ccol)
	draw_circle(c + Vector2(0, -2), 8, ccol)
	draw_circle(c + Vector2(8, 2), 6, ccol)
	draw_rect(Rect2(c.x - 10, c.y + 2, 22, 5), ccol)
	if wth == "rainy":
		for i in 3:
			draw_line(c + Vector2(-6 + i * 7, 10), c + Vector2(-8 + i * 7, 16), Color(0.59, 0.75, 1.0, 0.8), 1.5)
	elif wth == "snowy":
		for i in 3:
			draw_circle(c + Vector2(-6 + i * 7, 13), 1.6, Color(0.9, 0.96, 1.0, 0.9))


func live_rows() -> Array:
	var by_name := {}
	for r in leaderboard:
		if typeof(r) != TYPE_DICTIONARY or String(r.get("name", "")) == "":
			continue
		var nm := String(r["name"])
		var rs := int(r.get("score", 0))
		var old = by_name.get(nm)
		if old == null or rs > old["score"]:
			by_name[nm] = {"name": nm, "score": rs, "level": int(r.get("level", 1))}
	if Meta.player_name != "" and not is_admin():
		var old = by_name.get(Meta.player_name)
		if old == null or score > old["score"]:
			by_name[Meta.player_name] = {"name": Meta.player_name, "score": score, "level": lvl}
	var rows: Array = by_name.values()
	rows.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		return a["name"] < b["name"])
	return rows


func short_name(n: String, maxc: int) -> String:
	return n.substr(0, maxc - 1) + "…" if n.length() > maxc else n


func draw_live_leaderboard() -> void:
	var rows := live_rows()
	var top := rows.slice(0, 5)
	var rank := 0
	for i in rows.size():
		if rows[i]["name"] == Meta.player_name:
			rank = i + 1
			break
	var compact := w < 520
	var pw := 148.0 if compact else 174.0
	var px := w - pw - 14
	var py := 84.0 if compact else 56.0
	var row_h := 16.0 if compact else 18.0
	var ph := (118.0 if compact else 132.0) + (18.0 if rank > 5 else 0.0)
	if px < 150 or state == "GAME_OVER":
		return
	if SB.active_player_count >= 0:
		var chip_w := 58.0 if compact else 64.0
		var chip_x := px - chip_w - 8  # left of the panel so it never overlaps the lives box
		rrect(Rect2(chip_x, py - 26, chip_w, 20), 10, Color(0.03, 0.04, 0.08, 0.55))
		draw_circle(Vector2(chip_x + 12, py - 16), 5, Color("#22c55e"))
		txt_l(str(SB.active_player_count), chip_x + 23, py - 12, 10 if compact else 11, Color.WHITE)
	rrect(Rect2(px, py, pw, ph), 10, Color(0.04, 0.03, 0.1, 0.68))
	rrect_line(Rect2(px, py, pw, ph), 10, Color(GOLD, 0.35), 1)
	txt_l("ROOM TOP 5" if Meta.current_room != "" else "TOP 5", px + 10, py + 18, 10 if compact else 11, GOLD)
	if top.is_empty():
		txt_l("No scores yet", px + 10, py + 42, 10 if compact else 11, Color(1, 1, 1, 0.45))
		return
	for i in top.size():
		var r: Dictionary = top[i]
		var y := py + 38 + i * row_h
		var is_me: bool = r["name"] == Meta.player_name
		rrect(Rect2(px + 6, y - row_h + 3, pw - 12, row_h), 5, Color(GREEN, 0.18) if is_me else Color(1, 1, 1, 0.05))
		txt_l("%d. %s" % [i + 1, short_name(r["name"], 9 if compact else 12)], px + 10, y, 10 if compact else 11, GREEN if is_me else Color.WHITE)
		txt_r(str(r["score"]), px + pw - 10, y, 10 if compact else 11, GOLD)
	if rank > 5:
		var y := py + 38 + 5 * row_h + 12
		draw_line(Vector2(px + 10, y - 11), Vector2(px + pw - 10, y - 11), Color(1, 1, 1, 0.16), 1)
		txt_l("#%d %s" % [rank, short_name(Meta.player_name, 8 if compact else 11)], px + 10, y, 10 if compact else 11, GREEN)
		txt_r(str(score), px + pw - 10, y, 10 if compact else 11, GREEN)


func draw_burst() -> void:
	var x := scx(burst_wx)
	var y := burst_y
	var t := minf(1.0, burst_t / 1.5)
	var ga := 1 - t * 0.15
	for i in 24:
		var a := i * 2.399
		var spd := 18 + (i % 7) * 8
		var px := x + cos(a) * spd * t
		var py := y + sin(a) * spd * t - 18 * t
		var sz := 2 + (i % 4)
		var col := Color("#d91f3c") if i % 3 != 0 else Color("#7f1022")
		draw_circle(Vector2(px, py), sz * (1 - t * 0.35), Color(col, ga))
	for i in 6:
		var a := i * PI / 3 + 0.4
		var px := x + cos(a) * 32 * t
		var py := y - 18 + sin(a) * 22 * t
		draw_line(Vector2(px - 4, py - 4), Vector2(px + 5, py + 5), Color(Color("#111827"), ga), 4)


func draw_leaderboard_full() -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.03, 0.1, 0.96))
	txt_c("ROOM %s" % Meta.current_room if Meta.current_room != "" else "LEADERBOARD", w / 2, 50, 22, GOLD)
	if leaderboard.is_empty():
		txt_c("No scores yet. Be the first!", w / 2, h / 2, 15, Color(1, 1, 1, 0.5))
	else:
		for i in leaderboard.size():
			var row: Dictionary = leaderboard[i]
			var y := 90.0 + i * 38
			var is_me: bool = String(row.get("name", "")) == Meta.player_name
			rrect(Rect2(w / 2 - 160, y - 22, 320, 32), 8, Color(GREEN, 0.15) if is_me else Color(1, 1, 1, 0.04))
			if is_me:
				rrect_line(Rect2(w / 2 - 160, y - 22, 320, 32), 8, GREEN, 1)
			var medal := "%d." % (i + 1)
			var medal_col := Color.WHITE
			if i == 0: medal_col = Color("#ffd700")
			elif i == 1: medal_col = Color("#c0c0c0")
			elif i == 2: medal_col = Color("#cd7f32")
			txt_l(medal, w / 2 - 150, y, 15, medal_col)
			txt_l(String(row.get("name", "")), w / 2 - 120, y, 15, GREEN if is_me else Color.WHITE)
			txt_r("%d  Lv%d" % [int(row.get("score", 0)), int(row.get("level", 1))], w / 2 + 150, y, 15, GOLD)
	var bw := 140.0
	var by := h - 60.0
	rrect(Rect2(w / 2 - bw / 2, by, bw, 36), 10, Color(1, 1, 1, 0.1))
	rrect_line(Rect2(w / 2 - bw / 2, by, bw, 36), 10, Color.WHITE, 1)
	txt_c("✕ Close", w / 2, by + 23, 14, Color.WHITE)


func draw_hint() -> void:
	if state != "WAITING" or score > 0:
		return
	txt_c("Hold to grow bridge  ·  Release to drop", w / 2, h - 18, 14, Color(1, 1, 1, 0.4))


func draw_go() -> void:
	if state != "GAME_OVER":
		return
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.03, 0.1, 0.82))
	var pw := 300.0
	var ph := 300.0
	var ox := w / 2 - pw / 2
	var oy := h / 2 - ph / 2
	rrect(Rect2(ox, oy, pw, ph), 20, Color(0.1, 0.08, 0.22, 0.96))
	rrect_line(Rect2(ox, oy, pw, ph), 20, GOLD, 2)
	txt_c("Game Over!", w / 2, oy + 52, 34, RED)
	txt_c("Level: %d" % lvl, w / 2, oy + 84, 20, GREEN)
	txt_c("Score: %d" % score, w / 2, oy + 112, 22, GOLD)
	if score >= Meta.hi and score > 0:
		txt_c("New record!", w / 2, oy + 136, 14, GREEN)
	txt_c("Tap to play again", w / 2, oy + 165, 16, Color(1, 1, 1, 0.7))
	rrect(Rect2(w / 2 - 80, oy + 178, 160, 36), 10, Color(GOLD, 0.15))
	rrect_line(Rect2(w / 2 - 80, oy + 178, 160, 36), 10, GOLD, 1)
	txt_c("Leaderboard", w / 2, oy + 200, 13, GOLD)
	rrect(Rect2(w / 2 - 90, oy + 222, 180, 34), 10, Color(GREEN, 0.14))
	rrect_line(Rect2(w / 2 - 90, oy + 222, 180, 34), 10, Color(GREEN, 0.65), 1)
	txt_c("Challenge Friends", w / 2, oy + 243, 13, GREEN)


func draw_trail() -> void:
	if Meta.active_item.get("trail", "default") != "sparkTrail" or state != "WALKING":
		return
	var x := scx(pl["x"]) - 8
	var y := gr - 42
	for i in 6:
		draw_circle(Vector2(x - i * 9, y + sin(elapsed * 8 + i) * 7), 2.6 - i * 0.2, Color(0.96, 0.88, 0.3, 0.75 - i * 0.1))
