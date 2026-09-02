extends PointLight2D

@export var base_energy := 1.5

var target_energy := 1.5

func _process(delta):
	if randf() < 0.02:
		target_energy = randf_range(0.2, 0.8)
	elif randf() < 0.05:
		target_energy = base_energy
	
	energy = lerp(energy, target_energy, delta * 12.0)
