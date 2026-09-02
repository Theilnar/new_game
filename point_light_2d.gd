extends PointLight2D

@export var base_energy := 1.2
@export var flicker := 0.3

var target_energy := 1.2

func _process(delta):
	if randf() < 0.1:
		target_energy = base_energy + randf_range(-flicker, flicker)
	
	energy = lerp(energy, target_energy, delta * 10.0)
	
	# Немного меняем размер света
	texture_scale = lerp(
		texture_scale,
		randf_range(0.95, 1.05),
		delta * 5.0
	)
