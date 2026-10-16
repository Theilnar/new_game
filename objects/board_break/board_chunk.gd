extends RigidBody2D

@export var life_time := 3.0

func _ready() -> void:
	var timer := get_tree().create_timer(life_time)
	timer.timeout.connect(queue_free)

