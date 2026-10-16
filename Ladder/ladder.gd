extends Node2D

@export_enum("top", "left", "right") var exit_direction: String = "top"
@export var top_drop_through_time: float = 0.3
@onready var top_platform_collision: CollisionShape2D = $ExitTop/TopPlatform/CollisionShape2D
var top_drop_timer: float = 0.0

func _ready() -> void:
	top_platform_collision.disabled = exit_direction != "top"

func _physics_process(delta: float) -> void:
	if top_drop_timer > 0.0:
		top_drop_timer -= delta
		if top_drop_timer <= 0.0 and exit_direction == "top":
			top_platform_collision.disabled = false

func begin_top_drop() -> void:
	if exit_direction != "top":
		return
	top_platform_collision.set_deferred("disabled", true)
	top_drop_timer = top_drop_through_time

func cancel_top_drop() -> void:
	if exit_direction != "top":
		return
	top_drop_timer = 0.0
	top_platform_collision.set_deferred("disabled", false)

func is_top_exit() -> bool:
	return exit_direction == "top"

func get_exit_position() -> Vector2:
	var marker_name: String = String({
		"top": "ExitTop",
		"left": "ExitLeft",
		"right": "ExitRight",
	}.get(exit_direction, "ExitTop"))
	var marker := get_node_or_null(marker_name) as Marker2D
	return marker.global_position if marker != null else global_position

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
