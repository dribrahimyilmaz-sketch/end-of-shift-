extends Node
## Portrait smoke test: force a portrait window, play into GAME, capture HUD + zoom.

var game: Node2D


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(432, 768)
	var main: Node2D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	game = main
	_run()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://portrait_%s.png" % name)
	print("[PORTRAIT] shot ", name, " w=", game.w, " h=", game.h)


func _run() -> void:
	await _wait(0.4)
	Meta.player_name = "nimet"
	Meta.avatar = "maleDoctor"
	game.menu.refresh_ui()
	await _wait(0.2)
	await _shot("menu")
	game.menu._confirm_exit()
	await _wait(0.2)
	await _shot("menu_exit")
	game.menu.confirm_overlay.visible = false
	game.menu.visible = false
	game.start_game(2)
	game.scn = "GAME"
	game.state = "WAITING"
	game.score = 29
	game.lives = 2
	await _wait(0.3)
	await _shot("waiting")
	# land a few platforms so we can see the walk + zoom mid-run
	for i in 3:
		var np: Dictionary = game.plats[game.ci + 1]
		game.stick_len = (np["x"] + np["w"] / 2.0) - game.piv_x()
		game.stick_ang = 0.0
		game.state = "FALLING"
		var guard := 0
		while game.state != "WAITING" and game.scn == "GAME" and guard < 2000:
			game._update(1.0 / 60.0)
			guard += 1
	await _wait(0.2)
	await _shot("mid")
	# exit-confirm panel
	game.confirm_exit = true
	await _wait(0.1)
	await _shot("confirm")
	game.confirm_exit = false
	# big house: HOUSEIN cinematic centres the house on the current platform
	game.scn = "HOUSEIN"
	game.scene_t = 0.3
	game.intro_doc_x = game.scx(game.plats[game.ci]["x"]) + 12
	await _wait(0.1)
	await _shot("house")
	print("[PORTRAIT] OK")
	get_tree().quit()
