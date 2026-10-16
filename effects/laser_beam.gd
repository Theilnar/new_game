extends Node2D
class_name LaserBeam

@export var beam_color := Color(0.15, 0.75, 1.0, 1.0)
@export var beam_length := 420.0
@export var beam_width := 3.0
@export var light_count := 7
@export var light_energy := 1.2
@export var light_radius := 1.0
@export var shockwave_on_pulse := true

@onready var core: Line2D = $Core
@onready var aura: Line2D = $Aura
@onready var wide_aura: Line2D = $WideAura
@onready var lights: Node2D = $Lights
@onready var shockwave: ColorRect = $ShockwaveLayer/Shockwave

var _start := Vector2.ZERO
var _end := Vector2.RIGHT * 420.0
var _pulse_tween: Tween

func _ready() -> void:
	_end = Vector2.RIGHT * beam_length
	_rebuild_beam()
	_build_lights()
	shockwave.visible = false

func _process(_delta: float) -> void:
	var flicker := 0.94 + sin(Time.get_ticks_msec() * 0.02) * 0.06
	core.modulate.a = flicker
	aura.modulate.a = 0.72 + flicker * 0.12
	wide_aura.modulate.a = 0.28 + flicker * 0.08

func set_beam(start_point: Vector2, end_point: Vector2) -> void:
	_start = start_point
	_end = end_point
	_rebuild_beam()
	_build_lights()

func pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(core, "width", beam_width * 2.4, 0.06)
	_pulse_tween.parallel().tween_property(aura, "width", beam_width * 5.0, 0.06)
	_pulse_tween.parallel().tween_property(wide_aura, "width", beam_width * 11.0, 0.06)
	_pulse_tween.tween_property(core, "width", beam_width, 0.22)
	_pulse_tween.parallel().tween_property(aura, "width", beam_width * 2.3, 0.22)
	_pulse_tween.parallel().tween_property(wide_aura, "width", beam_width * 6.0, 0.22)
	for light in lights.get_children():
		light.energy = light_energy * 2.8
		var light_tween := create_tween()
		light_tween.tween_property(light, "energy", light_energy, 0.28)
	if shockwave_on_pulse:
		_play_shockwave()

func _rebuild_beam() -> void:
	var points := PackedVector2Array([_start, _end])
	core.points = points
	aura.points = points
	wide_aura.points = points

func _build_lights() -> void:
	for child in lights.get_children():
		child.queue_free()
	await get_tree().process_frame
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(beam_color.r, beam_color.g, beam_color.b, 0.9), Color(beam_color.r, beam_color.g, beam_color.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	for index in range(maxi(1, light_count)):
		var light := PointLight2D.new()
		light.color = beam_color
		light.energy = light_energy
		light.texture = texture
		light.texture_scale = light_radius
		light.position = _start.lerp(_end, float(index) / float(maxi(1, light_count - 1)))
		lights.add_child(light)

func _play_shockwave() -> void:
	shockwave.visible = true
	shockwave.modulate.a = 1.0
	shockwave.material.set_shader_parameter("progress", 0.0)
	shockwave.material.set_shader_parameter("center", get_viewport().get_canvas_transform() * global_position / get_viewport_rect().size)
	var tween := create_tween()
	tween.tween_method(_set_shockwave_progress, 0.0, 1.0, 0.55)
	tween.tween_callback(func():
		shockwave.visible = false
		shockwave.modulate.a = 0.0
	)

func _set_shockwave_progress(value: float) -> void:
	shockwave.material.set_shader_parameter("progress", value)
