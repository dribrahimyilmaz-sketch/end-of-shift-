extends Node
## Isolate the walkout scene: print w and intro_doc_x, capture one frame.

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
	game.set_process(false)  # stop _update from moving intro_doc_x / scene_t
	game.scn = "WALKOUT"
	game.scene_t = 0.5
	game.intro_doc_x = 400.0
	game.queue_redraw()
	# let the redraw actually land before capturing
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[WALKOUT] w=", game.w, " intro_doc_x=", game.intro_doc_x)
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://walkout_clean.png")
	print("[WALKOUT] saved")
	get_tree().quit()
