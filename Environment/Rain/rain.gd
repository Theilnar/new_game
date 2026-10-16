extends CanvasLayer

@export var rain_enabled: bool = true:
	set(value):
		rain_enabled = value
		if is_node_ready():
			$RainParticles.emitting = value

@export_range(0.2, 3.0, 0.1) var rain_density: float = 1.0

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var rain_material: ParticleProcessMaterial = rain_particles.process_material as ParticleProcessMaterial

func _ready() -> void:
	get_viewport().size_changed.connect(_update_rain_area)
	_update_rain_area()
	rain_particles.emitting = rain_enabled

func _update_rain_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	rain_particles.position = Vector2(viewport_size.x * 0.5, -40.0)
	rain_material.emission_box_extents = Vector3(viewport_size.x * 0.5 + 120.0, 24.0, 1.0)
	rain_particles.amount = int(260.0 * rain_density)
	rain_particles.visibility_rect = Rect2(-viewport_size.x * 0.5 - 160.0, -100.0, viewport_size.x + 320.0, viewport_size.y + 220.0)

func set_rain_enabled(value: bool) -> void:
	rain_enabled = value

func toggle_rain() -> void:
	set_rain_enabled(not rain_enabled)
