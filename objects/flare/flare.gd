extends RigidBody2D
## Ignites on spawn; the spent casing remains a physical object.
signal burned_out

@export_range(0.1, 300.0) var burn_duration: float = 30.0
@export_range(0.0, 16.0) var light_energy: float = 4.5
@export_range(32.0, 1200.0) var light_radius: float = 320.0
@export var flare_color: Color = Color(1.0, 0.025, 0.015)
@export_range(0.0, 200.0) var bullet_impulse: float = 35.0
@export_range(0.0, 500.0) var bullet_spin_impulse: float = 45.0

var burning: bool = true
var elapsed: float = 0.0
var rng := RandomNumberGenerator.new()
var sparks: CPUParticles2D
var flame: CPUParticles2D
var smoke: CPUParticles2D
@onready var light: PointLight2D = $RedLight
var glow: Sprite2D

func on_bullet_hit(direction: Vector2, _damage: int) -> void:
	if direction.length_squared() <= 0.001:
		return
	sleeping = false
	var hit_direction := direction.normalized()
	apply_central_impulse(hit_direction * bullet_impulse)
	var spin_sign := signf(hit_direction.x)
	if is_zero_approx(spin_sign):
		spin_sign = signf(hit_direction.y)
	apply_torque_impulse(spin_sign * bullet_spin_impulse)

func _ready() -> void:
	rng.randomize()
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	light.texture_scale = light_radius / 128.0
	light.color = flare_color
	light.energy = light_energy
	light.height = 40.0
	light.range_layer_min = -20
	light.range_layer_max = 20
	light.shadow_enabled = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow = Sprite2D.new()
	glow.texture = texture
	glow.position = light.position
	glow.scale = Vector2.ONE * 0.32
	glow.modulate = flare_color
	glow.material = additive
	add_child(glow)
	sparks = _particles(65, 0.65, 80.0, 180.0, Color(1, 0.7, 0.25), 1.0, 2.3)
	sparks.gravity = Vector2(0, 210)
	sparks.spread = 65.0
	sparks.material = additive
	flame = _particles(32, 0.3, 25.0, 60.0, Color(1, 0.85, 0.6), 2.0, 5.0)
	flame.spread = 25.0
	flame.material = additive
	smoke = _particles(20, 2.5, 12.0, 24.0, Color(0.32, 0.28, 0.27, 0.3), 7.0, 14.0)
	smoke.texture = texture
	smoke.scale_amount_min = 0.025
	smoke.scale_amount_max = 0.06
	smoke.gravity = Vector2(6, -12)

func _particles(amount: int, lifetime: float, speed_min: float, speed_max: float, tint: Color, size_min: float, size_max: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = Vector2(0, -11)
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.direction = Vector2.UP
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.scale_amount_min = size_min
	particles.scale_amount_max = size_max
	var ramp := Gradient.new()
	ramp.set_color(0, tint)
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0))
	particles.color_ramp = ramp
	add_child(particles)
	return particles

func _process(delta: float) -> void:
	if not burning:
		return
	elapsed += delta
	if elapsed >= burn_duration:
		burning = false
		light.enabled = false
		glow.visible = false
		sparks.emitting = false
		flame.emitting = false
		smoke.emitting = false
		burned_out.emit()
		return
	var ignition := clampf(elapsed / 0.12, 0.0, 1.0)
	var fade := clampf((burn_duration - elapsed) / minf(2.0, burn_duration * 0.25), 0.0, 1.0)
	var flicker := 0.88 + sin(elapsed * 39.0) * 0.08 + rng.randf_range(0.0, 0.22)
	light.energy = light_energy * ignition * fade * flicker
	glow.modulate = flare_color * Color(1, 1, 1, ignition * fade * flicker)
