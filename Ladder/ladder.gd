extends Node2D

#func _ready() -> void:
	#add_to_group("Ladder")
	#print(get_groups())

	
	#Signals.connect("player_position_update", Callable (self, "_on_player_position_update"))

func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if body.name == "Player":
		#Global.is_climbing = true
		$Label.text = "Лестница " + str(Global.is_climbing)
##	if is_in_group('Ladder'):
#		print('aa')


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		#Global.is_climbing = false
		$Label.text = "Лестница " + str(Global.is_climbing)
