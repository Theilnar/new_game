extends Sprite2D

@onready var water: Sprite2D = $"."
var water_speed = 0.5

func _ready():
	pass
	#var shader_material = ShaderMaterial.new()
	#shader_material.shader = load("res://Shader/water_shader.tres")
	#self.material = shader_material

func _process(delta):
	pass
	#var material = self.material
	#material.set_shader_param("scale", 0.5)

	#material.set_shader_param("scale",water_speed)

#func _zoom_changed():
#	pass
	#material.set_shader_param("y_zoom", get_viewport().global_canvas_transform.y.y)
	
#func _on_item_rect_changed() -> void:
#	material.set_shader_param("scale",scale)
