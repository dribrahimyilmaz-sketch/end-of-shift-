extends Node
## Automated smoke test — drives the game through every scene/state so all
## _draw and update paths execute. Run: godot --path . res://test/TestMain.tscn

var game: Node2D


func _ready() -> void:
	var main: Node2D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	game = main
	_run()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_%s.png" % name)
	print("[TEST] screenshot: ", name)


func _run() -> void:
	await _wait(0.5)
	await _shot("menu")
	game.menu.visible = false
	game.start_game(1)
	print("[TEST] scene=", game.scn)
	await _wait(1.0)
	await _shot("hospital")
	game._on_s(Vector2(400, 300))  # tap hospital -> walkout
	await _wait(2.2)
	print("[TEST] scene=", game.scn, " state=", game.state)
	var avatars := ["maleDoctor", "femaleDoctor", "maleNurse", "femaleNurse"]
	for i in 12:
		Meta.avatar = avatars[i % 4]
		game._on_s(Vector2(-99999, -99999))
		await _wait(0.3)
		game._on_e()
		await _wait(1.5)
	print("[TEST] after cycles: scene=", game.scn, " state=", game.state,
		" score=", game.score, " lvl=", game.lvl, " lives=", game.lives)
	game.scn = "GAME"
	game.state = "WAITING"
	await _wait(0.1)
	await _shot("game")
	# Force each cinematic to exercise its draw path
	game.scn = "HOUSEIN"
	game.scene_t = 0.0
	game.intro_doc_x = 100
	await _wait(1.0)
	game.scn = "DUEL"
	game.scene_t = 0.0
	await _wait(1.2)
	await _shot("duel")
	game.scn = "FLASH"
	game.scene_t = 0.0
	await _wait(0.5)
	game.scn = "GAME"
	game.state = "BURST"
	game.burst_wx = game.pl["x"]
	game.burst_y = game.h - 24
	game.burst_t = 0.0
	await _wait(2.0)
	print("[TEST] after burst: state=", game.state, " lives=", game.lives,
		" death_msg_t=", game.death_msg_t)
	game.state = "GAME_OVER"
	await _wait(0.5)
	await _shot("gameover")
	# Challenge Friends: must create/keep a room and copy the text to clipboard
	game.share_challenge()
	await _wait(0.2)
	var clip := DisplayServer.clipboard_get()
	print("[TEST] challenge room=", Meta.current_room, " clipboard=", clip)
	if not clip.contains("End of Shift") or Meta.current_room == "":
		print("[TEST] FAIL: challenge friends broken")
	game.show_leaderboard = true
	await _wait(0.8)
	await _shot("leaderboard")
	game.show_leaderboard = false
	game.scn = "GAME"
	game.state = "WAITING"
	game.death_msg = "Test line one\nTest line two"
	game.death_msg_t = 2.4
	Meta.active_item = {"steth": "goldSteth", "coat": "mintCoat", "bg": "nightGlow", "trail": "sparkTrail"}
	game.state = "WALKING"
	await _wait(1.0)
	print("[TEST] OK — all draw paths exercised")
	get_tree().quit()
