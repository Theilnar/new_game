extends Node2D

var cam_trigger = false

@onready var camera = $"../Player/Player/Camera2D"
#var camera := $"../Player/Player/Camera2D"

func _physics_process(_delta: float) -> void:
	if cam_trigger == true:
		pass

		# Создание объекта Tween
		#tween = Tween()
		#add_child(self.tween)
		#var tween = get_tree().create_tween()
		
		#tween.parallel().tween_property(self,"position:x",$"../../ladder".position.x,0.4)
		#var tween = get_tree().create_tween()
		#tween.tween_property(self, "position", Vector2(global_position.x+20,global_position.y-5), 0.9);
		# Настройка анимации изменения свойств камеры
		
		#tween.tween_property(camera, "position",camera.position, camera.position + Vector3(0, 5, -5), 1.0)
		#tween.parallel().tween_property(camera, "zoom", camera.zoom, camera.zoom * 0.5, 1.0)
		#tween.set_ease(Tween.EASE_IN_OUT)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		cam_trigger = true
		print('мы тутаф ')
		var tween = create_tween()
		#camera.enabled = false
		tween.parallel().tween_property(camera, "zoom", Vector2(2.5, 2.5), 5.0)
		#tween.parallel().tween_property(camera, "position", Vector2(500, 0), 4.0)
		#camera_transition(camera, "position", 20.0,4.0)
		#tween.interpolate_property(camera, "position", 0, 200, 20.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		#tween.interpolate_property(camera,"zoom",2,1, 1.0)


		#camera.zoom.x = 1.0
		#camera.zoom.y = 1.0
		#get_node("Camera2D").set_zoom(Vector2(1, 1))
		#var tween = get_tree().create_tween()
		#tween.parallel().tween_property(camera, "zoom", camera.zoom, camera.zoom * 0.5, 1.0);


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		cam_trigger = false
		var tween = create_tween()

		tween.parallel().tween_property(camera, "zoom", Vector2(1.8, 1.8), 5.0)
