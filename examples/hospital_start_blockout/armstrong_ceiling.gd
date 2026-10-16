extends Node2D

const CEILING_LEFT := -230.0
const CEILING_RIGHT := -252.0
const CEILING_TOP := -300.0
const CEILING_END := 1800.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var seam_color := Color(0.23, 0.25, 0.26, 0.9)
	var highlight_color := Color(0.46, 0.48, 0.48, 0.45)
	# Продольные швы плит Armstrong с лёгким перспективным наклоном.
	for x in range(0, 1801, 128):
		var t := float(x) / CEILING_END
		var bottom_y: float = lerpf(CEILING_LEFT, CEILING_RIGHT, t)
		draw_line(Vector2(x, CEILING_TOP), Vector2(x, bottom_y), seam_color, 2.0)
		draw_line(Vector2(x + 2, CEILING_TOP + 2), Vector2(x + 2, bottom_y - 1), highlight_color, 1.0)

	# Поперечные швы слегка сходятся к дальней стороне потолка.
	for y in [-285.0, -270.0, -255.0]:
		var t: float = float(y - CEILING_TOP) / float(CEILING_LEFT - CEILING_TOP)
		var right_y: float = lerpf(CEILING_TOP, CEILING_RIGHT, t)
		draw_line(Vector2(0, y), Vector2(CEILING_END, right_y), seam_color, 2.0)
