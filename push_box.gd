extends StaticBody2D

var posx_right = false
var posx_left = false

func _physics_process(_delta: float) -> void:
	if posx_right == true:
		position.x +=  1
	if posx_left == true:
		position.x -=  1



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		posx_right = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		posx_right = false

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		posx_left = true

func _on_area_2d_2_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		posx_left = false
