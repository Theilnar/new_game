extends Node2D

@export_category("Flashlight")
@export var base_energy := 2.4
@export var flicker := 0.12
@export var light_color := Color(0.82, 0.91, 1.0, 1.0)
@export var texture_scale := 2.8
@export var aim_offset_degrees := -90.0

@onready var light: PointLight2D = $PointLight2D
var target_energy := 2.4


func _ready() -> void:
	light.color = light_color
	light.texture_scale = texture_scale
	target_energy = base_energy


func _process(delta: float) -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 0.001:
		# The flashlight texture points down in its default orientation.
		rotation = direction.angle() + deg_to_rad(aim_offset_degrees)

	if randf() < 0.08:
		target_energy = base_energy + randf_range(-flicker, flicker)
	light.energy = lerpf(light.energy, target_energy, delta * 12.0)
