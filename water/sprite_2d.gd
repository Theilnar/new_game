extends Sprite2D

func _process(delta: float) -> void:
	_zoom()
	
func _zoom():
	pass
	#material.set_shader_param("scale_y",scale)



	#material.set_shader_param("zoom_y", get_viewport_transform().get_scale().y)


func _on_item_rect_changed() -> void:
	material.set_shader_param("scale",scale)
