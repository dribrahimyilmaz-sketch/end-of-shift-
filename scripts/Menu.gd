extends Control
## Name-entry / lobby overlay — mobile-game styled main menu.

const AvatarIcon := preload("res://scripts/AvatarIcon.gd")

const GOLD := Color("#e9c46a")
const GREEN := Color("#4ade80")
const RED := Color("#e63946")
const CARD_BG := Color(1, 1, 1, 0.055)
const CARD_BORDER := Color(1, 1, 1, 0.12)

var game: Node2D

var name_field: LineEdit
var room_status: Label
var room_history: OptionButton
var coin_label: Label
var sound_btn: Button
var music_btn: Button
var tasks_box: VBoxContainer
var market_grid: GridContainer
var badge_box: VBoxContainer
var avatar_icons: Array = []

var dialog: ConfirmationDialog
var confirm_overlay: Control
var dlg_code: LineEdit
var dlg_name: LineEdit
var dlg_info: Label
var dlg_mode := ""


func _ready() -> void:
	game = get_node("../..")  # Menu -> UI -> Main
	_build()
	open_menu()


func _draw() -> void:
	# Mobile-game style gradient backdrop with soft glow accents.
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("#141034"), Color("#0d0a24"), Color("#070512"), Color("#1a0f38")]))
	draw_circle(Vector2(s.x * 0.12, s.y * 0.1), s.y * 0.3, Color(0.35, 0.2, 0.75, 0.10))
	draw_circle(Vector2(s.x * 0.9, s.y * 0.85), s.y * 0.38, Color(0.1, 0.6, 0.5, 0.07))
	draw_circle(Vector2(s.x * 0.85, s.y * 0.12), s.y * 0.16, Color(0.91, 0.77, 0.42, 0.06))
	for i in 26:
		var px := fmod(i * 137.7, s.x)
		var py := fmod(i * 89.3, s.y)
		draw_circle(Vector2(px, py), 1.0 + (i % 3) * 0.5, Color(1, 1, 1, 0.05 + (i % 4) * 0.015))


func open_menu() -> void:
	refresh_ui()
	visible = true
	if confirm_overlay:
		confirm_overlay.visible = false
	name_field.text = Meta.player_name
	queue_redraw()


# --- styling helpers ---

func _label(text: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _flat_style(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), bwidth: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bwidth > 0:
		sb.border_color = border
		sb.set_border_width_all(bwidth)
	sb.set_content_margin_all(8)
	return sb


func _button(text: String, fsize: int = 13, kind: String = "chip") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fsize)
	b.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat
	var fg: Color
	match kind:
		"primary":
			normal = _flat_style(GREEN, 24)
			fg = Color(0.03, 0.08, 0.05)
		"danger":
			normal = _flat_style(Color(RED, 0.16), 12, Color(RED, 0.6), 1)
			fg = Color("#ff8a94")
		"gold":
			normal = _flat_style(Color(GOLD, 0.1), 18, Color(GOLD, 0.65), 1)
			fg = GOLD
		_:
			normal = _flat_style(Color(1, 1, 1, 0.08), 12, Color(1, 1, 1, 0.16), 1)
			fg = Color(1, 1, 1, 0.9)
	var hover := normal.duplicate()
	hover.bg_color = Color(normal.bg_color, minf(1.0, normal.bg_color.a + 0.1))
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", _flat_style(Color(1, 1, 1, 0.04), 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(Sfx.tick)  # light haptic tick on every button press
	return b


func _card(title: String) -> Array:  # [PanelContainer, VBoxContainer]
	var pc := PanelContainer.new()
	var sb := _flat_style(CARD_BG, 16, CARD_BORDER, 1)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	if title != "":
		var head := _label(title, 11, Color(GREEN, 0.9))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(head)
	pc.add_child(v)
	return [pc, v]


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 12)
	outer.custom_minimum_size = Vector2(340, 0)
	scroll.add_child(outer)

	outer.add_child(Control.new())  # top spacer

	var title := _label("END OF SHIFT", 34, GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_offset_x", 0)
	outer.add_child(title)
	outer.add_child(_label("Survive the shift. Get home.", 13, Color(1, 1, 1, 0.55)))

	name_field = LineEdit.new()
	name_field.max_length = 16
	name_field.placeholder_text = "Your name..."
	name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_field.custom_minimum_size = Vector2(280, 50)
	name_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_field.add_theme_font_size_override("font_size", 17)
	name_field.add_theme_stylebox_override("normal", _flat_style(Color(1, 1, 1, 0.08), 25, Color(1, 1, 1, 0.2), 1))
	name_field.add_theme_stylebox_override("focus", _flat_style(Color(1, 1, 1, 0.1), 25, GREEN, 2))
	name_field.text_submitted.connect(func(_t): _submit())
	outer.add_child(name_field)

	var av_row := HBoxContainer.new()
	av_row.add_theme_constant_override("separation", 12)
	av_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for av in Meta.AVATARS:
		var icon: Control = AvatarIcon.new()
		icon.avatar = av
		icon.custom_minimum_size = Vector2(66, 80)
		icon.picked.connect(_on_avatar_picked)
		av_row.add_child(icon)
		avatar_icons.append(icon)
	outer.add_child(av_row)

	var start_btn := _button("START", 19, "primary")
	start_btn.custom_minimum_size = Vector2(240, 54)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_submit)
	outer.add_child(start_btn)

	var lb_btn := _button("Leaderboard", 14, "gold")
	lb_btn.custom_minimum_size = Vector2(180, 40)
	lb_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lb_btn.pressed.connect(_open_lb)
	outer.add_child(lb_btn)

	# Room card
	var rc := _card("ROOMS")
	var room_v: VBoxContainer = rc[1]
	room_status = _label("Global leaderboard", 12, GOLD)
	room_v.add_child(room_status)
	var hist_row := HBoxContainer.new()
	hist_row.add_theme_constant_override("separation", 6)
	room_history = OptionButton.new()
	room_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_history.item_selected.connect(_on_room_selected)
	hist_row.add_child(room_history)
	var b_del := _button("Delete", 11, "danger")
	b_del.tooltip_text = "Remove the selected room from YOUR saved list (scores stay online)"
	b_del.pressed.connect(_delete_room)
	hist_row.add_child(b_del)
	room_v.add_child(hist_row)
	var room_actions := HBoxContainer.new()
	room_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	room_actions.add_theme_constant_override("separation", 8)
	var b_create := _button("Create Room", 12)
	b_create.pressed.connect(_create_room)
	var b_join := _button("Join", 12)
	b_join.pressed.connect(_join_room)
	var b_global := _button("Global", 12)
	b_global.pressed.connect(_leave_room)
	var b_copy := _button("Copy Code", 12)
	b_copy.pressed.connect(_copy_room_code)
	room_actions.add_child(b_create)
	room_actions.add_child(b_join)
	room_actions.add_child(b_global)
	room_actions.add_child(b_copy)
	room_v.add_child(room_actions)
	outer.add_child(rc[0])

	# Wallet + sound row
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	var coin_panel := PanelContainer.new()
	coin_panel.add_theme_stylebox_override("panel", _flat_style(Color(GOLD, 0.1), 14, Color(GOLD, 0.5), 1))
	coin_label = _label("Coins: 0", 13, GOLD)
	coin_panel.add_child(coin_label)
	coin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet_row.add_child(coin_panel)
	sound_btn = _button("Sound ON", 12)
	sound_btn.pressed.connect(_toggle_sound)
	wallet_row.add_child(sound_btn)
	music_btn = _button("Music ON", 12)
	music_btn.pressed.connect(_toggle_music)
	wallet_row.add_child(music_btn)
	outer.add_child(wallet_row)

	# Daily tasks card
	var tc := _card("DAILY TASKS")
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 4)
	tc[1].add_child(tasks_box)
	outer.add_child(tc[0])

	# Market card
	var mc := _card("MARKET")
	market_grid = GridContainer.new()
	market_grid.columns = 2
	market_grid.add_theme_constant_override("h_separation", 8)
	market_grid.add_theme_constant_override("v_separation", 8)
	mc[1].add_child(market_grid)
	outer.add_child(mc[0])

	# Badges card
	var bc := _card("BADGES")
	badge_box = VBoxContainer.new()
	badge_box.add_theme_constant_override("separation", 3)
	bc[1].add_child(badge_box)
	var note := _label("Leaderboard cleanup: every 5 days only scores under 100 are removed.", 9, Color(1, 1, 1, 0.4))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bc[1].add_child(note)
	outer.add_child(bc[0])

	var exit_btn := _button("Exit Game", 13, "danger")
	exit_btn.custom_minimum_size = Vector2(180, 40)
	exit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_btn.pressed.connect(_confirm_exit)
	outer.add_child(exit_btn)

	outer.add_child(Control.new())  # bottom spacer

	_build_confirm_overlay()

	# Room dialog
	dialog = ConfirmationDialog.new()
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	dlg_info = _label("", 12, Color(1, 1, 1, 0.7))
	dlg_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_code = LineEdit.new()
	dlg_code.placeholder_text = "Room code (e.g. SHIFTAB12)"
	dlg_code.max_length = 10
	dlg_name = LineEdit.new()
	dlg_name.placeholder_text = "Room name"
	dlg_name.max_length = 22
	dv.add_child(dlg_info)
	dv.add_child(dlg_code)
	dv.add_child(dlg_name)
	dialog.add_child(dv)
	dialog.confirmed.connect(_on_dialog_ok)
	add_child(dialog)


func refresh_ui() -> void:
	Meta.reset_daily_if_needed()
	for icon in avatar_icons:
		icon.set_selected(icon.avatar == Meta.avatar)
	room_status.text = "Room: %s  [%s]" % [Meta.room_name(Meta.current_room), Meta.current_room] if Meta.current_room != "" else "Global leaderboard"
	room_history.clear()
	room_history.add_item("Saved rooms")
	room_history.set_item_disabled(0, true)
	for i in Meta.rooms.size():
		var r: Dictionary = Meta.rooms[i]
		room_history.add_item("%s - %s" % [r.get("name", ""), r.get("code", "")])
		if r.get("code", "") == Meta.current_room:
			room_history.select(i + 1)
	coin_label.text = "Coins: %d" % Meta.coins
	sound_btn.text = "Sound ON" if Meta.sound_on else "Sound OFF"
	music_btn.text = "Music ON" if Meta.music_on else "Music OFF"
	_refresh_tasks()
	_refresh_market()
	_refresh_badges()


func _refresh_tasks() -> void:
	for c in tasks_box.get_children():
		c.queue_free()
	for t in Meta.TASKS:
		var row := HBoxContainer.new()
		var l := _label(t["label"], 12, Color(1, 1, 1, 0.85))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var p := Meta.task_progress(t)
		var done := p >= int(t["target"])
		var claimed: bool = Meta.daily["claimed"].get(t["id"], false)
		var b := _button("Done" if claimed else "%d/%d  +%d" % [p, t["target"], t["reward"]], 11,
			"primary" if done and not claimed else "chip")
		b.disabled = (not done) or claimed
		var tid: String = t["id"]
		b.pressed.connect(func():
			Meta.claim_task(tid)
			refresh_ui())
		row.add_child(b)
		tasks_box.add_child(row)


func _refresh_market() -> void:
	for c in market_grid.get_children():
		c.queue_free()
	for m in Meta.MARKET:
		var txt: String
		var kind := "chip"
		if Meta.owned.get(m["id"], false):
			if Meta.active_item.get(m["type"], "default") == m["id"]:
				txt = "%s: ON" % m["label"]
				kind = "primary"
			else:
				txt = "%s: use" % m["label"]
		else:
			txt = "%s  %d c" % [m["label"], m["cost"]]
			kind = "gold"
		var b := _button(txt, 11, kind)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 38)
		var mid: String = m["id"]
		b.pressed.connect(func():
			Meta.buy_item(mid)
			refresh_ui())
		market_grid.add_child(b)


func _refresh_badges() -> void:
	for c in badge_box.get_children():
		c.queue_free()
	for bname in Meta.BADGE_LIST:
		var row := HBoxContainer.new()
		var unlocked: bool = Meta.badges.get(bname, false)
		var l := _label(bname, 12, Color(1, 1, 1, 0.85) if unlocked else Color(1, 1, 1, 0.45))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var st := _label("UNLOCKED" if unlocked else "LOCKED", 10, GREEN if unlocked else Color(1, 1, 1, 0.35))
		row.add_child(st)
		badge_box.add_child(row)


func _on_avatar_picked(av: String) -> void:
	Meta.avatar = av
	Meta.save()
	Sfx.tick()
	Sfx.score()
	for icon in avatar_icons:
		icon.set_selected(icon.avatar == av)


func _toggle_sound() -> void:
	Meta.sound_on = not Meta.sound_on
	Meta.save()
	refresh_ui()


func _toggle_music() -> void:
	Meta.music_on = not Meta.music_on
	Meta.save()
	Sfx.update_music()
	refresh_ui()


func _build_confirm_overlay() -> void:
	confirm_overlay = Control.new()
	confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks behind
	confirm_overlay.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.1, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.add_child(center)

	var card := PanelContainer.new()
	var sb := _flat_style(Color(0.1, 0.08, 0.22, 0.98), 18, GOLD, 2)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(300, 0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var title := _label("Exit Game?", 24, GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(title)
	var msg := _label("Are you sure you want to quit?", 13, Color(1, 1, 1, 0.7))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)

	v.add_child(_spacer(6))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var yes := _button("Yes", 15, "danger")
	yes.custom_minimum_size = Vector2(112, 44)
	yes.pressed.connect(func(): get_tree().quit())
	var no := _button("No", 15, "primary")
	no.custom_minimum_size = Vector2(112, 44)
	no.pressed.connect(func(): confirm_overlay.visible = false)
	row.add_child(yes)
	row.add_child(no)
	v.add_child(row)

	add_child(confirm_overlay)


func _spacer(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


func _confirm_exit() -> void:
	confirm_overlay.visible = true
	confirm_overlay.move_to_front()


func _submit() -> void:
	var n := name_field.text.strip_edges()
	if n.length() < 2:
		name_field.placeholder_text = "Name (min 2 letters)!"
		return
	Meta.player_name = n
	Meta.save()
	visible = false
	SB.ping_active(Meta.player_name, Meta.session_id)
	game.admin_start_level = 1
	game.start_game(1)


func _open_lb() -> void:
	visible = false
	game.open_leaderboard()


# --- Rooms ---

func _rand_code(n: int) -> String:
	const CH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	for i in n:
		out += CH[randi() % CH.length()]
	return out


func _create_room() -> void:
	dlg_mode = "create"
	dialog.title = "Create Room"
	dialog.get_ok_button().text = "Create"
	dlg_info.text = "A room has its own leaderboard. You get a code to share with friends."
	dlg_code.visible = false
	dlg_name.visible = true
	dlg_name.text = "%s's Room" % Meta.player_name if Meta.player_name != "" else "My Shift Room"
	dialog.popup_centered(Vector2i(320, 180))


func _join_room() -> void:
	dlg_mode = "join"
	dialog.title = "Join Room"
	dialog.get_ok_button().text = "Join"
	dlg_info.text = "Enter the room code your friend shared."
	dlg_code.visible = true
	dlg_code.text = ""
	dlg_name.visible = false
	dialog.popup_centered(Vector2i(320, 170))


func _on_dialog_ok() -> void:
	if dlg_mode == "create":
		var code := "SHIFT" + _rand_code(4)
		var rname := dlg_name.text.strip_edges()
		if rname == "":
			rname = "My Shift Room"
		Meta.set_room(code)
		Meta.remember_room(code, rname)
		DisplayServer.clipboard_set(code)
		room_status.text = "Room created! Code %s copied." % code
	elif dlg_mode == "join":
		var code := Meta.clean_room(dlg_code.text)
		if code == "":
			return
		Meta.set_room(code)
		Meta.remember_room(code, code)
	refresh_ui()
	if dlg_mode == "create":
		room_status.text = "Room ready — code %s copied!" % Meta.current_room
	game.refresh_leaderboard()


func _copy_room_code() -> void:
	if Meta.current_room == "":
		room_status.text = "No room active — create one first."
		return
	DisplayServer.clipboard_set(Meta.current_room)
	room_status.text = "Code %s copied!" % Meta.current_room


func _delete_room() -> void:
	var idx := room_history.selected
	if idx <= 0 or idx - 1 >= Meta.rooms.size():
		room_status.text = "Select a saved room to delete."
		return
	var code: String = Meta.rooms[idx - 1].get("code", "")
	Meta.rooms.remove_at(idx - 1)
	if Meta.current_room == code:
		Meta.set_room("")
	Meta.save()
	refresh_ui()
	room_status.text = "Removed %s from your list." % code
	game.refresh_leaderboard()


func _leave_room() -> void:
	Meta.set_room("")
	refresh_ui()
	game.refresh_leaderboard()


func _on_room_selected(idx: int) -> void:
	if idx <= 0 or idx - 1 >= Meta.rooms.size():
		return
	var code: String = Meta.rooms[idx - 1].get("code", "")
	if code == "":
		return
	Meta.set_room(code)
	Meta.remember_room(code, Meta.room_name(code))
	refresh_ui()
	game.refresh_leaderboard()
