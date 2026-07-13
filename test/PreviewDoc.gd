extends Node2D
## Renders all 4 avatars: standing (front) + walk cycle (side) at 6 phases.

const DocDraw := preload("res://scripts/DocDraw.gd")

var _shot := false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 900, 500), Color("#5a7ea0"))
	var avatars := ["maleDoctor", "femaleDoctor", "maleNurse", "femaleNurse"]
	# big front + big side, zoomed for face/neck/beard inspection
	for i in 4:
		var x := 120.0 + i * 210
		DocDraw.character(self, Vector2(x, 250), avatars[i], {"scale": 2.4})
		DocDraw.character(self, Vector2(x + 90, 470), avatars[i], {"t": PI * 0.5, "scale": 2.0})


func _process(_d: float) -> void:
	if _shot:
		return
	_shot = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://preview_doc.png")
	print("[PREVIEW] saved")
	get_tree().quit()
