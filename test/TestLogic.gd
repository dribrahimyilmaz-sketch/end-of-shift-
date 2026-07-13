extends Node
## Deterministic logic test: place the stick exactly on the next platform and
## verify the player walks, scores and the level progresses.

var game: Node2D


func _ready() -> void:
	var main: Node2D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	game = main
	_run()


func _run() -> void:
	await get_tree().process_frame
	game.menu.visible = false
	game.start_game(1)
	game.scn = "GAME"
	game.state = "WAITING"
	var ok := true
	for i in 12:
		var np: Dictionary = game.plats[game.ci + 1]
		var target: float = (np["x"] + np["w"] / 2.0) - game.piv_x()
		game.stick_len = target
		game.stick_ang = 0.0
		game.state = "FALLING"
		var guard := 0
		while game.state != "WAITING" and game.scn == "GAME" and guard < 3000:
			game._update(1.0 / 60.0)
			guard += 1
		if game.scn != "GAME":
			break
	print("[LOGIC] score=", game.score, " combo=", game.combo, " lp=", game.lp,
		" scene=", game.scn, " state=", game.state, " ci=", game.ci)
	if game.score < 10:
		ok = false
		print("[LOGIC] FAIL: expected perfect landings to score")
	if game.scn != "HOUSEIN":
		ok = false
		print("[LOGIC] FAIL: expected HOUSEIN after 10 platforms, got ", game.scn)
	# miss test
	game.scn = "GAME"
	game.state = "WAITING"
	game.lp = 0
	game.stick_len = 1.0
	game.stick_ang = 0.0
	game.state = "FALLING"
	var guard2 := 0
	while game.state != "DEAD" and guard2 < 600:
		game._update(1.0 / 60.0)
		guard2 += 1
	if game.state != "DEAD":
		ok = false
		print("[LOGIC] FAIL: short stick should cause DEAD, state=", game.state)
	print("[LOGIC] ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)
