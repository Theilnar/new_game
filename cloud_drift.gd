extends ParallaxLayer

## Slow autonomous movement for the cloud layer.
@export var drift_speed: float = 2.0


func _process(delta: float) -> void:
	var repeat_width := motion_mirroring.x
	if repeat_width <= 0.0:
		return

	# motion_offset is the ParallaxLayer-native way to drift a mirrored layer.
	# Moving position.x conflicts with the internal parallax transform and causes gaps.
	motion_offset.x -= drift_speed * delta
	if motion_offset.x <= -repeat_width:
		motion_offset.x += repeat_width
