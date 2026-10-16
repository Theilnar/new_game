extends Area2D

func _physics_process(_delta: float) -> void:
	position.x += 1

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position",position - Vector2(0,25),0.2) #ввер поднимается за 2 сек
		tween.tween_property(self, "modulate:a",0,0.2)  #исчезает за 2 сек
		#tween.tween_callback(queue_free) # как выше было выполнено, то удаляем
 		#body.gold += 1

		
