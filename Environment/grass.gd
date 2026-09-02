extends Node2D


var on_grass = false

func _physics_process(_delta: float) -> void:
		if $"../../Player/Player".velocity.x !=0 and on_grass:
			($Sprite2D.material as ShaderMaterial).set_shader_parameter('detail',5.0)
			($Sprite2D.material as ShaderMaterial).set_shader_parameter('max strength',0.08)
		else:
			($Sprite2D.material as ShaderMaterial).set_shader_parameter('detail',1.0)
			($Sprite2D.material as ShaderMaterial).set_shader_parameter('max strength',0.03)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		on_grass = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		on_grass = false
		
