extends Node2D
func _physics_process(delta: float) -> void:
	var unit = get_viewport().get_texture().get_size() / Vector2(get_viewport_rect().size)
	$CanvasLayer/Control/GlowProcess.get_material().set_shader_parameter("unit", unit)
	

	var x = Input.get_axis("ui_left", "ui_right")
	var y = Input.get_axis("ui_up", "ui_down")
	$Icon.position += Vector2(x, y)
	if Input.is_action_pressed("ui_select"):
		$Icon.rotation_degrees += 1
	pass
