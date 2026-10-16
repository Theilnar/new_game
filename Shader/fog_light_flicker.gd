extends PointLight2D

@export var base_energy: float = 3.25
@export var flicker_amount: float = 0.22
@export var flicker_speed: float = 1.4

var time := 0.0


func _process(delta: float) -> void:
	time += delta
	var flicker := sin(time * flicker_speed) * 0.65 + sin(time * 8.7) * 0.35
	energy = base_energy * (1.0 + flicker * flicker_amount)
