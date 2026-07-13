extends Node2D
## Renders all 4 avatars: standing (front) + walk cycle (side) at 6 phases.

const DocDraw := preload("res://scripts/DocDraw.gd")

var _shot := false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 900, 500), Color("#5a7ea0"))
	var avatars := ["maleDoctor", "femaleDoctor", "maleNurse", "femaleNurse"]
	for row in 4:
		var y := 110.0 + row * 100
		# ground line
		draw_line(Vector2(0, y), Vector2(900, y), Color(0, 0, 0, 0.2), 1)
		# standing (front)
		DocDraw.character(self, Vector2(50, y), avatars[row], {"scale": 0.85})
		# 6 phases of the walk cycle
		for ph in 6:
			var t := TAU * ph / 6.0
			DocDraw.character(self, Vector2(160 + ph * 120, y), avatars[row], {"t": t, "scale": 0.85})


func _process(_d: float) -> void:
	if _shot:
		return
	_shot = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://preview_doc.png")
	print("[PREVIEW] saved")
	get_tree().quit()
