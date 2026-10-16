extends Node2D







func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		Global.player_on_visibility_area = true

func _on_area_2d_body_exited(_body: Node2D) -> void:
	#if body.name == "Player":
		Global.player_on_visibility_area = false
